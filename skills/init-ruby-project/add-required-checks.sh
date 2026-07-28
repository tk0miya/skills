#!/usr/bin/env bash
# Ensures a branch ruleset named "main" exists on the repository with the base
# protection rules, and that the given status check contexts are required by it.
# A new one is created against the default branch; an existing one is taken as
# is, so whichever refs it covers are the refs that end up protected.
#
# Creating and appending are one operation because the GitHub API has no
# "append a rule" endpoint: PUT /rulesets/{id} replaces the whole rules array,
# so adding a context means read-modify-write. The contexts are then unioned in,
# which makes every call additive and idempotent.
#
# On an existing ruleset, parameters already set on a rule are left alone (they
# may have been tuned by hand); only missing base rules and missing contexts are
# added.
#
# Usage:
#   add-required-checks.sh --repo OWNER/NAME [--add-check CONTEXT]...
#
# A context is the status check name GitHub reports: a job's `name:` if it has
# one, otherwise its job id, with matrix jobs expanded. Repeat --add-check so a
# name containing a comma still works. Copy it from the workflow as written, and
# only for jobs that always run and always report on a pull request -- not
# release-only workflows, not jobs gated by paths/if:, not workflows with a
# narrowed types:. A name that is never reported leaves every pull request
# pending, and there is no way to remove one here.

set -euo pipefail

usage() {
  echo "Usage: $0 --repo OWNER/NAME [--add-check CONTEXT]..."
  exit 1
}

REPO=""
CHECKS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)       REPO="$2";      shift 2 ;;
    --add-check)  CHECKS+=("$2"); shift 2 ;;
    *) usage ;;
  esac
done

[[ -z "$REPO" ]] && usage

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

RULESET_NAME="main"

BASE_RULES='[
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
      "required_status_checks": [],
      "strict_required_status_checks_policy": false
    }
  }
]'

# Adds any missing base rule, then unions the given contexts into
# required_status_checks. Keeps the parameters of rules that already exist.
RECONCILE='
  (.rules | map(.type)) as $have
  | .rules += ($base | map(select((.type | IN($have[])) | not)))
  | .rules |= map(
      if .type == "required_status_checks" then
        .parameters.required_status_checks =
          ((.parameters.required_status_checks
            + ($ARGS.positional | map(select(. != "")) | map({context: .})))
           | unique_by(.context))
      else . end)
'

# --paginate emits one array per page; jq -s + flatten merges them.
# includes_parents=false: org/enterprise rulesets are not ours to update, and a
# same-named parent would make the repo-scoped GET/PUT below 404.
RULESETS=$(gh api --paginate "repos/${REPO}/rulesets?includes_parents=false" | jq -s 'flatten')
ID=$(jq -r --arg n "$RULESET_NAME" \
  'map(select(.name == $n and .target == "branch")) | .[0].id // ""' <<<"$RULESETS")

# Rulesets are matched by name, so another active one may gate pull requests
# alongside this one. Say so and carry on rather than guessing which is meant.
OTHERS=$(jq -r --arg n "$RULESET_NAME" \
  'map(select(.target == "branch" and .enforcement == "active" and .name != $n))
   | .[].name' <<<"$RULESETS")
[[ -z "$OTHERS" ]] \
  || echo "WARNING: other active branch rulesets may also gate pull requests:" \
          "${OTHERS//$'\n'/, }" >&2

if [[ -z "$ID" ]]; then
  echo "==> Creating ${RULESET_NAME} ruleset"
  RESULT=$(jq -n --arg name "$RULESET_NAME" --argjson base "$BASE_RULES" "
    {
      name: \$name,
      target: \"branch\",
      enforcement: \"active\",
      conditions: { ref_name: { include: [\"~DEFAULT_BRANCH\"], exclude: [] } },
      rules: []
    } | ${RECONCILE}
    " --args "${CHECKS[@]+"${CHECKS[@]}"}" \
    | gh api "repos/${REPO}/rulesets" --method POST --input -)
else
  echo "==> Adding required status checks to ${RULESET_NAME}"
  EXISTING=$(gh api "repos/${REPO}/rulesets/${ID}")
  RESULT=$(jq --argjson base "$BASE_RULES" "
      ${RECONCILE}
      # PUT takes only the writable fields; drop id, _links and friends. Carry
      # bypass_actors over so a hand-configured bypass list is not cleared.
      | {name, target, enforcement, conditions, rules}
        + (if has(\"bypass_actors\") then {bypass_actors} else {} end)
      " --args "${CHECKS[@]+"${CHECKS[@]}"}" <<<"$EXISTING" \
    | gh api "repos/${REPO}/rulesets/${ID}" --method PUT --input -)
fi

ENFORCEMENT=$(jq -r '.enforcement' <<<"$RESULT")
if [[ "$ENFORCEMENT" != "active" ]]; then
  echo "WARNING: ${RULESET_NAME} enforcement is '${ENFORCEMENT}'; the checks below are not enforced" >&2
fi

echo "==> ${RULESET_NAME} required checks:"
jq -r '.rules[] | select(.type == "required_status_checks")
       | .parameters.required_status_checks[].context | "    - " + .' <<<"$RESULT"
