---
title: "RDP Installation and Configuration Guide (Debian/Ubuntu)"
date: 2025-10-04T00:26:00+02:00
lastmod: 2025-10-04T00:26:00+02:00
draft: false
author: "Manzolo"
tags: ["rdp", "xrdp", "remote-desktop", "ubuntu", "installation"]
categories: ["Linux Administration"]
series: ["System Administration Basics"]
weight: 7
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# RDP Installation and Configuration Guide (Debian/Ubuntu)

## Introduction

Remote Desktop Protocol (RDP) enables remote access to a graphical desktop environment on a Linux system. XRDP is an open-source RDP server that allows connections from RDP clients (e.g., Windows Remote Desktop, Remmina) to a Debian/Ubuntu system. This guide explains how to install and configure XRDP with the XFCE desktop environment, a lightweight and efficient choice for remote desktops, on Debian/Ubuntu systems. It includes steps to set up a secure and functional RDP server for remote access.

## What is XRDP?

XRDP is an open-source implementation of the RDP protocol, allowing remote desktop connections to Linux systems. Key features include:
- **Cross-Platform Access**: Connect from Windows, macOS, or Linux clients.
- **XFCE Integration**: Lightweight desktop environment for smooth performance.
- **Security**: Supports SSL for encryption with proper configuration.
- **Multi-User Support**: Allows multiple simultaneous sessions.

This guide configures XRDP with XFCE for a minimal, efficient remote desktop experience.

## Prerequisites

- **Debian/Ubuntu**: Version 20.04+.
- **Packages**: `xrdp`, `xfce4`, `xfce4-goodies`, `ubuntu-desktop` (optional for full desktop dependencies).
- **Root Access**: Commands require `sudo`.
- **Network**: Open port 3389 (RDP default) on your firewall.
- **Client**: An RDP client (e.g., Microsoft Remote Desktop, Remmina).

Install prerequisites:
```bash
sudo apt update
sudo apt install -y curl
```

Verify network:
```bash
sudo ss -tuln | grep 3389  # Check if port 3389 is open
```

## Critical Warning: Secure Your Setup

{{< callout type="warning" >}}
**Caution**: Exposing RDP (port 3389) to the internet without proper security (e.g., strong passwords, firewall rules, or VPN) can lead to unauthorized access. Always configure a firewall (e.g., UFW) to restrict access and back up critical configurations (e.g., `/etc/xrdp/xrdp.ini`) before modifying. Test locally before opening to external networks.
{{< /callout >}}

## How to Install and Configure XRDP

### 1. Install XRDP and XFCE
Install the necessary packages for XRDP and the XFCE desktop environment.

```bash
sudo apt update
sudo apt install --no-install-recommends ubuntu-desktop
sudo apt install -y xfce4 xfce4-goodies xrdp
```

- `--no-install-recommends`: Minimizes dependencies for `ubuntu-desktop`.
- `xfce4-goodies`: Adds extra XFCE tools for a better experience.

### 2. Configure XRDP
Set XRDP to use XFCE as the default session.

```bash
echo "exec startxfce4" | sudo tee -a /etc/xrdp/xrdp.ini
echo xfce4-session > ~/.xsession
```

- `/etc/xrdp/xrdp.ini`: Configures XRDP to start XFCE.
- `~/.xsession`: Sets XFCE as the user’s session.

### 3. Add XRDP User to SSL Group
Grant XRDP access to SSL certificates for secure connections.

```bash
sudo adduser xrdp ssl-cert
```

### 4. Restart XRDP Service
Apply changes by restarting the XRDP service.

```bash
sudo systemctl restart xrdp
```

Verify the service is running:
```bash
sudo systemctl status xrdp
```

### 5. Configure Firewall
Allow RDP connections through port 3389.

```bash
sudo apt install -y ufw
sudo ufw allow 3389/tcp
sudo ufw enable
```

### 6. Test Remote Connection
- From a client (e.g., Windows Remote Desktop):
  - Enter the server’s IP address (e.g., `192.168.1.100:3389`).
  - Use your Linux username and password.
- Verify XFCE desktop loads remotely.

## Example

### Example: Full XRDP Setup
Run the following script to automate the entire process:

```bash
#!/bin/bash
echo "Installing RDP..."
sudo apt update -qqy > /dev/null
sudo apt install -qqy --no-install-recommends ubuntu-desktop > /dev/null
sudo apt install -qqy xfce4 xfce4-goodies xrdp > /dev/null
echo "exec startxfce4" | sudo tee -a /etc/xrdp/xrdp.ini > /dev/null
sudo adduser xrdp ssl-cert > /dev/null
sudo systemctl restart xrdp > /dev/null
echo xfce4-session | sudo tee /home/$(whoami)/.xsession > /dev/null
echo "XRDP installed and configured. Connect via RDP to $(hostname -I | awk '{print $1}'):3389"
```

Save as `install_xrdp.sh`, make executable, and run:
```bash
chmod +x install_xrdp.sh
./install_xrdp.sh
```

**Output** (example):
```
XRDP installed and configured. Connect via RDP to 192.168.1.100:3389
```

Connect using an RDP client to the server’s IP and port 3389.

## Command Breakdown

- **apt install xrdp xfce4**: Installs XRDP server and XFCE desktop.
- **echo "exec startxfce4" >> /etc/xrdp/xrdp.ini**: Configures XRDP to use XFCE.
- **adduser xrdp ssl-cert**: Grants SSL access for secure connections.
- **systemctl restart xrdp**: Restarts the XRDP service.
- **echo xfce4-session > ~/.xsession**: Sets XFCE as the session.

## Use Cases
- **Remote Administration**: Manage servers with a GUI remotely.
- **Workstation Access**: Access Linux desktops from Windows/macOS.
- **Development**: Use graphical IDEs over RDP.
- **Shared Desktops**: Multi-user access for collaborative work.

## Pro Tips
- **Secure with SSH**: Tunnel RDP over SSH for security:
  ```bash
  ssh -L 3389:localhost:3389 user@remote.host
  ```
  Connect to `localhost:3389` on the client.
- **Backup Configs**: Save `/etc/xrdp/xrdp.ini` and `~/.xsession`:
  ```bash
  sudo cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak
  cp ~/.xsession ~/.xsession.bak
  ```
- **Lightweight Alternative**: Use `xfce4` instead of heavier desktops (e.g., GNOME) for better performance.
- **Custom Port**: Change RDP port in `/etc/xrdp/xrdp.ini` (e.g., `port=3390`) and update firewall.
- **Performance**: Disable animations in XFCE settings for faster remote sessions.

{{< callout type="tip" >}}
**Tip**: Use `xfce4-panel --restart` if the XFCE panel doesn’t load correctly in RDP.
{{< /callout >}}

## Troubleshooting
- **RDP Connection Fails**: Check `sudo systemctl status xrdp` and ensure port 3389 is open (`sudo ss -tuln | grep 3389`).
- **Blank Screen**: Verify `~/.xsession` contains `xfce4-session` and restart XRDP.
- **Permission Issues**: Ensure `xrdp` user is in `ssl-cert` group (`groups xrdp`).
- **Slow Performance**: Switch to a lighter XFCE theme or reduce resolution in the RDP client.
- **Firewall Blocking**: Re-run `sudo ufw allow 3389/tcp` or check `ufw status`.

## Next Steps
In future tutorials, we’ll explore:
- Securing XRDP with TLS certificates.
- Multi-user RDP configurations.
- Integrating XRDP with Active Directory.

## Resources
- [XRDP Documentation](http://xrdp.org/)
- [Ubuntu XFCE Guide](https://ubuntu.com/server/docs/desktops)
- [Arch Wiki: XRDP](https://wiki.archlinux.org/title/XRDP)

---

*Set up XRDP with XFCE for a lightweight, secure remote desktop—test locally before exposing to the network!*