---
title: "Guida alla gestione di LVM RAID (Debian/Ubuntu)"
url: "2025/10/lvm-raid-management-guide-debian/ubuntu/"
date: 2025-10-03T14:01:00+02:00
lastmod: 2025-10-03T14:01:00+02:00
draft: false
author: "Manzolo"
tags: ["lvm", "raid", "storage", "mdadm", "volume-management"]
categories: ["Storage & Disks"]
series: ["Linux Storage Deep Dive"]
weight: 4
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Guida alla gestione di LVM RAID (Debian/Ubuntu)

## Introduzione

Il Logical Volume Management (LVM) è un sistema flessibile di gestione dello storage che astrae i dischi fisici in volumi logici, e permette ridimensionamenti a caldo, snapshot e configurazioni RAID. LVM RAID integra il RAID software di Linux (mdadm) con LVM per dare ridondanza e flessibilità. Questa guida spiega come creare, modificare e gestire una configurazione LVM con RAID su sistemi Debian/Ubuntu: la creazione del volume group, l'impostazione dei logical volume con RAID e le operazioni di manutenzione.

LVM RAID è l'ideale dove serve ridondanza (per esempio RAID-1, RAID-5) insieme al ridimensionamento dinamico e agli snapshot di LVM.

## Che cos'è LVM RAID?

LVM RAID usa `mdadm` di Linux per le funzioni RAID dentro i physical volume (PV) di LVM, che sono raggruppati in volume group (VG). I logical volume (LV) vengono poi creati con un livello RAID per avere ridondanza:
- **RAID-1**: mirroring (i dati sono duplicati su più dischi).
- **RAID-5**: striping con parità (servono 3 o più dischi).
- **RAID-6**: striping con doppia parità (servono 4 o più dischi).
- **Snapshot**: copie dei LV a un dato istante, per i backup.
- **Ridimensionamento**: LV e VG si allargano o si riducono dinamicamente.

LVM RAID unisce i vantaggi di `mdadm` (la ridondanza) all'astrazione logica di LVM, e si gestisce con i comandi `lvm` e `mdadm`.

## Prerequisiti

- **Debian/Ubuntu**: versione 20.04 o successiva (supporto a LVM e mdadm).
- **LVM2 e mdadm installati**: i pacchetti per gestire LVM e RAID.
- **Dischi**: dischi fisici inutilizzati (per esempio `/dev/sdb`, `/dev/sdc`). **Attenzione**: le operazioni LVM e RAID cancellano i dischi: fai prima un backup dei dati.
- **Accesso root**: i comandi richiedono `sudo`.
- **Hardware**: più dischi per il RAID (2 per RAID-1, 3 o più per RAID-5, 4 o più per RAID-6).

Installa le dipendenze su Debian/Ubuntu:
```bash
sudo apt update
sudo apt install lvm2 mdadm
# Load LVM kernel modules
sudo modprobe dm-mod
sudo modprobe dm-raid
```

Verifica l'installazione:
```bash
lvm version  # Check LVM version
mdadm --version  # Check mdadm version
lsblk  # List disks
```

## Avvertenza fondamentale: controlla i dischi prima di ogni operazione

{{< callout type="warning" >}}
**Massima attenzione**: prima di creare physical volume LVM o array RAID, usa `lsblk` o `fdisk -l` per verificare di aver scelto i dischi giusti (per esempio `/dev/sdb`, `/dev/sdc`). Operazioni come la creazione di physical volume o di array RAID cancellano tutti i dati sui dischi selezionati. Ricontrolla sempre lo schema dei dischi e fai il backup dei dati importanti prima di procedere.
{{< /callout >}}

## Come si usa LVM RAID

### 1. Creare una configurazione LVM RAID
Con LVM RAID si creano dei physical volume (PV), un volume group (VG) e un logical volume (LV) con il livello RAID scelto.

#### Creazione passo passo
1. **Prepara i dischi**:
   ```bash
   lsblk  # Identify disks (e.g., sdb, sdc, sdd)
   ```

2. **Crea i physical volume**:
   ```bash
   sudo pvcreate /dev/sdb /dev/sdc /dev/sdd
   pvdisplay  # Verify PVs
   ```

3. **Crea il volume group**:
   ```bash
   sudo vgcreate myvg /dev/sdb /dev/sdc /dev/sdd
   vgdisplay  # Verify VG
   ```

4. **Crea il logical volume con RAID**:
   - **RAID-1 (mirror, 2 dischi)**:
     ```bash
     sudo lvcreate --type raid1 -m 1 -L 10G -n mylv myvg
     ```
   - **RAID-5 (3 o più dischi, parità singola)**:
     ```bash
     sudo lvcreate --type raid5 -i 2 -L 10G -n mylv myvg
     ```
   - **RAID-6 (4 o più dischi, doppia parità)**:
     ```bash
     sudo lvcreate --type raid6 -i 2 -L 10G -n mylv myvg
     ```

   Parametri:
   - `-m 1`: 1 copia in mirror (RAID-1).
   - `-i 2`: 2 stripe di dati (RAID-5/6: il numero dei dischi meno quelli di parità).
   - `-L 10G`: dimensione del logical volume.
   - `-n mylv`: nome del logical volume.

5. **Formatta e monta**:
   ```bash
   sudo mkfs.ext4 /dev/myvg/mylv
   sudo mkdir /mnt/mylv
   sudo mount /dev/myvg/mylv /mnt/mylv
   df -h /mnt/mylv  # Verify mount
   ```

### 2. Modificare una configurazione LVM RAID
Il VG o il LV si modificano per allargarli, ridurli o sostituire un disco.

- **Estendere il volume group** (aggiungere dischi):
  ```bash
  sudo pvcreate /dev/sde
  sudo vgextend myvg /dev/sde
  vgdisplay  # Check new capacity
  ```

- **Estendere il logical volume**:
  ```bash
  sudo lvextend -L +10G /dev/myvg/mylv
  sudo resize2fs /dev/myvg/mylv  # Resize filesystem (ext4)
  ```

- **Sostituire un disco guasto**:
  ```bash
  sudo pvs  # Check PV status
  sudo vgreduce myvg /dev/sdb  # Remove failed PV
  sudo pvcreate /dev/sdf
  sudo vgextend myvg /dev/sdf
  sudo lvsync /dev/myvg/mylv  # Resync RAID
  ```

- **Convertire il livello RAID** (per esempio da RAID-1 a RAID-5):
  ```bash
  sudo lvconvert --type raid5 -i 2 /dev/myvg/mylv
  ```

### 3. Gestire una configurazione LVM RAID
Monitorare, riparare e gestire l'array RAID e i componenti LVM.

- **Controllare lo stato**:
  ```bash
  sudo lvs -o+raid_sync_action  # Check LV status and sync
  cat /proc/mdstat  # Check RAID status
  ```

- **Creare uno snapshot**:
  ```bash
  sudo lvcreate --snapshot -L 2G -n mysnap /dev/myvg/mylv
  sudo mount /dev/myvg/mysnap /mnt/snapshot
  ```

- **Rimuovere un logical volume o un volume group** (distruttivo!):
  ```bash
  sudo umount /mnt/mylv
  sudo lvremove /dev/myvg/mylv
  sudo vgremove myvg
  sudo pvremove /dev/sdb /dev/sdc /dev/sdd
  ```

- **Attivare/disattivare il VG**:
  ```bash
  sudo vgchange -a n myvg  # Deactivate
  sudo vgchange -a y myvg  # Activate
  ```

### 4. Configurare le proprietà del filesystem
Imposta le opzioni di mount o le quote:
```bash
sudo tune2fs -m 5 /dev/myvg/mylv  # Reserve 5% for root (ext4)
sudo mount -o remount,ro /mnt/mylv  # Remount read-only
```

## Esempi

### Esempio 1: creare e usare un logical volume RAID-1
```bash
# Verify disks
lsblk

# Create PVs and VG
sudo pvcreate /dev/sdb /dev/sdc
sudo vgcreate myvg /dev/sdb /dev/sdc

# Create RAID-1 LV
sudo lvcreate --type raid1 -m 1 -L 10G -n mylv myvg

# Format and mount
sudo mkfs.ext4 /dev/myvg/mylv
sudo mkdir /mnt/mylv
sudo mount /dev/myvg/mylv /mnt/mylv
echo "Test data" > /mnt/mylv/test.txt

# Check status
sudo lvs -o+raid_sync_action
cat /proc/mdstat
```

**Output**:
```
  LV   VG   Attr       LSize  ... SyncAction
  mylv myvg rwi-a-r--- 10.00g ... idle
Personalities : [raid1]
md127 : active raid1 sdb[0] sdc[1]
      10483712 blocks super 1.2 [2/2] [UU]
```

### Esempio 2: estendere e sostituire un disco
```bash
# Add new disk to VG
sudo pvcreate /dev/sdd
sudo vgextend myvg /dev/sdd

# Extend LV
sudo lvextend -L +5G /dev/myvg/mylv
sudo resize2fs /dev/myvg/mylv

# Replace failed disk
sudo vgreduce myvg /dev/sdb
sudo pvcreate /dev/sde
sudo vgextend myvg /dev/sde
sudo lvsync /dev/myvg/mylv
```

### Esempio 3: creare e ripristinare uno snapshot
```bash
# Create snapshot
sudo lvcreate --snapshot -L 2G -n mysnap /dev/myvg/mylv

# Mount and verify
sudo mkdir /mnt/snapshot
sudo mount /dev/myvg/mysnap /mnt/snapshot
ls /mnt/snapshot

# Restore from snapshot
sudo umount /mnt/mylv /mnt/snapshot
sudo lvconvert --merge /dev/myvg/mysnap
```

## I comandi, uno per uno

- **pvcreate**: inizializza i dischi come physical volume.
- **vgcreate/vgextend/vgreduce**: gestiscono i volume group.
- **lvcreate --type raid*`: crea LV con un livello RAID.
- **lvextend/resize2fs**: allargano LV e filesystem.
- **lvconvert**: cambia livello RAID o fa il merge degli snapshot.
- **lvs/mdstat**: tengono d'occhio lo stato di LVM e del RAID.

Livelli RAID comuni: `raid1` (mirror), `raid5` (parità singola), `raid6` (doppia parità).

## Casi d'uso
- **Storage per server**: RAID-5/6 per la ridondanza dei dati, con la flessibilità di LVM.
- **Sistemi di backup**: snapshot per backup coerenti.
- **Virtualizzazione**: LV in thin provisioning per i dischi delle VM.
- **Storage dinamico**: volumi ridimensionati senza fermo.

## Consigli da esperti
- **Preparazione dei dischi**: usa dischi interi o partizioni, ma verifica con `lsblk`.
- **Seguire la sincronizzazione del RAID**: usa `watch cat /proc/mdstat` durante il resync.
- **Snapshot**: riserva abbastanza spazio per le modifiche (per esempio il 10-20% del LV).
- **Backup automatici**: pianifica gli snapshot con cron:
  ```bash
  0 0 * * * lvcreate --snapshot -L 2G -n mysnap-$(date +%Y%m%d) /dev/myvg/mylv
  ```
- **Abbinarlo a LUKS**: cifra i PV prima di LVM:
  ```bash
  cryptsetup luksFormat /dev/sdb
  cryptsetup luksOpen /dev/sdb cryptdisk
  pvcreate /dev/mapper/cryptdisk
  ```

{{< callout type="tip" >}}
**Consiglio**: usa `lvs -o+seg_pe_ranges` per controllare come sono allocati i physical extent, quando ottimizzi le prestazioni.
{{< /callout >}}

## Risoluzione dei problemi
- **«Device not found»**: verifica i dischi con `lsblk` o `fdisk -l`.
- **Sincronizzazione RAID lenta**: seguila con `cat /proc/mdstat`; pianificala nei momenti di poco I/O.
- **Snapshot pieno**: aumenta la dimensione dello snapshot o riduci le modifiche.
- **VG non trovato**: attivalo con `vgchange -a y`.
- **Problemi di permessi**: lavora come root; controlla i moduli `dm-mod` e `dm-raid` (`lsmod`).
- **Disco guasto**: sostituiscilo in fretta per non perdere dati; controlla con `mdadm --detail`.

## Prossimi passi
Nei prossimi tutorial vedremo:
- Snapshot LVM avanzati e thin provisioning.
- La cache LVM per le prestazioni.
- L'integrazione di LVM con strumenti di backup come `rsync`.

## Risorse
- [Documentazione di LVM](https://www.sourceware.org/lvm2/)
- [Guida a LVM di Ubuntu](https://wiki.ubuntu.com/LVM)
- [Pagina man di mdadm](https://linux.die.net/man/8/mdadm)

---

*Sperimenta LVM RAID su dischi di scorta per costruire uno storage flessibile e ridondante: comincia dal RAID-1, che è il più semplice!*
