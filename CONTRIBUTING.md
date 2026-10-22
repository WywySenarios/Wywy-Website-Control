# Contributing

## Layout

| Path       | Contents                                                                   |
| ---------- | -------------------------------------------------------------------------- |
| `ansible/` | Playbooks and dev/prod inventories that create VMs and configure services. |
| `k8s/`     | Kustomize manifests for the cluster (`base/` and `dev/`).                  |
| `docker/`  | Jenkins and GitHub Actions runner images.                                  |
| `scripts/` | Host bootstrap, installation, and test entrypoints.                        |
| `config/`  | Universal and per-service environment files, plus `config.yml`.            |
| `secrets/` | sops-encrypted secrets (`dev/`, `shared/`).                                |
| `tests/`   | Deployment tests.                                                          |

## Testing

Testing is in a really ugly spot right now!

Remember to run `pre-commit install` for pre-commit checks.
