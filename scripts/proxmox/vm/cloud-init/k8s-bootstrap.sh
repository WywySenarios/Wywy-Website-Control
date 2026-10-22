#!/bin/bash
#
# Bootstrap Kubernetes packages and kubelet config for a worker VM.
# Runs once at cloud-init first boot.
#
# Usage: NODE_ROLE=general ./k8s-bootstrap.sh
#        NODE_ROLE=master-db,wywy.io/storage-class=db ./k8s-bootstrap.sh
#
set -euo pipefail

LOG_FILE="/var/log/k8s-bootstrap.log"
NODE_ROLE="${NODE_ROLE:-general}"

# Log everything — tee to the log so both console (cloud-init captures it) and
# the file get a copy for post-mortem inspection.
exec > >(tee -a "$LOG_FILE") 2>&1

step() {
	echo ""
	echo "[$(date '+%H:%M:%S')] === $* ==="
}

# ---------------------------------------------------------------------------
step "Configure containerd"
# ---------------------------------------------------------------------------
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
echo "  -> containerd running, SystemdCgroup=true"

# ---------------------------------------------------------------------------
step "Add Kubernetes apt repository"
# ---------------------------------------------------------------------------
mkdir -p /etc/apt/keyrings
curl -fsSL --retry 5 --retry-delay 5 \
	https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key |
	gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
if [ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then
	echo "FATAL: failed to download Kubernetes GPG key" >&2
	exit 1
fi
echo "  -> GPG key installed"

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" \
	>/etc/apt/sources.list.d/kubernetes.list
echo "  -> kubernetes.list written"

# ---------------------------------------------------------------------------
step "Install kubelet / kubeadm / kubectl"
# ---------------------------------------------------------------------------
apt update && apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
echo "  -> installed v1.36, held"

# ---------------------------------------------------------------------------
step "Enable IP forwarding"
# ---------------------------------------------------------------------------
sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' >/etc/sysctl.d/99-kubernetes.conf
echo "  -> net.ipv4.ip_forward=1"

# ---------------------------------------------------------------------------
step "Configure kubelet --node-labels"
# ---------------------------------------------------------------------------
echo "KUBELET_EXTRA_ARGS=\"--node-labels=$NODE_ROLE\"" >/etc/default/kubelet
echo "  -> KUBELET_EXTRA_ARGS set to --node-labels=$NODE_ROLE"

systemctl daemon-reload && systemctl restart kubelet
echo "  -> kubelet restarted"

# ---------------------------------------------------------------------------
step "k8s bootstrap complete — see /var/log/k8s-bootstrap.log"
# ---------------------------------------------------------------------------
