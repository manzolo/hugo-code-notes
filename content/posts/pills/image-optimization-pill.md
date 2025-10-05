---
title: "Batch Image Optimization"
date: 2025-10-05T16:00:00+02:00
draft: false
author: "Manzolo"
tags: ["linux", "images", "optimization", "jpegoptim", "web", "quick-pill"]
categories: ["linux", "quick-pills"]
series: ["Quick Pills"]
weight: 4
ShowToc: false
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
description: "Quick guide to batch optimize JPEG images for web use, reducing file size while maintaining quality"
---

# 💊 Quick Pill: Batch Image Optimization

{{< callout type="info" >}}
**Use case**: Optimize hundreds of JPEG images for websites, reduce storage space, speed up page loading, or prepare photos for sharing.
{{< /callout >}}

## 🚀 Quick Setup

### Install Required Tools

```bash
# Ubuntu/Debian
sudo apt install jpegoptim optipng

# Fedora/RHEL
sudo dnf install jpegoptim optipng

# macOS (with Homebrew)
brew install jpegoptim optipng
```

## 📸 Basic Image Optimization

### Optimize All JPEGs in Folder

Save as `optimize_images.sh`:

```bash
#!/bin/bash

# Go to your images folder
cd imgfolder

# Find and optimize all JPEGs
find . -type f -name "*.jpg" -exec jpegoptim -P --max=35 --strip-all {} \;
```

**What it does:**
- `find . -type f -name "*.jpg"`: Finds all `.jpg` files recursively
- `-exec jpegoptim`: Runs jpegoptim on each file
- `-P`: Preserve file modification time
- `--max=35`: Set quality to 35% (aggressive compression)
- `--strip-all`: Remove all metadata (EXIF, GPS, etc.)

{{< callout type="warning" >}}
**⚠️ Backup First!** This modifies files in place. Always test on copies first.
{{< /callout >}}

### Run the Script

```bash
chmod +x optimize_images.sh
./optimize_images.sh
```

## 🎨 Quality Levels Guide

### JPEG Quality Settings

| Quality | Use Case | File Size | Visual Quality |
|---------|----------|-----------|----------------|
| `--max=35` | Thumbnails, aggressive compression | Very small | Acceptable |
| `--max=50` | Web images, blog posts | Small | Good |
| `--max=70` | Standard web use | Medium | Very good |
| `--max=85` | High quality web | Larger | Excellent |
| `--max=95` | Print, professional | Large | Near original |

### Choose Your Quality

```bash
# Thumbnails - maximum compression
find . -name "*.jpg" -exec jpegoptim --max=35 --strip-all {} \;

# Web images - balanced
find . -name "*.jpg" -exec jpegoptim --max=70 --strip-all {} \;

# High quality - minimal loss
find . -name "*.jpg" -exec jpegoptim --max=85 --strip-all {} \;
```

## 💡 Pro Tips

<details>
<summary><strong>Optimize specific folder recursively</strong></summary>

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
<summary><strong>Optimize both .jpg and .jpeg extensions</strong></summary>

```bash
# Handle both extensions
find . -type f \( -name "*.jpg" -o -name "*.jpeg" \) \
    -exec jpegoptim -P --max=70 --strip-all {} \;
```
</details>

<details>
<summary><strong>Keep EXIF data (camera info, date, etc.)</strong></summary>

```bash
# Preserve EXIF but remove other metadata
find . -name "*.jpg" -exec jpegoptim -P --max=70 --all-progressive {} \;

# Or keep all metadata
find . -name "*.jpg" -exec jpegoptim -P --max=70 {} \;
```
</details>

<details>
<summary><strong>Optimize PNG images too</strong></summary>

```bash
#!/bin/bash

echo "Optimizing JPEGs..."
find . -name "*.jpg" -exec jpegoptim -P --max=70 --strip-all {} \;

echo "Optimizing PNGs..."
find . -name "*.png" -exec optipng -o2 {} \;

echo "✅ All images optimized!"
```

PNG optimization levels:
- `-o2`: Fast, good compression
- `-o5`: Balanced (default)
- `-o7`: Best compression, slower
</details>

<details>
<summary><strong>Create backup before optimizing</strong></summary>

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
<summary><strong>Show size savings statistics</strong></summary>

```bash
#!/bin/bash

FOLDER="imgfolder"

# Calculate size before
BEFORE=$(du -sh "$FOLDER" | cut -f1)
echo "Size before: $BEFORE"

# Optimize
cd "$FOLDER"
find . -name "*.jpg" -exec jpegoptim -P --max=70 --strip-all {} \; | tee /tmp/optim.log

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
<summary><strong>Optimize only images larger than X KB</strong></summary>

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
<summary><strong>Resize AND optimize (for web)</strong></summary>

Install ImageMagick first: `sudo apt install imagemagick`

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
<summary><strong>Create web-optimized copies (keep originals)</strong></summary>

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

## 🔍 Understanding jpegoptim Options

### Common Options

| Option | Description | When to Use |
|--------|-------------|-------------|
| `--max=N` | Set maximum quality (0-100) | Always - controls compression |
| `--strip-all` | Remove all metadata | Web use, privacy |
| `--strip-exif` | Remove only EXIF data | Remove GPS/camera info |
| `--strip-com` | Remove comments | Clean up files |
| `-P` | Preserve file timestamps | Keep original dates |
| `--all-progressive` | Progressive JPEGs | Better web loading |
| `--all-normal` | Baseline JPEGs | Maximum compatibility |
| `--size=N` | Target file size in KB | Strict size limits |

### Example Combinations

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

## 📊 Common Use Cases

### Website Optimization

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

### Social Media Preparation

```bash
# Instagram/Facebook ready
find . -name "*.jpg" -exec jpegoptim --max=80 --strip-all {} \;

# Twitter (smaller files)
find . -name "*.jpg" -exec jpegoptim --max=70 --strip-all {} \;
```

### Email Attachments

```bash
# Reduce for email (target ~500KB per image)
find . -name "*.jpg" -exec jpegoptim --size=500k --strip-all {} \;
```

### Photo Archive Compression

```bash
# Compress old photos (keep EXIF for dates)
find ./archive -name "*.jpg" -exec jpegoptim --max=75 -P {} \;
```

## ⚠️ Important Warnings

{{< callout type="danger" >}}
**Before Optimizing:**

1. **Always backup originals** - optimization is destructive
2. **Test on sample images** first to find right quality setting
3. **Check results** - some images may degrade more than others
4. **Cannot undo** - once optimized, original quality is lost
{{< /callout >}}

### Safe Testing Workflow

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

## 🎯 Recommended Quality by Use Case

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

## 🔧 Troubleshooting

<details>
<summary><strong>jpegoptim: command not found</strong></summary>

**Problem**: Tool not installed

**Solution**:
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install jpegoptim

# Check installation
jpegoptim --version
```
</details>

<details>
<summary><strong>Images look terrible after optimization</strong></summary>

**Problem**: Quality setting too aggressive

**Solution**:
```bash
# Restore from backup
cp -r imgfolder_backup/* imgfolder/

# Use higher quality
find imgfolder -name "*.jpg" -exec jpegoptim --max=80 --strip-all {} \;
```
</details>

<details>
<summary><strong>Permission denied errors</strong></summary>

**Problem**: No write access to files

**Solution**:
```bash
# Change ownership if needed
sudo chown -R $USER:$USER imgfolder/

# Or run with sudo (not recommended)
sudo find . -name "*.jpg" -exec jpegoptim --max=70 --strip-all {} \;
```
</details>

<details>
<summary><strong>Script optimization is too slow</strong></summary>

**Problem**: Processing thousands of images

**Solution**:
```bash
# Use parallel processing (install GNU parallel first)
sudo apt install parallel

# Optimize in parallel (4 jobs at once)
find . -name "*.jpg" | parallel -j4 jpegoptim -P --max=70 --strip-all {}

# Much faster on multi-core systems!
```
</details>

## 📈 Expected Size Reductions

| Original Quality | max=35 | max=50 | max=70 | max=85 |
|-----------------|--------|--------|--------|--------|
| High-res photo | ~90% | ~75% | ~50% | ~30% |
| Already compressed | ~30% | ~20% | ~10% | ~5% |
| Screenshots | ~80% | ~65% | ~40% | ~20% |

## 🚀 Advanced One-Liners

```bash
# Optimize, show progress, count files
find . -name "*.jpg" | tee >(wc -l) | xargs -I {} jpegoptim --max=70 {}

# Optimize only recent files (last 7 days)
find . -name "*.jpg" -mtime -7 -exec jpegoptim --max=70 --strip-all {} \;

# Optimize by file size (>500KB only)
find . -name "*.jpg" -size +500k -exec jpegoptim --max=70 --strip-all {} \;

# Optimize and log results
find . -name "*.jpg" -exec jpegoptim --max=70 --strip-all {} \; > optimization.log

# Remove GPS data only (keep other EXIF)
find . -name "*.jpg" -exec exiftool -gps:all= {} \;
```

## 📋 Complete Optimization Script

Save as `optimize_all.sh`:

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

**Usage:**
```bash
chmod +x optimize_all.sh

# Optimize current folder, quality 70
./optimize_all.sh

# Optimize specific folder, quality 80
./optimize_all.sh /path/to/images 80
```

---

*Optimize your images for faster websites and smaller storage!*