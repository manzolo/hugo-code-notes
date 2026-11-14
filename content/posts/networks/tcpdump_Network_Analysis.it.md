---
title: "Analisi del traffico di rete con tcpdump (Debian/Ubuntu)"
url: "2025/10/network-traffic-analysis-with-tcpdump-debian/ubuntu/"
date: 2025-10-04T13:35:00+02:00
lastmod: 2025-10-04T13:35:00+02:00
draft: false
author: "Manzolo"
tags: ["tcpdump", "network-analysis", "packet-capture", "cli", "troubleshooting"]
categories: ["Networking & Security"]
series: ["Networking Fundamentals"]
weight: 6
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Analisi del traffico di rete con tcpdump (Debian/Ubuntu)

## Introduzione

`tcpdump` è uno strumento leggero, da riga di comando, per catturare pacchetti e analizzare il traffico di rete sui sistemi Linux. È l'ideale sui server o per una diagnosi veloce senza interfaccia grafica, e si affianca a strumenti come Wireshark. Questa guida spiega come installare `tcpdump` su Debian/Ubuntu, catturare il traffico su un'interfaccia di rete, applicare filtri, salvare le catture in file PCAP e analizzarle con `tcpdump` o con Wireshark. Ci sono esempi per monitorare il traffico HTTP, fare debug della connettività e catturare da remoto.

## Cos'è tcpdump?

`tcpdump` è un analizzatore di pacchetti da riga di comando: cattura i pacchetti di rete in tempo reale oppure li salva in file PCAP da analizzare dopo. Le caratteristiche principali:
- **Cattura dei pacchetti**: cattura il traffico su interfacce come `eth0` o `wlan0`.
- **Filtri**: supporta la sintassi Berkeley Packet Filter (BPF) per filtrare per protocollo, IP, porta e così via.
- **Output**: mostra un riepilogo dei pacchetti oppure salva in file PCAP compatibili con Wireshark.
- **Casi d'uso**: fare debug di problemi di rete, monitorare protocolli specifici, catturare traffico per un'analisi forense.

## Prerequisiti

- **Debian/Ubuntu**: versione 20.04+.
- **Accesso root**: usa `sudo` per catturare i pacchetti (serve per la modalità promiscua).
- **Interfaccia di rete**: un'interfaccia di rete (per esempio `eth0`, `wlan0`) su cui catturare il traffico.
- **Strumenti**: `tcpdump` (si installa con `apt`), facoltativo `wireshark` per analizzare i PCAP.
- **Accesso a internet**: serve per installare `tcpdump`.

Controlla le interfacce di rete:
```bash
ip link show
```
Esempio di output:
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 ...
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
3: wlan0: <BROADCAST,MULTICAST> mtu 1500 ...
```

## Avviso importante: sicurezza e permessi

{{< callout type="warning" >}}
**Attenzione**: catturare traffico di rete richiede i privilegi di root e può esporre dati sensibili (per esempio password non cifrate). Usa `tcpdump` in modo responsabile, rispetta la legge ed evita di catturare su reti pubbliche o su cui non sei autorizzato. Fai un backup delle configurazioni critiche prima di procedere.
{{< /callout >}}

## Come si usa tcpdump

### 1. Installare tcpdump
Installa `tcpdump` con `apt`:
```bash
sudo apt update
sudo apt install tcpdump
```

Verifica l'installazione:
```bash
tcpdump --version
```
Esempio di output:
```
tcpdump version 4.99.0
libpcap version 1.10.0
```

### 2. Individuare le interfacce di rete
Elenca le interfacce di rete disponibili per la cattura:
```bash
ip link show
```
Oppure con `tcpdump`:
```bash
tcpdump -D
```
Esempio di output:
```
1.eth0 [Up, Running]
2.wlan0 [Up]
3.lo [Up, Running, Loopback]
```

**Nota**: usa `eth0` per le connessioni via cavo, `wlan0` per il Wi-Fi, `lo` per il traffico locale.

### 3. Catturare il traffico di rete
Cattura i pacchetti su un'interfaccia (per esempio `eth0`):
```bash
sudo tcpdump -i eth0
```
![tcpdump che cattura una richiesta HTTP e la sua risposta](/images/tcpdump-capture.png "Output di sudo tcpdump -i enp2s0 -nn -c 6 port 80 (il nome dell'interfaccia dipende dalla tua macchina)")
Esempio di output:
```
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
13:30:01.123456 IP 192.168.1.100.12345 > 93.184.216.34.80: Flags [S], seq 123456789, win 64240, length 0
13:30:01.124567 IP 93.184.216.34.80 > 192.168.1.100.12345: Flags [S.], seq 987654321, ack 123456790, win 65535, length 0
```

Ferma la cattura con `Ctrl+C`.

Aumenta la verbosità per avere più dettagli:
```bash
sudo tcpdump -i eth0 -v
```

### 4. Applicare i filtri
Usa la sintassi Berkeley Packet Filter (BPF) per limitare i pacchetti catturati. I filtri più comuni:
- `port 80`: cattura il traffico HTTP.
- `host 192.168.1.100`: cattura il traffico da/verso un IP.
- `tcp`: cattura solo i pacchetti TCP.
- `dst 93.184.216.34`: cattura i pacchetti diretti a un IP di destinazione.

Esempio (catturare il traffico HTTP):
```bash
sudo tcpdump -i eth0 port 80
```
Esempio di output:
```
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
13:30:02.123456 IP 192.168.1.100.12345 > 93.184.216.34.80: Flags [P.], seq 123456789, ack 987654321, win 64240, length 123: HTTP: GET /index.html HTTP/1.1
13:30:02.124567 IP 93.184.216.34.80 > 192.168.1.100.12345: Flags [P.], seq 987654321, ack 123456912, win 65535, length 456: HTTP: HTTP/1.1 200 OK
```

Combina i filtri (per esempio HTTP verso un host preciso):
```bash
sudo tcpdump -i eth0 host 192.168.1.100 and port 80
```

### 5. Salvare le catture in un file PCAP
Salva i pacchetti catturati per analizzarli dopo:
```bash
sudo tcpdump -i eth0 -w capture.pcap
```

Leggi un file PCAP:
```bash
sudo tcpdump -r capture.pcap
```

Analizzalo con Wireshark:
```bash
wireshark capture.pcap &
```

### 6. Analizzare il traffico catturato
- **Analisi di base**: usa `-v` o `-vv` per informazioni dettagliate sui pacchetti:
  ```bash
  sudo tcpdump -i eth0 -vv
  ```
- **Filtrare un PCAP salvato**: applica i filtri in lettura:
  ```bash
  sudo tcpdump -r capture.pcap port 80
  ```
- **Statistiche**: conta i pacchetti o riassumi il traffico:
  ```bash
  sudo tcpdump -i eth0 -c 100
  ```

Esempio (contare 10 pacchetti HTTP):
```bash
sudo tcpdump -i eth0 -c 10 port 80
```

## Esempi

### Esempio 1: installare tcpdump
Installa `tcpdump` e verifica:
```bash
sudo apt update
sudo apt install tcpdump
tcpdump --version
```

**Output**:
```
tcpdump version 4.99.0
libpcap version 1.10.0
```

### Esempio 2: catturare il traffico HTTP
Cattura il traffico HTTP su `eth0`:
```bash
sudo tcpdump -i eth0 port 80
```

**Output**:
```
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
13:30:02.123456 IP 192.168.1.100.12345 > 93.184.216.34.80: Flags [P.], seq 123456789, ack 987654321, win 64240, length 123: HTTP: GET /index.html HTTP/1.1
13:30:02.124567 IP 93.184.216.34.80 > 192.168.1.100.12345: Flags [P.], seq 987654321, ack 123456912, win 65535, length 456: HTTP: HTTP/1.1 200 OK
```

### Esempio 3: fare debug di problemi di connessione TCP
Cattura il traffico TCP di SSH (porta 22) per diagnosticare i problemi:
```bash
sudo tcpdump -i eth0 port 22
```

**Output** (una connessione fallita):
```
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
13:30:03.123456 IP 192.168.1.100.12345 > 192.168.1.10.22: Flags [S], seq 123456789, win 64240, length 0
13:30:03.124567 IP 192.168.1.10.22 > 192.168.1.100.12345: Flags [R.], seq 0, ack 123456790, win 0, length 0
```

### Esempio 4: salvare e analizzare un file PCAP
Salva una cattura e analizzala:
```bash
sudo tcpdump -i eth0 -w capture.pcap -c 100
sudo tcpdump -r capture.pcap port 80
```

Aprila in Wireshark:
```bash
wireshark capture.pcap &
```

## Varianti

### Catturare su un server remoto
Cattura il traffico da remoto via SSH:
```bash
ssh user@remote-host "sudo tcpdump -i eth0 -w -" > remote-capture.pcap
```

Analizza in locale:
```bash
tcpdump -r remote-capture.pcap
wireshark remote-capture.pcap &
```

### Catturare protocolli specifici
Cattura solo il traffico DNS:
```bash
sudo tcpdump -i eth0 port 53
```

Cattura ICMP (per esempio il ping):
```bash
sudo tcpdump -i eth0 icmp
```

### Limitare la dimensione della cattura
Limita la cattura a 10 pacchetti o a una dimensione precisa:
```bash
sudo tcpdump -i eth0 -c 10
sudo tcpdump -i eth0 -s 100  # Capture first 100 bytes of each packet
```

## I comandi, uno per uno
- **ip link show**: elenca le interfacce di rete.
- **tcpdump -D**: elenca le interfacce su cui si può catturare.
- **tcpdump -i <interface>**: cattura i pacchetti su un'interfaccia.
- **tcpdump -w <file>**: salva la cattura in un file PCAP.
- **tcpdump -r <file>**: legge un file PCAP.
- **tcpdump -c <count>**: limita la cattura a un certo numero di pacchetti.
- **tcpdump <filter>**: applica i filtri BPF (per esempio `port 80`, `host 192.168.1.100`).
- **apt install tcpdump**: installa `tcpdump`.

## Casi d'uso
- **Debug della connettività**: individua i reset TCP o i pacchetti persi.
- **Monitoraggio del traffico web**: cattura il traffico HTTP o HTTPS.
- **Analisi di sicurezza**: rileva traffico sospetto (per esempio i port scan).
- **Analisi forense**: salva le catture per analizzarle dopo con Wireshark.

## Consigli pratici
- **Lancialo con sudo**: `tcpdump` richiede i privilegi di root per la modalità promiscua.
- **Usa i filtri**: applica i filtri BPF (per esempio `port 80`) per ridurre i dati catturati.
- **Salva i PCAP**: conserva le catture per condividerle o analizzarle nel dettaglio.
- **Output verboso**: usa `-v` o `-vv` per avere più dettagli sui pacchetti.
- **Controlla lo stato dell'interfaccia**: assicurati che sia attiva con `ip link show`.

## Risoluzione dei problemi
- **Nessun pacchetto catturato**: verifica l'interfaccia con `ip link show` e assicurati che ci sia traffico (per esempio `ping 8.8.8.8`).
- **Permesso negato**: lancialo con `sudo` o controlla i permessi dell'interfaccia (`/dev/bpf*` esiste solo su BSD e macOS). Su Linux, per catturare senza `sudo`, dai al programma le due capability che gli servono: ``sudo setcap cap_net_raw,cap_net_admin=eip $(which tcpdump)``.
- **Uso alto della CPU**: limita i pacchetti con `-c` o usa filtri precisi.
- **Sintassi del filtro non valida**: controlla la sintassi BPF (per esempio `port 80` e non `port=80`). Per i dettagli c'è `man tcpdump`.
- **Guarda i log**: controlla `/var/log/syslog` o `journalctl` per gli errori.

## Risorse
- [Pagina man di tcpdump](https://www.tcpdump.org/manpages/tcpdump.1.html)
- [Guida al networking di Ubuntu](https://ubuntu.com/server/docs/networking)
- [Analisi dei PCAP con Wireshark](https://www.wireshark.org/docs/wsug_html_chunked/)

---

*Analizza il traffico di rete in modo efficiente con `tcpdump` su Debian/Ubuntu, per una diagnosi veloce!*