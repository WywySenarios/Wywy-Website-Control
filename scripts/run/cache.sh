#!/bin/bash
# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Error: No argument provided."
  echo "Usage: $0 <prod | dev>"
  exit 1
fi

project_dir="/usr/local/Wywy-Website/Wywy-Website-Cache"
docker_dir="$project_dir/docker"
config_dir="/etc/Wywy-Website-Control/config"

case "$1" in
    prod)
        docker compose -f "$docker_dir/docker-compose.prod.yml" \
            --env-file "$config_dir/.env" \
            --env-file "$config_dir/cache/.env" \
            --env-file "$config_dir/cache/.env.prod" \
            up
        ;;
    dev)
        docker compose -f "$docker_dir/docker-compose.dev.yml" \
            --env-file "$config_dir/.env" \
            --env-file "$config_dir/cache/.env" \
            --env-file "$config_dir/cache/.env.dev" \
            up \
            --watch
        ;;
    *)
        echo "Error: Invalid argument '$1'. Expected 'prod' or 'dev'"
        exit 1
        ;;
esac