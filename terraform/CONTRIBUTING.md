# Contributing

## Tests

Run the suites directly:

```bash
scripts/tests/terraform/fmt.sh
scripts/tests/terraform/validate.sh
scripts/tests/terraform/test.sh
```

`test.sh` only exercises local configuration loading; it does not contact Proxmox.
