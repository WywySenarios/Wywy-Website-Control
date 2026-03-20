# stop docker containers
# prod
docker compose -f "$docker_dir/docker-compose.prod.yml" \
    --env-file "$config_dir/.env" \
    --env-file "$config_dir/website/.env" \
    down --remove-orphans --rmi --volumes
# dev
docker compose -f "$docker_dir/docker-compose.dev.yml" \
    --env-file "$config_dir/.env" \
    --env-file "$config_dir/.env.dev" \
    --env-file "$config_dir/website/.env" \
    --env-file "$config_dir/website/.env.dev" \
    down --remove-orphans --rmi --volumes

if [[ -d "/usr/local/Wywy-Website/Wywy-Website" ]]; then
    echo "Website repository is already installed. Skipping source code pull."
else
    git clone https://github.com/WywySenarios/Wywy-Website.git /usr/local/Wywy-Website/Wywy-Website
fi