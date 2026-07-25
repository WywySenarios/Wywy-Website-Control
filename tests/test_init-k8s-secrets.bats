#!/usr/bin/env bats
# Tests for scripts/init-k8s-secrets.sh
#
# Seam: WYWY_CONTROL_DIR env var redirects the script to a fixture tree.
# Seam: INIT_K8S_SECRETS_SKIP_PRIVILEGE_CHECK=1 bypasses EUID/SUDO_USER
#       checks so functional tests can run without root.
#
# Mock strategy: PATH is prepended with a mock dir. Mocks log invocations
# to a file for verification.

# ---- helpers ---------------------------------------------------------------

# Create mock directory with usable stubs.
# Sets MOCK_DIR and MOCK_LOG for the test.
setup_mocks() {
    export MOCK_DIR="$TEST_DIR/mocks"
    export MOCK_LOG="$TEST_DIR/mock.log"
    mkdir -p "$MOCK_DIR"

    # mock sops — strips .sops extension, outputs underlying plaintext if it
    # exists, else a canned string on stdout.
    cat > "$MOCK_DIR/sops" <<'EOF'
#!/bin/bash
echo "sops:$*" >> "$MOCK_LOG"
for arg; do true; done  # cheap "last arg"
src="$arg"
if [[ "$*" == *--decrypt* ]]; then
    plain="${src%.sops}"
    if [[ -f "$plain" ]]; then
        cat "$plain"
    else
        echo "decrypted:$(basename "$src")"
    fi
fi
EOF

    # mock kubectl — just log and succeed/return appropriately
    cat > "$MOCK_DIR/kubectl" <<'EOF'
#!/bin/bash
echo "kubectl:$*" >> "$MOCK_LOG"
# For get secret: return failure so the script attempts create
if [[ "$1" == "get" && "$2" == "secret" && "$3" != "secret" ]]; then
    exit 1
fi
# For create secret generic: output minimal valid YAML
if [[ "$1" == "create" && "$2" == "secret" && "$3" == "generic" ]]; then
    cat <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: placeholder
  namespace: default
YAML
    exit 0
fi
# For apply -f -: read stdin and return success
if [[ "$1" == "apply" ]]; then
    cat > /dev/null
    exit 0
fi
EOF

    # mock runuser — strip -u <user> -- prefix, exec the remainder
    cat > "$MOCK_DIR/runuser" <<'EOF'
#!/bin/bash
echo "runuser:$*" >> "$MOCK_LOG"
if [[ "$1" == "-u" ]]; then
    runuser_user="$2"
    shift 2
    [[ "$1" == "--" ]] && shift
    exec "$@"
fi
EOF

    # mock sleep — return immediately (no delay)
    cat > "$MOCK_DIR/sleep" <<'EOF'
#!/bin/bash
echo "sleep:$*" >> "$MOCK_LOG"
exit 0
EOF

    chmod +x "$MOCK_DIR"/*
    export PATH="$MOCK_DIR:$PATH"
}

# Install fixture secrets under the given control dir.
#   Usage: install_fixtures <control_dir>
install_fixtures() {
    local dir="$1"
    mkdir -p "$dir/secrets/backup"
    cp /etc/Wywy-Website-Control/tests/fixtures/init-k8s-secrets/secrets/*.sops \
        "$dir/secrets/" 2>/dev/null || true
    cp /etc/Wywy-Website-Control/tests/fixtures/init-k8s-secrets/secrets/backup/* \
        "$dir/secrets/backup/" 2>/dev/null || true
}

setup() {
    TEST_DIR="$(mktemp -d)"
    SCRIPT="/etc/Wywy-Website-Control/scripts/init-k8s-secrets.sh"
    setup_mocks
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ---- guard tests (run as non-root, no bypass) -----------------------------

@test "GUARD: no sudo — exits 1 with sudo message" {
    run env -u INIT_K8S_SECRETS_SKIP_PRIVILEGE_CHECK \
        PATH="$MOCK_DIR:$PATH" \
        bash "$SCRIPT"
    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"sudo"* ]]
}

@test "GUARD: no SUDO_USER — exits 1 with error message" {
    if ! command -v fakeroot &>/dev/null; then
        skip "fakeroot not available — can't fake EUID=0"
    fi
    run fakeroot env -u SUDO_USER \
        INIT_K8S_SECRETS_SKIP_PRIVILEGE_CHECK="" \
        PATH="$MOCK_DIR:$PATH" \
        MOCK_LOG="$MOCK_LOG" \
        bash "$SCRIPT"
    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"SUDO_USER"* ]]
}

# ---- functional tests (with test seams) -----------------------------------

@test "all secrets present — creates all three K8s secrets" {
    local ctrl="$TEST_DIR/ctrl"
    install_fixtures "$ctrl"

    WYWY_CONTROL_DIR="$ctrl" \
    INIT_K8S_SECRETS_SKIP_PRIVILEGE_CHECK=1 \
    SUDO_USER=testuser \
    run bash "$SCRIPT"

    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Creating new secret"* ]]
    [[ "$output" == *"master-db-admin"* ]]
    [[ "$output" == *"github-runner-pat"* ]]
    [[ "$output" == *"backup-ssh-key"* ]]
}

@test "missing source file — warns but continues with others" {
    local ctrl="$TEST_DIR/ctrl"
    install_fixtures "$ctrl"
    rm -f "$ctrl/secrets/admin.txt.sops"

    WYWY_CONTROL_DIR="$ctrl" \
    INIT_K8S_SECRETS_SKIP_PRIVILEGE_CHECK=1 \
    SUDO_USER=testuser \
    run bash "$SCRIPT"

    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"missing"* ]] || [[ "$output" == *"failed"* ]]
    [[ "$output" == *"github-runner-pat"* ]]
    [[ "$output" == *"backup-ssh-key"* ]]
    [[ "$output" != *"master-db-admin"* ]]
}

@test "all source files missing — exits 0 with 'Nothing to do'" {
    local ctrl="$TEST_DIR/ctrl"
    mkdir -p "$ctrl/secrets"  # empty secrets dir

    WYWY_CONTROL_DIR="$ctrl" \
    INIT_K8S_SECRETS_SKIP_PRIVILEGE_CHECK=1 \
    SUDO_USER=testuser \
    run bash "$SCRIPT"

    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nothing to do"* ]]
}

@test "SOPS decryption fails — warns but continues" {
    local ctrl="$TEST_DIR/ctrl"
    install_fixtures "$ctrl"
    # Replace sops mock with one that fails
    cat > "$MOCK_DIR/sops" <<'EOF'
#!/bin/bash
echo "sops:$*" >> "$MOCK_LOG"
exit 1
EOF
    chmod +x "$MOCK_DIR/sops"

    WYWY_CONTROL_DIR="$ctrl" \
    INIT_K8S_SECRETS_SKIP_PRIVILEGE_CHECK=1 \
    SUDO_USER=testuser \
    run bash "$SCRIPT"

    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"failed"* ]] || [[ "$output" == *"missing"* ]]
}

@test "warning banner is displayed before countdown" {
    local ctrl="$TEST_DIR/ctrl"
    install_fixtures "$ctrl"

    WYWY_CONTROL_DIR="$ctrl" \
    INIT_K8S_SECRETS_SKIP_PRIVILEGE_CHECK=1 \
    SUDO_USER=testuser \
    run bash "$SCRIPT"

    echo "status:  $status"
    echo "output:  $output"
    [[ "$output" == *"WARNING"* ]]
    [[ "$output" == *"master-db-admin"* ]]
}

@test "countdown seconds are displayed" {
    local ctrl="$TEST_DIR/ctrl"
    install_fixtures "$ctrl"

    WYWY_CONTROL_DIR="$ctrl" \
    INIT_K8S_SECRETS_SKIP_PRIVILEGE_CHECK=1 \
    SUDO_USER=testuser \
    run bash "$SCRIPT"

    echo "status:  $status"
    echo "output:  $output"
    [[ "$output" == *"5..."* ]]
    [[ "$output" == *"1..."* ]]
}

@test "kubectl is called for each secret" {
    local ctrl="$TEST_DIR/ctrl"
    install_fixtures "$ctrl"

    WYWY_CONTROL_DIR="$ctrl" \
    INIT_K8S_SECRETS_SKIP_PRIVILEGE_CHECK=1 \
    SUDO_USER=testuser \
    run bash "$SCRIPT"

    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 0 ]

    echo "=== MOCK_LOG ==="
    cat "$MOCK_LOG"
    grep -q "kubectl:create secret generic" "$MOCK_LOG"
}

@test "sops --decrypt is called on SOPS files" {
    local ctrl="$TEST_DIR/ctrl"
    install_fixtures "$ctrl"

    WYWY_CONTROL_DIR="$ctrl" \
    INIT_K8S_SECRETS_SKIP_PRIVILEGE_CHECK=1 \
    SUDO_USER=testuser \
    run bash "$SCRIPT"

    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 0 ]

    echo "=== MOCK_LOG ==="
    cat "$MOCK_LOG"
    grep -q "sops:--decrypt" "$MOCK_LOG"
}

@test "runuser is invoked with SUDO_USER when privilege check active" {
    if ! command -v fakeroot &>/dev/null; then
        skip "fakeroot not available"
    fi
    local ctrl="$TEST_DIR/ctrl"
    install_fixtures "$ctrl"

    run fakeroot env SUDO_USER=testuser \
        INIT_K8S_SECRETS_SKIP_PRIVILEGE_CHECK="" \
        WYWY_CONTROL_DIR="$ctrl" \
        PATH="$MOCK_DIR:$PATH" \
        MOCK_LOG="$MOCK_LOG" \
        bash "$SCRIPT"

    echo "status:  $status"
    echo "output:  $output"
    [ "$status" -eq 0 ]

    echo "=== MOCK_LOG ==="
    cat "$MOCK_LOG"
    grep -q "runuser:-u testuser" "$MOCK_LOG"
}
