# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"
BOX_IMAGE = "centos/7"
NODE_COUNT = 2

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vbguest.auto_update = false
  config.vm.box = "centos/7"

  config.vm.provider :virtualbox do |virtualbox, override|
    virtualbox.customize ["modifyvm", :id, "--memory", 2048]
  end

  config.vm.define :server do |server|
    server.vm.hostname = "server"
    server.vm.network "private_network", ip: "10.0.0.10"
  end

 (1..NODE_COUNT).each do |i|
  config.vm.define :"node#{i}" do |node|
    node.vm.box = BOX_IMAGE
    node.vm.hostname = "node#{i}"
    node.vm.network :private_network, ip: "10.0.0.#{i + 10}"
  end	
end

 config.vm.provision "ansible_local" do |ansible|
  ansible.config_file = "ansible/ansible.cfg"
  ansible.playbook = "ansible/plays/server.yml"
  ansible.groups = {
    "servers" => ["server"],
    "servers:vars" => {"consul_master" => "yes", "consul_join" => "no", 
    "consul_server"=> "yes", "private_ip" => "10.0.0.10", "nomad_master" => "yes",
    "nomad_server" => "yes"},
    "nodes" => ["node1", "node2"],
    "nodes:vars" => {"consul_master" => "no", "consul_join" => "yes", 
    "consul_server"=> "no", "private_ip" => "10.0.0.11", "nomad_master" => "no",
    "nomad_server" => "no"},
  }
  end
 
end

