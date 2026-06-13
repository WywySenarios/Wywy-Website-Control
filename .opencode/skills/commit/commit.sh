#!/bin/bash
# Commits staged changes in a Wywy service repository, with optional submodule recursion.
# Usage: commit.sh [-r] <service_name> "<message>"
#   -r  Also commit inside each dirty submodule before committing the parent repo.
#   service_name: cache | website | backup | master-database | agentic | control
#
# NOTE: This script only runs git commit. Staging (git add) must be done beforehand.

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
REPO_ROOT="/etc/Wywy-Website-Control"
RECURSE=0

usage() {
    echo "Usage: commit.sh [-r] <service_name> \"<message>\"" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--recurse-submodules) RECURSE=1; shift ;;
        -*) echo "Unknown flag: $1" >&2; usage ;;
        *) break ;;
    esac
done

if [[ $# -lt 2 ]]; then
    usage
fi

service_name="$1"
message="$2"

resolve_repo_path() {
    local name="$1"

    if [[ "$name" == "control" ]]; then
        echo "$REPO_ROOT"
        return
    fi

    local repo_name
    repo_name=$(grep "^$name," "$REPO_ROOT/services.txt" | cut -d',' -f2)
    if [[ -z "$repo_name" ]]; then
        echo "Error: unknown service '$name'. Valid services: cache, website, backup, master-database, agentic, control" >&2
        exit 1
    fi

    local repo_path="/usr/local/Wywy-Website/$repo_name"
    if [[ ! -d "$repo_path" ]]; then
        echo "Error: repo directory '$repo_path' does not exist." >&2
        exit 1
    fi

    echo "$repo_path"
}

repo_path=$(resolve_repo_path "$service_name")

if [[ "$RECURSE" -eq 1 ]]; then
    echo "=== Recurse into submodules ==="
    while IFS=' ' read -r _sub_hash sub_path _rest; do
        sub_path="$repo_path/$sub_path"
        if [[ -z "$(git -C "$sub_path" status --porcelain)" ]]; then
            echo "Skipping $sub_path (clean)"
            continue
        fi
        echo "Committing in $sub_path"
        git -C "$sub_path" commit -m "$message" || echo "Warning: commit in $sub_path may have failed" >&2
    done < <(git -C "$repo_path" submodule status --recursive 2>/dev/null || true)
fi

echo "=== Committing in $repo_path ==="
git -C "$repo_path" commit -m "$message"
