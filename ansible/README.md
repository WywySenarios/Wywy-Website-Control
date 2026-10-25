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
