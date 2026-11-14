---
title: "Network Traffic Analysis with Wireshark (Debian/Ubuntu)"
date: 2025-10-04T13:25:00+02:00
lastmod: 2026-11-14T20:00:00+01:00
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
description: "Capture wide, look narrow: the two filter languages, the permission trap, a refused connection, HTTPS decrypted with a key log, and a remote capture that does not capture itself"
---

# Network Traffic Analysis with Wireshark (Debian/Ubuntu)

{{< callout type="info" >}}
**Use case**: see what really travels on the wire - which request a program sends, why a connection fails, what a device talks to. Everything below was run on 2026-11-14 with Wireshark 4.2.2 on Ubuntu 24.04: outputs and screenshots come from that machine.
{{< /callout >}}

## 🧭 Two filter languages, and they are not the same

Wireshark has two kinds of filters, and most of the confusion comes from mixing them:

| | Capture filter | Display filter |
|---|---|---|
| Decides | what gets **recorded** | what you **see** of what was recorded |
| Language | BPF, the one of `tcpdump` | Wireshark's own |
| Example | `tcp port 80` | `tcp.port == 80` |
| Where | `tshark -f`, the field on the welcome screen | `tshark -Y`, the bar above the packet list |
| A mistake costs | packets lost forever | nothing: change the filter |

Hence the rule of thumb: **capture wide, look narrow**. When you are not sure what you are looking for, record more and filter the view.

The two look alike, so they get swapped. A capture filter typed into the display bar turns red and the status bar explains why:

![A capture filter in the display filter bar: red, with an error in the status bar](/images/wireshark-filter-wrong.png "port 80 is BPF: as a display filter it is invalid (\"80\" was unexpected in this context)")

![The same intent as a display filter: green](/images/wireshark-filter-right.png "tcp.port == 80 is the display-filter way to say it")

## 📦 Install, and the permission trap

```bash
sudo apt update
sudo apt install wireshark tshark
sudo usermod -aG wireshark $USER
```

Answer **Yes** when the installer asks whether non-superusers should be able to capture: capturing is then done by `dumpcap`, and only for members of the `wireshark` group.

The trap is that the group only counts **from the next login**. In the same session nothing changes:

```text
tshark: Couldn't run dumpcap in child process: Permission denied
0 packets captured
```

And the graphical Wireshark, started from a desktop session that predates the group, is even more misleading: no error at all, simply **no network interfaces** in the list, only the "remote capture" entries:

![Wireshark start screen with no network interfaces, only extcap entries](/images/wireshark-no-interfaces.png "Started from a session without the wireshark group: no interfaces, and no message")

Log out and back in (or reboot), then check:

```bash
id -nG | grep -w wireshark || echo "not yet: log out and back in"
tshark -D
```

If you answered **No** during the installation:

```bash
sudo dpkg-reconfigure wireshark-common
```

## 🎯 Capture

```bash
# Interface names are enp2s0, ens3, wlp3s0... on current systems, rarely eth0
ip -br link

# Capture filter (BPF): decides what gets recorded
tshark -i enp2s0 -f "tcp port 80" -w http.pcapng

# In another terminal, generate some traffic
curl -s -o /dev/null http://example.com/
```

`Ctrl+C` stops `tshark`. In the GUI, the same capture filter goes in the field of the start screen, before double-clicking the interface. Save the file (`-w`, or File → Save As): a capture you can reopen is worth more than one you watched scroll by.

## 🔎 What does the program actually send?

Reopen the capture with a display filter:

```bash
tshark -r http.pcapng -Y http.request
```

```text
    4 0.014939878 192.168.122.18 → 104.20.23.154 HTTP 140 GET / HTTP/1.1
```

In the GUI, select that packet and use **Analyze → Follow → TCP Stream** (`Ctrl+Alt+Shift+T`): Wireshark puts the whole conversation back together, request in red and answer in blue.

![Follow TCP Stream: the HTTP request and the server's answer](/images/wireshark-follow-stream.png "Follow TCP Stream: what curl sent, and what came back")

## 🚫 A refused connection looks like this

```bash
# Capture on loopback, then try a port where nothing listens
tshark -i lo -f "tcp port 81" -w rst.pcapng
curl http://localhost:81/        # curl: (7) Failed to connect

tshark -r rst.pcapng
```

```text
    3 0.000085535    127.0.0.1 → 127.0.0.1    TCP 74 35950 → 81 [SYN] Seq=0 Win=65495 Len=0 ...
    4 0.000098947    127.0.0.1 → 127.0.0.1    TCP 54 81 → 35950 [RST, ACK] Seq=1 Ack=1 Win=0 Len=0
```

`[SYN]` and then `[RST, ACK]` from the target: the host is reachable and **nothing is listening on that port**. Filter for it with `tcp.flags.reset == 1`:

![Packets with the RST flag in a refused connection](/images/wireshark-rst.png "tcp.flags.reset == 1: the target answers RST to every SYN")

When instead only `[SYN]` packets appear, repeated with growing intervals and never answered, something is **dropping** them on the way (a firewall, a wrong route): a different problem, and a different place to look.

## 🔐 HTTPS: decrypting your own traffic

TLS hides the content, but a client can be told to write down its session keys: with them Wireshark decrypts what **that client** sent and received. Nothing else.

```bash
# 1. Capture, and make the client write its session keys
tshark -i enp2s0 -f "tcp port 443" -w tls.pcapng
SSLKEYLOGFILE=$HOME/tls-keys.log curl -s -o /dev/null https://example.com/

# 2. Without the keys: only "Application Data"
tshark -r tls.pcapng -Y tls.app_data

# 3. With the keys: the HTTP inside
tshark -r tls.pcapng -o tls.keylog_file:$HOME/tls-keys.log -Y http

# The same in the GUI
wireshark -o tls.keylog_file:$HOME/tls-keys.log -r tls.pcapng
```

```text
   11 0.041216857 192.168.122.18 → 172.66.147.243 HTTP 162 GET / HTTP/1.1
   14 0.064270505 172.66.147.243 → 192.168.122.18 HTTP 93 HTTP/1.1 200 OK  (text/html)
```

![TLS traffic without the keys: Client Hello, then only Application Data](/images/wireshark-tls-encrypted.png "Without the keys: the SNI (example.com) is visible, the content is not")

![The same capture with the key log: GET and 200 OK in clear](/images/wireshark-tls-decrypted.png "With the key log: the HTTP inside, and a Decrypted TLS tab under the bytes")

`curl` honours `SSLKEYLOGFILE` (tested above); Firefox and Chromium-based browsers read the same variable when started from a terminal that sets it. In the GUI the setting lives in **Edit → Preferences → Protocols → TLS → (Pre)-Master-Secret log filename**.

{{< callout type="warning" >}}
**The key log decrypts everything recorded with it**, passwords and cookies included. Use it on your own traffic, keep it out of shared folders and delete it when done.
{{< /callout >}}

## 📊 Who talks to whom

```bash
tshark -r http.pcapng -q -z conv,ip
```

```text
================================================================================
IPv4 Conversations
Filter:<No Filter>
                                   |       <-      | |       ->      | |     Total     |
                                   | Frames  Bytes | | Frames  Bytes | | Frames  Bytes |
192.168.122.18 <-> 104.20.23.154        5 1271 bytes       7 544 bytes      12 1815 bytes
================================================================================
```

(Columns trimmed.) The `-q` matters: without it `tshark` first prints every packet and only then the statistics. In the GUI: **Statistics → Conversations** and **Statistics → Protocol Hierarchy**.

## 🛰️ Capturing on a remote machine

```bash
# On the remote host your user must be in the wireshark group:
# ssh has no terminal to type a sudo password into
ssh user@remote-host "tshark -i enp2s0 -f 'not port 22' -w -" > remote.pcapng
wireshark remote.pcapng
```

The `not port 22` is not optional. The capture travels back **inside the SSH session it is capturing**: every packet sent creates more packets to capture. In the test, 6 seconds on an almost idle link gave 42 packets, 40 of which were the SSH session itself; with the filter, 2.

## 🪤 Traps, in one table

| Symptom | Cause |
|---------|-------|
| No interfaces in the GUI, no error | Not yet in the `wireshark` group in this session: log out and back in |
| `Couldn't run dumpcap in child process: Permission denied` | Same cause, from `tshark` |
| Red filter bar, `"80" was unexpected in this context` | A capture filter (BPF) typed as a display filter |
| A remote capture that is mostly SSH | The capture's own transport: add `not port 22` |
| `-z conv,ip` floods the terminal | Missing `-q` |
| HTTPS shows only "Application Data" | No key log: `SSLKEYLOGFILE` on the client, then `tls.keylog_file` |
| `eth0` does not exist | Predictable interface names: `ip -br link` |

## 📚 Resources

- [Wireshark User's Guide](https://www.wireshark.org/docs/wsug_html_chunked/)
- [Display filter reference](https://www.wireshark.org/docs/dfref/)
- [pcap-filter(7)](https://www.tcpdump.org/manpages/pcap-filter.7.html) - the capture filter syntax
- [tshark man page](https://www.wireshark.org/docs/man-pages/tshark.html)
- [Network Traffic Analysis with tcpdump](/2025/10/network-traffic-analysis-with-tcpdump-debian/ubuntu/) - the same captures from the command line only
