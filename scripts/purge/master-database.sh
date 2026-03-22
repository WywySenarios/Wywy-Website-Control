project_dir=/usr/local/Wywy-Website/Wywy-Website-Master-Database
docker_dir="$project_dir/docker"
config_dir="/etc/Wywy-Website-Control/config"

read -p "Remove all master-database data? [y/n] " remove

# stop docker containers
# prod
docker compose -f "$docker_dir/docker-compose.prod.yml" \
    --env-file "$config_dir/.env" \
    --env-file "$config_dir/master-database/.env" \
    down --remove-orphans --rmi all --volumes
# dev
docker compose -f "$docker_dir/docker-compose.dev.yml" \
    --env-file "$config_dir/.env" \
    --env-file "$config_dir/.env.dev" \
    --env-file "$config_dir/master-database/.env" \
    --env-file "$config_dir/master-database/.env.dev" \
    down --remove-orphans --rmi all --volumes
# test
# @TODO determine which env files to use
docker compose -f "$docker_dir/docker-compose.dev.yml" \
    -f "$docker_dir/docker-compose.test.yml" \
    --env-file "$config_dir/.env" \
    --env-file "$config_dir/.env.dev" \
    --env-file "$config_dir/master-database/.env" \
    --env-file "$config_dir/master-database/.env.dev" \
    down --remove-orphans --rmi all --volumes

if [[ "$remove" =~ ^[Yy]$ ]]; then
    sudo rm -rf "/var/lib/Wywy-Website/master-database"
    echo "Successfully removed master database data."
fi