---
title: API Conventions
# Macroscope supports many models: https://docs.macroscope.com/model-pricing#available-models
model: claude-opus-5-5
effort: medium
input: full_diff
include:
  - "src/api/**"
  - "src/routes/**"
exclude:
  - "src/api/**/*.test.ts"
  - "src/gen/**"
---

You review changes to the HTTP API surface for adherence to this team's conventions.
Only flag the rules below.

### New routes must be registered — 🔴 Must fix

**What to flag:** a new route handler added under `src/api/` or `src/routes/` that is
not wired into the central router in `src/routes/index.ts`.

**Don't flag:** edits to existing handlers, or internal helpers that aren't routes.

### Handlers must return the `Result` type, not throw — 🟡 Should fix

**What to flag:** a route handler that `throw`s for an expected error path instead of
returning the project's `Result`/`ApiError` envelope.

**Don't flag:** truly unexpected errors (assertions, invariant violations). Throwing
there is fine.

### Breaking response-shape changes need a version bump — 🔴 Must fix

**What to flag:** a removed or renamed field, or a changed type, on an existing
response model under `src/api/**` without a corresponding bump in `API_VERSION` or a
new versioned route.

**Don't flag:** additive changes such as new optional fields.

## Output

For each finding, post an inline review comment on the exact offending line, with the
severity emoji and a one-sentence explanation of the problem and the fix. Then post one
top-level PR comment listing each finding on a single line. If nothing here applies,
post a single top-level comment "All clear." and add no inline comments. Never invent
findings to fill space.
