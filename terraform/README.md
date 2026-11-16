# OpenWrt Terraform

Infrastructure-as-code for the OpenWrt gateway (`gateway.internal`, also the current `nameserver.internal` host).

## Provider

[`openwrt-iac/uapi`](https://registry.terraform.io/providers/openwrt-iac/uapi)
talks to the router's native uapi HTTP API. The router must run OpenWrt 25.12+
with `uapi >= 3.0.0` and a scoped bearer token.

`uapi-token` comes from the router's `uapi` package. The install playbook
installs it; the populate playbook runs:

```bash
uapi-token create --name terraform --scope '*:rw'
```

This is the bootstrap token: Terraform cannot mint the token it uses to
authenticate. The playbook writes the encrypted secret to:

```text
secrets/<env>/openwrt/uapi.sops
```

The file contains only the bearer token. The admin only installs the operator
SSH public key on the router. Install `uapi` once, then populate the token:

```bash
uv run --directory ansible wywy-ansible --dev playbooks/openwrt/install.yaml
uv run --directory ansible wywy-ansible --dev playbooks/openwrt/secrets/populate.yaml
```

After this token exists, scoped tokens can be minted with the provider's
`uapi_token` ephemeral resource.

The router endpoint is committed in `terraform/providers.tf`. The bearer token
and TLS setting come from the environment:

| Variable        | Meaning                                                        |
| --------------- | -------------------------------------------------------------- |
| `UAPI_TOKEN`    | Bearer token                                                   |
| `UAPI_INSECURE` | `1` only while the router presents its self-signed certificate |

Run OpenTofu through the entrypoint:

```bash
scripts/terraform.sh --dev plan
```

It loads the token from `secrets/<env>/openwrt/uapi.sops` and sets
`UAPI_TOKEN` for the command. The router currently uses a self-signed
certificate, so the entrypoint defaults `UAPI_INSECURE=1`; override it to `0`
once the router has a trusted certificate.

## Inputs

The VM network contract lives in `config/base/network.yaml` and is shared with Ansible.

## State

State is local to each operator machine.
Do not commit state or plan files.
