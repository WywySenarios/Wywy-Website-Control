# Installation

Installation is per user.

Installation requires the "git" package to be installed.

Before installing, check <a href=https://raw.githubusercontent.com/WywySenarios/Wywy-Website-Control/install.sh>my GitHub</a> to see that the script is not malicious.

Run one of these commands to install:

```
curl -o- https://raw.githubusercontent.com/WywySenarios/Wywy-Website-Control/main/install.sh | bash
```

```
wget -qO- https://raw.githubusercontent.com/WywySenarios/Wywy-Website-Control/main/install.sh | bash
```

Find the instructions for the installation of every sub-service inside the respective repo's README.

# Global Secrets

All secrets are located under `./secrets`. Global secrets are files directly inside that directory.
| Secret File Name | purpose |
|---|---|
| admin.txt | The admin password over all services. |
| id_ed25519 | The private SSH key to use when querying another service. |
| id_ed25519.pub | The public SSH key to use when querying another service. |
