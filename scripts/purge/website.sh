project_dir=/usr/local/Wywy-Website/Wywy-Website
docker_dir="$project_dir/docker"
config_dir="/etc/Wywy-Website-Control/config"

# @TODO

# clean docker containers
/etc/Wywy-Website-Control/scripts/run/website.sh down prod --remove-orphans --rmi all --volumes
/etc/Wywy-Website-Control/scripts/run/website.sh down dev --remove-orphans --rmi all --volumes
