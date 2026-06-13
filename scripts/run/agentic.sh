#!/bin/bash
project_dir="/usr/local/Wywy-Website/Wywy-Codes"
docker_dir="$project_dir/docker"
config_dir="/etc/Wywy-Website-Control/config"

EXPECTED_FORMAT="Usage: $0 [compose command] <prod | dev | test> [exec target or alias]? ...[docker compose flags]"

compose_files=(-f "$docker_dir/docker-compose.base.yml")
env_files=(
    --env-file "$config_dir/.env"
    --env-file "$config_dir/agentic/.env"
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

if [[ -z "$development_environment" ]]; then
    echo "Error: Missing development environment." >&2
    echo "$EXPECTED_FORMAT" >&2
fi

case "$development_environment" in
    prod)
        compose_files+=(-f "$docker_dir/docker-compose.prod.yml")
        ;;
    dev)
        compose_files+=(-f "$docker_dir/docker-compose.dev.yml")
        env_files+=(--env-file "$config_dir/.env.dev")
        ;;
    test)
        compose_files+=(
            -f "$docker_dir/docker-compose.dev.yml"
            -f "$docker_dir/docker-compose.test.yml"
        )
        env_files+=(--env-file "$config_dir/.env.dev")
        ;;
    *)
        echo "Error: Invalid argument '$development_environment'. Expected <'prod'|'dev'|'test'>"
        exit 1
        ;;
esac

# exec target aliases
if [[ "$compose_command" == "exec" ]]; then
    case "$exec_target" in
        py | python)
            exec_target="django"
            ;;
    esac

    compose_command="$compose_command $exec_target bash"
fi

docker compose ${compose_files[@]} ${env_files[@]} $compose_command ${endflags[@]}

# take down testing dockers
if [[ "$compose_command" == "up" && "$development_environment" == "test" ]]; then
    docker compose ${compose_files[@]} ${env_files[@]} down
fi
