---
title: "Guida alla gestione di LVM RAID (Debian/Ubuntu)"
url: "2025/10/lvm-raid-management-guide-debian/ubuntu/"
date: 2025-10-03T14:01:00+02:00
lastmod: 2025-10-03T14:01:00+02:00
draft: false
author: "Manzolo"
tags: ["lvm", "raid", "storage", "lvmraid", "volume-management"]
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

LVM RAID usa il codice RAID MD del kernel attraverso il device mapper (`dm-raid`), sopra i physical volume (PV) di LVM, che sono raggruppati in volume group (VG). I logical volume (LV) vengono poi creati con un livello RAID per avere ridondanza:
- **RAID-1**: mirroring (i dati sono duplicati su più dischi).
- **RAID-5**: striping con parità (servono 3 o più dischi).
- **RAID-6**: striping con doppia parità (servono 5 o più dischi: almeno 3 stripe di dati).
- **Snapshot**: copie dei LV a un dato istante, per i backup.
- **Ridimensionamento**: LV e VG si allargano o si riducono dinamicamente.

LVM RAID unisce la ridondanza del RAID all'astrazione logica di LVM, e si gestisce solo con i comandi `lvm`: **`mdadm` non serve**, e i volumi LVM RAID non compaiono in `/proc/mdstat` (verificato entrambe le cose su Ubuntu 24.04: con un RAID1 LVM attivo e mdadm non installato, `/proc/mdstat` elenca le personality e nessun array).

## Prerequisiti

- **Debian/Ubuntu**: Debian 11 o successiva, Ubuntu 20.04 o successiva.
- **LVM2 installato**: basta il pacchetto `lvm2`.
- **Dischi**: dischi fisici inutilizzati (per esempio `/dev/sdb`, `/dev/sdc`). **Attenzione**: le operazioni LVM e RAID cancellano i dischi: fai prima un backup dei dati.
- **Accesso root**: i comandi richiedono `sudo`.
- **Hardware**: più dischi per il RAID (2 per RAID-1, 3 o più per RAID-5, 5 o più per RAID-6).

Installa le dipendenze su Debian/Ubuntu:
```bash
sudo apt update
sudo apt install lvm2
# Load LVM kernel modules
sudo modprobe dm-mod
sudo modprobe dm-raid
```

Verifica l'installazione:
```bash
lvm version  # Check LVM version
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
   - **RAID-6 (5 o più dischi, doppia parità)**:
     ```bash
     sudo lvcreate --type raid6 -i 3 -L 10G -n mylv myvg
     ```

   Parametri:
   - `-m 1`: 1 copia in mirror (RAID-1).
   - `-i 2` / `-i 3`: numero di stripe di dati (i dischi meno quelli di parità). RAID-6 ne vuole almeno 3: `lvcreate --type raid6 -i 2` fallisce con `Minimum of 3 stripes required for raid6`.
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
  sudo lvs -a -o name,devices,lv_health_status myvg  # failed leg: [unknown], partial
  sudo pvcreate /dev/sdf               # a new disk, if the VG has no free one
  sudo vgextend myvg /dev/sdf
  sudo lvconvert --repair myvg/mylv    # rebuild the failed leg on a free PV
  sudo vgreduce --removemissing myvg   # drop the dead disk from the VG
  ```

- **Convertire il livello RAID** (per esempio da RAID-1 a RAID-5):
  ```bash
  sudo lvconvert --type raid5 /dev/myvg/mylv      # raid1 (2 legs) -> raid5 on 2 devices
  sudo lvconvert --stripes 2 /dev/myvg/mylv       # reshape to 2 data stripes (3 devices)
  sudo lvs -o name,segtype,stripes,sync_percent myvg
  ```

### 3. Gestire una configurazione LVM RAID
Monitorare, riparare e gestire l'array RAID e i componenti LVM.

- **Controllare lo stato**:
  ```bash
  sudo lvs -o+raid_sync_action  # Check LV status and sync
  sudo lvs -a -o name,segtype,devices,sync_percent,lv_health_status myvg
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
sudo lvs -a -o name,segtype,devices,sync_percent,lv_health_status myvg
```

**Output**:
```
  LV   VG   Attr       LSize  ... Cpy%Sync SyncAction
  mylv myvg rwi-a-r--- 10.00g ... 100.00   idle
  LV              Type   Devices                           Cpy%Sync Health
  mylv            raid1  mylv_rimage_0(0),mylv_rimage_1(0) 100.00
  [mylv_rimage_0] linear /dev/sdb(1)
  [mylv_rimage_1] linear /dev/sdc(1)
  [mylv_rmeta_0]  linear /dev/sdb(0)
  [mylv_rmeta_1]  linear /dev/sdc(0)
```

### Esempio 2: estendere e sostituire un disco
```bash
# Add new disk to VG
sudo pvcreate /dev/sdd
sudo vgextend myvg /dev/sdd

# Extend LV
sudo lvextend -L +5G /dev/myvg/mylv
sudo resize2fs /dev/myvg/mylv

# Replace failed disk (sdb died)
sudo pvcreate /dev/sde
sudo vgextend myvg /dev/sde
sudo lvconvert --repair myvg/mylv
sudo vgreduce --removemissing myvg
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

## La prova: un disco muore

Provato il 2026-11-14 su una VM Ubuntu 24.04 con cinque dischi da 2 GB e senza `mdadm` installato. È stato creato un LV RAID-1, formattato, montato e riempito con un file; poi uno dei suoi dischi è stato staccato a caldo dalla VM accesa.

- `lvs -a -o name,devices,lv_health_status` ha dato il LV come `partial`, con la gamba morta su `[unknown]`. Il file è rimasto leggibile, e scrivibile.
- `vgreduce myvg /dev/sdb` (la vecchia istruzione di questa guida) si è rifiutato: `Cannot process volume group myvg`.
- `lvconvert --repair myvg/mylv` ha risposto `Faulty devices in myvg/mylv successfully replaced.`, ricostruendo la gamba su un disco libero del VG; `vgreduce --removemissing myvg` ha tolto il disco morto. Pochi secondi dopo `Cpy%Sync` era `100.00` e il file era intatto.
- Sullo stesso LV è stata eseguita la conversione da RAID-1 a RAID-5 della sezione 2: `lvconvert --type raid5 -i 2` avverte `--stripes not allowed ... when converting from raid1 to raid5` e produce un RAID-5 a 2 dispositivi; il secondo comando, `--stripes 2`, lo rimodella su 3 dispositivi e fa crescere il LV. Il file è sopravvissuto a entrambe.

## I comandi, uno per uno

- **pvcreate**: inizializza i dischi come physical volume.
- **vgcreate/vgextend/vgreduce**: gestiscono i volume group.
- **`lvcreate --type raid*`**: crea LV con un livello RAID.
- **lvextend/resize2fs**: allargano LV e filesystem.
- **lvconvert**: cambia livello RAID o fa il merge degli snapshot.
- **lvs**: tiene d'occhio i LV, la sincronizzazione e la salute del RAID (`lvs -a -o+sync_percent,lv_health_status`).

Livelli RAID comuni: `raid1` (mirror), `raid5` (parità singola), `raid6` (doppia parità).

## Casi d'uso
- **Storage per server**: RAID-5/6 per la ridondanza dei dati, con la flessibilità di LVM.
- **Sistemi di backup**: snapshot per backup coerenti.
- **Virtualizzazione**: LV in thin provisioning per i dischi delle VM.
- **Storage dinamico**: volumi ridimensionati senza fermo.

## Consigli da esperti
- **Preparazione dei dischi**: usa dischi interi o partizioni, ma verifica con `lsblk`.
- **Seguire la sincronizzazione del RAID**: usa `watch sudo lvs -o name,sync_percent,raid_sync_action` durante il resync.
- **Snapshot**: riserva abbastanza spazio per le modifiche (per esempio il 10-20% del LV).
- **Backup automatici**: pianifica gli snapshot con cron:
  ```bash
  # root's crontab (sudo crontab -e): % must be written \% in a crontab line
  0 0 * * * /usr/sbin/lvcreate --snapshot -L 2G -n mysnap-$(date +\%Y\%m\%d) /dev/myvg/mylv
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
- **Sincronizzazione RAID lenta**: seguila con `lvs -o+sync_percent`; pianificala nei momenti di poco I/O.
- **Snapshot pieno**: aumenta la dimensione dello snapshot o riduci le modifiche.
- **VG non trovato**: attivalo con `vgchange -a y`.
- **Problemi di permessi**: lavora come root; controlla i moduli `dm-mod` e `dm-raid` (`lsmod`).
- **Disco guasto**: `lvs -a -o+lv_health_status` mostra `partial` e la gamba morta come `[unknown]`; i dati restano leggibili. Si ripara con `lvconvert --repair` e `vgreduce --removemissing`, come nell'esempio sopra. Un semplice `vgreduce myvg /dev/sdb` si rifiuta (`Cannot process volume group`), e il comando `lvsync` non esiste.

## Prossimi passi
Nei prossimi tutorial vedremo:
- Snapshot LVM avanzati e thin provisioning.
- La cache LVM per le prestazioni.
- L'integrazione di LVM con strumenti di backup come `rsync`.

## Risorse
- [Documentazione di LVM](https://www.sourceware.org/lvm2/)
- [Guida a LVM di Ubuntu](https://wiki.ubuntu.com/LVM)
- [Pagina man di lvmraid(7)](https://man7.org/linux/man-pages/man7/lvmraid.7.html)

---

*Sperimenta LVM RAID su dischi di scorta per costruire uno storage flessibile e ridondante: comincia dal RAID-1, che è il più semplice!*
