---
title: "Riparare il boot di Linux (Debian/Ubuntu)"
url: "2025/09/linux-boot-repair-debian/ubuntu/"
date: 2025-09-27T15:34:00+02:00
lastmod: 2026-11-14T18:00:00+01:00
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

{{< callout type="info" >}}
**Provato davvero** (2026-11-14): i comandi qui sotto sono stati eseguiti su macchine virtuali rotte apposta - Ubuntu 26.04 in UEFI con la partizione di sistema EFI svuotata, Ubuntu 24.04 in BIOS con il codice di avvio cancellato dall'MBR - dal supporto live di Ubuntu, ed entrambi i sistemi sono ripartiti. Nelle VM il disco era `/dev/vda`; su un PC di solito è `/dev/sda`, oppure `/dev/nvme0n1` con le partizioni `nvme0n1p1`, `nvme0n1p2`.
{{< /callout >}}

### Prima di tutto: UEFI o BIOS?

Dalla sessione live:

```bash
ls /sys/firmware/efi >/dev/null 2>&1 && echo UEFI || echo BIOS
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME
```

La sessione live deve girare nella **stessa modalità** del sistema installato: per riparare un'installazione UEFI, avvia la chiavetta live dalla sua voce UEFI nel menu di avvio del firmware.

### Riparare il boot UEFI

Lo schema più comune, ed è quello della VM di prova: la partizione 1 è la partizione di sistema EFI (ESP, FAT32, qualche centinaio di MB), la partizione 2 è il filesystem di root.

Quando la ESP è vuota o danneggiata il firmware non trova niente da avviare:

![Il firmware segnala che non c'è nessuna opzione avviabile](/images/linux-boot-uefi-no-bootable.png "La ESP è stata svuotata: nessuna opzione o dispositivo avviabile")

#### Montare, entrare nel chroot, reinstallare GRUB

```bash
# Root partition first, then the ESP inside it
sudo mount /dev/sda2 /mnt
sudo mount /dev/sda1 /mnt/boot/efi

# The live system's /dev, /proc and /sys, recursively
for d in dev proc sys; do sudo mount --rbind --make-rslave /$d /mnt/$d; done

sudo chroot /mnt
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
update-grub
exit

sudo umount -R /mnt
efibootmgr
```

Atteso: `Installation finished. No error reported.` **senza avvisi**, e in `efibootmgr` una voce che punta a `\EFI\ubuntu\shimx64.efi` in cima a `BootOrder`.

![grub-install nel chroot, con le variabili EFI visibili](/images/linux-boot-uefi-grub-install-ok.png "Con --rbind il chroot vede le variabili EFI, e grub-install finisce senza avvisi")

A farlo funzionare sono due dettagli dei montaggi. Nella prova sono stati provati entrambi anche nell'altro modo:

| Scelta | Perché | Senza |
|--------|--------|-------|
| `--rbind`, non `--bind` | le variabili EFI stanno in un filesystem a parte montato sotto `/sys` (`/sys/firmware/efi/efivars`); un semplice `--bind` lo lascia fuori | `grub-install` copia i file ma avverte `EFI variables cannot be set on this system`: la voce di avvio non viene scritta |
| `--make-rslave` | lo smontaggio del chroot non si propaga al sistema live | `umount -R /mnt` fallisce con `target is busy`; e il tentatore `umount -lR` stacca anche il `/dev/pts` del sistema live, dopo di che `sudo` smette di funzionare (`unable to open pty`) |

![grub-install avverte che non può impostare le variabili EFI](/images/linux-boot-uefi-efivars-warning.png "Con un semplice --bind: i file vengono copiati, la voce di avvio no")

`--bootloader-id` è il nome della cartella nella ESP e della voce di avvio: usa quello della tua distribuzione (`ubuntu` su Ubuntu, `debian` su Debian), così i file tornano dove shim e la voce esistente se li aspettano.

**Su Ubuntu il sistema spesso parte anche senza la voce di avvio**: `grub-install` scrive anche la copia di riserva `\EFI\BOOT\BOOTX64.EFI`, che il firmware prova da solo e che al primo avvio ricrea la voce mancante. Nella prova è andata così. Non farci affidamento con altre distribuzioni o altri firmware: controlla `efibootmgr`.

![Il desktop di Ubuntu dopo la riparazione](/images/linux-boot-uefi-repaired-desktop.png "Il sistema riparato, di nuovo sul desktop")

#### Non formattare la ESP «per sicurezza»

Riformattare la ESP le dà un **UUID nuovo**. `/etc/fstab` cerca ancora quello vecchio, e su Ubuntu 26.04 anche l'initramfs. Nella prova il risultato è stato un avvio che aspetta per sempre:

```text
[    **] Job dev-disk-by\x2duuid-B5D2\x2d58E…tart running (4min 41s / no limit)
```

Correggere solo `/etc/fstab` non è bastato: il sistema è ripartito soltanto dopo aver rigenerato anche l'initramfs. Quindi formatta la ESP solo se è davvero danneggiata (non si monta, oppure `fsck.vfat` segnala errori), e poi completa il lavoro:

```bash
sudo mkfs.vfat -F 32 /dev/sda1
sudo blkid /dev/sda1      # note the new UUID

# mount and chroot exactly as above, then inside the chroot:
nano /etc/fstab           # put the new UUID on the /boot/efi line
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
update-grub
update-initramfs -u -k all
exit
```

#### Creare una ESP mancante (disco GPT)

Una ESP può andare solo in uno **spazio libero**. Non cancellare mai la partizione 1 per farle posto: su molti dischi la partizione 1 è la root o una partizione di dati. Se lo spazio libero non c'è, prima restringi una partizione (GParted dalla sessione live).

```text
sudo fdisk /dev/sda
n        new partition: Enter, Enter (first free number and sector)
+512M    size
t        change the type
1        number of the new partition (fdisk shows it after n)
1        type 1 = EFI System on GPT
w        write and quit
```

Poi formattala, aggiungi la sua riga a `/etc/fstab` e prosegui come nella sezione precedente. Sui dischi GPT le vecchie risposte da MBR non funzionano: il codice di tipo `ef` lascia la partizione com'è (`Type of partition 1 is unchanged`), e `n p 1` fallisce perché `p` viene letto come numero di partizione.

### Riparare il boot Legacy (BIOS)

Con il BIOS, GRUB si scrive all'inizio del **disco**, non di una partizione. Gli schemi comuni sono due: un disco MBR, oppure un disco GPT con una partizione «BIOS boot» da 1 MB, che è quello che Ubuntu crea quando viene installato in modalità BIOS (la VM di prova).

Quando il codice di avvio non c'è più, il BIOS si ferma lì:

![Il BIOS fermo su Booting from Hard Disk](/images/linux-boot-bios-hang.png "Nessun codice di avvio nell'MBR: il BIOS si ferma su Booting from Hard Disk...")

```bash
# Root partition: often sda1 on MBR disks, sda2 on GPT disks with a BIOS boot partition
sudo mount /dev/sda2 /mnt
for d in dev proc sys; do sudo mount --rbind --make-rslave /$d /mnt/$d; done

sudo chroot /mnt
grub-install --target=i386-pc /dev/sda
update-grub
exit

sudo umount -R /mnt
```

![grub-install e update-grub per BIOS nel chroot](/images/linux-boot-bios-repair.png "La riparazione Legacy: grub-install sul disco, update-grub trova il kernel, umount -R non lascia niente montato")

I montaggi di `/dev`, `/proc` e `/sys` non sono facoltativi. Senza, `grub-install` si ferma subito:

![grub-install che fallisce in un chroot senza /dev, e fdisk che rifiuta il comando a su GPT](/images/linux-boot-bios-chroot-without-binds.png "Senza i montaggi: cannot find a device for /boot/grub (is /dev mounted?)")

#### Il flag di avvio

La stessa schermata mostra l'altra trappola: `a` (attiva il flag di avvio) esiste solo sui dischi **MBR**; su GPT `fdisk` risponde `a: unknown command`. A GRUB il flag non serve, ma alcuni BIOS vecchi rifiutano di avviare un disco MBR senza una partizione attiva. Solo in quel caso:

```text
sudo fdisk /dev/sda
a        toggle the bootable flag (MBR disks only)
1        partition number
w        write and quit
```

## Consigli e risoluzione dei problemi

### Problemi comuni
- **GRUB non si carica**:
  - Controlla qual è il disco giusto con `fdisk -l` o `lsblk`.
  - Controlla che la sessione live giri nella stessa modalità (UEFI o BIOS) del sistema installato.
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
  - Montali con `--rbind --make-rslave` come sopra. Non usare `--rbind` su `/run`: porta dentro anche i montaggi della sessione dell'utente live, e poi `umount -R` fallisce su `/mnt/run/user/1000` (visto nella prova).

### Altri consigli
- **Backup della configurazione di GRUB**: prima di modificarla, fai una copia di `/boot/grub/grub.cfg`:
  ```bash
  sudo cp /mnt/boot/grub/grub.cfg /mnt/boot/grub/grub.cfg.bak
  ```
- **Controlla la disposizione delle partizioni**: usa `lsblk` o `fdisk -l` per avere conferma di dischi e partizioni prima di qualunque modifica.
- **Prova il boot**: dopo le riparazioni, riavvia e prova. Se GRUB non si carica, avvia di nuovo dalla live USB e ripeti i comandi.
- **Lo strumento Boot Repair**: se i passi manuali non bastano, usa lo strumento `boot-repair` in una sessione live (il PPA vale solo per i supporti live di Ubuntu):
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
