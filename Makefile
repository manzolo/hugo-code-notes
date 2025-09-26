.PHONY: help dev build serve export import clean new-post restart deploy-remote

# Load environment variables
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

HOST ?= 0.0.0.0
PORT ?= 8080

help:
	@echo "Available commands:"
	@echo ""
	@echo "Development:"
	@echo "  make dev         - Start development server"
	@echo "  make new-post    - Create new post"
	@echo ""
	@echo "Production:"
	@echo "  make build       - Build site content"
	@echo "  make export      - Create content archive for deployment"
	@echo "  make serve       - Start production server"
	@echo "  make import      - Import content to running server (restarts container)"
	@echo "  make restart     - Restart production server"
	@echo ""
	@echo "Remote Deployment:"
	@echo "  make deploy-remote - Deploy to remote server (build -> export -> scp -> remote restart)"
	@echo ""
	@echo "Workflow:"
	@echo "  make deploy      - Full pipeline: build -> export -> serve -> import"
	@echo "  make update      - Update running server: build -> export -> import"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean       - Clean build files"
	@echo "  make logs        - Show server logs"
	@echo "  make status      - Show container status"

# Development with live reload
dev:
	docker compose down dev
	docker compose rm -f dev
	docker compose up dev

# Build content
build:
	@echo "Building site content..."
	docker compose run --rm build
	@echo "Build completed in ./public"

# Export content to archive
export: build
	@echo "Creating content archive..."
	@mkdir -p ./export
	@cd ./public && tar -czf ../export/site-content.tar.gz .
	@cd ..
	@echo "Content exported to ./export/site-content.tar.gz"
	@echo "Archive size: $(shell du -h export/site-content.tar.gz | cut -f1)"
	@echo "Archive contains $(shell tar -tzf export/site-content.tar.gz | wc -l) files"

# Deploy to remote server
deploy-remote: export
	@echo "Deploying to remote server $(SSH_HOST)..."
	@if [ -z "$(SSH_HOST)" ] || [ -z "$(SSH_EXPORT)" ] || [ -z "$(SSH_WORKSPACE)" ]; then \
		echo "ERROR: SSH variables not set. Please check your .env file"; \
		exit 1; \
	fi
	@echo "Uploading content archive to $(SSH_HOST):$(SSH_EXPORT)..."
	scp ./export/site-content.tar.gz $(SSH_HOST):$(SSH_EXPORT)/
	@echo "Restarting Docker services on remote server..."
	ssh $(SSH_HOST) "cd $(SSH_WORKSPACE) && docker compose down && docker compose up -d"
	@echo "Remote deployment completed!"
	@echo "Content uploaded and services restarted on $(SSH_HOST)"

# Start production server
serve:
	@echo "Starting production server..."
	docker compose up -d prod
	@echo "Server started at http://$(HOST):$(PORT)"
	@echo "Container will auto-import content if archive exists"

# Import content to running server (restarts container to trigger import)
import:
	@if [ ! -f "./export/site-content.tar.gz" ]; then \
		echo "ERROR: No content archive found. Run 'make export' first."; \
		exit 1; \
	fi
	@echo "Importing content to running server..."
	@echo "Restarting container to trigger auto-import..."
	docker compose restart prod
	@echo "Content imported successfully!"
	@echo "Site available at http://$(HOST):$(PORT)"

# Restart production server
restart:
	@echo "Restarting production server..."
	docker compose restart prod
	@echo "Server restarted at http://$(HOST):$(PORT)"

# Full deployment pipeline
deploy: export serve
	@sleep 2  # Wait for container to start
	@echo "Deployment completed!"
	@echo "Site available at http://$(HOST):$(PORT)"

# Update running server with new content
update: export import
	@echo "Server updated with new content!"

# Create new post
new-post:
	@read -p "Post title: " title; \
	slug=$$(echo "$$title" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g'); \
	docker compose run --rm dev hugo new posts/$$slug.md; \
	echo "Post created: content/posts/$$slug.md"

# Clean build files
clean:
	@echo "Cleaning build files..."
	@rm -rf ./public ./resources ./.hugo_build.lock ./export
	@echo "Cleanup completed"

# Show logs
logs:
	docker compose logs -f prod

# Show status
status:
	@echo "Container status:"
	@docker compose ps prod
	@echo ""
	@if [ -f "./export/site-content.tar.gz" ]; then \
		echo "Content archive: $(shell du -h export/site-content.tar.gz | cut -f1) ($(shell tar -tzf ./export/site-content.tar.gz | wc -l) files)"; \
	else \
		echo "No content archive found"; \
	fi

# Stop everything
stop:
	docker compose down

# List exported content
list-exports:
	@echo "Export directory contents:"
	@ls -lah ./export/ 2>/dev/null || echo "No exports found"
	@if [ -f "./export/site-content.tar.gz" ]; then \
		echo ""; \
		echo "Current archive contents (first 20 files):"; \
		tar -tzf ./export/site-content.tar.gz | head -20; \
		if [ $$(tar -tzf ./export/site-content.tar.gz | wc -l) -gt 20 ]; then \
			echo "... and $$(( $$(tar -tzf ./export/site-content.tar.gz | wc -l) - 20 )) more files"; \
		fi; \
	fi

# Development workflow: make changes, test, update production
dev-update: update
	@echo "Development changes deployed to production"