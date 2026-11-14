---
title: "Manzolo PPA (il mio repository Ubuntu)"
url: "2025/11/manzolo-ppa-my-own-ubuntu-repository/"
date: 2025-11-08T18:30:00+02:00
lastmod: 2026-04-24T00:00:00+02:00
draft: false
author: "Manzolo"
tags: ["ppa", "ubuntu", "repository", "apt", "custom-packages"]
categories: ["Package Management"]
series: ["System Administration Basics"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Manzolo PPA — Il mio repository Ubuntu personale

**Installa i miei strumenti direttamente con `apt`!**  
Repository sicuro, firmato con GPG, ospitato su **https://ubuntu-repo.manzolo.it**

**Ubuntu 26.04 (resolute) — PIENAMENTE SUPPORTATO**

```bash
wget -qO - https://ubuntu-repo.manzolo.it/KEY.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/manzolo-repo.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/manzolo-repo.gpg] https://ubuntu-repo.manzolo.it resolute main" | sudo tee /etc/apt/sources.list.d/manzolo-repo.list
sudo apt update
```

**Ubuntu 24.04 (noble) — PIENAMENTE SUPPORTATO**

```bash
wget -qO - https://ubuntu-repo.manzolo.it/KEY.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/manzolo-repo.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/manzolo-repo.gpg] https://ubuntu-repo.manzolo.it noble main" | sudo tee /etc/apt/sources.list.d/manzolo-repo.list
sudo apt update
```

## Installa i miei pacchetti

### Il pacchetto manzolo-chroot
```bash
sudo apt install manzolo-chroot
```
### Cerca tutti i miei strumenti
```bash
apt search manzolo
```

## Verifica che funzioni tutto
```bash
apt policy | grep manzolo
```

## Rimuovi il repository (se mai volessi)
```bash
sudo rm /etc/apt/sources.list.d/manzolo-repo.list
sudo rm /etc/apt/trusted.gpg.d/manzolo-repo.gpg
sudo apt update
```
