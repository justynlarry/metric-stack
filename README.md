# System Monitoring and Problem Detection
!! Under Construction !!

1. First install Docker (instructions for Debian below).
```
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update


# Install Latest Version:
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Make sure that Docker is running:
sudo systemctl status docker

# Test Installation:
sudo docker run hello-world

# Add user to docker group (optional):
sudo usermod -aG docker $USER
# Refresh the shell
newgrp docker

# Install Docker Compose:
sudo apt update
sudo apt install docker-compose-plugin

# Verify:
docker compose version
```
2. Set up docker-compose.yaml for Prometheus
