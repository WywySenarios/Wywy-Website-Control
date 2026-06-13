# Stage completion template

When a stage completes, declare it using this template:

```md
## [STAGE] — done

**Files changed:**
| File | Change |
|------|--------|
| `<path>` | `<line>` — (one-sentence description) |

**Test results:**
| Result | Count |
|--------|-------|
| Passed | N |
| Failed | N |
| Skipped | N |

**Notes:** (stage-specific details — what the test demands, what production changed, or what was refactored)
**Next:** (the following stage)
```

- `[STAGE]` is `RED`, `GREEN`, or `REFACTOR`.
- Include every file touched in the stage, not just production code.
- Test counts must be from the full service suite (`/etc/Wywy-Website-Control/run.sh <service> test`).
