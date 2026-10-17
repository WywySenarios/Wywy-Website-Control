# Wywy Control: Ansible

Remember to pull dependencies:

```bash
uv sync
```

Run a playbook with the command below:

```bash
# if you cwd is repo root,
uv run --directory ansible wywy-ansible --dev|--prod path/to/playbook.yaml

# if your cwd is ansible/,
uv run wywy-ansible --dev|--prod path/to/playbook.yaml
```
