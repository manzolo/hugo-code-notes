---
title: "Network Traffic Analysis with Wireshark (Debian/Ubuntu)"
date: 2025-10-04T13:25:00+02:00
lastmod: 2025-10-04T13:25:00+02:00
draft: false
author: "Manzolo"
tags: ["wireshark", "network-analysis", "packet-capture", "troubleshooting", "security"]
categories: ["Networking & Security"]
series: ["Networking Fundamentals"]
weight: 5
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Network Traffic Analysis with Wireshark (Debian/Ubuntu)

## Introduction

Wireshark is a powerful open-source tool for capturing and analyzing network traffic, widely used for debugging network issues, monitoring traffic, and security analysis. This guide explains how to install Wireshark on Debian/Ubuntu, capture traffic on a network interface, apply filters, and analyze packets for common protocols like HTTP and TCP. It includes practical examples for troubleshooting connectivity, inspecting web traffic, and identifying bandwidth usage.

## What is Wireshark?

Wireshark is a packet analyzer that captures network packets in real-time or from saved files (PCAP format) and provides detailed insights into protocols, packet contents, and network behavior. Key features include:
- **Packet Capture**: Captures traffic on interfaces like `eth0` or `wlan0`.
- **Filters**: Allows filtering packets by protocol, IP, port, etc.
- **Analysis**: Displays packet details, statistics, and protocol hierarchies.
- **Use Cases**: Debug network issues, monitor HTTP requests, detect suspicious traffic.

## Prerequisites

- **Debian/Ubuntu**: Version 20.04+.
- **Root Access**: Use `sudo` for installation and packet capture.
- **Network Interface**: A network interface (e.g., `eth0`, `wlan0`) to capture traffic.
- **Tools**: `wireshark` (GUI or CLI with `tshark`), `tcpdump` (optional for comparison).
- **Internet Access**: Required for installing Wireshark.

Verify network interfaces:
```bash
ip link show
```
Example output:
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 ...
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
3: wlan0: <BROADCAST,MULTICAST> mtu 1500 ...
```

## Critical Warning: Security and Permissions

{{< callout type="warning" >}}
**Caution**: Capturing network traffic requires root privileges or Wireshark group membership and may expose sensitive data (e.g., passwords in unencrypted protocols). Use Wireshark responsibly, ensure legal compliance, and avoid capturing on public or unauthorized networks. Back up critical configurations before proceeding.
{{< /callout >}}

## How to Use Wireshark

### 1. Install Wireshark
Install Wireshark using `apt` and configure it to allow non-root users to capture packets.

```bash
sudo apt update
sudo apt install wireshark
```

During installation, you’ll be prompted to allow non-root users to capture packets. Select **Yes** to add users to the `wireshark` group, or run Wireshark as root (not recommended).

Add your user (e.g., `manzolo`) to the `wireshark` group:
```bash
sudo usermod -aG wireshark manzolo
```

Log out and back in to apply group changes. Verify:
```bash
groups | grep wireshark
```

Install `tshark` (CLI version) for terminal-based captures:
```bash
sudo apt install tshark
```

### 2. Identify Network Interfaces
List available network interfaces for capturing:
```bash
ip link show
```
Or with Wireshark’s CLI tool:
```bash
tshark -D
```
Example output:
```
1. eth0
2. wlan0
3. lo (Loopback)
```

**Note**: Use `eth0` for wired connections, `wlan0` for Wi-Fi, or `lo` for local traffic.

### 3. Capture Network Traffic
Start Wireshark’s GUI to capture packets:
```bash
wireshark &
```

1. In the Wireshark GUI, select an interface (e.g., `eth0`) and click **Start**.
2. Traffic will appear in real-time, showing packets with columns like Source, Destination, Protocol, and Info.

![Wireshark packet capture on eth0](/images/wireshark-capture.png "Wireshark capturing HTTP traffic on eth0")

Alternatively, use `tshark` for CLI capture:
```bash
tshark -i eth0
```
Example output:
```
Capturing on 'eth0'
1 0.000000 192.168.1.100 → 93.184.216.34 TCP 66 12345 → 80 [SYN] Seq=0 Win=64240 Len=0
2 0.001234 93.184.216.34 → 192.168.1.100 TCP 66 80 → 12345 [SYN, ACK] Seq=0 Ack=1 Win=65535 Len=0
```

Stop capture with `Ctrl+C` (CLI) or the Stop button (GUI).

### 4. Apply Filters
Wireshark supports **capture filters** (applied during capture) and **display filters** (applied to captured packets).

- **Capture Filter** (limits captured packets, e.g., only HTTP):
  ```bash
  tshark -i eth0 -f "tcp port 80"
  ```
  Or in Wireshark GUI: Enter `tcp port 80` in the capture filter field before starting.

- **Display Filter** (filters packets in GUI):
  - In the Wireshark GUI, enter a filter in the filter bar (e.g., `http` to show HTTP packets).
  - Common filters:
    - `ip.addr == 192.168.1.100`: Packets to/from an IP.
    - `tcp.port == 80`: TCP traffic on port 80 (HTTP).
    - `http.request`: HTTP requests only.

Example (filter HTTP requests in GUI):
```
http.request
```

### 5. Analyze Packets
Inspect packet details in Wireshark:
- **Packet List**: Shows summary (Source, Destination, Protocol).
- **Packet Details**: Expand protocols (e.g., TCP, HTTP) to view headers and payloads.
- **Packet Bytes**: Raw packet data in hex and ASCII.

Example: To analyze an HTTP request:
1. Apply filter `http.request`.
2. Select a packet and expand the HTTP section to view details (e.g., `GET /index.html HTTP/1.1`).

Save captured packets for later analysis:
```bash
tshark -i eth0 -w capture.pcap
```
Or in GUI: File → Save As.

### 6. Monitor Bandwidth Usage
Use Wireshark’s **Statistics** menu to analyze bandwidth:
- **Protocol Hierarchy**: Shows traffic distribution by protocol (Statistics → Protocol Hierarchy).
- **Conversations**: Lists top talkers by IP/port (Statistics → Conversations).

Example (CLI equivalent with `tshark`):
```bash
tshark -i eth0 -z conv,ip
```

## Examples

### Example 1: Install and Configure Wireshark
Install Wireshark and add user to the `wireshark` group:
```bash
sudo apt update
sudo apt install wireshark
sudo usermod -aG wireshark manzolo
groups | grep wireshark
```

**Output**:
```
manzolo wireshark
```

### Example 2: Capture HTTP Traffic
Capture HTTP traffic on `eth0` using `tshark`:
```bash
tshark -i eth0 -f "tcp port 80"
```

**Output**:
```
Capturing on 'eth0'
1 0.000000 192.168.1.100 → 93.184.216.34 HTTP 123 GET /index.html HTTP/1.1
2 0.001234 93.184.216.34 → 192.168.1.100 HTTP 456 HTTP/1.1 200 OK
```

In GUI:
1. Start Wireshark (`wireshark &`).
2. Select `eth0`, set capture filter `tcp port 80`, and start capture.
3. Apply display filter `http` to view HTTP packets.

### Example 3: Debug TCP Connection Issues
Capture TCP traffic to diagnose connection issues:
```bash
tshark -i eth0 -f "tcp port 22"
```

**Output** (showing failed SSH connection):
```
1 0.000000 192.168.1.100 → 192.168.1.10 TCP 66 12345 → 22 [SYN] Seq=0 Win=64240 Len=0
2 0.001234 192.168.1.10 → 192.168.1.100 TCP 66 22 → 12345 [RST, ACK] Seq=0 Ack=1 Win=0 Len=0
```

In GUI:
1. Start capture on `eth0`.
2. Apply display filter `tcp.port == 22 && tcp.flags.reset == 1` to find TCP resets.

### Example 4: Save and Analyze a Capture File
Save a capture and analyze later:
```bash
tshark -i eth0 -w capture.pcap
wireshark capture.pcap &
```

Apply a filter in Wireshark GUI (e.g., `ip.addr == 192.168.1.100`).

## Variants

### Using `tcpdump` for Lightweight Capture
If Wireshark is too heavy, use `tcpdump`:
```bash
sudo apt install tcpdump
sudo tcpdump -i eth0 -w capture.pcap
```

Open in Wireshark:
```bash
wireshark capture.pcap &
```

### Capturing on a Remote Server
Capture traffic remotely using SSH and `tshark`:
```bash
ssh user@remote-host "tshark -i eth0 -w -" > remote-capture.pcap
wireshark remote-capture.pcap &
```

### Analyzing Encrypted Traffic
If traffic is encrypted (e.g., HTTPS), configure Wireshark with SSL/TLS keys:
1. Export browser’s SSL key (e.g., `SSLKEYLOGFILE=/tmp/sslkey.log` in Firefox).
2. In Wireshark: Edit → Preferences → Protocols → TLS → Set (Pre)-Master-Secret log filename.

## Command Breakdown
- **ip link show**: Lists network interfaces.
- **tshark -D**: Lists capture interfaces.
- **wireshark**: Starts Wireshark GUI.
- **tshark -i <interface>**: Captures packets in CLI.
- **tshark -f "<filter>"**: Applies capture filters (e.g., `tcp port 80`).
- **tshark -w <file>**: Saves capture to a PCAP file.
- **apt install wireshark/tshark**: Installs Wireshark or CLI tool.
- **wireshark <file>**: Opens a PCAP file for analysis.

## Use Cases
- **Debugging Connectivity**: Identify TCP resets or dropped packets.
- **Web Traffic Monitoring**: Analyze HTTP requests/responses.
- **Security Analysis**: Detect suspicious traffic (e.g., port scans).
- **Bandwidth Analysis**: Identify top talkers or protocol usage.

## Pro Tips
- **Run as Non-Root**: Always add users to the `wireshark` group to avoid running as root.
- **Use Capture Filters**: Reduce captured data with filters (e.g., `tcp port 80`) to improve performance.
- **Save Captures**: Store PCAP files for later analysis or sharing.
- **Filter Shortcuts**: Use Wireshark’s autocomplete in the filter bar for quick filter creation.
- **Check Permissions**: Ensure the capture interface is accessible (e.g., `sudo chmod o+rw /dev/bpf*` for some systems).

## Troubleshooting
- **Wireshark Won’t Start Capture**: Verify user is in `wireshark` group or use `sudo`. Check `ip link show` for valid interfaces.
- **No Packets Captured**: Ensure the correct interface is selected and traffic is present (e.g., `ping 8.8.8.8`).
- **Permission Denied**: Run `sudo dpkg-reconfigure wireshark-common` and select Yes for non-root capture.
- **High CPU Usage**: Use capture filters to limit packets or switch to `tshark`.
- **Encrypted Traffic**: Configure SSL/TLS keys for HTTPS analysis.
- **Check Logs**: View `/var/log/syslog` or `journalctl -u wireshark` for errors.

## Resources
- [Wireshark User’s Guide](https://www.wireshark.org/docs/wsug_html_chunked/)
- [Ubuntu Networking Guide](https://ubuntu.com/server/docs/networking)
- [Tshark Man Page](https://www.wireshark.org/docs/man-pages/tshark.html)

---

*Analyze network traffic with Wireshark for effective debugging and monitoring on Debian/Ubuntu!*