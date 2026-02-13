# (non-dev) environment variables
set -a
source "$CONTROL_DIR/config/backup/.env"
set +a

# Set up WAL & backup destinations
for TARGET_DIR in /var/lib/Wywy-Website/backup/postgres_WALs /var/lib/Wywy-Website/backup/postgres_backups; do
  sudo mkdir -p $TARGET_DIR
  sudo chmod 700 $TARGET_DIR
  sudo chown $BACKUP_USER:$BACKUP_USER $TARGET_DIR
done

# Clone README
git clone https://github.com/WywySenarios/Wywy-Website-Backup.git /usr/local/Wywy-Website/Wywy-Website-Backup