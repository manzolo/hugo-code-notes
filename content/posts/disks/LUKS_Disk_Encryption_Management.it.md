---
title: "Guida alla gestione della cifratura dei dischi con LUKS (Debian/Ubuntu)"
url: "2025/10/luks-disk-encryption-management-guide-debian/ubuntu/"
date: 2025-10-03T14:00:00+02:00
lastmod: 2026-11-14T19:00:00+01:00
draft: false
author: "Manzolo"
tags: ["luks", "encryption", "cryptsetup", "security", "disk-encryption"]
categories: ["Storage & Disks"]
series: ["Linux Storage Deep Dive"]
weight: 5
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Guida alla gestione della cifratura dei dischi con LUKS (Debian/Ubuntu)

## Introduzione

LUKS (Linux Unified Key Setup) è uno standard per la cifratura dei dischi su Linux che offre un modo indipendente dalla piattaforma di cifrare i device a blocchi, come partizioni o dischi interi. Supporta più passphrase (chiavi), una derivazione sicura delle chiavi e l'integrazione con altri strati di storage come LVM o ZFS. Questa guida spiega come creare, modificare e gestire dischi cifrati con LUKS su sistemi Debian/Ubuntu: configurazione, gestione delle chiavi, mount e manutenzione.

LUKS protegge i dati a riposo, ed è quindi essenziale per mettere le informazioni sensibili al riparo dagli accessi non autorizzati.

## Che cos'è LUKS?

LUKS è una specifica di cifratura dei dischi che usa una master key protetta da una o più passphrase fornite dall'utente. Le caratteristiche principali:
- **Più chiavi**: fino a 32 key slot con LUKS2 (8 con il vecchio LUKS1) per passphrase o keyfile diversi.
- **Header**: conserva i metadati (cifrario, hash, key slot) all'inizio del device.
- **Integrazione**: funziona con LVM (volumi cifrati), loop device (file cifrati) o dischi interi.
- **Sicurezza**: usa cifrari robusti (per esempio AES-XTS) e una funzione di derivazione della chiave per rinforzare la passphrase: Argon2id con LUKS2, il formato predefinito di cryptsetup dalla 2.1 (Ubuntu 20.04, Debian 11), PBKDF2 con LUKS1.
- **Sblocco**: i device vengono «aperti» creando un device mapper decifrato (per esempio `/dev/mapper/cryptdisk`).

LUKS si gestisce con lo strumento `cryptsetup`, che permette di cifrare partizioni, container o array RAID.

## Prerequisiti

- **Debian/Ubuntu**: versione 20.04 o successiva (supporto a cryptsetup).
- **cryptsetup installato**: il pacchetto per gestire LUKS.
- **Dischi/partizioni**: device inutilizzati (per esempio `/dev/sdb1`, file di loop). **Attenzione**: la cifratura cancella i dati: fai prima un backup.
- **Accesso root**: i comandi richiedono `sudo`.
- **Backup**: fai sempre il backup dei dati e degli header LUKS prima di ogni modifica.

Installa cryptsetup su Debian/Ubuntu:
```bash
sudo apt update
sudo apt install cryptsetup
```

Verifica l'installazione:
```bash
cryptsetup --version  # Check version
lsblk  # List devices
```

## Avvertenza fondamentale: controlla i device prima di cifrare

{{< callout type="warning" >}}
**Massima attenzione**: prima di formattare o cifrare un device con LUKS, usa `lsblk` o `fdisk -l` per verificare di aver scelto quello giusto (per esempio `/dev/sdb1`). La formattazione LUKS cancella tutti i dati sul device, e scegliere quello sbagliato (per esempio il disco di root) può voler dire perdere tutto. Ricontrolla sempre lo schema dei device e fai il backup dei dati importanti, header LUKS compreso, prima di procedere.
{{< /callout >}}

## Come si usa LUKS

### 1. Creare un device cifrato
Usa `cryptsetup luksFormat` per inizializzare LUKS su un device.

Sintassi di base:
```bash
sudo cryptsetup luksFormat [options] <device>
```
- `--cipher aes-xts-plain64`: il cifrario consigliato (predefinito).
- `--key-size 512`: per una cifratura più robusta.

#### Esempi di creazione
- **Cifrare una partizione**:
  ```bash
  sudo cryptsetup luksFormat /dev/sdb1  # Prompts for passphrase
  ```
- **Cifrare un disco intero**:
  ```bash
  sudo cryptsetup luksFormat /dev/sdb
  ```
- **Creare un file container cifrato** (loop device):
  ```bash
  dd if=/dev/zero of=/path/to/container.img bs=1M count=1024  # 1GB file
  sudo losetup /dev/loop0 /path/to/container.img
  sudo cryptsetup luksFormat /dev/loop0
  ```

### 2. Aprire e montare il device cifrato
Sblocca il device per creare il mapper, poi formattalo e montalo.

- **Aprire (sbloccare)**:
  ```bash
  sudo cryptsetup luksOpen /dev/sdb1 cryptdisk  # Prompts for passphrase
  ```
- **Formattare e montare** (la prima volta):
  ```bash
  sudo mkfs.ext4 /dev/mapper/cryptdisk
  sudo mkdir /mnt/crypt
  sudo mount /dev/mapper/cryptdisk /mnt/crypt
  ```
- **Chiudere (bloccare)**:
  ```bash
  sudo umount /mnt/crypt
  sudo cryptsetup luksClose cryptdisk
  ```

### 3. Modificare un device cifrato
Aggiungere o togliere chiavi, cambiare passphrase, ridimensionare.

- **Aggiungere una nuova chiave**:
  ```bash
  sudo cryptsetup luksAddKey /dev/sdb1  # Prompts for existing and new passphrase
  ```
- **Togliere una chiave**:
  ```bash
  sudo cryptsetup luksRemoveKey /dev/sdb1  # Prompts for the key to remove
  ```
- **Cambiare la passphrase**:
  ```bash
  sudo cryptsetup luksChangeKey /dev/sdb1  # Prompts for old and new
  ```
- **Ridimensionare (con LVM all'interno)**:
  ```bash
  sudo cryptsetup resize cryptdisk
  sudo pvresize /dev/mapper/cryptdisk  # If using LVM
  sudo lvextend -L +10G /dev/myvg/mylv
  sudo resize2fs /dev/myvg/mylv
  ```

- **Backup/ripristino dell'header**:
  ```bash
  sudo cryptsetup luksHeaderBackup /dev/sdb1 --header-backup-file header.backup
  sudo cryptsetup luksHeaderRestore /dev/sdb1 --header-backup-file header.backup
  ```

### 4. Gestire i device LUKS
Monitorare, cancellare o integrare con il boot.

- **Controllare lo stato**:
  ```bash
  sudo cryptsetup luksDump /dev/sdb1  # Show key slots and metadata
  sudo cryptsetup status cryptdisk    # Mapper status
  ```
- **Cancellare LUKS (distruttivo!)**:
  ```bash
  sudo cryptsetup erase /dev/sdb1
  ```
- **Mount automatico al boot**: modifica `/etc/crypttab` e `/etc/fstab` (per esempio per la cifratura dell'intero disco in fase di installazione).

## Esempi

### Esempio 1: creare e usare una partizione cifrata
```bash
# Verify devices
lsblk

# Create LUKS on partition
sudo cryptsetup luksFormat /dev/sdb1

# Open and format
sudo cryptsetup luksOpen /dev/sdb1 cryptdisk
sudo mkfs.ext4 /dev/mapper/cryptdisk

# Mount and test
sudo mkdir /mnt/crypt
sudo mount /dev/mapper/cryptdisk /mnt/crypt
echo "Secret data" > /mnt/crypt/test.txt

# Close
sudo umount /mnt/crypt
sudo cryptsetup luksClose cryptdisk
```

**Output** (estratto di luksDump):
```
LUKS header information
Version:        2
...
Data segments:
  0: crypt
        offset: 16777216 [bytes]
        length: (whole device)
        cipher: aes-xts-plain64
...
Keyslots:
  0: luks2
        Key:        512 bits
        ...
        PBKDF:      argon2id
...
```

### Esempio 2: aggiungere una chiave e ridimensionare
```bash
# Open device
sudo cryptsetup luksOpen /dev/sdb1 cryptdisk

# Add new key
sudo cryptsetup luksAddKey /dev/sdb1

# Assume LVM inside: Resize
sudo cryptsetup resize cryptdisk
sudo pvresize /dev/mapper/cryptdisk
sudo lvextend -L +5G /dev/myvg/mylv
sudo resize2fs /dev/myvg/mylv

# Close
sudo cryptsetup luksClose cryptdisk
```

### Esempio 3: backup e ripristino dell'header
```bash
sudo cryptsetup luksHeaderBackup /dev/sdb1 --header-backup-file luks_header.backup
# Simulate damage...
sudo cryptsetup luksHeaderRestore /dev/sdb1 --header-backup-file luks_header.backup
```

## I comandi, uno per uno

- **luksFormat**: inizializza LUKS su un device.
- **luksOpen/luksClose**: sbloccano/bloccano il device cifrato (sintassi vecchia, ancora accettata; la forma attuale è `open`/`close`).
- **luksAddKey/luksRemoveKey/luksChangeKey**: gestiscono i key slot.
- **resize**: allarga il device cifrato (seguito dal ridimensionamento del filesystem interno).
- **luksHeaderBackup/Restore**: salvano/ripristinano i metadati.
- **luksDump/status**: mostrano informazioni e stato di LUKS.

Opzioni comuni: `--cipher`, `--key-size`, `--hash` per una sicurezza su misura.

## Casi d'uso
- **Cifratura dell'intero disco**: per proteggere portatili e server in caso di furto.
- **Container cifrati**: file cifrati portatili per i backup.
- **Accesso con più chiavi**: storage condiviso con più utenti/passphrase.
- **Integrazione con LVM/ZFS**: cifrare i device sottostanti per una sicurezza a strati.

## Consigli da esperti
- **Keyfile**: usa dei file al posto delle passphrase per automatizzare:
  ```bash
  dd if=/dev/urandom of=/path/to/keyfile bs=1M count=1
  sudo cryptsetup luksAddKey /dev/sdb1 /path/to/keyfile
  ```
- **Integrazione con il TPM**: usa il TPM per lo sblocco automatico (serve il pacchetto `clevis`).
- **Backup dell'header**: conserva sempre gli header fuori dal device, per il ripristino.
- **Prestazioni**: usa AES per la velocità; misurale con `cryptsetup benchmark`.
- **Abbinarlo a LVM/ZFS**: cifra i PV o i pool:
  ```bash
  cryptsetup luksFormat /dev/sdb
  cryptsetup luksOpen /dev/sdb cryptdisk
  pvcreate /dev/mapper/cryptdisk
  ```

{{< callout type="tip" >}}
**Consiglio**: usa `cryptsetup benchmark` per provare i cifrari prima di formattare.
{{< /callout >}}

## Risoluzione dei problemi
- **«Wrong passphrase»**: controlla il blocco maiuscole; recupera con le chiavi di riserva.
- **Header danneggiato**: ripristinalo dal backup con `luksHeaderRestore`.
- **Device non trovato**: controlla con `lsblk`; ricarica i moduli (`modprobe dm-crypt`).
- **Il mount fallisce**: assicurati di averlo aperto con `luksOpen`; controlla il filesystem con `fsck`.
- **Tutte le chiavi dimenticate**: i dati sono irrecuperabili, a riprova di quanto contano i backup.
- **Sblocco lento**: `--iter-time` (tempo del PBKDF in ms) decide quanto dura lo sblocco, non la velocità di lettura e scrittura; puoi abbassarlo con `luksChangeKey --iter-time`.
- **Cifratura lenta**: controlla `cryptsetup benchmark` e il supporto AES della CPU (AES-NI); se serve, usa hardware più potente.

## Prossimi passi
Nei prossimi tutorial vedremo:
- LUKS con keyfile e TPM.
- Il boot cifrato con GRUB.
- L'integrazione di LUKS con i backup.

## Risorse
- [Pagina man di cryptsetup](https://manpages.ubuntu.com/manpages/jammy/man8/cryptsetup.8.html)
- [Guida alla cifratura del disco di Ubuntu](https://help.ubuntu.com/community/Full_Disk_Encryption_Howto_2019)
- [Arch Wiki: dm-crypt](https://wiki.archlinux.org/title/Dm-crypt)

---

*Fai pratica con LUKS su device di scorta per mettere al sicuro i tuoi dati: comincia da semplici partizioni, per non rischiare!*
