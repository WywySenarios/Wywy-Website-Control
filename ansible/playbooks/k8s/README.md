# Kubernetes Playbooks

| Playbook                              | Purpose                                                                   |
| ------------------------------------- | ------------------------------------------------------------------------- |
| `control-plane/proxmox-template.yaml` | Build the control-plane VM template on each `k8s_control_plane_pve` host. |
| `control-plane/proxmox-vm.yaml`       | Clone the control-plane VMs.                                              |
| `control-plane/bootstrap.yaml`        | Install Kubernetes and bootstrap the control-plane nodes.                 |
| `cni.yaml`                            | Install Calico CNI.                                                       |
| `storage.yaml`                        | Install local-path after the workers exist.                               |
| `workers/workers.yaml`                | Temporary: wire registry DNS and CA trust on existing workers.            |
| `registry-endpoint.yaml`              | Refresh the registry-endpoint ConfigMap from `hosts.sops`.                |

The `proxmox_vm` role removes the stale SSH host key when it clones a VM, so
recreating a VM at the same address does not require manual `known_hosts`
cleanup.
