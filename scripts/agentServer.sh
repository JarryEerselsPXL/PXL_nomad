#!/bin/bash

sudo mv /vagrant/server_hcl/nomad.hcl /etc/nomad.d/nomad.hcl
sudo mv /vagrant/server_hcl/consul.hcl /etc/consul.d/consul.hcl
sudo systemctl start nomad
sudo systemctl enable nomad
sudo systemctl start consul
sudo systemctl enable consul
sudo cp /vagrant/jobs/webserverjob.txt /home/vagrant/webserver.nomad
sudo dos2unix /home/vagrant/webserver.nomad

