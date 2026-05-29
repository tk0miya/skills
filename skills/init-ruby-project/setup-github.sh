#!/usr/bin/env bash
# Usage:
#   setup-github.sh --project-name NAME --visibility public|private
#   setup-github.sh --project-name NAME --visibility public|private --ruby-versions "3.2 3.3 3.4"
#
# --ruby-versions を指定すると gem 向けの設定（複数 Ruby バージョンの CI チェック）になる。
# 省略した場合は非 gem 向けの設定（"test" チェックのみ）になる。

set -euo pipefail

usage() {
  echo "Usage: $0 --project-name NAME --visibility public|private [--ruby-versions '3.2 3.3 3.4']"
  exit 1
}

PROJECT_NAME=""
VISIBILITY=""
RUBY_VERSIONS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name)   PROJECT_NAME="$2";   shift 2 ;;
    --visibility)     VISIBILITY="$2";     shift 2 ;;
    --ruby-versions)  RUBY_VERSIONS="$2";  shift 2 ;;
    *) usage ;;
  esac
done

[[ -z "$PROJECT_NAME" || -z "$VISIBILITY" ]] && usage

REPO="tk0miya/${PROJECT_NAME}"

echo "==> Creating GitHub repository: ${REPO} (${VISIBILITY})"
gh repo create "$PROJECT_NAME" "--${VISIBILITY}" --source=. --push

echo "==> Creating branch ruleset"
if [[ -n "$RUBY_VERSIONS" ]]; then
  STATUS_CHECKS=$(echo "$RUBY_VERSIONS" | tr ' ' '\n' | jq -R '{"context": ("Ruby " + .)}' | jq -s '. + [{"context": "actionlint"}, {"context": "zizmor"}]')
else
  STATUS_CHECKS='[{"context": "test"}, {"context": "actionlint"}, {"context": "zizmor"}]'
fi

jq -n --argjson checks "$STATUS_CHECKS" '{
  name: "main",
  target: "branch",
  enforcement: "active",
  conditions: {
    ref_name: {
      include: ["~DEFAULT_BRANCH"],
      exclude: []
    }
  },
  rules: [
    {type: "deletion"},
    {type: "non_fast_forward"},
    {
      type: "pull_request",
      parameters: {
        required_approving_review_count: 0,
        dismiss_stale_reviews_on_push: false,
        require_code_owner_review: false,
        require_last_push_approval: false,
        required_review_thread_resolution: false
      }
    },
    {
      type: "required_status_checks",
      parameters: {
        required_status_checks: $checks,
        strict_required_status_checks_policy: false
      }
    }
  ]
}' | gh api "repos/${REPO}/rulesets" --method POST --input -

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
  --body "$(cat ~/Dropbox/Personal/secrets/repo-housekeeper.private-key.pem)" \
  --repo "$REPO"

echo "==> Done: ${REPO}"
