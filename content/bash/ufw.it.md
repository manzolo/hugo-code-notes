---
title: "Uncomplicated Firewall"
url: "bash/ufw/"
#description: ""
date: 2025-09-26T10:00:00+01:00
lastmod: 2025-09-26T10:00:00+01:00
draft: false
author: "Manzolo"
tags: ["ufw", "firewall", "security", "iptables", "ubuntu"]
categories: ["Command Reference"]
series: ["Command Line Mastery"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Guida al firewall UFW su Ubuntu

## Introduzione

UFW (Uncomplicated Firewall) è un'interfaccia semplice per gestire le regole del firewall iptables sui sistemi Ubuntu. Rende più facile configurare il firewall: è alla portata di chi comincia e resta efficiente per chi è esperto. Questa guida passa in rassegna i comandi essenziali di UFW, con esempi pratici e consigli per mettere in sicurezza il tuo server Ubuntu.

## Cos'è UFW?

UFW è un front-end di iptables, pensato per rendere lineare la configurazione del firewall. Ti permette di governare il traffico di rete in entrata e in uscita definendo regole basate su porte, protocolli e indirizzi IP.

## Prerequisiti

- Un sistema Ubuntu con UFW installato (`ufw` è incluso di default in Ubuntu).
- Privilegi di root o sudo.
- Una conoscenza di base dei protocolli di rete (TCP/UDP) e delle porte.

Verifica che UFW sia installato:

```bash
ufw version
```

Se non c'è, installalo:

```bash
sudo apt update
sudo apt install ufw
```

## Comandi UFW di base

### Attivare e disattivare UFW

```bash
# Enable UFW (warning: this may block all traffic unless rules are set)
sudo ufw enable

# Disable UFW
sudo ufw disable

# Check UFW status
sudo ufw status
```

### Impostare le policy predefinite

Le policy predefinite stabiliscono cosa fare del traffico che nessuna regola prevede:

```bash
# Deny all incoming traffic by default
sudo ufw default deny incoming

# Allow all outgoing traffic by default
sudo ufw default allow outgoing
```

### Gestire le regole

```bash
# Allow a specific port (e.g., SSH on port 22)
sudo ufw allow 22

# Allow a specific protocol and port (e.g., HTTP on TCP port 80)
sudo ufw allow 80/tcp

# Deny a specific port
sudo ufw deny 23

# Delete a rule
sudo ufw delete allow 80/tcp

# Reset UFW to default (removes all rules)
sudo ufw reset
```

## Esempi comuni

### Esempio 1: mettere in sicurezza un server web

Apri HTTP (porta 80), HTTPS (porta 443) e SSH (porta 22) per un server web:

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

- **Spiegazione**:
  - `22/tcp`: apre SSH per l'accesso remoto.
  - `80/tcp`: apre HTTP per il traffico web.
  - `443/tcp`: apre HTTPS per il traffico web cifrato.
- **Verifica**: lancia `sudo ufw status` per controllare le regole.

### Esempio 2: limitare SSH a un IP specifico

Consenti SSH solo da un indirizzo IP preciso (per esempio `192.168.1.100`):

```bash
sudo ufw allow from 192.168.1.100 to any port 22
sudo ufw enable
```

- **Spiegazione**:
  - `from 192.168.1.100`: limita l'accesso SSH a questo IP.
  - `to any port 22`: applica la regola alla porta 22 del server.
- **Uso**: solo l'IP indicato può collegarsi via SSH.

### Esempio 3: aprire un intervallo di porte

Apri un intervallo di porte (per esempio per un'applicazione tua sulle porte 3000–3010):

```bash
sudo ufw allow 3000:3010/tcp
sudo ufw enable
```

- **Spiegazione**:
  - `3000:3010/tcp`: consente il traffico TCP sulle porte da 3000 a 3010.
- **Uso**: utile per applicazioni come Node.js o per servizi personalizzati.

### Esempio 4: aprire un servizio per nome

UFW riconosce i nomi dei servizi definiti in `/etc/services`:

```bash
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw enable
```

- **Spiegazione**:
  - `ssh`, `http`, `https`: corrispondono rispettivamente alle porte 22, 80 e 443.
- **Uso**: semplifica la scrittura delle regole per i servizi più comuni.

## Comandi UFW avanzati

### Consentire intervalli di IP

Consenti il traffico da una sottorete (per esempio `192.168.1.0/24`):

```bash
sudo ufw allow from 192.168.1.0/24 to any port 80
```

### Limitare la frequenza delle connessioni SSH

Previeni gli attacchi brute-force limitando le connessioni SSH:

```bash
sudo ufw limit 22/tcp
```

- **Spiegazione**: limita le connessioni a 6 ogni 30 secondi da un singolo IP.

### Logging

Attiva il logging per tenere d'occhio l'attività del firewall:

```bash
sudo ufw logging on
sudo ufw logging low  # Options: off, low, medium, high, full
```

I log si leggono in `/var/log/ufw.log`, oppure con:

```bash
sudo cat /var/log/ufw.log
```

## Uno script pratico

Crea uno script che imposta una configurazione UFW di base per un server web:

```bash
#!/bin/bash
# configure_ufw.sh

echo "=== Configuring UFW ==="
echo "Setting default policies..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "Allowing essential services..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

echo "Enabling UFW..."
sudo ufw enable

echo "Current UFW status:"
sudo ufw status
```

Rendilo eseguibile:

```bash
chmod +x configure_ufw.sh
./configure_ufw.sh
```

## Consigli da esperti

{{< callout type="tip" >}}
**Consiglio**: su un server remoto apri sempre SSH (porta 22) prima di attivare UFW, per non chiuderti fuori.
```bash
sudo ufw allow ssh
```
{{< /callout >}}

{{< callout type="warning" >}}
**Attenzione**: attivare UFW con una policy predefinita di deny senza aver aperto SSH può bloccare l'accesso remoto. Prova le regole in locale, oppure assicurati prima l'accesso SSH.
{{< /callout >}}

{{< callout type="success" title="Quick Reference" >}}
**Comandi essenziali:**
- `sudo ufw enable`: attiva il firewall.
- `sudo ufw status verbose`: mostra lo stato in dettaglio.
- `sudo ufw app list`: elenca i profili applicativi disponibili.
- `sudo ufw reset`: riporta tutto ai valori predefiniti (da usare con cautela).
{{< /callout >}}

## Risoluzione dei problemi

- **Chiuso fuori da SSH**: se perdi l'accesso SSH, entra nel server da una console (per esempio la dashboard del provider cloud) e disattiva UFW (`sudo ufw disable`).
- **Servizio non raggiungibile**: verifica le regole con `sudo ufw status` e assicurati che sia consentita la coppia porta/protocollo giusta.
- **I log non compaiono**: controlla che il logging sia attivo (`sudo ufw logging on`) e verifica il file di log (`/var/log/ufw.log`).
- **Profili applicativi**: usa `sudo ufw app list` per vedere i profili già pronti (per esempio per Nginx o Apache).

## Prossimi passi

Nei prossimi tutorial vedremo:
- Regole iptables avanzate per gli scenari complessi.
- Come configurare UFW con i container Docker.
- Come impostare il rilevamento delle intrusioni con strumenti come Fail2Ban.
- Come monitorare il traffico di rete con `tcpdump`.

## Esercizi pratici

1. **Configurazione di base**: configura UFW per consentire SSH, HTTP e HTTPS, poi verifica le regole.
2. **Accesso ristretto**: consenti SSH solo da un intervallo di IP preciso e prova la connessione.
3. **Limitazione della frequenza**: applica il rate limiting a una porta a tua scelta e simula più connessioni.
4. **Analisi dei log**: attiva il logging e analizza il traffico bloccato in `/var/log/ufw.log`.

## Risorse

- [Manuale di UFW](https://manpages.ubuntu.com/manpages/focal/man8/ufw.8.html)
- [Guida a UFW di Ubuntu](https://help.ubuntu.com/community/UFW)
- [Tutorial sul firewall in Linux](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-with-ufw-on-ubuntu)

---

*Fai pratica con le regole di UFW per mettere davvero in sicurezza il tuo server!*
