#!/usr/bin/env bash
# Usage:
#   setup-github.sh --project-name NAME --visibility public|private

set -euo pipefail

usage() {
  echo "Usage: $0 --project-name NAME --visibility public|private"
  exit 1
}

PROJECT_NAME=""
VISIBILITY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name)  PROJECT_NAME="$2";  shift 2 ;;
    --visibility)    VISIBILITY="$2";    shift 2 ;;
    *) usage ;;
  esac
done

[[ -z "$PROJECT_NAME" || -z "$VISIBILITY" ]] && usage

REPO="tk0miya/${PROJECT_NAME}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Creating GitHub repository: ${REPO} (${VISIBILITY})"
gh repo create "$PROJECT_NAME" "--${VISIBILITY}" --source=. --push

echo "==> Creating branch ruleset"
gh api "repos/${REPO}/rulesets" --method POST --input "${SCRIPT_DIR}/ruleset.json"

echo "==> Updating repository settings"
gh api "repos/${REPO}" \
  --method PATCH \
  --field allow_auto_merge=true \
  --field delete_branch_on_merge=true

echo "==> Creating labels"
gh label create "auto-merge" --color "0075ca" --description "Automatically merge this PR" --repo "$REPO"

echo "==> Enabling Dependabot"
gh api "repos/${REPO}/vulnerability-alerts" --method PUT
gh api "repos/${REPO}/automated-security-fixes" --method PUT

echo "==> Granting GitHub Actions permission to approve PRs"
gh api "repos/${REPO}/actions/permissions/workflow" \
  --method PUT \
  --field can_approve_pull_request_reviews=true

echo "==> Setting up PR_AUTO_MERGER"
gh variable set PR_AUTO_MERGER_APP_ID --body "1239986" --repo "$REPO"
gh secret set PR_AUTO_MERGER_PRIVATE_KEY \
  --body "$(cat ~/Dropbox/Personal/secrets/pull-request-auto-merging-bot.private-key.pem)" \
  --repo "$REPO"
gh secret set PR_AUTO_MERGER_PRIVATE_KEY --app dependabot \
  --body "$(cat ~/Dropbox/Personal/secrets/pull-request-auto-merging-bot.private-key.pem)" \
  --repo "$REPO"

echo "==> Setting up REPO_HOUSEKEEPER"
gh variable set REPO_HOUSEKEEPER_APP_ID --body "412513" --repo "$REPO"
gh secret set REPO_HOUSEKEEPER_PRIVATE_KEY \
  --body "$(cat ~/Dropbox/Personal/secrets/rbs_collection_updater.private-key.pem)" \
  --repo "$REPO"

echo "==> Done: ${REPO}"
