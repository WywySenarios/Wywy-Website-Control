#!/bin/bash

service_name=$1

EXPECTED_FORMAT="Bad arguments. Expected [service name]"

if [[ -z "$service_name" ]]; then
  echo "No service name was provided." >&2
  echo "Usage: $EXPECTED_FORMAT" >&2
  exit 1
fi

dir_name=$(grep "^$service_name," /etc/Wywy-Website-Control/services.txt | cut -d',' -f2)

if [[ -z "$dir_name" ]]; then
  echo "Unknown service name \"$service_name\"." >&2
  exit 1
fi

service_dir="/usr/local/Wywy-Website/$dir_name"

if [[ ! -d "$service_dir" ]]; then
  echo "Service directory \"$service_dir\" does not exist." >&2
  exit 1
fi

(cd "$service_dir" && opencode)
