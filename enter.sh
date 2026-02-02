#!/bin/bash
# Arguments:
#   $1: Service name (reduced, lowercase)
#   ...: Arguments to pass into the service's enter script.

target="scripts/enter/$1.sh"

shift $((OPTIND-1))
bash "$target" "$@"