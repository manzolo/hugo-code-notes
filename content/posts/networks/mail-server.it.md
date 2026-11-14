---
title: "Mail server: guida all'installazione e alla configurazione (Debian/Ubuntu)"
url: "2025/10/mail-server-installation-and-configuration-guide-debian/ubuntu/"
date: 2025-10-04T11:00:00+02:00
lastmod: 2025-10-04T11:00:00+02:00
draft: false
author: "Manzolo"
tags: ["mail-server", "postfix", "dovecot", "email", "configuration"]
categories: ["Networking & Security"]
series: ["Networking Fundamentals"]
weight: 9
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Mail server: guida all'installazione e alla configurazione (Debian/Ubuntu)

## Introduzione

Mettere in piedi un mail server completo ti permette di inviare e ricevere posta con il tuo dominio, con il pieno controllo sui tuoi dati. Questa guida spiega come installare e configurare su Debian/Ubuntu un mail server pronto per la produzione, con Postfix (SMTP), Dovecot (POP3/IMAP), gestione degli utenti, quote e funzioni di sicurezza, cifratura TLS/SSL compresa. È l'ideale per piccole aziende, organizzazioni o chiunque voglia una posta indipendente.

## Cos'è un mail server?

Un mail server è un sistema che si occupa di inviare, ricevere e conservare i messaggi di posta elettronica. Una configurazione completa comprende:
- **Server SMTP (Postfix)**: invia e riceve le email tra i server.
- **Server IMAP/POP3 (Dovecot)**: permette ai client di scaricare le email.
- **Gestione degli utenti**: utenti virtuali con autenticazione.
- **Sicurezza**: cifratura TLS/SSL per SMTPS, IMAPS, POP3S.
- **Gestione delle quote**: limiti di spazio per utente.
- **Protezione dallo spam**: filtri di base e autenticazione.

Caratteristiche principali:
- **Pieno controllo**: l'infrastruttura di posta la gestisci tu.
- **Privacy**: i tuoi dati restano sul tuo server.
- **Più utenti**: supporto a più caselle di posta.
- **Rispetto degli standard**: funziona con tutti i client di posta standard.

## Prerequisiti

- **Debian/Ubuntu**: versione 20.04+ (consigliata l'edizione server).
- **Accesso root**: usa `sudo` per l'installazione e la configurazione.
- **Nome di dominio**: un dominio registrato con accesso al DNS (es. example.com).
- **Record DNS**: la possibilità di creare record MX, A e TXT.
- **IP pubblico statico**: necessario per ricevere la posta.
- **Certificato SSL valido**: consigliato Let's Encrypt (gratuito).
- **Porte aperte**: 25 (SMTP), 587 (submission), 993 (IMAPS), 995 (POP3S).
- **Reverse DNS**: record PTR che punta all'hostname del tuo mail server.
- **IP con una reputazione pulita**: IP non in blacklist (controlla con MXToolbox).

Verifica il sistema:
```bash
uname -a  # Check kernel and distro
hostname -f  # Should return FQDN (e.g., mail.example.com)
ip addr show  # Check IP addresses
```

## Avviso importante: sicurezza e configurazione
{{< callout type="warning" >}}
**Attenzione**: un mail server configurato male può diventare un open relay per lo spam, far finire il tuo IP in blacklist o esporre dati sensibili. Usa sempre la cifratura, imposta un'autenticazione come si deve, configura i record SPF/DKIM/DMARC e tieni aggiornato il software. Fai tutte le prove prima di andare in produzione. Fai un backup delle configurazioni (es. `/etc/postfix/`, `/etc/dovecot/`) prima di ogni modifica.
{{< /callout >}}
## Come configurare un mail server completo

### 1. Preparare il sistema e il DNS

Aggiorna il sistema e imposta l'hostname:
```bash
sudo apt update && sudo apt upgrade -y
sudo hostnamectl set-hostname mail.example.com
```

Modifica `/etc/hosts`:
```bash
sudo nano /etc/hosts
```
Aggiungi:
```
YOUR_SERVER_IP mail.example.com mail
```

Configura i record DNS (dal registrar del dominio o dal provider DNS):
- **Record A**: `mail.example.com` → `YOUR_SERVER_IP`
- **Record MX**: `example.com` → `mail.example.com` (priorità 10)
- **Record PTR**: `YOUR_SERVER_IP` → `mail.example.com` (reverse DNS, chiedi al tuo provider di hosting)
- **Record SPF** (TXT): `v=spf1 mx ~all`
- **Record DMARC** (TXT): `_dmarc.example.com` → `v=DMARC1; p=quarantine; rua=mailto:postmaster@example.com`

Verifica il DNS:
```bash
dig mail.example.com
dig -t MX example.com
dig -x YOUR_SERVER_IP  # Check PTR
```

### 2. Installare Postfix (server SMTP)

Installa Postfix:
```bash
sudo apt install postfix
```

Durante l'installazione:
- Scegli **Internet Site**
- System mail name: `example.com`

Configura Postfix:
```bash
sudo nano /etc/postfix/main.cf
```

Le impostazioni principali:
```
myhostname = mail.example.com
mydomain = example.com
myorigin = $mydomain
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
relayhost =
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
inet_protocols = all

# Virtual mailbox settings
virtual_mailbox_domains = /etc/postfix/virtual_domains
virtual_mailbox_base = /var/mail/vhosts
virtual_mailbox_maps = hash:/etc/postfix/virtual_mailboxes
virtual_minimum_uid = 100
virtual_uid_maps = static:5000
virtual_gid_maps = static:5000
virtual_alias_maps = hash:/etc/postfix/virtual_aliases

# TLS settings
smtpd_tls_cert_file=/etc/letsencrypt/live/mail.example.com/fullchain.pem
smtpd_tls_key_file=/etc/letsencrypt/live/mail.example.com/privkey.pem
smtpd_use_tls=yes
smtpd_tls_auth_only = yes
smtpd_tls_security_level = may
smtp_tls_security_level = may
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_ciphers = high
smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1

# SASL authentication
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = $myhostname
broken_sasl_auth_clients = yes

# Security
smtpd_recipient_restrictions = 
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_unauth_destination,
    reject_invalid_hostname,
    reject_non_fqdn_sender,
    reject_non_fqdn_recipient,
    reject_unknown_sender_domain,
    reject_unknown_recipient_domain
```

Configura la porta di submission (587):
```bash
sudo nano /etc/postfix/master.cf
```

Togli il commento alla sezione submission e modificala:
```
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_tls_auth_only=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_helo_restrictions=
  -o smtpd_sender_restrictions=
  -o smtpd_recipient_restrictions=
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
```

### 3. Installare e configurare i certificati SSL

Installa Certbot per Let's Encrypt:
```bash
sudo apt install certbot
```

Richiedi il certificato:
```bash
sudo certbot certonly --standalone -d mail.example.com
```

Segui le richieste a schermo e inserisci l'indirizzo email.

Verifica il certificato:
```bash
sudo ls -l /etc/letsencrypt/live/mail.example.com/
```

Imposta il rinnovo automatico:
```bash
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

### 4. Creare la struttura delle caselle virtuali

Crea la cartella che conterrà la posta:
```bash
sudo mkdir -p /var/mail/vhosts/example.com
sudo groupadd -g 5000 vmail
sudo useradd -g vmail -u 5000 vmail -d /var/mail
sudo chown -R vmail:vmail /var/mail
```

Configura i domini virtuali:
```bash
sudo nano /etc/postfix/virtual_domains
```
Aggiungi:
```
example.com
```

Configura le caselle virtuali:
```bash
sudo nano /etc/postfix/virtual_mailboxes
```
Aggiungi gli utenti:
```
user1@example.com example.com/user1/
user2@example.com example.com/user2/
admin@example.com example.com/admin/
```

Configura gli alias virtuali (facoltativo):
```bash
sudo nano /etc/postfix/virtual_aliases
```
Aggiungi gli alias:
```
postmaster@example.com admin@example.com
abuse@example.com admin@example.com
```

Genera i database hash:
```bash
sudo postmap /etc/postfix/virtual_mailboxes
sudo postmap /etc/postfix/virtual_aliases
```

Riavvia Postfix:
```bash
sudo systemctl restart postfix
sudo systemctl enable postfix
```

### 5. Installare Dovecot (server IMAP/POP3)

Installa Dovecot:
```bash
sudo apt install dovecot-core dovecot-imapd dovecot-pop3d
```

Configura le impostazioni principali:
```bash
sudo nano /etc/dovecot/dovecot.conf
```
Togli il commento o aggiungi:
```
protocols = imap pop3
listen = *, ::
```

Configura la posizione della posta:
```bash
sudo nano /etc/dovecot/conf.d/10-mail.conf
```
Imposta:
```
mail_location = maildir:/var/mail/vhosts/%d/%n
mail_privileged_group = mail
first_valid_uid = 5000
first_valid_gid = 5000
```

Configura l'autenticazione:
```bash
sudo nano /etc/dovecot/conf.d/10-auth.conf
```
Modifica:
```
disable_plaintext_auth = yes
auth_mechanisms = plain login
!include auth-passwdfile.conf.ext
```

Commenta:
```
#!include auth-system.conf.ext
```

Modifica l'autenticazione tramite file di password:
```bash
sudo nano /etc/dovecot/conf.d/auth-passwdfile.conf.ext
```
Imposta:
```
passdb {
  driver = passwd-file
  args = scheme=PLAIN username_format=%u /etc/dovecot/users
}

userdb {
  driver = static
  args = uid=vmail gid=vmail home=/var/mail/vhosts/%d/%n
}
```

Configura SSL:
```bash
sudo nano /etc/dovecot/conf.d/10-ssl.conf
```
Imposta:
```
ssl = required
ssl_cert = </etc/letsencrypt/live/mail.example.com/fullchain.pem
ssl_key = </etc/letsencrypt/live/mail.example.com/privkey.pem
ssl_min_protocol = TLSv1.2
ssl_cipher_list = HIGH:!aNULL:!MD5
ssl_prefer_server_ciphers = yes
```

Configura IMAP e POP3:
```bash
sudo nano /etc/dovecot/conf.d/20-imap.conf
```
```
protocol imap {
  mail_max_userip_connections = 10
}
```

```bash
sudo nano /etc/dovecot/conf.d/20-pop3.conf
```
```
protocol pop3 {
  pop3_uidl_format = %08Xu%08Xv
  mail_max_userip_connections = 10
}
```

Configura il SASL per Postfix:
```bash
sudo nano /etc/dovecot/conf.d/10-master.conf
```
Aggiungi o modifica il servizio auth:
```
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
}
```

### 6. Creare gli utenti e impostare le password

Crea il file degli utenti:
```bash
sudo nano /etc/dovecot/users
```

Aggiungi gli utenti nel formato: `email:password:uid:gid::home::`
```
user1@example.com:{PLAIN}password123:5000:5000::/var/mail/vhosts/example.com/user1::
user2@example.com:{PLAIN}securepass456:5000:5000::/var/mail/vhosts/example.com/user2::
admin@example.com:{PLAIN}adminpass789:5000:5000::/var/mail/vhosts/example.com/admin::
```

**Importante**: per una sicurezza migliore usa password con hash. Si generano con:
```bash
doveadm pw -s SHA512-CRYPT
```
Poi usa il formato: `{SHA512-CRYPT}$6$...`

Imposta i permessi:
```bash
sudo chmod 640 /etc/dovecot/users
sudo chown root:dovecot /etc/dovecot/users
```

Riavvia Dovecot:
```bash
sudo systemctl restart dovecot
sudo systemctl enable dovecot
```

### 7. Configurare la gestione delle quote

Modifica la configurazione delle quote di Dovecot:
```bash
sudo nano /etc/dovecot/conf.d/90-quota.conf
```
Aggiungi:
```
plugin {
  quota = maildir:User quota
  quota_rule = *:storage=1G
  quota_rule2 = Trash:storage=+100M
  quota_warning = storage=95%% quota-warning 95 %u
  quota_warning2 = storage=80%% quota-warning 80 %u
}
```

Abilita il plugin delle quote:
```bash
sudo nano /etc/dovecot/conf.d/10-mail.conf
```
Aggiungi:
```
mail_plugins = $mail_plugins quota
```

```bash
sudo nano /etc/dovecot/conf.d/20-imap.conf
```
Modifica:
```
protocol imap {
  mail_plugins = $mail_plugins imap_quota
  mail_max_userip_connections = 10
}
```

Crea lo script di avviso per la quota:
```bash
sudo nano /usr/local/bin/quota-warning.sh
```
```bash
#!/bin/bash
PERCENT=$1
USER=$2
cat << EOF | /usr/lib/dovecot/dovecot-lda -d $USER -o "plugin/quota=maildir:User quota:noenforcing"
From: postmaster@example.com
Subject: Quota warning - $PERCENT% full

Your mailbox is now $PERCENT% full. Please delete old messages to free up space.
EOF
```

Rendilo eseguibile:
```bash
sudo chmod +x /usr/local/bin/quota-warning.sh
```

Configura il servizio di avviso per la quota:
```bash
sudo nano /etc/dovecot/conf.d/10-master.conf
```
Aggiungi:
```
service quota-warning {
  executable = script /usr/local/bin/quota-warning.sh
  user = vmail
  unix_listener quota-warning {
    user = vmail
  }
}
```

Riavvia Dovecot:
```bash
sudo systemctl restart dovecot
```

### 8. Configurare il firewall

Apri le porte della posta:
```bash
sudo ufw allow 25/tcp    # SMTP
sudo ufw allow 587/tcp   # Submission
sudo ufw allow 993/tcp   # IMAPS
sudo ufw allow 995/tcp   # POP3S
sudo ufw allow 'OpenSSH'
sudo ufw enable
```

Verifica:
```bash
sudo ufw status
```

### 9. Configurare SPF, DKIM e DMARC

Installa OpenDKIM:
```bash
sudo apt install opendkim opendkim-tools
```

Configura OpenDKIM:
```bash
sudo nano /etc/opendkim.conf
```
Le impostazioni principali:
```
Domain                  example.com
KeyFile                 /etc/opendkim/keys/example.com/mail.private
Selector                mail
Socket                  inet:8891@localhost
```

Crea la struttura delle cartelle:
```bash
sudo mkdir -p /etc/opendkim/keys/example.com
```

Genera le chiavi DKIM:
```bash
cd /etc/opendkim/keys/example.com
sudo opendkim-genkey -s mail -d example.com
sudo chown opendkim:opendkim mail.private
```

Recupera la chiave pubblica per il DNS:
```bash
sudo cat mail.txt
```

Aggiungila al DNS come record TXT:
```
mail._domainkey.example.com → (paste the content from mail.txt)
```

Configura Postfix perché usi OpenDKIM:
```bash
sudo nano /etc/postfix/main.cf
```
Aggiungi:
```
milter_default_action = accept
milter_protocol = 2
smtpd_milters = inet:localhost:8891
non_smtpd_milters = inet:localhost:8891
```

Avvia OpenDKIM:
```bash
sudo systemctl restart opendkim
sudo systemctl enable opendkim
sudo systemctl restart postfix
```

### 10. Provare il mail server

Prova la connessione SMTP:
```bash
telnet mail.example.com 25
```
Comandi:
```
EHLO example.com
QUIT
```

Prova l'autenticazione (porta di submission):
```bash
openssl s_client -connect mail.example.com:587 -starttls smtp
```

Prova IMAP:
```bash
openssl s_client -connect mail.example.com:993
```
Login:
```
a1 LOGIN user1@example.com password123
a2 LIST "" "*"
a3 LOGOUT
```

Prova POP3:
```bash
openssl s_client -connect mail.example.com:995
```
Comandi:
```
USER user1@example.com
PASS password123
STAT
QUIT
```

Controlla la quota di un utente:
```bash
doveadm quota get -u user1@example.com
```

Invia un'email di prova:
```bash
echo "Test email body" | mail -s "Test Subject" -r user1@example.com user2@example.com
```

## Esempi

### Esempio 1: installare Postfix e Dovecot
```bash
sudo apt update
sudo apt install postfix dovecot-core dovecot-imapd dovecot-pop3d
```

**Output**:
```
Setting up postfix (3.6.4-1) ...
Setting up dovecot-core (1:2.3.16+dfsg1-3) ...
```

### Esempio 2: creare un utente con casella virtuale
```bash
sudo nano /etc/postfix/virtual_mailboxes
# Add: john@example.com example.com/john/
sudo postmap /etc/postfix/virtual_mailboxes
sudo nano /etc/dovecot/users
# Add: john@example.com:{PLAIN}johnpass123:5000:5000::/var/mail/vhosts/example.com/john::
sudo systemctl restart postfix dovecot
```

### Esempio 3: controllare lo stato del mail server
```bash
sudo systemctl status postfix
sudo systemctl status dovecot
sudo netstat -tulpn | grep -E ':(25|587|993|995)'
```

**Output**:
```
● postfix.service - Postfix Mail Transport Agent
     Active: active (running) since Sat 2025-10-04 14:00:00 UTC

tcp        0      0 0.0.0.0:25              0.0.0.0:*               LISTEN      1234/master
tcp        0      0 0.0.0.0:587             0.0.0.0:*               LISTEN      1234/master
tcp        0      0 0.0.0.0:993             0.0.0.0:*               LISTEN      5678/dovecot
tcp        0      0 0.0.0.0:995             0.0.0.0:*               LISTEN      5678/dovecot
```

### Esempio 4: provare invio e ricezione
Invia un'email di prova:
```bash
echo "This is a test message" | mail -s "Test Email" -r sender@example.com recipient@example.com
```

Controlla la coda della posta:
```bash
sudo mailq
```

Guarda i log:
```bash
sudo tail -f /var/log/mail.log
```

### Esempio 5: generare la password con hash per un utente
```bash
doveadm pw -s SHA512-CRYPT
```

**Output**:
```
Enter new password: 
Retype new password: 
{SHA512-CRYPT}$6$randomsalt$hashedpasswordstring...
```

Poi aggiungila a `/etc/dovecot/users`:
```
newuser@example.com:{SHA512-CRYPT}$6$randomsalt$hashed...:5000:5000::/var/mail/vhosts/example.com/newuser::
```

## Varianti

### Usare MySQL/PostgreSQL per la gestione degli utenti

Per scalare meglio, usa un database al posto dei file di testo:

Installa MySQL:
```bash
sudo apt install mysql-server postfix-mysql dovecot-mysql
```

Crea il database e le tabelle:
```sql
CREATE DATABASE mailserver;
CREATE USER 'mailuser'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON mailserver.* TO 'mailuser'@'localhost';

USE mailserver;

CREATE TABLE virtual_domains (
  id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE virtual_users (
  id INT NOT NULL AUTO_INCREMENT,
  domain_id INT NOT NULL,
  email VARCHAR(100) NOT NULL,
  password VARCHAR(150) NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
);

CREATE TABLE virtual_aliases (
  id INT NOT NULL AUTO_INCREMENT,
  domain_id INT NOT NULL,
  source VARCHAR(100) NOT NULL,
  destination VARCHAR(100) NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
);
```

Configura Postfix perché usi MySQL (modifica `/etc/postfix/main.cf`):
```
virtual_mailbox_domains = mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf
virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf
virtual_alias_maps = mysql:/etc/postfix/mysql-virtual-alias-maps.cf
```

### Interfaccia webmail con Roundcube

Installa Roundcube per leggere la posta dal browser:
```bash
sudo apt install roundcube roundcube-mysql
```

Configura Apache/Nginx perché serva Roundcube e accedi dal browser.

### Anti-spam avanzato con SpamAssassin

Installa SpamAssassin:
```bash
sudo apt install spamassassin spamc
sudo systemctl enable spamassassin
sudo systemctl start spamassassin
```

Configura Postfix perché usi SpamAssassin:
```bash
sudo nano /etc/postfix/master.cf
```
Aggiungi:
```
smtp      inet  n       -       y       -       -       smtpd
  -o content_filter=spamassassin

spamassassin unix -     n       n       -       -       pipe
  user=debian-spamc argv=/usr/bin/spamc -f -e /usr/sbin/sendmail -oi -f ${sender} ${recipient}
```

## I comandi, uno per uno

- **postfix**: MTA (Mail Transfer Agent) per inviare e ricevere le email
- **dovecot**: MDA (Mail Delivery Agent) per l'accesso IMAP/POP3
- **postmap**: genera il database hash a partire dai file di testo
- **doveadm**: lo strumento di amministrazione di Dovecot, per la gestione degli utenti
- **certbot**: ottiene e rinnova i certificati SSL
- **opendkim**: implementa l'autenticazione DKIM delle email
- **mailq**: mostra lo stato della coda della posta
- **mail**: utility per inviare email da riga di comando

## Casi d'uso

- **Posta per una piccola azienda**: ospitare la posta aziendale con un dominio proprio
- **Posta attenta alla privacy**: controllo completo sui dati della tua posta
- **Sviluppo e test**: provare le funzioni di posta delle applicazioni
- **Hosting multidominio**: ospitare la posta di più domini su un solo server
- **Studio**: capire i protocolli e l'infrastruttura della posta elettronica

## Consigli pratici

- **Usa password robuste**: sempre password con hash, mai in chiaro in produzione
- **Tieni d'occhio i log**: controlla regolarmente `/var/log/mail.log` per scovare i problemi
- **Fai backup regolari**: salva `/var/mail/vhosts/`, `/etc/postfix/`, `/etc/dovecot/`
- **Tieni aggiornato il DNS**: verifica che i record SPF, DKIM e DMARC siano corretti
- **Controlla le blacklist**: sorveglia il tuo IP con MXToolbox.com
- **Rate limiting**: configura i limiti di frequenza di Postfix per prevenire gli abusi
- **Fail2ban**: installa fail2ban per bloccare i tentativi di brute force
- **Sorveglia le quote**: imposta degli avvisi per quando gli utenti si avvicinano al limite
- **Prova la consegna**: manda email di prova a Gmail, Outlook, Yahoo
- **Tieniti aggiornato**: gli aggiornamenti di sicurezza regolari sono fondamentali

## Risoluzione dei problemi

**Non riesci a inviare email**:
- Controlla il firewall: `sudo ufw status`
- Verifica il record MX nel DNS: `dig -t MX example.com`
- Controlla i log di Postfix: `sudo tail -f /var/log/mail.log`
- Prova SMTP: `telnet mail.example.com 25`

**Non riesci a ricevere email**:
- Verifica che i record MX e A puntino dove devono
- Controlla se la porta 25 è bloccata dal provider
- Verifica che Postfix sia in ascolto: `sudo netstat -tulpn | grep :25`
- Controlla le restrizioni di relay in `/etc/postfix/main.cf`

**L'autenticazione fallisce**:
- Verifica che l'utente esista in `/etc/dovecot/users`
- Controlla il formato della password (PLAIN, SHA512-CRYPT, ecc.)
- Prova a mano: `doveadm auth test user@example.com password`
- Controlla i log di Dovecot: `sudo journalctl -u dovecot`

**Errori del certificato SSL**:
- Verifica i percorsi dei certificati nelle configurazioni
- Prova il certificato: `openssl s_client -connect mail.example.com:993`
- Rinnova il certificato: `sudo certbot renew`
- Controlla i permessi: i certificati devono essere leggibili

**Le email finiscono nello spam**:
- Verifica il record SPF: `dig -t TXT example.com`
- Controlla la firma DKIM: `sudo opendkim-testkey -d example.com -s mail`
- Verifica il reverse DNS (PTR): `dig -x YOUR_IP`
- Controlla la reputazione dell'IP su MXToolbox
- Assicurati che la policy DMARC sia impostata

**Le quote non funzionano**:
- Verifica che il plugin delle quote sia caricato nella configurazione di Dovecot
- Controlla lo stato della quota: `doveadm quota get -u user@example.com`
- Ricalcola la quota: `doveadm quota recalc -u user@example.com`

**Carico elevato o problemi di prestazioni**:
- Controlla se ci sono attacchi di spam: `sudo mailq | wc -l`
- Tieni d'occhio le connessioni: `sudo netstat -an | grep :25 | wc -l`
- Esamina la coda di Postfix: `sudo postqueue -p`
- Svuota la coda se serve: `sudo postsuper -d ALL`

## Risorse

- [Documentazione di Postfix](http://www.postfix.org/documentation.html)
- [Documentazione di Dovecot](https://doc.dovecot.org/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Guida a OpenDKIM](http://opendkim.org/)
- [MXToolbox](https://mxtoolbox.com/) - per provare la configurazione della posta
- [Mail-Tester](https://www.mail-tester.com/) - per provare la consegna delle email

---

*Metti in piedi un mail server completo su Debian/Ubuntu con SMTP, IMAP, POP3, gestione degli utenti e quote!*
