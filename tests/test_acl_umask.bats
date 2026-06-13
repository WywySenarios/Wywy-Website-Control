#!/usr/bin/env bats
# Tests for ACL umask-proof behavior — TDD Cycle 3 RED
#
# Verifies that default ACLs on Tier-1/2 directories guarantee correct
# group permissions regardless of the creating process's umask.
#
# RED because: existing source trees lack default ACLs (setfacl -d not yet
# applied).  Without ACLs, umask 077 would block group access entirely.

setup() {
    TEST_ROOT="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

# Create a directory with default ACL granting group 2523 read+execute.
function create_acl_protected_dir() {
    local dir="$1"
    mkdir -p "$dir"
    setfacl -d -m "g:2523:rx" "$dir" 2>/dev/null || true
}

# ---- tests -----------------------------------------------------------------

@test "umask 022: new file is group-readable via ACL" {
    create_acl_protected_dir "$TEST_ROOT/acl"
    (umask 022; touch "$TEST_ROOT/acl/f")
    perms=$(stat -c '%A' "$TEST_ROOT/acl/f")
    [[ "${perms:4:1}" == "r" ]]
}

@test "umask 077: new file is group-readable via ACL" {
    create_acl_protected_dir "$TEST_ROOT/acl"
    (umask 077; touch "$TEST_ROOT/acl/f")
    perms=$(stat -c '%A' "$TEST_ROOT/acl/f")
    [[ "${perms:4:1}" == "r" ]]
}

@test "umask 027: new file is group-readable via ACL" {
    create_acl_protected_dir "$TEST_ROOT/acl"
    (umask 027; touch "$TEST_ROOT/acl/f")
    perms=$(stat -c '%A' "$TEST_ROOT/acl/f")
    [[ "${perms:4:1}" == "r" ]]
}

@test "umask 000: group permissions still controlled by ACL" {
    create_acl_protected_dir "$TEST_ROOT/acl"
    (umask 000; touch "$TEST_ROOT/acl/f")
    perms=$(stat -c '%A' "$TEST_ROOT/acl/f")
    # even with umask 000, group read comes from ACL
    [[ "${perms:4:1}" == "r" ]]
    # confirm ACL entry exists for the file
    getfacl "$TEST_ROOT/acl/f" 2>/dev/null | grep -qE "^group:(2523|Wywy-Website):"
}

@test "umask 077: new subdirectory is group-traversable" {
    create_acl_protected_dir "$TEST_ROOT/acl"
    (umask 077; mkdir "$TEST_ROOT/acl/sub")
    perms=$(stat -c '%A' "$TEST_ROOT/acl/sub")
    # group must have read AND execute (r-x)
    [[ "${perms:4:1}" == "r" ]]
    [[ "${perms:6:1}" == "x" ]]
}

@test "no ACL + umask 077: group access is blocked (control)" {
    mkdir -p "$TEST_ROOT/no-acl"
    (umask 077; touch "$TEST_ROOT/no-acl/f")
    perms=$(stat -c '%A' "$TEST_ROOT/no-acl/f")
    # group must have no permissions at all
    [[ "${perms:4:1}" == "-" ]]
    [[ "${perms:5:1}" == "-" ]]
    [[ "${perms:6:1}" == "-" ]]
}
