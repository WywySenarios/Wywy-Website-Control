# Stage 2: Green — Make it pass

## CRITICAL: Test modification during GREEN

**You MUST NEVER modify tests during the GREEN stage without explicit user approval.** The test is the specification. The test was written to describe the missing feature or bug — if the test does not pass, the production code is wrong, not the test. Request tests sparingly, if at all.

If you need to modify any test, STOP. **Load the `request-test-edit` skill and fill out the request template.**

## Write the minimum code

- Write **only** the code needed to turn the test green. No more.
- Follow existing patterns in the module. Do not refactor yet.
- If you hit a design question, choose the simplest correct answer and note it for Refactor.
- If the minimum code is ugly or duplicated, that is fine. Green comes first.

## Run the test — confirm it passes

```bash
/etc/Wywy-Website-Control/run.sh <service> test
```

- The new test must pass. If it does not, fix the production code until it does.
- Run the **full test suite** for the service, not just the new test. You must not break anything.
- If other tests break, undo and find a narrower fix.

---

### STOP. Report findings to user with [template](./template.md). Wait for approval.
