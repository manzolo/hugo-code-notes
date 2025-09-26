---
title: "Linux Sysadmin Commands Guide"
#description: ""
date: 2025-09-26T10:00:00+01:00
lastmod: 2025-09-26T10:00:00+01:00
draft: false
author: "Manzolo"
tags: ["bash", "linux", "terminal", "commands", "tutorial"]
categories: ["bash", "tutorial", "linux"]
series: ["SysAdmin"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Linux Sysadmin Commands Guide

## Introduction

As a Linux system administrator, mastering essential commands is crucial for managing servers, monitoring systems, and troubleshooting issues. This guide covers fundamental Linux commands for system administration, focusing on user management, process control, network diagnostics, and system monitoring, with practical examples.

## Prerequisites

- A Linux system (e.g., Ubuntu, CentOS, or Debian).
- Root or sudo privileges.
- Basic familiarity with the terminal.

## System Information

### Hardware and System Overview

```bash
# Display system information
uname -a

# Show CPU details
lscpu
cat /proc/cpuinfo

# Display memory usage
free -h
cat /proc/meminfo

# List block devices (disks)
lsblk
fdisk -l  # Requires sudo

# Show mounted filesystems
df -h
```

### System Uptime and Load

```bash
# Display system uptime and load average
uptime

# Show load average
cat /proc/loadavg

# Interactive system monitoring
top
htop  # If installed
```

## User and Group Management

### Managing Users

```bash
# Add a new user
sudo useradd -m -s /bin/bash username

# Set a password for the user
sudo passwd username

# Modify user details
sudo usermod -aG groupname username  # Add user to a group
sudo usermod -s /bin/zsh username    # Change shell

# Delete a user
sudo userdel -r username  # Remove user and home directory
```

### Managing Groups

```bash
# Create a new group
sudo groupadd groupname

# Add user to a group
sudo usermod -aG groupname username

# List groups
getent group

# Delete a group
sudo groupdel groupname
```

### Example: Creating a User with Specific Permissions

Create a user `devuser` with sudo privileges:

```bash
sudo useradd -m -s /bin/bash devuser
sudo passwd devuser
sudo usermod -aG sudo devuser
```

- **Explanation**: Creates `devuser` with a home directory, sets a password, and adds them to the `sudo` group.

## Process Management

### Viewing Processes

```bash
# List all processes
ps aux
ps -ef

# Interactive process viewer
top
htop

# Display process tree
pstree
```

### Controlling Processes

```bash
# Kill a process by PID
kill PID

# Kill a process by name
killall process_name
pkill process_name

# Run a process in the background
command &

# List background jobs
jobs

# Bring job to foreground
fg %1
```

### Example: Monitoring High-CPU Processes

Find and manage high-CPU processes:

```bash
# List top 5 CPU-consuming processes
ps aux --sort=-%cpu | head -n 6

# Kill a high-CPU process (replace PID)
kill -9 PID
```

## File and Permissions Management

### File Operations

```bash
# List files with details
ls -la

# Copy files or directories
cp file.txt /destination/
cp -r directory/ /destination/

# Move or rename files
mv file.txt newfile.txt

# Remove files or directories
rm file.txt
rm -rf directory/
```

### Permissions and Ownership

```bash
# Change file permissions
chmod 644 file.txt  # rw-r--r--
chmod -R 755 directory/  # rwx-r-xr-x

# Change file ownership
chown user:group file.txt
chown -R user:group directory/
```

### Example: Securing a Directory

Secure a directory for a specific user:

```bash
sudo mkdir /data
sudo chown devuser:devuser /data
sudo chmod 700 /data
```

- **Explanation**: Creates `/data`, assigns it to `devuser`, and restricts access to the owner only.

## Network Management

### Network Diagnostics

```bash
# Check network interfaces
ip addr
ifconfig  # If available

# Test connectivity
ping google.com

# Display network connections
netstat -tuln  # List listening ports
ss -tuln

# Trace route to a host
traceroute google.com
```

### Firewall Management (UFW)

```bash
# Enable UFW
sudo ufw enable

# Allow specific port
sudo ufw allow 22/tcp

# Check UFW status
sudo ufw status
```

### Example: Checking Open Ports

List open ports and verify connectivity:

```bash
sudo netstat -tuln
curl http://localhost:80  # Test web server
```

## Disk and Storage Management

### Disk Usage

```bash
# Show disk usage
df -h

# Detailed disk usage for current directory
du -sh * | sort -h

# Find files larger than 100MB
find / -type f -size +100M -exec du -sh {} +
```

### Partition Management

```bash
# List block devices
lsblk

# Check disk partitions
sudo fdisk -l

# Format a new partition (e.g., /dev/sdb1)
sudo mkfs.ext4 /dev/sdb1
```

### Example: Monitoring Disk Space

Create a script to check disk usage:

```bash
#!/bin/bash
# monitor_disk.sh

echo "=== Disk Usage Report ==="
echo "Current directory: $(pwd)"
echo ""

echo "Disk space usage:"
df -h /

echo ""
echo "Top 5 largest directories:"
du -sh /home/* | sort -hr | head -n 5
```

Make it executable:

```bash
chmod +x monitor_disk.sh
./monitor_disk.sh
```

## Package Management (Ubuntu/Debian)

```bash
# Update package lists
sudo apt update

# Upgrade installed packages
sudo apt upgrade

# Install a package
sudo apt install package_name

# Remove a package
sudo apt remove package_name

# Clean up unused packages
sudo apt autoremove
```

## Log Management

### Viewing Logs

```bash
# View system logs
sudo journalctl

# View logs for a specific service
sudo journalctl -u sshd

# Follow logs in real-time
sudo journalctl -f
```

### Example: Checking Failed Login Attempts

Monitor failed SSH login attempts:

```bash
sudo journalctl -u sshd | grep "Failed password"
```

## Practical Script

Create a script to perform routine sysadmin tasks:

```bash
#!/bin/bash
# sysadmin_check.sh

echo "=== System Admin Check ==="
echo "Date: $(date)"
echo ""

echo "System Uptime:"
uptime

echo ""
echo "Disk Usage:"
df -h /

echo ""
echo "Top 5 CPU Processes:"
ps aux --sort=-%cpu | head -n 6

echo ""
echo "Open Ports:"
ss -tuln

echo ""
echo "Checking for updates..."
sudo apt update
```

Make it executable:

```bash
chmod +x sysadmin_check.sh
./sysadmin_check.sh
```

## Pro Tips

{{< callout type="tip" >}}
**Tip**: Use `htop` for a more user-friendly process viewer:
```bash
sudo apt install htop
htop
```
{{< /callout >}}

{{< callout type="warning" >}}
**Warning**: Be cautious with commands like `rm -rf` or `kill -9`, as they can cause data loss or system instability if misused.
{{< /callout >}}

{{< callout type="success" title="Quick Reference" >}}
**Essential shortcuts:**
- `Ctrl+C`: Interrupt a command.
- `Ctrl+Z`: Suspend a command.
- `sudo !!`: Run the last command with sudo.
- `watch -n 5 command`: Run a command every 5 seconds.
{{< /callout >}}

## Troubleshooting

- **Permission Denied**: Verify sudo privileges or file ownership (`ls -l`).
- **Service Not Starting**: Check logs with `journalctl -u service_name`.
- **High CPU/Memory Usage**: Use `top` or `htop` to identify resource-heavy processes.
- **Network Issues**: Use `ping`, `traceroute`, or `ss` to diagnose connectivity problems.

## Next Steps

In future tutorials, we’ll cover:
- Automating tasks with cron jobs.
- Configuring SSH for secure remote access.
- Setting up monitoring tools like Nagios or Prometheus.
- Managing containers with Docker or Podman.

## Practice Exercises

1. **User Setup**: Create a user with sudo access and restrict their SSH login to a specific IP.
2. **Process Monitoring**: Write a script to alert if CPU usage exceeds 80%.
3. **Disk Cleanup**: Find and delete files older than 30 days in `/tmp`.
4. **Network Analysis**: Monitor open ports and log unauthorized connection attempts.

## Resources

- [Linux man pages](https://man7.org/linux/man-pages/)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)
- [Linux Command Line Basics](https://www.digitalocean.com/community/tutorials/an-introduction-to-linux-basics)
- [TLDR Pages](https://tldr.sh/)

---

*Practice these commands to become a proficient Linux sysadmin!*