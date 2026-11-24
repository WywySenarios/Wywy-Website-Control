# Kubernetes Playbooks

| Playbook                       | Purpose                                                    | Level |
| ------------------------------ | ---------------------------------------------------------- | ----- |
| `control-plane/bootstrap.yaml` | Install Kubernetes and bootstrap the control-plane nodes.  | 0     |
| `workers/workers.yaml`         | Install Kubernetes and join the worker nodes.              | 1     |
| `cni.yaml`                     | Install Calico CNI.                                        | 2     |
| `registry-endpoint.yaml`       | Refresh the registry-endpoint ConfigMap from `hosts.sops`. | N/A   |

Tip: Provision the "lower" level items first. We build from the bottom up.

Terraform owns the Kubernetes templates and VMs. Ansible starts at
`control-plane/bootstrap.yaml`.
