#!/bin/bash
# Arguments:
#   $1: Service name (reduced, lower snake case)
#   $2: Short-hand container name

BAD_ARGUMENTS_MESSAGE="Bad arguments. Expected [service name] [short-hand container name]"
BAD_ARGUMENT_MESSAGE="Bad arguments. Expected [service name] [short-hand container name?]"
config_dir="/etc/Wywy-Website-Control/config"
compose_files=()
env_files=(--env-file "$config_dir/.env")
target=()

if [[ -z "$1" ]]; then
  echo "$BAD_ARGUMENT_MESSAGE" >&2
  exit 1
fi

if [[ "$3" != "prod" ]]; then
  env_files+=(--env-file "$config_dir/.env.dev")
fi

case "$1" in
  backup)
    echo "There is no container to enter to. The backup server does not have any containers!"
    ;;
  master-database)
    if [[ -z "$2" ]]; then
      echo "$BAD_ARGUMENTS_MESSAGE" >&2
      exit 1
    fi

    docker_dir="/usr/local/Wywy-Website/Wywy-Website-Master-Database/docker"

    case "$2" in
      sqlr)
        docker compose -f "$docker_dir/docker-compose.dev.yml" \
            -f "$docker_dir/docker-compose.test.yml" \
            --env-file "$config_dir/.env" \
            --env-file "$config_dir/.env.dev" \
            --env-file "$config_dir/master-database/.env" \
            --env-file "$config_dir/master-database/.env.dev" \
            exec sql_receptionist bash
        ;;
      pgres)
        docker compose -f "$docker_dir/docker-compose.dev.yml" \
            -f "$docker_dir/docker-compose.test.yml" \
            --env-file "$config_dir/.env" \
            --env-file "$config_dir/.env.dev" \
            --env-file "$config_dir/master-database/.env" \
            --env-file "$config_dir/master-database/.env.dev" \
            exec postgres bash
        ;;
      create_tables)
        docker exec -it wywy_website_master_database-create_tables bash
        ;;
      *)
        echo "Error: Invalid argument '$2'. Expected 'sqlr', 'pgres', or 'create_tables'."
        exit 1
        ;;
    esac
    ;;
  cache)
    if [[ -z "$2" ]]; then
      echo "$BAD_ARGUMENTS_MESSAGE" >&2
      exit 1
    fi
    docker_dir=/usr/local/Wywy-Website/Wywy-Website-Cache/docker
    env_files+=(--env-file "$config_dir/cache/.env")

    case "$3" in
      prod)
        compose_files=(
          -f "$docker_dir/docker-compose.prod.yml"
        )
        ;;
      test)
        compose_files=(
          -f "$docker_dir/docker-compose.dev.yml"
          -f "$docker_dir/docker-compose.test.yml"
        )
        env_files+=(--env-file "$config_dir/cache/.env.dev")
        env_files+=(--env-file "$config_dir/.env.dev")
        ;;
      *)
        # dev by default
        compose_files=(
          -f "$docker_dir/docker-compose.dev.yml"
        )
        env_files+=(--env-file "$config_dir/cache/.env.dev")
        env_files+=(--env-file "$config_dir/.env.dev")
        ;;
    esac
    
    case "$2" in
      create_tables)
        target="create_tables bash"
        ;;
      sync)
        target="sync bash"
        ;;
      pgres)
        target="database bash"
        ;;
      test)
        target="test bash"
        ;;
      *)
        echo "Error: Invalid argument '$1'. Expected 'sync', 'mod', 'pgres', or 'test'."
        exit 1
        ;;
    esac

    docker compose ${compose_files[@]} ${env_files[@]} exec $target
    ;;
  website)
    docker_dir=/usr/local/Wywy-Website/Wywy-Website/docker
    docker compose -f "$docker_dir/docker-compose.dev.yml" \
            --env-file "$config_dir/.env" \
            --env-file "$config_dir/.env.dev" \
            --env-file "$config_dir/website/.env" \
            --env-file "$config_dir/website/.env.dev" \
            exec astro-app bash
    ;;
  *)
    echo "Unknown service name \"$1\"." >&2
    ;;
esac