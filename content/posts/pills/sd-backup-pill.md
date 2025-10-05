---
title: "SD Card Backup and Restore"
date: 2025-10-05T14:30:00+02:00
draft: false
author: "Manzolo"
tags: ["linux", "backup", "raspberry-pi", "dd", "quick-pill"]
categories: ["linux", "quick-pills"]
series: ["Quick Pills"]
weight: 1
ShowToc: false
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "Quick guide to backup and restore SD cards using dd and gzip compression"
---

# 💊 Quick Pill: SD Card Backup and Restore

{{< callout type="info" >}}
**Use case**: Backup Raspberry Pi SD cards, bootable USB drives, or any block device with compression.
{{< /callout >}}

## 🔄 Backup SD Card

Create a compressed backup of your SD card:

```bash
sudo dd bs=1M status=progress if=/dev/sdb | gzip > ~/Desktop/retropie_`date +%d%m%y`.gz
```

**What it does:**
- `dd bs=1M`: Reads the device in 1MB blocks
- `status=progress`: Shows progress during backup
- `if=/dev/sdb`: Input file (your SD card - **verify with `lsblk`!**)
- `gzip`: Compresses the output on-the-fly
- `date +%d%m%y`: Adds date to filename (e.g., `retropie_051025.gz`)

{{< callout type="danger" >}}
**⚠️ Critical**: Always verify your device name with `lsblk` before running dd. Using the wrong device will destroy your data!
{{< /callout >}}

## 📥 Restore SD Card

Restore the compressed backup to an SD card:

```bash
sudo gzip -dc ~/Desktop/retropie_051025.gz | dd bs=1M of=/dev/sdb status=progress
```

**What it does:**
- `gzip -dc`: Decompresses the backup to stdout
- `dd bs=1M`: Writes in 1MB blocks
- `of=/dev/sdb`: Output file (target SD card)
- `status=progress`: Shows progress during restore

## 🔍 Verify Your Device

Before backup or restore, always check which device is your SD card:

```bash
# List all block devices
lsblk

# Example output:
# NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
# sda      8:0    0  500G  0 disk 
# └─sda1   8:1    0  500G  0 part /
# sdb      8:16   1   32G  0 disk 
# └─sdb1   8:17   1   32G  0 part /media/sdcard
```

In this example, `sdb` is the 32GB SD card.

## 💡 Pro Tips

<details>
<summary><strong>Show estimated time remaining</strong></summary>

```bash
# Install pv (pipe viewer) for better progress indication
sudo apt install pv

# Backup with pv
sudo dd bs=1M if=/dev/sdb | pv -s 32G | gzip > ~/Desktop/backup_`date +%d%m%y`.gz

# Restore with pv
sudo gzip -dc ~/Desktop/backup_051025.gz | pv | dd bs=1M of=/dev/sdb
```
</details>

<details>
<summary><strong>Backup only used space (sparse image)</strong></summary>

For ext4 filesystems, you can create a sparse image that skips empty blocks:

```bash
# Mount the partition first
sudo mount /dev/sdb1 /mnt

# Create sparse backup
sudo tar -czSpf ~/Desktop/sparse_backup_`date +%d%m%y`.tar.gz -C /mnt .

# Restore sparse backup
sudo tar -xzSpf ~/Desktop/sparse_backup_051025.tar.gz -C /mnt
```
</details>

<details>
<summary><strong>Verify backup integrity</strong></summary>

```bash
# Test if the compressed backup is valid
gzip -t ~/Desktop/retropie_051025.gz

# If successful, no output
# If corrupted, you'll see an error message
```
</details>

<details>
<summary><strong>Backup to remote server via SSH</strong></summary>

```bash
# Backup directly to remote server
sudo dd bs=1M if=/dev/sdb | gzip | ssh user@server 'cat > ~/backups/retropie_`date +%d%m%y`.gz'

# Restore from remote server
ssh user@server 'cat ~/backups/retropie_051025.gz' | sudo gzip -dc | dd bs=1M of=/dev/sdb
```
</details>

## ⚠️ Safety Checklist

Before running dd commands:

- [ ] Verified device name with `lsblk`
- [ ] SD card is **unmounted** (not the system disk!)
- [ ] Have enough disk space for the backup
- [ ] Double-checked `if=` (input) and `of=` (output) parameters
- [ ] Tested the backup file after creation

{{< callout type="danger" >}}
**Remember**: `dd` is nicknamed "disk destroyer" for a reason. One typo can wipe your system drive. Always double-check!
{{< /callout >}}

## 📊 Typical Use Cases

| Scenario | Command |
|----------|---------|
| Raspberry Pi backup | `sudo dd if=/dev/sdb \| gzip > ~/rpi_backup.gz` |
| RetroPie backup | `sudo dd if=/dev/sdb \| gzip > ~/retropie.gz` |
| Bootable USB backup | `sudo dd if=/dev/sdc \| gzip > ~/bootusb.gz` |
| Clone to larger SD | `sudo dd if=/dev/sdb of=/dev/sdc bs=1M status=progress` |


---

*Quick, effective, compressed backups for your SD cards and bootable devices!*