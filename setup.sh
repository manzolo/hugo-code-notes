#!/bin/bash

# Setup script for Hugo Blog
set -e

echo "🚀 Hugo Blog Setup Script"
echo "========================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed${NC}"
    echo "Please install Docker Compose first: https://docs.docker.com/compose/install/"
    exit 1
fi

echo -e "${GREEN}✓ Docker and Docker Compose are installed${NC}"

# Create necessary directories
echo "Creating directory structure..."
mkdir -p content/posts
mkdir -p content/posts/bash
mkdir -p layouts/_default
mkdir -p layouts/shortcodes
mkdir -p static/js
mkdir -p conf
mkdir -p themes

echo -e "${GREEN}✓ Directory structure created${NC}"

# Create .env file with user IDs for proper permissions
echo "Creating .env file..."
cat > .env << EOF
# User and Group IDs for Docker permissions
UID=$(id -u)
GID=$(id -g)

# Server Configuration
HOST=0.0.0.0
PORT=8080

# Site Configuration
SITE_BASE_URL=http://localhost:8080/
EOF

echo -e "${GREEN}✓ .env file created${NC}"

# Install PaperMod theme
echo "Installing PaperMod theme..."
if [ ! -d "themes/PaperMod" ]; then
    git submodule add --depth=1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
    git submodule update --init --recursive
    echo -e "${GREEN}✓ PaperMod theme installed${NC}"
else
    echo -e "${YELLOW}⚠ PaperMod theme already exists${NC}"
fi

# Create conf directory if it doesn't exist
if [ ! -f "conf/nginx.conf" ]; then
    echo "Creating nginx configuration..."
    mkdir -p conf
    cat > conf/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Custom error pages
    error_page 404 /404.html;

    # Main configuration
    location / {
        try_files $uri $uri/ $uri.html /404.html;
    }

    # Handle 404 page
    location = /404.html {
        internal;
    }

    # Optimization for static files
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;
}
EOF
    echo -e "${GREEN}✓ Nginx configuration created${NC}"
else
    echo -e "${YELLOW}⚠ Nginx configuration already exists${NC}"
fi

# Build the site
echo "Building the site..."
docker compose run --rm build
echo -e "${GREEN}✓ Site built successfully${NC}"

# Fix permissions
echo "Fixing file permissions..."
docker run --rm -v $(pwd):/app alpine:latest sh -c "chown -R $(id -u):$(id -g) /app/public /app/resources 2>/dev/null || true"
echo -e "${GREEN}✓ Permissions fixed${NC}"

echo ""
echo "========================================="
echo -e "${GREEN}✅ Setup complete!${NC}"
echo "========================================="
echo ""
echo "Available commands:"
echo "  make dev        - Start development server"
echo "  make build      - Build the site"
echo "  make serve      - Serve in production mode"
echo "  make new-post   - Create a new post"
echo "  make clean      - Clean build files"
echo ""
echo "To start the development server:"
echo -e "${YELLOW}  make dev${NC}"
echo ""
echo "The site will be available at:"
echo -e "${GREEN}  http://localhost:8080${NC}"
echo ""