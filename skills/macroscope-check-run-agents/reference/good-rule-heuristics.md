# What makes a good check run agent rule

A check run agent runs on every PR. A vague, subjective, or duplicate rule trains the
team to ignore the agent. A candidate should clearly pass all four tests below.

## 1. Objective and diff-checkable

Can an LLM reviewer decide this from the PR diff plus browsing the codebase? Favor
rules with a concrete trigger.

- **Good:** "New HTTP route handlers must register an entry in `routes.ts`."
- **Good:** "Any new public function in `sdk/` needs a doc comment."
- **Bad:** "Code should be well-architected." No trigger.
- **Bad:** "Make sure the feature is what the customer wanted." Not in the diff.

Rephrase soft conventions into a concrete trigger, or drop them.

## 2. Recurring

Automate what comes up again and again.

- Strongest: a repo rule that reviewers still had to ask for in PR comments.
- Strong: a repo rule stated emphatically, or a PR comment that recurs across 2 or
  more PRs or from 2 or more reviewers, mostly on threads the author acted on.
- Weak: a passing aside, a preference with no teeth, or a PR comment seen once.

## 3. Not covered by another check run agent

The only thing to dedupe against is another check run agent: an existing custom agent
in `.macroscope/check-run-agents/`, or the built-in **Correctness** (runtime bugs) and
**Approvability** (merge readiness). If a rule restates one of those, drop it.

Overlap with linters, formatters, type-checkers, and CI is fine. A linter only helps
when it's configured, enabled, and able to make the call. Rules get disabled inline or
never set up, and a linter can't reason that "this `assert` lets the test continue and
the next line dereferences nil." If a violation reaches review, the linter didn't catch
it. Read linter configs to understand the team's conventions, never as a reason to
exclude a candidate.

## 4. Costly when violated

Prefer rules where a miss hurts: correctness, security, data integrity, API stability,
on-call burden. Cosmetic rules can ship as 🟢 Nit but shouldn't crowd out the important
ones.

## Conventions, not bugs

An agent encodes a standing rule that applies to every future PR. It is not a place to
park a one-off finding. The test: can you restate it as "on any PR, flag X when Y"
without pointing at specific code? If not, drop it. Correctness already owns bugs.

## Grouping into agents

Macroscope runs an agent on every PR that touches a file matching its `include`
glob, and pays the whole prompt each time. So the file scope, not the topic, decides
which rules share an agent:

- Same scope, same agent. Universal rules (any code change) form the primary agent.
  Language rules form one agent per language. Area rules (`src/api/**`,
  `migrations/**`) form one per area.
- About 5 rules per agent.
- Merge up, never sideways. A one-rule agent folds into the nearest enclosing scope.
  Never combine disjoint scopes such as Python and Go: every Go PR would pay for
  Python rules that can't fire.
- Split by domain only inside a scope and only past the cap: Go testing and Go API
  conventions, not Go and Python.

Give each agent `include` and `exclude` globs that state its scope exactly.

## Checklist for each rule

- A concrete trigger: "flag X when Y".
- A severity: 🔴 / 🟡 / 🟢.
- What not to flag, where false positives are likely.
- The agent ends with explicit permission to report nothing on a clean PR.
- A source in the repo you can cite to the user. If you can't cite one, don't propose
  it.
