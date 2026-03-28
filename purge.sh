# Purge all docker containers & database values. ONLY USE IN DEV!!!

set -e

echo "Purging the Wywy-Website repository will remove docker containers, docker images, and Wywy-Website databases."

read -p "Do you want to proceed? [y/n] " yn

if [[ ! "$yn" =~ [Yy]$ ]]; then
    echo "Aborting."
    exit 0
fi

echo "Proceeding with purge in 3,"
sleep 1
echo "2,"
sleep 1
echo "1."
sleep 1
echo "Beginning purge."
sleep 0.1

read -p "Purge logs? [y/n] " logs
if [[ "$logs" =~ ^[Yy]$ ]]; then
    sudo rm -rf /var/log/Wywy-Website
fi

for service_name in $(cat /etc/Wywy-Website-Control/services.txt | cut -d',' -f1); do
    read -p "Purge service $service_name? [y/n] " purge
    if [[ ! "$purge" =~ ^[Yy]$ ]]; then
        continue
    fi

    "/etc/Wywy-Website-Control/scripts/purge/$service_name.sh"
done

read -p "Prune docker? [y/n] " prune
if [[ "$prune" =~ ^[Yy]$ ]]; then
    docker system prune -af
fi