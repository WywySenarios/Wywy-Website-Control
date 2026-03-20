project_dir=/usr/local/Wywy-Website/Wywy-Website-Backup
config_dir="/etc/Wywy-Website-Control/config"

# purge all postgres backups (prompt first because these are extra sensitive)

read -p "Remove all backups? [y/n] " remove

if [[ "$remove" =~ ^[Yy]$ ]]; then
    sudo rm -rf "/var/lib/Wywy-Website/backup"
    echo "Successfully removed backups."
fi