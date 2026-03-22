project_dir=/usr/local/Wywy-Website/Wywy-Website
docker_dir="$project_dir/docker"
config_dir="/etc/Wywy-Website-Control/config"

# @TODO

# stop docker containers
# prod
docker compose -f "$docker_dir/docker-compose.prod.yml" \
    --env-file "$config_dir/.env" \
    --env-file "$config_dir/website/.env" \
    down --remove-orphans --rmi all --volumes
# dev
docker compose -f "$docker_dir/docker-compose.dev.yml" \
    --env-file "$config_dir/.env" \
    --env-file "$config_dir/.env.dev" \
    --env-file "$config_dir/website/.env" \
    --env-file "$config_dir/website/.env.dev" \
    down --remove-orphans --rmi all --volumes