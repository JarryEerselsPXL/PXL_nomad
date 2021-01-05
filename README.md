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

De software op de vm's worden geïnstalleerd via een Ansible playbook. Voor de installatie van de software met de Ansible playboek ga naar de volgende link: https://github.com/JarryEerselsPXL/PXL_nomad/tree/team18opdracht2



<h2>Nomad jobs</h2>

<h3>Prometheus job</h3>

De Prometheus job gaat op één van de nodes een Docker container starten met Prometheus, die gaat wordt opengesteld op poort 9090. In de job worden ook 2 templates gemaakt die Prometheus gaat gebruiken. Eén template is om Prometheus te configureren, de tweede template is om de Prometheus alerts op te stellen.

```bash
job "prometheus" {
    datacenters = ["dc1"]
    type        = "service"

    group "prometheus" {
  	    network {
  		    port "prometheus_ui" {
    	        to = 9090
      	         static = 9090
		    }
	    }
        service {
	        name = "prometheus"
            port = "prometheus_ui"
            tags = [
      	        "metrics"
            ]
        }
	    task "prometheus" {
            template {
                change_mode = "noop"
                destination = "local/prometheus.yml"

                data = <<EOH
---
global:
  scrape_interval:     5s
  evaluation_interval: 5s

alerting:
  alertmanagers:
  # List of Consul service discovery configurations.
  - consul_sd_configs:
    - server: '10.0.0.10:8500'
      services: ['alertmanager']

rule_files:
  - "/etc/alertmanager/infra.rules"

scrape_configs:

  - job_name: 'consul'

    consul_sd_configs:
    - server: '10.0.0.10:8500'
      services: ['consul-exporter']

    relabel_configs:
    - source_labels: [__meta_consul_service]
      target_label: job

    scrape_interval: 5s
    metrics_path: /metrics
    params:
      format: ['prometheus']

  - job_name: 'nomad_metrics'

    consul_sd_configs:
    - server: '10.0.0.10:8500'
      services: ['nomad', 'nomad-client']

    relabel_configs:
    - source_labels: [__meta_consul_tags]
      separator: ;
      regex: (.*)http(.*)
      replacement: $1
      action: keep
    - source_labels: [__meta_consul_address]
      separator: ;
      regex: (.*)
      target_label: __meta_consul_service_address
      replacement: $1
      action: replace

    scrape_interval: 5s
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']

  - job_name: 'nodes'

    consul_sd_configs:
    - server: '10.0.0.10:8500'
      services: ['node-exporter']

    relabel_configs:
    - source_labels: [__meta_consul_service]
      target_label: job
    
    scrape_interval: 5s
    metrics_path: /metrics
    params:
      format: ['prometheus']

  - job_name: 'prometheus'

    consul_sd_configs:
    - server: '10.0.0.10:8500'
      services: ['prometheus']

    relabel_configs:
    - source_labels: [__meta_consul_service]
      target_label: job
    
    scrape_interval: 5s
    metrics_path: /metrics
    params:
      format: ['prometheus']

  - job_name: 'alertmanager'

    consul_sd_configs:
    - server: '10.0.0.10:8500'
      services: ['alertmanager']

    relabel_configs:
    - source_labels: [__meta_consul_service]
      target_label: job

    scrape_interval: 5s
    metrics_path: /metrics
    params:
      format: ['prometheus']

  - job_name: 'webserver'

    consul_sd_configs:
    - server: '10.0.0.10:8500'
      services: ['apache-exporter']

    relabel_configs:
    - source_labels: [__meta_consul_service]
      target_label: job
    
    scrape_interval: 5s
    metrics_path: /metrics
    params:
      format: ['prometheus']
EOH
      }
            template {
                change_mode = "noop"
                destination = "local/infra.rules"
                data = <<EOH
groups:
  - name: Prometheus rules
    rules:
      - alert: PrometheusJobMissing
        expr: absent(up{job="prometheus"})
        for: 0m
        labels:
          severity: warning
        annotations:
          summary: Prometheus job missing 
          description: A Prometheus job has disappeared
      - alert: PrometheusTargetMissing
        expr: up == 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: Prometheus target missing 
          description: A Prometheus target has disappeared. An exporter might be crashed.
      - alert: PrometheusAllTargetsMissing
        expr: count by (job) (up) == 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: Prometheus all targets missing 
          description: A Prometheus job does not have living target anymore.
      - alert: PrometheusAlertmanagerConfigurationReloadFailure
        expr: alertmanager_config_last_reload_successful != 1
        for: 0m
        labels:
          severity: warning
        annotations:
          summary: Prometheus AlertManager configuration reload failure 
          description: AlertManager configuration reload error
      - alert: PrometheusNotConnectedToAlertmanager
        expr: prometheus_notifications_alertmanagers_discovered < 1
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: Prometheus not connected to alertmanager 
          description: Prometheus cannot connect the alertmanager
      - alert: PrometheusTargetEmpty
        expr: prometheus_sd_discovered_targets == 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: Prometheus target empty 
          description: Prometheus has no target in service discovery
      # Alert when an instance is down for 2 minutes
      - alert: instance_down_2m
        expr: absent(up{job="node-exporter"}) == 1
        for: 2m 
        labels: 
          severity: Critical
        annotations: 
          description: Instance prometheus DOWN for 2 minutes
          summary: Instance DOWN
      - alert: PrometheusAlertmanagerE2eDeadManSwitch
        expr: vector(1)
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: Prometheus AlertManager E2E dead man switch
          description: Prometheus DeadManSwitch is an always-firing alert. It's used as an end-to-end test of Prometheus through the Alertmanager
  - name: Node-exporter rules
    rules:
      - alert: HostOutOfMemory
        expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100 < 10
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: Host out of memory 
          description: Node memory is filling up (< 10% left)
      - alert: HostOutOfDiskSpace
        expr: (node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes < 10 and ON (instance, device, mountpoint) node_filesystem_readonly == 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: Host out of disk space 
          description: Disk is almost full (< 10% left)
      - alert: HostOutOfInodes
        expr: node_filesystem_files_free{mountpoint ="/rootfs"} / node_filesystem_files{mountpoint="/rootfs"} * 100 < 10 and ON (instance, device, mountpoint) node_filesystem_readonly{mountpoint="/rootfs"} == 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: Host out of inodes 
          description: Disk is almost running out of available inodes (< 10% left)
      - alert: HostHighCpuLoad
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100) > 80
        for: 0m
        labels:
          severity: warning
        annotations:
          summary: Host high CPU load 
          description: CPU load is > 80% 
  - name: Apache rules
    rules:  
      - alert: ApacheDown
        expr: apache_up == 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: Apache down
          description: Apache down
      - alert: ApacheRestart
        expr: apache_uptime_seconds_total / 60 < 1
        for: 0m
        labels:
          severity: warning
        annotations:
          summary: Apache restart 
          description: Apache has just been restarted.
  - name: Consul rules
    rules:
      - alert: ConsulServiceHealthcheckFailed
        expr: consul_catalog_service_node_healthy == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: Consul service healthcheck failed 
          description: Service:  Healthcheck: 
      - alert: ConsulAgentUnhealthy
        expr: consul_health_node_status{status="critical"} == 1
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: Consul agent unhealthy 
          description: A Consul agent is down
EOH
        }
            driver = "docker"
            config {
      	        image = "prom/prometheus:latest"
                ports = ["prometheus_ui"]
                logging {
                    type = "journald"
                    config {
          	            tag = "PROMETHEUS"
                    }
                }   
                volumes = [
                    "local/prometheus.yml:/etc/prometheus/prometheus.yml",
                    "local/infra.rules:/etc/alertmanager/infra.rules",       
                ]
            }
            resources {
      	        memory = 100
            }
  	    } 
    }
}

```

<h3>Node exporter</h3>

De node exporter job gaat op iedere node in de Nomad cluster een Docker container opspinnen met node exporters service. Met deze service kan Prometheus metrics uitlezen van de nodes.

```bash
job "node_exporter" {
    datacenters = ["dc1"]
    type        = "service"

    group "node-exporter" {
        count = 2
  	    network {
  		    port "node_exporter_port" {
    	        to = 9100
      	         static = 9100
			}
		}
        service {
	        name = "node-exporter"
            tags =  [
                "node_exporter", "metrics"
            ]
            port = "node_exporter_port"
        }
	    task "node_exporter" {
            driver = "docker"
            config {
      	        image = "prom/node-exporter:latest"
                ports = ["node_exporter_port"]
                logging {
        	        type = "journald"
                    config {
          	            tag = "NODE_EXPORTER"
                    }
                }
            }
            resources {
      	        memory = 100
            }  
  	    } 
    }
}
```
´

<h3>Alertmanager</h3>

Deze job gaat op één van de nodes een Docker container draaien met de alertmanager. In de job wordt er een template gemaakt met de configuratie van de alertmanager. 
Hierin gaan we bijvoorbeeld een webbook configureren.

```bash
job "alertmanager" {
	datacenters = ["dc1"]
    type        = "service"

    group "alertmanager" {
        count = 1
  	    network {
  		    port "alertmanager_ui" {
    	    to = 9093
      	     static = 9093
			}
		}
        service {
	        name = "alertmanager"
            port = "alertmanager_ui"
            tags = [
      	        "metrics"
            ]
        }
	    task "alertmanager" {
             template {
                change_mode = "noop"
                destination = "local/alertmanager.yml"
                data = <<EOH
global:
  # The smarthost and SMTP sender used for mail notifications.

# The directory from which notification templates are read.
templates: 
- '/etc/alertmanager/template/*.tmpl'

# The root route on which each incoming alert enters.
route:
  group_by: ['alertname']
  group_wait: 20s
  group_interval: 5m
  repeat_interval: 3h 
  receiver: discord_webhook

receivers:
- name: 'discord_webhook'
  webhook_configs:
  - url: 'http://10.0.0.12:9094'
  - url: 'http://10.0.0.11:9094'
EOH
      }
            driver = "docker"
            config {
      	        image = "prom/alertmanager:latest"
                ports = ["alertmanager_ui"]
                logging {
        	        type = "journald"
                    config {
          	            tag = "ALERTMANAGER"
                    }
                }
                volumes = [
                    "local/alertmanager.yml:/etc/alertmanager/alertmanager.yml",     
                ]
            }
            resources {
      	        memory = 100
            }
  	    }       
    }
}
```

<h3>Grafana</h3>

De Grafana job gaat op één van de nodes een Docker container draaien met de Grafana service. Deze wordt gebruikt om de Prometheus metrics te visualizeren met dashboards.
Alle dashboards die we gaan gebruiken staan de in de map /grafana dashboards. 

```bash
job "grafana" {
    datacenters = ["dc1"]
    type        = "service"

    group "grafana" {
        count = 1
  	    network {
  		    port "grafana_ui" {
    	        to = 3000
      	         static = 3000
			}
		}
        service {
	        name = "grafana"
        }
	    task "grafana" {
            driver = "docker"
            config {
      	        image = "grafana/grafana:latest"
                ports = ["grafana_ui"]
                logging {
        	        type = "journald"
                    config {
          	            tag = "GRAFANA"
                    }
                }
            } 
  	    } 
    }
}
```

<h3>Consul exporter</h3>

De node exporter job gaat op een node in de Nomad cluster een Docker container opspinnen met Consul exporter service. Met deze service kan Prometheus metrics uitlezen van de Consul server.

```bash
job "consul_exporter" {
    datacenters = ["dc1"]
    type        = "service"

    group "consul-exporter" {
        count = 1
  	    network {
  		    port "consul_exporter_port" {
    	        to = 9107
      	         static = 9107
			}
		}
        service {
	        name = "consul-exporter"
            tags =  [
                "consul_exporter", "metrics"
            ]
            port = "consul_exporter_port"
        }
	    task "consul_exporter" {
            driver = "docker"
            config {
      	        image = "prom/consul-exporter:latest"
                ports = ["consul_exporter_port"]
                args = [
                    "--consul.server=10.0.0.10:8500",
                ]
                logging {
        	        type = "journald"
                    config {
          	            tag = "CONSUL_EXPORTER"
                    }
                }
            }
            resources {
      	        memory = 100
            } 
  	    } 
    }
}
```

<h3>Apache exporter</h3>

De node exporter job gaat op iedere node in de Nomad cluster een Docker container opspinnen met Apache exporters service. Met deze service kan Prometheus metrics uitlezen van de Apache containers die op de nodes worden gedraaid met de webserverjob.

```bash
job "apache_exporter" {
    datacenters = ["dc1"]
    type        = "service"
    constraint {
        distinct_hosts = true
    }
    group "apache-exporter" {
        count = 2
  	    network {
  		    port "apache_exporter_port" {
    	        to = 9117
      	         static = 9117
			}
		}
        service {
	        name = "apache-exporter"
            tags =  [
                "apache_exporter", "metrics"
            ]
            port = "apache_exporter_port"
        }
	    task "apache_exporter" {
            driver = "docker"
            config {
      	        image = "bitnami/apache-exporter:latest"
                ports = ["apache_exporter_port"]
                args = [
                    "--scrape_uri=http://${attr.unique.network.ip-address}:22222/server-status/?auto",
                ]
                logging {
        	        type = "journald"
                    config {
          	            tag = "APACHE_EXPORTER"
                    }
                }
            }
            resources {
      	        memory = 100
            } 
  	    } 
    }
}
```

<h3>webserverjob</h3>

Met de webserverjob wordt op iedere node in de Nomad cluster een Docker container opgespind met httpd/apache. 
Het is een simpele website die we als extra applicatie gekozen hebben.


```bash
job "webserver" {
    datacenters = ["dc1"]
    type        = "service"

    group "webserver" {
        count = 2
  	    network {
  		    port "webserver_port" {
    	        to = 80
      	         static = 22222
			}
		}
        service {
	        name = "webserver"
            tags =  [
                "webserver"
            ]
            port = "webserver_port"
        }
	    task "webserver" {
            driver = "docker"
            config {
      	        image = "jarryeerselspxl/httpd-apache_exporter:latest"
                ports = ["webserver_port"]
                logging {
        	        type = "journald"
                    config {
          	            tag = "WEBSERVER"
                    }
                }
            } 
  	    } 
    }
}


```

<h3>DiscordAlerts</h3>

Met de DiscordAlerts job gaan we op één van de nodes een Docker container opspinnen. Deze gaat ervoor zorgen dat de alerts die binnenkomen op de Alertmanager gepusht worden naar een Discord server.


```bash
job "discordAlerts" {
    datacenters = ["dc1"]
    type        = "service"

    group "discordAlerts" {
        count = 1
  	    network {
  		    port "discordAlerts_port" {
    	        to = 9094
      	         static = 9094
			}
		}
        service {
	        name = "discordAlerts"
            tags =  [
                "discordAlerts", "alertmanager"
            ]
            port = "discordAlerts_port"
        }
	    task "discordAlerts" {
            driver = "docker"
            config {
      	        image = "benjojo/alertmanager-discord"
                ports = ["discordAlerts_port"]
                logging {
        	        type = "journald"
                    config {
          	            tag = "DISCORDALERTS"
                    }
                }
            }
            env {
                DISCORD_WEBHOOK = "https://discord.com/api/webhooks/795038213613027348/humqlVLtuMyFDtwxjiGIJdtWVpaP7jxMTJmFBE74KTInrjHWJZxOeAgKzxFIZ0iMl4CN"
            } 
  	    } 
    }
}
```

<h2>Grafana Dashboards</h2>

In deze map zitten een aantal JSON bestanden die verschillende dashboards gaat aanmaken voor onze Prometheus metrics. 
We hebben een dashboard voor Consul, Nomad, de Nomad jobs, de Apache exporter en voor de node exporter.



Verdeling van de taken:

- De Prometheus job Jarry
- De node exporter Jarry
- Alert manager Jarry
- Discord alert Jarry
- Webserver job Niels
- Grafana Niels
- Consul exporter beide teamleden
- Apache exporter beide teamleden
- Dashboards beide teamleden


Bronnen:

- https://prometheus.io/docs/introduction/overview/
- https://github.com/benjojo/alertmanager-discord
- https://www.consul.io/
- https://www.nomadproject.io/
- https://github.com/prometheus/consul_exporter
- https://github.com/prometheus/node_exporter
- https://www.nomadproject.io/docs/operations/telemetry
- https://grafana.com/
- https://github.com/Lusitaniae/apache_exporter
- https://github.com/samber/awesome-prometheus-alerts
- https://awesome-prometheus-alerts.grep.to/rules.html