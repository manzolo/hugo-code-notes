---
title: "Build Your Own Ubuntu Repository with Docker"
date: 2025-11-08T08:30:00+02:00
lastmod: 2025-11-08T08:30:00+02:00
draft: false
author: "Manzolo"
tags: ["ubuntu", "docker", "repository", "devops", "packaging", "apt"]
categories: ["development", "devops", "docker", "linux", "tutorial"]
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

# Build Your Own Ubuntu Repository with Docker 📦

Ever wanted to distribute your own software packages just like Ubuntu does? Whether you're managing internal tools across multiple servers, creating a private package distribution system, or just want to learn how APT repositories work under the hood, building your own Ubuntu repository is easier than you might think.

In this guide, I'll show you how to create a production-ready Ubuntu repository using Docker, complete with GPG signing, automated publishing, and a web interface for package distribution.

## Why Build Your Own Repository?

Before diving into the technical details, let's explore some scenarios where a custom repository makes sense:

- **Internal Tools Distribution**: Deploy custom scripts and utilities across your organization without manual copying
- **Version Control**: Manage different versions of your packages with proper dependency resolution
- **Offline Installations**: Create air-gapped environments with pre-approved packages
- **Custom Software**: Distribute proprietary or modified software to your team
- **Learning**: Understand how package management systems work at a deeper level

## Architecture Overview

Our repository setup uses a modern, containerized stack:

- **Aptly**: A powerful APT repository management tool that handles package indexing and publishing
- **Docker**: Containerization for easy deployment and isolation
- **Nginx**: Web server to distribute packages over HTTP/HTTPS
- **GPG**: Cryptographic signing to ensure package authenticity and integrity

```
┌─────────────────────────────────────────┐
│         Docker Container                │
│  ┌───────────────────────────────────┐  │
│  │         Nginx Web Server          │  │
│  │    (Port 80 → Your packages)      │  │
│  └───────────────────────────────────┘  │
│                  ↓                      │
│  ┌───────────────────────────────────┐  │
│  │    Aptly Repository Manager       │  │
│  │  - Package indexing               │  │
│  │  - Metadata generation            │  │
│  │  - GPG signing                    │  │
│  └───────────────────────────────────┘  │
│                  ↓                      │
│  ┌───────────────────────────────────┐  │
│  │      Persistent Volumes           │  │
│  │  - Package pool                   │  │
│  │  - GPG keys                       │  │
│  │  - Repository metadata            │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Prerequisites

You'll need:

- A server with Docker and Docker Compose installed
- Basic understanding of Linux package management
- About 2GB of free disk space (more depending on your packages)
- A domain name or IP address for hosting (optional but recommended)

## Project Structure

First, let's look at the files we'll be creating:

```
ubuntu_repo/
├── docker-compose.yml      # Container orchestration
├── Dockerfile              # Container image definition
├── docker-entrypoint.sh    # Container initialization
├── repo-manager.sh         # Package management script
├── repo.sh                 # Main control script
├── .env                    # Configuration (you'll create this)
├── packages/               # Drop .deb files here
└── logs/                   # Nginx access/error logs
```

## Step 1: Create the Dockerfile

The Dockerfile sets up our repository environment. Create a file named `Dockerfile`:

```dockerfile
FROM ubuntu:22.04

LABEL maintainer="Your Name"
LABEL description="Ubuntu/Debian Package Repository with Aptly and Nginx"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Rome

# Install dependencies
RUN apt-get update && apt-get install -y \
    nginx \
    gnupg \
    gpg \
    wget \
    curl \
    ca-certificates \
    apt-utils \
    software-properties-common \
    bzip2 \
    xz-utils \
    gzip \
    && rm -rf /var/lib/apt/lists/*

# Add aptly repository and install aptly
RUN wget -qO - https://www.aptly.info/pubkey.txt | \
    gpg --dearmor > /usr/share/keyrings/aptly-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/aptly-archive-keyring.gpg] http://repo.aptly.info/ squeeze main" \
    > /etc/apt/sources.list.d/aptly.list && \
    apt-get update && \
    apt-get install -y aptly && \
    rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /var/www/ubuntu-repo/aptly \
    /var/www/ubuntu-repo/public \
    /var/log/nginx \
    /scripts

# Copy scripts
COPY docker-entrypoint.sh /scripts/
COPY repo-manager.sh /scripts/
RUN chmod +x /scripts/*.sh

# Remove default nginx site
RUN rm -f /etc/nginx/sites-enabled/default

# Expose HTTP port
EXPOSE 80

# Set working directory
WORKDIR /var/www/ubuntu-repo

# Volume for persistent data
VOLUME ["/var/www/ubuntu-repo/aptly", "/var/www/ubuntu-repo/public", "/root/.gnupg"]

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Entrypoint
ENTRYPOINT ["/scripts/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
```

## Step 2: Create the Docker Entrypoint Script

This script initializes the repository on first run. Create `docker-entrypoint.sh`:

```bash
#!/bin/bash
set -e

# Load environment variables with defaults
REPO_NAME="${REPO_NAME:-myrepo}"
REPO_DISTRIBUTION="${REPO_DISTRIBUTION:-focal}"
REPO_COMPONENT="${REPO_COMPONENT:-main}"
REPO_ARCHITECTURE="${REPO_ARCHITECTURE:-amd64}"
GPG_KEY_NAME="${GPG_KEY_NAME:-Ubuntu Repo Signing Key}"
GPG_KEY_EMAIL="${GPG_KEY_EMAIL:-repo@example.com}"
SERVER_NAME="${SERVER_NAME:-localhost}"

echo "Initializing Ubuntu Repository..."
echo "Repository: $REPO_NAME"
echo "Distribution: $REPO_DISTRIBUTION"

# Fix GPG directory permissions
mkdir -p /root/.gnupg
chmod 700 /root/.gnupg

# Create aptly configuration
cat > /etc/aptly.conf << EOF
{
  "rootDir": "/var/www/ubuntu-repo/aptly",
  "architectures": ["$REPO_ARCHITECTURE", "all"],
  "FileSystemPublishEndpoints": {
    "public": {
      "rootDir": "/var/www/ubuntu-repo/public",
      "linkMethod": "copy"
    }
  }
}
EOF

# Generate GPG key if it doesn't exist
if ! gpg --list-keys | grep -q "$GPG_KEY_EMAIL"; then
    echo "Generating GPG key..."
    cat > /tmp/gpg-key-config << EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $GPG_KEY_NAME
Name-Email: $GPG_KEY_EMAIL
Expire-Date: 0
EOF
    gpg --batch --gen-key /tmp/gpg-key-config
    rm -f /tmp/gpg-key-config
fi

# Export GPG public key
GPG_KEY_ID=$(gpg --list-keys --with-colons "$GPG_KEY_EMAIL" | grep ^pub | cut -d':' -f5)
gpg --armor --export "$GPG_KEY_ID" > /var/www/ubuntu-repo/public/KEY.gpg

# Create repository if it doesn't exist
if ! aptly repo show "$REPO_NAME" &>/dev/null; then
    echo "Creating repository..."
    aptly repo create -distribution="$REPO_DISTRIBUTION" \
                      -component="$REPO_COMPONENT" "$REPO_NAME"
fi

# Publish repository if not already published
if ! aptly publish list | grep -q "$REPO_DISTRIBUTION"; then
    echo "Publishing repository..."
    aptly publish repo -batch -gpg-key="$GPG_KEY_ID" \
                       -distribution="$REPO_DISTRIBUTION" \
                       -architectures="$REPO_ARCHITECTURE,all" \
                       "$REPO_NAME" filesystem:public: 2>&1 || true
fi

# Configure nginx
cat > /etc/nginx/sites-available/ubuntu-repo << EOF
server {
    listen 80 default_server;
    server_name $SERVER_NAME;

    root /var/www/ubuntu-repo/public;
    autoindex on;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /KEY.gpg {
        default_type application/pgp-keys;
    }

    add_header Access-Control-Allow-Origin *;

    access_log /var/log/nginx/ubuntu-repo-access.log;
    error_log /var/log/nginx/ubuntu-repo-error.log;
}
EOF

ln -sf /etc/nginx/sites-available/ubuntu-repo /etc/nginx/sites-enabled/ubuntu-repo
nginx -t

# Show client configuration
echo ""
echo "═══════════════════════════════════════════════════════"
echo "Client Configuration:"
echo "═══════════════════════════════════════════════════════"
echo "1. Download and install GPG key:"
echo "   wget -qO - http://$SERVER_NAME/KEY.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/$REPO_NAME.gpg"
echo ""
echo "2. Add repository:"
echo "   echo \"deb [signed-by=/etc/apt/trusted.gpg.d/$REPO_NAME.gpg] http://$SERVER_NAME $REPO_DISTRIBUTION $REPO_COMPONENT\" | sudo tee /etc/apt/sources.list.d/$REPO_NAME.list"
echo ""
echo "3. Update package lists:"
echo "   sudo apt update"
echo "═══════════════════════════════════════════════════════"

# Execute the main command
exec "$@"
```

Make it executable:
```bash
chmod +x docker-entrypoint.sh
```

## Step 3: Create the Repository Manager Script

This script handles package operations inside the container. Create `repo-manager.sh`:

```bash
#!/bin/bash

REPO_NAME="${REPO_NAME:-myrepo}"
REPO_DISTRIBUTION="${REPO_DISTRIBUTION:-focal}"

# Add package to repository
add_package() {
    local deb_file="$1"

    if [ ! -f "$deb_file" ]; then
        echo "✗ File not found: $deb_file"
        return 1
    fi

    echo "Adding package: $(basename $deb_file)"
    aptly repo add "$REPO_NAME" "$deb_file"

    if [ $? -eq 0 ]; then
        echo "✓ Package added"
        publish_repository
    else
        echo "✗ Failed to add package"
        return 1
    fi
}

# Publish repository
publish_repository() {
    GPG_KEY_EMAIL="${GPG_KEY_EMAIL:-repo@example.com}"
    GPG_KEY_ID=$(gpg --list-keys --with-colons "$GPG_KEY_EMAIL" | grep ^pub | cut -d':' -f5)

    aptly publish update -batch -gpg-key="$GPG_KEY_ID" \
                         "$REPO_DISTRIBUTION" filesystem:public: 2>/dev/null || \
    aptly publish repo -batch -gpg-key="$GPG_KEY_ID" \
                       -distribution="$REPO_DISTRIBUTION" \
                       "$REPO_NAME" filesystem:public:

    echo "✓ Repository published"
    gpg --armor --export "$GPG_KEY_ID" > /var/www/ubuntu-repo/public/KEY.gpg
}

# List packages
list_packages() {
    echo "Packages in repository '$REPO_NAME':"
    aptly repo show -with-packages "$REPO_NAME"
}

# Main execution
case "${1:-}" in
    add) add_package "$2" ;;
    list) list_packages ;;
    publish) publish_repository ;;
    *) echo "Usage: $0 {add|list|publish}" ;;
esac
```

Make it executable:
```bash
chmod +x repo-manager.sh
```

## Step 4: Create Docker Compose Configuration

Create `docker-compose.yml`:

```yaml
services:
  ubuntu-repo:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ubuntu-repo
    hostname: repo.local

    environment:
      - REPO_NAME=${REPO_NAME:-myrepo}
      - REPO_DISTRIBUTION=${REPO_DISTRIBUTION:-focal}
      - REPO_COMPONENT=${REPO_COMPONENT:-main}
      - REPO_ARCHITECTURE=${REPO_ARCHITECTURE:-amd64}
      - GPG_KEY_NAME=${GPG_KEY_NAME:-Ubuntu Repo Signing Key}
      - GPG_KEY_EMAIL=${GPG_KEY_EMAIL:-repo@example.com}
      - SERVER_NAME=${SERVER_NAME:-localhost}
      - TZ=${TZ:-UTC}

    ports:
      - "${HTTP_PORT:-8080}:80"

    volumes:
      - repo-data:/var/www/ubuntu-repo/aptly
      - repo-public:/var/www/ubuntu-repo/public
      - gpg-keys:/root/.gnupg
      - ./packages:/packages
      - ./logs:/var/log/nginx

    restart: unless-stopped

    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  repo-data:
    driver: local
  repo-public:
    driver: local
  gpg-keys:
    driver: local

networks:
  default:
    name: ubuntu-repo-network
```

## Step 5: Create Environment Configuration

Create a `.env` file with your configuration:

```bash
# Server Configuration
SERVER_NAME=repo.example.com  # Or your IP address
HTTP_PORT=8080                # Port to expose (80 for production)
CONTAINER_NAME=ubuntu-repo

# Repository Configuration
REPO_NAME=myrepo
REPO_DISTRIBUTION=focal       # focal=20.04, jammy=22.04, noble=24.04
REPO_COMPONENT=main
REPO_ARCHITECTURE=amd64       # or arm64, armhf, i386

# GPG Configuration
GPG_KEY_NAME=My Repository Signing Key
GPG_KEY_EMAIL=repo@example.com

# Timezone
TZ=Europe/Rome
```

## Step 6: Start Your Repository

Now you're ready to launch:

```bash
# Build and start the container
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

The first startup will:
1. Build the Docker image (~2 minutes)
2. Generate a GPG signing key
3. Initialize the repository
4. Start the Nginx web server

## Step 7: Creating and Adding Packages

### Creating a Simple Package

Let's create a test package. First, create the package structure:

```bash
mkdir -p hello_1.0.0/DEBIAN
mkdir -p hello_1.0.0/usr/local/bin
```

Create the control file (`hello_1.0.0/DEBIAN/control`):

```
Package: hello
Version: 1.0.0
Section: utils
Priority: optional
Architecture: all
Maintainer: Your Name <you@example.com>
Description: A simple hello world script
 This is a demonstration package that prints a greeting message.
 It shows how to create basic Debian packages for your repository.
```

Create the script (`hello_1.0.0/usr/local/bin/hello`):

```bash
#!/bin/bash
echo "Hello from my custom repository!"
echo "Package management is awesome!"
```

Make it executable:
```bash
chmod +x hello_1.0.0/usr/local/bin/hello
```

Build the package:
```bash
dpkg-deb --build hello_1.0.0
```

### Adding the Package to Your Repository

Copy the package to the `packages` directory:

```bash
cp hello_1.0.0.deb packages/
```

Import it into the repository:

```bash
docker exec ubuntu-repo /scripts/repo-manager.sh add /packages/hello_1.0.0.deb
```

Or create a convenience script `repo.sh`:

```bash
#!/bin/bash

case "$1" in
    add)
        docker exec ubuntu-repo /scripts/repo-manager.sh add "$2"
        ;;
    list)
        docker exec ubuntu-repo /scripts/repo-manager.sh list
        ;;
    publish)
        docker exec ubuntu-repo /scripts/repo-manager.sh publish
        ;;
    import)
        for deb in packages/*.deb; do
            [ -f "$deb" ] && docker exec ubuntu-repo /scripts/repo-manager.sh add "/packages/$(basename $deb)"
        done
        ;;
    *)
        echo "Usage: $0 {add|list|publish|import}"
        ;;
esac
```

Then use it:
```bash
chmod +x repo.sh
./repo.sh import  # Import all .deb files from packages/
./repo.sh list    # List packages in repository
```

## Step 8: Configure Client Machines

On any Ubuntu/Debian machine that should use your repository:

### Modern Method (Recommended)

```bash
# 1. Download and trust the GPG key
wget -qO - http://repo.example.com:8080/KEY.gpg | \
    sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/myrepo.gpg

# 2. Add the repository with signed-by
echo "deb [signed-by=/etc/apt/trusted.gpg.d/myrepo.gpg] http://repo.example.com:8080 focal main" | \
    sudo tee /etc/apt/sources.list.d/myrepo.list

# 3. Update package lists
sudo apt update

# 4. Install packages from your repository
sudo apt install hello
```

### Verify Installation

```bash
# Check package info
apt show hello

# Run the installed script
hello
# Output: Hello from my custom repository!
```

## Advanced Topics

### Supporting Multiple Distributions

To support multiple Ubuntu versions, modify your entrypoint to create multiple publications:

```bash
for dist in focal jammy noble; do
    aptly publish repo -batch -gpg-key="$GPG_KEY_ID" \
                       -distribution="$dist" \
                       "$REPO_NAME" filesystem:public:
done
```

### Adding HTTPS Support

For production environments, use a reverse proxy like Traefik or add certbot:

```bash
# Install certbot in container
apt-get install certbot python3-certbot-nginx

# Get certificate
certbot --nginx -d repo.example.com

# Auto-renewal is configured automatically
```

### Automating Package Builds

Create a CI/CD pipeline to automatically build and publish packages:

```yaml
# .github/workflows/publish-packages.yml
name: Build and Publish Packages

on:
  push:
    paths:
      - 'scripts/**'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Build packages
        run: |
          for script in scripts/*.sh; do
            ./build-deb.sh "$script"
          done

      - name: Publish to repository
        run: |
          scp *.deb repo-server:/packages/
          ssh repo-server './repo.sh import'
```

### Monitoring and Maintenance

Track repository size and usage:

```bash
# Check repository size
docker exec ubuntu-repo du -sh /var/www/ubuntu-repo

# Monitor access logs
tail -f logs/ubuntu-repo-access.log

# List all published packages
docker exec ubuntu-repo aptly repo show -with-packages myrepo
```

## Troubleshooting

### GPG Signature Verification Failed

If clients report GPG errors:

```bash
# Re-export and re-import the key
wget -qO - http://your-server:8080/KEY.gpg | \
    sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/myrepo.gpg
```

### Package Not Found After Adding

Ensure the package was published:

```bash
./repo.sh publish
```

### Container Won't Start

Check logs for details:

```bash
docker compose logs ubuntu-repo
```

Common issues:
- Port 8080 already in use (change `HTTP_PORT` in `.env`)
- Invalid GPG key configuration
- Insufficient disk space

## Best Practices

1. **Version Your Packages**: Use semantic versioning (1.0.0, 1.0.1, etc.)
2. **Sign Everything**: Always use GPG signing for security
3. **Backup Regularly**: Backup the GPG keys and repository data volumes
4. **Use HTTPS**: In production, always serve over HTTPS
5. **Monitor Disk Space**: Repositories grow quickly; monitor disk usage
6. **Document Dependencies**: Clearly specify package dependencies in control files
7. **Test Before Publishing**: Test packages locally before adding to repository

## Backing Up Your Repository

Create a backup script:

```bash
#!/bin/bash
BACKUP_DIR="/backups/ubuntu-repo-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup Docker volumes
docker run --rm \
    -v ubuntu-repo_repo-data:/data \
    -v "$BACKUP_DIR:/backup" \
    ubuntu tar czf /backup/repo-data.tar.gz /data

docker run --rm \
    -v ubuntu-repo_gpg-keys:/data \
    -v "$BACKUP_DIR:/backup" \
    ubuntu tar czf /backup/gpg-keys.tar.gz /data

echo "Backup completed: $BACKUP_DIR"
```

## Conclusion

You now have a fully functional Ubuntu package repository that can:

- ✅ Host and distribute .deb packages
- ✅ Sign packages with GPG for authenticity
- ✅ Support multiple Ubuntu/Debian distributions
- ✅ Run in a containerized environment
- ✅ Persist data across container restarts
- ✅ Serve packages over HTTP (or HTTPS with additional setup)

This setup is perfect for distributing internal tools, managing custom software deployments, or learning about how package management systems work. The containerized approach makes it portable, reproducible, and easy to maintain.

## Next Steps

- Create packages for your existing scripts and tools
- Set up automatic package building in your CI/CD pipeline
- Configure HTTPS with Let's Encrypt
- Add authentication for private repositories
- Explore advanced aptly features like snapshots and mirrors

## Resources

- [Aptly Documentation](https://www.aptly.info/doc/overview/)
- [Debian Package Guide](https://www.debian.org/doc/manuals/maint-guide/)
- [Ubuntu Packaging Guide](https://packaging.ubuntu.com/html/)
- [Docker Documentation](https://docs.docker.com/)

Happy packaging! 🚀
