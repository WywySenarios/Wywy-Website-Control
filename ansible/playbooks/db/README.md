# Wywy DB Scripts

1. proxmox-template.yaml
2. proxmox-vm.yaml will create the virtual machine and stops right after cloud-init finishes.
3. db.yaml will install postgres
4. seed.yaml will create databases, roles, and extensions. It will also update the superuser password.
