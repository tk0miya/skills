#!/usr/bin/env bash
# Configures the project-wide GitHub side: everything that is not specific to
# one language.
#   - branch protection ruleset requiring actionlint / zizmor
#     (via add-required-checks.sh)
#   - auto-merge label
#   - allow_auto_merge / delete_branch_on_merge repo settings
#   - Dependabot vulnerability alerts / automated security fixes
#   - Actions permission to approve PRs
#   - PR_AUTO_MERGER variable / secret (incl. dependabot scope)
#   - REPO_HOUSEKEEPER variable / secret
#
# The client IDs and key paths below identify this owner's GitHub Apps.
#
# Run after the workflow files have been merged into the default branch: it makes
# actionlint / zizmor required, which strands every pull request while the
# workflow that reports them is unmerged.
#
# Usage:
#   setup.sh --repo OWNER/NAME

set -euo pipefail

usage() {
  echo "Usage: $0 --repo OWNER/NAME"
  exit 1
}

REPO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -z "$REPO" ]] && usage

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PR_AUTO_MERGER_CLIENT_ID="Iv23liInIOSVmvfZicez"
PR_AUTO_MERGER_PRIVATE_KEY_PATH="$HOME/Dropbox/Personal/secrets/pull-request-auto-merging-bot.private-key.pem"
REPO_HOUSEKEEPER_CLIENT_ID="Iv1.11115f090b79bb10"
REPO_HOUSEKEEPER_PRIVATE_KEY_PATH="$HOME/Dropbox/Personal/secrets/repo-housekeeper.private-key.pem"

# -s as well as -r: cat in $(...) does not fail, so a 0-byte key would be
# registered as an empty secret and only fail at workflow run time.
require_key() {
  [[ -s "$1" && -r "$1" ]] || { echo "private key missing or empty: $1" >&2; exit 1; }
}
require_key "$PR_AUTO_MERGER_PRIVATE_KEY_PATH"
require_key "$REPO_HOUSEKEEPER_PRIVATE_KEY_PATH"

# This writes an owner's GitHub App keys, so a mistyped --repo is expensive. When
# run inside a checkout, make sure it is a checkout of that repository; running
# outside one is fine and skips the check.
if CHECKOUT=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null); then
  [[ "$CHECKOUT" == "$REPO" ]] \
    || { echo "this is a checkout of ${CHECKOUT}, not ${REPO}" >&2; exit 1; }
fi

# On the default branch, not in the working tree: an unmerged workflow-lint.yml
# never reports, so requiring actionlint / zizmor would strand every PR pending.
gh api "repos/${REPO}/contents/.github/workflows/workflow-lint.yml" --silent \
  || { echo "workflow-lint.yml is not on the default branch of ${REPO}: merge it first" >&2; exit 1; }

echo "==> Updating repository settings"
gh api "repos/${REPO}" \
  --method PATCH \
  --field allow_auto_merge=true \
  --field delete_branch_on_merge=true

bash "${SCRIPT_DIR}/add-required-checks.sh" --repo "$REPO" \
  --add-check actionlint --add-check zizmor

echo "==> Creating labels"
gh label create "auto-merge" --color "0075ca" --description "Automatically merge this PR" --repo "$REPO" \
  || echo "==> label 'auto-merge' already exists, skipping"

echo "==> Enabling Dependabot"
gh api "repos/${REPO}/vulnerability-alerts" --method PUT
gh api "repos/${REPO}/automated-security-fixes" --method PUT

echo "==> Granting GitHub Actions permission to approve PRs"
gh api "repos/${REPO}/actions/permissions/workflow" \
  --method PUT \
  --field can_approve_pull_request_reviews=true

echo "==> Setting up PR_AUTO_MERGER"
gh variable set PR_AUTO_MERGER_CLIENT_ID --body "$PR_AUTO_MERGER_CLIENT_ID" --repo "$REPO"
gh secret set PR_AUTO_MERGER_PRIVATE_KEY \
  --body "$(cat "$PR_AUTO_MERGER_PRIVATE_KEY_PATH")" \
  --repo "$REPO"
gh secret set PR_AUTO_MERGER_PRIVATE_KEY --app dependabot \
  --body "$(cat "$PR_AUTO_MERGER_PRIVATE_KEY_PATH")" \
  --repo "$REPO"

echo "==> Setting up REPO_HOUSEKEEPER"
gh variable set REPO_HOUSEKEEPER_CLIENT_ID --body "$REPO_HOUSEKEEPER_CLIENT_ID" --repo "$REPO"
gh secret set REPO_HOUSEKEEPER_PRIVATE_KEY \
  --body "$(cat "$REPO_HOUSEKEEPER_PRIVATE_KEY_PATH")" \
  --repo "$REPO"

echo "==> setup-github-workflows done: ${REPO}"
