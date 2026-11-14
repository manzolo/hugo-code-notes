---
title: "Guida all'installazione e configurazione di un server OpenVPN (Debian/Ubuntu)"
url: "2025/10/openvpn-server-installation-and-configuration-guide-debian/ubuntu/"
date: 2025-10-04T11:00:00+02:00
lastmod: 2025-10-04T11:00:00+02:00
draft: false
author: "Manzolo"
tags: ["openvpn", "vpn", "server", "security", "encryption", "tutorial"]
categories: ["Networking & Security"]
series: ["Networking Fundamentals"]
weight: 8
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Guida all'installazione e configurazione di un server OpenVPN (Debian/Ubuntu)

## Introduzione

Un server OpenVPN ti dà un accesso remoto sicuro alla tua rete o alle tue risorse. Questa guida spiega come installare un server OpenVPN su Debian/Ubuntu, generare certificati e chiavi, configurare il server, creare le configurazioni di utenti e client e collegarsi da un client. Comprende i passaggi per creare più utenti e provare le connessioni: è adatta a server di casa, piccole aziende o a chi ha bisogno di un accesso remoto sicuro.

## Cos'è un server OpenVPN?

Un server OpenVPN crea tunnel cifrati con cui i client si collegano in sicurezza attraverso internet. Le caratteristiche principali:
- **Sicurezza**: usa certificati e TLS per autenticazione e cifratura.
- **Flessibilità**: gestisce più client, ognuno con la propria configurazione.
- **Routing**: invia ai client le rotte per raggiungere le reti locali.
- **Casi d'uso**: accesso remoto sicuro, collegamenti site-to-site, aggirare restrizioni.

## Prerequisiti

- **Debian/Ubuntu**: versione 20.04+ (consigliata l'edizione server).
- **Accesso root**: usa `sudo` per installazione e configurazione.
- **IP pubblico o dominio**: un IP pubblico statico o un DNS dinamico per le connessioni dei client (porta 1194 UDP inoltrata).
- **Strumenti**: `openvpn`, `easy-rsa` per generare i certificati.
- **Accesso a internet**: serve per installare i pacchetti.
- **Firewall**: apri la porta 1194/UDP.

Controlla il sistema:
```bash
uname -a  # Check kernel and distro
ip addr show  # Check IP addresses
```

## Avviso importante: sicurezza e configurazione

{{< callout type="warning" >}}
**Attenzione**: un server VPN configurato male può esporre la tua rete a rischi. Usa passphrase robuste, tieni privati i certificati e limita gli accessi con il firewall. Prova in locale prima di esporlo su internet. Fai un backup delle configurazioni (per esempio `/etc/openvpn/`) prima di ogni modifica.
{{< /callout >}}

## Come si usa un server OpenVPN

### 1. Installare OpenVPN ed Easy-RSA
Installa OpenVPN ed Easy-RSA (per generare i certificati):
```bash
sudo apt update
sudo apt install openvpn easy-rsa
```

Verifica l'installazione:
```bash
openvpn --version
ls /usr/share/easy-rsa/
```

**Nota**: su Debian/Ubuntu `easyrsa` non è nel `PATH`: sta in `/usr/share/easy-rsa/` e si lancia come `./easyrsa` dalla cartella che `make-cadir` crea al passo successivo.

### 2. Preparare Easy-RSA per i certificati
Easy-RSA genera la Certificate Authority (CA) e le chiavi.

1. Copia i file di Easy-RSA:
   ```bash
   make-cadir ~/openvpn-ca
   cd ~/openvpn-ca
   ```

2. Modifica le variabili (per esempio il file `vars`):
   ```bash
   nano vars
   ```
   Imposta i parametri (per esempio `set_var EASYRSA_REQ_COUNTRY "US"`, `set_var EASYRSA_KEY_SIZE 2048`).

3. Crea la CA:
   ```bash
   ./easyrsa init-pki
   ./easyrsa build-ca
   ```
   Inserisci una passphrase per la CA e conferma i dati.

4. Genera il certificato del server:
   ```bash
   ./easyrsa gen-req server nopass
   ./easyrsa sign-req server server
   ```

5. Genera i parametri Diffie-Hellman:
   ```bash
   ./easyrsa gen-dh
   ```

6. Genera la chiave TLS per la protezione HMAC:
   ```bash
   openvpn --genkey secret pki/ta.key
   ```

### 3. Configurare il server OpenVPN
Crea e modifica il file di configurazione del server:
```bash
sudo cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf /etc/openvpn/server.conf
sudo nano /etc/openvpn/server.conf
```

Modifiche principali:
- `port 1194`
- `proto udp`
- `dev tun`
- `ca /etc/openvpn/ca.crt`
- `cert /etc/openvpn/server.crt`
- `key /etc/openvpn/server.key`
- `dh /etc/openvpn/dh.pem`
- `server 10.8.0.0 255.255.255.0` (sottorete della VPN)
- `push "redirect-gateway def1 bypass-dhcp"` (instrada tutto il traffico attraverso la VPN)
- `push "dhcp-option DNS 8.8.8.8"`
- `tls-auth /etc/openvpn/ta.key 0`
- `user nobody`
- `group nogroup`

**Nota** (OpenVPN 2.6, Ubuntu 24.04): il file di esempio non ha la riga `dh` e ha `user`/`group` commentate. Senza una riga `dh` il server si rifiuta di partire con `Options error: You must define DH file (--dh)`, quindi aggiungila a mano. Le versioni più vecchie distribuivano l'esempio compresso con gzip come `examples/server.conf.gz`.

Copia le chiavi in `/etc/openvpn/`:
```bash
sudo cp ~/openvpn-ca/pki/ca.crt /etc/openvpn/
sudo cp ~/openvpn-ca/pki/issued/server.crt /etc/openvpn/
sudo cp ~/openvpn-ca/pki/private/server.key /etc/openvpn/
sudo cp ~/openvpn-ca/pki/dh.pem /etc/openvpn/
sudo cp ~/openvpn-ca/pki/ta.key /etc/openvpn/
```

### 4. Avviare e abilitare il servizio OpenVPN
Avvia il server OpenVPN:
```bash
sudo systemctl start openvpn@server
sudo systemctl enable openvpn@server
```

Controlla lo stato:
```bash
sudo systemctl status openvpn@server
```
![Stato del server OpenVPN: active (running), Initialization Sequence Completed](/images/openvpn-server-status.png "Output di sudo systemctl status openvpn@server")
Esempio di output:
```
● openvpn@server.service - OpenVPN connection to server
     Loaded: loaded (/lib/systemd/system/openvpn@.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2025-10-04 14:00:00 UTC; 1min ago
```

### 5. Configurare il firewall
Lascia passare il traffico VPN attraverso il firewall:
- Installa UFW (se non c'è già):
  ```bash
  sudo apt install ufw
  ```
- Configura le regole:
  ```bash
  sudo ufw allow 1194/udp
  sudo ufw allow OpenSSH
  sudo ufw enable
  ```

### 5.1 Far navigare i client: inoltro IP e NAT
Con `push "redirect-gateway def1 bypass-dhcp"` ogni client manda **tutto** il suo traffico nel tunnel. Il server deve quindi inoltrarlo e nasconderlo dietro il proprio indirizzo, altrimenti i client si collegano senza problemi e poi non navigano: il tunnel è su, `ping 10.8.0.1` risponde, e oltre il server non risponde più niente.

Provato su Ubuntu 24.04 con OpenVPN 2.6: senza le tre modifiche qui sotto un client collegato perde il 100% dei ping verso l'esterno; con quelle, naviga.

1. Trova l'interfaccia di uscita del server (il nome dopo `dev`: `eth0`, `ens3`, `enp2s0`...):
   ```bash
ip route show default
```

2. Abilita l'inoltro IP, in modo permanente:
   ```bash
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-openvpn.conf
sudo sysctl --system
```

3. Permetti a UFW di inoltrare i pacchetti. In `/etc/default/ufw` imposta `DEFAULT_FORWARD_POLICY="ACCEPT"`:
   ```bash
sudo nano /etc/default/ufw
```

4. Aggiungi la regola di NAT **in cima** a `/etc/ufw/before.rules`, prima della sezione `*filter`, mettendo la tua interfaccia al posto di `eth0`:
   ```bash
sudo nano /etc/ufw/before.rules
```
   ```
# START OPENVPN RULES
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
COMMIT
# END OPENVPN RULES
```

5. Ricarica UFW e controlla:
   ```bash
sudo ufw disable
sudo ufw enable
```
   ```bash
sysctl net.ipv4.ip_forward
sudo iptables -t nat -S POSTROUTING | grep 10.8.0.0
```
   Atteso: `net.ipv4.ip_forward = 1` e una riga `MASQUERADE` per `10.8.0.0/24`.

### 6. Creare utenti/client
Genera i certificati e le configurazioni dei client.

1. Per un nuovo utente (per esempio `client1`):
   ```bash
   cd ~/openvpn-ca
   ./easyrsa gen-req client1 nopass
   ./easyrsa sign-req client client1
   ```

2. Crea il file `.ovpn` del client:
   ```bash
   cd ~
   mkdir client-configs
   cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf ./client-configs/base.conf
   nano ./client-configs/base.conf
   ```
   Aggiorna:
   - `remote your-server-ip 1194`
   - `proto udp`
   - `user nobody`
   - `group nogroup`
   - `ca ca.crt`
   - `cert client.crt`
   - `key client.key`
   - `tls-auth ta.key 1`

3. Genera il file `.ovpn` del client:
   Crea uno script che genera le configurazioni dei client:
   ```bash
   nano ./client-configs/make_config.sh
   ```
   Contenuto:
   ```bash
   #!/bin/bash
   KEY_DIR=~/openvpn-ca/pki
   OUTPUT_DIR=~/client-configs/files
   BASE_CONFIG=~/client-configs/base.conf

   mkdir -p ${OUTPUT_DIR}
   chmod 700 ${OUTPUT_DIR}

   cat ${BASE_CONFIG} \
       <(echo -e '<ca>') \
       ${KEY_DIR}/ca.crt \
       <(echo -e '</ca>\n<cert>') \
       ${KEY_DIR}/issued/${1}.crt \
       <(echo -e '</cert>\n<key>') \
       ${KEY_DIR}/private/${1}.key \
       <(echo -e '</key>\n<tls-auth>') \
       ${KEY_DIR}/ta.key \
       <(echo -e '</tls-auth>') \
       > ${OUTPUT_DIR}/${1}.ovpn
   ```

   Rendilo eseguibile:
   ```bash
   chmod 700 ./client-configs/make_config.sh
   ```

4. Genera la configurazione del client:
   ```bash
   cd ./client-configs
   ./make_config.sh client1
   ```
   Il file `client1.ovpn` ora è in `~/client-configs/files/`. Fallo avere al client in modo sicuro.

5. Ripeti per gli altri utenti (per esempio `client2`):
   ```bash
   cd ~/openvpn-ca
   ./easyrsa gen-req client2 nopass
   ./easyrsa sign-req client client2
   cd ~/client-configs
   ./make_config.sh client2
   ```

### 7. Collegarsi da un client
Su un client Debian/Ubuntu:
1. Installa OpenVPN:
   ```bash
   sudo apt install openvpn
   ```

2. Copia il file `.ovpn` dal server (per esempio con SCP):
   ```bash
   mkdir -p ~/vpn
   scp user@server-ip:~/client-configs/files/client1.ovpn ~/vpn/client1.ovpn
   ```

3. Collegati:
   ```bash
   sudo openvpn --config ~/vpn/client1.ovpn
   ```
   Inserisci la passphrase, se richiesta.

4. Verifica:
   ```bash
   curl ifconfig.me  # Shows server IP
   ```

## Esempi

### Esempio 1: installare il server OpenVPN
Installa OpenVPN ed Easy-RSA:
```bash
sudo apt update
sudo apt install openvpn easy-rsa
openvpn --version
```

**Output**:
```
OpenVPN 2.5.9 x86_64-pc-linux-gnu [SSL (OpenSSL)] [LZO] [LZ4] ...
```

### Esempio 2: generare la CA e i certificati del server
Prepara Easy-RSA e genera i certificati:
```bash
make-cadir ~/openvpn-ca
cd ~/openvpn-ca
nano vars  # Set parameters
./easyrsa init-pki
./easyrsa build-ca
./easyrsa gen-req server nopass
./easyrsa sign-req server server
./easyrsa gen-dh
openvpn --genkey secret pki/ta.key
```

**Output** (durante `build-ca`):
```
Enter PEM pass phrase: [enter passphrase]
Common Name (eg: your user, host, or server name) [Easy-RSA CA]: [press Enter]
CA creation complete and you may now import and sign cert requests.
```

### Esempio 3: configurare e avviare il server OpenVPN
Configura il server e avvia il servizio:
```bash
sudo cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf /etc/openvpn/server.conf
sudo nano /etc/openvpn/server.conf  # Edit as needed
sudo cp ~/openvpn-ca/pki/ca.crt /etc/openvpn/
sudo cp ~/openvpn-ca/pki/issued/server.crt /etc/openvpn/
sudo cp ~/openvpn-ca/pki/private/server.key /etc/openvpn/
sudo cp ~/openvpn-ca/pki/dh.pem /etc/openvpn/
sudo cp ~/openvpn-ca/pki/ta.key /etc/openvpn/
sudo systemctl start openvpn@server
sudo systemctl enable openvpn@server
sudo systemctl status openvpn@server
```

**Output** (stato):
```
● openvpn@server.service - OpenVPN connection to server
     Loaded: loaded (/lib/systemd/system/openvpn@.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2025-10-04 14:00:00 UTC; 1min ago
```

### Esempio 4: creare un utente/client
Genera la configurazione di un client:
```bash
cd ~/openvpn-ca
./easyrsa gen-req client1 nopass
./easyrsa sign-req client client1
cd ~
mkdir client-configs
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf ./client-configs/base.conf
nano ./client-configs/base.conf  # Edit as needed
nano ./client-configs/make_config.sh  # Create the script as shown in the guide
chmod 700 ./client-configs/make_config.sh
cd ./client-configs
./make_config.sh client1
ls ~/client-configs/files/client1.ovpn
```

**Output**:
```
~/client-configs/files/client1.ovpn
```

### Esempio 5: collegarsi da un client
Sul client:
```bash
sudo apt install openvpn
mkdir -p ~/vpn
scp user@server-ip:~/client-configs/files/client1.ovpn ~/vpn/client1.ovpn
sudo openvpn --config ~/vpn/client1.ovpn
```

**Output**:
```
2025-10-04 14:00:01 Initialization Sequence Completed
2025-10-04 14:00:01 [Server] Peer Connection Initiated with [AF_INET]192.168.1.10:1194
```

## Varianti

### WireGuard come VPN alternativa
Installa e configura WireGuard per una VPN più veloce e più semplice:
```bash
sudo apt install wireguard
wg genkey | tee private.key | wg pubkey > public.key
nano /etc/wireguard/wg0.conf  # Configure interface
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0
```

### VPN con più utenti
Per più utenti, genera altri client:
```bash
cd ~/openvpn-ca
./easyrsa gen-req client2 nopass
./easyrsa sign-req client client2
cd ~/client-configs
./make_config.sh client2
```

## I comandi, uno per uno
- **apt install openvpn easy-rsa**: installa OpenVPN e gli strumenti per i certificati.
- **easyrsa build-ca**: genera la CA.
- **easyrsa gen-req/sign-req**: genera e firma i certificati.
- **openvpn --genkey secret**: genera la chiave TLS.
- **systemctl start/enable openvpn@server**: gestisce il servizio del server.
- **ufw allow**: configura le regole del firewall.
- **openvpn --config <file>**: collega il client.

## Casi d'uso
- **Accesso remoto sicuro**: collegati alla rete di casa da qualunque posto.
- **Privacy**: cifra il traffico sulle Wi-Fi pubbliche.
- **VPN site-to-site**: collega più reti in modo sicuro.
- **Aggirare restrizioni**: da usare con provider commerciali per i contenuti con blocco geografico.

## Consigli pratici
- **Passphrase robuste**: usa passphrase complesse per la CA e le chiavi dei client.
- **Regole del firewall**: limita l'accesso alla porta 1194/UDP agli IP fidati.
- **Revoca dei client**: revoca un client con `./easyrsa revoke client1` e aggiorna la CRL in `server.conf`.
- **Push del DNS**: aggiungi `push "dhcp-option DNS 8.8.8.8"` in `server.conf` per il DNS dei client.
- **Tieni d'occhio i log**: usa `journalctl -u openvpn@server` per i log del server.

## Risoluzione dei problemi
- **Connessione rifiutata**: controlla il firewall (`ufw status`), l'inoltro della porta e l'IP del server nel file `.ovpn`.
- **Errori di certificato**: verifica la passphrase della CA e i percorsi delle chiavi in `server.conf`.
- **Niente internet dopo il collegamento**: il tunnel è su ma oltre `10.8.0.1` non risponde niente: il server non inoltra o non fa NAT. Vedi il passo 5.1 (inoltro IP, `DEFAULT_FORWARD_POLICY`, regola `MASQUERADE`). Controlla anche che in `server.conf` ci sia `push "redirect-gateway def1 bypass-dhcp"`.
- **Problemi di permessi**: assicurati che le chiavi abbiano `chmod 600` e che il proprietario sia root.
- **Guarda i log**: i log del server stanno in `/var/log/syslog` o in `journalctl -u openvpn@server`.
- **Il client non si collega**: usa `openvpn --config client1.ovpn --verb 4` per avere log dettagliati.

## Risorse
- [Documentazione di OpenVPN](https://openvpn.net/community-resources/)
- [Guida a OpenVPN di Ubuntu](https://ubuntu.com/server/docs/virtual-private-networks-openvpn)
- [Easy-RSA su GitHub](https://github.com/OpenVPN/easy-rsa)

---

*Metti in piedi un server OpenVPN su Debian/Ubuntu per l'accesso remoto sicuro e i collegamenti dei client!*