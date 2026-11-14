---
title: "Guida ad APT e DPKG (Debian/Ubuntu)"
url: "2025/10/apt-and-dpkg-guide-debian/ubuntu/"
date: 2025-10-04T12:00:00+02:00
lastmod: 2025-10-04T12:50:00+02:00
draft: false
author: "Manzolo"
tags: ["apt", "dpkg", "debian", "ubuntu", "package-management"]
categories: ["Package Management"]
series: ["System Administration Basics"]
weight: 4
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Guida ad APT e DPKG (Debian/Ubuntu)

## Introduzione

`apt` e `dpkg` sono gli strumenti fondamentali per gestire i pacchetti sui sistemi Debian e Ubuntu. `apt update` aggiorna l'indice dei pacchetti dai repository configurati, così hai sempre le informazioni più recenti. `dpkg` gestisce i pacchetti `.deb`: permette di installarli direttamente, rimuoverli, interrogarli o scoprire a quale pacchetto appartiene un file. Questa guida spiega come usare `apt update` e `dpkg`, con casi d'uso come l'aggiornamento del sistema, l'installazione manuale di un `.deb`, la ricerca dei pacchetti, la ricerca del pacchetto proprietario di un file, l'aggiunta e la rimozione di repository esterni, e come capire quale repository fornisce un pacchetto.

## Cosa sono APT e DPKG?

- **APT (Advanced Package Tool)**: un gestore di pacchetti di alto livello che semplifica installazione, aggiornamento, ricerca e rimozione del software. `apt update` scarica gli elenchi dei pacchetti, mentre comandi come `apt install`, `apt upgrade` o `apt search` si occupano delle operazioni sui pacchetti.
- **DPKG**: uno strumento di basso livello per gestire i pacchetti `.deb`, usato per installare file `.deb` locali, interrogare i pacchetti installati, rimuoverli o scoprire a chi appartiene un file.

Insieme offrono una gestione dei pacchetti solida per i sistemi Debian/Ubuntu.

## Prerequisiti

- **Debian/Ubuntu**: versione 20.04+.
- **Accesso root**: usa `sudo` per la maggior parte dei comandi.
- **Accesso a Internet**: necessario per `apt update` e per le operazioni sui repository.
- **Strumenti**: `apt`, `dpkg` e `gnupg` sono preinstallati su Debian/Ubuntu.

Verifica gli strumenti:
```bash
apt --version
dpkg --version
gpg --version
```

## Avviso importante: fai un backup prima di modificare

{{< callout type="warning" >}}
**Attenzione**: aggiornamenti, installazioni di pacchetti o modifiche ai repository possono sovrascrivere le configurazioni o creare problemi al sistema. Fai un backup dei dati e delle configurazioni importanti (ad esempio `/etc/`) prima di procedere.
{{< /callout >}}

## Come usare APT update e DPKG

### 1. Aggiornare gli elenchi dei pacchetti con `apt update`
`apt update` aggiorna l'indice dei pacchetti dai repository elencati in `/etc/apt/sources.list` e `/etc/apt/sources.list.d/`. Lancialo prima di installare o aggiornare pacchetti.

```bash
sudo apt update
```
![Output di APT update con l'aggiornamento dei repository](/images/apt-update-output.png "Output di sudo apt update")
Output di esempio:
```
Hit:1 http://deb.debian.org/debian bullseye InRelease
Get:2 http://deb.debian.org/debian-security bullseye-security InRelease [48.4 kB]
Fetched 48.4 kB in 1s (45.2 kB/s)
Reading package lists... Done
Building dependency tree... Done
All packages are up to date.
```

**Nota**: se vedi errori (ad esempio 404 Not Found), controlla che in `/etc/apt/sources.list` o `/etc/apt/sources.list.d/` non ci siano URL non validi.

### 2. Aggiungere un repository esterno
Per installare software che non sta nei repository predefiniti (ad esempio Docker), aggiungi un repository di terze parti in `/etc/apt/sources.list` o `/etc/apt/sources.list.d/`. Spesso, per sicurezza, va aggiunta anche una chiave GPG.

Esempio (aggiungere il repository di Docker):
```bash
# Add Docker's GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list

# Update package lists
sudo apt update
```

Verifica:
```bash
cat /etc/apt/sources.list.d/docker.list
```

**Nota**: verifica sempre la chiave GPG e l'URL del repository, per non correre rischi di sicurezza.

### 3. Rimuovere un repository esterno
Per rimuovere un repository, cancella la sua riga da `/etc/apt/sources.list` oppure il suo file in `/etc/apt/sources.list.d/` e, se vuoi, rimuovi anche la chiave GPG.

Esempio (rimuovere il repository di Docker):
```bash
# Remove repository file
sudo rm /etc/apt/sources.list.d/docker.list

# Remove GPG key (optional)
sudo rm /usr/share/keyrings/docker-archive-keyring.gpg

# Update package lists
sudo apt update
```

Verifica:
```bash
ls /etc/apt/sources.list.d/
```

**Nota**: se invece il repository è elencato in `/etc/apt/sources.list`, modifica quel file con `sudo nano`.

### 4. Capire quale repository fornisce un pacchetto
Usa `apt-cache policy` per scoprire quale repository fornisce un pacchetto e quali versioni sono disponibili.

```bash
apt-cache policy <package-name>
```
Esempio (controllare `docker-ce`):
```bash
apt-cache policy docker-ce
```
Output di esempio:
```
docker-ce:
  Installed: (none)
  Candidate: 5:24.0.7-1~debian.11~bullseye
  Version table:
     5:24.0.7-1~debian.11~bullseye 500
        500 https://download.docker.com/linux/debian bullseye/stable amd64 Packages
```

**Nota**: lancia prima `sudo apt update`, così la cache dei pacchetti è aggiornata.

### 5. Cercare un pacchetto
Usa `apt search` o `apt-cache search` per trovare i pacchetti per nome o descrizione.

- **Con `apt search`** (più leggibile, ordinato):
  ```bash
  apt search <keyword>
  ```
  Esempio (cercare `vim`):
  ```bash
  apt search vim
  ```
  Output di esempio:
  ```
  Sorting... Done
  Full Text Search... Done
  vim/bullseye 2:8.2.2434-3+deb11u1 amd64
    Vi IMproved - enhanced vi editor
  vim-tiny/bullseye 2:8.2.2434-3+deb11u1 amd64
    Vi IMproved - enhanced vi editor (tiny version)
  ```

- **Con `apt-cache search`** (dettagliato, non ordinato):
  ```bash
  apt-cache search <keyword>
  ```
  Esempio (cercare `nginx`):
  ```bash
  apt-cache search nginx
  ```
  Output di esempio:
  ```
  nginx - small, powerful, scalable web/proxy server
  nginx-common - small, powerful, scalable web/proxy server - common files
  ```

**Nota**: lancia prima `sudo apt update`.

### 6. Trovare il pacchetto a cui appartiene un file
Usa `dpkg -S` per scoprire quale pacchetto ha installato un file.

```bash
dpkg -S <file-path>
```
Esempio (trovare il pacchetto di `/usr/bin/vim`):
```bash
dpkg -S /usr/bin/vim
```
Output di esempio:
```
vim: /usr/bin/vim
```

**Nota**: se il file non viene trovato, può darsi che non appartenga a nessun pacchetto.

### 7. Aggiornare i pacchetti installati
Porta i pacchetti installati all'ultima versione:
- **Aggiornamento sicuro** (evita di rimuovere pacchetti):
  ```bash
  sudo apt upgrade
  ```
- **Aggiornamento completo** (può rimuovere pacchetti):
  ```bash
  sudo apt full-upgrade
  ```

Esempio:
```bash
sudo apt update
sudo apt upgrade
```

### 8. Installare un pacchetto con `apt`
Installa un pacchetto dai repository:
```bash
sudo apt install <package-name>
```
Esempio (installare `vim`):
```bash
sudo apt install vim
```

### 9. Installare un file `.deb` locale con `dpkg`
Installa un file `.deb` scaricato:
```bash
sudo dpkg -i ./package.deb
```
Esempio (installare `google-chrome-stable_current_amd64.deb`):
```bash
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
```

**Nota**: se mancano delle dipendenze, sistema con:
```bash
sudo apt install -f
```

### 10. Interrogare i pacchetti installati con `dpkg`
Controlla se un pacchetto è installato o leggine i dettagli:
```bash
dpkg -l | grep <package-name>
dpkg -s <package-name>
```
Esempio (controllare `vim`):
```bash
dpkg -l | grep vim
dpkg -s vim
```

Elenca i file installati da un pacchetto:
```bash
dpkg -L <package-name>
```
Esempio:
```bash
dpkg -L vim
```

### 11. Rimuovere i pacchetti, con o senza configurazione, con `dpkg`
- **Remove** (tiene i file di configurazione):
  ```bash
  sudo dpkg -r <package-name>
  ```
- **Purge** (rimuove anche i file di configurazione):
  ```bash
  sudo dpkg --purge <package-name>
  ```
Esempio (rimuovere `vim`):
```bash
sudo dpkg -r vim
```

### 12. Riparare le dipendenze rotte
Se `dpkg` o `apt` segnalano dipendenze rotte:
```bash
sudo apt install -f
```

## Esempi

### Esempio 1: aggiornare gli elenchi e il sistema
Aggiorna gli elenchi dei pacchetti e poi i pacchetti:
```bash
# Update package lists
sudo apt update

# Upgrade packages
sudo apt upgrade
```

**Output**:
```
Reading package lists... Done
Building dependency tree... Done
Calculating upgrade... Done
0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
```

### Esempio 2: aggiungere un repository esterno
Aggiungi il repository di Docker:
```bash
# Add GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list

# Update package lists
sudo apt update
```

**Output** (dopo `apt update`):
```
Get:1 https://download.docker.com/linux/debian bullseye/stable amd64 Packages [24.8 kB]
Fetched 24.8 kB in 1s (30.2 kB/s)
Reading package lists... Done
```

### Esempio 3: rimuovere un repository esterno
Rimuovi il repository di Docker:
```bash
# Remove repository file
sudo rm /etc/apt/sources.list.d/docker.list

# Remove GPG key
sudo rm /usr/share/keyrings/docker-archive-keyring.gpg

# Update package lists
sudo apt update
```

**Output**:
```
Reading package lists... Done
Building dependency tree... Done
All packages are up to date.
```

### Esempio 4: capire quale repository fornisce un pacchetto
Controlla il repository di `docker-ce`:
```bash
apt-cache policy docker-ce
```

**Output**:
```
docker-ce:
  Installed: (none)
  Candidate: 5:24.0.7-1~debian.11~bullseye
  Version table:
     5:24.0.7-1~debian.11~bullseye 500
        500 https://download.docker.com/linux/debian bullseye/stable amd64 Packages
```

### Esempio 5: cercare un pacchetto
Cerca un pacchetto:
```bash
apt search vim
```

**Output**:
```
Sorting... Done
Full Text Search... Done
vim/bullseye 2:8.2.2434-3+deb11u1 amd64
  Vi IMproved - enhanced vi editor
vim-tiny/bullseye 2:8.2.2434-3+deb11u1 amd64
  Vi IMproved - enhanced vi editor (tiny version)
```

### Esempio 6: trovare a quale pacchetto appartiene un file
Individua il pacchetto di un file:
```bash
dpkg -S /usr/bin/vim
```

**Output**:
```
vim: /usr/bin/vim
```

### Esempio 7: installare un file `.deb` locale
Installa un file `.deb` e sistema le dipendenze:
```bash
# Download a .deb file
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

# Install with dpkg
sudo dpkg -i google-chrome-stable_current_amd64.deb

# Fix dependencies
sudo apt install -f
```

**Output** (se mancano delle dipendenze):
```
dpkg: dependency problems prevent configuration of google-chrome-stable:
 google-chrome-stable depends on libatk1.0-0 (>= 2.32.0); however:
  Package libatk1.0-0 is not installed.
...
sudo apt install -f
...
Setting up libatk1.0-0 (2.36.0-2) ...
Setting up google-chrome-stable (114.0.5735.198-1) ...
```

### Esempio 8: interrogare e rimuovere un pacchetto
Controlla un pacchetto e rimuovilo:
```bash
# Check package status
dpkg -l | grep vim
dpkg -s vim

# List package files
dpkg -L vim

# Remove package
sudo dpkg -r vim
```

**Output** (interrogazione):
```
ii  vim  2:8.2.2434-3+deb11u1  amd64  Vi IMproved - enhanced vi editor
```

### Esempio 9: riparare le dipendenze rotte
Se `dpkg -i` fallisce:
```bash
sudo dpkg -i package.deb
# Errors about missing dependencies
sudo apt install -f
```

## Varianti

### Aggiungere e usare un repository esterno
Aggiungi un repository per installare un software specifico (ad esempio Docker):
```bash
# Add GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list

# Update and install
sudo apt update
sudo apt install docker-ce
```

### Rimuovere un repository esterno
Rimuovi un repository e fai pulizia:
```bash
# Remove repository file
sudo rm /etc/apt/sources.list.d/docker.list

# Remove GPG key
sudo rm /usr/share/keyrings/docker-archive-keyring.gpg

# Update package lists
sudo apt update
```

### Usare `dpkg` per riconfigurare i pacchetti
Riconfigura le impostazioni di un pacchetto:
```bash
sudo dpkg-reconfigure <package-name>
```
Esempio (riconfigurare `tzdata`):
```bash
sudo dpkg-reconfigure tzdata
```

## I comandi in breve
- **apt update**: aggiorna l'indice dei pacchetti dai repository.
- **apt search**: cerca i pacchetti per nome o descrizione.
- **apt-cache search**: ricerca dettagliata dei pacchetti (non ordinata).
- **apt-cache policy**: mostra quale repository fornisce un pacchetto.
- **apt upgrade/full-upgrade**: aggiorna i pacchetti installati.
- **apt install**: installa pacchetti o sistema le dipendenze.
- **dpkg -i**: installa un file `.deb` locale.
- **dpkg -S**: trova il pacchetto a cui appartiene un file.
- **dpkg -r/--purge**: rimuove i pacchetti, con o senza i file di configurazione.
- **dpkg -l/-s/-L**: interroga i pacchetti installati o i loro file.
- **apt install -f**: risolve le dipendenze rotte.

## Casi d'uso
- **Manutenzione del sistema**: un `apt update && apt upgrade` regolare per gli aggiornamenti.
- **Software particolare**: aggiungere repository esterni per software come Docker.
- **Scoprire i pacchetti**: usare `apt search` o `apt-cache policy` per trovare i pacchetti e la loro provenienza.
- **Proprietà dei file**: usare `dpkg -S` per risalire all'origine di un file.
- **Installazione manuale**: usare `dpkg -i` per i file `.deb` che non stanno nei repository.
- **Debug**: interrogare i pacchetti con `dpkg -l` o `dpkg -s`.

## Consigli da esperti
- **Verifica le sorgenti dei repository**: quando aggiungi un repository, controlla chiavi GPG e URL, per sicurezza.
- **Pulizia della cache**: libera spazio su disco con `sudo apt autoclean` e `sudo apt autoremove`.
- **Prova a vuoto**: usa `apt upgrade --dry-run` per vedere in anteprima le modifiche.
- **Opzioni di forzatura di dpkg**: usa `dpkg -i --force-depends` con cautela quando mancano delle dipendenze.
- **Backup delle sorgenti APT**: salva `/etc/apt/sources.list` e `/etc/apt/sources.list.d/` prima di modificarli.

## Risoluzione dei problemi
- **Errori 404 in apt update**: controlla `/etc/apt/sources.list` o `/etc/apt/sources.list.d/`:
  ```bash
  sudo nano /etc/apt/sources.list
  ls /etc/apt/sources.list.d/
  sudo apt update
  ```
- **Pacchetto non trovato con apt search**: lancia `sudo apt update` e verifica i repository.
- **apt-cache policy non mostra nessun repository**: assicurati che il pacchetto sia disponibile in un repository configurato.
- **dpkg -S non restituisce niente**: può darsi che il file non appartenga a nessun pacchetto.
- **Dipendenze rotte**: lancia `sudo apt install -f` dopo `dpkg -i`.
- **Conflitti tra pacchetti**: rimuovi i pacchetti in conflitto con `sudo dpkg --purge <package-name>`.
- **Problemi di permessi**: usa `sudo` con i comandi `apt` e `dpkg`.
- **Controlla i log**: guarda `/var/log/dpkg.log` o `/var/log/apt/history.log`.

## Risorse
- [Manuale di APT di Debian](https://www.debian.org/doc/manuals/debian-reference/ch02.en.html)
- [Gestione dei pacchetti su Ubuntu](https://ubuntu.com/server/docs/package-management)
- [Pagina man di DPKG](https://man7.org/linux/man-pages/man1/dpkg.1.html)

---

*Gestisci i pacchetti in modo efficiente con `apt update` e `dpkg`, per un sistema Debian/Ubuntu solido!*
