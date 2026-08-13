# Security: Self-Hosted Runner PR Protection

**This repository uses self-hosted GitHub Actions runners.**

A self-hosted runner executes code on our own infrastructure. Any pull request from an outside collaborator (i.e., anyone who is not a repository maintainer) can inject arbitrary code into that runner — including access to internal network services, the Docker daemon, and cluster resources.

## Required GitHub Setting

**You MUST enable the following setting on EVERY Wywy repository:**

1. Go to **Settings → Actions → General → Fork pull request workflows from outside collaborators**
2. Select **"Require approval for all outside collaborators"**

Without this setting, any external contributor can open a pull request and have their code execute automatically on our self-hosted runners. This is a **remote code execution** vulnerability with no intermediate gate.

Verify this setting is applied before merging any pull request from an external contributor.

## Additional Recommendations

- If a workflow step executes scripts from the checked-out repository (a `run:` step), that code runs on our infrastructure. Minimize or audit such steps.
- Pin all action versions to immutable commit SHAs (not just major-version tags) to prevent tag hijacking.

---

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

All secrets are located under `./secrets`, organized per environment (`secrets/dev/`, `secrets/prod/`, `secrets/ci/`, `secrets/shared/`). Env-specific secrets share the same file name across environments (e.g. `secrets/dev/postgres-password.sops`, `secrets/prod/postgres-password.sops`); secrets not tied to one cluster live under `secrets/shared/`.

| Secret File Path              | purpose                                                   |
| ----------------------------- | --------------------------------------------------------- |
| secrets/shared/admin.txt      | The admin password over all services.                     |
| secrets/shared/id_ed25519     | The private SSH key to use when querying another service. |
| secrets/shared/id_ed25519.pub | The public SSH key to use when querying another service.  |

# File Permissions

Every Wywy-Website file except secrets should be readable by GID 2523. The user who installs the services will automatically be added to this group.
The source code should be owned and modifiable by the user who installed the services.

The secrets folder should be open to write by the installation user during installation.
After installation, the secrets folder should be locked down to root. More specifically, the permissions on the secrets folder will be 000 and it will be owned by root.

NOTE: The file permissions migration has not been complete yet.
