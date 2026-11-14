---
title: "LVM RAID Management Guide (Debian/Ubuntu)"
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

# LVM RAID Management Guide (Debian/Ubuntu)

## Introduction

Logical Volume Management (LVM) is a flexible storage management system that abstracts physical disks into logical volumes, allowing dynamic resizing, snapshots, and RAID configurations. LVM RAID integrates Linux software RAID (mdadm) with LVM to provide redundancy and flexibility. This guide explains how to create, modify, and manage an LVM setup with RAID on Debian/Ubuntu systems, covering volume group creation, logical volume setup with RAID, and maintenance tasks.

LVM RAID is ideal for environments needing redundancy (e.g., RAID-1, RAID-5) combined with LVM's dynamic resizing and snapshot capabilities.

## What is LVM RAID?

LVM RAID uses the kernel's MD RAID code through device mapper (`dm-raid`), on top of LVM physical volumes (PVs), which are grouped into volume groups (VGs). Logical volumes (LVs) are then created with RAID levels for redundancy:
- **RAID-1**: Mirroring (data duplicated across disks).
- **RAID-5**: Striping with parity (requires 3+ disks).
- **RAID-6**: Striping with double parity (requires 5+ disks: at least 3 data stripes).
- **Snapshots**: Point-in-time copies of LVs for backups.
- **Resizing**: Dynamically grow or shrink LVs and VGs.

LVM RAID combines RAID redundancy with LVM's logical abstraction, and is managed with the `lvm` commands only: **`mdadm` is not needed**, and LVM RAID volumes do not appear in `/proc/mdstat` (both checked on Ubuntu 24.04: with an active LVM RAID1 and no mdadm installed, `/proc/mdstat` lists the personalities and no arrays).

## Prerequisites

- **Debian/Ubuntu**: Debian 11+ or Ubuntu 20.04+.
- **LVM2 Installed**: The `lvm2` package is all you need.
- **Disks**: Unused physical disks (e.g., `/dev/sdb`, `/dev/sdc`). **Warning**: LVM and RAID operations wipe disks—back up data first.
- **Root Access**: Commands require `sudo`.
- **Hardware**: Multiple disks for RAID (2 for RAID-1, 3+ for RAID-5, 5+ for RAID-6).

Install dependencies on Debian/Ubuntu:
```bash
sudo apt update
sudo apt install lvm2
# Load LVM kernel modules
sudo modprobe dm-mod
sudo modprobe dm-raid
```

Verify installation:
```bash
lvm version  # Check LVM version
lsblk  # List disks
```

## Critical Warning: Verify Disks Before Operations

{{< callout type="warning" >}}
**Extreme Caution**: Before creating LVM physical volumes or RAID arrays, use `lsblk` or `fdisk -l` to verify you are selecting the correct disks (e.g., `/dev/sdb`, `/dev/sdc`). Operations like creating physical volumes or RAID arrays will erase all data on the selected disks. Always double-check the disk layout and back up critical data before proceeding.
{{< /callout >}}

## How to Use LVM RAID

### 1. Create an LVM RAID Setup
LVM RAID involves creating physical volumes (PVs), a volume group (VG), and a logical volume (LV) with a specified RAID level.

#### Step-by-Step Creation
1. **Prepare Disks**:
   ```bash
   lsblk  # Identify disks (e.g., sdb, sdc, sdd)
   ```

2. **Create Physical Volumes**:
   ```bash
   sudo pvcreate /dev/sdb /dev/sdc /dev/sdd
   pvdisplay  # Verify PVs
   ```

3. **Create Volume Group**:
   ```bash
   sudo vgcreate myvg /dev/sdb /dev/sdc /dev/sdd
   vgdisplay  # Verify VG
   ```

4. **Create Logical Volume with RAID**:
   - **RAID-1 (Mirror, 2 disks)**:
     ```bash
     sudo lvcreate --type raid1 -m 1 -L 10G -n mylv myvg
     ```
   - **RAID-5 (3+ disks, single parity)**:
     ```bash
     sudo lvcreate --type raid5 -i 2 -L 10G -n mylv myvg
     ```
   - **RAID-6 (5+ disks, double parity)**:
     ```bash
     sudo lvcreate --type raid6 -i 3 -L 10G -n mylv myvg
     ```

   Parameters:
   - `-m 1`: 1 mirror copy (RAID-1).
   - `-i 2` / `-i 3`: number of data stripes (disks minus parity). RAID-6 needs at least 3: `lvcreate --type raid6 -i 2` fails with `Minimum of 3 stripes required for raid6`.
   - `-L 10G`: Size of the logical volume.
   - `-n mylv`: Name of the logical volume.

5. **Format and Mount**:
   ```bash
   sudo mkfs.ext4 /dev/myvg/mylv
   sudo mkdir /mnt/mylv
   sudo mount /dev/myvg/mylv /mnt/mylv
   df -h /mnt/mylv  # Verify mount
   ```

### 2. Modify an LVM RAID Setup
Modify the VG or LV for expansion, reduction, or disk replacement.

- **Extend Volume Group** (Add Disks):
  ```bash
  sudo pvcreate /dev/sde
  sudo vgextend myvg /dev/sde
  vgdisplay  # Check new capacity
  ```

- **Extend Logical Volume**:
  ```bash
  sudo lvextend -L +10G /dev/myvg/mylv
  sudo resize2fs /dev/myvg/mylv  # Resize filesystem (ext4)
  ```

- **Replace Failed Disk**:
  ```bash
  sudo lvs -a -o name,devices,lv_health_status myvg  # failed leg: [unknown], partial
  sudo pvcreate /dev/sdf               # a new disk, if the VG has no free one
  sudo vgextend myvg /dev/sdf
  sudo lvconvert --repair myvg/mylv    # rebuild the failed leg on a free PV
  sudo vgreduce --removemissing myvg   # drop the dead disk from the VG
  ```

- **Convert RAID Level** (e.g., RAID-1 to RAID-5):
  ```bash
  sudo lvconvert --type raid5 /dev/myvg/mylv      # raid1 (2 legs) -> raid5 on 2 devices
  sudo lvconvert --stripes 2 /dev/myvg/mylv       # reshape to 2 data stripes (3 devices)
  sudo lvs -o name,segtype,stripes,sync_percent myvg
  ```

### 3. Manage an LVM RAID Setup
Monitor, repair, and manage the RAID array and LVM components.

- **Check Status**:
  ```bash
  sudo lvs -o+raid_sync_action  # Check LV status and sync
  sudo lvs -a -o name,segtype,devices,sync_percent,lv_health_status myvg
  ```

- **Create Snapshot**:
  ```bash
  sudo lvcreate --snapshot -L 2G -n mysnap /dev/myvg/mylv
  sudo mount /dev/myvg/mysnap /mnt/snapshot
  ```

- **Remove Logical Volume or Volume Group** (Destructive!):
  ```bash
  sudo umount /mnt/mylv
  sudo lvremove /dev/myvg/mylv
  sudo vgremove myvg
  sudo pvremove /dev/sdb /dev/sdc /dev/sdd
  ```

- **Activate/Deactivate VG**:
  ```bash
  sudo vgchange -a n myvg  # Deactivate
  sudo vgchange -a y myvg  # Activate
  ```

### 4. Configure Filesystem Properties
Set mount options or quotas:
```bash
sudo tune2fs -m 5 /dev/myvg/mylv  # Reserve 5% for root (ext4)
sudo mount -o remount,ro /mnt/mylv  # Remount read-only
```

## Examples

### Example 1: Create and Use a RAID-1 Logical Volume
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

### Example 2: Extend and Replace Disk
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

### Example 3: Create and Restore Snapshot
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

## Proof: a Disk Dies

Tested on 2026-11-14 on an Ubuntu 24.04 VM with five 2 GB disks and no `mdadm` installed. A RAID-1 LV was created, formatted, mounted and filled with a file; then one of its disks was hot-unplugged from the running VM.

- `lvs -a -o name,devices,lv_health_status` reported the LV as `partial`, with the dead leg on `[unknown]`. The file stayed readable, and writable.
- `vgreduce myvg /dev/sdb` (the old instruction of this guide) refused: `Cannot process volume group myvg`.
- `lvconvert --repair myvg/mylv` answered `Faulty devices in myvg/mylv successfully replaced.`, rebuilding the leg on a free disk of the VG; `vgreduce --removemissing myvg` dropped the dead disk. A few seconds later `Cpy%Sync` was `100.00` and the file was intact.
- The RAID-1 to RAID-5 conversion of section 2 was run on the same LV: `lvconvert --type raid5 -i 2` warns `--stripes not allowed ... when converting from raid1 to raid5` and produces a 2-device RAID-5; the second command, `--stripes 2`, reshapes it to 3 devices and grows the LV. The file survived both.

## Command Breakdown

- **pvcreate**: Initializes disks as physical volumes.
- **vgcreate/vgextend/vgreduce**: Manages volume groups.
- **`lvcreate --type raid*`**: Creates LVs with RAID levels.
- **lvextend/resize2fs**: Expands LVs and filesystems.
- **lvconvert**: Changes RAID levels or merges snapshots.
- **lvs**: Monitors LVs, RAID sync and health (`lvs -a -o+sync_percent,lv_health_status`).

Common RAID Levels: `raid1` (mirror), `raid5` (single parity), `raid6` (double parity).

## Use Cases
- **Server Storage**: RAID-5/6 for data redundancy with LVM flexibility.
- **Backup Systems**: Snapshots for consistent backups.
- **Virtualization**: Thin-provisioned LVs for VM disks.
- **Dynamic Storage**: Resize volumes without downtime.

## Pro Tips
- **Disk Prep**: Use whole disks or partitions, but verify with `lsblk`.
- **RAID Sync Monitoring**: Use `watch sudo lvs -o name,sync_percent,raid_sync_action` during resync.
- **Snapshots**: Allocate enough space (e.g., 10-20% of LV) for changes.
- **Automate Backups**: Schedule snapshots with cron:
  ```bash
  # root's crontab (sudo crontab -e): % must be written \% in a crontab line
  0 0 * * * /usr/sbin/lvcreate --snapshot -L 2G -n mysnap-$(date +\%Y\%m\%d) /dev/myvg/mylv
  ```
- **Combine with LUKS**: Encrypt PVs before LVM:
  ```bash
  cryptsetup luksFormat /dev/sdb
  cryptsetup luksOpen /dev/sdb cryptdisk
  pvcreate /dev/mapper/cryptdisk
  ```

{{< callout type="tip" >}}
**Tip**: Use `lvs -o+seg_pe_ranges` to check physical extent allocation for performance tuning.
{{< /callout >}}

## Troubleshooting
- **"Device not found"**: Verify disks with `lsblk` or `fdisk -l`.
- **RAID Sync Slow**: Monitor with `lvs -o+sync_percent`; schedule during low I/O.
- **Snapshot Overflow**: Increase snapshot size or reduce changes.
- **VG Not Found**: Activate with `vgchange -a y`.
- **Permission Issues**: Run as root; check `dm-mod` and `dm-raid` modules (`lsmod`).
- **Failed Disk**: `lvs -a -o+lv_health_status` shows `partial` and the dead leg as `[unknown]`; the data stays readable. Repair with `lvconvert --repair` and `vgreduce --removemissing`, as in the example above. A plain `vgreduce myvg /dev/sdb` refuses (`Cannot process volume group`), and there is no `lvsync` command.

## Next Steps
In future tutorials, we'll explore:
- Advanced LVM snapshots and thin provisioning.
- LVM cache for performance.
- Integrating LVM with backup tools like `rsync`.

## Resources
- [LVM Documentation](https://www.sourceware.org/lvm2/)
- [Ubuntu LVM Guide](https://wiki.ubuntu.com/LVM)
- [lvmraid(7) Man Page](https://man7.org/linux/man-pages/man7/lvmraid.7.html)

---

*Experiment with LVM RAID on spare disks to build flexible, redundant storage—start with RAID-1 for simplicity!*