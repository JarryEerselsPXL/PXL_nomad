#!/bin/bash

sudo mv /vagrant/client_hcl/nomad.hcl /etc/nomad.d/nomad.hcl
sudo mv /vagrant/client_hcl/consul.hcl /etc/consul.d/consul.hcl
echo bind_addr = \"`ip a s eth1 | awk '/inet / {print$2}'| cut -d/ -f1`\" | sudo tee -a /etc/consul.d/consul.hcl
sudo dos2unix /etc/consul.d/consul.hcl
sudo systemctl start nomad
sudo systemctl enable nomad
sudo systemctl start consul
sudo systemctl enable consul