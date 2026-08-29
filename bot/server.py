#!/usr/bin/env python3
"""
ПК-Мастер — сервер сайта с интеграцией Битрикс24.
Раздаёт статические файлы сайта (из папки ../site) и обрабатывает
POST /api/request, создавая лид в CRM Битрикс24 через вебхук.

Настройки вебхука берутся из файла config.env (переменная BITRIX_WEBHOOK_URL).
Запуск:  python3 server.py   (по умолчанию порт 8080)
Переменная окружения PORT позволяет сменить порт.
"""
import datetime
import json
import os
import sys
import urllib.request
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# Папка со статикой сайта относительно этого файла: <root>/site
SITE_DIR = os.path.join(BASE_DIR, '..', 'site')


def load_config():
    """Читает config.env в словарь."""
    cfg = {}
    env_path = os.path.join(BASE_DIR, 'config.env')
    if os.path.exists(env_path):
        with open(env_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#') or '=' not in line:
                    continue
                key, _, value = line.partition('=')
                cfg[key.strip()] = value.strip().strip('"').strip("'")
    return cfg


CONFIG = load_config()
BITRIX_WEBHOOK_URL = CONFIG.get('BITRIX_WEBHOOK_URL', '')
LOG_FILE = CONFIG.get('LOG_FILE', '')


def is_configured():
    """True, если в config.env вписан реальный адрес вебхука."""
    url = BITRIX_WEBHOOK_URL.strip()
    if not url:
        return False
    if 'ВСТАВЬТЕ' in url:
        return False
    return True


def bitrix_webhook_url(method):
    """Собирает полный URL метода REST из базового адреса вебхука."""
    base = BITRIX_WEBHOOK_URL.strip().rstrip('/')
    # Если пользователь вписал полный URL метода (уже .json) — используем как есть
    if base.lower().endswith('.json'):
        return base
    return f'{base}/{method}.json'


def write_log_file(line):
    """Дописывает строку в файл логов (путь берётся из LOG_FILE)."""
    if not LOG_FILE:
        return
    try:
        path = LOG_FILE
        if not os.path.isabs(path):
            path = os.path.join(BASE_DIR, path)
        log_dir = os.path.dirname(path)
        if log_dir:
            os.makedirs(log_dir, exist_ok=True)
        with open(path, 'a', encoding='utf-8') as f:
            f.write(line + '\n')
    except Exception as exc:
        sys.stderr.write(f'  [Ошибка записи лога]: {exc}\n')


def log(msg):
    """Выводит сообщение в консоль и записывает его в файл логов."""
    line = f'{datetime.datetime.now().isoformat(timespec="seconds")}  {msg}'
    print(line)
    write_log_file(line)


def create_bitrix_lead(data):
    """
    Создаёт лид в Битрикс24 (crm.lead.add).
    Возвращает True при успехе, False при ошибке.
    Если вебхук не настроен — логирует заявку и возвращает True (для теста).
    """
    if not is_configured():
        log(f'[BITRIX24 НЕ НАСТРОЕН] Заявка: {json.dumps(data, ensure_ascii=False)}')
        return True

    call_first = 'Да, позвонить перед визитом' if data.get('call_first') == 'yes' else 'Нет'

    comments_lines = [
        f'Услуга: {data.get("service") or "-"}',
        f'Удобное время звонка: {data.get("call_time") or "-"}',
        f'Позвонить предварительно: {call_first}',
    ]
    if data.get('message'):
        comments_lines.append(f'Описание: {data.get("message")}')

    fields = {
        'TITLE': f"Заявка с сайта — {data.get('service') or 'Ремонт ПК'}",
        'NAME': data.get('name', ''),
        'CITY': data.get('city', ''),
        'ADDRESS': data.get('address', ''),
        'SOURCE_ID': 'WEBFORM',
        'SOURCE_DESCRIPTION': 'Форма на сайте ПК-Мастер',
        'PHONE': [{'VALUE': data.get('phone', ''), 'VALUE_TYPE': 'WORK'}],
        'COMMENTS': '\n'.join(comments_lines),
    }

    payload = {'fields': fields}
    url = bitrix_webhook_url('crm.lead.add')

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
        method='POST',
    )

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read().decode('utf-8')
            result = json.loads(body)
            if 'result' in result:
                log(f'[Битрикс24] Лид создан, id: {result["result"]}')
                return True
            log(f'[Ошибка Битрикс24]: {body}')
            return False
    except Exception as exc:
        log(f'[Ошибка отправки в Битрикс24]: {exc}')
        return False


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, fmt, *args):  # компактный лог (консоль + файл)
        msg = '%s - %s' % (self.address_string(), fmt % args)
        sys.stderr.write(msg + '\n')
        write_log_file(f'{datetime.datetime.now().isoformat(timespec="seconds")}  {msg}')

    def do_POST(self):
        if self.path == '/api/request':
            length = int(self.headers.get('Content-Length', 0) or 0)
            raw = self.rfile.read(length) if length else b''
            try:
                data = json.loads(raw.decode('utf-8'))
            except (ValueError, UnicodeDecodeError):
                self.send_json(400, {'ok': False, 'error': 'Некорректные данные заявки'})
                return

            ok = create_bitrix_lead(data)
            if ok:
                self.send_json(200, {'ok': True, 'message': 'Заявка отправлена'})
            else:
                self.send_json(500, {'ok': False, 'error': 'Не удалось отправить заявку'})
        else:
            self.send_json(404, {'ok': False, 'error': 'Не найдено'})

    def send_json(self, status, obj):
        body = json.dumps(obj, ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)


if __name__ == '__main__':
    os.chdir(SITE_DIR)
    port = int(os.environ.get('PORT', '8080'))
    httpd = ThreadingHTTPServer(('0.0.0.0', port), Handler)
    log('=' * 50)
    log('  ПК-Мастер — сайт запущен')
    log(f'  Статика:   {SITE_DIR}')
    log(f'  Откройте:  http://localhost:{port}')
    log(f'  Логи:      {LOG_FILE if LOG_FILE else "(запись логов отключена)"}')
    if is_configured():
        log('  Битрикс24: настроен (создание лидов активно)')
    else:
        log('  Битрикс24: НЕ настроен — впишите BITRIX_WEBHOOK_URL в config.env')
    log('  Остановка: Ctrl+C')
    log('=' * 50)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('\nСервер остановлен.')
        httpd.server_close()