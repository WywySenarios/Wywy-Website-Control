project_dir=/usr/local/Wywy-Website/Wywy-Website-Cache
docker_dir="$project_dir/docker"
config_dir="/etc/Wywy-Website-Control/config"

read -p "Remove all cache data? [y/n] " remove

# clean docker containers
/etc/Wywy-Website-Control/scripts/run/cache.sh down prod --remove-orphans --rmi all --volumes
/etc/Wywy-Website-Control/scripts/run/cache.sh down dev --remove-orphans --rmi all --volumes
/etc/Wywy-Website-Control/scripts/run/cache.sh down test --remove-orphans --rmi all --volumes

if [[ "$remove" =~ ^[Yy]$ ]]; then
    sudo rm -rf "/var/lib/Wywy-Website/cache"
    echo "Successfully removed cache data."
fi