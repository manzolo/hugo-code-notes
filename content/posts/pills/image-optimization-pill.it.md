---
title: "Ottimizzare le immagini in blocco"
url: "2025/10/batch-image-optimization/"
date: 2025-10-05T16:00:00+02:00
lastmod: 2026-11-14T19:00:00+01:00
draft: false
author: "Manzolo"
tags: ["images", "optimization", "compression", "web", "quick-tip"]
categories: ["Quick Pills"]
series: ["Quick Pills Collection"]
weight: 4
ShowToc: false
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "Guida rapida per ottimizzare in blocco le immagini JPEG per il web, riducendo il peso dei file senza perdere qualità"
---

# 💊 Pillola rapida: ottimizzare le immagini in blocco

{{< callout type="info" >}}
**A cosa serve**: ottimizzare centinaia di immagini JPEG per un sito, risparmiare spazio su disco, velocizzare il caricamento delle pagine o preparare le foto da condividere.
{{< /callout >}}

## 🚀 Preparazione rapida

### Installare gli strumenti necessari

```bash
# Ubuntu/Debian
sudo apt install jpegoptim optipng

# Fedora/RHEL
sudo dnf install jpegoptim optipng

# macOS (with Homebrew)
brew install jpegoptim optipng
```

## 📸 Ottimizzazione di base

### Ottimizzare tutti i JPEG di una cartella

Salvalo come `optimize_images.sh`:

```bash
#!/bin/bash

# Go to your images folder
cd imgfolder

# Find and optimize all JPEGs
find . -type f -name "*.jpg" -exec jpegoptim -P --max=35 --strip-all {} \;
```

**Cosa fa:**
- `find . -type f -name "*.jpg"`: trova tutti i file `.jpg`, anche nelle sottocartelle
- `-exec jpegoptim`: esegue jpegoptim su ogni file
- `-P`: conserva la data di modifica del file
- `--max=35`: imposta la qualità al 35% (compressione aggressiva)
- `--strip-all`: toglie tutti i metadati (EXIF, GPS, ecc.)

{{< callout type="warning" >}}
**⚠️ Prima il backup!** Il comando modifica i file sul posto. Provalo sempre prima su delle copie.
{{< /callout >}}

### Eseguire lo script

```bash
chmod +x optimize_images.sh
./optimize_images.sh
```

## 🎨 Guida ai livelli di qualità

### Le impostazioni di qualità JPEG

| Qualità | Quando usarla | Peso del file | Resa visiva |
|---------|----------|-----------|----------------|
| `--max=35` | Miniature, compressione aggressiva | Molto piccolo | Accettabile |
| `--max=50` | Immagini per il web, articoli del blog | Piccolo | Buona |
| `--max=70` | Uso web standard | Medio | Molto buona |
| `--max=85` | Web ad alta qualità | Più grande | Eccellente |
| `--max=95` | Stampa, uso professionale | Grande | Quasi come l'originale |

### Scegli la tua qualità

```bash
# Thumbnails - maximum compression
find . -name "*.jpg" -exec jpegoptim --max=35 --strip-all {} \;

# Web images - balanced
find . -name "*.jpg" -exec jpegoptim --max=70 --strip-all {} \;

# High quality - minimal loss
find . -name "*.jpg" -exec jpegoptim --max=85 --strip-all {} \;
```

## 💡 Consigli da esperti

<details>
<summary><strong>Ottimizzare una cartella precisa, sottocartelle comprese</strong></summary>

```bash
#!/bin/bash

# Set your folder path
IMAGE_FOLDER="/path/to/images"
QUALITY=70

echo "Optimizing images in: $IMAGE_FOLDER"
echo "Quality setting: $QUALITY"

# Count images first
TOTAL=$(find "$IMAGE_FOLDER" -type f \( -name "*.jpg" -o -name "*.jpeg" \) | wc -l)
echo "Found $TOTAL images to optimize"

# Optimize
find "$IMAGE_FOLDER" -type f \( -name "*.jpg" -o -name "*.jpeg" \) \
    -exec jpegoptim -P --max=$QUALITY --strip-all {} \;

echo "✅ Optimization complete!"
```
</details>

<details>
<summary><strong>Ottimizzare sia i .jpg sia i .jpeg</strong></summary>

```bash
# Handle both extensions
find . -type f \( -name "*.jpg" -o -name "*.jpeg" \) \
    -exec jpegoptim -P --max=70 --strip-all {} \;
```
</details>

<details>
<summary><strong>Tenere i dati EXIF (fotocamera, data, ecc.)</strong></summary>

```bash
# Preserve EXIF but remove other metadata
find . -name "*.jpg" -exec jpegoptim -P --max=70 --strip-all --keep-exif {} \;

# Or keep all metadata
find . -name "*.jpg" -exec jpegoptim -P --max=70 {} \;
```
</details>

<details>
<summary><strong>Ottimizzare anche le immagini PNG</strong></summary>

```bash
#!/bin/bash

echo "Optimizing JPEGs..."
find . -name "*.jpg" -exec jpegoptim -P --max=70 --strip-all {} \;

echo "Optimizing PNGs..."
find . -name "*.png" -exec optipng -o2 {} \;

echo "✅ All images optimized!"
```

Livelli di ottimizzazione PNG:
- `-o2`: veloce, buona compressione (predefinito)
- `-o5`: più lento, compressione migliore
- `-o7`: compressione migliore, più lento
</details>

<details>
<summary><strong>Fare un backup prima di ottimizzare</strong></summary>

```bash
#!/bin/bash

FOLDER="imgfolder"
BACKUP="${FOLDER}_backup_$(date +%Y%m%d_%H%M%S)"

echo "Creating backup: $BACKUP"
cp -r "$FOLDER" "$BACKUP"

echo "Optimizing images in $FOLDER..."
cd "$FOLDER"
find . -name "*.jpg" -exec jpegoptim -P --max=70 --strip-all {} \;

echo "✅ Done! Backup saved in: $BACKUP"
```
</details>

<details>
<summary><strong>Mostrare le statistiche dello spazio risparmiato</strong></summary>

```bash
#!/bin/bash

FOLDER="imgfolder"

# Calculate size before
BEFORE=$(du -sh "$FOLDER" | cut -f1)
echo "Size before: $BEFORE"

# Optimize (no cd: du below needs the original relative path)
find "$FOLDER" -name "*.jpg" -exec jpegoptim -P --max=70 --strip-all {} \; | tee /tmp/optim.log

# Calculate size after
AFTER=$(du -sh "$FOLDER" | cut -f1)
echo "Size after: $AFTER"

# Show summary
echo ""
echo "=== Optimization Summary ==="
grep -E "optimized|skipped" /tmp/optim.log | tail -5
```
</details>

<details>
<summary><strong>Ottimizzare solo le immagini più grandi di X KB</strong></summary>

```bash
# Only optimize images larger than 500KB
find . -name "*.jpg" -size +500k \
    -exec jpegoptim -P --max=70 --strip-all {} \;

# Only optimize images larger than 1MB
find . -name "*.jpg" -size +1M \
    -exec jpegoptim -P --max=70 --strip-all {} \;
```
</details>

<details>
<summary><strong>Ridimensionare E ottimizzare (per il web)</strong></summary>

Prima installa ImageMagick: `sudo apt install imagemagick`

```bash
#!/bin/bash

# Resize to max width 1920px AND optimize
find . -name "*.jpg" -exec sh -c '
    convert "$1" -resize "1920x1920>" -quality 70 "$1"
    jpegoptim -P --strip-all "$1"
' _ {} \;

echo "✅ Resized and optimized!"
```
</details>

<details>
<summary><strong>Creare copie ottimizzate per il web (tenendo gli originali)</strong></summary>

```bash
#!/bin/bash

SOURCE="originals"
OUTPUT="web_optimized"

# Create output folder
mkdir -p "$OUTPUT"

# Copy and optimize
find "$SOURCE" -name "*.jpg" -type f | while read file; do
    # Get relative path
    rel_path="${file#$SOURCE/}"
    out_file="$OUTPUT/$rel_path"
    
    # Create directory structure
    mkdir -p "$(dirname "$out_file")"
    
    # Copy and optimize
    cp "$file" "$out_file"
    jpegoptim -P --max=70 --strip-all "$out_file"
done

echo "✅ Web-optimized copies created in: $OUTPUT"
```
</details>

## 🔍 Capire le opzioni di jpegoptim

### Opzioni comuni

| Opzione | Descrizione | Quando usarla |
|--------|-------------|-------------|
| `--max=N` | Imposta la qualità massima (0-100) | Sempre: regola la compressione |
| `--strip-all` | Toglie tutti i metadati | Uso web, privacy |
| `--strip-exif` | Toglie solo i dati EXIF | Per eliminare GPS e dati della fotocamera |
| `--strip-com` | Toglie i commenti | Per ripulire i file |
| `-P` | Conserva le date dei file | Per tenere le date originali |
| `--all-progressive` | JPEG progressivi | Caricamento migliore sul web |
| `--all-normal` | JPEG baseline | Massima compatibilità |
| `--size=N` | Peso obiettivo del file in KB | Limiti di peso rigidi |

### Combinazioni di esempio

```bash
# Web thumbnails - aggressive
jpegoptim --max=40 --strip-all --all-progressive image.jpg

# Blog post images - balanced
jpegoptim --max=70 --strip-all -P image.jpg

# Photography website - high quality
jpegoptim --max=90 --strip-com -P image.jpg

# Target specific file size
jpegoptim --size=100k image.jpg  # Max 100KB
```

## 📊 Casi d'uso comuni

### Ottimizzazione per un sito web

```bash
#!/bin/bash
# Optimize all images for website deployment

echo "🌐 Optimizing for web..."

# Hero images - high quality
find ./images/hero -name "*.jpg" -exec jpegoptim -P --max=85 --strip-all {} \;

# Blog images - medium quality
find ./images/blog -name "*.jpg" -exec jpegoptim -P --max=70 --strip-all {} \;

# Thumbnails - low quality
find ./images/thumbs -name "*.jpg" -exec jpegoptim -P --max=40 --strip-all {} \;

echo "✅ Website images optimized!"
```

### Preparazione per i social

```bash
# Instagram/Facebook ready
find . -name "*.jpg" -exec jpegoptim --max=80 --strip-all {} \;

# Twitter (smaller files)
find . -name "*.jpg" -exec jpegoptim --max=70 --strip-all {} \;
```

### Allegati di posta

```bash
# Reduce for email (target ~500KB per image)
find . -name "*.jpg" -exec jpegoptim --size=500k --strip-all {} \;
```

### Compressione di un archivio fotografico

```bash
# Compress old photos (keep EXIF for dates)
find ./archive -name "*.jpg" -exec jpegoptim --max=75 -P {} \;
```

## ⚠️ Avvertenze importanti

{{< callout type="danger" >}}
**Prima di ottimizzare:**

1. **Fai sempre il backup degli originali** - l'ottimizzazione è distruttiva
2. **Prova prima su qualche immagine campione**, per trovare la qualità giusta
3. **Controlla il risultato** - alcune immagini si degradano più di altre
4. **Non si torna indietro** - una volta ottimizzata, la qualità originale è persa
{{< /callout >}}

### Una procedura di prova sicura

```bash
# 1. Create test folder with copies
mkdir test_optimization
cp imgfolder/*.jpg test_optimization/

# 2. Test optimization
cd test_optimization
jpegoptim --max=70 --strip-all *.jpg

# 3. Review results
ls -lh  # Check file sizes
# Open images and check quality

# 4. If satisfied, optimize originals
cd ../imgfolder
jpegoptim --max=70 --strip-all *.jpg
```

## 🎯 Qualità consigliata per caso d'uso

```bash
# Thumbnails (100-200px)
--max=35

# Social media posts
--max=70

# Blog/website images
--max=75

# Portfolio/photography site
--max=85

# Print preparation
--max=95

# Icons/logos (use PNG instead!)
# jpegoptim not recommended
```

## 🔧 Risoluzione dei problemi

<details>
<summary><strong>jpegoptim: command not found</strong></summary>

**Problema**: lo strumento non è installato

**Soluzione**:
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install jpegoptim

# Check installation
jpegoptim --version
```
</details>

<details>
<summary><strong>Dopo l'ottimizzazione le immagini sono orribili</strong></summary>

**Problema**: qualità impostata in modo troppo aggressivo

**Soluzione**:
```bash
# Restore from backup
cp -r imgfolder_backup/* imgfolder/

# Use higher quality
find imgfolder -name "*.jpg" -exec jpegoptim --max=80 --strip-all {} \;
```
</details>

<details>
<summary><strong>Errori «Permission denied»</strong></summary>

**Problema**: non hai i permessi di scrittura sui file

**Soluzione**:
```bash
# Change ownership if needed
sudo chown -R $USER:$USER imgfolder/

# Or run with sudo (not recommended)
sudo find . -name "*.jpg" -exec jpegoptim --max=70 --strip-all {} \;
```
</details>

<details>
<summary><strong>Lo script di ottimizzazione è troppo lento</strong></summary>

**Problema**: ci sono migliaia di immagini da elaborare

**Soluzione**:
```bash
# Use parallel processing (install GNU parallel first)
sudo apt install parallel

# Optimize in parallel (4 jobs at once)
find . -name "*.jpg" | parallel -j4 jpegoptim -P --max=70 --strip-all {}

# Much faster on multi-core systems!
```
</details>

## 📈 Riduzioni di peso attese

| Qualità di partenza | max=35 | max=50 | max=70 | max=85 |
|-----------------|--------|--------|--------|--------|
| Foto ad alta risoluzione | ~90% | ~75% | ~50% | ~30% |
| Già compressa | ~30% | ~20% | ~10% | ~5% |
| Screenshot | ~80% | ~65% | ~40% | ~20% |

## 🚀 One-liner avanzati

```bash
# Count files, then optimize (one result line per file)
echo "Files: $(find . -name "*.jpg" | wc -l)"; find . -name "*.jpg" -exec jpegoptim --max=70 {} \;

# Optimize only recent files (last 7 days)
find . -name "*.jpg" -mtime -7 -exec jpegoptim --max=70 --strip-all {} \;

# Optimize by file size (>500KB only)
find . -name "*.jpg" -size +500k -exec jpegoptim --max=70 --strip-all {} \;

# Optimize and log results
find . -name "*.jpg" -exec jpegoptim --max=70 --strip-all {} \; > optimization.log

# Remove GPS data only (keep other EXIF)
find . -name "*.jpg" -exec exiftool -gps:all= {} \;
```

## 📋 Lo script completo di ottimizzazione

Salvalo come `optimize_all.sh`:

```bash
#!/bin/bash

# Configuration
SOURCE_FOLDER="${1:-.}"  # Default to current folder
QUALITY="${2:-70}"       # Default quality 70
BACKUP=true              # Set to false to skip backup

echo "================================================"
echo "  Image Optimization Script"
echo "================================================"
echo "Folder: $SOURCE_FOLDER"
echo "Quality: $QUALITY"
echo ""

# Create backup if enabled
if [ "$BACKUP" = true ]; then
    BACKUP_FOLDER="${SOURCE_FOLDER}_backup_$(date +%Y%m%d_%H%M%S)"
    echo "Creating backup: $BACKUP_FOLDER"
    cp -r "$SOURCE_FOLDER" "$BACKUP_FOLDER"
fi

# Count files
TOTAL_JPG=$(find "$SOURCE_FOLDER" -type f \( -name "*.jpg" -o -name "*.jpeg" \) | wc -l)
TOTAL_PNG=$(find "$SOURCE_FOLDER" -type f -name "*.png" | wc -l)

echo "Found $TOTAL_JPG JPEG files"
echo "Found $TOTAL_PNG PNG files"
echo ""

# Size before
SIZE_BEFORE=$(du -sh "$SOURCE_FOLDER" | cut -f1)
echo "Size before: $SIZE_BEFORE"
echo ""

# Optimize JPEGs
if [ $TOTAL_JPG -gt 0 ]; then
    echo "Optimizing JPEGs..."
    find "$SOURCE_FOLDER" -type f \( -name "*.jpg" -o -name "*.jpeg" \) \
        -exec jpegoptim -P --max=$QUALITY --strip-all {} \;
fi

# Optimize PNGs
if [ $TOTAL_PNG -gt 0 ]; then
    echo ""
    echo "Optimizing PNGs..."
    find "$SOURCE_FOLDER" -type f -name "*.png" -exec optipng -o2 -quiet {} \;
fi

# Size after
SIZE_AFTER=$(du -sh "$SOURCE_FOLDER" | cut -f1)

echo ""
echo "================================================"
echo "  Optimization Complete!"
echo "================================================"
echo "Size before: $SIZE_BEFORE"
echo "Size after:  $SIZE_AFTER"
if [ "$BACKUP" = true ]; then
    echo "Backup: $BACKUP_FOLDER"
fi
echo ""
```

**Uso:**
```bash
chmod +x optimize_all.sh

# Optimize current folder, quality 70
./optimize_all.sh

# Optimize specific folder, quality 80
./optimize_all.sh /path/to/images 80
```

---

*Ottimizza le tue immagini: siti più veloci e meno spazio occupato!*
