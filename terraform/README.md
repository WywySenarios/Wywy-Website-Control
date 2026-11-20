# Terraform

Infrastructure-as-code for Proxmox VE.

## Provider

[`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox) is pinned
to `0.122.0`.

The provider reads its connection settings from the environment:

| Variable               | Meaning                                                            |
| ---------------------- | ------------------------------------------------------------------ |
| `PROXMOX_VE_ENDPOINT`  | Proxmox API endpoint, normally `https://proxmox-1.internal:8006/`. |
| `PROXMOX_VE_API_TOKEN` | API token in the form `user@realm!tokenid=secret`.                 |
| `PROXMOX_VE_INSECURE`  | `true` while Proxmox uses its self-signed certificate.             |

Run OpenTofu through the entrypoint:

```bash
scripts/terraform.sh --dev plan
```

The entrypoint defaults the endpoint to `https://proxmox-1.internal:8006/` and
`PROXMOX_VE_INSECURE=true`. It requires
`secrets/<env>/proxmox/terraform.sops` and fails if that file is missing. The
file contains one API token in the form `user@realm!tokenid=secret`.

## Credentials

These are three different things:

| Credential        | Used by                                       | Stored in                                             |
| ----------------- | --------------------------------------------- | ----------------------------------------------------- |
| PVE root password | Installer answer file, initial root login     | `secrets/<env>/proxmox/root.sops.yaml`                |
| SSH public key    | Seeded into the ISO, used by Ansible over SSH | `ansible/inventory/<env>/group_vars/proxmox_iso.yaml` |
| Proxmox API token | Terraform provider                            | `secrets/<env>/proxmox/terraform.sops`                |

Terraform does not use the root password or the ISO SSH key. Create a dedicated
`terraform@pve` API token after PVE is installed and store it in the sops file.
Never commit it.

## State

State is local to each operator machine. Do not commit state or plan files.
