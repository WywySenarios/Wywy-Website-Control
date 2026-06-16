#!/bin/bash
set -euo pipefail

# verify-filesystem-convention.sh
#
# Checks filesystem directories and files against the 5-tier permission
# convention defined in filesystem-permissions-compliance.md.
#
# Seams: WYWY_FS_ROOT redirects all path checks to a temp directory (default /).
#        WYWY_FS_GID overrides the expected group ID (default 2523).

WYWY_FS_ROOT="${WYWY_FS_ROOT:-/}"
WYWY_FS_GID="${WYWY_FS_GID:-2523}"
WYWY_FS_TIER3_OWNER="${WYWY_FS_TIER3_OWNER:-}"

# accumulated failures and error messages
FAILED=0
ERRORS=""

# ---- helpers ---------------------------------------------------------------

# Prepend the test root to a relative path.
function prefix() {
    echo "${WYWY_FS_ROOT}${1}"
}

# Check a single directory against the Tier-1/2 convention:
# correct group, setgid bit, and default ACL.
function check_tier12_dir() {
    local dir="$1"   # the logical path (e.g. /usr/local/Wywy-Website)
    local path
    path=$(prefix "$dir")
    [[ -d "$path" ]] || return 0

    local gid mode
    gid=$(stat -c "%g" "$path" 2>/dev/null || echo "?")
    if [[ "$gid" != "$WYWY_FS_GID" ]]; then
        ERRORS+="group=$gid $dir"$'\n'
        FAILED=1
    fi

    mode=$(stat -c "%a" "$path" 2>/dev/null || echo "0000")
    if [[ "${mode:0:1}" != "2" ]]; then
        ERRORS+="mode=$mode $dir (missing setgid)"$'\n'
        FAILED=1
    fi

    if ! getfacl "$path" 2>/dev/null | grep -q "^default:"; then
        ERRORS+="missing default ACL on $dir"$'\n'
        FAILED=1
    fi
}

# Check a single directory whose mode must match an exact value.
function check_exact_mode() {
    local dir="$1"
    local expected="$2"
    local path
    path=$(prefix "$dir")
    [[ -d "$path" ]] || return 0

    local mode
    mode=$(stat -c "%a" "$path" 2>/dev/null || echo "0000")
    if [[ "$mode" != "$expected" ]]; then
        ERRORS+="mode=$mode $dir (expected $expected)"$'\n'
        FAILED=1
    fi
}

# Check a directory whose other-permission bits must be 0.
function check_no_world_access() {
    local dir="$1"
    local path
    path=$(prefix "$dir")
    [[ -d "$path" ]] || return 0

    local mode other_perm
    mode=$(stat -c "%a" "$path" 2>/dev/null || echo "0000")
    other_perm="${mode: -1}"
    if [[ "$other_perm" != "0" ]]; then
        ERRORS+="leak: $dir has other=$other_perm"$'\n'
        FAILED=1
    fi
}

# Check a Tier-3 directory owner matches the expected container UID.
# Skipped when WYWY_FS_TIER3_OWNER is unset or empty.
function check_tier3_owner() {
    local dir="$1"
    [[ -n "$WYWY_FS_TIER3_OWNER" ]] || return 0
    local path
    path=$(prefix "$dir")
    [[ -d "$path" ]] || return 0

    local uid
    uid=$(stat -c "%u" "$path" 2>/dev/null || echo "?")
    if [[ "$uid" != "$WYWY_FS_TIER3_OWNER" ]]; then
        ERRORS+="owner=$uid $dir (expected $WYWY_FS_TIER3_OWNER)"$'\n'
        FAILED=1
    fi
}

# ---- Tier 1: Source directories (2750, setgid, default ACL) ----------------
for dir in "/usr/local/Wywy-Website" "/etc/Wywy-Website-Control"; do
    check_tier12_dir "$dir"
done

# ---- Tier 2: Workspace (2770, setgid, default ACL) -------------------------
for dir in "/var/workspace/Wywy-Website"; do
    check_tier12_dir "$dir"
done

# ---- Tier 3: Service data (700, owner-only) --------------------------------
for dir in "/var/lib/Wywy-Website/orchestrator"; do
    check_exact_mode "$dir" "700"
    check_tier3_owner "$dir"
done

# ---- Tier 4: Service logs (no world access) --------------------------------
for dir in "/var/log/Wywy-Website/agentic" "/var/log/Wywy-Website/website"; do
    check_no_world_access "$dir"
done

# ---- Tier 5: Secrets (000, functionally equivalent to inherited 2000) ------
for dir in "/etc/Wywy-Website-Control/secrets"; do
    path=$(prefix "$dir")
    [[ -d "$path" ]] || continue
    mode=$(stat -c "%a" "$path" 2>/dev/null || echo "0000")
    # accept 000 (fully locked) or 2000 (setgid inherited but no permission bits)
    if [[ "$mode" != "000" && "$mode" != "2000" ]]; then
        ERRORS+="mode=$mode $dir (expected 000)"$'\n'
        FAILED=1
    fi
done

# ---- Recursive checks: walk source trees for group and other leaks ---------
for root_dir in "/usr/local/Wywy-Website" "/etc/Wywy-Website-Control"; do
    path=$(prefix "$root_dir")
    [[ -d "$path" ]] || continue

    # walk files only — directories are checked above by tier
    while IFS= read -r -d "" entry; do
        entry_gid=$(stat -c "%g" "$entry" 2>/dev/null || echo "?")
        if [[ "$entry_gid" != "$WYWY_FS_GID" ]]; then
            ERRORS+="group=$entry_gid $entry"$'\n'
            FAILED=1
        fi

        entry_mode=$(stat -c "%a" "$entry" 2>/dev/null || echo "0000")
        other_perm="${entry_mode: -1}"
        if [[ "$other_perm" != "0" ]]; then
            ERRORS+="leak: $entry has other=$other_perm"$'\n'
            FAILED=1
        fi
    done < <(find "$path" -type f -mindepth 1 -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/.astro/*" -not -path "*/test-results/*" -not -path "*/screenshots/*" -print0 2>/dev/null || true)
done

# ---- Report ----------------------------------------------------------------
if [[ "$FAILED" -ne 0 ]]; then
    echo -n "$ERRORS"
    exit 1
fi
exit 0
