# Nomad consul

The aim of this project is to provide a development environment based on [consul](https://www.consul.io) and [nomad](https://www.nomadproject.io) to manage container based microservices.

The following steps should make that clear;

bring up the environment by using [vagrant](https://www.vagrantup.com) which will create centos 7 virtualbox machine or lxc container.

The proved working vagrant providers used on an [ArchLinux](https://www.archlinux.org/) system are
* [vagrant-lxc](https://github.com/fgrehm/vagrant-lxc)
* [vagrant-libvirt](https://github.com/vagrant-libvirt/)
* [virtualbox](https://www.virtualbox.org/)

```bash
    $ vagrant up --provider lxc
    OR
    $ vagrant up --provider libvirt
    OR
    $ vagrant up --provider virtualbox
```

Once it is finished, you should be able to connect to the vagrant environment through SSH and interact with Nomad:

```bash
    $ vagrant ssh
    [vagrant@nomad ~]$
```

Team 18 Linux PE
Teamleden: Jarry Eersels & Niels Dewolf

Doel van de PE is een Een productie waardige nomad cluster met consul als service discovery en docker als driver installeren, configureren en starten door gebruik te maken van de vagrant shell provisioner in een vagrant multi machine omgeving. 

In de vagrantfile worden 3 vm's aangemaakt waarvan eentje zal dienen als nomad server en de overige 2 als nomad agent. Op al deze vm's worden Docker, Consul en Nomad geïnstalleerd aan de hand van het script install.sh. 
Er wordt ook dos2unix geïnstalleerd om later Windows files te kunnen overzetten op de vm's zonder parsing errors.

Na de installatie van Docker, Consul, Nomad en dos2unix worden de agents van Consul en Nomad geconfigureerd aan de hand van 2 scripts. 
De server gebruikt het agentServer.sh script en de nodes gebruiken het agentClient.sh script. Deze scripts gaan de voorafgemaakte configuratiefiles op de juiste plaats zetten in de vm's en de Nomad en Consul agents starten.

De nomad server consul configuratie is zo geconfigureerd dat de nomad agents automatisch joinen.
Ook wordt er tijdens het agentServer.sh script ook al een webserver job file aangemaakt zodat deze makkelijk te runnen is met 1 commando.

Bronnen:
https://manski.net/2016/09/vagrant-multi-machine-tutorial/
https://www.vagrantup.com/docs/multi-machine
https://www.consul.io/docs/agent/options.html
https://www.nomadproject.io/docs/configuration
https://learn.hashicorp.com/tutorials/consul/get-started-create-datacenter