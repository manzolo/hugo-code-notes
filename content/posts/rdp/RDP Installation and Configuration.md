---
title: "RDP Installation and Configuration Guide (Debian/Ubuntu)"
date: 2025-10-04T00:26:00+02:00
lastmod: 2026-11-14T21:00:00+01:00
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
description: "xrdp and XFCE on Debian/Ubuntu: the two lines that decide the desktop and the encryption, both failing silently, and how to keep port 3389 closed"
---

# RDP Installation and Configuration Guide (Debian/Ubuntu)

{{< callout type="info" >}}
**Use case**: reach the graphical desktop of a Linux machine from Windows (Remote Desktop), macOS or another Linux, with xrdp and XFCE. Tested on 2026-11-14 with xrdp 0.9.24 on Ubuntu 24.04: the log lines and the screenshot below come from that machine.
{{< /callout >}}

## 🧭 Two lines decide everything

An xrdp setup works or fails on two details, and both fail **silently**:

| Line | Decides | If it is missing |
|------|---------|------------------|
| `~/.xsession` | **which desktop** the RDP session starts | you get the system's default desktop |
| `adduser xrdp ssl-cert` | **whether the connection is encrypted with TLS** | it still connects, with the old RDP security instead of TLS |

Everything else is installing packages.

## 📦 Install

```bash
sudo apt update
sudo apt install xrdp xfce4 xfce4-goodies
```

On the test machine these three packages were enough: `xorgxrdp` (the X server for RDP sessions) comes with `xrdp`. No `ubuntu-desktop` is needed, and on Debian it does not exist.

## 🖥️ Choose the desktop: `~/.xsession`

```bash
# As the user who will connect over RDP, not as root
echo xfce4-session > ~/.xsession
```

At login xrdp runs `/etc/xrdp/startwm.sh`, which hands over to `/etc/X11/Xsession`, which reads `~/.xsession`. It is a **per-user** file: each user who connects over RDP needs their own.

What happened in the test, three variants:

| `exec startxfce4` in `xrdp.ini` | `~/.xsession` | Desktop that started |
|---|---|---|
| yes | yes | XFCE |
| no | yes | XFCE |
| yes | no | LXQt (the machine's default) |

So the line that many guides (this one included, in its first version) append to `/etc/xrdp/xrdp.ini` does nothing: that file is an INI file, not a script.

![XFCE desktop served over RDP, seen from the client window](/images/rdp-xfce-session.png "The XFCE session of user demo, opened with an RDP client")

## 🔒 TLS: the `ssl-cert` group

xrdp runs as the user `xrdp` and uses the system's "snakeoil" certificate, whose key sits in `/etc/ssl/private`: readable only by root and by the `ssl-cert` group. In the test, right after the installation `xrdp` was **not** in that group, and every connection went like this:

```text
[ERROR] Cannot read private key file /etc/xrdp/key.pem: Permission denied
[WARN ] Cannot accept TLS connections because certificate or private key file is not readable. ...
[INFO ] Security protocol: configured [RDP], requested [SSL|HYBRID|RDP], selected [RDP]
```

The client connected anyway. Nothing on screen says that TLS is off. After:

```bash
sudo adduser xrdp ssl-cert
sudo systemctl restart xrdp
```

the same connection reads:

```text
[INFO ] Security protocol: configured [SSL|RDP], requested [SSL|HYBRID|RDP], selected [SSL]
[INFO ] TLS connection established from ::ffff:127.0.0.1 port 39446: TLSv1.3 with cipher TLS_AES_256_GCM_SHA384
```

To check yours, connect once and then:

```bash
sudo grep -E "Security protocol|TLS connection|private key" /var/log/xrdp.log | tail -3
```

## 🔥 Do not leave port 3389 open to the world

The best way is not to open it at all and go through SSH, which you probably already have:

```bash
# On the client: local port 13389 -> port 3389 of the server, inside SSH
ssh -N -L 13389:localhost:3389 user@server

# Then point the RDP client at localhost:13389
```

In the test xrdp saw the session arrive from `127.0.0.1`, the far end of the tunnel, with TLS on top: two layers of encryption, and only port 22 exposed. (Port 13389 avoids a clash with 3389 on a Windows client that has its own Remote Desktop on.)

If it must be reachable directly, limit it to the local network:

```bash
# Only from the local network, never from everywhere
sudo ufw allow from 192.168.1.0/24 to any port 3389 proto tcp
sudo ufw status
```

## 📜 Everything in one script

```bash
#!/bin/bash
# Run as the user who will connect over RDP (sudo is used where needed)
set -e
sudo apt update -qq
sudo apt install -y -qq xrdp xfce4 xfce4-goodies
sudo adduser xrdp ssl-cert
echo xfce4-session > ~/.xsession
sudo systemctl restart xrdp
echo "Connect with an RDP client to $(hostname -I | awk '{print $1}'):3389"
```

## 🪤 Traps, in one table

| Symptom | Cause |
|---------|-------|
| The RDP session opens a different desktop | No `~/.xsession` for **that** user |
| `Cannot read private key file /etc/xrdp/key.pem` in the log | `xrdp` not in `ssl-cert`: the connection works, without TLS |
| `exec startxfce4` in `xrdp.ini` "does not work" | It never did: the desktop is chosen by `~/.xsession` |
| `~/.xsession` owned by root | Created with `sudo tee`: create it as the user |
| Port 3389 reachable from the internet | Use the SSH tunnel, or `ufw allow from <your LAN>` |

## 📚 Resources

- [xrdp](https://www.xrdp.org/) and its [wiki on GitHub](https://github.com/neutrinolabs/xrdp/wiki)
- [Arch Wiki: xrdp](https://wiki.archlinux.org/title/Xrdp)
- [SSH Forward Tunneling](/bash/ssh-forward-tunneling/) - more on `ssh -L`
