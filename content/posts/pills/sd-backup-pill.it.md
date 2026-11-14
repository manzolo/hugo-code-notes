---
title: "Backup e ripristino di una scheda SD"
url: "2025/10/sd-card-backup-and-restore/"
date: 2025-10-05T14:30:00+02:00
draft: false
author: "Manzolo"
tags: ["backup", "sd-card", "dd", "raspberry-pi", "quick-tip"]
categories: ["Quick Pills"]
series: ["Quick Pills Collection"]
weight: 1
ShowToc: false
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "Guida rapida al backup e al ripristino delle schede SD con dd e la compressione gzip"
---

# 💊 Pillola: backup e ripristino di una scheda SD

{{< callout type="info" >}}
**A cosa serve**: fare il backup compresso delle schede SD del Raspberry Pi, delle chiavette USB avviabili o di qualunque dispositivo a blocchi.
{{< /callout >}}

## 🔄 Backup della scheda SD

Crea un backup compresso della scheda SD:

```bash
sudo dd bs=1M status=progress if=/dev/sdb | gzip > ~/Desktop/retropie_`date +%d%m%y`.gz
```

**Cosa fa:**
- `dd bs=1M`: legge il dispositivo a blocchi da 1 MB
- `status=progress`: mostra l'avanzamento durante il backup
- `if=/dev/sdb`: file di ingresso (la tua scheda SD - **verifica con `lsblk`!**)
- `gzip`: comprime l'uscita al volo
- `date +%d%m%y`: aggiunge la data al nome del file (es. `retropie_051025.gz`)

{{< callout type="danger" >}}
**⚠️ Fondamentale**: verifica sempre il nome del dispositivo con `lsblk` prima di lanciare dd. Con il dispositivo sbagliato distruggi i tuoi dati!
{{< /callout >}}

## 📥 Ripristino della scheda SD

Ripristina il backup compresso su una scheda SD:

```bash
gzip -dc ~/Desktop/retropie_051025.gz | sudo dd bs=1M of=/dev/sdb status=progress
```

**Cosa fa:**
- `gzip -dc`: decomprime il backup su stdout
- `dd bs=1M`: scrive a blocchi da 1 MB
- `of=/dev/sdb`: file di uscita (la scheda SD di destinazione)
- `status=progress`: mostra l'avanzamento durante il ripristino

## 🔍 Verifica il dispositivo

Prima di un backup o di un ripristino, controlla sempre qual è il dispositivo della scheda SD:

```bash
# List all block devices
lsblk

# Example output:
# NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
# sda      8:0    0  500G  0 disk 
# └─sda1   8:1    0  500G  0 part /
# sdb      8:16   1   32G  0 disk 
# └─sdb1   8:17   1   32G  0 part /media/sdcard
```

In questo esempio `sdb` è la scheda SD da 32 GB.

## 💡 Consigli pratici

<details>
<summary><strong>Mostrare il tempo rimanente stimato</strong></summary>

```bash
# Install pv (pipe viewer) for better progress indication
sudo apt install pv

# Backup with pv
sudo dd bs=1M if=/dev/sdb | pv -s 32G | gzip > ~/Desktop/backup_`date +%d%m%y`.gz

# Restore with pv
gzip -dc ~/Desktop/backup_051025.gz | pv | sudo dd bs=1M of=/dev/sdb
```
</details>

<details>
<summary><strong>Backup del solo spazio usato (immagine sparse)</strong></summary>

Con i filesystem ext4 puoi creare un'immagine sparse che salta i blocchi vuoti:

```bash
# Mount the partition first
sudo mount /dev/sdb1 /mnt

# Create sparse backup
sudo tar -czSpf ~/Desktop/sparse_backup_`date +%d%m%y`.tar.gz -C /mnt .

# Restore sparse backup
sudo tar -xzSpf ~/Desktop/sparse_backup_051025.tar.gz -C /mnt
```
</details>

<details>
<summary><strong>Verificare l'integrità del backup</strong></summary>

```bash
# Test if the compressed backup is valid
gzip -t ~/Desktop/retropie_051025.gz

# If successful, no output
# If corrupted, you'll see an error message
```
</details>

<details>
<summary><strong>Backup su un server remoto via SSH</strong></summary>

```bash
# Backup directly to remote server
sudo dd bs=1M if=/dev/sdb | gzip | ssh user@server 'cat > ~/backups/retropie_`date +%d%m%y`.gz'

# Restore from remote server
ssh user@server 'cat ~/backups/retropie_051025.gz' | gzip -dc | sudo dd bs=1M of=/dev/sdb
```
</details>

## ⚠️ Checklist di sicurezza

Prima di lanciare un comando dd:

- [ ] Nome del dispositivo verificato con `lsblk`
- [ ] La scheda SD è **smontata** (e non è il disco di sistema!)
- [ ] C'è abbastanza spazio su disco per il backup
- [ ] Parametri `if=` (ingresso) e `of=` (uscita) ricontrollati
- [ ] File di backup provato dopo la creazione

{{< callout type="danger" >}}
**Ricorda**: `dd` è soprannominato «disk destroyer» non a caso. Basta un errore di battitura per cancellare il disco di sistema. Ricontrolla sempre!
{{< /callout >}}

## 📊 Casi d'uso tipici

| Scenario | Comando |
|----------|---------|
| Backup del Raspberry Pi | `sudo dd if=/dev/sdb \| gzip > ~/rpi_backup.gz` |
| Backup di RetroPie | `sudo dd if=/dev/sdb \| gzip > ~/retropie.gz` |
| Backup di una USB avviabile | `sudo dd if=/dev/sdc \| gzip > ~/bootusb.gz` |
| Clonare su una SD più grande | `sudo dd if=/dev/sdb of=/dev/sdc bs=1M status=progress` |


---

*Backup rapidi, efficaci e compressi per le tue schede SD e i tuoi dispositivi avviabili!*
