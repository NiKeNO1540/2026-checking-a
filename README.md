# Checking. Module Student-A

Репозиторий с проверками DEMO-2026, Module A(Базовый уровень)


# Вставки

### Открыли определенную вам категорию, скопировали, зашли в терминал через xtermjs, ПКМ > Вставить, ждете. То есть ничего сложного нету.

<details>
<summary>HQ-SRV</summary>

### Первый модуль

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/HQ-SRV-Module-1.sh
chmod +x HQ-SRV-Module-1.sh && ./HQ-SRV-Module-1.sh
```

### Второй модуль

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/HQ-SRV-Module-2.sh
chmod +x HQ-SRV-Module-2.sh && ./HQ-SRV-Module-2.sh
```

</details>

<details>
<summary>BR-SRV</summary>

### Первый модуль

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/BR-SRV-Module-1.sh
chmod +x BR-SRV-Module-1.sh && ./BR-SRV-Module-1.sh
```

### Второй модуль

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/BR-SRV-Module-2.sh
chmod +x BR-SRV-Module-2.sh && ./BR-SRV-Module-2.sh
```

</details>

<details>
<summary>HQ-CLI</summary>

### Первый модуль

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/HQ-CLI-Module-1.sh
chmod +x HQ-CLI-Module-1.sh && ./HQ-CLI-Module-1.sh
```

### Второй модуль

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/HQ-CLI-Module-2.sh
chmod +x HQ-CLI-Module-2.sh && ./HQ-CLI-Module-2.sh
```

</details>

<details>
<summary>HQ-RTR</summary>

### HQ-RTR

```tcl
en
conf
no security default
end
wr
```

### Первый модуль [ЗАПУСКАЕТСЯ НА HQ-SRV]

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/Uni_export_v2.sh
chmod +x Uni_export_v2.sh && ./Uni_export_v2.sh
```

### Второй модуль [ЗАПУСКАЕТСЯ НА HQ-SRV]

### HQ-RTR

```tcl
en
conf
no security default
end
wr
```

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/Uni_export_v2.sh
chmod +x Uni_export_v2.sh && ./Uni_export_v2.sh
```

</details>

<details>
<summary>BR-RTR</summary>

### Первый модуль [ЗАПУСКАЕТСЯ НА BR-SRV]

### BR-RTR

```tcl
en
conf
no security default
end
wr
```

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/Uni_export_v2.sh
chmod +x Uni_export_v2.sh && ./Uni_export_v2.sh
```

### Второй модуль [ЗАПУСКАЕТСЯ НА BR-SRV]

### BR-RTR

```tcl
en
conf
no security default
end
wr
```

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/Uni_export_v2.sh
chmod +x Uni_export_v2.sh && ./Uni_export_v2.sh
```

</details>

<details>
<summary>ISP</summary>

### Первый модуль

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/ISP-Module-1.sh
chmod +x ISP-Module-1.sh && ./ISP-Module-1.sh
```

### Второй модуль

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/ISP-Module-2.sh
chmod +x ISP-Module-2.sh && ./ISP-Module-2.sh
```

</details>
