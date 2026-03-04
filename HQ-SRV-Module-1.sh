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
check_config_exists() {
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
    result=$(host "$query" 192.168.1.10 2>/dev/null)
    
    if echo "$result" | grep -q "$expected"; then
        log_and_echo "  ✓ $query → $expected"
        return 0
    else
        log_and_echo "  ✗ $query: ожидалось '$expected'"
        log_and_echo "    Получено: $result"
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
execute_check "Имя хоста hq-srv.au-team.irpo" "hostnamectl | grep -i hq-srv"

# ==================== КРИТЕРИЙ 5: ЛОКАЛЬНЫЕ ПОЛЬЗОВАТЕЛИ ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 5: Проверка локальных учётных записей               │"
log_and_echo "│ Описание: Пользователь sshuser должен существовать           │"
log_and_echo "│           и состоять в группе wheel (права sudo)             │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

log_and_echo "Проверка: Существование пользователя sshuser"
if id sshuser &>/dev/null; then
    log_and_echo "✓ Пользователь sshuser существует"
    
    log_and_echo "Команда: id sshuser"
    id sshuser | tee -a "$LOG_FILE"
    log_and_echo ""
    
    log_and_echo "Проверка: Членство в группе wheel (права администратора)"
    log_and_echo "Команда: groups sshuser | grep wheel"
    
    if groups sshuser | grep -q "\bwheel\b"; then
        log_and_echo "✓ Пользователь sshuser состоит в группе wheel"
    else
        log_and_echo "✗ Пользователь sshuser НЕ состоит в группе wheel"
        log_and_echo "  Текущие группы: $(groups sshuser)"
    fi
else
    log_and_echo "✗ Пользователь sshuser НЕ существует"
fi
log_and_echo ""

# ==================== КРИТЕРИЙ 6: СЕТЕВАЯ СВЯЗНОСТЬ ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 6: Проверка сетевой связности и выхода в интернет   │"
log_and_echo "│ Описание: Проверяем доступность Google DNS (8.8.8.8)         │"
log_and_echo "│           для подтверждения выхода в интернет                │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

execute_check "Ping до Google DNS (8.8.8.8)" "ping -c 4 8.8.8.8"

# ==================== КРИТЕРИЙ 7: DNS-СЕРВЕР BIND ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 7: Проверка DNS-сервера BIND                        │"
log_and_echo "│ Описание: Проверяем конфигурацию и работу DNS-сервера        │"
log_and_echo "│           - Файлы конфигурации BIND                          │"
log_and_echo "│           - Зоны прямого и обратного просмотра               │"
log_and_echo "│           - Разрешение DNS-имён                              │"
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
    
    check_config_exists "$RFC1912_CONF" 'zone "au-team.irpo"' "Зона au-team.irpo объявлена"
    check_config_exists "$RFC1912_CONF" 'zone "1.168.192.in-addr.arpa"' "Зона обратного просмотра 1.168.192 объявлена"
    check_config_exists "$RFC1912_CONF" 'zone "2.168.192.in-addr.arpa"' "Зона обратного просмотра 2.168.192 объявлена"
    check_config_exists "$RFC1912_CONF" 'type master' "Тип зоны: master"
    check_config_exists "$RFC1912_CONF" 'file "au-team.irpo"' "Файл зоны au-team.irpo указан"
else
    log_and_echo "✗ Файл $RFC1912_CONF не найден"
fi
log_and_echo ""

# --- 7.4 Проверка файла прямой зоны ---
log_and_echo "═══ 7.4 Проверка файла прямой зоны au-team.irpo ═══"
log_and_echo "Файл: $ZONE_FORWARD"

if [ -f "$ZONE_FORWARD" ]; then
    log_and_echo "✓ Файл существует"
    
    check_config_exists "$ZONE_FORWARD" 'SOA.*au-team.irpo' "SOA запись настроена"
    check_config_exists "$ZONE_FORWARD" 'NS.*hq-srv.au-team.irpo' "NS запись указывает на hq-srv"
    check_config_exists "$ZONE_FORWARD" 'hq-srv.*IN.*A.*192.168.1.10' "A запись hq-srv → 192.168.1.10"
    check_config_exists "$ZONE_FORWARD" 'hq-rtr.*IN.*A.*192.168.1.1' "A запись hq-rtr → 192.168.1.1"
    check_config_exists "$ZONE_FORWARD" 'hq-cli.*IN.*A.*192.168.2.10' "A запись hq-cli → 192.168.2.10"
    check_config_exists "$ZONE_FORWARD" 'br-rtr.*IN.*A.*192.168.3.1' "A запись br-rtr → 192.168.3.1"
    check_config_exists "$ZONE_FORWARD" 'br-srv.*IN.*A.*192.168.3.10' "A запись br-srv → 192.168.3.10"
    check_config_exists "$ZONE_FORWARD" 'docker.*IN.*A.*172.16.1.1' "A запись docker → 172.16.1.1"
    check_config_exists "$ZONE_FORWARD" 'web.*IN.*A.*172.16.2.1' "A запись web → 172.16.2.1"
else
    log_and_echo "✗ Файл $ZONE_FORWARD не найден"
fi
log_and_echo ""

# --- 7.5 Проверка файла обратной зоны 1.168.192 ---
log_and_echo "═══ 7.5 Проверка файла обратной зоны 1.168.192.in-addr.arpa ═══"
log_and_echo "Файл: $ZONE_REVERSE1"

if [ -f "$ZONE_REVERSE1" ]; then
    log_and_echo "✓ Файл существует"
    
    check_config_exists "$ZONE_REVERSE1" 'SOA.*au-team.irpo' "SOA запись настроена"
    check_config_exists "$ZONE_REVERSE1" 'NS.*hq-srv.au-team.irpo' "NS запись указывает на hq-srv"
    check_config_exists "$ZONE_REVERSE1" '1.*IN.*PTR.*hq-rtr.au-team.irpo' "PTR запись 1 → hq-rtr"
    check_config_exists "$ZONE_REVERSE1" '10.*IN.*PTR.*hq-srv.au-team.irpo' "PTR запись 10 → hq-srv"
else
    log_and_echo "✗ Файл $ZONE_REVERSE1 не найден"
fi
log_and_echo ""

# --- 7.6 Проверка файла обратной зоны 2.168.192 ---
log_and_echo "═══ 7.6 Проверка файла обратной зоны 2.168.192.in-addr.arpa ═══"
log_and_echo "Файл: $ZONE_REVERSE2"

if [ -f "$ZONE_REVERSE2" ]; then
    log_and_echo "✓ Файл существует"
    
    check_config_exists "$ZONE_REVERSE2" 'SOA.*au-team.irpo' "SOA запись настроена"
    check_config_exists "$ZONE_REVERSE2" 'NS.*hq-srv.au-team.irpo' "NS запись указывает на hq-srv"
    check_config_exists "$ZONE_REVERSE2" '10.*IN.*PTR.*hq-cli.au-team.irpo' "PTR запись 10 → hq-cli"
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
log_and_echo "DNS-сервер: 192.168.1.10"
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

log_and_echo "Подготовка: Проверка доступности интернета для установки sshpass..."

if ping -c 2 8.8.8.8 &> /dev/null; then
    log_and_echo "✓ Интернет доступен"
    
    if ! command -v sshpass &> /dev/null; then
        log_and_echo "Установка sshpass..."
        apt-get update -qq && apt-get install sshpass -y -qq
    else
        log_and_echo "✓ sshpass уже установлен"
    fi
    
    if command -v sshpass &> /dev/null; then
        log_and_echo ""
        log_and_echo "═══ Настройка SSH-ключей ═══"
        
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        
        log_and_echo "Добавление SSH хоста в known_hosts..."
        ssh-keyscan -p $SSH_PORT -H $SSH_TARGET >> ~/.ssh/known_hosts 2>/dev/null
        log_and_echo "✓ Хост добавлен в known_hosts"

        if ! [ -f ~/.ssh/id_rsa.pub ]; then
            log_and_echo "Создание RSA ключа..."
            ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa -q
            log_and_echo "✓ RSA ключ создан"
        else
            log_and_echo "✓ RSA ключ уже существует"
        fi
        
        log_and_echo "Копирование SSH ключа на BR-SRV..."
        sshpass -p "$SSH_PASSWORD" ssh-copy-id -p $SSH_PORT sshuser@$SSH_TARGET 2>/dev/null
        if [ $? -eq 0 ]; then
            log_and_echo "✓ SSH ключ скопирован"
        else
            log_and_echo "⚠ Не удалось скопировать ключ (возможно уже существует)"
        fi
    else
        log_and_echo "✗ Не удалось установить sshpass, пропускаем настройку SSH ключей"
    fi
else
    log_and_echo "✗ Интернет недоступен, пропускаем установку sshpass"
fi

log_and_echo ""
log_and_echo "═══ Тестирование SSH-подключения ═══"
log_and_echo "Команда: ssh sshuser@$SSH_TARGET -p $SSH_PORT"
log_and_echo "Выполняется тестовое SSH подключение (timeout 10s)..."

if timeout 10s ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no \
    -p $SSH_PORT sshuser@$SSH_TARGET "echo 'SSH подключение успешно'" 2>> "$LOG_FILE"; then
    log_and_echo "✓ SSH подключение УСПЕШНО"
else
    ssh_exit_code=$?
    if [ $ssh_exit_code -eq 124 ]; then
        log_and_echo "⚠ SSH подключение: таймаут"
    else
        log_and_echo "✗ SSH подключение НЕ УДАЛОСЬ (код: $ssh_exit_code)"
    fi
fi
log_and_echo ""

# ==================== ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ ДОПОЛНИТЕЛЬНО: Информация о сетевых интерфейсах              │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

log_and_echo "Команда: ip -br a"
ip -br a | tee -a "$LOG_FILE"
log_and_echo ""

# ==================== ИТОГИ ====================
log_and_echo ""
log_and_echo "╔══════════════════════════════════════════════════════════════╗"
log_and_echo "║                    ПРОВЕРКА ЗАВЕРШЕНА                        ║"
log_and_echo "║         Результаты сохранены в: $LOG_FILE            ║"
log_and_echo "╚══════════════════════════════════════════════════════════════╝"

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                    СВОДКА РЕЗУЛЬТАТОВ                        │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# Подсчёт результатов
success_count=$(grep -c "✓" "$LOG_FILE")
fail_count=$(grep -c "✗" "$LOG_FILE")

echo "  ✓ Успешных проверок:    $success_count"
echo "  ✗ Неуспешных проверок:  $fail_count"
echo ""

echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                  СТАТУС ПО КРИТЕРИЯМ                         │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "  Критерий 1 (IP-адрес):      $(ip a | grep -q '192.168.1.10/27' && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 2 (Hostname/Time): $(hostnamectl | grep -qi 'hq-srv' && timedatectl | grep -q 'Asia/Yekaterinburg' && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 5 (sshuser):       $(id sshuser &>/dev/null && groups sshuser | grep -q wheel && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 6 (Интернет):      $(ping -c 1 8.8.8.8 &>/dev/null && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 7 (DNS BIND):      $(systemctl is-active bind &>/dev/null && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 9 (SSH к BR-SRV):  $(timeout 5s ssh -o ConnectTimeout=3 -o BatchMode=yes -p $SSH_PORT sshuser@$SSH_TARGET exit &>/dev/null && echo '✓ OK' || echo '✗ FAIL')"
echo ""

echo "Для просмотра полных результатов: cat $LOG_FILE"
