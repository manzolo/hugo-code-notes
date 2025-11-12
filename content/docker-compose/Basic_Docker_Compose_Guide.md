---
title: "Basic Docker Compose Guide for Beginners (Debian/Ubuntu)"
date: 2025-10-11T09:55:00+02:00
lastmod: 2025-10-11T09:55:00+02:00
draft: false
author: "Manzolo"
tags: ["docker-compose", "beginner", "nodejs", "postgresql", "tutorial"]
categories: ["Docker & Containers"]
series: ["Docker Essentials"]
weight: 2
ShowToc: true
TocOpen: false
hidemeta: false
comments: true
disableHLJS: false
disableShare: false
searchHidden: false
---

# Basic Docker Compose Guide for Beginners (Debian/Ubuntu)

## Introduction

Docker Compose is a tool for defining and running multi-container Docker applications using a simple YAML file. This beginner-friendly guide explains how to install Docker and Docker Compose on Debian/Ubuntu, create a basic `docker-compose.yml` file for a web application (Node.js) and database (PostgreSQL), run the application, and manage containers. It's designed for users new to Docker who want to quickly set up a multi-container app.

## What is Docker Compose?

Docker Compose simplifies managing multiple Docker containers by defining services, networks, and volumes in a single `docker-compose.yml` file. Key features include:
- **Multi-Container Apps**: Run web apps, databases, and other services together.
- **Easy Configuration**: Define containers in YAML with minimal commands.
- **Use Cases**: Development, testing, or simple production setups.

This guide sets up a Node.js web server and a PostgreSQL database as an example.

## Prerequisites

- **Debian/Ubuntu**: Version 20.04+.
- **Root Access**: Use `sudo` for installation and Docker commands.
- **Internet Access**: Required for installing Docker and pulling images.
- **Tools**: `curl` or `wget` for downloading installation scripts.
- **Basic Knowledge**: Familiarity with terminal commands.

Verify system:
```bash
uname -a
```
Example output:
```
Linux ubuntu 5.15.0-73-generic #80-Ubuntu SMP Mon May 15 15:18:26 UTC 2023 x86_64 GNU/Linux
```

## Critical Warning: Security and Data

{{< callout type="warning" >}}
**Caution**: Docker containers can expose ports to the internet or consume significant resources. Use secure passwords for databases, avoid exposing development containers in production, and ensure proper permissions for Docker. Back up data before experimenting.
{{< /callout >}}

## How to Use Docker Compose

### 1. Install Docker and Docker Compose
[Install Docker Engine](https://docs.docker.com/engine/install/ubuntu/) and Docker Compose on Debian/Ubuntu.

### 2. Create a Project Directory
Create a directory for your Docker Compose project:
```bash
mkdir my-app
cd my-app
```

### 3. Create a Simple Node.js Application
Create a basic Node.js web server for the example.

1. Create a `backend` directory:
   ```bash
   mkdir backend
   cd backend
   ```

2. Create `package.json`:
   ```bash
   echo '{"name": "app", "version": "1.0.0", "main": "server.js", "dependencies": {"express": "^4.17.1"}}' > package.json
   ```

3. Create `server.js`:
   ```bash
   echo -e 'const express = require("express");\nconst app = express();\napp.get("/", (req, res) => res.send("Hello from Docker Compose!"));\napp.listen(4000, () => console.log("Server running on port 4000"));' > server.js
   ```

4. Create a `Dockerfile`:
   ```bash
   echo -e 'FROM node:16\nWORKDIR /usr/src/app\nCOPY package.json ./\nRUN npm install\nCOPY . .\nEXPOSE 4000\nCMD ["node", "server.js"]' > Dockerfile
   ```

5. Return to the project root:
   ```bash
   cd ..
   ```

### 4. Create a docker-compose.yml File
Create a `docker-compose.yml` file for a Node.js app and PostgreSQL database:
```bash
nano docker-compose.yml
```

Content:
```yaml
services:
  app:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: app
    ports:
      - "4000:4000"
    depends_on:
      - db
    networks:
      - app-net
    environment:
      - DATABASE_URL=postgres://app:secret@db:5432/app_db

  db:
    image: postgres:16
    container_name: db
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: app_db
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - app-net

networks:
  app-net:
    driver: bridge

volumes:
  db-data:
```

### 5. Run the Application
Start the containers:
```bash
docker compose up -d
```

Verify containers are running:
```bash
docker compose ps
```
![Docker Compose container status](/images/docker-compose-ps.png "Output of docker compose ps")
Example output:
```
NAME    SERVICE  STATUS      PORTS
app     app      running     0.0.0.0:4000->4000/tcp
db      db       running
```

Test the web app:
```bash
curl http://localhost:4000
```
Example output:
```
Hello from Docker Compose!
```

### 6. Stop and Remove Containers
Stop and remove containers:
```bash
docker compose down
```

Remove volumes (optional):
```bash
docker compose down -v
```

## Examples

### Example 1: Install Docker and Docker Compose
[Install Docker Engine](https://docs.docker.com/engine/install/ubuntu/) and verify Docker:
```bash
docker compose version
```

**Output**:
```
Docker Compose version v2.40.0
```

### Example 2: Create and Run a Docker Compose App
Set up and run the sample app:
```bash
mkdir my-app
cd my-app
# Create backend files as shown in Step 3
nano docker-compose.yml  # Add the YAML from Step 4
docker compose up -d
curl http://localhost:4000
```

**Output**:
```
Hello from Docker Compose!
```

### Example 3: Check Container Status
Verify running containers:
```bash
docker compose ps
```

**Output**:
```
NAME    SERVICE  STATUS      PORTS
app     app      running     0.0.0.0:4000->4000/tcp
db      db       running
```

### Example 4: Stop and Clean Up
Stop and remove containers:
```bash
docker compose down
```

**Output**:
```
[+] Running 3/3
 ✔ Container app  Removed
 ✔ Container db   Removed
 ✔ Network app-net  Removed
```

## Variants

### Using a Different Web Framework
Replace the Node.js app with a Python Flask app:
1. Create `backend/app.py`:
   ```python
   from flask import Flask
   app = Flask(__name__)
   @app.route('/')
   def hello():
       return 'Hello from Flask!'
   if __name__ == '__main__':
       app.run(host='0.0.0.0', port=4000)
   ```
2. Create `backend/requirements.txt`:
   ```
   flask==2.0.1
   ```
3. Update `backend/Dockerfile`:
   ```dockerfile
   FROM python:3.9
   WORKDIR /app
   COPY requirements.txt .
   RUN pip install -r requirements.txt
   COPY . .
   EXPOSE 4000
   CMD ["python", "app.py"]
   ```

4. Update `docker-compose.yml` to use the new `Dockerfile`.

### Adding a .env File
Create `.env` for environment variables:
```
POSTGRES_USER=app
POSTGRES_PASSWORD=secret
POSTGRES_DB=app_db
```
Update `docker-compose.yml`:
```yaml
services:
  db:
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
```

## Command Breakdown
- **apt install docker-ce docker-compose-plugin**: Installs Docker and Compose.
- **docker compose up -d**: Starts containers in detached mode.
- **docker compose ps**: Lists running containers.
- **docker compose down**: Stops and removes containers.
- **docker compose build**: Builds images from Dockerfiles.
- **curl http://localhost:4000**: Tests the web app.

## Use Cases
- **Development**: Run local web apps with databases.
- **Learning**: Experiment with multi-container setups.
- **Testing**: Test app-database interactions in isolated containers.

## Pro Tips
- **Run Without sudo**: Add your user to the `docker` group to avoid `sudo`.
- **Use Detached Mode**: Use `-d` with `docker compose up` for background running.
- **Check Logs**: Use `docker compose logs` to debug issues.
- **Keep Images Updated**: Pull latest images with `docker compose pull`.
- **Clean Up**: Use `docker compose down -v` to remove volumes and avoid clutter.

## Troubleshooting
- **Docker Command Permission Denied**: Add user to `docker` group or use `sudo`:
  ```bash
  sudo usermod -aG docker $USER
  ```
- **Port Already in Use**: Check for conflicts with `netstat -tuln | grep 4000` and change ports in `docker-compose.yml`.
- **Container Exits Immediately**: Check logs with `docker compose logs app`.
- **Image Pull Fails**: Verify internet access and repository in `docker-compose.yml`.
- **Database Connection Issues**: Ensure `DATABASE_URL` matches `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB`.

## Resources
- [Docker Installation Guide](https://docs.docker.com/engine/install/ubuntu/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker Compose Reference](https://docs.docker.com/reference/cli/docker/compose/)

---

*Get started with Docker Compose on Debian/Ubuntu to run multi-container apps effortlessly!*