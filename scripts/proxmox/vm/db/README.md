# DB VM

Most scripts require you to specify the deployment target (`--dev` or `--prod`).

Remember to update `.env.network`

## Superuser Password

Store the password with sops at:

- `secrets/prod/postgres-password.sops` for prod
- `secrets/dev/postgres-password.sops` for dev

Update the password with the relevant script, which will escape characters.

Remember to avoid leaking secrets through `bash_history` on host or with `ssh`.

The helper escapes quoting — passwords may contain any characters.

## Update pg_hba.conf + ufw (post-provision)

pg_hba is not automatically updated when `.env.network` changes.

Apply (UPSERT) `.env.network` values to a running VM with the relevant script.

## Deployment Tests

Remember to run deployments with `test.sh deployment`.
The helper escapes quoting — passwords may contain any characters.
