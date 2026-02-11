#!/bin/bash
# Arguments:
#   $1: Service name (reduced, lower snake case)
#   $2: Short-hand container name

if [[ -z "$1" || -z "$2" ]]; then
  echo "Bad arguments. Expected [service name] [short-hand container name]" &>2
  exit 1
fi

case "$1" in
  backup)
    sudo docker exec -it wywywebsite_backup bash
    ;;
  cache)
    case "$2" in
      sync)
        docker exec -it wywywebsite-cache_sync bash
        ;;
      mod)
        sudo docker run -it --rm \
        -p 2325:2325 \
        --env-file .env \
        --mount type=bind,source="$(pwd)/../secrets/admin.txt",target=/run/secrets/admin,readonly \
        docker-mod /bin/sh
        ;;
      pgres)
        sudo docker run -it --rm -p 5432:5432 -v "postgres-db:/var/lib/postgresql" docker-postgres /bin/sh
        ;;
      *)
        echo "Error: Invalid argument '$1'. Expected 'sync', 'mod', or 'pgres'."
        exit 1
        ;;
    esac
    ;;
  website)
    case "$2" in
      astro)
        docker exec -it wywywebsite_astro-dev-server bash
        ;;
      sqlr)
        docker exec -it wywywebsite_sql-receptionist-dev-server bash
        ;;
      pgres)
        docker exec -it wywywebsite_postgres bash
        ;;
      create_tables)
        docker run -it --rm docker-wywywebsite_create_tables bash
        ;;
      *)
        echo "Error: Invalid argument '$2'. Expected 'astro', 'sqlr', or 'pgres'."
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Unknown service name \"$1\"." &>2
    ;;
esac