#!/bin/bash
#
# PostToolUse hook for self-review after git push
#
# This script triggers a self-review process after git push operations.
# The output is fed back to Claude via JSON, prompting it to perform
# a code review.
#
# NOTE: PostToolUse hooks with exit code 0 only show plain text stdout
# in verbose mode. To ensure Claude receives the message, we output JSON
# with "decision": "block" and "reason", which Claude Code delivers as
# a system-reminder.
#

set -euo pipefail

# Read JSON input from stdin
input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Only run for Bash tool
if [[ "$tool_name" != "Bash" ]]; then
  exit 0
fi

# Check if it's a git push command
if [[ ! "$command" =~ git[[:space:]]+push ]]; then
  exit 0
fi

# Check if push was successful (field may not exist; default to 0)
exit_code=$(echo "$input" | jq -r '.tool_response.exit_code // 0')

if [[ "$exit_code" != "0" ]]; then
  # Push failed, no need for review
  exit 0
fi

# Output self-review prompt as JSON so Claude receives it
review_prompt='SELF-REVIEW REQUIRED: A git push has been completed. Please use the Task tool with subagent_type Explore to perform a self-review of the changes. Use this prompt for the Explore subagent:

First, read CLAUDE.md to understand the project rules and conventions.
Then review the recent git push. Run `git log origin/main..HEAD --stat` and
`git diff origin/main...HEAD` to examine all changes from the branch point.
Check for:
1. Correctness: requirements met, logic errors, edge cases
2. Code Quality: naming, readability, follows project conventions
3. Testing: test coverage for new functionality
4. Security: vulnerabilities, input validation
5. Commit Quality: each commit should be a meaningful unit of work.
   If there are minor fix commits (typos, forgotten changes, careless mistakes),
   suggest squashing them into the relevant commit before merging.

Report findings and suggest fixes if needed.
After the subagent review, if issues are found, create follow-up commits to address them.

If working in a git worktree (i.e., the working directory is under .claude/worktrees/),
use `git -C <worktree-path>` for all git commands instead of `cd <path> && git`.
Also avoid chaining commands with `&&` where possible — run each command separately.'

jq -n --arg reason "$review_prompt" '{
  "decision": "block",
  "reason": $reason
}'

exit 0
