# Proxmox VE 9.2-1 ISO builds

Builds one official PVE 9.2-1 installer ISO per physical Proxmox node from the control repo.

The ISO build runs on the operator machine.

To collect hardware from an already-running PVE node, that node also needs `proxmox-auto-install-assistant` and root or `wywy` sudo access. For a blank node, run `proxmox-auto-install-assistant device-info` in the installer's Debug Mode.

Tip: `ip link show` and `lsblk -o WWN` can be used to help you gather information.

## Playbooks

Example playbooks for dev:

| Playbook                                | Purpose                                            |
| --------------------------------------- | -------------------------------------------------- |
| `playbooks/proxmox/root-passwords.yaml` | Add missing root passwords to the encrypted store. |
| `playbooks/proxmox/iso.yaml`            | Build the per-node installer ISOs.                 |

ISOs output at `build/proxmox/dev/iso/<node>.iso`. Force a rebuild with `-e proxmox_iso_force_rebuild=true`.

Feel free to double check the answer file:

```bash
proxmox-auto-install-assistant inspect-iso /path/to/iso
```

Never commit ISOs. They contain plaintext secrets. Delete them once you are done.

## Write the ISO to a USB drive

Note: these commands can and will destroy entire disks worth of content, so take caution.

Identify the USB device and confirm it is the whole disk, not a partition:

```bash
lsblk -o NAME,SIZE,MODEL,TRAN
```

Then write the ISO to the whole device (replace `/dev/sdX` with the actual value):

```bash
sudo dd if=build/proxmox/dev/iso/<node>.iso of=/dev/sdX bs=4M status=progress oflag=sync
sync
```
