#!/usr/bin/env bats
# Tests for install script permission patterns — TDD Cycle 2 RED
#
# Each test simulates a key permission command in a temp directory and
# verifies the resulting filesystem state.  These are the patterns that
# the six install scripts must use after the Cycle 2 fixes.
#
# RED because: the install scripts currently use g-w+r instead of g=rX,
# lack setgid+ACL, and install.sh:97 has the chown $USER:$USER antipattern.

setup() {
    TEST_ROOT="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

# Create a directory with setgid, group 2523, and default ACL — the
# pattern that install scripts should use after being fixed.
function create_tier1_source_dir() {
    local dir="$1"
    mkdir -p "$dir"
    chgrp 2523 "$dir"
    chmod 2750 "$dir"
    setfacl -d -m "g:2523:rx" "$dir" 2>/dev/null || true
}

@test "setgid leading digit is 2 after chmod 2750" {
    create_tier1_source_dir "$TEST_ROOT/source"
    mode=$(stat -c "%a" "$TEST_ROOT/source")
    [ "${mode:0:1}" = "2" ]
}

@test "new subdirectory inherits setgid from parent" {
    create_tier1_source_dir "$TEST_ROOT/source"
    mkdir "$TEST_ROOT/source/sub"
    mode=$(stat -c "%a" "$TEST_ROOT/source/sub")
    [ "${mode:0:1}" = "2" ]
}

@test "new file inherits group 2523 from setgid parent" {
    create_tier1_source_dir "$TEST_ROOT/source"
    touch "$TEST_ROOT/source/file.txt"
    gid=$(stat -c "%g" "$TEST_ROOT/source/file.txt")
    [ "$gid" = "2523" ]
}

@test "chmod g=rX gives group read on files and r-x on dirs" {
    mkdir -p "$TEST_ROOT/repo/src"
    chgrp 2523 "$TEST_ROOT/repo"
    chgrp 2523 "$TEST_ROOT/repo/src"
    touch "$TEST_ROOT/repo/README.md"
    touch "$TEST_ROOT/repo/src/main.py"
    chgrp 2523 "$TEST_ROOT/repo/README.md" 2>/dev/null || true
    chgrp 2523 "$TEST_ROOT/repo/src/main.py" 2>/dev/null || true
    chmod -R g=rX "$TEST_ROOT/repo"
    file_mode=$(stat -c "%a" "$TEST_ROOT/repo/README.md")
    [ "${file_mode:1:1}" = "4" ]
    dir_mode=$(stat -c "%a" "$TEST_ROOT/repo/src")
    [ "${dir_mode:1:1}" = "5" ]
}

@test "default ACL survives chmod -R g=rX" {
    create_tier1_source_dir "$TEST_ROOT/source"
    chmod -R g=rX "$TEST_ROOT/source"
    getfacl "$TEST_ROOT/source" 2>/dev/null | grep -q "^default:"
}

@test "setgid survives chmod -R g=rX" {
    create_tier1_source_dir "$TEST_ROOT/source"
    chmod -R g=rX "$TEST_ROOT/source"
    mode=$(stat -c "%a" "$TEST_ROOT/source")
    [ "${mode:0:1}" = "2" ]
}

@test "antipattern chown USER:USER is absent from install.sh" {
    # The chown $USER:$USER pattern overrides a prior chgrp 2523.
    # install.sh line 97 currently has this bug.
    if grep -qF "\$USER:\$USER" /etc/Wywy-Website-Control/install.sh 2>/dev/null; then
        echo "FAIL: install.sh contains chown \$USER:\$USER antipattern"
        false
    fi
}

