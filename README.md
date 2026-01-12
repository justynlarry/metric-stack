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
  scrape_interval: 15s

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

- Create the docker container:
```cd <dir_name> ```
```docker-compose up -d --build```
### Tree structure
```
monitor/
├── docker-compose.yml
├── loki/
│   └── local-config.yaml
├── promtail/
│   └── config.yml
└── prometheus/
    ├── file_sd/
    │   ├── <example_exporter>.yml
    │   ├── filebeat.yml
    │   ├── node_exporter.yml
    │   ├── <example_exporter>.yml
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

## 5. Add Grafana to docker-compose.yml:
```nano docker-compose.yml```
```
  grafana:
    image: grafana/grafana
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana-storage:/var/lib/grafana
    restart: unless-stopped

volumes:
  grafana-storage:
```
- Tear down the docker container
```docker-compose down```
- Rebuild the container for Prometheus and Grafana:
```docker-compose up -d --build```

## 6.  Log in to Grafana in web browser:
```http:://<host_IP_Address>:3000```
- create username and password
- set up prometheus endpoint
- create graphs

## PHASE 2: Promtail and Loki
- add Loki and Promtail to Docker Compose:
```
# Promtail
  promtail: grafana/promtail:latest
  container_name: promtail
  command:
    - "-config.file=/home/stack-user/promtail/config.yml"
    - "- config.enable-api" # Enable reload endpoint
  volumes:
    - ./promtail/config.yml:/etc/promtail/config.yml
    - ./promtail/file_sd:/etc/promtail/file_sd
    - ./var/log:/var/log:ro
    - promtail-positions:/var/lib/promtail
  ports:
    - "9080:9080"
  networks:
    - loki
  restart: unless-stopped

# Loki
  loki:
    image: grafana/loki:latest
    container_name: loki
    volumes:
      - ./loki/config.yml:/etc/loki/local-config.yaml
      - loki-data:/loki
    ports:
      - "3100:3100"
    networks:
      - loki
    restart: unless-stopped
volumes:
  promtail-positions:
  loki-data:

networks:
  loki:
    driver: bridge
```

- Add Loki and Promtail config files:

```cd <dir_name> && nano docker-copmose.yml```
```
# Loki

# Disable authentication, so anyone can send logs to or query from thie Loki Instance (starter setup)
auth_enabled: false

# Listen for HTTP requests on port 3100
server:
  http_listen_port: 3100

# Shared settings used across multiple Loki Components
common:
  # Base directory where Loki stores its data
  path_prefix: /loki
  # Define how logs are stored
  storage:
    filesystem:
      # Where actual log data (chunks) is stored
      chunks_directory: /loki/chunks
      # Where alerting/recording rules are stored
      rules_directory: /loki/rules
  # Data is stored in only one copy (starter setup)
  replication_factor: 1
  # Configuration for Loki's has ring (used for distributing work)
  ring:
    # Ring state is kept in memory rather than a separate database like Consul or etcd
    kvstore:
      store: inmemory

# Defines how logs are indexed and stored
schema_config:
  configs:
    # Applies to all logs from Jan 1, 2023 onward
    - from: 2023-01-01
      # Used BoltDB for the index (a single=file database)
      store: boltdb-shipper
      # Stores chunks on the local filesystem
      object_store: filesystem
      schema: v11
      index:
        # Index files will be named starting with 'index_'
        prefix: index_
        # A new index file is created every 24 hours
        period: 24h

limits_config:
  # Logs are automatically deleted after 30 days
  retention_period: 30d
```
Promtail
```
# Promtail
# Listen on port 9080 and disable gRPC
server:
  http_listen_port: 9080
  grpc_listen_port: 0

# Tracks where Promtail stopped reading each log file -> bookmark
positions:
  filename: /tmp/positions.yaml

# Where to send the collected file logs -> Loki server's push endpoint
#  Needs to be modified if multiple Loki instances are running
clients:
  - url: http://loki:3100/loki/api/v1/push

# Define what logs to collect
scrape_configs:
  # Name for collection job
  - job_name: <job_name>
    # Static list of targets -> adjust for auto pickup
    file_sd_configs:
      - files:
          - /etc/promtail/file_sd/*.yml
        refresh_interval: 30s

```
- Create file_sd/system.yml 
### Look deeper into using MinIO to distribute across multiple instances:
```
auth_enabled: false
server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    s3:
      endpoint: minio.yourdomain.local:9000  # Your MinIO endpoint
      bucketnames: loki-data
      access_key_id: minioadmin  # Change these!
      secret_access_key: minioadmin
      s3forcepathstyle: true  # Important for MinIO!
      insecure: false  # Set to true if not using HTTPS
  replication_factor: 3
  ring:
    kvstore:
      store: memberlist  # Good option for small clusters

memberlist:
  join_members:
    - loki-1:7946  # Your Loki instances
    - loki-2:7946
    - loki-3:7946

schema_config:
  configs:
    - from: 2023-01-01
      store: boltdb-shipper
      object_store: s3  # Uses MinIO via S3 API
      schema: v11
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 7d
```
- Create /promtail/file_sd/nginx.yml
```
- targets:
    - ${HOStNAME}
  labels:
    job: nginx
    container: nginx
    __path__: /var/log/nginx/*.log
```

- Add Nginx to the docker-compose.yml:
```
  nginx:
    image: nginx:latest
    conatiner_name: nginx
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/html:/usr/share/nginx/html:ro
      - nginx-logs:/var/log/nginx
    ports:
      - "80:80"
      - "443:443"
    networks:
      - web
    restart: unless-stopped
```

```
┌─────────────────────────────────────────────────────────────────┐
│                        Docker Network                            │
│                                                                   │
│  ┌──────────┐         ┌──────────┐         ┌──────────┐        │
│  │  Nginx   │────────▶│ Grafana  │◀────────│  Users   │        │
│  │  :80     │  Proxy  │  :3000   │   Web   │ (Browser)│        │
│  │  :443    │         └──────────┘         └──────────┘        │
│  └──────────┘              │    │                                │
│       │                    │    │                                │
│       │ Logs               │    │                                │
│       │                    │    └──────────────┐                │
│       ▼                    │                   │                │
│  ┌──────────┐              │ Queries           │ Queries        │
│  │ Promtail │──Push logs──▶│                   │                │
│  │  :9080   │              │                   │                │
│  └──────────┘              ▼                   ▼                │
│       │                ┌──────────┐       ┌────────────┐        │
│       │                │   Loki   │       │ Prometheus │        │
│       │                │  :3100   │       │   :9090    │        │
│       │                └──────────┘       └────────────┘        │
│       │                    │                   ▲                │
│       │                    │ Stores            │ Scrapes        │
│       │                    ▼                   │                │
│       │                ┌──────────┐            │                │
│       │                │  MinIO   │            │                │
│       │                │  :9000   │            │                │
│       │                └──────────┘            │                │
│       │                                        │                │
│       └──Reads logs from──────────────────────┘                │
│          (nginx, apps,                                           │
│           prometheus, loki)                                      │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

DATA FLOW:
1. Nginx → generates access/error logs
2. Promtail → reads those logs + scrapes Prometheus/Loki metrics
3. Promtail → pushes logs to Loki
4. Loki → stores logs in MinIO (or local storage)
5. Prometheus → scrapes metrics from all services (including itself)
6. Grafana → queries Loki for logs, queries Prometheus for metrics
7. Nginx → reverse proxies user requests to Grafana
8. Users → access Grafana via Nginx (SSL termination)
```





**Key settings for MinIO:**
- `s3forcepathstyle: true` - MinIO uses path-style URLs instead of virtual-hosted-style
- `endpoint:` - Your MinIO server address (not AWS)
- `insecure: true` - If you're not using TLS (not recommended for production)

## Architecture Overview
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Loki-1     │────▶│  Loki-2     │────▶│  Loki-3     │
│ (Ingester)  │     │ (Ingester)  │     │ (Ingester)  │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                           ▼
                  ┌────────────────┐
                  │  MinIO Cluster │
                  │  (4 VMs with   │
                  │   replication) │
                  └────────────────┘
```

- Create loki and promtail sub-directories
``` mkdir loki promtail```
- create local-config.yaml
```cd loki && nano local-config.yaml```
- create promtail config.yaml
```cd promtail && nano config.yaml```









<This may be a bit heavy out of the gate, promtail-Loki may be a better, more lightweight starter option>
# Phase X:  Filebeat & ElasticSearch
## 1.  Install ElasticSearch Client as docker container
- create the .env file for passwords (exclude from GitHub if applicable)
```cd <dir_name> && nano .env```
```
# Project namespace (defaults to the current folder name if not set)
COMPOSE_PROJECT_NAME=<project-name>

# Password for the 'elastic user (minimum 6 characters)
ELASTIC_PASSWORD=<password>

# Version of Elastic Products
STACK_VERSION=8.7.1

# Set the Cluster Name
CLUSTER_NAME=<cluster_name>

LICENSE=basic

# Port to expose Elasticsearch HTTP API to the host
ES_PORT=5601

# Increase or decrease based on teh available host memory (in bytes)
ES_MEM_LIMIT=1073741824
KB_MEM_LIMIT=1073741824
LS_MEM_LIMIT=1073741824

```


- edit docker-compose.yml:
```cd <dir_name>```
```nano docker-compose.yml```
```
  elasticsearch:
    image: elasticsearch/elasticsearch
    container_name: elasticsearch
    ports:
      - "9200:9200"
    volumens:
      - elasticsearch:
```

- Install Filebeat on Client
```curl -L -o https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-9.2.3-adm64.deb```
```sudo dpkg -i filebeat-9.2.3-amd64.deb```

# Proposed Final Directory Structure:
```
/home/stack-user/monitor/
├── docker-compose.yml
├── .env
│
├── nginx/
│   ├── nginx.conf
│   ├── conf.d/
│   │   ├── grafana.conf
│   │   └── default.conf
│   ├── ssl/
│   │   ├── cert.pem
│   │   └── key.pem
│   └── html/
│       └── index.html
│
├── grafana/
│   ├── grafana.ini
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   ├── loki.yml
│   │   │   └── prometheus.yml
│   │   └── dashboards/
│   │       ├── dashboard.yml
│   │       └── dashboards/
│   │           ├── nginx-dashboard.json
│   │           └── system-dashboard.json
│   └── data/              # Created by Docker volume
│
├── loki/
│   ├── config.yml
│   └── data/              # Created by Docker volume
│
├── prometheus/
│   ├── prometheus.yml
│   ├── alerts/
│   │   └── rules.yml
│   ├── file_sd/
│   │   ├── services.yml
│   │   └── containers.yml
│   └── data/              # Created by Docker volume
│
├── promtail/
│   ├── config.yml
│   ├── file_sd/
│   │   ├── nginx.yml
│   │   ├── loki.yml
│   │   ├── prometheus.yml
│   │   └── grafana.yml
│   └── positions/         # Created by Docker volume
│
└── minio/                 # Optional - for S3-compatible storage
    ├── config/
    └── data/              # Created by Docker volume
```
