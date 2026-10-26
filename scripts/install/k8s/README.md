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

## Public access (Cloudflare tunnels)

Most (all except Jenkins) cloudflare tunnels are provisioned through a playbook:

```bash
uv run --directory ansible wywy-ansible --dev playbooks/cloudflare/tunnels.yaml
```

| Service     | URL                                |
| ----------- | ---------------------------------- |
| Immich      | https://immich-dev.ericzhu.me      |
| Grafana     | https://grafana-dev.ericzhu.me     |
| Jellyfin    | https://jellyfin-dev.ericzhu.me    |
| Nextcloud   | https://nextcloud-dev.ericzhu.me   |
| Vaultwarden | https://vaultwarden-dev.ericzhu.me |

The generated `cloudflared-tunnel-token.sops.yaml` files live under
`k8s/dev/cloudflared/<namespace>/secrets/` and are reconciled by the
`dev-cloudflared-*` ArgoCD Applications. Run the playbook before pushing the
manifests: the Applications cannot render until the encrypted token files
exist.
