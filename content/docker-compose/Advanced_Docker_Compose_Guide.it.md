---
title: "Guida avanzata a Docker Compose con esempi"
url: "docker-compose/advanced_docker_compose_guide/"
date: 2025-10-11T09:00:00+02:00
lastmod: 2025-10-11T09:00:00+02:00
draft: false
author: "Manzolo"
tags: ["docker-compose", "advanced", "networking", "volumes", "tutorial"]
categories: ["Docker & Containers"]
series: ["Docker Essentials"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Guida avanzata a Docker Compose con esempi pratici

## Indice

1. [Introduzione](#introduction)
2. [Prerequisiti](#prerequisites)
3. [Composizione su più file](#1-multi-file-composition)
4. [Variabili d'ambiente](#2-environment-variables-and-env-files)
5. [Build multi-stage](#3-multi-stage-builds)
6. [Networking avanzato](#4-advanced-networking)
7. [Volumi e persistenza](#5-volumes-and-data-persistence)
8. [Healthcheck](#6-healthchecks-and-dependencies)
9. [Gestione dei secret](#7-secrets-management)
10. [Compose Watch](#8-compose-watch-for-development)
11. [Schemi per la produzione](#9-production-deployment-patterns)
12. [Risoluzione dei problemi](#10-troubleshooting)

---

## Introduzione {#introduction}

Docker Compose è uno strumento potente per definire ed eseguire applicazioni multi-container. Questa guida ne esplora le funzioni avanzate usando come esempio principale un'**applicazione reale Flask + PostgreSQL**.

**Cosa costruiremo**: un'applicazione web pronta per la produzione, con:
- Server web Flask
- Database PostgreSQL con migrazioni
- pgAdmin per gestire il database
- Backup automatici
- Configurazioni di sviluppo e di produzione

**Repository**: [docker-python-flask-postgres-template](https://github.com/manzolo/docker-python-flask-postgres-template)

---

## Prerequisiti {#prerequisites}

### Software necessario

```bash
# Check Docker version (20.10.0+)
docker --version

# Check Docker Compose version (2.0.0+)
docker compose version

# Verify installation
docker run hello-world
```

### Installazione su Debian/Ubuntu

[Installa Docker Engine](https://docs.docker.com/engine/install/ubuntu/) e Docker Compose su Debian/Ubuntu.

# Verifica
```
docker compose version
```

---

## 1. Composizione su più file {#1-multi-file-composition}

### Configurazione di base

Usare più file Compose permette di avere configurazioni specifiche per ogni ambiente senza duplicare codice.

**docker-compose.yml** (configurazione di base):

```yaml
services:
  web:
    build: .
    ports:
      - "${APP_PORT:-5000}:5000"
    environment:
      - FLASK_ENV=${FLASK_ENV:-production}
      - DATABASE_URL=${DATABASE_URL}
    volumes:
      - .:/app
    depends_on:
      db:
        condition: service_healthy
    user: "${UID:-1000}:${GID:-1000}"

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  pgadmin:
    image: dpage/pgadmin4:latest
    environment:
      - PGADMIN_DEFAULT_EMAIL=${PGADMIN_EMAIL}
      - PGADMIN_DEFAULT_PASSWORD=${PGADMIN_PASSWORD}
    ports:
      - "${PGADMIN_PORT:-5050}:80"
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    depends_on:
      - db

volumes:
  postgres_data:
  pgadmin_data:
```

### Override per lo sviluppo

**docker-compose.dev.yml**:

```yaml
services:
  web:
    build:
      context: .
      target: development
    environment:
      - FLASK_ENV=development
      - FLASK_DEBUG=1
    volumes:
      - .:/app
      - /app/__pycache__  # Exclude Python cache
    command: flask run --host=0.0.0.0 --reload
    develop:
      watch:
        - path: ./app
          action: sync+restart
          target: /app

  db:
    # Expose database for local tools
    ports:
      - "5432:5432"
    # Enable query logging
    command: postgres -c log_statement=all

  # Add debugging tools
  adminer:
    image: adminer:latest
    ports:
      - "8080:8080"
    depends_on:
      - db
```

### Override per la produzione

**docker-compose.prod.yml**:

```yaml
services:
  web:
    build:
      context: .
      target: production
    environment:
      - FLASK_ENV=production
    restart: always
    # Remove volume mount (use image code)
    volumes: !reset []
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1'
          memory: 1G

  db:
    restart: always
    # Don't expose port externally
    ports: !reset []
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G

  pgadmin:
    restart: always
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

**Perché `!reset`**: quando Compose unisce i file, le liste vengono **sommate**, non sostituite. Un semplice `volumes: []` o `ports: []` nell'override non toglie niente: il bind mount e la porta pubblicata del file base restano. È `!reset []` a svuotarle davvero (controlla con `docker compose -f docker-compose.yml -f docker-compose.prod.yml config`). Attenzione anche a `replicas: 2` insieme a una porta host fissa nel file base: la seconda replica fallisce con `port is already allocated`. Pubblica un intervallo di porte, oppure lascia la pubblicazione a un reverse proxy.

### Comandi d'uso

```bash
# Development mode
docker compose -f docker-compose.yml -f docker-compose.dev.yml up

# Production mode
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# View merged configuration (debugging)
docker compose -f docker-compose.yml -f docker-compose.dev.yml config

# Use profiles for optional services
docker compose --profile monitoring up
```

---

## 2. Variabili d'ambiente e file .env {#2-environment-variables-and-env-files}

### Struttura del file .env

**.env**:

```bash
# User Configuration (auto-detected)
UID=1000
GID=1000

# Flask Configuration
FLASK_ENV=development
SECRET_KEY=dev-secret-change-in-production
APP_PORT=5000

# PostgreSQL Configuration
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=myapp_db
POSTGRES_PORT=5432

# Database URL
DATABASE_URL=postgresql://postgres:postgres@db:5432/myapp_db

# pgAdmin Configuration
PGADMIN_EMAIL=admin@admin.com
PGADMIN_PASSWORD=admin
PGADMIN_PORT=5050

# Backup Configuration
BACKUP_RETENTION_DAYS=7
```

### File specifici per ambiente

**.env.development**:

```bash
FLASK_ENV=development
FLASK_DEBUG=1
LOG_LEVEL=DEBUG
```

**.env.production**:

```bash
FLASK_ENV=production
FLASK_DEBUG=0
LOG_LEVEL=WARNING
SECRET_KEY=generate-secure-random-key-here
```

### Sostituzione delle variabili in Compose

```yaml
services:
  web:
    # Basic substitution
    image: myapp:${VERSION:-latest}
    
    # With default value
    ports:
      - "${APP_PORT:-5000}:5000"
    
    # Required variable (error if missing)
    environment:
      - DATABASE_URL=${DATABASE_URL:?DATABASE_URL must be set}
    
    # Conditional substitution
    command: ${DEV_COMMAND:-gunicorn app:app}
```

### Buone pratiche di sicurezza

**.gitignore**:

```bash
# Environment files with secrets
.env
.env.local
.env.production

# Keep examples
!.env.example
```

**Generare secret sicuri**:

```bash
# Generate SECRET_KEY
python -c 'import secrets; print(secrets.token_hex(32))'

# Or use OpenSSL
openssl rand -hex 32

# For passwords
openssl rand -base64 24
```

---

## 3. Build multi-stage {#3-multi-stage-builds}

### Esempio con Python Flask

**Dockerfile** con build multi-stage:

```dockerfile
# ============================================
# Stage 1: Base
# ============================================
FROM python:3.12-slim AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements
COPY requirements.txt .

# ============================================
# Stage 2: Dependencies
# ============================================
FROM base AS dependencies

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# ============================================
# Stage 3: Development
# ============================================
FROM dependencies AS development

# Install development tools
RUN pip install --no-cache-dir \
    pytest \
    pytest-cov \
    black \
    flake8

# Copy application code
COPY . .

# Expose ports
EXPOSE 5000

# Development command
CMD ["flask", "run", "--host=0.0.0.0", "--reload"]

# ============================================
# Stage 4: Production
# ============================================
FROM dependencies AS production

# Copy only necessary files
COPY app/ ./app/
COPY migrations/ ./migrations/
COPY entrypoint.sh .
COPY alembic.ini .

# Create non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

# Make entrypoint executable
RUN chmod +x entrypoint.sh

EXPOSE 5000

ENTRYPOINT ["./entrypoint.sh"]
```

### Usare gli stage in Compose

```yaml
services:
  web-dev:
    build:
      context: .
      target: development  # Use dev stage
    profiles:
      - dev

  web-prod:
    build:
      context: .
      target: production   # Use prod stage
    profiles:
      - prod
```

### Ottimizzare la build

**.dockerignore**:

```bash
# Python
__pycache__/
*.py[cod]
*.egg-info/

# Environment
.env
.env.*

# IDE
.vscode/
.idea/

# Database
postgres_data/
*.db

# Git
.git/
.gitignore

# Documentation
*.md
docs/
```

---

## 4. Networking avanzato {#4-advanced-networking}

### Isolamento delle reti

**docker-compose.yml** con reti isolate:

```yaml
services:
  web:
    build: .
    networks:
      - frontend
      - backend

  api:
    build: ./api
    networks:
      - backend
      - database

  db:
    image: postgres:15-alpine
    networks:
      - database  # Only accessible to backend

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    networks:
      - frontend  # Public facing

networks:
  frontend:
    driver: bridge
  
  backend:
    driver: bridge
    internal: true  # No external access
  
  database:
    driver: bridge
    internal: true  # Maximum isolation
```

### Configurazione di rete personalizzata

```yaml
networks:
  app_network:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: br-app
      com.docker.network.driver.mtu: 1500
    ipam:
      driver: default
      config:
        - subnet: 172.28.0.0/16
          gateway: 172.28.0.1
```

### Debug della rete

```bash
# List networks
docker network ls

# Inspect network
docker network inspect myapp_backend

# Test connectivity
docker compose exec web ping db

# Check DNS resolution
docker compose exec web nslookup db

# View container IP
docker compose exec web hostname -i
```

---

## 5. Volumi e persistenza dei dati {#5-volumes-and-data-persistence}

### Volumi con nome

```yaml
services:
  db:
    image: postgres:15-alpine
    volumes:
      # Named volume for data
      - postgres_data:/var/lib/postgresql/data
      
      # Bind mount for backups
      - ./backups:/backups
      
      # Bind mount for init scripts
      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init.sql:ro

volumes:
  postgres_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/data/postgres
```

### Comandi per gestire i volumi

```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect myapp_postgres_data

# Backup volume
docker run --rm \
  -v myapp_postgres_data:/source:ro \
  -v $(pwd)/backups:/backup \
  alpine \
  tar -czf /backup/db_backup.tar.gz -C /source .

# Restore volume
docker run --rm \
  -v myapp_postgres_data:/target \
  -v $(pwd)/backups:/backup \
  alpine \
  tar -xzf /backup/db_backup.tar.gz -C /target

# View volume contents
docker run --rm -v myapp_postgres_data:/data alpine ls -lah /data

# Remove unused volumes
docker volume prune
```

### Esempio di script di backup

**scripts/backup.sh**:

```bash
#!/bin/bash

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./backups"
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.sql"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup database
docker compose exec -T db pg_dump \
  -U $POSTGRES_USER \
  $POSTGRES_DB > $BACKUP_FILE

# Compress
gzip $BACKUP_FILE

echo "✓ Backup created: ${BACKUP_FILE}.gz"

# Cleanup old backups (keep last 7 days)
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +7 -delete
```

---

## 6. Healthcheck e dipendenze {#6-healthchecks-and-dependencies}

### Configurazione degli healthcheck

```yaml
services:
  db:
    image: postgres:15-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  web:
    build: .
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

### Endpoint di health check (Flask)

**app/routes.py**:

```python
from flask import Blueprint, jsonify
from . import db

bp = Blueprint('main', __name__)

@bp.route('/api/health')
def health_check():
    """Health check endpoint for Docker"""
    try:
        # Test database connection
        db.session.execute(db.text('SELECT 1'))
        db_status = 'healthy'
    except Exception as e:
        db_status = f'unhealthy: {str(e)}'
        return jsonify({
            'status': 'error',
            'database': db_status
        }), 503
    
    return jsonify({
        'status': 'ok',
        'database': db_status,
        'message': 'Application is running'
    }), 200
```

### Script di avvio del container

**entrypoint.sh**:

```bash
#!/bin/bash
set -e

echo "=== Starting Flask Application ==="

# Wait for database
echo "Waiting for database..."
until psql "$DATABASE_URL" -c '\l' > /dev/null 2>&1; do
  echo "  Database unavailable - sleeping"
  sleep 2
done

echo "✓ Database ready"

# Run migrations
echo "Applying migrations..."
alembic upgrade head

echo "✓ Migrations applied"

# Start application
echo "Starting Flask server..."
exec flask run --host=0.0.0.0 --port=5000
```

---

## 7. Gestione dei secret {#7-secrets-management}

### Usare i Docker Secrets (modalità Swarm)

```yaml
services:
  web:
    image: myapp:latest
    secrets:
      - db_password
      - secret_key
    environment:
      DATABASE_PASSWORD_FILE: /run/secrets/db_password
      SECRET_KEY_FILE: /run/secrets/secret_key

secrets:
  db_password:
    file: ./secrets/db_password.txt
  
  secret_key:
    file: ./secrets/secret_key.txt
```

### Caricare i secret in Python

**app/config.py**:

```python
import os

def load_secret(secret_name, env_var=None):
    """Load secret from file or environment"""
    # Try Docker secret file
    secret_path = f'/run/secrets/{secret_name}'
    if os.path.exists(secret_path):
        with open(secret_path, 'r') as f:
            return f.read().strip()
    
    # Try environment variable with _FILE suffix
    if env_var:
        file_path = os.getenv(f'{env_var}_FILE')
        if file_path and os.path.exists(file_path):
            with open(file_path, 'r') as f:
                return f.read().strip()
        
        # Try direct environment variable
        return os.getenv(env_var)
    
    raise ValueError(f'Secret {secret_name} not found')

# Usage
DATABASE_PASSWORD = load_secret('db_password', 'DATABASE_PASSWORD')
SECRET_KEY = load_secret('secret_key', 'SECRET_KEY')
```

### Script per generare i secret

**scripts/generate-secrets.sh**:

```bash
#!/bin/bash

SECRETS_DIR="./secrets"
mkdir -p $SECRETS_DIR
chmod 700 $SECRETS_DIR

# Generate database password
openssl rand -base64 32 > $SECRETS_DIR/db_password.txt

# Generate secret key
openssl rand -hex 32 > $SECRETS_DIR/secret_key.txt

# Set permissions
chmod 600 $SECRETS_DIR/*

echo "✓ Secrets generated in $SECRETS_DIR"
echo "  Add $SECRETS_DIR/ to .gitignore"
```

---

## 8. Compose Watch per lo sviluppo {#8-compose-watch-for-development}

### Configurazione di watch (Docker Compose 2.22+)

```yaml
services:
  web:
    build:
      context: .
      target: development
    develop:
      watch:
        # Sync Python code changes
        - path: ./app
          action: sync+restart
          target: /app/app
          ignore:
            - __pycache__/
            - "*.pyc"
        
        # Rebuild on requirements change
        - path: ./requirements.txt
          action: rebuild
        
        # Sync templates without restart
        - path: ./app/templates
          action: sync
          target: /app/app/templates
```

### Uso

```bash
# Start with watch mode
docker compose watch

# Watch specific services
docker compose watch web

# Watch with build
docker compose up --watch
```

---

## 9. Schemi di deploy in produzione {#9-production-deployment-patterns}

### Makefile di produzione

**Makefile**:

```makefile
.PHONY: prod-build prod-up prod-down prod-logs

prod-build:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml build

prod-up:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
	@echo "✓ Production environment started"
	@docker compose ps

prod-down:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml down

prod-logs:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml logs -f

prod-backup:
	@mkdir -p ./backups
	@docker compose exec -T db pg_dump -U $$POSTGRES_USER $$POSTGRES_DB | \
		gzip > ./backups/backup_$$(date +%Y%m%d_%H%M%S).sql.gz
	@echo "✓ Backup created"
```

### Script di deploy

**deploy.sh**:

```bash
#!/bin/bash
set -e

echo "=== Production Deployment ==="

# Create backup
echo "Creating backup..."
make prod-backup

# Pull latest code
echo "Pulling latest changes..."
git pull origin main

# Build images
echo "Building images..."
make prod-build

# Run migrations
echo "Running migrations..."
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  run --rm web alembic upgrade head

# Deploy
echo "Deploying..."
make prod-down
make prod-up

echo "✓ Deployment complete"
```

---

## 10. Risoluzione dei problemi {#10-troubleshooting}

### Problemi comuni

**Vedere i log**:
```bash
# All logs
docker compose logs

# Specific service
docker compose logs web

# Follow logs
docker compose logs -f

# Last 100 lines
docker compose logs --tail=100
```

**Controllare lo stato dei container**:
```bash
# List containers
docker compose ps

# Detailed status
docker compose ps -a

# Resource usage
docker stats
```

**Fare debug di un container**:
```bash
# Enter container
docker compose exec web bash

# Run command
docker compose exec web flask shell

# Check environment
docker compose exec web env
```

**Problemi di rete**:
```bash
# Test connectivity
docker compose exec web ping db

# Check DNS
docker compose exec web nslookup db

# Inspect network
docker network inspect myapp_default
```

**Azzerare tutto**:
```bash
# Stop and remove
docker compose down -v

# Clean system
docker system prune -a --volumes

# Restart
docker compose up --build
```

---

## Riferimento rapido

### Comandi essenziali

```bash
# Start
docker compose up -d

# Stop
docker compose down

# Rebuild
docker compose up --build

# View logs
docker compose logs -f web

# Execute command
docker compose exec web bash

# Check status
docker compose ps

# View configuration
docker compose config
```

### Buone pratiche

1. **Usa sempre i file .env** per la configurazione
2. **Non fare mai il commit dei secret** nel controllo di versione
3. **Usa gli healthcheck** per tutti i servizi
4. **Imposta un logging fatto bene**, con rotazione
5. **Fai backup regolari** dei volumi dati
6. **Usa le build multi-stage** per ridurre la dimensione delle immagini
7. **Isola le reti** per sicurezza
8. **Prova in locale** prima del deploy

---

## Altre risorse

- [Documentazione ufficiale di Docker Compose](https://docs.docker.com/compose/)
- [Riferimento del file Compose](https://docs.docker.com/compose/compose-file/)
- [Repository di esempio](https://github.com/manzolo/docker-python-flask-postgres-template)
- [Buone pratiche per Docker](https://docs.docker.com/develop/dev-best-practices/)

---
