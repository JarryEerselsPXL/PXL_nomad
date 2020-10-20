# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"
BOX_IMAGE = "centos/7"
CLIENT_COUNT = 2

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.provider :virtualbox do |virtualbox, override|
    virtualbox.customize ["modifyvm", :id, "--memory", 2048]
  end

  config.vm.define "server" do |server|
    server.vm.box = BOX_IMAGE
	  server.vm.hostname = "server"
    server.vm.network :private_network, ip: "10.0.0.10"
    server.vm.provision "shell", path: "scripts/agentServer.sh"
  end
  
  
  (1..CLIENT_COUNT).each do |i|
    config.vm.define "client#{i}" do |client|
      client.vm.box = BOX_IMAGE
	    client.vm.hostname = "client#{i}"
      client.vm.network :private_network, ip: "10.0.0.#{i + 10}"
      client.vm.provision "shell", path: "scripts/agentClient.sh" 
    end	
  end
  
  # Install Docker / Consul / Nomad
	config.vm.provision "shell", path: "scripts/install.sh" 

end

