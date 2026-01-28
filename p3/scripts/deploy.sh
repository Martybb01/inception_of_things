#!/bin/bash

# this script will deploy wilSapp on argoCD

argocd repo add https://github.com/Martybb01/inception_of_things.git
echo "Creating ArgoCD Application..."
argocd app create wil-playground \
  --repo https://github.com/Martybb01/inception_of_things.git \
  --path p3/app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --sync-policy automated \
  --auto-prune \
  --self-heal

echo "Syncing application..."
argocd app sync wil-playground

echo "Waiting for application to be healthy..."
argocd app wait wil-playground --health

echo "Application deployed successfully!"
echo "Check status with: argocd app get wil-playground"

argocd app get wil-playground

kubectl port-forward -n dev svc/wilS-playground 8888:8888
