---
title: "Leggere i log di Windows: dal codice di errore alla causa"
url: "2026/09/reading-windows-logs-from-error-code-to-root-cause/"
date: 2026-09-18T11:00:00+02:00
lastmod: 2026-09-18T11:00:00+02:00
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
description: "Quando SFC, DISM o Windows Update falliscono con un messaggio generico, segui la catena dei log invece di rilanciare lo stesso comando"
---

# 💊 Pillola rapida: leggere i log di Windows

{{< callout type="info" >}}
**A cosa serve**: SFC, DISM o Windows Update sono falliti con un messaggio che non spiega
niente. Invece di rilanciare gli stessi comandi sperando in un risultato diverso, scopri
cosa si è rotto davvero.
{{< /callout >}}

## 🧭 Lo strumento che segnala l'errore non è quello che lo spiega

È tutta l'idea di questa pagina, e vale la pena dirla chiara:

> **Il livello che ti mostra l'errore non è quasi mai il livello che ne conosce la causa.**

DISM ti dice `Error: 605`. DISM non sa cosa voglia dire 605 nel tuo caso: ha raccolto un
errore dallo stack di servicing e ha stampato il numero. Lo stack di servicing ha scritto
il motivo in `CBS.log`, un piano più sotto. SFC ti dice che *«could not perform the
requested operation»*, che è il messaggio che stampa per qualunque motivo esista.

Quindi il metodo è una **catena**, e funziona solo in ordine:

```
error code  ->  decode the code  ->  log of the tool  ->  log of the cause  ->  timestamp  ->  Event Viewer  ->  hardware
```

È saltando un anello che si finisce a reinstallare Windows per sistemare un cavo SATA che
sta morendo.

## 🔢 Decodifica il codice prima di aprire qualunque log

Metà delle volte il codice da solo restringe il problema a una famiglia, e questo decide
quale log vale la pena aprire. Non c'è niente da installare.

### certutil -error - lo strumento che nessuno usa

`certutil` c'è su ogni Windows e traduce qualunque codice di errore, a qualunque famiglia
appartenga:

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
0xc0000242 (NTSTATUS: 3221226050) -- 3221226050 (-1073741246)
Error message text: {Bad Compression Buffer}
The specified buffer contains ill-formed data.
```

*(output abbreviato - `certutil` stampa anche una riga finale di esito positivo)*

Accetta esadecimale o decimale, funziona offline, e gestisce HRESULT, Win32 e NTSTATUS
senza che tu gli dica quale gli hai dato. Non c'è motivo di incollare un codice di errore
in un motore di ricerca prima di aver lanciato questo.

### Anatomia di un HRESULT

Un HRESULT non è un numero opaco: sono tre campi impacchettati in 32 bit.

```
0x8007025D
  │ │  └─────  code:      0x025D = 605      <- the classic Win32 error
  │ └────────  facility:  0x007            <- FACILITY_WIN32
  └──────────  severity:  1                <- failure
```

Da cui una regola che puoi applicare a occhio: **tutto quello che ha la forma `0x8007XXXX`
è un normale errore Win32 travestito.** Prendi le ultime quattro cifre esadecimali e hai il
numero che `net helpmsg` capisce.

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

### Le famiglie da riconoscere a colpo d'occhio

| Forma | Famiglia | Chi l'ha prodotto |
|-------|----------|-------------------|
| `0x8007XXXX` | HRESULT, `FACILITY_WIN32` | È fallita una chiamata a un'API Win32 - tieni le ultime 4 cifre |
| `0x800FXXXX` | HRESULT, `FACILITY_SETUPAPI` | Servicing / CBS - per esempio `0x800F081F`, «source files not found» |
| `0x8024XXXX` | Agente di Windows Update | `wuauserv` in persona: policy, WSUS, proxy, download |
| `0xC000XXXX` | **NTSTATUS** | Kernel, driver, I/O. Molto più vicino all'hardware |

L'ultima riga conta più delle altre. Un **NTSTATUS** in un log di servicing vuol dire che
l'errore non è avvenuto nella logica di Windows: è avvenuto mentre il kernel parlava con un
dispositivo o con la memoria. Questi sono quelli da conoscere:

| NTSTATUS | Nome | Cosa significa di solito |
|----------|------|--------------------------|
| `0xC0000005` | `STATUS_ACCESS_VIOLATION` | Puntatore non valido - bug software, oppure RAM |
| `0xC000009C` | `STATUS_DEVICE_DATA_ERROR` | **Settore illeggibile.** Hardware fino a prova contraria |
| `0xC000009D` | `STATUS_DEVICE_NOT_CONNECTED` | Il dispositivo è sparito dal bus |
| `0xC0000102` | `STATUS_FILE_CORRUPT_ERROR` | Il filesystem dice che il file è strutturalmente sbagliato |
| `0xC0000185` | `STATUS_IO_DEVICE_ERROR` | Errore di I/O - cavo, controller, disco |
| `0xC0000242` | `STATUS_BAD_COMPRESSION_BUFFER` | Dati compressi che non si decomprimono |

### Err.exe, per quando vuoi tutte le risposte insieme

**Err.exe** di Microsoft (lo strumento «Error Code Look-up») è un singolo eseguibile
portabile che cerca un valore in tutti i file header di Windows e mostra *tutti* i nomi
simbolici a cui corrisponde, in ogni famiglia:

```batch
err.exe 0xc0000242
```

È utile proprio perché un numero nudo può esistere in più di una famiglia: `certutil`
sceglie una interpretazione, `err.exe` te le mostra tutte e ti lascia scegliere quella che
si adatta al contesto.

## 🔗 La catena dei log: quale log per quale strumento

| Strumento | Log | Cosa ci trovi |
|-----------|-----|---------------|
| **SFC** | `C:\Windows\Logs\CBS\CBS.log` | Le righe `[SR]`, `Cannot repair member file`, i nomi dei file |
| **DISM** | `C:\Windows\Logs\DISM\dism.log` | **Che** qualcosa è fallito, e in quale punto di DISM - raramente perché |
| **DISM (la causa vera)** | `C:\Windows\Logs\CBS\CBS.log` | Il componente, il file, l'NTSTATUS che sta sotto |
| **Windows Update** | `C:\Windows\Logs\WindowsUpdate\*.etl` | Tracce binarie - si leggono con `Get-WindowsUpdateLog` |
| **Aggiornamento di funzionalità / setup** | `C:\$WINDOWS.~BT\Sources\Panther\setuperr.log` | Perché l'aggiornamento è tornato indietro (`C:\Windows\Panther\` a installazione fatta) |
| **Driver** | `C:\Windows\INF\setupapi.dev.log` | Installazione ed enumerazione dei driver, dispositivo per dispositivo |
| **Hardware / sistema** | Event Viewer, log `System` | Disco, NTFS, controller, alimentazione - il livello fisico |

{{< callout type="info" >}}
**La riga che sorprende è la terza.** `dism.log` è un log di DISM, non un log della
riparazione: registra fedelmente che un passo ha restituito un errore e quale funzione
interna era in esecuzione. Il motivo sta in `CBS.log`, perché è lo stack di servicing
basato sui componenti a toccare davvero i file. Aprili tutti e due, sempre in quest'ordine.
{{< /callout >}}

Due note pratiche su Windows Update:

```powershell
# Convert the ETL traces into a readable WindowsUpdate.log
Get-WindowsUpdateLog -LogPath "$env:userprofile\Desktop\WindowsUpdate.log"
```

e su CBS: il file vivo è `CBS.log`, ma quando supera il suo limite Windows lo ruota in
`CbsPersist_<timestamp>.cab` **nella stessa cartella**. Se il tuo errore è della settimana
scorsa, sta dentro uno di quei cab, non in `CBS.log`.

## 🔎 Filtrare un log da 100 MB

`CBS.log` supera regolarmente i 100 MB. Aprirlo con il Blocco note e scorrere non è una
tecnica.

### I filtri grossolani

```batch
:: The SFC verdict lines, and the files it gave up on
findstr /c:"[SR]" /c:"Cannot repair" %windir%\Logs\CBS\CBS.log > "%userprofile%\Desktop\sfc.txt"

:: Every failure line: CBS marks them with (F)
findstr /c:"(F)" %windir%\Logs\CBS\CBS.log > "%userprofile%\Desktop\cbs-failures.txt"
```

`(F)` è il marcatore di gravità di CBS per *failure*, e cercarlo trasforma un file da
100 MB in qualcosa che si riesce davvero a leggere. I suoi compagni sono `(E)` per error e
`(W)` per warning.

### Il nome del file si nasconde nel contesto

La riga che contiene il codice di errore di solito **non** contiene il nome del file:
quello sta sulla riga prima, o due righe dopo. Cercare senza contesto butta via la
risposta.

```powershell
# Six lines before and six after every hit
Select-String -Path $env:windir\Logs\CBS\CBS.log -Pattern 'c0000242' -Context 6,6
```

```powershell
# Only the failure lines, with what led to them
Select-String -Path $env:windir\Logs\CBS\CBS.log -Pattern '\(F\)' -Context 3,1 |
    Select-Object -Last 20
```

### Ancorati all'orologio - il trucco che fa risparmiare più tempo

È l'abitudine che rende di più in tutta questa pagina. **Segnati l'ora esatta in cui
l'errore è comparso a schermo**, poi leggi per intero quel minuto di log, invece di cercare
parole che stai tirando a indovinare.

```powershell
# You saw the failure at 14:52. Read that minute, whole, from both logs.
$when = '2026-09-18 14:5'
Select-String -Path $env:windir\Logs\DISM\dism.log -Pattern $when
Select-String -Path $env:windir\Logs\CBS\CBS.log  -Pattern $when
```

Funziona perché ognuno di questi log ha il timestamp riga per riga, e perché la causa vera
è sempre scritta **a un secondo o due** dal sintomo che hai visto. Cercare per parola
chiave ti costringe a indovinare il vocabolario di un componente che non hai mai letto.
Cercare per ora ti chiede di sapere solo quello che sai già: quando è successo.

Lo stesso ancoraggio poi ti porta dentro Event Viewer, che è l'argomento della prossima
sezione.

```batch
:: More detail from DISM next time round
Dism /Online /Cleanup-Image /ScanHealth /LogLevel:4
```

## 📟 Event Viewer dalla riga di comando

L'interfaccia grafica va bene per sfogliare ed è pessima per correlare. Da PowerShell puoi
fare la domanda che hai davvero.

### Tutto quello che lo stack dello storage ha detto questa settimana

```powershell
Get-WinEvent -FilterHashtable @{
    LogName      = 'System'
    ProviderName = 'disk','Ntfs','volmgr','storahci','stornvme'
    StartTime    = (Get-Date).AddDays(-7)
} -ErrorAction SilentlyContinue |
    Format-Table TimeCreated, Id, ProviderName, Message -AutoSize -Wrap
```

`-ErrorAction SilentlyContinue` non è decorazione: `Get-WinEvent` scrive un errore
(«Impossibile trovare eventi che soddisfino i criteri di selezione specificati») quando un
filtro non trova niente, e sembra un comando rotto anziché una buona notizia. È un errore
non bloccante: lo script prosegue comunque, e questa opzione tiene solo il testo rosso
fuori dallo schermo.

### Gli stessi cinque minuti del tuo errore

```powershell
Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    StartTime = Get-Date '2026-09-18 14:50'
    EndTime   = Get-Date '2026-09-18 14:55'
} -ErrorAction SilentlyContinue | Sort-Object TimeCreated
```

Se un evento `disk` o `Ntfs` cade nel minuto in cui DISM è fallito, hai finito di tirare a
indovinare: l'errore di servicing è un sintomo e la storia è il disco.

### Eventi dello storage da conoscere per numero

| Sorgente | ID | Significato |
|----------|-----|-------------|
| `disk` | **7** | *«The device has a bad block.»* Settore illeggibile |
| `disk` | **51** | Errore durante un'**operazione di paging** - I/O fallito sul disco di boot |
| `disk` | **153** | L'I/O è stato **ritentato**. Avviso precoce: un disco che se ne sta andando |
| `Ntfs` | **55** | Struttura del filesystem corrotta - lancia `chkdsk` |
| `Ntfs` | **98** | Rilevata corruzione dei **metadati** del volume |
| `Ntfs` | **137 / 140** | Scrittura del log delle transazioni fallita - può seguire corruzione |
| `storahci` | **129** | *«Reset to device ... was issued.»* Il controller ha perso la pazienza con il disco |
| `volmgr` | **46** | Inizializzazione del crash dump fallita |

### Esportazione e colpo d'occhio

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

`perfmon /rel` merita più affetto di quanto ne riceva: è il modo più veloce per rispondere
a *«è cominciato in un giorno preciso?»*, e un grappolo di errori che compare nella stessa
data è spesso tutta la diagnosi.

## 🕳️ Falsi negativi: quando un log mente per omissione

**Questa è la sezione più importante della pagina.**

Un log può dirti che va tutto bene perché **il controllo non è mai arrivato in fondo**. Il
blocco di riepilogo viene scritto comunque; riassume quello che è stato esaminato, non
quello che esiste. Se la scansione si è interrotta al 92%, il riepilogo riporta
onestamente zero problemi trovati nella parte che è riuscita a guardare - e chi legge solo
il riepilogo conclude che il sistema è sano.

Ecco com'è fatta la trappola, presa da un `CBS.log` vero:

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

`Total Detected Corruption: 0`, poche righe dopo che la scansione è saltata su un file
illeggibile. Entrambe le affermazioni sono vere. Solo una delle due è una risposta.

**Quindi: verifica sempre che l'operazione sia arrivata alla fine, non solo cosa ha
concluso.**

```powershell
# 1. Did anything abort? Look BEFORE you trust the summary
Select-String -Path $env:windir\Logs\CBS\CBS.log `
    -Pattern 'c0000|\(F\)|Failed to|abort' | Select-Object -Last 20

# 2. Only then read the verdict
Select-String -Path $env:windir\Logs\CBS\CBS.log `
    -Pattern 'Last Successful Step|Total Detected Corruption|Operation result' |
    Select-Object -Last 10
```

Il campo da leggere è **`Last Successful Step`**. Se non dice
*«Entire operation completes»*, ogni zero che gli sta sotto non significa niente.

{{< callout type="warning" >}}
**La regola generale**: un risultato pulito vale quanto la copertura della scansione che
l'ha prodotto. Prima di credere a un verdetto verde, chiediti quanta parte di quello che
doveva esaminare ha effettivamente raggiunto. Vale ben oltre Windows.
{{< /callout >}}

## 🧪 Caso di studio: SFC si ferma al 48%

Una catena vera, tappa per tappa - compresa l'ipotesi che si è rivelata sbagliata, perché
scartare ipotesi è il metodo, non una deviazione dal metodo.

### Tappa 1 - il sintomo

```text
sfc /scannow
Beginning system scan. This process will take some time.
Beginning verification phase of system scan.
Verification 48% complete.
Windows Resource Protection could not perform the requested operation.
```

**Imparato:** ancora niente. Quel messaggio è la stringa di errore universale di SFC. Non
ti dice nemmeno se il problema è un file, lo store, o il disco che sta sotto.
**Poi:** controllare il component store, visto che SFC ripara *da* lì.

### Tappa 2 - il falso via libera

```text
Dism /Online /Cleanup-Image /CheckHealth
No component store corruption detected.
The operation completed successfully.
```

**Imparato:** ancora niente - e qui si è quasi presa la strada sbagliata. `CheckHealth`
**non fa una scansione**: riferisce se un'operazione *precedente* ha segnalato l'immagine.
Su una macchina mai scansionata dice sempre così. Preso alla lettera dice «lo store è a
posto, quindi il problema è altrove», e ti manda a reinstallare driver.
**Poi:** una scansione che scansioni davvero.

### Tappa 3 - finalmente, un codice

```text
Dism /Online /Cleanup-Image /ScanHealth
[==========================92.4%=====     ]
Error: 605
The operation could not be completed due to an unspecified error.
```

**Imparato:** finalmente qualcosa di concreto. `certutil -error 0x8007025D` (la forma
HRESULT di 605) restituisce `ERROR_BAD_COMPRESSION_BUFFER`. Nota anche il **92.4%**: la
scansione non è finita, quindi qualunque «corruption: 0» stampato dopo non vale niente.
**Poi:** il log di DISM, per sapere dove è morto.

### Tappa 4 - dism.log: dove, non perché

```text
2026-09-18 14:52:07, Error  DISM  DISM Provider Store: PID=6104 TID=7220
    Failed to get the IDismObject Interface - CDISMProviderStore::Internal_Finalize
    HRESULT=0x8007025D
2026-09-18 14:52:08, Info   DISM  DISM.EXE: Reboot Required=no
```

**Imparato:** due cose utili.
1. L'errore è emerso in `Internal_Finalize`, cioè DISM l'ha raccolto mentre usciva -
   l'errore veniva da sotto, non da DISM stesso.
2. **`Reboot Required=no`** ammazza un'intera famiglia di ipotesi: non è un'operazione di
   servicing in sospeso che aspetta un riavvio. Riavviare non servirà. Non riavviare tre
   volte «per sicurezza».

**Ancora ignoto:** quale file. `dism.log` non lo nomina mai.
**Poi:** il piano di sotto.

### 💀 L'ipotesi che è morta qui

A questo punto la teoria ragionevole era la **rete**: un `ERROR_BAD_COMPRESSION_BUFFER` su
un'operazione di servicing somiglia molto a un proxy aziendale o a un antivirus che
storpiano i payload compressi serviti da Windows Update. Calza alla perfezione con la
tappa 3, è una causa reale e comune, e suggerisce una prova facile (`/LimitAccess` con un
`install.wim` locale).

Era sbagliata - e ad ammazzarla è stata la tappa 5. Vale la pena annotarlo, perché una
teoria plausibile che sopravvive a quattro tappe e muore alla quinta è esattamente ciò *per
cui* la catena esiste.

### Tappa 5 - CBS.log: la causa vera

```text
2026-09-18 14:52:07, Info   CSI  00000a31 Direct SIL provider: failed to read file.
2026-09-18 14:52:07, Error  CSI  00000a32 (F) base\wcp\sil\merged\ntu\ntsystem.cpp(3674):
    Error c0000242 [Error,Facility=(system),Code=578 (0x0242)]
    originated in function DirectFileSystemProvider::SysReadFile expression: (null)
```

**Imparato - ed è qui che la catena ripaga:**

- `c0000242` è `STATUS_BAD_COMPRESSION_BUFFER`, il gemello **NTSTATUS** del `605` che
  DISM ha stampato. Sono lo stesso fatto a due quote diverse: il kernel ha detto
  `0xC0000242`, lo stack di servicing l'ha tradotto nel Win32 `605` e l'ha incartato come
  `0x8007025D`. Solo quello più in basso porta l'informazione che conta.
- `DirectFileSystemProvider::SysReadFile` è una **lettura**. Una `ReadFile` su un file
  locale, su dati compressi, tornata con spazzatura.
- **Quindi la teoria del proxy è morta.** Non si stava scaricando niente. L'errore sta fra
  il filesystem e il piatto.
- E non è nemmeno un manifest rotto: un manifest malformato fallisce mentre viene
  *interpretato*, non mentre viene *letto*.

### Tappa 6 - dove punta la catena

La causa è una lettura di dati compressi che restituisce byte inutilizzabili. Tre cose da
controllare, in quest'ordine:

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
**Se il disco è sospetto, smetti di riparare e comincia a copiare.**
`sfc`, `DISM /RestoreHealth` e `chkdsk /f` **scrivono** tutti, martellano tutti il disco
per decine di minuti, e su un disco che sta cedendo possono trasformare una situazione
recuperabile in una irrecuperabile. Prima l'immagine, poi si ripara l'immagine:

```bash
# From a Linux live USB, onto a healthy destination
sudo smartctl -a /dev/sda
sudo ddrescue -d -r3 /dev/sda /mnt/rescue/windows.img /mnt/rescue/windows.map
```

`ddrescue` legge prima le zone buone e solo dopo ritenta quelle rovinate, così le parti
ancora leggibili sono al sicuro prima che al disco venga chiesto di sforzarsi.
{{< /callout >}}

Nota cosa non è mai successo in questa storia: nessuno ha reinstallato Windows, e nessuno
ha lanciato `sfc /scannow` una quarta volta. La catena ha trasformato *«Windows Resource
Protection could not perform the requested operation»* in *«questo disco non riesce a
leggere un file compresso»* in sei passi, e il secondo di quei passi era una bugia che
andava smascherata.

## ✅ La checklist da riusare

1. **Scrivi il codice di errore e l'ora.** Tutti e due. L'ora non è facoltativa.
2. **`certutil -error <code>`** - dai un nome all'errore prima di farci sopra delle teorie.
3. **Individua la famiglia**: `0x8007` → Win32, `0x800F` → servicing, `0x8024` → Windows
   Update, `0xC000` → **kernel/hardware, da prendere sul serio**.
4. **Apri il log dello strumento** (`dism.log`) - ti dice *dove* è fallito.
5. **Apri il log della causa** (`CBS.log`) - ti dice *cosa* è fallito.
6. **Cerca per timestamp, non per parola chiave**, e sempre con `-Context`.
7. **Controlla che l'operazione sia arrivata in fondo** prima di credere a un riepilogo con
   «0 corruption». Leggi `Last Successful Step`.
8. **Correla con Event Viewer** sugli stessi minuti: `disk`, `Ntfs`, `storahci`.
9. **Se c'entra l'hardware, fai l'immagine prima di riparare.**
10. **Scrivi quale ipotesi è morta e perché.** Al prossimo che ci sbatte contro -
    probabilmente tu, fra un anno - i rami scartati servono quanto la risposta.

---

**Pillole correlate:**
- [Riparazione e manutenzione di Windows](/2025/10/windows-system-repair-and-maintenance/) - la sequenza DISM/SFC a cui appartengono questi log
- [Riparazione del boot di Windows](/2025/09/windows-boot-repair/)
- Salvare un disco in avaria con ddrescue (in arrivo)

---

*Un codice di errore è una domanda, non una risposta. Segui la catena verso il basso finché qualcosa non nomina un file.*
