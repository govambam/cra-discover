#!/usr/bin/env bash
# fetch-repo.sh — fetch only a repo's convention files into a directory.
#
#   fetch-repo.sh owner/repo <dir>
#
# Shallow, blobless, no-checkout clone (a few seconds for any repo size), then a
# sparse checkout of just the files the skill reads. Prints the matched paths.
# Read-only against GitHub. Uses gh for auth so private repos work.

set -euo pipefail

repo="${1:?usage: fetch-repo.sh owner/repo <dir>}"
dir="${2:?usage: fetch-repo.sh owner/repo <dir>}"

pattern='(^|/)(CLAUDE|AGENTS|CONTRIBUTING|STYLEGUIDE|copilot-instructions)\.md$|\.cursorrules$|(^|/)\.cursor/rules/|(^|/)\.github/(PULL_REQUEST_TEMPLATE|CODEOWNERS)|(^|/)(\.claude|\.agents)/skills/|(^|/)\.macroscope/check-run-agents/'

gh repo clone "$repo" "$dir" -- --quiet --depth=1 --filter=blob:none --no-checkout
files="$(git -C "$dir" ls-tree -r --name-only HEAD | grep -iE "$pattern" || true)"
if [[ -z "$files" ]]; then
  echo "fetch-repo: no convention files in $repo" >&2
  exit 0
fi
printf '%s\n' "$files" | git -C "$dir" sparse-checkout set --no-cone --stdin
git -C "$dir" checkout -q HEAD
printf '%s\n' "$files"
