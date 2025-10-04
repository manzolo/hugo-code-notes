---
title: "ZFS Pool Management Guide (Debian/Ubuntu)"
date: 2025-10-03T10:00:00+02:00
lastmod: 2025-10-04T10:41:00+02:00
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

ZFS (Zettabyte File System) is an advanced filesystem and volume manager for large storage pools, offering snapshots, compression, and redundancy (e.g., mirror, RAID-Z). This guide shows how to initialize disks with GPT or MBR, create a ZFS pool using device names (`/dev/vdb`, `/dev/vdc`), transition to UUIDs (`/dev/disk/by-uuid/`) for management, support various RAID types (mirror, RAID-Z1, RAID-Z2), and mount datasets for normal user access on Debian/Ubuntu.

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
- **Disks**: Unused disks (e.g., `/dev/vdb`, `/dev/vdc`). **Warning**: ZFS erases data.
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
**Caution**: ZFS erases disk data. Use `lsblk` or `blkid` to confirm disks (e.g., `/dev/vdb`, `/dev/vdc`). Back up critical data.
{{< /callout >}}

## How to Use ZFS Pools

### 1. Initialize Disks with GPT or MBR
Disks need a GPT or MBR partition table. GPT is preferred for disks >2TB; MBR is for legacy setups. Whole disks are recommended for performance.

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

### 2. Create a ZFS Pool
Create the pool using device names (`/dev/vdb`, `/dev/vdc`). Whole disks are preferred.

#### Mirror (RAID-1, 2 disks)
```bash
sudo zpool create -f tank mirror /dev/vdb /dev/vdc
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
Example (post-creation, mirror):
```
/dev/vdb: UUID="150809157285762621" TYPE="zfs_member" PTUUID="496711cc-9f74-45e2-b78f-903ab66ddad9"
/dev/vdc: UUID="150809157285762621" TYPE="zfs_member" PTUUID="67c82dbc-3b3b-4af0-b738-ffb955e661a2"
```

Check pool:
```bash
zpool status tank
```

### 3. Transition from /dev/vdX to UUIDs
After creation, ZFS assigns UUIDs (`TYPE="zfs_member"`) to disks. Use `/dev/disk/by-uuid/` for reliable management to avoid device name changes.

1. **Verify UUIDs**:
   ```bash
   sudo blkid | grep zfs_member
   ls -l /dev/disk/by-uuid/
   ```
   Example:
   ```
   lrwxrwxrwx 1 root root 10 Oct  4 10:41 150809157285762621 -> ../../vdb
   lrwxrwxrwx 1 root root 10 Oct  4 10:41 150809157285762621 -> ../../vdc
   ```

2. **Export and Import with UUIDs**:
   To ensure the pool uses UUIDs in `zpool status`:
   ```bash
   sudo zpool export tank
   sudo zpool import -d /dev/disk/by-uuid tank
   ```

3. **Verify UUID Usage**:
   ```bash
   zpool status tank
   ```
   Example:
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
   sudo zpool attach tank /dev/disk/by-uuid/150809157285762621 /dev/vdh
   ```

**Note**: If `zpool status` shows PARTUUIDs (e.g., `ee2507fe-0b11-ad4c-b1c5-87e36055410e`), use `-d /dev/disk/by-uuid` during import to prioritize UUIDs.

### 4. Mount and Write to a ZFS Dataset
To allow a normal user (e.g., `manzolo`) to mount and write to a dataset (e.g., `tank/data`):

1. **Create and Mount Dataset** (as root):
   ```bash
   sudo zfs create tank/data
   sudo zfs set mountpoint=/mnt/tank tank/data
   ```

2. **Set Permissions for Normal User**:
   ```bash
   sudo chown manzolo:manzolo /mnt/tank
   sudo chmod 775 /mnt/tank
   ```

3. **Mount and Write as Normal User** (with `sudo`):
   ```bash
   sudo zfs mount tank/data
   echo "Test data" | sudo tee /mnt/tank/test.txt
   ```
   Or without `sudo` (after permissions are set):
   ```bash
   echo "Test data" > /mnt/tank/test.txt
   ```

**Note**: If the dataset doesn’t mount, check with `zfs list` and ensure the `mountpoint` property is set. Use `sudo zfs set canmount=on tank/data` if needed.

### 5. Modify a ZFS Pool
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

### 6. Replace a Degraded Disk
If a disk fails (e.g., `UNAVAIL`), replace it using UUIDs.

1. **Check Status**:
   ```bash
   zpool status tank
   ```
   Example:
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

2. **Replace Disk**:
   ```bash
   sudo parted /dev/vdg mklabel gpt
   sudo zpool replace tank /dev/disk/by-uuid/150809157285762621 /dev/vdg
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

### 7. Manage a ZFS Pool
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

## Examples

### Example 1: Create Mirrored Pool and Transition to UUIDs
```bash
# Verify disks
lsblk
sudo blkid

# Initialize with GPT
sudo parted /dev/vdb mklabel gpt
sudo parted /dev/vdc mklabel gpt

# Create mirror pool
sudo zpool create -f tank mirror /dev/vdb /dev/vdc

# Check UUIDs
sudo blkid | grep zfs_member
# Example: /dev/vdb: UUID="150809157285762621" TYPE="zfs_member"

# Transition to UUIDs
sudo zpool export tank
sudo zpool import -d /dev/disk/by-uuid tank
zpool status tank
# Shows UUIDs in config

# Attach new disk with UUID
sudo parted /dev/vdh mklabel gpt
sudo zpool attach tank /dev/disk/by-uuid/150809157285762621 /dev/vdh

# Create and mount dataset for user
sudo zfs create -o compression=lz4 tank/data
sudo zfs set mountpoint=/mnt/tank tank/data
sudo chown manzolo:manzolo /mnt/tank
sudo chmod 775 /mnt/tank
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
zpool status tank  # Shows UNAVAIL disk

# Initialize new disk
sudo parted /dev/vdg mklabel gpt

# Replace with UUID
sudo zpool replace tank /dev/disk/by-uuid/150809157285762621 /dev/vdg
zpool status tank  # Monitor resilver
```

### Example 4: Export/Import for Maintenance
```bash
sudo zpool export tank
sudo zpool import -d /dev/disk/by-uuid tank
```

## Variants

### Using Partitions Instead of Whole Disks
ZFS can use partitions (e.g., `/dev/vdb1`, `/dev/vdc1`) instead of whole disks if needed (e.g., for dual-boot or mixed filesystems).

1. **Create Partitions**:
   ```bash
   sudo parted /dev/vdb mklabel gpt
   sudo parted /dev/vdb mkpart primary 0% 100%
   sudo parted /dev/vdc mklabel gpt
   sudo parted /dev/vdc mkpart primary 0% 100%
   ```

2. **Create Pool with Partitions**:
   ```bash
   sudo zpool create -f tank mirror /dev/vdb1 /dev/vdc1
   ```

3. **Verify UUIDs and PARTUUIDs**:
   ```bash
   sudo blkid | grep zfs_member
   ```
   Example (post-creation, mirror with partitions):
   ```
   /dev/vdb1: UUID="150809157285762621" TYPE="zfs_member" PARTUUID="ee2507fe-0b11-ad4c-b1c5-87e36055410e"
   /dev/vdc1: UUID="150809157285762621" TYPE="zfs_member" PARTUUID="c074a830-4f67-a24d-b028-7cefbe64a690"
   ```

4. **Transition to UUIDs**:
   ```bash
   sudo zpool export tank
   sudo zpool import -d /dev/disk/by-uuid tank
   zpool status tank
   ```
   Example:
   ```
     pool: tank
    state: ONLINE
   config:
           NAME                                     STATE     READ WRITE CKSUM
           tank                                     ONLINE    0    0     0
             mirror-0                               ONLINE    0    0     0
               ee2507fe-0b11-ad4c-b1c5-87e36055410e ONLINE    0    0     0
               c074a830-4f67-a24d-b028-7cefbe64a690 ONLINE    0    0     0
   ```

5. **Replace a Partition**:
   ```bash
   sudo parted /dev/vdg mklabel gpt
   sudo parted /dev/vdg mkpart primary 0% 100%
   sudo zpool replace tank /dev/disk/by-uuid/150809157285762621 /dev/vdg1
   ```

**Note**: If `zpool status` shows PARTUUIDs, use `-d /dev/disk/by-uuid` during import to prioritize UUIDs.

## Command Breakdown
- **parted**: Initializes disks (`mklabel gpt` or `mklabel msdos`).
- **zpool create**: Builds pool with vdevs (mirror, raidz, raidz2).
- **zpool export/import**: Transitions to UUIDs.
- **zpool add/replace/attach**: Modifies pool structure.
- **zfs create/set/mount**: Manages datasets and permissions.
- **zpool status/scrub**: Monitors and repairs.

## Use Cases
- **Home NAS**: Mirror pools for media with snapshots.
- **Server Storage**: RAID-Z for enterprise data.
- **Backup**: Snapshots for recovery.

## Pro Tips
- **Whole Disks**: Prefer `/dev/vdb` over `/dev/vdb1` for performance.
- **UUIDs**: Use `/dev/disk/by-uuid/` after creation for reliability.
- **ECC RAM**: Recommended to prevent corruption.
- **Auto-Import**: `sudo zpool set cachefile=/etc/zfs/zpool.cache tank` for boot-time import.
- **Snapshots**: Automate with cron:
  ```bash
  0 0 * * * zfs snapshot tank@daily-$(date +%Y%m%d)
  ```

## Troubleshooting
- **UUID Not Found**: UUIDs appear after `zpool create`. Use device names before creation.
- **Replace Fails**: Avoid active pool members (e.g., `150809157285762621`). Check `zpool status`.
- **Disk in Use**: Check: `sudo lsof /dev/vdb`. Clear metadata: `sudo wipefs -a /dev/vdb`.
- **Pool Creation Fails**: Verify disks with `lsblk`, ensure not mounted.
- **PARTUUID in zpool status**: Export/import with `-d /dev/disk/by-uuid` to use UUIDs.

## Resources
- [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)
- [Ubuntu ZFS Guide](https://ubuntu.com/server/docs/zfs)

---

*Build ZFS pools with device names and manage with UUIDs for robust storage!*