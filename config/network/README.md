# OpenWrt router configuration

The `/etc/config` templates live in:

```text
ansible/playbooks/openwrt/templates/
```

Environment-specific secrets live in the encrypted Ansible group vars:

```text
ansible/inventory/<env>/group_vars/openwrt.sops.yaml
```

That file currently holds the operator MAC, DHCPv6 DUID, and ULA prefix.

The only remaining secret inside a template is the `rpcd` password hash in
`templates/rpcd.j2`.

These files are referenced by the router config but are outside `/etc/config`,
so `router.yaml` does not restore them:

| File                                      | Classification       |
| ----------------------------------------- | -------------------- |
| `/etc/uhttpd.key`                         | TLS private key      |
| `/etc/dropbear/dropbear_ed25519_host_key` | SSH host private key |
| `/etc/dropbear/dropbear_rsa_host_key`     | SSH host private key |
| `/etc/shadow`                             | Root password hash   |
| `/etc/dropbear/authorized_keys`           | Public keys          |
| `/etc/uhttpd.crt`                         | Public certificate   |

Automated scanners do not detect UCI secrets reliably. `betterleaks` and
`gitleaks` both miss `option key`, `option hash`, and similar UCI fields.
