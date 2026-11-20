# Walkthrough correzione

> Non fare logout: la VM si spegne. Se succede: `virsh -c qemu:///session start iot`

## 0. VM (sul PC)
```bash
~/sgoinfre/iot-vm/create_vm.sh        # accende la VM (la ricrea se goinfre è vuoto)
# solo se è stata ricreata:
scp ~/sgoinfre/iot-vm/setup_vm.sh iot:~ && ssh iot 'bash ~/setup_vm.sh'
ssh iot
```

## Nella VM
```bash
git clone https://github.com/Martybb01/inception_of_things.git && cd inception_of_things
```

## P1
```bash
cd p1 && vagrant up
vagrant ssh marboccuS -c "hostname; ip a show ens6; kubectl get nodes -o wide"
vagrant ssh marboccuSW -c "hostname; ip a show ens6"
vagrant destroy -f && cd ..
```

## P2
```bash
cd p2 && vagrant up                   # poi aspetta ~30 s (Traefik)
curl -H "Host: app1.com" 192.168.56.110
curl -H "Host: app2.com" 192.168.56.110
curl 192.168.56.110                   # app3
vagrant ssh marboccuS -c "kubectl get all; kubectl get ingress"
vagrant destroy -f && cd ..
```

## P3
```bash
cd p3/scripts
./initial_setup.sh                    # se poi Docker dà "permission denied": newgrp docker
./cluster_setup.sh                    # stampa la password admin
kubectl get ns && kubectl get pods -n dev
curl localhost:8888                   # v1
```
UI Argo CD: dal browser del PC → **https://localhost:8080** (admin / password stampata)

Demo v2 (push **dal PC**, lì c'è la chiave GitHub):
```bash
cd ~/RNCP7/github/marboccu-iot && git pull
sed -i 's/playground:v1/playground:v2/' deployment.yaml && git commit -am v2 && git push
```
Nella VM:
```bash
argocd app get wil-playground --refresh   # o REFRESH nella UI (senza: 3–6 min)
curl localhost:8888                        # v2
```
Dopo: riporta il repo a v1 (`v2` → `v1`, commit, push).

## Se qualcosa non va
- UI non risponde → nella VM: `nohup kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 &`
- `vagrant up` dice che la VM esiste già → `vagrant destroy -f` e rilancia
