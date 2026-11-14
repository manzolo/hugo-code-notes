---
title: "Riparare il boot di Linux (Debian/Ubuntu)"
url: "2025/09/linux-boot-repair-debian/ubuntu/"
date: 2025-09-27T15:34:00+02:00
lastmod: 2025-09-27T15:34:00+02:00
draft: false
author: "Manzolo"
tags: ["boot-repair", "grub", "recovery", "troubleshooting", "ubuntu"]
categories: ["Linux Administration"]
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

# Guida alla riparazione del boot di Linux (Debian/Ubuntu)

## Introduzione

I problemi di boot su Debian o Ubuntu possono impedire al sistema di avviarsi, spesso per colpa di un bootloader GRUB corrotto, di partizioni configurate male o di problemi con il kernel. Questa guida spiega passo per passo come riparare il processo di boot sui sistemi UEFI e Legacy (BIOS/MBR) usando una live USB/CD. Copre la reinstallazione di GRUB, la preparazione delle partizioni e la soluzione dei problemi più comuni.

## Prerequisiti

- Una live USB/CD di Debian o Ubuntu (meglio se della stessa versione del tuo sistema).
- Una sessione live, ottenuta avviando dal supporto live e scegliendo «Try Ubuntu/Debian».
- Un minimo di familiarità con il terminale.
- Privilegi di amministratore (root) nell'ambiente live.

## Avvertenza fondamentale: controlla le partizioni prima di formattare

{{< callout type="warning" >}}
**Massima cautela**: prima di formattare una partizione, usa `lsblk` o `fdisk -l` per controllare che tu stia scegliendo il disco e la partizione giusti (per esempio la EFI System Partition o la partizione di root). Formattare la partizione sbagliata può cancellare i tuoi dati o file critici. Ricontrolla sempre la disposizione di dischi e partizioni per non perdere dati.
{{< /callout >}}

## Riparare il boot di Linux

### Riparare il boot UEFI

I sistemi UEFI usano una EFI System Partition (ESP) per conservare GRUB e i file di boot. Se la ESP manca, è corrotta o è configurata male, il sistema può non avviarsi.

#### Preparazione delle partizioni
Per preparare o riparare la ESP e la partizione di root:

```bash
sudo fdisk -l  # List disks to identify the correct one
sudo fdisk /dev/sda  # Replace sda with your disk

# Select EFI System Partition (ESP) - FAT32
# Verify partition layout with 'p'
p
# If ESP exists (typically 100-550 MB, type EFI System Partition), format it
t
1  # Select partition 1 (verify it’s the ESP)
ef # Set type to EFI System Partition
w  # Write changes

# Format ESP as FAT32
sudo mkfs.vfat -F 32 /dev/sda1  # Verify sda1 is the ESP
```

- **Spiegazione**:
  - `fdisk -l`: elenca tutti i dischi e le partizioni, per avere conferma del disco giusto (per esempio `/dev/sda`).
  - `fdisk /dev/sda`: apre il disco in modifica (sostituisci `sda` con il tuo disco).
  - `p`: stampa la tabella delle partizioni per controllare la ESP (di solito 100-550 MB, tipo EFI).
  - `t 1 ef`: imposta il tipo di partizione a EFI System Partition, se serve.
  - `w`: scrive le modifiche sul disco.
  - `mkfs.vfat -F 32`: formatta la ESP in FAT32 (obbligatorio per UEFI).

#### Montare i filesystem e reinstallare GRUB
Monta i filesystem necessari e usa un ambiente chroot per reinstallare GRUB:

```bash
# Mount root partition
sudo mount /dev/sda2 /mnt  # Replace sda2 with your root partition

# Mount ESP
sudo mkdir -p /mnt/boot/efi
sudo mount /dev/sda1 /mnt/boot/efi  # Replace sda1 with your ESP

# Mount other necessary filesystems
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys

# Enter chroot
sudo chroot /mnt

# Reinstall GRUB for UEFI
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
update-grub

# Exit chroot and unmount
exit
sudo umount /mnt/dev /mnt/proc /mnt/sys /mnt/boot/efi /mnt
```

- **Spiegazione**:
  - Monta la partizione di root (`/dev/sda2`) e la ESP (`/dev/sda1`) sotto `/mnt`.
  - Monta in bind `/dev`, `/proc` e `/sys`, che servono al chroot.
  - `chroot /mnt`: entra nell'ambiente di root del sistema.
  - `grub-install`: installa GRUB per UEFI sulla ESP.
  - `update-grub`: aggiorna la configurazione di GRUB perché rilevi il kernel.
  - Alla fine smonta i filesystem.

#### Creazione manuale della partizione EFI
Se la ESP manca, creane una:

```bash
sudo fdisk /dev/sda  # Replace sda with your disk

# Create EFI partition (100MB)
d
1  # Delete existing partition if necessary (verify carefully)
n
p
1
# Accept default start sector
+100M
t
1
ef  # Set type to EFI System Partition
w   # Write changes

# Format as FAT32
sudo mkfs.vfat -F 32 /dev/sda1
```

- **Spiegazione**:
  - `fdisk /dev/sda`: apre il disco in modifica.
  - `d 1`: cancella la vecchia partizione (se serve; controlla che non sia una partizione dati).
  - `n p 1 +100M`: crea una partizione da 100 MB per la ESP.
  - `t 1 ef`: imposta il tipo di partizione a EFI System Partition.
  - `mkfs.vfat -F 32`: formatta la partizione in FAT32.
  - Prosegui con i passi di `grub-install` visti sopra.

### Riparare il boot Legacy (BIOS/MBR)

I sistemi Legacy usano il Master Boot Record (MBR) e un settore di boot sulla partizione di root o su una partizione di boot separata.

#### Reinstallare GRUB
Monta la partizione di root e reinstalla GRUB:

```bash
sudo fdisk -l  # List disks to identify the correct one
sudo mount /dev/sda1 /mnt  # Replace sda1 with your root partition

# Mount other necessary filesystems
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys

# Enter chroot
sudo chroot /mnt

# Reinstall GRUB for Legacy
grub-install --target=i386-pc /dev/sda  # Replace sda with your disk
update-grub

# Exit chroot and unmount
exit
sudo umount /mnt/dev /mnt/proc /mnt/sys /mnt
```

- **Spiegazione**:
  - `fdisk -l`: individua il disco e la partizione di root giusti.
  - Monta la partizione di root (`/dev/sda1`) su `/mnt`.
  - Monta in bind `/dev`, `/proc` e `/sys` per il chroot.
  - `grub-install --target=i386-pc`: installa GRUB nell'MBR del disco.
  - `update-grub`: genera la configurazione di GRUB.
  - Alla fine smonta i filesystem.

#### Riparare il settore di boot (se GRUB non parte)
Se il settore di boot è corrotto:

```bash
sudo fdisk /dev/sda  # Replace sda with your disk
a
1  # Set partition 1 as bootable (verify it’s the root or boot partition)
w  # Write changes

# Reinstall GRUB as above
sudo mount /dev/sda1 /mnt
sudo chroot /mnt
grub-install --target=i386-pc /dev/sda
update-grub
exit
sudo umount /mnt/dev /mnt/proc /mnt/sys /mnt
```

- **Spiegazione**:
  - `a 1`: marca come avviabile la partizione di root o di boot.
  - Reinstalla GRUB per essere sicuri che il settore di boot sia configurato bene.

## Consigli e risoluzione dei problemi

### Problemi comuni
- **GRUB non si carica**:
  - Controlla qual è il disco giusto con `fdisk -l` o `lsblk`.
  - Assicurati che la ESP (`/dev/sda1`) sia in FAT32 per UEFI, oppure che la partizione di root/boot sia avviabile per Legacy.
- **«No such device» o kernel non trovato**:
  - Lancia `update-grub` nell'ambiente chroot perché rilevi il kernel.
  - Controlla che `/boot` contenga i file del kernel e dell'initramfs (per esempio `vmlinuz`, `initrd.img`).
- **UEFI e BIOS scambiati**:
  - Verifica nelle impostazioni del BIOS/UEFI in quale modalità lavora il firmware (UEFI o Legacy).
  - Usa `--target=x86_64-efi` per UEFI oppure `--target=i386-pc` per Legacy.
- **Dati persi per una formattazione**:
  - Usa sempre `lsblk` o `fdisk -l` per controllare le partizioni prima di formattare.
  - Formattare per errore la partizione di root o quella dei dati vuol dire perdere i dati. Fai un backup dei dati critici prima di procedere.
- **Errori nel chroot**:
  - Assicurati che tutti i filesystem (`/dev`, `/proc`, `/sys`, `/boot/efi`) siano montati correttamente.
  - Se nel chroot ti serve internet, monta in bind `/run`: `sudo mount --bind /run /mnt/run`.

### Altri consigli
- **Backup della configurazione di GRUB**: prima di modificarla, fai una copia di `/boot/grub/grub.cfg`:
  ```bash
  sudo cp /mnt/boot/grub/grub.cfg /mnt/boot/grub/grub.cfg.bak
  ```
- **Controlla la disposizione delle partizioni**: usa `lsblk` o `fdisk -l` per avere conferma di dischi e partizioni prima di qualunque modifica.
- **Prova il boot**: dopo le riparazioni, riavvia e prova. Se GRUB non si carica, avvia di nuovo dalla live USB e ripeti i comandi.
- **Lo strumento Boot Repair**: se i passi manuali non bastano, usa lo strumento `boot-repair` in una sessione live:
  ```bash
  sudo add-apt-repository ppa:yannubuntu/boot-repair
  sudo apt update
  sudo apt install -y boot-repair
  boot-repair
  ```

## Prossimi passi

Nei prossimi tutorial vedremo:
- Come personalizzare la configurazione di GRUB.
- Come recuperare un sistema Linux con la modalità rescue.
- Come automatizzare le riparazioni del boot con degli script.

## Risorse
- [Guida a Boot Repair di Ubuntu](https://help.ubuntu.com/community/Boot-Repair)
- [Documentazione di GRUB per Debian](https://www.debian.org/doc/manuals/debian-handbook/sect.grub2.en.html)
- [Manuale di GRUB](https://www.gnu.org/software/grub/manual/grub/grub.html)

---

*Prova questi comandi in un ambiente di test per padroneggiare la riparazione del boot di Linux, e controlla sempre le partizioni per non perdere dati!*
