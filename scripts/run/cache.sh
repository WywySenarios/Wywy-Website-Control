#!/bin/bash
# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Error: No argument provided." >&2
  echo "Usage: $0 <prod | dev | test>" >&2
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
    test)
        docker compose -f "$docker_dir/docker-compose.dev.yml" \
            -f "$docker_dir/docker-compose.test.yml" \
            --env-file "$config_dir/.env" \
            --env-file "$config_dir/.env.dev" \
            --env-file "$config_dir/cache/.env" \
            --env-file "$config_dir/cache/.env.dev" \
            up ${endflags}

        status=$?

        if [[ "$compose_command" != "config" ]]; then
            docker compose -f "$docker_dir/docker-compose.dev.yml" \
                -f "$docker_dir/docker-compose.test.yml" \
                --env-file "$config_dir/.env" \
                --env-file "$config_dir/.env.dev" \
                --env-file "$config_dir/cache/.env" \
                --env-file "$config_dir/cache/.env.dev" \
                down
        fi
        ;;
    *)
        echo "Error: Invalid argument '$1'. Expected 'prod', 'dev', or 'test'" >&2
        exit 1
        ;;
esac