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
sel disk 0  # Verify this is the correct disk
list part   # Confirm partition layout (ESP is typically 100-300 MB, FAT32)

# Select EFI System Partition (ESP) - FAT32
sel part 1  # Verify this is the ESP
format quick fs=fat32
assign letter=s

# Select Windows Partition
sel part 3  # Verify this is the Windows partition
assign letter=c
exit
```

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

#### Manual EFI Partition Creation
If the ESP is missing, create one:

```cmd
diskpart
list disk
sel disk 0  # Verify this is the correct disk

# Create EFI partition (100MB)
create partition efi size=100 offset=1
format quick fs=fat32 label="System"
assign letter=S

# Create Microsoft Reserved (MSR) partition (128MB)
create partition msr size=128 offset=103424
exit
```

- **Explanation**:
  - `list disk`: Confirms the correct disk.
  - `create partition efi size=100 offset=1`: Creates a 100 MB EFI partition with a 1 KB offset for alignment.
  - `format quick fs=fat32 label="System"`: Formats the partition as FAT32 with a "System" label.
  - `create partition msr size=128 offset=103424`: Creates a 128 MB Microsoft Reserved partition (required for UEFI).
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
sel disk 0  # Verify this is the correct disk
list part   # Confirm partition layout (system partition is typically 100-500 MB)

# System partition - FAT32 or NTFS
sel part 1  # Verify this is the system partition
format quick fs=fat32
assign letter=s

# Windows partition
sel part 3  # Verify this is the Windows partition
assign letter=c
exit

# Rebuild boot configuration for all firmware types
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
  - When creating partitions for virtual hard disks (VHDs), use `subformat=fixed,force_size` in `diskpart` for better compatibility:
    ```cmd
    create vdisk file="C:\path\to\disk.vhd" maximum=50000 type=fixed
    attach vdisk
    create partition efi size=100 offset=1 subformat=fixed,force_size
    ```
- **Partition Alignment**:
  - Use proper offsets (e.g., `offset=1` for EFI, `offset=103424` for MSR) to align partitions for optimal performance.
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