#!/bin/bash

# Automatic Traccar Installer with MySQL or PostgreSQL and SSL via Nginx
#
# Programmer: Tonny Barros
# Email: tonnybarros@gmail.com
# Contact: +55 21 97912-3851
#
# Contributor: Michaell Oliveira
# Email: michaelloliveira@gmail.com
# Contact: +55 79 9116-5245
#
# Changelog
# [2025-03-24] Michaell Oliveira
# * Refactored
# * Option to choose Traccar version
#   if not selected the latest version will be used
# * Option to choose database:
#   MySQL (default) or PostgreSQL
# * Compatible with Ubuntu, Debian, Fedora, AlmaLinux, CentOS
# * Sensitive field validation
# * More informative messages
# * Error checking

set -e

clear

display_banner() {
    echo ""
    echo "████████╗██████╗  █████╗  ██████╗ ██████╗ █████╗ ██████╗ "
    echo "╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██╔════╝██╔══██╗██╔══██╗"
    echo "   ██║   ██████╔╝███████║██║     ██║     ███████║██████╔╝ "
    echo "   ██║   ██╔══██╗██╔══██║██║     ██║     ██╔══██║██╔══██╗"
    echo "   ██║   ██║  ██║██║  ██║╚██████╗╚██████╗██║  ██║██║  ██║"
    echo "   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝╚═════╝ ╚═╝  ╚═╝ v3.0"
    echo ""
    echo "Traccar Installer - v3.0"
    echo "This script will always fetch the latest Traccar version from GitHub if not specified."
    echo "The script can optimize Java memory (if enabled). Read more: https://www.traccar.org/optimization/"
    echo "!!! Recommended to use a clean server installation !!!"
    read -p "Press ENTER to start"
}

TOTAL_MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEMORY_MB=$((TOTAL_MEMORY_KB / 1024))

get_user_input() {

    read -p "Enter the Traccar version (Example: 6.6 or leave blank for latest): " LATEST_VERSION

    while [[ -z "$DB_TYPE" ]]; do
        read -p "Choose database (mysql/postgresql): " DB_TYPE
    done

    while [[ -z "$DB_NAME" ]]; do
        read -p "Enter the database name for Traccar: " DB_NAME
    done

    while [[ -z "$DB_USER" ]]; do
        read -p "Enter the database user to be created for Traccar: " DB_USER
    done

    while [[ -z "$DB_PASS" ]]; do
        read -sp "Enter the database password: " DB_PASS
        echo ""
    done

    while [[ -z "$DOMAIN" ]]; do
        read -p "Enter your domain (example: gps.yourdomain.com): " DOMAIN
    done

    echo "Total server memory: ${TOTAL_MEMORY_MB}MB"

    read -p "Enter percentage of server memory to allocate for Java (example: 60 for 60%) (leave blank to skip): " MEMORY_PERCENT
}

install_dependencies() {

    DISTRO=$(lsb_release -i | awk '{print $3}')

    if [[ "$DISTRO" == "Ubuntu" || "$DISTRO" == "Debian" ]]; then
        sudo apt update && sudo apt upgrade -y
        sudo apt install -y unzip openjdk-17-jre nginx certbot python3-certbot-nginx curl

        if [[ "$DB_TYPE" == "mysql" ]]; then
            sudo apt install -y mysql-server
        elif [[ "$DB_TYPE" == "postgresql" ]]; then
            sudo apt install -y postgresql postgresql-contrib
        fi

    elif [[ "$DISTRO" == "Fedora" || "$DISTRO" == "CentOS" || "$DISTRO" == "AlmaLinux" ]]; then
        sudo dnf update -y
        sudo dnf install -y unzip java-17-openjdk nginx certbot python3-certbot-nginx curl

        if [[ "$DB_TYPE" == "mysql" ]]; then
            sudo dnf install -y mysql-server
        elif [[ "$DB_TYPE" == "postgresql" ]]; then
            sudo dnf install -y postgresql postgresql-server
        fi

    else
        echo "Unsupported Linux distribution!"
        exit 1
    fi
}

configure_database() {

    if [[ "$DB_TYPE" == "mysql" ]]; then

        sudo mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
        sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
        sudo mysql -e "FLUSH PRIVILEGES;"

    elif [[ "$DB_TYPE" == "postgresql" ]]; then

        sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
        sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

    fi
}

download_traccar() {

    if [[ -z "$LATEST_VERSION" ]]; then
        LATEST_VERSION=$(curl -s https://api.github.com/repos/traccar/traccar/releases/latest | grep tag_name | awk -F '"' '{print $4}')
    fi

    wget https://github.com/traccar/traccar/releases/download/$LATEST_VERSION/traccar-linux-64-${LATEST_VERSION:1}.zip
    unzip -o traccar-linux-64-${LATEST_VERSION:1}.zip
    sudo ./traccar.run
}

configure_traccar() {

    DB_DRIVER=""
    DB_URL=""

    if [[ "$DB_TYPE" == "mysql" ]]; then

        DB_DRIVER="com.mysql.cj.jdbc.Driver"
        DB_URL="jdbc:mysql://localhost:3306/$DB_NAME?allowPublicKeyRetrieval=true&amp;serverTimezone=UTC&amp;useSSL=false&amp;allowMultiQueries=true&amp;autoReconnect=true&amp;useUnicode=yes&amp;characterEncoding=UTF-8&amp;sessionVariables=sql_mode=''"

    elif [[ "$DB_TYPE" == "postgresql" ]]; then

        DB_DRIVER="org.postgresql.Driver"
        DB_URL="jdbc:postgresql://localhost:5432/$DB_NAME"

    fi

sudo tee /opt/traccar/conf/traccar.xml > /dev/null <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">
<properties>

<entry key='database.driver'>$DB_DRIVER</entry>
<entry key='database.url'>$DB_URL</entry>
<entry key='database.user'>$DB_USER</entry>
<entry key='database.password'>$DB_PASS</entry>

<entry key='processing.copyAttributes.enable'>true</entry>
<entry key='processing.copyAttributes'>power,ignition,battery,blocked,driverUniqueId</entry>

<entry key='processing.remoteAddress.enable'>true</entry>

<entry key='distance.enable'>true</entry>

<entry key='web.url'>https://$DOMAIN</entry>

</properties>
EOL
}

configure_nginx() {

sudo tee /etc/nginx/sites-available/traccar > /dev/null <<EOL

server {
listen 80;
server_name $DOMAIN;

location / {
proxy_pass http://localhost:8082;
proxy_http_version 1.1;
proxy_set_header Upgrade \$http_upgrade;
proxy_set_header Connection 'upgrade';
proxy_set_header Host \$host;
proxy_cache_bypass \$http_upgrade;
}

location /api/socket {
proxy_pass http://localhost:8082/api/socket;
proxy_http_version 1.1;
proxy_set_header Upgrade \$http_upgrade;
proxy_set_header Connection "upgrade";
}

}

EOL

sudo ln -sf /etc/nginx/sites-available/traccar /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
}

configure_ssl() {

sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email --redirect

}

configure_memory() {

if [ ! -z "$MEMORY_PERCENT" ]; then

MAX_MEMORY_MB=$((TOTAL_MEMORY_MB * MEMORY_PERCENT / 100))

echo "Setting Java maximum memory (Xmx) to ${MEMORY_PERCENT}% of server memory: ${MAX_MEMORY_MB}MB"

sudo sed -i "s|ExecStart=/opt/traccar/jre/bin/java -jar tracker-server.jar conf/traccar.xml|ExecStart=/opt/traccar/jre/bin/java -Xmx${MAX_MEMORY_MB}m -jar tracker-server.jar conf/traccar.xml|" /etc/systemd/system/traccar.service

sudo systemctl daemon-reload
sudo systemctl restart traccar

fi
}

insert_friendly_commands() {

sudo tee /usr/local/bin/start-traccar > /dev/null <<EOL
#!/bin/bash
sudo systemctl start traccar
EOL

sudo tee /usr/local/bin/stop-traccar > /dev/null <<EOL
#!/bin/bash
sudo systemctl stop traccar
EOL

sudo tee /usr/local/bin/status-traccar > /dev/null <<EOL
#!/bin/bash
sudo systemctl status traccar
EOL

sudo tee /usr/local/bin/restart-traccar > /dev/null <<EOL
#!/bin/bash
sudo systemctl restart traccar
EOL

sudo tee /usr/local/bin/log-traccar > /dev/null <<EOL
#!/bin/bash
sudo tail -f /opt/traccar/logs/tracker-server.log
EOL

sudo chmod +x /usr/local/bin/*
}

finish_installation() {

echo ""
echo "Installation completed successfully!"
echo "Access your server via:"
echo "https://$DOMAIN"
echo ""

}

display_banner
get_user_input
install_dependencies
configure_database
download_traccar
configure_traccar
configure_nginx
configure_ssl
configure_memory
insert_friendly_commands
finish_installation
