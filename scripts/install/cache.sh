# (non-dev) environment variables
set -a
source "$CONTROL_DIR/config/cache/.env"
set +a

REPO_DIR=/usr/local/Wywy-Website/Wywy-Website-Cache

# set up postgres database folder
sudo mkdir -p "/var/lib/Wywy-Website/cache/postgres"
sudo chown 999 "/var/lib/Wywy-Website/cache/postgres"
sudo chmod 700 "/var/lib/Wywy-Website/cache/postgres"

# logging folder
sudo mkdir -p /var/log/Wywy-Website/cache
sudo chgrp 2523 /var/log/Wywy-Website/cache
sudo chmod 750 /var/log/Wywy-Website/cache
sudo chown $USER_ID /var/log/Wywy-Website/cache

# postgres logging foler
sudo mkdir -p /var/log/Wywy-Website/cache/postgres
sudo chgrp 2523 /var/log/Wywy-Website/cache/postgres
sudo chmod 750 /var/log/Wywy-Website/cache/postgres
sudo chown 999 /var/log/Wywy-Website/cache/postgres

# clone git repository
if [[ -d "/usr/local/Wywy-Website/Wywy-Website-Cache" ]]; then
    echo "Cache repository is already installed. Skipping source code pull."
else
    git clone https://github.com/WywySenarios/Wywy-Website-Cache.git /usr/local/Wywy-Website/Wywy-Website-Cache
fi

# Set source code group permissions
sudo chgrp -R 2523 /usr/local/Wywy-Website/Wywy-Website-Cache
# set permissions on a best effort basis
chmod -R u+rw $REPO_DIR 2>/dev/null || true
chmod -R g-w+r $REPO_DIR 2>/dev/null || true
chmod -R o-rwx $REPO_DIR 2>/dev/null || true