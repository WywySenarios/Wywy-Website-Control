# (non-dev) environment variables
set -a
source "$CONTROL_DIR/config/backup/.env"
set +a

# Create backup user
if ! id "$BACKUP_USER" &>/dev/null; then
  sudo useradd -m $BACKUP_USER
  echo "Created new user: $BACKUP_USER"
fi

# Re-populate SSH key secret
echo "$(cat /etc/ssh/ssh_host_ed25519_key.pub)" > "$SECRETS_DIR/backup/ssh_host_ed25519_key.pub"
echo "Repopulated backup host SSH key."

# Set up WAL & backup destinations
for TARGET_DIR in /var/lib/Wywy-Website/backup/postgres_WALs /var/lib/Wywy-Website/backup/postgres_backups; do
  sudo mkdir -p $TARGET_DIR
  sudo chmod 700 $TARGET_DIR
  sudo chown $BACKUP_USER:$BACKUP_USER $TARGET_DIR
done

# Clone README
git clone https://github.com/WywySenarios/Wywy-Website-Backup.git /usr/local/Wywy-Website/Wywy-Website-Backup