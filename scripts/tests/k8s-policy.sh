#!/bin/bash
# Kube-linter for rendered and unrendered plain Kubernetes manifests.
set -euo pipefail

REPO_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../..")"
cd "$REPO_ROOT"
# shellcheck source=../lib/k8s-manifests.sh
source scripts/lib/k8s-manifests.sh

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
RENDER_DIR="$TMP_DIR/rendered"

k8s_render "$RENDER_DIR"
k8s_classify_raw

kube-linter lint --config config/kube-linter-k8s.yaml "$RENDER_DIR" "${RAW_LINT[@]}"
