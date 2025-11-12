---
title: "Docker and Docker Compose"
#description: ""
date: 2025-09-26T10:00:00+01:00
lastmod: 2025-09-26T10:00:00+01:00
draft: false
author: "Manzolo"
tags: ["docker", "docker-compose", "containers", "commands", "cheatsheet"]
categories: ["Command Reference"]
series: ["Docker Essentials"]
weight: 1
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Docker and Docker Compose Guide

## Introduction

Docker is a platform for developing, shipping, and running applications inside containers. Docker Compose is a tool for defining and running multi-container Docker applications using YAML files. This guide covers essential Docker and Docker Compose commands, with practical examples, to help you manage containers effectively.

## What is Docker?

Docker allows you to package applications with their dependencies into containers, ensuring consistency across different environments. Containers are lightweight, portable, and run independently of the host system.

## What is Docker Compose?

Docker Compose simplifies the management of multi-container applications by defining services, networks, and volumes in a single YAML file. It allows you to start, stop, and configure multiple containers with a single command.

## Prerequisites

- Docker installed on your system (`docker --version` to verify).
- Docker Compose installed (`docker-compose --version` or `docker compose version` for newer versions).
- Basic understanding of terminal commands.

## Basic Docker Commands

### Container Management

```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Run a container
docker run -d --name my_container -p 8080:80 nginx

# Stop a container
docker stop my_container

# Start a stopped container
docker start my_container

# Remove a container
docker rm my_container

# Remove all stopped containers
docker container prune
```

### Image Management

```bash
# List images
docker images

# Pull an image from Docker Hub
docker pull nginx:latest

# Build an image from a Dockerfile
docker build -t my_image:tag .

# Remove an image
docker rmi my_image:tag

# Remove unused images
docker image prune
```

### Logs and Inspection

```bash
# View container logs
docker logs my_container

# Follow container logs in real-time
docker logs -f my_container

# Inspect container details
docker inspect my_container

# View container resource usage
docker stats
```

## Docker Compose Basics

Docker Compose uses a `docker-compose.yml` file to define services. Below is an example for a web application with a database.

### Example: Simple Web App with Nginx and MySQL

```yaml
version: '3.8'
services:
  web:
    image: nginx:latest
    ports:
      - "8080:80"
    volumes:
      - ./html:/usr/share/nginx/html
    depends_on:
      - db
  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: example_password
      MYSQL_DATABASE: myapp
    volumes:
      - db_data:/var/lib/mysql
volumes:
  db_data:
```

### Explanation

- `version`: Specifies the Docker Compose file format.
- `services`: Defines the containers (e.g., `web` for Nginx, `db` for MySQL).
- `ports`: Maps host port `8080` to container port `80`.
- `volumes`: Persists MySQL data and mounts a local `html` folder for Nginx.
- `environment`: Sets MySQL configuration variables.
- `depends_on`: Ensures the database starts before the web service.

### Docker Compose Commands

```bash
# Start services defined in docker-compose.yml
docker-compose up -d

# Stop and remove services
docker-compose down

# View logs for all services
docker-compose logs

# Follow logs in real-time
docker-compose logs -f

# List running services
docker-compose ps

# Build or rebuild services
docker-compose build

# Restart services
docker-compose restart

# Remove stopped service containers
docker-compose rm -f
```

## Useful Docker Commands

### Networking

```bash
# List networks
docker network ls

# Create a custom network
docker network create my_network

# Run a container in a specific network
docker run -d --network my_network --name my_container nginx

# Inspect a network
docker network inspect my_network
```

### Volumes

```bash
# List volumes
docker volume ls

# Create a volume
docker volume create my_volume

# Remove unused volumes
docker volume prune

# Inspect a volume
docker volume inspect my_volume
```

### System Maintenance

```bash
# Remove all unused containers, networks, and images
docker system prune -a

# View Docker system information
docker info

# Check Docker version
docker --version
```

## Practical Script

Create a script to monitor and manage a Docker Compose setup:

```bash
#!/bin/bash
# manage_docker.sh

echo "=== Docker Compose Management ==="
echo "Current directory: $(pwd)"
echo ""

echo "Starting services..."
docker-compose up -d

echo ""
echo "Running containers:"
docker-compose ps

echo ""
echo "System status:"
docker info --format '{{.ContainersRunning}} containers running, {{.Images}} images'

echo ""
echo "Cleaning up unused resources..."
docker system prune -f
```

Make it executable:

```bash
chmod +x manage_docker.sh
./manage_docker.sh
```

## Pro Tips

{{< callout type="tip" >}}
**Tip**: Use `docker-compose.yml` for reproducible environments. Version control this file to track changes.
{{< /callout >}}

{{< callout type="warning" >}}
**Warning**: Be cautious with `docker system prune -a`, as it removes all unused images, including those you might need later.
{{< /callout >}}

{{< callout type="success" title="Quick Reference" >}}
**Essential shortcuts:**
- `docker-compose up -d`: Start services in detached mode.
- `docker-compose down -v`: Stop services and remove volumes.
- `docker ps -q`: List only container IDs.
- `docker stop $(docker ps -q)`: Stop all running containers.
{{< /callout >}}

## Troubleshooting

- **Container Won't Start**: Check logs with `docker logs <container_name>` or `docker-compose logs`.
- **Port Conflicts**: Ensure the host port (e.g., `8080`) isn't already in use (`netstat -tuln`).
- **Image Pull Issues**: Verify internet connectivity or check Docker Hub for the image.
- **Volume Permission Issues**: Ensure the host user has access to mounted directories.

## Next Steps

In future tutorials, we’ll cover:
- Writing efficient Dockerfiles.
- Docker networking and service discovery.
- Orchestration with Docker Swarm or Kubernetes.
- CI/CD integration with Docker.

## Practice Exercises

1. **Web App Setup**: Create a `docker-compose.yml` for a Node.js app with a MongoDB database.
2. **Log Analysis**: Write a script to tail logs from a specific service.
3. **Resource Cleanup**: Create a script to remove all stopped containers and unused images.
4. **Multi-Container App**: Build a Compose file for a web app, database, and cache (e.g., Redis).

## Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Docker Hub](https://hub.docker.com/)
- [Awesome Docker](https://github.com/veggiemonk/awesome-docker)

---

*Practice building and managing containers to master Docker and Docker Compose!*