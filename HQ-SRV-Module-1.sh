#!/bin/bash

# Файл для записи результатов
LOG_FILE="system_check_results.txt"
CONFIG_FILE="/etc/dnsmasq.conf"
EXPECTED_CONFIG=(
    "domain=au-team.irpo"
    "server=8.8.8.8"
    "\<hq-rtr.au-team.irpo"
    "\<168.192.in-addr.arpa,hq-rtr.au-team.irpo"
    "\<web.au-team.irpo"
    "\<docker.au-team.irpo"
    "\<br-rtr.au-team.irpo"
    "\<hq-srv.au-team.irpo"
    "\<168.192.in-addr.arpa,hq-srv.au-team.irpo"
    "\<hq-cli.au-team.irpo"
    "\<168.192.in-addr.arpa,hq-cli.au-team.irpo"
    "\<br-srv.au-team.irpo"
)
SSH_PASSWORD="P@ssw0rd"

# Функция для логирования и вывода
log_and_echo() {
    echo "$1"
    echo "$1" >> "$LOG_FILE"
}

# Функция проверки доступа в интернет
check_internet_access() {
    log_and_echo "Проверка доступа в интернет..."
    ping -c 2 -W 3 8.8.8.8 > /dev/null 2>&1
    return $?
}

# Функция установки sshpass
install_sshpass() {
    log_and_echo "Установка sshpass..."
    
    # Определяем пакетный менеджер
    if ! command -v sshpass > /dev/null 2>&1; then
        apt-get install sshpass -y
    fi
    
    if command -v sshpass > /dev/null 2>&1; then
        log_and_echo "✓ sshpass успешно установлен"
        return 0
    else
        log_and_echo "✗ Ошибка установки sshpass"
        return 1
    fi
}

# Функция настройки SSH подключения
setup_ssh_connection() {
    log_and_echo "Настройка SSH подключения..."
    
    # Сканирование SSH ключа хоста
    log_and_echo "Создание SSH ключа + добавление хоста в known_hosts..."
    ssh-keyscan -p 2026 -H 192.168.3.10 >> ~/.ssh/known_hosts 2>> "$LOG_FILE"
    if ! [ -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa -q
    else
    log_and_echo "Ключ уже есть."
    fi
    if [ $? -eq 0 ]; then
        log_and_echo "✓ SSH ключ хоста добавлен в known_hosts"
    else
        log_and_echo "✗ Ошибка добавления SSH ключа хоста"
    fi
    
    # Копирование SSH ключа
    log_and_echo "Копирование SSH ключа на удаленный хост..."
    sshpass -p "$SSH_PASSWORD" ssh-copy-id -p 2026 sshuser@192.168.3.10 >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        log_and_echo "✓ SSH ключ успешно скопирован на удаленный хост"
        return 0
    else
        log_and_echo "✗ Ошибка копирования SSH ключа"
        return 1
    fi
}

# Очистка старого лог-файла
> "$LOG_FILE"

log_and_echo "=== Начало проверки системы ==="
log_and_echo "Время проверки: $(date)"
log_and_echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 1"
log_and_echo "Проверка IP адреса:"
ip a | grep 192.168.1.10/27 >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ IP адрес 192.168.1.10/27 настроен"
else
    log_and_echo "✗ IP адрес 192.168.1.10/27 НЕ настроен"
fi
log_and_echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 2"
log_and_echo "Проверка временной зоны:"
timedatectl | grep "Asia/Yekaterinburg" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ Временная зона Asia/Yekaterinburg установлена"
else
    log_and_echo "✗ Временная зона Asia/Yekaterinburg НЕ установлена"
fi
log_and_echo ""

# Проверка hostname
log_and_echo "Проверка hostname:"
hostnamectl | grep "hq-srv.au-team.irpo" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ Hostname hq-srv.au-team.irpo установлен"
else
    log_and_echo "✗ Hostname hq-srv.au-team.irpo НЕ установлен"
fi
log_and_echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 5"
log_and_echo "Проверка пользователей"
cat /etc/passwd | grep home >> "$LOG_FILE" 2>&1
log_and_echo "✓ Список пользователей с домашними директориями записан в лог"
log_and_echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 6"
log_and_echo "Проверка доступности сетевых узлов:"

ping_hosts=(
    "192.168.1.1"
    "192.168.2.10" 
    "172.16.1.1"
    "192.168.3.10"
    "8.8.8.8"
    "br-srv.au-team.irpo"
)

for host in "${ping_hosts[@]}"; do
    log_and_echo "Пинг $host:"
    ping -c 2 "$host" >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        log_and_echo "✓ $host - доступен"
    else
        log_and_echo "✗ $host - НЕ доступен"
    fi
done
log_and_echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 7"
log_and_echo "Проверка DNS разрешения имен:"
ping -c 2 ya.ru >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ DNS разрешение имен работает (ya.ru доступен)"
else
    log_and_echo "✗ DNS разрешение имен НЕ работает"
fi
log_and_echo ""

# Проверка службы dnsmasq
log_and_echo "Проверка службы dnsmasq:"
systemctl status dnsmasq | grep -q "Active: active" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ Служба dnsmasq активна"
else
    log_and_echo "✗ Служба dnsmasq НЕ активна"
fi
log_and_echo ""

# Проверка конфигурации dnsmasq.conf
log_and_echo "8. Проверка конфигурации $CONFIG_FILE:"

if [ -f "$CONFIG_FILE" ]; then
    log_and_echo "✓ Файл конфигурации существует"
    
    missing_configs=0
    for config_line in "${EXPECTED_CONFIG[@]}"; do
        if grep -q "$config_line" "$CONFIG_FILE"; then
            log_and_echo "✓ Найдена строка: $config_line"
        else
            log_and_echo "✗ Отсутствует строка: $config_line"
            ((missing_configs++))
        fi
    done
    
    if [ $missing_configs -eq 0 ]; then
        log_and_echo "✓ Все необходимые конфигурационные строки присутствуют"
    else
        log_and_echo "✗ Отсутствует $missing_configs конфигурационных строк"
    fi
else
    log_and_echo "✗ Файл конфигурации $CONFIG_FILE не существует"
fi
log_and_echo ""

# Проверка доступа в интернет и установка sshpass
log_and_echo "Проверка доступа в интернет и настройка SSH:"
if check_internet_access; then
    log_and_echo "✓ Доступ в интернет есть"
    
    # Проверяем, установлен ли уже sshpass
    if ! command -v sshpass > /dev/null 2>&1; then
        install_sshpass
    else
        log_and_echo "✓ sshpass уже установлен"
    fi
    
    # Настраиваем SSH подключение если sshpass доступен
    if command -v sshpass > /dev/null 2>&1; then
        # Создаем .ssh директорию если не существует
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        
        setup_ssh_connection
    else
        log_and_echo "✗ sshpass недоступен, пропускаем настройку SSH ключей"
    fi
else
    log_and_echo "✗ Доступ в интернет отсутствует, пропускаем установку sshpass"
fi
log_and_echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 9"
log_and_echo "Проверка SSH подключения:"
log_and_echo "Попытка подключения к sshuser@192.168.3.10:2026..."

# Проверяем, был ли настроен SSH ключ
if [ -f ~/.ssh/id_rsa ] || [ -f ~/.ssh/id_ed25519 ]; then
    # Пробуем подключение без пароля (по ключу)
    timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no sshuser@192.168.3.10 -p 2026 exit >> "$LOG_FILE" 2>&1
    ssh_exit_code=$?
else
    # Пробуем подключение с паролем (если sshpass установлен)
    if command -v sshpass > /dev/null 2>&1; then
        timeout 10 sshpass -p "$SSH_PASSWORD" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no sshuser@192.168.3.10 -p 2026 exit >> "$LOG_FILE" 2>&1
        ssh_exit_code=$?
    else
        # Простая проверка без аутентификации
        timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no sshuser@192.168.3.10 -p 2026 exit >> "$LOG_FILE" 2>&1
        ssh_exit_code=$?
    fi
fi

if [ $ssh_exit_code -eq 0 ]; then
    log_and_echo "✓ SSH подключение успешно"
elif [ $ssh_exit_code -eq 124 ]; then
    log_and_echo "⚠ SSH подключение требует аутентификации (таймаут)"
else
    log_and_echo "✗ SSH подключение НЕ удалось (код ошибки: $ssh_exit_code)"
fi

log_and_echo ""
log_and_echo "=== Проверка завершена ==="
log_and_echo "Подробные результаты сохранены в файл: $LOG_FILE"

# Вывод итоговой информации
echo ""
echo "=== Краткие результаты проверки ==="
tail -n 60 "$LOG_FILE" | grep -E "^(✓|✗|⚠|===|Проверка|Настройка)"
