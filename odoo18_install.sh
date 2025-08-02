#!/bin/bash

# Скрипт для автоматичної інсталяції Odoo 18 на Ubuntu Server 24.04
# Використання: ./install_odoo18.sh [DB_PASSWORD] [ADMIN_PASSWORD]

set -e  # Зупинити скрипт при помилці

# Параметри за замовчуванням
DB_PASSWORD=${1:-"123456"}
ADMIN_PASSWORD=${2:-"admin"}
ODOO_USER="odoo18"
ODOO_HOME="/opt/odoo18"

echo "=== Початок інсталяції Odoo 18 ==="
echo "Пароль БД: $DB_PASSWORD"
echo "Пароль адміністратора: $ADMIN_PASSWORD"

# Оновлення системи
echo "Оновлення пакетів системи..."
sudo apt-get update

# Інсталяція Python та залежностей
echo "Інсталяція Python та залежностей..."
sudo apt-get install -y python3-pip python3-dev python3-venv libxml2-dev libxslt1-dev zlib1g-dev \
    libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libmysqlclient-dev \
    libjpeg-dev libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev

# Інсталяція Node.js та npm
echo "Інсталяція Node.js та npm..."
sudo apt-get install -y npm nodejs
sudo npm install -g less less-plugin-clean-css
sudo apt-get install -y node-less

# Інсталяція PostgreSQL
echo "Інсталяція PostgreSQL..."
sudo apt-get install -y postgresql

# Створення користувача бази даних
echo "Створення користувача бази даних odoo18..."
sudo -u postgres psql -c "DROP USER IF EXISTS $ODOO_USER;"
sudo -u postgres createuser --createdb --no-createrole --superuser $ODOO_USER
sudo -u postgres psql -c "ALTER USER $ODOO_USER WITH PASSWORD '$DB_PASSWORD';"

# Створення системного користувача
echo "Створення системного користувача $ODOO_USER..."
sudo adduser --system --home=$ODOO_HOME --group $ODOO_USER || true

# Інсталяція Git
sudo apt-get install -y git

# Завантаження Odoo 18
echo "Завантаження Odoo 18..."
sudo rm -rf $ODOO_HOME/* || true
sudo -u $ODOO_USER git clone https://www.github.com/odoo/odoo --depth 1 --branch 18.0 --single-branch $ODOO_HOME/odoo
sudo -u $ODOO_USER mkdir -p $ODOO_HOME/custom_addons
sudo -u $ODOO_USER mkdir -p $ODOO_HOME/data_directory

# Створення віртуального середовища
echo "Створення віртуального середовища Python..."
sudo python3 -m venv $ODOO_HOME/venv
sudo chown -R $ODOO_USER:$ODOO_USER $ODOO_HOME/venv

# Інсталяція Python залежностей
echo "Інсталяція Python залежностей..."
sudo -u $ODOO_USER $ODOO_HOME/venv/bin/pip install --upgrade pip
sudo -u $ODOO_USER $ODOO_HOME/venv/bin/pip install -r $ODOO_HOME/odoo/requirements.txt

# Інсталяція wkhtmltopdf
echo "Інсталяція wkhtmltopdf..."
cd /tmp
wget -q https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb
wget -q http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb || true
sudo apt-get install -y xfonts-75dpi
sudo dpkg -i wkhtmltox_0.12.5-1.bionic_amd64.deb || true
sudo apt install -f -y

# Створення конфігураційного файлу
echo "Створення конфігураційного файлу..."
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

# Встановлення правильних прав доступу
sudo chown -R $ODOO_USER:$ODOO_USER $ODOO_HOME

# Створення systemd сервісу
echo "Створення systemd сервісу..."
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

# Перезавантаження systemd та запуск сервісу
echo "Запуск Odoo 18 сервісу..."
sudo systemctl daemon-reload
sudo systemctl enable odoo18.service
sudo systemctl start odoo18.service

# Перевірка статусу
echo "Перевірка статусу сервісу..."
sleep 5
sudo systemctl status odoo18.service --no-pager

echo ""
echo "=== Інсталяція завершена ==="
echo "Odoo 18 доступний за адресою: http://localhost:8069"
echo "Пароль майстра (admin_passwd): $ADMIN_PASSWORD"
echo "Користувач БД: $ODOO_USER"
echo "Пароль БД: $DB_PASSWORD"
echo ""
echo "Для перегляду логів використовуйте:"
echo "sudo tail -f $ODOO_HOME/odoo18.log"
echo ""
echo "Для управління сервісом:"
echo "sudo systemctl start|stop|restart|status odoo18.service"
