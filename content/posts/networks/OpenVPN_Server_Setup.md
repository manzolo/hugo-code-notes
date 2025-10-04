---
title: "OpenVPN Server Installation and Configuration Guide (Debian/Ubuntu)"
date: 2025-10-04T11:00:00+02:00
lastmod: 2025-10-04T11:00:00+02:00
draft: false
author: "Manzolo"
tags: ["linux", "openvpn", "vpn", "server", "networking", "security", "tutorial"]
categories: ["linux", "tutorial"]
series: ["Linux Essentials"]
weight: 8
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# OpenVPN Server Installation and Configuration Guide (Debian/Ubuntu)

## Introduction

Setting up an OpenVPN server allows secure remote access to your network or resources. This guide explains how to install an OpenVPN server on Debian/Ubuntu, generate certificates and keys, configure the server, create user/client configurations, and connect from a client. It includes steps for creating multiple users and testing connections, making it ideal for home servers, small businesses, or secure remote access.

## What is an OpenVPN Server?

An OpenVPN server creates encrypted tunnels for clients to connect securely over the internet. Key features include:
- **Security**: Uses certificates and TLS for authentication and encryption.
- **Flexibility**: Supports multiple clients with individual configurations.
- **Routing**: Pushes routes to clients for access to local networks.
- **Use Cases**: Secure remote access, site-to-site connections, or bypassing restrictions.

## Prerequisites

- **Debian/Ubuntu**: Version 20.04+ (server edition recommended).
- **Root Access**: Use `sudo` for installation and configuration.
- **Public IP or Domain**: A static public IP or dynamic DNS for client connections (port 1194 UDP forwarded).
- **Tools**: `openvpn`, `easy-rsa` for certificate generation.
- **Internet Access**: Required for installing packages.
- **Firewall**: Open port 1194/UDP.

Verify system:
```bash
uname -a  # Check kernel and distro
ip addr show  # Check IP addresses
```

## Critical Warning: Security and Configuration

{{< callout type="warning" >}}
**Caution**: An improperly configured VPN server can expose your network to risks. Use strong passphrases, keep certificates private, and restrict access with firewalls. Test locally before exposing to the internet. Back up configurations (e.g., `/etc/openvpn/`) before changes.
{{< /callout >}}

## How to Use OpenVPN Server

### 1. Install OpenVPN and Easy-RSA
Install OpenVPN and Easy-RSA (for certificate generation):
```bash
sudo apt update
sudo apt install openvpn easy-rsa
```

Verify installation:
```bash
openvpn --version
easyrsa version
```

### 2. Set Up Easy-RSA for Certificates
Easy-RSA generates the Certificate Authority (CA) and keys.

1. Copy Easy-RSA files:
   ```bash
   make-cadir ~/openvpn-ca
   cd ~/openvpn-ca
   ```

2. Edit variables (e.g., `vars` file):
   ```bash
   nano vars
   ```
   Set parameters (e.g., `set_var EASYRSA_REQ_COUNTRY "US"`, `set_var EASYRSA_KEY_SIZE 2048`).

3. Build CA:
   ```bash
   ./easyrsa init-pki
   ./easyrsa build-ca
   ```
   Enter a passphrase for the CA and confirm details.

4. Generate server certificate:
   ```bash
   ./easyrsa gen-req server nopass
   ./easyrsa sign-req server server
   ```

5. Generate Diffie-Hellman parameters:
   ```bash
   ./easyrsa gen-dh
   ```

6. Generate TLS key for HMAC protection:
   ```bash
   openvpn --genkey --secret pki/ta.key
   ```

### 3. Configure the OpenVPN Server
Create and edit the server configuration file:
```bash
sudo cp /usr/share/doc/openvpn/examples/server.conf.gz /etc/openvpn/server.conf.gz
sudo gunzip /etc/openvpn/server.conf.gz
sudo nano /etc/openvpn/server.conf
```

Key changes:
- `port 1194`
- `proto udp`
- `dev tun`
- `ca /etc/openvpn/ca.crt`
- `cert /etc/openvpn/server.crt`
- `key /etc/openvpn/server.key`
- `dh /etc/openvpn/dh.pem`
- `server 10.8.0.0 255.255.255.0` (VPN subnet)
- `push "redirect-gateway def1 bypass-dhcp"` (route all traffic through VPN)
- `push "dhcp-option DNS 8.8.8.8"`
- `tls-auth /etc/openvpn/ta.key 0`
- `user nobody`
- `group nogroup`

Copy keys to `/etc/openvpn/`:
```bash
sudo cp ~/openvpn-ca/pki/ca.crt /etc/openvpn/
sudo cp ~/openvpn-ca/pki/issued/server.crt /etc/openvpn/
sudo cp ~/openvpn-ca/pki/private/server.key /etc/openvpn/
sudo cp ~/openvpn-ca/pki/dh.pem /etc/openvpn/
sudo cp ~/openvpn-ca/pki/ta.key /etc/openvpn/
```

### 4. Start and Enable OpenVPN Service
Start the OpenVPN server:
```bash
sudo systemctl start openvpn@server
sudo systemctl enable openvpn@server
```

Verify status:
```bash
sudo systemctl status openvpn@server
```
![OpenVPN server status showing active connection](/images/openvpn-server-status.png "Output of sudo systemctl status openvpn@server")
Example output:
```
● openvpn@server.service - OpenVPN connection to server
     Loaded: loaded (/lib/systemd/system/openvpn@.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2025-10-04 14:00:00 UTC; 1min ago
```

### 5. Configure Firewall
Allow VPN traffic through the firewall:
- Install UFW (if not installed):
  ```bash
  sudo apt install ufw
  ```
- Configure rules:
  ```bash
  sudo ufw allow 1194/udp
  sudo ufw allow OpenSSH
  sudo ufw enable
  ```

### 6. Create Users/Clients
Generate client certificates and configurations.

1. For a new user (e.g., `client1`):
   ```bash
   cd ~/openvpn-ca
   ./easyrsa gen-req client1 nopass
   ./easyrsa sign-req client client1
   ```

2. Create client `.ovpn` file:
   ```bash
   cd ~
   mkdir client-configs
   cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf ./client-configs/base.conf
   nano ./client-configs/base.conf
   ```
   Update:
   - `remote your-server-ip 1194`
   - `proto udp`
   - `user nobody`
   - `group nogroup`
   - `ca ca.crt`
   - `cert client.crt`
   - `key client.key`
   - `tls-auth ta.key 1`

3. Generate client `.ovpn`:
   Create a script to generate client configs:
   ```bash
   nano ./client-configs/make_config.sh
   ```
   Content:
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

   Make executable:
   ```bash
   chmod 700 ./client-configs/make_config.sh
   ```

4. Generate client config:
   ```bash
   cd ./client-configs
   ./make_config.sh client1
   ```
   The `client1.ovpn` is now in `~/client-configs/files/`. Send it to the client securely.

5. Repeat for additional users (e.g., `client2`):
   ```bash
   cd ~/openvpn-ca
   ./easyrsa gen-req client2 nopass
   ./easyrsa sign-req client client2
   cd ~/client-configs
   ./make_config.sh client2
   ```

### 7. Connect from a Client
On a Debian/Ubuntu client:
1. Install OpenVPN:
   ```bash
   sudo apt install openvpn
   ```

2. Copy the `.ovpn` file from the server (e.g., via SCP):
   ```bash
   scp user@server-ip:~/client-configs/files/client1.ovpn ~/vpn/client1.ovpn
   ```

3. Connect:
   ```bash
   sudo openvpn --config ~/vpn/client1.ovpn
   ```
   Enter passphrase if required.

4. Verify:
   ```bash
   curl ifconfig.me  # Shows server IP
   ```

## Examples

### Example 1: Install OpenVPN Server
Install OpenVPN and Easy-RSA:
```bash
sudo apt update
sudo apt install openvpn easy-rsa
openvpn --version
```

**Output**:
```
OpenVPN 2.5.9 x86_64-pc-linux-gnu [SSL (OpenSSL)] [LZO] [LZ4] ...
```

### Example 2: Generate CA and Server Certificates
Set up Easy-RSA and generate certificates:
```bash
make-cadir ~/openvpn-ca
cd ~/openvpn-ca
nano vars  # Set parameters
./easyrsa init-pki
./easyrsa build-ca
./easyrsa gen-req server nopass
./easyrsa sign-req server server
./easyrsa gen-dh
openvpn --genkey --secret pki/ta.key
```

**Output** (during `build-ca`):
```
Enter PEM pass phrase: [enter passphrase]
Common Name (eg: your user, host, or server name) [Easy-RSA CA]: [press Enter]
CA creation complete and you may now import and sign cert requests.
```

### Example 3: Configure and Start OpenVPN Server
Configure the server and start the service:
```bash
sudo cp /usr/share/doc/openvpn/examples/server.conf.gz /etc/openvpn/server.conf.gz
sudo gunzip /etc/openvpn/server.conf.gz
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

**Output** (status):
```
● openvpn@server.service - OpenVPN connection to server
     Loaded: loaded (/lib/systemd/system/openvpn@.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2025-10-04 14:00:00 UTC; 1min ago
```

### Example 4: Create a User/Client
Generate a client configuration:
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

### Example 5: Connect from a Client
On the client:
```bash
sudo apt install openvpn
scp user@server-ip:~/client-configs/files/client1.ovpn ~/vpn/client1.ovpn
sudo openvpn --config ~/vpn/client1.ovpn
```

**Output**:
```
2025-10-04 14:00:01 Initialization Sequence Completed
2025-10-04 14:00:01 [Server] Peer Connection Initiated with [AF_INET]192.168.1.10:1194
```

## Variants

### Using WireGuard as an Alternative VPN
Install and configure WireGuard for a faster, simpler VPN:
```bash
sudo apt install wireguard
wg genkey | tee private.key | wg pubkey > public.key
nano /etc/wireguard/wg0.conf  # Configure interface
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0
```

### Multi-User VPN Setup
For multiple users, generate additional clients:
```bash
cd ~/openvpn-ca
./easyrsa gen-req client2 nopass
./easyrsa sign-req client client2
cd ~/client-configs
./make_config.sh client2
```

## Command Breakdown
- **apt install openvpn easy-rsa**: Installs OpenVPN and certificate tools.
- **easyrsa build-ca**: Generates the CA.
- **easyrsa gen-req/sign-req**: Generates and signs certificates.
- **openvpn --genkey --secret**: Generates TLS key.
- **systemctl start/enable openvpn@server**: Manages the server service.
- **ufw allow**: Configures firewall rules.
- **openvpn --config <file>**: Connects the client.

## Use Cases
- **Secure Remote Access**: Connect to home networks from anywhere.
- **Privacy**: Encrypt traffic on public Wi-Fi.
- **Site-to-Site VPN**: Link multiple networks securely.
- **Bypass Restrictions**: Use with commercial providers for geo-blocked content.

## Pro Tips
- **Strong Passphrases**: Use complex passphrases for CA and client keys.
- **Firewall Rules**: Restrict access to port 1194/UDP from trusted IPs.
- **Client Revocation**: Revoke clients with `./easyrsa revoke client1` and update CRL in `server.conf`.
- **DNS Push**: Add `push "dhcp-option DNS 8.8.8.8"` in `server.conf` for client DNS.
- **Monitor Logs**: Use `journalctl -u openvpn@server` for server logs.

## Troubleshooting
- **Connection Refused**: Check firewall (`ufw status`), port forwarding, and server IP in `.ovpn`.
- **Certificate Errors**: Verify CA passphrase and key locations in `server.conf`.
- **No Internet After Connecting**: Check `server.conf` for `push "redirect-gateway def1 bypass-dhcp"`.
- **Permission Issues**: Ensure keys have `chmod 600` and are owned by root.
- **Check Logs**: Server logs in `/var/log/syslog` or `journalctl -u openvpn@server`.
- **Client Connection Fails**: Use `openvpn --config client1.ovpn --verb 4` for detailed logs.

## Resources
- [OpenVPN Documentation](https://openvpn.net/community-resources/)
- [Ubuntu OpenVPN Guide](https://ubuntu.com/server/docs/virtual-private-networks-openvpn)
- [Easy-RSA GitHub](https://github.com/OpenVPN/easy-rsa)

---

*Set up an OpenVPN server on Debian/Ubuntu for secure remote access and client connections!*