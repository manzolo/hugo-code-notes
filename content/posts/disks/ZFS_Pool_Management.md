---
title: "ZFS Pool Management Guide (Debian/Ubuntu)"
date: 2025-10-03T10:00:00+02:00
lastmod: 2025-10-04T11:35:00+02:00
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

# ZFS Pool Management Guide (Debian/Ubuntu)

## Introduction

ZFS (Zettabyte File System) is an advanced filesystem and volume manager for large storage pools, offering snapshots, compression, and redundancy (e.g., mirror, RAID-Z). This guide shows how to initialize disks with GPT, create a ZFS pool, use stable device identifiers (`/dev/disk/by-id/` or `/dev/disk/by-partuuid/`), support various RAID types (mirror, RAID-Z1, RAID-Z2), and mount datasets for normal user access on Debian/Ubuntu.

## ⚡ Quick Start

{{< callout type="info" >}}
**New to ZFS? Start here:**
1. [Install prerequisites](#prerequisites)
2. [Identify your disks](#identifying-available-disks)
3. **Choose your method:**
   - Physical disks? → [Whole Disks with by-id](#method-a-with-devdiskby-id-physical-disks)
   - Virtual disks (VM)? → [Whole Disks without by-id](#method-b-without-devdiskby-id-virtual-disks)
   - Need partitions? → [Manual Partitions](#alternative-approach-manual-partitions-with-by-partuuid)
4. [Create mirror pool](#creating-the-pool-whole-disks) (most common setup)
5. [Create and manage datasets](#creating-and-managing-datasets)

**Need to fix something?** → [Replace a failed disk](#replace-a-failed-disk)
{{< /callout >}}

## What is a ZFS Pool?

A ZFS pool is a collection of virtual devices (vdevs) forming the foundation for ZFS datasets (filesystems) and zvols (block devices). Pools support:

- **Redundancy**: Mirror (RAID-1), RAID-Z1/2/3 (like RAID-5/6/7).
- **Expansion**: Add vdevs to increase capacity (cannot remove easily).
- **Health Monitoring**: Scrubbing and checksums for data integrity.
- **Snapshots/Clones**: Point-in-time copies without full duplication.

Pools are created with `zpool create` and managed via `zpool` commands. Data is stored in datasets (e.g., `tank/home`).

## 🔑 Understanding UUIDs in ZFS

{{< callout type="warning" >}}
**Critical Concept**: Understanding the difference between Pool UUID and Device Identifiers is essential for proper ZFS management.
{{< /callout >}}

### Pool UUID vs Device Identifiers

#### Pool UUID
- **Example**: `150809157285762621`
- Shown as `UUID="..."` with `TYPE="zfs_member"` in `blkid` output
- **Shared by ALL disks/partitions** that are members of the same pool
- **Not used directly** in zpool commands

#### Device Identifiers (for referencing individual disks/partitions)

**`/dev/disk/by-id/`** - Persistent identifier based on disk serial number
- ✅ **Best for whole disks** 
- Example: `ata-Samsung_SSD_850_S21NX0AG123456`
- Survives disk reordering and system reboots

**`/dev/disk/by-partuuid/`** - GPT partition UUID
- ✅ **Best for manual partitions**
- Example: `ee2507fe-0b11-ad4c-b1c5-87e36055410e`
- Each partition has its own unique PARTUUID

**`/dev/vdb`, `/dev/sda`** - Kernel device names
- ⚠️ **Unreliable** - can change on reboot or disk reordering
- Use only for initial pool creation, then switch to persistent identifiers

### Decision Matrix: Which Identifier to Use?

| Scenario | Recommended Identifier | Example |
|----------|------------------------|---------|
| Whole disk to ZFS | `/dev/disk/by-id/` | `ata-WDC_WD40EFRX-68N32N0_WD-1234` |
| Manual partition to ZFS | `/dev/disk/by-partuuid/` | `ee2507fe-0b11-ad4c-b1c5-87e36055410e` |
| Initial pool creation only | `/dev/vdb`, `/dev/sda` | Transition immediately after |

## Prerequisites

{{< callout type="info" >}}
**Required**:
- Debian/Ubuntu 20.04+
- Root access (`sudo`)
- Unused disks (e.g., `/dev/vdb`, `/dev/vdc`)
{{< /callout >}}

{{< callout type="warning" >}}
**⚠️ Data Loss Warning**: ZFS will erase all data on selected disks. Back up critical data first!
{{< /callout >}}

### Installation

```bash
sudo apt update
sudo apt install zfsutils-linux parted
sudo modprobe zfs
```

### Verify Installation

```bash
zpool status  # No pools initially
zfs list      # Empty initially
```

## Identifying Available Disks

### 1. List All Block Devices

```bash
# Show all disks and their mount status
lsblk
```

**Example output**:
```
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   20G  0 disk 
└─sda1   8:1    0   20G  0 part /
sr0     11:0    1 1024M  0 rom  
vdb    252:16   0   10G  0 disk 
vdc    252:32   0   10G  0 disk 
```

In this example, `vdb` and `vdc` are available disks without partitions.

### 2. Check Disk Identifiers

```bash
# Try to list persistent IDs
ls -l /dev/disk/by-id/ | grep -v part
```

{{< callout type="info" >}}
**Important**: For brand new virtual disks (like `/dev/vdb`, `/dev/vdc`), `/dev/disk/by-id/` might not show them because:
- Virtual disks (QEMU/VirtIO) often don't have hardware serial numbers
- Disks without partition tables may not appear in by-id
{{< /callout >}}

**What you might see**:
```bash
# Only DVD/CD-ROM visible, no data disks
lrwxrwxrwx 1 root root 9 ott  4 11:50 ata-QEMU_DVD-ROM_QM00001 -> ../../sr0
```

### 3. Verify Disks Are Empty

```bash
# Check if disks have any filesystem or partition table
sudo blkid /dev/vdb /dev/vdc

# If empty, no output or "no such device"
```

```bash
# Alternative check with wipefs
sudo wipefs /dev/vdb /dev/vdc
```

## 🚀 Recommended Approach: Whole Disks

{{< callout type="success" >}}
**Best Practice**: Using whole disks is the recommended approach for most ZFS installations. ZFS automatically creates optimal partition layouts.
{{< /callout >}}

### Method A: With /dev/disk/by-id/ (Physical Disks)

{{< callout type="info" >}}
**Use this method if**: You have physical SATA/SAS disks that appear in `/dev/disk/by-id/`
{{< /callout >}}

If your disks appear in `/dev/disk/by-id/` (typical for physical SATA/SAS disks):

```bash
# List available disk IDs
ls -l /dev/disk/by-id/ | grep -v part

# Example output for physical disks:
# ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567 -> ../../sdb
# ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7654321 -> ../../sdc
```

Use these IDs directly in pool creation.

### Method B: Without /dev/disk/by-id/ (Virtual Disks)

{{< callout type="info" >}}
**Use this method if**: You have virtual disks (VMs) like `/dev/vdb`, `/dev/vdc` that don't appear in `/dev/disk/by-id/`
{{< /callout >}}

**Option 1: Create pool with device names** (Recommended for VMs)

ZFS automatically creates a GPT partition table when you use a whole disk.

```bash
# Create pool with device names
sudo zpool create tank mirror /dev/vdb /dev/vdc

# After creation, check what ZFS created:
sudo blkid | grep zfs_member
ls -l /dev/disk/by-id/ | grep -v dvd
```

<details>
<summary><strong>Option 2: Use VirtIO IDs if available</strong></summary>

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

### Creating the Pool (Whole Disks)

ZFS will automatically create a GPT partition table and use the entire disk.

#### With Physical Disks (using by-id)

**Mirror (RAID-1, 2 disks)** - Recommended for most users
```bash
sudo zpool create tank mirror \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7654321
```

<details>
<summary><strong>RAID-Z1 (3+ disks, 1 disk failure tolerance)</strong></summary>

```bash
sudo zpool create tank raidz \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7654321 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K9876543
```
</details>

<details>
<summary><strong>RAID-Z2 (4+ disks, 2 disk failure tolerance)</strong></summary>

```bash
sudo zpool create tank raidz2 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7654321 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K9876543 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1111111
```
</details>

#### With Virtual Disks (using device names)

**Mirror (RAID-1, 2 disks)** - Most common for VMs
```bash
# ZFS creates GPT automatically
sudo zpool create tank mirror /dev/vdb /dev/vdc
```

<details>
<summary><strong>RAID-Z1 (3+ disks)</strong></summary>

```bash
sudo zpool create tank raidz /dev/vdb /dev/vdc /dev/vdd
```
</details>

<details>
<summary><strong>RAID-Z2 (4+ disks)</strong></summary>

```bash
sudo zpool create tank raidz2 /dev/vdb /dev/vdc /dev/vdd /dev/vde
```
</details>

### Verify Pool Status

```bash
zpool status tank
```

**Example output (physical disks with by-id)**:
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

**Example output (virtual disks)**:
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

### Understanding What ZFS Created

After creating a pool with whole disks, check what ZFS automatically created:

```bash
# Show partition table ZFS created
sudo blkid | grep zfs_member
```

**Example output (virtual disks)**:
```
/dev/vdb: UUID="150809157285762621" UUID_SUB="4234567890123456789" TYPE="zfs_member" PTTYPE="gpt"
/dev/vdc: UUID="150809157285762621" UUID_SUB="9876543210987654321" TYPE="zfs_member" PTTYPE="gpt"
```

Or with partitions:
```
/dev/vdb1: UUID="150809157285762621" TYPE="zfs_member" PARTUUID="ee2507fe-0b11-ad4c-b1c5-87e36055410e"
/dev/vdc1: UUID="150809157285762621" TYPE="zfs_member" PARTUUID="c074a830-4f67-a24d-b028-7cefbe64a690"
```

```bash
# Check partition layout
lsblk
```

**What ZFS created**:
- **Partition 1** (`vdb1`, `vdc1`): Main ZFS partition with your data
- **Partition 9** (`vdb9`, `vdc9`): Small 8MB partition for ZFS reserved area
- **GPT** (`PTTYPE="gpt"`): GUID Partition Table
- **Pool UUID**: Same for all pool members (`150809157285762621`)
- **PARTUUID**: Unique for each partition (if created)

## Alternative Approach: Manual Partitions with by-partuuid

{{< callout type="warning" >}}
**Use this approach only if you need to:**
- Share a disk with other filesystems (dual-boot)
- Create custom partition layouts
- Use only part of a disk for ZFS
{{< /callout >}}

<details>
<summary><strong>Expand for manual partition instructions</strong></summary>

### 1. Create GPT Partitions

```bash
# Initialize disk with GPT
sudo parted /dev/vdb mklabel gpt
sudo parted /dev/vdb mkpart primary 0% 100%

sudo parted /dev/vdc mklabel gpt
sudo parted /dev/vdc mkpart primary 0% 100%
```

### 2. Find PARTUUIDs

```bash
# List partition UUIDs
ls -l /dev/disk/by-partuuid/

# Or use blkid
sudo blkid /dev/vdb1 /dev/vdc1
```

Example output:
```
/dev/vdb1: PARTUUID="ee2507fe-0b11-ad4c-b1c5-87e36055410e"
/dev/vdc1: PARTUUID="c074a830-4f67-a24d-b028-7cefbe64a690"
```

### 3. Create Pool with Partitions

```bash
sudo zpool create tank mirror \
  /dev/disk/by-partuuid/ee2507fe-0b11-ad4c-b1c5-87e36055410e \
  /dev/disk/by-partuuid/c074a830-4f67-a24d-b028-7cefbe64a690
```

Or transition from device names:

```bash
# Create with device names
sudo zpool create -f tank mirror /dev/vdb1 /dev/vdc1

# Export and re-import with PARTUUIDs
sudo zpool export tank
sudo zpool import -d /dev/disk/by-partuuid tank
```

### 4. Verify PARTUUID Usage

```bash
zpool status tank
```

Example output:
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

## 💾 Creating and Managing Datasets

### Create and Mount Dataset

```bash
# Create dataset
sudo zfs create tank/data

# Set mountpoint
sudo zfs set mountpoint=/mnt/tank tank/data

# Enable compression (recommended)
sudo zfs set compression=lz4 tank/data
```

### Set Permissions for Normal User

```bash
# Change ownership to your user
sudo chown manzolo:manzolo /mnt/tank
sudo chmod 775 /mnt/tank
```

### Write Data as Normal User

```bash
# Now you can write without sudo
echo "Test data" > /mnt/tank/test.txt
cat /mnt/tank/test.txt
```

### Verify Dataset

```bash
zfs list
df -h /mnt/tank
```

## 🔧 Pool Modification Operations

### Add Devices to Expand Pool

<details>
<summary><strong>Add Mirror Vdev (whole disks)</strong></summary>

```bash
sudo zpool add tank mirror \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K3333333 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K4444444
```
</details>

<details>
<summary><strong>Add RAID-Z1 Vdev (whole disks)</strong></summary>

```bash
sudo zpool add tank raidz \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K5555555 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K6666666 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7777777
```
</details>

<details>
<summary><strong>Add Mirror with Partitions</strong></summary>

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

### Replace a Failed Disk

{{< callout type="warning" >}}
**Important**: The replacement procedure depends on how the pool was created (whole disks vs partitions).
{{< /callout >}}

#### For Pools Created with Whole Disks (by-id)

1. **Check pool status to identify failed disk**:
```bash
zpool status tank
```

Example output showing failure:
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

2. **Replace the failed disk**:
```bash
sudo zpool replace tank \
  ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K9999999
```

3. **Monitor resilvering**:
```bash
zpool status tank
```

<details>
<summary><strong>For Pools Created with Partitions (by-partuuid)</strong></summary>

1. **Check pool status**:
```bash
zpool status tank
```

2. **Create partition on replacement disk**:
```bash
sudo parted /dev/vdg mklabel gpt
sudo parted /dev/vdg mkpart primary 0% 100%
```

3. **Replace using PARTUUID**:
```bash
sudo zpool replace tank \
  ee2507fe-0b11-ad4c-b1c5-87e36055410e \
  /dev/disk/by-partuuid/[new-partuuid-of-vdg1]
```

4. **Monitor resilvering**:
```bash
zpool status tank
```
</details>

### Attach Device to Mirror

<details>
<summary><strong>Convert single disk to mirror or expand existing mirror</strong></summary>

#### Whole Disk Approach
```bash
# Attach new disk to existing single disk (converts to mirror)
sudo zpool attach tank \
  ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567 \
  /dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K8888888
```

#### Partition Approach
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

## 🔍 Pool Maintenance

### Check Pool Status
```bash
zpool status tank
zpool list tank
```

### Scrub Pool (Verify Data Integrity)
```bash
# Start scrub
sudo zpool scrub tank

# Monitor progress
zpool status tank
```

### Export and Import Pool

<details>
<summary><strong>Useful for moving pools between systems or maintenance</strong></summary>

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

## 📋 Complete Examples

### Example 1: Mirror with Virtual Disks (Most Common for VMs)

{{< callout type="success" >}}
**Recommended for**: VM environments, home labs
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
<summary><strong>Example 2: Mirror with Physical Disks (by-id)</strong></summary>

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
<summary><strong>Example 3: RAID-Z1 with Virtual Disks</strong></summary>

```bash
# Create RAID-Z1 pool with 3 virtual disks
sudo zpool create tank raidz /dev/vdb /dev/vdc /dev/vdd

# Check status
zpool status tank
```
</details>

<details>
<summary><strong>Example 4: Mirror with Manual Partitions</strong></summary>

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
<summary><strong>Example 5: Replace Failed Partition</strong></summary>

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

## 📚 Command Reference

### Essential Commands

| Command | Purpose |
|---------|---------|
| `zpool create` | Create new pool |
| `zpool status` | Check pool health |
| `zpool list` | List pools with capacity |
| `zpool scrub` | Verify data integrity |
| `zpool replace` | Replace failed disk |
| `zpool attach` | Add disk to mirror |
| `zpool add` | Add vdev to pool |
| `zpool export` | Unmount pool |
| `zpool import` | Mount pool |
| `zfs create` | Create dataset |
| `zfs set` | Set dataset properties |
| `zfs list` | List datasets |
| `zfs mount` | Mount dataset |
| `zfs snapshot` | Create snapshot |

### Device Identifier Commands

| Command | Purpose |
|---------|---------|
| `ls -l /dev/disk/by-id/` | List disk serial IDs |
| `ls -l /dev/disk/by-partuuid/` | List partition UUIDs |
| `sudo blkid` | Show all UUIDs and identifiers |
| `lsblk` | List block devices |

## 💡 Pro Tips

### Best Practices

{{< callout type="success" >}}
**Golden Rules**:
1. Use whole disks with `/dev/disk/by-id/` for simplicity and performance
2. Enable compression: `zfs set compression=lz4` (free space savings!)
3. Schedule monthly scrubs for data integrity
4. ECC RAM recommended for production systems
{{< /callout >}}

### Auto-Import on Boot
```bash
sudo zpool set cachefile=/etc/zfs/zpool.cache tank
```

<details>
<summary><strong>Automated Snapshots</strong></summary>

```bash
# Daily snapshots via cron
0 0 * * * /sbin/zfs snapshot tank/data@daily-$(date +\%Y\%m\%d)

# Keep only last 7 days
0 1 * * * /sbin/zfs list -t snapshot -o name | grep daily | head -n -7 | xargs -n 1 /sbin/zfs destroy
```
</details>

<details>
<summary><strong>Monitor Pool Health</strong></summary>

```bash
# Check for errors
zpool status -x

# Detailed status
zpool status -v tank

# I/O statistics
zpool iostat tank 1
```
</details>

## 🔧 Troubleshooting

<details>
<summary><strong>Pool UUID vs PARTUUID Confusion</strong></summary>

**Problem**: Confusion between pool UUID and partition PARTUUID.

**Solution**: 
- Pool UUID (from `blkid`, `TYPE="zfs_member"`): Identifies the ZFS pool, shared by all members
- PARTUUID: Unique identifier for each GPT partition, used in `zpool` commands
</details>

<details>
<summary><strong>Device Not Found After Reboot</strong></summary>

**Problem**: Pool shows `/dev/sdb` but device is now `/dev/sdc`.

**Solution**: Always use persistent identifiers:
```bash
sudo zpool export tank
sudo zpool import -d /dev/disk/by-id tank  # or by-partuuid for partitions
```
</details>

<details>
<summary><strong>Cannot Replace Device</strong></summary>

**Problem**: Replace command fails with "device is in use".

**Solution**: 
- Ensure you're referencing the correct identifier from `zpool status`
- For partition pools, use PARTUUID shown in status
- For whole disk pools, use by-id path shown in status
</details>

<details>
<summary><strong>Disk/Partition In Use</strong></summary>

**Problem**: Cannot create pool, device busy.

**Check**:
```bash
sudo lsof /dev/vdb1
sudo wipefs -a /dev/vdb1  # Clear old filesystem signatures
```
</details>

<details>
<summary><strong>Pool Not Importing After System Move</strong></summary>

**Problem**: Pool not visible after moving disks to new system.

**Solution**:
```bash
# Scan for pools
sudo zpool import

# Import by pool ID
sudo zpool import -d /dev/disk/by-id [pool-id]
```
</details>

<details>
<summary><strong>PARTUUID Not Showing in zpool status</strong></summary>

**Problem**: Status shows `/dev/vdb1` instead of PARTUUID.

**Solution**:
```bash
# Re-import with correct directory
sudo zpool export tank
sudo zpool import -d /dev/disk/by-partuuid tank
```
</details>

## 🎯 Use Cases

- **Home NAS**: Mirror pools for media storage with snapshots
- **Server Storage**: RAID-Z for enterprise data with redundancy
- **Backup Systems**: Snapshots for point-in-time recovery
- **Virtual Machines**: Datasets with compression for VM images
- **Development**: Fast snapshots for testing and rollback

## 📖 Resources

- [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)
- [Ubuntu ZFS Guide](https://ubuntu.com/server/docs/zfs)
- [ZFS Best Practices](https://openzfs.github.io/openzfs-docs/Performance%20and%20Tuning/Workload%20Tuning.html)

---

*Build robust ZFS pools with persistent device identifiers for reliable storage management!*