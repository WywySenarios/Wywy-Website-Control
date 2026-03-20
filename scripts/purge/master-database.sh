read -p "Remove all master-database data? [y/n] " remove

if [[ ! remove =~ [Yy]$ ]]; then
    sudo rm -rf "/var/lib/Wywy-Website/master-database"
fi