# Wywy-Website-Control

This repo is part of the Wywy repo line and is subject to Wywy conventions.

Infrastructure-as-code and scripts for the Wywy cloud stack.

## Requirements

The operator machine needs to be set up with the `wywy-dotfiles` repo. It is assumed that this machine is dedicated to solely being an operator machine.

For your homelab setup:

- Multiple computers to run Proxmox VE
- Preferrably a dedicated network

## Install

Note: The commands below target dev. Substitute `--prod` for production.

1. Install the Ansible toolchain:

   ```bash
   scripts/install/ansible.sh
   ```

2. Run all the Ansible playbooks as you see fit! `ansible/playbooks/` might have README's in the subdir to give you an idea of what to run in what order.

## Configuration

Environment-dependent values live under `config/`.
The repo is expected to be checked out at `/etc/Wywy-Website-Control`.
The (deprecated) env files reference that absolute path.
Env files apply in this order, highest priority first:

1. `config/<service>/.env.dev`
2. `config/<service>/.env`
3. `config/.env.dev`
4. `config/.env`

Some secrets are sops-encrypted under `secrets/<env>/` (currently `secrets/dev/`) and `secrets/shared/`.

Ansible configuration lives in `ansible/inventory/<env>/group_vars/` as plain `*.yaml` and encrypted `*.sops.yaml` files.

## Status

Unstable. Production with PVE & Kubernetes is not online.
