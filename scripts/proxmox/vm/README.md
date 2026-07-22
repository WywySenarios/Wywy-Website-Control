# VM Installation

This assumes that you don't have Proxmox-level shared storage.

Remember to specify you target: `--dev`, `--prod`, or the IPs you want to target.

Remember to populate `.env.network`.

1. create-template.sh
2. push-cloud-init.sh
   Push the cloud initialization scripts to the proxmox hosts.
3. recreate-workers.sh
4. join-workers.sh
   The workers join the Kubernetes cluster.
