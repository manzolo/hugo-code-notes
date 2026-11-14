---
title: "Forward tunneling con SSH"
url: "bash/ssh-forward-tunneling/"
#description: ""
date: 2025-09-26T10:00:00+01:00
lastmod: 2025-09-26T10:00:00+01:00
draft: false
author: "Manzolo"
tags: ["ssh", "tunneling", "port-forwarding", "networking", "security"]
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

# Guida al forward tunneling con SSH

## Introduzione

Il forward tunneling di SSH (detto anche local port forwarding) ti permette di collegarti in modo sicuro a un servizio remoto passando da un server SSH, come se il servizio girasse sulla tua macchina. Torna utile per raggiungere servizi che stanno su un server remoto, o su un'altra macchina di una rete protetta, e che non sono accessibili direttamente.

In questa guida vediamo le basi del forward tunneling con SSH, come funziona, e qualche esempio pratico.

## Cos'è il forward tunneling di SSH?

Il forward tunneling inoltra una porta locale verso un server remoto, o verso un altro host raggiungibile dal server SSH. La connessione è cifrata dentro il tunnel SSH, e questo garantisce una comunicazione sicura.

### Sintassi di base

```bash
ssh -L [local_port]:[destination_host]:[destination_port] [user]@[ssh_server]
```

- `-L`: indica il local port forwarding.
- `[local_port]`: la porta sulla tua macchina da cui accederai al servizio.
- `[destination_host]`: l'host di destinazione (visto dal server SSH) a cui vuoi collegarti.
- `[destination_port]`: la porta sull'host di destinazione.
- `[user]@[ssh_server]`: il server SSH che fa da intermediario.

## Come funziona

1. Apri una connessione SSH verso il server SSH.
2. Una porta locale della tua macchina viene legata a una porta precisa dell'host di destinazione, passando dal server SSH.
3. Tutto il traffico mandato alla porta locale viene inoltrato attraverso il tunnel SSH fino all'host e alla porta di destinazione.

## Prerequisiti

- Un client SSH installato (ad esempio `OpenSSH` su Linux/macOS, o strumenti come PuTTY su Windows).
- L'accesso a un server SSH, con le credenziali (utente e password, oppure chiave SSH).
- Sapere quali sono l'host e la porta di destinazione che vuoi raggiungere.

## Esempi

### Esempio 1: raggiungere un web server remoto

Supponi di voler raggiungere un web server che gira su `webserver.local` (porta 80) passando da un server SSH (`ssh.example.com`). Il web server non è accessibile direttamente dalla tua macchina, ma il server SSH lo raggiunge.

```bash
ssh -L 8080:webserver.local:80 user@ssh.example.com
```

- **Spiegazione**:
  - `8080`: la porta della tua macchina da cui accederai al web server.
  - `webserver.local:80`: il web server remoto e la sua porta.
  - `user@ssh.example.com`: il server SSH a cui ti colleghi.
- **Utilizzo**: apri il browser e vai su `http://localhost:8080`. Il traffico passa nel tunnel fino a `webserver.local:80`, attraverso il server SSH.

### Esempio 2: raggiungere un server di database

Devi collegarti a un database MySQL che gira su `dbserver.local` (porta 3306), passando dallo stesso server SSH.

```bash
ssh -L 3306:dbserver.local:3306 user@ssh.example.com
```

- **Spiegazione**:
  - `3306`: la porta locale a cui collegherai il tuo client MySQL.
  - `dbserver.local:3306`: il server MySQL remoto e la sua porta.
- **Utilizzo**: usa un client MySQL (ad esempio `mysql`, o una GUI come DBeaver) per collegarti a `localhost:3306`. Il traffico viene inoltrato al database remoto.

### Esempio 3: tunnel verso un'altra macchina

Se vuoi raggiungere un servizio su una terza macchina (`internal.host:5432`) che è raggiungibile solo dal server SSH, puoi inoltrare il traffico così:

```bash
ssh -L 5432:internal.host:5432 user@ssh.example.com
```

- **Utilizzo**: collegati a `localhost:5432` dalla tua macchina per parlare con `internal.host:5432`.

## Opzioni utili

- **In background**: lancia il tunnel in background con `-f` e `-N` (nessun comando da eseguire):

  ```bash
  ssh -f -N -L 8080:webserver.local:80 user@ssh.example.com
  ```

- **Ascolto su tutte le interfacce**: permetti ad altre macchine di collegarsi alla tua porta locale (da usare con cautela):

  ```bash
  ssh -L 0.0.0.0:8080:webserver.local:80 user@ssh.example.com
  ```

- **Keep alive**: evita che il tunnel vada in timeout aggiungendo le opzioni di keep-alive:

  ```bash
  ssh -o ServerAliveInterval=60 -L 8080:webserver.local:80 user@ssh.example.com
  ```

## Uno script pratico

Crea uno script che apra un forward tunnel e verifichi che sia attivo:

```bash
#!/bin/bash
# ssh_tunnel.sh

echo "Setting up SSH forward tunnel..."
ssh -f -N -L 8080:webserver.local:80 user@ssh.example.com

if [ $? -eq 0 ]; then
  echo "Tunnel established. Access the service at http://localhost:8080"
else
  echo "Failed to establish tunnel."
fi
```

Rendilo eseguibile:

```bash
chmod +x ssh_tunnel.sh
./ssh_tunnel.sh
```

## Port forwarding

Il port forwarding con SSH esiste in tre varianti principali: locale, remoto e dinamico. Ognuna ha il suo scopo nel gestire in sicurezza l'accesso alla rete.

### Forwarding locale

Come descritto sopra, il forwarding locale (`-L`) ti permette di raggiungere servizi interni dalla tua macchina passando da un server SSH. È l'ideale per collegarsi in sicurezza alle risorse di una rete privata.

**Esempio**:
```bash
ssh -L 8080:internal.service:80 user@ssh.example.com
```
Vai su `http://localhost:8080` per raggiungere `internal.service:80`.

### Forwarding remoto

Il forwarding remoto (`-R`) espone un servizio che gira sulla tua macchina (o su una macchina raggiungibile dalla tua) al server SSH, o a un'altra macchina che il server SSH raggiunge.

**Sintassi**:
```bash
ssh -R [remote_port]:[local_host]:[local_port] [user]@[ssh_server]
```

**Esempio**:
```bash
ssh -R 8080:localhost:3000 user@ssh.example.com
```
- **Spiegazione**: un servizio che gira sulla tua macchina su `localhost:3000` diventa raggiungibile sul server SSH, su `ssh.example.com:8080`.
- **Utilizzo**: sul server SSH apri `http://localhost:8080`. Di default `sshd` lega gli inoltri remoti solo al suo loopback: per raggiungere `http://ssh.example.com:8080` da altre macchine, sul server serve `GatewayPorts yes` (oppure `clientspecified`) in `sshd_config`.

### Forwarding dinamico (proxy SOCKS)

Il forwarding dinamico (`-D`) trasforma la tua connessione SSH in un proxy SOCKS, che si comporta come una mini-VPN. Ti permette di instradare il traffico in modo dinamico attraverso il server SSH, senza indicare un host o una porta di destinazione fissi.

**Sintassi**:
```bash
ssh -D [local_port] [user]@[ssh_server]
```

**Esempio**:
```bash
ssh -D 1080 user@ssh.example.com
```
- **Spiegazione**: crea un proxy SOCKS su `localhost:1080`. Configura il browser o l'applicazione perché usi questo proxy, e il traffico passerà dal server SSH.
- **Utilizzo**: imposta `localhost:1080` come proxy SOCKS del browser per navigare in sicurezza attraverso il server SSH.

### SSH come VPN (tunnel di livello 2 o 3)

SSH si può usare per creare un tunnel simile a una VPN a livello di rete (livello 2 o 3), con strumenti come `sshuttle` oppure configurando un'interfaccia TUN/TAP. In questo modo tutto il traffico di rete può essere instradato attraverso il server SSH.

**Esempio con sshuttle**:
```bash
sshuttle -r user@ssh.example.com 192.168.1.0/24
```
- **Spiegazione**: instrada attraverso il server SSH il traffico destinato alla sottorete `192.168.1.0/24`, creando di fatto una VPN.

### X11 forwarding (GUI da remoto)

L'X11 forwarding ti permette di lanciare applicazioni grafiche su un server remoto e di vederle sulla tua macchina.

**Sintassi**:
```bash
ssh -X [user]@[ssh_server]
```

**Esempio**:
```bash
ssh -X user@ssh.example.com xterm
```
- **Spiegazione**: lancia l'applicazione `xterm` sul server SSH, ma la sua interfaccia grafica compare sulla tua macchina.
- **Prerequisito**: in locale deve girare un server X (ad esempio XQuartz su macOS o Xming su Windows).

### Montare un filesystem remoto (sshfs)

Con `sshfs` puoi montare in locale un filesystem remoto via SSH, e lavorare sui file remoti come se fossero sulla tua macchina.

**Esempio**:
```bash
sshfs user@ssh.example.com:/remote/path /local/mountpoint
```
- **Spiegazione**: monta la cartella `/remote/path` del server SSH su `/local/mountpoint` della tua macchina.
- **Smontare**: usa `fusermount -u /local/mountpoint` (`fusermount3 -u` sui sistemi recenti): da utente normale `umount` non funziona su un montaggio FUSE.

Installa `sshfs`:
```bash
sudo apt install sshfs  # Ubuntu/Debian
```

### Multiplexing delle connessioni

Il multiplexing di SSH permette a più sessioni di condividere un'unica connessione SSH, riducendo il carico quando apri più tunnel o lanci più comandi.

**Configurazione di esempio** (`~/.ssh/config`):
```bash
Host ssh.example.com
  ControlMaster auto
  ControlPath ~/.ssh/mux-%r@%h:%p
  ControlPersist 10m
```

**Utilizzo**:
```bash
ssh user@ssh.example.com  # Opens master connection
ssh user@ssh.example.com  # Reuses existing connection
```

### Una reverse shell sicura

Con il forwarding remoto di SSH si può mettere in piedi una reverse shell, che permette a una macchina remota di accedere in sicurezza a una shell sulla tua macchina.

**Esempio**:
```bash
ssh -R 2222:localhost:22 user@ssh.example.com
```
- **Spiegazione**: dal server SSH puoi collegarti a `localhost:2222` per raggiungere il server SSH della tua macchina (`localhost:22`).

## Consigli da esperti

{{< callout type="tip" >}}
**Consiglio**: usa `autossh` per avere un tunnel più robusto, che si ricollega da solo se la connessione cade:

```bash
autossh -M 0 -f -N -L 8080:webserver.local:80 user@ssh.example.com
```

Installa `autossh` con:
```bash
sudo apt install autossh  # Ubuntu/Debian
```
{{< /callout >}}

{{< callout type="warning" >}}
**Attenzione**: vacci piano con l'ascolto su `0.0.0.0`: espone la porta su tutte le interfacce di rete, e può aprire la strada ad accessi non autorizzati.
{{< /callout >}}

## Risoluzione dei problemi

- **Connection refused**: assicurati che il server SSH raggiunga l'host e la porta di destinazione.
- **Porta già in uso**: controlla se la porta locale è già occupata (`netstat -tuln`) e scegline un'altra.
- **Permission denied**: verifica le credenziali SSH o la configurazione dell'autenticazione a chiave.
- **Il tunnel si ferma**: usa `-o ServerAliveInterval=60` per tenere viva la connessione, oppure valuta `autossh`.

## Prossimi passi

Nei prossimi tutorial vedremo:
- Il reverse tunneling SSH per esporre servizi locali.
- Il tunneling dinamico con proxy SOCKS.
- Le configurazioni SSH avanzate con `~/.ssh/config`.

## Risorse

- [Manuale di OpenSSH](https://www.openssh.com/manual.html)
- [Il tunneling SSH spiegato](https://www.ssh.com/academy/ssh/tunneling-example)

---

*Fai pratica aprendo tunnel verso servizi diversi, per padroneggiare il forwarding di SSH!*
