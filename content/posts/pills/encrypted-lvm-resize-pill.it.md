---
title: "Ridimensionare un disco LVM cifrato (LUKS + LVM)"
url: "2025/10/encrypted-lvm-disk-resize-luks--lvm/"
date: 2025-10-05T17:00:00+02:00
draft: false
author: "Manzolo"
tags: ["lvm", "luks", "resize", "encryption", "quick-tip"]
categories: ["Quick Pills"]
series: ["Quick Pills Collection"]
weight: 6
ShowToc: false
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "Guida rapida per ridimensionare i dischi QEMU con cifratura LUKS e partizioni LVM"
---

# 💊 Pillola rapida: ridimensionare un disco LVM cifrato

{{< callout type="info" >}}
**A cosa serve**: allargare le VM Ubuntu/Debian cifrate che usano LUKS + LVM. È la situazione tipica delle installazioni con cifratura dell'intero disco.
{{< /callout >}}

## 🔐 La procedura completa (cifratura + LVM)

{{< callout type="warning" >}}
**⚠️ Fondamentale**: 
- Spegni del tutto la VM prima di cominciare
- Fai prima un backup dell'immagine del disco
- Vale per la configurazione LUKS + LVM (l'installazione cifrata standard di Ubuntu)
{{< /callout >}}

### Guida passo passo

```bash
# 1. Resize the disk image file
qemu-img resize -f raw Ubuntu.vhd 200G

# 2. Load NBD module
sudo modprobe nbd max_part=8

# 3. Connect disk as network block device
sudo qemu-nbd --connect=/dev/nbd0 -f raw Ubuntu.vhd

# 4. Check partition layout
lsblk

# 5. Open LUKS encrypted partition (you'll need the password)
sudo cryptsetup luksOpen /dev/nbd0p3 sda3_crypt

# 6. Scan LVM volumes
sudo vgscan
sudo pvscan
sudo lvscan

# 7. Resize the partition
sudo parted /dev/nbd0
```

**Dentro parted:**
```
(parted) print                    # Show current layout
(parted) resizepart 3 100%        # Resize partition 3 to fill disk
(parted) quit
```

```bash
# 8. Reload partition table
sudo partprobe /dev/nbd0

# 9. Verify partition resize
sudo parted /dev/nbd0 print

# 10. Resize LUKS container
sudo cryptsetup -v resize sda3_crypt

# 11. Resize LVM physical volume
sudo pvresize /dev/mapper/sda3_crypt

# 12. Check filesystem before resize (important!)
sudo e2fsck -f /dev/mapper/vgubuntu-root

# 13. Extend logical volume to use all free space
sudo lvextend -l +100%FREE /dev/vgubuntu/root

# 14. Resize filesystem
sudo resize2fs /dev/mapper/vgubuntu-root

# 15. Verify filesystem after resize
sudo e2fsck -f /dev/mapper/vgubuntu-root

# 16. Verify LVM changes
sudo vgscan
sudo pvscan
sudo lvscan

# 17. Deactivate LVM volumes (important!)
sudo lvchange -an /dev/vgubuntu/root
sudo lvchange -an /dev/vgubuntu/swap_1
sudo vgchange -an vgubuntu

# 18. Close LUKS container
sudo cryptsetup luksClose sda3_crypt

# 19. Disconnect NBD
sudo qemu-nbd --disconnect /dev/nbd0

# 20. Start your VM - done!
```

## 🔍 Capire gli strati

### Lo schema tipico di una Ubuntu cifrata

```
Disk Image (Ubuntu.vhd)
  └─ Partition 1: EFI System Partition (ESP)
  └─ Partition 2: /boot (unencrypted)
  └─ Partition 3: LUKS encrypted container
      └─ LVM Physical Volume (sda3_crypt)
          └─ Volume Group (vgubuntu)
              ├─ Logical Volume: root
              └─ Logical Volume: swap_1
```

### L'ordine del ridimensionamento (fondamentale!)

1. **Immagine del disco** → Si allarga il file
2. **Partizione** → Si allarga la tabella delle partizioni
3. **Container LUKS** → Si allarga lo strato cifrato
4. **Physical Volume** → Si allarga il PV di LVM
5. **Logical Volume** → Si allarga il LV di LVM
6. **Filesystem** → Si allarga ext4/xfs

## 💡 Consigli da esperti

<details>
<summary><strong>Trovare il numero giusto della partizione</strong></summary>

```bash
# After connecting NBD
sudo qemu-nbd --connect=/dev/nbd0 -f raw Ubuntu.vhd

# List all partitions with details
sudo lsblk -f /dev/nbd0

# Example output:
# NAME      FSTYPE      LABEL  UUID                                 MOUNTPOINT
# nbd0
# ├─nbd0p1  vfat        ESP    XXXX-XXXX
# ├─nbd0p2  ext4        boot   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# └─nbd0p3  crypto_LUKS        yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy

# Partition 3 is LUKS encrypted - that's what we resize!

# Check partition types
sudo parted /dev/nbd0 print

# Look for LUKS
sudo cryptsetup isLuks /dev/nbd0p3 && echo "This is LUKS"
```
</details>

<details>
<summary><strong>Trovare i nomi del volume group e dei logical volume</strong></summary>

```bash
# After opening LUKS
sudo cryptsetup luksOpen /dev/nbd0p3 sda3_crypt

# Scan for volume groups
sudo vgscan
# Output: Found volume group "vgubuntu"...

# List volume groups
sudo vgdisplay

# List logical volumes
sudo lvdisplay

# Quick list
sudo lvscan
# Output:
#   ACTIVE   '/dev/vgubuntu/root' [XX.XX GiB]
#   ACTIVE   '/dev/vgubuntu/swap_1' [X.XX GiB]

# Use these names in lvextend command
# Format: /dev/VolumeGroup/LogicalVolume
```
</details>

<details>
<summary><strong>Lo script completo, tutto automatico</strong></summary>

Salvalo come `resize_encrypted_lvm.sh`:

```bash
#!/bin/bash

# Configuration
DISK_IMAGE="${1}"
NEW_SIZE="${2}"
ENCRYPTED_PART="${3:-3}"  # Usually partition 3
NBD_DEVICE="/dev/nbd0"

if [ -z "$DISK_IMAGE" ] || [ -z "$NEW_SIZE" ]; then
    echo "Usage: $0 <disk_image> <new_size> [encrypted_partition_num]"
    echo "Example: $0 Ubuntu.vhd 200G 3"
    exit 1
fi

echo "================================================"
echo "  Encrypted LVM Disk Resize"
echo "================================================"
echo "Disk: $DISK_IMAGE"
echo "New size: $NEW_SIZE"
echo "Encrypted partition: $ENCRYPTED_PART"
echo ""

read -p "⚠️  WARNING: Backup your disk first! Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Step 1: Resize image
echo "[1/15] Resizing disk image..."
qemu-img resize -f raw "$DISK_IMAGE" "$NEW_SIZE" || exit 1

# Step 2: Load NBD
echo "[2/15] Loading NBD module..."
sudo modprobe nbd max_part=8

# Step 3: Connect NBD
echo "[3/15] Connecting disk..."
sudo qemu-nbd --connect=$NBD_DEVICE -f raw "$DISK_IMAGE" || exit 1
sleep 2

# Step 4: Show layout
echo "[4/15] Current disk layout:"
lsblk $NBD_DEVICE
echo ""

# Step 5: Open LUKS
LUKS_PART="${NBD_DEVICE}p${ENCRYPTED_PART}"
MAPPER_NAME="temp_crypt_$$"

echo "[5/15] Opening LUKS partition..."
echo "You'll need to enter the disk encryption password:"
sudo cryptsetup luksOpen "$LUKS_PART" "$MAPPER_NAME" || {
    echo "Failed to open LUKS. Cleaning up..."
    sudo qemu-nbd --disconnect $NBD_DEVICE
    exit 1
}

# Step 6: Scan LVM
echo "[6/15] Scanning LVM volumes..."
sudo vgscan
sudo pvscan
sudo lvscan

# Detect VG and LV names
VG_NAME=$(sudo vgs --noheadings -o vg_name | head -1 | xargs)
ROOT_LV=$(sudo lvs --noheadings -o lv_name "$VG_NAME" | grep -v swap | head -1 | xargs)
SWAP_LV=$(sudo lvs --noheadings -o lv_name "$VG_NAME" | grep swap | head -1 | xargs)

echo ""
echo "Detected configuration:"
echo "  Volume Group: $VG_NAME"
echo "  Root LV: $ROOT_LV"
echo "  Swap LV: $SWAP_LV"
echo ""

# Step 7: Resize partition
echo "[7/15] Resizing partition..."
sudo parted $NBD_DEVICE resizepart $ENCRYPTED_PART 100%

# Step 8: Reload partition table
echo "[8/15] Reloading partition table..."
sudo partprobe $NBD_DEVICE
sleep 1

# Step 9: Resize LUKS
echo "[9/15] Resizing LUKS container..."
sudo cryptsetup -v resize "$MAPPER_NAME"

# Step 10: Resize PV
echo "[10/15] Resizing physical volume..."
sudo pvresize "/dev/mapper/$MAPPER_NAME"

# Step 11: Check filesystem
echo "[11/15] Checking filesystem..."
sudo e2fsck -f "/dev/$VG_NAME/$ROOT_LV"

# Step 12: Extend LV
echo "[12/15] Extending logical volume..."
sudo lvextend -l +100%FREE "/dev/$VG_NAME/$ROOT_LV"

# Step 13: Resize filesystem
echo "[13/15] Resizing filesystem..."
sudo resize2fs "/dev/$VG_NAME/$ROOT_LV"

# Step 14: Verify
echo "[14/15] Verifying filesystem..."
sudo e2fsck -f "/dev/$VG_NAME/$ROOT_LV"

# Step 15: Cleanup
echo "[15/15] Cleaning up..."
sudo lvchange -an "/dev/$VG_NAME/$ROOT_LV"
[ -n "$SWAP_LV" ] && sudo lvchange -an "/dev/$VG_NAME/$SWAP_LV"
sudo vgchange -an "$VG_NAME"
sudo cryptsetup luksClose "$MAPPER_NAME"
sudo qemu-nbd --disconnect $NBD_DEVICE

echo ""
echo "================================================"
echo "  Resize Complete!"
echo "================================================"
echo "Final layout:"
sudo vgdisplay "$VG_NAME" 2>/dev/null || echo "(Volumes deactivated)"
echo ""
echo "You can now start your VM."
```

**Uso:**
```bash
chmod +x resize_encrypted_lvm.sh
sudo ./resize_encrypted_lvm.sh Ubuntu.vhd 200G 3
```
</details>

<details>
<summary><strong>Ridimensionare anche la swap</strong></summary>

```bash
# After extending root, you can also resize swap if needed

# Deactivate swap
sudo swapoff /dev/vgubuntu/swap_1

# Extend swap LV (add 4GB for example)
sudo lvextend -L +4G /dev/vgubuntu/swap_1

# Recreate swap
sudo mkswap /dev/vgubuntu/swap_1

# Note: Usually not necessary unless you need more swap
```
</details>

<details>
<summary><strong>Controllare lo spazio disponibile prima di ridimensionare</strong></summary>

```bash
# After pvresize, check available space
sudo vgdisplay vgubuntu

# Look for "Free PE / Size"
# Example output:
#   Free  PE / Size       12800 / 50.00 GiB

# Calculate how much to extend
sudo lvextend -L +50G /dev/vgubuntu/root

# Or use all free space
sudo lvextend -l +100%FREE /dev/vgubuntu/root
```
</details>

<details>
<summary><strong>Se il filesystem è XFS invece di ext4</strong></summary>

```bash
# Check filesystem type first
sudo blkid /dev/mapper/vgubuntu-root

# If XFS (instead of ext4):
# After lvextend, mount and resize
sudo mkdir -p /mnt/temp
sudo mount /dev/mapper/vgubuntu-root /mnt/temp
sudo xfs_growfs /mnt/temp
sudo umount /mnt/temp

# Note: XFS can be resized while mounted in the VM too
```
</details>

<details>
<summary><strong>Backup dell'header LUKS prima di ridimensionare</strong></summary>

```bash
# CRITICAL: Backup LUKS header first
sudo cryptsetup luksHeaderBackup /dev/nbd0p3 \
    --header-backup-file ~/luks_header_backup_$(date +%Y%m%d).img

# Store this file safely!
# If LUKS header is damaged, your data is LOST

# Restore header if needed
sudo cryptsetup luksHeaderRestore /dev/nbd0p3 \
    --header-backup-file ~/luks_header_backup_20251005.img
```
</details>

## 🚀 Comandi per avviare QEMU

### Avvio base della VM

```bash
# Standard launch
qemu-system-x86_64 \
  -machine q35 \
  -drive file=Ubuntu.vhd,format=raw,if=virtio \
  -m 4G \
  -cpu host \
  -enable-kvm \
  -bios /usr/share/OVMF/OVMF.fd \
  -device virtio-net,netdev=net0 \
  -netdev user,id=net0 \
  -display sdl
```

### Avvio con il supporto di installazione

```bash
# Boot with ISO for recovery/install
qemu-system-x86_64 \
  -machine q35 \
  -drive file=/path/to/ubuntu-24.04-desktop-amd64.iso,media=cdrom \
  -boot menu=on \
  -drive file=Ubuntu.vhd,format=raw,if=virtio \
  -m 4G \
  -cpu host \
  -enable-kvm \
  -bios /usr/share/OVMF/OVMF.fd \
  -device virtio-net,netdev=net0 \
  -netdev user,id=net0 \
  -display sdl
```

<details>
<summary><strong>Le opzioni di avvio di QEMU, spiegate</strong></summary>

```bash
qemu-system-x86_64 \
  -machine q35 \              # Modern chipset
  -drive file=disk.img,format=raw,if=virtio \  # Disk (virtio = fast)
  -m 4G \                     # RAM (4GB)
  -cpu host \                 # Use host CPU features
  -enable-kvm \               # Enable KVM acceleration
  -bios /usr/share/OVMF/OVMF.fd \  # UEFI boot (for modern VMs)
  -device virtio-net,netdev=net0 \  # Network card
  -netdev user,id=net0 \      # NAT networking
  -display sdl                # Display type (or gtk, vnc, spice)
```

**Aggiunte comuni:**
```bash
# More RAM
-m 8G

# Multiple cores
-smp 4

# USB passthrough
-usb -device usb-host,vendorid=0x1234,productid=0x5678

# VNC display (for remote access)
-display vnc=:1

# Shared folder (requires guest tools)
-virtfs local,path=/host/path,mount_tag=shared,security_model=none

# Snapshot mode (don't modify disk)
-snapshot
```
</details>

## 🔧 Risoluzione dei problemi

<details>
<summary><strong>Numero di partizione sbagliato</strong></summary>

**Problema**: la partizione LUKS non si trova

**Soluzione**:
```bash
# Check all partitions
sudo lsblk -f /dev/nbd0

# Find LUKS partition
sudo blkid | grep crypto_LUKS

# Test each partition
sudo cryptsetup isLuks /dev/nbd0p1 && echo "p1 is LUKS"
sudo cryptsetup isLuks /dev/nbd0p2 && echo "p2 is LUKS"
sudo cryptsetup isLuks /dev/nbd0p3 && echo "p3 is LUKS"
```
</details>

<details>
<summary><strong>Il volume group non si trova</strong></summary>

**Problema**: `vgscan` non trova nessun volume group

**Soluzione**:
```bash
# Make sure LUKS is open first
sudo cryptsetup status sda3_crypt

# If not open:
sudo cryptsetup luksOpen /dev/nbd0p3 sda3_crypt

# Scan again
sudo vgscan
sudo vgchange -ay  # Activate all VGs

# List all PVs
sudo pvs

# List all VGs
sudo vgs

# List all LVs
sudo lvs
```
</details>

<details>
<summary><strong>Il controllo del filesystem fallisce</strong></summary>

**Problema**: `e2fsck` segnala errori

**Soluzione**:
```bash
# Force check and auto-fix
sudo e2fsck -f -y /dev/mapper/vgubuntu-root

# If still errors, try:
sudo e2fsck -f -p /dev/mapper/vgubuntu-root

# Last resort (may lose data):
sudo e2fsck -f -y -v /dev/mapper/vgubuntu-root
```
</details>

<details>
<summary><strong>lvextend: insufficient free space</strong></summary>

**Problema**: non c'è abbastanza spazio nel volume group

**Soluzione**:
```bash
# Check available space
sudo vgdisplay vgubuntu | grep "Free"

# You may have forgotten to resize PV
sudo pvresize /dev/mapper/sda3_crypt

# Check PV size
sudo pvdisplay

# Then try lvextend again
sudo lvextend -l +100%FREE /dev/vgubuntu/root
```
</details>

<details>
<summary><strong>Device occupato durante la pulizia finale</strong></summary>

**Problema**: non si riesce a chiudere LUKS o a scollegare NBD

**Soluzione**:
```bash
# Check what's using the device
sudo lsof | grep nbd0
sudo lsof | grep vgubuntu

# Force deactivate LVs
sudo lvchange -an /dev/vgubuntu/root
sudo lvchange -an /dev/vgubuntu/swap_1

# Force deactivate VG
sudo vgchange -an vgubuntu

# Force close LUKS
sudo cryptsetup luksClose sda3_crypt

# Force disconnect NBD
sudo qemu-nbd --disconnect /dev/nbd0

# If still stuck, check kernel modules
sudo lsmod | grep nbd
```
</details>

<details>
<summary><strong>La VM non parte più dopo il ridimensionamento</strong></summary>

**Problema**: errori di GRUB o kernel panic

**Soluzione**:
```bash
# Boot with installation ISO
qemu-system-x86_64 \
  -drive file=ubuntu.iso,media=cdrom \
  -boot d \
  -drive file=Ubuntu.vhd,format=raw,if=virtio \
  -m 4G -enable-kvm

# In live environment:
# 1. Open LUKS
sudo cryptsetup luksOpen /dev/vda3 crypt

# 2. Mount root
sudo mount /dev/mapper/vgubuntu-root /mnt

# 3. Mount boot
sudo mount /dev/vda2 /mnt/boot

# 4. Mount EFI
sudo mount /dev/vda1 /mnt/boot/efi

# 5. Chroot
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo chroot /mnt

# 6. Reinstall GRUB
update-grub
grub-install /dev/vda

# 7. Exit and reboot
exit
sudo reboot
```
</details>

## ⚠️ Avvertenze fondamentali

{{< callout type="danger" >}}
**Prima di cominciare:**

1. **Spegni del tutto la VM** - mai ridimensionare con la VM accesa
2. **Fai il backup dell'immagine del disco** - `cp Ubuntu.vhd Ubuntu.vhd.backup`
3. **Fai il backup dell'header LUKS** - header corrotto = dati persi per sempre
4. **Prova prima con uno snapshot** - usa l'opzione `-snapshot` di QEMU
5. **Tieni a portata la password** - ti serve per aprire LUKS
6. **Controlla il numero della partizione** - di solito è p3, ma verificalo prima
7. **Verifica i nomi di VG e LV** - cambiano da una distribuzione all'altra

**L'ordine conta**: Disco → Partizione → LUKS → PV → LV → Filesystem
{{< /callout >}}

## 📊 Riepilogo della sequenza dei comandi

```bash
# EXPAND LAYERS (in order)
qemu-img resize                    # 1. Disk image
parted resizepart                  # 2. Partition
cryptsetup resize                  # 3. LUKS container
pvresize                           # 4. Physical Volume
lvextend                           # 5. Logical Volume
resize2fs                          # 6. Filesystem

# CLEANUP (reverse order)
lvchange -an                       # 6. Deactivate LVs
vgchange -an                       # 5. Deactivate VG
cryptsetup luksClose               # 4. Close LUKS
qemu-nbd --disconnect              # 3. Disconnect NBD
```

## 🎯 Scenari comuni

### Ubuntu con cifratura dell'intero disco

```bash
# Standard Ubuntu encrypted install layout
# Partition 1: EFI (512MB)
# Partition 2: /boot (1GB)
# Partition 3: LUKS + LVM (everything else)

# Resize to 200GB
qemu-img resize -f raw ubuntu.img 200G
# ... follow main process with partition 3
```

### Installazione cifrata di Debian

```bash
# Similar to Ubuntu
# Usually partition 5 is LUKS in Debian

qemu-img resize -f raw debian.img 150G
# Use partition 5 instead of 3
sudo cryptsetup luksOpen /dev/nbd0p5 crypt
```

### Fedora/RHEL cifrate

```bash
# Fedora uses different VG names
# Volume Group: fedora (not vgubuntu)
# Root LV: root
# Swap LV: swap

sudo lvextend -l +100%FREE /dev/fedora/root
sudo xfs_growfs /dev/fedora/root  # Fedora uses XFS
```

## 📈 Dimensioni consigliate

| Tipo di VM | Partizione root | Swap | Disco totale |
|---------|---------------|------|------------|
| Server minimale | 20GB | 2GB | 25GB |
| Desktop | 50GB | 4GB | 60GB |
| Sviluppo | 100GB | 8GB | 120GB |
| Workstation completa | 200GB+ | 16GB | 250GB+ |

---

*Allarga in sicurezza le tue macchine virtuali cifrate!*
