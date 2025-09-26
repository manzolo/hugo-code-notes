---
title: "SSH Forward Tunneling"
#description: ""
date: 2025-09-26T10:00:00+01:00
lastmod: 2025-09-26T10:00:00+01:00
draft: false
author: "Manzolo"
tags: ["bash", "linux", "terminal", "commands", "tutorial"]
categories: ["bash", "tutorial"]
series: ["Bash Essentials"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# SSH Forward Tunneling Guide

## Introduction

SSH forward tunneling (also known as local port forwarding) allows you to securely connect to a remote service through an SSH server, making it appear as if the service is running on your local machine. This is useful for accessing services on a remote server or another machine in a secure network that aren't directly accessible.

In this guide, we'll cover the basics of SSH forward tunneling, explain how it works, and provide practical examples.

## What is SSH Forward Tunneling?

Forward tunneling lets you forward a local port to a remote server or another host reachable by the SSH server. The connection is encrypted through the SSH tunnel, ensuring secure communication.

### Basic Syntax

```bash
ssh -L [local_port]:[destination_host]:[destination_port] [user]@[ssh_server]
```

- `-L`: Specifies local port forwarding.
- `[local_port]`: The port on your local machine where you'll access the service.
- `[destination_host]`: The target host (relative to the SSH server) you want to connect to.
- `[destination_port]`: The port on the destination host.
- `[user]@[ssh_server]`: The SSH server acting as the intermediary.

## How It Works

1. You initiate an SSH connection to the SSH server.
2. A local port on your machine is bound to a specific port on the destination host via the SSH server.
3. Any traffic sent to the local port is forwarded through the SSH tunnel to the destination host and port.

## Prerequisites

- An SSH client installed (e.g., `OpenSSH` on Linux/macOS or tools like PuTTY on Windows).
- Access to an SSH server with credentials (username and password or SSH key).
- Knowledge of the destination host and port you want to access.

## Examples

### Example 1: Accessing a Remote Web Server

Suppose you want to access a web server running on `webserver.local` (port 80) through an SSH server (`ssh.example.com`). The web server isn't directly accessible from your machine, but the SSH server can reach it.

```bash
ssh -L 8080:webserver.local:80 user@ssh.example.com
```

- **Explanation**:
  - `8080`: Your local machine's port where you'll access the web server.
  - `webserver.local:80`: The remote web server and its port.
  - `user@ssh.example.com`: The SSH server you're connecting to.
- **Usage**: Open your browser and go to `http://localhost:8080`. The traffic is tunneled to `webserver.local:80` via the SSH server.

### Example 2: Accessing a Database Server

You need to connect to a MySQL database running on `dbserver.local` (port 3306) through the same SSH server.

```bash
ssh -L 3306:dbserver.local:3306 user@ssh.example.com
```

- **Explanation**:
  - `3306`: The local port where you'll connect your MySQL client.
  - `dbserver.local:3306`: The remote MySQL server and its port.
- **Usage**: Use a MySQL client (e.g., `mysql` or a GUI like DBeaver) to connect to `localhost:3306`. The traffic is forwarded to the remote database.

### Example 3: Tunneling to Another Machine

If you want to access a service on a third machine (`internal.host:5432`) that's only reachable by the SSH server, you can forward traffic like this:

```bash
ssh -L 5432:internal.host:5432 user@ssh.example.com
```

- **Usage**: Connect to `localhost:5432` from your local machine to interact with `internal.host:5432`.

## Useful Options

- **Background Mode**: Run the tunnel in the background with `-f` and `-N` (no command execution):

  ```bash
  ssh -f -N -L 8080:webserver.local:80 user@ssh.example.com
  ```

- **Bind to All Interfaces**: Allow other machines to connect to your local port (use with caution):

  ```bash
  ssh -L 0.0.0.0:8080:webserver.local:80 user@ssh.example.com
  ```

- **Keep Alive**: Prevent the tunnel from timing out by adding keep-alive options:

  ```bash
  ssh -o ServerAliveInterval=60 -L 8080:webserver.local:80 user@ssh.example.com
  ```

## Practical Script

Create a script to set up a forward tunnel and verify it's running:

```bash
#!/bin/bash
# ssh_tunnel.sh

echo "Setting up SSH forward tunnel..."
ssh -f -N -L 8080:webserver.local:80 user@ssh.example.com

if [ $? -eq 0 ]; then
  echo "Tunnel established. Access the service at http://localhost:8080"
else
  echo "Failed to establish tunnel."
fi
```

Make it executable:

```bash
chmod +x ssh_tunnel.sh
./ssh_tunnel.sh
```

## Pro Tips

{{< callout type="tip" >}}
**Tip**: Use `autossh` for a more robust tunnel that automatically reconnects if the connection drops:

```bash
autossh -M 0 -f -N -L 8080:webserver.local:80 user@ssh.example.com
```

Install `autossh` with:
```bash
sudo apt install autossh  # Ubuntu/Debian
```
{{< /callout >}}

{{< callout type="warning" >}}
**Warning**: Be cautious when binding to `0.0.0.0`, as it exposes the port to all network interfaces, potentially allowing unauthorized access.
{{< /callout >}}

## Troubleshooting

- **Connection Refused**: Ensure the SSH server can reach the destination host and port.
- **Port Already in Use**: Check if the local port is already used (`netstat -tuln`) and choose another port.
- **Permission Denied**: Verify your SSH credentials or key-based authentication setup.
- **Tunnel Stops**: Use `-o ServerAliveInterval=60` to keep the connection alive or consider `autossh`.

## Next Steps

In future tutorials, we’ll explore:
- Reverse SSH tunneling for exposing local services.
- Dynamic tunneling with SOCKS proxy.
- Advanced SSH configurations with `~/.ssh/config`.

## Resources

- [OpenSSH Manual](https://www.openssh.com/manual.html)
- [SSH Tunneling Explained](https://www.ssh.com/academy/ssh/tunneling-example)

---

*Practice setting up tunnels with different services to master SSH forwarding!*