# Stage 1: Red — Write the failing test

## Before writing

1. Identify the **seam** — where in the call chain can the test exercise the real change?
2. Find the **existing test file** or the right place to add one. Mirror the production module structure.
3. Decide the **test scope**: unit (fastest), integration (service boundary), or e2e (external contract).

## Write the test

- Name it to describe the expected behaviour: `test_<what>_<when>_<then>`.
- Use existing test fixtures, factories, and helpers. Do not invent new machinery yet.
- The test must exercise the **exact code path** the production code will use.
- Assert on the **specific outcome**, not on implementation details.

## Resolve imports — create bare skeletons

Before running the test, make sure it does **not** fail because of a missing import or
unresolved module.  If the test imports a function, component, or module that does not
exist yet:

1. Create a **bare skeleton** file at the expected import path.
2. The skeleton MUST export the name the test imports, but its body should be empty or
   return a no-op — enough to make the import resolve, but not enough to satisfy the
   assertions.
3. If the skeleton requires a third-party package that is not yet installed, add it to
   `package.json` and run the package manager's install command before proceeding.
4. Kill any other environment blockers (missing `window.matchMedia`, missing globals,
   etc.) via setup files or mocks so the test fails on *behaviour*, not environment.

### Examples

| Test imports | Doesn't exist | Action |
|---|---|---|
| `import { cn } from "../../lib/utils"` | `src/lib/utils.ts` | Create `src/lib/utils.ts` with `export function cn() { return "" }` |
| `import { Button } from "./button"` | Button lacks `asChild` | Existing file, but skeleton already resolves — no action |
| `import { ThemeProvider } from "next-themes"` | Package not installed | Add to `package.json`, run `npm install` |
| `window.matchMedia` unavailable | jsdom environment | Add mock to `tests/unit/setup.ts` |

### Why

A test that fails with `Module not found` or `window.matchMedia is not a function` tells
you nothing about the feature.  A test that fails because `expect(theme).toBe("dark")`
returned `undefined` tells you exactly what behaviour is missing.

## Run the test — confirm it fails for the right reason

```bash
/etc/Wywy-Website-Control/run.sh <service> test
```

- The failure must match the **missing feature or bug**. A wrong failure = wrong test. Fix the test.
- If the test passes without new code, the feature already exists or the test is not testing the right thing. Investigate.

---

### STOP. Report findings to user with [template](./template.md). Wait for approval.

