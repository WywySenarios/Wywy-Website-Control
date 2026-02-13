#!/bin/bash
# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Error: No argument provided." >&2
  echo "Usage: $0 <prod | dev>" >&2
  exit 1
fi

rebuild=0
endflags=""
project_dir=/usr/local/Wywy-Website/Wywy-Website-Master-Database
docker_dir="$project_dir/docker"
config_dir="/etc/Wywy-Website-Control/config"

# Check for flags
while getopts "b" opt;
do
    case "${opt}" in
    b)
        rebuild=1
        endflags="${endflags} --build"
        ;;
    *)
        echo "Invalid flag \"-${opt}\". Expected -b for build." >&2
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
            --env-file "$config_dir/master-database/.env" \
            up ${endflags}
        ;;
    dev)
        docker compose -f "$docker_dir/docker-compose.dev.yml" \
            --env-file "$config_dir/.env" \
            --env-file "$config_dir/.env.dev" \
            --env-file "$config_dir/master-database/.env" \
            --env-file "$config_dir/master-database/.env.dev" \
            up \
            --watch ${endflags}
        ;;
    *)
        echo "Error: Invalid argument '$1'. Expected 'prod' or 'dev'"
        exit 1
        ;;
esac