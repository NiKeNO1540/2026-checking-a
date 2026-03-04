#!/bin/bash

# Файл для записи результатов
LOG_FILE="/var/log/system_check.log"

# Путь к конфигурационному файлу FRR
FRR_CONF="/etc/frr/frr.conf"

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

# Функция проверки пользователя в группе
check_user_in_group() {
    local username="$1"
    local groupname="$2"
    
    if id "$username" &>/dev/null; then
        if groups "$username" | grep -q "\b$groupname\b"; then
            return 0
        fi
    fi
    return 1
}

# ============================================================================
# НАЧАЛО ПРОВЕРКИ
# ============================================================================

clear
log_and_echo "╔══════════════════════════════════════════════════════════════╗"
log_and_echo "║         ПРОВЕРКА КОНФИГУРАЦИИ МАРШРУТИЗАТОРА HQ-RTR          ║"
log_and_echo "║         Дата: $(date '+%Y-%m-%d %H:%M:%S')                         ║"
log_and_echo "╚══════════════════════════════════════════════════════════════╝"
log_and_echo ""

# ==================== КРИТЕРИЙ 1: IP-АДРЕСАЦИЯ (WAN) ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 1: Проверка IP-адресации (WAN-интерфейс)            │"
log_and_echo "│ Описание: IP-адрес WAN должен быть 172.16.1.10/28            │"
log_and_echo "│           Это адрес для связи с ISP                          │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

execute_check "IP-адрес WAN 172.16.1.10/28" "ip a | grep 172.16.1.10/28"

# ==================== КРИТЕРИЙ 2: HOSTNAME И ВРЕМЕННАЯ ЗОНА ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 2: Проверка имени хоста и временной зоны            │"
log_and_echo "│ Описание: Hostname должен содержать 'hq-rtr'                 │"
log_and_echo "│           Временная зона = Asia/Yekaterinburg                │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

execute_check "Временная зона Asia/Yekaterinburg" "timedatectl | grep Asia/Yekaterinburg"
execute_check "Имя хоста содержит 'hq-rtr'" "hostnamectl | grep -i hq-rtr"

# ==================== КРИТЕРИЙ 3: ДИНАМИЧЕСКАЯ МАРШРУТИЗАЦИЯ (OSPF) ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 3: Проверка динамической маршрутизации (OSPF/FRR)   │"
log_and_echo "│ Описание: Служба FRR должна быть запущена                    │"
log_and_echo "│           Конфигурация OSPF должна содержать:                │"
log_and_echo "│           - Настройки интерфейса gre1 с MD5-аутентификацией  │"
log_and_echo "│           - Сети 192.168.1.0/27, 192.168.2.0/28, 192.168.5.0/30│"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

# Проверка статуса службы FRR
execute_check "Статус службы FRR" "systemctl is-active frr"

# Проверка конфигурации FRR
log_and_echo "═══ Проверка конфигурации $FRR_CONF ═══"

if [ -f "$FRR_CONF" ]; then
    log_and_echo "✓ Файл конфигурации существует"
    log_and_echo ""
    
    log_and_echo "--- Настройки интерфейса GRE1 ---"
    check_config_exists "$FRR_CONF" "interface gre1" "Интерфейс gre1 объявлен"
    check_config_exists "$FRR_CONF" "ip ospf authentication message-digest" "OSPF MD5-аутентификация включена"
    check_config_exists "$FRR_CONF" "ip ospf message-digest-key 1 md5 P@ssw0rd" "MD5-ключ настроен (P@ssw0rd)"
    check_config_exists "$FRR_CONF" "no ip ospf passive" "Интерфейс не пассивный"
    
    log_and_echo ""
    log_and_echo "--- Настройки OSPF Router ---"
    check_config_exists "$FRR_CONF" "router ospf" "Процесс OSPF запущен"
    check_config_exists "$FRR_CONF" "network 192.168.1.0/27 area 0" "Сеть 192.168.1.0/27 в area 0 (HQ-SRV)"
    check_config_exists "$FRR_CONF" "network 192.168.2.0/28 area 0" "Сеть 192.168.2.0/28 в area 0 (HQ-CLI)"
    check_config_exists "$FRR_CONF" "network 192.168.5.0/30 area 0" "Сеть 192.168.5.0/30 в area 0 (GRE-туннель)"
else
    log_and_echo "✗ Файл $FRR_CONF не найден"
fi
log_and_echo ""

# ==================== КРИТЕРИЙ 4: DHCP-СЕРВЕР ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 4: Проверка DHCP-сервера                            │"
log_and_echo "│ Описание: Служба dhcpd должна быть запущена для              │"
log_and_echo "│           автоматической выдачи IP-адресов клиентам          │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

execute_check "Статус службы DHCP (dhcpd)" "systemctl is-active dhcpd"

# Дополнительная проверка - альтернативные имена службы
if ! systemctl is-active dhcpd &>/dev/null; then
    log_and_echo "Проверка альтернативных имён службы DHCP..."
    execute_check "Статус службы isc-dhcp-server" "systemctl is-active isc-dhcp-server"
fi

# ==================== КРИТЕРИЙ 5: ЛОКАЛЬНЫЕ ПОЛЬЗОВАТЕЛИ ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 5: Проверка локальных учётных записей               │"
log_and_echo "│ Описание: Пользователь net_admin должен существовать         │"
log_and_echo "│           и состоять в группе wheel (права sudo)             │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

# Проверка существования пользователя
log_and_echo "Проверка: Существование пользователя net_admin"
if id net_admin &>/dev/null; then
    log_and_echo "✓ Пользователь net_admin существует"
    
    # Вывод информации о пользователе
    log_and_echo "Команда: id net_admin"
    id net_admin | tee -a "$LOG_FILE"
    log_and_echo ""
    
    # Проверка членства в группе wheel
    log_and_echo "Проверка: Членство в группе wheel (права администратора)"
    log_and_echo "Команда: groups net_admin | grep wheel"
    
    if groups net_admin | grep -q "\bwheel\b"; then
        log_and_echo "✓ Пользователь net_admin состоит в группе wheel"
    else
        log_and_echo "✗ Пользователь net_admin НЕ состоит в группе wheel"
        log_and_echo "  Текущие группы: $(groups net_admin)"
    fi
else
    log_and_echo "✗ Пользователь net_admin НЕ существует"
fi
log_and_echo ""

# ==================== КРИТЕРИЙ 6: СЕТЕВАЯ СВЯЗНОСТЬ ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 6: Проверка сетевой связности и выхода в интернет   │"
log_and_echo "│ Описание: Проверяем доступность Google DNS (8.8.8.8)         │"
log_and_echo "│           для подтверждения выхода в интернет                │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

execute_check "Ping до Google DNS (8.8.8.8)" "ping -c 4 8.8.8.8"

# ==================== КРИТЕРИЙ 8: GRE-ТУННЕЛЬ ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 8: Проверка GRE-туннеля между HQ и BR               │"
log_and_echo "│ Описание: Проверяем связность с BR-RTR через туннель         │"
log_and_echo "│           IP-адрес удалённой стороны: 192.168.5.2            │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

# Проверка наличия интерфейса gre1
log_and_echo "Проверка: Наличие интерфейса gre1"
log_and_echo "Команда: ip a show gre1"

if ip a show gre1 &>/dev/null; then
    ip a show gre1 | tee -a "$LOG_FILE"
    log_and_echo "✓ Интерфейс gre1 существует"
else
    log_and_echo "✗ Интерфейс gre1 не найден"
fi
log_and_echo ""

# Проверка связности через туннель
execute_check "Ping до BR-RTR через туннель (192.168.5.2)" "ping -c 4 192.168.5.2"

# ==================== КРИТЕРИЙ 10: ПОДИНТЕРФЕЙСЫ (VLAN) ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 10: Проверка подинтерфейсов (VLAN)                  │"
log_and_echo "│ Описание: Должны быть настроены 3 подинтерфейса:             │"
log_and_echo "│           - 192.168.1.1/27  (VLAN для HQ-SRV)                │"
log_and_echo "│           - 192.168.2.1/28  (VLAN для HQ-CLI)                │"
log_and_echo "│           - 192.168.99.1/29 (VLAN управления/Management)     │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

log_and_echo "═══ Проверка наличия IP-адресов подинтерфейсов ═══"
log_and_echo ""

# Подинтерфейс 1: Сеть HQ-SRV
log_and_echo "--- Подинтерфейс 1: Сеть HQ-SRV ---"
execute_check "IP-адрес 192.168.1.1/27" "ip a | grep 192.168.1.1/27"

# Подинтерфейс 2: Сеть HQ-CLI
log_and_echo "--- Подинтерфейс 2: Сеть HQ-CLI ---"
execute_check "IP-адрес 192.168.2.1/28" "ip a | grep 192.168.2.1/28"

# Подинтерфейс 3: Сеть управления
log_and_echo "--- Подинтерфейс 3: Сеть управления (Management) ---"
execute_check "IP-адрес 192.168.99.1/29" "ip a | grep 192.168.99.1/29"

# Вывод всех сетевых интерфейсов для справки
log_and_echo "═══ Полный список сетевых интерфейсов ═══"
log_and_echo "Команда: ip -br a"
ip -br a | tee -a "$LOG_FILE"
log_and_echo ""

# ==================== ИТОГИ ====================
log_and_echo ""
log_and_echo "╔══════════════════════════════════════════════════════════════╗"
log_and_echo "║                    ПРОВЕРКА ЗАВЕРШЕНА                        ║"
log_and_echo "║         Результаты сохранены в: $LOG_FILE                    ║"
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

# Вывод критериев
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                  СТАТУС ПО КРИТЕРИЯМ                         │"
echo "└──────────────────────────────────────────────────────────────┘"

echo ""
echo "  Критерий 1 (IP WAN):        $(ip a | grep -q '172.16.1.10/28' && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 2 (Hostname/Time): $(hostnamectl | grep -qi 'hq-rtr' && timedatectl | grep -q 'Asia/Yekaterinburg' && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 3 (OSPF/FRR):      $(systemctl is-active frr &>/dev/null && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 4 (DHCP):          $(systemctl is-active dhcpd &>/dev/null && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 5 (net_admin):     $(id net_admin &>/dev/null && groups net_admin | grep -q wheel && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 6 (Интернет):      $(ping -c 1 8.8.8.8 &>/dev/null && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 8 (GRE-туннель):   $(ping -c 1 192.168.5.2 &>/dev/null && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 10 (VLAN):         $(ip a | grep -q '192.168.1.1/27' && ip a | grep -q '192.168.2.1/28' && ip a | grep -q '192.168.99.1/29' && echo '✓ OK' || echo '✗ FAIL')"
echo ""

echo "Для просмотра полных результатов: cat $LOG_FILE"
