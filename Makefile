.PHONY: help dev build serve export import clean new-post restart deploy-remote switch-env auto-switch-dev auto-switch-prod update-theme update-theme-version rollback-theme theme-info theme-list

# Load environment variables
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Current environment detection
CURRENT_ENV := $(ENVIRONMENT)

# Set defaults based on environment
ENVIRONMENT ?= dev

ifeq ($(ENVIRONMENT),dev)
    HOST := $(DEV_HOST)
    PORT := $(DEV_PORT)
    BASE_URL := $(DEV_BASE_URL)
    HUGO_ENV := development
    BUILD_DRAFTS := --buildDrafts
else ifeq ($(ENVIRONMENT),production)
    HOST := $(PROD_HOST)
    PORT := $(PROD_PORT)
    BASE_URL := $(PROD_BASE_URL)
    HUGO_ENV := production
    BUILD_DRAFTS := 
endif

help:
	@echo "🚀 Hugo Blog Management (Simplified)"
	@echo "===================================="
	@echo ""
	@echo "Current Environment: $(ENVIRONMENT)"
	@echo "Base URL: $(BASE_URL)"
	@echo ""
	@echo "🛠️  Development (auto-switches to dev):"
	@echo "  make dev                       - Switch to dev + start dev server"
	@echo "  make preview                   - Preview with drafts (dev mode)"
	@echo "  make new-post                  - Create new post"
	@echo ""
	@echo "🚀 Production (auto-switches to prod):"
	@echo "  make deploy                    - Switch to prod + build + serve locally"
	@echo "  make deploy-remote             - Switch to prod + deploy to remote"
	@echo "  make quick-prod                - Quick local production deployment"
	@echo ""
	@echo "🔄 Management:"
	@echo "  make update                    - Update running server"
	@echo "  make restart                   - Restart current environment"
	@echo "  make logs                      - Show logs"
	@echo "  make status                    - Show status"
	@echo ""
	@echo "🧹 Utilities:"
	@echo "  make clean                     - Clean build files"
	@echo "  make backup                    - Create backup"
	@echo "  make stop                      - Stop all containers"
	@echo ""
	@echo "🎨 Theme Management:"
	@echo "  make theme-info                - Show current theme version"
	@echo "  make theme-list                - List available theme versions"
	@echo "  make update-theme              - Update theme to latest version"
	@echo "  make update-theme-version      - Update to specific version (VERSION=v7.0)"
	@echo "  make rollback-theme            - Rollback theme to previous commit"

# Auto-switch to dev environment
auto-switch-dev:
	@if [ "$(CURRENT_ENV)" != "dev" ]; then \
		echo "🔄 Auto-switching to development environment..."; \
		sed -i.bak 's/^ENVIRONMENT=.*/ENVIRONMENT=dev/' .env; \
		echo "✅ Switched to development"; \
	fi

# Auto-switch to production environment
auto-switch-prod:
	@if [ "$(CURRENT_ENV)" != "production" ]; then \
		echo "🔄 Auto-switching to production environment..."; \
		sed -i.bak 's/^ENVIRONMENT=.*/ENVIRONMENT=production/' .env; \
		echo "✅ Switched to production"; \
	fi

# Development with auto-switch
dev: auto-switch-dev
	@echo "🛠️  Starting development server..."
	@echo "📍 URL: $(DEV_BASE_URL)"
	@$(MAKE) stop 2>/dev/null || true
	SITE_BASE_URL=$(DEV_BASE_URL) docker compose up dev

# Preview with auto-switch
preview: auto-switch-dev
	@echo "👁️  Starting preview server with drafts..."
	@echo "📍 URL: $(DEV_BASE_URL)"
	docker compose run --rm -p $(DEV_PORT):1313 dev hugo server \
		--bind 0.0.0.0 --port 1313 \
		--baseURL $(DEV_BASE_URL) \
		--appendPort=false \
		--buildDrafts \
		--buildFuture

# Build content (respects current environment)
build:
	@echo "🏗️  Building site content ($(ENVIRONMENT))..."
	@echo "📍 Base URL: $(BASE_URL)"
	HUGO_ENV=$(HUGO_ENV) SITE_BASE_URL=$(BASE_URL) \
	docker compose run --rm build hugo \
		$(if $(filter production,$(HUGO_ENV)),--minify) \
		$(BUILD_DRAFTS) \
		--baseURL=$(BASE_URL)
	@echo "✅ Build completed in ./public"

# Export content to archive
export: build
	@echo "📦 Creating content archive..."
	@mkdir -p ./export
	@cd ./public && tar -czf ../export/site-content.tar.gz .
	@echo "✅ Content exported to ./export/site-content.tar.gz"
	@echo "📊 Archive size: $(shell du -h export/site-content.tar.gz | cut -f1)"

# Deploy with auto-switch to production
deploy: auto-switch-prod
	@echo "🚀 Deploying to production locally..."
	@$(MAKE) export
	@$(MAKE) serve
	@echo "✅ Local production deployment completed!"
	@echo "📍 Site available at $(PROD_BASE_URL)"

# Deploy to remote with auto-switch to production
deploy-remote: auto-switch-prod
	@echo "🌐 Deploying to remote server..."
	@if [ -z "$(SSH_HOST)" ] || [ -z "$(SSH_EXPORT)" ] || [ -z "$(SSH_WORKSPACE)" ]; then \
		echo "❌ SSH variables not set in .env file"; \
		echo "   Required: SSH_HOST, SSH_EXPORT, SSH_WORKSPACE"; \
		exit 1; \
	fi
	@echo "🏗️  Building production content..."
	@$(MAKE) export
	@echo "📤 Uploading to $(SSH_HOST)..."
	scp ./export/site-content.tar.gz $(SSH_HOST):$(SSH_EXPORT)/
	@echo "🔄 Restarting remote server..."
	ssh $(SSH_HOST) "cd $(SSH_WORKSPACE) && docker compose down && docker compose up -d"
	@if [ -n "$(DEPLOY_WEBHOOK_URL)" ]; then \
		curl -X POST "$(DEPLOY_WEBHOOK_URL)" -d "status=deployed&environment=production" || true; \
	fi
	@echo "✅ Remote deployment completed!"
	@echo "📍 Check your remote server URL"

# Quick production deployment (local)
quick-prod: auto-switch-prod
	@$(MAKE) update
	@echo "✅ Quick production update completed!"

# Start production server
serve:
	@echo "🚀 Starting production server..."
	@echo "📍 URL: $(BASE_URL)"
	SITE_BASE_URL=$(BASE_URL) docker compose up -d prod
	@echo "✅ Server started"

# Import content to running server
import:
	@if [ ! -f "./export/site-content.tar.gz" ]; then \
		echo "❌ No content archive found. Building..."; \
		$(MAKE) export; \
	fi
	@echo "📥 Importing content to running server..."
	docker compose restart prod
	@echo "✅ Content imported successfully!"

# Update running server with new content
update: export import
	@echo "✅ Server updated with new content!"

# Create new post (works in any environment)
new-post:
	@read -p "📝 Post title: " title; \
	read -p "📂 Category (optional): " category; \
	slug=$$(echo "$$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$$//g'); \
	if [ -n "$$category" ]; then \
		mkdir -p content/posts/$$category; \
		file="content/posts/$$category/$$slug.md"; \
	else \
		file="content/posts/$$slug.md"; \
	fi; \
	docker compose run --rm dev hugo new "$$file"; \
	echo "✅ Post created: $$file"; \
	echo "💡 Start development server with: make dev"

# Restart server (detects current environment)
restart:
	@echo "🔄 Restarting $(ENVIRONMENT) server..."
ifeq ($(ENVIRONMENT),dev)
	docker compose restart dev
else
	docker compose restart prod
endif
	@echo "✅ Server restarted"

# Clean build files
clean:
	@echo "🧹 Cleaning build files..."
	@rm -rf ./public ./resources ./.hugo_build.lock
	@echo "✅ Cleanup completed"

# Create backup
backup:
	@echo "💾 Creating backup..."
	@mkdir -p ./backups
	@backup_name="backup-$(shell date +%Y%m%d-%H%M%S).tar.gz"; \
	tar -czf "./backups/$$backup_name" \
		--exclude='./backups' \
		--exclude='./public' \
		--exclude='./resources' \
		--exclude='./.git' \
		--exclude='./node_modules' \
		.; \
	echo "✅ Backup created: ./backups/$$backup_name"

# Show logs (detects current environment)
logs:
ifeq ($(ENVIRONMENT),dev)
	docker compose logs -f dev
else
	docker compose logs -f prod
endif

# Show status
status:
	@echo "📊 System Status"
	@echo "================"
	@echo "Environment: $(ENVIRONMENT)"
	@echo "Base URL: $(BASE_URL)"
	@echo ""
	@echo "🐳 Containers:"
	@docker compose ps 2>/dev/null || echo "No containers running"
	@echo ""
	@echo "📦 Content Archive:"
	@if [ -f "./export/site-content.tar.gz" ]; then \
		echo "✅ $(shell du -h export/site-content.tar.gz | cut -f1) ($(shell tar -tzf ./export/site-content.tar.gz | wc -l) files)"; \
	else \
		echo "❌ No content archive found"; \
	fi

# Stop all containers
stop:
	@echo "🛑 Stopping all containers..."
	docker compose down
	@echo "✅ All containers stopped"

# Manual environment switch (for advanced users)
switch-env:
	@if [ -z "$(ENV)" ]; then \
		echo "❌ Please specify environment: make switch-env ENV=dev|production"; \
		exit 1; \
	fi
	@if [ "$(ENV)" != "dev" ] && [ "$(ENV)" != "production" ]; then \
		echo "❌ Invalid environment. Use: dev or production"; \
		exit 1; \
	fi
	@sed -i.bak 's/^ENVIRONMENT=.*/ENVIRONMENT=$(ENV)/' .env
	@echo "✅ Environment switched to: $(ENV)"

# Development workflow shortcuts
write: auto-switch-dev
	@$(MAKE) new-post
	@echo "💡 Ready to write! Run 'make dev' to start the development server"

# Sync to remote without full restart (faster updates)
sync-remote: auto-switch-prod export
	@echo "🔄 Quick sync to remote server..."
	@if [ -z "$(SSH_HOST)" ]; then \
		echo "❌ SSH_HOST not set"; \
		exit 1; \
	fi
	scp ./export/site-content.tar.gz $(SSH_HOST):$(SSH_EXPORT)/
	ssh $(SSH_HOST) "cd $(SSH_WORKSPACE) && docker compose exec prod sh -c 'rm -rf /usr/share/nginx/html/* && tar -xzf /export/site-content.tar.gz -C /usr/share/nginx/html/'"
	@echo "✅ Content synced to remote!"

# Complete workflow shortcuts
dev-to-prod: auto-switch-dev
	@echo "🔄 Complete workflow: dev -> build -> deploy to production"
	@read -p "Press Enter to start development server (Ctrl+C when ready to deploy)..."
	@$(MAKE) dev &
	@read -p "Press Enter when ready to deploy to production..."
	@$(MAKE) deploy-remote
	@echo "✅ Workflow completed!"

# ============================================
# Theme Management
# ============================================

# Show current theme information
theme-info:
	@echo "🎨 PaperMod Theme Information"
	@echo "============================="
	@echo ""
	@echo "Current branch:"
	@cd themes/PaperMod && git branch --show-current
	@echo ""
	@echo "Current commit:"
	@cd themes/PaperMod && git log -1 --oneline
	@echo ""
	@echo "Current tag (if any):"
	@cd themes/PaperMod && git describe --tags --abbrev=0 2>/dev/null || echo "No tag found (using branch)"
	@echo ""
	@echo "Remote repository:"
	@cd themes/PaperMod && git remote -v | grep fetch

# List available theme versions
theme-list:
	@echo "📋 Available PaperMod Versions"
	@echo "=============================="
	@echo ""
	@echo "Fetching latest versions..."
	@cd themes/PaperMod && git fetch --tags origin 2>/dev/null
	@echo ""
	@echo "Latest 10 releases:"
	@cd themes/PaperMod && git tag -l --sort=-version:refname | head -10
	@echo ""
	@echo "💡 Use: make update-theme-version VERSION=v7.0"

# Update theme to latest version
update-theme:
	@echo "🔄 Updating PaperMod theme to latest version..."
	@echo ""
	@echo "📌 Current version:"
	@cd themes/PaperMod && git log -1 --oneline
	@echo ""
	@read -p "⚠️  This will update to the latest master. Continue? [y/N] " confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		echo "❌ Update cancelled"; \
		exit 1; \
	fi
	@echo ""
	@echo "💾 Creating backup of current version..."
	@cd themes/PaperMod && git log -1 --format="%H" > /tmp/papermod-backup.txt
	@echo "Backup ref saved to: /tmp/papermod-backup.txt"
	@echo ""
	@echo "⬇️  Fetching latest changes..."
	@cd themes/PaperMod && git fetch origin
	@echo ""
	@echo "🔄 Updating theme..."
	@cd themes/PaperMod && git checkout master && git pull origin master
	@echo ""
	@echo "✅ Theme updated successfully!"
	@echo ""
	@echo "📌 New version:"
	@cd themes/PaperMod && git log -1 --oneline
	@echo ""
	@echo "🧪 Testing build..."
	@$(MAKE) build
	@echo ""
	@echo "✅ Build successful!"
	@echo "💡 Test your site with: make dev"
	@echo "💡 To rollback: make rollback-theme"

# Update theme to specific version
update-theme-version:
	@if [ -z "$(VERSION)" ]; then \
		echo "❌ Please specify VERSION: make update-theme-version VERSION=v7.0"; \
		echo ""; \
		echo "Available versions:"; \
		cd themes/PaperMod && git fetch --tags origin 2>/dev/null && git tag -l --sort=-version:refname | head -10; \
		exit 1; \
	fi
	@echo "🔄 Updating PaperMod theme to $(VERSION)..."
	@echo ""
	@echo "📌 Current version:"
	@cd themes/PaperMod && git log -1 --oneline
	@echo ""
	@echo "💾 Creating backup of current version..."
	@cd themes/PaperMod && git log -1 --format="%H" > /tmp/papermod-backup.txt
	@echo "Backup ref saved to: /tmp/papermod-backup.txt"
	@echo ""
	@echo "⬇️  Fetching tags..."
	@cd themes/PaperMod && git fetch --tags origin
	@echo ""
	@echo "🔄 Checking out $(VERSION)..."
	@cd themes/PaperMod && git checkout tags/$(VERSION) 2>/dev/null || \
		(echo "❌ Version $(VERSION) not found" && exit 1)
	@echo ""
	@echo "✅ Theme updated to $(VERSION)!"
	@echo ""
	@echo "📌 Current version:"
	@cd themes/PaperMod && git log -1 --oneline
	@echo ""
	@echo "🧪 Testing build..."
	@$(MAKE) build
	@echo ""
	@echo "✅ Build successful!"
	@echo "💡 Test your site with: make dev"
	@echo "💡 To rollback: make rollback-theme"

# Rollback theme to previous version
rollback-theme:
	@if [ ! -f /tmp/papermod-backup.txt ]; then \
		echo "❌ No backup found"; \
		echo ""; \
		echo "Available recent commits:"; \
		cd themes/PaperMod && git log -5 --oneline; \
		echo ""; \
		echo "💡 Manually rollback with:"; \
		echo "   cd themes/PaperMod && git checkout <commit-hash>"; \
		exit 1; \
	fi
	@echo "🔄 Rolling back PaperMod theme..."
	@echo ""
	@echo "📌 Current version:"
	@cd themes/PaperMod && git log -1 --oneline
	@echo ""
	@backup_ref=$$(cat /tmp/papermod-backup.txt); \
	echo "⬅️  Rolling back to: $$backup_ref"; \
	cd themes/PaperMod && git checkout $$backup_ref
	@echo ""
	@echo "✅ Theme rolled back successfully!"
	@echo ""
	@echo "📌 Current version:"
	@cd themes/PaperMod && git log -1 --oneline
	@echo ""
	@echo "🧪 Testing build..."
	@$(MAKE) build
	@echo ""
	@echo "✅ Build successful!"
	@rm -f /tmp/papermod-backup.txt
	@echo "💡 Test your site with: make dev"