---
title: "Network Traffic Analysis with tcpdump (Debian/Ubuntu)"
date: 2025-10-04T13:35:00+02:00
lastmod: 2025-10-04T13:35:00+02:00
draft: false
author: "Manzolo"
tags: ["tcpdump", "network-analysis", "packet-capture", "cli", "troubleshooting"]
categories: ["Networking & Security"]
series: ["Networking Fundamentals"]
weight: 6
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Network Traffic Analysis with tcpdump (Debian/Ubuntu)

## Introduction

`tcpdump` is a lightweight, command-line packet capture tool for analyzing network traffic on Linux systems. It’s ideal for server environments or quick diagnostics without a GUI, complementing tools like Wireshark. This guide covers installing `tcpdump` on Debian/Ubuntu, capturing traffic on a network interface, applying filters, saving captures to PCAP files, and analyzing them with `tcpdump` or Wireshark. It includes examples for monitoring HTTP traffic, debugging connectivity, and remote capturing.

## What is tcpdump?

`tcpdump` is a command-line packet analyzer that captures network packets in real-time or saves them to PCAP files for later analysis. Key features include:
- **Packet Capture**: Captures traffic on interfaces like `eth0` or `wlan0`.
- **Filters**: Supports Berkeley Packet Filter (BPF) syntax for filtering by protocol, IP, port, etc.
- **Output**: Displays packet summaries or saves to PCAP files compatible with Wireshark.
- **Use Cases**: Debug network issues, monitor specific protocols, or capture traffic for forensic analysis.

## Prerequisites

- **Debian/Ubuntu**: Version 20.04+.
- **Root Access**: Use `sudo` for capturing packets (required for promiscuous mode).
- **Network Interface**: A network interface (e.g., `eth0`, `wlan0`) to capture traffic.
- **Tools**: `tcpdump` (installable via `apt`), optionally `wireshark` for PCAP analysis.
- **Internet Access**: Required for installing `tcpdump`.

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
**Caution**: Capturing network traffic requires root privileges and may expose sensitive data (e.g., unencrypted passwords). Use `tcpdump` responsibly, ensure legal compliance, and avoid capturing on public or unauthorized networks. Back up critical configurations before proceeding.
{{< /callout >}}

## How to Use tcpdump

### 1. Install tcpdump
Install `tcpdump` using `apt`:
```bash
sudo apt update
sudo apt install tcpdump
```

Verify installation:
```bash
tcpdump --version
```
Example output:
```
tcpdump version 4.99.0
libpcap version 1.10.0
```

### 2. Identify Network Interfaces
List available network interfaces for capturing:
```bash
ip link show
```
Or with `tcpdump`:
```bash
tcpdump -D
```
Example output:
```
1.eth0 [Up, Running]
2.wlan0 [Up]
3.lo [Up, Running, Loopback]
```

**Note**: Use `eth0` for wired connections, `wlan0` for Wi-Fi, or `lo` for local traffic.

### 3. Capture Network Traffic
Capture packets on an interface (e.g., `eth0`):
```bash
sudo tcpdump -i eth0
```
![tcpdump capturing HTTP traffic on eth0](/images/tcpdump-capture.png "Output of sudo tcpdump -i eth0 port 80")
Example output:
```
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
13:30:01.123456 IP 192.168.1.100.12345 > 93.184.216.34.80: Flags [S], seq 123456789, win 64240, length 0
13:30:01.124567 IP 93.184.216.34.80 > 192.168.1.100.12345: Flags [S.], seq 987654321, ack 123456790, win 65535, length 0
```

Stop capture with `Ctrl+C`.

Increase verbosity for more details:
```bash
sudo tcpdump -i eth0 -v
```

### 4. Apply Filters
Use Berkeley Packet Filter (BPF) syntax to limit captured packets. Common filters:
- `port 80`: Capture HTTP traffic.
- `host 192.168.1.100`: Capture traffic to/from an IP.
- `tcp`: Capture only TCP packets.
- `dst 93.184.216.34`: Capture packets to a destination IP.

Example (capture HTTP traffic):
```bash
sudo tcpdump -i eth0 port 80
```
Example output:
```
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
13:30:02.123456 IP 192.168.1.100.12345 > 93.184.216.34.80: Flags [P.], seq 123456789, ack 987654321, win 64240, length 123: HTTP: GET /index.html HTTP/1.1
13:30:02.124567 IP 93.184.216.34.80 > 192.168.1.100.12345: Flags [P.], seq 987654321, ack 123456912, win 65535, length 456: HTTP: HTTP/1.1 200 OK
```

Combine filters (e.g., HTTP to a specific host):
```bash
sudo tcpdump -i eth0 host 192.168.1.100 and port 80
```

### 5. Save Captures to a PCAP File
Save captured packets for later analysis:
```bash
sudo tcpdump -i eth0 -w capture.pcap
```

Read a PCAP file:
```bash
sudo tcpdump -r capture.pcap
```

Analyze with Wireshark:
```bash
wireshark capture.pcap &
```

### 6. Analyze Captured Traffic
- **Basic Analysis**: Use `-v` or `-vv` for detailed packet information:
  ```bash
  sudo tcpdump -i eth0 -vv
  ```
- **Filter Saved PCAP**: Apply filters when reading:
  ```bash
  sudo tcpdump -r capture.pcap port 80
  ```
- **Statistics**: Count packets or summarize traffic:
  ```bash
  sudo tcpdump -i eth0 -c 100
  ```

Example (count 10 HTTP packets):
```bash
sudo tcpdump -i eth0 -c 10 port 80
```

## Examples

### Example 1: Install tcpdump
Install `tcpdump` and verify:
```bash
sudo apt update
sudo apt install tcpdump
tcpdump --version
```

**Output**:
```
tcpdump version 4.99.0
libpcap version 1.10.0
```

### Example 2: Capture HTTP Traffic
Capture HTTP traffic on `eth0`:
```bash
sudo tcpdump -i eth0 port 80
```

**Output**:
```
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
13:30:02.123456 IP 192.168.1.100.12345 > 93.184.216.34.80: Flags [P.], seq 123456789, ack 987654321, win 64240, length 123: HTTP: GET /index.html HTTP/1.1
13:30:02.124567 IP 93.184.216.34.80 > 192.168.1.100.12345: Flags [P.], seq 987654321, ack 123456912, win 65535, length 456: HTTP: HTTP/1.1 200 OK
```

### Example 3: Debug TCP Connection Issues
Capture TCP traffic for SSH (port 22) to diagnose issues:
```bash
sudo tcpdump -i eth0 port 22
```

**Output** (showing a failed connection):
```
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
13:30:03.123456 IP 192.168.1.100.12345 > 192.168.1.10.22: Flags [S], seq 123456789, win 64240, length 0
13:30:03.124567 IP 192.168.1.10.22 > 192.168.1.100.12345: Flags [R.], seq 0, ack 123456790, win 0, length 0
```

### Example 4: Save and Analyze a PCAP File
Save a capture and analyze it:
```bash
sudo tcpdump -i eth0 -w capture.pcap -c 100
sudo tcpdump -r capture.pcap port 80
```

Open in Wireshark:
```bash
wireshark capture.pcap &
```

## Variants

### Capturing on a Remote Server
Capture traffic remotely via SSH:
```bash
ssh user@remote-host "sudo tcpdump -i eth0 -w -" > remote-capture.pcap
```

Analyze locally:
```bash
tcpdump -r remote-capture.pcap
wireshark remote-capture.pcap &
```

### Capturing Specific Protocols
Capture only DNS traffic:
```bash
sudo tcpdump -i eth0 port 53
```

Capture ICMP (e.g., ping):
```bash
sudo tcpdump -i eth0 icmp
```

### Limiting Capture Size
Limit capture to 10 packets or specific size:
```bash
sudo tcpdump -i eth0 -c 10
sudo tcpdump -i eth0 -s 100  # Capture first 100 bytes of each packet
```

## Command Breakdown
- **ip link show**: Lists network interfaces.
- **tcpdump -D**: Lists capture interfaces.
- **tcpdump -i <interface>**: Captures packets on an interface.
- **tcpdump -w <file>**: Saves capture to a PCAP file.
- **tcpdump -r <file>**: Reads a PCAP file.
- **tcpdump -c <count>**: Limits capture to a number of packets.
- **tcpdump <filter>**: Applies BPF filters (e.g., `port 80`, `host 192.168.1.100`).
- **apt install tcpdump**: Installs `tcpdump`.

## Use Cases
- **Debugging Connectivity**: Identify TCP resets or dropped packets.
- **Web Traffic Monitoring**: Capture HTTP or HTTPS traffic.
- **Security Analysis**: Detect suspicious traffic (e.g., port scans).
- **Forensic Analysis**: Save captures for later analysis with Wireshark.

## Pro Tips
- **Run with sudo**: `tcpdump` requires root privileges for promiscuous mode.
- **Use Filters**: Apply BPF filters (e.g., `port 80`) to reduce captured data.
- **Save PCAPs**: Store captures for sharing or detailed analysis.
- **Verbose Output**: Use `-v` or `-vv` for more packet details.
- **Check Interface Status**: Ensure the interface is up with `ip link show`.

## Troubleshooting
- **No Packets Captured**: Verify the interface with `ip link show` and ensure traffic is present (e.g., `ping 8.8.8.8`).
- **Permission Denied**: Run with `sudo` or check interface permissions (`sudo chmod o+rw /dev/bpf*` if needed).
- **High CPU Usage**: Limit packets with `-c` or use specific filters.
- **Invalid Filter Syntax**: Check BPF syntax (e.g., `port 80` not `port=80`). Use `man tcpdump` for reference.
- **Check Logs**: View `/var/log/syslog` or `journalctl` for errors.

## Resources
- [tcpdump Man Page](https://www.tcpdump.org/manpages/tcpdump.1.html)
- [Ubuntu Networking Guide](https://ubuntu.com/server/docs/networking)
- [Wireshark PCAP Analysis](https://www.wireshark.org/docs/wsug_html_chunked/)

---

*Analyze network traffic efficiently with `tcpdump` on Debian/Ubuntu for quick diagnostics!*