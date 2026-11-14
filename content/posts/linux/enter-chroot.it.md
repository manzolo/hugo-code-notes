---
title: "Guida al chroot per Debian/Ubuntu"
url: "2025/09/chroot-guide-for-debian/ubuntu/"
date: 2025-09-27T15:36:00+02:00
lastmod: 2025-09-27T15:36:00+02:00
draft: false
author: "Manzolo"
tags: ["chroot", "recovery", "rescue", "system-repair", "troubleshooting"]
categories: ["Linux Administration"]
series: ["System Administration Basics"]
weight: 2
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Guida al chroot per Debian/Ubuntu

## Introduzione

Un ambiente chroot (change root) ti permette di spostare la directory radice di una sessione Linux su un altro filesystem, così puoi lavorare dentro un sistema Debian/Ubuntu rotto o inaccessibile come se fosse il sistema attivo. È utile soprattutto per riparare problemi di boot, recuperare file, aggiornare configurazioni o reimpostare password. Questa guida spiega passo per passo come preparare un ambiente chroot da una live USB/CD di Debian/Ubuntu.

## Prerequisiti

- Una live USB/CD di Debian o Ubuntu (meglio se della stessa versione del tuo sistema).
- Una sessione live, ottenuta avviando dal supporto live e scegliendo «Try Ubuntu/Debian».
- Un minimo di familiarità con il terminale.
- Privilegi di amministratore (root) nell'ambiente live.

## Avvertenza fondamentale: controlla le partizioni prima di montare

{{< callout type="warning" >}}
**Massima cautela**: prima di montare le partizioni, usa `lsblk` o `fdisk -l` per controllare che tu stia scegliendo il disco e la partizione giusti (per esempio la partizione di root o la EFI System Partition). Montare o modificare la partizione sbagliata può toccare dati o sistemi che non c'entrano. Ricontrolla sempre la disposizione di dischi e partizioni per non perdere dati e non sbagliare configurazione.
{{< /callout >}}

## Preparare un ambiente chroot

### Passo 1: avvia l'ambiente live
1. Inserisci la live USB/CD di Debian/Ubuntu e avvia il computer.
2. Scegli «Try Ubuntu/Debian» per entrare nella sessione live.
3. Apri un terminale (per esempio con `Ctrl+Alt+T`).

### Passo 2: individua e monta la partizione di root
Individua la disposizione di dischi e partizioni, poi monta il filesystem di root del sistema installato:

```bash
# List disks and partitions
lsblk

# Mount the root partition (e.g., /dev/sda2)
sudo mkdir -p /mnt
sudo mount /dev/sda2 /mnt  # Replace sda2 with your root partition
```

- **Spiegazione**:
  - `lsblk`: mostra i dispositivi a blocchi e le loro partizioni. Individua la tua partizione di root (di solito ext4, montata come `/` sul sistema installato).
  - `sudo mount /dev/sda2 /mnt`: monta la partizione di root su `/mnt`. Sostituisci `sda2` con la partizione giusta (per esempio `/dev/nvme0n1p2` per i dischi NVMe).

### Passo 3: monta gli altri filesystem
Perché l'ambiente chroot funzioni del tutto, monta le directory di sistema essenziali:

```bash
# Mount /dev, /proc, /sys recursively (this includes /dev/pts and the EFI variables)
for d in dev proc sys; do sudo mount --rbind --make-rslave /$d /mnt/$d; done

# Mount EFI System Partition (ESP) for UEFI systems
sudo mkdir -p /mnt/boot/efi
sudo mount /dev/sda1 /mnt/boot/efi  # Replace sda1 with your ESP (typically FAT32, 100-550 MB)
```

- **Spiegazione**:
  - `--rbind`: aggancia ogni directory **con tutto quello che c'è montato sotto**: `/dev/pts` per i terminali e `/sys/firmware/efi/efivars`, senza il quale `grub-install` non riesce a scrivere la voce di avvio UEFI.
  - `--make-rslave`: lo smontaggio del chroot non si propaga al sistema live. Senza, `umount -R /mnt` fallisce con `target is busy` (provato; vedi la [guida alla riparazione del boot di Linux](/it/2025/09/linux-boot-repair-debian/ubuntu/)).
  - `/boot/efi`: monta la ESP se il tuo sistema usa UEFI (controlla con `lsblk` o `fdisk -l`).

### Passo 4: facoltativo - attiva la rete
Se nel chroot ti serve l'accesso a internet (per esempio per aggiornare i pacchetti):

```bash
# Copy resolv.conf for DNS resolution
sudo cp /etc/resolv.conf /mnt/etc/resolv.conf

# Bind-mount /run for network services
sudo mount --bind /run /mnt/run
```

- **Spiegazione**:
  - `resolv.conf`: fornisce le impostazioni DNS per l'accesso a internet.
  - `/run`: serve alla gestione moderna della rete (per esempio NetworkManager, systemd-resolved).

### Passo 5: entra nell'ambiente chroot
Passa all'ambiente chroot:

```bash
sudo chroot /mnt
```

- **Spiegazione**:
  - `chroot /mnt`: sposta la directory radice su `/mnt`, che diventa la nuova `/` della sessione. Adesso stai lavorando dentro il filesystem del sistema installato.

### Passo 6: fai le riparazioni o le operazioni che servono
Le operazioni più comuni nell'ambiente chroot:

- **Aggiornare GRUB**:
  ```bash
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu  # UEFI (debian on Debian)
  # OR
  grub-install --target=i386-pc /dev/sda  # Legacy (replace sda with your disk)
  update-grub
  ```
- **Reimpostare la password di root**:
  ```bash
  passwd
  ```
- **Aggiornare i pacchetti**:
  ```bash
  apt update
  apt upgrade
  ```
- **Riparare il filesystem** (mai su un filesystem montato: il manuale di `e2fsck` dice che non è sicuro, e che se ti chiede se proseguire «l'unica risposta corretta è no»):
  ```bash
  # NOT here: from the live session, after Step 7, with the partition unmounted
  sudo fsck /dev/sda2  # Replace sda2 with your root partition
  ```

### Passo 7: esci e smonta
Esci dal chroot e smonta tutti i filesystem:

```bash
exit
sudo umount -R /mnt
```

- **Spiegazione**:
  - `exit`: esce dall'ambiente chroot.
  - `umount -R`: smonta `/mnt` e tutto quello che c'è montato sotto, nell'ordine giusto. Grazie a `--make-rslave` lascia stare il sistema live.

## Consigli e risoluzione dei problemi

### Problemi comuni
- **«chroot: failed to run command»**:
  - Assicurati che la partizione di root sia montata correttamente (`lsblk` per controllare).
  - Controlla che `/mnt/bin/bash` esista. Se manca, il sistema può essere corrotto oppure usare un'altra shell (prova per esempio `chroot /mnt /bin/sh`).
- **ESP mancante sui sistemi UEFI**:
  - Controlla con `lsblk` che la ESP (`/dev/sda1`, FAT32) sia montata su `/mnt/boot/efi`.
  - Se manca, creane una (vedi la [guida alla riparazione del boot di Linux](/it/2025/09/linux-boot-repair-debian/ubuntu/)).
- **Niente internet nel chroot**:
  - Verifica che `/etc/resolv.conf` sia stato copiato e che `/run` sia montata.
  - Prova con `ping 8.8.8.8` o `apt update`.
- **Montata la partizione sbagliata**:
  - Ricontrolla la disposizione delle partizioni con `lsblk` o `fdisk -l` prima di montare.
  - Montare la partizione sbagliata può portare a modifiche non volute o alla perdita di dati.
- **Lo smontaggio fallisce**:
  - Se `umount` fallisce, controlla se ci sono processi aperti che usano il punto di mount:
    ```bash
    lsof | grep /mnt
    ```
  - Termina quei processi e riprova. Evita `umount -l` («lazy») sui montaggi `--rbind` fatti senza `--make-rslave`: nella prova ha staccato anche il `/dev/pts` del sistema live, e `sudo` ha smesso di funzionare (`unable to open pty`).

### Altri consigli
- **Backup dei file critici**: prima del chroot, fai una copia dei file importanti (per esempio `/mnt/etc`, `/mnt/boot`):
  ```bash
  sudo cp -r /mnt/etc /mnt/etc.bak
  ```
- **Controlla la disposizione delle partizioni**: usa `lsblk` o `fdisk -l` per avere conferma del disco e della partizione giusti prima di montare.
- **Prova le modifiche**: dopo aver fatto le modifiche, riavvia per provarle. Se i problemi restano, rientra nella sessione live e rifai il chroot.
- **Usa un tunnel SSH per l'accesso remoto**: per i server remoti, usa un tunnel SSH per raggiungere l'ambiente live:
  ```bash
  ssh -L 2222:remote.linux.server:22 user@ssh.example.com
  ```
  Poi collegati via SSH a `localhost:2222`.
- **Lo strumento Boot Repair**: se il chroot manuale non basta, prova lo strumento `boot-repair` nella sessione live:
  ```bash
  sudo add-apt-repository ppa:yannubuntu/boot-repair
  sudo apt update
  sudo apt install -y boot-repair
  boot-repair
  ```

## Prossimi passi

Nei prossimi tutorial vedremo:
- La configurazione avanzata di GRUB nel chroot.
- Il recupero dei filesystem con il chroot.
- Come automatizzare la preparazione del chroot con degli script.

## Risorse
- [Documentazione di Ubuntu sul chroot](https://help.ubuntu.com/community/BasicChroot)
- [Wiki di Debian: Chroot](https://wiki.debian.org/chroot)
- [Manuale di GRUB](https://www.gnu.org/software/grub/manual/grub/grub.html)

---

*Esercitati a preparare un ambiente chroot su un sistema di test per padroneggiare le riparazioni di Debian/Ubuntu, e controlla sempre le partizioni per non perdere dati!*
