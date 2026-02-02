#!/bin/bash
# FOR DEVELOPMENT USE ONLY.
# Runs all services specified in the positional arguments. Input the reduced lowercase name of the service.
# 

# Runs a service given the name.
# Arguments:
#   $1: Service name (reduced, lowercase).
run_service() {
    bash "scripts/run/$service_name.sh" "dev"
}

all=0
rebuild=0

# Check for flags
while getopts "a" opt;
do
    case "${opt}" in
    a)
        all=1
        ;;
    b)
        rebuild=1
    *)
        echo "Invalid flag \"-${opt}\". Expected -a for all, -b for build" &>2
        exit 1
        ;;
    esac
done

# shift args so that position arguments make sense
shift $((OPTIND-1))

if [[ a -eq 0 ]];
then
    for service_name in $(cat /etc/Wywy-Website-Control/services.txt); do
        (run_service "$service_name")
    done
fi

# Run each service specified.
for service_name in $#; do
    (run_service "$service_name")
done