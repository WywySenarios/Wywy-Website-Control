project_dir=/usr/local/Wywy-Website/Wywy-Website-Master-Database
docker_dir="$project_dir/docker"
config_dir="/etc/Wywy-Website-Control/config"

read -p "Remove all master-database data? [y/n] " remove

# clean docker containers
/etc/Wywy-Website-Control/scripts/run/master-database.sh down prod --remove-orphans --rmi all --volumes
/etc/Wywy-Website-Control/scripts/run/master-database.sh down dev --remove-orphans --rmi all --volumes
/etc/Wywy-Website-Control/scripts/run/master-database.sh down test --remove-orphans --rmi all --volumes

if [[ "$remove" =~ ^[Yy]$ ]]; then
    sudo rm -rf "/var/lib/Wywy-Website/master-database"
    echo "Successfully removed master database data."
fi