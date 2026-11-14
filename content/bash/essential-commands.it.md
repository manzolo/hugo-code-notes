---
title: "Comandi Bash essenziali - Gestione dei file e analisi del sistema"
url: "bash/essential-commands/"
description: "Impara i comandi Bash fondamentali per la gestione dei file e l'analisi del sistema che ogni sviluppatore dovrebbe conoscere"
date: 2025-09-25T10:00:00+01:00
lastmod: 2025-09-25T10:00:00+01:00
draft: false
author: "Manzolo"
tags: ["bash", "linux", "commands", "terminal", "reference"]
categories: ["Command Reference"]
series: ["Command Line Mastery"]
weight: 1
cover:
    image: "/img/bash-cover.png"
    alt: "Bash terminal"
    caption: "Essential Bash commands"
    relative: false
    hidden: false
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

## Introduzione

In questo tutorial vediamo i comandi Bash fondamentali che ogni sviluppatore dovrebbe padroneggiare. Partiamo dall'analisi dello spazio su disco e allarghiamo il discorso alle operazioni essenziali sui file.

## Analisi dello spazio su disco

### Il comando di base

Ecco un comando utile per elencare i file in ordine di dimensione:

```bash
du -sh * | sort -h
```

### Il comando pezzo per pezzo

- `du -sh *`: 
  - `du` = disk usage, l'uso del disco
  - `-s` = riepilogo (per le directory solo il totale)  
  - `-h` = formato leggibile (KB, MB, GB)
  - `*` = tutti i file e le directory della cartella corrente

- `sort -h`: ordina numericamente i valori in formato leggibile

### Varianti utili

```bash
# Top 10 largest files/directories
du -sh * | sort -hr | head -10

# Recursive analysis with details
du -ah . | sort -hr | head -20

# Directories only, excluding files
du -sh */ | sort -hr

# Analysis of specific directory
du -sh /home/user/* | sort -hr
```

## Comandi collegati

### Spazio libero su disco

```bash
# Free space on filesystems
df -h

# Information about specific partition
df -h /home
```

### Trovare i file grossi

```bash
# Files larger than 100MB
find . -type f -size +100M -exec du -sh {} + | sort -hr

# Files larger than 1GB in current directory
find . -maxdepth 1 -type f -size +1G -exec ls -lh {} +
```

## Uno script pratico

Crea uno script per tenere d'occhio lo spazio su disco:

```bash
#!/bin/bash
# monitor_space.sh

echo "=== Disk Space Analysis ==="
echo "Current directory: $(pwd)"
echo ""

echo "Top 10 items by size:"
du -sh * 2>/dev/null | sort -hr | head -10

echo ""
echo "Free space:"
df -h .
```

Rendilo eseguibile:

```bash
chmod +x monitor_space.sh
./monitor_space.sh
```

## Operazioni sui file

### Comandi di base sui file

```bash
# List files with details
ls -la

# Copy files
cp source.txt destination.txt
cp -r source_dir/ destination_dir/

# Move/rename files
mv old_name.txt new_name.txt

# Remove files (be careful!)
rm file.txt
rm -rf directory/
```

### Operazioni sui file di testo

```bash
# View file contents
cat file.txt
less file.txt
head -n 10 file.txt    # First 10 lines
tail -n 10 file.txt    # Last 10 lines
tail -f log_file.txt   # Follow file changes

# Search in files
grep "pattern" file.txt
grep -r "pattern" directory/
grep -i "case-insensitive" file.txt
```

## Gestione dei processi

### Vedere i processi

```bash
# List running processes
ps aux
ps -ef

# Interactive process viewer
top
htop  # If installed

# Process tree
pstree
```

### Controllo dei processi

```bash
# Run command in background
command &

# List background jobs
jobs

# Bring job to foreground
fg %1

# Send to background
bg %1

# Kill processes
kill PID
killall process_name
pkill pattern
```

## Consigli da esperto

{{< callout type="tip" >}}
**Consiglio**: usa `ncdu` per analizzare l'uso del disco in modo interattivo:
```bash
sudo apt install ncdu  # Ubuntu/Debian
ncdu /home/user
```
{{< /callout >}}

{{< callout type="warning" >}}
**Attenzione**: il comando `du` può essere lento sulle directory con molti file. Usa `--max-depth=1` per limitare la profondità della ricorsione.
{{< /callout >}}

{{< callout type="success" title="Quick Reference" >}}
**Scorciatoie essenziali:**
- `Ctrl+C` - Interrompe il comando in corso
- `Ctrl+Z` - Sospende il comando in corso
- `Ctrl+D` - Esce dalla shell/EOF
- `Ctrl+L` - Pulisce lo schermo
- `!!` - Ripete l'ultimo comando
- `!$` - Ultimo argomento del comando precedente
{{< /callout >}}

## Informazioni di sistema

### Informazioni sull'hardware

```bash
# CPU information
lscpu
cat /proc/cpuinfo

# Memory information
free -h
cat /proc/meminfo

# Storage devices
lsblk
fdisk -l

# USB devices
lsusb

# PCI devices
lspci
```

### Stato del sistema

```bash
# System uptime
uptime

# Who's logged in
who
w

# System load average
cat /proc/loadavg

# Kernel information
uname -a
```

## Variabili d'ambiente

### Variabili comuni

```bash
# View all environment variables
env
printenv

# Important variables
echo $HOME     # Home directory
echo $USER     # Current user
echo $PATH     # Executable paths
echo $SHELL    # Current shell
echo $PWD      # Current directory
```

### Impostare le variabili

```bash
# Temporary variable (current session)
export MY_VAR="value"

# Permanent variable (add to ~/.bashrc)
echo 'export MY_VAR="value"' >> ~/.bashrc
source ~/.bashrc
```

## Prossimi passi

Nel prossimo tutorial vedremo:
- Elaborazione avanzata del testo con `awk` e `sed`
- Comandi di rete e ricerca dei guasti
- Automazione delle attività con i job di cron
- Buone pratiche per gli script di shell

## Esercizi pratici

Prova questi esercizi per fissare quello che hai imparato:

1. **Pulizia del disco**: trova ed elenca tutti i file più grandi di 500MB nella tua home directory
2. **Analisi dei log**: usa `tail -f` per seguire i log di sistema in `/var/log/`
3. **Monitoraggio dei processi**: crea uno script che mostra i 5 processi che consumano più CPU
4. **Organizzazione dei file**: scrivi uno script che ordina i file in sottodirectory in base all'estensione

## Risorse

- [Manuale di Bash](https://www.gnu.org/software/bash/manual/)
- [Cheat sheet della riga di comando Linux](https://cheatography.com/davechild/cheat-sheets/linux-command-line/)
- [ExplainShell](https://explainshell.com/) - Scompone i comandi complessi

---

*Ricorda: la pratica rende perfetti! Più usi questi comandi, più ti verranno naturali.*
