---
title: "Uncomplicated Firewall"
#description: ""
date: 2025-09-26T10:00:00+01:00
lastmod: 2025-09-26T10:00:00+01:00
draft: false
author: "Manzolo"
tags: ["ufw", "firewall", "security", "iptables", "ubuntu"]
categories: ["Command Reference"]
series: ["Command Line Mastery"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Ubuntu UFW Firewall Guide

## Introduction

UFW (Uncomplicated Firewall) is a user-friendly interface for managing iptables firewall rules on Ubuntu systems. It simplifies the process of configuring firewall settings, making it accessible for beginners and efficient for advanced users. This guide covers essential UFW commands, practical examples, and tips for securing your Ubuntu server.

## What is UFW?

UFW is a front-end for iptables, designed to make firewall configuration straightforward. It allows you to manage inbound and outbound network traffic by defining rules based on ports, protocols, and IP addresses.

## Prerequisites

- Ubuntu system with UFW installed (`ufw` is included by default in Ubuntu).
- Root or sudo privileges.
- Basic understanding of network protocols (TCP/UDP) and ports.

Verify UFW installation:

```bash
ufw version
```

If not installed, install it:

```bash
sudo apt update
sudo apt install ufw
```

## Basic UFW Commands

### Enabling and Disabling UFW

```bash
# Enable UFW (warning: this may block all traffic unless rules are set)
sudo ufw enable

# Disable UFW
sudo ufw disable

# Check UFW status
sudo ufw status
```

### Setting Default Policies

Set default policies to define how to handle unspecified traffic:

```bash
# Deny all incoming traffic by default
sudo ufw default deny incoming

# Allow all outgoing traffic by default
sudo ufw default allow outgoing
```

### Managing Rules

```bash
# Allow a specific port (e.g., SSH on port 22)
sudo ufw allow 22

# Allow a specific protocol and port (e.g., HTTP on TCP port 80)
sudo ufw allow 80/tcp

# Deny a specific port
sudo ufw deny 23

# Delete a rule
sudo ufw delete allow 80/tcp

# Reset UFW to default (removes all rules)
sudo ufw reset
```

## Common Examples

### Example 1: Securing a Web Server

Allow HTTP (port 80), HTTPS (port 443), and SSH (port 22) for a web server:

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

- **Explanation**:
  - `22/tcp`: Allows SSH for remote access.
  - `80/tcp`: Allows HTTP for web traffic.
  - `443/tcp`: Allows HTTPS for secure web traffic.
- **Verification**: Run `sudo ufw status` to confirm the rules.

### Example 2: Restricting SSH to a Specific IP

Allow SSH only from a specific IP address (e.g., `192.168.1.100`):

```bash
sudo ufw allow from 192.168.1.100 to any port 22
sudo ufw enable
```

- **Explanation**:
  - `from 192.168.1.100`: Restricts SSH access to this IP.
  - `to any port 22`: Applies the rule to port 22 on the server.
- **Usage**: Only the specified IP can connect via SSH.

### Example 3: Allowing a Range of Ports

Allow a range of ports (e.g., for a custom application on ports 3000–3010):

```bash
sudo ufw allow 3000:3010/tcp
sudo ufw enable
```

- **Explanation**:
  - `3000:3010/tcp`: Allows TCP traffic on ports 3000 to 3010.
- **Usage**: Useful for applications like Node.js or custom services.

### Example 4: Allowing a Service by Name

UFW supports service names defined in `/etc/services`:

```bash
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw enable
```

- **Explanation**:
  - `ssh`, `http`, `https`: Maps to ports 22, 80, and 443, respectively.
- **Usage**: Simplifies rule creation for common services.

## Advanced UFW Commands

### Allowing Specific IP Ranges

Allow traffic from a subnet (e.g., `192.168.1.0/24`):

```bash
sudo ufw allow from 192.168.1.0/24 to any port 80
```

### Rate-Limiting SSH

Prevent brute-force attacks by limiting SSH connections:

```bash
sudo ufw limit 22/tcp
```

- **Explanation**: Limits connections to 6 per 30 seconds from a single IP.

### Logging

Enable logging to monitor firewall activity:

```bash
sudo ufw logging on
sudo ufw logging low  # Options: off, low, medium, high, full
```

View logs in `/var/log/ufw.log` or with:

```bash
sudo cat /var/log/ufw.log
```

## Practical Script

Create a script to configure a basic UFW setup for a web server:

```bash
#!/bin/bash
# configure_ufw.sh

echo "=== Configuring UFW ==="
echo "Setting default policies..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "Allowing essential services..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

echo "Enabling UFW..."
sudo ufw enable

echo "Current UFW status:"
sudo ufw status
```

Make it executable:

```bash
chmod +x configure_ufw.sh
./configure_ufw.sh
```

## Pro Tips

{{< callout type="tip" >}}
**Tip**: Always allow SSH (port 22) before enabling UFW on a remote server to avoid locking yourself out.
```bash
sudo ufw allow ssh
```
{{< /callout >}}

{{< callout type="warning" >}}
**Warning**: Enabling UFW with a default deny policy without allowing SSH can block remote access. Test rules locally or ensure SSH access first.
{{< /callout >}}

{{< callout type="success" title="Quick Reference" >}}
**Essential commands:**
- `sudo ufw enable`: Activate the firewall.
- `sudo ufw status verbose`: Detailed status output.
- `sudo ufw app list`: List available application profiles.
- `sudo ufw reset`: Reset to default (use with caution).
{{< /callout >}}

## Troubleshooting

- **Locked Out via SSH**: If you lose SSH access, access the server via a console (e.g., cloud provider dashboard) and disable UFW (`sudo ufw disable`).
- **Service Not Accessible**: Verify rules with `sudo ufw status` and ensure the correct port/protocol is allowed.
- **Logs Not Showing**: Check if logging is enabled (`sudo ufw logging on`) and verify the log file (`/var/log/ufw.log`).
- **Application Profiles**: Use `sudo ufw app list` to check for predefined profiles (e.g., for Nginx or Apache).

## Next Steps

In future tutorials, we’ll cover:
- Advanced iptables rules for complex scenarios.
- Configuring UFW with Docker containers.
- Setting up intrusion detection with tools like Fail2Ban.
- Monitoring network traffic with `tcpdump`.

## Practice Exercises

1. **Basic Setup**: Configure UFW to allow SSH, HTTP, and HTTPS, then verify the rules.
2. **Restricted Access**: Allow SSH only from a specific IP range and test connectivity.
3. **Rate Limiting**: Apply rate-limiting to a custom port and simulate multiple connections.
4. **Log Analysis**: Enable logging and analyze blocked traffic in `/var/log/ufw.log`.

## Resources

- [UFW Manual](https://manpages.ubuntu.com/manpages/focal/man8/ufw.8.html)
- [Ubuntu UFW Guide](https://help.ubuntu.com/community/UFW)
- [Linux Firewall Tutorial](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-with-ufw-on-ubuntu)

---

*Practice configuring UFW rules to secure your server effectively!*