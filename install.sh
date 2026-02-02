#!/bin/bash

y=0

# Check for flags
while getopts "y" opt;
do
    case "${opt}" in
    y)
        y=1
        ;;
    *)
        echo "Invalid flag \"-${opt}\". Expected -y for automatically say yes." &>2
        exit 1
        ;;
    esac
done

# shift args so that position arguments make sense
shift $((OPTIND-1))

# install the control repo
sudo mkdir /etc/Wywy-Website-Control
sudo chmod 755 /etc/Wywy-Website-Control
sudo chown 755 $USER:$USER /etc/Wywy-Website-Control
git clone git@github.com:WywySenarios/Wywy-Website-Control.git /etc/Wywy-Website-Control

# clone every service that is desired by the user.
for service_name in (cat /etc/Wywy-Website-Control/services.txt); do
    read -p "Install service $service_name? [y/n]" overwrite
    if ! [[ $overwrite = "y" ]] && ! [[ $y = "1" ]]
    then
        continue
    fi

    sudo mkdir /usr/local/Wywy-Website
    sudo chmod 755 /usr/local/Wywy-Website
    sudo chown 755 $USER:$USER /usr/local/Wywy-Website
    git clone git@github.com:WywySenarios/Wywy-Website-$service_name.git /usr/local/Wywy-Website/Wywy-Website-$service_name
done

# create secrets directory
mkdir /etc/Wywy-Website-Control/secrets
chmod 755 /etc/Wywy-Website-Control/secrets
for service_name in (cat /etc/Wywy-Website-Control/services.txt); do
    mkdir "/etc/Wywy-Website-Control/secrets/$service_name"
    chmod 755 "/etc/Wywy-Website-Control/secrets/$service_name"
done
