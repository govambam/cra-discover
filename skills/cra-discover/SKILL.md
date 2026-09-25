---
name: cra-discover
description: >
  Generate Macroscope check run agents from what a repository already enforces: its
  written conventions (CLAUDE.md, AGENTS.md, cursor rules, CONTRIBUTING, review
  skills) and the review comments its reviewers keep leaving on merged PRs. Writes
  proposed agent files and a README explaining each rule's evidence to
  `./cra-proposals/`. Use when the user wants to create or discover check run
  agents, or asks "what should Macroscope check on my PRs?". Accepts an optional
  `owner/repo` argument to target a repo that isn't checked out locally.
---

# Macroscope check run agents

Turn the rules this team already enforces into check run agents: the AI reviewers
Macroscope runs on every PR. Two sources tell you what the team enforces. **Repo
rules** are conventions written in files in the repo. **PR comments** are what
reviewers keep asking for on merged PRs. Read both, pick the rules worth automating,
group them by the files they apply to, write the agent files, and report where each
rule came from using those two names. The user reviews the proposals in their
editor, copies the ones they keep into `.macroscope/check-run-agents/`, and merges.
Merging to the default branch is what activates them.

Read `reference/agent-file-format.md` and `reference/good-rule-heuristics.md` before
writing anything.

`scripts/` sits beside this file. For a manual install that is
`~/.claude/skills/cra-discover/scripts`; for the plugin it is
`$CLAUDE_PLUGIN_ROOT/skills/cra-discover/scripts`.

## 0. Target

With no argument, the target is the current checkout: `git rev-parse --show-toplevel`
for files, `gh repo view --json nameWithOwner` for the GitHub name.

With an `owner/repo` argument that isn't the current checkout, fetch its convention
files into a scratch directory and read from there:

```bash
scripts/fetch-repo.sh owner/repo "$TMPDIR/owner-repo"
```

Either way, start PR mining now so it runs while you read:

```bash
scripts/review-threads.sh owner/repo > "$TMPDIR/threads.tsv" 2> "$TMPDIR/threads.log" &
```

## 1. Discover

**Repo rules.** List candidate files in one sweep and read them:

```bash
git ls-files | grep -iE '(^|/)(CLAUDE|AGENTS|CONTRIBUTING|STYLEGUIDE|copilot-instructions)\.md$|\.cursorrules$|(^|/)\.cursor/rules/|(^|/)\.github/(PULL_REQUEST_TEMPLATE|CODEOWNERS)|(^|/)(\.claude|\.agents)/skills/|(^|/)\.macroscope/check-run-agents/'
```

Read rule files, contributor docs, and review skills fully. Skim PR templates and
CODEOWNERS. Only sample `docs/` or ADRs if the rule files are thin; never crawl a
docs tree. Linter and CI configs are a source of conventions, not an exclusion
filter: if a violation reaches review, the linter didn't catch it.

**PR comments.** Wait for the script, then read the TSV. Each line is one review
thread: PR number, reviewer, whether it was resolved, file path, and the reviewer's
comment. Cluster the lines by the underlying rule, not the wording. For each
cluster record the distinct PRs, distinct reviewers, how many were resolved, and one
representative quote with its PR number and reviewer. Keep a cluster only if:

- it appears in 2 or more PRs, or from 2 or more reviewers;
- it restates as "on any PR, flag X when Y" without pointing at that PR's code. A
  comment about a specific defect is a bug report, and Correctness already owns
  bugs;
- most of its threads are `resolved` or `outdated`, which means authors acted on it.
  A cluster that is mostly `open` is a debate, not a convention.

If the log says PR mining was skipped, carry on with repo rules alone and say so in
the report.

**Off the table from the start:** anything an existing agent in
`.macroscope/check-run-agents/` covers, and anything the built-in agents already do.
Correctness finds runtime bugs; Approvability judges merge readiness.

**Give every candidate a scope** as you collect it, because grouping depends on it:

- universal: applies to any code change
- language: `**/*.py`, `**/*.go`, `**/*.{ts,tsx}`
- area: `src/api/**`, `migrations/**`, `charts/**`
- language within an area, in monorepos

In a single-language repo, universal and language are the same scope. Tests and
generated code are their own scopes: give test rules a test-file agent, and exclude
generated files (`*.pb.go`, mocks, `gen/**`) from every source agent.

Keep the evidence for each candidate: for a repo rule, the quoted line and its
`file:line`; for a PR comment, the quote, reviewer, PR number, file path, and the
other PRs where the same ask appears.

## 2. Select and group

Score each candidate against the four tests in `reference/good-rule-heuristics.md`:
objective and checkable from the diff, recurring, not covered by another agent,
costly when violated. Drop anything that fails one. Then rank by corroboration:

1. **Both sources.** A repo rule that reviewers still had to ask for in PR comments.
2. **PR comments only, recurring.** 2+ PRs or 2+ reviewers.
3. **Repo rules only.**
4. A PR comment seen once with no repo rule: drop.

**Group by scope, not by topic.** Macroscope pays an agent's whole prompt on every PR
that touches its `include` glob, so two rules share an agent only when they share a
file scope:

- Rules with the same scope go in one agent. Universal rules form the primary agent;
  name it `conventions.md` or whatever the repo's own vocabulary suggests. Language
  rules form one agent per language. Area rules form one per area.
- About 5 rules per agent. The quality bar and the scopes decide how many agents
  there are; a thin repo yields one or two.
- Merge up, never sideways. An agent left with one rule folds into the nearest
  enclosing scope: Python-in-`services/` into Python, Python into the primary. Never
  combine disjoint scopes such as Python and Go; that spends a run on every PR of
  either language for rules that can't fire.
- Split by domain only inside a scope and only past the cap, such as Go testing and
  Go API conventions.

Weak candidates teach the team to ignore the agent. Three sharp rules beat six padded
ones.

**Templates.** `templates/` holds curated agents Macroscope recommends. Offer one when
a repo signal fits and nothing discovered or existing already covers it. Each is
already scoped and keeps its own file.

| Template | Offer when |
|----------|-----------|
| `ticket-requirements` | PR template asks for a ticket link, or branch and commit names carry `PROJ-123` IDs. Needs the issue-tracker integration connected. |
| `language-idioms` | The repo is mostly Go or TypeScript. |
| `architecture-standards` | Multiple services or packages with real module boundaries. |
| `accessibility` | The repo has a frontend. |
| `security-review` | Handles untrusted input, auth, or a web surface. Ships blocking. |
| `guardrails` | Any repo. Cheap. Ships blocking. |

When conventions are thin, lead with templates rather than inventing rules.

## 3. Write

Write each authored agent following `reference/agent-file-format.md`, shaped like
`reference/example.md`:

- Frontmatter: `title`, the scope as `include` and `exclude` globs,
  `model: claude-opus-5-5` preceded by this exact comment line so the reader knows
  it's a choice:

  ```yaml
  # Macroscope supports many models: https://docs.macroscope.com/model-pricing#available-models
  model: claude-opus-5-5
  ```

  and `effort` and `input` from the agent's tier, set by its hardest rule:

  | Tier | The hardest rule needs | `effort` | `input` |
  |---|---|---|---|
  | pattern | only the changed lines | `low` | `incremental` |
  | context | to open other files | `medium` | `incremental` |
  | pr-level | the whole PR at once | `medium` | `full_diff` |
  | metadata | only title, body, or commits | `low` | `pr_metadata` |

  Never write `reasoning`: every Anthropic model newer than 4.5 ignores it. Use
  `effort: high` only for a rule that traces across several files, and name it in
  the report. Leave `conclusion` unset so the agent is advisory. Leave `tools` unset;
  setting it replaces the defaults, and the default `modify_pr` is what lets the
  agent post inline comments. Only set `tools` when a rule needs an integration such
  as `sentry`, and then re-list the defaults.
- Body: one `###` section per rule with a severity (🔴 Must fix, 🟡 Should fix,
  🟢 Nit), a concrete "flag X when Y", and a "don't flag" line where false positives
  are likely. A standard that already lives in a focused file can be spliced in with
  `@/path/to/file.md` instead of restated, but keep a checkable trigger inline, and
  don't import a whole `CLAUDE.md`; it's written for a coding assistant, not a
  reviewer.
- End with the output block from `reference/example.md`, verbatim.
- No evidence in the body. Macroscope runs the body as instructions, so a citation
  is noise. Quotes, PR numbers, and file lines go in the report only.

Copy accepted templates from `templates/<id>.md` unchanged, including a
`conclusion: failure` where one is set.

**Where the files go.** Always `./cra-proposals/` in the current directory, flat:
one `<name>.md` per agent plus a `README.md` holding the report from Step 4. These are
proposals, so they don't go into `.macroscope/` until the user has reviewed them. If
`./cra-proposals/` already exists, write `./cra-proposals-2/` (then `-3`, and so on)
rather than overwriting.

## 4. Report

Number the agents and the rules inside them, and put the evidence for each rule in
two named blocks so a reader can trace every suggestion to its source. No tables.
The shape, in this order:

```markdown
# Proposed check run agents — owner/repo

Read: 7 convention files; 180 human review threads across 150 merged PRs, most
merged since 2026-09.

## 1. error-handling.md — Go source, not tests or generated
Effort low, incremental. Every rule is decidable from the changed lines.

### 1.1 Errors are handled, never discarded — 🔴 Must fix

PR comments
- "Can we avoid ignoring the returned error?" — @rodrigozhou in
  [#9523](https://github.com/owner/repo/pull/9523), `common/persistence/cassandra/queue_v2_store.go`.
  Same ask in 1 other PR: #11197.

Repo rules
- "errors MUST be handled, not ignored" — `AGENTS.md:62`

### 1.2 …
```

Rules with both blocks come first inside each agent. Omit a block the rule has no
evidence for. One quote per block; the count carries the rest. Every PR gets a link
and every repo rule gets a `file:line`. The line under each agent heading states
its effort and input and the one-sentence reason for that tier. After the agents:

- **Templates**: one bullet per template written, with why it applies and whether
  it ships blocking or needs an integration.
- **Left out**: one bullet per candidate that nearly made it and why it didn't.
- **Next**: two lines. Review the files here and delete what you don't want. Copy
  the rest into `.macroscope/check-run-agents/` at the repo root and open a PR;
  merging to the default branch activates them. (Macroscope ignores a `README.md`
  in that folder, so copying everything is safe.)

Print the same report to the terminal, and end with the output folder path.

If PR mining was skipped, the Read line says so and why. If nothing clears the bar,
say so and write nothing.
