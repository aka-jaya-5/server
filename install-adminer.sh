#!/bin/bash

clear
echo "======================================"
echo " ADMINER AUTO INSTALL + AUTO PORT"
echo "======================================"

if [ "$EUID" -ne 0 ]; then
  echo "Jalankan sebagai root"
  exit
fi

echo ""
echo "Update system..."
apt update -y

echo ""
echo "Install PHP..."
apt install -y php php-mysql curl

echo ""
echo "Download Adminer..."
mkdir -p /opt/adminer
cd /opt/adminer

curl -L https://www.adminer.org/latest.php -o index.php

echo ""
echo "Mencari port kosong..."

PORT=8080

while ss -tuln | grep -q ":$PORT "; do
  PORT=$((PORT+1))
done

echo "Port kosong ditemukan: $PORT"

SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "Menjalankan Adminer..."

nohup php -S 0.0.0.0:$PORT > /dev/null 2>&1 &

echo ""
echo "======================================"
echo " ADMINER GUI SIAP"
echo "======================================"
echo ""
echo "Akses dari browser:"
echo ""
echo "http://$SERVER_IP:$PORT"
echo ""
echo "Login database:"
echo "System   : MySQL"
echo "Server   : localhost"
echo "User     : tracker"
echo "Password : tracker123456"
echo "Database : tracker"
echo ""
echo "======================================"
