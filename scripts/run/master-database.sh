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
compose_command="up"

# Check for flags
while getopts "bc" opt;
do
    case "${opt}" in
    b)
        rebuild=1
        endflags="${endflags} --build"
        ;;
    c)
        compose_command="config"
        ;;
    *)
        echo "Invalid flag \"-${opt}\". Expected -b for build, -c for config." >&2
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
            $compose_command ${endflags}
        ;;
    dev)
        docker compose -f "$docker_dir/docker-compose.dev.yml" \
            --env-file "$config_dir/.env" \
            --env-file "$config_dir/.env.dev" \
            --env-file "$config_dir/master-database/.env" \
            --env-file "$config_dir/master-database/.env.dev" \
            $compose_command \
            --watch ${endflags}
        ;;
    test)
        # add abort flags if possible
        if [[ "$compose_command" != "config" ]]; then
            endflags="$endflags --abort-on-container-exit --exit-code-from wywy_website_master_database-test"
        fi

        # @TODO determine which env files to use
        docker compose -f "$docker_dir/docker-compose.dev.yml" \
            -f "$docker_dir/docker-compose.test.yml" \
            --env-file "$config_dir/.env" \
            --env-file "$config_dir/.env.dev" \
            --env-file "$config_dir/master-database/.env" \
            --env-file "$config_dir/master-database/.env.dev" \
            $compose_command \
            ${endflags}

        if [[ "$compose_command" != "config" ]]; then
            if [[ $? -eq 0 ]]; then
                echo "Tests succeeded."
            else
                echo "Tests failed."
            fi

            exit $?
        fi
        ;;
    *)
        echo "Error: Invalid argument '$1'. Expected <'prod'|'dev'|'test'>"
        exit 1
        ;;
esac