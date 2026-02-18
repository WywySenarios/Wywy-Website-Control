#!/bin/bash
export CONTROL_DIR="/etc/Wywy-Website-Control"

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
        echo "Invalid flag \"-${opt}\". Expected -y for automatically say yes." &>2
        exit 1
        ;;
    esac
done

# shift args so that position arguments make sense
shift $((OPTIND-1))

# Create secrets directory if necessary
mkdir -p /etc/Wywy-Website-Control/secrets
chmod 755 /etc/Wywy-Website-Control/secrets
for service_name in $(cat /etc/Wywy-Website-Control/services.txt | cut -d',' -f1); do
    mkdir -p "/etc/Wywy-Website-Control/secrets/$service_name"
    chmod 755 "/etc/Wywy-Website-Control/secrets/$service_name"
done

# install the control repo
sudo mkdir -p /etc/Wywy-Website-Control
sudo chmod 755 /etc/Wywy-Website-Control
sudo chown $USER:$USER /etc/Wywy-Website-Control
git clone https://github.com/WywySenarios/Wywy-Website-Control.git /etc/Wywy-Website-Control

# Pre-flight checks
preflight=0 # innocent until proven guilty
echo "Beginning pre-flight checks."
# Check all secrets have been populated
for secret_path in $(cat /etc/Wywy-Website-Control/secrets.txt); do
  if [[ ! -f "/etc/Wywy-Website-Control/secrets/$secret_path" ]]; then
    echo "MISSING SECRET: secret $secret_path does not exist." >&2
    preflight=0
  fi
done

if [[ ! "$preflight" -eq 0 ]]; then
  echo "ERROR: Installation pre-flight failed." >&2
  exit 1
fi

echo "Pre-flight succeeded. Proceeding with installation."

# install every service that is desired by the user.
sudo mkdir -p /usr/local/Wywy-Website
sudo chmod 755 /usr/local/Wywy-Website
sudo chown $USER:$USER /usr/local/Wywy-Website
for service_name in $(cat /etc/Wywy-Website-Control/services.txt); do
    read -p "Install service $service_name? [y/n]" overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        continue
    fi

    "/etc/Wywy-Website-Control/scripts/install/$service_name.sh"
done