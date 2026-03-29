# (non-dev) environment variables
set -a
source "$CONTROL_DIR/config/website/.env"
set +a

# logging folder
sudo mkdir -p /var/log/Wywy-Website/website
sudo chgrp 2523 /var/log/Wywy-Website/website
sudo chmod 750 /var/log/Wywy-Website/website
sudo chown $USER_ID /var/log/Wywy-Website/website

if [[ -d "/usr/local/Wywy-Website/Wywy-Website" ]]; then
    echo "Website repository is already installed. Skipping source code pull."
else
    git clone https://github.com/WywySenarios/Wywy-Website.git /usr/local/Wywy-Website/Wywy-Website
fi

# Set source code group permissions
sudo chgrp -R 2523 /usr/local/Wywy-Website/Wywy-Website
# lock out other users on a best effort basis
chmod -R o-rwx /usr/local/Wywy-Website/Wywy-Website 2>/dev/null || true