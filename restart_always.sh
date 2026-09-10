#!/usr/bin/env bash
#
# Скрипт проверки работоспособности ВМ в Yandex Cloud.
# Если ВМ выключена/остановлена — перезапускает её,
# записывает новый публичный IP-адрес и обновляет
# A-запись домена в DNS сервиса Beget.
#
# Требования:
#   - установлен и настроен Yandex Cloud CLI (yc) + jq + curl
#   - авторизация выполнена (yc init / yc auth) с нужным профилем
#
# Запуск вручную:      ./script.sh
# По расписанию (cron): 0 * * * * /home/user/site/script.sh >> /var/log/vm-check.log 2>&1
#
set -euo pipefail

# Ключ API Beget (раздел "Настройки" -> "API" в панели управления)
# Записываем переменные $BEGET_API_LOGIN и BEGET_API_PASS в файл .env и считываем их оттуда
set -a
source .env
set +a

# ======================= КОНФИГУРАЦИЯ =======================
# Имя (или ID) ВМ в Яндекс.Облаке
VM_NAME="mia-project-vm-1"

# Профиль YC (необязательно; укажите, если профилей несколько)
YC_PROFILE=""

# --- Параметры DNS Beget ---
# Домен, для которого меняем запись (например: example.ru)
BEGET_DOMAIN="pc-master-bgm.ru"
# TTL записи в секундах
BEGET_TTL=600
# Базовый адрес API Beget
BEGET_API_BASE="https://api.beget.com/api"

# Файл, куда сохраняется последний использованный IP (для логирования и сравнения)
LAST_IP_FILE="$(dirname "$(realpath "$0")")/.last_nat_ip"
# Файл лога (используется, если вывод не перенаправлен в cron)
LOG_FILE="$(dirname "$(realpath "$0")")/vm-check.log"
# ===========================================================

log() {
    local msg="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${msg}" | tee -a "${LOG_FILE}"
}

die() {
    log "ОШИБКА: $*"
    exit 1
}

# ------------------------------------------------------------
# Получение информации о ВМ через yc
# Возвращает JSON во временную переменную через командную подстановку
get_vm_info() {
    local profile_args=()
    [[ -n "${YC_PROFILE}" ]] && profile_args+=(--profile "${YC_PROFILE}")
    yc compute instance get "${VM_NAME}" "${profile_args[@]}" --format json 2>/dev/null
}

# Извлечение статуса ВМ из JSON
get_status() {
    jq -r '.status' <<< "$1"
}

# Извлечение публичного (NAT) IPv4 из JSON
get_nat_ip() {
    jq -r '.network_interfaces[]?.primary_v4_address.one_to_one_nat.address // empty' <<< "$1"
}

# Ожидание готовности ВМ (статус RUNNING и назначенный внешний IP)
wait_vm_ready() {
    local timeout=180  # максимум секунд ожидания
    local waited=0

    while (( waited < timeout )); do
        local vm_info status ip
        vm_info="$(get_vm_info)" || { sleep 10; waited=$((waited+10)); continue; }
        status="$(get_status "${vm_info}")"
        ip="$(get_nat_ip "${vm_info}")"

        if [[ "${status}" == "RUNNING" && -n "${ip}" ]]; then
            log "ВМ готова (статус=${status}), публичный IP=${ip}"
            return 0
        fi
        sleep 10
        waited=$((waited+10))
    done

    return 1
}

# Ожидание остановки ВМ (статус STOPPED)
wait_vm_stopped() {
    local timeout=180  # максимум секунд ожидания
    local waited=0

    while (( waited < timeout )); do
        local vm_info status
        vm_info="$(get_vm_info)" || { sleep 10; waited=$((waited+10)); continue; }
        status="$(get_status "${vm_info}")"

        if [[ "${status}" == "STOPPED" ]]; then
            log "ВМ остановлена (статус=${status})"
            return 0
        fi
        sleep 10
        waited=$((waited+10))
    done

    return 1
}

# ------------------------------------------------------------
# Обновление A-записи в DNS Beget
update_beget_dns() {
    local new_ip="$1"
    local response updated result_input
    
    # 1. Получаем текущие записи домена
    log "Получение текущих DNS-записей домена '${BEGET_DOMAIN}'..."
    local list_data
    list_data="$(jq -nc --arg d "${BEGET_DOMAIN}" '{fqdn:$d}')"
    response="$(curl -sS "${BEGET_API_BASE}/dns/getData" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "login=${BEGET_API_LOGIN}" \
        --data-urlencode "passwd=${BEGET_API_PASS}" \
        --data-urlencode "input_format=json" \
        --data-urlencode "input_data=${list_data}")"
    
    if [[ "$(jq -r '.answer.status // "error"' <<< "${response}")" != "success" ]]; then
        die "Не удалось получить записи DNS: ${response}"
    fi
    
    # 2. Обновляем значение A-записи
    updated="$(jq -c \
        --arg ip "${new_ip}" \
        --argjson ttl "${BEGET_TTL}" '
        .answer.result.records
        | .A = (.A | map(.ttl = $ttl | .address = $ip))
    ' <<< "${response}")"

    # 3. Отправляем обновлённый набор записей
    log "Обновление A-записи домена '${BEGET_DOMAIN}' на ${new_ip}..."
    result_input="$(jq -nc --arg d "${BEGET_DOMAIN}" --argjson r "${updated}" '{fqdn:$d, records:$r}')"
    response="$(curl -sS "${BEGET_API_BASE}/dns/changeRecords" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "login=${BEGET_API_LOGIN}" \
        --data-urlencode "passwd=${BEGET_API_PASS}" \
        --data-urlencode "input_format=json" \
        --data-urlencode "input_data=${result_input}")"
    
    if [[ "$(jq -r '.answer.status // "error"' <<< "${response}")" != "success" ]]; then
        die "Beget вернул ошибку: ${response}"
    fi

    log "DNS запись успешно обновлена."
}

# Проверка доступности сайта: возвращает HTTP-код ответа
# (или "000", если сервер не отвечает / соединение не установлено)
site_http_code() {
    curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 10 --max-time 20 \
        "https://${BEGET_DOMAIN}" || echo "000"
}

# Ожидание, пока сайт не начнёт отвечать любым HTTP-кодом.
# Возвращает 0, как только получен любой код ответа.
wait_site_ready() {
    local timeout="${1:-300}"  # максимум секунд ожидания
    local waited=0

    while (( waited < timeout )); do
        local code
        code="$(site_http_code)"
        if [[ "${code}" != "000" ]]; then
            log "Сайт отвечает (HTTP ${code})."
            return 0
        fi
        log "Сайт пока не отвечает (HTTP ${code}). Подожду 10 c..."
        sleep 10
        waited=$((waited+10))
    done

    return 1
}

# ============================================================
#                        ГЛАВНАЯ ЛОГИКА
# ============================================================

main() {
    [[ -z "${BEGET_API_LOGIN}" ]] && die "Не задан BEGET_API_LOGIN"

    log "=== Проверка ВМ '${VM_NAME}' ==="

    local profile_args=()
    [[ -n "${YC_PROFILE}" ]] && profile_args+=(--profile "${YC_PROFILE}")

    local vm_info status nat_ip attempts=0 max_attempts=5
    vm_info="$(get_vm_info)" || die "Не удалось получить информацию о ВМ '${VM_NAME}'. Проверьте yc CLI/авторизацию."

    status="$(get_status "${vm_info}")"
    nat_ip="$(get_nat_ip "${vm_info}")"

    log "Статус ВМ: ${status}, публичный IP: ${nat_ip:-нет}"

    # Иногда после старта ВМ в Яндекс.Облаке машина недоступна ни по SSH,
    # ни по HTTP. Повторяем запуск/перезапуск в цикле до тех пор, пока сайт
    # не ответит любым HTTP-кодом.
    while true; do
        attempts=$((attempts+1))
        log "--- Попытка #${attempts} из ${max_attempts} ---"

        if [[ "${status}" != "RUNNING" ]]; then
            log "ВМ не запущена (${status}). Выполняю запуск..."
            if [[ "${status}" == "STOPPED" ]]; then
                yc compute instance start "${VM_NAME}" "${profile_args[@]}" >/dev/null || die "Не удалось запустить ВМ"
            fi

            wait_vm_ready || die "ВМ не стала доступной за отведённое время."
            # После перезапуска внешний IP мог измениться — берём свежий
            vm_info="$(get_vm_info)"
            nat_ip="$(get_nat_ip "${vm_info}")"
        else
            log "ВМ запущена (${status}). Останавливаю..."
            yc compute instance stop "${VM_NAME}" "${profile_args[@]}" >/dev/null || die "Не удалось остановить ВМ"

            wait_vm_stopped || die "ВМ не остановилась за отведнное время."
            
            vm_info="$(get_vm_info)"

            log "Перезапускаю..."
                yc compute instance start "${VM_NAME}" "${profile_args[@]}" >/dev/null || die "Не удалось запустить ВМ"

            wait_vm_ready || die "ВМ не стала доступной за отведнное время."
            # После перезапуска внешний IP мог измениться — берем свежий
            vm_info="$(get_vm_info)"
            status="$(get_status "${vm_info}")"
            nat_ip="$(get_nat_ip "${vm_info}")"
        fi

        [[ -z "${nat_ip}" ]] && die "Не удалось определить публичный IP-адрес ВМ."

        # 4. Сравниваем с предыдущим IP — если не изменился, DNS трогать не нужно
        local prev_ip=""
        [[ -f "${LAST_IP_FILE}" ]] && prev_ip="$(cat "${LAST_IP_FILE}")"

        if [[ "${prev_ip}" == "${nat_ip}" ]]; then
            log "IP не изменился (${nat_ip}). Обновление DNS не требуется."
        else
            log "Новый публичный IP: ${nat_ip} (предыдущий: ${prev_ip:-нет})."
            # Записываем новый адрес в файл
            echo "${nat_ip}" > "${LAST_IP_FILE}"
            # Обновляем DNS в Beget
            update_beget_dns "${nat_ip}"
        fi

        # Как только сайт ответил любым HTTP-кодом — выходим из цикла
        if wait_site_ready; then
            break
        fi

        # Не даём скрипту крутиться вечно
        if (( attempts >= max_attempts )); then
            die "Сайт не стал доступен после ${max_attempts} попыток перезапуска."
        fi

        log "Сайт недоступен — повторяю перезапуск ВМ."
    
    done

    log "=== Готово. Публичный IP ВМ: ${nat_ip} ==="
}

main "$@"