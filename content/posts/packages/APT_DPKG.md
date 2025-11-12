---
title: "APT and DPKG Guide (Debian/Ubuntu)"
date: 2025-10-04T12:00:00+02:00
lastmod: 2025-10-04T12:50:00+02:00
draft: false
author: "Manzolo"
tags: ["apt", "dpkg", "debian", "ubuntu", "package-management"]
categories: ["Package Management"]
series: ["System Administration Basics"]
weight: 4
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# APT and DPKG Guide (Debian/Ubuntu)

## Introduction

`apt` and `dpkg` are core tools for package management on Debian and Ubuntu systems. `apt update` refreshes the package index from configured repositories, ensuring you have the latest package information. `dpkg` manages `.deb` packages, allowing direct installation, removal, querying, or identifying file ownership. This guide covers using `apt update` and `dpkg`, with use cases like system updates, manual `.deb` installation, searching for packages, finding file ownership, adding/removing external repositories, and determining which repository provides a package.

## What are APT and DPKG?

- **APT (Advanced Package Tool)**: A high-level package manager that simplifies installing, updating, searching, and removing software. `apt update` fetches package lists, while commands like `apt install`, `apt upgrade`, or `apt search` handle package operations.
- **DPKG**: A low-level tool for managing `.deb` packages, used for tasks like installing local `.deb` files, querying installed packages, removing packages, or identifying file ownership.

Together, they provide robust package management for Debian/Ubuntu systems.

## Prerequisites

- **Debian/Ubuntu**: Version 20.04+.
- **Root Access**: Use `sudo` for most commands.
- **Internet Access**: Required for `apt update` and repository operations.
- **Tools**: `apt`, `dpkg`, and `gnupg` are pre-installed on Debian/Ubuntu.

Verify tools:
```bash
apt --version
dpkg --version
gpg --version
```

## Critical Warning: Backup Before Changes

{{< callout type="warning" >}}
**Caution**: Package updates, installations, or repository changes can overwrite configurations or cause system issues. Back up critical data and configurations (e.g., `/etc/`) before proceeding.
{{< /callout >}}

## How to Use APT Update and DPKG

### 1. Update Package Lists with `apt update`
`apt update` refreshes the package index from repositories listed in `/etc/apt/sources.list` and `/etc/apt/sources.list.d/`. Run this before installing or upgrading packages.

```bash
sudo apt update
```
![APT update output showing repository refresh](/images/apt-update-output.png "Output of sudo apt update")
Example output:
```
Hit:1 http://deb.debian.org/debian bullseye InRelease
Get:2 http://deb.debian.org/debian-security bullseye-security InRelease [48.4 kB]
Fetched 48.4 kB in 1s (45.2 kB/s)
Reading package lists... Done
Building dependency tree... Done
All packages are up to date.
```

**Note**: If you see errors (e.g., 404 Not Found), check `/etc/apt/sources.list` or `/etc/apt/sources.list.d/` for invalid URLs.

### 2. Add an External Repository
To install software not in default repositories (e.g., Docker), add a third-party repository to `/etc/apt/sources.list` or `/etc/apt/sources.list.d/`. Often, you need to add a GPG key for security.

Example (add Docker repository):
```bash
# Add Docker's GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list

# Update package lists
sudo apt update
```

Verify:
```bash
cat /etc/apt/sources.list.d/docker.list
```

**Note**: Always verify the GPG key and repository URL to avoid security risks.

### 3. Remove an External Repository
To remove a repository, delete its entry from `/etc/apt/sources.list` or its file in `/etc/apt/sources.list.d/`, and optionally remove the GPG key.

Example (remove Docker repository):
```bash
# Remove repository file
sudo rm /etc/apt/sources.list.d/docker.list

# Remove GPG key (optional)
sudo rm /usr/share/keyrings/docker-archive-keyring.gpg

# Update package lists
sudo apt update
```

Verify:
```bash
ls /etc/apt/sources.list.d/
```

**Note**: Edit `/etc/apt/sources.list` with `sudo nano` if the repository is listed there instead.

### 4. Determine Which Repository Provides a Package
Use `apt-cache policy` to find which repository provides a package and its available versions.

```bash
apt-cache policy <package-name>
```
Example (check `docker-ce`):
```bash
apt-cache policy docker-ce
```
Example output:
```
docker-ce:
  Installed: (none)
  Candidate: 5:24.0.7-1~debian.11~bullseye
  Version table:
     5:24.0.7-1~debian.11~bullseye 500
        500 https://download.docker.com/linux/debian bullseye/stable amd64 Packages
```

**Note**: Run `sudo apt update` first to ensure the package cache is current.

### 5. Search for a Package
Use `apt search` or `apt-cache search` to find packages by name or description.

- **Using `apt search`** (user-friendly, sorted):
  ```bash
  apt search <keyword>
  ```
  Example (search for `vim`):
  ```bash
  apt search vim
  ```
  Example output:
  ```
  Sorting... Done
  Full Text Search... Done
  vim/bullseye 2:8.2.2434-3+deb11u1 amd64
    Vi IMproved - enhanced vi editor
  vim-tiny/bullseye 2:8.2.2434-3+deb11u1 amd64
    Vi IMproved - enhanced vi editor (tiny version)
  ```

- **Using `apt-cache search`** (detailed, unsorted):
  ```bash
  apt-cache search <keyword>
  ```
  Example (search for `nginx`):
  ```bash
  apt-cache search nginx
  ```
  Example output:
  ```
  nginx - small, powerful, scalable web/proxy server
  nginx-common - small, powerful, scalable web/proxy server - common files
  ```

**Note**: Run `sudo apt update` first.

### 6. Find the Package Owning a File
Use `dpkg -S` to identify which package installed a file.

```bash
dpkg -S <file-path>
```
Example (find package for `/usr/bin/vim`):
```bash
dpkg -S /usr/bin/vim
```
Example output:
```
vim: /usr/bin/vim
```

**Note**: If the file isn’t found, it may not belong to a package.

### 7. Upgrade Installed Packages
Upgrade installed packages to their latest versions:
- **Safe Upgrade** (avoids removing packages):
  ```bash
  sudo apt upgrade
  ```
- **Full Upgrade** (may remove packages):
  ```bash
  sudo apt full-upgrade
  ```

Example:
```bash
sudo apt update
sudo apt upgrade
```

### 8. Install a Package with `apt`
Install a package from repositories:
```bash
sudo apt install <package-name>
```
Example (install `vim`):
```bash
sudo apt install vim
```

### 9. Install a Local `.deb` File with `dpkg`
Install a downloaded `.deb` file:
```bash
sudo dpkg -i ./package.deb
```
Example (install `google-chrome-stable_current_amd64.deb`):
```bash
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
```

**Note**: If dependencies are missing, fix with:
```bash
sudo apt install -f
```

### 10. Query Installed Packages with `dpkg`
Check if a package is installed or get details:
```bash
dpkg -l | grep <package-name>
dpkg -s <package-name>
```
Example (check `vim`):
```bash
dpkg -l | grep vim
dpkg -s vim
```

List files installed by a package:
```bash
dpkg -L <package-name>
```
Example:
```bash
dpkg -L vim
```

### 11. Remove or Purge Packages with `dpkg`
- **Remove** (keeps configuration files):
  ```bash
  sudo dpkg -r <package-name>
  ```
- **Purge** (removes configuration files):
  ```bash
  sudo dpkg --purge <package-name>
  ```
Example (remove `vim`):
```bash
sudo dpkg -r vim
```

### 12. Fix Broken Dependencies
If `dpkg` or `apt` reports broken dependencies:
```bash
sudo apt install -f
```

## Examples

### Example 1: Update and Upgrade System
Update package lists and upgrade packages:
```bash
# Update package lists
sudo apt update

# Upgrade packages
sudo apt upgrade
```

**Output**:
```
Reading package lists... Done
Building dependency tree... Done
Calculating upgrade... Done
0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
```

### Example 2: Add an External Repository
Add the Docker repository:
```bash
# Add GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list

# Update package lists
sudo apt update
```

**Output** (after `apt update`):
```
Get:1 https://download.docker.com/linux/debian bullseye/stable amd64 Packages [24.8 kB]
Fetched 24.8 kB in 1s (30.2 kB/s)
Reading package lists... Done
```

### Example 3: Remove an External Repository
Remove the Docker repository:
```bash
# Remove repository file
sudo rm /etc/apt/sources.list.d/docker.list

# Remove GPG key
sudo rm /usr/share/keyrings/docker-archive-keyring.gpg

# Update package lists
sudo apt update
```

**Output**:
```
Reading package lists... Done
Building dependency tree... Done
All packages are up to date.
```

### Example 4: Determine Which Repository Provides a Package
Check the repository for `docker-ce`:
```bash
apt-cache policy docker-ce
```

**Output**:
```
docker-ce:
  Installed: (none)
  Candidate: 5:24.0.7-1~debian.11~bullseye
  Version table:
     5:24.0.7-1~debian.11~bullseye 500
        500 https://download.docker.com/linux/debian bullseye/stable amd64 Packages
```

### Example 5: Search for a Package
Search for a package:
```bash
apt search vim
```

**Output**:
```
Sorting... Done
Full Text Search... Done
vim/bullseye 2:8.2.2434-3+deb11u1 amd64
  Vi IMproved - enhanced vi editor
vim-tiny/bullseye 2:8.2.2434-3+deb11u1 amd64
  Vi IMproved - enhanced vi editor (tiny version)
```

### Example 6: Find Which Package Owns a File
Identify the package for a file:
```bash
dpkg -S /usr/bin/vim
```

**Output**:
```
vim: /usr/bin/vim
```

### Example 7: Install a Local `.deb` File
Install a `.deb` file and fix dependencies:
```bash
# Download a .deb file
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

# Install with dpkg
sudo dpkg -i google-chrome-stable_current_amd64.deb

# Fix dependencies
sudo apt install -f
```

**Output** (if dependencies are missing):
```
dpkg: dependency problems prevent configuration of google-chrome-stable:
 google-chrome-stable depends on libatk1.0-0 (>= 2.32.0); however:
  Package libatk1.0-0 is not installed.
...
sudo apt install -f
...
Setting up libatk1.0-0 (2.36.0-2) ...
Setting up google-chrome-stable (114.0.5735.198-1) ...
```

### Example 8: Query and Remove a Package
Check and remove a package:
```bash
# Check package status
dpkg -l | grep vim
dpkg -s vim

# List package files
dpkg -L vim

# Remove package
sudo dpkg -r vim
```

**Output** (query):
```
ii  vim  2:8.2.2434-3+deb11u1  amd64  Vi IMproved - enhanced vi editor
```

### Example 9: Fix Broken Dependencies
If `dpkg -i` fails:
```bash
sudo dpkg -i package.deb
# Errors about missing dependencies
sudo apt install -f
```

## Variants

### Adding and Using an External Repository
Add a repository to install specific software (e.g., Docker):
```bash
# Add GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list

# Update and install
sudo apt update
sudo apt install docker-ce
```

### Removing an External Repository
Remove a repository and clean up:
```bash
# Remove repository file
sudo rm /etc/apt/sources.list.d/docker.list

# Remove GPG key
sudo rm /usr/share/keyrings/docker-archive-keyring.gpg

# Update package lists
sudo apt update
```

### Using `dpkg` to Reconfigure Packages
Reconfigure a package’s settings:
```bash
sudo dpkg-reconfigure <package-name>
```
Example (reconfigure `tzdata`):
```bash
sudo dpkg-reconfigure tzdata
```

## Command Breakdown
- **apt update**: Refreshes package index from repositories.
- **apt search**: Searches for packages by name or description.
- **apt-cache search**: Detailed package search (unsorted).
- **apt-cache policy**: Shows which repository provides a package.
- **apt upgrade/full-upgrade**: Upgrades installed packages.
- **apt install**: Installs packages or fixes dependencies.
- **dpkg -i**: Installs a local `.deb` file.
- **dpkg -S**: Finds the package owning a file.
- **dpkg -r/--purge**: Removes or purges packages.
- **dpkg -l/-s/-L**: Queries installed packages or their files.
- **apt install -f**: Resolves broken dependencies.

## Use Cases
- **System Maintenance**: Regular `apt update && apt upgrade` for updates.
- **Custom Software**: Add external repositories for software like Docker.
- **Package Discovery**: Use `apt search` or `apt-cache policy` to find packages and their sources.
- **File Ownership**: Use `dpkg -S` to troubleshoot file origins.
- **Manual Installation**: Use `dpkg -i` for `.deb` files not in repositories.
- **Debugging**: Query packages with `dpkg -l` or `dpkg -s`.

## Pro Tips
- **Verify Repository Sources**: Check GPG keys and URLs for security when adding repositories.
- **Cache Cleaning**: Free disk space with `sudo apt autoclean` and `sudo apt autoremove`.
- **Dry Run**: Use `apt upgrade --dry-run` to preview changes.
- **Force Options with dpkg**: Use `dpkg -i --force-depends` cautiously for missing dependencies.
- **Backup APT Sources**: Save `/etc/apt/sources.list` and `/etc/apt/sources.list.d/` before changes.

## Troubleshooting
- **404 Errors in apt update**: Check `/etc/apt/sources.list` or `/etc/apt/sources.list.d/`:
  ```bash
  sudo nano /etc/apt/sources.list
  ls /etc/apt/sources.list.d/
  sudo apt update
  ```
- **Package Not Found in apt search**: Run `sudo apt update` and verify repositories.
- **apt-cache policy Shows No Repository**: Ensure the package is available in a configured repository.
- **dpkg -S Returns Nothing**: The file may not belong to a package.
- **Broken Dependencies**: Run `sudo apt install -f` after `dpkg -i`.
- **Package Conflicts**: Remove conflicting packages with `sudo dpkg --purge <package-name>`.
- **Permission Issues**: Use `sudo` for `apt` and `dpkg` commands.
- **Check Logs**: View `/var/log/dpkg.log` or `/var/log/apt/history.log`.

## Resources
- [Debian APT Manual](https://www.debian.org/doc/manuals/debian-reference/ch02.en.html)
- [Ubuntu Package Management](https://ubuntu.com/server/docs/package-management)
- [DPKG Man Page](https://man7.org/linux/man-pages/man1/dpkg.1.html)

---

*Manage packages efficiently with `apt update` and `dpkg` for a robust Debian/Ubuntu system!*