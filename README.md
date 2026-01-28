
# Inception of Things

A hands-on exploration of Kubernetes infrastructure using K3s, K3d, Vagrant, and GitOps.
This repository contains three progressive projects that demonstrate **Kubernetes cluster setup, application deployment, and continuous deployment.**

### Requirements

- Vagrant
- VirtualBox
- 2GB+ available RAM

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
./cluster_setup.sh
./deploy.sh
```

**Access ArgoCD UI:**
```bash
# From your local machine, create SSH tunnel to the VM after creating ssh key:
ssh -i ~/.ssh/id_ed25519 -L 8081:localhost:8080 <hostname>@<VM_IP>

# Then visit: https://localhost:8081
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
1. Edit the image tag in `p3/app/wilSapp.yaml` (e.g., change `v1` to `v2`)
2. Commit and push the change to Git
3. ArgoCD will automatically detect the change and sync the new version
4. Verify the update in ArgoCD UI or with: `argocd app get wil-playground`
