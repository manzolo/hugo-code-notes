---
title: "Reading Windows Logs: From Error Code to Root Cause"
date: 2026-09-18T11:00:00+02:00
lastmod: 2026-11-14T21:00:00+01:00
draft: true
author: "Manzolo"
tags: ["windows", "logs", "troubleshooting", "dism", "sfc", "quick-tip"]
categories: ["Quick Pills"]
series: ["Quick Pills Collection"]
weight: 9
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "When SFC, DISM or Windows Update fail with a generic message, follow the log chain instead of running the same command again"
---

# 💊 Quick Pill: Reading Windows Logs

{{< callout type="info" >}}
**Use case**: SFC, DISM or Windows Update failed with a message that explains nothing.
Instead of running the same commands again and hoping for a different result, find out
what actually broke.
{{< /callout >}}

## 🧭 The tool that reports the error is not the tool that explains it

This is the whole idea of this page, and it is worth stating plainly:

> **The layer that shows you the error is almost never the layer that knows the cause.**

DISM tells you `Error: 605`. DISM does not know what 605 means in your case - it caught a
failure from the servicing stack and printed the number. The servicing stack wrote the
reason into `CBS.log`, one floor down. SFC tells you it *"could not perform the requested
operation"*, which is the message it prints for every reason there is.

So the method is a **chain**, and it only works in order:

```
error code  ->  decode the code  ->  log of the tool  ->  log of the cause  ->  timestamp  ->  Event Viewer  ->  hardware
```

Skipping a link is how people end up reinstalling Windows to fix a dying SATA cable.

## 🔢 Decode the code before you open any log

Half the time the code alone narrows the problem down to a family, and that decides which
log is worth opening. You do not need to install anything.

### certutil -error - the tool nobody uses

`certutil` ships with every Windows and translates any error code, whatever family it
belongs to:

```batch
certutil -error 0x8007025d
```

```text
0x8007025d (WIN32: 605 ERROR_BAD_COMPRESSION_BUFFER) -- 2147943005 (-2147024291)
Error message text: The specified buffer contains ill-formed data.
```

```batch
certutil -error 0xc0000242
```

```text
0xc0000242 (NT: 0xc0000242 STATUS_BAD_COMPRESSION_BUFFER) -- 3221226050 (-1073741246)
Error message text: The specified buffer contains ill-formed data.
```

*(output abridged - `certutil` also prints a trailing success line)*

It takes hex or decimal, it works offline, and it handles HRESULT, Win32 and NTSTATUS
without being told which one you gave it. There is no reason to paste an error code into
a search engine before running this.

### Anatomy of an HRESULT

An HRESULT is not an opaque number: it is three fields packed into 32 bits.

```
0x8007025D
  │ │  └─────  code:      0x025D = 605      <- the classic Win32 error
  │ └────────  facility:  0x007            <- FACILITY_WIN32
  └──────────  severity:  1                <- failure
```

Which gives you a rule you can apply by eye: **anything shaped `0x8007XXXX` is a plain
Win32 error wearing a costume.** Take the last four hex digits and you have the number
that `net helpmsg` understands.

```powershell
# Pull the Win32 code out of an 0x8007 HRESULT
$hr = 0x8007025D
'{0:X8} -> Win32 {1} (0x{1:X})' -f $hr, ($hr -band 0xFFFF)
# 8007025D -> Win32 605 (0x25D)
```

```batch
net helpmsg 605
:: The specified buffer contains ill-formed data.
```

### The families worth recognising on sight

| Shape | Family | Who produced it |
|-------|--------|-----------------|
| `0x8007XXXX` | HRESULT, `FACILITY_WIN32` | A Win32 API call failed - strip to the last 4 digits |
| `0x800FXXXX` | HRESULT, `FACILITY_SETUPAPI` | Servicing / CBS - e.g. `0x800F081F` "source files not found" |
| `0x8024XXXX` | Windows Update agent | `wuauserv` itself: policy, WSUS, proxy, download |
| `0xC000XXXX` | **NTSTATUS** | Kernel, drivers, I/O. Much closer to the hardware |

That last row matters more than the others. An **NTSTATUS** in a servicing log means the
failure did not happen in Windows' logic, it happened while the kernel was talking to a
device or to memory. These are the ones worth knowing:

| NTSTATUS | Name | What it usually means |
|----------|------|-----------------------|
| `0xC0000005` | `STATUS_ACCESS_VIOLATION` | Bad pointer - software bug, or RAM |
| `0xC000009C` | `STATUS_DEVICE_DATA_ERROR` | **Unreadable sector.** Hardware until proven otherwise |
| `0xC000009D` | `STATUS_DEVICE_NOT_CONNECTED` | The device dropped off the bus |
| `0xC0000102` | `STATUS_FILE_CORRUPT_ERROR` | The filesystem says the file is structurally wrong |
| `0xC0000185` | `STATUS_IO_DEVICE_ERROR` | I/O error - cable, controller, disk |
| `0xC0000242` | `STATUS_BAD_COMPRESSION_BUFFER` | Compressed data that will not decompress |

### Err.exe, for when you want every answer at once

Microsoft's **Err.exe** (the "Error Code Look-up" tool, a free download from Microsoft: it is not part of Windows) is a single portable executable
that greps every Windows header file for a value and shows *all* the symbolic names it
matches, across families:

```batch
err.exe 0xc0000242
```

Useful precisely because a bare number can exist in more than one family: `certutil` picks
one interpretation, `err.exe` shows you all of them and lets you choose the one that fits
the context.

## 🔗 The log chain: which log for which tool

| Tool | Log | What you will find there |
|------|-----|--------------------------|
| **SFC** | `C:\Windows\Logs\CBS\CBS.log` | `[SR]` lines, `Cannot repair member file`, the file names |
| **DISM** | `C:\Windows\Logs\DISM\dism.log` | **That** something failed, and where in DISM - rarely why |
| **DISM (the actual cause)** | `C:\Windows\Logs\CBS\CBS.log` | The component, the file, the underlying NTSTATUS |
| **Windows Update** | `C:\Windows\Logs\WindowsUpdate\*.etl` | Binary traces - read via `Get-WindowsUpdateLog` |
| **Feature update / setup** | `C:\$WINDOWS.~BT\Sources\Panther\setuperr.log` | Why the upgrade rolled back (`C:\Windows\Panther\` once installed) |
| **Drivers** | `C:\Windows\INF\setupapi.dev.log` | Driver install and enumeration, device by device |
| **Hardware / system** | Event Viewer, `System` log | Disk, NTFS, controller, power - the physical layer |

{{< callout type="info" >}}
**The row that surprises people is the third one.** `dism.log` is a log of DISM, not a log
of the repair: it faithfully records that a step returned an error and which internal
function was executing. The reason lives in `CBS.log`, because the component-based
servicing stack is what actually touches the files. Open both, always in that order.
{{< /callout >}}

Two practical notes on Windows Update:

```powershell
# Convert the ETL traces into a readable WindowsUpdate.log
Get-WindowsUpdateLog -LogPath "$env:userprofile\Desktop\WindowsUpdate.log"
```

and on CBS: the live file is `CBS.log`, but once it grows past its limit Windows rotates
it into `CbsPersist_<timestamp>.cab` **in the same folder**. If your failure is from last
week, it is inside one of those cabs, not in `CBS.log`.

## 🔎 Filtering a 100 MB log

`CBS.log` routinely passes 100 MB. Opening it in Notepad and scrolling is not a technique.

### The blunt filters

```batch
:: The SFC verdict lines, and the files it gave up on
findstr /c:"[SR]" /c:"Cannot repair" %windir%\Logs\CBS\CBS.log > "%userprofile%\Desktop\sfc.txt"

:: Every failure line: CBS marks them with (F)
findstr /c:"(F)" %windir%\Logs\CBS\CBS.log > "%userprofile%\Desktop\cbs-failures.txt"
```

`(F)` is the CBS severity marker for *failure*, and grepping for it turns a 100 MB file
into something you can actually read. Its companions are `(E)` for error and `(W)` for
warning.

### Context is where the file name hides

The line that contains the error code usually does **not** contain the file name: that is
on the line before, or two after. Grepping without context throws away the answer.

```powershell
# Six lines before and six after every hit
Select-String -Path $env:windir\Logs\CBS\CBS.log -Pattern 'c0000242' -Context 6,6
```

```powershell
# Only the failure lines, with what led to them
Select-String -Path $env:windir\Logs\CBS\CBS.log -Pattern '\(F\)' -Context 3,1 |
    Select-Object -Last 20
```

### Anchor on the clock - the trick that saves the most time

This is the single highest-return habit in this whole page. **Note the wall-clock time
when the error appeared on screen**, then read that minute of the log in full, instead of
searching for words you are guessing at.

```powershell
# You saw the failure at 14:52. Read that minute, whole, from both logs.
$when = '2026-09-18 14:5'
Select-String -Path $env:windir\Logs\DISM\dism.log -Pattern $when
Select-String -Path $env:windir\Logs\CBS\CBS.log  -Pattern $when
```

It works because every one of these logs is timestamped line by line, and because the real
cause is always written **within a second or two** of the symptom you saw. Searching by
keyword makes you guess the vocabulary of a component you have never read. Searching by
time requires you to know only what you already know: when it happened.

The same anchor then carries you into Event Viewer, which is the point of the next section.

```batch
:: More detail from DISM next time round
Dism /Online /Cleanup-Image /ScanHealth /LogLevel:4
```

## 📟 Event Viewer from the command line

The GUI is fine for browsing and terrible for correlating. From PowerShell you can ask the
question you actually have.

### Everything the storage stack said this week

```powershell
Get-WinEvent -FilterHashtable @{
    LogName      = 'System'
    ProviderName = 'disk','Ntfs','volmgr','storahci','stornvme'
    StartTime    = (Get-Date).AddDays(-7)
} -ErrorAction SilentlyContinue |
    Format-Table TimeCreated, Id, ProviderName, Message -AutoSize -Wrap
```

`-ErrorAction SilentlyContinue` is not decoration: `Get-WinEvent` writes an error
(`No events were found that match the specified selection criteria`) when a filter matches
nothing, which reads like a broken command rather than good news. It is a non-terminating
error: the script goes on anyway, and this option simply keeps the red text off the screen.

### The same five minutes as your failure

```powershell
Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    StartTime = Get-Date '2026-09-18 14:50'
    EndTime   = Get-Date '2026-09-18 14:55'
} -ErrorAction SilentlyContinue | Sort-Object TimeCreated
```

If a `disk` or `Ntfs` event lands inside the minute where DISM failed, you are done
guessing: the servicing error is a symptom and the disk is the story.

### Storage events worth knowing by number

| Source | ID | Meaning |
|--------|-----|---------|
| `disk` | **7** | *"The device has a bad block."* Unreadable sector |
| `disk` | **51** | Error during a **paging operation** - I/O failed on the boot disk |
| `disk` | **153** | The I/O was **retried**. Early warning: a drive on its way out |
| `Ntfs` | **55** | Filesystem structure corrupt - run `chkdsk` |
| `Ntfs` | **98** | Volume **metadata** corruption detected |
| `Ntfs` | **137 / 140** | Failed to flush the transaction log - corruption may follow |
| `storahci` | **129** | *"Reset to device ... was issued."* The controller lost patience with the drive |
| `volmgr` | **46** | Crash dump initialisation failed |

### Export and quick overview

```batch
:: The last 20 disk events, newest first, as text
wevtutil qe System /q:"*[System[Provider[@Name='disk']]]" /c:20 /rd:true /f:text

:: The whole System log, to analyse elsewhere
wevtutil epl System "%userprofile%\Desktop\system.evtx"
```

```batch
:: Reliability Monitor - a chronological, human view of what broke and when
perfmon /rel
```

![Reliability Monitor: stability index and the events of each day](/images/win-reliability-monitor.png "perfmon /rel on Windows 11 (Italian interface): one column per day, details of the selected day below")

`perfmon /rel` deserves more affection than it gets: it is the fastest way to answer
*"did this start on a particular day?"*, and a cluster of failures appearing on the same
date is frequently the whole diagnosis.

## 🕳️ False negatives: when a log lies by omission

**This is the most important section on this page.**

A log can tell you everything is fine because **the check never reached the end**. The
summary block is written regardless; it summarises what was examined, not what exists. If
the scan aborted at 92%, the summary honestly reports zero problems found in the part it
managed to look at - and a reader who only reads the summary concludes the system is healthy.

Here is the shape of the trap, taken from a real `CBS.log`:

```text
2026-09-18 14:52:07, Error  CSI  (F) base\wcp\sil\merged\ntu\ntsystem.cpp(3674):
    Error c0000242 originated in function DirectFileSystemProvider::SysReadFile
...
Summary:
Operation: Detect only
Operation result: 0x0
Last Successful Step: Entire operation completes.
Total Detected Corruption: 0
    CBS Manifest Corruption: 0
    CBS Payload Corruption: 0
```

`Total Detected Corruption: 0`, a few lines after the scan blew up on an unreadable file.
Both statements are true. Only one of them is an answer.

**So: always verify that the operation terminated, not just what it concluded.**

```powershell
# 1. Did anything abort? Look BEFORE you trust the summary
Select-String -Path $env:windir\Logs\CBS\CBS.log `
    -Pattern 'c0000|\(F\)|Failed to|abort' | Select-Object -Last 20

# 2. Only then read the verdict
Select-String -Path $env:windir\Logs\CBS\CBS.log `
    -Pattern 'Last Successful Step|Total Detected Corruption|Operation result' |
    Select-Object -Last 10
```

The field to read is **`Last Successful Step`**. If it does not say
*"Entire operation completes"*, every zero underneath it is meaningless.

{{< callout type="warning" >}}
**The general rule**: a clean result is only as good as the coverage of the scan that
produced it. Before believing a green verdict, ask how much of what it was supposed to
examine it actually reached. This applies far beyond Windows.
{{< /callout >}}

## 🧪 Case study: SFC stops at 48%

A real chain, stage by stage - including the hypothesis that turned out to be wrong,
because discarding hypotheses is the method, not a detour from it.

### Stage 1 - the symptom

```text
sfc /scannow
Beginning system scan. This process will take some time.
Beginning verification phase of system scan.
Verification 48% complete.
Windows Resource Protection could not perform the requested operation.
```

**Learned:** nothing yet. That message is SFC's universal failure string. It does not even
tell you whether the problem is a file, the store, or the disk underneath.
**Next:** check the component store, since SFC repairs *from* it.

### Stage 2 - the false all-clear

```text
Dism /Online /Cleanup-Image /CheckHealth
No component store corruption detected.
The operation completed successfully.
```

**Learned:** still nothing - and nearly went the wrong way here. `CheckHealth` **does not
scan**: it reports whether a *previous* operation flagged the image. On a machine that was
never scanned it always says this. Taken at face value it says "the store is fine, so the
problem is elsewhere", and sends you off to reinstall drivers.
**Next:** a scan that actually scans.

### Stage 3 - finally, a code

```text
Dism /Online /Cleanup-Image /ScanHealth
[==========================92.4%=====     ]
Error: 605
The operation could not be completed due to an unspecified error.
```

**Learned:** something concrete at last. `certutil -error 0x8007025D` (the HRESULT form of
605) returns `ERROR_BAD_COMPRESSION_BUFFER`. Also note **92.4%**: the scan did not finish,
so any "corruption: 0" printed afterwards is worthless.
**Next:** DISM's own log, for where it died.

### Stage 4 - dism.log: where, not why

```text
2026-09-18 14:52:07, Error  DISM  DISM Provider Store: PID=6104 TID=7220
    Failed to get the IDismObject Interface - CDISMProviderStore::Internal_Finalize
    HRESULT=0x8007025D
2026-09-18 14:52:08, Info   DISM  DISM.EXE: Reboot Required=no
```

**Learned:** two useful things.
1. The failure surfaced in `Internal_Finalize`, i.e. DISM caught it on the way out -
   the error came from below, not from DISM itself.
2. **`Reboot Required=no`** kills a whole family of hypotheses: this is not a pending
   servicing operation waiting for a restart. Rebooting will not help. Do not reboot
   three times "just in case".

**Still unknown:** which file. `dism.log` never names it.
**Next:** the floor below.

### 💀 The hypothesis that died here

At this point the reasonable theory was **network**: `ERROR_BAD_COMPRESSION_BUFFER` on a
servicing operation looks a lot like a corporate proxy or an antivirus mangling the
compressed payloads that Windows Update serves. It fits stage 3 perfectly, it is a common
real cause, and it suggests an easy test (`/LimitAccess` with a local `install.wim`).

It was wrong - and stage 5 is what killed it. Worth recording, because a plausible theory
that survives four stages and dies at the fifth is exactly what the chain is *for*.

### Stage 5 - CBS.log: the actual cause

```text
2026-09-18 14:52:07, Info   CSI  00000a31 Direct SIL provider: failed to read file.
2026-09-18 14:52:07, Error  CSI  00000a32 (F) base\wcp\sil\merged\ntu\ntsystem.cpp(3674):
    Error c0000242 [Error,Facility=(system),Code=578 (0x0242)]
    originated in function DirectFileSystemProvider::SysReadFile expression: (null)
```

**Learned - and this is the payoff:**

- `c0000242` is `STATUS_BAD_COMPRESSION_BUFFER`, the **NTSTATUS** twin of the `605`
  DISM printed. They are the same fact at two altitudes: the kernel said `0xC0000242`,
  the servicing stack translated it to Win32 `605` and wrapped it as `0x8007025D`. Only
  the lower one carries the information that matters.
- `DirectFileSystemProvider::SysReadFile` is a **read**. A `ReadFile` on a local file, on
  compressed data, that came back with garbage.
- **Therefore the proxy theory is dead.** Nothing was being downloaded. The failure is
  between the filesystem and the platter.
- And it is not a broken manifest either: a malformed manifest fails while being *parsed*,
  not while being *read*.

### Stage 6 - where the chain points

The cause is a read of compressed data that returns unusable bytes. Three things to check,
in this order:

```batch
:: 1. Is this system using Compact OS? Then system files ARE compressed on disk
compact /compactos:query
```

```powershell
# 2. Did the storage stack complain in the same minute? (see the section above)
Get-WinEvent -FilterHashtable @{
    LogName='System'; ProviderName='disk','Ntfs','storahci'
    StartTime = Get-Date '2026-09-18 14:50'; EndTime = Get-Date '2026-09-18 14:55'
} -ErrorAction SilentlyContinue

# 3. What does the drive say about itself?
Get-PhysicalDisk | Get-StorageReliabilityCounter |
    Format-List DeviceId, ReadErrorsUncorrected, Wear, Temperature
```

{{< callout type="warning" >}}
**If the disk is under suspicion, stop repairing and start copying.**
`sfc`, `DISM /RestoreHealth` and `chkdsk /f` all **write**, they all hammer the drive for
tens of minutes, and on a failing disk they can convert a recoverable situation into an
unrecoverable one. Image first, repair the image afterwards:

```bash
# From a Linux live USB, onto a healthy destination
sudo smartctl -a /dev/sda
sudo ddrescue -d -r3 /dev/sda /mnt/rescue/windows.img /mnt/rescue/windows.map
```

`ddrescue` reads the good areas first and only then retries the bad ones, so the parts
that are still readable are safe before the drive is asked to strain.
{{< /callout >}}

Note what never happened in this story: nobody reinstalled Windows, and nobody ran
`sfc /scannow` a fourth time. The chain converted *"Windows Resource Protection could not
perform the requested operation"* into *"this drive cannot read a compressed file"* in six
steps, and the second of those steps was a lie that had to be caught.

## ✅ The reusable checklist

1. **Write down the error code and the time.** Both. The time is not optional.
2. **`certutil -error <code>`** - name the error before theorising about it.
3. **Identify the family**: `0x8007` → Win32, `0x800F` → servicing, `0x8024` → Windows
   Update, `0xC000` → **kernel/hardware, treat as serious**.
4. **Open the log of the tool** (`dism.log`) - it tells you *where* it failed.
5. **Open the log of the cause** (`CBS.log`) - it tells you *what* failed.
6. **Search by timestamp, not by keyword**, and always with `-Context`.
7. **Check that the operation completed** before believing any "0 corruption" summary.
   Read `Last Successful Step`.
8. **Correlate with Event Viewer** over the same minutes: `disk`, `Ntfs`, `storahci`.
9. **If the hardware is implicated, image before you repair.**
10. **Write down which hypothesis died and why.** The next person to hit this - probably
    you, in a year - needs the discarded branches as much as the answer.

---

**Related Pills:**
- [Windows System Repair and Maintenance](/2025/10/windows-system-repair-and-maintenance/) - the DISM/SFC sequence these logs belong to
- [Windows Boot Repair](/2025/09/windows-boot-repair/)
- Rescuing a failing disk with ddrescue (coming soon)

---

*An error code is a question, not an answer. Follow the chain down until something names a file.*
