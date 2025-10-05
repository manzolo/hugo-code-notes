---
title: "QEMU/VirtualBox Disk Resize"
date: 2025-10-05T16:30:00+02:00
draft: false
author: "Manzolo"
tags: ["linux", "qemu", "virtualbox", "virtualization", "disk", "quick-pill"]
categories: ["linux", "quick-pills"]
series: ["Quick Pills"]
weight: 5
ShowToc: false
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "Quick guide to resize QEMU/VirtualBox virtual disks and expand partitions"
---

# 💊 Quick Pill: QEMU/VirtualBox Disk Resize

{{< callout type="info" >}}
**Use case**: Expand virtual machine disk when running out of space. Works with QEMU raw images, VirtualBox VDI/VHD, and similar formats.
{{< /callout >}}

## 🚀 Complete Resize Process

{{< callout type="warning" >}}
**⚠️ Critical**: Always backup your VM disk before resizing!
{{< /callout >}}

### Step-by-Step Guide

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

**Inside parted:**
```
(parted) print                    # Show current partitions
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

## 📋 Understanding Each Step

### 1. Resize Disk Image

```bash
qemu-img resize -f raw Ubuntu.vhd 200G
```

**What it does:**
- `-f raw`: Specifies format (raw, qcow2, vdi, vhd, vmdk)
- `Ubuntu.vhd`: Your disk image file
- `200G`: New total size (not added space!)

**Size formats:**
- `200G`: Set to 200GB total
- `+50G`: Add 50GB to current size
- `+10240M`: Add 10GB (in megabytes)

### 2. Connect as Block Device

```bash
sudo modprobe nbd
sudo qemu-nbd --connect=/dev/nbd0 -f raw Ubuntu.vhd
```

**What it does:**
- `nbd`: Network Block Device module
- `/dev/nbd0`: First NBD device (use nbd1, nbd2 if busy)
- Mounts disk image as if it were a physical disk

### 3. Resize Partition

```bash
sudo parted /dev/nbd0
(parted) resizepart 2 100%
```

**What it does:**
- `resizepart 2`: Resize partition number 2
- `100%`: Use all available space
- **Note**: Adjust partition number if different!

### 4. Resize Filesystem

```bash
sudo resize2fs /dev/nbd0p2
```

**What it does:**
- Expands ext4/ext3 filesystem to fill partition
- `p2` = partition 2 (match with resizepart!)
- Automatic: detects new size from partition

## 💡 Pro Tips

<details>
<summary><strong>Work with different disk formats</strong></summary>

### QCOW2 (QEMU native format)
```bash
# Resize
qemu-img resize -f qcow2 disk.qcow2 +50G

# Connect
sudo qemu-nbd --connect=/dev/nbd0 -f qcow2 disk.qcow2
```

### VirtualBox VDI
```bash
# Resize using VBoxManage
VBoxManage modifymedium disk Ubuntu.vdi --resize 204800  # Size in MB

# Or convert to raw first, then resize
qemu-img convert -f vdi -O raw Ubuntu.vdi Ubuntu.raw
qemu-img resize Ubuntu.raw 200G
```

### VMDK (VMware)
```bash
# Resize VMDK
qemu-img resize -f vmdk disk.vmdk 200G

# Connect
sudo qemu-nbd --connect=/dev/nbd0 -f vmdk disk.vmdk
```
</details>

<details>
<summary><strong>Check partition layout first</strong></summary>

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
<summary><strong>Resize XFS filesystem instead of ext4</strong></summary>

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
<summary><strong>Resize LVM volumes</strong></summary>

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
<summary><strong>Add space incrementally</strong></summary>

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
<summary><strong>Multiple NBD devices in use</strong></summary>

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
<summary><strong>Create complete resize script</strong></summary>

Save as `resize_vm_disk.sh`:

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

**Usage:**
```bash
chmod +x resize_vm_disk.sh
sudo ./resize_vm_disk.sh Ubuntu.vhd 200G 2
```
</details>

<details>
<summary><strong>Shrink disk (advanced, risky)</strong></summary>

{{< callout type="danger" >}}
**Warning**: Shrinking is dangerous and can cause data loss!
{{< /callout >}}

```bash
# 1. Connect disk
sudo qemu-nbd --connect=/dev/nbd0 -f raw Ubuntu.vhd

# 2. Check filesystem usage
sudo e2fsck -f /dev/nbd0p2
sudo resize2fs /dev/nbd0p2 150G  # Shrink filesystem first!

# 3. Shrink partition
sudo parted /dev/nbd0
(parted) resizepart 2 150GB
(parted) quit

# 4. Disconnect
sudo qemu-nbd --disconnect /dev/nbd0

# 5. Shrink image (only for raw/qcow2)
qemu-img resize --shrink -f raw Ubuntu.vhd 160G

# Note: Always leave some extra space!
```
</details>

## 🔍 Troubleshooting

<details>
<summary><strong>NBD module not found</strong></summary>

**Problem**: `modprobe: FATAL: Module nbd not found`

**Solution**:
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

**Problem**: Cannot connect to /dev/nbd0

**Solution**:
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
<summary><strong>Partition not found after resize</strong></summary>

**Problem**: `/dev/nbd0p2` doesn't exist

**Solution**:
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
<summary><strong>Filesystem still shows old size in VM</strong></summary>

**Problem**: VM shows old disk size after resize

**Solution**:
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
<summary><strong>Cannot resize: filesystem has errors</strong></summary>

**Problem**: `resize2fs: filesystem has errors`

**Solution**:
```bash
# Check and repair filesystem first
sudo e2fsck -f -y /dev/nbd0p2

# Then resize
sudo resize2fs /dev/nbd0p2
```
</details>

<details>
<summary><strong>VirtualBox disk resize fails</strong></summary>

**Problem**: VBoxManage resize not working

**Solution**:
```bash
# Convert to raw format first
VBoxManage clonehd Ubuntu.vdi Ubuntu.vhd --format VHD

# Resize using qemu-img
qemu-img resize Ubuntu.vhd 200G

# Follow NBD process above

# Or use VBoxManage with correct UUID
VBoxManage showhdinfo Ubuntu.vdi  # Get UUID
VBoxManage modifymedium disk <UUID> --resize 204800
```
</details>

## 📊 Supported Formats

| Format | Command | Notes |
|--------|---------|-------|
| RAW | `qemu-img resize -f raw disk.raw 200G` | Fastest, largest file |
| QCOW2 | `qemu-img resize -f qcow2 disk.qcow2 +50G` | QEMU native, dynamic |
| VDI | `VBoxManage modifymedium disk.vdi --resize 204800` | VirtualBox (size in MB) |
| VHD | `qemu-img resize -f vpc disk.vhd 200G` | Hyper-V/VirtualBox |
| VMDK | `qemu-img resize -f vmdk disk.vmdk 200G` | VMware |

## ⚠️ Important Warnings

{{< callout type="danger" >}}
**Before Resizing:**

1. **Shutdown the VM completely** - never resize while running
2. **Backup the disk image** - copy to safe location
3. **Test in snapshot/copy first** if possible
4. **Verify format** with `qemu-img info disk.img`
5. **Check free space** on host (need room for larger file)
6. **Remember**: Shrinking is dangerous, expanding is safe
{{< /callout >}}

## 🎯 Common Scenarios

### Expand Ubuntu VM

```bash
# Typical Ubuntu setup: partition 2 is root
qemu-img resize -f raw Ubuntu.vhd 200G
sudo modprobe nbd
sudo qemu-nbd --connect=/dev/nbd0 -f raw Ubuntu.vhd
sudo parted /dev/nbd0 resizepart 2 100%
sudo resize2fs /dev/nbd0p2
sudo qemu-nbd --disconnect /dev/nbd0
```

### Expand Windows VM (NTFS)

```bash
# Windows needs ntfsresize instead of resize2fs
qemu-img resize -f raw Windows.vhd 300G
sudo modprobe nbd
sudo qemu-nbd --connect=/dev/nbd0 -f raw Windows.vhd
sudo parted /dev/nbd0 resizepart 2 100%
sudo ntfsresize -f /dev/nbd0p2  # For NTFS
sudo qemu-nbd --disconnect /dev/nbd0
```

### Quick Check Without Resizing

```bash
# Just inspect disk
sudo modprobe nbd
sudo qemu-nbd --connect=/dev/nbd0 -f raw Ubuntu.vhd
sudo parted /dev/nbd0 print
sudo fdisk -l /dev/nbd0
df -h  # Won't show until mounted
sudo qemu-nbd --disconnect /dev/nbd0
```

## 📈 Size Planning Guide

| VM Purpose | Recommended Size | Resize When |
|------------|-----------------|-------------|
| Testing/Dev | 20-50GB | Below 5GB free |
| Desktop VM | 50-100GB | Below 10GB free |
| Server | 100-500GB | Below 20GB free |
| Production | 500GB+ | Below 10% free |

## 🚀 Quick Reference Commands

```bash
# 1. RESIZE IMAGE
qemu-img resize -f raw disk.vhd +50G

# 2. CONNECT
sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 -f raw disk.vhd

# 3. RESIZE PARTITION (interactive)
sudo parted /dev/nbd0
> resizepart 2 100%
> quit

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

## 🔄 Alternative: Resize from Inside VM

If NBD doesn't work, resize from within the VM:

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

*Expand your virtual machines without the hassle!*