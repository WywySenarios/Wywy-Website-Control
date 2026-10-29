# Wywy Control: Ansible

To install Ansible:

```bash
# from the repository root
scripts/install/ansible.sh

# from ansible/
../scripts/install/ansible.sh
```

Run a playbook with the command below:

```bash
# if you cwd is repo root,
uv run --directory ansible wywy-ansible --dev|--prod path/to/playbook.yaml

# if your cwd is ansible/,
uv run wywy-ansible --dev|--prod path/to/playbook.yaml
```

## Tests

Run the Ansible checks from the repo root:

```bash
scripts/tests/ansible/pytest.sh
scripts/tests/ansible/lint.sh
scripts/tests/ansible/syntax.sh
scripts/tests/ansible/ruff.sh
```
