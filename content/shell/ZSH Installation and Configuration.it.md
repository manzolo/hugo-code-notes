---
title: "Guida all'installazione e alla configurazione di ZSH (Debian/Ubuntu)"
url: "shell/zsh-installation-and-configuration/"
date: 2025-10-04T00:22:00+02:00
lastmod: 2026-11-14T19:00:00+01:00
draft: false
author: "Manzolo"
tags: ["zsh", "shell", "oh-my-zsh", "terminal", "configuration"]
categories: ["Linux Administration"]
series: ["System Administration Basics"]
weight: 6
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Guida all'installazione e alla configurazione di ZSH (Debian/Ubuntu)

## Introduzione

ZSH (Z Shell) è una shell potente e personalizzabile, pensata per l'uso interattivo e per lo scripting, che rispetto a Bash offre funzioni in più come l'autocompletamento avanzato, i temi e i plugin. Questa guida spiega come installare ZSH, impostare Oh My Zsh (un framework molto diffuso per gestire le configurazioni di ZSH) e configurare il tema Powerlevel10k con plugin come l'evidenziazione della sintassi e i suggerimenti automatici su sistemi Debian/Ubuntu. Il risultato è una configurazione snella per una shell moderna e comoda da usare.

## Che cos'è ZSH?

ZSH è una shell open source con funzioni come:
- **Autocompletamento**: suggerimenti per comandi e percorsi che tengono conto del contesto.
- **Temi**: prompt personalizzabili tramite framework come Oh My Zsh.
- **Plugin**: funzionalità estendibili (per esempio integrazione con git, evidenziazione della sintassi).
- **Scripting**: compatibile con gli script Bash, ma con una sintassi più ricca.

Questa guida usa Oh My Zsh con il tema Powerlevel10k, per una shell gradevole da vedere ed efficiente.

## Prerequisiti

- **Debian/Ubuntu**: versione 20.04 o successiva.
- **Pacchetti**: `zsh`, `git`, `curl`, `powerline`, `fonts-powerline`.
- **Accesso root**: alcuni comandi richiedono `sudo`.
- **Accesso a internet**: per scaricare Oh My Zsh e i plugin.

Installa le dipendenze:
```bash
sudo apt update
sudo apt install zsh git curl powerline fonts-powerline
```

Verifica l'installazione:
```bash
zsh --version  # Should show zsh version (e.g., 5.8)
```

## Avviso importante: fai un backup della configurazione della shell

{{< callout type="warning" >}}
**Attenzione**: cambiare la shell predefinita o modificare i file di configurazione (per esempio `~/.zshrc`) può cambiare il comportamento del tuo terminale. Fai un backup delle configurazioni della shell esistenti (per esempio `~/.bashrc`, `~/.zshrc`) prima di procedere. Se la configurazione di ZSH non va a buon fine, puoi tornare a Bash con `chsh -s /bin/bash`.
{{< /callout >}}

## Come installare e configurare ZSH

### 1. Installa ZSH e le dipendenze
Installa ZSH e i pacchetti di supporto per una configurazione personalizzata.

```bash
sudo apt update
sudo apt install -y zsh git curl powerline fonts-powerline
```

### 2. Installa Oh My Zsh
Oh My Zsh è un framework che semplifica la configurazione di ZSH e la gestione dei plugin.

```bash
git clone --quiet --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
```

In alternativa, usa l'installer ufficiale (togli il commento se lo preferisci):
```bash
# sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended
```

### 3. Installa i plugin e il tema
Aggiungi i plugin più diffusi (evidenziazione della sintassi, suggerimenti automatici) e il tema Powerlevel10k.

```bash
# Clone plugins
git -C ~/.oh-my-zsh/custom/plugins clone --quiet --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git
git -C ~/.oh-my-zsh/custom/plugins clone --quiet --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git
# Clone Powerlevel10k theme
git -C ~/.oh-my-zsh/custom/themes clone --quiet --depth=1 https://github.com/romkatv/powerlevel10k.git
```

### 4. Configura ZSH
Crea o aggiorna `~/.zshrc` per impostare Oh My Zsh con il tema Powerlevel10k e i plugin.

```bash
cat > ~/.zshrc << 'END'
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ZSH=~/.oh-my-zsh
DISABLE_AUTO_UPDATE=true
DISABLE_MAGIC_FUNCTIONS=true
ZSH_AUTOSUGGEST_MANUAL_REBIND=1
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true

ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(
  git
  git-flow
  zsh-syntax-highlighting
  zsh-autosuggestions
  history
  sudo
)

source ~/.oh-my-zsh/oh-my-zsh.sh
END
```

### 5. Imposta ZSH come shell predefinita
Cambia in ZSH la shell predefinita dell'utente corrente.

```bash
sudo chsh -s $(which zsh) $(whoami)
```

### 6. Verifica la configurazione
Avvia una nuova sessione ZSH per controllare che sia tutto a posto.

```bash
zsh
# Check theme and plugins
echo $ZSH_THEME  # Should output powerlevel10k/powerlevel10k
```

Esci e rientra, oppure apri una nuova sessione di terminale, per usare ZSH con il tema configurato.

## Esempio

### Esempio: configurazione completa di ZSH
Lancia lo script seguente per automatizzare tutta la procedura:

```bash
#!/bin/bash
echo "Installing ZSH..."
sudo apt update -qqy > /dev/null
sudo apt install -qqy zsh git curl powerline fonts-powerline > /dev/null
git clone --quiet --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh > /dev/null
git -C ~/.oh-my-zsh/custom/plugins clone --quiet --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git > /dev/null
git -C ~/.oh-my-zsh/custom/plugins clone --quiet --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git > /dev/null
git -C ~/.oh-my-zsh/custom/themes clone --quiet --depth=1 https://github.com/romkatv/powerlevel10k.git > /dev/null

cat > ~/.zshrc << 'END'
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ZSH=~/.oh-my-zsh
DISABLE_AUTO_UPDATE=true
DISABLE_MAGIC_FUNCTIONS=true
ZSH_AUTOSUGGEST_MANUAL_REBIND=1
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true

ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(
  git
  git-flow
  zsh-syntax-highlighting
  zsh-autosuggestions
  history
  sudo
)

source ~/.oh-my-zsh/oh-my-zsh.sh
END

sudo chsh -s $(which zsh) $(whoami)
echo "ZSH installed and configured. Start a new session with 'zsh'."
```

Salvalo come `install_zsh.sh`, rendilo eseguibile e lancialo:
```bash
chmod +x install_zsh.sh
./install_zsh.sh
zsh
```

**Risultato** (nella nuova sessione ZSH):
- Un prompt con il tema Powerlevel10k, con lo stato di git, l'evidenziazione della sintassi e i suggerimenti automatici.

## I comandi, uno per uno

- **apt install zsh**: installa la shell ZSH.
- **git clone ohmyzsh**: installa il framework Oh My Zsh.
- **git clone plugins/themes**: aggiunge l'evidenziazione della sintassi, i suggerimenti automatici e Powerlevel10k.
- **cat > ~/.zshrc**: configura ZSH con tema e plugin.
- **chsh -s**: imposta ZSH come shell predefinita.

## Casi d'uso
- **Lavoro da sviluppatore**: integrazione con git e suggerimenti automatici mentre scrivi codice.
- **Attività da sysadmin**: evidenziazione della sintassi per non sbagliare i comandi.
- **Shell su misura**: prompt personalizzati per lavorare meglio.
- **Uso interattivo**: cronologia e completamento con Tab potenziati.

## Consigli da esperto
- **Personalizza Powerlevel10k**: lancia `p10k configure` per una configurazione interattiva, se il wizard è abilitato.
- **Backup di Bash**: salva `~/.bashrc` prima di cambiare shell:
  ```bash
  cp ~/.bashrc ~/.bashrc.bak
  ```
- **Aggiungi plugin**: modifica `plugins` in `~/.zshrc` per aggiungerne altri (per esempio `docker`, `kubectl`).
- **Prestazioni**: disattiva in `~/.zshrc` i plugin che non usi per velocizzare ZSH.

{{< callout type="tip" >}}
**Consiglio**: con `zsh-autosuggestions` accetti i suggerimenti con la freccia destra, e scrivi più in fretta.
{{< /callout >}}

## Risoluzione dei problemi
- **ZSH non trovato**: verifica con `zsh --version`; reinstalla se serve (`sudo apt install zsh`).
- **Problemi con il tema**: assicurati che Powerlevel10k sia clonato in `~/.oh-my-zsh/custom/themes`.
- **I plugin non funzionano**: controlla in `~/.zshrc` che i nomi dei plugin siano corretti; ricarica con `source ~/.zshrc`.
- **La shell non cambia**: verifica con `echo $SHELL`; rilancia `chsh` oppure controlla `/etc/passwd`.
- **Avvio lento**: disattiva `POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD` e lancia `p10k configure` per ottimizzare.

## Prossimi passi
Nei prossimi tutorial vedremo:
- Personalizzare i prompt di Powerlevel10k.
- Plugin avanzati di ZSH per flussi di lavoro specifici.
- Integrare ZSH con gli strumenti di sviluppo.

## Risorse
- [Documentazione di ZSH](http://zsh.sourceforge.net/Doc/)
- [Oh My Zsh](https://ohmyz.sh/)
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k)

---

*Installa ZSH con Oh My Zsh per una shell moderna ed efficiente: sperimenta con i plugin per lavorare meglio!*
