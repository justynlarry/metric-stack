# System Monitoring Stack - Complete Setup Guide

## Stack Components: Prometheus + Grafana + Loki + Promtail + Nginx + MinIO
## Phase 1: Install Docker
### 1. Add Docker's official GPG key:
bash
```
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```
### 2. Add the repository to Apt sources:

bash
```
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```
### 3. Update and install Docker:

bash
```
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
### 4. Verify Docker is running:

bash
```
sudo systemctl status docker
```
### 5. Test installation:

bash
```
sudo docker run hello-world
```
### 6. Add user to docker group (optional but recommended):

bash
```
sudo usermod -aG docker $USER
newgrp docker
```
## Phase 2: Create Directory Structure
### 1. Create base directory:

bash
```
mkdir -p /home/stack-user/monitor && cd /home/stack-user/monitor
```
### 2. Create all subdirectories:

bash
```
mkdir -p prometheus/file_sd
mkdir -p promtail/file_sd
mkdir -p loki
mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards
mkdir -p nginx/conf.d
mkdir -p minio/data
```

### 3. Create .env file

bash
```
# Grafana Credentials
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=<grafana_password>

# MinIO Credientials
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=<minio_password>

# Loki MinIO Access (should match MinIO Credentials)
LOKI_S3_ACCESS_KEY=minioadmin
LOKI_S3_SECRET_KEY=<minio_password>

# Prometheus Retention (how many days data is kept)
PROMETHEUS_RETENTION=30d


```

## Final directory structure:
```
/home/stack-user/monitor/
├── docker-compose.yml
├── .env
├── prometheus/
│   ├── prometheus.yml
│   └── file_sd/
│       ├── prom_nodes.yml
│       └── (other exporter configs)
├── promtail/
│   ├── config.yml
│   └── file_sd/
│       ├── nginx.yml
│       ├── system.yml
│       └── (other log sources)
├── loki/
│   └── config.yml
├── grafana/
│   ├── grafana.ini (optional)
│   └── provisioning/
│       ├── datasources/
│       │   ├── loki.yml
│       │   └── prometheus.yml
│       └── dashboards/
│           └── dashboard.yml
├── nginx/
│   ├── nginx.conf (optional)
│   └── conf.d/
│       └── grafana.conf
└── minio/
    └── data/
```

## Phase 3: Create Configuration Files
1. Docker Compose - Main Stack Definition

Create: /home/stack-user/monitor/docker-compose.yml

yaml
```
version: '3.8'

services:
  # Prometheus - Metrics collection and alerting
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
      - '--storage.tsdb.retention.time=${PROMETHEUS_RETENTION:-30d}'
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/file_sd:/etc/prometheus/file_sd:ro
      - prometheus-data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - monitoring
    restart: unless-stopped

  # Grafana - Visualization and dashboards
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=http://localhost:3000
      - GF_INSTALL_PLUGINS=
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - grafana-data:/var/lib/grafana
    ports:
      - "3000:3000"
    networks:
      - monitoring
    restart: unless-stopped
    depends_on:
      - prometheus
      - loki

  # MinIO - S3-compatible object storage for Loki
  minio:
    image: minio/minio:latest
    container_name: minio
    command: server /data --console-address ":9001"
    environment:
      - MINIO_ROOT_USER=${MINIO_ROOT_USER:-minioadmin}
      - MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-minioadmin}
    volumes:
      - minio-data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    networks:
      - monitoring
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3

  # Loki - Log aggregation system
  loki:
    image: grafana/loki:latest
    container_name: loki
    command: -config.file=/etc/loki/local-config.yaml
    environment:
      - LOKI_S3_ACCESS_KEY=${LOKI_S3_ACCESS_KEY:-minioadmin}
      - LOKI_S3_SECRET_KEY=${LOKI_S3_SECRET_KEY:-minioadmin}
    volumes:
      - ./loki/config.yml:/etc/loki/local-config.yaml:ro
      - loki-data:/loki
    ports:
      - "3100:3100"
    networks:
      - monitoring
    restart: unless-stopped
    depends_on:
      minio:
        condition: service_healthy

  # Promtail - Log collector and shipper
  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    command:
      - "-config.file=/etc/promtail/config.yml"
      - "-config.enable-api"
    volumes:
      - ./promtail/config.yml:/etc/promtail/config.yml:ro
      - ./promtail/file_sd:/etc/promtail/file_sd:ro
      - /var/log:/var/log:ro
      - nginx-logs:/var/log/nginx:ro
      - promtail-positions:/var/lib/promtail
    ports:
      - "9080:9080"
    networks:
      - monitoring
    restart: unless-stopped
    depends_on:
      - loki

  # Nginx - Reverse proxy and web server
  nginx:
    image: nginx:alpine
    container_name: nginx
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - nginx-logs:/var/log/nginx
    ports:
      - "80:80"
      - "443:443"
    networks:
      - monitoring
    restart: unless-stopped
    depends_on:
      - grafana

volumes:
  prometheus-data:
    driver: local
  grafana-data:
    driver: local
  loki-data:
    driver: local
  promtail-positions:
    driver: local
  nginx-logs:
    driver: local
  minio-data:
    driver: local

networks:
  monitoring:
    driver: bridge
```
### 2. Prometheus Configuration

Create: /home/stack-user/monitor/prometheus/prometheus.yml

yaml
```
# Global settings that apply to all scrape jobs
global:
  # How often to scrape targets
  scrape_interval: 15s
  # How often to evaluate alerting rules
  evaluation_interval: 15s

# List all targets/services that Prometheus will monitor
scrape_configs:
  # Monitor Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Monitor Grafana
  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']

  # Monitor Loki
  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']

  # Monitor Promtail
  - job_name: 'promtail'
    static_configs:
      - targets: ['promtail:9080']

  # Monitor MinIO
  - job_name: 'minio'
    static_configs:
      - targets: ['minio:9000']

  # File-based service discovery for node_exporter
  - job_name: 'nodes'
    file_sd_configs:
      - files:
          - /etc/prometheus/file_sd/prom_nodes.yml
        # How often to re-read the file for changes
        refresh_interval: 30s
```
Create: /home/stack-user/monitor/prometheus/file_sd/prom_nodes.yml

yaml
```
# Example node exporter target
- targets:
    - 192.168.1.100:9100
  labels:
    instance: webserver-01
    hostname: web01
    role: webserver
    env: production
    exporter: node

# Add more nodes as needed
# - targets:
#     - 192.168.1.101:9100
#   labels:
#     instance: database-01
#     hostname: db01
#     role: database
#     env: production
#     exporter: node
```
### 3. Loki Configuration (with MinIO backend)

Create: /home/stack-user/monitor/loki/config.yml

yaml
```
# Disable authentication (suitable for internal/development use)
auth_enabled: false

# Listen for HTTP requests on port 3100
server:
  http_listen_port: 3100
  grpc_listen_port: 9096

# Shared settings used across multiple Loki components
common:
  # Base directory where Loki stores its data
  path_prefix: /loki
  # Use MinIO as S3-compatible storage backend
  storage:
    s3:
      endpoint: minio:9000
      bucketnames: loki-data
      # These come from environment variables passed by docker-compose
      access_key_id: ${LOKI_S3_ACCESS_KEY}
      secret_access_key: ${LOKI_S3_SECRET_KEY}
      s3forcepathstyle: true
      insecure: true  # Set to false if using HTTPS
  # Store 1 replica (increase when running multiple Loki instances)
  replication_factor: 1
  # Configuration for Loki's hash ring
  ring:
    kvstore:
      store: inmemory  # Use 'memberlist' for multi-instance setup

# Defines how logs are indexed and stored
schema_config:
  configs:
    # This schema applies to all logs from Jan 1, 2023 onward
    - from: 2023-01-01
      # Use BoltDB for the index
      store: boltdb-shipper
      # Store chunks in MinIO (S3-compatible)
      object_store: s3
      # Schema version
      schema: v11
      index:
        # Index files will be named starting with 'index_'
        prefix: index_
        # Create a new index file every 24 hours
        period: 24h

# Storage configuration
storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    cache_ttl: 24h
    shared_store: s3

# Limits and retention
limits_config:
  # Automatically delete logs after 30 days
  retention_period: 30d
  # Maximum number of active streams per tenant
  max_streams_per_user: 10000
  # Maximum line size (256KB)
  max_line_size: 256000
  # Reject old samples
  reject_old_samples: true
  reject_old_samples_max_age: 168h

# Compactor - cleans up old data
compactor:
  working_directory: /loki/compactor
  shared_store: s3
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
```

### 4. Promtail Configuration

Create: /home/stack-user/monitor/promtail/config.yml

yaml
```
# Promtail server configuration
server:
  # Web UI and metrics available on port 9080
  http_listen_port: 9080
  grpc_listen_port: 0

# Position file tracks where Promtail stopped reading each log file
positions:
  filename: /var/lib/promtail/positions.yaml

# Where to send collected logs
clients:
  - url: http://loki:3100/loki/api/v1/push

# Define what logs to collect
scrape_configs:
  # File-based service discovery
  - job_name: file_sd
    file_sd_configs:
      - files:
          - /etc/promtail/file_sd/*.yml
        refresh_interval: 30s
```
#### Create: /home/stack-user/monitor/promtail/file_sd/nginx.yml

yaml
```
- targets:
    - localhost
  labels:
    job: nginx
    container: nginx
    host: ${HOSTNAME}
    __path__: /var/log/nginx/*.log
```
#### Create: /home/stack-user/monitor/promtail/file_sd/system.yml

yaml
```
- targets:
    - localhost
  labels:
    job: syslog
    host: ${HOSTNAME}
    __path__: /var/log/syslog
```
### 5. Nginx Configuration

#### Create: /home/stack-user/monitor/nginx/conf.d/grafana.conf

nginx
```
server {
    listen 80;
    server_name monitoring.yourdomain.com;

    # Proxy to Grafana
    location / {
        proxy_pass http://grafana:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket support for Grafana live features
    location /api/live/ {
        proxy_pass http://grafana:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```
#### Create: /home/stack-user/monitor/nginx/nginx.conf

nginx
```
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    keepalive_timeout  65;

    # Include all server configs
    include /etc/nginx/conf.d/*.conf;
}
```

### 6. Grafana Data Source Provisioning

#### Create: /home/stack-user/monitor/grafana/provisioning/datasources/loki.yml

yaml
```
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: false
    editable: true
```

#### Create: /home/stack-user/monitor/grafana/provisioning/datasources/prometheus.yml

yaml
```
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
```

## Phase 4: Initialize MinIO Bucket

MinIO needs the loki-data bucket created before Loki can use it.
### Option 1: Create bucket via MinIO Console (Easiest)

Start the stack:

bash
```
cd /home/stack-user/monitor
docker-compose up -d
```

### 2. Access MinIO Console:
```
http://<host-ip>:9001

    Login with credentials:
        Username: minioadmin
        Password: minioadmin123
    Create bucket named: loki-data
    Restart Loki:
```
bash
```
docker-compose restart loki
```

### Option 2: Create bucket via MinIO Client (mc)

bash
```
# Install mc client
docker run --rm -it --entrypoint=/bin/sh minio/mc

# Inside container:
mc alias set myminio http://minio:9000 minioadmin minioadmin123
mc mb myminio/loki-data
mc policy set public myminio/loki-data
exit
```
## Phase 5: Deploy and Verify
### 1. Start the entire stack:

bash
```
cd /home/stack-user/monitor
docker-compose up -d
```
### 2. Verify all containers are running:

bash
```
docker-compose ps
```
You should see all services in "Up" state:

    prometheus
    grafana
    loki
    promtail
    nginx
    minio

### 3. Check logs for any errors:

bash
```
# Check all logs
docker-compose logs

# Check specific service
docker-compose logs loki
docker-compose logs promtail
```
### 4. Access the services:
Service	URL	Credentials
Grafana	http://<host-ip>:3000	admin / admin
Prometheus	http://<host-ip>:9090	None
MinIO Console	http://<host-ip>:9001	minioadmin / minioadmin123
Promtail	http://<host-ip>:9080	None

### 5. Verify Grafana data sources:

    Log into Grafana
    Go to: Configuration → Data Sources
    You should see:
        ✅ Prometheus (default)
        ✅ Loki

### 6. Test Prometheus targets:

Visit http://<host-ip>:9090/targets - you should see:

    prometheus (UP)
    grafana (UP)
    loki (UP)
    promtail (UP)
    minio (UP)

### 7. Test Promtail targets:

Visit http://<host-ip>:9080/targets - you should see discovered log files
8. Query logs in Grafana:

    Go to Explore in Grafana
    Select Loki as data source
    Try query: {job="nginx"}
    You should see nginx access/error logs

## Phase 6: Install Node Exporter on Target Machines

For each server you want to monitor:
### 1. Download node_exporter:

bash
```
wget https://github.com/prometheus/node_exporter/releases/download/v1.10.2/node_exporter-1.10.2.linux-amd64.tar.gz
```
### 2. Extract:

bash
```
tar xvfz node_exporter-1.10.2.linux-amd64.tar.gz
cd node_exporter-1.10.2.linux-amd64
```

### 3. Create systemd service:

bash
```
sudo nano /etc/systemd/system/node_exporter.service
```

ini
```
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
```

### 4. Move binary and create user:

bash
```
sudo mv node_exporter /usr/local/bin/
sudo useradd -rs /bin/false node_exporter
```
### 5. Start and enable:

bash
```
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
```
### 6. Verify it's working:

bash
```
curl http://localhost:9100/metrics
```

### 7. Add to Prometheus:

Edit /home/stack-user/monitor/prometheus/file_sd/prom_nodes.yml and add:

yaml
```
- targets:
    - <target-ip>:9100
  labels:
    instance: my-server
    hostname: server01
    role: application
    env: production
    exporter: node
```
### 8. Reload Prometheus config:

bash
```
curl -X POST http://<prometheus-host>:9090/-/reload
```

#### Maintenance and Operations
Reload configurations without restart:

bash
```
# Reload Prometheus
curl -X POST http://localhost:9090/-/reload

# Reload Promtail
curl -X POST http://localhost:9080/-/reload
```
View logs:

bash
```
docker-compose logs -f <service-name>
```
Restart a service:

bash
```
docker-compose restart <service-name>
```
Stop the stack:

bash
```
docker-compose down
```

Stop and remove volumes (CAUTION - deletes all data):

bash
```
docker-compose down -v
```

Backup configuration:

bash
```
tar -czf monitor-backup-$(date +%Y%m%d).tar.gz /home/stack-user/monitor/
```

---

## Architecture Diagram
```
┌─────────────────────────────────────────────────────────────────┐
│                     Docker Network: monitoring                  │
│                                                                 │
│  ┌──────────┐         ┌──────────┐         ┌──────────┐         │
│  │  Nginx   │────────▶│ Grafana  │◀────────│  Users   │         │
│  │  :80     │  Proxy  │  :3000   │   HTTP  │ (Browser)│         │
│  │  :443    │         └──────────┘         └──────────┘         │
│  └──────────┘              │    │                               │
│       │                    │    │                               │
│       │ Logs               │    │                               │
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
│       │                │  :9001   │            │                │
│       │                └──────────┘            │                │
│       │                                        │                │
│       └──Reads logs────────────────────────────┘                │
│          (nginx, system,                                        │
│           containers)                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```
External Targets:
```
  ┌────────────┐     ┌────────────┐     ┌────────────┐
  │ Server 1   │     │ Server 2   │     │ Server 3   │
  │node:9100   │     │node:9100   │     │node:9100   │
  └────────────┘     └────────────┘     └────────────┘
        ▲                  ▲                  ▲
        └──────────────────┴──────────────────┘
               Prometheus scrapes metrics
```
## Troubleshooting
Loki can't connect to MinIO:

    Ensure MinIO is healthy: docker-compose logs minio
    Verify bucket exists in MinIO console
    Check Loki logs: docker-compose logs loki

Promtail not shipping logs:

    Check positions file permissions
    Verify log file paths exist
    Check Promtail targets: http://localhost:9080/targets

Prometheus not scraping targets:

    Check targets page: http://localhost:9090/targets
    Verify network connectivity
    Check firewall rules on target machines

Grafana can't query data:

    Test data sources in Grafana UI
    Check Prometheus/Loki are running
    Verify network connectivity between containers

Next Steps (Future Enhancements)

    Add Alertmanager for alerts
    Configure SSL/TLS for Nginx
    Set up Grafana dashboards
    Add more exporters (blackbox, snmp, etc.)
    Configure Loki retention policies
    Set up backup strategy for MinIO
    Implement authentication for services
    Add monitoring for Docker containers (cAdvisor)

Notes on Filebeat & Elasticsearch (Future Project)

This section preserved for future reference - Filebeat/Elasticsearch stack is heavier and more complex than Promtail/Loki. Start with the current stack and migrate later if needed.
