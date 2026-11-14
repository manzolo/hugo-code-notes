---
title: "Salvare un disco che sta morendo con ddrescue"
url: "2026/09/rescuing-a-failing-disk-with-ddrescue/"
date: 2026-09-18T13:00:00+02:00
lastmod: 2026-09-18T13:00:00+02:00
draft: false
author: "Manzolo"
tags: ["disks", "recovery", "ddrescue", "linux", "smart"]
categories: ["Storage & Disks"]
series: ["Linux Storage Deep Dive"]
weight: 6
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "Copiare un disco che sta morendo finché si legge ancora: solo le zone che contengono dati, sopravvivendo alle cadute del disco stesso, senza mai scriverci sopra"
---

# Salvare un disco che sta morendo con ddrescue

{{< callout type="info" >}}
**A cosa serve**: un disco che legge piano, dà errori di I/O, sparisce dal bus o si rifiuta
di fare il boot. Tira fuori i dati **prima** di tentare qualunque riparazione - e il
paziente non si ripara mai.
{{< /callout >}}

## 🧭 Si ripara l'immagine, non il disco

> **`chkdsk /f`, `fsck` e `sfc /scannow` scrivono, tutti.** Su un disco che sta perdendo
> settori, ognuno di loro può trasformare una situazione recuperabile in una perdita definitiva.

La tesi è tutta qui. A un disco in avaria resta un certo numero di letture riuscite, e
nessuno sa quante siano. Spenderle per uno strumento di riparazione che martella il disco per
quaranta minuti - e ci riscrive sopra quello che crede di aver trovato - è il modo più
comune in cui un disco recuperabile diventa irrecuperabile.

Quindi l'ordine è obbligato:

```
1. establish that the disk really is the problem
2. copy it to an image, read-only, while it still reads
3. repair the IMAGE
4. the original disk is never written to, and never needed again
```

Tutto quello che segue è uno di questi passi, con le trappole che ciascuno nasconde.

## 🩺 Per prima cosa: è davvero il disco?

Tre letture, non una. E non valgono uguale:

| Lettura | Cos'è | Quanto fidarsi |
|---------|-----------|-------|
| **SMART** | Il resoconto che il disco fa di sé stesso | La **dichiarazione dell'indiziato** |
| **`dmesg`** | Quello che il kernel ha osservato parlandoci | Una **misura** |
| **Velocità di lettura sequenziale** | Quello che riesci davvero a tirarne fuori | Una **misura** |

SMART va letto, e va messo in dubbio. Un disco con il controller in avaria riporta
tranquillamente `PASSED` mentre non riesce a dare un megabyte al secondo: il firmware che
riferisce su sé stesso è il testimone meno indipendente che ci sia. **Se due delle tre
indicano il disco, smetti di diagnosticare e comincia a copiare.**

```bash
sudo smartctl -a /dev/sdd
sudo smartctl -l selftest /dev/sdd
```

Gli attributi che contano più del verdetto complessivo:

| Attributo | Significato |
|-----------|---------|
| `Reallocated_Sector_Ct` (5) | Settori già sostituiti con quelli di riserva. Se sale = degrado in corso |
| `Current_Pending_Sector` (197) | Illeggibili, non ancora riallocati. **Quelli che stai per perdere** |
| `Offline_Uncorrectable` (198) | Illeggibili, confermati |
| `Reported_Uncorrect` (187) | Errori che il disco non è riuscito a correggere |
| `Percentage_Used` / `Media_Wearout` | Usura dell'SSD - un altro modo di guastarsi |

```bash
# What the kernel sees, live, while you touch the disk
sudo dmesg -wT | grep -iE 'sd[a-z]|ata[0-9]|I/O error|offline|medium error'
```

Le righe da riconoscere al volo:

```text
critical medium error, dev sdd, sector 712
Device offlined - not ready after error recovery
rejecting I/O to offline device
```

Le ultime due non vogliono dire «il disco è lento». Vogliono dire che **il kernel ha
rinunciato del tutto al dispositivo**, e che da lì in poi tutto fallirà all'istante.
Tienile a mente: più avanti in questa pagina tornano.

```bash
# One short sequential read. Do not run a long benchmark on a dying drive.
sudo dd if=/dev/sdd of=/dev/null bs=1M count=2000 iflag=direct status=progress
```

Un SSD SATA che dà **8 MB/s invece di 500** ti ha già detto tutto quello che ti serve. Non
occorre altra diagnosi, e ogni minuto speso a farla è un minuto tolto alla copia.

## 📦 Prima di cominciare

{{< callout type="warning" >}}
**`ddrescue` vuole `infile outfile mapfile`, in quest'ordine.** Scambia i primi due e
scriverai la destinazione vuota sopra il disco che stavi cercando di salvare, in fretta e
in silenzio. Controlla il comando due volte prima di premere Invio. Non si torna indietro,
e non c'è nessuna richiesta di conferma.
{{< /callout >}}

```bash
# Identify by SERIAL, not by letter
lsblk -o NAME,SERIAL,SIZE,MODEL,TRAN
```

{{< callout type="warning" >}}
**Il nodo del dispositivo non è un'identità stabile.** Un disco in avaria che cade dal bus
e viene ri-enumerato torna con una *lettera diversa*: `/dev/sdd` diventa `/dev/sde`, e il
vecchio nodo adesso può appartenere a tutt'altro. Su un disco che si scollega di continuo
- cioè proprio il tipo di disco di cui stai facendo l'immagine - **conferma sempre il
seriale prima di ogni giro**, oppure fai cercare allo script il seriale invece del nome.
{{< /callout >}}

Altre tre regole prima del primo comando:

- **Fai l'immagine del disco intero** (`/dev/sdd`), non di una partizione. Ti servono la
  tabella delle partizioni, lo spazio prima della prima partizione e le strutture di backup
  in fondo.
- **Mai montare la sorgente in lettura-scrittura.** Meglio ancora non montarla affatto:
  monterai l'immagine, dopo.
- **La destinazione dev'essere un filesystem che supporta i file sparsi** - ext4, xfs,
  btrfs. Su exFAT o FAT32 un'immagine da 240 GB occupa 240 GB anche quando è quasi tutta
  buchi, e FAT32 un file di quelle dimensioni non lo può proprio contenere.

```bash
sudo apt install gddrescue        # the package is gddrescue; the binary is ddrescue
mkdir -p /mnt/rescue
```

## 🚑 Il giro di base, e perché il mapfile è tutto

```bash
sudo ddrescue -f -n /dev/sdd /mnt/rescue/disk.img /mnt/rescue/disk.map
```

| Flag | Perché |
|------|-----|
| `-f` | Obbligatorio quando la destinazione esiste già |
| `-n` | **Niente scraping**: la prima passata prende tutto quello che si legge facilmente, e non si ferma a combattere con le zone rovinate |
| *(mapfile)* | Non è facoltativo. Mai |

**Il mapfile è lo strumento intero.** Registra, blocco per blocco, cosa è stato copiato,
cosa è fallito e cosa non è mai stato tentato: così un giro interrotto riprende esattamente
da dove si era fermato, invece di ricominciare. Su un disco che cade ogni venti minuti, un
giro senza mapfile non è un recupero, è un ciclo infinito.

La prima passata prende i dati facili. Solo dopo si torna a prendere le parti difficili:

```bash
# Second pass: direct access, three retries on what is left
sudo ddrescue -d -r3 /dev/sdd /mnt/rescue/disk.img /mnt/rescue/disk.map
```

La mappa si può leggere in qualunque momento - non costa niente e non tocca l'hardware:

```bash
ddrescuelog -t /mnt/rescue/disk.map
```

```text
rescued: 51234 MB,  tried: 0 B,  bad-sector: 512 KB,  bad areas: 12
   pct rescued: 99.97%, read errors: 12, remaining time: 0
```

## ⏱️ Leggere solo quello che contiene davvero dati

Copiare un disco in sequenza vuol dire copiare anche il suo **spazio libero**. Su un disco
da 240 GB con 51 GiB di file, sono 172 GiB di niente - e a 8 MB/s sono più di sei ore
passate a leggere zeri, su un disco che intanto si degrada sotto la lettura.

A `ddrescue` si può dire di limitare ogni operazione a un insieme di blocchi:

```bash
sudo ddrescue -f -n --domain-mapfile=/mnt/rescue/domain.map \
    /dev/sdd /mnt/rescue/disk.img /mnt/rescue/disk.map
```

Il domain mapfile segna con `+` solo le zone che vale la pena leggere. Per un volume NTFS
lo puoi costruire a partire da **`$Bitmap`** - il registro in cui il filesystem stesso
annota quali cluster sono allocati (è sempre l'inode 6). Il risparmio non è marginale: sul
disco descritto qui sopra ha voluto dire **51 GiB invece di 224, e due ore invece di otto e
mezza.**

Cosa ci va dentro il dominio:

- la tabella delle partizioni e lo spazio prima della prima partizione;
- gli spazi fra le partizioni - pochi settori, non vale la pena escluderli;
- le partizioni piccole, per intero: analizzare una partizione di ripristino da 500 MB non
  fa risparmiare niente;
- per ogni partizione NTFS grande, i cluster che `$Bitmap` dà per allocati, **più l'ultimo
  settore** (NTFS ci tiene una copia di backup del boot sector);
- ogni partizione di cui non si riesce a leggere la bitmap: **la partizione intera**, con
  un avviso ben visibile. Nel dubbio, includi. Una mappa del dominio che esclude troppo
  produce un'immagine che sembra completa e non lo è.

{{< callout type="info" >}}
**A cosa rinunci**: lo spazio libero resta fuori, quindi l'immagine ha buchi di zeri dove
prima c'erano i file cancellati. **Tutti i file esistenti ci sono; il recupero forense di
quelli cancellati no.** Per una macchina che deve tornare a fare il boot è lo scambio
giusto. Per un'indagine, usa `--full` e paga le ore.
{{< /callout >}}

## 🔌 Quando il disco si mette offline da solo

Dopo tre reset falliti il kernel Linux dichiara perso il dispositivo e rifiuta ogni altro
I/O:

```text
Device offlined - not ready after error recovery
rejecting I/O to offline device
```

Da quel momento ogni lettura fallisce all'istante, e `ddrescue` va avanti lo stesso,
segnando come illeggibile un disco che è soltanto *assente*. La risposta classica è staccare
il cavo e riattaccarlo - che funziona, e richiede qualcuno lì in piedi alle 3 di notte.

C'è un'alternativa da una riga:

```bash
echo running | sudo tee /sys/block/sdd/device/state
```

Riscrivere lo stato del dispositivo SCSI lo riporta in vita senza toccare il cavo. Mettilo
in un ciclo e la copia va avanti da sola tutta la notte:

```bash
# Watchdog: poll every second, revive on sight
while :; do
    [ "$(cat /sys/block/sdd/device/state 2>/dev/null)" = offline ] &&
        echo running > /sys/block/sdd/device/state
    sleep 1
done
```

**Controlla ogni secondo, non ogni cinque.** In cinque secondi `ddrescue` fa in tempo ad
attraversare decine di GB di errori istantanei e a registrarli come veri - che è la
prossima trappola, e la peggiore di questa pagina.

## 🚩 Il falso rapporto: guarda la *velocità*, non il totale

A un certo punto un giro ha riportato **747.257 errori di lettura** su 49 GB, con una
velocità di errore di **5,3 GB/s**. Un verdetto apocalittico - ed è uscito con stato 0.

Il verdetto non valeva niente, e a tradirlo è la velocità:

> **Un disco che si sta sbriciolando sbaglia a kB/s. A MB/s non è guasto - è *assente*.**

Il disco si era messo offline da solo, il watchdog l'aveva riportato su cinque secondi
dopo, e in quei cinque secondi `ddrescue` aveva spazzato tutto il dominio raccogliendo un
errore istantaneo per regione. La difesa è un solo flag:

```bash
sudo ddrescue -f -n -E 1Mi -T 180 --domain-mapfile=/mnt/rescue/domain.map \
    /dev/sdd /mnt/rescue/disk.img /mnt/rescue/disk.map
```

| Flag | Effetto |
|------|--------|
| `-E 1Mi` | Esce quando la **velocità** di errore supera questa soglia. Un disco assente la fa scattare in un secondo |
| `-T 180` | Esce se passano 180 s senza nemmeno una lettura riuscita |

Poi rilancialo in un ciclo: ogni giro riprende dal mapfile, e un disco che ha bisogno di
duecento tentativi li ottiene senza che nessuno stia a guardare.

## 🕳️ Il buco silenzioso che `-E` si lascia dietro

Questo è il secondo strato della stessa trappola, e lo si scopre solo sbattendoci contro
due volte.

**Anche con `-E`**, nel secondo che precede lo scatto della soglia, `ddrescue` segna come
`*` (*non-trimmed*) tutto quello che stava per leggere - 17,9 GB nel caso qui sopra. E con
`-n` le regioni `*` **non vengono mai ritentate**. Così la protezione ha evitato il falso
rapporto e ha lasciato un **buco silenzioso nell'immagine**: dati mai letti, in una mappa
che non ha più intenzione di leggerli.

Il rimedio è azzerare, dopo ogni caduta, i segni che vogliono dire «interrotto», tenendo
quelli che vogliono dire «davvero illeggibile»:

```bash
# '*' non-trimmed and '/' non-scraped  ->  '?' never tried
ddrescuelog --change-types='*/,??' /mnt/rescue/disk.map > /mnt/rescue/disk.map.next
mv /mnt/rescue/disk.map.next /mnt/rescue/disk.map
```

I tipi di blocco del mapfile, perché questo è l'unico punto in cui contano:

| Tipo | Significato | Si azzera? |
|------|---------|-----------|
| `+` | Copiato | No |
| `?` | Mai tentato | — |
| `*` | Non-trimmed - *interrotto* prima di essere letto | **Sì** |
| `/` | Non-scraped - *interrotto* prima dello scraping | **Sì** |
| `-` | **Settore danneggiato**: letto uno per uno, e davvero illeggibile | **Mai** |

> **La differenza fra «non l'ho letto» e «l'ho letto e non si legge» è tutto, in un
> recupero.** `-` è un reperto. `*` è un'interruzione travestita da reperto.

## 🐢 Leggere con delicatezza

Su un disco che fa fatica, una richiesta da 1 MB va in timeout *tutta intera* - e si porta
via i settori sani che per caso conteneva. Richieste più piccole, niente readahead e un
timeout breve recuperano sensibilmente di più:

```bash
echo 64 | sudo tee /sys/block/sdd/queue/max_sectors_kb    # small requests
echo 0  | sudo tee /sys/block/sdd/queue/read_ahead_kb     # do not read ahead
echo 15 | sudo tee /sys/block/sdd/device/timeout          # fail fast, move on
```

Questi valori **tornano a quelli predefiniti quando il dispositivo viene rilevato di
nuovo**: su un disco che continua a cadere vanno quindi riapplicati a ogni ciclo, non
impostati una volta all'inizio.

## 🧾 Tutto quanto, dall'inizio alla fine

Un giro completo con numeri realistici: un SSD SATA da 240 GB in un box USB, circa 51 GiB
di dati veri, copiato in un'immagine su un disco di backup da 2 TB.

### 1. Trova i dischi

```bash
lsblk -o NAME,SERIAL,SIZE,MODEL,TRAN,MOUNTPOINTS
```

```text
NAME   SERIAL            SIZE MODEL                 TRAN   MOUNTPOINTS
sda    S3Z2NB0K512345  465.8G Samsung SSD 860 EVO   sata
├─sda1                   512M                              /boot/efi
└─sda2                 465.3G                              /
sdb    WD-WCC4N1234567   1.8T WDC WD20EZAZ-00GGJB0  usb
└─sdb1                   1.8T                              /mnt/backup
sdd    50026B7684A1B2C3  223.6G KINGSTON SA400S37240G usb
├─sdd1                   100M
├─sdd2                    16M
└─sdd3                 223.0G
```

Tre dischi, tre ruoli:

| Nodo | Seriale | Ruolo |
|------|--------|------|
| `sda` | `S3Z2NB0K512345` | **Questa macchina.** Non si tocca |
| `sdb` | `WD-WCC4N1234567` | **La destinazione**, montata su `/mnt/backup` |
| `sdd` | `50026B7684A1B2C3` | **Il paziente**: 223.6G, nessun mountpoint, partizioni che sembrano di Windows |

{{< callout type="warning" >}}
**Scriviti adesso il seriale del paziente**: `50026B7684A1B2C3`. Da qui in poi, ogni volta
che il disco cade dal bus e torna con una lettera diversa, è così che lo ritrovi - ed è
così che ti assicuri di non essere sul punto di copiare `sdb` sopra `sdd`.
{{< /callout >}}

```bash
# Resolve the serial to whatever node it holds right now
PATIENT=$(lsblk -ndo NAME,SERIAL | awk '$2=="50026B7684A1B2C3"{print "/dev/"$1}')
echo "$PATIENT"        # /dev/sdd
```

### 2. Conferma la diagnosi, in fretta

```bash
sudo smartctl -a "$PATIENT" | grep -E 'SMART overall|Reallocated_Sector|Current_Pending|Power_On'
```

```text
SMART overall-health self-assessment test result: PASSED
  5 Reallocated_Sector_Ct   0x0033   100   100   010    Pre-fail  Always  -  0
197 Current_Pending_Sector  0x0032   100   100   000    Old_age   Always  -  48
  9 Power_On_Hours          0x0032   091   091   000    Old_age   Always  -  31402
```

`PASSED`, e **48 settori pendenti**. Ecco esattamente perché SMART è la dichiarazione
dell'indiziato: il riepilogo dice che va tutto bene, il contatore dice 48 settori che non
riesce più a leggere.

```bash
sudo dd if="$PATIENT" of=/dev/null bs=1M count=500 iflag=direct status=progress
```

```text
524288000 bytes (524 MB, 500 MiB) copied, 62.4 s, 8.4 MB/s
```

8,4 MB/s da un SSD SATA che dovrebbe farne 500. Due misure su tre indicano il disco.
**Smetti di diagnosticare.**

### 3. Prepara la destinazione

```bash
df -h /mnt/backup                      # sparse image, but leave room for the full size
mkdir -p /mnt/backup/rescue-2026-09-18
cd /mnt/backup/rescue-2026-09-18
```

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb1       1.8T  412G  1.3T  25% /mnt/backup
```

### 4. Avvia il watchdog, in un terminale tutto suo

```bash
sudo bash -c '
while :; do
    n=$(lsblk -ndo NAME,SERIAL | awk "\$2==\"50026B7684A1B2C3\"{print \$1}")
    if [ -n "$n" ] && [ "$(cat /sys/block/$n/device/state 2>/dev/null)" = offline ]; then
        echo "$(date +%T) $n was offline -> running"
        echo running > /sys/block/$n/device/state
    fi
    sleep 1
done'
```

```text
03:14:22 sdd was offline -> running
04:51:07 sdd was offline -> running
```

Due cadute nella notte, tutte e due gestite senza nessuno presente.

### 5. Copialo

```bash
sudo ddrescue -f -n -E 1Mi -T 180 \
    --domain-mapfile=domain.map \
    /dev/sdd disk.img disk.map
```

```text
     ipos:   47218 MB, non-trimmed:   17956 MB,  current rate:    112 kB/s
     opos:   47218 MB,     non-scraped:       0 B,  average rate:   7986 kB/s
non-tried:    3894 MB,        bad-sector:     512 kB,    error rate:    5341 MB/s
  rescued:   47320 MB,         bad areas:       12,        run time:  1h 38m
pct rescued:   92.38%, read errors:   747257,  remaining time:         n/a
```

**Leggi la velocità di errore prima del totale degli errori.** 747.257 errori a **5341
MB/s** non descrivono un disco che va in pezzi - descrivono un disco che non c'era.
`-E 1Mi` se n'è accorto e si è fermato. Adesso rimedia al danno che quella caduta ha fatto
alla mappa:

```bash
cp -a disk.map disk.map.before-reset
ddrescuelog --change-types='*/,??' disk.map > disk.map.next && mv disk.map.next disk.map
ddrescuelog -t disk.map
```

```text
non-tried:   21850 MB,  bad-sector:   512 kB,  bad areas:  12
  rescued:   47320 MB,  pct rescued: 68.41%
```

Guarda cos'è successo: **17.956 MB di `non-trimmed` sono tornati `non-tried`**. Il 92%
apparente era una bugia - contava come «gestiti» quasi 18 GB che non erano mai stati letti.
Il 68% è la verità, ed è il numero da cui ripartirà il prossimo giro.

### 6. Ripeti in ciclo finché non finisce

```bash
for i in $(seq 1 200); do
    n=$(lsblk -ndo NAME,SERIAL | awk '$2=="50026B7684A1B2C3"{print "/dev/"$1}')
    [ -n "$n" ] || { echo "disk gone, waiting"; sleep 30; continue; }

    # these revert on every re-probe, so set them every time
    b=$(basename "$n")
    echo 64 | sudo tee /sys/block/$b/queue/max_sectors_kb >/dev/null
    echo 0  | sudo tee /sys/block/$b/queue/read_ahead_kb  >/dev/null
    echo 15 | sudo tee /sys/block/$b/device/timeout       >/dev/null

    echo "== attempt $i on $n - $(date +%T)"
    sudo ddrescue -f -n -E 1Mi -T 180 --domain-mapfile=domain.map "$n" disk.img disk.map

    left=$(ddrescuelog -t disk.map | awk '/non-tried/{print $2}')
    [ "$left" = "0" ] && { echo "done"; break; }

    ddrescuelog --change-types='*/,??' disk.map > disk.map.next && mv disk.map.next disk.map
    sleep 15
done
```

```text
== attempt 1 on /dev/sdd - 22:41:03
== attempt 2 on /dev/sde - 23:19:47      <- note: different letter, same serial
== attempt 3 on /dev/sde - 01:02:11
...
== attempt 27 on /dev/sdf - 06:38:55
done
```

Il tentativo 2 è il motivo di tutte quelle ricerche per seriale: il disco è tornato come
`/dev/sde`. Uno script con `/dev/sdd` scritto fisso dentro in quel momento avrebbe letto
qualunque altra cosa a cui il kernel avesse dato quel nome.

### 7. Il verdetto finale

```bash
ddrescuelog -t disk.map
```

```text
     rescued:   54892 MB,  bad-sector:    512 kB,  bad areas:  12
   non-tried:        0 B,  pct rescued:  99.9991%
```

512 kB illeggibili su 51 GiB, in 12 zone. **Questo è un reperto**, non un'interruzione -
sono blocchi `-`, letti un settore alla volta e morti davvero. In quali file cadano è una
domanda da fare all'immagine, non al disco:

```bash
sudo losetup -fP --show disk.img       # /dev/loop0
```

Adesso il disco va in un cassetto. Da qui in poi tutto succede sulla copia.

## 🧪 Adesso ripara l'immagine

Il disco va in un cassetto. Da qui in poi tutto succede sulla copia.

```bash
# Attach the image with its partition table
sudo losetup -fP --show /mnt/rescue/disk.img      # -> /dev/loop0
lsblk /dev/loop0
sudo mount -o ro /dev/loop0p3 /mnt/win            # read-only first: just look
```

Prima di lanciare qualunque cosa che scriva, crea un **overlay copy-on-write**: così una
riparazione fallita non costa niente e ne puoi provare un'altra:

```bash
qemu-img create -f qcow2 -b /mnt/rescue/disk.img -F raw /mnt/rescue/overlay.qcow2
```

Poi ripara dentro una VM, dove gli strumenti di Windows possono fare bene il loro lavoro:

```bash
qemu-system-x86_64 -m 4096 -enable-kvm -machine q35 \
  -device ahci,id=ahci \
  -drive file=/mnt/rescue/overlay.qcow2,format=qcow2,if=none,id=d0 \
  -device ide-hd,bus=ahci.0,drive=d0,bootindex=0 -vga std
```

Adesso `chkdsk /f`, `sfc /scannow` e `DISM /RestoreHealth` si possono lanciare senza
rischi, perché il peggio che possono fare è rovinare un file che ricrei in un secondo con
`qemu-img`. È tutto qui il motivo per cui si fa prima l'immagine: **gli strumenti di
riparazione diventano innocui quando il paziente è una copia.**

Per una sistemata veloce al filesystem senza avviare niente:

```bash
sudo ntfsfix -d /dev/loop0p3        # replays the journal, clears the dirty bit
```

## 💀 L'ipotesi che è morta: il bridge USB

Vale la pena metterla agli atti, perché era la teoria ovvia ed era sbagliata.

Un SSD SATA che legge a **8 MB/s** attraverso un box USB punta dritto al bridge: un
adattatore difettoso, un quirk del driver `uas`, un collegamento negoziato a velocità USB 2.
La teoria era abbastanza sicura di sé da consigliare l'acquisto di un cavo SATA.

È stata messa alla prova come si deve, cambiando il bridge:

| Bridge | Driver | Velocità | Link |
|--------|--------|-------|------|
| Generico vecchio | `uas` | 7.0 MB/s | 5000M |
| Generico vecchio | `usb-storage` | 8.9 MB/s | 5000M |
| Realtek nuovo | `uas` | 7.6 MB/s | 5000M |

Due bridge, due driver, il collegamento negoziato a 5 Gbps in tutti i casi. **Il collo di
bottiglia era il disco**, e il cavo SATA promesso si è dovuto ritrattare pubblicamente.

Peggio ancora, i tentativi di «dare una mano» hanno peggiorato davvero le cose: un quirk
anti-UAS che non ha cambiato niente, e la ri-enumerazione forzata con `authorized=0/1`, che
ha bloccato il controller fino al timeout perfino su un settore che aveva letto un minuto
prima. Lì è servito staccare fisicamente il cavo - l'unico momento di tutto il recupero in
cui una mano è servita davvero.

La lezione vale anche fuori dai dischi: **quando una misura è brutta, cambia una variabile
e misura di nuovo.** Due bridge e due driver sono costati dieci minuti e hanno chiuso la
questione. Ragionare su quale adattatore fosse migliore sarebbe costato una giornata e un
ordine.

## 📊 I flag da ricordare

| Flag | Cosa fa | Quando |
|------|--------------|------|
| `-f` | Sovrascrive un file di output che esiste già | Sempre, dopo il primo giro |
| `-n` | Niente scraping: prima i dati facili | **Prima passata, sempre** |
| `-d` | Accesso diretto, salta la cache del kernel | Dalla seconda passata in poi |
| `-r3` | Ritenta tre volte le zone danneggiate | Seconda passata |
| `-E 1Mi` | Esce quando la **velocità** di errore è assurda | Un disco che si scollega |
| `-T 180` | Esce dopo 180 s senza letture riuscite | Giri senza nessuno davanti |
| `--domain-mapfile=` | Legge solo le zone segnate | Disco grande, pochi dati |
| `-R` | Direzione inversa | Zone danneggiate concentrate in fondo |
| `--full` | *(convenzione di questo articolo)* ignora il dominio | Analisi forense, file cancellati |

## ✅ La checklist da riusare

1. **Tre letture, non una**: SMART, `dmesg`, velocità sequenziale. SMART è la dichiarazione
   dell'indiziato.
2. **Due su tre indicano il disco? Smetti di diagnosticare.** Ogni altro test spende letture
   che non puoi rimpiazzare.
3. **Identifica per seriale**, mai per lettera - la lettera cambia quando il disco viene ri-enumerato.
4. **`infile outfile mapfile`.** Leggi il comando due volte.
5. **Prima passata con `-n`**, disco intero, con un domain mapfile se è quasi tutto vuoto.
6. **`-E` e `-T`** su ogni disco che si scollega, e un watchdog che controlla ogni **secondo**.
7. **Dopo ogni caduta riporta `*` e `/` a `?`** - e non toccare mai `-`.
8. **Controlla la *velocità* di errore prima di credere al *totale* degli errori.** MB/s vuol dire assente, non rotto.
9. **Ripara l'immagine, su un overlay qcow2.** Sul disco originale non si scrive mai più.
10. **Solo a quel punto** lancia `chkdsk`, `sfc` o `DISM` - dentro la VM, sulla copia.

---

**Vedi anche:**
- [Riparazione e manutenzione del sistema Windows](/2025/10/windows-system-repair-and-maintenance/) - gli strumenti da lanciare **sull'immagine**, nell'ordine giusto
- [Riparazione del boot di Windows](/2025/09/windows-boot-repair/)
- [Gestione della cifratura dei dischi con LUKS](/2025/10/luks-disk-encryption-management-guide-debian/)

---

*La prima regola del recupero dati è che il paziente non si opera. Si opera la copia.*
