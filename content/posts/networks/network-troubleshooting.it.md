---
title: "Diagnosi di rete: un metodo a livelli"
url: "2026/09/network-troubleshooting-a-layered-diagnostic-method/"
date: 2026-09-18T12:00:00+02:00
lastmod: 2026-11-14T19:00:00+01:00
draft: false
author: "Manzolo"
tags: ["networking", "troubleshooting", "linux", "windows", "dns"]
categories: ["Networking & Security"]
series: ["Networking Fundamentals"]
weight: 10
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "Una macchina della LAN non risponde, o risponde a metà: capire quale livello è rotto invece di provare comandi a caso"
---

# Diagnosi di rete: un metodo a livelli

{{< callout type="info" >}}
**A cosa serve**: una macchina della LAN non risponde, o risponde *a metà*. Invece di
provare comandi a caso, capisci **su quale livello** sta davvero il problema.
{{< /callout >}}

## 🧭 Si diagnostica dal basso verso l'alto

> **Cavo, link, IP, gateway, DNS, porta, applicazione.** In quest'ordine.

Saltare un livello vuol dire dare al DNS o al firewall la colpa di un problema che sta due
piani più sotto. Succede di continuo, e per un motivo comprensibile: i livelli alti
producono messaggi di errore leggibili. *«Name resolution failed»* è una frase che puoi
incollare in un motore di ricerca. Un cavo con una coppia schiacciata è silenzio. Così la
frase viene indagata e il silenzio no.

La disciplina è semplice e un po' noiosa: **non si sale finché il livello corrente non ti
ha dato un sì netto.** È il «sì» al livello *n* a dare un significato a un guasto al
livello *n+1*. Senza quello non stai diagnosticando: stai tirando a indovinare con una
tastiera.

| # | Livello | La domanda a cui risponde | Se fallisce, guarda |
|---|---------|---------------------------|---------------------|
| 1 | **Link e interfaccia** | C'è una connessione fisica, e un indirizzo vero? | Cavo, porta, switch, DHCP |
| 2 | **Raggiungibilità locale** | La macchina è viva su questo segmento? | ARP, IP duplicato, firewall dell'host |
| 3 | **Routing e gateway** | I pacchetti riescono a uscire dalla subnet e a tornare? | Rotta, netmask, VLAN |
| 4 | **DNS** | Il nome diventa l'indirizzo giusto? | Resolver, zona, cache, suffisso |
| 5 | **Porte e servizi** | Il servizio è in ascolto, ed è raggiungibile? | Servizio fermo, indirizzo di bind |
| 6 | **Firewall e proxy** | Qualcosa lo scarta o lo devia? | Firewall dell'host, profilo, proxy |
| 7 | **Traffico** | Cosa passa davvero sul cavo? | `tcpdump`, `curl`, `openssl` |

{{< callout type="info" >}}
**Convenzioni usate in tutta la pagina.** LAN `192.168.1.0/24`, gateway `192.168.1.1`. La
macchina sotto esame è **`workstation-01`**, a `192.168.1.47`; la diagnosi si fa **da**
`192.168.1.10`. Server interno `192.168.1.20`; DNS interni `192.168.1.5` e
`192.168.1.6`. Esempi pubblici `203.0.113.10` e `198.51.100.25` (intervalli per la
documentazione, RFC 5737). Domini: `example.internal` dentro, `example.com` fuori.
{{< /callout >}}

{{< callout type="warning" >}}
**Prima di lanciare qualunque cosa di questa pagina**: `nmap` e `tcpdump` su reti che non
amministri possono violare le regole interne, e in certi posti qualcosa di più delle
regole. Per chi osserva, un port scan è indistinguibile da una ricognizione, e una cattura
di pacchetti su un segmento condiviso vede il traffico degli altri. **Usali solo su reti
di cui ti occupi tu**, e nel dubbio chiedi prima a chi la rete la gestisce.
{{< /callout >}}

## 🔌 Livello 1 - Link e interfaccia

Prima di tutto: la macchina ha davvero una connessione?

### Linux

```bash
ip -br link            # interface state, one line each
ip -br addr            # addresses, one line each
ethtool eth0           # speed, duplex, and "Link detected"
ip -s link show eth0   # error and drop counters
```

```text
$ ip -br link
lo               UNKNOWN        00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP>
eth0             UP             52:54:00:a1:b2:c3 <BROADCAST,MULTICAST,UP,LOWER_UP>

$ ethtool eth0
        Speed: 1000Mb/s
        Duplex: Full
        Link detected: yes
```

`Link detected: yes` è la risposta del livello 1. Senza quella, tutto il resto di questa
pagina non significa niente.

### Windows

```powershell
Get-NetAdapter | Format-Table Name, Status, LinkSpeed, MacAddress
Get-NetIPConfiguration
Get-NetAdapterStatistics
```

```batch
ipconfig /all
```

### 🚩 I quattro allarmi di questo livello

| Segnale | Cosa significa |
|---------|----------------|
| Interfaccia **DOWN** / `Link detected: no` | Cavo, porta o scheda di rete. Non c'è ancora una rete su cui fare debug |
| Indirizzo **`169.254.x.x`** (APIPA) | **Il DHCP è fallito.** Tutto quello che sta sopra è rumore |
| **100 Mbps** negoziati su una porta gigabit | Cavo o porta danneggiati |
| `errors` / `dropped` **in crescita** in `ip -s link` | Fisico: cavo, connettore, duplex mismatch |

Il caso APIPA va detto senza giri di parole: **`169.254.x.x` significa che il resto della
diagnosi è rumore.** La macchina non ha un indirizzo utilizzabile, quindi non raggiunge il
gateway, non raggiunge il DNS e non è raggiungibile da te. Indagare sulla risoluzione dei
nomi su un host con un indirizzo APIPA è tempo buttato. Vai a scoprire perché il DHCP non
ha risposto.

Il caso dei 100 Mbps è quello che sfugge di più fra i quattro, perché *funziona* - solo
male. Il Fast Ethernet usa due coppie, il gigabit le vuole tutte e quattro. **Rompi una
coppia e il link, zitto zitto, negozia al ribasso a 100 Mbps invece di cadere.** Un cavo
schiacciato, un pin dell'RJ45 piegato, una porta del patch panel mai crimpata bene: il
sintomo non è un'interruzione, è una macchina misteriosamente dieci volte più lenta delle
vicine.

```bash
# Watch the counters move while the problem is happening
watch -n1 'ip -s link show eth0 | tail -4'
ethtool -S eth0 | grep -iE 'err|drop|crc'
```

### Sullo switch, se ci puoi arrivare

Uno switch gestito chiude le discussioni in fretta: **stato della porta**, **velocità
negoziata** e soprattutto **contatori di errore** (CRC, runt, late collision). Gli errori
CRC contati sulla porta dello switch sono cablaggio. Non un driver, non un sistema
operativo, non un firewall: cablaggio.

## 📡 Livello 2 - Raggiungibilità locale

La macchina ha un link e un indirizzo. È viva su questo segmento?

### ⚠️ La trappola del ping - da leggere prima di concludere qualunque cosa

{{< callout type="warning" >}}
**Una macchina Windows che non risponde al ping può essere in perfetta salute.** Windows
Defender Firewall blocca di default gli ICMP Echo Request in ingresso, e soprattutto sul
profilo di rete **Pubblico**. `Request timed out` quindi **non** è una prova che l'host
sia giù.

È il falso negativo più costoso della diagnosi di rete. Manda la gente in sala server a
guardare una macchina che è rimasta accesa tutto il tempo.
{{< /callout >}}

```bash
ping -c3 192.168.1.47
```

Per far rispondere la macchina, quando è davvero quello che vuoi:

```powershell
# Either enable the built-in rule...
Set-NetFirewallRule -Name FPS-ICMP4-ERQ-In -Enabled True
# ...or create an explicit one
New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4 `
    -IcmpType 8 -Direction Inbound -Action Allow
```

### ARP: la risposta che il ping non ti può dare

È lo strumento decisivo di questo livello, ed è usato molto meno di quanto meriti. **ARP
lavora sotto il filtraggio IP**: un host che scarta i tuoi ping deve comunque rispondere
all'ARP, altrimenti non potrebbe proprio usare la rete. Se per `192.168.1.47` c'è una voce
con un MAC valido, quella macchina è accesa e presente sul segmento - qualunque cosa dica
il ping.

```bash
ip neigh show 192.168.1.47
# 192.168.1.47 dev eth0 lladdr 52:54:00:a1:b2:c3 REACHABLE   <- it is there
# 192.168.1.47 dev eth0  FAILED                              <- nothing answered
```

```batch
:: Windows
arp -a 192.168.1.47
```

Per fare la domanda direttamente al livello 2, scavalcando del tutto i firewall IP:

```bash
sudo arping -I eth0 -c3 192.168.1.47
```

E per passare al setaccio il segmento senza dipendere dall'ICMP - su una subnet locale
`nmap -sn` usa l'**ARP**, quindi trova anche gli host che scartano i ping in silenzio:

```bash
sudo nmap -sn 192.168.1.0/24
sudo arp-scan --localnet
```

### IP duplicato, e perché i suoi sintomi sono così difficili da leggere

Due macchine configurate con `192.168.1.47` producono un guasto diverso da tutti gli
altri: funziona, poi non funziona, poi funziona di nuovo. **L'intermittenza senza uno
schema è la firma.**

Si legge così male perché non c'è niente di rotto in nessun singolo componente. Ogni cache
ARP del segmento tiene la risposta arrivata per ultima, e non tengono tutte la stessa. Così
`192.168.1.10` può parlare con la workstation vera mentre `192.168.1.20` parla con
l'impostore, nello stesso istante, ed entrambi sono convinti di avere ragione. Riavvia
qualcosa, o lascia scadere una cache, e i ruoli si scambiano. Ogni prova che fai dà una
risposta diversa: sembra una rete ballerina, e in realtà sono due macchine che rispondono
allo stesso nome.

```bash
# Two replies, two different MACs, for one address = duplicate
$ sudo arping -I eth0 -c3 192.168.1.47
Unicast reply from 192.168.1.47 [52:54:00:A1:B2:C3]  0.641ms
Unicast reply from 192.168.1.47 [52:54:00:D4:E5:F6]  0.702ms   <- second owner
```

Gli indizi che lo confermano:

```bash
ip -s neigh show 192.168.1.47          # the entry keeps changing MAC
journalctl -k | grep -i 'duplicate address'
```

```powershell
# Windows logs the conflict explicitly: Tcpip event 4199
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Tcpip'; Id=4199} `
    -ErrorAction SilentlyContinue | Select-Object TimeCreated, Message
```

La causa solita è un indirizzo statico assegnato dentro il pool del DHCP. La correzione va
fatta sul server DHCP - restringi il pool, oppure trasformalo in una prenotazione fatta
come si deve - non sui due host.

### ✅ Criterio per salire

L'ARP risolve e l'host è presente su questo segmento. **Solo adesso** non riuscire a
raggiungere qualcosa fuori dalla subnet vuol dire routing, e non una macchina morta.

## 🚪 Livello 3 - Routing e gateway

```bash
ip route
ping -c3 192.168.1.1              # the gateway FIRST, before anything external
ip neigh show 192.168.1.1
traceroute 203.0.113.10
```

```powershell
Get-NetRoute -AddressFamily IPv4 | Format-Table DestinationPrefix, NextHop, RouteMetric
```

```batch
route print
tracert -d 203.0.113.10
```

```text
$ ip route
default via 192.168.1.1 dev eth0 proto dhcp metric 100
192.168.1.0/24 dev eth0 proto kernel scope link src 192.168.1.47
```

**Fai il ping al gateway prima di farlo a qualunque cosa di esterno.** Se `192.168.1.1` non
risponde, ogni prova verso l'esterno che fai dopo ti dice la stessa cosa due volte e ti
costa un minuto.

{{< callout type="info" >}}
**Perché `tracert` su Windows sembra rotto**: di default fa una risoluzione DNS inversa su
ogni hop, quindi ognuno aspetta un resolver che può essere lui stesso parte del problema.
**`tracert -d`** salta la risoluzione dei nomi e risponde in pochi secondi. Se ti sei mai
chiesto perché lo strumento di Windows è «tanto più lento di traceroute», il motivo è
tutto qui.
{{< /callout >}}

### mtr, e come leggerlo senza ingannarsi

`traceroute` è una singola istantanea. Per i problemi intermittenti è quasi inutile:
l'unica passata che hai fatto può aver mancato del tutto la perdita, oppure aver beccato un
secondo sfortunato e mostrato una perdita che non c'è. **`mtr` continua a sondare e ti dà
statistiche continue**, che è quello che serve davvero per un guasto intermittente.

```bash
mtr -rwc 100 203.0.113.10        # report mode, 100 cycles, wide output
```

```text
HOST                         Loss%   Snt   Last   Avg  Best  Wrst StDev
1. 192.168.1.1                0.0%   100    0.4   0.5   0.3   1.2   0.1
2. 203.0.113.1               18.0%   100    8.2   8.9   7.9  24.0   2.1     <- ignore this
3. 198.51.100.25              0.0%   100    9.1   9.4   8.8  19.2   1.6
4. 203.0.113.10               0.0%   100    9.3   9.7   9.0  21.4   1.8
```

{{< callout type="warning" >}}
**Una perdita su un hop intermedio, con gli hop successivi puliti, non è un problema.**

Molti router mettono in bassa priorità o limitano l'ICMP indirizzato *a loro stessi*,
perché generare quelle risposte costa CPU che è meglio spendere per inoltrare. Così l'hop 2
qui sopra mostra il 18% di perdita mentre gli hop 3 e 4 non ne mostrano - cosa impossibile
se l'hop 2 scartasse davvero il traffico, dato che tutto quello che va agli hop 3 e 4 ci
passa *attraverso*.

**Conta solo la perdita che persiste fino alla destinazione.** Leggere come guasto la
perdita su un hop intermedio è il modo più comune di dare la colpa alla rete sbagliata - di
solito quella di qualcun altro, in una mail di cui ti pentirai.
{{< /callout >}}

### VLAN: una subnet che sembra la stessa, un segmento diverso

Se `192.168.1.47` e `192.168.1.10` stanno su VLAN diverse pur sembrando nella stessa `/24`,
il loro traffico passa dal router, e tutto quello che il router non permette semplicemente
non succede.

L'indizio pulito sta al livello 2: **l'ARP non attraversa il confine di una VLAN.** Quindi
una voce di `ip neigh` che resta `FAILED` per un host che sembra stare nella tua stessa
subnet vuol dire che non siete sullo stesso segmento, qualunque cosa suggerisca
l'indirizzamento.

```bash
ip neigh show 192.168.1.47      # FAILED for an "on-link" host = different VLAN
traceroute -n 192.168.1.47      # a hop appearing at all proves it is being routed
```

Un classico imparentato è la netmask sbagliata: `192.168.1.47/25` tratta `192.168.1.0-127`
come locale e manda al gateway tutto quello che sta sopra `.127`. Mezza LAN funziona. Gli
utenti dicono che va a singhiozzo.

```bash
ip -br addr show eth0
# eth0  UP  192.168.1.47/25      <- and every neighbour is /24
```

### ✅ Criterio per salire

Rotta di default presente, gateway che risponde, destinazione raggiungibile **per IP**.
Adesso un fallimento *per nome* è una questione di DNS.

## 🌐 Livello 4 - DNS

> **Prova per IP, poi per nome.** Se `192.168.1.20` risponde e
> `server.example.internal` no, è il DNS - non «la rete».
> Se fallisce anche l'IP, non è il DNS. Torna giù.

Questa sola distinzione risolve metà dei casi, ed è quella che la gente salta.

```bash
dig +short server.example.internal
dig @192.168.1.5 server.example.internal
dig @192.168.1.6 server.example.internal
dig +trace example.com
dig -x 192.168.1.47                     # reverse lookup
resolvectl status                       # which resolver is REALLY in use, per link
resolvectl flush-caches
```

```powershell
Resolve-DnsName server.example.internal -Server 192.168.1.5
Get-DnsClientServerAddress
```

```batch
nslookup server.example.internal 192.168.1.5
ipconfig /displaydns
ipconfig /flushdns
```

### 🚩 Interroga ogni resolver a mano

Con `192.168.1.5` e `192.168.1.6` entrambi configurati, **un solo resolver rotto produce
un guasto intermittente, non un'interruzione**: lo stack li alterna e più o meno metà delle
risoluzioni va a buon fine. Gli utenti lo descrivono come «ogni tanto è lento», che suona
come un problema di prestazioni e non lo è.

```bash
for ns in 192.168.1.5 192.168.1.6; do
    printf '%s -> ' "$ns"
    dig +short +time=2 +tries=1 @"$ns" server.example.internal || echo TIMEOUT
done
```

### 🚩 resolvectl status: il resolver che credi di aver configurato

Con `systemd-resolved` il server DNS scritto in `/etc/resolv.conf` spesso **non** è quello
che viene usato. La risoluzione è per link, le VPN e NetworkManager iniettano i propri
server, e `127.0.0.53` in `resolv.conf` non ti dice niente su dove finiscono le query.

```bash
resolvectl status | grep -A3 'Link.*eth0'
```

Controllalo **prima** di concludere che un server DNS è rotto. È regolarmente la risposta a
«ma io ho configurato `192.168.1.5`, perché chiede a qualcun altro?»

### Domini di ricerca e suffissi

Perché `ping workstation-01` funziona mentre `ping workstation-01.example.internal` no, o
il contrario?

- **Il nome breve funziona, l'FQDN no**: al nome breve sta rispondendo qualcosa che non è
  il DNS - `/etc/hosts`, una voce del file `hosts`, LLMNR o NetBIOS su Windows. L'FQDN va
  al DNS vero e proprio, dove il record manca o è sbagliato.
- **L'FQDN funziona, il nome breve no**: il **suffisso di ricerca** manca o è sbagliato,
  quindi `workstation-01` non viene mai espanso in `workstation-01.example.internal`.

```bash
resolvectl status | grep -i 'search'
cat /etc/resolv.conf
```

```powershell
Get-DnsClient | Format-Table InterfaceAlias, ConnectionSpecificSuffix
Get-DnsClientGlobalSetting | Select-Object SuffixSearchList
```

E controlla sempre la forzatura che batte ogni strumento DNS, perché a tutti loro è
invisibile ed è *sempre* qualcosa che una persona ha scritto durante una sessione di
diagnosi precedente:

```bash
cat /etc/hosts
```

```cmd
type C:\Windows\System32\drivers\etc\hosts
```

### ✅ Criterio per salire

Il nome si risolve, da questa macchina, nell'indirizzo che ti aspetti. Adesso: c'è qualcosa
in ascolto?

## 🔉 Livello 5 - Porte e servizi

### Sulla macchina stessa

```bash
sudo ss -tulpn
sudo ss -lntp | grep ':3389'
```

```text
LISTEN 0 511 127.0.0.1:443 0.0.0.0:*  users:(("nginx",pid=1234,fd=6))
             ^^^^^^^^^
```

Eccolo, il classico: il servizio **è** in esecuzione, ed è legato a **`127.0.0.1`** invece
che a `0.0.0.0`, quindi risponde solo dalla macchina stessa. In locale funziona tutto, ed è
proprio per questo che nessuno sospetta del server. Da `192.168.1.10` ricevi un rifiuto, e
il ticket dice *«la rete non funziona»* - mentre la rete sta benissimo e il problema è una
riga di un file di configurazione.

```batch
netstat -ano | findstr :3389
```

```powershell
Get-NetTCPConnection -State Listen |
    Select-Object LocalAddress, LocalPort, OwningProcess
```

### Dal client

```bash
nc -zv 192.168.1.47 3389
sudo nmap -Pn -p 3389 192.168.1.47
```

```powershell
Test-NetConnection 192.168.1.47 -Port 3389
# TcpTestSucceeded : True
```

`Test-NetConnection -Port` è molto più utile del ping, perché prova il **TCP** invece
dell'ICMP - il protocollo che il tuo servizio usa davvero, e quello che non è bloccato di
default.

{{< callout type="warning" >}}
**`-Pn` non è facoltativo quando l'ICMP è filtrato.** Senza, `nmap` fa prima il ping
all'host e, se non arriva risposta, lo salta del tutto, riportando *«host seems down»*
senza aver mai provato una sola porta. La trappola del ping del livello 2 torna a morderti
qui, se la lasci fare.
{{< /callout >}}

### 🚩 Rifiuto e timeout sono diagnosi opposte

Questa distinzione è tutto il senso di questo livello:

| Risultato | Pacchetto | Significato | Guarda |
|-----------|-----------|-------------|--------|
| **Connection refused** | È tornato un **RST** | L'host è su e **ha risposto**. Su quella porta non c'è niente in ascolto | Il **servizio**: fermo, andato in crash, legato all'indirizzo sbagliato |
| **Timeout / filtered** | Non è tornato **niente** | Qualcosa sta **scartando in silenzio** il pacchetto | Un **firewall**, sull'host o lungo il percorso |

Un rifiuto è una buona notizia: dimostra i livelli da 1 a 3 fino allo stack TCP della
destinazione. Un timeout dimostra solo che qualcuno scarta il traffico, e la domanda
interessante diventa *chi* - che è il livello 6.

### Porte da conoscere su una workstation Windows

| Porta | Servizio | Sintomo tipico quando è bloccata |
|-------|----------|----------------------------------|
| **445** | SMB | Condivisioni e `\\workstation-01` irraggiungibili |
| **3389** | RDP | Desktop remoto va in timeout |
| **135** | RPC endpoint mapper | WMI, gestione remota e console MMC falliscono |
| **5985** | WinRM (HTTP) | `Enter-PSSession` / `Invoke-Command` falliscono |

## 🛡️ Livello 6 - Firewall e proxy

### Windows: controlla il profilo prima delle regole

```powershell
Get-NetFirewallProfile | Format-Table Name, Enabled, DefaultInboundAction
Get-NetConnectionProfile                    # which profile is this network in?
Get-NetFirewallRule -Enabled True -Direction Inbound |
    Where-Object DisplayName -match 'Remote Desktop'
```

```batch
netsh advfirewall show allprofiles
```

{{< callout type="warning" >}}
**Il profilo di rete cambia in silenzio quali regole si applicano.** Una macchina che passa
da *Privato* a *Pubblico* - dopo un aggiornamento, un cambio di scheda di rete, un riavvio
in cui il domain controller ha risposto tardi - applica un insieme di regole completamente
diverso. Nessuno ha modificato una regola. Nessuno ha toccato un firewall. E RDP smette di
funzionare.

È la causa del caso di studio più sotto, ed è abbastanza comune da controllarla presto.
{{< /callout >}}

### Linux

```bash
sudo nft list ruleset
sudo iptables -L -n -v            # with counters: which rule is actually matching
sudo ufw status verbose
```

Il `-v` di `iptables -L -n -v` conta: i contatori dei pacchetti ti dicono quale regola sta
scartando, invece di lasciarti a leggere tutta la catena e a ragionarci sopra.

### Proxy: quello di sistema non è quello del browser

```batch
netsh winhttp show proxy
```

```powershell
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' |
    Select-Object ProxyEnable, ProxyServer
```

**Sono due impostazioni diverse.** Il browser usa la configurazione WinINET dell'utente;
**Windows Update, lo stack di servicing e la maggior parte dei servizi usano WinHTTP**.
Così «internet funziona» - nel browser - mentre gli aggiornamenti falliscono all'infinito,
e i due fatti non si contraddicono.

Su Linux:

```bash
env | grep -i proxy
```

Qui quella subdola è **`no_proxy`**. Configurata male, rompe il traffico *interno* in un
modo che sembra un guasto di DNS o di routing: gli host interni vengono mandati al proxy,
che non ha idea di cosa sia `server.example.internal` e li rifiuta.

```bash
# Internal destinations must bypass the proxy - note the leading dots and the CIDR
export no_proxy="localhost,127.0.0.1,.example.internal,192.168.1.0/24"
```

Ricorda che in molti strumenti il confronto di `no_proxy` è letterale: `.example.internal`
copre i sottodomini, `example.internal` da solo può non coprirli.

## 🔬 Livello 7 - Guardare il traffico vero

Quando i livelli precedenti non hanno chiuso la questione, smetti di ragionare e guarda.

```bash
sudo tcpdump -i eth0 host 192.168.1.47 -nn
sudo tcpdump -i eth0 port 445 -nn -w capture.pcap      # for Wireshark afterwards
```

`-nn` disattiva la risoluzione dei nomi sia per gli host sia per le porte: è più veloce, e
toglie a `tcpdump` la dipendenza dal DNS su cui magari stai facendo debug.

### Leggere un handshake TCP fallito

È qui che la cattura ripaga, e distingue i due casi del livello 5 con certezza invece che
per deduzione:

```text
# SYN with no SYN-ACK: dropped upstream, silently
10:14:02.113 IP 192.168.1.10.51234 > 192.168.1.47.3389: Flags [S], seq 1043...
10:14:03.115 IP 192.168.1.10.51234 > 192.168.1.47.3389: Flags [S], seq 1043...   <- retry
10:14:05.119 IP 192.168.1.10.51234 > 192.168.1.47.3389: Flags [S], seq 1043...   <- retry
```

```text
# SYN followed by RST: actively refused - the host answered
10:16:40.882 IP 192.168.1.10.51240 > 192.168.1.47.3389: Flags [S], seq 88213...
10:16:40.883 IP 192.168.1.47.3389 > 192.168.1.10.51240: Flags [R.], seq 0, ack ...
```

SYN ritrasmessi senza niente che torna indietro vuol dire un **firewall che scarta**. Un
RST immediato vuol dire che l'**host sta bene e nessun servizio è in ascolto**. Catturare
da *entrambi* i lati ti dice ancora di più: se il SYN arriva a `workstation-01` e la
risposta non raggiunge mai `192.168.1.10`, lo scarto è sul percorso di ritorno, e hai
appena eliminato mezza rete.

Su Windows c'è un equivalente integrato:

```batch
pktmon filter add -i 192.168.1.47
pktmon start --capture
:: reproduce the problem, then
pktmon stop
pktmon etl2pcap PktMon.etl -o capture.pcap
```

### HTTP e TLS

```bash
curl -v https://server.example.internal/
curl -I https://server.example.internal/                 # headers only
curl -v --resolve server.example.internal:443:192.168.1.20 https://server.example.internal/
openssl s_client -connect 192.168.1.20:443 -servername server.example.internal </dev/null
```

Il trucco di **`--resolve`** è il miglior strumento singolo a questo livello: punta `curl`
su un IP preciso continuando a mandare l'header `Host` e l'SNI corretti. **Se con
`--resolve` funziona e senza fallisce, il server sta bene ed è il DNS a mandarti altrove** -
il che ti riporta al livello 4 con in mano una prova invece di un sospetto.

## 📏 I problemi di MTU, una sezione a parte

L'MTU merita un discorso separato perché produce i sintomi più ingannevoli di tutto il
networking: **il ping funziona, SSH si collega e poi si blocca, le pagine web si caricano a
metà.**

Il meccanismo: i pacchetti piccoli passano, quelli grandi no. Così ogni prova veloce va a
buon fine e ogni trasferimento vero si pianta. La connessione viene stabilita - per quella
bastano pacchetti piccoli - e poi muore nel momento in cui qualcosa manda un frame a
dimensione piena.

```bash
# 1472 payload + 8 ICMP + 20 IP = 1500. Do not fragment.
ping -M do -s 1472 -c2 203.0.113.10
```

```batch
ping -f -l 1472 203.0.113.10
```

### Trovare l'MTU reale per bisezione

Se 1472 fallisce, scendi dimezzando finché non passa, poi risali:

```bash
for s in 1472 1400 1300 1200; do
    printf '%s: ' "$s"
    ping -M do -s "$s" -c1 -W2 203.0.113.10 >/dev/null 2>&1 && echo OK || echo FAIL
done
```

```text
1472: FAIL
1400: OK        <- narrow between 1400 and 1472 from here
```

**L'MTU reale è il payload più grande che passa, più 28** (20 byte di header IP più 8 di
ICMP). Se il payload più grande che passa è 1422, l'MTU è 1450 - un valore tipicissimo per
un tunnel.

Cause tipiche:

| Causa | MTU tipico |
|-------|------------|
| PPPoE (DSL) | 1492 |
| Tunnel IPsec / OpenVPN | 1400-1450 |
| WireGuard | 1420 |
| GRE | 1476 |

E quella che trasforma un piccolo fastidio in un mistero: **il Path MTU Discovery rotto da
un firewall che scarta l'ICMP**. Il PMTUD funziona facendo restituire a un router
*«fragmentation needed»* (ICMP tipo 3, codice 4) quando un pacchetto è troppo grande. Un
amministratore che blocca «tutto l'ICMP» per sicurezza ammazza quel messaggio - così chi
trasmette non impara mai a mandare pacchetti più piccoli e si limita a ritrasmettere
all'infinito lo stesso frame troppo grande. La connessione resta appesa invece di
adattarsi.

```bash
tracepath 203.0.113.10          # reports the pmtu where it changes
```

Se sospetti questo, controlla che l'ICMP tipo 3 codice 4 sia permesso prima di metterti ad
abbassare MTU a mano dappertutto.

## 🧪 Caso di studio: RDP verso workstation-01 va in timeout

`192.168.1.47` non è raggiungibile in RDP da `192.168.1.10`. Si percorrono i livelli in
ordine.

### 1. Il ping fallisce

```text
C:\> ping 192.168.1.47
Request timed out.
```

**Imparato: niente.** Inconcludente per costruzione - l'ICMP può essere filtrato, e su
Windows di solito lo è. Qui la tentazione è dichiarare la macchina morta e andarci a piedi.
Si resiste.

### 2. L'ARP mostra una voce valida

```text
C:\> arp -a 192.168.1.47
  Internet Address      Physical Address      Type
  192.168.1.47          52-54-00-a1-b2-c3     dynamic
```

**Imparato: la macchina è viva e sta su questo segmento.** Per un host spento una voce con
un MAC valido non può esistere. Il livello 2 è un sì netto, e implicitamente lo è anche il
livello 1. Si sale.

### 3. La porta 3389 va in timeout - e non rifiuta

```text
PS> Test-NetConnection 192.168.1.47 -Port 3389
WARNING: TCP connect to (192.168.1.47 : 3389) failed
TcpTestSucceeded : False
```

La distinzione del livello 5 decide il resto dell'indagine: **timeout, non rifiuto.** Non è
tornato proprio niente. Se RDP fosse stato semplicemente fermo, l'host avrebbe risposto con
un RST e avremmo avuto un rifiuto in pochi millisecondi. Qualcosa sta **scartando** i
pacchetti.

### 💀 L'ipotesi che è morta qui

A questo punto la teoria ragionevole era **una ACL sul router**: la notte prima una
finestra di manutenzione aveva toccato gli apparati di rete, un timeout è esattamente
quello che produce una ACL su un router, e le due macchine stanno su VLAN diverse. Calza
alla perfezione con il passo 3.

È stata messa alla prova ed è morta: `Test-NetConnection 192.168.1.20 -Port 3389` dallo
stesso client è andato a buon fine, sullo stesso percorso di VLAN. **Il percorso lascia
passare la 3389.** Quindi lo scarto è a destinazione, non in mezzo. Vale la pena
annotarlo, perché era la teoria giusta da avere e verificarla è costato trenta secondi -
mentre agire di conseguenza avrebbe voluto dire aprire un ticket al gruppo di rete e
aspettare un giorno una risposta che avevamo già.

### 4. Sulla macchina: il servizio è in ascolto

```text
C:\> netstat -ano | findstr :3389
  TCP    0.0.0.0:3389      0.0.0.0:0      LISTENING     1288
```

**Imparato: il servizio è su ed è legato a `0.0.0.0`**, non al loopback. Quindi RDP in sé
sta bene e i pacchetti vengono scartati prima di arrivarci. Resta esattamente un livello:
il firewall dell'host.

### 5. Il profilo di rete è passato a Pubblico

```text
PS> Get-NetConnectionProfile
Name             : Network 3
NetworkCategory  : Public

PS> Get-NetFirewallRule -DisplayGroup "Remote Desktop" |
      Select-Object DisplayName, Enabled, Profile
DisplayName                          Enabled  Profile
-----------                          -------  -------
Remote Desktop - User Mode (TCP-In)  True     Domain, Private
```

**Eccolo.** Dopo un aggiornamento la macchina è partita prima che il domain controller
rispondesse, la rete è stata classificata come **Pubblica**, e le regole di RDP valgono
solo per **Domain, Private**. Nessuno ha cambiato una regola del firewall. La regola è
attiva, corretta, e semplicemente non si applica al profilo in cui la macchina si trova
adesso.

```powershell
# Put the network back in the right category
Set-NetConnectionProfile -InterfaceAlias 'Ethernet' -NetworkCategory Private
```

Cinque passi, nessun riavvio, nessuna reinstallazione, e l'ipotesi che al passo 3 sembrava
la più probabile era sbagliata - che è la forma normale di una diagnosi, non il suo
fallimento.

## 📊 Sintomo → livello → primo comando

| Sintomo | Livello probabile | Primo comando |
|---------|-------------------|---------------|
| Nessun link | 1 | `ethtool eth0` / `Get-NetAdapter` |
| Indirizzo `169.254.x.x` (APIPA) | 1 | `journalctl -u NetworkManager` / `ipconfig /all` |
| Il ping fallisce ma la voce ARP c'è | 2 / 6 | `ip neigh show 192.168.1.47` |
| Nessuno schema, va e poi non va | 2 | `arping -I eth0 -c3 192.168.1.47` |
| Gateway irraggiungibile | 3 | `ip route` + `ping 192.168.1.1` |
| Raggiunge mezza LAN | 3 | `ip -br addr show eth0` (controlla il prefisso) |
| Funziona per IP, fallisce per nome | 4 | `dig @192.168.1.5 server.example.internal` |
| Fallisce circa una volta su due, per nome | 4 | Interroga `192.168.1.5` e `192.168.1.6` separatamente |
| **Connection refused** | 5 | `ss -lntp` sulla destinazione |
| **Timeout** | 6 | `Get-NetConnectionProfile` / `nft list ruleset` |
| Si collega, poi si blocca | MTU | `ping -M do -s 1472 203.0.113.10` |
| Lentezza intermittente | 1 / 3 | `ethtool eth0`, poi `mtr -rwc 100` |
| Il browser va, gli aggiornamenti falliscono | 6 | `netsh winhttp show proxy` |

## 🔀 Equivalenze dei comandi Linux ↔ Windows

Perché finisci a lavorare su entrambi, di solito nella stessa ora.

| Compito | Linux | Windows |
|---------|-------|---------|
| Indirizzi | `ip -br addr` | `ipconfig /all` · `Get-NetIPConfiguration` |
| Interfacce | `ip -br link` · `ethtool eth0` | `Get-NetAdapter` |
| Tabella di routing | `ip route` | `route print` · `Get-NetRoute` |
| Tabella ARP | `ip neigh` | `arp -a` · `Get-NetNeighbor` |
| Socket in ascolto | `ss -tulpn` | `netstat -ano` · `Get-NetTCPConnection` |
| Query DNS | `dig`, `resolvectl query` | `nslookup` · `Resolve-DnsName` |
| Svuotare la cache DNS | `resolvectl flush-caches` | `ipconfig /flushdns` |
| Tracciare il percorso | `traceroute` · `mtr` | `tracert -d` · `pathping` |
| Provare una porta TCP | `nc -zv host port` | `Test-NetConnection host -Port n` |
| Cattura dei pacchetti | `tcpdump -i eth0 -nn` | `pktmon` (→ `etl2pcap`) |
| Regole del firewall | `nft list ruleset` · `ufw status` | `netsh advfirewall show allprofiles` |
| Proxy di sistema | `env \| grep -i proxy` | `netsh winhttp show proxy` |

## ✅ La checklist da riusare

1. **Link** - `ethtool` / `Get-NetAdapter`. `Link detected: yes`? APIPA vuol dire fermati:
   sistema il DHCP.
2. **Locale** - `ip neigh` / `arp -a`, **non** il ping. Il silenzio del ping non è una prova
   di morte.
3. **Gateway** - ping a `192.168.1.1` prima di qualunque cosa di esterno. Confronta la
   netmask con quella dei vicini.
4. **DNS** - solo dopo aver dimostrato l'IP, e interroga **ogni** resolver a mano.
   `resolvectl status` per vedere quale viene usato davvero.
5. **Porta** - `ss -tulpn` sulla destinazione, `Test-NetConnection` dal client. **Rifiuto**
   (servizio) e **timeout** (firewall) sono diagnosi opposte.
6. **Firewall e proxy** - il **profilo** prima delle regole; il proxy WinHTTP, non quello
   del browser.
7. **Cattura** - `tcpdump -nn`. SYN ritrasmessi = scartato; SYN e poi RST = rifiutato.
   Cattura da entrambi i lati, se puoi.
8. **Si blocca invece di fallire?** Sospetta l'MTU e prova con `ping -M do` prima di
   qualunque altra cosa.
9. **Scrivi quale livello era, alla fine.** Dopo qualche mese quell'elenco ti dice dove si
   rompe davvero la tua rete, che raramente è dove pensi.

---

**Vedi anche:**
- [Riparazione e manutenzione di Windows](/2025/10/windows-system-repair-and-maintenance/)
- [Analisi del traffico di rete con tcpdump](/2025/10/network-traffic-analysis-with-tcpdump-debian/) - il livello 7, in profondità
- [Analisi del traffico di rete con Wireshark](/2025/10/network-traffic-analysis-with-wireshark-debian/)

---

*Ogni livello che salti è un livello a cui finirai per dare la colpa.*
