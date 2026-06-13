---
name: tdd
description: |
  You MUST use this when implementing a new feature or fixing a bug that requires tests. You MUST make efforts to consider TDD during planning. Do NOT use for config or docs.
---

# Red-Green-Refactor (TDD)

## The cycle

1. **Red** — write a minimal failing test that proves the feature is missing or the bug exists.
2. **Green** — write the minimum code to make the test pass.
3. **Refactor** — clean up both production and test code while keeping all tests green.

Each stage must complete before the next begins. Never skip ahead. Never write production code before a test demands it.

## Stage details

- **Stage 1 (Red):** See [`red.md`](red.md) — write the failing test.
- **Stage 2 (Green):** See [`green.md`](green.md) — make it pass. **You MUST NEVER modify tests during GREEN without user approval.**
- **Stage 3 (Refactor):** See [`refactor.md`](refactor.md) — clean up.

---

## Multi-change features

For features requiring multiple production changes, run the full cycle once per change. Stack cycles:

```
Cycle 1: Red → Green → Refactor
Cycle 2: Red → Green → Refactor
...
```

Each cycle ends with a green test suite. Never carry failing tests across cycles. **ALWAYS** wait for user approval between stages and cycles.

## Running tests

All services use the control script:

```bash
/etc/Wywy-Website-Control/run.sh <service> test
```

| Service | Test framework |
|---|---|
| master-database | Python integration (pytest) + C valgrind unit tests |
| cache | Django pytest |
| website | Docker compose test |
| agentic | Django pytest |
| backup | N/A |

For details on test output, container inspection, and debugging test failures, load the `test` skill.
