#!/bin/bash
set -e

echo "Please enter client name: "
read client_name



echo "[*] Updating packages..."
apt update -y && apt install unzip -y

#############################################
# 1. Prometheus Node Exporter
#############################################
echo "[*] Installing Node Exporter..."

cd /tmp
NODE_VERSION="1.8.2"
wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/node_exporter-${NODE_VERSION}.linux-amd64.tar.gz
tar -xzf node_exporter-${NODE_VERSION}.linux-amd64.tar.gz
mv node_exporter-${NODE_VERSION}.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-${NODE_VERSION}.linux-amd64*

# Systemd service
cat << 'EOF' > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network-online.target
Wants=network-online.target

[Service]
User=nobody
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

#############################################
# 2. PromTail Exporter
#############################################
echo "[*] Installing Promtail Exporter..."

mkdir -p /etc/promtail
mkdir -p /var/lib/promtail
useradd --system --shell /bin/false promtail || true
usermod -aG adm promtail

cd /tmp
PT_VERSION="3.0.0"
wget -q https://github.com/grafana/loki/releases/download/v${PT_VERSION}/logcli-linux-amd64.zip
unzip promtail-linux-amd64.zip
mv promtail-linux-amd64 /usr/local/bin/promtail
chmod +x /usr/local/bin/promtail

# Create Config file:
cat << 'EOF' > /etc/promtail/config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://100.126.10.29:3100/loki/api/v1/push

scrape_configs:
  - targets:
    - localhost
  labels:
    tenant: ${client_name}
    job: syslog
    environment: production
    host: $HOST
    __path__: /var/log/syslog

EOF

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
systemctl enable --now node_exporter.service


echo "[+] Setup complete!"
