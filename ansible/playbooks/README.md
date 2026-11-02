# Wywy Playbooks

| Category   | Purpose                            | Level |
| ---------- | ---------------------------------- | ----- |
| proxmox    | Hypervisor                         | 0     |
| db         | PostgreSQL database                | 1     |
| files      | NFS (file storage)                 | 1     |
| registry   | Docker registry                    | 1     |
| pki        | Internal certificates              | 1     |
| k8s        | Container orchestration            | 1     |
| argocd     | CD (for containers only)           | 2\*   |
| jenkins    | CI (including building containers) | 3\*   |
| cloudflare | Public service exposure            | 3     |

Tip: Provision the "lower" level items first. We build from the bottom up.

\*ArgoCD cannot sync the Jenkins service unless the Jenkins controller image is already pushed.
