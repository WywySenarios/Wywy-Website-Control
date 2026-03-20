# (non-dev) environment variables
set -a
source "$CONTROL_DIR/config/backup/.env"
set +a

# stop docker containers
# prod
docker compose -f "$docker_dir/docker-compose.prod.yml" \
    --env-file "$config_dir/.env" \
    --env-file "$config_dir/cache/.env" \
    down --remove-orphans --rmi --volumes
# dev
docker compose -f "$docker_dir/docker-compose.dev.yml" \
    --env-file "$config_dir/.env" \
    --env-file "$config_dir/.env.dev" \
    --env-file "$config_dir/cache/.env" \
    --env-file "$config_dir/cache/.env.dev" \
    down --remove-orphans --rmi --volumes

# set up postgres database folder
sudo mkdir -p "/var/lib/Wywy-Website/cache/postgres"
sudo chown 999 "/var/lib/Wywy-Website/cache/postgres"
sudo chmod 700 "/var/lib/Wywy-Website/cache/postgres"

# clone git repository
if [[ -d "/usr/local/Wywy-Website/Wywy-Website-Cache" ]]; then
    echo "Cache repository is already installed. Skipping source code pull."
else
    git clone https://github.com/WywySenarios/Wywy-Website-Cache.git /usr/local/Wywy-Website/Wywy-Website-Cache
fi