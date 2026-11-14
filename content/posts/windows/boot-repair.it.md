---
title: "Riparare il boot di Windows"
url: "2025/09/windows-boot-repair/"
date: 2025-09-27T15:26:00+02:00
lastmod: 2025-09-27T15:26:00+02:00
draft: false
author: "Manzolo"
tags: ["boot-repair", "windows", "dual-boot", "grub", "troubleshooting"]
categories: ["Linux Administration"]
series: ["System Administration Basics"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Guida alla riparazione del boot di Windows

## Introduzione

I problemi di boot di Windows possono impedire al sistema di avviarsi correttamente, spesso per file di boot corrotti, partizioni configurate male o impostazioni del firmware. Questa guida spiega passo passo come riparare il boot di Windows sui sistemi UEFI e su quelli MBR/Legacy, usando il prompt dei comandi dell'ambiente di ripristino di Windows (WinRE). Copre la preparazione delle partizioni, la ricostruzione della configurazione di boot e la soluzione dei problemi più comuni.

## Prerequisiti

- Una chiavetta USB o un DVD di installazione di Windows della stessa versione del tuo sistema.
- L'accesso all'ambiente di ripristino di Windows (WinRE): avvia dal supporto di installazione e scegli «Ripristina il computer».
- Un minimo di dimestichezza con il prompt dei comandi.
- Privilegi di amministratore nell'ambiente di ripristino.

## Avviso importante: controlla le partizioni prima di formattare

{{< callout type="warning" >}}
**Massima attenzione**: prima di formattare una partizione, usa i comandi `list disk` e `list part` di `diskpart` per verificare di aver selezionato il disco e la partizione giusti (per esempio la partizione di sistema EFI o la partizione di sistema). Formattare la partizione sbagliata può cancellare i dati di Windows o altri file critici. Ricontrolla sempre la disposizione di dischi e partizioni, per essere sicuro di non cancellare il disco dei dati.
{{< /callout >}}

## Riparare il boot di Windows

### Riparazione del boot UEFI

I sistemi UEFI usano una partizione di sistema EFI (ESP) per conservare i file di boot. Se la ESP manca, è corrotta o è configurata male, Windows può non avviarsi.

#### Preparazione delle partizioni
Per preparare o riparare la ESP e la partizione di Windows:

```cmd
diskpart
list disk
sel disk 0  # Verify this is the correct disk
list part   # Confirm partition layout (ESP is typically 100-300 MB, FAT32)

# Select EFI System Partition (ESP) - FAT32
sel part 1  # Verify this is the ESP
format quick fs=fat32
assign letter=s

# Select Windows Partition
sel part 3  # Verify this is the Windows partition
assign letter=c
exit
```

- **Spiegazione**:
  - `diskpart`: avvia lo strumento di partizionamento dei dischi.
  - `list disk`: elenca tutti i dischi, per confermare il numero del disco giusto.
  - `sel disk 0`: seleziona il disco principale (sostituisci `0` con il numero del disco giusto).
  - `list part`: mostra le partizioni, per individuare la ESP (di solito 100-300 MB, FAT32) e la partizione di Windows.
  - `sel part 1`: seleziona la ESP (verifica che sia la partizione giusta).
  - `format quick fs=fat32`: formatta la ESP in FAT32 (solo se necessario).
  - `assign letter=s`: assegna una lettera di unità per accedervi.
  - `sel part 3`: seleziona la partizione di Windows (verifica con `list part`).
  - `assign letter=c`: assegna una lettera di unità alla partizione di Windows.
  - `exit`: esce da diskpart.

#### Configurazione di boot
Per ricostruire la configurazione di boot UEFI:

```cmd
bcdboot c:\Windows /s S: /f UEFI
```

- **Spiegazione**:
  - `bcdboot`: copia i file di boot dalla partizione di Windows (`c:\Windows`) alla ESP (`S:`).
  - `/f UEFI`: indica il tipo di firmware UEFI, per garantire la compatibilità.

#### Creare a mano la partizione EFI
Se la ESP manca, creane una:

```cmd
diskpart
list disk
sel disk 0  # Verify this is the correct disk

# Create EFI partition (100MB)
create partition efi size=100 offset=1
format quick fs=fat32 label="System"
assign letter=S

# Create Microsoft Reserved (MSR) partition (128MB)
create partition msr size=128 offset=103424
exit
```

- **Spiegazione**:
  - `list disk`: conferma il disco giusto.
  - `create partition efi size=100 offset=1`: crea una partizione EFI da 100 MB con un offset di 1 KB per l'allineamento.
  - `format quick fs=fat32 label="System"`: formatta la partizione in FAT32 con l'etichetta «System».
  - `create partition msr size=128 offset=103424`: crea una partizione Microsoft Reserved da 128 MB (richiesta per UEFI).
  - Poi usa `bcdboot c:\Windows /s S: /f UEFI` per popolare la ESP.

### Riparazione del boot MBR/Legacy

I sistemi MBR/Legacy usano un processo di boot diverso, basato sul Master Boot Record e sul settore di boot.

#### Comandi standard di riparazione del boot
Lancia questi comandi nel prompt dei comandi di WinRE:

```cmd
bootrec /fixmbr
bootrec /fixboot
bootrec /scanos
bootrec /rebuildbcd
```

- **Spiegazione**:
  - `bootrec /fixmbr`: ripara il Master Boot Record per risolvere i problemi del boot loader.
  - `bootrec /fixboot`: scrive un nuovo settore di boot sulla partizione di sistema.
  - `bootrec /scanos`: cerca le installazioni di Windows non elencate nei Boot Configuration Data (BCD).
  - `bootrec /rebuildbcd`: ricostruisce l'archivio BCD includendo le installazioni di Windows trovate.

#### Metodo alternativo (se `bootrec /fixboot` fallisce con «access denied»)
Se `bootrec /fixboot` fallisce, usa questo metodo:

```cmd
diskpart
list disk
sel disk 0  # Verify this is the correct disk
list part   # Confirm partition layout (system partition is typically 100-500 MB)

# System partition - FAT32 or NTFS
sel part 1  # Verify this is the system partition
format quick fs=fat32
assign letter=s

# Windows partition
sel part 3  # Verify this is the Windows partition
assign letter=c
exit

# Rebuild boot configuration for all firmware types
bcdboot C:\Windows /s S: /f ALL
```

- **Spiegazione**:
  - `list disk` e `list part`: verificano la disposizione di dischi e partizioni, per non formattare il disco dei dati.
  - Formatta la partizione di sistema (di solito 100-500 MB) in FAT32 o NTFS (solo se necessario).
  - Assegna le lettere di unità per accedere alla partizione di sistema e a quella di Windows.
  - `bcdboot /f ALL`: crea file di boot compatibili sia con il firmware UEFI sia con il BIOS.

## Consigli e risoluzione dei problemi

### Problemi comuni
- **«`bootrec /fixboot` access denied»**:
  - Usa il metodo alternativo con `bcdboot` mostrato sopra.
  - Assicurati che la partizione di sistema sia attiva (comando `active` in `diskpart`, per MBR) o formattata correttamente (FAT32 per UEFI).
- **Compatibilità con i VHD**:
  - Quando crei partizioni per dischi rigidi virtuali (VHD), usa `subformat=fixed,force_size` in `diskpart` per una compatibilità migliore:
    ```cmd
    create vdisk file="C:\path\to\disk.vhd" maximum=50000 type=fixed
    attach vdisk
    create partition efi size=100 offset=1 subformat=fixed,force_size
    ```
- **Allineamento delle partizioni**:
  - Usa gli offset corretti (per esempio `offset=1` per la EFI, `offset=103424` per la MSR) per allineare le partizioni e avere prestazioni ottimali.
  - Verifica l'allineamento con `list part` in `diskpart`.
- **Installazione di Windows non trovata**:
  - Se `bootrec /scanos` non rileva Windows, assicurati che la partizione di Windows abbia una lettera assegnata e contenga `Windows\System32`.
- **UEFI e BIOS non corrispondono**:
  - Controlla le impostazioni del firmware nel setup BIOS/UEFI e assicurati che la modalità di boot sia quella giusta (UEFI o Legacy).
  - Usa `/f UEFI` per i sistemi UEFI o `/f BIOS` per i sistemi Legacy con `bcdboot`.
- **Perdita di dati per una formattazione**:
  - Usa sempre `list disk` e `list part` per confermare che stai formattando la partizione giusta (per esempio la ESP o la partizione di sistema).
  - Formattare per errore la partizione di Windows o quella dei dati fa perdere i dati. Fai un backup dei dati critici prima di procedere.

### Altri consigli
- **Backup del BCD**: prima di modificare il BCD, esportalo:
  ```cmd
  bcdedit /export C:\BCD_Backup
  ```
- **Verifica la disposizione dei dischi**: usa `list disk` e `list part` di `diskpart` per confermare disco e partizioni giusti prima di qualunque modifica.
- **Prova il boot**: dopo le riparazioni, riavvia e prova. Se i problemi restano, controlla le impostazioni del firmware o rilancia i comandi `bootrec`.

## Prossimi passi

Nei prossimi tutorial vedremo:
- La modifica avanzata del BCD con `bcdedit`.
- Il ripristino di Windows con Ripristino configurazione di sistema e la modalità provvisoria.
- L'automazione delle riparazioni di Windows con script PowerShell.

## Risorse
- [Documentazione Microsoft di Bootrec](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/bootrec)
- [Documentazione Microsoft di BCDboot](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/bcdboot-command-line-options-techref-di)
- [Ambiente di ripristino di Windows](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-recovery-environment--windows-re--technical-reference)

---

*Prova questi comandi in un ambiente di test per padroneggiare la riparazione del boot di Windows, e verifica sempre le partizioni per non perdere dati!*