# System Monitoring and Problem Detection
!! Under Construction !!

## 1. First install Docker (instructions for Debian below).

a. Add Docker's official GPG key:
```
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```
b. Add the repository to Apt sources:

```sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
```
c. Update the system
sudo apt update

d. Install Latest Version:
```
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
e. Make sure that Docker is running:
```
sudo systemctl status docker
```

f. Test Installation:
```
sudo docker run hello-world
```

g. Add user to docker group (optional):
```
sudo usermod -aG docker $USER
```
h. Refresh the shell
```
newgrp docker
```

## 2. Create directory for prometheus.
```
mkdir <dir_name> && cd <dir_name>
```

## 3. Set up docker-compose.yaml for Prometheus
```nano docker-compose.yaml```

### Docker Compose .yaml file:
```
# Defines all Containers to be run
services:
  # Name of the service
  prometheus:
    # Download the official prometheus image from DockerHub
    image: prom/prometheus
    # Set container's name to 'prometheus' instead of auto-generated name
    container_name: prometheus
    # Override default command with custom flags
    command:
      # Tell prometheus where to find it's config file
      - "--config.file=/etc/prometheus/prometheus.yml"
      # Enable API Endpoints to reload config without restarting
      - "--web.enable-lifecycle"
    # Mounts files/directories into the docker container
    volumes:
      - ".prometheus.yml:/etc/prometheus/prometheus.yml"
      - "prometheus-data:/prometheus"
    ports:
      - 9090:9090
    restart: unless-stopped
volumes:
  # Docker-managed volume for persistent storage
  prometheus-data:
```

## 4. Create prometheus.yml and Point Scraper to sub-directory file_sd of <dir_name>
```
mkdir prometheus && cd prometheus
nano prometheus.yml
```
```prometheus.yml
# Global settings that apply to all scrape jobs
global:
  # Set interval 
  scrape_interval: 5s

# List all targets/services that Prometheus will monitor
scrape_configs:
  # Lable Scrape Job
  - job_name: 'prometheus'
    # File-Based service discovery (targets defined in ./file_sd/
    file_sd_configs:
      - files:
      # Path to file with prometheus node targets
      - /etc/prometheus/file_sd/prom_nodes.yml
        # How often to re-read the file for changes (allows for dynamic updates without restart)
        refresh_interval: 30s
```

- Create sub-directory file_sd/ in <dir_name> and make prom_nodes.yml
```
mkdir file_sd/ && cd file_sd/
nano prom_nodes.yml
```
 
- In file_sd create config files for each scraper job -> this and the '--web.enable-lifecycle' in docker-compose.yml make it so the docker container doesn't need to be restarted when new servers are added.
```
- targets:
    - <node_ip>:9100
  labels:
    instance: <display_name>
    hostname: <node_name>
    role: <type_of_node>
    env: <category_of_node>
    exporter: node
```
```
monitor/
├── docker-compose.yml
└── prometheus/
    ├── file_sd/
    │   ├── cpu_temp_exporter.yml
    │   ├── filebeat.yml
    │   ├── node_exporter.yml
    │   ├── proxmox.yml
    │   ├── smartctl_exporter.yml
    │   └── smartmon.yml
    └── prometheus.yml
```
- download prometheus node_exporter on target machine:
```  wget https://github.com/prometheus/node_exporter/releases/download/v1.10.2/node_exporter-1.10.2.linux-amd64.tar.gz ```
- Extract tarball:
``` tar xvfz nod_exporter-*.*-amd64.tar.gz && cd node_exporter-*.*-amd64 ```

- start prometheus node_exporeter on target mahcine:
``` ./node_exporter ```
- verify target machine is producing metrics:
``` curl http://localhost:9100/metrics ```


