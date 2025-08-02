# odoo18_install
Automated odoo 18 install script

# Download file
git clone https://github.com/sanikua18/odoo18_install/raw/refs/heads/main/odoo18_install.sh

# Зробити файл виконуваним
chmod +x odoo18_install.sh

# Запуск з параметрами за замовчуванням (пароль БД: 123456, пароль адміна: admin)
sudo ./odoo18_install.sh

# Запуск з власними паролями
sudo ./odoo18_install.sh "мій_пароль_бд" "мій_пароль_адміна"
