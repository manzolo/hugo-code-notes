# Makefile for Hugo Blog with Docker
.PHONY: help dev build clean deploy test lint env-check

# Load environment variables
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Variables with defaults - UNA SOLA PORTA!
HUGO_VERSION ?= 0.150.0
DOCKER_IMAGE := hugomods/hugo:go-$(HUGO_VERSION)
SITE_NAME ?= manzolo-code-notes
USER ?= $(WHOAMI)
PUBLIC_DIR := public
DOCKER_COMPOSE := docker compose
HOST ?= 0.0.0.0
PORT ?= 8080

# Colors for output
RED := \033[31m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
PURPLE := \033[35m
CYAN := \033[36m
RESET := \033[0m

# Default target
help: ## Show this help message
	@echo "$(GREEN)🚀 Available commands:$(RESET)"
	@echo ""
	@awk '/^[a-zA-Z_-]+:/ && /## / { split($$0, a, " ## "); printf "  $(BLUE)%-20s$(RESET) %s\n", substr(a[1], 1, index(a[1], ":")-1), a[2] }' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(CYAN)⚙️  Configuration:$(RESET)"
	@echo "  Host: $(YELLOW)$(HOST)$(RESET)"
	@echo "  Port: $(YELLOW)$(PORT)$(RESET)"
	@echo "  Hugo Version: $(YELLOW)$(HUGO_VERSION)$(RESET)"
	@echo ""

# Environment setup
env-check: ## Check environment configuration
	@echo "$(BLUE)🔍 Environment Configuration:$(RESET)"
	@echo "HOST: $(HOST)"
	@echo "PORT: $(PORT)"
	@echo "HUGO_VERSION: $(HUGO_VERSION)"
	@echo "SITE_BASE_URL: $(SITE_BASE_URL)"
	@echo ""
	@if [ -f ".env" ]; then \
		echo "$(GREEN)✅ .env file found$(RESET)"; \
	else \
		echo "$(YELLOW)⚠️  .env file not found$(RESET)"; \
	fi

env-create: ## Create .env file from template
	@if [ ! -f ".env" ]; then \
		echo "$(GREEN)🔧 Creating .env file...$(RESET)"; \
		echo "# Environment variables for Hugo Blog" > .env; \
		echo "HUGO_VERSION=0.150.0" >> .env; \
		echo "HOST=0.0.0.0" >> .env; \
		echo "PORT=8080" >> .env; \
		echo "SITE_BASE_URL=http://localhost:8080/" >> .env; \
		echo "HUGO_ENV=development" >> .env; \
		echo "DOCKER_COMPOSE_PROJECT=hugo-blog" >> .env; \
		echo "DOCKER_NETWORK=hugo-network" >> .env; \
		echo "$(GREEN)✅ .env file created$(RESET)"; \
	else \
		echo "$(YELLOW)⚠️  .env file already exists$(RESET)"; \
	fi

# Pre-flight cleanup
preflight: ## Clean everything before starting
	@echo "$(YELLOW)🧹 Pre-flight cleanup...$(RESET)"
	@$(DOCKER_COMPOSE) down --remove-orphans --volumes 2>/dev/null || true
	@docker network prune -f 2>/dev/null || true
	@docker container prune -f 2>/dev/null || true
	@echo "$(GREEN)✅ Pre-flight cleanup completed$(RESET)"

# Development
dev: preflight env-check ## Start development server
	@echo "$(GREEN)🚀 Starting development server...$(RESET)"
	@echo "$(CYAN)📡 Server available at http://localhost:$(PORT)$(RESET)"
	@$(DOCKER_COMPOSE) --profile dev up hugo-dev

dev-detached: preflight env-check ## Start development server in background
	@echo "$(GREEN)🚀 Starting development server in background...$(RESET)"
	@$(DOCKER_COMPOSE) --profile dev up -d hugo-dev
	@echo "$(CYAN)📡 Server started at http://localhost:$(PORT)$(RESET)"

# Build
build: preflight env-check ## Build site for production
	@echo "$(GREEN)🔨 Building site...$(RESET)"
	@$(DOCKER_COMPOSE) --profile build run --rm hugo-build
	@echo "$(GREEN)✅ Build completed in ./$(PUBLIC_DIR)$(RESET)"

# Production
prod-start: preflight build ## Start production server (clean + build + start)
	@echo "$(GREEN)🚀 Starting production server...$(RESET)"
	@$(DOCKER_COMPOSE) --profile production up -d nginx
	@echo "$(GREEN)✅ Production site available at http://localhost:$(PORT)$(RESET)"

prod-stop: ## Stop production server
	@echo "$(YELLOW)🛑 Stopping production server...$(RESET)"
	@$(DOCKER_COMPOSE) --profile production down
	@echo "$(GREEN)✅ Production server stopped$(RESET)"

prod-logs: ## Show production logs
	@echo "$(BLUE)📋 Production logs:$(RESET)"
	@$(DOCKER_COMPOSE) --profile production logs --follow nginx

# Standalone container (self-contained with build)
standalone-build: preflight env-check ## Build standalone production container
	@echo "$(GREEN)🔨 Building standalone container...$(RESET)"
	@$(DOCKER_COMPOSE) --profile standalone build hugo-prod
	@echo "$(GREEN)✅ Standalone container built$(RESET)"

standalone-start: preflight standalone-build ## Start standalone container
	@echo "$(GREEN)🚀 Starting standalone container...$(RESET)"
	@$(DOCKER_COMPOSE) --profile standalone up -d hugo-prod
	@echo "$(GREEN)✅ Standalone site available at http://localhost:$(PORT)$(RESET)"

standalone-stop: ## Stop standalone container
	@echo "$(YELLOW)🛑 Stopping standalone container...$(RESET)"
	@$(DOCKER_COMPOSE) --profile standalone down
	@echo "$(GREEN)✅ Standalone container stopped$(RESET)"

# Docker image commands
image-build: ## Build Docker image for deployment
	@echo "$(GREEN)🔨 Building Docker image...$(RESET)"
	@docker build -t $(SITE_NAME):latest .
	@echo "$(GREEN)✅ Docker image built$(RESET)"

image-run: preflight ## Run Docker image locally
	@echo "$(GREEN)🚀 Running Docker image...$(RESET)"
	@docker run -d --name $(SITE_NAME)-container -p $(PORT):80 $(SITE_NAME):latest
	@echo "$(GREEN)✅ Container running at http://localhost:$(PORT)$(RESET)"

image-stop: ## Stop Docker image container
	@echo "$(YELLOW)🛑 Stopping Docker container...$(RESET)"
	@docker stop $(SITE_NAME)-container 2>/dev/null || true
	@docker rm $(SITE_NAME)-container 2>/dev/null || true
	@echo "$(GREEN)✅ Container stopped$(RESET)"

# Cleanup
clean: ## Clean everything
	@echo "$(YELLOW)🧹 Full cleanup...$(RESET)"
	@$(DOCKER_COMPOSE) down --volumes --remove-orphans 2>/dev/null || true
	@docker stop $(SITE_NAME)-container 2>/dev/null || true
	@docker rm $(SITE_NAME)-container 2>/dev/null || true
	@sudo chown -R $(USER):$(USER) $(PUBLIC_DIR) 2>/dev/null || true
	@sudo chown -R $(USER):$(USER) resources 2>/dev/null || true
	@rm -rf $(PUBLIC_DIR) resources _gen 2>/dev/null || true
	@docker system prune -f 2>/dev/null || true
	@echo "$(GREEN)✅ Cleanup completed$(RESET)"

stop-all: ## Stop all containers
	@echo "$(YELLOW)🛑 Stopping all containers...$(RESET)"
	@$(DOCKER_COMPOSE) down --remove-orphans 2>/dev/null || true
	@$(DOCKER_COMPOSE) --profile dev down 2>/dev/null || true
	@$(DOCKER_COMPOSE) --profile production down 2>/dev/null || true
	@$(DOCKER_COMPOSE) --profile standalone down 2>/dev/null || true
	@docker stop $(SITE_NAME)-container 2>/dev/null || true
	@docker rm $(SITE_NAME)-container 2>/dev/null || true
	@echo "$(GREEN)✅ All containers stopped$(RESET)"

# Content Management
new-post: ## Create new post (usage: make new-post TITLE="Post Title")
	@if [ -z "$(TITLE)" ]; then \
		echo "$(RED)❌ Specify title: make new-post TITLE=\"Post Title\"$(RESET)"; \
	else \
		$(DOCKER_COMPOSE) run --rm hugo-dev hugo new posts/$$(echo "$(TITLE)" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$$//g').md; \
		echo "$(GREEN)✅ New post created$(RESET)"; \
	fi

new-bash: ## Create new Bash tutorial
	@if [ -z "$(TITLE)" ]; then \
		echo "$(RED)❌ Specify title: make new-bash TITLE=\"Title\"$(RESET)"; \
	else \
		$(DOCKER_COMPOSE) run --rm hugo-dev hugo new bash/$$(echo "$(TITLE)" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$$//g').md; \
		echo "$(GREEN)✅ New Bash tutorial created$(RESET)"; \
	fi

# Deployment
deploy-netlify: build ## Deploy to Netlify
	@echo "$(BLUE)🚀 Deploying to Netlify...$(RESET)"
	@if command -v netlify >/dev/null 2>&1; then \
		netlify deploy --prod --dir=$(PUBLIC_DIR); \
		echo "$(GREEN)✅ Deployed to Netlify$(RESET)"; \
	else \
		echo "$(RED)❌ Netlify CLI not installed$(RESET)"; \
	fi

# Quick workflows
quick-dev: clean dev ## Full dev workflow (clean + dev)

quick-prod: clean prod-start ## Full production workflow (clean + build + prod)

quick-standalone: clean standalone-start ## Full standalone workflow (clean + build + start)

# Information
status: ## Show service status
	@echo "$(BLUE)📊 Service status:$(RESET)"
	@$(DOCKER_COMPOSE) ps

info: ## Show system information
	@echo "$(BLUE)ℹ️  System information:$(RESET)"
	@echo "Port: $(PORT)"
	@echo "Docker: $$(docker --version 2>/dev/null || echo 'Not installed')"
	@echo "Site URL: http://localhost:$(PORT)"

# Help
workflows: ## Show workflow examples
	@echo "$(CYAN)🔄 Simple Workflows:$(RESET)"
	@echo ""
	@echo "$(YELLOW)Development:$(RESET)"
	@echo "  make dev                    # Start dev server"
	@echo "  make quick-dev              # Clean + start dev"
	@echo ""
	@echo "$(YELLOW)Production:$(RESET)"
	@echo "  make prod-start             # Build + start production"
	@echo "  make quick-prod             # Clean + build + start"
	@echo ""
	@echo "$(YELLOW)Standalone:$(RESET)"
	@echo "  make standalone-start       # Build + start container"
	@echo "  make quick-standalone       # Clean + build + start"
	@echo ""
	@echo "$(YELLOW)Cleanup:$(RESET)"
	@echo "  make stop-all               # Stop everything"
	@echo "  make clean                  # Clean everything"