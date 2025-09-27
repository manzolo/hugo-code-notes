#!/bin/bash

# Daily workflow script for Hugo Blog
# Usage: ./workflow.sh [command]

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Show help
show_help() {
    echo "Hugo Blog Daily Workflow"
    echo "========================"
    echo
    echo "Usage: ./workflow.sh [command]"
    echo
    echo "Daily Commands:"
    echo "  start           - Start development environment"
    echo "  write           - Quick post creation workflow"
    echo "  publish         - Publish draft posts to production"
    echo "  sync            - Sync changes to remote server"
    echo "  backup          - Create backup of content"
    echo "  status          - Show current status"
    echo
    echo "Environment:"
    echo "  dev             - Switch to development and start"
    echo "  prod            - Deploy to production"
    echo
    echo "Maintenance:"
    echo "  update-theme    - Update PaperMod theme"
    echo "  cleanup         - Clean temporary files"
    echo "  health-check    - Check system health"
    echo
}

# Start development environment
start_dev() {
    log "Starting development environment..."
    
    # Switch to dev if not already
    if [ "${ENVIRONMENT}" != "dev" ]; then
        make switch-env ENV=dev
    fi
    
    # Start development server
    make dev
}

# Quick post creation workflow
write_post() {
    log "Starting post creation workflow..."
    
    echo
    read -p "Post title: " title
    if [ -z "$title" ]; then
        error "Title cannot be empty"
        exit 1
    fi
    
    echo
    echo "Available categories:"
    ls content/posts/ | grep -E '^[a-z]+$' || echo "  (no categories yet)"
    read -p "Category (optional): " category
    
    echo
    read -p "Tags (comma-separated): " tags
    
    # Create slug
    slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
    
    # Determine file path
    if [ -n "$category" ]; then
        mkdir -p "content/posts/$category"
        filepath="content/posts/$category/$slug.md"
    else
        filepath="content/posts/$slug.md"
    fi
    
    # Create post with frontmatter
    cat > "$filepath" << EOF
---
title: "$title"
date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
draft: true
$([ -n "$tags" ] && echo "tags: [$(echo "$tags" | sed 's/,/","/g' | sed 's/^/"/;s/$/"/')]")
$([ -n "$category" ] && echo "categories: [\"$category\"]")
description: ""
cover:
    image: ""
    alt: "$title"
    caption: ""
showToc: true
showReadingTime: true
---

# $title

Write your content here...

## Section 1

Content...

## Section 2

More content...
EOF

    success "Post created: $filepath"
    
    # Ask if user wants to open editor
    read -p "Open in editor? (y/n) [y]: " open_editor
    if [ "$open_editor" != "n" ]; then
        # Try common editors
        if command -v code &> /dev/null; then
            code "$filepath"
        elif command -v vim &> /dev/null; then
            vim "$filepath"
        elif command -v nano &> /dev/null; then
            nano "$filepath"
        else
            log "Please open $filepath in your preferred editor"
        fi
    fi
    
    log "Remember to:"
    echo "  1. Write your content"
    echo "  2. Add a description"
    echo "  3. Set draft: false when ready"
    echo "  4. Run: ./workflow.sh publish"
}

# Publish draft posts
publish_posts() {
    log "Publishing draft posts..."
    
    # Find draft posts
    draft_posts=$(find content/posts -name "*.md" -exec grep -l "draft: true" {} \; 2>/dev/null || true)
    
    if [ -z "$draft_posts" ]; then
        warning "No draft posts found"
        return
    fi
    
    echo "Draft posts found:"
    echo "$draft_posts" | while read -r post; do
        title=$(grep "^title:" "$post" | sed 's/title: *"\?//' | sed 's/"\?$//')
        echo "  - $title ($post)"
    done
    
    echo
    read -p "Publish all drafts? (y/n) [n]: " publish_all
    
    if [ "$publish_all" = "y" ]; then
        echo "$draft_posts" | while read -r post; do
            sed -i 's/draft: true/draft: false/' "$post"
            title=$(grep "^title:" "$post" | sed 's/title: *"\?//' | sed 's/"\?$//')
            success "Published: $title"
        done
        
        # Deploy to production
        log "Deploying to production..."
        make switch-env ENV=production
        make deploy
        
        success "All posts published and deployed!"
    else
        log "Publication cancelled"
    fi
}

# Sync to remote server
sync_remote() {
    log "Syncing to remote server..."
    
    if [ -z "$SSH_HOST" ]; then
        error "SSH_HOST not configured in .env"
        exit 1
    fi
    
    # Quick sync without restart
    make sync-remote
    success "Sync completed to $SSH_HOST"
}

# Create backup
create_backup() {
    log "Creating backup..."
    make backup
    success "Backup created"
    
    # Show backup status
    if [ -d "./backups" ]; then
        echo
        echo "Recent backups:"
        ls -lah ./backups/ | tail -5
    fi
}

# Show status
show_status() {
    echo "Hugo Blog Status"
    echo "================"
    echo
    
    # Environment info
    echo "Environment: $ENVIRONMENT"
    echo "Base URL: ${!ENVIRONMENT}_BASE_URL"
    echo
    
    # Container status
    make status
    
    # Content stats
    echo
    echo "Content Statistics:"
    total_posts=$(find content/posts -name "*.md" | wc -l)
    draft_posts=$(find content/posts -name "*.md" -exec grep -l "draft: true" {} \; 2>/dev/null | wc -l)
    published_posts=$((total_posts - draft_posts))
    
    echo "  Total posts: $total_posts"
    echo "  Published: $published_posts"
    echo "  Drafts: $draft_posts"
    
    # Recent activity
    echo
    echo "Recent posts:"
    find content/posts -name "*.md" -newer "$(date -d '7 days ago' '+%Y-%m-%d')" 2>/dev/null | head -3 | while read -r post; do
        title=$(grep "^title:" "$post" | sed 's/title: *"\?//' | sed 's/"\?$//')
        echo "  - $title"
    done || echo "  (no recent posts)"
}

# Update theme
update_theme() {
    log "Updating PaperMod theme..."
    
    if [ -d "themes/PaperMod/.git" ]; then
        cd themes/PaperMod
        git pull origin master
        cd ../..
        success "Theme updated"
    else
        warning "Theme not installed as git submodule"
        log "Reinstalling theme..."
        rm -rf themes/PaperMod
        git submodule add --depth=1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
        success "Theme reinstalled"
    fi
}

# Cleanup
cleanup() {
    log "Cleaning up temporary files..."
    
    make clean
    
    # Clean old backups
    if [ -d "./backups" ] && [ "$BACKUP_ENABLED" = "true" ]; then
        find ./backups -name "backup-*.tar.gz" -mtime +${BACKUP_RETENTION_DAYS:-7} -delete 2>/dev/null || true
        log "Old backups cleaned"
    fi
    
    # Clean Docker images
    read -p "Clean unused Docker images? (y/n) [n]: " clean_docker
    if [ "$clean_docker" = "y" ]; then
        docker system prune -f
        success "Docker cleanup completed"
    fi
    
    success "Cleanup completed"
}

# Health check
health_check() {
    log "Performing health check..."
    
    local issues=0
    
    # Check required files
    for file in config.yml Dockerfile docker-compose.yml Makefile; do
        if [ ! -f "$file" ]; then
            error "Missing required file: $file"
            issues=$((issues + 1))
        fi
    done
    
    # Check directories
    for dir in content layouts static; do
        if [ ! -d "$dir" ]; then
            error "Missing required directory: $dir"
            issues=$((issues + 1))
        fi
    done
    
    # Check theme
    if [ ! -d "themes/PaperMod" ]; then
        error "PaperMod theme not installed"
        issues=$((issues + 1))
    fi
    
    # Check Docker
    if ! docker compose config &>/dev/null; then
        error "Docker Compose configuration invalid"
        issues=$((issues + 1))
    fi
    
    # Check environment variables
    if [ -z "$ENVIRONMENT" ]; then
        error "ENVIRONMENT not set in .env"
        issues=$((issues + 1))
    fi
    
    if [ $issues -eq 0 ]; then
        success "Health check passed - no issues found"
    else
        error "Health check failed - $issues issue(s) found"
        exit 1
    fi
}

# Main command handling
case "${1:-help}" in
    "help"|"--help"|"-h")
        show_help
        ;;
    "start")
        start_dev
        ;;
    "write")
        write_post
        ;;
    "publish")
        publish_posts
        ;;
    "sync")
        sync_remote
        ;;
    "backup")
        create_backup
        ;;
    "status")
        show_status
        ;;
    "dev")
        make switch-env ENV=dev
        make dev
        ;;
    "prod")
        make switch-env ENV=production
        make deploy
        ;;
    "update-theme")
        update_theme
        ;;
    "cleanup")
        cleanup
        ;;
    "health-check")
        health_check
        ;;
    *)
        error "Unknown command: $1"
        echo
        show_help
        exit 1
        ;;
esac