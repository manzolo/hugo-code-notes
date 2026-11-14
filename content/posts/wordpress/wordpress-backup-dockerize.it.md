---
title: "Wordpress: backup (file e database) e dockerizzazione"
url: "2025/09/wordpress-backing-up-files-and-database-and-dockerizing/"
date: 2025-09-27T09:20:30Z
lastmod: 2026-11-14T19:00:00+01:00
categories: ["Docker & Containers"]
series: ["Docker Essentials"]
tags: ["wordpress", "backup", "docker", "mysql", "migration"]
draft: false
---

# Guida all'uso dello script di gestione di WordPress

## Introduzione

Lo [script](https://github.com/manzolo/BashCollection/blob/main/utils/wordpress/wp-management.sh) `wp-management` è un potente strumento Bash pensato per semplificare la gestione dei siti WordPress. Ha due funzioni principali: il **backup** di un sito WordPress (file e database compresi) e la **dockerizzazione** di un sito WordPress, per farlo girare in un ambiente a container con il ripristino automatico dei backup. Questa guida spiega a cosa serve lo script e come si usa, con esempi pratici per cominciare.

## Cos'è lo script `wp-management`?

Lo script `wp-management` automatizza le operazioni essenziali di gestione di un sito WordPress:

1. **Backup**:
   - Crea un backup completo di un sito WordPress, che comprende:
     - La cartella `wp-content` (temi, plugin, upload) come archivio `.tar.gz`.
     - Il file di configurazione `wp-config.php`.
     - Il database MySQL/MariaDB come file `.sql`.
     - Un file di testo `backup_info` che riassume i dettagli del backup.

2. **Dockerizzazione**:
   - Prepara un ambiente Docker per un sito WordPress, generando:
     - Un file `.env` con le variabili di configurazione.
     - Un file `docker-compose.yml` che definisce i container di MariaDB, WordPress e phpMyAdmin.
     - Uno script `manage.sh` per controllare l'ambiente Docker (start, stop, backup, restore, ecc.).
     - Un `README.md` con le istruzioni d'uso.
   - Controlla e crea da solo le reti Docker necessarie (`wp-net` e `nginx-net`).
   - Ripristina `wp-content` e il database dai backup esistenti, se ci sono.

Lo script è l'ideale per sviluppatori, sistemisti o proprietari di siti WordPress che devono mettere al sicuro i dati del sito, portarlo su Docker o ripristinarlo da un backup.

## Prerequisiti

Prima di usare lo script, assicurati di avere installato sul sistema:
- **Bash**: serve per eseguire lo script (disponibile su Linux/macOS, o con WSL su Windows).
- **Client MySQL**: serve per i backup del database (è richiesto `mysqldump`).
- **Docker e Docker Compose**: servono per la dockerizzazione (con le versioni recenti usa `docker compose`).
- **Un sito WordPress o un backup**: la cartella di un sito WordPress con un `wp-config.php` valido, oppure una cartella di backup con i file `wp-config_*.php`, `wp-content_*.tar.gz` e `database_*.sql`.
- **Permessi**: accesso in scrittura alle cartelle dei backup e dei file Docker.
- **Facoltativo**: `openssl` per generare password sicure durante la dockerizzazione.

Installa le dipendenze su Ubuntu/Debian:
```bash
sudo apt update
sudo apt install mysql-client docker.io docker-compose-v2
sudo apt install openssl  # Optional, for secure password generation
```

## Come si usa lo script

### 1. Preparazione
1. **Salva lo script**: salva lo script `wp-management` in un file chiamato `wp-management`.
2. **Rendilo eseguibile**:
   ```bash
   chmod +x wp-management
   ```
3. **Metti lo script al suo posto**: mettilo in una cartella da cui si raggiungono le cartelle dei tuoi siti WordPress o la cartella dei backup.

### 2. Uso dello script
Lo script accetta due comandi: `backup` e `dockerize`. La sintassi generale è:
```bash
./wp-management {backup|dockerize} <site_name>
```
- `backup`: fa il backup del sito WordPress chiamato `<site_name>`.
- `dockerize`: crea un ambiente Docker per il sito WordPress chiamato `<site_name>`, ripristinando da solo i backup se ci sono.
- `<site_name>`: il nome della cartella che contiene il sito WordPress (es. `mysite` per `./mysite`) o della cartella di backup (es. `./backup/mysite`).

### 3. Struttura delle cartelle
Per i backup, lo script si aspetta il sito WordPress in una cartella chiamata `<site_name>`:
```
./mysite/wp-content/
./mysite/wp-config.php
./wp-management
```
Per la dockerizzazione può usare sia la cartella del sito sia una cartella di backup:
```
./backup/mysite/wp-content_20250927_110715.tar.gz
./backup/mysite/wp-config_20250927_110715.php
./backup/mysite/database_20250927_110715.sql
./wp-management
```

### 4. Configurazione delle reti Docker
Lo script controlla da solo le reti Docker necessarie (`wp-net` e `nginx-net`) e le crea se non esistono, così i container comunicano senza intoppi.

## Esempi

### Esempio 1: backup di un sito WordPress
Supponiamo che tu abbia un sito WordPress nella cartella `./mysite`.

**Comando**:
```bash
./wp-management backup mysite
```

**Cosa succede**:
- Lo script verifica la cartella `./mysite` e il suo file `wp-config.php`.
- Estrae le credenziali del database (`DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`) da `wp-config.php`.
- Crea una cartella di backup (`./backup/mysite`).
- Salva:
  - `wp-content` come `wp-content_20250927_110715.tar.gz`.
  - `wp-config.php` come `wp-config_20250927_110715.php`.
  - Il database come `database_20250927_110715.sql`.
  - Un file `backup_info_20250927_110715.txt` con i dettagli.
- L'output è a colori (es. verde per i successi, rosso per gli errori).

**Risultato**:
I file di backup finiscono in `./backup/mysite`. Puoi usarli per un ripristino o per una migrazione.

### Esempio 2: dockerizzare un sito WordPress ripristinando il backup
Supponiamo che tu abbia un sito WordPress in `./mysite` oppure dei backup in `./backup/mysite`.

**Comando**:
```bash
./wp-management dockerize mysite
```

**Cosa succede**:
- Lo script cerca `wp-config.php` in `./mysite` o in `./backup/mysite`.
- Se trova più backup `wp-config_*.php`, ti chiede di sceglierne uno oppure di copiare quello che vuoi in `./mysite/wp-config.php`.
- Estrae le credenziali del database da `wp-config.php`.
- Crea una cartella Docker (`./docker-mysite`) con:
  - `.env`: le variabili d'ambiente (es. credenziali del database, nomi dei container).
  - `docker-compose.yml`: definisce i container di MariaDB, WordPress e phpMyAdmin.
  - `manage.sh`: uno script per gestire i container.
  - `README.md`: le istruzioni d'uso.
- Controlla le reti Docker (`wp-net`, `nginx-net`) e le crea se mancano.
- Se in `./backup/mysite` ci sono dei backup:
  - Ripristina `wp-content` dall'ultimo `wp-content_*.tar.gz` in `./docker-mysite/wp-data`.
  - Copia l'ultimo `database_*.sql` in `./docker-mysite/restore_database.sql`, avvia il container del database e ripristina il database.
- Si ferma ad aspettare la tua conferma prima dei passaggi critici (es. il ripristino del database).

**Risultato**:
L'ambiente Docker è pronto in `./docker-mysite`. Per avviare i container:
```bash
cd docker-mysite
docker compose up -d
```

**Accesso**:
- **WordPress**: ci arrivi tramite un reverse proxy, oppure togli il commento alla mappatura della porta in `docker-compose.yml` (es. `8080:80`) per raggiungerlo su `http://localhost:8080`.
- **phpMyAdmin**: ci arrivi tramite un reverse proxy, oppure togli il commento alla mappatura della porta (es. `8081:80`) per raggiungerlo su `http://localhost:8081`.

**Gestire i container**:
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

### Esempio 3: ripristino manuale del database
Se hai un file di backup del database, puoi ripristinarlo a mano.

**Passaggi**:
1. Metti il file `.sql` nella cartella Docker con il nome `restore_database.sql`:
   ```bash
   cp ./backup/mysite/database_20250927_110715.sql ./docker-mysite/restore_database.sql
   ```
2. Lancia il comando di ripristino:
   ```bash
   cd docker-mysite
   ./manage.sh restore-db
   ```

**Cosa succede**:
- Lo script controlla che il container del database sia in esecuzione e pronto.
- Ripristina il database da `restore_database.sql` usando `mariadb`, oppure `mysql` come ripiego.
- Ti dice se è andata bene o male e, se serve, ti dà le istruzioni per il ripristino manuale.

### Esempio 4: controllare lo stato dei container
Per verificare lo stato dei tuoi container Docker:
```bash
cd docker-mysite
./manage.sh status
```

**Esempio di output**:
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

## Casi d'uso
- **Backup**:
  - Fare backup regolari prima degli aggiornamenti di WordPress o delle migrazioni.
  - Tenere i backup al sicuro per il disaster recovery.
  - Usare i backup per ripristinare un sito in un ambiente Docker.
- **Dockerizzazione**:
  - Sviluppare o provare siti WordPress in un ambiente coerente e isolato.
  - Mettere i siti in produzione dietro un reverse proxy (es. Nginx).
  - Ripristinare siti esistenti dai backup per averli pronti in fretta.
- **Gestione del database**:
  - Usare `manage.sh backup` per creare snapshot del database.
  - Usare `manage.sh restore-db` per ripartire da un backup o migrare i dati.

## Consigli pratici
- **Automatizza i backup**: pianificali con `cron`:
  ```bash
  0 2 * * * /path/to/wp-management backup mysite
  ```
  Così il backup parte ogni giorno alle 2 di notte.
- **Metti al sicuro i backup**: sposta i file di backup su uno storage cloud o in un'altra sede.
- **Se i backup sono più di uno**: quando esistono più file `wp-config_*.php`, copia quello che vuoi in `./mysite/wp-config.php` per evitare ambiguità.
- **Tunnel SSH per i siti remoti**: usa un tunnel SSH (port forwarding locale) per raggiungere un database remoto:
  ```bash
  ssh -L 3306:dbserver.local:3306 user@ssh.example.com
  ```
  Lo script si collega al `DB_HOST` che legge da `wp-config.php`: perché il backup passi dal tunnel, nella copia locale di `wp-config.php` imposta `DB_HOST` a `127.0.0.1` (non `localhost`, che fa usare al client MySQL il socket Unix locale invece del tunnel).
- **Tieni d'occhio i container**: usa `./manage.sh status` per controllare la salute dei container prima di un backup o di un ripristino.

## Risoluzione dei problemi
- **Cartella non trovata**: controlla che la cartella `<site_name>` o `./backup/<site_name>` esista e contenga file validi.
- **Più backup**: se vengono trovati più file `wp-config_*.php`, copia a mano quello che vuoi nella cartella del sito.
- **Dipendenze mancanti**: installa `mysqldump`, `docker` e `docker-compose-v2` secondo necessità.
- **Conflitti di porte in Docker**: cambia le mappature delle porte in `docker-compose.yml` se `8080` o `8081` sono già occupate.
- **Errori del database**: verifica le credenziali del database in `wp-config.php` e controlla che il server MySQL/MariaDB sia in esecuzione.
- **Container non pronto**: usa `./manage.sh status` per controllare che i container siano in esecuzione e in salute prima di un ripristino.

## Risorse
- [Documentazione di WordPress](https://wordpress.org/documentation/)
- [Riferimento di Docker Compose](https://docs.docker.com/compose/)
- [Documentazione di MariaDB](https://mariadb.com/kb/en/documentation/)

---

*Usa lo script `wp-management` per gestire in modo efficiente i tuoi siti WordPress, tra backup e deploy su Docker!*
