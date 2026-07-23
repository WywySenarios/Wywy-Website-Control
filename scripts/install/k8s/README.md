# K8s Tooling Installation

Scripts in this directory install Kubernetes components and tooling on a
fresh cluster. All are idempotent — safe to re-run.

1. **k8s-base.sh** — control plane bootstrap
   containerd, kubeadm/kubelet/kubectl, Calico CNI, Helm, local-path-provisioner
2. Bring up some nodes (enough to run the monitoring nodes, etc.)
3. **prometheus-stack.sh** — monitoring
   kube-prometheus-stack (Prometheus + Grafana + Alertmanager), grafana port-forward systemd service
4. **linkerd.sh** — service mesh
5. **argocd.sh** — GitOps

Orchestration wrappers:

- **dev-1.sh** — runs k8s-base.sh (before workers join)
- **dev-2.sh** — runs prometheus-stack.sh, linkerd.sh, argocd.sh (after workers join)

## Port forwarding

`systemd/install.sh` pushes all port-forward services to systemd:

| Service | Port | URL                   |
| ------- | ---- | --------------------- |
| Grafana | 8081 | http://localhost:8081 |
| Linkerd | 8082 | http://localhost:8082 |
| ArgoCD  | 8083 | http://localhost:8083 |

Each component script also installs its own service automatically.
