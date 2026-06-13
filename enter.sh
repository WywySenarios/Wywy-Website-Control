#!/bin/bash

service_name=$1
shift
container_name=$1
shift
development_environment=$1
shift

EXPECTED_FORMAT="Bad arguments. Expected [service name] [short-hand container name] [development environment]"

if [[ -z "$service_name" ]]; then
  echo "No service name was provided." >&2
  echo "Usage: $EXPECTED_FORMAT" >&2
  exit 1
fi

case "$service_name" in
  backup)
    echo "There is no container to enter to. The backup server does not have any containers!"
    exit 0
    ;;
  master-database)
    bash "scripts/run/$service_name.sh" exec $development_environment $container_name
    ;;
  cache)
    bash "scripts/run/$service_name.sh" exec $development_environment $container_name
    ;;
  website)
    bash "scripts/run/$service_name.sh" exec $container_name astro-app
    ;;
  agentic)
    bash "scripts/run/$service_name.sh" exec $development_environment $container_name
    ;;
  *)
    echo "Unknown service name \"$service_name\"." >&2
    ;;
esac