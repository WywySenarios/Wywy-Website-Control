#!/bin/bash
# Runs the service specified in the positional arguments. Input the reduced name of the service.
# Use this shell script in this format:
# .../run.sh [service_name] [flags] [args]

service_name="$1"

# do not pass in service_name arg
shift

# Run the service specified.
DIR="$(dirname "$(realpath "$0")")"
bash "$DIR/scripts/run/$service_name.sh" up "$@"