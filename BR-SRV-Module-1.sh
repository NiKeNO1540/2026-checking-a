#!/bin/bash

# Файл для записи результатов
LOG_FILE="/var/log/system_check.log"

SSH_PASSWORD="P@ssw0rd"
SSH_PORT="2026"
SSH_TARGET="192.168.1.10"

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

# ============================================================================
# НАЧАЛО ПРОВЕРКИ
# ============================================================================

clear
log_and_echo "╔══════════════════════════════════════════════════════════════╗"
log_and_echo "║         ПРОВЕРКА КОНФИГУРАЦИИ СЕРВЕРА BR-SRV                 ║"
log_and_echo "║         Дата: $(date '+%Y-%m-%d %H:%M:%S')                           ║"
log_and_echo "╚══════════════════════════════════════════════════════════════╝"
log_and_echo ""

# ==================== КРИТЕРИЙ 1: IP-АДРЕСАЦИЯ ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 1: Проверка IP-адресации                            │"
log_and_echo "│ Описание: IP-адрес должен быть 192.168.3.10/28               │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

execute_check "IP-адрес 192.168.3.10/28" "ip a | grep 192.168.3.10/28"

# ==================== КРИТЕРИЙ 2: HOSTNAME И ВРЕМЕННАЯ ЗОНА ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 2: Проверка имени хоста и временной зоны            │"
log_and_echo "│ Описание: Hostname = br-srv.au-team.irpo                     │"
log_and_echo "│           Временная зона = Asia/Yekaterinburg                │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

execute_check "Временная зона Asia/Yekaterinburg" "timedatectl | grep Asia/Yekaterinburg"
execute_check "Имя хоста br-srv.au-team.irpo" "hostnamectl | grep -i br-srv"

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

# ==================== КРИТЕРИЙ 9: SSH-ПОДКЛЮЧЕНИЕ ====================
log_and_echo "┌──────────────────────────────────────────────────────────────┐"
log_and_echo "│ КРИТЕРИЙ 9: Проверка SSH-подключения к HQ-SRV                │"
log_and_echo "│ Описание: Подключение к sshuser@192.168.1.10 порт 2026       │"
log_and_echo "│           Аутентификация по ключу без пароля                 │"
log_and_echo "└──────────────────────────────────────────────────────────────┘"

# Проверка доступности интернета для установки sshpass
log_and_echo "Подготовка: Проверка доступности интернета для установки sshpass..."

if ping -c 2 8.8.8.8 &> /dev/null; then
    log_and_echo "✓ Интернет доступен"
    
    # Проверяем установлен ли sshpass
    if ! command -v sshpass &> /dev/null; then
        log_and_echo "Установка sshpass..."
        apt-get update -qq && apt-get install sshpass -y -qq
    else
        log_and_echo "✓ sshpass уже установлен"
    fi
    
    # Проверяем успешность установки sshpass
    if command -v sshpass &> /dev/null; then
        log_and_echo ""
        log_and_echo "═══ Настройка SSH-ключей ═══"
        
        # Создаём директорию .ssh
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        
        # Добавляем хост в known_hosts
        log_and_echo "Добавление SSH хоста в known_hosts..."
        ssh-keyscan -p $SSH_PORT -H $SSH_TARGET >> ~/.ssh/known_hosts 2>/dev/null
        log_and_echo "✓ Хост добавлен в known_hosts"

        # Создание ключа если не существует
        if ! [ -f ~/.ssh/id_rsa.pub ]; then
            log_and_echo "Создание RSA ключа..."
            ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa -q
            log_and_echo "✓ RSA ключ создан"
        else
            log_and_echo "✓ RSA ключ уже существует"
        fi
        
        # Копируем SSH ключ
        log_and_echo "Копирование SSH ключа на HQ-SRV..."
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

# Тестовое SSH подключение с таймаутом
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

echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                  СТАТУС ПО КРИТЕРИЯМ                         │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "  Критерий 1 (IP-адрес):      $(ip a | grep -q '192.168.3.10/28' && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 2 (Hostname/Time): $(hostnamectl | grep -qi 'br-srv' && timedatectl | grep -q 'Asia/Yekaterinburg' && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 5 (sshuser):       $(id sshuser &>/dev/null && groups sshuser | grep -q wheel && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 6 (Интернет):      $(ping -c 1 8.8.8.8 &>/dev/null && echo '✓ OK' || echo '✗ FAIL')"
echo "  Критерий 9 (SSH к HQ-SRV):  $(timeout 5s ssh -o ConnectTimeout=3 -o BatchMode=yes -p $SSH_PORT sshuser@$SSH_TARGET exit &>/dev/null && echo '✓ OK' || echo '✗ FAIL')"
echo ""

echo "Для просмотра полных результатов: cat $LOG_FILE"
