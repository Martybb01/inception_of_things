#!/bin/bash
MASTER_IP=$1

TIMEOUT=300
ELAPSED=0
while [ ! -f /vagrant/token ] && [ $ELAPSED -lt $TIMEOUT ]; do
  echo "Waiting for master token... ($ELAPSED/$TIMEOUT seconds)"
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

if [ ! -f /vagrant/token ]; then
  echo "Timeout waiting for master token"
  exit 1
fi

K3S_TOKEN=$(cat /vagrant/token)
echo "Token found, connecting to master at $MASTER_IP"

if ! nc -z $MASTER_IP 6443; then
  echo "Cannot reach master at $MASTER_IP:6443"
  exit 1
fi

IFACE=$(ip -4 addr show | grep "192.168.56.111" | awk '{print $NF}')

if [ -z "$IFACE" ]; then
  echo "Interface with IP 192.168.56.111 not found, using default"
  curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$K3S_TOKEN INSTALL_K3S_EXEC="agent --node-ip=192.168.56.111" sh -
else
  echo "Using interface: $IFACE"
  curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$K3S_TOKEN INSTALL_K3S_EXEC="agent --node-ip=192.168.56.111 --flannel-iface=$IFACE" sh -
fi
