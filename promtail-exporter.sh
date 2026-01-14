#!/bin/bash
set -e

# Get client_name Variable from Installer
echo "Please enter client name: "
read client_name

# Use system hostname if $HOST isn't set
INSTANCE_HOSTNAME=$(hostname)


# Update apt packages and instal unzip and wget
echo "[*] Updating packages..."
DEBIAN_FRONTEND=noninteractive apt update -y
DEBIAN_FRONTEND=noninteractive apt install -y unzip wget


#############################################
# 1. PromTail Exporter
#############################################
echo "[*] Installing Promtail..."

mkdir -p /etc/promtail
mkdir -p /var/lib/promtail
useradd --system --shell /bin/false promtail || true
usermod -aG adm promtail
usermod -aG systemd-journal promtail

cd /tmp
PT_VERSION="3.0.0"
wget -q https://github.com/grafana/loki/releases/download/v${PT_VERSION}/promtail-linux-amd64.zip
unzip promtail-linux-amd64.zip
mv promtail-linux-amd64 /usr/local/bin/promtail
chmod +x /usr/local/bin/promtail

# Create Config file:
LOKI_URL="http://100.126.10.29:3100"
cat << EOF > /etc/promtail/config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: ${LOKI_URL}/loki/api/v1/push

scrape_configs:
  - job_name: syslog
    static_configs:
    - targets:
        - localhost
      labels:
        tenant: ${client_name}
        job: syslog
        environment: production
        host: ${INSTANCE_HOSTNAME}
        __path__: /var/log/syslog

  - job_name: journal
    journal:
      path: /var/log/journal
      max_age: 12h
      labels:
        tenant: ${client_name}
        job: systemd-journal
        environment: production
        host: ${INSTANCE_HOSTNAME}


EOF

chown -R promtail:promtail /etc/promtail
chown -R promtail:promtail /var/lib/promtail

# Systemd Service
cat << 'EOF' > /etc/systemd/system/promtail.service
[Unit]
Description=Promtail Service
After=network-online.target
Wants=network-online.target

[Service]
User=promtail
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF


#############################################
# Reload + Enable Services
#############################################
echo "[*] Enabling and starting services..."

systemctl daemon-reload
systemctl enable --now promtail.service

sleep 4
systemctl status promtail.service --no-pager


echo ""
echo "[+] Setup complete FOR ${client_name} on ${INSTANCE_HOSTNAME}!"
echo ""
echo "Promtail listening on: http://$(hostname -I | awk '{print $1}'):9080"
echo ""
echo "Test with:"
echo " curl http://localhost:9080/metrics | head"



