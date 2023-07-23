#!/bin/bash

# Configuración de los puntos de montaje
# Crear tabla de particiones y volumen lógico con LVM
sudo parted /dev/sdb mklabel gpt
sudo parted /dev/sdb mkpart primary ext4 0% 100%
sudo pvcreate /dev/sdb1
sudo vgcreate wordpress_vg /dev/sdb1
sudo lvcreate -n wordpress_lv -l 100%FREE wordpress_vg
sudo mkfs.ext4 /dev/wordpress_vg/wordpress_lv

# Montar el volumen lógico en /var/lib/mysql y agregar la entrada en /etc/fstab
sudo mkdir -p /var/lib/mysql
echo "/dev/wordpress_vg/wordpress_lv /var/lib/mysql ext4 defaults 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# Actualización de repositorios
sudo apt-get update
sudo apt-get upgrade -y

# Instalación de Nginx, MariaDB y paquetes PHP
sudo apt-get install -y nginx mariadb-server mariadb-common php-fpm php-mysql expect php-curl php-gd php-intl php-mbstring php-soap php-xml php-xmlrpc php-zip

# Configurar Nginx
sudo tee /etc/nginx/sites-available/wordpress >/dev/null <<EOL
# Managed by installation script - Do not change
server {
    listen 80;
    root /var/www/wordpress;
    index index.php index.html index.htm index.nginx-debian.html;
    server_name localhost;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

sudo ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# Habilitar servicios de Nginx y PHP-FPM
sudo systemctl enable nginx php7.2-fpm
sudo systemctl restart nginx php7.2-fpm

# Instalación de Wordpress
# Creación de la base de datos y usuario para Wordpress
sudo mysql <<EOL
CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
GRANT ALL ON wordpress.* TO 'wordpressuser'@'localhost' IDENTIFIED BY 'keepcoding';
FLUSH PRIVILEGES;
EOL

# Descargar y descomprimir la última release de Wordpress
cd /tmp
wget -q https://wordpress.org/latest.tar.gz
tar xzf latest.tar.gz
sudo mv wordpress /var/www/

# Configurar la conexión a la base de datos en wp-config.php
sudo mv /var/www/wordpress/wp-config-sample.php /var/www/wordpress/wp-config.php
sudo sed -i "s/database_name_here/wordpress/" /var/www/wordpress/wp-config.php
sudo sed -i "s/username_here/wordpressuser/" /var/www/wordpress/wp-config.php
sudo sed -i "s/password_here/keepcoding/" /var/www/wordpress/wp-config.php

# Asegurarse de que el directorio es propiedad de www-data
sudo chown -R www-data:www-data /var/www/wordpress

# Instalación de Filebeat
# Configuración del repositorio de Elastic.co para Filebeat 8
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

# Actualizar índices de APT
sudo apt update

# Instalar Filebeat
sudo apt install filebeat

# Habilitar los módulos de system y nginx
sudo filebeat modules enable system
sudo filebeat modules enable nginx

# Crear el directorio /etc/filebeat
sudo mkdir -p /etc/filebeat

# Configurar Filebeat
sudo tee /etc/filebeat/filebeat.yml > /dev/null <<EOL
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/*.log
    - /var/log/nginx/*.log
    - /var/log/mysql/*.log
  # Agrega aquí cualquier otro log que desees monitorizar

output.logstash:
  hosts: ["192.168.100.6:5044"]
EOL

# Reiniciar Filebeat para aplicar la configuración
sudo systemctl restart filebeat