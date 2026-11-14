---
title: "Git"
url: "bash/git/"
#description: ""
date: 2025-09-26T10:00:00+01:00
lastmod: 2025-09-26T10:00:00+01:00
draft: false
author: "Manzolo"
tags: ["git", "version-control", "commands", "github", "reference"]
categories: ["Command Reference"]
series: ["Command Line Mastery"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Guida a Git e Gitflow

## Introduzione

Git è un sistema di controllo di versione distribuito che permette a più sviluppatori di collaborare in modo efficiente sugli stessi progetti. Gitflow è un modello di branching molto diffuso, che organizza i branch di Git per rendere ordinati lo sviluppo e la gestione dei rilasci. Questa guida passa in rassegna i comandi essenziali di Git, presenta il workflow Gitflow e propone esempi pratici per gestire i repository di codice.

## Cos'è Git?

Git tiene traccia delle modifiche ai file e permette a più persone di lavorare sullo stesso progetto senza pestarsi i piedi. Gestisce branch, merge e cronologia delle versioni: per questo è ideale per lo sviluppo software e per i progetti collaborativi.

## Cos'è Gitflow?

Gitflow è una strategia di branching che definisce branch specifici per lo sviluppo, le feature, i rilasci e gli hotfix. Garantisce un workflow strutturato, soprattutto ai team che lavorano su progetti di lunga durata con più rilasci.

## Prerequisiti

- Git installato sul sistema (`git --version` per verificare).
- Una conoscenza di base dei comandi da terminale.
- Un repository Git (locale o remoto, per esempio su GitHub, GitLab o Bitbucket).

Se serve, installa Git:

```bash
sudo apt update
sudo apt install git  # Ubuntu/Debian
```

## Comandi Git di base

### Preparare il repository

```bash
# Initialize a new Git repository
git init

# Clone a remote repository
git clone https://github.com/user/repo.git

# Check repository status
git status
```

### Fare il commit delle modifiche

```bash
# Stage files for commit
git add file.txt
git add .  # Stage all changes

# Commit staged changes
git commit -m "Add feature X"

# Amend the last commit
git commit --amend -m "Updated message"
```

### I branch

```bash
# List all branches
git branch

# Create a new branch
git branch feature-x

# Switch to a branch
git checkout feature-x

# Create and switch to a new branch
git checkout -b feature-x

# Delete a branch
git branch -d feature-x
```

### Operazioni sul remoto

```bash
# Add a remote repository
git remote add origin https://github.com/user/repo.git

# Push changes to remote
git push origin main

# Pull changes from remote
git pull origin main

# Fetch changes without merging
git fetch origin
```

## Il workflow Gitflow

Gitflow assegna a ogni branch un ruolo preciso:

- **main**: il codice pronto per la produzione.
- **develop**: il branch di integrazione delle feature.
- **feature/***: per le nuove feature (parte da `develop`).
- **release/***: per preparare un rilascio (parte da `develop`, finisce con un merge in `main` e in `develop`).
- **hotfix/***: per le correzioni urgenti (parte da `main`, torna con un merge in `main` e in `develop`).
- **support/***: per mantenere i rilasci più vecchi (facoltativo).

### Configurare Gitflow

Installa `git-flow` (facoltativo, per comodità):

```bash
sudo apt install git-flow  # Ubuntu/Debian
```

Inizializza Gitflow:

```bash
git flow init
```

Il comando crea la struttura dei branch con i valori predefiniti (per esempio `main`, `develop`).

### Esempio 1: creare un branch di feature

Comincia una nuova feature:

```bash
git flow feature start my-feature
```

- **Spiegazione**: crea il branch `feature/my-feature` a partire da `develop`.
- **Uso**:
  ```bash
  # Make changes
  echo "New feature" > feature.txt
  git add feature.txt
  git commit -m "Implement my-feature"

  # Finish the feature (merges into develop)
  git flow feature finish my-feature
  ```

### Esempio 2: preparare un rilascio

Comincia un rilascio:

```bash
git flow release start 1.0.0
```

- **Spiegazione**: crea il branch `release/1.0.0` a partire da `develop`.
- **Uso**:
  ```bash
  # Make final adjustments (e.g., update version numbers)
  echo "1.0.0" > version.txt
  git add version.txt
  git commit -m "Bump version to 1.0.0"

  # Finish the release (merges into main and develop, tags the release)
  git flow release finish 1.0.0
  git push origin main develop --tags
  ```

### Esempio 3: gestire un hotfix

Comincia un hotfix per un bug in produzione:

```bash
git flow hotfix start 1.0.1
```

- **Spiegazione**: crea il branch `hotfix/1.0.1` a partire da `main`.
- **Uso**:
  ```bash
  # Fix the bug
  echo "Bugfix" > patch.txt
  git add patch.txt
  git commit -m "Fix critical bug"

  # Finish the hotfix (merges into main and develop, tags the hotfix)
  git flow hotfix finish 1.0.1
  git push origin main develop --tags
  ```

## Comandi Git utili

### Guardare la cronologia

```bash
# View commit history
git log
git log --oneline --graph --all  # Compact, visual history

# Show changes in a commit
git show commit_hash
```

### Merge e rebase

```bash
# Merge a branch into the current branch
git merge feature-x

# Rebase current branch onto another
git rebase develop

# Resolve merge conflicts manually, then:
git add resolved_file
git rebase --continue  # or git merge --continue
```

### Mettere da parte le modifiche con stash

```bash
# Save uncommitted changes
git stash

# List stashed changes
git stash list

# Apply the latest stash
git stash apply

# Drop a stash
git stash drop stash@{0}
```

### I tag

```bash
# Create a tag
git tag v1.0.0

# Push tags to remote
git push origin v1.0.0

# List tags
git tag
```

## Uno script pratico

Crea uno script che automatizza la configurazione di Gitflow e i controlli di stato:

```bash
#!/bin/bash
# manage_gitflow.sh

echo "=== Gitflow Management ==="
echo "Current repository: $(pwd)"
echo ""

# Initialize Gitflow if not already set up
if [ ! -f .git/config ] || ! grep -q "gitflow" .git/config; then
  echo "Initializing Gitflow..."
  git flow init -d
fi

echo "Current branches:"
git branch

echo ""
echo "Recent commits:"
git log --oneline --graph --all -n 5

echo ""
echo "Repository status:"
git status
```

Rendilo eseguibile:

```bash
chmod +x manage_gitflow.sh
./manage_gitflow.sh
```

## Consigli da esperti

{{< callout type="tip" >}}
**Consiglio**: usa i comandi `git-flow` per coerenza, ma se preferisci puoi ottenere gli stessi risultati con i comandi standard di Git.
{{< /callout >}}

{{< callout type="warning" >}}
**Attenzione**: evita il force-push (`git push --force`) sui branch condivisi come `main` o `develop`, per non sovrascrivere il lavoro degli altri.
{{< /callout >}}

{{< callout type="success" title="Quick Reference" >}}
**Scorciatoie essenziali:**
- `git checkout -b feature/x`: crea un branch di feature e ci passa sopra.
- `git push --set-upstream origin branch`: fa il push di un branch nuovo e ne imposta il tracking.
- `git stash pop`: applica l'ultimo stash e lo rimuove.
- `git log --oneline`: mostra una cronologia sintetica dei commit.
{{< /callout >}}

## Risoluzione dei problemi

- **Conflitti di merge**: modifica i file in conflitto, segnali come risolti (`git add`) e prosegui con il merge o il rebase.
- **Errori nel push sul remoto**: prima di fare il push assicurati di avere le ultime modifiche (`git pull --rebase`).
- **Commit persi**: usa `git reflog` per ritrovare gli hash dei commit persi e recuperali con `git checkout commit_hash`.
- **Gitflow non trovato**: installa `git-flow` oppure riproduci il workflow con i comandi standard di Git.

## Prossimi passi

Nei prossimi tutorial vedremo:
- Workflow Git avanzati (per esempio GitHub Flow).
- Come automatizzare le operazioni di Git con gli hook.
- Come gestire repository di grandi dimensioni con Git LFS.
- Come integrare Git con le pipeline CI/CD.

## Esercizi pratici

1. **Sviluppo di una feature**: crea un branch di feature, aggiungi un file e fai il merge in `develop` usando Gitflow.
2. **Processo di rilascio**: simula un rilascio con un tag di versione e fanne il push su un repository remoto.
3. **Hotfix**: crea un branch di hotfix, applica una correzione e fai il merge in `main` e in `develop`.
4. **Analisi della cronologia**: usa `git log` e `git blame` per analizzare le modifiche a un file.

## Risorse

- [Documentazione di Git](https://git-scm.com/doc)
- [Il workflow Gitflow](https://nvie.com/posts/a-successful-git-branching-model/)
- [I tutorial su Git di Atlassian](https://www.atlassian.com/git)
- [Learn Git Branching](https://learngitbranching.js.org/)

---

*Fai pratica con Git e Gitflow per rendere più scorrevole il tuo workflow di sviluppo!*
