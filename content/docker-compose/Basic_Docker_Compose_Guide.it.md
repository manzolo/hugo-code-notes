---
title: "Guida base a Docker Compose per principianti (Debian/Ubuntu)"
url: "docker-compose/basic_docker_compose_guide/"
date: 2025-10-11T09:55:00+02:00
lastmod: 2026-11-14T19:00:00+01:00
draft: false
author: "Manzolo"
tags: ["docker-compose", "beginner", "nodejs", "postgresql", "tutorial"]
categories: ["Docker & Containers"]
series: ["Docker Essentials"]
weight: 2
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Guida base a Docker Compose per principianti (Debian/Ubuntu)

## Introduzione

Docker Compose è uno strumento per definire e far girare applicazioni Docker fatte di più container, a partire da un semplice file YAML. Questa guida per principianti spiega come installare Docker e Docker Compose su Debian/Ubuntu, creare un `docker-compose.yml` di base per un'applicazione web (Node.js) e un database (PostgreSQL), avviare l'applicazione e gestire i container. È pensata per chi è nuovo a Docker e vuole mettere in piedi in fretta un'applicazione multi-container.

## Cos'è Docker Compose?

Docker Compose semplifica la gestione di più container Docker definendo servizi, reti e volumi in un unico file `docker-compose.yml`. Le caratteristiche principali:
- **Applicazioni multi-container**: fai girare insieme applicazioni web, database e altri servizi.
- **Configurazione semplice**: definisci i container in YAML, con pochissimi comandi.
- **Casi d'uso**: sviluppo, test, o semplici ambienti di produzione.

Come esempio, questa guida mette in piedi un web server Node.js e un database PostgreSQL.

## Prerequisiti

- **Debian/Ubuntu**: Debian 12+ o Ubuntu 22.04+ (le versioni supportate oggi da Docker Engine).
- **Accesso root**: usa `sudo` per l'installazione e per i comandi Docker.
- **Accesso a Internet**: necessario per installare Docker e scaricare le immagini.
- **Strumenti**: `curl` per provare l'applicazione web.
- **Conoscenze di base**: un po' di familiarità con i comandi del terminale.

Verifica il sistema:
```bash
uname -a
```
Output di esempio:
```
Linux ubuntu 5.15.0-73-generic #80-Ubuntu SMP Mon May 15 15:18:26 UTC 2023 x86_64 GNU/Linux
```

## Avviso importante: sicurezza e dati

{{< callout type="warning" >}}
**Attenzione**: i container Docker possono esporre porte su Internet o consumare parecchie risorse. Usa password sicure per i database, non esporre in produzione i container di sviluppo e assicurati che i permessi di Docker siano quelli giusti. Fai un backup dei dati prima di sperimentare.
{{< /callout >}}

## Come usare Docker Compose

### 1. Installare Docker e Docker Compose
[Installa Docker Engine](https://docs.docker.com/engine/install/ubuntu/) e Docker Compose su Debian/Ubuntu.

### 2. Creare la cartella del progetto
Crea una cartella per il tuo progetto Docker Compose:
```bash
mkdir my-app
cd my-app
```

### 3. Creare una semplice applicazione Node.js
Crea un web server Node.js di base per l'esempio.

1. Crea una cartella `backend`:
   ```bash
   mkdir backend
   cd backend
   ```

2. Crea `package.json`:
   ```bash
   echo '{"name": "app", "version": "1.0.0", "main": "server.js", "dependencies": {"express": "^4.17.1"}}' > package.json
   ```

3. Crea `server.js`:
   ```bash
   echo -e 'const express = require("express");\nconst app = express();\napp.get("/", (req, res) => res.send("Hello from Docker Compose!"));\napp.listen(4000, () => console.log("Server running on port 4000"));' > server.js
   ```

4. Crea un `Dockerfile`:
   ```bash
   echo -e 'FROM node:22\nWORKDIR /usr/src/app\nCOPY package.json ./\nRUN npm install\nCOPY . .\nEXPOSE 4000\nCMD ["node", "server.js"]' > Dockerfile
   ```

5. Torna alla radice del progetto:
   ```bash
   cd ..
   ```

### 4. Creare il file docker-compose.yml
Crea un file `docker-compose.yml` per un'applicazione Node.js e un database PostgreSQL:
```bash
nano docker-compose.yml
```

Contenuto:
```yaml
services:
  app:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: app
    ports:
      - "4000:4000"
    depends_on:
      - db
    networks:
      - app-net
    environment:
      - DATABASE_URL=postgres://app:secret@db:5432/app_db

  db:
    image: postgres:16
    container_name: db
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: app_db
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - app-net

networks:
  app-net:
    driver: bridge

volumes:
  db-data:
```

### 5. Avviare l'applicazione
Avvia i container:
```bash
docker compose up -d
```

Verifica che i container siano in esecuzione:
```bash
docker compose ps
```
![Stato dei container di Docker Compose](/images/docker-compose-ps.png "Output di docker compose ps")
Output di esempio (il nome dell'immagine viene dalla cartella del progetto, `my-app`):
```
NAME      IMAGE         COMMAND                  SERVICE   CREATED         STATUS         PORTS
app       my-app-app    "docker-entrypoint.s…"   app       5 seconds ago   Up 5 seconds   0.0.0.0:4000->4000/tcp, [::]:4000->4000/tcp
db        postgres:16   "docker-entrypoint.s…"   db        5 seconds ago   Up 5 seconds   5432/tcp
```

Prova l'applicazione web:
```bash
curl http://localhost:4000
```
Output di esempio:
```
Hello from Docker Compose!
```

### 6. Fermare e rimuovere i container
Ferma e rimuovi i container:
```bash
docker compose down
```

Rimuovi i volumi (facoltativo):
```bash
docker compose down -v
```

## Esempi

### Esempio 1: installare Docker e Docker Compose
[Installa Docker Engine](https://docs.docker.com/engine/install/ubuntu/) e verifica Docker:
```bash
docker compose version
```

**Output**:
```
Docker Compose version v2.40.0
```

### Esempio 2: creare e avviare un'applicazione Docker Compose
Prepara e avvia l'applicazione di esempio:
```bash
mkdir my-app
cd my-app
# Create backend files as shown in Step 3
nano docker-compose.yml  # Add the YAML from Step 4
docker compose up -d
curl http://localhost:4000
```

**Output**:
```
Hello from Docker Compose!
```

### Esempio 3: controllare lo stato dei container
Verifica i container in esecuzione:
```bash
docker compose ps
```

**Output**:
```
NAME      IMAGE         COMMAND                  SERVICE   CREATED         STATUS         PORTS
app       my-app-app    "docker-entrypoint.s…"   app       5 seconds ago   Up 5 seconds   0.0.0.0:4000->4000/tcp, [::]:4000->4000/tcp
db        postgres:16   "docker-entrypoint.s…"   db        5 seconds ago   Up 5 seconds   5432/tcp
```

### Esempio 4: fermare e fare pulizia
Ferma e rimuovi i container:
```bash
docker compose down
```

**Output**:
```
[+] Running 3/3
 ✔ Container app  Removed
 ✔ Container db   Removed
 ✔ Network my-app_app-net  Removed
```

## Varianti

### Usare un altro framework web
Sostituisci l'applicazione Node.js con una in Python Flask:
1. Crea `backend/app.py`:
   ```python
   from flask import Flask
   app = Flask(__name__)
   @app.route('/')
   def hello():
       return 'Hello from Flask!'
   if __name__ == '__main__':
       app.run(host='0.0.0.0', port=4000)
   ```
2. Crea `backend/requirements.txt`:
   ```
   flask==3.1.2
   ```
3. Aggiorna `backend/Dockerfile`:
   ```dockerfile
   FROM python:3.13
   WORKDIR /app
   COPY requirements.txt .
   RUN pip install -r requirements.txt
   COPY . .
   EXPOSE 4000
   CMD ["python", "app.py"]
   ```

4. Aggiorna `docker-compose.yml` perché usi il nuovo `Dockerfile`.

### Aggiungere un file .env
Crea un `.env` per le variabili d'ambiente:
```
POSTGRES_USER=app
POSTGRES_PASSWORD=secret
POSTGRES_DB=app_db
```
Aggiorna `docker-compose.yml`:
```yaml
services:
  db:
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
```

## I comandi in breve
- **docker compose version**: controlla che Docker Compose sia installato.
- **docker compose up -d**: avvia i container in modalità detached.
- **docker compose ps**: elenca i container in esecuzione.
- **docker compose down**: ferma e rimuove i container.
- **docker compose build**: costruisce le immagini dai Dockerfile.
- **curl http://localhost:4000**: prova l'applicazione web.

## Casi d'uso
- **Sviluppo**: far girare in locale applicazioni web con i loro database.
- **Imparare**: sperimentare con configurazioni multi-container.
- **Test**: provare l'interazione tra applicazione e database in container isolati.

## Consigli da esperti
- **Lavora senza sudo**: aggiungi il tuo utente al gruppo `docker` per fare a meno di `sudo`.
- **Usa la modalità detached**: usa `-d` con `docker compose up` per l'esecuzione in background.
- **Controlla i log**: usa `docker compose logs` per fare il debug dei problemi.
- **Tieni aggiornate le immagini**: scarica le ultime immagini con `docker compose pull`.
- **Fai pulizia**: usa `docker compose down -v` per rimuovere i volumi e non accumulare roba inutile.

## Risoluzione dei problemi
- **Permission denied sui comandi Docker**: aggiungi l'utente al gruppo `docker` oppure usa `sudo`:
  ```bash
  sudo usermod -aG docker $USER
  ```
- **Porta già in uso**: cerca i conflitti con `ss -tuln | grep 4000` e cambia le porte in `docker-compose.yml`.
- **Il container esce subito**: controlla i log con `docker compose logs app`.
- **Il pull dell'immagine fallisce**: verifica l'accesso a Internet e il repository indicato in `docker-compose.yml`.
- **Problemi di connessione al database**: assicurati che `DATABASE_URL` corrisponda a `POSTGRES_USER`, `POSTGRES_PASSWORD` e `POSTGRES_DB`.

## Risorse
- [Guida all'installazione di Docker](https://docs.docker.com/engine/install/ubuntu/)
- [Documentazione di Docker Compose](https://docs.docker.com/compose/)
- [Riferimento di Docker Compose](https://docs.docker.com/reference/cli/docker/compose/)

---

*Comincia con Docker Compose su Debian/Ubuntu e fai girare applicazioni multi-container senza fatica!*
