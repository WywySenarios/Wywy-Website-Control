# Proxmox Setup

## Playbooks

Run these playbooks in order. You will need to flash the ISOs yourself after the iso playbook.

| Playbook                          | Purpose                                                         |
| --------------------------------- | --------------------------------------------------------------- |
| `playbooks/proxmox/populate.yaml` | Add missing PVE and PBS root passwords to the encrypted stores. |
| `playbooks/proxmox/iso.yaml`      | Build the per-node PVE and PBS installer ISOs.                  |
| `playbooks/proxmox/apt.yaml`      | Manage apt sources on PVE nodes.                                |
| `playbooks/proxmox/cluster.yaml`  | Create the PVE cluster and harden SSH.                          |

## Node Topology

### PBS Nodes

PBS machines can have several drives.
The repo-configured disk is the drive to store the target OS in.
There is no RAID.
The remaining drives stay untouched and are added later as PBS datastores.

## Bootstrap

Use playbooks `populate.yaml` and `iso.yaml`

Tip: `ip link show` and `lsblk -o NAME,WWN` can be used to help you gather information.

The `iso.yaml` playbook builds two independent sets:

| Product | Host group                 | Output                                      |
| ------- | -------------------------- | ------------------------------------------- |
| PVE     | `groups['proxmox']`        | `build/proxmox/<env>/iso/<node>.iso`        |
| PBS     | `groups['proxmox_backup']` | `build/proxmox-backup/<env>/iso/<node>.iso` |

An empty `proxmox_backup` group skips the PBS build.

Tip: Force a rebuild with `-e proxmox_iso_force_rebuild=true`.

Feel free to double check the answer file:

```bash
proxmox-auto-install-assistant inspect-iso /path/to/iso
```

Never commit ISOs. They contain plaintext secrets. Delete them once you are done.

### Write the ISO to a USB drive

Note: these commands can and will destroy entire disks worth of content, so take caution.

Tip: if you just connected your USB, you might need to run `sync` for `/dev/sdX` to appear.

Identify the USB device and confirm it is the whole disk, not a partition:

```bash
lsblk -o NAME,SIZE,MODEL,TRAN
```

Then write the ISO to the whole device (replace `/dev/sdX` with the actual value).

```bash
cp build/proxmox/dev/iso/<node>.iso
sync
```

[Further explaination can be found at Debian documentation/tutorials.](https://www.debian.org/releases/stable/amd64/ch04s03.en.html)

A more legacy way of flashing it is:

```bash
sudo dd if=build/proxmox/dev/iso/<node>.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

After this, things should be smooth sailing with Ansible!
