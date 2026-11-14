---
title: "Installare NVIDIA Container Toolkit"
url: "2025/11/installing-nvidia-container-toolkit/"
description: "Guida all'installazione di NVIDIA Container Toolkit per abilitare il supporto GPU nei container Docker"
date: 2025-11-04T09:00:00+02:00
lastmod: 2025-11-04T09:00:00+02:00
draft: false
author: "Manzolo"
tags: ["nvidia", "gpu", "container-toolkit", "installation", "cuda"]
categories: ["Docker & Containers"]
series: ["Docker Essentials"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Installare NVIDIA Container Toolkit

Questa guida spiega come installare NVIDIA Container Toolkit, indispensabile per abilitare l'accelerazione GPU dentro i container Docker. È utile soprattutto per le applicazioni che sfruttano le GPU NVIDIA per attività come il machine learning e il calcolo scientifico con supporto GPU.

## Prerequisiti

Prima di procedere, assicurati di avere:

1.  **GPU NVIDIA:** una scheda grafica NVIDIA compatibile.
2.  **Driver NVIDIA:** gli ultimi driver NVIDIA stabili installati per il tuo sistema operativo. Di solito si scaricano dal [sito di NVIDIA](https://www.nvidia.com/drivers).
3.  **Docker:** Docker Engine installato e in esecuzione sul sistema. Segui la [guida ufficiale all'installazione di Docker](https://docs.docker.com/engine/install/) per il tuo sistema operativo.

## Passi di installazione

Segui questi passi per installare NVIDIA Container Toolkit su un sistema basato su Debian/Ubuntu. Per le altre distribuzioni Linux fai riferimento alla [documentazione ufficiale di NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html).

### 1. Configura il repository di NVIDIA Container Toolkit

Per prima cosa aggiungi la chiave GPG di NVIDIA Container Toolkit e configura il repository.

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
```

### 2. Aggiorna l'elenco dei pacchetti

Aggiorna l'elenco dei pacchetti del sistema per includere il nuovo repository:

```bash
sudo apt-get update
```

### 3. Installa NVIDIA Container Toolkit

Installa il pacchetto `nvidia-container-toolkit`:

```bash
sudo apt-get install -y nvidia-container-toolkit
```

### 4. Configura il demone Docker

Dopo l'installazione devi configurare il demone Docker perché riconosca il runtime NVIDIA. Di solito questo comporta il riavvio del servizio Docker.

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### 5. Verifica l'installazione

Per verificare che NVIDIA Container Toolkit sia installato e configurato correttamente, lancia un semplice container CUDA:

```bash
docker run --rm --gpus all nvidia/cuda:12.9.1-runtime-ubuntu24.04 nvidia-smi
```

Se l'installazione è andata a buon fine, dovresti vedere un output simile a quello di `nvidia-smi`, con le informazioni sulla tua GPU.

## Risoluzione dei problemi

*   Se qualcosa non va, assicurati che i driver NVIDIA siano aggiornati e installati correttamente.
*   Controlla i log del demone Docker per eventuali errori legati al runtime NVIDIA.
*   Fai riferimento alla [documentazione ufficiale di NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) per indicazioni più dettagliate sulla risoluzione dei problemi.
