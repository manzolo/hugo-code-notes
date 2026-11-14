---
title: "Self-Hosting Firefox Sync with Docker"
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
description: "Keep your Firefox passwords, bookmarks and history on your own server: Mozilla's official syncstorage-rs image, one compose file, and the traps nobody mentions"
---

# Self-Hosting Firefox Sync with Docker

{{< callout type="info" >}}
**Use case**: you like Firefox Sync, but you would rather the synced data - passwords,
bookmarks, history, open tabs - sat on a machine you own. Tested with Firefox 156 and
syncstorage-rs 0.24.1.
{{< /callout >}}

## 🧭 You move the storage, not the account

> **Your Mozilla account stays where it is.** Only the place where the encrypted data is
> stored changes.

This is the part that confuses people, so it comes first. Firefox Sync is two services:

| Service | What it does | Where it lives after this guide |
|---------|--------------|---------------------------------|
| **Mozilla accounts** | Login, password, device list | Still at Mozilla |
| **Token server** | Tells the browser which storage node to use | **Your server** |
| **Sync storage** | Holds the synced records | **Your server** |

You keep signing in with the same account. The browser then asks *your* token server
where to put the data, and gets *your* storage node as the answer.

Two consequences worth knowing before you start:

- **The server never sees your data.** Records are encrypted in the browser with a key
  derived from your account. What lands in the database is ciphertext - you will see it
  with your own eyes below.
- **There is no web interface.** A sync server is used by Firefox, not by people.

## 📦 What you need

- A Linux host with Docker and Docker Compose
- A Mozilla account
- For anything beyond a local trial: a domain name and a reverse proxy with HTTPS

A year ago this meant compiling a Rust project from source. Today Mozilla publishes
ready-made images on `ghcr.io`, one per database backend. This guide uses the MySQL one.

## 🏗️ The stack

Three files in one directory.

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

What the less obvious lines do:

| Setting | Why it is there |
|---------|-----------------|
| `SYNC_TOKENSERVER__RUN_MIGRATIONS` | Creates the token server tables at startup. The storage tables are always created |
| `SYNC_TOKENSERVER__INIT_NODE_URL` | Registers your server as the storage node. **Written once, on first start** |
| `SYNC_TOKENSERVER__FXA_*` | Points at Mozilla's production account servers, to validate logins |
| `SYNC_TOKENSERVER__ALLOW_NEW_USERS` | Whether accounts never seen before may use the server. See the lock-down section |
| `SYNC_BIND` | The port is published on `127.0.0.1` only, unless you say otherwise |

### `init-db.sh`

One MySQL instance, two databases. The script runs once, the first time MySQL starts on
an empty data directory.

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

# Protocol + host, no path. For a first local trial:
PUBLIC_URL=http://localhost:8000
```

Generate the four secrets like this:

```bash
echo "MYSQL_ROOT_PASSWORD=$(openssl rand -hex 16)"
echo "MYSQL_PASSWORD=$(openssl rand -hex 16)"
echo "MASTER_SECRET=$(openssl rand -hex 32)"
echo "FXA_METRICS_SECRET=$(openssl rand -hex 32)"
```

{{< callout type="warning" >}}
**Use hex, not base64.** The database password ends up inside a connection URL
(`mysql://user:password@host/db`). A base64 password can contain `/` or `+`, which do
not belong in a URL: hex characters are always safe there.
{{< /callout >}}

```bash
chmod 600 .env
```

## ▶️ Start it and check it

```bash
docker compose up -d
docker compose ps
```

Both containers should reach `healthy` within a minute. Then:

```bash
curl http://localhost:8000/__heartbeat__
```

```json
{"status":"Ok","database":"Ok","version":"0.24.1","quota":{"enabled":false,"size":2097152000}}
```

{{< figure src="/img/firefox-sync/heartbeat.png" alt="The heartbeat endpoint opened in Firefox" caption="`/__heartbeat__` is the only page worth opening in a browser" >}}

Two more answers that look like failures and are not:

| You open | You get | Meaning |
|----------|---------|---------|
| `/` | A redirect to Mozilla's API documentation | Normal. There is no home page |
| `/1.0/sync/1.5` | `401 Unauthorized` | Normal. It wants the credentials only Firefox sends |

## 🦊 Point Firefox at it

One preference. Open `about:config` and search for `identity.sync.tokenserver.uri`:

{{< figure src="/img/firefox-sync/about-config-default.png" alt="The default token server in about:config" caption="The default: Mozilla's token server" >}}

Change it to your server, **keeping the `/1.0/sync/1.5` path**:

```text
http://localhost:8000/1.0/sync/1.5
```

or, once the server is public:

```text
https://sync.example.com/1.0/sync/1.5
```

{{< figure src="/img/firefox-sync/about-config-custom.png" alt="The token server changed to a custom URL" caption="Bold means modified. The arrow on the right puts the default back" >}}

Restart Firefox, then sign in as usual from **Settings → Account and sync**:

{{< figure src="/img/firefox-sync/sign-in.png" alt="The Account and sync page before signing in" caption="The sign-in is still Mozilla's. Only what happens afterwards changes" >}}

The first sync starts by itself as soon as you are in.

{{< callout type="tip" >}}
**Try it on a throwaway profile first** (`firefox -P`, create a new one). An empty profile
talking to an empty server cannot damage anything, and whatever you already have on
Mozilla's servers is not touched: the browser simply stops talking to them.
{{< /callout >}}

## 🪤 The trap: "Sync now" that only syncs tabs

This one cost me twenty minutes of staring at a database.

I saved a password, clicked the account icon in the toolbar, saw *"Last synced: 1 second
ago"*, and looked on the server: **no passwords**. Again. Still nothing.

The sync log (`about:sync-log`) had the answer in one line:

```text
Sync.Synchronizer   INFO   Syncing specified engines: ["tabs"]
```

Opening the account panel triggers a quick sync of the **open tabs only**. It says
"synced", and it is true - for tabs. Everything else waits for the next scheduled full
sync, which can be an hour away.

To force a real, full sync:

```text
Settings → Account and sync → Sync → Sync Now
```

After that button, the log shows every engine, and the password is on the server.

## 🔎 See it on the server

Which accounts are registered:

```bash
docker compose exec syncstorage_mysql sh -c \
  'mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT uid, nodeid FROM tokenserver_rs.users"'
```

What has been stored, by collection:

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

And what a password looks like from the server's point of view:

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

No site, no username, no password. That is all your server ever holds.

### The test that actually proves it

Uploading is half the story. To know the data can come **back**:

```text
1. profile A: save a password, Settings → Sync Now
2. check the server: the passwords collection exists
3. profile B (brand new, same tokenserver preference): sign in
4. about:logins on profile B shows the password
```

On the server side, step 3 shows up as a plain `GET /storage/passwords` - no delete, no
upload. The new browser asked, and the server answered.

## 🌍 Going public

To sync a phone, or a laptop away from home, the server needs a public HTTPS address.

**1. Set the real URL before the first start.** On the production host, in `.env`:

```bash
PUBLIC_URL=https://sync.example.com
SYNC_BIND=0.0.0.0:8000     # only if the reverse proxy is on another machine
```

{{< callout type="warning" >}}
**The node URL is written to the database on the first start, and only then.** Change
`PUBLIC_URL` later and nothing happens: browsers keep being sent to the old address. If
you really need to move, update the row by hand:

`UPDATE tokenserver_rs.nodes SET node = 'https://new.example.com' WHERE id = 1;`

Easier: start production with an empty `mysql_data/` and the right URL from the beginning.
{{< /callout >}}

**2. Put a reverse proxy in front.** Any will do. The nginx version:

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

**3. Check it from outside your network**, not from the server itself:

```bash
curl https://sync.example.com/__heartbeat__
```

**4. Change the preference in every browser** to
`https://sync.example.com/1.0/sync/1.5`.

## 🔒 Lock the door behind you

A public sync server accepts **any Mozilla account** by default. Whoever learns the URL
can use your disk as their storage. They cannot read your data - but it is your disk.

Once every account of yours has signed in at least once:

```bash
# .env
ALLOW_NEW_USERS=false
```

```bash
docker compose up -d
```

From then on only accounts already in `tokenserver_rs.users` are served. To let a new
account in, switch it back to `true`, sign in, switch it off again.

## 📱 Firefox for Android

There is no `about:config` on the release version, but there is a hidden menu:

```text
1. Settings → About Firefox
2. Tap the Firefox logo until the debug menu is enabled
3. Back in Settings: Sync Debug
4. Custom Sync server → https://sync.example.com/1.0/sync/1.5
5. Tap "Stop Firefox" in the same menu, then reopen it and sign in
```

The simplest order is to set it **before** signing in.

## 🔧 Day-to-day

```bash
# Logs
docker compose logs -f syncstorage_app

# Update: change SYNCSERVER_VERSION in .env, then
docker compose pull && docker compose up -d

# Backup
docker compose exec -T syncstorage_mysql sh -c \
  'mysqldump -u$MYSQL_USER -p$MYSQL_PASSWORD --databases syncstorage_rs tokenserver_rs' \
  > sync-backup-$(date +%F).sql
```

Pin the version. `latest` on a service that holds your passwords is a surprise waiting
for a Tuesday.

{{< callout type="info" >}}
**How precious is the backup?** Less than it seems. Every browser holds a full copy of
its own data; a lost server is rebuilt by signing in again from any of them. Back up
`.env` with more care than the database: a changed `MASTER_SECRET` invalidates every
token already issued.
{{< /callout >}}

## ↩️ Going back

Reset `identity.sync.tokenserver.uri` (the arrow in `about:config`), restart Firefox, and
the browser talks to Mozilla's servers again, where your data is exactly as you left it.

## 🪤 Traps, in one table

| Symptom | Cause |
|---------|-------|
| "Synced 1 second ago" but nothing on the server | The toolbar panel syncs tabs only. Use **Sync Now** in Settings |
| The server URL opens Mozilla's documentation | Normal: `/` redirects there |
| `401` on `/1.0/sync/1.5` in a browser | Normal: only Firefox carries the credentials |
| The app cannot connect to the database | Check the password for `/` or `+`: it sits inside a URL. Use hex |
| Changed `PUBLIC_URL`, browsers still use the old one | The node is stored in `tokenserver_rs.nodes` at first start |
| `init-db.sh` did nothing | It only runs on an **empty** `mysql_data/` |
| Strangers in `tokenserver_rs.users` | `ALLOW_NEW_USERS` left at `true` on a public server |

## 📚 References

- [syncstorage-rs](https://github.com/mozilla-services/syncstorage-rs) - the server, and the current documentation (the pages the server redirects to are archived)
- [Container images](https://github.com/mozilla-services/syncstorage-rs/pkgs/container/syncstorage-rs%2Fsyncserver-mysql) - published tags
