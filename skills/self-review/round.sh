#!/bin/bash
#
# Count the self-review rounds spent on the commit being prepared.
#
# Prints `proceed` while rounds remain and `stop` once the cap is spent, because
# a review that keeps finding something to act on would otherwise be run again
# after every fix, without end. How many rounds are left is deliberately not
# printed: told that the next round is the last, an agent has a cheaper way past
# a finding than judging it.
#
# The state file holds the branch and the commit the change-set builds on, and
# the rounds spent on it. A commit that lands on that base starts a fresh count,
# and so does moving to another branch, which prepares a different commit. A
# base the current HEAD does not descend from, on the same branch, means the
# commit was rewritten (an amend, a rebase) rather than a new one landing, so
# the count carries over.
# Resetting there would hand the loop a fresh budget for the price of an amend,
# which the commit guidance asks for after every minor fix.
#
# Keying on the base rather than on the change-set is what makes the budget
# bound a loop at all: every fix changes the change-set, so a budget keyed on it
# would be renewed by the very rounds it is meant to count. The cost is that a
# change-set started over on the same base inherits what the discarded one
# spent, and that work amended onto a commit whose budget is spent goes
# unreviewed until a new commit lands. Both are for the user to release, not the
# agent.
#
# Usage: round.sh [<repo-path>]

set -euo pipefail

work_dir="${1:-.}"
max_rounds=5

# Not --git-common-dir: worktrees prepare different commits in parallel, and one
# budget shared between them would let a worktree spend another's rounds.
state_file="$(git -C "$work_dir" rev-parse --absolute-git-dir)/self-review-rounds"

# Before the first commit there is no HEAD; name that state so it can be
# compared like a commit.
head=$(git -C "$work_dir" rev-parse --verify HEAD 2>/dev/null || echo "initial-commit")
branch=$(git -C "$work_dir" symbolic-ref --quiet --short HEAD || echo "detached")

# The base commit goes on the first line, the rounds spent on it on the second,
# and the branch they were spent on on the third.
rounds=0
if [[ -f "$state_file" ]]; then
  base=$(sed -n 1p "$state_file")
  rounds=$(sed -n 2p "$state_file")
  state_branch=$(sed -n 3p "$state_file")
  [[ "$rounds" =~ ^[0-9]+$ ]] || rounds=0
  if [[ "$state_branch" != "$branch" ]]; then
    rounds=0
  elif [[ "$base" != "$head" ]] &&
       { [[ "$base" == "initial-commit" ]] ||
         git -C "$work_dir" merge-base --is-ancestor "$base" "$head" 2>/dev/null; }; then
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
