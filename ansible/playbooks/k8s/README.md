# Kubernetes Playbooks

| Playbook                              | Purpose                                                                   | Level |
| ------------------------------------- | ------------------------------------------------------------------------- | ----- |
| `control-plane/proxmox-template.yaml` | Build the control-plane VM template on each `k8s_control_plane_pve` host. | 0     |
| `workers/proxmox-template.yaml`       | Build the worker VM template on each `k8s_workers_pve` host.              | 0     |
| `control-plane/proxmox-vm.yaml`       | Clone the control-plane VMs.                                              | 1     |
| `workers/proxmox-vm.yaml`             | Clone the worker VMs.                                                     | 1     |
| `control-plane/bootstrap.yaml`        | Install Kubernetes and bootstrap the control-plane nodes.                 | 2     |
| `workers/workers.yaml`                | Install Kubernetes and join the worker nodes.                             | 3     |
| `cni.yaml`                            | Install Calico CNI.                                                       | 4     |
| `coredns.yaml`                        | Render the `*.internal` names into the CoreDNS hosts block.               | 5     |
| `registry-endpoint.yaml`              | Refresh the registry-endpoint ConfigMap from `hosts.sops`.                | N/A   |

Tip: Provision the "lower" level items first. We build from the bottom up.

The `proxmox_vm` role removes the stale SSH host key when it clones a VM, so
recreating a VM at the same address does not require manual `known_hosts`
cleanup.
