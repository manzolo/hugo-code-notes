---
title: "Riparazione e manutenzione del sistema Windows"
url: "2025/10/windows-system-repair-and-maintenance/"
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
description: "Riparare i file di sistema corrotti di Windows con DISM e SFC: nell'ordine che funziona davvero, e perché quello più diffuso non funziona"
---

# 💊 Pillola: riparare il sistema Windows

{{< callout type="info" >}}
**A cosa serve**: riparare i file di sistema corrotti di Windows, sistemare i problemi di Windows Update, risolvere gli errori delle DLL e rimettere in salute il sistema.
{{< /callout >}}

## 🧭 Il trucco è tutto nell'ordine

Quasi tutti gli script di «riparazione di Windows» che girano su internet lo fanno al
contrario, e lo faceva anche **la prima versione di questa pagina**. L'ordine giusto è:

```
1. Dism /Online /Cleanup-Image /ScanHealth       (diagnose the store)
2. Dism /Online /Cleanup-Image /RestoreHealth    (repair the store)
3. sfc /scannow                                  (repair the files, FROM the store)
4. reboot, then sfc /scannow once more if step 3 fixed anything
```

**Il perché, in una frase:** `sfc` non scarica niente - ripara un file di sistema
danneggiato copiandone una versione buona **dal component store** (`%WinDir%\WinSxS`).
Se è lo store a essere danneggiato, SFC non ha niente di buono da cui copiare, ed è proprio
da lì che viene il famoso messaggio *«found corrupt files but was unable to fix some of them»*.
**DISM ripara lo store. SFC ripara i file. Quindi DISM va per primo.**

{{< callout type="warning" >}}
**NON fermare Windows Update, BITS o il servizio Installer prima di DISM.**
`Dism /Online /Cleanup-Image /RestoreHealth` si procura i file sostitutivi
**tramite Windows Update**: ha bisogno di `wuauserv` e `bits` **in esecuzione**. Fermarli è
il modo più comune in assoluto per fabbricarsi l'errore `0x800f081f` e poi dare la colpa alla
connessione internet. Fermare quei servizi fa parte di una procedura *diversa* - il
[reset dei componenti di Windows Update](#-resetting-windows-update-components-a-different-procedure)
- dove lo scopo è liberare `SoftwareDistribution` e `catroot2`, non riparare dei file.
{{< /callout >}}

## 🔧 Script di riparazione automatica

Salvalo come `windows_repair.bat` ed **eseguilo come amministratore**:

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
**⚠️ Servono i diritti di amministratore**: clic destro sullo script e scegli «Esegui come amministratore».
Lo script lo controlla da solo e altrimenti si rifiuta di partire.
{{< /callout >}}

## 📋 Cosa fa ciascun comando

### 1. DISM ScanHealth

```batch
Dism /Online /Cleanup-Image /ScanHealth
```

- **Fa davvero la scansione** del component store alla ricerca di corruzioni
- Solo rilevamento, non ripara niente
- Scrive il suo verdetto in un flag che poi `CheckHealth` andrà a leggere
- Tempo: 5-10 minuti

### 2. DISM RestoreHealth

```batch
Dism /Online /Cleanup-Image /RestoreHealth
```

- **Ripara davvero** il component store
- Sorgente predefinita: **Windows Update** (quindi: online, e con `wuauserv`/`bits` in esecuzione)
- `/LimitAccess` disattiva il ripiego su Windows Update - usalo solo insieme a `/Source:`
- Tempo: 10-60 minuti
- Log: `%windir%\Logs\DISM\dism.log`

### 3. SFC (System File Checker)

```batch
sfc /scannow
```

- Fa la scansione di tutti i file protetti da **Windows Resource Protection**
- Sostituisce un file guasto con la copia buona presa dal component store,
  **`%WinDir%\WinSxS`** - *non* da `System32\dllcache`, che era
  Windows File Protection ed è morta con Windows XP
- Tempo: 10-30 minuti
- Log: `%windir%\Logs\CBS\CBS.log`

### E CheckHealth?

```batch
Dism /Online /Cleanup-Image /CheckHealth
```

`CheckHealth` **non fa nessuna scansione**. Riferisce soltanto se un'operazione *precedente*
ha già segnato l'immagine come corrotta. Su una macchina che non è mai stata scansionata
risponde allegramente *«No component store corruption detected»* - che vuol dire
«non è stato registrato niente», non «il sistema è sano».

Serve davvero in un caso solo: rileggere all'istante un verdetto già emesso.
Come primo passo di una riparazione è peggio che inutile, perché ti dà un falso via libera.

## 🚀 Comandi manuali rapidi

<details>
<summary><strong>Lanciare i comandi uno per uno</strong></summary>

### Riparazione completa, nell'ordine giusto (30-90 minuti)

```batch
:: Open CMD or PowerShell as Administrator
Dism /Online /Cleanup-Image /ScanHealth
Dism /Online /Cleanup-Image /RestoreHealth
sfc /scannow
:: reboot, then:
sfc /scannow
```

### In una riga di PowerShell

```powershell
# Runs SFC only if DISM actually succeeded
Dism /Online /Cleanup-Image /RestoreHealth; if ($LASTEXITCODE -in 0,3010) { sfc /scannow }
```

### Solo un'occhiata veloce, senza riparare niente

```batch
Dism /Online /Cleanup-Image /ScanHealth
```
</details>

<details>
<summary><strong>Usare una sorgente locale (offline, più veloce, ed è il rimedio per 0x800f081f)</strong></summary>

Monta la ISO di Windows (clic destro > Monta), poi guarda cosa c'è dentro `D:\sources\`:
le immagini recenti hanno `install.esd`, le altre `install.wim`. La sintassi **vuole il
prefisso del formato e l'indice**, ed è qui che fallisce la maggior parte dei comandi copiati e incollati:

```batch
:: 1. List the editions inside the image and note the Index of yours
Dism /Get-WimInfo /WimFile:D:\sources\install.wim

:: 2. Use that index (here: 6 = Windows 11 Pro, yours may differ)
Dism /Online /Cleanup-Image /RestoreHealth /Source:wim:D:\sources\install.wim:6 /LimitAccess

:: For an .esd image
Dism /Online /Cleanup-Image /RestoreHealth /Source:esd:D:\sources\install.esd:6 /LimitAccess
```

Tre regole da cui dipende se funziona o no:

1. **L'indice deve corrispondere alla tua edizione.** Una Pro riparata dall'indice della Home fallisce.
2. **L'immagine deve avere la stessa build o una più recente** di quella installata. Una ISO
   vecchia contro un sistema aggiornato fino all'ultima patch è la causa numero uno di `0x800f081f`.
3. `D:\sources\sxs` **non** è una sorgente per `RestoreHealth` - quella cartella serve solo
   a `/Enable-Feature` per .NET Framework 3.5.
</details>

<details>
<summary><strong>Riparazione offline (Windows non si avvia)</strong></summary>

Dal supporto di installazione di Windows, *Ripristina il computer > Prompt dei comandi*.
**Le lettere di unità in WinPE non sono quelle che vedi in Windows**: prima controllale.

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

Senza `/offbootdir` e `/offwindir`, in WinPE `sfc` fa la scansione del RAM disk da cui hai
fatto il boot e riferisce che va tutto bene - il che non ti dice niente del tuo Windows.
</details>

## 🔍 Capire i risultati

### I messaggi di SFC

| Messaggio | Significato | Cosa fare |
|-----------|-------------|-----------|
| «did not find any integrity violations» | ✅ Tutti i file a posto | Non c'è niente da fare |
| «found corrupt files and repaired them» | ✅ Riparato | Riavvia e rilancia SFC; controlla `CBS.log` |
| «found corrupt files but was unable to fix» | ⚠️ È danneggiato anche lo store | Lancia DISM `/RestoreHealth`, poi di nuovo SFC |
| «could not perform the requested operation» | ❌ Lo blocca un'operazione in sospeso | Riavvia (così si completano gli aggiornamenti in sospeso) e riprova |

### I messaggi di DISM

| Messaggio | Significato | Cosa fare |
|-----------|-------------|-----------|
| «No component store corruption detected» **dopo ScanHealth** | ✅ Store sano | Prosegui con SFC |
| «No component store corruption detected» **dopo CheckHealth** | 🤷 Non è mai stato registrato niente | Lancia ScanHealth - questo non era un controllo |
| «The component store is repairable» | ⚠️ Trovata una corruzione | Lancia RestoreHealth |
| «The restore operation completed successfully» | ✅ Store riparato | **Adesso** lancia SFC |
| Errore `0x800f081f` | ❌ File sorgente non trovati | Usa una sorgente locale con indice e build giusti |
| Errore `0x800f0906` | ❌ Download non riuscito | Controlla connessione, proxy, policy WSUS; oppure usa una sorgente locale |

## 💡 Consigli pratici

<details>
<summary><strong>Leggere come si deve il log di SFC</strong></summary>

```batch
findstr /c:"[SR]" %windir%\Logs\CBS\CBS.log > "%userprofile%\Desktop\sfcdetails.txt"
notepad "%userprofile%\Desktop\sfcdetails.txt"
```

Cerca `Cannot repair member file` - quella riga dice il nome del file su cui SFC si è arreso,
ed è la prova che il problema è il component store, non il file.
</details>

<details>
<summary><strong>Recuperare spazio dopo la riparazione</strong></summary>

```batch
:: Removes superseded component versions - run it AFTER everything works,
:: because it makes the previous updates non-uninstallable
Dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase
```
</details>

<details>
<summary><strong>Pianificare la manutenzione automatica</strong></summary>

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

Tieni presente che un `/RestoreHealth` non presidiato può durare un'ora e ha bisogno della
rete: come attività pianificata, un `ScanHealth` trimestrale è più sensato della riparazione completa.
</details>

## 🔄 Reset dei componenti di Windows Update (una procedura diversa) {#-resetting-windows-update-components-a-different-procedure}

Qui sì che fermare i servizi ha senso: lo scopo è liberare le cartelle
`SoftwareDistribution` e `catroot2` per poterle rinominare. Con la riparazione dei file
di sistema non c'entra niente, e **non** va fusa con lo script qui sopra.

Salvalo come `reset_windows_update.bat`:

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

Guarda le ultime quattro righe: tutto quello che fermi, **lo riavvii**. Uno script di
riparazione che lascia fermi `wuauserv`, `bits` e `msiserver` ha disattivato in silenzio gli
aggiornamenti e le installazioni MSI fino al prossimo riavvio.

## ⚠️ Risoluzione dei problemi

<details>
<summary><strong>SFC non riesce a riparare alcuni file</strong></summary>

**Problema**: SFC ha trovato delle corruzioni ma non è riuscito a sistemarle.

**Causa**: anche la copia buona dentro il component store manca o è danneggiata.

**Soluzione**: ripara lo store, poi ripeti.

```batch
Dism /Online /Cleanup-Image /RestoreHealth
sfc /scannow
```

Se succede di nuovo dopo un DISM andato a buon fine, prima riavvia: un file in uso non si
può sostituire, e spesso è il secondo passaggio quello che riesce.
</details>

<details>
<summary><strong>DISM fallisce con l'errore 0x800f081f</strong></summary>

**Problema**: DISM non trova i file sorgente.

**Cause**, in ordine di frequenza:
1. `wuauserv`/`bits` fermi (certi «script di riparazione» lo fanno al posto tuo)
2. `/LimitAccess` usato senza un `/Source:`
3. La ISO è **più vecchia** della build installata
4. Indice sbagliato - l'edizione della sorgente non è la tua

**Soluzione**:
```batch
Dism /Get-WimInfo /WimFile:D:\sources\install.wim
Dism /Online /Cleanup-Image /RestoreHealth /Source:wim:D:\sources\install.wim:6 /LimitAccess
```
</details>

<details>
<summary><strong>Errori di «Accesso negato»</strong></summary>

**Problema**: lo script non parte, oppure mostra errori di permessi.

**Soluzione**: clic destro sul `.bat` e scegli «Esegui come amministratore», oppure apri
prima un CMD con privilegi elevati. Un normale account «Administrator» non basta: è il
processo stesso che deve avere i privilegi elevati.
</details>

<details>
<summary><strong>DISM resta fermo al 20% (o al 40%) per sempre</strong></summary>

**Non è un blocco.** `RestoreHealth` si ferma a percentuali fisse mentre scarica i file,
e su una linea lenta può restarci a lungo. Prima di ucciderlo:

```batch
:: In a second elevated window, watch the log grow
powershell -c "Get-Content $env:windir\Logs\DISM\dism.log -Tail 5 -Wait"
```

Se il log si muove ancora, sta lavorando. Se è bloccato davvero, annulla e usa una sorgente
locale con `/Source:` e `/LimitAccess`.
</details>

## 📊 Casi d'uso comuni

| Problema | Cosa lanciare | Tempo |
|----------|---------------|-------|
| Un singolo errore di DLL, per il resto il sistema va | `sfc /scannow` | 15 min |
| SFC dice che non riesce a riparare alcuni file | DISM `/RestoreHealth` → SFC | 45 min |
| Windows Update continua a fallire | Reset di Update → DISM → SFC | 60 min |
| Il sistema sembra corrotto un po' ovunque | DISM `/ScanHealth` → `/RestoreHealth` → SFC | 60 min |
| Pulizia dopo un malware | Script completo + riavvio + secondo SFC | 90 min |
| Preparazione a un aggiornamento delle funzionalità | DISM `/ScanHealth`, riparazione se serve | 20 min |

## 🔄 Calendario di manutenzione consigliato

- **Ogni tre mesi**: `Dism /Online /Cleanup-Image /ScanHealth` - costa poco, è in sola lettura, e ti dice
  se c'è davvero qualcosa da riparare
- **Prima di un aggiornamento delle funzionalità**: la stessa scansione, e la riparazione se segnala corruzioni
- **Dopo la rimozione di un malware**: sequenza completa, poi il secondo passaggio di SFC
- **Quando qualcosa è rotto davvero**: subito

Lanciare `sfc /scannow` ogni mese su una macchina sana è un rito, non manutenzione:
su un sistema pulito non cambia niente. La scansione che vale la pena pianificare è quella di DISM.

## 🎯 Quando usarlo

✅ **Va bene per:**
- File di sistema corrotti
- Problemi di Windows Update
- Errori di DLL mancanti
- Crash casuali del sistema
- Manutenzione prima di un aggiornamento

❌ **Non serve per:**
- Guasti hardware (controlla prima SMART e RAM)
- Problemi di driver (usa Gestione dispositivi)
- Problemi di prestazioni (usa Pulizia disco / Gestione attività)
- Rimozione di virus (usa prima l'antivirus - riparare un file che un'infezione attiva
  continua a modificare è un giro da cui non esci vincitore)

{{< callout type="info" >}}
**Aggiornato il 2026-09-18.** La prima versione di questa pagina lanciava `sfc` prima di DISM e prima
ancora fermava Windows Update e BITS - due errori che su internet si copiano l'uno con l'altro
e che, insieme, garantiscono sia il messaggio *«unable to fix»* sia l'errore `0x800f081f`.
Sono stati corretti l'ordine, il ragionamento che lo giustifica e la sintassi della sorgente.
{{< /callout >}}

---

**Pillole correlate:**
- [Backup e ripristino di una scheda SD](/2025/10/sd-card-backup-and-restore/)
- [Riparazione del boot di Windows](/2025/09/windows-boot-repair/)

---

*Tieni in salute il tuo Windows con una manutenzione regolare - nell'ordine giusto.*
