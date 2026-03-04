#!/bin/bash

# Файл для записи результатов
LOG_FILE="/var/log/system_check.log"

# Пути к конфигурационным файлам BIND
OPTIONS_CONF="/var/lib/bind/etc/options.conf"
RFC1912_CONF="/var/lib/bind/etc/rfc1912.conf"
ZONE_FORWARD="/var/lib/bind/etc/zone/au-team.irpo"
ZONE_REVERSE1="/var/lib/bind/etc/zone/1.168.192.in-addr.arpa"
ZONE_REVERSE2="/var/lib/bind/etc/zone/2.168.192.in-addr.arpa"

SSH_PASSWORD="P@ssw0rd"
SSH_PORT="2026"
SSH_TARGET="192.168.3.10"

# Очистка лог-файла
> "$LOG_FILE"

# Функция для логирования и вывода
log_and_echo() {
    echo "$1"
    echo "$1" >> "$LOG_FILE"
}

# Функция выполнения проверки
execute_check() {
    local description="$1"
    local command="$2"
    
    log_and_echo "Проверка: $description"
    log_and_echo "Команда: $command"
    
    local output
    output=$(eval "$command" 2>&1)
    local exit_code=$?
    
    echo "$output" >> "$LOG_FILE"
    echo "$output"
    
    if [ $exit_code -eq 0 ]; then
        log_and_echo "✓ УСПЕХ"
    else
        log_and_echo "✗ ОШИБКА (код: $exit_code)"
    fi
    
    log_and_echo ""
    return $exit_code
}

# Функция проверки строки в файле на определённой позиции
check_line_contains() {
    local file="$1"
    local line_num="$2"
    local expected="$3"
    local description="$4"
    
    if [ ! -f "$file" ]; then
        log_and_echo "  ✗ Файл не найден: $file"
        return 1
    fi
    
    local actual_line
    actual_line=$(sed -n "${line_num}p" "$file" 2>/dev/null)
    
    # Убираем лишние пробелы для сравнения
    local actual_trimmed=$(echo "$actual_line" | tr -d '[:space:]')
    local expected_trimmed=$(echo "$expected" | tr -d '[:space:]')
    
    if [[ "$actual_trimmed" == *"$expected_trimmed"* ]] || [[ "$actual_line" == *"$expected"* ]]; then
        log_and_echo "  ✓ Строка $line_num: $description"
        return 0
    else
        log_and_echo "  ✗ Строка $line_num: ожидалось '$expected'"
        log_and_echo "    Фактически: '$actual_line'"
        return 1
    fi
}

# Функция проверки наличия блока в файле
check_block_exists() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if [ ! -f "$file" ]; then
        log_and_echo "  ✗ Файл не найден: $file"
        return 1
    fi
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        log_and_echo "  ✓ $description"
        return 0
    else
        log_and_echo "  ✗ $description - НЕ НАЙДЕНО"
        return 1
    fi
}

# Функция проверки DNS-записи через host
check_dns_record() {
    local query="$1"
    local expected="$2"
    local record_type="$3"
    
    local result
    if [ "$record_type" == "PTR" ]; then
        result=$(host "$query" 127.0.0.1 2>/dev/null)
    else
        result=$(host "$query" 127.0.0.1 2>/dev/null)
    fi
    
    if echo "$result" | grep -q "$expected"; then
        log_and_echo "  ✓ $query → $expected"
        return 0
    else
        log_and_echo "  ✗ $query: ожидалось '$expected'"
        log_and_echo "    Получено: $result"
        return 1
    fi
}

# Функция проверки доступа в интернет
check_internet() {
    ping -c 2 -W 3 8.8.8.8 > /dev/null 2>&1
    return $?
}

# Функция установки sshpass
install_sshpass() {
    log_and_echo "Установка sshpass..."
    if ! command -v sshpass > /dev/null 2>&1; then
        apt-get update -qq && apt-get install sshpass -y -qq
    fi
    
    if command -v sshpass > /dev/null 2>&1; then
        log_and_echo "✓ sshpass установлен"
        return 0
    else
        log_and_echo "✗ Ошибка установки sshpass"
        return 1
    fi
}

# Функция настройки SSH-подключения
setup_ssh() {
    log_and_echo "Настройка SSH-подключения к BR-SRV..."
    
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    ssh-keyscan -p $SSH_PORT -H $SSH_TARGET >> ~/.ssh/known_hosts 2>/dev/null
    log_and_echo "✓ Хост добавлен в known_hosts"
    
    if ! [ -f ~/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa -q
        log_and_echo "✓ SSH-ключ создан"
    else
        log_and_echo "✓ SSH-ключ уже существует"
    fi
    
    sshpass -p "$SSH_PASSWORD" ssh-copy-id -p $SSH_PORT sshuser@$SSH_TARGET 2>/dev/null
    if [ $? -eq 0 ]; then
        log_and_echo "✓ SSH-ключ скопирован на BR-SRV"
        return 0
    else
        log_and_echo "✗ Ошибка копирования SSH-ключа"
        return 1
    fi
}

# ============================================================================
# НАЧАЛО ПРОВЕРКИ
# ============================================================================

clear
log_and_echo "╔══════════════════════════════════════════════════════════════╗"
log_and_echo "║         ПРОВЕРКА КОНФИГУРАЦИИ СЕРВЕРА HQ-SRV                 ║"
log_and_echo "║         Дата: $(date '+%Y-%m-%d %H:%M:%S')                         ║"
log_and_echo "╚══════════════════════════════════════════════════════════════╝"
log_and_echo ""

# ==================== КРИТЕРИЙ 1: IP-АДРЕСАЦИЯ ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 1: Проверка IP-адресации                            │"
log_and_echo "│ Описание: IP-адрес должен быть 192.168.1.10/27               │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

execute_check "IP-адрес 192.168.1.10/27" "ip a | grep 192.168.1.10/27"

# ==================== КРИТЕРИЙ 2: HOSTNAME И ВРЕМЕННАЯ ЗОНА ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 2: Проверка имени хоста и временной зоны            │"
log_and_echo "│ Описание: Hostname = hq-srv.au-team.irpo                     │"
log_and_echo "│           Временная зона = Asia/Yekaterinburg                │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

execute_check "Временная зона Asia/Yekaterinburg" "timedatectl | grep Asia/Yekaterinburg"
execute_check "Имя хоста hq-srv.au-team.irpo" "hostnamectl | grep hq-srv.au-team.irpo"

# ==================== КРИТЕРИЙ 5: ПОЛЬЗОВАТЕЛИ ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 5: Проверка локальных пользователей                 │"
log_and_echo "│ Описание: Проверяем наличие пользователей с домашними        │"
log_and_echo "│           директориями в /home                               │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

execute_check "Пользователи с домашними директориями" "cat /etc/passwd | grep home"

# ==================== КРИТЕРИЙ 6: СЕТЕВАЯ СВЯЗНОСТЬ ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 6: Проверка сетевой связности                       │"
log_and_echo "│ Описание: Проверяем доступность всех узлов инфраструктуры    │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

ping_hosts=(
    "192.168.1.1|HQ-RTR (локальный шлюз)"
    "192.168.2.10|HQ-CLI (клиент в HQ)"
    "172.16.1.1|ISP (провайдер)"
    "192.168.3.10|BR-SRV (сервер филиала)"
    "8.8.8.8|Интернет (Google DNS)"
)

for host_info in "${ping_hosts[@]}"; do
    IFS='|' read -r ip desc <<< "$host_info"
    execute_check "Ping до $desc" "ping -c 2 $ip"
done

execute_check "Ping до BR-SRV по имени" "ping -c 2 br-srv.au-team.irpo"

# ==================== КРИТЕРИЙ 7: DNS-СЕРВЕР BIND ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 7: Проверка DNS-сервера BIND                        │"
log_and_echo "│ Описание: Проверяем конфигурацию и работу DNS-сервера        │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

# --- 7.1 Проверка статуса службы ---
log_and_echo ""
log_and_echo "═══ 7.1 Статус службы BIND ═══"
execute_check "Статус службы bind" "systemctl is-active bind"

# --- 7.2 Проверка options.conf ---
log_and_echo "═══ 7.2 Проверка файла options.conf ═══"
log_and_echo "Файл: $OPTIONS_CONF"

if [ -f "$OPTIONS_CONF" ]; then
    log_and_echo "✓ Файл существует"
    
    check_line_contains "$OPTIONS_CONF" 16 "listen-on { 192.168.1.10; };" "listen-on настроен на 192.168.1.10"
    check_line_contains "$OPTIONS_CONF" 17 "listen-on-v6 { none; };" "IPv6 отключён"
    check_line_contains "$OPTIONS_CONF" 24 "forwarders { 8.8.8.8; };" "forwarders указывает на 8.8.8.8"
    check_line_contains "$OPTIONS_CONF" 29 "allow-query { any; };" "allow-query разрешает всех"
    check_line_contains "$OPTIONS_CONF" 49 "allow-recursion { any; };" "allow-recursion разрешает всех"
else
    log_and_echo "✗ Файл $OPTIONS_CONF не найден"
fi
log_and_echo ""

# --- 7.3 Проверка rfc1912.conf ---
log_and_echo "═══ 7.3 Проверка файла rfc1912.conf ═══"
log_and_echo "Файл: $RFC1912_CONF"

if [ -f "$RFC1912_CONF" ]; then
    log_and_echo "✓ Файл существует"
    
    check_block_exists "$RFC1912_CONF" 'zone "au-team.irpo"' "Зона au-team.irpo объявлена"
    check_block_exists "$RFC1912_CONF" 'zone "1.168.192.in-addr.arpa"' "Зона обратного просмотра 1.168.192 объявлена"
    check_block_exists "$RFC1912_CONF" 'zone "2.168.192.in-addr.arpa"' "Зона обратного просмотра 2.168.192 объявлена"
    check_block_exists "$RFC1912_CONF" 'type master' "Тип зоны: master"
    check_block_exists "$RFC1912_CONF" 'file "au-team.irpo"' "Файл зоны au-team.irpo указан"
else
    log_and_echo "✗ Файл $RFC1912_CONF не найден"
fi
log_and_echo ""

# --- 7.4 Проверка файла прямой зоны ---
log_and_echo "═══ 7.4 Проверка файла прямой зоны au-team.irpo ═══"
log_and_echo "Файл: $ZONE_FORWARD"

if [ -f "$ZONE_FORWARD" ]; then
    log_and_echo "✓ Файл существует"
    
    check_block_exists "$ZONE_FORWARD" 'SOA.*au-team.irpo' "SOA запись настроена"
    check_block_exists "$ZONE_FORWARD" 'NS.*hq-srv.au-team.irpo' "NS запись указывает на hq-srv"
    check_block_exists "$ZONE_FORWARD" 'hq-srv.*IN.*A.*192.168.1.10' "A запись hq-srv → 192.168.1.10"
    check_block_exists "$ZONE_FORWARD" 'hq-rtr.*IN.*A.*192.168.1.1' "A запись hq-rtr → 192.168.1.1"
    check_block_exists "$ZONE_FORWARD" 'hq-cli.*IN.*A.*192.168.2.10' "A запись hq-cli → 192.168.2.10"
    check_block_exists "$ZONE_FORWARD" 'br-rtr.*IN.*A.*192.168.3.1' "A запись br-rtr → 192.168.3.1"
    check_block_exists "$ZONE_FORWARD" 'br-srv.*IN.*A.*192.168.3.10' "A запись br-srv → 192.168.3.10"
    check_block_exists "$ZONE_FORWARD" 'docker.*IN.*A.*172.16.1.1' "A запись docker → 172.16.1.1"
    check_block_exists "$ZONE_FORWARD" 'web.*IN.*A.*172.16.2.1' "A запись web → 172.16.2.1"
else
    log_and_echo "✗ Файл $ZONE_FORWARD не найден"
fi
log_and_echo ""

# --- 7.5 Проверка файла обратной зоны 1.168.192 ---
log_and_echo "═══ 7.5 Проверка файла обратной зоны 1.168.192.in-addr.arpa ═══"
log_and_echo "Файл: $ZONE_REVERSE1"

if [ -f "$ZONE_REVERSE1" ]; then
    log_and_echo "✓ Файл существует"
    
    check_block_exists "$ZONE_REVERSE1" 'SOA.*au-team.irpo' "SOA запись настроена"
    check_block_exists "$ZONE_REVERSE1" 'NS.*hq-srv.au-team.irpo' "NS запись указывает на hq-srv"
    check_block_exists "$ZONE_REVERSE1" '1.*IN.*PTR.*hq-rtr.au-team.irpo' "PTR запись 1 → hq-rtr"
    check_block_exists "$ZONE_REVERSE1" '10.*IN.*PTR.*hq-srv.au-team.irpo' "PTR запись 10 → hq-srv"
else
    log_and_echo "✗ Файл $ZONE_REVERSE1 не найден"
fi
log_and_echo ""

# --- 7.6 Проверка файла обратной зоны 2.168.192 ---
log_and_echo "═══ 7.6 Проверка файла обратной зоны 2.168.192.in-addr.arpa ═══"
log_and_echo "Файл: $ZONE_REVERSE2"

if [ -f "$ZONE_REVERSE2" ]; then
    log_and_echo "✓ Файл существует"
    
    check_block_exists "$ZONE_REVERSE2" 'SOA.*au-team.irpo' "SOA запись настроена"
    check_block_exists "$ZONE_REVERSE2" 'NS.*hq-srv.au-team.irpo' "NS запись указывает на hq-srv"
    check_block_exists "$ZONE_REVERSE2" '1.*IN.*PTR.*hq-rtr.au-team.irpo' "PTR запись 1 → hq-rtr"
    check_block_exists "$ZONE_REVERSE2" '10.*IN.*PTR.*hq-cli.au-team.irpo' "PTR запись 10 → hq-cli"
else
    log_and_echo "✗ Файл $ZONE_REVERSE2 не найден"
fi
log_and_echo ""

# --- 7.7 Проверка конфигурации через named-checkconf ---
log_and_echo "═══ 7.7 Проверка конфигурации BIND (named-checkconf -z) ═══"
log_and_echo "Команда: named-checkconf -z"

checkconf_output=$(named-checkconf -z 2>&1)
checkconf_exit=$?

echo "$checkconf_output" >> "$LOG_FILE"

log_and_echo ""
log_and_echo "Ожидаемые зоны:"

if echo "$checkconf_output" | grep -q "zone au-team.irpo/IN: loaded serial 2025110500"; then
    log_and_echo "  ✓ zone au-team.irpo/IN: loaded serial 2025110500"
else
    log_and_echo "  ✗ zone au-team.irpo/IN: НЕ НАЙДЕНА или неверный serial"
fi

if echo "$checkconf_output" | grep -q "zone 1.168.192.in-addr.arpa/IN: loaded serial 2025110500"; then
    log_and_echo "  ✓ zone 1.168.192.in-addr.arpa/IN: loaded serial 2025110500"
else
    log_and_echo "  ✗ zone 1.168.192.in-addr.arpa/IN: НЕ НАЙДЕНА или неверный serial"
fi

if echo "$checkconf_output" | grep -q "zone 2.168.192.in-addr.arpa/IN: loaded serial 2025110500"; then
    log_and_echo "  ✓ zone 2.168.192.in-addr.arpa/IN: loaded serial 2025110500"
else
    log_and_echo "  ✗ zone 2.168.192.in-addr.arpa/IN: НЕ НАЙДЕНА или неверный serial"
fi

if [ $checkconf_exit -eq 0 ]; then
    log_and_echo ""
    log_and_echo "✓ named-checkconf завершился успешно"
else
    log_and_echo ""
    log_and_echo "✗ named-checkconf обнаружил ошибки (код: $checkconf_exit)"
fi
log_and_echo ""

# --- 7.8 Проверка DNS-разрешения через host ---
log_and_echo "═══ 7.8 Проверка DNS-разрешения (команда host) ═══"
log_and_echo "DNS-сервер: 127.0.0.1"
log_and_echo ""

log_and_echo "--- Прямые записи (A) ---"
check_dns_record "hq-srv.au-team.irpo" "192.168.1.10" "A"
check_dns_record "hq-rtr.au-team.irpo" "192.168.1.1" "A"
check_dns_record "hq-cli.au-team.irpo" "192.168.2.10" "A"
check_dns_record "br-rtr.au-team.irpo" "192.168.3.1" "A"
check_dns_record "br-srv.au-team.irpo" "192.168.3.10" "A"
check_dns_record "docker.au-team.irpo" "172.16.1.1" "A"
check_dns_record "web.au-team.irpo" "172.16.2.1" "A"

log_and_echo ""
log_and_echo "--- Обратные записи (PTR) ---"
check_dns_record "192.168.1.10" "hq-srv.au-team.irpo" "PTR"
check_dns_record "192.168.1.1" "hq-rtr.au-team.irpo" "PTR"
check_dns_record "192.168.2.10" "hq-cli.au-team.irpo" "PTR"

log_and_echo ""

# ==================== КРИТЕРИЙ 9: SSH-ПОДКЛЮЧЕНИЕ ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 9: Проверка SSH-подключения к BR-SRV                │"
log_and_echo "│ Описание: Подключение к sshuser@192.168.3.10 порт 2026       │"
log_and_echo "│           Аутентификация по ключу без пароля                 │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

log_and_echo "Подготовка: Проверка доступа в интернет..."
if check_internet; then
    log_and_echo "✓ Интернет доступен"
    
    if ! command -v sshpass > /dev/null 2>&1; then
        install_sshpass
    else
        log_and_echo "✓ sshpass уже установлен"
    fi
    
    if command -v sshpass > /dev/null 2>&1; then
        setup_ssh
    fi
else
    log_and_echo "✗ Интернет недоступен, пропускаем настройку SSH-ключей"
fi

log_and_echo ""
log_and_echo "Тестирование SSH-подключения..."
log_and_echo "Команда: ssh sshuser@$SSH_TARGET -p $SSH_PORT"

if [ -f ~/.ssh/id_rsa ]; then
    timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no \
        sshuser@$SSH_TARGET -p $SSH_PORT exit 2>> "$LOG_FILE"
    ssh_code=$?
else
    if command -v sshpass > /dev/null 2>&1; then
        timeout 10 sshpass -p "$SSH_PASSWORD" ssh -o ConnectTimeout=5 \
            -o StrictHostKeyChecking=no sshuser@$SSH_TARGET -p $SSH_PORT exit 2>> "$LOG_FILE"
        ssh_code=$?
    else
        timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes \
            -o StrictHostKeyChecking=no sshuser@$SSH_TARGET -p $SSH_PORT exit 2>> "$LOG_FILE"
        ssh_code=$?
    fi
fi

if [ $ssh_code -eq 0 ]; then
    log_and_echo "✓ SSH-подключение УСПЕШНО"
elif [ $ssh_code -eq 124 ]; then
    log_and_echo "⚠ SSH-подключение: таймаут"
else
    log_and_echo "✗ SSH-подключение НЕ УДАЛОСЬ (код: $ssh_code)"
fi

# ==================== ИТОГИ ====================
log_and_echo ""
log_and_echo "╔══════════════════════════════════════════════════════════════╗"
log_and_echo "║                    ПРОВЕРКА ЗАВЕРШЕНА                        ║"
log_and_echo "║         Результаты сохранены в: $LOG_FILE                    ║"
log_and_echo "╚══════════════════════════════════════════════════════════════╝"

echo ""
echo "=== СВОДКА РЕЗУЛЬТАТОВ ==="
echo ""
echo "Успешные проверки:"
grep -c "✓" "$LOG_FILE" | xargs -I {} echo "  {} проверок пройдено"
echo ""
echo "Неуспешные проверки:"
grep -c "✗" "$LOG_FILE" | xargs -I {} echo "  {} проверок не пройдено"
echo ""
echo "Для просмотра полных результатов: cat $LOG_FILE"
