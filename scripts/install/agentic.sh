# (non-dev) environment variables
set -a
source "$CONTROL_DIR/config/agentic/.env"
set +a

REPO_DIR=/usr/local/Wywy-Website/Wywy-Codes

# logging folder
sudo mkdir -p /var/log/Wywy-Website/agentic
sudo chown "$USER_ID":2523 /var/log/Wywy-Website/agentic
sudo chmod 750 /var/log/Wywy-Website/agentic

# orchestrator data folder (needs group write for container user in GID 2523)
sudo mkdir -p /var/lib/Wywy-Website/orchestrator
sudo chgrp 2523 /var/lib/Wywy-Website/orchestrator
sudo chmod 700 /var/lib/Wywy-Website/orchestrator

# pipeline workspace (needs group write for container user in GID 2523)
sudo mkdir -p /var/workspace/Wywy-Website
sudo chgrp 2523 /var/workspace/Wywy-Website
sudo chmod 2770 /var/workspace/Wywy-Website
sudo setfacl -d -m g:2523:rwx /var/workspace/Wywy-Website

if [[ -d "$REPO_DIR" ]]; then
    echo "Wywy-Codes repository is already installed. Skipping source code pull."
else
    git clone https://github.com/WywySenarios/Wywy-Codes.git "$REPO_DIR"
fi

# Set source code group permissions
sudo chgrp -R 2523 "$REPO_DIR"
# set permissions on a best effort basis
chmod -R u+rw "$REPO_DIR" 2>/dev/null || true
chmod -R g=rX "$REPO_DIR" 2>/dev/null || true
sudo chmod g+s "$REPO_DIR"
sudo setfacl -R -d -m g:2523:rx "$REPO_DIR"
chmod -R o-rwx "$REPO_DIR" 2>/dev/null || true

# Install log purge cron job
sudo cp "$CONTROL_DIR/scripts/cron/wywy-agentic-log-purge" /etc/cron.monthly/wywy-agentic-log-purge
sudo chmod 755 /etc/cron.monthly/wywy-agentic-log-purge
echo "Installed log purge cron job."
