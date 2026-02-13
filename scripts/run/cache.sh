#!/bin/bash
# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Error: No argument provided."
  echo "Usage: $0 <prod | dev>"
  exit 1
fi

endflags=""
project_dir="/usr/local/Wywy-Website/Wywy-Website-Cache"
docker_dir="$project_dir/docker"
config_dir="/etc/Wywy-Website-Control/config"

# Check for flags
while getopts "b" opt;
do
    case "${opt}" in
    b)
        endflags="${endflags} --build"
        ;;
    *)
        echo "Invalid flag \"-${opt}\". Expected -b for build." &>2
        exit 1
        ;;
    esac
done

# shift args so that position arguments make sense
shift $((OPTIND-1))

case "$1" in
    prod)
        docker compose -f "$docker_dir/docker-compose.prod.yml" \
            --env-file "$config_dir/.env" \
            --env-file "$config_dir/cache/.env" \
            up ${endflags}
        ;;
    dev)
        docker compose -f "$docker_dir/docker-compose.dev.yml" \
            --env-file "$config_dir/.env" \
            --env-file "$config_dir/.env.dev" \
            --env-file "$config_dir/cache/.env" \
            --env-file "$config_dir/cache/.env.dev" \
            up \
            --watch ${endflags}
        ;;
    *)
        echo "Error: Invalid argument '$1'. Expected 'prod' or 'dev'"
        exit 1
        ;;
esac