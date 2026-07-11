#!/usr/bin/env bash
# Configures the GitHub side for the workflows shipped by the
# setup-github-workflows skill (workflow-lint.yml, auto-merge.yml,
# dependabot-auto-label.yml, dependabot.yml):
#   - base branch protection ruleset (PR required; actionlint / zizmor checks)
#   - auto-merge label
#   - allow_auto_merge / delete_branch_on_merge repo settings
#   - Dependabot vulnerability alerts / automated security fixes
#   - Actions permission to approve PRs
#   - PR_AUTO_MERGER variable / secret (incl. dependabot scope)
#
# The repository must already exist and the workflow files must already be
# pushed to the default branch (this script adds the protection ruleset, so
# run it AFTER pushing).
#
# Usage:
#   setup.sh --repo OWNER/NAME
#
# Owner-specific values can be overridden via environment variables:
#   PR_AUTO_MERGER_CLIENT_ID         (default: Iv23liInIOSVmvfZicez)
#   PR_AUTO_MERGER_PRIVATE_KEY_PATH  (default: ~/Dropbox/Personal/secrets/pull-request-auto-merging-bot.private-key.pem)

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

CLIENT_ID="${PR_AUTO_MERGER_CLIENT_ID:-Iv23liInIOSVmvfZicez}"
KEY_PATH="${PR_AUTO_MERGER_PRIVATE_KEY_PATH:-$HOME/Dropbox/Personal/secrets/pull-request-auto-merging-bot.private-key.pem}"

echo "==> Updating repository settings"
gh api "repos/${REPO}" \
  --method PATCH \
  --field allow_auto_merge=true \
  --field delete_branch_on_merge=true

echo "==> Creating base branch protection ruleset"
gh api "repos/${REPO}/rulesets" --method POST --input - <<'JSON'
{
  "name": "branch-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "required_status_checks": [
          {"context": "actionlint"},
          {"context": "zizmor"}
        ],
        "strict_required_status_checks_policy": false
      }
    }
  ]
}
JSON

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
gh variable set PR_AUTO_MERGER_CLIENT_ID --body "$CLIENT_ID" --repo "$REPO"
gh secret set PR_AUTO_MERGER_PRIVATE_KEY \
  --body "$(cat "$KEY_PATH")" \
  --repo "$REPO"
gh secret set PR_AUTO_MERGER_PRIVATE_KEY --app dependabot \
  --body "$(cat "$KEY_PATH")" \
  --repo "$REPO"

echo "==> setup-github-workflows prerequisites done: ${REPO}"
