#!/usr/bin/env python3
"""
ПК-Мастер — сервер сайта.
Раздаёт статические файлы сайта (из папки ../site) и обрабатывает
POST /api/request — отправляет заявку по Email и в Telegram.

Настройки берутся из файла config.env.
Запуск:  python3 server.py   (по умолчанию порт 8080)
Переменная окружения PORT позволяет сменить порт.
"""
import datetime
import json
import os
import smtplib
import sys
import urllib.request
import urllib.parse
from email.message import EmailMessage
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
LOG_FILE = CONFIG.get('LOG_FILE', '')
EMAIL_TO = CONFIG.get('EMAIL_TO', 'request@pc-master-bgm.ru')
SMTP_HOST = CONFIG.get('SMTP_HOST', 'localhost').strip()
SMTP_PORT = int(CONFIG.get('SMTP_PORT', '25'))
SMTP_USERNAME = CONFIG.get('SMTP_USERNAME', '').strip()
SMTP_PASSWORD = CONFIG.get('SMTP_PASSWORD', '').strip()
SMTP_FROM = CONFIG.get('SMTP_FROM', EMAIL_TO).strip()
SMTP_USE_TLS = CONFIG.get('SMTP_USE_TLS', 'false').strip().lower() in {'1', 'true', 'yes', 'on'}
TELEGRAM_BOT_TOKEN = CONFIG.get('TELEGRAM_BOT_TOKEN', '').strip()
TELEGRAM_CHAT_ID = CONFIG.get('TELEGRAM_CHAT_ID', '').strip()
TELEGRAM_PROXY = CONFIG.get('TELEGRAM_PROXY', '').strip()


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


def format_email_body(data):
    """Формирует текст письма с данными заявки."""
    call_first = 'Да, позвонить перед визитом' if data.get('call_first') == 'yes' else 'Нет'
    lines = [
        'Новая заявка с сайта ПК-Мастер',
        '================================',
        f"Имя: {data.get('name') or '-'}",
        f"Телефон: {data.get('phone') or '-'}",
        f"Город: {data.get('city') or '-'}",
        f"Адрес: {data.get('address') or '-'}",
        f"Услуга: {data.get('service') or '-'}",
        f"Удобное время звонка: {data.get('call_time') or '-'}",
        f"Позвонить заранее: {call_first}",
    ]
    if data.get('message'):
        lines.append(f"Комментарий: {data.get('message')}")
    lines.append('')
    lines.append(f"Дата/время: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    return '\n'.join(lines)


def send_email_request(data):
    """Отправляет заявку на почту через SMTP."""
    subject = f"Новая заявка — {data.get('service') or 'Ремонт ПК'}"
    message = EmailMessage()
    message['From'] = SMTP_FROM
    message['To'] = EMAIL_TO
    message['Subject'] = subject
    message.set_content(format_email_body(data), charset='utf-8')

    if not SMTP_HOST:
        log(f'[EMAIL] SMTP_HOST не настроен. Заявка не отправлена: {json.dumps(data, ensure_ascii=False)}')
        return False

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=15) as smtp:
            if SMTP_USE_TLS:
                smtp.starttls()
            if SMTP_USERNAME:
                smtp.login(SMTP_USERNAME, SMTP_PASSWORD)
            smtp.send_message(message)
        log(f'[EMAIL] Заявка отправлена на {EMAIL_TO}')
        return True
    except Exception as exc:
        log(f'[EMAIL] Ошибка отправки письма: {exc}')
        log(f'[EMAIL] Заявка для отправки: {json.dumps(data, ensure_ascii=False)}')
        return False


def send_telegram_message(data):
    """Отправляет уведомление в Telegram (бот -> чат).
    Если токен или chat_id не настроены — молча пропускаем и возвращаем True.
    """
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        log('[TG] Telegram не настроен — пропускаем отправку')
        return True

    # Используем тот же текст, что и в письме (серверная сторона; токен не попадёт в JS)
    text = format_email_body(data)
    url = f'https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage'
    post = urllib.parse.urlencode({'chat_id': TELEGRAM_CHAT_ID, 'text': text}).encode('utf-8')
    req = urllib.request.Request(url, data=post, headers={'Content-Type': 'application/x-www-form-urlencoded'})
    try:
        # Если настроен прокси для Telegram, используем его
        if TELEGRAM_PROXY:
            proxy = TELEGRAM_PROXY
            proxy_handler = urllib.request.ProxyHandler({'http': proxy, 'https': proxy})
            opener = urllib.request.build_opener(proxy_handler)
            with opener.open(req, timeout=10) as resp:
                body = resp.read().decode('utf-8')
        else:
            with urllib.request.urlopen(req, timeout=10) as resp:
                body = resp.read().decode('utf-8')

        res = json.loads(body)
        if res.get('ok'):
            log(f'[TG] Уведомление отправлено в Telegram chat_id={TELEGRAM_CHAT_ID}')
            return True
        log(f'[TG] Ошибка API Telegram: {body}')
        return False
    except Exception as exc:
        log(f'[TG] Ошибка отправки в Telegram: {exc}')
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

            email_ok = send_email_request(data)
            tg_ok = send_telegram_message(data)
            if email_ok or tg_ok:
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
    log(f'  Email to:  {EMAIL_TO}')
    log(f'  SMTP:      {SMTP_HOST}:{SMTP_PORT}')
    log(f'  Telegram:  {"настроен" if TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID else "НЕ настроен"}')
    log('  Остановка: Ctrl+C')
    log('=' * 50)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('\nСервер остановлен.')
        httpd.server_close()