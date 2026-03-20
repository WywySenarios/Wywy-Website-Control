if [[ -d "/usr/local/Wywy-Website/Wywy-Website" ]]; then
    echo "Website repository is already installed. Skipping source code pull."
else
    git clone https://github.com/WywySenarios/Wywy-Website.git /usr/local/Wywy-Website/Wywy-Website
fi