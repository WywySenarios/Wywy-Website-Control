# Wywy Control: Ansible

Run a playbook with the command below. Replace `path/to/playbook.yaml` with the name of the playbook you intend to run.

```bash
uv run --directory ansible ansible-playbook path/to/playbook.yaml # if you are under repo root cwd

uv run ansible-playbook path/to/playbook.yaml # if you are under ansible/ cwd
```
