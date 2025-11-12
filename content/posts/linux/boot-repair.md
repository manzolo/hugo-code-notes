---
title: "Linux Boot Repair (Debian/Ubuntu)"
date: 2025-09-27T15:34:00+02:00
lastmod: 2025-09-27T15:34:00+02:00
draft: false
author: "Manzolo"
tags: ["boot-repair", "grub", "recovery", "troubleshooting", "ubuntu"]
categories: ["Linux Administration"]
series: ["System Administration Basics"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Linux Boot Repair Guide (Debian/Ubuntu)

## Introduction

Boot issues in Debian or Ubuntu can prevent your system from starting, often due to a corrupted GRUB bootloader, misconfigured partitions, or kernel problems. This guide provides step-by-step instructions to repair the boot process for both UEFI and Legacy (BIOS/MBR) systems using a live USB/CD. It covers GRUB reinstallation, partition setup, and troubleshooting common issues.

## Prerequisites

- A Debian or Ubuntu live USB/CD (preferably the same version as your system).
- Access to a live session by booting from the live media and selecting "Try Ubuntu/Debian."
- Basic familiarity with the terminal.
- Administrative (root) privileges in the live environment.

## Critical Warning: Verify Partitions Before Formatting

{{< callout type="warning" >}}
**Extreme Caution**: Before formatting any partition, use `lsblk` or `fdisk -l` to verify that you are selecting the correct disk and partition (e.g., EFI System Partition or root partition). Formatting the wrong partition can erase your data or critical files. Always double-check the disk and partition layout to avoid data loss.
{{< /callout >}}

## Linux Boot Repair

### UEFI Boot Repair

UEFI systems use an EFI System Partition (ESP) to store GRUB and boot files. If the ESP is missing, corrupted, or misconfigured, the system may fail to boot.

#### Partition Setup
To prepare or repair the ESP and root partition:

```bash
sudo fdisk -l  # List disks to identify the correct one
sudo fdisk /dev/sda  # Replace sda with your disk

# Select EFI System Partition (ESP) - FAT32
# Verify partition layout with 'p'
p
# If ESP exists (typically 100-550 MB, type EFI System Partition), format it
t
1  # Select partition 1 (verify it’s the ESP)
ef # Set type to EFI System Partition
w  # Write changes

# Format ESP as FAT32
sudo mkfs.vfat -F 32 /dev/sda1  # Verify sda1 is the ESP
```

- **Explanation**:
  - `fdisk -l`: Lists all disks and partitions to confirm the correct disk (e.g., `/dev/sda`).
  - `fdisk /dev/sda`: Opens the disk for editing (replace `sda` with your disk).
  - `p`: Prints the partition table to verify the ESP (typically 100-550 MB, type EFI).
  - `t 1 ef`: Sets the partition type to EFI System Partition if needed.
  - `w`: Writes changes to the disk.
  - `mkfs.vfat -F 32`: Formats the ESP as FAT32 (required for UEFI).

#### Mount Filesystems and Reinstall GRUB
Mount the necessary filesystems and use a chroot environment to reinstall GRUB:

```bash
# Mount root partition
sudo mount /dev/sda2 /mnt  # Replace sda2 with your root partition

# Mount ESP
sudo mkdir -p /mnt/boot/efi
sudo mount /dev/sda1 /mnt/boot/efi  # Replace sda1 with your ESP

# Mount other necessary filesystems
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys

# Enter chroot
sudo chroot /mnt

# Reinstall GRUB for UEFI
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
update-grub

# Exit chroot and unmount
exit
sudo umount /mnt/dev /mnt/proc /mnt/sys /mnt/boot/efi /mnt
```

- **Explanation**:
  - Mounts the root partition (`/dev/sda2`) and ESP (`/dev/sda1`) to `/mnt`.
  - Binds `/dev`, `/proc`, and `/sys` for chroot compatibility.
  - `chroot /mnt`: Enters the system’s root environment.
  - `grub-install`: Installs GRUB for UEFI to the ESP.
  - `update-grub`: Updates the GRUB configuration to detect the kernel.
  - Unmounts filesystems after completion.

#### Manual EFI Partition Creation
If the ESP is missing, create one:

```bash
sudo fdisk /dev/sda  # Replace sda with your disk

# Create EFI partition (100MB)
d
1  # Delete existing partition if necessary (verify carefully)
n
p
1
# Accept default start sector
+100M
t
1
ef  # Set type to EFI System Partition
w   # Write changes

# Format as FAT32
sudo mkfs.vfat -F 32 /dev/sda1
```

- **Explanation**:
  - `fdisk /dev/sda`: Opens the disk for editing.
  - `d 1`: Deletes the old partition (if necessary, verify it’s not a data partition).
  - `n p 1 +100M`: Creates a 100 MB partition for the ESP.
  - `t 1 ef`: Sets the partition type to EFI System Partition.
  - `mkfs.vfat -F 32`: Formats the partition as FAT32.
  - Follow with the `grub-install` steps above.

### Legacy (BIOS/MBR) Boot Repair

Legacy systems use the Master Boot Record (MBR) and a boot sector on the root or a separate boot partition.

#### Reinstall GRUB
Mount the root partition and reinstall GRUB:

```bash
sudo fdisk -l  # List disks to identify the correct one
sudo mount /dev/sda1 /mnt  # Replace sda1 with your root partition

# Mount other necessary filesystems
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys

# Enter chroot
sudo chroot /mnt

# Reinstall GRUB for Legacy
grub-install --target=i386-pc /dev/sda  # Replace sda with your disk
update-grub

# Exit chroot and unmount
exit
sudo umount /mnt/dev /mnt/proc /mnt/sys /mnt
```

- **Explanation**:
  - `fdisk -l`: Identifies the correct disk and root partition.
  - Mounts the root partition (`/dev/sda1`) to `/mnt`.
  - Binds `/dev`, `/proc`, and `/sys` for chroot.
  - `grub-install --target=i386-pc`: Installs GRUB to the MBR of the disk.
  - `update-grub`: Generates the GRUB configuration.
  - Unmounts filesystems after completion.

#### Repair Boot Sector (if GRUB fails to boot)
If the boot sector is corrupted:

```bash
sudo fdisk /dev/sda  # Replace sda with your disk
a
1  # Set partition 1 as bootable (verify it’s the root or boot partition)
w  # Write changes

# Reinstall GRUB as above
sudo mount /dev/sda1 /mnt
sudo chroot /mnt
grub-install --target=i386-pc /dev/sda
update-grub
exit
sudo umount /mnt/dev /mnt/proc /mnt/sys /mnt
```

- **Explanation**:
  - `a 1`: Marks the root or boot partition as bootable.
  - Reinstalls GRUB to ensure the boot sector is correctly configured.

## Tips and Troubleshooting

### Common Issues
- **GRUB not loading**:
  - Verify the correct disk with `fdisk -l` or `lsblk`.
  - Ensure the ESP (`/dev/sda1`) is FAT32 for UEFI or the root/boot partition is bootable for Legacy.
- **"No such device" or kernel not found**:
  - Run `update-grub` in the chroot environment to detect the kernel.
  - Check if `/boot` contains the kernel and initramfs files (e.g., `vmlinuz`, `initrd.img`).
- **UEFI vs. BIOS mismatch**:
  - Confirm your system’s firmware mode (UEFI or Legacy) in the BIOS/UEFI settings.
  - Use `--target=x86_64-efi` for UEFI or `--target=i386-pc` for Legacy.
- **Data loss from formatting**:
  - Always use `lsblk` or `fdisk -l` to verify partitions before formatting.
  - Incorrectly formatting the root or data partition will result in data loss. Back up critical data before proceeding.
- **Chroot errors**:
  - Ensure all filesystems (`/dev`, `/proc`, `/sys`, `/boot/efi`) are mounted correctly.
  - If internet is needed in chroot, bind-mount `/run`: `sudo mount --bind /run /mnt/run`.

### Additional Tips
- **Backup GRUB configuration**: Before modifying, back up `/boot/grub/grub.cfg`:
  ```bash
  sudo cp /mnt/boot/grub/grub.cfg /mnt/boot/grub/grub.cfg.bak
  ```
- **Verify Partition Layout**: Use `lsblk` or `fdisk -l` to confirm the disk and partition layout before any changes.
- **Test Boot**: After repairs, reboot and test. If GRUB doesn’t load, boot into the live USB again and re-run the commands.
- **Boot Repair Tool**: If manual steps fail, use the `boot-repair` tool in a live session:
  ```bash
  sudo add-apt-repository ppa:yannubuntu/boot-repair
  sudo apt update
  sudo apt install -y boot-repair
  boot-repair
  ```

## Next Steps

In future tutorials, we’ll explore:
- Customizing GRUB configurations.
- Recovering Linux systems using rescue mode.
- Automating boot repairs with scripts.

## Resources
- [Ubuntu Boot Repair Guide](https://help.ubuntu.com/community/Boot-Repair)
- [Debian GRUB Documentation](https://www.debian.org/doc/manuals/debian-handbook/sect.grub2.en.html)
- [GRUB Manual](https://www.gnu.org/software/grub/manual/grub/grub.html)

---

*Practice these commands in a test environment to master Linux boot repair, and always verify partitions to avoid data loss!*