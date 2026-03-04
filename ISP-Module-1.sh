#!/bin/bash

# Файл для записи результатов
LOG_FILE="system_check_results.txt"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "=== Результаты проверки системы - $TIMESTAMP ===" | tee "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Проверка IP адресов
echo "1. Проверка IP адресов:" | tee -a "$LOG_FILE"

echo "Проверка 172.16.1.1:" | tee -a "$LOG_FILE"
if ip a | grep -q "172.16.1.1"; then
    echo "✓ Найден IP 172.16.1.1" | tee -a "$LOG_FILE"
else
    echo "✗ IP 172.16.1.1 не найден" | tee -a "$LOG_FILE"
fi

echo "Проверка 172.16.2.1:" | tee -a "$LOG_FILE"
if ip a | grep -q "172.16.2.1"; then
    echo "✓ Найден IP 172.16.2.1" | tee -a "$LOG_FILE"
else
    echo "✗ IP 172.16.2.1 не найден" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"

# Проверка hostname
echo "2. Проверка hostname:" | tee -a "$LOG_FILE"
if hostnamectl | grep -q "ISP"; then
    echo "✓ Hostname содержит 'ISP'" | tee -a "$LOG_FILE"
    hostnamectl | grep -i "static hostname" | tee -a "$LOG_FILE"
else
    echo "✗ Hostname не содержит 'ISP'" | tee -a "$LOG_FILE"
    hostnamectl | grep -i "static hostname" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"

# Проверка временной зоны (исправлена опечатка в названии города)
echo "3. Проверка временной зоны:" | tee -a "$LOG_FILE"
if timedatectl | grep -q "Asia/Yekaterinburg"; then
    echo "✓ Временная зона установлена: Asia/Yekaterinburg" | tee -a "$LOG_FILE"
else
    echo "✗ Временная зона не установлена на Asia/Yekaterinburg" | tee -a "$LOG_FILE"
    timedatectl | grep "Time zone" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "Подробная информация о времени:" | tee -a "$LOG_FILE"
timedatectl | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "=== Проверка завершена ===" | tee -a "$LOG_FILE"
echo "Результаты сохранены в файл: $LOG_FILE" | tee -a "$LOG_FILE"
