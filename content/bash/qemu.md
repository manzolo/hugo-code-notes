---
title: "QEMU Disk Image and VM Management Guide"
#description: ""
date: 2025-09-26T10:00:00+01:00
lastmod: 2025-09-26T10:00:00+01:00
draft: false
author: "Manzolo"
tags: ["bash", "linux", "terminal", "commands", "tutorial"]
categories: ["bash", "tutorial", "virtualization"]
series: ["Qemu"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# QEMU Disk Image and VM Management Guide

## Introduction

QEMU is a powerful open-source emulator and virtualizer for running virtual machines (VMs) and managing disk images on Linux systems. It supports a wide range of architectures and provides tools for creating, manipulating, and running VMs with flexible configurations. This guide covers essential QEMU commands for disk image management and VM operations, with practical examples for system administrators and developers.

## Prerequisites

- QEMU installed on a Linux system (`qemu-system-x86_64 --version` to verify).
- Root or sudo privileges for certain operations (e.g., installing QEMU or accessing KVM).
- Basic understanding of Linux terminal commands and virtualization concepts.

Install QEMU on Ubuntu/Debian:

```bash
sudo apt update
sudo apt install qemu qemu-system qemu-utils
```

For KVM acceleration (recommended for better performance):

```bash
sudo apt install qemu-kvm
```

Verify KVM support:

```bash
kvm-ok
```

## Disk Image Management

QEMU uses `qemu-img` to create, convert, and manage disk images for VMs. Common formats include `qcow2` (copy-on-write, efficient) and `raw`.

### Creating Disk Images

```bash
# Create a 20GB qcow2 disk image
qemu-img create -f qcow2 disk.qcow2 20G

# Create a 10GB raw disk image
qemu-img create -f raw disk.raw 10G
```

- **Explanation**:
  - `-f qcow2`: Specifies the disk format (qcow2 supports snapshots and compression).
  - `disk.qcow2`: Output file name.
  - `20G`: Disk size (supports K, M, G, T suffixes).

### Inspecting Disk Images

```bash
# Display image information
qemu-img info disk.qcow2

# Check image for errors
qemu-img check disk.qcow2
```

### Resizing Disk Images

```bash
# Increase disk size by 10GB
qemu-img resize disk.qcow2 +10G

# Shrink disk (only if unused space, requires check first)
qemu-img resize --shrink disk.qcow2 15G
```

### Converting Disk Images

```bash
# Convert qcow2 to raw format
qemu-img convert -f qcow2 -O raw disk.qcow2 disk.raw

# Convert raw to qcow2 with compression
qemu-img convert -f raw -O qcow2 -c disk.raw disk_compressed.qcow2
```

### Snapshots

```bash
# Create a snapshot in a qcow2 image
qemu-img snapshot -c snapshot1 disk.qcow2

# List snapshots
qemu-img snapshot -l disk.qcow2

# Revert to a snapshot
qemu-img snapshot -a snapshot1 disk.qcow2

# Delete a snapshot
qemu-img snapshot -d snapshot1 disk.qcow2
```

### Example: Creating and Inspecting a Disk Image

Create a 30GB qcow2 image and check its details:

```bash
qemu-img create -f qcow2 ubuntu-vm.qcow2 30G
qemu-img info ubuntu-vm.qcow2
```

- **Output** (example):
  ```
  image: ubuntu-vm.qcow2
  file format: qcow2
  virtual size: 30 GiB
  disk size: 196 KiB
  ```

## Virtual Machine Management

QEMU's `qemu-system-*` commands (e.g., `qemu-system-x86_64`) are used to launch and manage VMs.

### Basic VM Launch

Run a VM with a disk image and an ISO file:

```bash
qemu-system-x86_64 \
  -m 2G \
  -hda ubuntu-vm.qcow2 \
  -cdrom ubuntu-24.04.iso \
  -boot d \
  -enable-kvm
```

- **Explanation**:
  - `-m 2G`: Allocates 2GB of RAM.
  - `-hda`: Specifies the primary disk image.
  - `-cdrom`: Attaches an ISO for installation.
  - `-boot d`: Boots from the CD-ROM.
  - `-enable-kvm`: Enables KVM for hardware acceleration.

### Networking

```bash
# User-mode networking (NAT)
qemu-system-x86_64 -m 2G -hda ubuntu-vm.qcow2 -netdev user,id=net0 -device virtio-net,netdev=net0

# Bridge networking (requires setup)
qemu-system-x86_64 -m 2G -hda ubuntu-vm.qcow2 -netdev bridge,id=net0,br=br0 -device virtio-net,netdev=net0
```

- **Note**: Bridge networking requires a configured network bridge (e.g., `br0`) on the host.

### CPU and Memory

```bash
# Specify 4 CPU cores and 4GB RAM
qemu-system-x86_64 -m 4G -smp 4 -hda ubuntu-vm.qcow2 -enable-kvm
```

- **Explanation**:
  - `-smp 4`: Allocates 4 CPU cores.
  - `-m 4G`: Allocates 4GB of RAM.

### Example: Running a VM with VNC

Launch a VM with VNC access for remote GUI:

```bash
qemu-system-x86_64 \
  -m 2G \
  -hda ubuntu-vm.qcow2 \
  -vnc :1 \
  -enable-kvm
```

- **Usage**: Connect to the VM using a VNC client (e.g., `vncviewer localhost:5901`).

### Example: Installing an OS

Boot from an ISO to install Ubuntu:

```bash
qemu-system-x86_64 \
  -m 4G \
  -smp 2 \
  -hda ubuntu-vm.qcow2 \
  -cdrom ubuntu-24.04.iso \
  -boot d \
  -vnc :1 \
  -enable-kvm
```

- **Explanation**: Boots from the ISO, allocates 4GB RAM and 2 CPUs, and provides VNC access.

## Practical Script

Create a script to manage a QEMU VM and disk image:

```bash
#!/bin/bash
# manage_qemu.sh

echo "=== QEMU VM Management ==="
echo "Current directory: $(pwd)"
echo ""

# Create disk image if it doesn't exist
if [ ! -f ubuntu-vm.qcow2 ]; then
  echo "Creating disk image..."
  qemu-img create -f qcow2 ubuntu-vm.qcow2 20G
fi

echo "Disk image info:"
qemu-img info ubuntu-vm.qcow2
echo ""

echo "Starting VM..."
qemu-system-x86_64 \
  -m 2G \
  -smp 2 \
  -hda ubuntu-vm.qcow2 \
  -netdev user,id=net0 -device virtio-net,netdev=net0 \
  -enable-kvm &

echo "VM started in background. Connect via VNC (port 5900) if enabled."
```

Make it executable:

```bash
chmod +x manage_qemu.sh
./manage_qemu.sh
```

## Pro Tips

{{< callout type="tip" >}}
**Tip**: Use `qcow2` for disk images to save space and enable snapshots. Enable KVM (`-enable-kvm`) for better performance on supported hardware.
```bash
qemu-system-x86_64 -enable-kvm -m 2G -hda disk.qcow2
```
{{< /callout >}}

{{< callout type="warning" >}}
**Warning**: Running QEMU without KVM acceleration is significantly slower. Ensure KVM is enabled and your CPU supports virtualization (check with `kvm-ok`).
{{< /callout >}}

{{< callout type="success" title="Quick Reference" >}}
**Essential commands:**
- `qemu-img create`: Create a new disk image.
- `qemu-system-x86_64`: Launch a VM.
- `qemu-img snapshot`: Manage disk snapshots.
- `virtio` drivers: Use for better performance (e.g., `-device virtio-net`).
{{< /callout >}}

## Troubleshooting

- **KVM Not Working**: Ensure KVM modules are loaded (`lsmod | grep kvm`) and your user is in the `kvm` group (`sudo usermod -aG kvm $USER`).
- **Disk Image Errors**: Use `qemu-img check` to diagnose and repair issues.
- **VM Won't Boot**: Verify the disk image, ISO, or boot order (`-boot`).
- **Network Issues**: Check network configuration with `ip addr` or ensure the correct `-netdev` settings.

## Next Steps

In future tutorials, we’ll cover:
- Advanced QEMU networking (e.g., TAP, bridge setups).
- Using `libvirt` with QEMU for easier VM management.
- Creating and managing VM snapshots.
- Automating VM deployment with scripts or Ansible.

## Practice Exercises

1. **Disk Management**: Create a 50GB qcow2 image, resize it to 60GB, and take a snapshot.
2. **VM Setup**: Launch a VM with 4GB RAM, 2 CPUs, and user-mode networking.
3. **OS Installation**: Install a Linux distro using an ISO and configure VNC access.
4. **Automation**: Write a script to start multiple VMs with different disk images.

## Resources

- [QEMU Documentation](https://www.qemu.org/docs/master/)
- [QEMU Wiki](https://wiki.qemu.org/Main_Page)
- [Ubuntu QEMU Guide](https://help.ubuntu.com/community/KVM)
- [Red Hat Virtualization Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_virtualization)

---

*Practice QEMU commands to master disk image and VM management!*