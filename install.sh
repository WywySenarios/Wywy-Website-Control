if [ -d "/etc/Wywy-Website-Control" ];
then
    read -p "Directory /etc/Wywy-Website-Control already exists. Overwrite? [y/n] " overwrite;
    if ! [[ $overwrite = "y" ]];
    then
        echo "Directory /etc/Wywy-Website-Control already exists. Aborting..."
        exit 1
    fi
fi

sudo mkdir /etc/Wywy-Website-Control
sudo chmod 755 /etc/Wywy-Website-Control
sudo chown 755 $USER:$USER /etc/Wywy-Website-Control

git clone git@github.com:WywySenarios/Wywy-Website-Control.git /etc/Wywy-Website-Control