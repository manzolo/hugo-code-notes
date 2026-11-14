---
title: "Guida ai comandi Linux per sysadmin"
url: "bash/linux/"
#description: ""
date: 2025-09-26T10:00:00+01:00
lastmod: 2025-09-26T10:00:00+01:00
draft: false
author: "Manzolo"
tags: ["linux", "bash", "commands", "system-administration", "reference"]
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

# Guida ai comandi Linux per sysadmin

## Introduzione

Per un amministratore di sistema Linux, padroneggiare i comandi essenziali è indispensabile per gestire i server, monitorare i sistemi e risolvere i problemi. Questa guida raccoglie i comandi Linux fondamentali per l'amministrazione di sistema: gestione degli utenti, controllo dei processi, diagnostica di rete e monitoraggio del sistema, con esempi pratici.

## Prerequisiti

- Un sistema Linux (per esempio Ubuntu, CentOS o Debian).
- Privilegi di root o sudo.
- Un minimo di familiarità con il terminale.

## Informazioni di sistema

### Panoramica di hardware e sistema

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

### Uptime e carico del sistema

```bash
# Display system uptime and load average
uptime

# Show load average
cat /proc/loadavg

# Interactive system monitoring
top
htop  # If installed
```

## Gestione di utenti e gruppi

### Gestire gli utenti

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

### Gestire i gruppi

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

### Esempio: creare un utente con permessi specifici

Crea un utente `devuser` con i privilegi sudo:

```bash
sudo useradd -m -s /bin/bash devuser
sudo passwd devuser
sudo usermod -aG sudo devuser
```

- **Spiegazione**: crea `devuser` con la sua home directory, imposta una password e lo aggiunge al gruppo `sudo`.

## Gestione dei processi

### Vedere i processi

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

### Controllare i processi

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

### Esempio: tenere d'occhio i processi che consumano CPU

Trova e gestisci i processi che usano più CPU:

```bash
# List top 5 CPU-consuming processes
ps aux --sort=-%cpu | head -n 6

# Kill a high-CPU process (replace PID)
kill -9 PID
```

## Gestione di file e permessi

### Operazioni sui file

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

### Permessi e proprietà

```bash
# Change file permissions
chmod 644 file.txt  # rw-r--r--
chmod -R 755 directory/  # rwx-r-xr-x

# Change file ownership
chown user:group file.txt
chown -R user:group directory/
```

### Esempio: mettere in sicurezza una directory

Proteggi una directory riservandola a un utente specifico:

```bash
sudo mkdir /data
sudo chown devuser:devuser /data
sudo chmod 700 /data
```

- **Spiegazione**: crea `/data`, la assegna a `devuser` e limita l'accesso al solo proprietario.

## Gestione della rete

### Diagnostica di rete

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

### Gestione del firewall (UFW)

```bash
# Enable UFW
sudo ufw enable

# Allow specific port
sudo ufw allow 22/tcp

# Check UFW status
sudo ufw status
```

### Esempio: controllare le porte aperte

Elenca le porte aperte e verifica la connettività:

```bash
sudo netstat -tuln
curl http://localhost:80  # Test web server
```

## Gestione di dischi e storage

### Uso del disco

```bash
# Show disk usage
df -h

# Detailed disk usage for current directory
du -sh * | sort -h

# Find files larger than 100MB
find / -type f -size +100M -exec du -sh {} +
```

### Gestione delle partizioni

```bash
# List block devices
lsblk

# Check disk partitions
sudo fdisk -l

# Format a new partition (e.g., /dev/sdb1)
sudo mkfs.ext4 /dev/sdb1
```

### Esempio: monitorare lo spazio su disco

Crea uno script che controlla l'uso del disco:

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

Rendilo eseguibile:

```bash
chmod +x monitor_disk.sh
./monitor_disk.sh
```

## Gestione dei pacchetti (Ubuntu/Debian)

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

## Gestione dei log

### Consultare i log

```bash
# View system logs
sudo journalctl

# View logs for a specific service
sudo journalctl -u sshd

# Follow logs in real-time
sudo journalctl -f
```

### Esempio: controllare i tentativi di accesso falliti

Tieni d'occhio i tentativi di accesso SSH falliti:

```bash
sudo journalctl -u sshd | grep "Failed password"
```

## Uno script pratico

Crea uno script che esegue i controlli di routine del sysadmin:

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

Rendilo eseguibile:

```bash
chmod +x sysadmin_check.sh
./sysadmin_check.sh
```

## Consigli pratici

{{< callout type="tip" >}}
**Suggerimento**: usa `htop` per vedere i processi in modo più comodo:
```bash
sudo apt install htop
htop
```
{{< /callout >}}

{{< callout type="warning" >}}
**Attenzione**: vai cauto con comandi come `rm -rf` o `kill -9`: usati male possono causare perdita di dati o instabilità del sistema.
{{< /callout >}}

{{< callout type="success" title="Quick Reference" >}}
**Scorciatoie essenziali:**
- `Ctrl+C`: interrompe un comando.
- `Ctrl+Z`: sospende un comando.
- `sudo !!`: riesegue l'ultimo comando con sudo.
- `watch -n 5 command`: esegue un comando ogni 5 secondi.
{{< /callout >}}

## Risoluzione dei problemi

- **Permission denied**: verifica i privilegi sudo o il proprietario del file (`ls -l`).
- **Un servizio non parte**: controlla i log con `journalctl -u service_name`.
- **Uso elevato di CPU/memoria**: usa `top` o `htop` per individuare i processi che consumano più risorse.
- **Problemi di rete**: usa `ping`, `traceroute` o `ss` per diagnosticare i problemi di connettività.

## Prossimi passi

Nei prossimi tutorial vedremo:
- Come automatizzare le attività con i cron job.
- Come configurare SSH per un accesso remoto sicuro.
- Come installare strumenti di monitoraggio come Nagios o Prometheus.
- Come gestire i container con Docker o Podman.

## Esercizi

1. **Configurazione di un utente**: crea un utente con accesso sudo e limita il suo login SSH a un IP specifico.
2. **Monitoraggio dei processi**: scrivi uno script che avvisa se l'uso della CPU supera l'80%.
3. **Pulizia del disco**: trova ed elimina i file più vecchi di 30 giorni in `/tmp`.
4. **Analisi di rete**: monitora le porte aperte e registra i tentativi di connessione non autorizzati.

## Risorse

- [Pagine man di Linux](https://man7.org/linux/man-pages/)
- [Guida di Ubuntu Server](https://ubuntu.com/server/docs)
- [Le basi della riga di comando Linux](https://www.digitalocean.com/community/tutorials/an-introduction-to-linux-basics)
- [Pagine TLDR](https://tldr.sh/)

---

*Esercitati con questi comandi per diventare un sysadmin Linux capace!*
