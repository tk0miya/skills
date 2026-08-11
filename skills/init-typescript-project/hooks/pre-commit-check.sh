#!/bin/bash

# Hook input is JSON from stdin
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Only run for git commit commands
if [[ "$tool_name" != "Bash" ]] || [[ ! "$command" =~ git[[:space:]]+(commit|cherry-pick|merge|rebase) ]]; then
    exit 0
fi

cd "$CLAUDE_PROJECT_DIR" || exit 1

echo "Running pre-commit checks..." >&2

if ! npm run ci >&2; then
    echo "Error: npm run ci failed" >&2
    exit 2
fi

echo "All checks passed!" >&2
exit 0
