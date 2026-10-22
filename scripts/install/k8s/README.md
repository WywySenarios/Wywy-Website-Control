# K8s Tooling Installation

Scripts in this directory install Kubernetes components and tooling on a
fresh cluster. All are idempotent — safe to re-run.

1. **k8s-base.sh** — control plane bootstrap
   containerd, kubeadm/kubelet/kubectl, Calico CNI, Helm, local-path-provisioner
2. Bring up some nodes (enough to run the monitoring nodes, etc.)
3. **prometheus-stack.sh** — monitoring
   kube-prometheus-stack (Prometheus + Grafana + Alertmanager), grafana port-forward systemd service
4. **argocd.sh** — GitOps

There are no orchestration wrapper scripts. Run the component scripts directly,
in order: `k8s-base.sh` before workers join, then `prometheus-stack.sh` and
`argocd.sh` after workers join. Workloads are deployed by ArgoCD, not by these
scripts.

## Port forwarding

`systemd/install.sh` pushes all port-forward services to systemd:

| Service  | Port | URL                   |
| -------- | ---- | --------------------- |
| Grafana  | 8081 | http://localhost:8081 |
| Jellyfin | 8082 | http://localhost:8082 |
| ArgoCD   | 8083 | http://localhost:8083 |
| Jenkins  | 8084 | http://localhost:8084 |
| Immich   | 8085 | http://localhost:8085 |

Each component script also installs its own service automatically. Jellyfin has
no component script, so install its unit with `systemd/install.sh jellyfin-pf.service`
(or run the installer bare for all units).
