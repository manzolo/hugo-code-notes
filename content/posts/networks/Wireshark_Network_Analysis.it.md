---
title: "Analisi del traffico di rete con Wireshark (Debian/Ubuntu)"
url: "2025/10/network-traffic-analysis-with-wireshark-debian/ubuntu/"
date: 2025-10-04T13:25:00+02:00
lastmod: 2025-10-04T13:25:00+02:00
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
---

# Analisi del traffico di rete con Wireshark (Debian/Ubuntu)

## Introduzione

Wireshark è un potente strumento open source per catturare e analizzare il traffico di rete, molto usato per il debug dei problemi di rete, il monitoraggio del traffico e l'analisi di sicurezza. Questa guida spiega come installare Wireshark su Debian/Ubuntu, catturare il traffico su un'interfaccia di rete, applicare i filtri e analizzare i pacchetti dei protocolli più comuni, come HTTP e TCP. Contiene esempi pratici per diagnosticare problemi di connettività, ispezionare il traffico web e capire chi consuma banda.

## Che cos'è Wireshark?

Wireshark è un analizzatore di pacchetti: cattura i pacchetti di rete in tempo reale o da file salvati (formato PCAP) e mostra nel dettaglio protocolli, contenuto dei pacchetti e comportamento della rete. Le funzioni principali:
- **Cattura dei pacchetti**: cattura il traffico su interfacce come `eth0` o `wlan0`.
- **Filtri**: permette di filtrare i pacchetti per protocollo, IP, porta e così via.
- **Analisi**: mostra i dettagli dei pacchetti, le statistiche e la gerarchia dei protocolli.
- **Casi d'uso**: debug dei problemi di rete, monitoraggio delle richieste HTTP, individuazione di traffico sospetto.

## Prerequisiti

- **Debian/Ubuntu**: versione 20.04 o successiva.
- **Accesso root**: usa `sudo` per l'installazione e la cattura dei pacchetti.
- **Interfaccia di rete**: un'interfaccia di rete (per esempio `eth0`, `wlan0`) su cui catturare il traffico.
- **Strumenti**: `wireshark` (GUI, o CLI con `tshark`), `tcpdump` (facoltativo, per confronto).
- **Accesso a internet**: serve per installare Wireshark.

Verifica le interfacce di rete:
```bash
ip link show
```
Output di esempio:
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 ...
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
3: wlan0: <BROADCAST,MULTICAST> mtu 1500 ...
```

## Avvertenza importante: sicurezza e permessi

{{< callout type="warning" >}}
**Attenzione**: catturare il traffico di rete richiede i privilegi di root o l'appartenenza al gruppo di Wireshark, e può esporre dati sensibili (per esempio le password nei protocolli non cifrati). Usa Wireshark in modo responsabile, rispetta la legge ed evita di catturare su reti pubbliche o su cui non sei autorizzato. Fai un backup delle configurazioni critiche prima di procedere.
{{< /callout >}}

## Come usare Wireshark

### 1. Installare Wireshark
Installa Wireshark con `apt` e configuralo perché anche gli utenti non root possano catturare i pacchetti.

```bash
sudo apt update
sudo apt install wireshark
```

Durante l'installazione ti viene chiesto se permettere agli utenti non root di catturare i pacchetti. Scegli **Yes** per aggiungere gli utenti al gruppo `wireshark`, altrimenti dovrai eseguire Wireshark come root (sconsigliato).

Aggiungi il tuo utente (per esempio `manzolo`) al gruppo `wireshark`:
```bash
sudo usermod -aG wireshark manzolo
```

Esci e rientra nella sessione per applicare la modifica ai gruppi. Verifica:
```bash
groups | grep wireshark
```

Installa `tshark` (la versione CLI) per le catture da terminale:
```bash
sudo apt install tshark
```

### 2. Individuare le interfacce di rete
Elenca le interfacce di rete disponibili per la cattura:
```bash
ip link show
```
Oppure con lo strumento CLI di Wireshark:
```bash
tshark -D
```
Output di esempio:
```
1. eth0
2. wlan0
3. lo (Loopback)
```

**Nota**: usa `eth0` per le connessioni cablate, `wlan0` per il Wi-Fi, oppure `lo` per il traffico locale.

### 3. Catturare il traffico di rete
Avvia la GUI di Wireshark per catturare i pacchetti:
```bash
wireshark &
```

1. Nella GUI di Wireshark seleziona un'interfaccia (per esempio `eth0`) e clicca su **Start**.
2. Il traffico compare in tempo reale: i pacchetti sono mostrati con colonne come Source, Destination, Protocol e Info.

![Wireshark mentre cattura traffico HTTP: elenco dei pacchetti, dettagli del protocollo e byte grezzi](/images/wireshark-capture.png "Wireshark mentre cattura traffico HTTP (filtro di cattura: port 80)")

In alternativa, usa `tshark` per la cattura da CLI:
```bash
tshark -i eth0
```
Output di esempio:
```
Capturing on 'eth0'
1 0.000000 192.168.1.100 → 93.184.216.34 TCP 66 12345 → 80 [SYN] Seq=0 Win=64240 Len=0
2 0.001234 93.184.216.34 → 192.168.1.100 TCP 66 80 → 12345 [SYN, ACK] Seq=0 Ack=1 Win=65535 Len=0
```

Ferma la cattura con `Ctrl+C` (CLI) o con il pulsante Stop (GUI).

### 4. Applicare i filtri
Wireshark ha i **filtri di cattura** (applicati durante la cattura) e i **filtri di visualizzazione** (applicati ai pacchetti già catturati).

- **Filtro di cattura** (limita i pacchetti catturati, per esempio solo HTTP):
  ```bash
  tshark -i eth0 -f "tcp port 80"
  ```
  Oppure nella GUI di Wireshark: scrivi `tcp port 80` nel campo del filtro di cattura prima di avviare.

- **Filtro di visualizzazione** (filtra i pacchetti nella GUI):
  - Nella GUI di Wireshark scrivi un filtro nella barra dei filtri (per esempio `http` per vedere i pacchetti HTTP).
  - Filtri comuni:
    - `ip.addr == 192.168.1.100`: i pacchetti da/verso un IP.
    - `tcp.port == 80`: il traffico TCP sulla porta 80 (HTTP).
    - `http.request`: solo le richieste HTTP.

Esempio (filtrare le richieste HTTP nella GUI):
```
http.request
```

### 5. Analizzare i pacchetti
Ispeziona i dettagli dei pacchetti in Wireshark:
- **Packet List**: mostra il riepilogo (Source, Destination, Protocol).
- **Packet Details**: espandi i protocolli (per esempio TCP, HTTP) per vedere intestazioni e payload.
- **Packet Bytes**: i dati grezzi del pacchetto, in esadecimale e ASCII.

Esempio: per analizzare una richiesta HTTP:
1. Applica il filtro `http.request`.
2. Seleziona un pacchetto ed espandi la sezione HTTP per vederne i dettagli (per esempio `GET /index.html HTTP/1.1`).

Salva i pacchetti catturati per analizzarli più tardi:
```bash
tshark -i eth0 -w capture.pcap
```
Oppure dalla GUI: File → Save As.

### 6. Monitorare l'uso della banda
Usa il menu **Statistics** di Wireshark per analizzare la banda:
- **Protocol Hierarchy**: mostra la distribuzione del traffico per protocollo (Statistics → Protocol Hierarchy).
- **Conversations**: elenca chi genera più traffico, per IP/porta (Statistics → Conversations).

Esempio (l'equivalente da CLI con `tshark`):
```bash
tshark -i eth0 -z conv,ip
```

## Esempi

### Esempio 1: installare e configurare Wireshark
Installa Wireshark e aggiungi l'utente al gruppo `wireshark`:
```bash
sudo apt update
sudo apt install wireshark
sudo usermod -aG wireshark manzolo
groups | grep wireshark
```

**Output**:
```
manzolo wireshark
```

### Esempio 2: catturare il traffico HTTP
Cattura il traffico HTTP su `eth0` con `tshark`:
```bash
tshark -i eth0 -f "tcp port 80"
```

**Output**:
```
Capturing on 'eth0'
1 0.000000 192.168.1.100 → 93.184.216.34 HTTP 123 GET /index.html HTTP/1.1
2 0.001234 93.184.216.34 → 192.168.1.100 HTTP 456 HTTP/1.1 200 OK
```

Nella GUI:
1. Avvia Wireshark (`wireshark &`).
2. Seleziona `eth0`, imposta il filtro di cattura `tcp port 80` e avvia la cattura.
3. Applica il filtro di visualizzazione `http` per vedere i pacchetti HTTP.

### Esempio 3: debug dei problemi di connessione TCP
Cattura il traffico TCP per diagnosticare i problemi di connessione:
```bash
tshark -i eth0 -f "tcp port 22"
```

**Output** (una connessione SSH fallita):
```
1 0.000000 192.168.1.100 → 192.168.1.10 TCP 66 12345 → 22 [SYN] Seq=0 Win=64240 Len=0
2 0.001234 192.168.1.10 → 192.168.1.100 TCP 66 22 → 12345 [RST, ACK] Seq=0 Ack=1 Win=0 Len=0
```

Nella GUI:
1. Avvia la cattura su `eth0`.
2. Applica il filtro di visualizzazione `tcp.port == 22 && tcp.flags.reset == 1` per trovare i reset TCP.

### Esempio 4: salvare e analizzare un file di cattura
Salva una cattura e analizzala più tardi:
```bash
tshark -i eth0 -w capture.pcap
wireshark capture.pcap &
```

Applica un filtro nella GUI di Wireshark (per esempio `ip.addr == 192.168.1.100`).

## Varianti

### Usare `tcpdump` per una cattura leggera
Se Wireshark è troppo pesante, usa `tcpdump`:
```bash
sudo apt install tcpdump
sudo tcpdump -i eth0 -w capture.pcap
```

Apri il file in Wireshark:
```bash
wireshark capture.pcap &
```

### Catturare su un server remoto
Cattura il traffico da remoto con SSH e `tshark`:
```bash
ssh user@remote-host "tshark -i eth0 -w -" > remote-capture.pcap
wireshark remote-capture.pcap &
```

### Analizzare il traffico cifrato
Se il traffico è cifrato (per esempio HTTPS), configura Wireshark con le chiavi SSL/TLS:
1. Esporta la chiave SSL del browser (per esempio `SSLKEYLOGFILE=/tmp/sslkey.log` in Firefox).
2. In Wireshark: Edit → Preferences → Protocols → TLS → imposta (Pre)-Master-Secret log filename.

## I comandi, uno per uno
- **ip link show**: elenca le interfacce di rete.
- **tshark -D**: elenca le interfacce di cattura.
- **wireshark**: avvia la GUI di Wireshark.
- **tshark -i <interface>**: cattura i pacchetti da CLI.
- **tshark -f "<filter>"**: applica i filtri di cattura (per esempio `tcp port 80`).
- **tshark -w <file>**: salva la cattura in un file PCAP.
- **apt install wireshark/tshark**: installa Wireshark o lo strumento CLI.
- **wireshark <file>**: apre un file PCAP per l'analisi.

## Casi d'uso
- **Debug della connettività**: individuare reset TCP o pacchetti persi.
- **Monitoraggio del traffico web**: analizzare richieste e risposte HTTP.
- **Analisi di sicurezza**: rilevare traffico sospetto (per esempio i port scan).
- **Analisi della banda**: capire chi genera più traffico o quali protocolli si usano.

## Consigli pratici
- **Esegui senza root**: aggiungi sempre gli utenti al gruppo `wireshark`, così eviti di lanciarlo come root.
- **Usa i filtri di cattura**: riduci i dati catturati con i filtri (per esempio `tcp port 80`) per migliorare le prestazioni.
- **Salva le catture**: conserva i file PCAP per analizzarli più tardi o condividerli.
- **Scorciatoie per i filtri**: sfrutta il completamento automatico di Wireshark nella barra dei filtri per scriverli in fretta.
- **Controlla i permessi**: assicurati che l'interfaccia di cattura sia accessibile (per esempio `sudo chmod o+rw /dev/bpf*` su alcuni sistemi).

## Risoluzione dei problemi
- **Wireshark non avvia la cattura**: verifica che l'utente sia nel gruppo `wireshark` oppure usa `sudo`. Controlla con `ip link show` che le interfacce siano valide.
- **Nessun pacchetto catturato**: assicurati di aver selezionato l'interfaccia giusta e che ci sia traffico (per esempio `ping 8.8.8.8`).
- **Permission denied**: lancia `sudo dpkg-reconfigure wireshark-common` e scegli Yes per la cattura senza root.
- **Uso elevato della CPU**: usa i filtri di cattura per limitare i pacchetti, oppure passa a `tshark`.
- **Traffico cifrato**: configura le chiavi SSL/TLS per analizzare l'HTTPS.
- **Controlla i log**: guarda `/var/log/syslog` o `journalctl -u wireshark` per gli errori.

## Risorse
- [Guida utente di Wireshark](https://www.wireshark.org/docs/wsug_html_chunked/)
- [Guida al networking di Ubuntu](https://ubuntu.com/server/docs/networking)
- [Pagina man di tshark](https://www.wireshark.org/docs/man-pages/tshark.html)

---

*Analizza il traffico di rete con Wireshark, per un debug e un monitoraggio efficaci su Debian/Ubuntu!*
