# Inception-of-Things — walkthrough per la correzione

Tutto gira nella VM **`iot`** (Ubuntu 24.04, KVM/QEMU, virtualizzazione annidata) sul PC della scuola.
Dentro la VM: Vagrant + libvirt per p1/p2, Docker + k3d + Argo CD per p3.

> ⚠️ **Non fare logout dalla sessione** durante la difesa: la VM gira nella sessione utente e si spegne.
> Se succede: `virsh -c qemu:///session start iot` (il disco resta).

---

## Dove sta cosa sul PC

```
PC DELLA SCUOLA (host, utente everonel, niente sudo)
├── ~/RNCP7/github/inception_of_things/     ← repo del progetto (questo)
│   ├── p1/ p2/ p3/                         ← la consegna
│   └── vm/                                 ← script della VM + questo walkthrough
│       ├── scripts/create_vm.sh            ← crea/accende la VM "iot" (si lancia SUL PC)
│       ├── scripts/setup_vm.sh             ← installa Vagrant+libvirt (si lancia DENTRO la VM)
│       └── WALKTHROUGH.md
├── ~/RNCP7/github/marboccu-iot/            ← clone del repo che Argo CD guarda (push v1/v2 da qui)
├── ~/.ssh/id_ed25519                       ← chiave: GitHub (emptydeepblue) + accesso alla VM
├── ~/.ssh/config                           ← alias "Host iot" → 127.0.0.1:2222 (creato da create_vm.sh)
├── ~/goinfre/iot/                          ← DISCO DELLA VM (disk.qcow2, ~10 GB). goinfre può essere svuotato!
│   ├── noble.img                           ← immagine Ubuntu 24.04 di base
│   ├── disk.qcow2                          ← disco della VM (tutto quello che c'è dentro)
│   └── seed.iso                            ← cloud-init (utente, password, chiave SSH)
└── ~/sgoinfre/iot-vm/                      ← copia di backup di vm/ (sgoinfre non viene svuotato)

VM "iot" (Ubuntu 24.04, 8 CPU, 8 GB, utente everonel / password everonel, sudo senza password)
├── ~/inception_of_things/                  ← clone del repo per la difesa (p1, p2, p3)
├── ~/.vagrant.d/boxes/                     ← box Rocky 10 già scaricato (cache)
└── /var/lib/libvirt/images/                ← dischi delle VM di p1/p2 (marboccuS, marboccuSW)
```

Porte dal PC verso la VM: `2222` → ssh, `8888` → app di p3, `8080` → interfaccia di Argo CD (p3).

Se si parte da un **PC nuovo** (o dal PC di un compagno): clona il repo del progetto in qualsiasi cartella,
poi segui la sezione 0 usando `vm/scripts/` del repo. Per fare la demo v2 serve una chiave SSH autorizzata
su GitHub per `emptydeepblue/marboccu-iot`.

---

## 0. Preparazione (prima che arrivino i valutatori)

```bash
# Sul PC della scuola
cd ~/RNCP7/github/inception_of_things
./vm/scripts/create_vm.sh             # accende la VM (o la ricrea se goinfre è stato svuotato)
ssh iot                               # entra nella VM (in alternativa: virt-manager → "QEMU/KVM user session")
```

**Solo se la VM è stata appena ricreata** (goinfre svuotato), ~10–15 minuti:
```bash
# dal PC della scuola, nella cartella del repo
scp vm/scripts/setup_vm.sh iot:~ && ssh iot 'bash ~/setup_vm.sh'
ssh iot                               # rientra: serve per il gruppo libvirt
```

**Nella VM**, clona il repo consegnato (versione pulita):
```bash
rm -rf ~/inception_of_things
git clone https://github.com/Martybb01/inception_of_things.git ~/inception_of_things
cd ~/inception_of_things && ls        # p1  p2  p3  README.md
```

Controlla che il repo di Argo CD sia su **v1**: https://github.com/emptydeepblue/marboccu-iot → `deployment.yaml` → `wil42/playground:v1`.

Pulizia, se è rimasto qualcosa acceso:
```bash
cd ~/inception_of_things/p1 && vagrant destroy -f
cd ~/inception_of_things/p2 && vagrant destroy -f
k3d cluster delete marboccuCluster
```

---

## 1. Parte generale (da mostrare subito)

```bash
cd ~/inception_of_things
find -maxdepth 2 -not -path './.git*'     # p1, p2, p3 con scripts/ e confs/
```
- "Tutto in una VM": mostra `virt-manager` o `ssh iot` → `hostnamectl` (Virtualization: kvm).
- Il provider è libvirt (la subject permette qualsiasi provider). È già impostato nei Vagrantfile, quindi basta `vagrant up`.

---

## 2. P1 — K3s e Vagrant (~2 min)

```bash
cd ~/inception_of_things/p1
cat Vagrantfile
vagrant up
```
Cose da indicare nel Vagrantfile:
- `config.vm.box = "rockylinux/10"` + **`config.vm.box_url`** → `dl.rockylinux.org`: è un'immagine pubblicata dalla distro stessa (lo chiede la subject; Ubuntu e Debian non pubblicano più box Vagrant). Rocky 10 è l'ultima versione stabile.
- Nomi delle macchine `marboccuS` / `marboccuSW` (login + S / SW); IP `192.168.56.110` / `.111` con `private_network` (interfaccia dedicata).
- Server: K3s in modalità **server/controller** (`k3s_master.sh`); worker in modalità **agent** (`k3s_agent.sh`).
- Il token passa dal master all'agent tramite `/vagrant/token` (cartella condivisa NFS).

Verifiche:
```bash
vagrant status
vagrant ssh marboccuS                 # niente password
  hostname                            # marboccuS
  ip a show ens6                      # 192.168.56.110
  kubectl get nodes -o wide           # 2 nodi Ready, INTERNAL-IP .110 e .111
  exit
vagrant ssh marboccuSW
  hostname; ip a show ens6            # marboccuSW, 192.168.56.111
  kubectl get nodes                   # kubectl funziona anche sul worker
  exit
vagrant ssh-config marboccuS | grep -E "IdentityFile|PasswordAuth"   # chiave per macchina, no password
```

Domande probabili:
- **Risorse?** La subject *consiglia* 1 CPU / 512–1024 MB. Il worker ha 1024 MB; il server 2048 MB perché il control plane di K3s con 1 GB finisce la memoria (l'abbiamo verificato: l'agente non riusciva a unirsi).
- **Perché firewalld disattivato?** Su Rocky è attivo di default e blocca la porta 6443 (API server) e le porte di flannel.
- **SSH senza password?** Vagrant sostituisce la sua chiave insicura con una chiave generata per ogni macchina; l'autenticazione con password è disattivata.
- **Server vs agent?** Il server ha control plane (API server, scheduler, controller manager) e datastore; l'agent esegue solo kubelet e container runtime e si unisce con URL + token.

Alla fine: `vagrant destroy -f` (p2 usa lo stesso IP .110).

---

## 3. P2 — K3s e tre applicazioni (~2 min)

```bash
cd ~/inception_of_things/p2
cat Vagrantfile scripts/run.sh confs/*.yaml
vagrant up
```
Da indicare: una sola VM `marboccuS` (.110), K3s server, 3 Deployment + Service, app2 con `replicas: 3`, un Ingress (Traefik di K3s) con regole per Host e una regola di default senza host → app3.

Verifiche (aspetta 30–60 s dopo `vagrant up` che Traefik sia pronto):
```bash
curl -H "Host: app1.com" 192.168.56.110      # Version: app1
curl -H "Host: app2.com" 192.168.56.110      # Version: app2 (ripeti: cambia il pod tra 3)
curl 192.168.56.110                          # Version: app3 (default)
curl -H "Host: ciao.com" 192.168.56.110      # app3

vagrant ssh marboccuS
  kubectl get all                     # namespace apps: app2 3/3
  kubectl get ingress                 # LA SUBJECT CHIEDE DI MOSTRARE L'INGRESS
  kubectl describe ingress app-ingress
  exit
```
Domande probabili: cos'è un Ingress (routing HTTP per host/path verso i Service), Service ClusterIP, come si scala (`kubectl scale deployment app2 --replicas=3`).

Alla fine: `vagrant destroy -f`.

---

## 4. P3 — K3d e Argo CD (~5 min)

```bash
cd ~/inception_of_things/p3/scripts
cat initial_setup.sh cluster_setup.sh ../confs/application.yaml
./initial_setup.sh                    # Docker, kubectl, k3d (la subject chiede uno script di installazione)
./cluster_setup.sh                    # cluster k3d, namespace argocd + dev, Argo CD, Application
```
> Se `cluster_setup.sh` dà "permission denied" su Docker: `newgrp docker` (o esci e rientra) e rilancialo.

Verifiche:
```bash
kubectl get ns                        # argocd, dev
kubectl get pods -n dev               # wil-playground-xxx Running
curl http://localhost:8888/           # {"status":"ok", "message": "v1"}
argocd app get wil-playground         # Repo: github.com/emptydeepblue/marboccu-iot, Synced, Healthy
```

**Interfaccia di Argo CD**: dal browser del PC della scuola apri **https://localhost:8080**
(accetta il certificato self-signed). Utente `admin`, password stampata da `cluster_setup.sh`
(o nella VM: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`).
Funziona senza tunnel perché il port-forward ascolta su `0.0.0.0` e la VM inoltra la porta 8080 al PC.

**Demo v1 → v2** (il push si fa **dal PC della scuola**: lì c'è la chiave GitHub di emptydeepblue):
```bash
# PC della scuola
cd ~/RNCP7/github/marboccu-iot        # (oppure: git clone git@github.com:emptydeepblue/marboccu-iot.git)
git pull
sed -i 's/wil42\/playground:v1/wil42\/playground:v2/' deployment.yaml
git commit -am "v2" && git push

# VM
argocd app get wil-playground --refresh   # oppure REFRESH nell'interfaccia
kubectl get pods -n dev -w                # nuovo pod, il vecchio termina (Ctrl+C)
curl http://localhost:8888/               # {"status":"ok", "message": "v2"}
```
> ⏱️ Senza refresh Argo CD controlla Git ogni ~3 minuti: possono passare **3–6 minuti**.
> Premi **REFRESH** nell'interfaccia o usa `--refresh` per non aspettare.

Dopo la valutazione riporta il repo a v1 (stesso comando con `v2` → `v1`).

Domande probabili:
- **K3s vs K3d?** K3s è una distribuzione Kubernetes leggera installata sul sistema (servizio systemd). K3d esegue K3s **dentro container Docker**: un cluster si crea o distrugge in pochi secondi, senza VM.
- **Perché `application.yaml`?** Configurazione dichiarativa (GitOps): anche la definizione dell'app sta nel repo; sync automatico con `prune` (rimuove ciò che non è più in Git) e `selfHeal` (annulla le modifiche manuali).
- **Perché il repo `marboccu-iot`?** La subject vuole il login di un membro del gruppo nel nome del repo pubblico.
- **Porta 8888?** Service NodePort 30420 → k3d mappa `8888:30420` sull'host.
- **Come arriva l'interfaccia al PC?** `kubectl port-forward --address 0.0.0.0` nella VM + inoltro della porta 8080 della VM verso il PC.
- **`--server-side` in kubectl apply?** Le CRD recenti di Argo CD superano il limite di dimensione dell'apply client-side.

---

## 5. Problemi e soluzioni

| Problema | Soluzione |
|---|---|
| `ssh iot`: connection refused | La VM è spenta: `virsh -c qemu:///session start iot`, aspetta ~20 s |
| goinfre svuotato (VM sparita) | `vm/scripts/create_vm.sh` + `setup_vm.sh` (sezione 0), ~10–15 min |
| `vagrant up`: "domain already exists" | `vagrant destroy -f`, oppure `sudo virsh destroy marboccuS; sudo virsh undefine marboccuS --remove-all-storage` |
| p2: curl non risponde subito | Traefik sta partendo: aspetta 30–60 s (`kubectl get pods -n kube-system`) |
| Interfaccia Argo CD non raggiungibile | Il port-forward è morto. Nella VM: `nohup kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 &` |
| `argocd` CLI: "Unauthenticated" | `argocd login localhost:8080 --insecure --username admin --password <password>` |
| Argo CD non vede v2 | `argocd app get wil-playground --refresh` o REFRESH nell'interfaccia |
