---
title: "Rescuing a Failing Disk with ddrescue"
date: 2026-09-18T13:00:00+02:00
lastmod: 2026-09-18T13:00:00+02:00
draft: false
author: "Manzolo"
tags: ["disks", "recovery", "ddrescue", "linux", "smart", "quick-tip"]
categories: ["Quick Pills"]
series: ["Quick Pills Collection"]
weight: 8
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "Copy a dying disk while it is still readable: only the areas that hold data, surviving the drive's own collapses, without ever writing to it"
---

# 💊 Quick Pill: Rescuing a Failing Disk with ddrescue

{{< callout type="info" >}}
**Use case**: a disk that reads slowly, throws I/O errors, disappears from the bus or
refuses to boot. Get the data off it **before** attempting any repair - and never repair
the patient.
{{< /callout >}}

## 🧭 You repair the image, not the disk

> **`chkdsk /f`, `fsck` and `sfc /scannow` all write.** On a drive that is losing sectors,
> every one of them can turn a recoverable situation into a permanent loss.

This is the entire thesis. A failing disk has a budget of successful reads left, and nobody
knows how large it is. Spending that budget on a repair tool that hammers the drive for
forty minutes - and writes back what it thinks it found - is the most common way a
recoverable disk becomes an unrecoverable one.

So the order is fixed:

```
1. establish that the disk really is the problem
2. copy it to an image, read-only, while it still reads
3. repair the IMAGE
4. the original disk is never written to, and never needed again
```

Everything below is one step of that, with the traps that each one hides.

## 🩺 First: is it really the disk?

Three readings, not one. And they are not equal:

| Reading | What it is | Trust |
|---------|-----------|-------|
| **SMART** | The drive's own account of itself | The **suspect's statement** |
| **`dmesg`** | What the kernel observed while talking to it | A **measurement** |
| **Sequential read speed** | What you can actually get out of it | A **measurement** |

SMART is worth reading and worth doubting. A drive with a failing controller will happily
report `PASSED` while being unable to deliver a megabyte per second: the firmware reporting
on itself is the least independent witness available. **If two of the three point at the
disk, stop diagnosing and start copying.**

```bash
sudo smartctl -a /dev/sdd
sudo smartctl -l selftest /dev/sdd
```

The attributes that matter more than the overall verdict:

| Attribute | Meaning |
|-----------|---------|
| `Reallocated_Sector_Ct` (5) | Sectors already swapped for spares. Rising = active decay |
| `Current_Pending_Sector` (197) | Unreadable, not yet reallocated. **The ones you are about to lose** |
| `Offline_Uncorrectable` (198) | Confirmed unreadable |
| `Reported_Uncorrect` (187) | Errors the drive could not correct |
| `Percentage_Used` / `Media_Wearout` | SSD wear - a different failure mode |

```bash
# What the kernel sees, live, while you touch the disk
sudo dmesg -wT | grep -iE 'sd[a-z]|ata[0-9]|I/O error|offline|medium error'
```

Lines worth recognising immediately:

```text
critical medium error, dev sdd, sector 712
Device offlined - not ready after error recovery
rejecting I/O to offline device
```

The last two are not "the disk is slow". They mean **the kernel has given up on the device
entirely**, and everything after that point will fail instantly. Remember them - they come
back later on this page.

```bash
# One short sequential read. Do not run a long benchmark on a dying drive.
sudo dd if=/dev/sdd of=/dev/null bs=1M count=2000 iflag=direct status=progress
```

A SATA SSD that delivers **8 MB/s instead of 500** has told you everything you need. No
further diagnosis is required, and every minute spent on one is a minute not spent copying.

## 📦 Before you start

{{< callout type="warning" >}}
**`ddrescue` takes `infile outfile mapfile`, in that order.** Reverse the first two and you
will write the empty destination over the disk you were trying to save, quickly and
silently. Check the command twice before pressing Enter. There is no undo, and no
confirmation prompt.
{{< /callout >}}

```bash
# Identify by SERIAL, not by letter
lsblk -o NAME,SERIAL,SIZE,MODEL,TRAN
```

{{< callout type="warning" >}}
**The device node is not a stable identity.** A failing disk that drops off the bus and
re-enumerates comes back as a *different letter*: `/dev/sdd` becomes `/dev/sde`, and the
old node may now belong to something else entirely. On a drive that disconnects repeatedly
- which is exactly the kind you are imaging - **always confirm the serial before every
run**, or script the lookup by serial rather than by name.
{{< /callout >}}

Three more rules before the first command:

- **Image the whole disk** (`/dev/sdd`), not a partition. You want the partition table, the
  gap before the first partition and the backup structures at the end.
- **Never mount the source read-write.** Ideally never mount it at all: mount the image
  afterwards.
- **The destination must be a filesystem with sparse-file support** - ext4, xfs, btrfs. On
  exFAT or FAT32 a 240 GB image occupies 240 GB even when most of it is holes, and FAT32
  cannot hold a file that size at all.

```bash
sudo apt install gddrescue        # the package is gddrescue; the binary is ddrescue
mkdir -p /mnt/rescue
```

## 🚑 The basic run, and why the mapfile is everything

```bash
sudo ddrescue -f -n /dev/sdd /mnt/rescue/disk.img /mnt/rescue/disk.map
```

| Flag | Why |
|------|-----|
| `-f` | Required when the destination already exists |
| `-n` | **No scraping**: first pass grabs everything that reads easily, and does not stop to fight the bad areas |
| *(mapfile)* | Not optional. Ever |

**The mapfile is the whole tool.** It records, block by block, what has been copied, what
failed and what has never been tried - so an interrupted run resumes exactly where it
stopped instead of starting again. On a disk that falls over every twenty minutes, a run
without a mapfile is not a recovery, it is a loop.

The first pass takes the easy data. Only afterwards do you go back for the hard parts:

```bash
# Second pass: direct access, three retries on what is left
sudo ddrescue -d -r3 /dev/sdd /mnt/rescue/disk.img /mnt/rescue/disk.map
```

Read the map at any time - it costs nothing and touches no hardware:

```bash
ddrescuelog -t /mnt/rescue/disk.map
```

```text
rescued: 51234 MB,  tried: 0 B,  bad-sector: 512 KB,  bad areas: 12
   pct rescued: 99.97%, read errors: 12, remaining time: 0
```

## ⏱️ Read only what actually holds data

Copying a disk sequentially means copying its **free space** too. On a 240 GB drive with
51 GiB of files, that is 172 GiB of nothing - and at 8 MB/s it is more than six hours spent
reading zeros, on a drive that is degrading while you read it.

`ddrescue` can be told to restrict every operation to a set of blocks:

```bash
sudo ddrescue -f -n --domain-mapfile=/mnt/rescue/domain.map \
    /dev/sdd /mnt/rescue/disk.img /mnt/rescue/disk.map
```

The domain mapfile marks with `+` only the areas worth reading. For an NTFS volume you can
build it from **`$Bitmap`** - the filesystem's own record of which clusters are allocated
(it is always inode 6). The saving is not marginal: on the drive described above it meant
**51 GiB instead of 224, and two hours instead of eight and a half.**

What belongs inside the domain:

- the partition table and the gap before the first partition;
- the gaps between partitions - a few sectors, not worth excluding;
- small partitions in full: analysing a 500 MB recovery partition saves nothing;
- for each large NTFS partition, the clusters `$Bitmap` calls allocated, **plus the last
  sector** (NTFS keeps a backup boot sector there);
- any partition whose bitmap cannot be read: **the whole partition**, with a loud warning.
  When in doubt, include. A domain map that excludes too much produces an image that looks
  complete and is not.

{{< callout type="info" >}}
**What you give up**: the free space stays out, so the image has holes of zeros where
deleted files used to be. **Every existing file is there; forensic recovery of deleted ones
is not.** For a machine that has to boot again, that is the right trade. For an
investigation, use `--full` and pay the hours.
{{< /callout >}}

## 🔌 When the drive takes itself offline

After three failed resets the Linux kernel declares the device lost and refuses all further
I/O:

```text
Device offlined - not ready after error recovery
rejecting I/O to offline device
```

From that moment every read fails instantly, and `ddrescue` keeps going, marking as
unreadable a disk that is merely *absent*. The classic response is to pull the cable and
plug it back in - which works, and requires somebody to be standing there at 3 a.m.

There is a one-line alternative:

```bash
echo running | sudo tee /sys/block/sdd/device/state
```

Rewriting the SCSI device state brings it back without touching the cable. Put it in a loop
and the copy runs unattended all night:

```bash
# Watchdog: poll every second, revive on sight
while :; do
    [ "$(cat /sys/block/sdd/device/state 2>/dev/null)" = offline ] &&
        echo running > /sys/block/sdd/device/state
    sleep 1
done
```

**Poll at one second, not five.** In five seconds `ddrescue` has time to cross tens of GB of
instant errors and record them as real - which is the next trap, and the worst one on this
page.

## 🚩 The false report: check the *rate*, not the total

At one point a run reported **747,257 read errors** across 49 GB, with an error rate of
**5.3 GB/s**. An apocalyptic verdict - and it exited with status 0.

The verdict was worthless, and the giveaway is the rate:

> **A disk that is crumbling errs at kB/s. At MB/s it is not failing - it is *absent*.**

The drive had taken itself offline, the watchdog had brought it back five seconds later,
and in those five seconds `ddrescue` had swept the entire domain collecting one instantaneous
error per region. The defence is a single flag:

```bash
sudo ddrescue -f -n -E 1Mi -T 180 --domain-mapfile=/mnt/rescue/domain.map \
    /dev/sdd /mnt/rescue/disk.img /mnt/rescue/disk.map
```

| Flag | Effect |
|------|--------|
| `-E 1Mi` | Exit when the error **rate** exceeds this. An absent disk trips it in a second |
| `-T 180` | Exit if 180 s pass with no successful read at all |

Then relaunch in a loop: each run resumes from the mapfile, and a drive that needs two
hundred attempts gets them without anyone watching.

## 🕳️ The silent hole `-E` leaves behind

This is the second layer of the same trap, and it is only discovered by hitting it twice.

**Even with `-E`**, in the second before the threshold trips, `ddrescue` marks as `*`
(*non-trimmed*) everything it was about to read - 17.9 GB in the case above. And with `-n`,
`*` regions are **never retried**. So the protection prevented the false report and left a
**silent hole in the image**: data that was never read, in a map that no longer intends to
read it.

The fix is to reset, after every collapse, the marks that mean "interrupted" while keeping
the ones that mean "genuinely unreadable":

```bash
# '*' non-trimmed and '/' non-scraped  ->  '?' never tried
ddrescuelog --change-types='*/,??' /mnt/rescue/disk.map > /mnt/rescue/disk.map.next
mv /mnt/rescue/disk.map.next /mnt/rescue/disk.map
```

The mapfile block types, because this is the one place they matter:

| Type | Meaning | Reset it? |
|------|---------|-----------|
| `+` | Copied | No |
| `?` | Never tried | — |
| `*` | Non-trimmed - *interrupted* before being read | **Yes** |
| `/` | Non-scraped - *interrupted* before being scraped | **Yes** |
| `-` | **Bad sector**: read one by one, and genuinely unreadable | **Never** |

> **The difference between "I have not read it" and "I read it and it will not read" is
> everything in a recovery.** `-` is a finding. `*` is an interruption wearing a finding's
> clothes.

## 🐢 Read gently

On a drive that is struggling, a 1 MB request times out *as a whole* - taking with it the
healthy sectors it happened to contain. Smaller requests, no readahead, and a short timeout
recover measurably more:

```bash
echo 64 | sudo tee /sys/block/sdd/queue/max_sectors_kb    # small requests
echo 0  | sudo tee /sys/block/sdd/queue/read_ahead_kb     # do not read ahead
echo 15 | sudo tee /sys/block/sdd/device/timeout          # fail fast, move on
```

These values **revert to defaults when the device is re-probed**, so on a disk that keeps
dropping off they must be reapplied on every cycle, not set once at the start.

## 🧾 The whole thing, end to end

A complete run with realistic numbers: a 240 GB SATA SSD in a USB enclosure, about 51 GiB
of actual data, imaged onto a 2 TB backup drive.

### 1. Find the disks

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

Three disks, three roles:

| Node | Serial | Role |
|------|--------|------|
| `sda` | `S3Z2NB0K512345` | **This machine.** Do not touch |
| `sdb` | `WD-WCC4N1234567` | **Destination**, mounted at `/mnt/backup` |
| `sdd` | `50026B7684A1B2C3` | **The patient**: 223.6G, no mountpoints, partitions look like Windows |

{{< callout type="warning" >}}
**Write down the serial of the patient now**: `50026B7684A1B2C3`. From here on, every time
the disk drops off the bus and comes back as a different letter, this is how you find it
again - and how you make sure you are not about to image `sdb` over `sdd`.
{{< /callout >}}

```bash
# Resolve the serial to whatever node it holds right now
PATIENT=$(lsblk -ndo NAME,SERIAL | awk '$2=="50026B7684A1B2C3"{print "/dev/"$1}')
echo "$PATIENT"        # /dev/sdd
```

### 2. Confirm the diagnosis, quickly

```bash
sudo smartctl -a "$PATIENT" | grep -E 'SMART overall|Reallocated_Sector|Current_Pending|Power_On'
```

```text
SMART overall-health self-assessment test result: PASSED
  5 Reallocated_Sector_Ct   0x0033   100   100   010    Pre-fail  Always  -  0
197 Current_Pending_Sector  0x0032   100   100   000    Old_age   Always  -  48
  9 Power_On_Hours          0x0032   091   091   000    Old_age   Always  -  31402
```

`PASSED`, and **48 pending sectors**. This is exactly why SMART is the suspect's own
statement: the summary says fine, the counter says 48 sectors it can no longer read.

```bash
sudo dd if="$PATIENT" of=/dev/null bs=1M count=500 iflag=direct status=progress
```

```text
524288000 bytes (524 MB, 500 MiB) copied, 62.4 s, 8.4 MB/s
```

8.4 MB/s from a SATA SSD that should do 500. Two measurements out of three point at the
disk. **Stop diagnosing.**

### 3. Prepare the destination

```bash
df -h /mnt/backup                      # sparse image, but leave room for the full size
mkdir -p /mnt/backup/rescue-2026-09-18
cd /mnt/backup/rescue-2026-09-18
```

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb1       1.8T  412G  1.3T  25% /mnt/backup
```

### 4. Start the watchdog, in its own terminal

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

Two collapses overnight, both handled without anyone present.

### 5. Copy it

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

**Read the error rate before the error total.** 747,257 errors at **5341 MB/s** does not
describe a disk falling apart - it describes a disk that was not there. `-E 1Mi` caught it
and stopped. Now undo the damage that collapse did to the map:

```bash
cp -a disk.map disk.map.before-reset
ddrescuelog --change-types='*/,??' disk.map > disk.map.next && mv disk.map.next disk.map
ddrescuelog -t disk.map
```

```text
non-tried:   21850 MB,  bad-sector:   512 kB,  bad areas:  12
  rescued:   47320 MB,  pct rescued: 68.41%
```

Note what happened: **17,956 MB of `non-trimmed` went back to `non-tried`**. The apparent
92% was a lie - it counted as "handled" nearly 18 GB that had never been read. 68% is the
truth, and it is the number the next run will work from.

### 6. Loop until it finishes

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

Attempt 2 is the reason for all the serial lookups: the disk came back as `/dev/sde`. A
script hard-coded to `/dev/sdd` would at that moment have been reading whatever else the
kernel had given that name to.

### 7. The final verdict

```bash
ddrescuelog -t disk.map
```

```text
     rescued:   54892 MB,  bad-sector:    512 kB,  bad areas:  12
   non-tried:        0 B,  pct rescued:  99.9991%
```

512 kB unreadable out of 51 GiB, in 12 areas. **That is a finding**, not an interruption -
those are `-` blocks, read one sector at a time and genuinely dead. Which files they fall
in is a question for the image, not for the disk:

```bash
sudo losetup -fP --show disk.img       # /dev/loop0
```

The disk goes in a drawer now. Everything from here happens on the copy.

## 🧪 Now repair the image

The disk goes in a drawer. Everything from here happens on the copy.

```bash
# Attach the image with its partition table
sudo losetup -fP --show /mnt/rescue/disk.img      # -> /dev/loop0
lsblk /dev/loop0
sudo mount -o ro /dev/loop0p3 /mnt/win            # read-only first: just look
```

Before running anything that writes, take a **copy-on-write overlay**, so a failed repair
costs nothing and you can try a different one:

```bash
qemu-img create -f qcow2 -b /mnt/rescue/disk.img -F raw /mnt/rescue/overlay.qcow2
```

Then repair inside a VM, where the Windows tools can do their job properly:

```bash
qemu-system-x86_64 -m 4096 -enable-kvm -machine q35 \
  -device ahci,id=ahci \
  -drive file=/mnt/rescue/overlay.qcow2,format=qcow2,if=none,id=d0 \
  -device ide-hd,bus=ahci.0,drive=d0,bootindex=0 -vga std
```

Now `chkdsk /f`, `sfc /scannow` and `DISM /RestoreHealth` are safe to run, because the worst
they can do is ruin a file you can recreate in a second with `qemu-img`. That is the whole
reason for imaging first: **repair tools become harmless once the patient is a copy.**

For a quick filesystem fix without booting anything:

```bash
sudo ntfsfix -d /dev/loop0p3        # replays the journal, clears the dirty bit
```

## 💀 The hypothesis that died: the USB bridge

Worth recording, because it was the obvious theory and it was wrong.

A SATA SSD reading at **8 MB/s** through a USB enclosure points straight at the bridge: a
bad adapter, a `uas` driver quirk, a link negotiated at USB 2 speeds. The theory was
confident enough to recommend buying a SATA cable.

It was tested properly, by swapping the bridge:

| Bridge | Driver | Speed | Link |
|--------|--------|-------|------|
| Old generic | `uas` | 7.0 MB/s | 5000M |
| Old generic | `usb-storage` | 8.9 MB/s | 5000M |
| New Realtek | `uas` | 7.6 MB/s | 5000M |

Two bridges, two drivers, the link negotiated at 5 Gbps in every case. **The bottleneck was
the disk**, and the promised SATA cable had to be publicly retracted.

Worse, the attempts to "help" made things actively worse: an anti-UAS quirk that changed
nothing, and forcing re-enumeration through `authorized=0/1`, which hung the controller
until it timed out even on a sector it had read a minute earlier. That one needed a physical
unplug - the only moment in the whole recovery when a hand was genuinely required.

The lesson generalises past disks: **when a measurement is bad, change one variable and
measure again.** Two bridges and two drivers cost ten minutes and settled it. Reasoning
about which adapter was better would have cost a day and an order.

## 📊 Flags worth remembering

| Flag | What it does | When |
|------|--------------|------|
| `-f` | Overwrite an existing output file | Always, after the first run |
| `-n` | No scraping: take the easy data first | **First pass, always** |
| `-d` | Direct access, bypass the kernel cache | Second pass onwards |
| `-r3` | Retry bad areas three times | Second pass |
| `-E 1Mi` | Exit when the error **rate** is absurd | A disk that disconnects |
| `-T 180` | Exit after 180 s with no successful read | Unattended runs |
| `--domain-mapfile=` | Read only the marked areas | Large disk, little data |
| `-R` | Reverse direction | Bad areas clustered at the end |
| `--full` | *(this article's convention)* ignore the domain | Forensics, deleted files |

## ✅ The reusable checklist

1. **Three readings, not one**: SMART, `dmesg`, sequential speed. SMART is the suspect's
   own statement.
2. **Two out of three point at the disk? Stop diagnosing.** Every further test spends reads
   you cannot replace.
3. **Identify by serial**, never by letter - the letter changes when the drive re-enumerates.
4. **`infile outfile mapfile`.** Read the command twice.
5. **First pass `-n`**, whole disk, with a domain mapfile if most of it is empty.
6. **`-E` and `-T`** on any drive that disconnects, and a watchdog polling at **one second**.
7. **After every collapse, reset `*` and `/` to `?`** - and never touch `-`.
8. **Check the error *rate* before believing the error *total*.** MB/s means absent, not broken.
9. **Repair the image, on a qcow2 overlay.** The original disk is never written to again.
10. **Only then** run `chkdsk`, `sfc` or `DISM` - inside the VM, on the copy.

---

**Related Pills:**
- [Windows System Repair and Maintenance](/2025/10/windows-system-repair-and-maintenance/) - the tools to run **on the image**, in the right order
- [Windows Boot Repair](/2025/09/windows-boot-repair/)
- [LUKS Disk Encryption Management](/2025/10/luks-disk-encryption-management-guide-debian/)

---

*The first rule of data recovery is that the patient does not get operated on. The copy does.*
