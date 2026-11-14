---
title: "Guida all'installazione e alla configurazione di RDP (Debian/Ubuntu)"
url: "2025/10/rdp-installation-and-configuration-guide-debian/ubuntu/"
date: 2025-10-04T00:26:00+02:00
lastmod: 2026-11-14T21:00:00+01:00
draft: false
author: "Manzolo"
tags: ["rdp", "xrdp", "remote-desktop", "ubuntu", "installation"]
categories: ["Linux Administration"]
series: ["System Administration Basics"]
weight: 7
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "xrdp e XFCE su Debian/Ubuntu: le due righe che decidono il desktop e la cifratura, entrambe silenziose quando mancano, e come tenere chiusa la porta 3389"
---

# Installare e configurare RDP (Debian/Ubuntu)

{{< callout type="info" >}}
**A cosa serve**: raggiungere il desktop grafico di una macchina Linux da Windows (Desktop remoto), da macOS o da un altro Linux, con xrdp e XFCE. Provato il 2026-11-14 con xrdp 0.9.24 su Ubuntu 24.04: le righe di registro e la schermata qui sotto vengono da quella macchina.
{{< /callout >}}

## 🧭 Due righe decidono tutto

Un'installazione di xrdp funziona o no per due dettagli, ed entrambi falliscono **in silenzio**:

| Riga | Decide | Se manca |
|------|--------|----------|
| `~/.xsession` | **quale desktop** parte nella sessione RDP | ti ritrovi il desktop predefinito del sistema |
| `adduser xrdp ssl-cert` | **se la connessione è cifrata con TLS** | si collega lo stesso, con la vecchia sicurezza RDP al posto di TLS |

Tutto il resto è installare pacchetti.

## 📦 Installazione

```bash
sudo apt update
sudo apt install xrdp xfce4 xfce4-goodies
```

Sulla macchina di prova sono bastati questi tre pacchetti: `xorgxrdp` (il server X delle sessioni RDP) arriva insieme a `xrdp`. `ubuntu-desktop` non serve, e su Debian non esiste.

## 🖥️ Scegliere il desktop: `~/.xsession`

```bash
# As the user who will connect over RDP, not as root
echo xfce4-session > ~/.xsession
```

All'accesso xrdp esegue `/etc/xrdp/startwm.sh`, che passa la mano a `/etc/X11/Xsession`, che legge `~/.xsession`. È un file **per utente**: ogni utente che si collega via RDP ha bisogno del suo.

Cosa è successo nella prova, in tre varianti:

| `exec startxfce4` in `xrdp.ini` | `~/.xsession` | Desktop partito |
|---|---|---|
| sì | sì | XFCE |
| no | sì | XFCE |
| sì | no | LXQt (quello predefinito della macchina) |

Quindi la riga che molte guide (anche questa, nella prima versione) accodano a `/etc/xrdp/xrdp.ini` non fa niente: quello è un file INI, non uno script.

![Il desktop XFCE servito via RDP, visto dalla finestra del client](/images/rdp-xfce-session.png "La sessione XFCE dell'utente demo, aperta con un client RDP")

## 🔒 TLS: il gruppo `ssl-cert`

xrdp gira come utente `xrdp` e usa il certificato «snakeoil» del sistema, la cui chiave sta in `/etc/ssl/private`: leggibile solo da root e dal gruppo `ssl-cert`. Nella prova, subito dopo l'installazione `xrdp` **non** era in quel gruppo, e ogni connessione andava così:

```text
[ERROR] Cannot read private key file /etc/xrdp/key.pem: Permission denied
[WARN ] Cannot accept TLS connections because certificate or private key file is not readable. ...
[INFO ] Security protocol: configured [RDP], requested [SSL|HYBRID|RDP], selected [RDP]
```

Il client si è collegato lo stesso. Sullo schermo niente dice che TLS è spento. Dopo:

```bash
sudo adduser xrdp ssl-cert
sudo systemctl restart xrdp
```

la stessa connessione dice:

```text
[INFO ] Security protocol: configured [SSL|RDP], requested [SSL|HYBRID|RDP], selected [SSL]
[INFO ] TLS connection established from ::ffff:127.0.0.1 port 39446: TLSv1.3 with cipher TLS_AES_256_GCM_SHA384
```

Per controllare la tua, collegati una volta e poi:

```bash
sudo grep -E "Security protocol|TLS connection|private key" /var/log/xrdp.log | tail -3
```

## 🔥 Non lasciare la porta 3389 aperta al mondo

Il modo migliore è non aprirla per niente e passare da SSH, che con ogni probabilità hai già:

```bash
# On the client: local port 13389 -> port 3389 of the server, inside SSH
ssh -N -L 13389:localhost:3389 user@server

# Then point the RDP client at localhost:13389
```

Nella prova xrdp ha visto arrivare la sessione da `127.0.0.1`, l'uscita del tunnel, con TLS sopra: due strati di cifratura, e solo la porta 22 esposta. (La porta 13389 evita lo scontro con la 3389 su un client Windows che ha il suo Desktop remoto acceso.)

Se deve essere raggiungibile direttamente, limitala alla rete locale:

```bash
# Only from the local network, never from everywhere
sudo ufw allow from 192.168.1.0/24 to any port 3389 proto tcp
sudo ufw status
```

## 📜 Tutto in uno script

```bash
#!/bin/bash
# Run as the user who will connect over RDP (sudo is used where needed)
set -e
sudo apt update -qq
sudo apt install -y -qq xrdp xfce4 xfce4-goodies
sudo adduser xrdp ssl-cert
echo xfce4-session > ~/.xsession
sudo systemctl restart xrdp
echo "Connect with an RDP client to $(hostname -I | awk '{print $1}'):3389"
```

## 🪤 Le trappole, in una tabella

| Sintomo | Causa |
|---------|-------|
| La sessione RDP apre un altro desktop | Manca `~/.xsession` per **quell'**utente |
| `Cannot read private key file /etc/xrdp/key.pem` nel registro | `xrdp` non è in `ssl-cert`: la connessione funziona, senza TLS |
| `exec startxfce4` in `xrdp.ini` «non funziona» | Non ha mai funzionato: il desktop lo sceglie `~/.xsession` |
| `~/.xsession` di proprietà di root | Creato con `sudo tee`: crealo come l'utente |
| Porta 3389 raggiungibile da internet | Usa il tunnel SSH, oppure `ufw allow from <la tua LAN>` |

## 📚 Risorse

- [xrdp](https://www.xrdp.org/) e la sua [wiki su GitHub](https://github.com/neutrinolabs/xrdp/wiki)
- [Arch Wiki: xrdp](https://wiki.archlinux.org/title/Xrdp)
- [SSH Forward Tunneling](/it/bash/ssh-forward-tunneling/) - di più su `ssh -L`
