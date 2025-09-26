#!/bin/sh
set -e

CONTENT_DIR="/usr/share/nginx/html"
EXPORT_DIR="/export"
ARCHIVE_PATH="/export/site-content.tar.gz"

echo "Starting Hugo Blog Container"

# Check if export archive exists and import it
if [ -f "$ARCHIVE_PATH" ]; then
    echo "Found export archive, importing content..."
    
    # Clear existing content
    rm -rf $CONTENT_DIR/*
    
    # Extract content
    tar -xzf "$ARCHIVE_PATH" -C "$CONTENT_DIR"
    
    echo "Content imported successfully from $ARCHIVE_PATH"
    echo "Total files: $(find "$CONTENT_DIR" -type f | wc -l)"
    
    # Optional: backup the imported archive with timestamp
    if [ "$BACKUP_IMPORTED_ARCHIVE" = "true" ]; then
        cp "$ARCHIVE_PATH" "/export/site-content-imported-$(date +%Y%m%d-%H%M%S).tar.gz"
    fi
    
else
    echo "No export archive found at $ARCHIVE_PATH"
    
    # Create default page if no content exists
    if [ ! -f "$CONTENT_DIR/index.html" ]; then
        echo "Creating default index page..."
        cat > "$CONTENT_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Hugo Blog - Waiting for Content</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 100px; }
        .container { max-width: 600px; margin: 0 auto; }
        .info { color: #007acc; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Hugo Blog Runtime</h1>
        <p class="info">Waiting for content...</p>
        <p>Run <code>make export</code> to create content archive, then <code>make import</code> to load it.</p>
    </div>
</body>
</html>
EOF
        echo "Default page created"
    fi
fi

echo "Starting nginx..."
exec "$@"