---
title: "Windows Boot Repair"
date: 2025-09-27T15:26:00+02:00
lastmod: 2025-09-27T15:26:00+02:00
draft: false
author: "Manzolo"
tags: ["boot-repair", "windows", "dual-boot", "grub", "troubleshooting"]
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

# Windows Boot Repair Guide

## Introduction

Windows boot issues can prevent your system from starting correctly, often due to corrupted boot files, misconfigured partitions, or firmware settings. This guide provides step-by-step instructions to repair Windows boot problems for both UEFI and MBR/Legacy systems using the Windows Recovery Environment (WinRE) command prompt. It covers partition setup, boot configuration rebuilding, and troubleshooting common issues.

## Prerequisites

- A Windows installation USB or DVD with the same version as your system.
- Access to the Windows Recovery Environment (WinRE) by booting from the installation media and selecting "Repair your computer."
- Basic familiarity with the Command Prompt.
- Administrative privileges in the recovery environment.

## Critical Warning: Verify Partitions Before Formatting

{{< callout type="warning" >}}
**Extreme Caution**: Before formatting any partition, use `diskpart`’s `list disk` and `list part` commands to verify that you are selecting the correct disk and partition (e.g., the EFI System Partition or system partition). Formatting the wrong partition can erase your Windows data or other critical files. Always double-check the disk and partition layout to ensure you are not deleting your data drive.
{{< /callout >}}

## Windows Boot Repair

### UEFI Boot Repair

UEFI systems use an EFI System Partition (ESP) to store boot files. If the ESP is missing, corrupted, or misconfigured, Windows may fail to boot.

#### Partition Setup
To prepare or repair the ESP and Windows partition:

```cmd
diskpart
list disk
rem Verify this is the correct disk
sel disk 0
rem Confirm partition layout (ESP is typically 100-300 MB, FAT32)
list part

rem Select EFI System Partition (ESP) - FAT32
rem Verify this is the ESP
sel part 1
format quick fs=fat32
assign letter=s

rem Select Windows Partition
rem Verify this is the Windows partition
sel part 3
assign letter=c
exit
```

**About the `rem` lines**: `diskpart` has no `#` comments. A command followed by `# something` is rejected (`The arguments specified for this command are not valid`) and, worse, a rejected `sel disk` leaves **no disk selected** - or the previous one. Comments go on their own line and start with `rem`. Tested with DiskPart 10.0.26100 on Windows 11.

- **Explanation**:
  - `diskpart`: Launches the disk partitioning tool.
  - `list disk`: Lists all disks to confirm the correct disk number.
  - `sel disk 0`: Selects the primary disk (replace `0` with the correct disk number).
  - `list part`: Displays partitions to identify the ESP (typically 100-300 MB, FAT32) and Windows partition.
  - `sel part 1`: Selects the ESP (verify it’s the correct partition).
  - `format quick fs=fat32`: Formats the ESP as FAT32 (only if necessary).
  - `assign letter=s`: Assigns a drive letter for access.
  - `sel part 3`: Selects the Windows partition (verify with `list part`).
  - `assign letter=c`: Assigns a drive letter to the Windows partition.
  - `exit`: Exits diskpart.

#### Boot Configuration
To rebuild the UEFI boot configuration:

```cmd
bcdboot c:\Windows /s S: /f UEFI
```

- **Explanation**:
  - `bcdboot`: Copies boot files from the Windows partition (`c:\Windows`) to the ESP (`S:`).
  - `/f UEFI`: Specifies UEFI firmware type to ensure compatibility.

#### Proof: Breaking and Repairing a Real ESP
The two blocks above were run exactly as written on a Windows 11 virtual machine (UEFI, GPT) whose EFI System Partition had been emptied on purpose. The screenshots come from an Italian Windows; the commands are the same in every language.

1. **The failure.** With the boot files gone the firmware finds nothing to start. This is the message of the VM firmware (OVMF); a physical PC words it differently, or drops straight into its setup screen.

   ![Firmware reporting that no bootable device was found](/images/win-boot-no-bootable-device.png "The ESP is empty: no bootable option or device was found")

2. **The command prompt.** Boot from the Windows installation media and press `Shift+F10` on the first screen: a command prompt opens, without going through the repair menus.

3. **The partitions.** `list part` shows the layout the commands assume (ESP = 1, Windows = 3). The ESP is formatted and both partitions get a letter.

   ![diskpart session: the ESP formatted as FAT32 and letters assigned](/images/win-boot-diskpart-repair.png "The diskpart commands of this guide, typed as written")

4. **The boot files.** `bcdboot c:\Windows /s S: /f UEFI` answers `Boot files successfully created.`

5. **The reboot.** Remove the installation media and restart: Windows starts normally.

   ![Windows 11 desktop after the repair](/images/win-boot-repaired-desktop.png "Back to the desktop after bcdboot")

**On a virtual machine with a VirtIO disk** `list disk` shows nothing: the installation media has no driver for it. Load it first from the virtio-win ISO (here mounted as `E:`), then run `diskpart` again:

```cmd
drvload E:\viostor\w11\amd64\viostor.inf
```

#### Manual EFI Partition Creation
If the ESP is missing, create one:

```cmd
diskpart
list disk
rem Verify this is the correct disk
sel disk 0

rem Create EFI partition (100MB)
create partition efi size=100
format quick fs=fat32 label="System"
assign letter=S

rem Create Microsoft Reserved (MSR) partition (128MB)
create partition msr size=128
exit
```

- **Explanation**:
  - `list disk`: Confirms the correct disk.
  - `create partition efi size=100`: Creates a 100 MB EFI partition. No `offset=`: `diskpart` places and aligns it by itself, on a megabyte boundary.
  - `format quick fs=fat32 label="System"`: Formats the partition as FAT32 with a "System" label.
  - `create partition msr size=128`: Creates a 128 MB Microsoft Reserved partition (required for UEFI).
  - Use `bcdboot c:\Windows /s S: /f UEFI` afterward to populate the ESP.

### MBR/Legacy Boot Repair

MBR/Legacy systems use a different boot process, relying on the Master Boot Record and boot sector.

#### Standard Boot Repair Commands
Run these commands in the WinRE Command Prompt:

```cmd
bootrec /fixmbr
bootrec /fixboot
bootrec /scanos
bootrec /rebuildbcd
```

- **Explanation**:
  - `bootrec /fixmbr`: Repairs the Master Boot Record to fix boot loader issues.
  - `bootrec /fixboot`: Writes a new boot sector to the system partition.
  - `bootrec /scanos`: Scans for Windows installations not listed in the Boot Configuration Data (BCD).
  - `bootrec /rebuildbcd`: Rebuilds the BCD store to include detected Windows installations.

#### Alternative Method (if `bootrec /fixboot` fails with "access denied")
If `bootrec /fixboot` fails, use this method:

```cmd
diskpart
list disk
rem Verify this is the correct disk
sel disk 0
rem Confirm partition layout (system partition is typically 100-500 MB)
list part

rem System partition - FAT32 or NTFS
rem Verify this is the system partition
sel part 1
format quick fs=fat32
assign letter=s

rem Windows partition
rem Verify this is the Windows partition
sel part 3
assign letter=c
exit

rem Rebuild boot configuration for all firmware types
bcdboot C:\Windows /s S: /f ALL
```

- **Explanation**:
  - `list disk` and `list part`: Verify the disk and partition layout to avoid formatting the data drive.
  - Formats the system partition (typically 100-500 MB) as FAT32 or NTFS (only if necessary).
  - Assigns drive letters to access the system and Windows partitions.
  - `bcdboot /f ALL`: Creates boot files compatible with both UEFI and BIOS firmware.

## Tips and Troubleshooting

### Common Issues
- **"`bootrec /fixboot` access denied"**:
  - Use the alternative `bcdboot` method shown above.
  - Ensure the system partition is active (`active` command in `diskpart` for MBR) or formatted correctly (FAT32 for UEFI).
- **VHD Compatibility**:
  - A VHD is partitioned like any other disk once it is attached. `diskpart` has no `subformat` option (that one belongs to `qemu-img`): adding it makes the command fail.
    ```cmd
    create vdisk file="C:\path\to\disk.vhd" maximum=50000 type=fixed
    attach vdisk
    convert gpt
    create partition efi size=100
    ```
- **Partition Alignment**:
  - Do not pass `offset=` when creating partitions: `diskpart` aligns them by itself. An explicit `offset=1` (1 KB) falls inside the GPT header area and is refused (`There is not enough usable space for this operation`).
  - Verify alignment with `list part` in `diskpart`.
- **Missing Windows Installation**:
  - If `bootrec /scanos` doesn’t detect Windows, ensure the Windows partition is assigned a letter and contains `Windows\System32`.
- **UEFI vs. BIOS Mismatch**:
  - Check your system’s firmware settings in the BIOS/UEFI setup to ensure the correct boot mode (UEFI or Legacy).
  - Use `/f UEFI` for UEFI systems or `/f BIOS` for Legacy systems with `bcdboot`.
- **Data Loss from Formatting**:
  - Always use `list disk` and `list part` to confirm you are formatting the correct partition (e.g., ESP or system partition).
  - Incorrectly formatting the Windows or data partition will result in data loss. Back up critical data before proceeding.

### Additional Tips
- **Backup BCD**: Before modifying the BCD, export it:
  ```cmd
  bcdedit /export C:\BCD_Backup
  ```
- **Verify Disk Layout**: Use `diskpart`’s `list disk` and `list part` to confirm the correct disk and partition layout before any changes.
- **Test Boot**: After repairs, reboot and test. If issues persist, check firmware settings or re-run `bootrec` commands.

## Next Steps

In future tutorials, we’ll explore:
- Advanced BCD editing with `bcdedit`.
- Windows recovery using System Restore and Safe Mode.
- Automating Windows repairs with PowerShell scripts.

## Resources
- [Microsoft Bootrec Documentation](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/bootrec)
- [Microsoft BCDboot Documentation](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/bcdboot-command-line-options-techref-di)
- [Windows Recovery Environment](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-recovery-environment--windows-re--technical-reference)

---

*Practice these commands in a test environment to master Windows boot repair, and always verify partitions to avoid data loss!*