#!/bin/bash

# Utility function for colored output
info()   { echo "\033[1;34m[INFO]\033[0m $1"; }
error()  { echo "\033[1;31m[ERROR]\033[0m $1"; }
success(){ echo "\033[1;32m[SUCCESS]\033[0m $1"; }

# Trap unexpected errors
trap 'error "An unexpected error occurred on line $LINENO"; exit 99' ERR

# Timestamp for logs
LOGFILE="deploy_$(date +%Y%m%d).log"

# Prompt for Git info
read -p "Enter Git repository URL: " GIT_REPO
while [ -z "$GIT_REPO" ]; do
    error "Git repo URL cannot be empty."
    read -p "Enter Git repository URL: " GIT_REPO
done

read -s -p "Enter your Personal Access Token (PAT): " GIT_PAT
echo
while [ -z "$GIT_PAT" ]; do
    error "PAT cannot be empty."
    read -s -p "Enter your Personal Access Token (PAT): " GIT_PAT
    echo
done

read -p "Enter branch name (leave blank for 'main'): " GIT_BRANCH
[ -z "$GIT_BRANCH" ] && GIT_BRANCH="main"
info "Using branch: $GIT_BRANCH"

# Prompt for SSH info
read -p "Enter SSH username: " SSH_USER
while [ -z "$SSH_USER" ]; do
    error "SSH username cannot be empty."
    read -p "Enter SSH username: " SSH_USER
done

read -p "Enter remote server IP: " SSH_IP
while ! echo "$SSH_IP" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; do
    error "Invalid IP format."
    read -p "Enter remote server IP: " SSH_IP
done

read -p "Enter path to your SSH private key: " SSH_KEY
while [ ! -f "$SSH_KEY" ]; do
    error "SSH key file not found."
    read -p "Enter path to your SSH private key: " SSH_KEY
done

read -p "Enter internal application port (e.g. 8080): " APP_PORT
while ! echo "$APP_PORT" | grep -Eq '^[0-9]{1,5}$' || [ "$APP_PORT" -lt 1024 ] || [ "$APP_PORT" -gt 65535 ]; do
    error "Port must be a number between 1024-65535."
    read -p "Enter internal application port (e.g. 8080): " APP_PORT
done

# Write input summary to log
{
    info "Git repository: $GIT_REPO"
    info "Branch: $GIT_BRANCH"
    info "SSH username: $SSH_USER"
    info "Remote server IP: $SSH_IP"
    info "SSH key path: $SSH_KEY"
    info "Internal app port: $APP_PORT"
} >> "$LOGFILE"

# Mask PAT output for security
info "Parameters collected. Ready for next steps."

# Optional: display collected values (PAT hidden)
echo "-------- PARAMETER SUMMARY --------"
echo "Git repo:      $GIT_REPO"
echo "Branch:        $GIT_BRANCH"
echo "SSH username:  $SSH_USER"
echo "Server IP:     $SSH_IP"
echo "SSH key path:  $SSH_KEY"
echo "App port:      $APP_PORT"
echo "-----------------------------------"



# ==============================
# CHUNK 2: Clone or Update Repository
# ==============================

info "Starting repository cloning process..."

# Extract repo folder name from URL
REPO_NAME=$(basename -s .git "$GIT_REPO")

# Check if directory already exists
if [ -d "$REPO_NAME" ]; then
    info "Repository $REPO_NAME already exists. Pulling latest changes..."
    cd "$REPO_NAME" || { error "Failed to enter directory $REPO_NAME"; exit 1; }

    git fetch origin "$GIT_BRANCH" >> "../$LOGFILE" 2>&1
    git checkout "$GIT_BRANCH" >> "../$LOGFILE" 2>&1
    git pull origin "$GIT_BRANCH" >> "../$LOGFILE" 2>&1
else
    info "Cloning fresh copy of repository..."
    # Add PAT for authentication (GitHub HTTPS method)
    AUTH_REPO_URL=$(echo "$GIT_REPO" | sed "s#https://#https://$SSH_USER:$GIT_PAT@#")

    git clone -b "$GIT_BRANCH" "$AUTH_REPO_URL" >> "$LOGFILE" 2>&1 \
        || { error "Unable to clone repository. Check Git repo URL or PAT."; exit 1; }

    cd "$REPO_NAME" || { error "Failed to enter directory $REPO_NAME"; exit 1; }
fi

# ===================================
# Verify Docker configuration files
# ===================================

if [ -f "Dockerfile" ] || [ -f "docker-compose.yml" ]; then
    success "Docker configuration verified in $REPO_NAME."
    echo "$(date) - Docker config found in $REPO_NAME" >> "../$LOGFILE"
else
    error "No Dockerfile or docker-compose.yml found in the repository!"
    echo "$(date) - Missing Docker setup in $REPO_NAME" >> "../$LOGFILE"
    exit 1
fi

info "Repository ready for deployment steps."

# ==============================
# CHUNK 3: SSH Connection & Remote Setup
# ==============================

info "Starting SSH connectivity and remote environment setup..."

# Test server reachability (ping)
if ping -c 2 "$SSH_IP" >/dev/null 2>&1; then
    success "Server $SSH_IP is reachable via network."
else
    error "Cannot reach server $SSH_IP. Check network or firewall."
    exit 1
fi

# Temporarily disable error trapping for SSH test
set +e  # disable automatic exit on error
trap - ERR  # pause ERR trap

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 "$SSH_USER@$SSH_IP" "echo Connected" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    error "SSH connection to $SSH_USER@$SSH_IP failed. Verify key permissions and username."
    exit 1
else
    success "SSH authentication successful for $SSH_USER@$SSH_IP."
fi

# Re-enable error trapping
trap 'error "An unexpected error occurred on line $LINENO"' ERR
set -e

# Prepare remote system
info "Preparing remote environment... installing dependencies."

# Disable automatic exit and trap before heredoc

ssh -i "$SSH_KEY" "$SSH_USER@$SSH_IP" <<REMOTE_CMDS
set -e

echo "[INFO] Updating system packages..."
sudo yum update -y >> /tmp/deploy_setup.log 2>&1

echo "[INFO] Installing Docker and Nginx..."
sudo yum install -y docker >> /tmp/deploy_setup.log 2>&1

# Enable nginx repo if not installed already
if ! command -v nginx >/dev/null 2>&1; then
    echo "[INFO] Enabling nginx via amazon-linux-extras..."
    sudo amazon-linux-extras enable nginx1 >> /tmp/deploy_setup.log 2>&1 || true
    sudo yum clean metadata -y >> /tmp/deploy_setup.log 2>&1
    sudo yum install -y nginx >> /tmp/deploy_setup.log 2>&1
fi

echo "[INFO] Enabling and starting services..."
sudo systemctl enable docker nginx
sudo systemctl start docker nginx

echo "[INFO] Installing Docker Compose plugin..."
if ! docker compose version >/dev/null 2>&1; then
    sudo mkdir -p /usr/libexec/docker/cli-plugins
    sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-\$(uname -m)" \
      -o /usr/libexec/docker/cli-plugins/docker-compose
    sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose
fi

echo "[INFO] Adding user to Docker group..."
sudo usermod -aG docker ec2-user

echo "[INFO] Confirming installation versions..."
docker --version
docker compose version || docker-compose version
nginx -v
REMOTE_CMDS

if [ $? -eq 0 ]; then
    success "Remote environment prepared successfully."
else
    error "Remote setup failed on $SSH_IP. Check logs."
    exit 1
fi

# ==============================
# CHUNK 4: Application Deployment & Nginx Proxy Setup
# ==============================

info "Starting remote deployment process..."

# Transfer project files to remote server
info "Copying project files to remote server..."
scp -i "$SSH_KEY" -r . "$SSH_USER@$SSH_IP:/home/$SSH_USER/app" >> "$LOGFILE" 2>&1 \
    || { error "File transfer failed."; exit 1; }

# Deploy application remotely
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_IP" <<'REMOTE_TASKS'
set -e

cd ~/app || { echo "[ERROR] App directory missing."; exit 1; }

echo "[INFO] Stopping previous containers..."
sudo docker ps -q --filter "name=hng_web" | grep -q . && sudo docker stop hng_web && sudo docker rm hng_web || echo "[INFO] No existing container."

echo "[INFO] Building Docker image..."
sudo docker build -t hng_stage1_image . >> /tmp/deploy_app.log 2>&1

echo "[INFO] Starting new container..."
sudo docker run -d --name hng_web -p 8080:80 hng_stage1_image

echo "[INFO] Configuring Nginx reverse proxy..."
sudo bash -c 'cat > /etc/nginx/conf.d/hng_stage1.conf <<EOF
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF'

sudo nginx -t && sudo systemctl reload nginx
REMOTE_TASKS

if [ $? -ne 0 ]; then
    error "Deployment failed."
    exit 1
else
    success "Application deployed successfully and Nginx configured."
    info "Access your app at http://$SSH_IP"
fi

