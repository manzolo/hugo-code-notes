---
title: "Guida a QEMU: immagini disco e gestione delle VM"
url: "bash/qemu/"
#description: ""
date: 2025-09-26T10:00:00+01:00
lastmod: 2025-09-26T10:00:00+01:00
draft: false
author: "Manzolo"
tags: ["qemu", "virtualization", "kvm", "vm", "commands"]
categories: ["Command Reference"]
series: ["Command Line Mastery"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Guida a QEMU: immagini disco e gestione delle VM

## Introduzione

QEMU è un potente emulatore e virtualizzatore open source per far girare macchine virtuali (VM) e gestire immagini disco sui sistemi Linux. Supporta un'ampia gamma di architetture e offre gli strumenti per creare, manipolare e avviare VM con configurazioni flessibili. Questa guida copre i comandi QEMU essenziali per la gestione delle immagini disco e delle VM, con esempi pratici per sistemisti e sviluppatori.

## Prerequisiti

- QEMU installato su un sistema Linux (`qemu-system-x86_64 --version` per verificarlo).
- Privilegi di root o sudo per alcune operazioni (es. installare QEMU o accedere a KVM).
- Una conoscenza di base dei comandi del terminale Linux e dei concetti di virtualizzazione.

Installa QEMU su Ubuntu/Debian:

```bash
sudo apt update
sudo apt install qemu-system-x86 qemu-utils
```

Per l'accelerazione KVM (consigliata per avere prestazioni migliori):

```bash
sudo apt install cpu-checker   # provides kvm-ok; KVM itself comes with qemu-system-x86
```

Verifica il supporto a KVM:

```bash
kvm-ok
```

## Gestione delle immagini disco

QEMU usa `qemu-img` per creare, convertire e gestire le immagini disco delle VM. I formati più comuni sono `qcow2` (copy-on-write, efficiente) e `raw`.

### Creare immagini disco

```bash
# Create a 20GB qcow2 disk image
qemu-img create -f qcow2 disk.qcow2 20G

# Create a 10GB raw disk image
qemu-img create -f raw disk.raw 10G
```

- **Spiegazione**:
  - `-f qcow2`: indica il formato del disco (qcow2 supporta snapshot e compressione).
  - `disk.qcow2`: nome del file di uscita.
  - `20G`: dimensione del disco (accetta i suffissi K, M, G, T).

### Ispezionare le immagini disco

```bash
# Display image information
qemu-img info disk.qcow2

# Check image for errors
qemu-img check disk.qcow2
```

### Ridimensionare le immagini disco

```bash
# Increase disk size by 10GB
qemu-img resize disk.qcow2 +10G

# Shrink disk (only if unused space, requires check first)
qemu-img resize --shrink disk.qcow2 15G
```

### Convertire le immagini disco

```bash
# Convert qcow2 to raw format
qemu-img convert -f qcow2 -O raw disk.qcow2 disk.raw

# Convert raw to qcow2 with compression
qemu-img convert -f raw -O qcow2 -c disk.raw disk_compressed.qcow2
```

### Snapshot

```bash
# Create a snapshot in a qcow2 image
qemu-img snapshot -c snapshot1 disk.qcow2

# List snapshots
qemu-img snapshot -l disk.qcow2

# Revert to a snapshot
qemu-img snapshot -a snapshot1 disk.qcow2

# Delete a snapshot
qemu-img snapshot -d snapshot1 disk.qcow2
```

### Esempio: creare e ispezionare un'immagine disco

Crea un'immagine qcow2 da 30 GB e controllane i dettagli:

```bash
qemu-img create -f qcow2 ubuntu-vm.qcow2 30G
qemu-img info ubuntu-vm.qcow2
```

- **Output** (esempio):
  ```
  image: ubuntu-vm.qcow2
  file format: qcow2
  virtual size: 30 GiB
  disk size: 196 KiB
  ```

## Gestione delle macchine virtuali

I comandi `qemu-system-*` di QEMU (es. `qemu-system-x86_64`) servono ad avviare e gestire le VM.

### Avvio di base di una VM

Avvia una VM con un'immagine disco e un file ISO:

```bash
qemu-system-x86_64 \
  -m 2G \
  -hda ubuntu-vm.qcow2 \
  -cdrom ubuntu-24.04.iso \
  -boot d \
  -enable-kvm
```

- **Spiegazione**:
  - `-m 2G`: assegna 2 GB di RAM.
  - `-hda`: indica l'immagine del disco principale.
  - `-cdrom`: collega una ISO per l'installazione.
  - `-boot d`: fa il boot dal CD-ROM.
  - `-enable-kvm`: abilita KVM per l'accelerazione hardware.

### Rete

```bash
# User-mode networking (NAT)
qemu-system-x86_64 -m 2G -hda ubuntu-vm.qcow2 -netdev user,id=net0 -device virtio-net,netdev=net0

# Bridge networking (requires setup)
qemu-system-x86_64 -m 2G -hda ubuntu-vm.qcow2 -netdev bridge,id=net0,br=br0 -device virtio-net,netdev=net0
```

- **Nota**: la rete in bridge richiede un bridge di rete già configurato (es. `br0`) sull'host.

### CPU e memoria

```bash
# Specify 4 CPU cores and 4GB RAM
qemu-system-x86_64 -m 4G -smp 4 -hda ubuntu-vm.qcow2 -enable-kvm
```

- **Spiegazione**:
  - `-smp 4`: assegna 4 core di CPU.
  - `-m 4G`: assegna 4 GB di RAM.

### Esempio: avviare una VM con VNC

Avvia una VM con accesso VNC per avere l'interfaccia grafica da remoto:

```bash
qemu-system-x86_64 \
  -m 2G \
  -hda ubuntu-vm.qcow2 \
  -vnc :1 \
  -enable-kvm
```

- **Uso**: collegati alla VM con un client VNC (es. `vncviewer localhost:5901`).

### Esempio: installare un sistema operativo

Fai il boot da una ISO per installare Ubuntu:

```bash
qemu-system-x86_64 \
  -m 4G \
  -smp 2 \
  -hda ubuntu-vm.qcow2 \
  -cdrom ubuntu-24.04.iso \
  -boot d \
  -vnc :1 \
  -enable-kvm
```

- **Spiegazione**: fa il boot dalla ISO, assegna 4 GB di RAM e 2 CPU, e offre l'accesso via VNC.

## Uno script pratico

Crea uno script per gestire una VM QEMU e la sua immagine disco:

```bash
#!/bin/bash
# manage_qemu.sh

echo "=== QEMU VM Management ==="
echo "Current directory: $(pwd)"
echo ""

# Create disk image if it doesn't exist
if [ ! -f ubuntu-vm.qcow2 ]; then
  echo "Creating disk image..."
  qemu-img create -f qcow2 ubuntu-vm.qcow2 20G
fi

echo "Disk image info:"
qemu-img info ubuntu-vm.qcow2
echo ""

echo "Starting VM..."
qemu-system-x86_64 \
  -m 2G \
  -smp 2 \
  -hda ubuntu-vm.qcow2 \
  -netdev user,id=net0 -device virtio-net,netdev=net0 \
  -enable-kvm &

echo "VM started in background. Connect via VNC (port 5900) if enabled."
```

Rendilo eseguibile:

```bash
chmod +x manage_qemu.sh
./manage_qemu.sh
```

## Consigli pratici

{{< callout type="tip" >}}
**Consiglio**: usa `qcow2` per le immagini disco, così risparmi spazio e hai gli snapshot. Abilita KVM (`-enable-kvm`) per avere prestazioni migliori sull'hardware che lo supporta.
```bash
qemu-system-x86_64 -enable-kvm -m 2G -hda disk.qcow2
```
{{< /callout >}}

{{< callout type="warning" >}}
**Attenzione**: QEMU senza l'accelerazione KVM è molto più lento. Assicurati che KVM sia abilitato e che la CPU supporti la virtualizzazione (controlla con `kvm-ok`).
{{< /callout >}}

{{< callout type="success" title="Quick Reference" >}}
**Comandi essenziali:**
- `qemu-img create`: crea una nuova immagine disco.
- `qemu-system-x86_64`: avvia una VM.
- `qemu-img snapshot`: gestisce gli snapshot del disco.
- Driver `virtio`: usali per avere prestazioni migliori (es. `-device virtio-net`).
{{< /callout >}}

## Risoluzione dei problemi

- **KVM non funziona**: controlla che i moduli KVM siano caricati (`lsmod | grep kvm`) e che il tuo utente sia nel gruppo `kvm` (`sudo usermod -aG kvm $USER`).
- **Errori nell'immagine disco**: `qemu-img check` fa solo la diagnosi; per riparare aggiungi `-r leaks` o `-r all` (a VM spenta, e dopo aver fatto una copia dell'immagine).
- **La VM non si avvia**: verifica l'immagine disco, la ISO o l'ordine di boot (`-boot`).
- **Problemi di rete**: controlla la configurazione di rete con `ip addr` e verifica che le impostazioni di `-netdev` siano corrette.

## Prossimi passi

Nei prossimi tutorial vedremo:
- La rete avanzata in QEMU (es. TAP, configurazioni in bridge).
- L'uso di `libvirt` con QEMU per gestire le VM più comodamente.
- La creazione e la gestione degli snapshot delle VM.
- L'automazione del deploy delle VM con script o Ansible.

## Esercizi

1. **Gestione dei dischi**: crea un'immagine qcow2 da 50 GB, portala a 60 GB e fai uno snapshot.
2. **Configurazione di una VM**: avvia una VM con 4 GB di RAM, 2 CPU e la rete in user-mode.
3. **Installazione di un sistema operativo**: installa una distro Linux da una ISO e configura l'accesso VNC.
4. **Automazione**: scrivi uno script che avvia più VM con immagini disco diverse.

## Risorse

- [Documentazione di QEMU](https://www.qemu.org/docs/master/)
- [Wiki di QEMU](https://wiki.qemu.org/Main_Page)
- [Guida a QEMU di Ubuntu](https://help.ubuntu.com/community/KVM)
- [Guida alla virtualizzazione di Red Hat](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_virtualization)

---

*Fai pratica con i comandi di QEMU per padroneggiare la gestione delle immagini disco e delle VM!*
