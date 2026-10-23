# K8s Tooling Installation

Scripts in this directory install Kubernetes components and tooling on a
fresh cluster. All are idempotent — safe to re-run.

1. **k8s-base.sh** — control plane bootstrap
   containerd, kubeadm/kubelet/kubectl, Calico CNI, Helm, local-path-provisioner
2. Bring up some nodes (enough to run the observability stack, etc.)
3. **argocd.sh** — GitOps

There are no orchestration wrapper scripts. Run the component scripts directly,
in order: `k8s-base.sh` before workers join, then `argocd.sh` after workers
join. Workloads are deployed by ArgoCD, not by these scripts — including
kube-prometheus-stack (Prometheus, Grafana, Alertmanager) from
`k8s/dev/infrastructure/app-observability.yaml`.

## Port forwarding

`systemd/install.sh` pushes all port-forward services to systemd:

| Service  | Port | URL                   |
| -------- | ---- | --------------------- |
| Grafana  | 8081 | http://localhost:8081 |
| Jellyfin | 8082 | http://localhost:8082 |
| ArgoCD   | 8083 | http://localhost:8083 |
| Jenkins  | 8084 | http://localhost:8084 |
| Immich   | 8085 | http://localhost:8085 |

Each component script also installs its own service automatically. Grafana has
no component script (it is deployed by ArgoCD), and Jellyfin has none at all, so
install their units with `systemd/install.sh grafana-pf.service` and
`systemd/install.sh jellyfin-pf.service` (or run the installer bare for all
units).
