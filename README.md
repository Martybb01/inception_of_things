
# Inception of Things

A hands-on exploration of Kubernetes infrastructure using K3s, K3d, Vagrant, and GitOps.
This repository contains three progressive projects that demonstrate **Kubernetes cluster setup, application deployment, and continuous deployment.**

### Requirements

- Vagrant + `vagrant-libvirt` plugin (KVM/libvirt provider, set as default in the Vagrantfiles)
- NFS server on the host (p1 shared folder)
- 4GB+ available RAM

Boxes: Rocky Linux 10 official Vagrant box, downloaded from the distribution itself (`config.vm.box_url` → `dl.rockylinux.org`).

## P1: K3s and Vagrant

Sets up a multi-node Kubernetes cluster from scratch using K3s and Vagrant. This project involves:
- Creating two VMs with static IPs on a private network
- Installing K3s on the controller node `(marboccuS at 192.168.56.110)`
- Joining a worker node `(marboccuSW at 192.168.56.111)` to the cluster
- Automatic token sharing between nodes via Vagrant's shared folder
- Network interface detection for Flannel CNI configuration

The setup scripts handle everything: K3s installation, kubeconfig generation, and kubectl configuration for both nodes.

**Try it:**
```bash
cd p1
vagrant up
vagrant ssh marboccuS  # or vagrant ssh marboccuSW
kubectl get nodes -o wide
```

## P2: K3s and Three Simple Applications

Deploys three web applications on a single-node K3s cluster with ingress routing. This project involves:
- Single-node K3s cluster setup
- Kubernetes Deployments and Services
- Ingress controller for host-based routing
- Replica scaling (app2 runs 3 replicas)

Applications:
- **app1**: accessible via `app1.com`
- **app2**: accessible via `app2.com` (3 replicas)
- **app3**: default route (accessible via IP)

**Try it:**
```bash
cd p2
vagrant up

# Add to your /etc/hosts:
192.168.56.110 app1.com app2.com

# Test with curl:
curl -H "Host: app1.com" 192.168.56.110
curl -H "Host: app2.com" 192.168.56.110
curl 192.168.56.110  # app3 (default)
```

All applications use the same Flask container image (`marboccu/flask-app:18`) but are routed differently based on the hostname.

## P3: K3d and Argo CD

Implements GitOps continuous deployment using K3d and ArgoCD. This project involves:
- Local K3d cluster creation with port mapping
- ArgoCD installation and configuration
- Automated application deployment from Git repository
- Continuous sync with auto-prune and self-healing
- Version management through container image tags

The setup demonstrates how ArgoCD monitors a Git repository and automatically deploys changes to the cluster, enabling true GitOps workflows.

The application uses `wil42/playground` container image with NodePort service on port 30420, exposed via k3d on localhost:8888.

**Setup:**
```bash
cd p3/scripts
./initial_setup.sh
./cluster_setup.sh   # k3d + Argo CD + Application (p3/confs/application.yaml)
```

Argo CD watches the public repo https://github.com/emptydeepblue/marboccu-iot (`deployment.yaml` at its root).
A copy of the manifest is kept in `p3/confs/app/deployment.yaml`.

**Access ArgoCD UI:**
```bash
# cluster_setup.sh runs `kubectl port-forward --address 0.0.0.0 ... 8080:443` inside the VM,
# and the VM forwards port 8080 to the host: no SSH tunnel / key needed.
# From the host visit: https://localhost:8080
# Username: admin
# Password: (shown during cluster_setup.sh execution)
```

**Access the deployed application:**
```bash
# From VM:
curl http://localhost:8888

# From your Mac visit:
curl http://<VM_IP>:8888
```

**Test GitOps - Verify automatic version updates:**
1. Edit the image tag in `deployment.yaml` of the `marboccu-iot` repo (e.g., change `v1` to `v2`)
2. Commit and push the change to Git
3. ArgoCD will automatically detect the change and sync the new version
4. Verify the update in ArgoCD UI or with: `argocd app get wil-playground` (`--refresh` to force an immediate check, Argo CD polls Git every ~3 minutes)

## Notes for the defense

**Environment**
- Everything runs inside one VM (Ubuntu 24.04 on KVM/QEMU, nested virtualization enabled). Vagrant uses the
  `libvirt` provider inside it: it is set in the Vagrantfiles (`VAGRANT_DEFAULT_PROVIDER`), so a plain `vagrant up` is enough.
- Boxes: the HashiCorp registry is not guaranteed after 2026, so `config.vm.box_url` points to the official
  **Rocky Linux 10** box published by Rocky itself (Ubuntu/Debian no longer publish Vagrant boxes).
- Run one part at a time (`vagrant destroy -f` / `k3d cluster delete marboccuCluster` before the next one):
  p1 and p2 both use `192.168.56.110`.

**P1**
- Resources: the subject *advises* 1 CPU / 512–1024 MB. The worker uses 1024 MB, the server 2048 MB:
  a K3s control plane runs out of memory with 1 GB (tested: the agent cannot join).
- Rocky specifics in the inline provision: `dnf` instead of `apt`, `nmap-ncat` for `nc`, and `firewalld` is disabled
  (otherwise it blocks port 6443 and the agent never joins).
- The token and kubeconfig are shared through `/vagrant` (NFS v4 synced folder, needed with libvirt).
- Passwordless SSH: Vagrant replaces its public insecure key with a new key generated for each machine
  (default `insert_key`), and password authentication is disabled. `vagrant ssh-config marboccuS` shows the key used.
- Check: `vagrant ssh marboccuS -c "kubectl get nodes -o wide"` and `ip a show ens6` on both machines.

**P2**
- The apps live in the `apps` namespace (default namespace of the kubeconfig).
- Show the Ingress: `kubectl get ingress` / `kubectl describe ingress app-ingress`.
- Each page shows `Version: app1|app2|app3` and the pod name; repeat `curl -H "Host: app2.com" 192.168.56.110`
  to see the 3 replicas answering.
- Traefik needs ~30–60 s after `vagrant up` before the routes answer.

**P3**
- The Argo CD Application is declarative (`p3/confs/application.yaml`), applied by `cluster_setup.sh`.
- The repo watched by Argo CD contains a team login in its name: `emptydeepblue/marboccu-iot`. Keep it on `v1` before the defense.
- Argo CD is installed with `--server-side --force-conflicts` (required by recent Argo CD versions: some CRDs are too big for a client-side apply).
- **After pushing v2, Argo CD can take ~3–6 minutes to notice the change** (it polls Git every ~3 minutes).
  To avoid waiting, press **REFRESH** in the UI or run `argocd app get wil-playground --refresh`.
- Demo:
  ```bash
  git clone git@github.com:emptydeepblue/marboccu-iot.git && cd marboccu-iot
  sed -i 's/wil42\/playground:v1/wil42\/playground:v2/' deployment.yaml
  git commit -am "v2" && git push
  argocd app get wil-playground --refresh
  kubectl get pods -n dev
  curl http://localhost:8888/     # {"status":"ok", "message": "v2"}
  ```

## Host VM setup (`vm/`)

`vm/scripts/create_vm.sh` (run on the host, no sudo) creates the KVM/QEMU VM `iot` used for the whole project,
`vm/scripts/setup_vm.sh` (run inside it) installs Vagrant + libvirt. Step-by-step defense guide: `vm/WALKTHROUGH.md`.
