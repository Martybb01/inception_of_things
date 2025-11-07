#!/bin/bash

echo "This script will install all the packages and tools needed to make the application works..."

echo "Installing Docker..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

sudo usermod -aG docker $USER


echo "Installing kubectl..."
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
    echo "Detected amd64 architecture"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    echo "Detected arm64 architecture"
    curl -LO "https://dl.k8s.io/release/v1.33.0/bin/linux/arm64/kubectl"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl 

echo "Installing k3d..."
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "Initial setup completed successfully, now ./cluster_setup.sh script will handle K3D and ArgoCD setup..."

newgrp docker

