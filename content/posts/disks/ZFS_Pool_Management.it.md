---
title: "Guida alla gestione dei pool ZFS (Debian/Ubuntu)"
url: "2025/10/zfs-pool-management-guide-debian/ubuntu/"
date: 2025-10-03T10:00:00+02:00
lastmod: 2026-11-14T19:00:00+01:00
draft: false
author: "Manzolo"
tags: ["zfs", "storage", "pool-management", "snapshots", "raid"]
categories: ["Storage & Disks"]
series: ["Linux Storage Deep Dive"]
weight: 3
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Guida alla gestione dei pool ZFS (Debian/Ubuntu)

## Introduzione

ZFS (Zettabyte File System) è un filesystem avanzato e insieme un gestore di volumi per grandi pool di storage, con snapshot, compressione e ridondanza (per esempio mirror e RAID-Z). Questa guida mostra come inizializzare i dischi con GPT, creare un pool ZFS, usare identificatori di dispositivo stabili (`/dev/disk/by-id/` o `/dev/disk/by-partuuid/`), scegliere tra i vari tipi di RAID (mirror, RAID-Z1, RAID-Z2) e montare i dataset in modo che li usi un utente normale, su Debian/Ubuntu.

## ⚡ Per partire subito

{{< callout type="info" >}}
**Nuovo su ZFS? Parti da qui:**
1. [Installa i prerequisiti](#prerequisites)
2. [Individua i tuoi dischi](#identifying-available-disks)
3. **Scegli il metodo:**
   - Dischi fisici? → [Dischi interi con by-id](#method-a-with-devdiskby-id-physical-disks)
   - Dischi virtuali (VM)? → [Dischi interi senza by-id](#method-b-without-devdiskby-id-virtual-disks)
   - Ti servono le partizioni? → [Partizioni manuali](#alternative-approach-manual-partitions-with-by-partuuid)
4. [Crea un pool mirror](#creating-the-pool-whole-disks) (la configurazione più comune)
5. [Crea e gestisci i dataset](#creating-and-managing-datasets)

**Devi riparare qualcosa?** → [Sostituisci un disco guasto](#replace-a-failed-disk)
{{< /callout >}}

## Che cos'è un pool ZFS?

Un pool ZFS è un insieme di dispositivi virtuali (vdev) che fa da base ai dataset ZFS (filesystem) e agli zvol (dispositivi a blocchi). I pool offrono:

- **Ridondanza**: mirror (RAID-1), RAID-Z1/2/3 (simili a RAID-5/6/7).
- **Espansione**: si aggiungono vdev per aumentare la capacità (toglierli non è semplice).
- **Controllo dello stato di salute**: scrub e checksum per l'integrità dei dati.
- **Snapshot/cloni**: copie a un dato istante, senza duplicare tutto.

I pool si creano con `zpool create` e si gestiscono con i comandi `zpool`. I dati stanno nei dataset (per esempio `tank/home`).

## 🔑 Capire gli UUID in ZFS

{{< callout type="warning" >}}
**Concetto fondamentale**: per gestire bene ZFS è essenziale capire la differenza tra l'UUID del pool e gli identificatori di dispositivo.
{{< /callout >}}

### UUID del pool e identificatori di dispositivo

#### UUID del pool
- **Esempio**: `150809157285762621`
- Compare come `UUID="..."` con `TYPE="zfs_member"` nell'output di `blkid`
- **Condiviso da TUTTI i dischi/partizioni** che fanno parte dello stesso pool
- **Non si usa direttamente** nei comandi zpool

#### Identificatori di dispositivo (per riferirsi ai singoli dischi/partizioni)

**`/dev/disk/by-id/`** - Identificatore persistente basato sul numero di serie del disco
- ✅ **Il migliore per i dischi interi** 
- Esempio: `ata-Samsung_SSD_850_S21NX0AG123456`
- Sopravvive al riordino dei dischi e ai riavvii del sistema

**`/dev/disk/by-partuuid/`** - UUID della partizione GPT
- ✅ **Il migliore per le partizioni manuali**
- Esempio: `ee2507fe-0b11-ad4c-b1c5-87e36055410e`
- Ogni partizione ha il proprio PARTUUID univoco

**`/dev/vdb`, `/dev/sda`** - Nomi di dispositivo del kernel
- ⚠️ **Inaffidabili** - possono cambiare al riavvio o se i dischi vengono riordinati
- Usali solo per la creazione iniziale del pool, poi passa agli identificatori persistenti

### Tabella di scelta: quale identificatore usare?

| Scenario | Identificatore consigliato | Esempio |
|----------|------------------------|---------|
| Disco intero a ZFS | `/dev/disk/by-id/` | `ata-WDC_WD40EFRX-68N32N0_WD-1234` |
| Partizione manuale a ZFS | `/dev/disk/by-partuuid/` | `ee2507fe-0b11-ad4c-b1c5-87e36055410e` |
| Solo creazione iniziale del pool | `/dev/vdb`, `/dev/sda` | Passa subito dopo a quelli persistenti |

## Prerequisiti {#prerequisites}

{{< callout type="info" >}}
**Cosa serve**:
- Debian/Ubuntu 20.04+
- Accesso root (`sudo`)
- Dischi inutilizzati (per esempio `/dev/vdb`, `/dev/vdc`)
{{< /callout >}}

{{< callout type="warning" >}}
**⚠️ Rischio di perdita dei dati**: ZFS cancella tutti i dati sui dischi selezionati. Prima fai un backup dei dati importanti!
{{< /callout >}}

### Installazione

```bash
sudo apt update
sudo apt install zfsutils-linux parted
sudo modprobe zfs
```

### Verificare l'installazione

```bash
zpool status  # No pools initially
zfs list      # Empty initially
```

## Individuare i dischi disponibili {#identifying-available-disks}

### 1. Elencare tutti i dispositivi a blocchi

```bash
# Show all disks and their mount status
lsblk
```

**Output di esempio**:
```
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   20G  0 disk 
└─sda1   8:1    0   20G  0 part /
sr0     11:0    1 1024M  0 rom  
vdb    252:16   0   10G  0 disk 
vdc    252:32   0   10G  0 disk 
```

In questo esempio `vdb` e `vdc` sono dischi disponibili, senza partizioni.

### 2. Controllare gli identificatori dei dischi

```bash
# Try to list persistent IDs
ls -l /dev/disk/by-id/ | grep -v part
```

{{< callout type="info" >}}
**Importante**: per i dischi virtuali appena creati (come `/dev/vdb`, `/dev/vdc`), `/dev/disk/by-id/` potrebbe non mostrarli, perché:
- I dischi virtuali (QEMU/VirtIO) spesso non hanno un numero di serie hardware
- I dischi senza tabella delle partizioni possono non comparire in by-id
{{< /callout >}}

**Cosa potresti vedere**:
```bash
# Only DVD/CD-ROM visible, no data disks
lrwxrwxrwx 1 root root 9 ott  4 11:50 ata-QEMU_DVD-ROM_QM00001 -> ../../sr0
```

### 3. Verificare che i dischi siano vuoti

```bash
# Check if disks have any filesystem or partition table
sudo blkid /dev/vdb /dev/vdc

# If empty, no output or "no such device"
```

```bash
# Alternative check with wipefs
sudo wipefs /dev/vdb /dev/vdc
```

## 🚀 Approccio consigliato: dischi interi

{{< callout type="success" >}}
**Buona pratica**: usare i dischi interi è l'approccio consigliato per la maggior parte delle installazioni ZFS. ZFS crea in automatico lo schema di partizioni ottimale.
{{< /callout >}}

### Metodo A: con /dev/disk/by-id/ (dischi fisici) {#method-a-with-devdiskby-id-physical-disks}

{{< callout type="info" >}}
**Usa questo metodo se**: hai dischi fisici SATA/SAS che compaiono in `/dev/disk/by-id/`
{{< /callout >}}

Se i tuoi dischi compaiono in `/dev/disk/by-id/` (è il caso tipico dei dischi fisici SATA/SAS):

```bash
# List available disk IDs
ls -l /dev/disk/by-id/ | grep -v part

# Example output for physical disks:
# ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567 -> ../../sdb
# ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7654321 -> ../../sdc
```

Usa questi ID direttamente nella creazione del pool.

### Metodo B: senza /dev/disk/by-id/ (dischi virtuali) {#method-b-without-devdiskby-id-virtual-disks}

{{< callout type="info" >}}
**Usa questo metodo se**: hai dischi virtuali (VM) come `/dev/vdb`, `/dev/vdc` che non compaiono in `/dev/disk/by-id/`
{{< /callout >}}

**Opzione 1: creare il pool con i nomi di dispositivo** (consigliata per le VM)

Quando usi un disco intero, ZFS crea in automatico una tabella delle partizioni GPT.

```bash
# Create pool with device names
sudo zpool create tank mirror /dev/vdb /dev/vdc

# After creation, check what ZFS created:
sudo blkid | grep zfs_member
ls -l /dev/disk/by-id/ | grep -v dvd
```

<details>
<summary><strong>Opzione 2: usare gli ID VirtIO, se disponibili</strong></summary>

```bash
# Check for virtio identifiers
ls -l /dev/disk/by-id/ | grep virtio

# If available, use them:
# virtio-xxxxx -> ../../vdb
sudo zpool create tank mirror \
  /dev/disk/by-id/virtio-xxxxx \
  /dev/disk/by-id/virtio-yyyyy
```
</details>

### Creare il pool (dischi interi) {#creating-the-pool-whole-disks}

ZFS crea in automatico una tabella delle partizioni GPT e usa tutto il disco.

#### Con dischi fisici (usando by-id)

**Mirror (RAID-1, 2 dischi)** - Consigliato per la maggior parte degli utenti
```bash
sudo zpool create tank mirror \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7654321
```

<details>
<summary><strong>RAID-Z1 (3 o più dischi, tollera il guasto di 1 disco)</strong></summary>

```bash
sudo zpool create tank raidz \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7654321 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K9876543
```
</details>

<details>
<summary><strong>RAID-Z2 (4 o più dischi, tollera il guasto di 2 dischi)</strong></summary>

```bash
sudo zpool create tank raidz2 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7654321 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K9876543 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1111111
```
</details>

#### Con dischi virtuali (usando i nomi di dispositivo)

**Mirror (RAID-1, 2 dischi)** - Il più comune per le VM
```bash
# ZFS creates GPT automatically
sudo zpool create tank mirror /dev/vdb /dev/vdc
```

<details>
<summary><strong>RAID-Z1 (3 o più dischi)</strong></summary>

```bash
sudo zpool create tank raidz /dev/vdb /dev/vdc /dev/vdd
```
</details>

<details>
<summary><strong>RAID-Z2 (4 o più dischi)</strong></summary>

```bash
sudo zpool create tank raidz2 /dev/vdb /dev/vdc /dev/vdd /dev/vde
```
</details>

### Verificare lo stato del pool

```bash
zpool status tank
```

**Output di esempio (dischi fisici con by-id)**:
```
  pool: tank
 state: ONLINE
config:
        NAME                                            STATE     READ WRITE CKSUM
        tank                                            ONLINE       0     0     0
          mirror-0                                      ONLINE       0     0     0
            ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567    ONLINE       0     0     0
            ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7654321    ONLINE       0     0     0
```

**Output di esempio (dischi virtuali)**:
```
  pool: tank
 state: ONLINE
config:
        NAME        STATE     READ WRITE CKSUM
        tank        ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            vdb     ONLINE       0     0     0
            vdc     ONLINE       0     0     0
```

### Capire cosa ha creato ZFS

Dopo aver creato un pool con dischi interi, guarda cosa ha creato ZFS in automatico:

```bash
# Show partition table ZFS created
sudo blkid | grep zfs_member
```

**Output di esempio (dischi virtuali)**:
```
/dev/vdb: UUID="150809157285762621" UUID_SUB="4234567890123456789" TYPE="zfs_member" PTTYPE="gpt"
/dev/vdc: UUID="150809157285762621" UUID_SUB="9876543210987654321" TYPE="zfs_member" PTTYPE="gpt"
```

Oppure, con le partizioni:
```
/dev/vdb1: UUID="150809157285762621" TYPE="zfs_member" PARTUUID="ee2507fe-0b11-ad4c-b1c5-87e36055410e"
/dev/vdc1: UUID="150809157285762621" TYPE="zfs_member" PARTUUID="c074a830-4f67-a24d-b028-7cefbe64a690"
```

```bash
# Check partition layout
lsblk
```

**Cosa ha creato ZFS**:
- **Partizione 1** (`vdb1`, `vdc1`): la partizione ZFS principale, con i tuoi dati
- **Partizione 9** (`vdb9`, `vdc9`): una piccola partizione da 8MB per l'area riservata di ZFS
- **GPT** (`PTTYPE="gpt"`): GUID Partition Table
- **UUID del pool**: uguale per tutti i membri del pool (`150809157285762621`)
- **PARTUUID**: univoco per ogni partizione (se sono state create)

## Approccio alternativo: partizioni manuali con by-partuuid {#alternative-approach-manual-partitions-with-by-partuuid}

{{< callout type="warning" >}}
**Usa questo approccio solo se devi:**
- Condividere un disco con altri filesystem (dual boot)
- Creare schemi di partizioni personalizzati
- Usare solo una parte del disco per ZFS
{{< /callout >}}

<details>
<summary><strong>Espandi per le istruzioni sulle partizioni manuali</strong></summary>

### 1. Creare le partizioni GPT

```bash
# Initialize disk with GPT
sudo parted /dev/vdb mklabel gpt
sudo parted /dev/vdb mkpart primary 0% 100%

sudo parted /dev/vdc mklabel gpt
sudo parted /dev/vdc mkpart primary 0% 100%
```

### 2. Trovare i PARTUUID

```bash
# List partition UUIDs
ls -l /dev/disk/by-partuuid/

# Or use blkid
sudo blkid /dev/vdb1 /dev/vdc1
```

Output di esempio:
```
/dev/vdb1: PARTUUID="ee2507fe-0b11-ad4c-b1c5-87e36055410e"
/dev/vdc1: PARTUUID="c074a830-4f67-a24d-b028-7cefbe64a690"
```

### 3. Creare il pool con le partizioni

```bash
sudo zpool create tank mirror \
  /dev/disk/by-partuuid/ee2507fe-0b11-ad4c-b1c5-87e36055410e \
  /dev/disk/by-partuuid/c074a830-4f67-a24d-b028-7cefbe64a690
```

Oppure partendo dai nomi di dispositivo:

```bash
# Create with device names
sudo zpool create -f tank mirror /dev/vdb1 /dev/vdc1

# Export and re-import with PARTUUIDs
sudo zpool export tank
sudo zpool import -d /dev/disk/by-partuuid tank
```

### 4. Verificare l'uso dei PARTUUID

```bash
zpool status tank
```

Output di esempio:
```
  pool: tank
 state: ONLINE
config:
        NAME                                     STATE     READ WRITE CKSUM
        tank                                     ONLINE       0     0     0
          mirror-0                               ONLINE       0     0     0
            ee2507fe-0b11-ad4c-b1c5-87e36055410e ONLINE       0     0     0
            c074a830-4f67-a24d-b028-7cefbe64a690 ONLINE       0     0     0
```
</details>

## 💾 Creare e gestire i dataset {#creating-and-managing-datasets}

### Creare e montare un dataset

```bash
# Create dataset
sudo zfs create tank/data

# Set mountpoint
sudo zfs set mountpoint=/mnt/tank tank/data

# Enable compression (recommended)
sudo zfs set compression=lz4 tank/data
```

### Impostare i permessi per un utente normale

```bash
# Change ownership to your user
sudo chown manzolo:manzolo /mnt/tank
sudo chmod 775 /mnt/tank
```

### Scrivere dati come utente normale

```bash
# Now you can write without sudo
echo "Test data" > /mnt/tank/test.txt
cat /mnt/tank/test.txt
```

### Verificare il dataset

```bash
zfs list
df -h /mnt/tank
```

## 🔧 Operazioni di modifica del pool

### Aggiungere dispositivi per espandere il pool

<details>
<summary><strong>Aggiungere un vdev mirror (dischi interi)</strong></summary>

```bash
sudo zpool add tank mirror \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K3333333 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K4444444
```
</details>

<details>
<summary><strong>Aggiungere un vdev RAID-Z1 (dischi interi)</strong></summary>

```bash
sudo zpool add tank raidz \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K5555555 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K6666666 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7777777
```
</details>

<details>
<summary><strong>Aggiungere un mirror con le partizioni</strong></summary>

```bash
# Create partitions
sudo parted /dev/vde mklabel gpt
sudo parted /dev/vde mkpart primary 0% 100%
sudo parted /dev/vdf mklabel gpt
sudo parted /dev/vdf mkpart primary 0% 100%

# Add to pool using PARTUUIDs
sudo zpool add tank mirror \
  /dev/disk/by-partuuid/[partuuid-of-vde1] \
  /dev/disk/by-partuuid/[partuuid-of-vdf1]
```
</details>

### Sostituire un disco guasto {#replace-a-failed-disk}

{{< callout type="warning" >}}
**Importante**: la procedura di sostituzione dipende da come è stato creato il pool (dischi interi o partizioni).
{{< /callout >}}

#### Per i pool creati con dischi interi (by-id)

1. **Controlla lo stato del pool per individuare il disco guasto**:
```bash
zpool status tank
```

Output di esempio con un guasto:
```
  pool: tank
 state: DEGRADED
config:
        NAME                                            STATE     READ WRITE CKSUM
        tank                                            DEGRADED     0     0     0
          mirror-0                                      DEGRADED     0     0     0
            ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567    UNAVAIL      0     0     0
            ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7654321    ONLINE       0     0     0
```

2. **Sostituisci il disco guasto**:
```bash
sudo zpool replace tank \
  ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K9999999
```

3. **Segui il resilvering**:
```bash
zpool status tank
```

<details>
<summary><strong>Per i pool creati con le partizioni (by-partuuid)</strong></summary>

1. **Controlla lo stato del pool**:
```bash
zpool status tank
```

2. **Crea la partizione sul disco sostitutivo**:
```bash
sudo parted /dev/vdg mklabel gpt
sudo parted /dev/vdg mkpart primary 0% 100%
```

3. **Sostituisci usando il PARTUUID**:
```bash
sudo zpool replace tank \
  ee2507fe-0b11-ad4c-b1c5-87e36055410e \
  /dev/disk/by-partuuid/[new-partuuid-of-vdg1]
```

4. **Segui il resilvering**:
```bash
zpool status tank
```
</details>

### Agganciare un dispositivo a un mirror

<details>
<summary><strong>Trasformare un disco singolo in mirror o allargare un mirror esistente</strong></summary>

#### Con un disco intero
```bash
# Attach new disk to existing single disk (converts to mirror)
sudo zpool attach tank \
  ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K8888888
```

#### Con una partizione
```bash
# Create partition
sudo parted /dev/vdh mklabel gpt
sudo parted /dev/vdh mkpart primary 0% 100%

# Attach using PARTUUIDs
sudo zpool attach tank \
  ee2507fe-0b11-ad4c-b1c5-87e36055410e \
  /dev/disk/by-partuuid/[new-partuuid]
```
</details>

## 🔍 Manutenzione del pool

### Controllare lo stato del pool
```bash
zpool status tank
zpool list tank
```

### Scrub del pool (verifica dell'integrità dei dati)
```bash
# Start scrub
sudo zpool scrub tank

# Monitor progress
zpool status tank
```

### Esportare e importare un pool

<details>
<summary><strong>Utile per spostare i pool tra sistemi o per la manutenzione</strong></summary>

```bash
# Export pool
sudo zpool export tank

# Import pool (whole disk with by-id)
sudo zpool import -d /dev/disk/by-id tank

# Import pool (partitions with by-partuuid)
sudo zpool import -d /dev/disk/by-partuuid tank

# Import without knowing pool name
sudo zpool import
```
</details>

## 📋 Esempi completi

### Esempio 1: mirror con dischi virtuali (il più comune per le VM)

{{< callout type="success" >}}
**Consigliato per**: ambienti con VM, home lab
{{< /callout >}}

```bash
# 1. Identify available disks
lsblk

# 2. Verify disks are empty
sudo blkid /dev/vdb /dev/vdc

# 3. Create mirror pool (ZFS creates GPT automatically)
sudo zpool create tank mirror /dev/vdb /dev/vdc

# 4. Check what ZFS created
sudo blkid | grep zfs_member
lsblk

# 5. Create dataset with compression
sudo zfs create -o compression=lz4 tank/data
sudo zfs set mountpoint=/mnt/tank tank/data

# 6. Set permissions
sudo chown manzolo:manzolo /mnt/tank
sudo chmod 775 /mnt/tank

# 7. Test
echo "Hello ZFS" > /mnt/tank/test.txt

# 8. Verify
zpool status tank
zfs list
```

<details>
<summary><strong>Esempio 2: mirror con dischi fisici (by-id)</strong></summary>

```bash
# 1. Identify disks
ls -l /dev/disk/by-id/ | grep -v part

# 2. Create mirror pool
sudo zpool create tank mirror \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7654321

# 3. Create dataset with compression
sudo zfs create -o compression=lz4 tank/data
sudo zfs set mountpoint=/mnt/tank tank/data

# 4. Set permissions
sudo chown manzolo:manzolo /mnt/tank
sudo chmod 775 /mnt/tank

# 5. Test
echo "Hello ZFS" > /mnt/tank/test.txt

# 6. Verify
zpool status tank
zfs list
```
</details>

<details>
<summary><strong>Esempio 3: RAID-Z1 con dischi virtuali</strong></summary>

```bash
# Create RAID-Z1 pool with 3 virtual disks
sudo zpool create tank raidz /dev/vdb /dev/vdc /dev/vdd

# Check status
zpool status tank
```
</details>

<details>
<summary><strong>Esempio 4: mirror con partizioni manuali</strong></summary>

```bash
# 1. Create partitions
sudo parted /dev/vdb mklabel gpt
sudo parted /dev/vdb mkpart primary 0% 100%
sudo parted /dev/vdc mklabel gpt
sudo parted /dev/vdc mkpart primary 0% 100%

# 2. Get PARTUUIDs
sudo blkid /dev/vdb1 /dev/vdc1

# 3. Create pool (initially with device names)
sudo zpool create -f tank mirror /dev/vdb1 /dev/vdc1

# 4. Transition to PARTUUIDs
sudo zpool export tank
sudo zpool import -d /dev/disk/by-partuuid tank

# 5. Verify PARTUUIDs in status
zpool status tank

# 6. Check UUIDs
sudo blkid | grep zfs_member
```
</details>

<details>
<summary><strong>Esempio 5: sostituire una partizione guasta</strong></summary>

```bash
# 1. Check status (shows failed partition)
zpool status tank

# 2. Prepare replacement disk
sudo parted /dev/vdg mklabel gpt
sudo parted /dev/vdg mkpart primary 0% 100%

# 3. Get new PARTUUID
sudo blkid /dev/vdg1

# 4. Replace (use PARTUUID shown in zpool status)
sudo zpool replace tank \
  ee2507fe-0b11-ad4c-b1c5-87e36055410e \
  /dev/disk/by-partuuid/[new-partuuid]

# 5. Monitor resilver
zpool status tank
```
</details>

## 📚 Riferimento dei comandi

### Comandi essenziali

| Comando | A cosa serve |
|---------|---------|
| `zpool create` | Crea un nuovo pool |
| `zpool status` | Controlla lo stato di salute del pool |
| `zpool list` | Elenca i pool con la capacità |
| `zpool scrub` | Verifica l'integrità dei dati |
| `zpool replace` | Sostituisce un disco guasto |
| `zpool attach` | Aggiunge un disco a un mirror |
| `zpool add` | Aggiunge un vdev al pool |
| `zpool export` | Smonta il pool |
| `zpool import` | Monta il pool |
| `zfs create` | Crea un dataset |
| `zfs set` | Imposta le proprietà di un dataset |
| `zfs list` | Elenca i dataset |
| `zfs mount` | Monta un dataset |
| `zfs snapshot` | Crea uno snapshot |

### Comandi per gli identificatori di dispositivo

| Comando | A cosa serve |
|---------|---------|
| `ls -l /dev/disk/by-id/` | Elenca gli ID seriali dei dischi |
| `ls -l /dev/disk/by-partuuid/` | Elenca gli UUID delle partizioni |
| `sudo blkid` | Mostra tutti gli UUID e gli identificatori |
| `lsblk` | Elenca i dispositivi a blocchi |

## 💡 Consigli pratici

### Buone pratiche

{{< callout type="success" >}}
**Regole d'oro**:
1. Usa i dischi interi con `/dev/disk/by-id/`, per semplicità e prestazioni
2. Attiva la compressione: `zfs set compression=lz4` (spazio risparmiato gratis!)
3. Programma uno scrub al mese per l'integrità dei dati
4. Per i sistemi di produzione è consigliata la RAM ECC
{{< /callout >}}

### Importazione automatica al boot
```bash
sudo zpool set cachefile=/etc/zfs/zpool.cache tank
```

<details>
<summary><strong>Snapshot automatici</strong></summary>

```bash
# Daily snapshots via cron
0 0 * * * /sbin/zfs snapshot tank/data@daily-$(date +\%Y\%m\%d)

# Keep only last 7 days
0 1 * * * /sbin/zfs list -H -t snapshot -o name -s creation -d 1 tank/data | grep @daily- | head -n -7 | xargs -n 1 /sbin/zfs destroy
```
</details>

<details>
<summary><strong>Tenere d'occhio la salute del pool</strong></summary>

```bash
# Check for errors
zpool status -x

# Detailed status
zpool status -v tank

# I/O statistics
zpool iostat tank 1
```
</details>

## 🔧 Risoluzione dei problemi

<details>
<summary><strong>Confusione tra UUID del pool e PARTUUID</strong></summary>

**Problema**: si confonde l'UUID del pool con il PARTUUID della partizione.

**Soluzione**: 
- UUID del pool (da `blkid`, `TYPE="zfs_member"`): identifica il pool ZFS ed è condiviso da tutti i membri
- PARTUUID: identificatore univoco di ogni partizione GPT, è quello che si usa nei comandi `zpool`
</details>

<details>
<summary><strong>Dispositivo non trovato dopo il riavvio</strong></summary>

**Problema**: il pool mostra `/dev/sdb` ma il dispositivo adesso è `/dev/sdc`.

**Soluzione**: usa sempre gli identificatori persistenti:
```bash
sudo zpool export tank
sudo zpool import -d /dev/disk/by-id tank  # or by-partuuid for partitions
```
</details>

<details>
<summary><strong>Impossibile sostituire un dispositivo</strong></summary>

**Problema**: il comando replace fallisce con «device is in use».

**Soluzione**: 
- Assicurati di usare l'identificatore giusto, quello mostrato da `zpool status`
- Per i pool su partizioni, usa il PARTUUID mostrato nello stato
- Per i pool su dischi interi, usa il percorso by-id mostrato nello stato
</details>

<details>
<summary><strong>Disco/partizione in uso</strong></summary>

**Problema**: non si riesce a creare il pool, il dispositivo è occupato.

**Controlla**:
```bash
sudo lsof /dev/vdb1
sudo wipefs -a /dev/vdb1  # Clear old filesystem signatures
```
</details>

<details>
<summary><strong>Il pool non si importa dopo lo spostamento su un altro sistema</strong></summary>

**Problema**: il pool non è visibile dopo aver spostato i dischi su un nuovo sistema.

**Soluzione**:
```bash
# Scan for pools
sudo zpool import

# Import by pool ID
sudo zpool import -d /dev/disk/by-id [pool-id]
```
</details>

<details>
<summary><strong>Il PARTUUID non compare in zpool status</strong></summary>

**Problema**: lo stato mostra `/dev/vdb1` invece del PARTUUID.

**Soluzione**:
```bash
# Re-import with correct directory
sudo zpool export tank
sudo zpool import -d /dev/disk/by-partuuid tank
```
</details>

## 🎯 Casi d'uso

- **NAS di casa**: pool mirror per l'archivio multimediale, con gli snapshot
- **Storage per server**: RAID-Z per i dati aziendali, con ridondanza
- **Sistemi di backup**: snapshot per il ripristino a un dato istante
- **Macchine virtuali**: dataset con compressione per le immagini delle VM
- **Sviluppo**: snapshot veloci per prove e rollback

## 📖 Risorse

- [Documentazione di OpenZFS](https://openzfs.github.io/openzfs-docs/)
- [Guida a ZFS di Ubuntu](https://ubuntu.com/server/docs/zfs)
- [Buone pratiche per ZFS](https://openzfs.github.io/openzfs-docs/Performance%20and%20Tuning/Workload%20Tuning.html)

---

*Costruisci pool ZFS robusti con identificatori di dispositivo persistenti, per uno storage gestito in modo affidabile!*
