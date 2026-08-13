#!/usr/bin/env bash
#
# Bootstrap a K8s control plane — base layer.
#
# Installs containerd, kubeadm/kubelet/kubectl, Calico CNI, Helm,
# and local-path-provisioner (default StorageClass).
#
# Idempotent — safe to re-run.
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# ---- Source network config (K8S_POD_CIDR) ----
CONTROL_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ENV_NETWORK="$CONTROL_DIR/config/.env.network"
[[ -f "$ENV_NETWORK" ]] || {
	echo "Error: $ENV_NETWORK not found" >&2
	echo "Copy config/.env.network.example to config/.env.network and fill in your values." >&2
	exit 1
}
# shellcheck disable=SC1090
source "$ENV_NETWORK"

: "${K8S_POD_CIDR:?K8S_POD_CIDR not set in config/.env.network}"

# ---- Prerequisites ----
if ! command -v sudo &>/dev/null; then
	echo "sudo is required but not found. Install sudo first." >&2
	exit 1
fi

# ---- apt packages (apt is idempotent) ----
sudo apt-get update

# Install containerd
sudo apt-get install -y containerd

# ---- Configure containerd (only if not already set) ----
sudo mkdir -p /etc/containerd
if ! grep -q 'SystemdCgroup = true' /etc/containerd/config.toml 2>/dev/null; then
	echo "==> containerd: enabling SystemdCgroup..."
	sudo mkdir -p /etc/containerd
	containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
	sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
	sudo systemctl restart containerd
	echo "  containerd restarted with SystemdCgroup=true"
else
	echo "  containerd already configured (SystemdCgroup=true)"
fi

# ---- Ensure CNI directories exist with standard permissions ----
sudo apt-get install -y containernetworking-plugins 2>/dev/null || true
sudo mkdir -p /etc/cni/net.d

# ---- Install kubeadm / kubelet / kubectl ----
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key |
	sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" |
	sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
sudo apt-get update
sudo apt-get install -y --allow-change-held-packages kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl 2>/dev/null

# ---- Enable IP forwarding (idempotent) ----
sudo sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-kubernetes.conf >/dev/null

# ---- Initialize control plane (skip if already running) ----
if kubectl cluster-info &>/dev/null; then
	echo "  K8s cluster already initialized — skipping kubeadm init"
else
	echo "==> Initializing control plane..."
	sudo kubeadm init --pod-network-cidr="$K8S_POD_CIDR"
fi

# ---- Configure kubectl (only if not already configured) ----
mkdir -p "$HOME/.kube"
if [ -f "$HOME/.kube/config" ] && [ "$(stat -c '%U' "$HOME/.kube/config")" = "$USER" ]; then
	echo "  kubectl config already present"
else
	sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
	sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
fi
kubectl cluster-info
kubectl get nodes

# ---- Apply Calico CNI (kubectl apply is idempotent) ----
echo "==> Applying Calico CNI..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.2/manifests/calico.yaml

# Patch calico-node: run install-cni as root, and install CNI plugins to
# /usr/lib/cni (containerd's default bin_dir).
echo "==> Patching calico-node..."
kubectl patch ds -n kube-system calico-node --type='json' \
	-p='[
		{"op": "add", "path": "/spec/template/spec/initContainers/1/securityContext", "value": {"runAsUser": 0}},
		{"op": "replace", "path": "/spec/template/spec/volumes/7/hostPath/path", "value": "/usr/lib/cni"}
	]' 2>/dev/null || true

# ---- Label control-plane node (--overwrite makes it idempotent) ----
echo "==> Labeling control-plane node..."
kubectl label node --overwrite "$(hostname)" wywy.io/role=control-plane

# ---- Install Helm (skip if already present) ----
if command -v helm &>/dev/null; then
	echo "  Helm $(helm version --short) already installed"
else
	echo "==> Installing Helm..."
	curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
	echo "  Helm $(helm version --short) installed"
fi

# ---- local-path-provisioner (idempotent) ----
echo "==> local-path-provisioner..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl annotate storageclass local-path \
	storageclass.kubernetes.io/is-default-class=true \
	--overwrite

# --- Output: join token ---
echo ""
echo "=============================================="
echo "  Base K8s control plane is ready."
echo "  Join workers now (with your join-workers.sh script),"
echo "  then run prometheus-stack.sh (and others) from this directory."
echo ""
echo "  Run this on each worker VM to join:"
echo "=============================================="
sudo kubeadm token create --print-join-command
echo "=============================================="
echo ""
echo "Note: The control plane node is tainted."
echo "Worker VMs will receive all workload pods."
