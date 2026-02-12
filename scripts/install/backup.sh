# Set up WAL backup destination
sudo mkdir -p /var/lib/Wywy-Website/backup/postgres_WALs
sudo chmod 700 /var/lib/Wywy-Website/backup/postgres_WALs
sudo chown $BACKUP_USER:$BACKUP_USER

# Clone README
git clone https://github.com/WywySenarios/Wywy-Website-Backup.git /usr/local/Wywy-Website/Wywy-Website-Backup