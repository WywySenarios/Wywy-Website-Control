# (non-dev) environment variables
set -a
source "$CONTROL_DIR/config/master-database/.env"
set +a

# set up postgres database folder
sudo mkdir -p "/var/lib/Wywy-Website/master-database/postgres"
sudo chown 999 "/var/lib/Wywy-Website/master-database/postgres"
sudo chmod 700 "/var/lib/Wywy-Website/master-database/postgres"

# logging folder
sudo mkdir -p /var/log/Wywy-Website/master-database
sudo chgrp 2523 /var/log/Wywy-Website/master-database
sudo chmod 750 /var/log/Wywy-Website/master-database
sudo chown $USER_ID /var/log/Wywy-Website/master-database

# postgres logging foler
sudo mkdir -p /var/log/Wywy-Website/master-database/postgres
sudo chgrp 2523 /var/log/Wywy-Website/master-database/postgres
sudo chmod 750 /var/log/Wywy-Website/master-database/postgres
sudo chown 999 /var/log/Wywy-Website/master-database/postgres

# Clone source code
if [[ -d "/usr/local/Wywy-Website/Wywy-Website-Master-Database" ]]; then
    echo "Master database repository is already installed. Skipping source code pull."
else
    git clone https://github.com/WywySenarios/Wywy-Website-Master-Database.git /usr/local/Wywy-Website/Wywy-Website-Master-Database
fi