# macroscope-check-run-agents

A Claude Code skill that generates [Macroscope check run agents](https://docs.macroscope.com/check-run-agents)
from what a repository already enforces.

It reads two sources: the conventions the team wrote down (`CLAUDE.md`, `AGENTS.md`,
cursor rules, `CONTRIBUTING.md`, review skills) and the review comments reviewers
keep leaving on merged PRs. It picks the rules worth automating, groups them by the
files they apply to so a Go PR never pays for Python rules, sets each agent's effort
and input mode from how hard its rules are, and writes them as
`.macroscope/check-run-agents/*.md` files. Each rule is reported with its source:
the file and line, or the PRs and reviewers who asked for it. You review the files in
your editor, keep what you want, and merge. Where a repo's conventions are thin, it
offers Macroscope's curated templates instead of inventing rules.

## Install

As a plugin:

```
/plugin marketplace add govambam/macroscope-check-run-agents
/plugin install macroscope-check-run-agents
```

Or copy `skills/macroscope-check-run-agents/` into `~/.claude/skills/` or your
repo's `.claude/skills/`.

PR mining and the target-repo form need [`gh`](https://cli.github.com/) authenticated.
Without it the skill runs on repo rules alone and says so.

## Use

Inside a repository:

```
/macroscope-check-run-agents
```

Against a repository you don't have checked out:

```
/macroscope-check-run-agents temporalio/temporal
```

The second form writes to `./temporalio-temporal/` in the current directory, with a
`PROPOSAL.md` beside the agent files holding the reasoning.

Generated agents are advisory and cannot block a PR. Templates that ship blocking
(`security-review`, `guardrails`) are flagged when offered. Macroscope loads agents
from the default branch, so merging is what activates them.

To validate agents against a real past PR once they're live, use
[pr-backtest-script](https://github.com/govambam/pr-backtest-script).

## Layout

```
.claude-plugin/              plugin and marketplace manifests
skills/macroscope-check-run-agents/
  SKILL.md                   the workflow
  scripts/
    review-threads.sh        150 merged PRs' human review threads as TSV, 3 API calls
    fetch-repo.sh            a target repo's convention files via sparse checkout
  reference/
    agent-file-format.md     frontmatter schema and body guidance, mirrored from the docs
    good-rule-heuristics.md  what makes a rule worth automating, and how to group them
    example.md               one complete agent in the shape the skill writes
  templates/                 Macroscope's curated agents, copied verbatim when accepted
```

## License

MIT. See [LICENSE](LICENSE).
