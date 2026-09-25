# Macroscope templates

Curated check run agents Macroscope recommends as starting points. The skill offers
one when a repo signal fits and no discovered rule or existing agent already covers
it. Accepted templates are copied unchanged.

| File | What it checks | `conclusion` | Notes |
|------|----------------|--------------|-------|
| `ticket-requirements.md` | The PR implements its linked Jira or Linear tickets | `neutral` | Needs the issue-tracker integration connected |
| `language-idioms.md` | Go and TypeScript idioms: error wrapping, naming, shared utilities | `neutral` | |
| `architecture-standards.md` | Service boundaries, dependency direction, public-API compatibility | `neutral` | Runs per code object |
| `security-review.md` | Hardcoded secrets, input validation, unsafe deserialization, SSRF | `failure` | Blocking |
| `accessibility.md` | Reachable controls, alt text, labeled inputs in UI changes | `neutral` | |
| `guardrails.md` | Stray debug output, untracked TODO/FIXME, dead code | `failure` | Blocking; low reasoning and effort |

Each template lists `modify_pr` in `tools` so findings post as inline comments.
