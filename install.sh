#!/bin/bash
export CONTROL_DIR="/etc/Wywy-Website-Control"

set -e

# (non-dev) environment variables
set -a
source "$CONTROL_DIR/config/.env"
set +a

# Ensure that necessary commands are available
# sudo
if ! command -v sudo >/dev/null 2>&1; then
    echo "FATAL: sudo is not installed." >&2
    exit 1
# git
elif ! command -v git >/dev/null 2>&1; then
    echo "Installing git."
    if ! sudo apt-get install git; then
        echo "Failed to install git. Aborting." >&2
        exit 1
    fi
# acl (needed for setfacl on source trees)
elif ! command -v setfacl >/dev/null 2>&1; then
    echo "Installing acl."
    if ! sudo apt-get install -y acl; then
        echo "Failed to install acl. Aborting." >&2
        exit 1
    fi
fi

y=0

# Check for flags
while getopts "y" opt;
do
    case "${opt}" in
    y)
        y=1
        ;;
    *)
        echo "Invalid flag \"-${opt}\". Expected -y for automatically say yes." >&2
        exit 1
        ;;
    esac
done

# shift args so that position arguments make sense
shift $((OPTIND-1))

# Create secrets directory if necessary
sudo mkdir -p /etc/Wywy-Website-Control/secrets
sudo chmod 700 /etc/Wywy-Website-Control/secrets
sudo chown $USER /etc/Wywy-Website-Control/secrets
for service_name in $(cat /etc/Wywy-Website-Control/services.txt | cut -d',' -f1); do
    sudo mkdir -p "/etc/Wywy-Website-Control/secrets/$service_name"
    sudo chmod 700 "/etc/Wywy-Website-Control/secrets/$service_name"
done

# install the control repo
sudo mkdir -p /etc/Wywy-Website-Control
sudo chmod 2750 /etc/Wywy-Website-Control
sudo chown $USER:Wywy-Website /etc/Wywy-Website-Control
if [[ $(git -C "/etc/Wywy-Website-Control" rev-parse --is-inside-work-tree >/dev/null 2>&1) ]]; then
    git clone https://github.com/WywySenarios/Wywy-Website-Control.git /etc/Wywy-Website-Control
fi
sudo chown -R $USER:Wywy-Website /etc/Wywy-Website-Control

# Pre-flight checks (TEMPORARILY DISABLED)
preflight=0 # innocent until proven guilty
echo "Beginning pre-flight checks."
# Check all secrets have been populated
for secret_path in $(cat /etc/Wywy-Website-Control/secrets.txt); do
  if [[ ! -f "/etc/Wywy-Website-Control/secrets/$secret_path" ]]; then
    echo "MISSING SECRET: secret $secret_path does not exist." >&2
    #preflight=1
  fi
done

if [[ ! "$preflight" -eq 0 ]]; then
  echo "ERROR: Installation pre-flight failed." >&2
  exit 1
fi

echo "Pre-flight succeeded. Proceeding with installation."

# Create GID 2523
if ! getent group Wywy-Website >/dev/null 2>&1; then
    sudo groupadd -g 2523 Wywy-Website
fi

# Add the current user to GID 2523
sudo usermod -aG 2523 $USER

# create logs folder
sudo mkdir -p /var/log/Wywy-Website
sudo chgrp 2523 /var/log/Wywy-Website
sudo chmod 050 /var/log/Wywy-Website

# install every service that is desired by the user.
sudo mkdir -p /usr/local/Wywy-Website
sudo chmod 2750 /usr/local/Wywy-Website
sudo chgrp 2523 /usr/local/Wywy-Website
sudo setfacl -d -m g:2523:rx /usr/local/Wywy-Website
for service_name in $(cat /etc/Wywy-Website-Control/services.txt | cut -d',' -f1); do
    read -p "Install service $service_name? [y/n] " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        continue
    fi

    "/etc/Wywy-Website-Control/scripts/install/$service_name.sh"
done

# set permissions for the control repository
chmod -R u+rw /etc/Wywy-Website-Control
chmod -R g=rX /etc/Wywy-Website-Control
sudo chmod g+s /etc/Wywy-Website-Control
sudo setfacl -R -d -m g:2523:rx /etc/Wywy-Website-Control
chmod -R o-rwx /etc/Wywy-Website-Control
sudo chgrp -R 2523 /etc/Wywy-Website-Control

# lock down secrets folder
chmod 000 /etc/Wywy-Website-Control/secrets
sudo chown root /etc/Wywy-Website-Control/secrets

echo "Installation complete. Enjoy!"
