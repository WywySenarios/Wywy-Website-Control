#!/bin/bash
# Static YAML lint for the Kubernetes manifests.
set -euo pipefail

REPO_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../..")"
cd "$REPO_ROOT"

yamllint --strict -c config/yamllint-k8s.yaml k8s/
