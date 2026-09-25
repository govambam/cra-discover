#!/usr/bin/env bash
# review-threads.sh — recent human review threads from merged PRs, as TSV.
#
#   review-threads.sh [owner/repo]        defaults to the current repo
#
# Reads up to 150 merged PRs in three GraphQL calls. Keeps the root comment of each
# review thread, drops bots, the PR author's own notes, and short replies like "nit"
# or "done". One line per thread on stdout:
#
#   #1234<TAB>reviewer<TAB>resolved|outdated|open<TAB>path<TAB>body
#
# A coverage line goes to stderr. Read-only. If gh is unavailable or the repo has no
# GitHub remote, exits 0 with nothing on stdout so the caller can carry on without it.

set -euo pipefail

repo="${1:-}"
if [[ -z "$repo" ]]; then
  repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
fi
if [[ -z "$repo" ]] || ! gh auth status >/dev/null 2>&1; then
  echo "review-threads: gh not authenticated or no GitHub repo; skipping PR mining" >&2
  exit 0
fi
owner="${repo%%/*}"
name="${repo#*/}"

query='query($owner:String!,$name:String!,$after:String){
  repository(owner:$owner,name:$name){
    pullRequests(states:MERGED,first:50,after:$after,orderBy:{field:UPDATED_AT,direction:DESC}){
      pageInfo{hasNextPage endCursor}
      nodes{ number mergedAt author{login}
        reviewThreads(first:30){ nodes{ isResolved isOutdated
          comments(first:1){ nodes{ author{__typename login} path body } } } } } } } }'

pages="$(mktemp)"
trap 'rm -f "$pages"' EXIT
after=""
for _ in 1 2 3; do
  args=(-f query="$query" -f owner="$owner" -f name="$name")
  [[ -n "$after" ]] && args+=(-f after="$after")
  page="$(gh api graphql "${args[@]}")"
  printf '%s\n' "$page" >>"$pages"
  jq -e '.data.repository.pullRequests.pageInfo.hasNextPage' <<<"$page" >/dev/null || break
  after="$(jq -r '.data.repository.pullRequests.pageInfo.endCursor' <<<"$page")"
done

# shellcheck disable=SC2016
rows='
  [.[].data.repository.pullRequests.nodes[]] as $prs
  | [ $prs[] | .number as $n | (.author.login // "") as $pr_author
      | [ .reviewThreads.nodes[]
          | . as $t | .comments.nodes[0] as $c
          | select($c != null and $c.author != null)
          | select($c.author.__typename != "Bot" and $c.author.login != $pr_author)
          | ($c.body | gsub("[\\r\\n\\t]+"; " ") | gsub(" +"; " ") | ltrimstr(" ")) as $body
          | select(($body | length) >= 30)
          | { n: $n, who: $c.author.login,
              state: (if $t.isResolved then "resolved" elif $t.isOutdated then "outdated" else "open" end),
              path: ($c.path // "-"), body: $body[0:240] }
        ][0:15][]
    ]'

jq -rs "$rows"' | .[] | "#\(.n)\t\(.who)\t\(.state)\t\(.path)\t\(.body)"' "$pages"
jq -rs "$rows"' as $r | [.[].data.repository.pullRequests.nodes[]] as $prs
  | ($prs | map(.mergedAt) | sort) as $d
  | "\($r | length) human review threads across \($prs | length) merged PRs, most merged since \($d[($d | length / 10 | floor)][0:7])"' \
  "$pages" >&2
