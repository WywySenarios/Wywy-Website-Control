#!/bin/bash
# Schema validation for sops-encrypted manifests without decrypting them.
set -euo pipefail

REPO_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../..")"
cd "$REPO_ROOT"
# shellcheck source=../lib/k8s-manifests.sh
source scripts/lib/k8s-manifests.sh

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
SOPS_DIR="$TMP_DIR/sops"

k8s_kubeconform_args "$TMP_DIR/kubeconform-cache"
k8s_classify_raw

if [ "${#RAW_SOPS[@]}" -eq 0 ]; then
	echo "ERROR: no sops manifests found" >&2
	exit 1
fi

# kubeconform only auto-discovers *.yaml/*.yml/*.json, so stage each sops file under a .yaml name.
# Validate the object shape and the sops metadata block without the age key.
for file in "${RAW_SOPS[@]}"; do
	name="${file%.sops.yaml}"
	name="${name%.sops}"
	mkdir -p "$SOPS_DIR/$(dirname "$file")"
	cp "$file" "$SOPS_DIR/${name}.yaml"
done

# Non-strict because the `sops` metadata block is an extra top-level key.
kubeconform -summary "${KUBECONFORM_ARGS[@]}" "$SOPS_DIR"
