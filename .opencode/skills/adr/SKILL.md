---
name: adr
description: Create or supersede Architecture Decision Records (ADRs). Use when the user asks to record a decision, create an ADR, document an architecture decision, or supersede an existing ADR. ADRs are stored in /var/lib/Wywy-Website/adr/.
---

# Architecture Decision Records (ADRs)

ADRs capture significant architectural decisions with context and consequences.
They live at `/var/lib/Wywy-Website/adr/`.

## Template

Every ADR follows this structure:

```markdown
# [Title]

- **Status:** [proposed | accepted | deprecated | superseded]
- **Date:** YYYY-MM-DD

## Context

[What is the issue that's motivating this decision? Describe the forces at
play — technical, business, team constraints.]

## Decision

[What is the change that we're proposing and/or doing? Be specific. Include
enough detail that someone reading this a year from now understands what
was chosen and why.]

## Consequences

[What becomes easier or more difficult to do because of this change? Include
both positive and negative consequences.]
```

## Status values

| Status | Meaning |
|---|---|
| `proposed` | Under consideration, not yet agreed upon |
| `accepted` | Agreed upon and active — this decision is in effect |
| `deprecated` | No longer relevant, but not replaced by a specific new ADR |
| `superseded` | Replaced by a newer ADR. Must include a forward reference: "Superseded by ADR-NNNN" |

## Creating a new ADR

### Step 1: Determine the next number

Scan `/var/lib/Wywy-Website/adr/` for existing files matching `NNNN-*.md`.
Find the highest number and increment by 1.  If no ADRs exist, start at
`0001`.  Use 4-digit zero-padded numbers (e.g., `0001`, `0023`, `0142`).

### Step 2: Generate the filename

Use the format: `NNNN-lowercase-title-with-dashes.md`

Example: `0003-use-sql-receptionist-for-data-access.md`

### Step 3: Write the ADR

Apply the template above.  Set status to `proposed` by default — do not
assume acceptance until the user confirms.

### Step 4: Notify the user

After writing, report:
- The ADR number and filename
- The full path (`/var/lib/Wywy-Website/adr/NNNN-title.md`)
- The status

Ask the user whether to change the status to `accepted` or leave it as
`proposed`.

## Superseding an existing ADR

When a new decision replaces an older one:

### Step 1: Create the new ADR

Follow "Creating a new ADR" above.  The new ADR gets the next available
number.

### Step 2: Add a "Supersedes" reference in the new ADR

After the status line in the new ADR, add:

```markdown
Supersedes: [ADR-NNNN](./NNNN-title.md)
```

### Step 3: Update the old ADR

1. Change the old ADR's status from `accepted` to `superseded`.
2. Add after the status line:

```markdown
Superseded by: [ADR-NNNN](./NNNN-title.md)
```

3. Do NOT delete or rename the old ADR — it remains as a historical
   record.

### Step 4: Report

List both ADRs and their new states:
- Old: `ADR-NNNN` → status changed to `superseded`
- New: `ADR-NNNN` → status `accepted`, supersedes ADR-NNNN
