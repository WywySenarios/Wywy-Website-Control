# Set up pgdata directory
for TARGET_DIR in /var/lib/Wywy-Website/master-database/postgres; do
  sudo mkdir -p $TARGET_DIR
  sudo chmod 700 $TARGET_DIR
  sudo chown -R 999:999 $TARGET_DIR
done

# Clone source code
git clone https://github.com/WywySenarios/Wywy-Website-Master-Database.git /usr/local/Wywy-Website/Wywy-Website-Master-Database