---
title: "GPG Bash Playground"
url: "2025/09/gpg-bash-playground/"
date: 2025-09-28T00:00:00+02:00
lastmod: 2025-09-28T00:00:00+02:00
draft: false
author: "Manzolo"
tags: ["gpg", "encryption", "security", "pgp", "keys"]
categories: ["Networking & Security"]
series: ["System Administration Basics"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Guida a GPG Bash Playground

## Introduzione

GPG Bash Playground è uno script Bash didattico che mostra l'uso pratico di GPG (GNU Privacy Guard): generazione delle chiavi, scambio delle chiavi pubbliche, cifratura e decifratura. Lo script simula uno scenario di comunicazione sicura: crea tre utenti (Alice, Bob e Carol), genera le loro chiavi GPG, scambia le chiavi pubbliche ed esegue scambi di messaggi cifrati. Ha un logging completo, la gestione degli errori e una modalità debug con output dettagliato. Questa guida spiega come prepararlo, eseguirlo e capire cosa fa.

Lo script è utile soprattutto per imparare i concetti di GPG in un ambiente controllato: fa vedere come funziona in pratica la cifratura asimmetrica, in cui solo i destinatari previsti riescono a decifrare i messaggi, mentre chi non è autorizzato (come Carol che prova a decifrare il messaggio di Bob per Alice) fallisce.

## Che cos'è GPG Bash Playground?

Lo script automatizza un flusso di lavoro GPG completo:
1. **Creazione degli utenti**: crea tre utenti di sistema (Alice, Bob, Carol) per simulare parti diverse.
2. **Generazione delle chiavi**: genera per ogni utente chiavi GPG RSA a 2048 bit.
3. **Scambio delle chiavi**: esporta e importa le chiavi pubbliche tra gli utenti, impostando i livelli di fiducia.
4. **Demo di cifratura/decifratura**: cifra messaggi tra coppie di utenti (per esempio da Bob ad Alice) e prova la decifratura da parte dei destinatari previsti e di quelli non autorizzati.
5. **Pulizia**: al termine rimuove utenti, file temporanei e agenti GPG.

Registra tutte le azioni in un file (per esempio `gpg.sh.log`) e ha una modalità debug (`-d`) con output verboso. Lo script richiede i privilegi di root, perché crea utenti e modifica il sistema.

## Prerequisiti

- **Bash**: compatibile con la maggior parte dei sistemi Unix-like (Linux/macOS).
- **GPG**: GNU Privacy Guard (su Debian/Ubuntu viene installato in automatico se manca).
- **Accesso root**: va eseguito con `sudo` per la gestione degli utenti.
- **Git**: per clonare il repository.
- **Docker** (facoltativo): per l'esecuzione in un container isolato.

Installa le dipendenze su Debian/Ubuntu:
```bash
sudo apt update
sudo apt install git gnupg docker.io  # Docker optional
```

## Come usare lo script

### 1. Clona e prepara
Clona il repository da GitHub:
```bash
git clone https://github.com/manzolo/gpg-bash-playground.git
cd gpg-bash-playground
chmod +x gpg.sh
```

### 2. Esegui lo script
Lancialo come root:
```bash
sudo ./gpg.sh
```

- **Modalità standard**: esegue la demo completa con il logging.
- **Modalità debug**: aggiungi `-d` per vedere l'output dettagliato dei comandi:
  ```bash
  sudo ./gpg.sh -d
  ```

Lo script:
- Installa GPG se serve.
- Crea gli utenti e genera le chiavi.
- Esegue gli scambi di chiavi e le cifrature/decifrature dei messaggi.
- Scrive i log in `gpg.sh.log` e li mostra in console.

### 3. Esecuzione in Docker (consigliata per le prove)
Per un ambiente isolato, che non tocca il sistema host:

```bash
git clone https://github.com/manzolo/gpg-bash-playground.git
cd gpg-bash-playground
docker build -t manzolo/gpg-playground .
mkdir -p tmp
chmod 777 -R tmp

# Standard mode
docker run --rm -it -v $(pwd)/tmp:/workspace/tmp manzolo/gpg-playground

# Debug mode
docker run --rm -it -v $(pwd)/tmp:/workspace/tmp manzolo/gpg-playground -d
```

- **Spiegazione**:
  - Costruisce un'immagine Docker con lo script e le dipendenze.
  - Monta `./tmp` come `/workspace/tmp` per esportare chiavi e log.
  - Esegue lo script dentro il container, conservando l'output in `./tmp`.

### 4. Guarda i log
Dopo l'esecuzione, controlla il file di log:
```bash
cat gpg.sh.log
```

## Esempi

### Esempio 1: esecuzione standard
Lanciando `sudo ./gpg.sh` ottieni un output di questo tipo:
```
2025-03-11 20:32:24 - [INFO] - Log file is ready.
2025-03-11 20:32:24 - [INFO] - GPG is already installed.
2025-03-11 20:32:24 - [INFO] - Creating user alice...
2025-03-11 20:32:24 - [INFO] - User alice created successfully.
...
2025-03-11 20:32:26 - [INFO] - bob is attempting to decrypt the message from alice...
2025-03-11 20:32:26 - [INFO] - Message from alice successfully decrypted by bob: Secret message from alice to bob
2025-03-11 20:32:26 - [ERROR] - carol failed to decrypt the message from bob.
2025-03-11 20:32:26 - [ERROR] - Decryption by Carol failed (expected).
...
2025-03-11 20:32:26 - [INFO] - Script completed.
```

- **Cosa osservare**:
  - Le decifrature riuscite confermano la cifratura asimmetrica di GPG.
  - I fallimenti attesi (per esempio Carol che prova a decifrare il messaggio di Bob per Alice) dimostrano la sicurezza.

### Esempio 2: modalità debug
Con `-d` vedi l'output verboso dei comandi:
```
2025-03-11 20:32:26 - [DEBUG] - gpg (GnuPG) 2.2.40
2025-03-11 20:32:26 - [DEBUG] - ...
2025-03-11 20:32:26 - [INFO] - Public key of alice imported successfully for user bob.
```

Utile per diagnosticare i problemi con i comandi GPG.

### Esempio 3: ispezionare le chiavi esportate
Dopo l'esecuzione, controlla le chiavi pubbliche esportate in `/tmp` (o in `./tmp` con Docker):
```bash
ls /tmp/*_public.gpg
gpg --import /tmp/alice_public.gpg  # Import to your keyring for inspection
```

## Come è fatto lo script

Lo script (`gpg.sh`) è strutturato in funzioni modulari:

- **Funzioni di logging**: `log_message`, `log_error`, `log_command_output` per un output colorato e con data e ora.
- **Gestione degli utenti**: `create_user`, `setup_gpg` (ripulisce la cartella `.gnupg`).
- **Operazioni GPG**:
  - `generate_gpg_key`: usa `--quick-generate-key` con passphrase vuota, per la demo.
  - `export_public_key`: esporta in `/tmp/${user}_public.gpg`.
  - `import_public_key`: importa e imposta la fiducia «ultimate».
  - `encrypt_message`: cifra un file di messaggio condiviso per un destinatario.
  - `decrypt_message`: tenta la decifratura e registra esito positivo o negativo.
- **Pulizia**: `kill_gpg_agent`, rimuove utenti e file.
- **Flusso principale**: legge gli argomenti, inizializza, esegue le demo, ripulisce.

I principali comandi GPG mostrati:
- `gpg --quick-generate-key`: generazione delle chiavi.
- `gpg --export/--import`: scambio delle chiavi pubbliche.
- `gpg --encrypt --recipient`: cifratura asimmetrica.
- `gpg --decrypt`: decifratura con la chiave privata.

## Casi d'uso
- **Imparare GPG**: demo pratica della gestione delle chiavi e dei flussi di cifratura.
- **Ambienti di test**: usa Docker per sperimentare senza root sull'host.
- **Didattica dello scripting**: un esempio di gestione degli errori, uso di sudo e logging in Bash.
- **Workshop sulla sicurezza**: simula una comunicazione cifrata tra più utenti.

## Consigli pratici
- **Personalizza utenti e messaggi**: modifica variabili come `ALICE="yourname"` o il contenuto del messaggio in `encrypt_message`.
- **Chiavi persistenti**: togli la sezione di pulizia per tenere utenti e chiavi e fare altre prove.
- **GPG avanzato**: estendilo con sottochiavi, firma (`--sign`) o revoca.
- **Analisi dei log**: passa i log in pipe a `grep ERROR` per trovare subito i problemi.

{{< callout type="tip" >}}
**Suggerimento**: eseguilo prima in Docker, così non crei utenti veri sul tuo sistema: ideale per le prove veloci!
{{< /callout >}}

{{< callout type="warning" >}}
**Attenzione**: lo script usa passphrase vuote a scopo dimostrativo. In produzione usa sempre passphrase robuste e valuta i token hardware.
{{< /callout >}}

## Risoluzione dei problemi
- **«This script must be run as root»**: usa `sudo`.
- **L'installazione di GPG fallisce**: verifica che `apt-get` abbia accesso a internet.
- **Errori nella creazione degli utenti**: controlla `/etc/passwd` per eventuali conflitti; lo script salta gli utenti già esistenti.
- **La decifratura fallisce sempre**: verifica i livelli di fiducia con `gpg --edit-key` in modalità debug.
- **Problemi con il volume Docker**: assicurati che `./tmp` abbia i permessi 777 per la scrittura.
- **gpg-agent resta attivo**: lancia a mano `pkill gpg-agent` se la pulizia non riesce.

## Prossimi passi

Nei prossimi tutorial vedremo:
- Scripting GPG avanzato con firma e revoca.
- L'integrazione di GPG con la posta (per esempio Thunderbird/Enigmail).
- La condivisione sicura di file con GPG nelle pipeline Bash.

## Risorse
- [Manuale di GPG](https://www.gnupg.org/documentation/manuals/gnupg/)
- [Guida allo scripting Bash](https://www.gnu.org/software/bash/manual/)
- [Documentazione di Docker](https://docs.docker.com/)

---

*Lancia GPG Bash Playground per sperimentare con la cifratura: perfetto per padroneggiare la comunicazione sicura in Bash!*
