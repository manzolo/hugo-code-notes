.PHONY: help dev build serve export import clean new-post restart deploy-remote switch-env

# Load environment variables
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

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
	@echo "🚀 Hugo Blog Management"
	@echo "======================="
	@echo ""
	@echo "Current Environment: $(ENVIRONMENT)"
	@echo "Base URL: $(BASE_URL)"
	@echo "Host: $(HOST):$(PORT)"
	@echo ""
	@echo "📋 Environment Management:"
	@echo "  make switch-env ENV=dev        - Switch to development"
	@echo "  make switch-env ENV=production - Switch to production"
	@echo "  make env-status                - Show current environment"
	@echo ""
	@echo "🛠️  Development:"
	@echo "  make dev                       - Start development server"
	@echo "  make new-post                  - Create new post"
	@echo "  make preview                   - Preview with drafts"
	@echo ""
	@echo "🏗️  Build & Deploy:"
	@echo "  make build                     - Build site content"
	@echo "  make export                    - Create content archive"
	@echo "  make serve                     - Start production server"
	@echo "  make deploy                    - Full pipeline (build->export->serve)"
	@echo ""
	@echo "🌐 Remote Operations:"
	@echo "  make deploy-remote             - Deploy to remote server"
	@echo "  make sync-remote               - Sync to remote (no restart)"
	@echo "  make remote-status             - Check remote server status"
	@echo ""
	@echo "🔄 Updates:"
	@echo "  make update                    - Update running server"
	@echo "  make import                    - Import content to running server"
	@echo "  make restart                   - Restart server"
	@echo ""
	@echo "🧹 Utilities:"
	@echo "  make clean                     - Clean build files"
	@echo "  make logs                      - Show server logs"
	@echo "  make status                    - Show container status"
	@echo "  make backup                    - Create backup"

# Environment management
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
	@echo "🔄 Restart any running services with: make restart"

env-status:
	@echo "Current Environment: $(ENVIRONMENT)"
	@echo "Base URL: $(BASE_URL)"
	@echo "Host: $(HOST):$(PORT)"
	@echo "Hugo Env: $(HUGO_ENV)"
	@if [ "$(ENVIRONMENT)" = "dev" ]; then \
		echo "Status: 🛠️  Development mode (drafts enabled)"; \
	else \
		echo "Status: 🚀 Production mode"; \
	fi

# Development with live reload
dev:
	@echo "🛠️  Starting development server ($(ENVIRONMENT))..."
	@echo "📍 URL: $(BASE_URL)"
	docker compose down dev 2>/dev/null || true
	docker compose rm -f dev 2>/dev/null || true
	SITE_BASE_URL=$(BASE_URL) docker compose up dev

# Preview with drafts
preview:
	@echo "👁️  Starting preview server with drafts..."
	@echo "📍 URL: $(BASE_URL)"
	docker compose run --rm -p $(PORT):1313 dev hugo server \
		--bind 0.0.0.0 --port 1313 \
		--baseURL $(BASE_URL) \
		--appendPort=false \
		--buildDrafts \
		--buildFuture

# Build content
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
	@echo "📁 Archive contains $(shell tar -tzf export/site-content.tar.gz | wc -l) files"

# Smart deploy based on environment
deploy:
ifeq ($(ENVIRONMENT),dev)
	@echo "🛠️  Development environment - starting dev server..."
	@$(MAKE) dev
else
	@echo "🚀 Deploying to $(ENVIRONMENT)..."
	@$(MAKE) export serve
	@echo "✅ Deployment completed!"
	@echo "📍 Site available at $(BASE_URL)"
endif

# Deploy to remote server
deploy-remote: export
	@echo "🌐 Deploying to remote server $(SSH_HOST)..."
	@if [ -z "$(SSH_HOST)" ] || [ -z "$(SSH_EXPORT)" ] || [ -z "$(SSH_WORKSPACE)" ]; then \
		echo "❌ SSH variables not set. Please check your .env file"; \
		exit 1; \
	fi
	@echo "📤 Uploading content archive to $(SSH_HOST):$(SSH_EXPORT)..."
	scp ./export/site-content.tar.gz $(SSH_HOST):$(SSH_EXPORT)/
	@echo "🔄 Restarting Docker services on remote server..."
	ssh $(SSH_HOST) "cd $(SSH_WORKSPACE) && docker compose down && docker compose up -d"
	@if [ -n "$(DEPLOY_WEBHOOK_URL)" ]; then \
		echo "📢 Sending deployment notification..."; \
		curl -X POST "$(DEPLOY_WEBHOOK_URL)" -d "status=deployed&environment=$(ENVIRONMENT)" || true; \
	fi
	@echo "✅ Remote deployment completed!"

# Sync to remote without restart (faster for minor updates)
sync-remote: export
	@echo "🔄 Syncing content to remote server..."
	@if [ -z "$(SSH_HOST)" ]; then \
		echo "❌ SSH_HOST not set"; \
		exit 1; \
	fi
	scp ./export/site-content.tar.gz $(SSH_HOST):$(SSH_EXPORT)/
	ssh $(SSH_HOST) "cd $(SSH_WORKSPACE) && docker compose exec prod sh -c 'rm -rf /usr/share/nginx/html/* && tar -xzf /export/site-content.tar.gz -C /usr/share/nginx/html/'"
	@echo "✅ Content synced!"

# Check remote server status
remote-status:
	@if [ -z "$(SSH_HOST)" ]; then \
		echo "❌ SSH_HOST not set"; \
		exit 1; \
	fi
	@echo "🔍 Checking remote server status..."
	ssh $(SSH_HOST) "cd $(SSH_WORKSPACE) && docker compose ps && df -h /export/ 2>/dev/null || echo 'Export dir not found'"

# Start production server
serve:
	@echo "🚀 Starting production server ($(ENVIRONMENT))..."
	@echo "📍 URL: $(BASE_URL)"
	SITE_BASE_URL=$(BASE_URL) docker compose up -d prod
	@echo "✅ Server started at $(BASE_URL)"

# Import content to running server
import:
	@if [ ! -f "./export/site-content.tar.gz" ]; then \
		echo "❌ No content archive found. Run 'make export' first."; \
		exit 1; \
	fi
	@echo "📥 Importing content to running server..."
	docker compose restart prod
	@echo "✅ Content imported successfully!"

# Update running server with new content
update: export import
	@echo "✅ Server updated with new content!"

# Create new post
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
	echo "✅ Post created: $$file"

# Restart server
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

# Clean everything including exports
clean-all: clean
	@echo "🧹 Cleaning all files including exports..."
	@rm -rf ./export
	@echo "✅ Full cleanup completed"

# Create backup
backup:
	@echo "💾 Creating backup..."
	@mkdir -p ./backups
	@backup_name="backup-$(shell date +%Y%m%d-%H%M%S).tar.gz"
	@tar -czf "./backups/$$backup_name" \
		--exclude='./backups' \
		--exclude='./public' \
		--exclude='./resources' \
		--exclude='./.git' \
		--exclude='./node_modules' \
		.
	@echo "✅ Backup created: ./backups/$$backup_name"
	@if [ "$(BACKUP_ENABLED)" = "true" ]; then \
		echo "🧹 Cleaning old backups (keeping last $(BACKUP_RETENTION_DAYS) days)..."; \
		find ./backups -name "backup-*.tar.gz" -mtime +$(BACKUP_RETENTION_DAYS) -delete 2>/dev/null || true; \
	fi

# Show logs
logs:
ifeq ($(ENVIRONMENT),dev)
	docker compose logs -f dev
else
	docker compose logs -f prod
endif

# Show status
status:
	@echo "📊 Container Status ($(ENVIRONMENT)):"
ifeq ($(ENVIRONMENT),dev)
	@docker compose ps dev 2>/dev/null || echo "Dev container not running"
else
	@docker compose ps prod 2>/dev/null || echo "Prod container not running"
endif
	@echo ""
	@echo "📦 Content Archive:"
	@if [ -f "./export/site-content.tar.gz" ]; then \
		echo "✅ $(shell du -h export/site-content.tar.gz | cut -f1) ($(shell tar -tzf ./export/site-content.tar.gz | wc -l) files)"; \
	else \
		echo "❌ No content archive found"; \
	fi
	@echo ""
	@echo "💾 Backups:"
	@if [ -d "./backups" ]; then \
		echo "📁 $(shell ls -1 ./backups/*.tar.gz 2>/dev/null | wc -l) backup(s) available"; \
		ls -lath ./backups/ 2>/dev/null | head -3 || true; \
	else \
		echo "❌ No backups found"; \
	fi

# Stop everything
stop:
	@echo "🛑 Stopping all containers..."
	docker compose down
	@echo "✅ All containers stopped"

# Quick development workflow
quick-dev: 
	@$(MAKE) switch-env ENV=dev
	@$(MAKE) dev

# Quick production deploy
quick-prod:
	@$(MAKE) switch-env ENV=production
	@$(MAKE) deploy

# Development workflow: make changes, test, update production
dev-update: 
	@$(MAKE) switch-env ENV=production
	@$(MAKE) update
	@echo "✅ Development changes deployed to production"