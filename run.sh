#!/bin/bash
# FOR DEVELOPMENT USE ONLY.
# Runs the service specified in the positional arguments. Input the reduced lower snake case name of the service.

# Runs a service given the name.
# Arguments:
#   $1: Service name (reduced, lower snake case).
run_service() {
    bash "scripts/run/$1.sh" "dev"
}

rebuild=0

# Check for flags
while getopts "a" opt;
do
    case "${opt}" in
    b)
        rebuild=1
        ;;
    *)
        echo "Invalid flag \"-${opt}\". Expected -b for build" >&2
        exit 1
        ;;
    esac
done

# shift args so that position arguments make sense
shift $((OPTIND-1))

# Run the service specified.
run_service "$1"