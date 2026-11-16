# OpenWrt

## Prerequisites

You need to install the operator SSH key into the router manually.

Dependencies are documented upstream:
<https://github.com/openwrt-iac/uapi/blob/main/docs/installation.md>. The router
must run OpenWrt 25.12+ with `apk`; the package pulls `uhttpd`,
`uhttpd-mod-ucode`, `ucode`, the required `ucode-mod-*` modules, and
`rpcd-mod-iwinfo` from the base feed.

Install `uapi` once:

```bash
uv run --directory ansible wywy-ansible --dev playbooks/openwrt/install.yaml
```

The install playbook aligns `uhttpd`, `uhttpd-mod-ubus`, `uhttpd-mod-ucode`,
`ucode`, and `libucode20230711` before installing `uapi`, so the plugin and
daemon are not left on incompatible versions. It also removes the uapi handler
and restarts `uhttpd` if the service does not stay up, so a bad handler does not
leave LuCI down.
