# (non-dev) environment variables
set -a
source "$CONTROL_DIR/config/backup/.env"
set +a

# stop docker containers
# prod
docker compose -f "$docker_dir/docker-compose.prod.yml" \
    --env-file "$config_dir/.env" \
    --env-file "$config_dir/master-database/.env" \
    down --remove-orphans --rmi --volumes
# dev
docker compose -f "$docker_dir/docker-compose.dev.yml" \
    --env-file "$config_dir/.env" \
    --env-file "$config_dir/.env.dev" \
    --env-file "$config_dir/master-database/.env" \
    --env-file "$config_dir/master-database/.env.dev" \
    down --remove-orphans --rmi --volumes
# test
# @TODO determine which env files to use
docker compose -f "$docker_dir/docker-compose.dev.yml" \
    -f "$docker_dir/docker-compose.test.yml" \
    --env-file "$config_dir/.env" \
    --env-file "$config_dir/.env.dev" \
    --env-file "$config_dir/master-database/.env" \
    --env-file "$config_dir/master-database/.env.dev" \
    down --remove-orphans --rmi --volumes

# set up postgres database folder
sudo mkdir -p "/var/lib/Wywy-Website/master-database/postgres"
sudo chown 999 "/var/lib/Wywy-Website/master-database/postgres"
sudo chmod 700 "/var/lib/Wywy-Website/master-database/postgres"

# Clone source code
if [[ -d "/usr/local/Wywy-Website/Wywy-Website-Master-Database" ]]; then
    echo "Master database repository is already installed. Skipping source code pull."
else
    git clone https://github.com/WywySenarios/Wywy-Website-Master-Database.git /usr/local/Wywy-Website/Wywy-Website-Master-Database
fi