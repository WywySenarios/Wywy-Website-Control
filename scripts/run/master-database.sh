#!/bin/bash
project_dir=/usr/local/Wywy-Website/Wywy-Website-Master-Database
docker_dir="$project_dir/docker"
config_dir="/etc/Wywy-Website-Control/config"

EXPECTED_FORMAT="Usage: $0 [compose command] <prod | dev | test> [exec target or alias]?"

compose_files=(-f "$docker_dir/docker-compose.base.yml")
env_files=(
    --env-file "$config_dir/.env"
    --env-file "$config_dir/master-database/.env"
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
            --env-file "$config_dir/master-database/.env.dev"
        )
        endflags+=(--watch)
        ;;
    test)
        compose_files+=(
            -f "$docker_dir/docker-compose.dev.yml"
            -f "$docker_dir/docker-compose.test.yml"
        )
        env_files+=(
            --env-file "$config_dir/.env.dev"
            --env-file "$config_dir/master-database/.env.dev"
        )
        ;;
    *)
        echo "Error: Invalid argument '$development_environment'. Expected <'prod'|'dev'|'test'>"
        exit 1
        ;;
esac

if [[ "$compose_command" == "exec" ]]; then
    case "$exec_target" in
        sqlr)
            exec_target="sql-receptionist"
            ;;
        pgres | psql | database)
            exec_target="postgres"
            ;;
    esac

    compose_command="$compose_command $exec_target bash"
fi

docker compose ${compose_files[@]} ${env_files[@]} $compose_command ${endflags[@]}

# take down testing dockers
if [[ "$compose_command" == "up" && "$development_environment" == "test" ]]; then
    docker compose ${compose_files[@]} ${env_files[@]} down
fi