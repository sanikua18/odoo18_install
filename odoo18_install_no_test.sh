#!/bin/bash

# Скрипт для автоматичної інсталяції Odoo 18 на Ubuntu Server 24.04
# Доданий прогрес виконання
# Використання: ./install_odoo18.sh для автоматичної інсталяції
# Використання: ./install_odoo18.sh [DB_PASSWORD] [ADMIN_PASSWORD]

set -e  # Зупинити скрипт при помилці

# Параметри за замовчуванням
DB_PASSWORD=${1:-"123456"}
ADMIN_PASSWORD=${2:-"admin"}
ODOO_USER="odoo18"
ODOO_HOME="/opt/odoo18"

# Загальна кількість етапів
TOTAL_STEPS=10

# Функція для відображення прогрес-бару
show_progress() {
    local current=$1
    local total=$2
    local step_name=$3
    
    # Обчислення відсотка
    local percent=$((current * 100 / total))
    
    # Створення візуального прогрес-бару
    local bar_length=50
    local filled_length=$((percent * bar_length / 100))
    
    # Створення строки з заповненими та порожніми символами
    local bar=""
    for ((i=0; i<filled_length; i++)); do
        bar+="█"
    done
    for ((i=filled_length; i<bar_length; i++)); do
        bar+="░"
    done
    
    # Очищення попереднього рядка та відображення нового
    printf "\r\033[2K"
    printf "\033[1;36m[%s] %3d%% \033[1;32m(%d/%d)\033[0m %s" \
        "$bar" "$percent" "$current" "$total" "$step_name"
    
    if [ $current -eq $total ]; then
        printf "\n\n"
    else
        printf "\n"
    fi
}

# Функція для виконання етапу з прогрес-баром
execute_step() {
    local step_num=$1
    local step_name=$2
    shift 2
    
    show_progress $step_num $TOTAL_STEPS "$step_name"
    
    # Виконання команди з перенаправленням виводу
    if ! "$@" >/dev/null 2>&1; then
        printf "\n\033[1;31m❌ Помилка на етапі: %s\033[0m\n" "$step_name"
        exit 1
    fi
    
    sleep 0.5  # Невелика пауза для візуального ефекту
}

# Функція для виконання команд sudo з виводом в null
silent_sudo() {
    sudo "$@" >/dev/null 2>&1
}

echo "🚀 \033[1;34mПочаток інсталяції Odoo 18\033[0m"
echo "📊 Пароль БД: $DB_PASSWORD"
echo "🔐 Пароль адміністратора: $ADMIN_PASSWORD"
echo "👤 Користувач: $ODOO_USER"
echo "📁 Домашня директорія: $ODOO_HOME"
echo ""

# Етап 1: Оновлення системи
execute_step 1 "Оновлення пакетів системи..." \
    silent_sudo apt-get update

# Етап 2: Інсталяція Python та залежностей
execute_step 2 "Інсталяція Python та системних залежностей..." \
    silent_sudo apt-get install -y python3-pip python3-dev python3-venv libxml2-dev libxslt1-dev zlib1g-dev \
    libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libmysqlclient-dev \
    libjpeg-dev libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev

# Етап 3: Інсталяція Node.js та npm
execute_step 3 "Інсталяція Node.js, npm та CSS препроцесорів..." \
    bash -c "
        silent_sudo apt-get install -y npm nodejs &&
        silent_sudo npm install -g less less-plugin-clean-css &&
        silent_sudo apt-get install -y node-less
    "

# Етап 4: Інсталяція PostgreSQL
execute_step 4 "Інсталяція та налаштування PostgreSQL..." \
    silent_sudo apt-get install -y postgresql

# Етап 5: Створення користувача бази даних
execute_step 5 "Створення користувача бази даних..." \
    bash -c "
        sudo -u postgres psql -c 'DROP USER IF EXISTS $ODOO_USER;' >/dev/null 2>&1 || true &&
        sudo -u postgres createuser --createdb --no-createrole --superuser $ODOO_USER >/dev/null 2>&1 &&
        sudo -u postgres psql -c \"ALTER USER $ODOO_USER WITH PASSWORD '$DB_PASSWORD';\" >/dev/null 2>&1
    "

# Етап 6: Створення системного користувача та завантаження Odoo
execute_step 6 "Створення користувача системи та завантаження Odoo 18..." \
    bash -c "
        silent_sudo adduser --system --home=$ODOO_HOME --group $ODOO_USER 2>/dev/null || true &&
        silent_sudo apt-get install -y git &&
        sudo rm -rf $ODOO_HOME/* 2>/dev/null || true &&
        sudo -u $ODOO_USER git clone https://www.github.com/odoo/odoo --depth 1 --branch 18.0 --single-branch $ODOO_HOME/odoo >/dev/null 2>&1 &&
        sudo -u $ODOO_USER mkdir -p $ODOO_HOME/custom_addons >/dev/null 2>&1 &&
        sudo -u $ODOO_USER mkdir -p $ODOO_HOME/data_directory >/dev/null 2>&1
    "

# Етап 7: Створення віртуального середовища та інсталяція залежностей
execute_step 7 "Створення Python віртуального середовища..." \
    bash -c "
        silent_sudo python3 -m venv $ODOO_HOME/venv &&
        silent_sudo chown -R $ODOO_USER:$ODOO_USER $ODOO_HOME/venv &&
        sudo -u $ODOO_USER $ODOO_HOME/venv/bin/pip install --upgrade pip >/dev/null 2>&1 &&
        sudo -u $ODOO_USER $ODOO_HOME/venv/bin/pip install -r $ODOO_HOME/odoo/requirements.txt >/dev/null 2>&1
    "

# Етап 8: Інсталяція wkhtmltopdf
execute_step 8 "Інсталяція wkhtmltopdf для генерації PDF..." \
    bash -c "
        cd /tmp &&
        wget -q https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb >/dev/null 2>&1 &&
        wget -q http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb >/dev/null 2>&1 &&
        silent_sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb 2>/dev/null || true &&
        silent_sudo apt-get install -y xfonts-75dpi &&
        silent_sudo dpkg -i wkhtmltox_0.12.5-1.bionic_amd64.deb 2>/dev/null || true &&
        silent_sudo apt install -f -y
    "

# Етап 9: Створення конфігурації та systemd сервісу
execute_step 9 "Створення конфігураційних файлів..." \
    bash -c "
        sudo tee $ODOO_HOME/odoo18.conf > /dev/null <<EOF
[options]
; This is the password that allows database operations:
admin_passwd = $ADMIN_PASSWORD
db_host = localhost
db_port = 5432
db_user = $ODOO_USER
db_password = $DB_PASSWORD
addons_path = $ODOO_HOME/odoo/addons,$ODOO_HOME/custom_addons
data_dir = $ODOO_HOME/data_directory
logfile = $ODOO_HOME/odoo18.log
xmlrpc_port = 8069
EOF

        sudo tee /etc/systemd/system/odoo18.service > /dev/null <<EOF
[Unit]
Description=Odoo18
Documentation=http://www.odoo.com
After=network.target postgresql.service

[Service]
Type=simple
User=$ODOO_USER
ExecStart=$ODOO_HOME/venv/bin/python3 $ODOO_HOME/odoo/odoo-bin -c $ODOO_HOME/odoo18.conf
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

        silent_sudo chown -R $ODOO_USER:$ODOO_USER $ODOO_HOME
    "

# Етап 10: Запуск сервісу
execute_step 10 "Запуск та активація Odoo 18 сервісу..." \
    bash -c "
        silent_sudo systemctl daemon-reload &&
        silent_sudo systemctl enable odoo18.service &&
        silent_sudo systemctl start odoo18.service &&
        sleep 3
    "

# Завершення з результатами
printf "\033[1;32m✅ Інсталяція успішно завершена!\033[0m\n\n"

# Перевірка статусу
echo "📋 \033[1;33mСтатус сервісу:\033[0m"
sudo systemctl status odoo18.service --no-pager --lines=3

echo ""
echo "🎉 \033[1;32m=== ІНСТАЛЯЦІЯ ЗАВЕРШЕНА ===\033[0m"
echo "🌐 Odoo 18 доступний за адресою: \033[1;34mhttp://localhost:8069\033[0m"
echo "🔐 Пароль майстра (admin_passwd): \033[1;31m$ADMIN_PASSWORD\033[0m"
echo "👤 Користувач БД: \033[1;36m$ODOO_USER\033[0m"
echo "🔑 Пароль БД: \033[1;31m$DB_PASSWORD\033[0m"
echo ""
echo "📜 \033[1;33mКорисні команди:\033[0m"
echo "   Логи: \033[0;37msudo tail -f $ODOO_HOME/odoo18.log\033[0m"
echo "   Керування: \033[0;37msudo systemctl [start|stop|restart|status] odoo18.service\033[0m"
