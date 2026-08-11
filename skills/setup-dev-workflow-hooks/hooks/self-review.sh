#!/bin/bash
#
# PreToolUse hook: review code before `git commit`.
#
# Fires before a Bash `git commit` command and blocks the first commit attempt
# for a given change-set, asking Claude to review the code before committing.
# The review uses the `self-review` skill when available, and falls back to the
# bundled `code-review` skill otherwise — so the hook works even in projects
# that don't ship the custom self-review skill.
#
# A state file under .git/ records the change-sets already surfaced for review,
# keyed by the commit they build on. A change-set that was reviewed commits
# without another block; a change-set the review has not seen — the fixes it
# asked for change the diff — is reviewed once more. Reviews are capped per
# commit, because a review that keeps finding something to fix would otherwise
# block every commit attempt forever. Once the cap is spent the hook stops
# gating and says so; a landed commit moves HEAD and starts a fresh cap.
#

set -euo pipefail

# Read JSON input from stdin
input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Only gate the Bash tool running a git commit.
if [[ "$tool_name" != "Bash" ]]; then
  exit 0
fi
# Match `git commit`, or `git -C <path> commit`.
commit_re='git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?commit'
if [[ ! "$command" =~ $commit_re ]]; then
  exit 0
fi

# If the command targets a specific repo via `git -C <path>`, operate there too.
work_dir="."
if [[ "$command" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
  work_dir="${BASH_REMATCH[1]}"
fi

# Not a git repo → nothing to do.
git_dir=$(git -C "$work_dir" rev-parse --absolute-git-dir 2>/dev/null || true)
if [[ -z "$git_dir" ]]; then
  exit 0
fi

# Hash what will be committed, and name the commit it builds on. `git status
# --porcelain` is included so a commit that only adds untracked files isn't
# mistaken for empty; `git diff HEAD` adds tracked content. On the first commit
# there is no HEAD, so use the working state.
if base=$(git -C "$work_dir" rev-parse --verify HEAD 2>/dev/null); then
  changeset=$(git -C "$work_dir" status --porcelain; git -C "$work_dir" diff HEAD)
else
  base="initial-commit"
  changeset=$(git -C "$work_dir" status --porcelain; git -C "$work_dir" diff; git -C "$work_dir" diff --cached)
fi

# Nothing to review (e.g. a message-only `--amend`) → let it proceed.
if [[ -z "$changeset" ]]; then
  exit 0
fi

hash=$(printf '%s' "$changeset" | git hash-object --stdin)

# The base commit goes on the first line, one reviewed change-set hash per line
# below it. A first line other than the current base records an earlier commit,
# so the file is started over.
state_file="$git_dir/self-review-state"
if [[ ! -f "$state_file" ]] || [[ "$(head -n 1 "$state_file")" != "$base" ]]; then
  printf '%s\n' "$base" > "$state_file"
fi

# Already surfaced for review → allow the commit.
if grep -qxF "$hash" <(tail -n +2 "$state_file"); then
  exit 0
fi

# One line per review spent on this commit, plus the base commit line. Out of
# reviews → let the commit through, and report the review that did not happen.
max_reviews=5
if (( $(wc -l < "$state_file") - 1 >= max_reviews )); then
  jq -n --arg max "$max_reviews" '{
    "systemMessage": ("Committing without a self-review: this commit has already been reviewed " + $max + " times.")
  }'
  exit 0
fi

# Record this change-set and block once to force a review first.
echo "$hash" >> "$state_file"

review_prompt='SELF-REVIEW REQUIRED before committing. Review the changes that are
about to be committed BEFORE running git commit again:

- If the `self-review` skill is available, invoke it (Skill tool, skill "self-review").
- Otherwise, run the bundled `/code-review` skill on the working diff.

Judge each finding the review returns rather than fixing it on sight. Weigh what the review
attached to it — how it graded the point, the basis it gave — and decide whether acting on it
is worth it. Where you skip a finding, say so; do not drop it silently. Where the choice needs
a requirement or an intent you do not have, leave it to the user. Once every fix you judged
necessary is in, review again; when nothing you judged worth fixing is left, run the same git
commit command again to proceed — it will be allowed through.'

jq -n --arg reason "$review_prompt" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": $reason
  }
}'

exit 0
