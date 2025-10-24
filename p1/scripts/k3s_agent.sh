#!/bin/bash
MASTER_IP=$1

while [ ! -f /vagrant/token ]; do
  echo "Waiting for master token..."
  sleep 2
done

K3S_TOKEN=$(cat /vagrant/token)

IFACE=$(ip -4 addr show | grep "192.168.56.111" | awk '{print $NF}')

if [ -z "$IFACE" ]; then
  echo "Interface with IP 192.168.56.111 not found, using default"
  curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$K3S_TOKEN INSTALL_K3S_EXEC="agent --node-ip=192.168.56.111" sh -
else
  echo "Using interface: $IFACE"
  curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$K3S_TOKEN INSTALL_K3S_EXEC="agent --node-ip=192.168.56.111 --flannel-iface=$IFACE" sh -
fi
