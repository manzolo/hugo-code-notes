---
title: "Network Troubleshooting: A Layered Diagnostic Method"
date: 2026-09-18T12:00:00+02:00
lastmod: 2026-09-18T12:00:00+02:00
draft: false
author: "Manzolo"
tags: ["networking", "troubleshooting", "linux", "windows", "dns"]
categories: ["Networking & Security"]
series: ["Networking Fundamentals"]
weight: 10
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "A machine on the LAN does not answer, or half-answers: work out which layer is broken instead of trying commands at random"
---

# Network Troubleshooting: A Layered Diagnostic Method

{{< callout type="info" >}}
**Use case**: a machine on the LAN does not respond, or responds *halfway*. Instead of
trying commands at random, work out **which layer** the problem is actually on.
{{< /callout >}}

## 🧭 You diagnose from the bottom up

> **Cable, link, IP, gateway, DNS, port, application.** In that order.

Skipping a layer means attributing to DNS or to the firewall a problem that lives two
floors further down. This happens constantly, and for an understandable reason: the upper
layers produce readable error messages. *"Name resolution failed"* is a sentence you can
paste into a search engine. A cable with a crushed pair is silence. So the sentence gets
investigated and the silence does not.

The discipline is simple and slightly boring: **do not climb until the current layer has
given you a clear yes.** A "yes" at layer *n* is what makes a failure at layer *n+1* mean
something. Without it you are not diagnosing, you are guessing with a keyboard.

| # | Layer | The question it answers | If it fails, look at |
|---|-------|--------------------------|----------------------|
| 1 | **Link & interface** | Is there a physical connection, and a real address? | Cable, port, switch, DHCP |
| 2 | **Local reachability** | Is the machine alive on this segment? | ARP, duplicate IP, host firewall |
| 3 | **Routing & gateway** | Can packets leave the subnet and come back? | Route, netmask, VLAN |
| 4 | **DNS** | Does the name become the right address? | Resolver, zone, cache, suffix |
| 5 | **Ports & services** | Is the service listening, and reachable? | Service down, bind address |
| 6 | **Firewall & proxy** | Is something dropping or diverting it? | Host firewall, profile, proxy |
| 7 | **Traffic** | What is actually on the wire? | `tcpdump`, `curl`, `openssl` |

{{< callout type="info" >}}
**Conventions used throughout.** LAN `192.168.1.0/24`, gateway `192.168.1.1`. The machine
under diagnosis is **`workstation-01`** at `192.168.1.47`; we diagnose **from**
`192.168.1.10`. Internal server `192.168.1.20`; internal DNS `192.168.1.5` and
`192.168.1.6`. Public examples `203.0.113.10` and `198.51.100.25` (RFC 5737 documentation
ranges). Domains: `example.internal` inside, `example.com` outside.
{{< /callout >}}

{{< callout type="warning" >}}
**Before you run anything on this page**: `nmap` and `tcpdump` on networks you do not
administer can violate internal policy, and in some places rather more than policy. A port
scan is indistinguishable from reconnaissance to anyone watching, and a packet capture on a
shared segment sees other people's traffic. **Use them only on networks that are yours to
look after**, and when in doubt ask the person whose network it is first.
{{< /callout >}}

## 🔌 Layer 1 - Link and interface

Before anything else: does the machine really have a connection?

### Linux

```bash
ip -br link            # interface state, one line each
ip -br addr            # addresses, one line each
ethtool eth0           # speed, duplex, and "Link detected"
ip -s link show eth0   # error and drop counters
```

```text
$ ip -br link
lo               UNKNOWN        00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP>
eth0             UP             52:54:00:a1:b2:c3 <BROADCAST,MULTICAST,UP,LOWER_UP>

$ ethtool eth0
        Speed: 1000Mb/s
        Duplex: Full
        Link detected: yes
```

`Link detected: yes` is the layer-1 answer. Everything else on this page is meaningless
without it.

### Windows

```powershell
Get-NetAdapter | Format-Table Name, Status, LinkSpeed, MacAddress
Get-NetIPConfiguration
Get-NetAdapterStatistics
```

```batch
ipconfig /all
```

### 🚩 The four alarms at this layer

| Sign | What it means |
|------|---------------|
| Interface **DOWN** / `Link detected: no` | Cable, port or NIC. There is no network to debug yet |
| Address **`169.254.x.x`** (APIPA) | **DHCP failed.** Everything above this is noise |
| **100 Mbps** negotiated on a gigabit port | Damaged cable or port |
| `errors` / `dropped` **growing** in `ip -s link` | Physical: cable, connector, duplex mismatch |

The APIPA case deserves to be said bluntly: **`169.254.x.x` means the rest of the
diagnosis is noise.** The machine has no usable address, so it cannot reach the gateway,
cannot reach DNS and cannot be reached by you. Investigating name resolution on a host with
an APIPA address is time thrown away. Go and find out why DHCP did not answer.

The 100 Mbps case is the most-missed of the four, because *it works* - just badly. Fast
Ethernet uses two pairs, gigabit needs all four. **Break one pair and the link quietly
negotiates down to 100 Mbps instead of failing.** A crushed cable, a bent RJ45 pin, a patch
panel port never punched down properly: the symptom is not an outage, it is one machine
mysteriously ten times slower than its neighbours.

```bash
# Watch the counters move while the problem is happening
watch -n1 'ip -s link show eth0 | tail -4'
ethtool -S eth0 | grep -iE 'err|drop|crc'
```

### On the switch, if you can reach it

A managed switch settles arguments fast: **port state**, **negotiated speed**, and above
all **error counters** (CRC, runts, late collisions). CRC errors counted on the switch port
are cabling. Not a driver, not an OS, not a firewall - cabling.

## 📡 Layer 2 - Local reachability

The machine has a link and an address. Is it alive on this segment?

### ⚠️ The ping trap - read this before concluding anything

{{< callout type="warning" >}}
**A Windows machine that does not answer ping can be perfectly healthy.** Windows Defender
Firewall blocks inbound ICMP Echo Request by default, and especially on the **Public**
network profile. `Request timed out` is therefore **not** evidence that the host is down.

This is the most expensive false negative in network diagnosis. It sends people to the
server room to look at a machine that was running the whole time.
{{< /callout >}}

```bash
ping -c3 192.168.1.47
```

To make the target answer, when that is what you actually want:

```powershell
# Either enable the built-in rule...
Set-NetFirewallRule -Name FPS-ICMP4-ERQ-In -Enabled True
# ...or create an explicit one
New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4 `
    -IcmpType 8 -Direction Inbound -Action Allow
```

### ARP: the answer ping cannot give you

This is the decisive tool at this layer and it is badly underused. **ARP works below IP
filtering**: a host that drops your pings still has to answer ARP, or it could not use the
network at all. If there is a valid MAC entry for `192.168.1.47`, that machine is powered
on and present on the segment - whatever ping says.

```bash
ip neigh show 192.168.1.47
# 192.168.1.47 dev eth0 lladdr 52:54:00:a1:b2:c3 REACHABLE   <- it is there
# 192.168.1.47 dev eth0  FAILED                              <- nothing answered
```

```batch
:: Windows
arp -a 192.168.1.47
```

Force the question at layer 2, bypassing IP firewalls entirely:

```bash
sudo arping -I eth0 -c3 192.168.1.47
```

And to sweep the segment without depending on ICMP - on a local subnet `nmap -sn` uses
**ARP**, so it finds hosts that silently drop pings:

```bash
sudo nmap -sn 192.168.1.0/24
sudo arp-scan --localnet
```

### Duplicate IP, and why its symptoms are so hard to read

Two machines configured with `192.168.1.47` produce a failure unlike any other: it works,
then it does not, then it works again. **Intermittency with no pattern is the signature.**

The reason it reads so badly is that nothing is broken in any single component. Every ARP
cache on the segment holds whichever reply arrived last, and they do not all hold the same
one. So `192.168.1.10` may be talking to the real workstation while `192.168.1.20` talks to
the impostor, at the same moment, with both convinced they are right. Reboot something, or
let a cache expire, and the roles swap. Every test you run gives a different answer, which
looks like a flaky network and is in fact two machines answering to one name.

```bash
# Two replies, two different MACs, for one address = duplicate
$ sudo arping -I eth0 -c3 192.168.1.47
Unicast reply from 192.168.1.47 [52:54:00:A1:B2:C3]  0.641ms
Unicast reply from 192.168.1.47 [52:54:00:D4:E5:F6]  0.702ms   <- second owner
```

Corroborating evidence:

```bash
ip -s neigh show 192.168.1.47          # the entry keeps changing MAC
journalctl -k | grep -i 'duplicate address'
```

```powershell
# Windows logs the conflict explicitly: Tcpip event 4199
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Tcpip'; Id=4199} `
    -ErrorAction SilentlyContinue | Select-Object TimeCreated, Message
```

The usual cause is a static address handed out inside the DHCP pool. The fix belongs on the
DHCP server - shrink the pool, or turn it into a proper reservation - not on the two hosts.

### ✅ Criterion to climb

ARP resolves and the host is present on this segment. **Only now** does a failure to reach
something outside the subnet mean routing rather than a dead machine.

## 🚪 Layer 3 - Routing and gateway

```bash
ip route
ping -c3 192.168.1.1              # the gateway FIRST, before anything external
ip neigh show 192.168.1.1
traceroute 203.0.113.10
```

```powershell
Get-NetRoute -AddressFamily IPv4 | Format-Table DestinationPrefix, NextHop, RouteMetric
```

```batch
route print
tracert -d 203.0.113.10
```

```text
$ ip route
default via 192.168.1.1 dev eth0 proto dhcp metric 100
192.168.1.0/24 dev eth0 proto kernel scope link src 192.168.1.47
```

**Ping the gateway before you ping anything external.** If `192.168.1.1` does not answer,
every external test you run afterwards tells you the same thing twice and costs a minute each.

{{< callout type="info" >}}
**Why `tracert` on Windows feels broken**: by default it does a reverse DNS lookup on every
hop, so each one waits for a resolver that may itself be part of the problem. **`tracert -d`**
skips name resolution and returns in seconds. If you ever wondered why the Windows tool is
"so much slower than traceroute", that is the whole reason.
{{< /callout >}}

### mtr, and how to read it without fooling yourself

`traceroute` is a single snapshot. For intermittent problems it is close to useless: the
one run you did may have missed the loss entirely, or hit an unlucky second and shown loss
that is not there. **`mtr` keeps probing and gives you continuous statistics**, which is
what an intermittent fault actually needs.

```bash
mtr -rwc 100 203.0.113.10        # report mode, 100 cycles, wide output
```

```text
HOST                         Loss%   Snt   Last   Avg  Best  Wrst StDev
1. 192.168.1.1                0.0%   100    0.4   0.5   0.3   1.2   0.1
2. 203.0.113.1               18.0%   100    8.2   8.9   7.9  24.0   2.1     <- ignore this
3. 198.51.100.25              0.0%   100    9.1   9.4   8.8  19.2   1.6
4. 203.0.113.10               0.0%   100    9.3   9.7   9.0  21.4   1.8
```

{{< callout type="warning" >}}
**Loss on an intermediate hop, with clean hops after it, is not a problem.**

Many routers deprioritise or rate-limit ICMP addressed *to themselves*, because generating
those replies costs CPU that is better spent forwarding. So hop 2 above shows 18% loss
while hops 3 and 4 show none - which is impossible if hop 2 were really dropping traffic,
since everything to hops 3 and 4 goes *through* it.

**Only loss that persists all the way to the destination counts.** Reading intermediate-hop
loss as a fault is the most common way to blame the wrong network - usually somebody
else's, in an email you will regret.
{{< /callout >}}

### VLANs: same-looking subnet, different segment

If `192.168.1.47` and `192.168.1.10` are on different VLANs despite looking like the same
`/24`, their traffic goes through the router, and anything the router does not permit
simply does not happen.

The clean tell is at layer 2: **ARP does not cross a VLAN boundary.** So an `ip neigh`
entry that stays `FAILED` for a host that appears to be inside your own subnet means you
are not on the same segment as it, whatever the addressing suggests.

```bash
ip neigh show 192.168.1.47      # FAILED for an "on-link" host = different VLAN
traceroute -n 192.168.1.47      # a hop appearing at all proves it is being routed
```

A related classic is the wrong netmask: `192.168.1.47/25` treats `192.168.1.0-127` as local
and sends everything above `.127` to the gateway. Half the LAN works. Users call it flaky.

```bash
ip -br addr show eth0
# eth0  UP  192.168.1.47/25      <- and every neighbour is /24
```

### ✅ Criterion to climb

Default route present, gateway answering, destination reachable **by IP**. Now a failure by
*name* is a DNS question.

## 🌐 Layer 4 - DNS

> **Test by IP, then by name.** If `192.168.1.20` answers and
> `server.example.internal` does not, it is DNS - not "the network".
> If the IP also fails, it is not DNS. Go back down.

That single distinction resolves half of all cases, and it is the one people skip.

```bash
dig +short server.example.internal
dig @192.168.1.5 server.example.internal
dig @192.168.1.6 server.example.internal
dig +trace example.com
dig -x 192.168.1.47                     # reverse lookup
resolvectl status                       # which resolver is REALLY in use, per link
resolvectl flush-caches
```

```powershell
Resolve-DnsName server.example.internal -Server 192.168.1.5
Get-DnsClientServerAddress
```

```batch
nslookup server.example.internal 192.168.1.5
ipconfig /displaydns
ipconfig /flushdns
```

### 🚩 Query each resolver by hand

With `192.168.1.5` and `192.168.1.6` both configured, **one broken resolver produces
intermittent failure, not an outage**: the stack alternates and roughly half the lookups
work. Users describe it as "slow sometimes", which sounds like a performance problem and
is not one.

```bash
for ns in 192.168.1.5 192.168.1.6; do
    printf '%s -> ' "$ns"
    dig +short +time=2 +tries=1 @"$ns" server.example.internal || echo TIMEOUT
done
```

### 🚩 resolvectl status: the resolver you think you configured

On `systemd-resolved` the DNS server in `/etc/resolv.conf` is frequently **not** the one
being used. Resolution is per-link, VPNs and NetworkManager inject their own servers, and
`127.0.0.53` in `resolv.conf` tells you nothing about where queries end up.

```bash
resolvectl status | grep -A3 'Link.*eth0'
```

Check this **before** concluding that a DNS server is broken. It is routinely the answer to
"but I configured `192.168.1.5`, why is it asking someone else?"

### Search domains and suffixes

Why does `ping workstation-01` work while `ping workstation-01.example.internal` does not,
or the reverse?

- **Short name works, FQDN fails**: the short name is being answered by something other
  than DNS - `/etc/hosts`, a `hosts` file entry, LLMNR or NetBIOS on Windows. The FQDN goes
  to DNS proper, where the record is missing or wrong.
- **FQDN works, short name fails**: the **search suffix** is missing or wrong, so
  `workstation-01` never gets expanded to `workstation-01.example.internal`.

```bash
resolvectl status | grep -i 'search'
cat /etc/resolv.conf
```

```powershell
Get-DnsClient | Format-Table InterfaceAlias, ConnectionSpecificSuffix
Get-DnsClientGlobalSetting | Select-Object SuffixSearchList
```

And always check the override that beats every DNS tool, because it is invisible to all of
them and it is *always* something a human typed during an earlier troubleshooting session:

```bash
cat /etc/hosts
type C:\Windows\System32\drivers\etc\hosts
```

### ✅ Criterion to climb

The name resolves, from this machine, to the address you expect. Now: is anything listening?

## 🔉 Layer 5 - Ports and services

### On the machine itself

```bash
sudo ss -tulpn
sudo ss -lntp | grep ':3389'
```

```text
LISTEN 0 511 127.0.0.1:443 0.0.0.0:*  users:(("nginx",pid=1234,fd=6))
             ^^^^^^^^^
```

There it is, the classic: the service **is** running, and it is bound to **`127.0.0.1`**
instead of `0.0.0.0`, so it answers only from the machine itself. Locally everything works,
which is precisely why nobody suspects the server. From `192.168.1.10` you get a refusal,
and the ticket says *"the network is not working"* - while the network is fine and the
problem is one line of a config file.

```batch
netstat -ano | findstr :3389
```

```powershell
Get-NetTCPConnection -State Listen |
    Select-Object LocalAddress, LocalPort, OwningProcess
```

### From the client

```bash
nc -zv 192.168.1.47 3389
sudo nmap -Pn -p 3389 192.168.1.47
```

```powershell
Test-NetConnection 192.168.1.47 -Port 3389
# TcpTestSucceeded : True
```

`Test-NetConnection -Port` is far more useful than ping, because it tests **TCP** rather
than ICMP - the protocol your service actually uses, and the one that is not blocked by
default.

{{< callout type="warning" >}}
**`-Pn` is not optional when ICMP is filtered.** Without it, `nmap` pings the host first
and skips it entirely when there is no reply, reporting *"host seems down"* without ever
testing a single port. The layer-2 ping trap comes back to bite you here if you let it.
{{< /callout >}}

### 🚩 Refused and timeout are opposite diagnoses

This distinction is the whole point of this layer:

| Result | Packet | Meaning | Look at |
|--------|--------|---------|---------|
| **Connection refused** | An **RST** came back | The host is up and **answered**. Nothing is listening on that port | The **service**: stopped, crashed, bound to the wrong address |
| **Timeout / filtered** | **Nothing** came back | Something is **silently dropping** the packet | A **firewall**, on the host or in the path |

A refusal is good news: it proves layers 1 to 3 all the way up to the target's TCP stack. A
timeout proves only that someone is dropping traffic, and the interesting question becomes
*who* - which is layer 6.

### Ports worth knowing on a Windows workstation

| Port | Service | Typical symptom when blocked |
|------|---------|------------------------------|
| **445** | SMB | Shares and `\\workstation-01` unreachable |
| **3389** | RDP | Remote Desktop times out |
| **135** | RPC endpoint mapper | WMI, remote management, MMC consoles fail |
| **5985** | WinRM (HTTP) | `Enter-PSSession` / `Invoke-Command` fail |

## 🛡️ Layer 6 - Firewall and proxy

### Windows: check the profile before the rules

```powershell
Get-NetFirewallProfile | Format-Table Name, Enabled, DefaultInboundAction
Get-NetConnectionProfile                    # which profile is this network in?
Get-NetFirewallRule -Enabled True -Direction Inbound |
    Where-Object DisplayName -match 'Remote Desktop'
```

```batch
netsh advfirewall show allprofiles
```

{{< callout type="warning" >}}
**The network profile silently changes which rules apply.** A machine that moves from
*Private* to *Public* - after an update, a NIC change, a reboot where the domain controller
answered late - enforces a completely different rule set. Nobody edited a rule. Nobody
changed a firewall. And RDP stops working.

This is the cause of the case study below, and it is common enough to check early.
{{< /callout >}}

### Linux

```bash
sudo nft list ruleset
sudo iptables -L -n -v            # with counters: which rule is actually matching
sudo ufw status verbose
```

The `-v` in `iptables -L -n -v` matters: the packet counters tell you which rule is doing
the dropping, instead of leaving you to read the whole chain and reason about it.

### Proxy: the system one is not the browser one

```batch
netsh winhttp show proxy
```

```powershell
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' |
    Select-Object ProxyEnable, ProxyServer
```

**These are two different settings.** The browser uses the per-user WinINET configuration;
**Windows Update, the servicing stack and most services use WinHTTP**. So "the internet
works" - in the browser - while updates fail forever, and the two facts are consistent.

On Linux:

```bash
env | grep -i proxy
```

The subtle one here is **`no_proxy`**. Configured badly, it breaks *internal* traffic in a
way that looks like a DNS or routing fault: internal hosts get sent to the proxy, which has
no idea what `server.example.internal` is and refuses them.

```bash
# Internal destinations must bypass the proxy - note the leading dots and the CIDR
export no_proxy="localhost,127.0.0.1,.example.internal,192.168.1.0/24"
```

Remember that `no_proxy` matching is literal in many tools: `.example.internal` covers
subdomains, `example.internal` alone may not.

## 🔬 Layer 7 - Watch the actual traffic

When the previous layers have not settled it, stop reasoning and look.

```bash
sudo tcpdump -i eth0 host 192.168.1.47 -nn
sudo tcpdump -i eth0 port 445 -nn -w capture.pcap      # for Wireshark afterwards
```

`-nn` disables name resolution for both hosts and ports - faster, and it stops `tcpdump`
from depending on the DNS you may be debugging.

### Reading a failed TCP handshake

This is the payoff of capturing, and it distinguishes the two cases from layer 5 with
certainty rather than inference:

```text
# SYN with no SYN-ACK: dropped upstream, silently
10:14:02.113 IP 192.168.1.10.51234 > 192.168.1.47.3389: Flags [S], seq 1043...
10:14:03.115 IP 192.168.1.10.51234 > 192.168.1.47.3389: Flags [S], seq 1043...   <- retry
10:14:05.119 IP 192.168.1.10.51234 > 192.168.1.47.3389: Flags [S], seq 1043...   <- retry
```

```text
# SYN followed by RST: actively refused - the host answered
10:16:40.882 IP 192.168.1.10.51240 > 192.168.1.47.3389: Flags [S], seq 88213...
10:16:40.883 IP 192.168.1.47.3389 > 192.168.1.10.51240: Flags [R.], seq 0, ack ...
```

Retried SYNs with nothing coming back means a **firewall dropping**. A prompt RST means the
**host is fine and no service is listening**. Capturing on *both* ends tells you more still:
if the SYN arrives at `workstation-01` and the reply never reaches `192.168.1.10`, the drop
is on the return path, and you have just eliminated half the network.

On Windows there is a built-in equivalent:

```batch
pktmon filter add -i 192.168.1.47
pktmon start --capture
:: reproduce the problem, then
pktmon stop
pktmon etl2pcap PktMon.etl -o capture.pcap
```

### HTTP and TLS

```bash
curl -v https://server.example.internal/
curl -I https://server.example.internal/                 # headers only
curl -v --resolve server.example.internal:443:192.168.1.20 https://server.example.internal/
openssl s_client -connect 192.168.1.20:443 -servername server.example.internal </dev/null
```

The **`--resolve`** trick is the best single tool at this level: it points `curl` at a
specific IP while still sending the correct `Host` header and SNI. **If it works with
`--resolve` and fails without it, the server is fine and DNS is sending you elsewhere** -
which returns you to layer 4 holding proof instead of a suspicion.

## 📏 MTU problems, a section of their own

MTU deserves separate treatment because it produces the most deceptive symptoms in
networking: **ping works, SSH connects and then freezes, web pages load halfway.**

The mechanism: small packets pass, large ones do not. So every quick test succeeds and
every real transfer stalls. The connection is established - that part needs only small
packets - and then dies the moment something sends a full-size frame.

```bash
# 1472 payload + 8 ICMP + 20 IP = 1500. Do not fragment.
ping -M do -s 1472 -c2 203.0.113.10
```

```batch
ping -f -l 1472 203.0.113.10
```

### Finding the real MTU by bisection

If 1472 fails, halve your way down until it passes, then climb back:

```bash
for s in 1472 1400 1300 1200; do
    printf '%s: ' "$s"
    ping -M do -s "$s" -c1 -W2 203.0.113.10 >/dev/null 2>&1 && echo OK || echo FAIL
done
```

```text
1472: FAIL
1400: OK        <- narrow between 1400 and 1472 from here
```

**The real MTU is the largest payload that passes, plus 28** (20 bytes of IP header plus 8
of ICMP). A largest good payload of 1422 means an MTU of 1450 - a very typical figure for a
tunnel.

Typical causes:

| Cause | Typical MTU |
|-------|-------------|
| PPPoE (DSL) | 1492 |
| IPsec / OpenVPN tunnel | 1400-1450 |
| WireGuard | 1420 |
| GRE | 1476 |

And the one that turns a small inconvenience into a mystery: **Path MTU Discovery broken by
a firewall that drops ICMP**. PMTUD works by having a router return
*"fragmentation needed"* (ICMP type 3, code 4) when a packet is too big. An administrator
who blocks "all ICMP" for security kills that message - so the sender never learns to send
smaller packets and simply retransmits the same oversized frame forever. The connection
hangs instead of adapting.

```bash
tracepath 203.0.113.10          # reports the pmtu where it changes
```

If you suspect this, check that ICMP type 3 code 4 is permitted before you start lowering
MTUs by hand everywhere.

## 🧪 Case study: RDP to workstation-01 times out

`192.168.1.47` is unreachable over RDP from `192.168.1.10`. Walking the layers in order.

### 1. Ping fails

```text
C:\> ping 192.168.1.47
Request timed out.
```

**Learned: nothing.** Inconclusive by construction - ICMP may be filtered, and on Windows
it usually is. The temptation here is to declare the machine down and walk to it. Resisted.

### 2. ARP shows a valid entry

```text
C:\> arp -a 192.168.1.47
  Internet Address      Physical Address      Type
  192.168.1.47          52-54-00-a1-b2-c3     dynamic
```

**Learned: the machine is alive and on this segment.** A valid MAC entry cannot exist for a
powered-off host. Layer 2 is a clear yes, layer 1 is implicitly a yes too. Climb.

### 3. Port 3389 times out - and does not refuse

```text
PS> Test-NetConnection 192.168.1.47 -Port 3389
WARNING: TCP connect to (192.168.1.47 : 3389) failed
TcpTestSucceeded : False
```

The distinction from layer 5 decides the rest of the investigation: **timeout, not
refused.** Nothing came back at all. If RDP had merely been stopped, the host would have
answered with an RST and we would have got a refusal in milliseconds. Something is
**dropping** the packets.

### 💀 The hypothesis that died here

At this point the reasonable theory was **an ACL on the router**: a maintenance window had
touched the network gear the previous night, a timeout is exactly what a router ACL
produces, and the two machines are on different VLANs. It fits stage 3 perfectly.

It was tested and it died: `Test-NetConnection 192.168.1.20 -Port 3389` from the same
client succeeded, on the same VLAN path. **The path permits 3389.** So the drop is at the
destination, not between us. Worth recording, because it was the right theory to have and
checking it cost thirty seconds - while acting on it would have meant opening a ticket with
the network team and waiting a day for an answer we already had.

### 4. On the machine: the service is listening

```text
C:\> netstat -ano | findstr :3389
  TCP    0.0.0.0:3389      0.0.0.0:0      LISTENING     1288
```

**Learned: the service is up and bound to `0.0.0.0`**, not to loopback. So RDP itself is
healthy and the packets are being discarded before they reach it. That leaves exactly one
layer: the host firewall.

### 5. The network profile flipped to Public

```text
PS> Get-NetConnectionProfile
Name             : Network 3
NetworkCategory  : Public

PS> Get-NetFirewallRule -DisplayGroup "Remote Desktop" |
      Select-Object DisplayName, Enabled, Profile
DisplayName                          Enabled  Profile
-----------                          -------  -------
Remote Desktop - User Mode (TCP-In)  True     Domain, Private
```

**There it is.** After an update the machine came up before the domain controller answered,
the network was categorised as **Public**, and the RDP rules apply to **Domain, Private**
only. Nobody changed a firewall rule. The rule is enabled, correct, and simply does not
apply to the profile the machine is now in.

```powershell
# Put the network back in the right category
Set-NetConnectionProfile -InterfaceAlias 'Ethernet' -NetworkCategory Private
```

Five steps, no reboots, no reinstalls, and the one hypothesis that felt most likely at
stage 3 was wrong - which is the normal shape of a diagnosis, not a failure of one.

## 📊 Symptom → layer → first command

| Symptom | Probable layer | First command |
|---------|---------------|---------------|
| No link at all | 1 | `ethtool eth0` / `Get-NetAdapter` |
| Address `169.254.x.x` (APIPA) | 1 | `journalctl -u NetworkManager` / `ipconfig /all` |
| Ping fails but ARP entry present | 2 / 6 | `ip neigh show 192.168.1.47` |
| No pattern, works then does not | 2 | `arping -I eth0 -c3 192.168.1.47` |
| Gateway unreachable | 3 | `ip route` + `ping 192.168.1.1` |
| Reaches half the LAN | 3 | `ip -br addr show eth0` (check the prefix) |
| Works by IP, fails by name | 4 | `dig @192.168.1.5 server.example.internal` |
| Fails about half the time, by name | 4 | Query `192.168.1.5` and `192.168.1.6` separately |
| **Connection refused** | 5 | `ss -lntp` on the target |
| **Timeout** | 6 | `Get-NetConnectionProfile` / `nft list ruleset` |
| Connects, then freezes | MTU | `ping -M do -s 1472 203.0.113.10` |
| Intermittent slowness | 1 / 3 | `ethtool eth0`, then `mtr -rwc 100` |
| Browser fine, updates fail | 6 | `netsh winhttp show proxy` |

## 🔀 Linux ↔ Windows command equivalents

Because you end up working on both, usually within the same hour.

| Task | Linux | Windows |
|------|-------|---------|
| Addresses | `ip -br addr` | `ipconfig /all` · `Get-NetIPConfiguration` |
| Interfaces | `ip -br link` · `ethtool eth0` | `Get-NetAdapter` |
| Routing table | `ip route` | `route print` · `Get-NetRoute` |
| ARP table | `ip neigh` | `arp -a` · `Get-NetNeighbor` |
| Listening sockets | `ss -tulpn` | `netstat -ano` · `Get-NetTCPConnection` |
| DNS query | `dig`, `resolvectl query` | `nslookup` · `Resolve-DnsName` |
| Flush DNS cache | `resolvectl flush-caches` | `ipconfig /flushdns` |
| Trace the path | `traceroute` · `mtr` | `tracert -d` · `pathping` |
| Test a TCP port | `nc -zv host port` | `Test-NetConnection host -Port n` |
| Packet capture | `tcpdump -i eth0 -nn` | `pktmon` (→ `etl2pcap`) |
| Firewall rules | `nft list ruleset` · `ufw status` | `netsh advfirewall show allprofiles` |
| System proxy | `env \| grep -i proxy` | `netsh winhttp show proxy` |

## ✅ The reusable checklist

1. **Link** - `ethtool` / `Get-NetAdapter`. `Link detected: yes`? APIPA means stop: fix DHCP.
2. **Local** - `ip neigh` / `arp -a`, **not** ping. Silence from ping is not evidence of death.
3. **Gateway** - ping `192.168.1.1` before anything external. Check the netmask against the
   neighbours'.
4. **DNS** - only after the IP is proven, and query **each** resolver by hand. `resolvectl
   status` to see which one is really used.
5. **Port** - `ss -tulpn` on the target, `Test-NetConnection` from the client. **Refused**
   (service) and **timeout** (firewall) are opposite diagnoses.
6. **Firewall & proxy** - the **profile** before the rules; WinHTTP proxy, not the browser's.
7. **Capture** - `tcpdump -nn`. Retried SYNs = dropped; SYN then RST = refused. Capture both
   ends if you can.
8. **Freezes rather than fails?** Suspect MTU and test with `ping -M do` before anything else.
9. **Write down which layer it turned out to be.** After a few months that list tells you
   where your network actually breaks, which is rarely where you assume.

---

**Related:**
- [Windows System Repair and Maintenance](/2025/10/windows-system-repair-and-maintenance/)
- [Network Traffic Analysis with tcpdump](/2025/10/network-traffic-analysis-with-tcpdump-debian/) - layer 7, in depth
- [Network Traffic Analysis with Wireshark](/2025/10/network-traffic-analysis-with-wireshark-debian/)

---

*Every layer you skip is a layer you will end up blaming.*
