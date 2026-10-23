#!/bin/bash
#
# hosts-lookup.sh — print the address of a name in a sops hosts-format file.
#
# Usage:
#   scripts/lib/hosts-lookup.sh <path> <name>
#
# The file is a plain path argument: this tool knows nothing about where the
# repo keeps its secrets, so the caller decides which file to read.
#
# A hosts-format line is "<address> <name> [<alias>...]": field 1 is the
# address, field 2 is the canonical name, and every later field is an alias of
# the same host. All name fields are searched, so an alias resolves exactly
# like a canonical name.
#
# Success prints the address on stdout and exits 0. Failure exits 1 with the
# reason on stderr and nothing on stdout, so no caller can mistake a
# diagnostic for an address:
#
#   name absent      -> "no entry for '<name>' in <path>"
#   name on 2+ lines -> "ambiguous", listing every claiming line and address
#
# A file sops cannot read — absent, unreadable, undecryptable, wrong key —
# fails ahead of any lookup, with sops's own message and exit code.
#
# Ambiguity is an error rather than a first-match. Two lines claiming one name
# means the file disagrees with itself about which machine holds that name;
# silently taking the first match would address the wrong host, and that would
# surface much later as an inexplicable connection rather than here as a file
# problem. A name repeated within a single line is not ambiguous — same line,
# same address.
#
# Requires: sops and the operator age key, by convention. There is
# deliberately no SCRIPT_DIR resolution: this script reads no sibling file.
set -euo pipefail

function usage() {
	echo "Usage: scripts/lib/hosts-lookup.sh <path> <name>" >&2
	exit 1
}

[[ $# -eq 2 ]] || usage

hosts_file="$1"
host_name="$2"

# Everything the file can be wrong about — absent, unreadable, bad ciphertext,
# wrong key — is sops's to report, and it reports it more precisely than this
# script could. Let its message and exit code through; set -e stops here.
plain="$(sops -d --output-type binary "$hosts_file")"

# Field 1 must look like an address, so a comment line's '#' is never read as
# one. `next` emits at most one match per line, so a name repeated on a line
# cannot masquerade as two hosts.
matches="$(awk -v n="$host_name" '$1 ~ /^[0-9.]+$/ { for (i = 2; i <= NF; i++) if ($i == n) { print NR ":" $1; next } }' <<<"$plain")"

if [[ -z "$matches" ]]; then
	echo "hosts-lookup.sh: no entry for '$host_name' in $hosts_file" >&2
	exit 1
fi

mapfile -t found <<<"$matches"
if [[ "${#found[@]}" -gt 1 ]]; then
	echo "hosts-lookup.sh: '$host_name' is ambiguous in $hosts_file — ${#found[@]} lines claim it:" >&2
	# Split per entry: passing the two expansions to one printf would pair them
	# across arrays (line -> line) instead of within each entry.
	for entry in "${found[@]}"; do
		printf '  line %s -> %s\n' "${entry%%:*}" "${entry#*:}" >&2
	done
	exit 1
fi

printf '%s\n' "${found[0]#*:}"
