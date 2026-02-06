#!/bin/bash

# Ensure the script is NOT run as sudo itself (so prompts work correctly)
if [[ $EUID -eq 0 ]]; then
   echo "Please run this script as a normal user (it will prompt for sudo when needed)."
   exit 1
fi

echo "------------------------------------------------"
echo "  Grafana Alloy: Universal Deployment Script"
echo "------------------------------------------------"

# 1. Collect Label Data
read -p "Tenant (e.g., client-a): " TENANT
read -p "Cluster (e.g., client-a-vm-prod): " CLUSTER
read -p "Instance (e.g., db-svr01): " INSTANCE
read -p "Environment (production/staging): " ENV
read -p "Platform (vm/metal/docker): " PLATFORM
read -p "Role (webserver/database): " ROLE
read -p "Host (hostname): " HOSTNAME
read -p "Remote Endpoint URL (e.g., https://loki.example.com): " REMOTE_URL

# 2. Create the config locally
TEMP_CONFIG="config.alloy.tmp"

cat <<EOF > $TEMP_CONFIG
// --- METRICS COLLECTION ---
prometheus.exporter.unix "node_exporter" {
}

prometheus.scrape "scrape_node_exporter" {
  targets    = prometheus.exporter.unix.node_exporter.targets
  forward_to = [prometheus.relabel.add_labels.receiver]
}

// Force-inject labels into metrics (Distro Agnostic)
prometheus.relabel "add_labels" {
  rule { target_label = "tenant",      replacement = "$TENANT" }
  rule { target_label = "cluster",     replacement = "$CLUSTER" }
  rule { target_label = "instance",    replacement = "$INSTANCE" }
  rule { target_label = "environment", replacement = "$ENV" }
  rule { target_label = "platform",    replacement = "$PLATFORM" }
  rule { target_label = "role",        replacement = "$ROLE" }
  rule { target_label = "host",        replacement = "$HOSTNAME" }
  rule { target_label = "exporter",    replacement = "node" }
  forward_to = [prometheus.remote_write.local.receiver]
}

prometheus.remote_write "local" {
  endpoint {
    url = "$REMOTE_URL/api/v1/push"
  }
}

// --- LOG COLLECTION (Universal Paths) ---
local.file_match "logs" {
  path_targets = [
    { "__path__" = "/var/log/*.log" },
    { "__path__" = "/var/log/syslog" },   // Debian/Ubuntu
    { "__path__" = "/var/log/messages" }, // RHEL/CentOS/Fedora
    { "__path__" = "/var/log/secure" },   // Auth logs RHEL
    { "__path__" = "/var/log/auth.log" }, // Auth logs Debian
  ]
}

loki.source.file "log_scrape" {
  targets    = local.file_match.logs.targets
  forward_to = [loki.process.add_labels.receiver]
}

loki.process "add_labels" {
  stage.static_labels {
    values = {
      tenant      = "$TENANT",
      cluster     = "$CLUSTER",
      instance    = "$INSTANCE",
      environment = "$ENV",
      platform    = "$PLATFORM",
      role        = "$ROLE",
      host        = "$HOSTNAME",
      exporter    = "node",
    }
  }
  forward_to = [loki.write.local.receiver]
}

loki.write "local" {
  endpoint {
    url = "$REMOTE_URL/loki/api/v1/push"
  }
}
EOF

echo "------------------------------------------------"
echo "Deploying Configuration..."

# 3. Move and Restart (Sudo Elevation)
if [ ! -d "/etc/alloy" ]; then
    echo "Creating /etc/alloy directory..."
    sudo mkdir -p /etc/alloy
fi

sudo mv $TEMP_CONFIG /etc/alloy/config.alloy

# Fix permissions so Alloy can read its own config
sudo chown root:root /etc/alloy/config.alloy
sudo chmod 644 /etc/alloy/config.alloy

# Check if alloy exists before restarting
if systemctl list-unit-files | grep -q alloy.service; then
    echo "Restarting Alloy Service..."
    sudo systemctl restart alloy
    sudo systemctl enable alloy
    echo "SUCCESS: Alloy is running with your new labels."
else
    echo "ERROR: Alloy is not installed on this system."
    echo "Config placed at /etc/alloy/config.alloy"
    echo "Install it via: https://grafana.com/docs/alloy/latest/set-up/install/"
fi

echo "------------------------------------------------"
