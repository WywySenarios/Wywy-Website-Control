#!/bin/bash
project_dir=/usr/local/Wywy-Website/Wywy-Website
docker_dir="$project_dir/docker"
config_dir="/etc/Wywy-Website-Control/config"

EXPECTED_FORMAT="Usage: $0 [compose command] <prod | dev> [exec target or alias]?"

compose_files=()
env_files=(
    --env-file "$config_dir/.env"
    --env-file "$config_dir/website/.env"
)
endflags=()

# Check for flags
while getopts "b" opt;
do
    case "${opt}" in
    b)
        endflags+=(--build)
        ;;
    *)
        echo "Invalid flag \"-${opt}\". Expected -b for build." >&2
        exit 1
        ;;
    esac
done

# shift args so that position arguments make sense
shift $((OPTIND-1))

# Do not validate. The command will fail by itself if this is invalid.
compose_command=$1
shift
development_environment=$1
shift
# Do not validate. The command will fail by itself if this is invalid. This will automatically be ignored if the compose command is not exec.
exec_target=$1
shift

if [[  -z "$development_environment" ]]; then
    echo "Error: Missing development environment." >&2
    echo "$EXPECTED_FORMAT" >&2
fi

case "$development_environment" in
    prod)
        compose_files+=(-f "$docker_dir/docker-compose.prod.yml")
        ;;
    dev)
        compose_files+=(-f "$docker_dir/docker-compose.dev.yml")
        env_files+=(
            --env-file "$config_dir/.env.dev"
            --env-file "$config_dir/website/.env.dev"
        )
        endflags+=(--watch)
        ;;
    *)
        echo "Error: Invalid argument '$development_environment'. Expected < prod | dev >"
        exit 1
        ;;
esac

docker compose ${compose_files[@]} ${env_files[@]} $compose_command ${endflags[@]}