#!/bin/bash
# Strict schema validation for rendered and raw plain Kubernetes manifests.
set -euo pipefail

REPO_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../..")"
cd "$REPO_ROOT"
# shellcheck source=../lib/k8s-manifests.sh
source scripts/lib/k8s-manifests.sh

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
RENDER_DIR="$TMP_DIR/rendered"

k8s_kubeconform_args "$TMP_DIR/kubeconform-cache"
k8s_render "$RENDER_DIR"
k8s_classify_raw

if [ "${#RAW_PLAIN[@]}" -eq 0 ]; then
	echo "ERROR: no plain manifests found" >&2
	exit 1
fi

kubeconform -strict -summary "${KUBECONFORM_ARGS[@]}" "$RENDER_DIR" "${RAW_PLAIN[@]}"
