---
title: "ZFS Pool Management Guide (Debian/Ubuntu)"
date: 2025-10-03T10:00:00+02:00
lastmod: 2025-10-04T01:36:00+02:00
draft: false
author: "Manzolo"
tags: ["linux", "zfs", "storage", "pool", "tutorial"]
categories: ["linux", "tutorial"]
series: ["Linux Essentials"]
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

ZFS (Zettabyte File System) is an advanced filesystem and volume manager for large storage pools, offering snapshots, compression, and redundancy (e.g., mirror, RAID-Z). This guide shows how to initialize disks with GPT or MBR, create a ZFS pool using device names (`/dev/vdb`, `/dev/vdc`), transition to UUIDs (`/dev/disk/by-uuid/`) for management, and support various RAID types (mirror, RAID-Z1, RAID-Z2) on Debian/Ubuntu.

## What is a ZFS Pool?

A ZFS pool is a collection of virtual devices (vdevs) forming the foundation for ZFS datasets (filesystems) and zvols (block devices). Pools support:
- **Redundancy**: Mirror (RAID-1), RAID-Z1/2/3 (like RAID-5/6/7).
- **Expansion**: Add vdevs to increase capacity (cannot remove easily).
- **Health Monitoring**: Scrubbing and checksums for data integrity.
- **Snapshots/Clones**: Point-in-time copies without full duplication.

Pools are created with `zpool create` and managed via `zpool` commands. Data is stored in datasets (e.g., `tank/home`).

## Prerequisites

- **Debian/Ubuntu**: Version 20.04+.
- **ZFS Installed**: OpenZFS package.
- **Disks**: Unused disks (e.g., `/dev/vdb`, `/dev/vdc`) or partitions (e.g., `/dev/vdb1`). **Warning**: ZFS erases data.
- **Root Access**: Use `sudo`.
- **Tools**: `parted` for partitioning.

Install ZFS:
```bash
sudo apt update
sudo apt install zfsutils-linux parted
sudo modprobe zfs
```

Verify:
```bash
zpool status  # No pools initially
zfs list      # Empty initially
parted --version
```

## Critical Warning: Verify Disks

{{< callout type="warning" >}}
**Caution**: ZFS erases disk or partition data. Use `lsblk` or `blkid` to confirm disks (e.g., `/dev/vdb`, `/dev/vdc`) or partitions (e.g., `/dev/vdb1`). Back up critical data.
{{< /callout >}}

## How to Use ZFS Pools

### 1. Initialize Disks with GPT or MBR
Disks or partitions need a GPT or MBR partition table. GPT is preferred for disks >2TB; MBR is for legacy setups. Whole disks are recommended for performance, but partitions can be used.

#### Initialize with GPT
```bash
sudo parted /dev/vdb mklabel gpt
sudo parted /dev/vdc mklabel gpt
```

#### Initialize with MBR
```bash
sudo parted /dev/vdb mklabel msdos
sudo parted /dev/vdc mklabel msdos
```

Verify:
```bash
sudo blkid | sort
lsblk
```
Example `blkid` output (pre-pool):
```
/dev/vdb: PTUUID="496711cc-9f74-45e2-b78f-903ab66ddad9" PTTYPE="gpt"
/dev/vdc: PTUUID="67c82dbc-3b3b-4af0-b738-ffb955e661a2" PTTYPE="gpt"
```

**Note**: If using partitions (e.g., `/dev/vdb1`), create them first:
```bash
sudo parted /dev/vdb mklabel gpt
sudo parted /dev/vdb mkpart primary 0% 100%
sudo parted /dev/vdc mklabel gpt
sudo parted /dev/vdc mkpart primary 0% 100%
```

### 2. Create a ZFS Pool
Create the pool using device names (`/dev/vdb`, `/dev/vdc`) or partitions (`/dev/vdb1`, `/dev/vdc1`). Whole disks are preferred.

#### Mirror (RAID-1, 2 disks)
```bash
sudo zpool create -f tank mirror /dev/vdb /dev/vdc
```
Or with partitions:
```bash
sudo zpool create -f tank mirror /dev/vdb1 /dev/vdc1
```

#### RAID-Z1 (3+ disks, 1 disk failure tolerance)
```bash
sudo parted /dev/vdd mklabel gpt
sudo zpool create -f tank raidz /dev/vdb /dev/vdc /dev/vdd
```

#### RAID-Z2 (4+ disks, 2 disk failure tolerance)
```bash
sudo parted /dev/vdd mklabel gpt
sudo parted /dev/vde mklabel gpt
sudo zpool create -f tank raidz2 /dev/vdb /dev/vdc /dev/vdd /dev/vde
```

Verify UUIDs:
```bash
sudo blkid | grep zfs_member
```
Example (post-creation, mirror with partitions):
```
/dev/vdb1: UUID="150809157285762621" TYPE="zfs_member" PARTUUID="ee2507fe-0b11-ad4c-b1c5-87e36055410e"
/dev/vdc1: UUID="150809157285762621" TYPE="zfs_member" PARTUUID="c074a830-4f67-a24d-b028-7cefbe64a690"
```

Check pool:
```bash
zpool status tank
```

### 3. Transition from /dev/vdX to UUIDs
After creation, ZFS assigns UUIDs (`TYPE="zfs_member"`) to disks/partitions. Use `/dev/disk/by-partuuid/` for reliable management to avoid device name changes.

1. **Verify UUIDs**:
   ```bash
   sudo blkid | grep zfs_member
   ls -l /dev/disk/by-partuuid/
   ```
   Example:
   ```
   lrwxrwxrwx 1 root root 10 Oct  4 01:36 11111111-6a2e-5f41-afa3-85ded4e3f046 -> ../../vdb
   lrwxrwxrwx 1 root root 10 Oct  4 01:36 22222222-76yt-yt76-94ir-dsalkjflkej3 -> ../../vdc
   ```

2. **Export and Import with PARTUUIDs**:
   To ensure the pool uses PARTUUIDs in `zpool status`:
   ```bash
   sudo zpool export tank
   sudo zpool import -d /dev/disk/by-partuuid tank
   ```

3. **Verify UUID Usage**:
   ```bash
   zpool status tank
   ```
   Example (mirror with partitions):
   ```
     pool: tank
    state: ONLINE
   config:
           NAME                                     STATE     READ WRITE CKSUM
           tank                                     ONLINE    0    0     0
             mirror-0                               ONLINE    0    0     0
               150809157285762621                   ONLINE    0    0     0
               150809157285762621                   ONLINE    0    0     0
   ```

4. **Use UUIDs for Operations** (e.g., attach a new disk):
   ```bash
   sudo parted /dev/vdh mklabel gpt
   sudo parted /dev/vdh mkpart primary 0% 100%
   sudo zpool attach tank /dev/disk/by-uuid/150809157285762621 /dev/vdh1
   ```

**Note**: If `zpool status` shows PARTUUIDs (e.g., `ee2507fe-0b11-ad4c-b1c5-87e36055410e`), repeat the export/import with `-d /dev/disk/by-uuid` to prioritize UUIDs.

### 4. Modify a ZFS Pool
Use UUIDs for modifications after transitioning.

- **Add a Mirror Vdev**:
  ```bash
  sudo parted /dev/vde mklabel gpt
  sudo parted /dev/vdf mklabel gpt
  sudo zpool add tank mirror /dev/vde /dev/vdf
  ```

- **Add a RAID-Z1 Vdev**:
  ```bash
  sudo parted /dev/vde mklabel gpt
  sudo parted /dev/vdf mklabel gpt
  sudo parted /dev/vdg mklabel gpt
  sudo zpool add tank raidz /dev/vde /dev/vdf /dev/vdg
  ```

### 5. Replace a Degraded Disk
If a disk/partition fails (e.g., `UNAVAIL`), replace it using UUIDs.

1. **Check Status**:
   ```bash
   zpool status tank
   ```
   Example (mirror with partitions):
   ```
     pool: tank
    state: DEGRADED
   config:
           NAME                                     STATE     READ WRITE CKSUM
           tank                                     DEGRADED  0    0     0
             mirror-0                               DEGRADED  0    0     0
               150809157285762621                   UNAVAIL   0    0     0
               150809157285762621                   ONLINE    0    0     0
   ```

2. **Replace Disk/Partition**:
   ```bash
   sudo parted /dev/vdg mklabel gpt
   sudo parted /dev/vdg mkpart primary 0% 100%
   sudo zpool replace tank /dev/disk/by-uuid/150809157285762621 /dev/vdg1
   ```

3. **Monitor Resilvering**:
   ```bash
   zpool status tank
   ```

4. **Verify**:
   ```bash
   sudo zpool scrub tank
   zpool status -v tank
   ```

### 6. Manage a ZFS Pool
- **Status and Scrub**:
  ```bash
  zpool status tank
  sudo zpool scrub tank
  ```
- **Export/Import**:
  ```bash
  sudo zpool export tank
  sudo zpool import -d /dev/disk/by-uuid tank
  ```
- **Create Dataset**:
  ```bash
  sudo zfs create tank/home
  sudo zfs set compression=lz4 tank
  ```

## Examples

### Example 1: Create Mirrored Pool and Transition to UUIDs
```bash
# Verify disks
lsblk
sudo blkid

# Initialize with GPT
sudo parted /dev/vdb mklabel gpt
sudo parted /dev/vdc mklabel gpt
# Optional: Create partitions
sudo parted /dev/vdb mkpart primary 0% 100%
sudo parted /dev/vdc mkpart primary 0% 100%

# Create mirror pool
sudo zpool create -f tank mirror /dev/vdb1 /dev/vdc1

# Check UUIDs
sudo blkid | grep zfs_member
# Example: /dev/vdb1: UUID="150809157285762621" TYPE="zfs_member"

# Transition to UUIDs
sudo zpool export tank
sudo zpool import -d /dev/disk/by-uuid tank
zpool status tank
# Shows UUIDs in config

# Attach new disk with UUID
sudo parted /dev/vdh mklabel gpt
sudo parted /dev/vdh mkpart primary 0% 100%
sudo zpool attach tank /dev/disk/by-uuid/150809157285762621 /dev/vdh1

# Create dataset
sudo zfs create -o compression=lz4 tank/data
sudo mkdir /mnt/tank
sudo zfs set mountpoint=/mnt/tank tank
echo "Test data" > /mnt/tank/test.txt

# Verify
zpool status tank
```

**Output**:
```
  pool: tank
 state: ONLINE
  scan: scrub repaired 0B in 00:00:01 with 0 errors on [date]
config:
        NAME                                     STATE     READ WRITE CKSUM
        tank                                     ONLINE    0    0     0
          mirror-0                               ONLINE    0    0     0
            150809157285762621                   ONLINE    0    0     0
            150809157285762621                   ONLINE    0    0     0
errors: No known data errors
```

### Example 2: Create RAID-Z1 Pool
```bash
# Initialize disks
sudo parted /dev/vdb mklabel gpt
sudo parted /dev/vdc mklabel gpt
sudo parted /dev/vdd mklabel gpt

# Create RAID-Z1 pool
sudo zpool create -f tank raidz /dev/vdb /dev/vdc /dev/vdd

# Check UUIDs
sudo blkid | grep zfs_member
sudo zpool export tank
sudo zpool import -d /dev/disk/by-uuid tank
zpool status tank
```

### Example 3: Replace a Degraded Disk
```bash
# Check status
zpool status tank  # Shows UNAVAIL disk/partition

# Initialize new disk
sudo parted /dev/vdg mklabel gpt
sudo parted /dev/vdg mkpart primary 0% 100%

# Replace with UUID
sudo zpool replace tank /dev/disk/by-uuid/150809157285762621 /dev/vdg1
zpool status tank  # Monitor resilver
```

### Example 4: Export/Import for Maintenance
```bash
sudo zpool export tank
sudo zpool import -d /dev/disk/by-uuid tank
```

## Command Breakdown
- **parted**: Initializes disks/partitions (`mklabel gpt` or `mklabel msdos`).
- **zpool create**: Builds pool with vdevs (mirror, raidz, raidz2).
- **zpool export/import**: Transitions to UUIDs.
- **zpool add/replace/attach**: Modifies pool structure.
- **zpool status/scrub**: Monitors and repairs.

## Use Cases
- **Home NAS**: Mirror pools for media with snapshots.
- **Server Storage**: RAID-Z for enterprise data.
- **Backup**: Snapshots for recovery.

## Pro Tips
- **Whole Disks vs. Partitions**: Use whole disks (`/dev/vdb`) for better performance; partitions (`/dev/vdb1`) if required.
- **UUIDs for Reliability**: Use `/dev/disk/by-uuid/` after creation to avoid device name changes.
- **ECC RAM**: Recommended to prevent corruption.
- **Auto-Import**: `sudo zpool set cachefile=/etc/zfs/zpool.cache tank` for boot-time import.
- **Snapshots**: Automate with cron:
  ```bash
  0 0 * * * zfs snapshot tank@daily-$(date +%Y%m%d)
  ```

## Troubleshooting
- **UUID Not Found**: UUIDs appear after `zpool create`. Use device names/partitions before creation.
- **Replace Fails**: Avoid replacing with active pool members (e.g., `150809157285762621`). Use `zpool status` to identify failed device.
- **Disk/Partition in Use**: Check: `sudo lsof /dev/vdb1`. Clear metadata: `sudo wipefs -a /dev/vdb1`.
- **Pool Creation Fails**: Verify disks with `lsblk`, ensure not mounted.
- **PARTUUID in zpool status**: Export/import with `-d /dev/disk/by-uuid` to use UUIDs.

## Resources
- [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)
- [Ubuntu ZFS Guide](https://ubuntu.com/server/docs/zfs)

---

*Build ZFS pools with device names/partitions and manage with UUIDs for robust storage!*