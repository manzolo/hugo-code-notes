---
title: "Docker e Docker Compose"
url: "bash/docker/"
#description: ""
date: 2025-09-26T10:00:00+01:00
lastmod: 2025-09-26T10:00:00+01:00
draft: false
author: "Manzolo"
tags: ["docker", "docker-compose", "containers", "commands", "cheatsheet"]
categories: ["Command Reference"]
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

# Guida a Docker e Docker Compose

## Introduzione

Docker è una piattaforma per sviluppare, distribuire ed eseguire applicazioni dentro i container. Docker Compose è uno strumento per definire ed eseguire applicazioni Docker con più container usando file YAML. Questa guida copre i comandi essenziali di Docker e Docker Compose, con esempi pratici, per aiutarti a gestire i container in modo efficace.

## Che cos'è Docker?

Docker ti permette di impacchettare le applicazioni con le loro dipendenze dentro dei container, garantendo lo stesso comportamento in ambienti diversi. I container sono leggeri, portabili e girano in modo indipendente dal sistema host.

## Che cos'è Docker Compose?

Docker Compose semplifica la gestione delle applicazioni con più container definendo servizi, reti e volumi in un unico file YAML. Ti permette di avviare, fermare e configurare più container con un solo comando.

## Prerequisiti

- Docker installato sul sistema (`docker --version` per verificare).
- Docker Compose v2 installato (`docker compose version`). È un plugin del comando `docker`: il vecchio `docker-compose` autonomo (con il trattino) è stato ritirato.
- Una conoscenza di base dei comandi da terminale.

## Comandi base di Docker

### Gestione dei container

```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Run a container
docker run -d --name my_container -p 8080:80 nginx

# Stop a container
docker stop my_container

# Start a stopped container
docker start my_container

# Remove a container
docker rm my_container

# Remove all stopped containers
docker container prune
```

### Gestione delle immagini

```bash
# List images
docker images

# Pull an image from Docker Hub
docker pull nginx:latest

# Build an image from a Dockerfile
docker build -t my_image:tag .

# Remove an image
docker rmi my_image:tag

# Remove unused images
docker image prune
```

### Log e ispezione

```bash
# View container logs
docker logs my_container

# Follow container logs in real-time
docker logs -f my_container

# Inspect container details
docker inspect my_container

# View container resource usage
docker stats
```

## Le basi di Docker Compose

Docker Compose usa un file `docker-compose.yml` per definire i servizi. Qui sotto un esempio per un'applicazione web con un database.

### Esempio: una semplice web app con Nginx e MySQL

```yaml
services:
  web:
    image: nginx:latest
    ports:
      - "8080:80"
    volumes:
      - ./html:/usr/share/nginx/html
    depends_on:
      - db
  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: example_password
      MYSQL_DATABASE: myapp
    volumes:
      - db_data:/var/lib/mysql
volumes:
  db_data:
```

### Spiegazione

- `version`: indica il formato del file di Docker Compose.
- `services`: definisce i container (per esempio `web` per Nginx, `db` per MySQL).
- `ports`: mappa la porta `8080` dell'host sulla porta `80` del container.
- `volumes`: rende persistenti i dati di MySQL e monta una cartella locale `html` per Nginx.
- `environment`: imposta le variabili di configurazione di MySQL.
- `depends_on`: fa in modo che il database parta prima del servizio web.

### Comandi di Docker Compose

```bash
# Start services defined in docker-compose.yml
docker compose up -d

# Stop and remove services
docker compose down

# View logs for all services
docker compose logs

# Follow logs in real-time
docker compose logs -f

# List running services
docker compose ps

# Build or rebuild services
docker compose build

# Restart services
docker compose restart

# Remove stopped service containers
docker compose rm -f
```

## Comandi utili di Docker

### Reti

```bash
# List networks
docker network ls

# Create a custom network
docker network create my_network

# Run a container in a specific network
docker run -d --network my_network --name my_container nginx

# Inspect a network
docker network inspect my_network
```

### Volumi

```bash
# List volumes
docker volume ls

# Create a volume
docker volume create my_volume

# Remove unused volumes
docker volume prune

# Inspect a volume
docker volume inspect my_volume
```

### Manutenzione del sistema

```bash
# Remove all unused containers, networks, and images
docker system prune -a

# View Docker system information
docker info

# Check Docker version
docker --version
```

## Uno script pratico

Crea uno script per controllare e gestire un ambiente Docker Compose:

```bash
#!/bin/bash
# manage_docker.sh

echo "=== Docker Compose Management ==="
echo "Current directory: $(pwd)"
echo ""

echo "Starting services..."
docker compose up -d

echo ""
echo "Running containers:"
docker compose ps

echo ""
echo "System status:"
docker info --format '{{.ContainersRunning}} containers running, {{.Images}} images'

echo ""
echo "Cleaning up unused resources..."
docker system prune -f
```

Rendilo eseguibile:

```bash
chmod +x manage_docker.sh
./manage_docker.sh
```

## Consigli da esperto

{{< callout type="tip" >}}
**Consiglio**: usa `docker-compose.yml` per avere ambienti riproducibili. Metti questo file sotto controllo di versione per tenere traccia delle modifiche.
{{< /callout >}}

{{< callout type="warning" >}}
**Attenzione**: vacci piano con `docker system prune -a`, perché rimuove tutte le immagini inutilizzate, comprese quelle che potrebbero servirti più avanti.
{{< /callout >}}

{{< callout type="success" title="Quick Reference" >}}
**Scorciatoie essenziali:**
- `docker compose up -d`: avvia i servizi in modalità detached.
- `docker compose down -v`: ferma i servizi e rimuove i volumi.
- `docker ps -q`: elenca solo gli ID dei container.
- `docker stop $(docker ps -q)`: ferma tutti i container in esecuzione.
{{< /callout >}}

## Risoluzione dei problemi

- **Il container non parte**: controlla i log con `docker logs <container_name>` oppure `docker compose logs`.
- **Conflitti di porta**: verifica che la porta dell'host (per esempio `8080`) non sia già in uso (`netstat -tuln`).
- **Problemi nel pull delle immagini**: verifica la connessione a internet oppure cerca l'immagine su Docker Hub.
- **Problemi di permessi sui volumi**: assicurati che l'utente dell'host abbia accesso alle cartelle montate.

## Prossimi passi

Nei prossimi tutorial vedremo:
- Scrivere Dockerfile efficienti.
- Le reti di Docker e il service discovery.
- L'orchestrazione con Docker Swarm o Kubernetes.
- L'integrazione di Docker nella CI/CD.

## Esercizi pratici

1. **Preparare una web app**: crea un `docker-compose.yml` per un'applicazione Node.js con un database MongoDB.
2. **Analisi dei log**: scrivi uno script che segua i log di un servizio specifico.
3. **Pulizia delle risorse**: crea uno script che rimuova tutti i container fermi e le immagini inutilizzate.
4. **Applicazione con più container**: costruisci un file Compose per una web app, un database e una cache (per esempio Redis).

## Risorse

- [Documentazione di Docker](https://docs.docker.com/)
- [Riferimento di Docker Compose](https://docs.docker.com/compose/)
- [Docker Hub](https://hub.docker.com/)
- [Awesome Docker](https://github.com/veggiemonk/awesome-docker)

---

*Fai pratica costruendo e gestendo container per padroneggiare Docker e Docker Compose!*
