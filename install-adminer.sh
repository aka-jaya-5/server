#!/bin/bash

set -e

clear

echo "======================================="
echo " ADMINER AUTO INSTALLER - DEBIAN 12"
echo "======================================="
echo ""

if [ "$EUID" -ne 0 ]; then
  echo "Jalankan script sebagai ROOT"
  exit
fi

SERVER_IP=$(hostname -I | awk '{print $1}')

echo "Server IP: $SERVER_IP"
echo ""

echo "Update system..."
apt update -y

echo "Install Nginx + PHP..."
apt install -y nginx php-fpm php-mysql curl

echo ""
echo "Download Adminer..."
mkdir -p /var/www/adminer
cd /var/www/adminer

curl -L https://www.adminer.org/latest.php -o index.php

echo ""
echo "Configuring Nginx..."

cat > /etc/nginx/sites-available/adminer <<EOF
server {

    listen 8080;
    server_name _;

    root /var/www/adminer;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }

}
EOF

ln -sf /etc/nginx/sites-available/adminer /etc/nginx/sites-enabled/adminer

echo ""
echo "Restart services..."

systemctl restart php8.2-fpm
systemctl restart nginx

echo ""
echo "======================================="
echo " INSTALLATION COMPLETE"
echo "======================================="
echo ""

echo "ADMINER GUI ACCESS:"
echo "http://$SERVER_IP:8080"
echo ""

echo "DATABASE LOGIN EXAMPLE:"
echo "System   : MySQL"
echo "Server   : localhost"
echo "Username : tracker"
echo "Password : tracker123456"
echo "Database : tracker"
echo ""

echo "======================================="
echo ""
