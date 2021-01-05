# Team 18 Linux PE 2
Teamleden Jarry Eersels & Niels Dewolf

<h2> Installatie en Configuratie </h2>
Met volgend commando starten 3 virtuele machines op, 1 server en 2 nodes.

```bash
    $ vagrant up
```

Deze server en nodes worden aan de hand van een Vagrantfile opgestart.
In de Vagrantfile worden volgende delen behandeld:

- Statische IP's toevoegen aan elke virtuele machine.
- Het runnen van een Ansible playbook op alle vm's
- Forwarden van de Nomad port van de server vm
- Forwarden van de Consul port van de server vm

```bash
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
    server.vm.network "forwarded_port", guest_ip: "10.0.0.10", guest: 4646, host: 4646, auto_correct: true, host_ip: "127.0.0.1"
    server.vm.network "forwarded_port", guest: 8500, host: 8500, auto_correct: true, host_ip: "127.0.0.1"
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
    ansible.playbook = "ansible/plays/play.yml"
    ansible.groups = {
      "servers" => ["server"],
      "servers:vars" => {"consul_master" => "yes", "consul_join" => "no", 
      "consul_server"=> "yes", "nomad_master" => "yes", "nomad_server" => "yes"},
      "nodes" => ["node1", "node2"],
      "nodes:vars" => {"consul_master" => "no", "consul_join" => "yes", 
      "consul_server"=> "no", "nomad_master" => "no", "nomad_server" => "no"},
    }
  end

end
```

De software op de vm's worden geïnstalleerd via een Ansible playbook. Op de server wordt Nomad en Consul geïnstalleerd en op de nodes Nomad, Consul en Docker.

Hiervoor wordt volgende playbook gebruikt:

```bash
---
- name: playbook for server vm
  hosts: servers
  become: yes

  roles:
    - role: software/consul
    - role: software/nomad

- name: playbook for node vm
  hosts: nodes
  become: yes

  roles:
    - role: software/docker
    - role: software/consul
    - role: software/nomad
```

Om de software te kunnen isntalleren voeren de roles volgende tasks uit:

Consul:

```bash
---
- name: Add Consul repository
  yum_repository:
    name: consul
    description: add consul repository
    baseurl: https://rpm.releases.hashicorp.com/RHEL/$releasever/$basearch/stable
    gpgkey: https://rpm.releases.hashicorp.com/gpg

- name: Install Consul
  yum:
    name: consul
    state: present

- name: Template Consul file
  template:
    src: consul.hcl.j2
    dest: /etc/consul.d/consul.hcl

- name: Start consul service
  systemd:
    name: consul
    state: restarted
    enabled: yes
```

Nomad:

```bash
---
- name: Add Nomad repository
  yum_repository:
    name: nomad
    description: add nomad repository
    baseurl: https://rpm.releases.hashicorp.com/RHEL/$releasever/$basearch/stable
    gpgkey: https://rpm.releases.hashicorp.com/gpg

- name: Install Nomad
  yum:
    name: nomad
    state: present

- name: Create a directory if it does not exist
  file:
    path: /opt/nomad/
    state: directory
    mode: '0755'

- name: Template Nomad file
  template:
    src: nomad.hcl.j2
    dest: /etc/nomad.d/nomad.hcl

- name: Start nomad service
  systemd:
    name: nomad
    state: restarted
    enabled: yes
```

Docker

```bash
---
- name: Add Docker repository
  yum_repository:
    name: docker-ce
    description: docker repo
    baseurl: https://download.docker.com/linux/centos/$releasever/$basearch/stable
    gpgkey: https://download.docker.com/linux/centos/gpg

- name: Install Docker
  yum:
    name: docker-ce
    state: present
  become: yes

- name: Start Docker service
  service:
    name: docker
    state: started
    enabled: yes
  become: yes

- name: Add user vagrant to docker group
  user:
    name: vagrant
    groups: docker
    append: yes
  become: yes
```

Om Nomad en Consul te configueren wordt in de roles volgende .j2 scipts geïmporteerd:

Consul:

```bash
datacenter = "dc1",
enable_syslog = true,
client_addr = "0.0.0.0",
bind_addr = "{{ ansible_eth1.ipv4.address }}",
rejoin_after_leave = true,
ui = true,
{% if consul_master == "yes" %}
bootstrap_expect = {{ groups['servers'] | length }},
{% endif %}
{% if consul_join == "yes" %}
start_join = [ "10.0.0.10" ],
{% endif %}
data_dir = "/opt/consul/",
{% if consul_server == "yes" %}
server = true
{% else %}
server = false
{% endif %}    
```

Nomad:
```bash
datacenter = "dc1",
data_dir = "/opt/nomad/{{ inventory_hostname }}",
bind_addr = "{{ ansible_eth1.ipv4.address }}",
{% if nomad_server == "yes" %}
server {
    enabled = true,
{% if nomad_master == "yes" %}
    bootstrap_expect = {{ groups['servers'] | length }},
{% endif %}
}
{% else %}
client {
    enabled = true,
    servers = [ "10.0.0.10" ],
    network_interface = "eth1",
}
{% endif %}
```

Verdeling van de taken:

- De eerste versie van Consul en Docker zijn geschreven door Jarry.
- De eerste versie van Nomad is geschreven door Niels.
- De Vagrentfile is geschreven door beide teamleden.
- De verbeteringen van de scripts zijn gedaan door beide teamleden.

Bronnen:

- https://github.com/visibilityspots/PXL_nomad/tree/master/ansible
- https://github.com/fhemberger/nomad-demo
- https://github.com/nickvth/ansible-consul-nomad
- https://www.consul.io/
- https://www.nomadproject.io/
- https://www.vagrantup.com/docs/provisioning/ansible