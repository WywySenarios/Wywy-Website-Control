KUBERNETES_VERSION="1.36.2"
K8S_SCHEMA_COMMIT="f7d855e49c34b039c9ef2196444910275e31e09e"
CRD_SCHEMA_COMMIT="3eb90d47aba8d61919d4419dd38301536e32a94b"
K8S_SCHEMA_URL="https://raw.githubusercontent.com/yannh/kubernetes-json-schema/${K8S_SCHEMA_COMMIT}/{{.NormalizedKubernetesVersion}}-standalone{{.StrictSuffix}}/{{.ResourceKind}}{{.KindSuffix}}.json"
CRD_SCHEMA_URL="https://raw.githubusercontent.com/datreeio/CRDs-catalog/${CRD_SCHEMA_COMMIT}/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json"

RENDER_DIRS=(
	k8s/base/cloudflared
	k8s/base/image-updater
	k8s/base/jenkins
	k8s/base/nextcloud
	k8s/base/vaultwarden
	k8s/dev/infrastructure
	k8s/dev/metallb
	k8s/dev/immich/pvcs
)

k8s_render() {
	local dest=$1
	local dir name
	mkdir -p "$dest"
	for dir in "${RENDER_DIRS[@]}"; do
		name="${dir//\//_}"
		echo "==> kustomize build ${dir}" >&2
		kustomize build "$dir" >"$dest/$name.yaml"
	done
}

# Populates the global arrays RAW_PLAIN, RAW_SOPS, and RAW_LINT.
# Fails hard on any file under k8s/ that is neither a plain manifest nor a sops-encrypted manifest.
k8s_classify_raw() {
	local file dir render_dir rendered
	mapfile -t RAW < <(
		find k8s -type f \
			! -name 'kustomization.yaml' \
			! -name 'ksops-generator.yaml' \
			! -name 'values.yaml' \
			! -path 'k8s/dev/image-updater/patch-deployment.yaml' \
			! -path 'k8s/dev/image-updater/patch-configmap.yaml' \
			! -path 'k8s/base/jenkins/jenkins.yaml' |
			sort
	)

	RAW_PLAIN=()
	RAW_SOPS=()
	for file in "${RAW[@]}"; do
		case "$file" in
		*.sops.yaml | *.sops)
			RAW_SOPS+=("$file")
			;;
		*.yaml)
			RAW_PLAIN+=("$file")
			;;
		*)
			printf 'ERROR: unexpected file in k8s/: %s (expected *.yaml, *.sops.yaml, or *.sops)\n' "$file" >&2
			exit 1
			;;
		esac
	done

	# kube-linter runs on rendered objects plus the plain manifests that cannot be rendered.
	# Base manifests are covered by the rendered output
	# Dev overlays that need ksops are linted from raw source.
	RAW_LINT=()
	for file in "${RAW_PLAIN[@]}"; do
		dir="$(dirname "$file")"
		rendered=0
		for render_dir in "${RENDER_DIRS[@]}"; do
			if [[ "$dir" == "$render_dir" || "$dir" == "$render_dir"/* ]]; then
				rendered=1
				break
			fi
		done
		if [ "$rendered" -eq 0 ]; then
			RAW_LINT+=("$file")
		fi
	done
}

# Build the kubeconform arguments for a suite-specific cache directory.
k8s_kubeconform_args() {
	local cache_dir=$1
	mkdir -p "$cache_dir"
	KUBECONFORM_ARGS=(
		-kubernetes-version "$KUBERNETES_VERSION"
		-cache "$cache_dir"
		-schema-location "$K8S_SCHEMA_URL"
		-schema-location "$CRD_SCHEMA_URL"
	)
}
