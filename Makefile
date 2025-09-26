.PHONY: help dev build serve clean new-post docker-save docker-load docker-export docker-import list-images

# Load environment variables
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

HOST ?= 0.0.0.0
PORT ?= 8080

# Image configuration
IMAGE_NAME ?= hugo-blog
IMAGE_TAG ?= latest
EXPORT_FILE ?= $(IMAGE_NAME)-$(IMAGE_TAG).tar
BACKUP_DIR ?= ./docker-backups

# Show help
help:
	@echo "Available commands:"
	@echo ""
	@echo "Development:"
	@echo "  make dev         - Start development server"
	@echo "  make build       - Build the site"
	@echo "  make serve       - Build and serve in production"
	@echo "  make new-post    - Create new post"
	@echo "  make clean       - Clean everything"
	@echo ""
	@echo "Docker Images:"
	@echo "  make docker-save    - Save production image to tar file"
	@echo "  make docker-load    - Load image from tar file"
	@echo "  make docker-export  - Export container with current content"
	@echo "  make docker-import  - Import container from tar file"
	@echo "  make list-images    - List all blog-related images"
	@echo "  make docker-build   - Build production image locally"
	@echo "  make docker-clean   - Remove all blog images and containers"
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE_NAME=$(IMAGE_NAME)"
	@echo "  IMAGE_TAG=$(IMAGE_TAG)"
	@echo "  EXPORT_FILE=$(EXPORT_FILE)"

# Development with live reload
dev:
	docker compose up dev

# Build for production
build:
	docker compose run --rm build
	@echo "Build completed in ./public"

# Serve in production (build + nginx)
serve: build
	docker compose up -d prod
	@echo "Site available at http://$(HOST):$(PORT)"

# Create new post
new-post:
	@read -p "Post title: " title; \
	slug=$$(echo "$$title" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g'); \
	docker compose run --rm dev hugo new posts/$$slug.md; \
	echo "Post created: content/posts/$$slug.md"

# Clean everything
clean:
	docker compose down --rmi local
	docker run --rm -v $$(pwd):/app alpine:latest sh -c "rm -rf /app/public /app/resources /app/.hugo_build.lock"
	@echo "Cleanup completed"

# Build production image locally (without compose)
docker-build: build
	@echo "Building production Docker image..."
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
	@echo "Image built: $(IMAGE_NAME):$(IMAGE_TAG)"

# Save production image to tar file
docker-save: docker-build
	@mkdir -p $(BACKUP_DIR)
	@echo "Saving image $(IMAGE_NAME):$(IMAGE_TAG) to $(BACKUP_DIR)/$(EXPORT_FILE)..."
	docker save $(IMAGE_NAME):$(IMAGE_TAG) | gzip > $(BACKUP_DIR)/$(EXPORT_FILE).gz
	@echo "Image saved to $(BACKUP_DIR)/$(EXPORT_FILE).gz"
	@ls -lh $(BACKUP_DIR)/$(EXPORT_FILE).gz

# Load image from tar file
docker-load:
	@if [ ! -f "$(BACKUP_DIR)/$(EXPORT_FILE).gz" ]; then \
		echo "Error: File $(BACKUP_DIR)/$(EXPORT_FILE).gz not found"; \
		echo "Available files:"; \
		ls -la $(BACKUP_DIR)/ 2>/dev/null || echo "Backup directory doesn't exist"; \
		exit 1; \
	fi
	@echo "Loading image from $(BACKUP_DIR)/$(EXPORT_FILE).gz..."
	gunzip -c $(BACKUP_DIR)/$(EXPORT_FILE).gz | docker load
	@echo "Image loaded successfully"

# Export running container with current content
docker-export: serve
	@mkdir -p $(BACKUP_DIR)
	@echo "Exporting running container hugo-prod..."
	@sleep 2  # Wait for container to be fully up
	docker export hugo-prod | gzip > $(BACKUP_DIR)/$(IMAGE_NAME)-container-$(shell date +%Y%m%d-%H%M%S).tar.gz
	@echo "Container exported to $(BACKUP_DIR)/$(IMAGE_NAME)-container-$(shell date +%Y%m%d-%H%M%S).tar.gz"

# Import container from tar file
docker-import:
	@echo "Available container exports:"
	@ls -la $(BACKUP_DIR)/*container*.tar.gz 2>/dev/null || echo "No container exports found"
	@read -p "Enter the container file name (without .tar.gz): " filename; \
	if [ -f "$(BACKUP_DIR)/$$filename.tar.gz" ]; then \
		echo "Importing container from $(BACKUP_DIR)/$$filename.tar.gz..."; \
		gunzip -c $(BACKUP_DIR)/$$filename.tar.gz | docker import - $(IMAGE_NAME):imported-$(shell date +%Y%m%d); \
		echo "Container imported as $(IMAGE_NAME):imported-$(shell date +%Y%m%d)"; \
	else \
		echo "File not found: $(BACKUP_DIR)/$$filename.tar.gz"; \
		exit 1; \
	fi

# List all blog-related images
list-images:
	@echo "Blog-related Docker images:"
	@docker images | grep -E "($(IMAGE_NAME)|hugo)" || echo "No blog images found"
	@echo ""
	@echo "All Docker images:"
	@docker images

# Clean all blog-related Docker resources
docker-clean:
	@echo "Stopping and removing containers..."
	@docker compose down --rmi local --remove-orphans 2>/dev/null || true
	@echo "Removing blog images..."
	@docker images | grep $(IMAGE_NAME) | awk '{print $$3}' | xargs -r docker rmi -f 2>/dev/null || true
	@echo "Removing unused images and containers..."
	@docker system prune -f
	@echo "Docker cleanup completed"

# Create a complete backup (source + image)
backup-complete: docker-save
	@echo "Creating complete backup..."
	@mkdir -p $(BACKUP_DIR)
	@tar --exclude='./public' --exclude='./resources' --exclude='./node_modules' \
		--exclude='./docker-backups' --exclude='./.git' \
		-czf $(BACKUP_DIR)/$(IMAGE_NAME)-source-$(shell date +%Y%m%d-%H%M%S).tar.gz .
	@echo "Source code backed up to $(BACKUP_DIR)/$(IMAGE_NAME)-source-$(shell date +%Y%m%d-%H%M%S).tar.gz"
	@echo "Complete backup finished!"
	@ls -lh $(BACKUP_DIR)/

# Restore from backup
restore-help:
	@echo "To restore from backup:"
	@echo "1. Extract source code: tar -xzf source-backup.tar.gz"
	@echo "2. Load Docker image: make docker-load"
	@echo "3. Start the blog: make serve"

# Quick deployment command
deploy: backup-complete
	@echo "Deployment package ready!"
	@echo "Copy the following files to deploy:"
	@ls -la $(BACKUP_DIR)/*$(shell date +%Y%m%d)* 2>/dev/null || echo "No recent backups found"