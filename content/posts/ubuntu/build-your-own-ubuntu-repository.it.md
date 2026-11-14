---
title: "Costruisci il tuo repository Ubuntu con Docker"
url: "2025/11/build-your-own-ubuntu-repository-with-docker/"
date: 2025-11-08T08:30:00+02:00
lastmod: 2026-11-14T19:00:00+01:00
draft: false
author: "Manzolo"
tags: ["ubuntu", "repository", "apt", "packaging", "dpkg"]
categories: ["Package Management"]
series: ["System Administration Basics"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Costruisci il tuo repository Ubuntu con Docker 📦

Hai mai voluto distribuire i tuoi pacchetti software proprio come fa Ubuntu? Che tu debba gestire strumenti interni su più server, mettere in piedi un sistema privato di distribuzione dei pacchetti, o semplicemente capire come funzionano i repository APT sotto il cofano, costruirsi un repository Ubuntu è più facile di quanto pensi.

In questa guida ti mostro come creare un repository Ubuntu pronto per la produzione usando Docker, completo di firma GPG, pubblicazione automatica e un'interfaccia web per distribuire i pacchetti.

## Perché costruirsi un repository?

Prima di entrare nei dettagli tecnici, vediamo qualche scenario in cui un repository personalizzato ha senso:

- **Distribuzione di strumenti interni**: porta script e utility personalizzati in tutta l'organizzazione senza copiarli a mano
- **Controllo delle versioni**: gestisci versioni diverse dei tuoi pacchetti con una risoluzione delle dipendenze fatta come si deve
- **Installazioni offline**: crea ambienti isolati dalla rete (air-gapped) con pacchetti già approvati
- **Software personalizzato**: distribuisci al tuo team software proprietario o modificato
- **Imparare**: capisci più a fondo come funzionano i sistemi di gestione dei pacchetti

## Panoramica dell'architettura

Il nostro repository usa uno stack moderno, a container:

- **Aptly**: un potente strumento di gestione dei repository APT, che si occupa di indicizzare e pubblicare i pacchetti
- **Docker**: i container, per un deploy semplice e isolato
- **Nginx**: il web server che distribuisce i pacchetti via HTTP/HTTPS
- **GPG**: la firma crittografica che garantisce autenticità e integrità dei pacchetti

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

## Prerequisiti

Ti servono:

- Un server con Docker e Docker Compose installati
- Le basi della gestione dei pacchetti su Linux
- Circa 2GB di spazio libero su disco (di più, a seconda dei tuoi pacchetti)
- Un nome di dominio o un indirizzo IP su cui ospitarlo (facoltativo ma consigliato)

## Struttura del progetto

Per prima cosa, diamo un'occhiata ai file che creeremo:

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

## Passo 1: crea il Dockerfile

Il Dockerfile prepara l'ambiente del repository. Crea un file chiamato `Dockerfile`:

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

## Passo 2: crea lo script di entrypoint di Docker

Questo script inizializza il repository al primo avvio. Crea `docker-entrypoint.sh`:

```bash
#!/bin/bash
set -e

# Load environment variables with defaults
REPO_NAME="${REPO_NAME:-myrepo}"
REPO_DISTRIBUTION="${REPO_DISTRIBUTION:-noble}"
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
echo "   wget -qO - http://$SERVER_NAME/KEY.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/$REPO_NAME.gpg"
echo ""
echo "2. Add repository:"
echo "   echo \"deb [signed-by=/etc/apt/keyrings/$REPO_NAME.gpg] http://$SERVER_NAME $REPO_DISTRIBUTION $REPO_COMPONENT\" | sudo tee /etc/apt/sources.list.d/$REPO_NAME.list"
echo ""
echo "3. Update package lists:"
echo "   sudo apt update"
echo "═══════════════════════════════════════════════════════"

# Execute the main command
exec "$@"
```

Rendilo eseguibile:
```bash
chmod +x docker-entrypoint.sh
```

## Passo 3: crea lo script di gestione del repository

Questo script si occupa delle operazioni sui pacchetti dentro il container. Crea `repo-manager.sh`:

```bash
#!/bin/bash

REPO_NAME="${REPO_NAME:-myrepo}"
REPO_DISTRIBUTION="${REPO_DISTRIBUTION:-noble}"

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

Rendilo eseguibile:
```bash
chmod +x repo-manager.sh
```

## Passo 4: crea la configurazione di Docker Compose

Crea `docker-compose.yml`:

```yaml
name: ubuntu-repo

services:
  ubuntu-repo:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ubuntu-repo
    hostname: repo.local

    environment:
      - REPO_NAME=${REPO_NAME:-myrepo}
      - REPO_DISTRIBUTION=${REPO_DISTRIBUTION:-noble}
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

Il `name:` in cima fissa il nome del progetto Compose, così i volumi si chiamano sempre `ubuntu-repo_repo-data`, `ubuntu-repo_gpg-keys` e così via, comunque si chiami la cartella del progetto (lo script di backup più avanti conta su questo).

## Passo 5: crea la configurazione dell'ambiente

Crea un file `.env` con la tua configurazione:

```bash
# Server Configuration
SERVER_NAME=repo.example.com  # Or your IP address
HTTP_PORT=8080                # Port to expose (80 for production)

# Repository Configuration
REPO_NAME=myrepo
REPO_DISTRIBUTION=noble       # focal=20.04, jammy=22.04, noble=24.04
REPO_COMPONENT=main
REPO_ARCHITECTURE=amd64       # or arm64, armhf, i386

# GPG Configuration
GPG_KEY_NAME=My Repository Signing Key
GPG_KEY_EMAIL=repo@example.com

# Timezone
TZ=Europe/Rome
```

## Passo 6: avvia il repository

Adesso sei pronto a partire:

```bash
# Build and start the container
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

Al primo avvio:
1. Viene costruita l'immagine Docker (~2 minuti)
2. Viene generata una chiave GPG di firma
3. Viene inizializzato il repository
4. Parte il web server Nginx

## Passo 7: creare e aggiungere pacchetti

### Creare un pacchetto semplice

Creiamo un pacchetto di prova. Per prima cosa, crea la struttura del pacchetto:

```bash
mkdir -p hello_1.0.0/DEBIAN
mkdir -p hello_1.0.0/usr/local/bin
```

Crea il file control (`hello_1.0.0/DEBIAN/control`):

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

Crea lo script (`hello_1.0.0/usr/local/bin/hello`):

```bash
#!/bin/bash
echo "Hello from my custom repository!"
echo "Package management is awesome!"
```

Rendilo eseguibile:
```bash
chmod +x hello_1.0.0/usr/local/bin/hello
```

Costruisci il pacchetto:
```bash
dpkg-deb --build hello_1.0.0
```

### Aggiungere il pacchetto al repository

Copia il pacchetto nella cartella `packages`:

```bash
cp hello_1.0.0.deb packages/
```

Importalo nel repository:

```bash
docker exec ubuntu-repo /scripts/repo-manager.sh add /packages/hello_1.0.0.deb
```

Oppure crea uno script di comodo, `repo.sh`:

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

Poi usalo:
```bash
chmod +x repo.sh
./repo.sh import  # Import all .deb files from packages/
./repo.sh list    # List packages in repository
```

## Passo 8: configura le macchine client

Su ogni macchina Ubuntu/Debian che deve usare il tuo repository:

### Metodo moderno (consigliato)

```bash
# 1. Download the GPG key into a dedicated keyring
sudo install -d -m 0755 /etc/apt/keyrings
wget -qO - http://repo.example.com:8080/KEY.gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/myrepo.gpg

# 2. Add the repository with signed-by
echo "deb [signed-by=/etc/apt/keyrings/myrepo.gpg] http://repo.example.com:8080 noble main" | \
    sudo tee /etc/apt/sources.list.d/myrepo.list

# 3. Update package lists
sudo apt update

# 4. Install packages from your repository
sudo apt install hello
```

### Verifica l'installazione

```bash
# Check package info
apt show hello

# Run the installed script
hello
# Output: Hello from my custom repository!
```

## Argomenti avanzati

### Supportare più distribuzioni

Per supportare più versioni di Ubuntu, modifica l'entrypoint in modo che crei più pubblicazioni:

```bash
for dist in focal jammy noble; do
    aptly publish repo -batch -gpg-key="$GPG_KEY_ID" \
                       -distribution="$dist" \
                       "$REPO_NAME" filesystem:public:
done
```

### Aggiungere il supporto HTTPS

Negli ambienti di produzione metti davanti al container un reverse proxy come Traefik, Nginx Proxy Manager o Caddy, e lascia a lui il TLS. Certbot dentro il container non dura: il compose non pubblica la porta 443, l'entrypoint riscrive il sito nginx a ogni avvio, `/etc/letsencrypt` non sta su un volume e non c'è né cron né systemd a rinnovare il certificato. Un esempio minimo con Caddy:

```
# Caddyfile on the proxy host: gets and renews the certificate itself
repo.example.com {
    reverse_proxy localhost:8080
}
```

### Automatizzare la build dei pacchetti

Crea una pipeline CI/CD che costruisca e pubblichi i pacchetti in automatico:

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
      - uses: actions/checkout@v5

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

### Monitoraggio e manutenzione

Tieni d'occhio dimensione e utilizzo del repository:

```bash
# Check repository size
docker exec ubuntu-repo du -sh /var/www/ubuntu-repo

# Monitor access logs
tail -f logs/ubuntu-repo-access.log

# List all published packages
docker exec ubuntu-repo aptly repo show -with-packages myrepo
```

## Risoluzione dei problemi

### Verifica della firma GPG fallita

Se i client segnalano errori GPG:

```bash
# Re-export and re-import the key
wget -qO - http://your-server:8080/KEY.gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/myrepo.gpg
```

### Pacchetto non trovato dopo l'aggiunta

Assicurati che il pacchetto sia stato pubblicato:

```bash
./repo.sh publish
```

### Il container non parte

Guarda i log per i dettagli:

```bash
docker compose logs ubuntu-repo
```

Problemi comuni:
- Porta 8080 già in uso (cambia `HTTP_PORT` nel `.env`)
- Configurazione della chiave GPG non valida
- Spazio su disco insufficiente

## Buone pratiche

1. **Versiona i pacchetti**: usa il versionamento semantico (1.0.0, 1.0.1, ecc.)
2. **Firma tutto**: usa sempre la firma GPG, per sicurezza
3. **Fai backup regolari**: metti al sicuro le chiavi GPG e i volumi con i dati del repository
4. **Usa HTTPS**: in produzione, servi sempre via HTTPS
5. **Tieni d'occhio lo spazio su disco**: i repository crescono in fretta; controlla l'uso del disco
6. **Documenta le dipendenze**: dichiara chiaramente le dipendenze dei pacchetti nei file control
7. **Prova prima di pubblicare**: prova i pacchetti in locale prima di aggiungerli al repository

## Fare il backup del repository

Crea uno script di backup:

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

## Conclusione

Adesso hai un repository di pacchetti Ubuntu pienamente funzionante, che può:

- ✅ Ospitare e distribuire pacchetti .deb
- ✅ Firmare con GPG i metadati del repository per garantirne l'autenticità
- ✅ Supportare più distribuzioni Ubuntu/Debian
- ✅ Girare in un ambiente a container
- ✅ Conservare i dati tra un riavvio del container e l'altro
- ✅ Servire i pacchetti via HTTP (o HTTPS, con un po' di configurazione in più)

Questa configurazione è perfetta per distribuire strumenti interni, gestire il deploy di software personalizzato, o imparare come funzionano i sistemi di gestione dei pacchetti. L'approccio a container la rende portabile, riproducibile e facile da mantenere.

## Prossimi passi

- Crea i pacchetti per gli script e gli strumenti che hai già
- Imposta la build automatica dei pacchetti nella tua pipeline CI/CD
- Configura HTTPS con Let's Encrypt
- Aggiungi l'autenticazione per i repository privati
- Esplora le funzioni avanzate di aptly, come snapshot e mirror

## Risorse

- [Documentazione di Aptly](https://www.aptly.info/doc/overview/)
- [Guida ai pacchetti Debian](https://www.debian.org/doc/manuals/maint-guide/)
- [Guida al packaging di Ubuntu](https://packaging.ubuntu.com/html/)
- [Documentazione di Docker](https://docs.docker.com/)
- [Provalo tu stesso](https://github.com/manzolo/ubuntu-repo-docker)

Buon packaging! 🚀
