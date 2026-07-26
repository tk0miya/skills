#!/bin/bash
#
# PreToolUse hook: run the project checks before `git commit`.
#
# The verdict is recorded per change-set under .git/, so a retry of an
# already-passing change-set skips the suite, and other hooks can order
# themselves after these checks.
#

# Hook input is JSON from stdin
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Only run for git commit commands, including `git -C <path> commit`.
git_re='git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?(commit|cherry-pick|merge|rebase)'
if [[ "$tool_name" != "Bash" ]] || [[ ! "$command" =~ $git_re ]]; then
    exit 0
fi

# Check the tree the command targets: git resolves the repository from the
# working directory, and `git -C <path>` points it elsewhere. Resolved the same
# way in self-review.sh, so both hooks judge the same tree.
work_dir="."
if [[ "$command" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
    work_dir="${BASH_REMATCH[1]}"
elif ! git rev-parse --git-dir >/dev/null 2>&1; then
    work_dir="$CLAUDE_PROJECT_DIR"
fi

cd "$work_dir" || exit 1

# Hash of the uncommitted change-set. Kept identical to the computation in
# self-review.sh: both hooks have to agree on what "this change-set" means.
# Returns non-zero when there is nothing uncommitted.
changeset_hash() {
    local changeset
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
        changeset=$(git status --porcelain; git diff HEAD)
    else
        changeset=$(git status --porcelain; git diff; git diff --cached)
    fi
    [[ -n "$changeset" ]] || return 1
    printf '%s' "$changeset" | git hash-object --stdin
}

git_dir=$(git rev-parse --absolute-git-dir 2>/dev/null || true)
passed_file=${git_dir:+$git_dir/pre-commit-check-passed}
failed_file=${git_dir:+$git_dir/pre-commit-check-failed}
hash=$(changeset_hash || true)

# Publish the verdict for the change-set as it stands now. The checks may have
# rewritten files under sig/, so hash the change-set again rather than reusing
# the pre-check hash: what a verdict has to describe is the state that is about
# to be committed, not the one the checks started from.
record() {
    local file=$1 current
    [[ -n "$file" ]] || return 0
    current=$(changeset_hash || true)
    if [[ -n "$current" ]] && ! { [[ -f "$file" ]] && grep -qxF "$current" "$file"; }; then
        echo "$current" >> "$file"
    fi
}

# This exact change-set already passed → nothing has changed since, skip. Note
# that untracked files contribute only their paths to the change-set, so editing
# one without staging it does not re-trigger the checks.
if [[ -n "$hash" && -n "$passed_file" && -f "$passed_file" ]] && grep -qxF "$hash" "$passed_file"; then
    exit 0
fi

if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
  eval "$(rbenv init - bash)"
fi

echo "Running pre-commit checks..." >&2

# Generate RBS and run all checks
if ! bundle exec rbs-inline --opt-out --output=sig/ lib/ >&2; then
    echo "Error: RBS generation failed" >&2
    record "$failed_file"
    exit 2
fi

if ! bundle exec rake >&2; then
    echo "Error: rake checks failed" >&2
    record "$failed_file"
    exit 2
fi

record "$passed_file"

echo "All checks passed!" >&2
exit 0
