---
title: "Installing NVIDIA Container Toolkit"
description: "A guide to installing the NVIDIA Container Toolkit to enable GPU support for Docker containers"
date: 2025-11-04T09:00:00+02:00
lastmod: 2025-11-04T09:00:00+02:00
draft: false
author: "Manzolo"
tags: ["nvidia", "gpu", "container-toolkit", "installation", "cuda"]
categories: ["Docker & Containers"]
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

# Installing NVIDIA Container Toolkit

This guide explains how to install the NVIDIA Container Toolkit, which is essential for enabling GPU acceleration within Docker containers. This is particularly useful for applications that leverage NVIDIA GPUs for tasks like machine learning, scientific computing with GPU support.

## Prerequisites

Before proceeding, ensure you have the following:

1.  **NVIDIA GPU:** A compatible NVIDIA graphics card.
2.  **NVIDIA Drivers:** The latest stable NVIDIA drivers installed for your operating system. You can usually download these from the [NVIDIA website](https://www.nvidia.com/drivers).
3.  **Docker:** Docker Engine installed and running on your system. Follow the official [Docker installation guide](https://docs.docker.com/engine/install/) for your specific OS.

## Installation Steps

Follow these steps to install the NVIDIA Container Toolkit on a Debian/Ubuntu-based system. For other Linux distributions, please refer to the [official NVIDIA Container Toolkit documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html).

### 1. Configure the NVIDIA Container Toolkit Repository

First, add the GPG key for the NVIDIA Container Toolkit and configure the repository.

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
```

### 2. Update Package Lists

Update your system's package list to include the new repository:

```bash
sudo apt-get update
```

### 3. Install the NVIDIA Container Toolkit

Install the `nvidia-container-toolkit` package:

```bash
sudo apt-get install -y nvidia-container-toolkit
```

### 4. Configure Docker Daemon

After installation, you need to configure the Docker daemon to recognize the NVIDIA runtime. This typically involves restarting the Docker service.

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### 5. Verify Installation

To verify that the NVIDIA Container Toolkit is correctly installed and configured, run a simple CUDA container:

```bash
docker run --rm --gpus all nvidia/cuda:12.9.1-runtime-ubuntu24.04 nvidia-smi
```

If the installation was successful, you should see output similar to `nvidia-smi` showing your GPU information.

## Troubleshooting

*   If you encounter issues, ensure your NVIDIA drivers are up-to-date and correctly installed.
*   Check the Docker daemon logs for any errors related to the NVIDIA runtime.
*   Refer to the [official NVIDIA Container Toolkit documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) for more detailed troubleshooting steps.
