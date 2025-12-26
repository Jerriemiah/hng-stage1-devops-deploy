
# HNG Stage 1 – Automated Deployment with Bash, Docker & NGINX

**DevOps Learning Project | Automation | Deployment Fundamentals**

## Overview

This project demonstrates an automated deployment workflow implemented using a single, production-style Bash script (`deploy.sh`). The script automates the setup and deployment of a Dockerized application on a remote Linux server, including environment preparation, container deployment, reverse proxy configuration, and validation.

The project was completed as part of the **HNG DevOps Internship (Stage 1)** and focuses on **core DevOps fundamentals** such as automation, idempotency, logging, remote execution, and service validation.

---

## Project Context

In real-world DevOps environments, deployments are expected to be:

* Repeatable
* Automated
* Safe to re-run
* Observable
* Easy to validate and troubleshoot

This project simulates that expectation by replacing manual server setup and deployment steps with a single executable script that performs the entire workflow end-to-end.

---

## Objectives

The primary objectives of this project were to:

* Automate application deployment using Bash
* Deploy a Dockerized application to a remote Linux server
* Configure NGINX as a reverse proxy
* Validate service availability after deployment
* Implement logging and error handling
* Ensure the script can be safely re-run (idempotency)

---

## High-Level Deployment Flow

The deployment process implemented by `deploy.sh` follows this sequence:

1. Collect and validate user input
2. Clone or update the application repository
3. Establish SSH connection to a remote server
4. Prepare the remote environment
5. Deploy Docker containers
6. Configure NGINX as a reverse proxy
7. Validate deployment health
8. Log all actions and outcomes

---

## Architecture Overview

**Local Machine**

* Runs the `deploy.sh` script
* Collects user inputs
* Initiates SSH and file transfer

**Remote Server**

* Hosts Docker and NGINX
* Runs the deployed containerized application
* Serves traffic through NGINX reverse proxy

---

## Implementation Details

### 1. User Input & Validation

The script prompts for and validates required parameters, including:

* Git repository URL
* Personal Access Token (PAT)
* Branch name (defaults to `main`)
* Remote server details:

  * Username
  * Server IP
  * SSH key path
* Application container port

Validation ensures required inputs are present before execution continues.

---

### 2. Repository Handling

* Clones the repository using authenticated access via PAT
* If the repository already exists, pulls the latest changes
* Switches to the specified branch
* Verifies the presence of:

  * `Dockerfile` **or**
  * `docker-compose.yml`

This prevents invalid deployments.

---

### 3. Remote Server Connection

* Establishes SSH connectivity using provided credentials
* Performs basic connectivity checks
* Executes deployment steps remotely using non-interactive SSH commands

---

### 4. Remote Environment Preparation

On the remote server, the script:

* Updates system packages
* Installs missing dependencies:

  * Docker
  * Docker Compose
  * NGINX
* Adds the user to the Docker group where necessary
* Enables and starts required services
* Verifies installed versions

These steps ensure a consistent deployment environment.

---

### 5. Application Deployment

* Transfers application files to the remote server
* Builds and runs containers using:

  * `docker build` / `docker run` **or**
  * `docker-compose up -d`
* Stops or removes existing containers if needed
* Ensures clean redeployment without duplication

---

### 6. NGINX Reverse Proxy Configuration

* Dynamically creates or overwrites an NGINX configuration file
* Proxies incoming HTTP traffic on port 80 to the container’s internal port
* Tests the NGINX configuration before reloading
* Reloads NGINX safely without service interruption

---

### 7. Deployment Validation

The script validates deployment success by checking:

* Docker service status
* Container running state
* NGINX proxy functionality
* Application accessibility using `curl` or similar checks

---

### 8. Logging & Error Handling

* All actions are logged to a timestamped log file:

  ```
  deploy_YYYYMMDD.log
  ```
* Success and failure states are clearly recorded
* Trap functions handle unexpected errors
* Meaningful exit codes are used to indicate failure stages

---

### 9. Idempotency & Safe Re-runs

The script is designed to be safely re-run by:

* Preventing duplicate installations
* Cleaning up or replacing old containers
* Avoiding conflicting NGINX configurations
* Reusing existing resources where possible

---

## Tools & Technologies Used

* **Scripting:** Bash (POSIX-compliant)
* **Containers:** Docker, Docker Compose
* **Web Server:** NGINX
* **Remote Access:** SSH, SCP
* **Version Control:** Git
* **Operating System:** Linux

---

## Repository Structure

```text
hng-stage1-devops/
├── deploy.sh
├── Dockerfile
├── docker-compose.yml
├── index.html
├── deploy_20251022.log
└── README.md
```

---

## Validation & Verification

After deployment, the application was accessible via the configured NGINX reverse proxy.

Example verification:

```
http://<server-ip>
```

Connectivity and service health were validated locally and remotely.

---

## Key Learnings

* Writing safe, repeatable Bash automation
* Remote server provisioning via SSH
* Docker-based application deployment
* Reverse proxy configuration using NGINX
* Importance of logging and validation
* Designing scripts to be re-runnable without breaking environments

---

## Limitations & Future Improvements

* Secrets handling could be improved using environment variables or vaults
* SSL/TLS could be added using Certbot
* Health checks could be expanded for deeper validation
* Migration to CI/CD pipelines (GitHub Actions) could further automate deployments

---

## Visuals & Documentation

### Suggested Images to Include

1. Deployment flow diagram
2. Architecture overview (local → server → container → NGINX)
3. Sample terminal output (deployment success)

---

## Image Generation Prompts (For AI Tools)

### 1. Deployment Flow Diagram

> *“A clean DevOps deployment flow diagram showing a local machine running a Bash script deploying a Docker container to a remote Linux server with NGINX reverse proxy. Minimalist vector style, no text.”*

---

### 2. Architecture Overview

> *“A simple architecture diagram showing user → NGINX → Docker container on a Linux server. Flat design, professional DevOps style.”*

---

### 3. Terminal Automation

> *“A terminal window showing a successful automated deployment script running with logs and status messages. Dark terminal theme, clean layout.”*

---

## Why This Project Matters

This project demonstrates:

* Foundational DevOps automation skills
* Understanding of deployment workflows
* Ability to work with Linux servers, Docker, and NGINX
* Emphasis on reliability, validation, and observability

It reflects **entry-level DevOps readiness** and complements an IT Support background with hands-on infrastructure automation experience.

---

## Author

**Jeremiah Inyiama**
GitHub: [https://github.com/Jerriemiah](https://github.com/Jerriemiah)

