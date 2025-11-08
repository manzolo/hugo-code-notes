---
title: "Manzolo PPA (My Own Ubuntu Repository)"
date: 2025-11-08T18:30:00+02:00
lastmod: 2025-11-08T18:30:00+02:00
draft: false
author: "Manzolo"
tags: ["ubuntu", "docker", "repository", "packaging", "apt"]
categories: ["linux"]
series: ["Docker"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Manzolo PPA — My Personal Ubuntu Repository

**Install my tools directly with `apt`!**  
Secure, GPG-signed repository hosted at **https://ubuntu-repo.manzolo.it**

**Ubuntu 24.04 (noble) — FULLY SUPPORTED**

```bash
wget -qO - https://ubuntu-repo.manzolo.it/KEY.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/manzolo-repo.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/manzolo-repo.gpg] https://ubuntu-repo.manzolo.it noble main" | sudo tee /etc/apt/sources.list.d/manzolo-repo.list
sudo apt update
```

## Install my packages

# manzolo-chroot package
```bash
sudo apt install manzolo-chroot
```
# Search all my tools
```bash
apt search manzolo
```

## Verify everything works
```bash
apt policy | grep manzolo
```

## Remove the repository (if you ever want to)
```bash
sudo rm /etc/apt/sources.list.d/manzolo-repo.list
sudo rm /etc/apt/trusted.gpg.d/manzolo-repo.gpg
sudo apt update
```