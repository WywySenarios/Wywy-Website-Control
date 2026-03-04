#!/bin/bash
# Pulls repository code so that everything is as new as possible.

# pull control repostiory code (always needed)
echo "Updating /etc/Wywy-Website-Control."
git -C /etc/Wywy-Website-Control pull

# pull all services that exist
for service_name in $(cat /etc/Wywy-Website-Control/services.txt | cut -d',' -f2); do
    if [[ ! -d "/usr/local/Wywy-Website/$service_name" ]]; then
        continue;
    fi

    echo "Updating service $service_name."
    git -C "/usr/local/Wywy-Website/$service_name" pull
    git -C "/usr/local/Wywy-Website/$service_name" submodule update --init --recursive
done