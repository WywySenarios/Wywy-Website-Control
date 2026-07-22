#!/usr/bin/env bash
#
# Push cloud-init snippets to one or more Proxmox hosts and reapply to the
# template on each.
#
# Usage:
#   scripts/proxmox/vm/push-cloud-init.sh --dev
#   scripts/proxmox/vm/push-cloud-init.sh --prod
#   scripts/proxmox/vm/push-cloud-init.sh <host> [host...]
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CLOUD_INIT_DIR="$SCRIPT_DIR/cloud-init"
SYSUSER="wywy"
ROLES=(general "master-db,wywy.io/storage-class=db")

# ---- Require input files ----
BOOTSTRAP_SCRIPT="$CLOUD_INIT_DIR/k8s-bootstrap.sh"
TEMPLATE="$CLOUD_INIT_DIR/k8s-worker.yaml.template"

for f in "$BOOTSTRAP_SCRIPT" "$TEMPLATE"; do
	[ -f "$f" ] || {
		echo "Error: $f not found" >&2
		exit 1
	}
done

# ---- Generate YAML files from template (once, before the loop) ----
echo "==> Generating snippet(s)…"
BOOTSTRAP_B64=$(base64 -w0 <"$BOOTSTRAP_SCRIPT")
GENERATED=()

for role in "${ROLES[@]}"; do
	case "$role" in
	general) out="k8s-worker-general.yaml" ;;
	*) out="k8s-worker-db.yaml" ;;
	esac

	sed -e "s|{{BOOTSTRAP_B64}}|$BOOTSTRAP_B64|g" \
		-e "s|{{NODE_ROLE}}|$role|g" \
		"$TEMPLATE" >"/tmp/$out"

	GENERATED+=("/tmp/$out")
	echo "  ✓ /tmp/$out"
done

# ---- Define callback ----
process_target() {
	local host="$1" worker="$2" idx="$3" prefix="$4"
	local template_vmid=$((2501 + idx))

	echo ""
	echo "==> Pushing to $SYSUSER@$host (template VM $template_vmid)…"

	scp "${GENERATED[@]}" "$SYSUSER@$host:~/"
	ssh "$SYSUSER@$host" bash -s <<REMOTE
    set -euo pipefail

    echo "  -> Installing to /var/lib/vz/snippets/…"
    sudo cp -v ~/k8s-worker-*.yaml /var/lib/vz/snippets/

    echo "  -> Reapplying --cicustom to VM $template_vmid…"
    if [ -f /var/lib/vz/snippets/k8s-worker-general.yaml ]; then
      sudo qm set $template_vmid --cicustom "vendor=local:snippets/k8s-worker-general.yaml"
      echo "  -> Template now uses k8s-worker-general.yaml"
    elif [ -f /var/lib/vz/snippets/k8s-worker-db.yaml ]; then
      sudo qm set $template_vmid --cicustom "vendor=local:snippets/k8s-worker-db.yaml"
      echo "  -> Template now uses k8s-worker-db.yaml"
    else
      echo "  -> No snippet found -- skipping --cicustom"
    fi

    echo "  -> $host done"
REMOTE

	echo "  ✓ $host"
}

# ---- Source helper (runs the loop) ----
source "$SCRIPT_DIR/../target-loop.sh"

# ---- Cleanup ----
rm -f "${GENERATED[@]}"
echo ""
