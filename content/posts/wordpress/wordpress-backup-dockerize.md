---
title: "Wordpress backing up (files and database) and dockerizing"
date: 2025-09-27T09:20:30Z
categories: ["Docker & Containers"]
series: ["Docker Essentials"]
tags: ["wordpress", "backup", "docker", "mysql", "migration"]
draft: false
---

# WordPress Management Script Usage Guide

## Introduction

The `wp-management` [script](https://github.com/manzolo/BashCollection/blob/main/utils/wordpress/wp-management.sh) is a powerful Bash tool designed to streamline the management of WordPress sites. It supports two primary functions: **backing up** a WordPress site (including files and database) and **dockerizing** a WordPress site to run in a containerized environment with automatic restoration of backups. This guide explains the script's purpose, how to use it, and provides practical examples to help you get started.

## What is the `wp-management` Script?

The `wp-management` script automates essential WordPress site management tasks:

1. **Backup**:
   - Creates a complete backup of a WordPress site, including:
     - The `wp-content` directory (themes, plugins, uploads) as a `.tar.gz` archive.
     - The `wp-config.php` configuration file.
     - The MySQL/MariaDB database as a `.sql` file.
     - A `backup_info` text file summarizing the backup details.

2. **Dockerization**:
   - Sets up a Docker environment for a WordPress site, generating:
     - A `.env` file with configuration variables.
     - A `docker-compose.yml` file defining MariaDB, WordPress, and phpMyAdmin containers.
     - A `manage.sh` script to control the Docker environment (start, stop, backup, restore, etc.).
     - A `README.md` with usage instructions.
   - Automatically checks and creates required Docker networks (`wp-net` and `nginx-net`).
   - Restores `wp-content` and the database from existing backups, if available.

This script is ideal for developers, system administrators, or WordPress site owners who need to secure site data, deploy sites in Docker, or restore sites from backups.

## Prerequisites

Before using the script, ensure the following are installed on your system:
- **Bash**: Required for running the script (available on Linux/macOS or WSL on Windows).
- **MySQL Client**: Needed for database backups (`mysqldump` is required).
- **Docker and Docker Compose**: Required for dockerization (use `docker compose` for newer versions).
- **WordPress Site or Backup**: A WordPress site folder with a valid `wp-config.php` or a backup directory containing `wp-config_*.php`, `wp-content_*.tar.gz`, and `database_*.sql` files.
- **Permissions**: Write access to the directories for backups and Docker files.
- **Optional**: `openssl` for generating secure passwords during dockerization.

Install dependencies on Ubuntu/Debian:
```bash
sudo apt update
sudo apt install mysql-client docker.io docker-compose-v2
sudo apt install openssl  # Optional, for secure password generation
```

## How to Use the Script

### 1. Setup
1. **Save the Script**: Save the `wp-management` script to a file named `wp-management`.
2. **Make it Executable**:
   ```bash
   chmod +x wp-management
   ```
3. **Place the Script**: Place the script in a directory with access to your WordPress site folder(s) or backup directory.

### 2. Script Usage
The script supports two commands: `backup` and `dockerize`. The general syntax is:
```bash
./wp-management {backup|dockerize} <site_name>
```
- `backup`: Backs up the WordPress site named `<site_name>`.
- `dockerize`: Creates a Docker environment for the WordPress site named `<site_name>`, automatically restoring backups if available.
- `<site_name>`: The name of the folder containing the WordPress site (e.g., `mysite` for `./mysite`) or the backup directory (e.g., `./backup/mysite`).

### 3. Directory Structure
For backups, the script expects the WordPress site in a folder named `<site_name>`:
```
./mysite/wp-content/
./mysite/wp-config.php
./wp-management
```
For dockerization, it can use either the site folder or a backup directory:
```
./backup/mysite/wp-content_20250927_110715.tar.gz
./backup/mysite/wp-config_20250927_110715.php
./backup/mysite/database_20250927_110715.sql
./wp-management
```

### 4. Docker Network Setup
The script automatically checks for and creates the required Docker networks (`wp-net` and `nginx-net`) if they don’t exist, ensuring seamless container communication.

## Examples

### Example 1: Backing Up a WordPress Site
Suppose you have a WordPress site in the folder `./mysite`.

**Command**:
```bash
./wp-management backup mysite
```

**What Happens**:
- The script verifies the `./mysite` folder and its `wp-config.php` file.
- It extracts database credentials (`DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`) from `wp-config.php`.
- It creates a backup directory (`./backup/mysite`).
- It backs up:
  - `wp-content` as `wp-content_20250927_110715.tar.gz`.
  - `wp-config.php` as `wp-config_20250927_110715.php`.
  - The database as `database_20250927_110715.sql`.
  - A `backup_info_20250927_110715.txt` file with details.
- Output is color-coded (e.g., green for success, red for errors).

**Result**:
Backup files are stored in `./backup/mysite`. You can use these for restoration or migration.

### Example 2: Dockerizing a WordPress Site with Backup Restoration
Suppose you have a WordPress site in `./mysite` or backups in `./backup/mysite`.

**Command**:
```bash
./wp-management dockerize mysite
```

**What Happens**:
- The script checks for `wp-config.php` in `./mysite` or `./backup/mysite`.
- If multiple `wp-config_*.php` backups are found, it prompts you to select one or copy the desired one to `./mysite/wp-config.php`.
- It extracts database credentials from `wp-config.php`.
- It creates a Docker directory (`./docker-mysite`) with:
  - `.env`: Environment variables (e.g., database credentials, container names).
  - `docker-compose.yml`: Defines MariaDB, WordPress, and phpMyAdmin containers.
  - `manage.sh`: A script to manage containers.
  - `README.md`: Usage instructions.
- It checks and creates Docker networks (`wp-net`, `nginx-net`) if missing.
- If backups exist in `./backup/mysite`:
  - Restores `wp-content` from the latest `wp-content_*.tar.gz` to `./docker-mysite/wp-data`.
  - Copies the latest `database_*.sql` to `./docker-mysite/restore_database.sql`, starts the database container, and restores the database.
- It pauses for user confirmation before critical steps (e.g., database restoration).

**Result**:
The Docker environment is set up in `./docker-mysite`. To start the containers:
```bash
cd docker-mysite
docker compose up -d
```

**Access**:
- **WordPress**: Access via a reverse proxy or uncomment the port mapping in `docker-compose.yml` (e.g., `8080:80`) to access at `http://localhost:8080`.
- **phpMyAdmin**: Access via a reverse proxy or uncomment the port mapping (e.g., `8081:80`) to access at `http://localhost:8081`.

**Manage the Containers**:
```bash
./manage.sh start      # Start containers
./manage.sh stop       # Stop containers
./manage.sh restart    # Restart containers
./manage.sh logs       # View logs
./manage.sh shell      # Access WordPress container shell
./manage.sh backup     # Back up the database
./manage.sh restore-db # Restore database from restore_database.sql
./manage.sh status     # Check container status
```

### Example 3: Manual Database Restoration
If you have a database backup file, you can manually restore it.

**Steps**:
1. Place the `.sql` file in the Docker directory as `restore_database.sql`:
   ```bash
   cp ./backup/mysite/database_20250927_110715.sql ./docker-mysite/restore_database.sql
   ```
2. Run the restore command:
   ```bash
   cd docker-mysite
   ./manage.sh restore-db
   ```

**What Happens**:
- The script checks if the database container is running and ready.
- It restores the database from `restore_database.sql` using `mariadb` or `mysql` as a fallback.
- It provides feedback on success or failure with manual restore instructions if needed.

### Example 4: Checking Container Status
To verify the status of your Docker containers:
```bash
cd docker-mysite
./manage.sh status
```

**Output Example**:
```
Container Status:
Database Container (wordpress_mysite_db):
  ✓ Running
  ✓ Database is responsive
WordPress Container (wordpress_mysite_webserver):
  ✓ Running
phpMyAdmin Container (wordpress_mysite_phpmyadmin):
  ✓ Running
```

## Use Cases
- **Backups**:
  - Create regular backups before WordPress updates or migrations.
  - Store backups securely for disaster recovery.
  - Use backups to restore a site in a Docker environment.
- **Dockerization**:
  - Develop or test WordPress sites in a consistent, isolated environment.
  - Deploy sites in production behind a reverse proxy (e.g., Nginx).
  - Restore existing sites from backups for quick setup.
- **Database Management**:
  - Use `manage.sh backup` to create database snapshots.
  - Use `manage.sh restore-db` to recover from a backup or migrate data.

## Pro Tips
- **Automate Backups**: Schedule backups using `cron`:
  ```bash
  0 2 * * * /path/to/wp-management backup mysite
  ```
  This runs a backup daily at 2 AM.
- **Secure Backups**: Move backup files to cloud storage or an offsite location.
- **Handle Multiple Backups**: If multiple `wp-config_*.php` files exist, copy the desired one to `./mysite/wp-config.php` to avoid ambiguity.
- **SSH Tunneling for Remote Sites**: Use SSH forward tunneling to access a remote database:
  ```bash
  ssh -L 3306:dbserver.local:3306 user@ssh.example.com
  ```
- **Monitor Containers**: Use `./manage.sh status` to check container health before performing backups or restores.

## Troubleshooting
- **Folder Not Found**: Ensure the `<site_name>` folder or `./backup/<site_name>` exists with valid files.
- **Multiple Backups**: If multiple `wp-config_*.php` files are found, manually copy the desired one to the site folder.
- **Missing Dependencies**: Install `mysqldump`, `docker`, and `docker-compose-v2` as needed.
- **Docker Port Conflicts**: Modify port mappings in `docker-compose.yml` if `8080` or `8081` are in use.
- **Database Errors**: Verify database credentials in `wp-config.php` and ensure the MySQL/MariaDB server is running.
- **Container Not Ready**: Use `./manage.sh status` to check if containers are running and healthy before restoring.

## Resources
- [WordPress Documentation](https://wordpress.org/documentation/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [MariaDB Documentation](https://mariadb.com/kb/en/documentation/)

---

*Use the `wp-management` script to efficiently manage your WordPress sites with backups and Docker deployments!*