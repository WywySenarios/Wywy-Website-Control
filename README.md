# Wywy-Website-Control

This repo is part of the Wywy repo line and is subject to Wywy conventions.

Infrastructure-as-code and scripts for the Wywy cloud stack.

## Requirements

The operator machine needs to be set up with the `wywy-dotfiles` repo. It is assumed that this machine is dedicated to solely being an operator machine.

For your homelab setup:

- Multiple computers to run Proxmox VE
- Preferrably a dedicated router

## Usage

1. Flash OpenWRT to your router

2. Configure the IP and subnet the OpenWRT LAN should occupy.

3. set `gateway.internal` in `/etc/hosts` to reoslve to your OpenWRT router

4. Gain SSH access with public key authentication to your OpenWRT router

5. Reserve your IP address as expected by `config/base/network.yaml`

6. Install the Ansible toolchain:

   ```bash
   scripts/install/ansible.sh
   ```

7. Run all the Ansible playbooks and Terraform suites as you see fit! `ansible/playbooks/` and `terraform/` have README's in some subdirectories to give you an idea of what to run in what order.

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

## Known Issues

Jenkins images playbook fails to resolve registry.internal. Currently /etc/hosts manual workaround is needed.

kubectl does not work unless k8s-api.internal is manually defined in /etc/hosts.

Some playbooks (particularily those generating certs) will ask for sudo password and this is not documented.

Proxmox/cloud managed /etc/hosts blocks may override Ansible blocks. Outside-of-cluster DNS needs to happen soon.

Postgres traffic is unencrypted. Clients authenticate with SCRAM, which protects the password, but queries and results travel in plaintext on the LAN. TLS is not configured.

@TODO remove transitional cloudflare secrets

## Status

Unstable. Production with PVE & Kubernetes is not online.

Currently rehearsing prod.
