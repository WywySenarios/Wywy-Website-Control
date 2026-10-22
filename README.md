# Wywy-Website-Control

This repo is part of the Wywy repo line and is subject to Wywy conventions.

Infrastructure-as-code and scripts for the Wywy cloud stack.

## Layout

| Path       | Contents                                                                   |
| ---------- | -------------------------------------------------------------------------- |
| `ansible/` | Playbooks and dev/prod inventories that create VMs and configure services. |
| `k8s/`     | Kustomize manifests for the cluster (`base/` and `dev/`).                  |
| `docker/`  | Jenkins and GitHub Actions runner images.                                  |
| `scripts/` | Host bootstrap, installation, and test entrypoints.                        |
| `config/`  | Universal and per-service environment files, plus `config.yml`.            |
| `secrets/` | sops-encrypted secrets (`dev/`, `shared/`).                                |
| `tests/`   | Deployment tests.                                                          |

## Requirements

For the operator machine (the machine you will call scripts from):

- Debian (YMMV with Debian-based distributions)
- `sudo`
- `git`
- Astral's `uv`
- `sops`
- Docker

For your homelab setup:

- Multiple computers to run Proxmox VE
- Preferrably a dedicated network

## Install

Note: The commands below target dev. Substitute `--prod` for production.

1. Build a preseeded Proxmox VE installer ISO:

   ```bash
   scripts/install/preseeds/proxmox/build-proxmox-iso.sh
   ```

Then flash those images to your Proxmox VE nodes

2. Install the Ansible toolchain:

   ```bash
   scripts/install/ansible.sh
   ```

3. Create the VMs and configure each service from `ansible/playbooks/`. Example for the database:

   ```bash
   uv run --directory ansible wywy-ansible --dev playbooks/db/proxmox-template.yaml
   uv run --directory ansible wywy-ansible --dev playbooks/db/proxmox-vm.yaml
   uv run --directory ansible wywy-ansible --dev playbooks/db/db.yaml
   ```

4. On the control-plane node, bootstrap the cluster and then the platform components:

   ```bash
   scripts/install/k8s/k8s-base.sh
   scripts/install/k8s/prometheus-stack.sh
   scripts/install/k8s/linkerd.sh
   scripts/install/k8s/keda.sh
   scripts/install/k8s/argocd.sh
   ```

@TODO steps 3 and 4 are currently intertwined and exact order to run scripts is not documented.

## Configuration

Environment-dependent values live under `config/`. Universal files (`config/.env`, `config/.env.dev`) apply to every service; per-service files (`config/<service>/.env`) override them, and `.env.dev` overrides `.env`. Site-wide YAML lives in `config/config.yml`.

Example configuration:

```bash
# config/.env
UNIVERSAL_CONFIG_DIR=/etc/Wywy-Website-Control/config
SECRETS_DIR=/etc/Wywy-Website-Control/secrets
DATA_DIR=/var/lib/Wywy-Website
MAIN_URL=https://ericzhu.me
```

Secrets are sops-encrypted under `secrets/` and are never committed in plaintext.

@TODO there are secrets and Ansible configuration

## Status

Unstable. Installation is being consolidated on Ansible and the Kubernetes scripts.
