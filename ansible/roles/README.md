# Ansible Roles

Roles are grouped by the domain they own. The group directories mirror `ansible/playbooks/`.

Each leaf directory is named after its role because Ansible resolves a role by `<roles_path>/<role_name>/tasks/main.yaml`.
The group paths are listed in `roles_path` in `ansible/ansible.cfg`, so `include_role: name: postgres` resolves to `db/postgres/`.
Adding a new top-level domain means adding its path there.

## `cloudflare/`

| Role                | Owns                      |
| ------------------- | ------------------------- |
| `cloudflare_tunnel` | Cloudflare tunnel and DNS |

## `db/`

| Role                | Owns                                        |
| ------------------- | ------------------------------------------- |
| `postgres`          | PostgreSQL service                          |
| `postgres_password` | PostgreSQL password lifecycle               |
| `postgres_seed`     | PostgreSQL initial roles and database state |
| `postgres_vchord`   | PostgreSQL vector extension                 |

## `files/`

| Role  | Owns                |
| ----- | ------------------- |
| `nfs` | NFS storage service |

## `k8s/`

| Role                | Owns                                     |
| ------------------- | ---------------------------------------- |
| `k8s_control_plane` | Kubernetes control-plane lifecycle       |
| `k8s_network`       | Kubernetes pod network and CoreDNS hosts |
| `k8s_node`          | Kubernetes node prerequisites            |
| `k8s_platform`      | Kubernetes platform services             |
| `k8s_worker`        | Kubernetes worker lifecycle              |

## `openwrt/`

| Role             | Owns                                      |
| ---------------- | ----------------------------------------- |
| `openwrt_router` | Raw OpenWrt config file writer and checksum |

## `pki/`

| Role          | Owns                                     |
| ------------- | ---------------------------------------- |
| `internal_ca` | Internal certificate authority and trust |

## `proxmox/`

| Role                     | Owns                          |
| ------------------------ | ----------------------------- |
| `proxmox_apt`            | Proxmox host package state    |
| `proxmox_cluster`        | Proxmox cluster membership    |
| `proxmox_iso`            | Proxmox installation media    |
| `proxmox_root_passwords` | Proxmox root-password stores  |
| `proxmox_ssh`            | Proxmox SSH access            |
| `proxmox_terraform_token` | Proxmox Terraform API token   |

## `registry/`

| Role       | Owns                     |
| ---------- | ------------------------ |
| `registry` | Container image registry |
