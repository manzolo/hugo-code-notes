---
title: "Guida all'installazione e alla configurazione di RDP (Debian/Ubuntu)"
url: "2025/10/rdp-installation-and-configuration-guide-debian/ubuntu/"
date: 2025-10-04T00:26:00+02:00
lastmod: 2025-10-04T00:26:00+02:00
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
---

# Guida all'installazione e alla configurazione di RDP (Debian/Ubuntu)

## Introduzione

Il Remote Desktop Protocol (RDP) permette di accedere da remoto all'ambiente desktop grafico di un sistema Linux. XRDP è un server RDP open source che accetta connessioni dai client RDP (per esempio Desktop remoto di Windows o Remmina) verso un sistema Debian/Ubuntu. Questa guida spiega come installare e configurare XRDP su Debian/Ubuntu con l'ambiente desktop XFCE, una scelta leggera ed efficiente per i desktop remoti. Comprende i passi per mettere in piedi un server RDP sicuro e funzionante per l'accesso remoto.

## Cos'è XRDP?

XRDP è un'implementazione open source del protocollo RDP, che permette connessioni desktop remote verso sistemi Linux. Le caratteristiche principali:
- **Accesso multipiattaforma**: ti colleghi da client Windows, macOS o Linux.
- **Integrazione con XFCE**: un ambiente desktop leggero, per prestazioni fluide.
- **Sicurezza**: con la giusta configurazione supporta SSL per la cifratura.
- **Supporto multiutente**: consente più sessioni contemporanee.

Questa guida configura XRDP con XFCE per avere un desktop remoto essenziale ed efficiente.

## Prerequisiti

- **Debian/Ubuntu**: versione 20.04+.
- **Pacchetti**: `xrdp`, `xfce4`, `xfce4-goodies`, `ubuntu-desktop` (facoltativo, per le dipendenze del desktop completo).
- **Accesso root**: i comandi richiedono `sudo`.
- **Rete**: la porta 3389 (quella predefinita di RDP) aperta sul firewall.
- **Client**: un client RDP (per esempio Microsoft Remote Desktop o Remmina).

Installa i prerequisiti:
```bash
sudo apt update
sudo apt install -y curl
```

Verifica la rete:
```bash
sudo ss -tuln | grep 3389  # Check if port 3389 is open
```

## Avvertenza importante: metti in sicurezza l'installazione

{{< callout type="warning" >}}
**Attenzione**: esporre RDP (porta 3389) su internet senza le protezioni adeguate (password robuste, regole del firewall o una VPN) può portare ad accessi non autorizzati. Configura sempre un firewall (per esempio UFW) per restringere l'accesso, e fai un backup delle configurazioni critiche (per esempio `/etc/xrdp/xrdp.ini`) prima di modificarle. Prova in locale prima di aprire alle reti esterne.
{{< /callout >}}

## Come installare e configurare XRDP

### 1. Installa XRDP e XFCE
Installa i pacchetti necessari per XRDP e per l'ambiente desktop XFCE.

```bash
sudo apt update
sudo apt install --no-install-recommends ubuntu-desktop
sudo apt install -y xfce4 xfce4-goodies xrdp
```

- `--no-install-recommends`: riduce al minimo le dipendenze di `ubuntu-desktop`.
- `xfce4-goodies`: aggiunge strumenti extra di XFCE, per lavorarci meglio.

### 2. Configura XRDP
Di' a XRDP quale desktop avviare. È un'impostazione per utente: lancialo come l'utente che entrerà via RDP.

```bash
echo xfce4-session > ~/.xsession
```

- `~/.xsession`: lo legge `/etc/X11/Xsession`, che XRDP esegue all'accesso (`/etc/xrdp/startwm.sh`). È l'unica riga che decide il desktop.

**Nota**: le versioni precedenti di questa guida accodavano anche `exec startxfce4` a `/etc/xrdp/xrdp.ini`. Quello è un file INI, non uno script, e la riga non fa niente. Provato su Ubuntu 24.04 con xrdp 0.9.24: con `~/.xsession` parte XFCE che la riga ci sia o no; senza `~/.xsession` parte il desktop predefinito del sistema (LXQt sulla macchina di prova) anche con la riga al suo posto.

### 3. Aggiungi l'utente XRDP al gruppo SSL
Dai a XRDP l'accesso ai certificati SSL, per le connessioni sicure.

```bash
sudo adduser xrdp ssl-cert
```

### 4. Riavvia il servizio XRDP
Applica le modifiche riavviando il servizio XRDP.

```bash
sudo systemctl restart xrdp
```

Verifica che il servizio sia in esecuzione:
```bash
sudo systemctl status xrdp
```

### 5. Configura il firewall
Consenti le connessioni RDP sulla porta 3389.

```bash
sudo apt install -y ufw
sudo ufw allow 3389/tcp
sudo ufw enable
```

### 6. Prova la connessione remota
- Da un client (per esempio Desktop remoto di Windows):
  - Inserisci l'indirizzo IP del server (per esempio `192.168.1.100:3389`).
  - Usa il tuo nome utente e la tua password di Linux.
- Verifica che il desktop XFCE si carichi da remoto.

![Il desktop XFCE servito via RDP, visto dalla finestra del client](/images/rdp-xfce-session.png "La sessione XFCE dell'utente demo, aperta con un client RDP")

## Esempio

### Esempio: installazione completa di XRDP
Lancia questo script per automatizzare tutto il procedimento:

Lancialo come l'utente che si collegherà (usa `sudo` dove serve): `~/.xsession` deve appartenere a quell'utente, non a root.

```bash
#!/bin/bash
echo "Installing RDP..."
sudo apt update -qqy > /dev/null
sudo apt install -qqy --no-install-recommends ubuntu-desktop > /dev/null
sudo apt install -qqy xfce4 xfce4-goodies xrdp > /dev/null
sudo adduser xrdp ssl-cert > /dev/null
sudo systemctl restart xrdp > /dev/null
echo xfce4-session > ~/.xsession
echo "XRDP installed and configured. Connect via RDP to $(hostname -I | awk '{print $1}'):3389"
```

Salvalo come `install_xrdp.sh`, rendilo eseguibile e lancialo:
```bash
chmod +x install_xrdp.sh
./install_xrdp.sh
```

**Output** (esempio):
```
XRDP installed and configured. Connect via RDP to 192.168.1.100:3389
```

Collegati con un client RDP all'IP del server, sulla porta 3389.

## I comandi, uno per uno

- **apt install xrdp xfce4**: installa il server XRDP e il desktop XFCE.
- **adduser xrdp ssl-cert**: dà l'accesso a SSL per le connessioni sicure.
- **systemctl restart xrdp**: riavvia il servizio XRDP.
- **echo xfce4-session > ~/.xsession**: imposta XFCE come sessione.

## Casi d'uso
- **Amministrazione remota**: gestisci i server da remoto con un'interfaccia grafica.
- **Accesso alla workstation**: raggiungi i desktop Linux da Windows/macOS.
- **Sviluppo**: usa gli IDE grafici attraverso RDP.
- **Desktop condivisi**: accesso multiutente per il lavoro collaborativo.

## Consigli da esperti
- **Proteggilo con SSH**: per sicurezza, fai passare RDP in un tunnel SSH:
  ```bash
  ssh -L 3389:localhost:3389 user@remote.host
  ```
  Dal client collegati a `localhost:3389`.
- **Backup delle configurazioni**: salva `/etc/xrdp/xrdp.ini` e `~/.xsession`:
  ```bash
  sudo cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak
  cp ~/.xsession ~/.xsession.bak
  ```
- **L'alternativa leggera**: usa `xfce4` al posto dei desktop più pesanti (per esempio GNOME) per avere prestazioni migliori.
- **Porta personalizzata**: cambia la porta RDP in `/etc/xrdp/xrdp.ini` (per esempio `port=3390`) e aggiorna il firewall.
- **Prestazioni**: disattiva le animazioni nelle impostazioni di XFCE per avere sessioni remote più veloci.

{{< callout type="tip" >}}
**Consiglio**: usa `xfce4-panel --restart` se in RDP il pannello di XFCE non si carica bene.
{{< /callout >}}

## Risoluzione dei problemi
- **La connessione RDP fallisce**: controlla `sudo systemctl status xrdp` e assicurati che la porta 3389 sia aperta (`sudo ss -tuln | grep 3389`).
- **Schermo vuoto**: verifica che `~/.xsession` contenga `xfce4-session` e riavvia XRDP.
- **Problemi di permessi**: assicurati che l'utente `xrdp` sia nel gruppo `ssl-cert` (`groups xrdp`).
- **Prestazioni lente**: passa a un tema XFCE più leggero o riduci la risoluzione nel client RDP.
- **Il firewall blocca**: rilancia `sudo ufw allow 3389/tcp` oppure controlla `ufw status`.

## Prossimi passi
Nei prossimi tutorial vedremo:
- Come mettere in sicurezza XRDP con i certificati TLS.
- Le configurazioni RDP multiutente.
- Come integrare XRDP con Active Directory.

## Risorse
- [Documentazione di XRDP](http://xrdp.org/)
- [Guida a XFCE su Ubuntu](https://ubuntu.com/server/docs/desktops)
- [Arch Wiki: XRDP](https://wiki.archlinux.org/title/XRDP)

---

*Metti in piedi XRDP con XFCE per avere un desktop remoto leggero e sicuro, e provalo in locale prima di esporlo alla rete!*
