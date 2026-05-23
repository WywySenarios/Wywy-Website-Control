---
name: test
description: Run tests, capture results, summarize pass/fail, and suggest fixes for any Wywy-Website service. Use when user mentions testing, fixing tests, running tests, debugging test failures, or verifying a service.
---

# Test a Wywy-Website Service

## Quick start

```bash
# Run all tests for a service
./run.sh master-database test
./run.sh cache test
```

## Services

| Service | Test type | Test command |
|---|---|---|
| master-database | Python integration (`test` container) + C valgrind unit tests (`unit-test` container) | `./run.sh master-database test` |
| cache | Python Django (`test` container) | `./run.sh cache test` |
| website | No tests configured | — |
| backup | No containers | — |

## Workflows

### 1. Run tests and capture output

Run `./run.sh <service> test`. This layers `docker-compose.dev.yml` + `docker-compose.test.yml`, brings up test containers, runs tests, then auto-teardowns.

### 2. Summarize results

After tests complete:

- Extract pass/fail counts from output
- List any test names that failed
- Note any errors, tracebacks, or valgrind leak summaries
- Reference `config/test_config.yml` for the schema under test

### 3. Suggest fixes

Analyze failure patterns:

- **Python integration tests** — inspect `apps/tests/` in the service repo (e.g. `/usr/local/Wywy-Website/Wywy-Website-Master-Database/apps/tests/`). Failures often stem from:
  - Schema mismatches with `config/test_config.yml`
  - API contract changes in `sql_receptionist` or `sync`
  - Missing/wrong env variables in `config/<service>/.env.dev`
- **C unit tests (valgrind)** — inspect `apps/unit_tests/` and `apps/sql-receptionist/`. Leaks or crashes indicate memory bugs in sql-receptionist.
- **Cache Django tests** — inspect `apps/sync/` in the cache repo. Likely failures: model changes, URL routing, DB schema drift.

## Inspecting test containers manually

Auto-teardown shuts down containers after tests. To debug a running test container:

```bash
# Before tests auto-complete:
docker compose -f <docker-compose.dev.yml> -f <docker-compose.test.yml> up test

# Or in a separate terminal (while tests run):
docker compose -f <docker-compose.dev.yml> -f <docker-compose.test.yml> ps
```

For valgrind unit tests specifically:

```bash
# Enter the unit-test container and run manually:
./enter.sh master-database test unittest
# Then inside the container:
make clean && make && valgrind --leak-check=yes --show-leak-kinds=definite ./app
```

## Test config

The config schema for tests is in `config/test_config.yml`. It defines the databases, tables, columns, pointer types, and tagging rules that test datasets are validated against.
