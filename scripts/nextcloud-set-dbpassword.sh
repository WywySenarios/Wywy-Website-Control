#!/bin/bash
# shell history safe nextcloud db password update
set -euo pipefail

namespace="${1:-nextcloud}"
secret="${2:-nextcloud-db-password}"

for value in "$namespace" "$secret"; do
	[[ "$value" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] || {
		echo "invalid Kubernetes name: $value" >&2
		exit 1
	}
done

kubectl -n "$namespace" get secret "$secret" -o jsonpath='{.data.password}' |
	base64 -d |
	python3 -c '
import json
import sys

password = sys.stdin.read()
if not password:
    raise SystemExit("empty password in secret")
print(json.dumps({"system": {"dbpassword": password}}))
' |
	kubectl -n "$namespace" exec -i deploy/nextcloud -- php /var/www/html/occ config:import

echo "Updated Nextcloud dbpassword from secret ${namespace}/${secret}. Restart the deployment to load the new environment."
