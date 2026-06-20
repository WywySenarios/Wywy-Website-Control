# Stage 3: Refactor

## Before touching code

- List every duplication, unclear name, or structural wart in both test and production files.
- Confirm all tests are still passing (baseline).

## Refactor one change at a time

Run the full test suite after **every change**. Commit only clean, green states.

Priorities:

1. **Remove duplication** — in tests and production code.
2. **Improve names** — variable, function, test names that are now misleading.
3. **Simplify structure** — extract helpers, reduce nesting, flatten conditionals.
4. **Update test helpers** — add shared fixtures/factories discovered during Green.
   - When a test edit is needed, **load the `request-test-edit` skill** and fill out the template before making the change.

## Final check

- [ ] All tests pass.
- [ ] No dead code, debug logs, or commented-out blocks remain.
- [ ] The test still fails if you revert the production change (prove the test catches the bug).
- [ ] Run lint/typecheck: follow project conventions.

### STOP. Report findings to user with [template](./template.md). Wait for approval.
