---
title: "Linux Boot Repair (Debian/Ubuntu)"
date: 2025-09-27T15:34:00+02:00
lastmod: 2026-11-14T18:00:00+01:00
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

{{< callout type="info" >}}
**Tested for real** (2026-11-14): the commands below were run on virtual machines broken on purpose - Ubuntu 26.04 on UEFI with its EFI System Partition emptied, Ubuntu 24.04 on BIOS with the boot code wiped from the MBR - from the Ubuntu live media, and both systems started again. In the VMs the disk was `/dev/vda`; on a PC it is usually `/dev/sda`, or `/dev/nvme0n1` with partitions `nvme0n1p1`, `nvme0n1p2`.
{{< /callout >}}

### First: UEFI or BIOS?

From the live session:

```bash
ls /sys/firmware/efi >/dev/null 2>&1 && echo UEFI || echo BIOS
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME
```

The live session must run in the **same mode** as the installed system: to repair a UEFI install, start the live USB from its UEFI entry in the firmware boot menu.

### UEFI Boot Repair

The usual layout, and the one of the test VM: partition 1 is the EFI System Partition (ESP, FAT32, a few hundred MB), partition 2 is the root filesystem.

When the ESP is empty or damaged the firmware has nothing to start:

![Firmware reporting that no bootable option was found](/images/linux-boot-uefi-no-bootable.png "The ESP has been emptied: no bootable option or device was found")

#### Mount, chroot, reinstall GRUB

```bash
# Root partition first, then the ESP inside it
sudo mount /dev/sda2 /mnt
sudo mount /dev/sda1 /mnt/boot/efi

# The live system's /dev, /proc and /sys, recursively
for d in dev proc sys; do sudo mount --rbind --make-rslave /$d /mnt/$d; done

sudo chroot /mnt
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
update-grub
exit

sudo umount -R /mnt
efibootmgr
```

Expected: `Installation finished. No error reported.` with **no warnings**, and in `efibootmgr` an entry pointing to `\EFI\ubuntu\shimx64.efi` at the top of `BootOrder`.

![grub-install inside the chroot, with the EFI variables visible](/images/linux-boot-uefi-grub-install-ok.png "With --rbind the chroot sees the EFI variables, and grub-install finishes without warnings")

Two details of the mounts are what makes this work. Both were tried the other way in the test:

| Choice | Why | Without it |
|--------|-----|------------|
| `--rbind`, not `--bind` | the EFI variables live in a separate filesystem mounted under `/sys` (`/sys/firmware/efi/efivars`); a plain `--bind` leaves it out | `grub-install` copies the files but warns `EFI variables cannot be set on this system`: no boot entry is written |
| `--make-rslave` | unmounting the chroot does not travel back to the live system | `umount -R /mnt` fails with `target is busy`; and the tempting `umount -lR` also detaches the live system's own `/dev/pts`, after which `sudo` stops working (`unable to open pty`) |

![grub-install warning that EFI variables cannot be set](/images/linux-boot-uefi-efivars-warning.png "With a plain --bind: the files are copied, the boot entry is not")

`--bootloader-id` is the name of the folder in the ESP and of the boot entry: use the one your distribution uses (`ubuntu` on Ubuntu, `debian` on Debian), so the files go back where shim and the existing entry expect them.

**On Ubuntu the system often starts even without the boot entry**: `grub-install` also writes the fallback copy `\EFI\BOOT\BOOTX64.EFI`, which the firmware tries on its own and which recreates the missing entry at the first boot. That is what happened in the test. Do not count on it with other distributions or firmware: check `efibootmgr`.

![Ubuntu desktop after the repair](/images/linux-boot-uefi-repaired-desktop.png "The repaired system, back to the desktop")

#### Do not format the ESP "just in case"

Reformatting the ESP gives it a **new UUID**. `/etc/fstab` still looks for the old one, and on Ubuntu 26.04 so does the initramfs. In the test the result was a boot that waits forever:

```text
[    **] Job dev-disk-by\x2duuid-B5D2\x2d58E…tart running (4min 41s / no limit)
```

Correcting `/etc/fstab` alone was not enough: the system started again only after the initramfs was regenerated too. So format the ESP only if it is really damaged (it does not mount, or `fsck.vfat` reports errors), and then complete the job:

```bash
sudo mkfs.vfat -F 32 /dev/sda1
sudo blkid /dev/sda1      # note the new UUID

# mount and chroot exactly as above, then inside the chroot:
nano /etc/fstab           # put the new UUID on the /boot/efi line
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
update-grub
update-initramfs -u -k all
exit
```

#### Creating a missing ESP (GPT disk)

An ESP can only go into **free space**. Never delete partition 1 to make room for it: on many disks partition 1 is the root or a data partition. If there is no free space, shrink a partition first (GParted from the live session).

```text
sudo fdisk /dev/sda
n        new partition: Enter, Enter (first free number and sector)
+512M    size
t        change the type
1        number of the new partition (fdisk shows it after n)
1        type 1 = EFI System on GPT
w        write and quit
```

Then format it, add its line to `/etc/fstab` and continue as in the previous section. On GPT disks the old MBR answers do not work: the type code `ef` leaves the partition unchanged (`Type of partition 1 is unchanged`), and `n p 1` fails because `p` is read as the partition number.

### Legacy BIOS Boot Repair

With BIOS, GRUB is written to the start of the **disk**, not of a partition. Two layouts are common: an MBR disk, or a GPT disk with a 1 MB "BIOS boot" partition, which is what Ubuntu creates when installed in BIOS mode (the test VM).

When the boot code is gone the BIOS stops right there:

![BIOS stuck at Booting from Hard Disk](/images/linux-boot-bios-hang.png "No boot code in the MBR: the BIOS stops at Booting from Hard Disk...")

```bash
# Root partition: often sda1 on MBR disks, sda2 on GPT disks with a BIOS boot partition
sudo mount /dev/sda2 /mnt
for d in dev proc sys; do sudo mount --rbind --make-rslave /$d /mnt/$d; done

sudo chroot /mnt
grub-install --target=i386-pc /dev/sda
update-grub
exit

sudo umount -R /mnt
```

![grub-install and update-grub for BIOS inside the chroot](/images/linux-boot-bios-repair.png "The Legacy repair: grub-install to the disk, update-grub finds the kernel, umount -R leaves nothing behind")

The `/dev`, `/proc` and `/sys` mounts are not optional. Without them `grub-install` stops immediately:

![grub-install failing in a chroot without /dev, and fdisk refusing the a command on GPT](/images/linux-boot-bios-chroot-without-binds.png "Without the mounts: cannot find a device for /boot/grub (is /dev mounted?)")

#### The bootable flag

The same screenshot shows the other trap: `a` (toggle the bootable flag) exists only on **MBR** disks; on GPT `fdisk` answers `a: unknown command`. GRUB does not need the flag, but some old BIOSes refuse to start an MBR disk with no active partition. Only in that case:

```text
sudo fdisk /dev/sda
a        toggle the bootable flag (MBR disks only)
1        partition number
w        write and quit
```

## Tips and Troubleshooting

### Common Issues
- **GRUB not loading**:
  - Verify the correct disk with `fdisk -l` or `lsblk`.
  - Check that the live session runs in the same mode (UEFI or BIOS) as the installed system.
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
  - Mount them with `--rbind --make-rslave` as shown above. Do not `--rbind` `/run`: it also brings in the live user's session mounts, and `umount -R` then fails on `/mnt/run/user/1000` (seen in the test).

### Additional Tips
- **Backup GRUB configuration**: Before modifying, back up `/boot/grub/grub.cfg`:
  ```bash
  sudo cp /mnt/boot/grub/grub.cfg /mnt/boot/grub/grub.cfg.bak
  ```
- **Verify Partition Layout**: Use `lsblk` or `fdisk -l` to confirm the disk and partition layout before any changes.
- **Test Boot**: After repairs, reboot and test. If GRUB doesn’t load, boot into the live USB again and re-run the commands.
- **Boot Repair Tool**: If manual steps fail, use the `boot-repair` tool in a live session (the PPA is for Ubuntu live media only):
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