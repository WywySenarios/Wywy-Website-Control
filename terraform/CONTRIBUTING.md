# Contributing

## Tests

Run the suites directly:

```bash
scripts/tests/terraform/fmt.sh
scripts/tests/terraform/validate.sh
scripts/tests/terraform/test.sh
```

`test.sh` uses a mocked provider, so it does not contact a router.
