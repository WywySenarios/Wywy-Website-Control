#!/usr/bin/env bats
# Tests for verify-filesystem-convention.sh — TDD Cycle 1 RED
#
# Seam: WYWY_FS_ROOT env var redirects all path checks to a temp directory
# so tests can simulate a compliant or non-compliant filesystem tree.
#
# RED because: verify-filesystem-convention.sh does not exist yet.
# Every test will fail because the script file is missing.

# ---- helpers ---------------------------------------------------------------

# Create a minimal compliant filesystem tree under $TEST_ROOT.
# Uses the permission tiers defined in the filesystem-permissions-compliance plan:
#   Tier 1 — Source (2750, debian:2523, setgid, default ACL g:2523:rx)
#   Tier 2 — Workspace (2770, root:2523, setgid, default ACL g:2523:rwx)
#   Tier 3 — Service data (700, container UID)
#   Tier 4 — Service logs (750 or 770, container UID:2523)
#   Tier 5 — Secrets (000, root:root)
create_compliant_fs() {
    local root="$1"

    # --- Tier 1: Source directories ---
    mkdir -p "$root/usr/local/Wywy-Website/Wywy-Codes/src"
    mkdir -p "$root/etc/Wywy-Website-Control/config"

    for tier1_dir in \
        "$root/usr/local/Wywy-Website" \
        "$root/etc/Wywy-Website-Control"; do
        chgrp 2523 "$tier1_dir"
        chmod 2750 "$tier1_dir"
        setfacl -d -m "g:2523:rx" "$tier1_dir" 2>/dev/null || true
    done

    # A single readme file inside source (Tier 1 content, compliant perms)
    echo "hello" > "$root/usr/local/Wywy-Website/Wywy-Codes/README.md"
    chgrp 2523 "$root/usr/local/Wywy-Website/Wywy-Codes/README.md" 2>/dev/null || true
    chmod 640 "$root/usr/local/Wywy-Website/Wywy-Codes/README.md"

    # --- Tier 2: Workspace ---
    mkdir -p "$root/var/workspace/Wywy-Website"
    chgrp 2523 "$root/var/workspace/Wywy-Website"
    chmod 2770 "$root/var/workspace/Wywy-Website"
    setfacl -d -m "g:2523:rwx" "$root/var/workspace/Wywy-Website" 2>/dev/null || true

    # --- Tier 3: Service data (owner-only) ---
    mkdir -p "$root/var/lib/Wywy-Website/orchestrator"
    chown 1000:1000 "$root/var/lib/Wywy-Website/orchestrator" 2>/dev/null || true
    chmod 700 "$root/var/lib/Wywy-Website/orchestrator"

    # --- Tier 4: Service logs ---
    mkdir -p "$root/var/log/Wywy-Website/agentic"
    mkdir -p "$root/var/log/Wywy-Website/website"
    chgrp 2523 "$root/var/log/Wywy-Website/agentic"
    chmod 770 "$root/var/log/Wywy-Website/agentic"
    chgrp 2523 "$root/var/log/Wywy-Website/website"
    chmod 750 "$root/var/log/Wywy-Website/website"

    # --- Tier 5: Secrets (locked down) ---
    mkdir -p "$root/etc/Wywy-Website-Control/secrets"
    chown root:root "$root/etc/Wywy-Website-Control/secrets" 2>/dev/null || true
    chmod 000 "$root/etc/Wywy-Website-Control/secrets"
}

# ---- per-test setup / teardown ---------------------------------------------

setup() {
    TEST_ROOT="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

# ---- tests -----------------------------------------------------------------

@test "all compliant checks pass — exit 0" {
    create_compliant_fs "$TEST_ROOT"

    run env WYWY_FS_ROOT="$TEST_ROOT" \
        /etc/Wywy-Website-Control/scripts/verify-filesystem-convention.sh

    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 0 ]
}

@test "wrong group on Tier 1 dir — exit 1 with 'group='" {
    create_compliant_fs "$TEST_ROOT"
    # sabotage: change group of /usr/local/Wywy-Website to something else
    chgrp 1000 "$TEST_ROOT/usr/local/Wywy-Website" 2>/dev/null || true

    run env WYWY_FS_ROOT="$TEST_ROOT" \
        /etc/Wywy-Website-Control/scripts/verify-filesystem-convention.sh

    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"group="* ]]
}

@test "missing setgid on Tier 1 dir — exit 1 with 'mode='" {
    create_compliant_fs "$TEST_ROOT"
    # strip the setgid bit
    chmod g-s "$TEST_ROOT/usr/local/Wywy-Website"

    run env WYWY_FS_ROOT="$TEST_ROOT" \
        /etc/Wywy-Website-Control/scripts/verify-filesystem-convention.sh

    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"mode="* ]]
}

@test "missing default ACL on Tier 1 dir — exit 1 with 'ACL'" {
    create_compliant_fs "$TEST_ROOT"
    # remove all ACLs from the directory
    setfacl -b "$TEST_ROOT/usr/local/Wywy-Website" 2>/dev/null || true

    run env WYWY_FS_ROOT="$TEST_ROOT" \
        /etc/Wywy-Website-Control/scripts/verify-filesystem-convention.sh

    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ACL"* ]]
}

@test "other permissions leak in source tree — exit 1 with 'leak'" {
    create_compliant_fs "$TEST_ROOT"
    # create a world-readable file inside the source tree
    echo "leaked" > "$TEST_ROOT/usr/local/Wywy-Website/Wywy-Codes/src/leaked.txt"
    chmod 644 "$TEST_ROOT/usr/local/Wywy-Website/Wywy-Codes/src/leaked.txt"

    run env WYWY_FS_ROOT="$TEST_ROOT" \
        /etc/Wywy-Website-Control/scripts/verify-filesystem-convention.sh

    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"leak"* ]]
}

@test "secrets directory not mode 000 — exit 1" {
    create_compliant_fs "$TEST_ROOT"
    # open up secrets dir permissions
    chmod 700 "$TEST_ROOT/etc/Wywy-Website-Control/secrets"

    run env WYWY_FS_ROOT="$TEST_ROOT" \
        /etc/Wywy-Website-Control/scripts/verify-filesystem-convention.sh

    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 1 ]
}

@test "service data directory not mode 700 — exit 1" {
    create_compliant_fs "$TEST_ROOT"
    # relax data dir permissions
    chmod 770 "$TEST_ROOT/var/lib/Wywy-Website/orchestrator"

    run env WYWY_FS_ROOT="$TEST_ROOT" \
        /etc/Wywy-Website-Control/scripts/verify-filesystem-convention.sh

    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 1 ]
}

@test "recursive group check catches deep wrong-group file" {
    create_compliant_fs "$TEST_ROOT"
    # set wrong group on a file deep in the source tree
    chgrp 1000 "$TEST_ROOT/usr/local/Wywy-Website/Wywy-Codes/README.md" 2>/dev/null || true

    run env WYWY_FS_ROOT="$TEST_ROOT" \
        /etc/Wywy-Website-Control/scripts/verify-filesystem-convention.sh

    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"group="* ]]
}
