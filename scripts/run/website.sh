#!/bin/bash
project_dir=/usr/local/Wywy-Website/Wywy-Website
docker_dir="$project_dir/docker"
config_dir="/etc/Wywy-Website-Control/config"

EXPECTED_FORMAT="Usage: $0 [compose command] <prod | dev> [exec target or alias]? ...[docker compose flags]"

compose_files=()
env_files=(
    --env-file "$config_dir/.env"
    --env-file "$config_dir/website/.env"
)
endflags=()

# Do not validate. The command will fail by itself if this is invalid.
compose_command=$1
shift
development_environment=$1
shift
if [[ "$compose_command" == "exec" ]]; then
    # Do not validate. The command will fail by itself if this is invalid. This will automatically be ignored if the compose command is not exec.
    exec_target=$1
    shift
fi
endflags+=("$@")

# Check for electron build target in trailing args
electron_build=false
for i in "${!endflags[@]}"; do
    if [[ "${endflags[$i]}" == "electron" ]]; then
        electron_build=true
        unset 'endflags[$i]'
        endflags=("${endflags[@]}")
        break
    fi
done

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
        ;;
    *)
        echo "Error: Invalid argument '$development_environment'. Expected < prod | dev >"
        exit 1
        ;;
esac

# If electron build, override compose files and run the build pipeline
if [[ "$electron_build" == true ]]; then
    compose_files=(-f "$docker_dir/docker-compose.build.electron.yml")
    docker compose ${compose_files[@]} ${env_files[@]} up --build --abort-on-container-exit
    result=$?
    docker compose ${compose_files[@]} ${env_files[@]} down
    exit $result
fi

if [[ "$compose_command" == "exec" ]]; then
    compose_command="$compose_command $exec_target bash"
fi

docker compose ${compose_files[@]} ${env_files[@]} $compose_command ${endflags[@]}