project_dir=/usr/local/Wywy-Website/Wywy-Website-Cache
docker_dir="$project_dir/docker"
config_dir="/etc/Wywy-Website-Control/config"

read -p "Remove all cache data? [y/n] " remove

# stop docker containers
# prod
docker compose -f "$docker_dir/docker-compose.prod.yml" \
    --env-file "$config_dir/.env" \
    --env-file "$config_dir/cache/.env" \
    down --remove-orphans --rmi all --volumes
# dev
docker compose -f "$docker_dir/docker-compose.dev.yml" \
    --env-file "$config_dir/.env" \
    --env-file "$config_dir/.env.dev" \
    --env-file "$config_dir/cache/.env" \
    --env-file "$config_dir/cache/.env.dev" \
    down --remove-orphans --rmi all --volumes

if [[ "$remove" =~ ^[Yy]$ ]]; then
    sudo rm -rf "/var/lib/Wywy-Website/cache"
    echo "Successfully removed cache data."
fi