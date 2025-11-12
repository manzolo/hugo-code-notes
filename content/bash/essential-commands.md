---
title: "Essential Bash Commands - File Management and System Analysis"
description: "Learn fundamental Bash commands for file management and system analysis that every developer should know"
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

## Introduction

In this tutorial, we'll explore fundamental Bash commands that every developer should master. We'll start with disk space analysis and expand to cover essential file operations.

## Disk Space Analysis

### Basic Command

Here's a useful command to list files by size:

```bash
du -sh * | sort -h
```

### Command Breakdown

- `du -sh *`: 
  - `du` = disk usage
  - `-s` = summary (total only for directories)  
  - `-h` = human-readable format (KB, MB, GB)
  - `*` = all files/directories in current folder

- `sort -h`: sorts human-readable values numerically

### Useful Variations

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

## Related Commands

### Free Disk Space

```bash
# Free space on filesystems
df -h

# Information about specific partition
df -h /home
```

### Finding Large Files

```bash
# Files larger than 100MB
find . -type f -size +100M -exec du -sh {} + | sort -hr

# Files larger than 1GB in current directory
find . -maxdepth 1 -type f -size +1G -exec ls -lh {} +
```

## Practical Script

Create a script to monitor disk space:

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

Make it executable:

```bash
chmod +x monitor_space.sh
./monitor_space.sh
```

## File Operations

### Basic File Commands

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

### Text File Operations

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

## Process Management

### Viewing Processes

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

### Process Control

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

## Pro Tips

{{< callout type="tip" >}}
**Tip**: Use `ncdu` for interactive disk usage analysis:
```bash
sudo apt install ncdu  # Ubuntu/Debian
ncdu /home/user
```
{{< /callout >}}

{{< callout type="warning" >}}
**Warning**: The `du` command can be slow on directories with many files. Use `--max-depth=1` to limit recursion depth.
{{< /callout >}}

{{< callout type="success" title="Quick Reference" >}}
**Essential shortcuts:**
- `Ctrl+C` - Interrupt current command
- `Ctrl+Z` - Suspend current command
- `Ctrl+D` - Exit shell/EOF
- `Ctrl+L` - Clear screen
- `!!` - Repeat last command
- `!$` - Last argument of previous command
{{< /callout >}}

## System Information

### Hardware Information

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

### System Status

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

## Environment Variables

### Common Variables

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

### Setting Variables

```bash
# Temporary variable (current session)
export MY_VAR="value"

# Permanent variable (add to ~/.bashrc)
echo 'export MY_VAR="value"' >> ~/.bashrc
source ~/.bashrc
```

## Next Steps

In the next tutorial, we'll cover:
- Advanced text processing with `awk` and `sed`
- Network commands and troubleshooting
- Automating tasks with cron jobs
- Shell scripting best practices

## Practice Exercises

Try these exercises to reinforce your learning:

1. **Disk Cleanup**: Find and list all files larger than 500MB in your home directory
2. **Log Analysis**: Use `tail -f` to monitor system logs in `/var/log/`
3. **Process Monitoring**: Create a script that shows the top 5 CPU-consuming processes
4. **File Organization**: Write a script that organizes files by extension into subdirectories

## Resources

- [Bash Manual](https://www.gnu.org/software/bash/manual/)
- [Linux Command Line Cheat Sheet](https://cheatography.com/davechild/cheat-sheets/linux-command-line/)
- [ExplainShell](https://explainshell.com/) - Break down complex commands

---

*Remember: Practice makes perfect! The more you use these commands, the more natural they'll become.*