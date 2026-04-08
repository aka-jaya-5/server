#!/bin/bash

set -e

clear

echo "========================================="
echo " TRACCAR AUTO INSTALLER - DEBIAN 12"
echo "========================================="
echo ""

if [ "$EUID" -ne 0 ]; then
  echo "Script harus dijalankan sebagai ROOT"
  exit
fi

DB_NAME="tracker"
DB_USER="tracker"
DB_PASS="tracker123456"

SERVER_IP=$(hostname -I | awk '{print $1}')

echo "Server IP : $SERVER_IP"
echo ""

echo "Update system..."
apt update -y
apt upgrade -y

echo ""
echo "Install dependencies..."
echo ""

apt install -y \
curl \
wget \
unzip \
nginx \
openjdk-17-jre \
mariadb-server

echo ""
echo "Start MariaDB..."
echo ""

systemctl start mariadb
systemctl enable mariadb

echo ""
echo "Setup Database..."
echo ""

mysql <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo ""
echo "Download Traccar latest version..."
echo ""

LATEST=$(curl -s https://api.github.com/repos/traccar/traccar/releases/latest | grep tag_name | cut -d '"' -f4)

VERSION=${LATEST#v}

wget https://github.com/traccar/traccar/releases/download/$LATEST/traccar-linux-64-${VERSION}.zip

unzip -o traccar-linux-64-${VERSION}.zip

echo ""
echo "Install Traccar..."
echo ""

./traccar.run

echo ""
echo "Configuring Traccar..."
echo ""

cat > /opt/traccar/conf/traccar.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">
<properties>

<entry key='database.driver'>com.mysql.cj.jdbc.Driver</entry>
<entry key='database.url'>jdbc:mysql://localhost:3306/$DB_NAME?useSSL=false&amp;serverTimezone=UTC</entry>
<entry key='database.user'>$DB_USER</entry>
<entry key='database.password'>$DB_PASS</entry>

<entry key='web.url'>http://$SERVER_IP:8082</entry>

<entry key='processing.copyAttributes.enable'>true</entry>

</properties>
EOF

systemctl restart traccar
systemctl enable traccar

echo ""
echo "========================================="
echo " INSTALLATION COMPLETED"
echo "========================================="
echo ""

echo "TRACCAR ACCESS:"
echo "http://$SERVER_IP:8082"
echo ""

echo "DEFAULT LOGIN:"
echo "Email    : admin"
echo "Password : admin"
echo ""

echo "DATABASE INFO:"
echo "DB Name  : $DB_NAME"
echo "DB User  : $DB_USER"
echo "DB Pass  : $DB_PASS"
echo ""

echo "SERVER INFO:"
echo "Server IP : $SERVER_IP"
echo ""

echo "TRACCAR STATUS:"
echo "systemctl status traccar"
echo ""

echo "VIEW LOG:"
echo "tail -f /opt/traccar/logs/tracker-server.log"
echo ""

echo "RESTART TRACCAR:"
echo "systemctl restart traccar"
echo ""

echo "========================================="
echo ""
