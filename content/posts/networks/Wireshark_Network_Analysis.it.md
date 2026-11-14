---
title: "Analisi del traffico di rete con Wireshark (Debian/Ubuntu)"
url: "2025/10/network-traffic-analysis-with-wireshark-debian/ubuntu/"
date: 2025-10-04T13:25:00+02:00
lastmod: 2026-11-14T20:00:00+01:00
draft: false
author: "Manzolo"
tags: ["wireshark", "network-analysis", "packet-capture", "troubleshooting", "security"]
categories: ["Networking & Security"]
series: ["Networking Fundamentals"]
weight: 5
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "Cattura largo, guarda stretto: i due linguaggi di filtro, la trappola dei permessi, una connessione rifiutata, l'HTTPS decifrato con il file delle chiavi e una cattura remota che non cattura sé stessa"
---

# Analisi del traffico di rete con Wireshark (Debian/Ubuntu)

{{< callout type="info" >}}
**A cosa serve**: vedere cosa passa davvero sul filo - quale richiesta manda un programma, perché una connessione fallisce, con chi parla un dispositivo. Tutto quello che segue è stato eseguito il 2026-11-14 con Wireshark 4.2.2 su Ubuntu 24.04: output e schermate vengono da quella macchina.
{{< /callout >}}

## 🧭 Due linguaggi di filtro, e non sono lo stesso

Wireshark ha due tipi di filtro, e quasi tutta la confusione nasce dal mescolarli:

| | Filtro di cattura | Filtro di visualizzazione |
|---|---|---|
| Decide | cosa viene **registrato** | cosa **vedi** di quello che è stato registrato |
| Linguaggio | BPF, quello di `tcpdump` | quello di Wireshark |
| Esempio | `tcp port 80` | `tcp.port == 80` |
| Dove | `tshark -f`, il campo nella schermata iniziale | `tshark -Y`, la barra sopra l'elenco dei pacchetti |
| Un errore costa | pacchetti persi per sempre | niente: cambi il filtro |

Da qui la regola pratica: **cattura largo, guarda stretto**. Quando non sai bene cosa cerchi, registra di più e filtra la vista.

Si assomigliano, e quindi si scambiano. Un filtro di cattura scritto nella barra di visualizzazione diventa rosso, e la barra di stato spiega perché:

![Un filtro di cattura nella barra dei filtri di visualizzazione: rosso, con un errore nella barra di stato](/images/wireshark-filter-wrong.png "port 80 è BPF: come filtro di visualizzazione non è valido (\"80\" was unexpected in this context)")

![La stessa intenzione come filtro di visualizzazione: verde](/images/wireshark-filter-right.png "tcp.port == 80 è il modo di dirlo con un filtro di visualizzazione")

## 📦 Installazione, e la trappola dei permessi

```bash
sudo apt update
sudo apt install wireshark tshark
sudo usermod -aG wireshark $USER
```

Rispondi **Sì** quando l'installazione chiede se gli utenti normali devono poter catturare: la cattura la fa allora `dumpcap`, e solo per i membri del gruppo `wireshark`.

La trappola è che il gruppo vale solo **dal login successivo**. Nella stessa sessione non cambia niente:

```text
tshark: Couldn't run dumpcap in child process: Permission denied
0 packets captured
```

E il Wireshark grafico, avviato da una sessione del desktop nata prima del gruppo, inganna ancora di più: nessun errore, semplicemente **nessuna interfaccia di rete** nell'elenco, solo le voci di «remote capture»:

![La schermata iniziale di Wireshark senza interfacce di rete, solo le voci extcap](/images/wireshark-no-interfaces.png "Avviato da una sessione senza il gruppo wireshark: nessuna interfaccia, e nessun messaggio")

Esci e rientra (o riavvia), poi controlla:

```bash
id -nG | grep -w wireshark || echo "not yet: log out and back in"
tshark -D
```

Se durante l'installazione hai risposto **No**:

```bash
sudo dpkg-reconfigure wireshark-common
```

## 🎯 Catturare

```bash
# Interface names are enp2s0, ens3, wlp3s0... on current systems, rarely eth0
ip -br link

# Capture filter (BPF): decides what gets recorded
tshark -i enp2s0 -f "tcp port 80" -w http.pcapng

# In another terminal, generate some traffic
curl -s -o /dev/null http://example.com/
```

`Ctrl+C` ferma `tshark`. Nell'interfaccia grafica lo stesso filtro di cattura va nel campo della schermata iniziale, prima del doppio clic sull'interfaccia. Salva il file (`-w`, oppure File → Salva con nome): una cattura che puoi riaprire vale più di una che hai visto scorrere.

## 🔎 Cosa manda davvero il programma?

Riapri la cattura con un filtro di visualizzazione:

```bash
tshark -r http.pcapng -Y http.request
```

```text
    4 0.014939878 192.168.122.18 → 104.20.23.154 HTTP 140 GET / HTTP/1.1
```

Nell'interfaccia grafica seleziona quel pacchetto e usa **Analyze → Follow → TCP Stream** (`Ctrl+Alt+Maiusc+T`): Wireshark rimette insieme tutta la conversazione, la richiesta in rosso e la risposta in blu.

![Follow TCP Stream: la richiesta HTTP e la risposta del server](/images/wireshark-follow-stream.png "Follow TCP Stream: cosa ha mandato curl, e cosa è tornato indietro")

## 🚫 Una connessione rifiutata è fatta così

```bash
# Capture on loopback, then try a port where nothing listens
tshark -i lo -f "tcp port 81" -w rst.pcapng
curl http://localhost:81/        # curl: (7) Failed to connect

tshark -r rst.pcapng
```

```text
    3 0.000085535    127.0.0.1 → 127.0.0.1    TCP 74 35950 → 81 [SYN] Seq=0 Win=65495 Len=0 ...
    4 0.000098947    127.0.0.1 → 127.0.0.1    TCP 54 81 → 35950 [RST, ACK] Seq=1 Ack=1 Win=0 Len=0
```

`[SYN]` e poi `[RST, ACK]` dalla destinazione: l'host è raggiungibile e **su quella porta non ascolta niente**. Il filtro per trovarlo è `tcp.flags.reset == 1`:

![Pacchetti con il flag RST in una connessione rifiutata](/images/wireshark-rst.png "tcp.flags.reset == 1: la destinazione risponde RST a ogni SYN")

Quando invece compaiono solo pacchetti `[SYN]`, ripetuti a intervalli sempre più lunghi e mai risposti, qualcosa li **scarta** lungo la strada (un firewall, una rotta sbagliata): un problema diverso, da cercare in un altro posto.

## 🔐 HTTPS: decifrare il proprio traffico

TLS nasconde il contenuto, ma a un client si può chiedere di scrivere le sue chiavi di sessione: con quelle Wireshark decifra quello che **quel client** ha mandato e ricevuto. Nient'altro.

```bash
# 1. Capture, and make the client write its session keys
tshark -i enp2s0 -f "tcp port 443" -w tls.pcapng
SSLKEYLOGFILE=$HOME/tls-keys.log curl -s -o /dev/null https://example.com/

# 2. Without the keys: only "Application Data"
tshark -r tls.pcapng -Y tls.app_data

# 3. With the keys: the HTTP inside
tshark -r tls.pcapng -o tls.keylog_file:$HOME/tls-keys.log -Y http

# The same in the GUI
wireshark -o tls.keylog_file:$HOME/tls-keys.log -r tls.pcapng
```

```text
   11 0.041216857 192.168.122.18 → 172.66.147.243 HTTP 162 GET / HTTP/1.1
   14 0.064270505 172.66.147.243 → 192.168.122.18 HTTP 93 HTTP/1.1 200 OK  (text/html)
```

![Traffico TLS senza le chiavi: Client Hello, poi solo Application Data](/images/wireshark-tls-encrypted.png "Senza le chiavi: si vede il nome del sito (SNI, example.com), il contenuto no")

![La stessa cattura con il file delle chiavi: GET e 200 OK in chiaro](/images/wireshark-tls-decrypted.png "Con il file delle chiavi: l'HTTP dentro, e una scheda Decrypted TLS sotto i byte")

`curl` rispetta `SSLKEYLOGFILE` (provato qui sopra); Firefox e i browser basati su Chromium leggono la stessa variabile quando vengono avviati da un terminale che la imposta. Nell'interfaccia grafica l'impostazione sta in **Edit → Preferences → Protocols → TLS → (Pre)-Master-Secret log filename**.

{{< callout type="warning" >}}
**Il file delle chiavi decifra tutto quello che è stato registrato con lui**, password e cookie compresi. Usalo sul tuo traffico, tienilo fuori dalle cartelle condivise e cancellalo quando hai finito.
{{< /callout >}}

## 📊 Chi parla con chi

```bash
tshark -r http.pcapng -q -z conv,ip
```

```text
================================================================================
IPv4 Conversations
Filter:<No Filter>
                                   |       <-      | |       ->      | |     Total     |
                                   | Frames  Bytes | | Frames  Bytes | | Frames  Bytes |
192.168.122.18 <-> 104.20.23.154        5 1271 bytes       7 544 bytes      12 1815 bytes
================================================================================
```

(Colonne accorciate.) Il `-q` conta: senza, `tshark` prima stampa tutti i pacchetti e solo dopo le statistiche. Nell'interfaccia grafica: **Statistics → Conversations** e **Statistics → Protocol Hierarchy**.

## 🛰️ Catturare su una macchina remota

```bash
# On the remote host your user must be in the wireshark group:
# ssh has no terminal to type a sudo password into
ssh user@remote-host "tshark -i enp2s0 -f 'not port 22' -w -" > remote.pcapng
wireshark remote.pcapng
```

Il `not port 22` non è facoltativo. La cattura torna indietro **dentro la sessione SSH che sta catturando**: ogni pacchetto spedito crea altri pacchetti da catturare. Nella prova, 6 secondi su una rete quasi ferma hanno dato 42 pacchetti, 40 dei quali erano la sessione SSH stessa; con il filtro, 2.

## 🪤 Le trappole, in una tabella

| Sintomo | Causa |
|---------|-------|
| Nessuna interfaccia nell'interfaccia grafica, nessun errore | In questa sessione non sei ancora nel gruppo `wireshark`: esci e rientra |
| `Couldn't run dumpcap in child process: Permission denied` | Stessa causa, da `tshark` |
| Barra del filtro rossa, `"80" was unexpected in this context` | Un filtro di cattura (BPF) scritto come filtro di visualizzazione |
| Una cattura remota fatta quasi solo di SSH | Il trasporto della cattura stessa: aggiungi `not port 22` |
| `-z conv,ip` inonda il terminale | Manca `-q` |
| L'HTTPS mostra solo «Application Data» | Niente file delle chiavi: `SSLKEYLOGFILE` sul client, poi `tls.keylog_file` |
| `eth0` non esiste | Nomi delle interfacce «prevedibili»: `ip -br link` |

## 📚 Risorse

- [Wireshark User's Guide](https://www.wireshark.org/docs/wsug_html_chunked/)
- [Riferimento dei filtri di visualizzazione](https://www.wireshark.org/docs/dfref/)
- [pcap-filter(7)](https://www.tcpdump.org/manpages/pcap-filter.7.html) - la sintassi dei filtri di cattura
- [Pagina man di tshark](https://www.wireshark.org/docs/man-pages/tshark.html)
- [Analisi del traffico di rete con tcpdump](/it/2025/10/network-traffic-analysis-with-tcpdump-debian/ubuntu/) - le stesse catture, solo da riga di comando
