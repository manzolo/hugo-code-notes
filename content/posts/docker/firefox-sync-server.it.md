---
title: "Firefox Sync in casa con Docker"
date: 2026-11-14T10:00:00+01:00
lastmod: 2026-11-14T10:00:00+01:00
draft: false
author: "Manzolo"
tags: ["firefox", "sync", "self-hosting", "docker-compose", "passwords", "privacy"]
categories: ["Docker & Containers"]
series: ["Docker Essentials"]
weight: 5
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "Password, segnalibri e cronologia di Firefox sul proprio server: l'immagine ufficiale syncstorage-rs di Mozilla, un solo file compose, e le trappole di cui nessuno parla"
---

# Firefox Sync in casa con Docker

{{< callout type="info" >}}
**A cosa serve**: Firefox Sync ti piace, ma preferiresti che i dati sincronizzati -
password, segnalibri, cronologia, schede aperte - stessero su una macchina tua. Provato
con Firefox 156 e syncstorage-rs 0.24.1.
{{< /callout >}}

## 🧭 Si sposta lo storage, non l'account

> **L'account Mozilla resta dov'è.** Cambia solo il posto in cui vengono conservati i dati
> cifrati.

È il punto che confonde di più, quindi viene per primo. Firefox Sync è fatto di più
servizi:

| Servizio | Cosa fa | Dove sta dopo questa guida |
|----------|---------|----------------------------|
| **Account Mozilla** | Accesso, password, elenco dei dispositivi | Sempre da Mozilla |
| **Token server** | Dice al browser quale nodo di storage usare | **Sul tuo server** |
| **Sync storage** | Conserva i record sincronizzati | **Sul tuo server** |

Continui ad accedere con lo stesso account. Poi il browser chiede al *tuo* token server
dove mettere i dati, e come risposta riceve il *tuo* nodo di storage.

Due conseguenze da sapere prima di cominciare:

- **Il server non vede mai i tuoi dati.** I record sono cifrati nel browser con una chiave
  derivata dal tuo account. Nel database finisce testo cifrato: più sotto lo vedrai con i
  tuoi occhi.
- **Non c'è un'interfaccia web.** Un server di sync lo usa Firefox, non le persone.

## 📦 Cosa serve

- Una macchina Linux con Docker e Docker Compose
- Un account Mozilla
- Per andare oltre la prova in locale: un nome di dominio e un reverse proxy con HTTPS

Un anno fa voleva dire compilare un progetto Rust da sorgente. Oggi Mozilla pubblica
immagini pronte su `ghcr.io`, una per ogni database. Questa guida usa quella per MySQL.

## 🏗️ Lo stack

Tre file in una cartella.

### `docker-compose.yml`

```yaml
services:
  syncstorage_mysql:
    image: mysql:8.0
    container_name: firefox-sync-mysql
    restart: unless-stopped
    command: --explicit_defaults_for_timestamp
    environment:
      MYSQL_ROOT_PASSWORD: "${MYSQL_ROOT_PASSWORD}"
      MYSQL_USER: "${MYSQL_USER}"
      MYSQL_PASSWORD: "${MYSQL_PASSWORD}"
      TZ: UTC
    volumes:
      - ./mysql_data:/var/lib/mysql
      - ./init-db.sh:/docker-entrypoint-initdb.d/init-db.sh:ro
    networks:
      - sync-net
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -u$$MYSQL_USER -p$$MYSQL_PASSWORD"]
      interval: 5s
      timeout: 5s
      retries: 20
      start_period: 60s

  syncstorage_app:
    image: ghcr.io/mozilla-services/syncstorage-rs/syncserver-mysql:${SYNCSERVER_VERSION:-0.24.1}
    platform: linux/amd64
    container_name: firefox-syncstorage-rs
    restart: unless-stopped
    ports:
      - "${SYNC_BIND:-127.0.0.1:8000}:8000"
    environment:
      SYNC_HOST: "0.0.0.0"
      SYNC_PORT: "8000"
      SYNC_MASTER_SECRET: "${MASTER_SECRET}"
      SYNC_HUMAN_LOGS: "true"
      SYNC_SYNCSTORAGE__DATABASE_URL: "mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@syncstorage_mysql:3306/syncstorage_rs"
      SYNC_TOKENSERVER__DATABASE_URL: "mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@syncstorage_mysql:3306/tokenserver_rs"
      SYNC_TOKENSERVER__ENABLED: "true"
      SYNC_TOKENSERVER__NODE_TYPE: "mysql"
      SYNC_TOKENSERVER__RUN_MIGRATIONS: "true"
      SYNC_TOKENSERVER__FXA_EMAIL_DOMAIN: "api.accounts.firefox.com"
      SYNC_TOKENSERVER__FXA_OAUTH_SERVER_URL: "https://oauth.accounts.firefox.com"
      SYNC_TOKENSERVER__FXA_METRICS_HASH_SECRET: "${FXA_METRICS_SECRET}"
      SYNC_TOKENSERVER__INIT_NODE_URL: "${PUBLIC_URL}"
      SYNC_TOKENSERVER__ALLOW_NEW_USERS: "${ALLOW_NEW_USERS:-true}"
    depends_on:
      syncstorage_mysql:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/__heartbeat__"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    networks:
      - sync-net

networks:
  sync-net:
    driver: bridge
```

Cosa fanno le righe meno ovvie:

| Impostazione | Perché c'è |
|--------------|------------|
| `SYNC_TOKENSERVER__RUN_MIGRATIONS` | Crea le tabelle del token server all'avvio. Quelle dello storage si creano sempre |
| `SYNC_TOKENSERVER__INIT_NODE_URL` | Registra il tuo server come nodo di storage. **Scritto una volta sola, al primo avvio** |
| `SYNC_TOKENSERVER__FXA_*` | Puntano ai server di produzione degli account Mozilla, per validare gli accessi |
| `SYNC_TOKENSERVER__ALLOW_NEW_USERS` | Se gli account mai visti prima possono usare il server. Vedi la sezione sulla chiusura |
| `SYNC_BIND` | La porta è pubblicata solo su `127.0.0.1`, salvo indicazione diversa |

### `init-db.sh`

Un solo MySQL, due database. Lo script gira una volta sola, la prima volta che MySQL parte
su una cartella dati vuota.

```bash
#!/bin/bash
set -e

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<SQL
CREATE DATABASE IF NOT EXISTS syncstorage_rs;
CREATE DATABASE IF NOT EXISTS tokenserver_rs;
GRANT ALL PRIVILEGES ON syncstorage_rs.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON tokenserver_rs.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL
```

```bash
chmod +x init-db.sh
```

### `.env`

```bash
MYSQL_ROOT_PASSWORD=...
MYSQL_USER=syncuser
MYSQL_PASSWORD=...
MASTER_SECRET=...
FXA_METRICS_SECRET=...

# Protocollo + host, senza percorso. Per una prima prova in locale:
PUBLIC_URL=http://localhost:8000
```

I quattro segreti si generano così:

```bash
echo "MYSQL_ROOT_PASSWORD=$(openssl rand -hex 16)"
echo "MYSQL_PASSWORD=$(openssl rand -hex 16)"
echo "MASTER_SECRET=$(openssl rand -hex 32)"
echo "FXA_METRICS_SECRET=$(openssl rand -hex 32)"
```

{{< callout type="warning" >}}
**Esadecimale, non base64.** La password del database finisce dentro un URL di connessione
(`mysql://utente:password@host/db`). Una password in base64 può contenere `/` o `+`, che
in un URL non ci devono stare: i caratteri esadecimali lì sono sempre sicuri.
{{< /callout >}}

```bash
chmod 600 .env
```

## ▶️ Avviarlo e controllarlo

```bash
docker compose up -d
docker compose ps
```

Entrambi i container devono arrivare a `healthy` entro un minuto. Poi:

```bash
curl http://localhost:8000/__heartbeat__
```

```json
{"status":"Ok","database":"Ok","version":"0.24.1","quota":{"enabled":false,"size":2097152000}}
```

{{< figure src="/img/firefox-sync/heartbeat.png" alt="L'endpoint heartbeat aperto in Firefox" caption="`/__heartbeat__` è l'unica pagina che vale la pena aprire nel browser" >}}

Altre due risposte che sembrano guasti e non lo sono:

| Apri | Ottieni | Significato |
|------|---------|-------------|
| `/` | Un rimando alla documentazione dell'API di Mozilla | Normale. Non c'è una pagina iniziale |
| `/1.0/sync/1.5` | `401 Unauthorized` | Normale. Vuole le credenziali che solo Firefox manda |

## 🦊 Puntare Firefox al server

Una sola preferenza. Apri `about:config` e cerca `identity.sync.tokenserver.uri`:

{{< figure src="/img/firefox-sync/about-config-default.png" alt="Il token server predefinito in about:config" caption="Il valore predefinito: il token server di Mozilla" >}}

Cambiala con l'indirizzo del tuo server, **tenendo il percorso `/1.0/sync/1.5`**:

```text
http://localhost:8000/1.0/sync/1.5
```

oppure, quando il server è pubblico:

```text
https://sync.example.com/1.0/sync/1.5
```

{{< figure src="/img/firefox-sync/about-config-custom.png" alt="Il token server cambiato con un URL personalizzato" caption="Il grassetto indica un valore modificato. La freccia a destra rimette quello predefinito" >}}

Riavvia Firefox, poi accedi come sempre da **Impostazioni → Account e sincronizzazione**:

{{< figure src="/img/firefox-sync/sign-in.png" alt="La pagina Account e sincronizzazione prima dell'accesso" caption="L'accesso è ancora quello di Mozilla. Cambia solo quello che succede dopo" >}}

La prima sincronizzazione parte da sola appena sei dentro.

{{< callout type="tip" >}}
**Provalo prima su un profilo usa e getta** (`firefox -P`, creane uno nuovo). Un profilo
vuoto che parla con un server vuoto non può rovinare niente, e quello che hai già sui
server di Mozilla non viene toccato: il browser smette semplicemente di parlarci.
{{< /callout >}}

## 🪤 La trappola: il «Sincronizza adesso» che sincronizza solo le schede

Questa mi è costata venti minuti passati a fissare un database.

Avevo salvato una password, cliccato l'icona dell'account nella barra, letto *«Ultima
sincronizzazione: 1 secondo fa»*, e guardato sul server: **nessuna password**. Di nuovo.
Ancora niente.

La risposta era in una riga del registro di sync (`about:sync-log`):

```text
Sync.Synchronizer   INFO   Syncing specified engines: ["tabs"]
```

Aprire il pannello dell'account fa partire una sincronizzazione rapida delle **sole schede
aperte**. Dice «sincronizzato», ed è vero - per le schede. Tutto il resto aspetta il
prossimo giro completo programmato, che può essere a un'ora di distanza.

Per forzare un giro vero, completo:

```text
Impostazioni → Account e sincronizzazione → Sincronizzazione → Sincronizza adesso
```

Dopo quel pulsante il registro mostra tutti i motori, e la password è sul server.

## 🔎 Guardarlo dal server

Quali account sono registrati:

```bash
docker compose exec syncstorage_mysql sh -c \
  'mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT uid, nodeid FROM tokenserver_rs.users"'
```

Cosa è stato salvato, per collezione:

```bash
docker compose exec syncstorage_mysql sh -c 'mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "
SELECT c.name AS collection, COUNT(*) AS records
FROM syncstorage_rs.bso b
LEFT JOIN syncstorage_rs.collections c ON c.id = b.collection
GROUP BY 1 ORDER BY 2 DESC"'
```

```text
collection   records
bookmarks    9
history      7
forms        3
passwords    1
tabs         1
...
```

E com'è fatta una password vista dal server:

```bash
docker compose exec syncstorage_mysql sh -c 'mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "
SELECT LEFT(b.payload, 45) AS payload
FROM syncstorage_rs.bso b
JOIN syncstorage_rs.collections c ON c.id = b.collection
WHERE c.name = \"passwords\""'
```

```text
{"ciphertext":"T1vbcR3mnM7HAzdLMunw+Fm5CONOdE...
```

Niente sito, niente utente, niente password. È tutto quello che il tuo server avrà mai.

### La prova che lo dimostra davvero

Caricare è metà della storia. Per sapere che i dati possono **tornare indietro**:

```text
1. profilo A: salva una password, Impostazioni → Sincronizza adesso
2. controlla il server: la collezione passwords esiste
3. profilo B (nuovo di zecca, stessa preferenza del token server): accedi
4. about:logins sul profilo B mostra la password
```

Dal lato server, il passo 3 si vede come una semplice `GET /storage/passwords`: nessuna
cancellazione, nessun caricamento. Il browser nuovo ha chiesto, e il server ha risposto.

## 🌍 Renderlo pubblico

Per sincronizzare un telefono, o un portatile fuori casa, il server ha bisogno di un
indirizzo HTTPS pubblico.

**1. Imposta l'URL vero prima del primo avvio.** Sulla macchina di produzione, nel `.env`:

```bash
PUBLIC_URL=https://sync.example.com
SYNC_BIND=0.0.0.0:8000     # solo se il reverse proxy sta su un'altra macchina
```

{{< callout type="warning" >}}
**L'URL del nodo viene scritto nel database al primo avvio, e solo allora.** Se cambi
`PUBLIC_URL` dopo non succede niente: i browser continuano a essere mandati al vecchio
indirizzo. Se devi proprio spostarti, aggiorna la riga a mano:

`UPDATE tokenserver_rs.nodes SET node = 'https://nuovo.example.com' WHERE id = 1;`

Più semplice: avviare la produzione con una `mysql_data/` vuota e l'URL giusto fin
dall'inizio.
{{< /callout >}}

**2. Metti davanti un reverse proxy.** Va bene qualunque. La versione nginx:

```nginx
server {
    listen 443 ssl;
    server_name sync.example.com;

    ssl_certificate     /etc/letsencrypt/live/sync.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sync.example.com/privkey.pem;

    client_max_body_size 100m;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**3. Controllalo da fuori dalla tua rete**, non dal server stesso:

```bash
curl https://sync.example.com/__heartbeat__
```

**4. Cambia la preferenza in ogni browser** con
`https://sync.example.com/1.0/sync/1.5`.

## 🔒 Chiudere la porta dietro di sé

Un server di sync pubblico accetta di default **qualunque account Mozilla**. Chi viene a
conoscere l'URL può usare il tuo disco come storage. I tuoi dati non li può leggere - ma
il disco è tuo.

Quando ogni tuo account ha fatto l'accesso almeno una volta:

```bash
# .env
ALLOW_NEW_USERS=false
```

```bash
docker compose up -d
```

Da quel momento vengono serviti solo gli account già presenti in `tokenserver_rs.users`.
Per far entrare un account nuovo: rimetti `true`, fai l'accesso, richiudi.

## 📱 Firefox per Android

Sulla versione normale non c'è `about:config`, ma c'è un menu nascosto:

```text
1. Impostazioni → Informazioni su Firefox
2. Tocca il logo di Firefox finché non si attiva il menu di debug
3. Di nuovo in Impostazioni: Sync Debug
4. Custom Sync server → https://sync.example.com/1.0/sync/1.5
5. Tocca «Stop Firefox» nello stesso menu, poi riaprilo e accedi
```

L'ordine più semplice è impostarlo **prima** di accedere.

## 🔧 Tutti i giorni

```bash
# Log
docker compose logs -f syncstorage_app

# Aggiornamento: cambia SYNCSERVER_VERSION nel .env, poi
docker compose pull && docker compose up -d

# Backup
docker compose exec -T syncstorage_mysql sh -c \
  'mysqldump -u$MYSQL_USER -p$MYSQL_PASSWORD --databases syncstorage_rs tokenserver_rs' \
  > sync-backup-$(date +%F).sql
```

Fissa la versione. `latest` su un servizio che tiene le tue password è una sorpresa che
aspetta un martedì.

{{< callout type="info" >}}
**Quanto è prezioso il backup?** Meno di quanto sembra. Ogni browser tiene una copia
completa dei propri dati: un server perso si ricostruisce accedendo di nuovo da uno
qualunque. Conserva il `.env` con più cura del database: un `MASTER_SECRET` cambiato
invalida tutti i token già emessi.
{{< /callout >}}

## ↩️ Tornare indietro

Ripristina `identity.sync.tokenserver.uri` (la freccia in `about:config`), riavvia
Firefox, e il browser torna a parlare con i server di Mozilla, dove i tuoi dati sono
esattamente come li avevi lasciati.

## 🪤 Le trappole, in una tabella

| Sintomo | Causa |
|---------|-------|
| «Sincronizzato 1 secondo fa» ma sul server non c'è niente | Il pannello della barra sincronizza solo le schede. Usa **Sincronizza adesso** nelle Impostazioni |
| L'URL del server apre la documentazione di Mozilla | Normale: `/` rimanda lì |
| `401` su `/1.0/sync/1.5` nel browser | Normale: solo Firefox porta le credenziali |
| L'applicazione non si collega al database | Controlla se la password contiene `/` o `+`: sta dentro un URL. Usa l'esadecimale |
| `PUBLIC_URL` cambiato, i browser usano ancora quello vecchio | Il nodo è salvato in `tokenserver_rs.nodes` al primo avvio |
| `init-db.sh` non ha fatto niente | Gira solo su una `mysql_data/` **vuota** |
| Sconosciuti in `tokenserver_rs.users` | `ALLOW_NEW_USERS` lasciato a `true` su un server pubblico |

## 📚 Riferimenti

- [syncstorage-rs](https://github.com/mozilla-services/syncstorage-rs) - il server, e la documentazione attuale (le pagine a cui il server rimanda sono archiviate)
- [Immagini dei container](https://github.com/mozilla-services/syncstorage-rs/pkgs/container/syncstorage-rs%2Fsyncserver-mysql) - i tag pubblicati
