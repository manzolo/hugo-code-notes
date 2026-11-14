---
title: "SPF, DMARC e DKIM: la triade della sicurezza email"
url: "2026/02/spf-dmarc-and-dkim-the-email-security-triad/"
description: "Come funzionano SPF, DMARC e DKIM per proteggere le tue email da spam e phishing"
date: 2026-02-16T10:00:00+02:00
lastmod: 2026-02-16T10:00:00+02:00
draft: false
author: "Manzolo"
tags: ["email", "security", "spf", "dmarc", "dkim", "spam", "phishing"]
categories: ["Security"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# SPF, DMARC e DKIM: la triade della sicurezza email

Nel mondo della sicurezza informatica le email sono spesso il primo punto d'ingresso per attacchi di phishing e spam. Per proteggere sistemi e utenti è fondamentale capire e configurare correttamente i protocolli di autenticazione della posta: SPF, DMARC e DKIM. Questi tre protocolli formano la triade della sicurezza email e lavorano insieme per garantire integrità e autenticità delle comunicazioni elettroniche.

## Che cos'è SPF (Sender Policy Framework)?

### Definizione

SPF (Sender Policy Framework) è un protocollo di autenticazione email che permette al proprietario di un dominio di indicare quali server possono inviare posta a nome di quel dominio. Funziona come una whitelist che elenca i server autorizzati a spedire email per un dominio.

### Come funziona

Quando un server riceve un'email, controlla il record SPF del dominio del mittente. Se l'indirizzo IP di chi invia è compreso nel record SPF, l'email è considerata autentica. In caso contrario può essere segnalata come sospetta o rifiutata.

### Esempio di record SPF

```
v=spf1 include:_spf.google.com ~all
```

In questo esempio:
- `v=spf1` indica la versione di SPF
- `include:_spf.google.com` include i server di Google per l'invio della posta
- `~all` indica che tutti gli altri permessi non specificati vanno trattati come «soft fail»

## Che cos'è DKIM (DomainKeys Identified Mail)?

### Definizione

DKIM (DomainKeys Identified Mail) è un protocollo di autenticazione email che usa la crittografia a chiave pubblica per firmare digitalmente i messaggi. La firma viaggia dentro il messaggio e permette al server ricevente di verificare che l'email non sia stata modificata durante il trasferimento e che arrivi davvero dal dominio dichiarato.

### Come funziona

1. Il server mittente genera una firma digitale usando una chiave privata
2. La firma viene inserita nell'intestazione dell'email come campo DKIM-Signature
3. Il server ricevente recupera la chiave pubblica dal DNS del dominio
4. Il server verifica la firma con la chiave pubblica
5. Se la verifica va a buon fine, l'email è considerata autentica

### Esempio di configurazione DKIM

```
mail._domainkey IN TXT "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC..."
```

## Che cos'è DMARC (Domain-based Message Authentication, Reporting and Conformance)?

### Definizione

DMARC (Domain-based Message Authentication, Reporting and Conformance) è un protocollo che si appoggia a SPF e DKIM per offrire un meccanismo di reportistica e di gestione delle policy per le email autenticate. DMARC non autentica direttamente le email, ma stabilisce cosa fare di quelle che non superano i controlli SPF o DKIM.

### Componenti principali

1. **Policy**: definisce cosa fare delle email non autenticate (reject, quarantine, none)
2. **Reportistica**: permette ai proprietari del dominio di ricevere report sulle email inviate
3. **Allineamento**: verifica che i domini di SPF e DKIM siano allineati con il dominio del mittente

### Esempio di record DMARC

```
_dmarc IN TXT "v=DMARC1; p=quarantine; rua=mailto:reports@yourdomain.com; ruf=mailto:forensic@yourdomain.com; fo=1"
```

In questo esempio:
- `v=DMARC1` indica la versione di DMARC
- `p=quarantine` policy: metti in quarantena le email non autenticate
- `rua=mailto:reports@yourdomain.com` indirizzo per i report aggregati
- `ruf=mailto:forensic@yourdomain.com` indirizzo per i report dettagliati
- `fo=1` segnala le violazioni

## Implementazione pratica

### Configurazione DNS

Per implementare correttamente questi protocolli devi configurare i record DNS del tuo dominio:

1. **Record SPF**: aggiungi un record TXT con il dominio SPF
2. **Record DKIM**: aggiungi un record TXT per la chiave pubblica DKIM
3. **Record DMARC**: aggiungi un record TXT per DMARC

### Test

Dopo la configurazione è importante mettere alla prova i protocolli:

1. Usa strumenti online come:
   - MXToolbox SPF Checker
   - DMARC Analyzer
   - DKIM Validator
2. Tieni d'occhio i report DMARC per verificare che tutto funzioni
3. Verifica che non ci siano falsi positivi

## Buone pratiche

### 1. Configurazione sicura

- Usa policy DMARC adeguate (reject per le email non autenticate)
- Attiva la reportistica per monitorare l'attività della posta
- Evita `~all` o `+all` in SPF (concede troppi permessi)

### 2. Monitoraggio e reportistica

- Imposta report DMARC regolari per monitorare l'attività
- Analizza i report per individuare problemi di configurazione
- Aggiorna regolarmente le configurazioni

### 3. Gestione dei server

- Tieni aggiornato in SPF l'elenco dei server autorizzati
- Verifica che tutti i server di invio siano configurati correttamente
- Rimuovi periodicamente i server non più usati

## Problemi comuni e soluzioni

### 1. Falsi positivi

**Problema**: email legittime vengono rifiutate o messe in quarantena
**Soluzione**: verifica la configurazione di SPF e DMARC, aggiungi i server autorizzati

### 2. Configurazione errata

**Problema**: la configurazione non funziona come dovrebbe
**Soluzione**: usa gli strumenti di test e verifica i record DNS

### 3. Report mancanti

**Problema**: non arriva nessun report DMARC
**Soluzione**: verifica che l'indirizzo per i report sia corretto e raggiungibile

## Conclusione

SPF, DMARC e DKIM sono strumenti essenziali per proteggere la posta elettronica da phishing e spam. Implementare correttamente questa triade ti permette di:
- Ridurre le email di spam e phishing
- Proteggere la reputazione del dominio
- Migliorare la sicurezza della posta
- Ottenere report dettagliati sull'attività email

La configurazione richiede attenzione e un monitoraggio continuo, ma i vantaggi in termini di sicurezza e affidabilità sono notevoli. Ricorda che la sicurezza della posta è un processo continuo, ed è importante tenere aggiornate le configurazioni per rispondere alle nuove minacce.

Prova sempre le configurazioni dopo ogni modifica e controlla regolarmente i report, per essere sicuro che la protezione della posta funzioni come deve.
