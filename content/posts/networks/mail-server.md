---
title: "Mail Server Installation and Configuration Guide (Debian/Ubuntu)"
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

# Mail Server Installation and Configuration Guide (Debian/Ubuntu)

## Introduction

Setting up a complete mail server allows you to send and receive emails using your own domain with full control over your data. This guide explains how to install and configure a production-ready mail server on Debian/Ubuntu with Postfix (SMTP), Dovecot (POP3/IMAP), user management, quota support, and security features including TLS/SSL encryption. It's ideal for small businesses, organizations, or anyone wanting independent email hosting.

## What is a Mail Server?

A mail server is a system that handles sending, receiving, and storing email messages. A complete setup includes:
- **SMTP Server (Postfix)**: Sends and receives emails between servers.
- **IMAP/POP3 Server (Dovecot)**: Allows clients to retrieve emails.
- **User Management**: Virtual users with authentication.
- **Security**: TLS/SSL encryption for SMTPS, IMAPS, POP3S.
- **Quota Management**: Storage limits per user.
- **Spam Protection**: Basic filtering and authentication.

Key features:
- **Full Control**: Manage your own email infrastructure.
- **Privacy**: Your data stays on your server.
- **Multiple Users**: Support for multiple email accounts.
- **Standards Compliant**: Works with all standard email clients.

## Prerequisites

- **Debian/Ubuntu**: Version 20.04+ (server edition recommended).
- **Root Access**: Use `sudo` for installation and configuration.
- **Domain Name**: A registered domain with DNS access (e.g., example.com).
- **DNS Records**: Ability to create MX, A, and TXT records.
- **Public Static IP**: Required for receiving emails.
- **Valid SSL Certificate**: Let's Encrypt recommended (free).
- **Ports Open**: 25 (SMTP), 587 (submission), 993 (IMAPS), 995 (POP3S).
- **Reverse DNS**: PTR record pointing to your mail server hostname.
- **Clean IP Reputation**: IP not blacklisted (check with MXToolbox).

Verify system:
```bash
uname -a  # Check kernel and distro
hostname -f  # Should return FQDN (e.g., mail.example.com)
ip addr show  # Check IP addresses
```

## Critical Warning: Security and Configuration
{{< callout type="warning" >}}
**Caution**: An improperly configured mail server can become an open relay for spam, get your IP blacklisted, or expose sensitive data. Always use encryption, implement proper authentication, configure SPF/DKIM/DMARC records, and regularly update software. Test thoroughly before production use. Back up configurations (e.g., `/etc/postfix/`, `/etc/dovecot/`) before changes.
{{< /callout >}}
## How to Set Up a Complete Mail Server

### 1. Prepare the System and DNS

Update the system and set hostname:
```bash
sudo apt update && sudo apt upgrade -y
sudo hostnamectl set-hostname mail.example.com
```

Edit `/etc/hosts`:
```bash
sudo nano /etc/hosts
```
Add:
```
YOUR_SERVER_IP mail.example.com mail
```

Configure DNS records (in your domain registrar/DNS provider):
- **A Record**: `mail.example.com` → `YOUR_SERVER_IP`
- **MX Record**: `example.com` → `mail.example.com` (priority 10)
- **PTR Record**: `YOUR_SERVER_IP` → `mail.example.com` (reverse DNS, contact your hosting provider)
- **SPF Record** (TXT): `v=spf1 mx ~all`
- **DMARC Record** (TXT): `_dmarc.example.com` → `v=DMARC1; p=quarantine; rua=mailto:postmaster@example.com`

Verify DNS:
```bash
dig mail.example.com
dig -t MX example.com
dig -x YOUR_SERVER_IP  # Check PTR
```

### 2. Install Postfix (SMTP Server)

Install Postfix:
```bash
sudo apt install postfix
```

During installation:
- Select **Internet Site**
- System mail name: `example.com`

Configure Postfix:
```bash
sudo nano /etc/postfix/main.cf
```

Key configurations:
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

Configure submission port (587):
```bash
sudo nano /etc/postfix/master.cf
```

Uncomment and modify the submission section:
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

### 3. Install and Configure SSL Certificates

Install Certbot for Let's Encrypt:
```bash
sudo apt install certbot
```

Obtain certificate:
```bash
sudo certbot certonly --standalone -d mail.example.com
```

Follow prompts and enter email address.

Verify certificate:
```bash
sudo ls -l /etc/letsencrypt/live/mail.example.com/
```

Set up auto-renewal:
```bash
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

### 4. Create Virtual Mailbox Structure

Create mail storage directory:
```bash
sudo mkdir -p /var/mail/vhosts/example.com
sudo groupadd -g 5000 vmail
sudo useradd -g vmail -u 5000 vmail -d /var/mail
sudo chown -R vmail:vmail /var/mail
```

Configure virtual domains:
```bash
sudo nano /etc/postfix/virtual_domains
```
Add:
```
example.com
```

Configure virtual mailboxes:
```bash
sudo nano /etc/postfix/virtual_mailboxes
```
Add users:
```
user1@example.com example.com/user1/
user2@example.com example.com/user2/
admin@example.com example.com/admin/
```

Configure virtual aliases (optional):
```bash
sudo nano /etc/postfix/virtual_aliases
```
Add aliases:
```
postmaster@example.com admin@example.com
abuse@example.com admin@example.com
```

Build hash databases:
```bash
sudo postmap /etc/postfix/virtual_mailboxes
sudo postmap /etc/postfix/virtual_aliases
```

Restart Postfix:
```bash
sudo systemctl restart postfix
sudo systemctl enable postfix
```

### 5. Install Dovecot (IMAP/POP3 Server)

Install Dovecot:
```bash
sudo apt install dovecot-core dovecot-imapd dovecot-pop3d
```

Configure main settings:
```bash
sudo nano /etc/dovecot/dovecot.conf
```
Uncomment or add:
```
protocols = imap pop3
listen = *, ::
```

Configure mail location:
```bash
sudo nano /etc/dovecot/conf.d/10-mail.conf
```
Set:
```
mail_location = maildir:/var/mail/vhosts/%d/%n
mail_privileged_group = mail
first_valid_uid = 5000
first_valid_gid = 5000
```

Configure authentication:
```bash
sudo nano /etc/dovecot/conf.d/10-auth.conf
```
Modify:
```
disable_plaintext_auth = yes
auth_mechanisms = plain login
!include auth-passwdfile.conf.ext
```

Comment out:
```
#!include auth-system.conf.ext
```

Edit password file authentication:
```bash
sudo nano /etc/dovecot/conf.d/auth-passwdfile.conf.ext
```
Set:
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

Configure SSL:
```bash
sudo nano /etc/dovecot/conf.d/10-ssl.conf
```
Set:
```
ssl = required
ssl_cert = </etc/letsencrypt/live/mail.example.com/fullchain.pem
ssl_key = </etc/letsencrypt/live/mail.example.com/privkey.pem
ssl_min_protocol = TLSv1.2
ssl_cipher_list = HIGH:!aNULL:!MD5
ssl_prefer_server_ciphers = yes
```

Configure IMAP and POP3:
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

Configure Postfix SASL:
```bash
sudo nano /etc/dovecot/conf.d/10-master.conf
```
Add/modify auth service:
```
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
}
```

### 6. Create Users and Set Passwords

Create the users file:
```bash
sudo nano /etc/dovecot/users
```

Add users with format: `email:password:uid:gid::home::`
```
user1@example.com:{PLAIN}password123:5000:5000::/var/mail/vhosts/example.com/user1::
user2@example.com:{PLAIN}securepass456:5000:5000::/var/mail/vhosts/example.com/user2::
admin@example.com:{PLAIN}adminpass789:5000:5000::/var/mail/vhosts/example.com/admin::
```

**Important**: For better security, use hashed passwords. Generate with:
```bash
doveadm pw -s SHA512-CRYPT
```
Then use format: `{SHA512-CRYPT}$6$...`

Set permissions:
```bash
sudo chmod 640 /etc/dovecot/users
sudo chown root:dovecot /etc/dovecot/users
```

Restart Dovecot:
```bash
sudo systemctl restart dovecot
sudo systemctl enable dovecot
```

### 7. Configure Quota Management

Edit Dovecot quota configuration:
```bash
sudo nano /etc/dovecot/conf.d/90-quota.conf
```
Add:
```
plugin {
  quota = maildir:User quota
  quota_rule = *:storage=1G
  quota_rule2 = Trash:storage=+100M
  quota_warning = storage=95%% quota-warning 95 %u
  quota_warning2 = storage=80%% quota-warning 80 %u
}
```

Enable quota plugin:
```bash
sudo nano /etc/dovecot/conf.d/10-mail.conf
```
Add:
```
mail_plugins = $mail_plugins quota
```

```bash
sudo nano /etc/dovecot/conf.d/20-imap.conf
```
Modify:
```
protocol imap {
  mail_plugins = $mail_plugins imap_quota
  mail_max_userip_connections = 10
}
```

Create quota warning script:
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

Make executable:
```bash
sudo chmod +x /usr/local/bin/quota-warning.sh
```

Configure quota warning service:
```bash
sudo nano /etc/dovecot/conf.d/10-master.conf
```
Add:
```
service quota-warning {
  executable = script /usr/local/bin/quota-warning.sh
  user = vmail
  unix_listener quota-warning {
    user = vmail
  }
}
```

Restart Dovecot:
```bash
sudo systemctl restart dovecot
```

### 8. Configure Firewall

Allow mail ports:
```bash
sudo ufw allow 25/tcp    # SMTP
sudo ufw allow 587/tcp   # Submission
sudo ufw allow 993/tcp   # IMAPS
sudo ufw allow 995/tcp   # POP3S
sudo ufw allow 'OpenSSH'
sudo ufw enable
```

Verify:
```bash
sudo ufw status
```

### 9. Configure SPF, DKIM, and DMARC

Install OpenDKIM:
```bash
sudo apt install opendkim opendkim-tools
```

Configure OpenDKIM:
```bash
sudo nano /etc/opendkim.conf
```
Key settings:
```
Domain                  example.com
KeyFile                 /etc/opendkim/keys/example.com/mail.private
Selector                mail
Socket                  inet:8891@localhost
```

Create directory structure:
```bash
sudo mkdir -p /etc/opendkim/keys/example.com
```

Generate DKIM keys:
```bash
cd /etc/opendkim/keys/example.com
sudo opendkim-genkey -s mail -d example.com
sudo chown opendkim:opendkim mail.private
```

Get public key for DNS:
```bash
sudo cat mail.txt
```

Add to DNS as TXT record:
```
mail._domainkey.example.com → (paste the content from mail.txt)
```

Configure Postfix to use OpenDKIM:
```bash
sudo nano /etc/postfix/main.cf
```
Add:
```
milter_default_action = accept
milter_protocol = 2
smtpd_milters = inet:localhost:8891
non_smtpd_milters = inet:localhost:8891
```

Start OpenDKIM:
```bash
sudo systemctl restart opendkim
sudo systemctl enable opendkim
sudo systemctl restart postfix
```

### 10. Testing the Mail Server

Test SMTP connection:
```bash
telnet mail.example.com 25
```
Commands:
```
EHLO example.com
QUIT
```

Test authentication (submission port):
```bash
openssl s_client -connect mail.example.com:587 -starttls smtp
```

Test IMAP:
```bash
openssl s_client -connect mail.example.com:993
```
Login:
```
a1 LOGIN user1@example.com password123
a2 LIST "" "*"
a3 LOGOUT
```

Test POP3:
```bash
openssl s_client -connect mail.example.com:995
```
Commands:
```
USER user1@example.com
PASS password123
STAT
QUIT
```

Check user quota:
```bash
doveadm quota get -u user1@example.com
```

Send test email:
```bash
echo "Test email body" | mail -s "Test Subject" -r user1@example.com user2@example.com
```

## Examples

### Example 1: Install Postfix and Dovecot
```bash
sudo apt update
sudo apt install postfix dovecot-core dovecot-imapd dovecot-pop3d
```

**Output**:
```
Setting up postfix (3.6.4-1) ...
Setting up dovecot-core (1:2.3.16+dfsg1-3) ...
```

### Example 2: Create Virtual Mailbox User
```bash
sudo nano /etc/postfix/virtual_mailboxes
# Add: john@example.com example.com/john/
sudo postmap /etc/postfix/virtual_mailboxes
sudo nano /etc/dovecot/users
# Add: john@example.com:{PLAIN}johnpass123:5000:5000::/var/mail/vhosts/example.com/john::
sudo systemctl restart postfix dovecot
```

### Example 3: Check Mail Server Status
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

### Example 4: Test Email Send/Receive
Send test email:
```bash
echo "This is a test message" | mail -s "Test Email" -r sender@example.com recipient@example.com
```

Check mail queue:
```bash
sudo mailq
```

View logs:
```bash
sudo tail -f /var/log/mail.log
```

### Example 5: Generate Hashed Password for User
```bash
doveadm pw -s SHA512-CRYPT
```

**Output**:
```
Enter new password: 
Retype new password: 
{SHA512-CRYPT}$6$randomsalt$hashedpasswordstring...
```

Then add to `/etc/dovecot/users`:
```
newuser@example.com:{SHA512-CRYPT}$6$randomsalt$hashed...:5000:5000::/var/mail/vhosts/example.com/newuser::
```

## Variants

### Using MySQL/PostgreSQL for User Management

For scalability, use a database instead of flat files:

Install MySQL:
```bash
sudo apt install mysql-server postfix-mysql dovecot-mysql
```

Create database and tables:
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

Configure Postfix to use MySQL (modify `/etc/postfix/main.cf`):
```
virtual_mailbox_domains = mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf
virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf
virtual_alias_maps = mysql:/etc/postfix/mysql-virtual-alias-maps.cf
```

### Webmail Interface with Roundcube

Install Roundcube for web-based email access:
```bash
sudo apt install roundcube roundcube-mysql
```

Configure Apache/Nginx to serve Roundcube and access via browser.

### Advanced Anti-Spam with SpamAssassin

Install SpamAssassin:
```bash
sudo apt install spamassassin spamc
sudo systemctl enable spamassassin
sudo systemctl start spamassassin
```

Configure Postfix to use SpamAssassin:
```bash
sudo nano /etc/postfix/master.cf
```
Add:
```
smtp      inet  n       -       y       -       -       smtpd
  -o content_filter=spamassassin

spamassassin unix -     n       n       -       -       pipe
  user=debian-spamc argv=/usr/bin/spamc -f -e /usr/sbin/sendmail -oi -f ${sender} ${recipient}
```

## Command Breakdown

- **postfix**: MTA (Mail Transfer Agent) for sending/receiving emails
- **dovecot**: MDA (Mail Delivery Agent) for IMAP/POP3 access
- **postmap**: Builds hash database from text files
- **doveadm**: Dovecot administration tool for user management
- **certbot**: Obtains and renews SSL certificates
- **opendkim**: Implements DKIM email authentication
- **mailq**: Shows mail queue status
- **mail**: Command-line email sending utility

## Use Cases

- **Small Business Email**: Host company email with custom domain
- **Privacy-Focused Email**: Complete control over your email data
- **Development/Testing**: Test email functionality in applications
- **Multi-Domain Hosting**: Host email for multiple domains on one server
- **Learning**: Understand email protocols and infrastructure

## Pro Tips

- **Use Strong Passwords**: Always use hashed passwords, never plain text in production
- **Monitor Logs**: Regularly check `/var/log/mail.log` for issues
- **Backup Regularly**: Backup `/var/mail/vhosts/`, `/etc/postfix/`, `/etc/dovecot/`
- **Update DNS**: Ensure SPF, DKIM, and DMARC records are correct
- **Check Blacklists**: Monitor your IP with MXToolbox.com
- **Rate Limiting**: Configure Postfix rate limits to prevent abuse
- **Fail2ban**: Install fail2ban to block brute-force attempts
- **Monitor Quota**: Set up alerts when users approach limits
- **Test Deliverability**: Send test emails to Gmail, Outlook, Yahoo
- **Keep Updated**: Regular security updates are critical

## Troubleshooting

**Cannot Send Email**:
- Check firewall: `sudo ufw status`
- Verify DNS MX record: `dig -t MX example.com`
- Check Postfix logs: `sudo tail -f /var/log/mail.log`
- Test SMTP: `telnet mail.example.com 25`

**Cannot Receive Email**:
- Verify MX and A records point correctly
- Check if port 25 is blocked by ISP
- Verify Postfix is listening: `sudo netstat -tulpn | grep :25`
- Check relay restrictions in `/etc/postfix/main.cf`

**Authentication Fails**:
- Verify user exists in `/etc/dovecot/users`
- Check password format (PLAIN, SHA512-CRYPT, etc.)
- Test manually: `doveadm auth test user@example.com password`
- Check Dovecot logs: `sudo journalctl -u dovecot`

**SSL Certificate Errors**:
- Verify certificate paths in configs
- Test certificate: `openssl s_client -connect mail.example.com:993`
- Renew certificate: `sudo certbot renew`
- Check permissions: certificates must be readable

**Emails Marked as Spam**:
- Verify SPF record: `dig -t TXT example.com`
- Check DKIM signature: `sudo opendkim-testkey -d example.com -s mail`
- Verify reverse DNS (PTR): `dig -x YOUR_IP`
- Check IP reputation on MXToolbox
- Ensure DMARC policy is set

**Quota Not Working**:
- Verify quota plugin is loaded in Dovecot config
- Check quota status: `doveadm quota get -u user@example.com`
- Recalculate quota: `doveadm quota recalc -u user@example.com`

**High Load/Performance Issues**:
- Check for spam attacks: `sudo mailq | wc -l`
- Monitor connections: `sudo netstat -an | grep :25 | wc -l`
- Review Postfix queue: `sudo postqueue -p`
- Clear queue if needed: `sudo postsuper -d ALL`

## Resources

- [Postfix Documentation](http://www.postfix.org/documentation.html)
- [Dovecot Documentation](https://doc.dovecot.org/)
- [Let's Encrypt](https://letsencrypt.org/)
- [OpenDKIM Guide](http://opendkim.org/)
- [MXToolbox](https://mxtoolbox.com/) - Test email configuration
- [Mail-Tester](https://www.mail-tester.com/) - Test email deliverability

---

*Set up a complete mail server on Debian/Ubuntu with SMTP, IMAP, POP3, user management, and quota support!*