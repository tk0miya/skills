#!/bin/bash
#
# Append the findings a self-review reported to the log, and read the log back.
#
# Usage:
#   log.sh finding [<repo-path>] --category C --reference F --perspective P \
#                                --finding TEXT --basis TEXT
#   log.sh report  [<repo-path>] [--since YYYY-MM-DD]
#
# The rounds are recorded by round.sh, which is what spends one; a finding is tied to the round
# it was reported in through the id round.sh left in its state file. A finding logged with no
# round state -- the file removed, or a review run without counting a round -- is still recorded,
# only ungrouped: refusing the finding would lose the thing worth keeping to protect bookkeeping.
#
# `report` is why the log is worth writing. Read as lines it answers nothing: whether a
# perspective keeps coming up is a share of the rounds, and whether the caller keeps passing on a
# finding is the same finding appearing under two rounds against one commit.
#
# The log is one JSON object per line in the repository's common git dir, so nothing has to be set
# up per project. In the work tree it would sit there as an uncommitted change until every project
# added an ignore entry, and the next review would start reporting on the log itself. The trade is
# that the log is local to the clone, which is the scope it is for -- looking back over the reviews
# done in one working environment.
#
# jq builds every line, and the line is captured before it is appended: JSON assembled by hand
# breaks on the first quote or newline in a finding, and a jq that failed while writing straight
# to the log would leave a half-written line that makes every line after it unreadable too.
#
# Fields stay the five the log started with, plus the type, the round id, and the perspective
# file. The file is there because a heading alone collides -- `Correctness` is in most of the
# perspective files, and without knowing which one, the counts merge into a bucket that says
# nothing about which perspective to work on. Nothing else is added: the target file and the
# branch were both left out on purpose, and the commit a round ran against is on the round.
#
# Lines written before the log recorded rounds carry no `type` and no `round_id`. They are read
# as findings, and left out of anything counted per round, which `report` says when it prints.

set -euo pipefail

die() { echo "log.sh: $*" >&2; exit 1; }

# A flag whose value is missing must not reach `shift 2`: shifting past the end fails, and under
# `set -e` that exits without a word. A record silently not written is the one failure this log
# cannot report on itself, since `report` can only count the lines that exist.
need() { [[ "$2" -ge 2 ]] || die "$1 takes a value"; }

usage() {
  cat >&2 <<'EOF'
Usage:
  log.sh finding [<repo-path>] --category C --reference F --perspective P \
                               --finding TEXT --basis TEXT
  log.sh report  [<repo-path>] [--since YYYY-MM-DD]
EOF
  exit 1
}

command -v jq >/dev/null 2>&1 || die "jq is required"

cmd="${1:-}"
[[ -n "$cmd" ]] || usage
shift

# The repository path is positional and optional, as it is for round.sh.
work_dir="."
if [[ $# -gt 0 && "$1" != --* ]]; then
  work_dir="$1"
  shift
fi

# The log is common to the repository, so worktrees of one repository share one history. The
# round state is per worktree, which is where round.sh keeps its budget.
common_dir=$(git -C "$work_dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) ||
  die "not a git repository: $work_dir"
log_file="$common_dir/self-review-log.jsonl"

case "$cmd" in
  finding)
    category=""
    reference=""
    perspective=""
    finding=""
    basis=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --category) need --category $#; category="$2"; shift 2 ;;
        --reference) need --reference $#; reference="$2"; shift 2 ;;
        --perspective) need --perspective $#; perspective="$2"; shift 2 ;;
        --finding) need --finding $#; finding="$2"; shift 2 ;;
        --basis) need --basis $#; basis="$2"; shift 2 ;;
        *) usage ;;
      esac
    done
    for required in category reference perspective finding basis; do
      [[ -n "${!required}" ]] || die "--$required is required"
    done

    # Fourth line of round.sh's state file. Absent on state written before rounds were recorded,
    # which leaves the finding ungrouped rather than unrecorded.
    round_state="$(git -C "$work_dir" rev-parse --absolute-git-dir)/self-review-rounds"
    round_id=""
    # An `if`, not `[[ -f ... ]] && round_id=...`: that form returns the test's status, which under
    # `set -e` exits the moment this lands anywhere its status is the last one -- and losing the
    # finding is the failure this whole branch exists to avoid.
    if [[ -f "$round_state" ]]; then
      round_id=$(sed -n 4p "$round_state")
    fi

    line=$(jq -c -n \
      --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg round_id "$round_id" \
      --arg category "$category" \
      --arg reference "$reference" \
      --arg perspective "$perspective" \
      --arg finding "$finding" \
      --arg basis "$basis" \
      '{
         type: "finding",
         timestamp: $timestamp,
         round_id: (if $round_id == "" then null else $round_id end),
         category: $category,
         reference: $reference,
         perspective: $perspective,
         finding: $finding,
         basis: $basis
       }') || die "could not build the record"
    printf '%s\n' "$line" >> "$log_file"
    ;;

  report)
    since=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --since) need --since $#; since="$2"; shift 2 ;;
        *) usage ;;
      esac
    done
    [[ -f "$log_file" ]] || die "nothing recorded yet ($log_file)"

    # Counts lead each line rather than being laid out in columns: the perspective names are
    # Japanese, and padding them by character count misplaces the column anyway.
    jq -s -r --arg since "$since" '
      def origin: (.reference // "(観点ファイル不明)") + "  " + (.perspective // "(見出し不明)");
      # Distinct rounds in a group of findings, counting only rounds the log actually recorded:
      # lines older than the round records carry no round_id, and a round_id whose round record is
      # missing names a round nothing is known about. Counting either would contradict the note
      # printed at the end, which says those lines stay out of the per-round figures.
      def rounds($h): map(select(.round_id != null and $h[.round_id] != null))
                      | map(.round_id) | unique | length;
      # "initial-commit" is the sentinel round.sh records before the first commit, not a sha.
      def short: if . == "initial-commit" then . else .[0:7] end;

      [ .[] | .type = (.type // "finding") ]
      | map(select($since == "" or (.timestamp // "") >= $since))                    as $all
      | ($all | map(select(.type == "round")))                                       as $round_records
      | ($all | map(select(.type == "finding")))                                     as $findings
      | ($round_records | map({key: .round_id, value: .head}) | from_entries)        as $head_of
      # Both shapes of "no round to attach to": no round_id at all, and a round_id whose round
      # record is missing, which is what a failed round append leaves behind.
      | ($findings | map(select(.round_id == null or $head_of[.round_id] == null)) | length)
                                                                                     as $ungrouped

      | [ "log: \($all | length) 行" + (if $since == "" then "" else "  (\($since) 以降)" end),
          "rounds: \($round_records | length)"
            + (if ($round_records | length) > 0
               then "  (指摘を報告した回 \($findings | rounds($head_of)))"
               else "" end),
          "findings: \($findings | length)",
          "" ]

      + (if ($findings | length) == 0 then [] else
          [ "区分別:" ]
          + ($findings | group_by(.category) | sort_by(-length)
             | map("  \(length)  \(.[0].category)"))
          + [ "" ]
        end)

      + (if ($findings | length) == 0 then [] else
          [ "観点別 (指摘数 / 上がったラウンド数):" ]
          + ($findings | group_by(origin) | sort_by(-length)
             | map("  \(length) / \(rounds($head_of))  \(.[0] | origin)"))
          + [ "" ]
        end)

      + (($findings
          | map(select(.round_id != null and $head_of[.round_id] != null))
          | group_by([$head_of[.round_id], (. | origin)])
          # Rounds, not findings: two findings from one perspective in a single review say nothing
          # about repetition. A perspective coming back while HEAD has not moved keeps finding
          # something in this change, which is not the same claim as the caller having passed --
          # the fixes for one round routinely expose the next finding from the same perspective.
          # Only the same finding coming back says it was passed on, and that is marked per
          # finding below.
          | map(select(rounds($head_of) > 1))
          | sort_by(-rounds($head_of))) as $repeats
         | if ($repeats | length) == 0 then [] else
             [ "同じコミットで複数ラウンド上がった観点:" ]
             + ($repeats | map(
                 "  \(rounds($head_of)) ラウンド  \(.[0] | origin)  [\($head_of[.[0].round_id] | short)]"
                 , (group_by(.finding)
                    | map("      - " + .[0].finding
                          + (if rounds($head_of) > 1 then "  ← 再提示 (呼び出し元が見送った)" else "" end))
                    | .[])))
             + [ "" ]
           end)

      + (if $ungrouped == 0 then [] else
           [ "\($ungrouped) 行はラウンドに紐付いておらず、ラウンド単位の集計には入らない。" ]
         end)

      | .[]
    ' "$log_file"
    ;;

  *) usage ;;
esac
