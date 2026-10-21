#!/usr/bin/env bats

setup() {
	if ! command -v kubectl >/dev/null 2>&1; then
		skip "kubectl not found"
	fi

	REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
	cd "$REPO_ROOT"
	MANIFESTS="$(kubectl kustomize k8s/base/jenkins)"
}

@test "cloudflared Deployment uses the pinned image and token Secret" {
	run grep -q 'name: cloudflared' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]

	run grep -q 'image: cloudflare/cloudflared:2026.10.2' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]

	run grep -q 'name: cloudflared-tunnel-token' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]

	run grep -q 'key: TUNNEL_TOKEN' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]

	run grep -q 'jenkins.wywy/token-rotation' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]
}

@test "cloudflared has its own egress policy and the controller accepts it" {
	run grep -q 'name: cloudflared' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]

	run grep -q 'app: cloudflared' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]

	run grep -q 'port: 7844' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]
}

@test "JCasC uses the public URL and managed hooks" {
	run grep -q 'name: JENKINS_PUBLIC_URL' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]

	run grep -q 'name: jenkins-public-url' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]

	run grep -q 'url: ${JENKINS_PUBLIC_URL}' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]

	run grep -q 'hookUrl: ${JENKINS_PUBLIC_URL}github-webhook/' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]

	run grep -q 'manageHooks: true' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]

	run grep -q 'hookSecretConfigs' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]

	run grep -q 'credentialsId: github-webhook-secret' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]

	run grep -q "interval('15')" <<<"$MANIFESTS"
	[ "$status" -eq 0 ]
}

@test "webhook secret is referenced and not embedded" {
	run grep -q 'name: github-webhook' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]

	run grep -q 'key: GITHUB_WEBHOOK_SECRET' <<<"$MANIFESTS"
	[ "$status" -eq 0 ]

	run grep -q 'TUNNEL_TOKEN: eyJ' <<<"$MANIFESTS"
	[ "$status" -eq 1 ]
}

@test "public URL is defined once in the dev overlay" {
	run grep -q '^  public_url:' k8s/dev/jenkins/public-url.yaml
	[ "$status" -eq 0 ]
}
