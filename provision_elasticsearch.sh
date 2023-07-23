#!/bin/bash

# Configuración de los puntos de montaje
# Crear tabla de particiones y volumen lógico con LVM
sudo parted /dev/sdb mklabel gpt
sudo parted /dev/sdb mkpart primary ext4 0% 100%
sudo pvcreate /dev/sdb1
sudo vgcreate elasticsearch_vg /dev/sdb1
sudo lvcreate -n elasticsearch_lv -l 100%FREE elasticsearch_vg
sudo mkfs.ext4 /dev/elasticsearch_vg/elasticsearch_lv

# Montar el volumen lógico en /var/lib/elasticsearch y agregar la entrada en /etc/fstab
sudo mkdir -p /var/lib/elasticsearch
echo "/dev/elasticsearch_vg/elasticsearch_lv /var/lib/elasticsearch ext4 defaults 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# Eliminar el directorio /var/lib/elasticsearch/lost+found si existe
sudo rm -rf /var/lib/elasticsearch/lost+found

# Configuración del repositorio de Elastic.co para Elasticsearch 8
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.list

# Actualizar índices de APT
sudo apt-get update
sudo apt-get upgrade -y

# Instalación de Elasticsearch
sudo apt install elasticsearch

# Habilitar y arrancar el servicio de Elasticsearch
sudo systemctl enable elasticsearch
sudo systemctl start elasticsearch

# Generar contraseñas para el usuario "elastic" y "kibana_system"
elastic_password=$(/usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -b -s)
kibana_system_password=$(/usr/share/elasticsearch/bin/elasticsearch-reset-password -u kibana_system -b -s)

# Guardar las contraseñas en un archivo para usarlas posteriormente
echo "Elasticsearch User (elastic) Password: $elastic_password" > passwords.txt
echo "Kibana System User Password: $kibana_system_password" >> passwords.txt

# Instalación de Kibana
sudo apt-get install -y kibana

# Configurar Kibana
sudo mkdir -p /etc/kibana/certs
sudo cp /etc/elasticsearch/certs/http_ca.crt /etc/kibana/certs/http_ca.crt

sudo sed -i 's/#server.port: 5601/server.port: 5601/' /etc/kibana/kibana.yml
sudo sed -i 's/#server.host: "localhost"/server.host: "0.0.0.0"/' /etc/kibana/kibana.yml
sudo sed -i 's/#elasticsearch.hosts:/elasticsearch.hosts:/' /etc/kibana/kibana.yml
sudo sed -i 's/#  - http:\/\/localhost:9200/  - https:\/\/localhost:9200/' /etc/kibana/kibana.yml
sudo sed -i "s/#elasticsearch.username:/elasticsearch.username: \"kibana_system\"/" /etc/kibana/kibana.yml
sudo sed -i "s/#elasticsearch.password:/elasticsearch.password: \"$kibana_system_password\"/" /etc/kibana/kibana.yml
sudo sed -i 's/#elasticsearch.ssl.certificateAuthorities: \[\]/elasticsearch.ssl.certificateAuthorities: [ "/etc/kibana/certs/http_ca.crt" ]/' /etc/kibana/kibana.yml

# Reiniciar Kibana para aplicar la configuración
sudo systemctl enable kibana --now

# Eliminar el directorio /var/lib/elasticsearch/lost+found si existe
sudo rm -rf /var/lib/elasticsearch/lost+found

# Instalación de Logstash
sudo apt-get install -y logstash

# Crear el directorio para almacenar el certificado de la CA de Elastic
sudo mkdir -p /etc/logstash/certs
sudo cp /etc/elasticsearch/certs/http_ca.crt /etc/kibana/certs/http_ca.crt
sudo chown -R logstash:logstash /etc/kibana/certs

# Crear el role de Logstash con permisos de escritura y creación de índices
curl -XPOST --cacert /etc/logstash/certs/http_ca.crt -u elastic:$ELASTIC_PASSWORD 'https://localhost:9200/_security/role/logstash_write_role' -H "Content-Type: application/json" -d '
{
  "cluster": ["monitor", "manage_index_templates"],
  "indices": [
    {
      "names": ["*"],
      "privileges": ["write", "create_index", "auto_configure"],
      "field_security": {
        "grant": ["*"]
      }
    }
  ],
  "run_as": [],
  "metadata": {},
  "transient_metadata": {
    "enabled": true
  }
}'
 
# Crear el usuario de Logstash
curl -XPOST --cacert /etc/logstash/certs/http_ca.crt -u elastic:$ELASTIC_PASSWORD 'https://localhost:9200/_security/user/logstash' -H "Content-Type: application/json" -d '
{
  "password" : "keepcoding_logstash",
  "roles" : ["logstash_admin", "logstash_system", "logstash_write_role"],
  "full_name" : "Logstash User"
}'
 
# Crear el directorio para almacenar los archivos de configuración
sudo mkdir -p /etc/logstash/conf.d

# Configurar los archivos de inputs y outputs
sudo tee /etc/logstash/conf.d/02-beats-input.conf > /dev/null <<EOL
input {
  beats {
    port => 5044
  }
}
EOL

sudo tee /etc/logstash/conf.d/30-elasticsearch-output.conf > /dev/null <<EOL
output {
  elasticsearch {
    hosts => ["https://localhost:9200"]
    manage_template => false
    index => "filebeat-demo-%{+YYYY.MM.dd}"
    user => "logstash"
    password => "keepcoding_logstash"
    cacert => "/etc/logstash/certs/http_ca.crt"
  }
}
EOL

# Reiniciar Logstash para aplicar la configuración
sudo systemctl enable logstash --now