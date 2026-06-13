# (non-dev) environment variables
set -a
source "$CONTROL_DIR/config/backup/.env"
set +a

REPO_DIR=/usr/local/Wywy-Website/Wywy-Website-Backup

# Create backup user
if ! id "$BACKUP_USER" &>/dev/null; then
  sudo useradd -m $BACKUP_USER
  echo "Created new user: $BACKUP_USER"
fi

# Re-populate SSH key secret
echo "$(cat /etc/ssh/ssh_host_ed25519_key.pub)" > "$SECRETS_DIR/backup/ssh_host_ed25519_key.pub"
echo "Repopulated backup host SSH key."

# Re-populate client SSH key
sudo mkdir -p "/home/$BACKUP_USER/.ssh"
sudo chmod 700 "/home/$BACKUP_USER/.ssh"
sudo chown $BACKUP_USER:$BACKUP_USER "/home/$BACKUP_USER/.ssh"
cat "$SECRETS_DIR/id_ed25519.pub" | sudo tee "/home/$BACKUP_USER/.ssh/authorized_keys" > /dev/null
sudo chmod 600 "/home/$BACKUP_USER/.ssh/authorized_keys"
sudo chown $BACKUP_USER:$BACKUP_USER "/home/$BACKUP_USER/.ssh/authorized_keys"
echo "Re-populated client SSH key."

# Set up WAL & backup destinations
for TARGET_DIR in /var/lib/Wywy-Website/backup/postgres_WALs /var/lib/Wywy-Website/backup/postgres_backups; do
  sudo mkdir -p $TARGET_DIR
  sudo chmod 700 $TARGET_DIR
  sudo chown $BACKUP_USER:$BACKUP_USER $TARGET_DIR
done

# Clone README
if [[ -d "/usr/local/Wywy-Website/Wywy-Website-Backup" ]]; then
  echo "Backup repository already installed. Skipping source code pull."
else
  git clone https://github.com/WywySenarios/Wywy-Website-Backup.git /usr/local/Wywy-Website/Wywy-Website-Backup
fi

# Set source code group permissions
sudo chgrp -R 2523 /usr/local/Wywy-Website/Wywy-Website-Backup
# set permissions on a best effort basis
chmod -R u+rw $REPO_DIR 2>/dev/null || true
chmod -R g=rX $REPO_DIR 2>/dev/null || true
sudo chmod g+s "$REPO_DIR"
sudo setfacl -R -d -m g:2523:rx "$REPO_DIR"
chmod -R o-rwx $REPO_DIR 2>/dev/null || true
