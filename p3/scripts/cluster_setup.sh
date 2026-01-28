#!/bin/bash

echo "Creating K3d cluster..."
if k3d cluster list | grep -q "marboccuCluster"; then
    echo "Cluster 'marboccuCluster' already exists, skipping creation..."
else
    k3d cluster create marboccuCluster -p 8888:30420
    echo "Cluster 'marboccuCluster' created successfully."
fi

echo "Creating namespaces for ArgoCD and application to be deployed..."
kubectl create namespace argocd
kubectl create namespace dev

echo "Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

nohup kubectl port-forward svc/argocd-server -n argocd 8080:443 >> /dev/null 2>&1 &

sleep 10

echo "Installing ArgoCD CLI..."
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
    echo "Detected amd64 architecture"
    curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    echo "Detected arm64 architecture"
    curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-arm64
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
sudo install -m 555 /tmp/argocd /usr/local/bin/argocd
rm /tmp/argocd

echo "Get initial Admin password to access UI..."
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d ; echo

echo "Login to ArgoCD..."
argocd login localhost:8080 --insecure --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD login successful."

echo "In order to access UI visit https://localhost:8080"
# ssh -i ~/.ssh/id_ed25519 -L 8081:localhost:8080 ubuntu@<ip> --> x vedere da macchina host + aggiungere la chiave pubblica .pub a authorized keys dentro .ssh su VM
# sull'host girerà sulla porta 8081 e non 8080

echo "Now it's time to step 3..."

