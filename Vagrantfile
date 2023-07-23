# -*- mode: ruby -*-
# vi: set ft=ruby :


Vagrant.configure("2") do |config|
 
  # Configuración de la máquina virtual 1 (Wordpress)
  config.vm.define "wordpress" do |wordpress|
    wordpress.vm.box = "hashicorp/bionic64"
    wordpress.vm.hostname = "wordpress"
    wordpress.vm.network "private_network", ip: "192.168.50.101"
    wordpress.vm.provider "virtualbox" do |vb|
      vb.name = "wordpress"
      vb.memory = "1024"
      vb.cpus = 1
      file_to_disk1 = "extradisk1.vmdk"
      unless File.exist?(file_to_disk1)
        vb.customize [ "createmedium", "disk", "--filename", "extradisk1.vmdk", "--format", "vmdk", "--size", 1024 * 1 ]
    end
    vb.customize [ "storageattach", "wordpress" , "--storagectl", "SATA Controller", "--port", "2", "--device", "0", "--type", "hdd", "--medium", file_to_disk1]
    end
    wordpress.vm.network "forwarded_port", guest: 80, host: 8081
    # Agregar el script de provisionamiento para Wordpress
    wordpress.vm.provision "shell", path: "provision_wordpress.sh"
  end

  # Configuración de la máquina virtual 2 (Elasticsearch)
  config.vm.define "elasticsearch" do |elasticsearch|
    elasticsearch.vm.box = "hashicorp/bionic64"
    elasticsearch.vm.hostname = "elasticsearch"
    elasticsearch.vm.network "private_network", ip: "192.168.50.102"
    elasticsearch.vm.provider "virtualbox" do |vb|
      vb.name = "elasticsearch"
      vb.memory = "4096"
      vb.cpus = 2
      file_to_disk2 = "extradisk2.vmdk"
      unless File.exist?(file_to_disk2)
        vb.customize [ "createmedium", "disk", "--filename", "extradisk2.vmdk", "--format", "vmdk", "--size", 1024 * 1 ]
    end
    vb.customize [ "storageattach", "elasticsearch" , "--storagectl", "SATA Controller", "--port", "2", "--device", "0", "--type", "hdd", "--medium", file_to_disk2]
    end
    elasticsearch.vm.network "forwarded_port", guest: 9200, host: 9200
    elasticsearch.vm.network "forwarded_port", guest: 5601, host: 5601
    # Agregar el script de provisionamiento para Elasticsearch
    elasticsearch.vm.provision "shell", path: "provision_elasticsearch.sh"
  end
end
