#!/bin/bash
# Run INSIDE the iot VM: installs Vagrant (HashiCorp repo) + libvirt/KVM provider.
# (Docker / k3d / kubectl for p3 are installed by p3/scripts/initial_setup.sh)
# Usage from the host:  scp setup_vm.sh iot:~ && ssh iot 'bash ~/setup_vm.sh'
set -euo pipefail

sudo apt-get update
sudo apt-get install -y curl gnupg lsb-release git rsync \
  qemu-kvm libvirt-daemon-system libvirt-clients libvirt-dev \
  ruby-dev build-essential pkg-config dnsmasq-base ebtables nfs-kernel-server

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
sudo apt-get update
sudo apt-get install -y vagrant

sudo usermod -aG libvirt,kvm "$USER"
sudo systemctl enable --now libvirtd

vagrant plugin install vagrant-libvirt
echo "Done. Log out/in (or 'newgrp libvirt') to use libvirt without sudo."
