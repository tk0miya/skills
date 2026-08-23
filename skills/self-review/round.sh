#!/bin/bash
#
# Count the self-review rounds spent on the commit being prepared, as it stands.
#
# Prints `proceed` while rounds remain and `stop` once the cap is spent, because
# a review that keeps finding something to act on would otherwise be run again
# after every fix, without end. How many rounds are left is deliberately not
# printed: told that the next round is the last, an agent has a cheaper way past
# a finding than judging it.
#
# The count is keyed on HEAD, so any update to the commit being prepared -- a
# new one landing, an amend, a cherry-pick, a rebase, a reset to another commit
# -- starts a fresh count, as does moving to another branch, even one at the
# same commit. What the cap bounds is the review-fix-review loop over
# uncommitted changes, where HEAD stands still; whatever follows an update is
# work no round has seen.
#
# Usage: round.sh [<repo-path>]

set -euo pipefail

work_dir="${1:-.}"
max_rounds=3

# Not --git-common-dir: worktrees prepare different commits in parallel, and one
# budget shared between them would let a worktree spend another's rounds.
state_file="$(git -C "$work_dir" rev-parse --absolute-git-dir)/self-review-rounds"

# Before the first commit there is no HEAD; name that state so it can be
# compared like a commit.
head=$(git -C "$work_dir" rev-parse --verify HEAD 2>/dev/null || echo "initial-commit")
branch=$(git -C "$work_dir" symbolic-ref --quiet --short HEAD || echo "detached")

rounds=0
if [[ -f "$state_file" ]]; then
  state_head=$(sed -n 1p "$state_file")
  rounds=$(sed -n 2p "$state_file")
  state_branch=$(sed -n 3p "$state_file")
  [[ "$rounds" =~ ^[0-9]+$ ]] || rounds=0
  if [[ "$state_head" != "$head" || "$state_branch" != "$branch" ]]; then
    rounds=0
  fi
fi

if (( rounds >= max_rounds )); then
  echo stop
  exit 0
fi

# Count the round before it runs: a round that starts and returns nothing still
# spent an attempt, and repeating it forever is the loop this cap is for.
printf '%s\n%s\n%s\n' "$head" "$((rounds + 1))" "$branch" > "$state_file"
echo proceed
