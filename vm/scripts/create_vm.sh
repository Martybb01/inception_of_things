#!/bin/bash
# Creates the "iot" KVM/QEMU VM (Ubuntu 24.04 cloud image) used to run the whole
# Inception-of-Things project. No sudo needed: libvirt user session (qemu:///session).
# Nested KVM is enabled (cpu host-passthrough) so Vagrant/libvirt works inside.
# Visible in virt-manager (File > Add connection > QEMU/KVM user session).
#
# Host -> VM port forwards (127.0.0.1): 2222->22 (ssh), 8080->8080 (Argo CD), 8888->8888 (app)
set -euo pipefail

VM=iot
DIR="$(realpath -m "$HOME/goinfre")/iot"
CPUS=${CPUS:-8}
MEM_MB=${MEM_MB:-8192}
DISK=${DISK:-40G}
USERNAME=$(whoami)
[ -f "$HOME/.ssh/id_ed25519.pub" ] || ssh-keygen -q -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519"
PUBKEY=$(cat "$HOME/.ssh/id_ed25519.pub")
VIRSH="virsh -c qemu:///session"

mkdir -p "$DIR" && cd "$DIR"

# ssh alias "iot" on the host
if ! grep -q "^Host iot$" "$HOME/.ssh/config" 2>/dev/null; then
  printf 'Host iot\n  HostName 127.0.0.1\n  Port 2222\n  User %s\n  StrictHostKeyChecking accept-new\n  LogLevel ERROR\n' "$USERNAME" >> "$HOME/.ssh/config"
  chmod 600 "$HOME/.ssh/config"
fi

if $VIRSH dominfo "$VM" >/dev/null 2>&1; then
  if [ -f "$DIR/disk.qcow2" ]; then
    $VIRSH domstate "$VM" | grep -q running || $VIRSH start "$VM"
    echo "VM $VM is running -> ssh iot"; exit 0
  fi
  echo "[*] VM $VM is defined but its disk is gone (goinfre wiped): recreating it"
  $VIRSH destroy "$VM" >/dev/null 2>&1 || true
  $VIRSH undefine "$VM"
fi
ssh-keygen -R '[127.0.0.1]:2222' >/dev/null 2>&1 || true

[ -f noble.img ] || curl -fL -o noble.img https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

echo "[*] Creating disk ($DISK, backed by the cloud image)"
rm -f disk.qcow2
qemu-img create -q -f qcow2 -F qcow2 -b "$DIR/noble.img" disk.qcow2 "$DISK"

echo "[*] Building cloud-init seed ISO"
mkdir -p seed
cat > seed/meta-data <<EOF
instance-id: $VM-001
local-hostname: $VM
EOF
cat > seed/user-data <<EOF
#cloud-config
users:
  - name: $USERNAME
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    plain_text_passwd: $USERNAME
    ssh_authorized_keys:
      - $PUBKEY
ssh_pwauth: true
package_update: true
packages: [git, curl, rsync]
EOF
rm -f seed.iso
xorriso -as mkisofs -quiet -output seed.iso -volid cidata -joliet -rock seed/user-data seed/meta-data

echo "[*] Defining VM"
cat > "$VM.xml" <<EOF
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <name>$VM</name>
  <memory unit='MiB'>$MEM_MB</memory>
  <vcpu>$CPUS</vcpu>
  <os><type arch='x86_64' machine='q35'>hvm</type><boot dev='hd'/></os>
  <features><acpi/><apic/></features>
  <cpu mode='host-passthrough' check='none'/>
  <clock offset='utc'/>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' discard='unmap'/>
      <source file='$DIR/disk.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='$DIR/seed.iso'/>
      <target dev='sda' bus='sata'/>
      <readonly/>
    </disk>
    <serial type='pty'><target port='0'/></serial>
    <console type='pty'><target type='serial' port='0'/></console>
    <graphics type='spice' autoport='yes'><listen type='address' address='127.0.0.1'/></graphics>
    <video><model type='virtio'/></video>
    <rng model='virtio'><backend model='random'>/dev/urandom</backend></rng>
  </devices>
  <qemu:commandline>
    <qemu:arg value='-netdev'/>
    <qemu:arg value='user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=tcp:127.0.0.1:8080-:8080,hostfwd=tcp:127.0.0.1:8888-:8888'/>
    <qemu:arg value='-device'/>
    <qemu:arg value='virtio-net-pci,netdev=net0'/>
  </qemu:commandline>
</domain>
EOF
$VIRSH define "$VM.xml"
$VIRSH start "$VM"
echo "[*] VM started. Connect with: ssh -p 2222 $USERNAME@127.0.0.1  (password: $USERNAME)"
