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
# A per-change-set marker (keyed by a hash of the diff, stored under .git/)
# prevents an infinite block loop: once a change-set has been surfaced for
# review, the matching commit is allowed through. If the review leads to fixes,
# the diff changes, so the new state is reviewed once more before it commits.
#
# When the project also installs a `.claude/hooks/pre-commit-check.sh`, the
# review is ordered after those checks: reviewing a change-set that the checks
# are about to send back for fixes is wasted work. All PreToolUse hooks run in
# parallel, so their order in settings.json cannot sequence them — instead this
# hook waits for the check hook to record the change-set as passing.
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

# Hash what will be committed. `git status --porcelain` is included so a commit
# that only adds untracked files isn't mistaken for empty; `git diff HEAD` adds
# tracked content. On the first commit there is no HEAD, so use the working state.
if git -C "$work_dir" rev-parse --verify HEAD >/dev/null 2>&1; then
  changeset=$(git -C "$work_dir" status --porcelain; git -C "$work_dir" diff HEAD)
else
  changeset=$(git -C "$work_dir" status --porcelain; git -C "$work_dir" diff; git -C "$work_dir" diff --cached)
fi

# Nothing to review (e.g. a message-only `--amend`) → let it proceed.
if [[ -z "$changeset" ]]; then
  exit 0
fi

hash=$(printf '%s' "$changeset" | git hash-object --stdin)
state_file="$git_dir/self-review-reviewed"

# Already surfaced for review → allow the commit.
if [[ -f "$state_file" ]] && grep -qxF "$hash" "$state_file"; then
  exit 0
fi

# Deny the commit, telling Claude what to do before retrying.
deny() {
  jq -n --arg reason "$1" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": $reason
    }
  }'
  exit 0
}

# Wait for the check hook's verdict, recorded under .git/ per change-set. A
# recorded failure keeps the review deferred for as long as it stands. With no
# verdict either way the wait is capped at one attempt per change-set, so a check
# hook that records nothing still lets the commit through the review and on.
check_hook="${CLAUDE_PROJECT_DIR:-$work_dir}/.claude/hooks/pre-commit-check.sh"
passed_file="$git_dir/pre-commit-check-passed"
failed_file="$git_dir/pre-commit-check-failed"
deferred_file="$git_dir/self-review-check-deferred"
recorded_in() {
  [[ -f "$1" ]] && grep -qxF "$hash" "$1"
}
if [[ -f "$check_hook" ]] && ! recorded_in "$passed_file"; then
  if recorded_in "$deferred_file"; then
    first_wait=no
  else
    first_wait=yes
    echo "$hash" >> "$deferred_file"
  fi

  if [[ "$first_wait" == yes ]] || recorded_in "$failed_file"; then
    deny 'PRE-COMMIT CHECKS COME FIRST. The self-review is requested once the project checks pass.

The `pre-commit-check.sh` hook runs alongside this one on every commit attempt:

- If it reported failures, fix them first.
- Otherwise nothing needs fixing — run the same git commit command again, and the
  self-review will be requested next.'
  fi
fi

# Record this change-set and block once to force a review first.
echo "$hash" >> "$state_file"

deny 'SELF-REVIEW REQUIRED before committing. Review the changes that are
about to be committed BEFORE running git commit again:

- If the `self-review` skill is available, invoke it (Skill tool, skill "self-review").
- Otherwise, run the bundled `/code-review` skill on the working diff.

If the review finds issues, fix them and review again. Once it is clean, run the same
git commit command again to proceed — it will be allowed through.'
