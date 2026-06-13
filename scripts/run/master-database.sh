#!/bin/bash
project_dir=/usr/local/Wywy-Website/Wywy-Website-Master-Database
docker_dir="$project_dir/docker"
config_dir="/etc/Wywy-Website-Control/config"

EXPECTED_FORMAT="Usage: $0 [compose command] <prod | dev | test> [exec target or alias]? ...[docker compose flags]"

compose_files=(-f "$docker_dir/docker-compose.base.yml")
env_files=(
    --env-file "$config_dir/.env"
    --env-file "$config_dir/master-database/.env"
)
endflags=()

# shift args so that position arguments make sense
shift $((OPTIND-1))

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
        if [[ "$compose_command" == "up" ]]; then
            endflags+=(--watch)
        fi
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

# exec target aliases
if [[ "$compose_command" == "exec" ]]; then
    case "$exec_target" in
        sqlr)
            exec_target="sql_receptionist"
            ;;
        pgres | psql | database)
            exec_target="postgres"
            ;;
        unittest)
            exec_target="unit_test"
            ;;
    esac

    compose_command="$compose_command $exec_target bash"
fi

if [[ "$compose_command" == "up" && "$development_environment" == "test" ]]; then
    # Detached + wait: starts services, waits for both test containers to exit, auto-teardowns.
    # Logs stream in background for real-time visibility.
    docker compose ${compose_files[@]} ${env_files[@]} up --detach --wait ${endflags[@]}
    docker compose ${compose_files[@]} ${env_files[@]} logs -f &
    LOGS_PID=$!
    test_cid=$(docker compose ${compose_files[@]} ${env_files[@]} ps -q test)
    unit_cid=$(docker compose ${compose_files[@]} ${env_files[@]} ps -q unit_test)
    docker wait "$test_cid"
    test_exit=$?
    docker wait "$unit_cid"
    unit_exit=$?
    docker compose ${compose_files[@]} ${env_files[@]} down
    kill $LOGS_PID 2>/dev/null
    wait $LOGS_PID 2>/dev/null
    exit_code=0
    [[ $test_exit -ne 0 ]] && exit_code=$test_exit
    [[ $unit_exit -ne 0 ]] && exit_code=$unit_exit
    exit $exit_code
else
    docker compose ${compose_files[@]} ${env_files[@]} $compose_command ${endflags[@]}
fi