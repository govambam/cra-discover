# Check run agent file format

Source: https://docs.macroscope.com/check-run-agents and
https://docs.macroscope.com/model-pricing, synced 2026-09-25. Re-check the live docs
if anything here looks stale. An unknown `model` value makes the run conclude
`skipped` with no fallback, so the model list matters most.

Each agent is one `.md` file in `.macroscope/check-run-agents/` at the repo root
(subdirectories are walked). The filename is the default title. Agents run on every
PR alongside Macroscope's built-in **Correctness** and **Approvability** agents.
Macroscope reads agent files from the PR's own branch, so a new agent can be tried
on its own PR before it's merged; other PRs pick it up once it's on the default
branch. `approvability.md` and `ignore.md` are reserved and live in `.macroscope/`.

## Frontmatter

All fields are optional.

| Field | Default | Notes |
|-------|---------|-------|
| `title` | filename | max 60 chars, shown in the Checks tab |
| `model` | `claude-opus-4-6` | see the model list below |
| `effort` | `low` | `low`, `medium`, `high`. Anthropic models only. How deep the agent digs. |
| `reasoning` | `low` | **Ignored on every Anthropic model newer than Opus 4.5 and Sonnet 4.5**, which set thinking automatically. Only meaningful on OpenAI, xAI, and open-source models. Don't write it for Anthropic models. |
| `input` | `incremental` | `full_diff`, `incremental`, `code_object`, `pr_metadata`. See below. Always set it explicitly. |
| `tools` | `browse_code`, `git_tools`, `github_api_read_only`, `modify_pr` | Setting `tools` replaces the defaults. Extras need a connection: `sentry`, `slack`, `issue_tracking_tools`, `posthog`, `launchdarkly`, `bigquery`, `amplitude`, `gcp_cloud_logging`, `web_tools`, `image_gen`, `mcp`. |
| `include` / `exclude` | none | globs. `include` narrows first, `exclude` carves out. A pattern without `/` matches at any depth. An agent's `include` overrides `.macroscope/ignore.md`. |
| `conclusion` | `neutral` | `failure` lets the agent block merges. Requires `input: full_diff`. |
| `labels` / `authors` / `targets` | none | run only when the PR matches. `targets` accepts `only_default_branch`. |
| `requiredStatusCheck` | `false` | report `skipped` instead of not appearing when filters exclude the PR. For branch-protection required checks. |
| `waitsFor` / `requires` | none | check names or `["*"]`. `requires` also skips the agent if a prerequisite failed. 10 names total. |
| `waitsForTimeout` | `20` | minutes, 1 to 60 |
| `maxRuns` | none | runs per PR |
| `maxBudgetPerRun` / `maxBudgetPerPR` | none | USD, best effort. Not with `code_object`. Workspace default caps all agents at $100 per PR. |
| `showToolCalls` | `true` | log tool calls on the check run page |

## Input modes

| `input` | What the agent sees | Cost | Use for |
|---|---|---|---|
| `incremental` | only files changed since this agent's last completed review, each as its full diff against the merge base | lowest on later pushes | any per-file rule on an advisory agent. This is also how Correctness runs. |
| `full_diff` | the whole PR diff every run | low | rules that need PR-level context (a change here requires a change there), and any blocking agent |
| `pr_metadata` | title, author, labels, description, commit messages. No diff. | lowest | rules about the PR itself: ticket links, title format |
| `code_object` | up to 20 parallel agents, one per changed code object | highest | strict per-unit rules. Prefer `full_diff`. |

`incremental` does not support `conclusion: failure`; that combination is a
configuration error. A diff that won't fit the model's context window is left out
whole and the agent is told to read paths with `git_diff` instead.

## Models

The skill writes `model: claude-opus-5-5` on every agent: the latest Opus, large
context, and at 4 / 20 USD per 1M input/output tokens it's cheaper than the
`claude-opus-4-6` default (5 / 25). Each generated file carries a comment above
`model` pointing at the full list, since the repo owner may prefer another:

```yaml
# Macroscope supports many models: https://docs.macroscope.com/model-pricing#available-models
model: claude-opus-5-5
```

Other Anthropic options: `claude-sonnet-5` (2 / 10) and `claude-fable-5-1` (10 / 50,
no Zero Data Retention). OpenAI, xAI, and open-source models honor `reasoning`
instead of `effort`; `gpt-6-luna` and `glm-5-3-flash` are the cheapest at 0.10 to
0.15 per 1M input.

## Choosing effort and input

The skill assigns each agent a tier from what its hardest rule needs:

| Tier | The rule needs | `effort` | `input` |
|---|---|---|---|
| **pattern** | only the changed lines: `assert` vs `require`, a `Sprintf` inside a log call, a camelCase proto field, `_ =` on an error | `low` | `incremental` |
| **context** | to open other files: does this helper already exist, who calls this export, is the new route registered | `medium` | `incremental` |
| **pr-level** | the whole PR at once: a bug-fix PR without a regression test, a response-shape change without a version bump | `medium` | `full_diff` |
| **metadata** | only the title, body, or commits | `low` | `pr_metadata` |

`effort: high` only when a rule genuinely traces across several files, and the report
says which rule. Never `reasoning` on these models, and never `xhigh` or `max`.

## Body

Plain markdown. Macroscope's own guidance:

- Be specific: "flag any function over 50 lines without a doc comment", not "review
  for quality".
- Define severity levels. Use headings to organize concerns. Say what not to flag.
- Don't replicate Correctness.
- Give the agent explicit permission to do nothing on a clean PR.
- Don't paste a standard in when it already lives in a file: `@/path/to/file.md`
  splices that file into the instructions. Same syntax as `CLAUDE.md` imports.

Between runs on the same PR, the agent is shown its own earlier threads and whether
they were resolved, so it doesn't repeat itself. Nothing in the body needs to ask
for that.
