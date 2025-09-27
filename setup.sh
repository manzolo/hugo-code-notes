#!/bin/bash

# Enhanced Setup script for Hugo Blog
set -e

echo "🚀 Hugo Blog Enhanced Setup"
echo "============================"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=0
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        echo "Please install Docker: https://docs.docker.com/get-docker/"
        missing_deps=1
    fi
    
    if ! command -v docker compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
        missing_deps=1
    fi
    
    if ! command -v git &> /dev/null; then
        log_warning "Git is not installed (optional for theme management)"
    fi
    
    if [ $missing_deps -eq 1 ]; then
        exit 1
    fi
    
    log_success "All required dependencies are installed"
}

# Create directory structure
create_directories() {
    log_info "Creating directory structure..."
    
    mkdir -p content/posts/{bash,docker,linux,javascript,tutorials}
    mkdir -p content/about
    mkdir -p layouts/{_default,shortcodes,partials}
    mkdir -p static/{js,css,images}
    mkdir -p conf
    mkdir -p themes
    mkdir -p export
    mkdir -p backups
    
    log_success "Directory structure created"
}

# Create environment configuration
create_env_config() {
    log_info "Creating environment configuration..."
    
    if [ -f ".env" ]; then
        log_warning ".env file already exists, creating backup"
        cp .env .env.backup.$(date +%Y%m%d-%H%M%S)
    fi
    
    # Interactive environment setup
    echo
    read -p "🌍 Choose default environment (dev/production) [dev]: " default_env
    default_env=${default_env:-dev}
    
    read -p "🔧 Development port [8080]: " dev_port
    dev_port=${dev_port:-8080}
    
    read -p "🚀 Production port [8080]: " prod_port
    prod_port=${prod_port:-8080}
    
    read -p "🌐 Production domain (e.g., yourdomain.com) [localhost]: " prod_domain
    prod_domain=${prod_domain:-localhost}
    
    # Optional SSH configuration for remote deploy
    read -p "🔑 Setup remote deployment? (y/n) [n]: " setup_remote
    if [ "$setup_remote" = "y" ]; then
        read -p "🖥️  SSH Host (user@server.com): " ssh_host
        read -p "📁 Remote workspace path: " ssh_workspace
        ssh_export="${ssh_workspace}/export"
    fi
    
    # Generate .env file
    cat > .env << EOF
# User and Group IDs for Docker permissions
UID=$(id -u)
GID=$(id -g)

# Environment Configuration
ENVIRONMENT=${default_env}

# Development Configuration
DEV_HOST=0.0.0.0
DEV_PORT=${dev_port}
DEV_BASE_URL=http://localhost:${dev_port}/

# Production Configuration
PROD_HOST=0.0.0.0
PROD_PORT=${prod_port}
PROD_BASE_URL=https://${prod_domain}/

EOF

    if [ "$setup_remote" = "y" ] && [ -n "$ssh_host" ]; then
        cat >> .env << EOF
# Remote SSH Configuration
SSH_HOST=${ssh_host}
SSH_PORT=22
SSH_WORKSPACE=${ssh_workspace}
SSH_EXPORT=${ssh_export}

EOF
    fi

    cat >> .env << EOF
# Backup Configuration
BACKUP_ENABLED=true
BACKUP_RETENTION_DAYS=7

# Site Configuration
SITE_TITLE="Manzolo Code Notes"
SITE_DESCRIPTION="Technical blog with tutorials and programming notes"

# Hugo Configuration
HUGO_ENV=production
HUGO_MINIFY=true
HUGO_BUILD_DRAFTS=false

# Optional: Webhooks (uncomment and configure as needed)
# DEPLOY_WEBHOOK_URL=
# SLACK_WEBHOOK_URL=
EOF

    log_success ".env file created"
}

# Install theme
install_theme() {
    log_info "Installing PaperMod theme..."
    
    if [ -d "themes/PaperMod" ]; then
        log_warning "PaperMod theme already exists"
        read -p "Update theme? (y/n) [y]: " update_theme
        if [ "$update_theme" != "n" ]; then
            cd themes/PaperMod
            git pull origin master
            cd ../..
            log_success "Theme updated"
        fi
    else
        if command -v git &> /dev/null; then
            git submodule add --depth=1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
            git submodule update --init --recursive
            log_success "PaperMod theme installed"
        else
            log_warning "Git not available, downloading theme manually..."
            wget -O papermod.zip https://github.com/adityatelange/hugo-PaperMod/archive/master.zip
            unzip papermod.zip -d themes/
            mv themes/hugo-PaperMod-master themes/PaperMod
            rm papermod.zip
            log_success "PaperMod theme downloaded"
        fi
    fi
}

# Create sample content
create_sample_content() {
    log_info "Creating sample content..."
    
    # About page
    if [ ! -f "content/about.md" ]; then
        cat > content/about.md << 'EOF'
---
title: "About"
date: 2025-01-01T00:00:00Z
draft: false
description: "About this blog and its author"
showToc: false
showReadingTime: false
---

# About This Blog

Welcome to my technical blog! Here I share tutorials, guides, and notes about programming, DevOps, and technology.

## What You'll Find Here

- 💻 **Programming Tutorials**: Step-by-step guides and best practices
- 🛠️ **DevOps & Infrastructure**: Docker, deployment strategies, and automation
- 📚 **Learning Notes**: Documentation of my learning journey
- 🔧 **Tips & Tricks**: Quick solutions and productivity hacks

## Contact

Feel free to reach out if you have questions or suggestions!
EOF
        log_success "About page created"
    fi
    
    # Sample post
    if [ ! -f "content/posts/welcome.md" ]; then
        cat > content/posts/welcome.md << 'EOF'
---
title: "Welcome to the Blog"
date: 2025-01-01T00:00:00Z
draft: false
tags: ["welcome", "blog", "hugo"]
categories: ["General"]
description: "Welcome post introducing the blog and its setup"
cover:
    image: ""
    alt: "Welcome"
    caption: ""
showToc: true
showReadingTime: true
---

# Welcome!

This is your first post on the new Hugo blog. The setup includes:

## Features

- 🎨 **PaperMod Theme**: Clean and responsive design
- 🔍 **Search**: Full-text search functionality
- 📱 **Mobile-friendly**: Responsive design
- 🌙 **Dark/Light mode**: Theme switching
- 📊 **Analytics ready**: Easy integration with analytics services

## Getting Started

### Create a New Post

```bash
make new-post
```

### Development Server

```bash
make dev
```

### Deploy to Production

```bash
make deploy
```

Enjoy blogging!
EOF
        log_success "Welcome post created"
    fi
}

# Build and test
build_and_test() {
    log_info "Building and testing the site..."
    
    # Build the site
    make build
    
    if [ $? -eq 0 ]; then
        log_success "Build completed successfully"
    else
        log_error "Build failed"
        exit 1
    fi
    
    # Create export
    make export
    
    log_success "Site built and exported"
}

# Main setup function
main() {
    echo "Starting enhanced setup process..."
    echo
    
    check_dependencies
    create_directories
    create_env_config
    install_theme
    create_sample_content
    build_and_test
    
    # Final setup
    echo
    echo "========================================="
    log_success "Setup completed successfully!"
    echo "========================================="
    echo
    echo "📋 Quick Start Commands:"
    echo "  make help           - Show all available commands"
    echo "  make dev            - Start development server"
    echo "  make new-post       - Create a new post"
    echo "  make deploy         - Deploy to production"
    echo
    echo "🌍 Environment Management:"
    echo "  make switch-env ENV=dev        - Switch to development"
    echo "  make switch-env ENV=production - Switch to production"
    echo "  make env-status                - Show current environment"
    echo
    echo "📍 URLs:"
    echo "  Development: http://localhost:${dev_port}"
    if [ "$prod_domain" != "localhost" ]; then
        echo "  Production:  https://${prod_domain}"
    else
        echo "  Production:  http://localhost:${prod_port}"
    fi
    echo
    echo "🚀 To get started:"
    echo "  1. Run: make dev"
    echo "  2. Open: http://localhost:${dev_port}"
    echo "  3. Edit content in ./content/posts/"
    echo
    
    if [ -n "$ssh_host" ]; then
        log_info "Remote deployment configured for: $ssh_host"
        echo "  Use 'make deploy-remote' to deploy to remote server"
        echo
    fi
    
    log_warning "Don't forget to:"
    echo "  - Customize config.yml with your site details"
    echo "  - Update the About page content"
    echo "  - Add your own content and remove sample posts"
    echo
}

# Error handling
trap 'log_error "Setup failed! Check the output above for details."; exit 1' ERR

# Run main setup
main "$@"