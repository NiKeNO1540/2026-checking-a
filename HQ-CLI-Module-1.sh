#!/bin/bash

# Файл для записи результатов
LOG_FILE="/var/log/system_check_results.txt"

# Очистка файла перед началом проверки
> "$LOG_FILE"

# Функция для записи и вывода результатов
log_and_echo() {
    echo "$1"
    echo "$1" >> "$LOG_FILE"
}

# Функция для выполнения команды и записи результата
execute_check() {
    local description="$1"
    local command="$2"
    
    log_and_echo "=========================================="
    log_and_echo "Проверка: $description"
    log_and_echo "Команда: $command"
    log_and_echo "------------------------------------------"
    
    # Выполнение команды и запись результата
    eval "$command" >> "$LOG_FILE" 2>&1
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_and_echo "Результат: УСПЕХ"
    else
        log_and_echo "Результат: ОШИБКА (код: $exit_code)"
    fi
    
    log_and_echo ""
}

log_and_echo "Начало проверки системы - $(date)"
log_and_echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 1"
execute_check "Проверка IP адреса 192.168.2.10/28" "ip a | grep 192.168.2.10/28"

log_and_echo "=========================================="
log_and_echo "Критерий 2"
execute_check "Проверка часового пояса Asia/Yekaterinburg" "timedatectl | grep Asia/Yekaterinburg"
execute_check "Проверка hostname hq-cli.au-team.irpo" "hostnamectl | grep hq-cli.au-team.irpo"

log_and_echo "=========================================="
log_and_echo "Критерий 5"
execute_check "Проверка пользователей с домашними директориями" "cat /etc/passwd | grep home"

log_and_echo "=========================================="
log_and_echo "Критерий 6"
execute_check "Пинг 192.168.3.1" "ping 192.168.3.1 -c 2"
execute_check "Пинг 192.168.3.10" "ping 192.168.3.10 -c 2"
execute_check "Пинг 172.16.2.1" "ping 172.16.2.1 -c 2"
execute_check "Пинг 192.168.1.10" "ping 192.168.1.10 -c 2"
execute_check "Пинг 8.8.8.8" "ping 8.8.8.8 -c 2"
execute_check "Пинг ya.ru (проверка DNS)" "ping ya.ru -c 2"

log_and_echo "=========================================="
log_and_echo "Проверка завершена - $(date)"
log_and_echo "Результаты сохранены в файл: $LOG_FILE"

# Дополнительная информация о системе
log_and_echo ""
log_and_echo "Дополнительная системная информация:"
log_and_echo "Hostname: $(hostname)" >> "$LOG_FILE"
log_and_echo "Время: $(date)" >> "$LOG_FILE"
log_and_echo "Пользователь: $(whoami)" >> "$LOG_FILE"

echo ""
echo "Для просмотра полных результатов выполните: cat $LOG_FILE"
