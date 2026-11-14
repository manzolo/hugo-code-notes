---
title: "Ridimensionare un disco QEMU/VirtualBox"
url: "2025/10/qemu/virtualbox-disk-resize/"
date: 2025-10-05T16:30:00+02:00
lastmod: 2026-11-14T19:00:00+01:00
draft: false
author: "Manzolo"
tags: ["qemu", "resize", "disk", "virtualization", "quick-tip"]
categories: ["Quick Pills"]
series: ["Quick Pills Collection"]
weight: 5
ShowToc: false
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "Guida rapida per ridimensionare i dischi virtuali di QEMU/VirtualBox ed espandere le partizioni"
---

# 💊 Pillola rapida: ridimensionare un disco QEMU/VirtualBox

{{< callout type="info" >}}
**A cosa serve**: allargare il disco di una macchina virtuale quando lo spazio sta finendo. Funziona con le immagini raw di QEMU, con i VDI/VHD di VirtualBox e con formati simili.
{{< /callout >}}

## 🚀 Il ridimensionamento completo

{{< callout type="warning" >}}
**⚠️ Fondamentale**: fai sempre un backup del disco della VM prima di ridimensionarlo!
{{< /callout >}}

### Guida passo per passo

```bash
# 1. Shutdown your VM first!

# 2. Resize the disk image file
qemu-img resize -f raw Ubuntu.vhd 200G

# 3. Load NBD kernel module
sudo modprobe nbd

# 4. Connect disk as network block device
sudo qemu-nbd --connect=/dev/nbd0 -f raw Ubuntu.vhd

# 5. Expand the partition
sudo parted /dev/nbd0
```

**Dentro parted:**
```
(parted) print                    # Show current partitions (on GPT, answer Fix when asked to fix the GPT)
(parted) resizepart 2 100%        # Resize partition 2 to use all space
(parted) quit                     # Exit parted
```

```bash
# 6. Resize the filesystem
sudo resize2fs /dev/nbd0p2

# 7. Verify the changes
sudo parted /dev/nbd0 print

# 8. Disconnect the NBD device
sudo qemu-nbd --disconnect /dev/nbd0

# 9. Start your VM - done!
```

## 📋 Capire ogni passo

### 1. Ridimensionare l'immagine del disco

```bash
qemu-img resize -f raw Ubuntu.vhd 200G
```

**Cosa fa:**
- `-f raw`: indica il formato (raw, qcow2, vdi, vpc per i VHD, vmdk); in qemu-img 8.2 `resize` funziona su raw e qcow2, non su vpc/vdi/vmdk
- `Ubuntu.vhd`: il file con l'immagine del disco; qui sono dati raw nonostante l'estensione (`qemu-img info` dice `file format: raw`, come per un VHD a dimensione fissa, che è un raw più un footer di 512 byte). Se ridimensioni un VHD fisso con `-f raw`, quel footer finisce in mezzo al disco: QEMU lo avvia ancora, Hyper-V e VirtualBox non lo leggono più come VHD
- `200G`: la nuova dimensione totale (non lo spazio aggiunto!)

**Formati della dimensione:**
- `200G`: porta il totale a 200GB
- `+50G`: aggiunge 50GB alla dimensione attuale
- `+10240M`: aggiunge 10GB (in megabyte)

### 2. Collegarlo come dispositivo a blocchi

```bash
sudo modprobe nbd
sudo qemu-nbd --connect=/dev/nbd0 -f raw Ubuntu.vhd
```

**Cosa fa:**
- `nbd`: il modulo Network Block Device
- `/dev/nbd0`: il primo dispositivo NBD (se è occupato usa nbd1, nbd2)
- Monta l'immagine del disco come se fosse un disco fisico

### 3. Ridimensionare la partizione

```bash
sudo parted /dev/nbd0 resizepart 2 100%
```

**Cosa fa:**
- `resizepart 2`: ridimensiona la partizione numero 2
- `100%`: usa tutto lo spazio disponibile
- **Nota**: se il numero della partizione è diverso, adattalo!

### 4. Ridimensionare il filesystem

```bash
sudo resize2fs /dev/nbd0p2
```

**Cosa fa:**
- Espande il filesystem ext4/ext3 fino a riempire la partizione
- `p2` = partizione 2 (deve combaciare con resizepart!)
- Automatico: la nuova dimensione la ricava dalla partizione

## 💡 Consigli da esperti

<details>
<summary><strong>Lavorare con altri formati di disco</strong></summary>

### QCOW2 (il formato nativo di QEMU)
```bash
# Resize
qemu-img resize -f qcow2 disk.qcow2 +50G

# Connect
sudo qemu-nbd --connect=/dev/nbd0 -f qcow2 disk.qcow2
```

### VDI di VirtualBox
```bash
# Resize using VBoxManage
VBoxManage modifymedium disk Ubuntu.vdi --resize 204800  # Size in MB

# Or convert to raw first, then resize
qemu-img convert -f vdi -O raw Ubuntu.vdi Ubuntu.raw
qemu-img resize Ubuntu.raw 200G
```

### VMDK (VMware)
```bash
# qemu-img cannot resize vmdk ("Image format driver does not support resize"):
# go through raw, then back
qemu-img convert -f vmdk -O raw disk.vmdk disk.raw
qemu-img resize -f raw disk.raw 200G
qemu-img convert -f raw -O vmdk disk.raw disk.vmdk

# Connect
sudo qemu-nbd --connect=/dev/nbd0 -f vmdk disk.vmdk
```
</details>

<details>
<summary><strong>Controllare prima lo schema delle partizioni</strong></summary>

```bash
# Connect disk
sudo qemu-nbd --connect=/dev/nbd0 -f raw Ubuntu.vhd

# List partitions
sudo parted /dev/nbd0 print

# Example output:
# Number  Start   End     Size    Type     File system  Flags
#  1      1049kB  538MB   537MB   primary  fat32        boot, esp
#  2      538MB   100GB   99.5GB  primary  ext4

# Note the partition number (usually 2 for Linux root)

# Disconnect when done
sudo qemu-nbd --disconnect /dev/nbd0
```
</details>

<details>
<summary><strong>Ridimensionare un filesystem XFS invece di ext4</strong></summary>

```bash
# After resizing partition
# XFS requires mounting first
sudo mkdir -p /mnt/temp
sudo mount /dev/nbd0p2 /mnt/temp

# Resize XFS
sudo xfs_growfs /mnt/temp

# Unmount
sudo umount /mnt/temp
```
</details>

<details>
<summary><strong>Ridimensionare i volumi LVM</strong></summary>

```bash
# After resizing partition with LVM
# 1. Resize physical volume
sudo pvresize /dev/nbd0p2

# 2. Check volume group
sudo vgdisplay

# 3. Resize logical volume
sudo lvextend -l +100%FREE /dev/ubuntu-vg/root

# 4. Resize filesystem
sudo resize2fs /dev/ubuntu-vg/root
# Or for XFS:
# sudo xfs_growfs /dev/ubuntu-vg/root
```
</details>

<details>
<summary><strong>Aggiungere spazio un po' alla volta</strong></summary>

```bash
# Add 50GB to current size (safer than setting absolute size)
qemu-img resize -f raw Ubuntu.vhd +50G

# Add in smaller chunks
qemu-img resize -f raw Ubuntu.vhd +10G
# Test VM, then add more if needed
qemu-img resize -f raw Ubuntu.vhd +10G
```
</details>

<details>
<summary><strong>Più dispositivi NBD in uso</strong></summary>

```bash
# Check which NBD devices are available
ls -la /dev/nbd*

# Try different device if nbd0 is busy
sudo qemu-nbd --connect=/dev/nbd1 -f raw Ubuntu.vhd
sudo qemu-nbd --connect=/dev/nbd2 -f raw Ubuntu.vhd

# List active NBD connections
ps aux | grep qemu-nbd
```
</details>

<details>
<summary><strong>Uno script completo per il ridimensionamento</strong></summary>

Salvalo come `resize_vm_disk.sh`:

```bash
#!/bin/bash

# Configuration
DISK_IMAGE="${1}"
NEW_SIZE="${2}"
PARTITION_NUM="${3:-2}"  # Default partition 2
NBD_DEVICE="/dev/nbd0"

if [ -z "$DISK_IMAGE" ] || [ -z "$NEW_SIZE" ]; then
    echo "Usage: $0 <disk_image> <new_size> [partition_number]"
    echo "Example: $0 Ubuntu.vhd 200G 2"
    exit 1
fi

if [ ! -f "$DISK_IMAGE" ]; then
    echo "Error: Disk image not found: $DISK_IMAGE"
    exit 1
fi

echo "================================================"
echo "  VM Disk Resize Script"
echo "================================================"
echo "Disk image: $DISK_IMAGE"
echo "New size: $NEW_SIZE"
echo "Partition: $PARTITION_NUM"
echo ""

read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Detect format
FORMAT=$(qemu-img info "$DISK_IMAGE" | grep "file format:" | awk '{print $3}')
echo "Detected format: $FORMAT"
echo ""

# Step 1: Resize image
echo "[1/6] Resizing disk image..."
qemu-img resize -f "$FORMAT" "$DISK_IMAGE" "$NEW_SIZE"

# Step 2: Load NBD module
echo "[2/6] Loading NBD module..."
sudo modprobe nbd max_part=8

# Step 3: Connect NBD
echo "[3/6] Connecting disk as NBD device..."
sudo qemu-nbd --connect=$NBD_DEVICE -f "$FORMAT" "$DISK_IMAGE"

# Wait for device
sleep 2

# Step 4: Show current layout
echo "[4/6] Current partition layout:"
sudo parted $NBD_DEVICE print

# Step 5: Resize partition
echo "[5/6] Resizing partition $PARTITION_NUM..."
# GPT: move the backup header to the new end of the disk, or resizepart fails
printf "Fix\n" | sudo parted ---pretend-input-tty $NBD_DEVICE print >/dev/null
sudo parted $NBD_DEVICE resizepart $PARTITION_NUM 100%

# Step 6: Resize filesystem
echo "[6/6] Resizing filesystem..."
PART_DEVICE="${NBD_DEVICE}p${PARTITION_NUM}"

# Detect filesystem type
FS_TYPE=$(sudo blkid -o value -s TYPE $PART_DEVICE)
echo "Filesystem type: $FS_TYPE"

case $FS_TYPE in
    ext4|ext3|ext2)
        sudo resize2fs $PART_DEVICE
        ;;
    xfs)
        TEMP_MOUNT="/mnt/temp_resize_$$"
        sudo mkdir -p "$TEMP_MOUNT"
        sudo mount $PART_DEVICE "$TEMP_MOUNT"
        sudo xfs_growfs "$TEMP_MOUNT"
        sudo umount "$TEMP_MOUNT"
        sudo rmdir "$TEMP_MOUNT"
        ;;
    *)
        echo "Warning: Unknown filesystem type: $FS_TYPE"
        echo "You may need to resize manually."
        ;;
esac

# Verify
echo ""
echo "New partition layout:"
sudo parted $NBD_DEVICE print

# Disconnect
echo ""
echo "Disconnecting NBD device..."
sudo qemu-nbd --disconnect $NBD_DEVICE

echo ""
echo "================================================"
echo "  Resize Complete!"
echo "================================================"
echo "You can now start your VM."
echo ""
```

**Uso:**
```bash
chmod +x resize_vm_disk.sh
sudo ./resize_vm_disk.sh Ubuntu.vhd 200G 2
```
</details>

<details>
<summary><strong>Rimpicciolire il disco (avanzato, rischioso)</strong></summary>

{{< callout type="danger" >}}
**Attenzione**: rimpicciolire è pericoloso e può far perdere dati!
{{< /callout >}}

```bash
# 1. Connect disk
sudo qemu-nbd --connect=/dev/nbd0 -f raw Ubuntu.vhd

# 2. Check filesystem usage
sudo e2fsck -f /dev/nbd0p2
sudo resize2fs /dev/nbd0p2 150G  # Shrink filesystem first!

# 3. Shrink partition: resizepart takes the END position, not the size,
#    and it must stay beyond partition start + 150GiB (parted "GB" = 10^9 bytes)
sudo parted /dev/nbd0 resizepart 2 155GiB

# 4. Disconnect
sudo qemu-nbd --disconnect /dev/nbd0

# 5. Shrink image (only for raw/qcow2)
qemu-img resize --shrink -f raw Ubuntu.vhd 160G

# Note: Always leave some extra space!
```
</details>

## 🔍 Risoluzione dei problemi

<details>
<summary><strong>Modulo NBD non trovato</strong></summary>

**Problema**: `modprobe: FATAL: Module nbd not found`

**Soluzione**:
```bash
# Ubuntu/Debian
sudo apt install qemu-utils qemu-block-extra

# Fedora/RHEL
sudo dnf install qemu-img

# Try loading again
sudo modprobe nbd max_part=8
```
</details>

<details>
<summary><strong>Device or resource busy</strong></summary>

**Problema**: non riesci a collegarti a /dev/nbd0

**Soluzione**:
```bash
# Check if nbd0 is in use
sudo qemu-nbd --disconnect /dev/nbd0

# Or use different device
sudo qemu-nbd --connect=/dev/nbd1 -f raw Ubuntu.vhd

# List all NBD devices
cat /proc/partitions | grep nbd
```
</details>

<details>
<summary><strong>Partizione non trovata dopo il ridimensionamento</strong></summary>

**Problema**: `/dev/nbd0p2` non esiste

**Soluzione**:
```bash
# Reload partition table
sudo partprobe /dev/nbd0

# Or reconnect with max_part
sudo qemu-nbd --disconnect /dev/nbd0
sudo modprobe -r nbd
sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 -f raw Ubuntu.vhd
```
</details>

<details>
<summary><strong>Nella VM il filesystem mostra ancora la vecchia dimensione</strong></summary>

**Problema**: dopo il ridimensionamento la VM mostra la vecchia dimensione del disco

**Soluzione**:
```bash
# Inside the VM (after resizing from host)
# 1. Check current size
df -h

# 2. Rescan disk
sudo partprobe

# 3. Grow filesystem (if not done from host)
sudo resize2fs /dev/sda2  # or your root partition

# 4. Verify
df -h
```
</details>

<details>
<summary><strong>Impossibile ridimensionare: il filesystem ha errori</strong></summary>

**Problema**: `resize2fs: filesystem has errors`

**Soluzione**:
```bash
# Check and repair filesystem first
sudo e2fsck -f -y /dev/nbd0p2

# Then resize
sudo resize2fs /dev/nbd0p2
```
</details>

<details>
<summary><strong>Il ridimensionamento del disco VirtualBox fallisce</strong></summary>

**Problema**: il resize con VBoxManage non funziona

**Soluzione**:
```bash
# Convert to raw format first (qemu-img cannot resize VDI or VHD)
VBoxManage clonemedium disk Ubuntu.vdi Ubuntu.img --format RAW

# Resize using qemu-img
qemu-img resize -f raw Ubuntu.img 200G

# Follow NBD process above

# Or use VBoxManage with correct UUID
VBoxManage showhdinfo Ubuntu.vdi  # Get UUID
VBoxManage modifymedium disk <UUID> --resize 204800
```
</details>

## 📊 Formati supportati

| Formato | Comando | Note |
|--------|---------|-------|
| RAW | `qemu-img resize -f raw disk.raw 200G` | Il più veloce, il file più grande |
| QCOW2 | `qemu-img resize -f qcow2 disk.qcow2 +50G` | Nativo di QEMU, dinamico |
| VDI | `VBoxManage modifymedium disk.vdi --resize 204800` | VirtualBox (dimensione in MB) |
| VHD | `qemu-img convert -f vpc -O raw disk.vhd disk.raw`, poi ridimensioni il file raw | Hyper-V/VirtualBox (qemu-img non ridimensiona `vpc`) |
| VMDK | `qemu-img convert -O raw`, `resize`, `convert -O vmdk` | VMware (niente resize diretto) |

## ⚠️ Avvertenze importanti

{{< callout type="danger" >}}
**Prima di ridimensionare:**

1. **Spegni del tutto la VM** - mai ridimensionare mentre è accesa
2. **Fai un backup dell'immagine del disco** - copiala in un posto sicuro
3. **Prova prima su uno snapshot o su una copia**, se puoi
4. **Verifica il formato** con `qemu-img info disk.img`
5. **Controlla lo spazio libero** sull'host (serve posto per il file più grande)
6. **Ricorda**: rimpicciolire è pericoloso, espandere è sicuro
{{< /callout >}}

## 🎯 Casi tipici

### Espandere una VM Ubuntu

```bash
# Typical Ubuntu setup: partition 2 is root
qemu-img resize -f raw Ubuntu.vhd 200G
sudo modprobe nbd
sudo qemu-nbd --connect=/dev/nbd0 -f raw Ubuntu.vhd
sudo parted /dev/nbd0 resizepart 2 100%
sudo resize2fs /dev/nbd0p2
sudo qemu-nbd --disconnect /dev/nbd0
```

### Espandere una VM Windows (NTFS)

```bash
# Windows needs ntfsresize instead of resize2fs
qemu-img resize -f raw Windows.vhd 300G
sudo modprobe nbd
sudo qemu-nbd --connect=/dev/nbd0 -f raw Windows.vhd
# Typical UEFI layout: 1 = EFI, 2 = MSR (16MB), 3 = Windows (NTFS), 4 = Recovery
# Partition 3 can grow only if nothing follows it: move or delete
# the Recovery partition first (check with: sudo parted /dev/nbd0 print)
sudo parted /dev/nbd0 resizepart 3 100%
sudo ntfsresize -f /dev/nbd0p3  # For NTFS
sudo qemu-nbd --disconnect /dev/nbd0
```

### Un controllo veloce, senza ridimensionare

```bash
# Just inspect disk
sudo modprobe nbd
sudo qemu-nbd --connect=/dev/nbd0 -f raw Ubuntu.vhd
sudo parted /dev/nbd0 print
sudo fdisk -l /dev/nbd0
df -h  # Won't show until mounted
sudo qemu-nbd --disconnect /dev/nbd0
```

## 📈 Guida al dimensionamento

| Uso della VM | Dimensione consigliata | Quando ridimensionare |
|------------|-----------------|-------------|
| Test/sviluppo | 20-50GB | Sotto i 5GB liberi |
| VM desktop | 50-100GB | Sotto i 10GB liberi |
| Server | 100-500GB | Sotto i 20GB liberi |
| Produzione | 500GB+ | Sotto il 10% libero |

## 🚀 Comandi di riferimento rapido

```bash
# 1. RESIZE IMAGE
qemu-img resize -f raw disk.vhd +50G

# 2. CONNECT
sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 -f raw disk.vhd

# 3. RESIZE PARTITION
sudo parted /dev/nbd0 resizepart 2 100%

# 4. RESIZE FILESYSTEM
sudo resize2fs /dev/nbd0p2        # ext4
# OR
sudo xfs_growfs /mnt/mountpoint   # XFS
# OR
sudo ntfsresize -f /dev/nbd0p2    # NTFS

# 5. VERIFY
sudo parted /dev/nbd0 print

# 6. DISCONNECT
sudo qemu-nbd --disconnect /dev/nbd0
```

## 🔄 L'alternativa: ridimensionare da dentro la VM

Se NBD non funziona, ridimensiona dall'interno della VM:

```bash
# 1. Resize image from host (VM off)
qemu-img resize disk.vhd 200G

# 2. Boot VM and run inside it
sudo growpart /dev/sda 2    # Grow partition
sudo resize2fs /dev/sda2    # Grow filesystem

# Or use parted
sudo parted /dev/sda resizepart 2 100%
sudo resize2fs /dev/sda2
```

---

*Allarga le tue macchine virtuali senza complicarti la vita!*
