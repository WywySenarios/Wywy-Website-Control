if [ -d "/etc/Wywy-Website-Config" ];
then
    read -p "Directory /etc/Wywy-Website-Config already exists. Overwrite? [y/n] " overwrite;
    if [[ $overwrite = "y" ]];
    then
        echo "HI"
    else
        echo "Directory /etc/Wywy-Website-Config already exists. Aborting..."
        exit 1
    fi
fi

sudo mkdir /etc/Wywy-Website-Config
sudo chmod 755 /etc/Wywy-Website-Config
sudo chown 755 $USER:$USER /etc/Wywy-Website-Config

git clone git@github.com:WywySenarios/Wywy-Website-Config.git /etc/Wywy-Website-Config