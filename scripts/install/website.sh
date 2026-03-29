# (non-dev) environment variables
set -a
source "$CONTROL_DIR/config/website/.env"
set +a

REPO_DIR=/usr/local/Wywy-Website/Wywy-Website

# logging folder
sudo mkdir -p /var/log/Wywy-Website/website
sudo chgrp 2523 /var/log/Wywy-Website/website
sudo chmod 750 /var/log/Wywy-Website/website
sudo chown $USER_ID /var/log/Wywy-Website/website

if [[ -d "/usr/local/Wywy-Website/Wywy-Website" ]]; then
    echo "Website repository is already installed. Skipping source code pull."
else
    git clone https://github.com/WywySenarios/Wywy-Website.git $REPO_DIR
fi

# Set source code group permissions
sudo chgrp -R 2523 $REPO_DIR
# set permissions on a best effort basis
chmod -R u+rw $REPO_DIR 2>/dev/null || true
chmod -R g-w+r $REPO_DIR 2>/dev/null || true
chmod -R o-rwx $REPO_DIR 2>/dev/null || true