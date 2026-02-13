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
  master-database)
    case "$2" in
      sqlr)
        docker exec -it wywy_website_master_database-sql_receptionist bash
        ;;
      pgres)
        docker exec -it wywy_website_master_database-postgres bash
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
    docker exec -it wywywebsite_astro-dev-server bash
  *)
    echo "Unknown service name \"$1\"." &>2
    ;;
esac