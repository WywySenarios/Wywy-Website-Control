read -p "Remove all cache data? [y/n] " remove

if [[ "$remove" =~ ^[Yy]$ ]]; then
    sudo rm -rf "/var/lib/Wywy-Website/cache"
    echo "Successfully removed cache data."
fi