---
title: "Windows System Repair and Maintenance"
date: 2025-10-05T15:00:00+02:00
lastmod: 2026-09-18T10:00:00+02:00
draft: false
author: "Manzolo"
tags: ["windows", "repair", "troubleshooting", "boot", "quick-tip"]
categories: ["Quick Pills"]
series: ["Quick Pills Collection"]
weight: 2
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "Repair corrupted Windows system files with DISM and SFC - in the order that actually works, and why the popular one doesn't"
---

# 💊 Quick Pill: Windows System Repair

{{< callout type="info" >}}
**Use case**: Fix corrupted Windows system files, repair Windows Update issues, resolve DLL errors, and restore system health.
{{< /callout >}}

## 🧭 The order is the whole trick

Almost every "Windows repair" script on the internet gets this backwards, and so did
**the first version of this page**. The correct order is:

```
1. Dism /Online /Cleanup-Image /ScanHealth       (diagnose the store)
2. Dism /Online /Cleanup-Image /RestoreHealth    (repair the store)
3. sfc /scannow                                  (repair the files, FROM the store)
4. reboot, then sfc /scannow once more if step 3 fixed anything
```

**Why, in one sentence:** `sfc` does not download anything - it repairs a damaged system
file by copying a good version **out of the component store** (`%WinDir%\WinSxS`).
If the store itself is damaged, SFC has nothing good to copy from, which is precisely the
famous message *"found corrupt files but was unable to fix some of them"*.
**DISM repairs the store. SFC repairs the files. So DISM goes first.**

{{< callout type="warning" >}}
**Do NOT stop Windows Update, BITS or the Installer service before DISM.**
`Dism /Online /Cleanup-Image /RestoreHealth` obtains the replacement payloads
**through Windows Update**: it needs `wuauserv` and `bits` **running**. Stopping them is
the single most common way to manufacture error `0x800f081f` and then blame the internet
connection. Stopping those services belongs to a *different* procedure - the
[Windows Update component reset](#-resetting-windows-update-components-a-different-procedure)
- where the point is to release `SoftwareDistribution` and `catroot2`, not to repair files.
{{< /callout >}}

## 🔧 Automated Repair Script

Save this as `windows_repair.bat` and **run as Administrator**:

```batch
@echo off
setlocal

net session >nul 2>&1
if errorlevel 1 (
    echo This script must be run as Administrator.
    echo Right-click the file and choose "Run as administrator".
    pause
    exit /b 1
)

echo ==========================================
echo  Windows System Repair - DISM then SFC
echo ==========================================
echo.
echo Windows Update and BITS must stay RUNNING:
echo DISM /RestoreHealth pulls the replacement files through them.
echo.

echo [1/3] DISM ScanHealth - looking for component store corruption...
echo       (5-10 minutes, no repair, detection only)
Dism /Online /Cleanup-Image /ScanHealth
echo.

echo [2/3] DISM RestoreHealth - repairing the component store...
echo       (10-60 minutes, downloads from Windows Update)
Dism /Online /Cleanup-Image /RestoreHealth
set DISM_RC=%errorlevel%

if %DISM_RC% equ 3010 echo DISM succeeded and is asking for a reboot.
if %DISM_RC% neq 0 if %DISM_RC% neq 3010 (
    echo.
    echo *** DISM failed with code %DISM_RC%.
    echo *** Running SFC now is mostly pointless: it repairs FROM the store
    echo *** that DISM just failed to fix. Use an offline source instead
    echo *** - see the "Use a local source" section of the guide.
    echo.
    choice /M "Run SFC anyway"
    if errorlevel 2 goto :done
)
echo.

echo [3/3] SFC - repairing system files from the repaired store...
echo       (10-30 minutes)
sfc /scannow
echo.

:done
echo ==========================================
echo  Finished. Details: %windir%\Logs\CBS\CBS.log
echo ==========================================
echo.
echo If SFC repaired anything, reboot and run "sfc /scannow" ONE MORE TIME:
echo some files can only be replaced while they are not in use, so the
echo second pass is the one that confirms the system is actually clean.
echo.

choice /M "Do you want to reboot now"
if errorlevel 2 goto :noreboot

echo Rebooting in 10 seconds...
shutdown /r /t 10 /c "Rebooting after system repair."
goto :end

:noreboot
echo Reboot cancelled. Please restart manually when convenient.

:end
echo.
pause
```

{{< callout type="warning" >}}
**⚠️ Administrator Rights Required**: right-click the script and select "Run as Administrator".
The script checks this itself and refuses to run otherwise.
{{< /callout >}}

## 📋 What Each Command Does

### 1. DISM ScanHealth

```batch
Dism /Online /Cleanup-Image /ScanHealth
```

- **Really scans** the component store for corruption
- Detection only, repairs nothing
- Writes its verdict into a flag that `CheckHealth` will later read
- Time: 5-10 minutes

### 2. DISM RestoreHealth

```batch
Dism /Online /Cleanup-Image /RestoreHealth
```

- **Actually repairs** the component store
- Default source: **Windows Update** (so: online, and with `wuauserv`/`bits` running)
- `/LimitAccess` disables the Windows Update fallback - only use it together with `/Source:`
- Time: 10-60 minutes
- Log: `%windir%\Logs\DISM\dism.log`

### 3. SFC (System File Checker)

```batch
sfc /scannow
```

- Scans all files protected by **Windows Resource Protection**
- Replaces a bad file with the good copy taken from the component store,
  **`%WinDir%\WinSxS`** - *not* from `System32\dllcache`, which was
  Windows File Protection and died with Windows XP
- Time: 10-30 minutes
- Log: `%windir%\Logs\CBS\CBS.log`

### And what about CheckHealth?

```batch
Dism /Online /Cleanup-Image /CheckHealth
```

`CheckHealth` **does not scan anything**. It only reports whether a *previous* operation
already flagged the image as corrupted. On a machine that has never been scanned it
cheerfully answers *"No component store corruption detected"* - which means
"nothing has been recorded", not "the system is healthy".

It is genuinely useful in one case only: an instant re-read of an earlier verdict.
As the first step of a repair it is worse than useless, because it hands you a false all-clear.

## 🚀 Quick Manual Commands

<details>
<summary><strong>Run the commands individually</strong></summary>

### Full repair, correct order (30-90 minutes)

```batch
:: Open CMD or PowerShell as Administrator
Dism /Online /Cleanup-Image /ScanHealth
Dism /Online /Cleanup-Image /RestoreHealth
sfc /scannow
:: reboot, then:
sfc /scannow
```

### PowerShell one-liner

```powershell
# Runs SFC only if DISM actually succeeded
Dism /Online /Cleanup-Image /RestoreHealth; if ($LASTEXITCODE -in 0,3010) { sfc /scannow }
```

### Just a quick look, repairing nothing

```batch
Dism /Online /Cleanup-Image /ScanHealth
```
</details>

<details>
<summary><strong>Use a local source (offline, faster, and the fix for 0x800f081f)</strong></summary>

Mount the Windows ISO (right-click > Mount), then check what is inside `D:\sources\`:
recent images ship `install.esd`, others `install.wim`. The syntax **requires the format
prefix and the index**, and this is where most copy-pasted commands fail:

```batch
:: 1. List the editions inside the image and note the Index of yours
Dism /Get-WimInfo /WimFile:D:\sources\install.wim

:: 2. Use that index (here: 6 = Windows 11 Pro, yours may differ)
Dism /Online /Cleanup-Image /RestoreHealth /Source:wim:D:\sources\install.wim:6 /LimitAccess

:: For an .esd image
Dism /Online /Cleanup-Image /RestoreHealth /Source:esd:D:\sources\install.esd:6 /LimitAccess
```

Three rules that decide whether this works:

1. **The index must match your edition.** Pro repaired from the Home index fails.
2. **The image must be the same build or newer** than the installed one. An old ISO
   against a fully patched system is the number one cause of `0x800f081f`.
3. `D:\sources\sxs` is **not** a source for `RestoreHealth` - that folder only serves
   `/Enable-Feature` for .NET Framework 3.5.
</details>

<details>
<summary><strong>Offline repair (Windows does not boot)</strong></summary>

From the Windows installation media, *Repair your computer > Command Prompt*.
**Drive letters in WinPE are not the ones you see in Windows**: check them first.

```batch
:: 1. Find the real letters (Windows volume, and the media)
diskpart
  list volume
  exit

:: 2. Repair the component store of the offline image
Dism /Image:C:\ /Cleanup-Image /RestoreHealth /Source:wim:E:\sources\install.wim:6 /LimitAccess

:: 3. Then, and only then, SFC against that offline installation
sfc /scannow /offbootdir=C:\ /offwindir=C:\Windows
```

Without `/offbootdir` and `/offwindir`, `sfc` in WinPE scans the RAM disk you booted
from and reports it is fine - which tells you nothing about your Windows.
</details>

## 🔍 Understanding Results

### SFC Output Messages

| Message | Meaning | Action |
|---------|---------|--------|
| "did not find any integrity violations" | ✅ All files OK | No action needed |
| "found corrupt files and repaired them" | ✅ Fixed | Reboot and run SFC again; check `CBS.log` |
| "found corrupt files but was unable to fix" | ⚠️ The store is damaged too | Run DISM `/RestoreHealth`, then SFC again |
| "could not perform the requested operation" | ❌ A pending operation blocks it | Reboot (finishes pending updates) and retry |

### DISM Output Messages

| Message | Meaning | Action |
|---------|---------|--------|
| "No component store corruption detected" **after ScanHealth** | ✅ Store healthy | Go on with SFC |
| "No component store corruption detected" **after CheckHealth** | 🤷 Nothing was ever recorded | Run ScanHealth - this was not a check |
| "The component store is repairable" | ⚠️ Corruption found | Run RestoreHealth |
| "The restore operation completed successfully" | ✅ Store repaired | **Now** run SFC |
| Error `0x800f081f` | ❌ Source files not found | Use a local source with the right index/build |
| Error `0x800f0906` | ❌ Could not download | Check connection, proxy, WSUS policy; or use a local source |

## 💡 Pro Tips

<details>
<summary><strong>Read the SFC log properly</strong></summary>

```batch
findstr /c:"[SR]" %windir%\Logs\CBS\CBS.log > "%userprofile%\Desktop\sfcdetails.txt"
notepad "%userprofile%\Desktop\sfcdetails.txt"
```

Look for `Cannot repair member file` - that line names the file SFC gave up on,
and it is the proof that the component store, not the file, is the problem.
</details>

<details>
<summary><strong>Reclaim space after the repair</strong></summary>

```batch
:: Removes superseded component versions - run it AFTER everything works,
:: because it makes the previous updates non-uninstallable
Dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase
```
</details>

<details>
<summary><strong>Schedule automatic maintenance</strong></summary>

```batch
:: Open Task Scheduler
taskschd.msc

:: Create Basic Task:
:: - Name: "Quarterly System Check"
:: - Trigger: Monthly (first Sunday, 2 AM)
:: - Action: Start a program
:: - Program: C:\path\to\windows_repair.bat
:: - Run with highest privileges: YES
```

Bear in mind that an unattended `/RestoreHealth` can run for an hour and needs the
network: a quarterly `ScanHealth` is a saner scheduled task than the full repair.
</details>

## 🔄 Resetting Windows Update components (a different procedure)

This is where stopping the services makes sense: the goal is to release the folders
`SoftwareDistribution` and `catroot2` so they can be renamed. It has nothing to do
with repairing system files, and it must **not** be merged into the script above.

Save as `reset_windows_update.bat`:

```batch
@echo off
net stop wuauserv
net stop cryptSvc
net stop bits
net stop msiserver

ren C:\Windows\SoftwareDistribution SoftwareDistribution.old
ren C:\Windows\System32\catroot2 catroot2.old

net start wuauserv
net start cryptSvc
net start bits
net start msiserver

echo Windows Update components reset!
pause
```

Note the last four lines: whatever you stop, **you start again**. A repair script that
leaves `wuauserv`, `bits` and `msiserver` stopped has silently disabled updates and MSI
installations until the next reboot.

## ⚠️ Troubleshooting

<details>
<summary><strong>SFC cannot repair some files</strong></summary>

**Problem**: SFC found corruption but could not fix it.

**Cause**: the good copy inside the component store is missing or damaged too.

**Solution**: repair the store, then repeat.

```batch
Dism /Online /Cleanup-Image /RestoreHealth
sfc /scannow
```

If it happens again after a successful DISM, reboot first: a file in use cannot be
replaced, and the second pass is often the one that succeeds.
</details>

<details>
<summary><strong>DISM fails with error 0x800f081f</strong></summary>

**Problem**: DISM cannot find the source files.

**Causes**, in order of frequency:
1. `wuauserv`/`bits` stopped (some "repair scripts" do this for you)
2. `/LimitAccess` used without a `/Source:`
3. The ISO is **older** than the installed build
4. Wrong index - the source edition is not your edition

**Solution**:
```batch
Dism /Get-WimInfo /WimFile:D:\sources\install.wim
Dism /Online /Cleanup-Image /RestoreHealth /Source:wim:D:\sources\install.wim:6 /LimitAccess
```
</details>

<details>
<summary><strong>"Access Denied" errors</strong></summary>

**Problem**: the script will not run, or shows permission errors.

**Solution**: right-click the `.bat` and choose "Run as Administrator", or open an
elevated CMD first. A standard "Administrator" account is not enough: the process
itself must be elevated.
</details>

<details>
<summary><strong>DISM sits at 20% (or 40%) forever</strong></summary>

**Not a hang.** `RestoreHealth` pauses at fixed percentages while it downloads payloads,
and on a slow line it can stay there for a long time. Before killing it:

```batch
:: In a second elevated window, watch the log grow
powershell -c "Get-Content $env:windir\Logs\DISM\dism.log -Tail 5 -Wait"
```

If the log is still moving, it is working. If it truly is stuck, cancel and use a local
source with `/Source:` and `/LimitAccess`.
</details>

## 📊 Common Use Cases

| Issue | What to run | Time |
|-------|-------------|------|
| A single DLL error, system otherwise fine | `sfc /scannow` | 15 min |
| SFC says it cannot fix some files | DISM `/RestoreHealth` → SFC | 45 min |
| Windows Update keeps failing | Update reset → DISM → SFC | 60 min |
| System feels generally corrupted | DISM `/ScanHealth` → `/RestoreHealth` → SFC | 60 min |
| Post-malware cleanup | Full script + reboot + second SFC | 90 min |
| Preparing for a feature upgrade | DISM `/ScanHealth`, repair if needed | 20 min |

## 🔄 Recommended Maintenance Schedule

- **Quarterly**: `Dism /Online /Cleanup-Image /ScanHealth` - cheap, read-only, tells you
  whether there is anything to repair at all
- **Before a feature update**: same scan, and repair if it reports corruption
- **After malware removal**: full sequence, then the second SFC pass
- **When something is actually broken**: immediately

Running `sfc /scannow` every month on a healthy machine is a ritual, not maintenance:
on a clean system it changes nothing. The scan that is worth scheduling is DISM's.

## 🎯 When to Use This

✅ **Good for:**
- Corrupted system files
- Windows Update problems
- Missing DLL errors
- Random system crashes
- Pre-upgrade maintenance

❌ **Not for:**
- Hardware failures (check SMART and RAM first)
- Driver issues (use Device Manager)
- Performance problems (use Disk Cleanup / Task Manager)
- Virus removal (use antivirus first - repairing a file an active infection keeps
  re-patching is a loop you cannot win)

{{< callout type="info" >}}
**Updated 2026-09-18.** The first version of this page ran `sfc` before DISM and stopped
Windows Update and BITS beforehand - two mistakes that copy each other around the internet
and that, together, guarantee both the *"unable to fix"* message and error `0x800f081f`.
The order, the reasoning behind it and the source syntax have been corrected.
{{< /callout >}}

---

**Related Pills:**
- [SD Card Backup and Restore](/2025/10/sd-card-backup-and-restore/)
- [Windows Boot Repair](/2025/09/windows-boot-repair/)

---

*Keep your Windows system healthy with regular maintenance - in the right order.*
