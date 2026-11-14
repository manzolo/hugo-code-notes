---
title: "Container cifrato con LUKS"
url: "2025/10/luks-encrypted-container/"
date: 2025-10-05T15:30:00+02:00
lastmod: 2026-11-14T19:00:00+01:00
draft: false
author: "Manzolo"
tags: ["luks", "encryption", "portable", "usb", "quick-tip"]
categories: ["Quick Pills"]
series: ["Quick Pills Collection"]
weight: 3
ShowToc: false
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "Guida rapida per creare e usare container cifrati con LUKS e conservare i file al sicuro su Linux"
---

# 💊 Pillola rapida: container cifrato con LUKS

{{< callout type="info" >}}
**A cosa serve**: creare file container cifrati per conservare al sicuro i backup, tenere documenti riservati o avere volumi cifrati portatili. Funziona come un disco virtuale cifrato.
{{< /callout >}}

## 🔐 Preparazione rapida (5 minuti)

### 1. Installa gli strumenti necessari

```bash
sudo apt install cryptsetup
```

### 2. Crea il container cifrato

```bash
# Create a 10GB empty file (fast allocation)
fallocate -l 10G BackupCrypt.img

# Initialize LUKS encryption (you'll set a password)
sudo cryptsetup luksFormat BackupCrypt.img

# Open the encrypted container
sudo cryptsetup open BackupCrypt.img backup_crypt

# Create filesystem inside
sudo mkfs.ext4 /dev/mapper/backup_crypt

# Mount it
sudo mkdir -p /mnt/encrypted
sudo mount /dev/mapper/backup_crypt /mnt/encrypted

# Set permissions (optional - for your user)
sudo chown $USER:$USER /mnt/encrypted
```

### 3. Usa il tuo spazio cifrato

```bash
# Copy files
cp -r ~/Documents/sensitive/ /mnt/encrypted/

# Work with files normally
echo "Secret data" > /mnt/encrypted/secret.txt
```

### 4. Chiudi il container cifrato

```bash
# Unmount
sudo umount /mnt/encrypted

# Close LUKS container
sudo cryptsetup close backup_crypt
```

{{< callout type="success" >}}
**Fatto!** Adesso i tuoi dati sono cifrati. Senza la password, il file sembra fatto di dati casuali.
{{< /callout >}}

## 🔄 Uso quotidiano

### Aprire e montare

```bash
# Open with password prompt
sudo cryptsetup open BackupCrypt.img backup_crypt

# Mount
sudo mount /dev/mapper/backup_crypt /mnt/encrypted
```

### Chiudere e bloccare

```bash
# Always unmount first
sudo umount /mnt/encrypted

# Then close
sudo cryptsetup close backup_crypt
```

## 📋 Riferimento dei comandi

### Creare il container

| Comando | A cosa serve | Note |
|---------|--------------|------|
| `fallocate -l SIZE file.img` | Crea un file vuoto (veloce) | Dimensioni: 1G, 10G, 100G, ecc. |
| `dd if=/dev/zero of=file.img bs=1M count=10240` | Crea il file (più lento, più sicuro) | Lo sovrascrive con zeri |
| `cryptsetup luksFormat file.img` | Inizializza la cifratura LUKS | **Imposta la password** |

### Aprire/chiudere

| Comando | A cosa serve |
|---------|--------------|
| `cryptsetup open file.img name` | Apre il container cifrato |
| `cryptsetup close name` | Chiude il container cifrato |
| `cryptsetup status name` | Controlla se il container è aperto |

### Filesystem

| Comando | A cosa serve |
|---------|--------------|
| `mkfs.ext4 /dev/mapper/name` | Crea un filesystem ext4 |
| `mkfs.xfs /dev/mapper/name` | Crea un filesystem XFS |
| `mkfs.btrfs /dev/mapper/name` | Crea un filesystem Btrfs |

## 💡 Consigli da esperto

<details>
<summary><strong>Creare il container con dd (più sicuro, più lento)</strong></summary>

Usa `dd` al posto di `fallocate` per una sicurezza maggiore: sovrascrive il file con zeri:

```bash
# Create 10GB file (10240 MB)
dd if=/dev/zero of=BackupCrypt.img bs=1M count=10240 status=progress

# Or use random data (MUCH slower but most secure)
dd if=/dev/urandom of=BackupCrypt.img bs=1M count=10240 status=progress
```

**Quando usarli:**
- `fallocate`: veloce, va bene nella maggior parte dei casi
- `dd` con `/dev/zero`: sovrascrive quello che c'era prima nei blocchi appena assegnati al file (non cancella il resto del disco)
- `dd` con `/dev/urandom`: massima sicurezza, molto lento
</details>

<details>
<summary><strong>Aggiungere più password (key slot)</strong></summary>

LUKS supporta più password: fino a 32 key slot con LUKS2 (il formato predefinito di cryptsetup dalla 2.1), 8 con LUKS1:

```bash
# Add a second password
sudo cryptsetup luksAddKey BackupCrypt.img

# Remove a password (need existing password)
sudo cryptsetup luksRemoveKey BackupCrypt.img

# List key slots
sudo cryptsetup luksDump BackupCrypt.img
```
</details>

<details>
<summary><strong>Mount automatico con /etc/fstab</strong></summary>

Per un mount permanente (sconsigliato per i container portatili). La sola riga in fstab non basta: `/dev/mapper/backup_crypt` esiste solo dopo che hai aperto il container (a mano, oppure con una voce in `/etc/crypttab`):

```bash
# Add to /etc/fstab
/dev/mapper/backup_crypt  /mnt/encrypted  ext4  defaults,noauto  0  0

# fstab only knows the mapper device: open the container first, then mount
sudo cryptsetup open BackupCrypt.img backup_crypt
sudo mount /mnt/encrypted
```
</details>

<details>
<summary><strong>Backup dell'header LUKS (FONDAMENTALE!)</strong></summary>

Se l'header si corrompe, i tuoi dati sono **persi per sempre**:

```bash
# Backup header
sudo cryptsetup luksHeaderBackup BackupCrypt.img --header-backup-file BackupCrypt_header.img

# Store this file SEPARATELY from your encrypted container!

# Restore header if needed
sudo cryptsetup luksHeaderRestore BackupCrypt.img --header-backup-file BackupCrypt_header.img
```
</details>

<details>
<summary><strong>Uno script per montare senza fatica</strong></summary>

Salvalo come `mount_encrypted.sh`:

```bash
#!/bin/bash
CONTAINER="$HOME/BackupCrypt.img"
MAPPER_NAME="backup_crypt"
MOUNT_POINT="/mnt/encrypted"

if [ "$1" = "open" ]; then
    sudo cryptsetup open "$CONTAINER" "$MAPPER_NAME"
    sudo mkdir -p "$MOUNT_POINT"
    sudo mount "/dev/mapper/$MAPPER_NAME" "$MOUNT_POINT"
    sudo chown $USER:$USER "$MOUNT_POINT"
    echo "✅ Encrypted container mounted at $MOUNT_POINT"
    
elif [ "$1" = "close" ]; then
    sudo umount "$MOUNT_POINT"
    sudo cryptsetup close "$MAPPER_NAME"
    echo "🔒 Encrypted container closed"
    
else
    echo "Usage: $0 {open|close}"
fi
```

Rendilo eseguibile e usalo:
```bash
chmod +x mount_encrypted.sh
./mount_encrypted.sh open   # Mount
./mount_encrypted.sh close  # Unmount
```
</details>

<details>
<summary><strong>Usare un key file al posto della password</strong></summary>

Per l'automazione (meno sicuro, ma comodo):

```bash
# Generate random key file
dd if=/dev/urandom of=~/backup.key bs=512 count=1
chmod 600 ~/backup.key

# Add key file to LUKS
sudo cryptsetup luksAddKey BackupCrypt.img ~/backup.key

# Open with key file (no password prompt)
sudo cryptsetup open BackupCrypt.img backup_crypt --key-file ~/backup.key

# ⚠️ Protect the key file! Anyone with it can decrypt your data
```
</details>

<details>
<summary><strong>Controllare stato e informazioni del container</strong></summary>

```bash
# Is container open?
sudo cryptsetup status backup_crypt

# Show LUKS header info
sudo cryptsetup luksDump BackupCrypt.img

# Check filesystem
sudo fsck -f /dev/mapper/backup_crypt

# Show disk usage
df -h /mnt/encrypted
```
</details>

## 🎯 Casi d'uso comuni

### Spazio cifrato per i backup

```bash
# Create large container for backups
fallocate -l 100G encrypted_backup.img
sudo cryptsetup luksFormat encrypted_backup.img
sudo cryptsetup open encrypted_backup.img backup
sudo mkfs.ext4 /dev/mapper/backup
sudo mount /dev/mapper/backup /mnt/backup

# Backup with rsync
rsync -av --progress ~/Documents/ /mnt/backup/

# Close when done
sudo umount /mnt/backup
sudo cryptsetup close backup
```

### Chiavetta USB cifrata portatile

```bash
# Create small container for USB drive
fallocate -l 2G portable.img
sudo cryptsetup luksFormat portable.img
# ... setup filesystem ...

# Copy to USB
cp portable.img /media/usb/

# Use anywhere with cryptsetup installed!
```

### Cifratura per il cloud storage

```bash
# Create container for cloud sync
fallocate -l 5G cloud_vault.img
# ... setup ...

# Sync to Dropbox/Drive (encrypted!)
cp cloud_vault.img ~/Dropbox/
```

## 🔍 Capire le dimensioni dei file

```bash
# Check file size
ls -lh BackupCrypt.img

# Check actual disk usage
du -h BackupCrypt.img

# Check available space inside
df -h /mnt/encrypted
```

**Con fallocate:**
- Dimensione del file: 10G (blocchi preallocati, non è un file sparse)
- Spazio occupato su disco: 10G da subito (un file sparse lo crea solo `truncate -s`)
- Creazione veloce

**Con dd:**
- Dimensione del file: 10G
- Spazio occupato su disco: 10G esatti, da subito
- Creazione più lenta, più sicuro

## ⚠️ Avvertenze importanti

{{< callout type="danger" >}}
**Punti critici:**

1. **Fai il backup dell'header LUKS**: senza, i tuoi dati sono **irrecuperabili**
2. **Ricordati la password**: non c'è modo di recuperarla
3. **Smonta sempre prima di chiudere**: eviti di corrompere i dati
4. **Chiudi prima di spegnere**: non lasciare container aperti
5. **Proteggi i key file**: sono delicati quanto le password
{{< /callout >}}

## 🔧 Risoluzione dei problemi

<details>
<summary><strong>«Device or resource busy» alla chiusura</strong></summary>

**Problema**: il container non si chiude, «device is busy»

**Soluzione**:
```bash
# Find what's using it
sudo lsof /mnt/encrypted

# Force unmount if needed
sudo umount -l /mnt/encrypted

# Then close
sudo cryptsetup close backup_crypt
```
</details>

<details>
<summary><strong>Password non accettata</strong></summary>

**Problema**: «No key available with this passphrase»

**Soluzione**:
```bash
# Verify LUKS header is intact
sudo cryptsetup luksDump BackupCrypt.img

# Try each key slot in use (luksDump lists them: 0-7 on LUKS1, up to 31 on LUKS2)
sudo cryptsetup open BackupCrypt.img backup_crypt --key-slot 0
sudo cryptsetup open BackupCrypt.img backup_crypt --key-slot 1
# ... etc

# If truly forgotten: data is LOST (by design)
# Restore from header backup if available
```
</details>

<details>
<summary><strong>File del container corrotto</strong></summary>

**Problema**: il container non si apre, errori che riguardano l'header

**Soluzione**:
```bash
# Restore header backup (if you made one!)
sudo cryptsetup luksHeaderRestore BackupCrypt.img \
    --header-backup-file BackupCrypt_header.img

# Check filesystem after opening
sudo cryptsetup open BackupCrypt.img backup_crypt
sudo fsck -f /dev/mapper/backup_crypt
```
</details>

<details>
<summary><strong>«Permission denied» quando accedi ai file</strong></summary>

**Problema**: non riesci a scrivere sul volume cifrato montato

**Soluzione**:
```bash
# Change ownership to your user
sudo chown -R $USER:$USER /mnt/encrypted

# Or set permissions
sudo chmod -R 755 /mnt/encrypted
```
</details>

## 📊 Dimensioni consigliate

| Caso d'uso | Dimensione consigliata | Metodo di creazione |
|------------|------------------------|---------------------|
| Piccoli segreti | 100M - 1G | fallocate |
| Documenti personali | 5G - 10G | fallocate |
| Backup delle foto | 50G - 100G | fallocate o dd |
| Backup completo del sistema | 100G+ | dd (sicurezza) |
| Sincronizzazione sul cloud | 1G - 5G | dd (sicurezza) |

## 🔐 Livelli di sicurezza

| Metodo | Sicurezza | Velocità | Ideale per |
|--------|-----------|----------|------------|
| fallocate | Buona | Molto veloce | Uso generico |
| dd + /dev/zero | Migliore | Media | Dati importanti |
| dd + /dev/urandom | Massima | Molto lento | Massima sicurezza |

## 🚀 Cheat sheet dei comandi rapidi

```bash
# CREATE
fallocate -l 10G backup.img
sudo cryptsetup luksFormat backup.img
sudo cryptsetup open backup.img vault
sudo mkfs.ext4 /dev/mapper/vault
sudo mount /dev/mapper/vault /mnt/vault

# USE
cd /mnt/vault
# ... work with files ...

# CLOSE
sudo umount /mnt/vault
sudo cryptsetup close vault

# BACKUP HEADER (DO THIS!)
sudo cryptsetup luksHeaderBackup backup.img --header-backup-file backup_header.img

# CHECK STATUS
sudo cryptsetup status vault
df -h /mnt/vault
```

---

*Tieni al sicuro i tuoi dati riservati con la cifratura LUKS!*
