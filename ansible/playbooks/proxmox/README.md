# Proxmox VE 9.2-1 Setup

## Playbooks

Run these playbooks in order. You will need to flash the ISOs yourself after the iso playbook.

| Playbook                                | Purpose                                                                                               |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `playbooks/proxmox/root-passwords.yaml` | Add missing root passwords to the encrypted store.                                                    |
| `playbooks/proxmox/iso.yaml`            | Build the per-node installer ISOs.                                                                    |
| `playbooks/proxmox/apt.yaml`            | Replace all apt sources with controlled Debian, Proxmox, and Ceph Tentacle sources; remove os-prober. |
| `playbooks/proxmox/cluster.yaml`        | Create the PVE cluster, join nodes using the leader fingerprint and root password, then harden SSH.   |

## Bootstrap

Use playbooks `root-passwords.yaml` and `iso.yaml`

Tip: `ip link show` and `lsblk -o WWN` can be used to help you gather information.

ISOs output at `build/proxmox/dev/iso/<node>.iso`. Force a rebuild with `-e proxmox_iso_force_rebuild=true`.

Feel free to double check the answer file:

```bash
proxmox-auto-install-assistant inspect-iso /path/to/iso
```

Never commit ISOs. They contain plaintext secrets. Delete them once you are done.

### Write the ISO to a USB drive

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

After this, things should be smooth sailing with Ansible!
