# Installation

The installation is global.

Installation requires root permissions (i.e. sudo).

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

# Environment Variable Configuration

## Order of Priority

Environment variables are applied in the following order of priority:

1. .env.dev of the current service
2. .env of the current service
3. .env.dev of a separate service
4. .env of a separate service
5. universal .env.dev
6. universal .env

The environment variables between services should not clash (otherwise they would have been abstracted to a universal environment variable).

## Production vs. Development

- Development environment variables are treated like overrides rather than a divergent option.
- Production environment variables are the default.
- Development environment variables exist only because there is an environmental difference between running the servers on multiple machines versus on one machine.

# Global Secrets

All secrets are located under `./secrets`. Global secrets are files directly inside that directory.
| Secret File Name | purpose |
|---|---|
| admin.txt | The admin password over all services. |
| id_ed25519 | The private SSH key to use when querying another service. |
| id_ed25519.pub | The public SSH key to use when querying another service. |

# File Permissions

Every Wywy-Website file except secrets should be readable by GID 2523. The user who installs the services will automatically be added to this group.
The source code should be owned and modifiable by the user who installed the services.

The secrets folder should be open to write by the installation user during installation.
After installation, the secrets folder should be locked down to root. More specifically, the permissions on the secrets folder will be 000 and it will be owned by root.

NOTE: The file permissions migration has not been complete yet.
