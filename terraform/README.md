# Terraform

Root configuration for every Terraform-managed system.

## Layout

| Path          | Contents                                                |
| ------------- | ------------------------------------------------------- |
| `proxmox/`    | Proxmox VE module, called from the root `main.tf`       |
| `cloudflare/` | Cloudflare tunnel and DNS module, called from `main.tf` |
| `tests/`      | Root-module tests                                       |

Each domain is a child module called from `main.tf`, not a separate root with its own state. `scripts/terraform.sh --dev apply` covers every domain in one state and one lock.

## Providers

[`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox) is pinned to
`0.122.0`. [`cloudflare/cloudflare`](https://registry.terraform.io/providers/cloudflare/cloudflare)
is pinned to `5.8.2`.

The Proxmox provider reads its connection settings from the environment:

| Variable               | Meaning                                                            |
| ---------------------- | ------------------------------------------------------------------ |
| `PROXMOX_VE_ENDPOINT`  | Proxmox API endpoint, normally `https://proxmox-1.internal:8006/`. |
| `PROXMOX_VE_API_TOKEN` | API token in the form `user@realm!tokenid=secret`.                 |
| `PROXMOX_VE_INSECURE`  | `true` while Proxmox uses its self-signed certificate.             |

The Cloudflare provider reads `CLOUDFLARE_API_TOKEN`. The account and zone IDs
are passed as Terraform variables.

Run OpenTofu through the entrypoint:

```bash
scripts/terraform.sh --dev plan
```

The entrypoint defaults the Proxmox endpoint to
`https://proxmox-1.internal:8006/` and `PROXMOX_VE_INSECURE=true`. It requires
`secrets/<env>/proxmox/terraform.sops` and fails if that file is missing. It
also reads `cloudflare_api_token`, `cloudflare_account_id`, and
`cloudflare_zone_id` from `secrets/<env>/cloudflare.sops.yaml`, so Terraform
and the token playbooks use one source for Cloudflare credentials.

## Credentials

| Credential                  | Used by                                       | Stored in                                             |
| --------------------------- | --------------------------------------------- | ----------------------------------------------------- |
| PVE root password           | Installer answer file, initial root login     | `secrets/<env>/proxmox/root.sops.yaml`                |
| SSH public key              | Seeded into the ISO, used by Ansible over SSH | `ansible/inventory/<env>/group_vars/proxmox_iso.yaml` |
| Proxmox API token           | Terraform provider                            | `secrets/<env>/proxmox/terraform.sops`                |
| Cloudflare API token        | Terraform provider, token playbooks           | `secrets/<env>/cloudflare.sops.yaml`                  |
| Cloudflare account/zone IDs | Terraform module                              | `secrets/<env>/cloudflare.sops.yaml`                  |

Terraform does not use the root password or the ISO SSH key. Create a dedicated
`terraform@pve` API token after PVE is installed and store it in the sops file.
Never commit it.

## Cloudflare

Terraform owns tunnel creation, tunnel ingress, and the CNAME records. The
public-host contract lives in `terraform/cloudflare/env/<env>/cloudflare.yaml`.

The tunnel token stays in sops. Cloudflare derives it from the tunnel, and the
Ansible playbooks read it by name after Terraform has applied:

```bash
uv run --directory ansible wywy-ansible --dev playbooks/cloudflare/secrets/populate.yaml
uv run --directory ansible wywy-ansible --dev playbooks/cloudflare/secrets/rotate.yaml --tags cloudflared-tunnel-token
```

To bring the existing tunnels and DNS records under Terraform, import them
before the first apply. The import IDs are opaque:

| Resource             | Import ID                  |
| -------------------- | -------------------------- |
| Tunnel               | `<account_id>/<tunnel_id>` |
| Tunnel configuration | `<account_id>/<tunnel_id>` |
| DNS record           | `<zone_id>/<record_id>`    |

Angle brackets are placeholders, not variables. Passing them literally sends
`%3Caccount_id%3E` and `%3Ctunnel_id%3E` to Cloudflare, which returns 404.

Resolve the IDs from sops and the Cloudflare API, then import each resource:

```bash
cloudflare=secrets/dev/cloudflare.sops.yaml
account_id="$(sops -d --extract '["cloudflare_account_id"]' "$cloudflare")"
zone_id="$(sops -d --extract '["cloudflare_zone_id"]' "$cloudflare")"
api_token="$(sops -d --extract '["cloudflare_api_token"]' "$cloudflare")"

tunnel_id="$(curl -fsS --get \
  --data-urlencode 'name=immich-dev' \
  --data-urlencode 'is_deleted=false' \
  -H "Authorization: Bearer $api_token" \
  "https://api.cloudflare.com/client/v4/accounts/$account_id/cfd_tunnel" \
  | jq -r '.result[0].id')"
record_id="$(curl -fsS --get \
  --data-urlencode 'type=CNAME' \
  --data-urlencode 'name=immich-dev.ericzhu.me' \
  -H "Authorization: Bearer $api_token" \
  "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
  | jq -r '.result[0].id')"

scripts/terraform.sh --dev import \
  'module.cloudflare.cloudflare_zero_trust_tunnel_cloudflared.this["immich-dev"]' \
  "$account_id/$tunnel_id"
scripts/terraform.sh --dev import \
  'module.cloudflare.cloudflare_zero_trust_tunnel_cloudflared_config.this["immich-dev"]' \
  "$account_id/$tunnel_id"
scripts/terraform.sh --dev import \
  'module.cloudflare.cloudflare_dns_record.this["immich-dev"]' \
  "$zone_id/$record_id"
```

Repeat for each tunnel in `terraform/cloudflare/env/dev/cloudflare.yaml`.
Confirm that `scripts/terraform.sh --dev plan` reports no changes before
applying.

## State

State is local to each operator machine. Do not commit state or plan files.

The Cloudflare tunnel token is deliberately not a Terraform resource. Reading it
through `data.cloudflare_zero_trust_tunnel_cloudflared_token` would store the
token in state, so Ansible remains responsible for writing it to sops.
