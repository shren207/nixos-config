#!/usr/bin/env bash
# measure-anchoring-bias.sh
#
# Measure plan-with-questions anchoring-bias signals across Claude Code
# transcripts on Mac local + MiniPC.
#
# 4-axis grep (codex:rescue meta-consultation recommendation):
#   1. user choice capture
#   2. recommendation framing
#   3. post-hoc defect
#   4. redesign resistance
#
# Output: per-host candidate session counts + intersection metrics.
# Hardcoded numbers are forbidden in skill docs — this script is the SSOT.
#
# Usage:
#   ./scripts/ai/measure-anchoring-bias.sh             # default mtime=-60
#   ./scripts/ai/measure-anchoring-bias.sh -d 30       # mtime=-30
#   ./scripts/ai/measure-anchoring-bias.sh --skip-ssh  # local only
#   ./scripts/ai/measure-anchoring-bias.sh --json      # JSON output
#
# Exit 0 always (best-effort metric collection).

set -uo pipefail

# Defaults
DAYS="60"
SKIP_SSH=0
JSON=0
SSH_HOST="minipc"

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--days) DAYS="$2"; shift 2 ;;
        --skip-ssh) SKIP_SSH=1; shift ;;
        --json) JSON=1; shift ;;
        --ssh-host) SSH_HOST="$2"; shift 2 ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

# 4-axis grep patterns (read from plan-with-questions/references/bias-measurement.md SSOT)
PAT_CHOICE='사용자 결정|사용자 확인 완료|선호|선택|추천|A 방식|B 방식|어느 쪽|AskUserQuestion|충분|인지'
PAT_FRAMING='추천|권장|기본값|best|Recommended|강력히'
PAT_DEFECT='DA Round|CONFIRMED_ISSUE|NEEDS_MORE_INFO|YAGNI|NGMI|REGRESSION|overbuilt|missing|conflicting|parallel-audit|review-implementation'
PAT_RESISTANCE='사용자 결정에 따라|현상 유지|기각|생략|그래도|재설계.*거부|redesign.*reject|추천대로'

# Per-host measurement
measure_host() {
    local host_label="$1"
    local exec_prefix="$2"  # empty for local, "ssh $SSH_HOST" for remote

    local total
    if [ -z "$exec_prefix" ]; then
        total=$(find "$HOME/.claude/projects" -name '*.jsonl' -mtime "-${DAYS}" 2>/dev/null | wc -l | tr -d ' ')
    else
        total=$($exec_prefix "find ~/.claude/projects -name '*.jsonl' -mtime -${DAYS} 2>/dev/null | wc -l" 2>/dev/null | tr -d ' ')
    fi

    if [ -z "$total" ] || [ "$total" = "0" ]; then
        echo "${host_label}|total=0|skip"
        return
    fi

    # Count files matching each axis
    local count_choice count_framing count_defect count_resistance
    local count_choice_and_defect count_anchoring_candidate

    if [ -z "$exec_prefix" ]; then
        count_choice=$(find "$HOME/.claude/projects" -name '*.jsonl' -mtime "-${DAYS}" -print0 2>/dev/null | xargs -0 rg -l -e "$PAT_CHOICE" 2>/dev/null | wc -l | tr -d ' ')
        count_framing=$(find "$HOME/.claude/projects" -name '*.jsonl' -mtime "-${DAYS}" -print0 2>/dev/null | xargs -0 rg -l -e "$PAT_FRAMING" 2>/dev/null | wc -l | tr -d ' ')
        count_defect=$(find "$HOME/.claude/projects" -name '*.jsonl' -mtime "-${DAYS}" -print0 2>/dev/null | xargs -0 rg -l -e "$PAT_DEFECT" 2>/dev/null | wc -l | tr -d ' ')
        count_resistance=$(find "$HOME/.claude/projects" -name '*.jsonl' -mtime "-${DAYS}" -print0 2>/dev/null | xargs -0 rg -l -e "$PAT_RESISTANCE" 2>/dev/null | wc -l | tr -d ' ')
        # intersection: files matching both choice AND defect (rg -l prints newline-separated paths; second xargs reads them — we accept legacy line-based pipe here since rg -l output for jsonl fixture paths has no whitespace)
        count_choice_and_defect=$(find "$HOME/.claude/projects" -name '*.jsonl' -mtime "-${DAYS}" -print0 2>/dev/null | xargs -0 rg -l -e "$PAT_CHOICE" 2>/dev/null | tr '\n' '\0' | xargs -0 rg -l -e "$PAT_DEFECT" 2>/dev/null | wc -l | tr -d ' ')
        # full anchoring candidate: choice + framing + defect + resistance
        count_anchoring_candidate=$(find "$HOME/.claude/projects" -name '*.jsonl' -mtime "-${DAYS}" -print0 2>/dev/null | xargs -0 rg -l -e "$PAT_CHOICE" 2>/dev/null | tr '\n' '\0' | xargs -0 rg -l -e "$PAT_FRAMING" 2>/dev/null | tr '\n' '\0' | xargs -0 rg -l -e "$PAT_DEFECT" 2>/dev/null | tr '\n' '\0' | xargs -0 rg -l -e "$PAT_RESISTANCE" 2>/dev/null | wc -l | tr -d ' ')
    else
        # Remote execution — pass patterns via env
        local remote_cmd
        remote_cmd="cd ~/.claude/projects && \
            CHOICE=\$(find . -name '*.jsonl' -mtime -${DAYS} -print0 2>/dev/null | xargs -0 rg -l -e \"$PAT_CHOICE\" 2>/dev/null | wc -l | tr -d ' ') && \
            FRAMING=\$(find . -name '*.jsonl' -mtime -${DAYS} -print0 2>/dev/null | xargs -0 rg -l -e \"$PAT_FRAMING\" 2>/dev/null | wc -l | tr -d ' ') && \
            DEFECT=\$(find . -name '*.jsonl' -mtime -${DAYS} -print0 2>/dev/null | xargs -0 rg -l -e \"$PAT_DEFECT\" 2>/dev/null | wc -l | tr -d ' ') && \
            RESIST=\$(find . -name '*.jsonl' -mtime -${DAYS} -print0 2>/dev/null | xargs -0 rg -l -e \"$PAT_RESISTANCE\" 2>/dev/null | wc -l | tr -d ' ') && \
            CHOICE_AND_DEFECT=\$(find . -name '*.jsonl' -mtime -${DAYS} -print0 2>/dev/null | xargs -0 rg -l -e \"$PAT_CHOICE\" 2>/dev/null | tr '\n' '\0' | xargs -0 rg -l -e \"$PAT_DEFECT\" 2>/dev/null | wc -l | tr -d ' ') && \
            ANCHOR=\$(find . -name '*.jsonl' -mtime -${DAYS} -print0 2>/dev/null | xargs -0 rg -l -e \"$PAT_CHOICE\" 2>/dev/null | tr '\n' '\0' | xargs -0 rg -l -e \"$PAT_FRAMING\" 2>/dev/null | tr '\n' '\0' | xargs -0 rg -l -e \"$PAT_DEFECT\" 2>/dev/null | tr '\n' '\0' | xargs -0 rg -l -e \"$PAT_RESISTANCE\" 2>/dev/null | wc -l | tr -d ' ') && \
            echo \"\$CHOICE \$FRAMING \$DEFECT \$RESIST \$CHOICE_AND_DEFECT \$ANCHOR\""
        local result
        result=$(eval "$exec_prefix \"$remote_cmd\"" 2>/dev/null)
        if [ -z "$result" ]; then
            echo "${host_label}|total=${total}|ssh-failed"
            return
        fi
        read -r count_choice count_framing count_defect count_resistance count_choice_and_defect count_anchoring_candidate <<< "$result"
    fi

    if [ $JSON -eq 1 ]; then
        printf '{"host":"%s","days":%s,"total":%s,"choice":%s,"framing":%s,"defect":%s,"resistance":%s,"choice_and_defect":%s,"anchoring_candidate":%s}\n' \
            "$host_label" "$DAYS" "$total" "$count_choice" "$count_framing" "$count_defect" "$count_resistance" "$count_choice_and_defect" "$count_anchoring_candidate"
    else
        echo "${host_label} (mtime=-${DAYS}d)"
        echo "  total transcripts:           ${total}"
        echo "  axis-1 choice:               ${count_choice}"
        echo "  axis-2 recommendation:       ${count_framing}"
        echo "  axis-3 post-hoc defect:      ${count_defect}"
        echo "  axis-4 redesign resistance:  ${count_resistance}"
        echo "  intersect choice ∩ defect:   ${count_choice_and_defect}"
        echo "  full anchoring candidate:    ${count_anchoring_candidate}"
        if [ "$total" -gt 0 ]; then
            local pct
            pct=$(awk "BEGIN { printf \"%.1f\", ($count_choice_and_defect / $total) * 100 }")
            echo "  choice_then_defect_rate:     ${pct}%"
        fi
    fi
}

if [ $JSON -eq 1 ]; then
    echo "["
    measure_host "mac" ""
    if [ $SKIP_SSH -eq 0 ]; then
        echo ","
        measure_host "${SSH_HOST}" "ssh ${SSH_HOST}"
    fi
    echo "]"
else
    echo "=== Anchoring-bias signal measurement ==="
    echo ""
    measure_host "mac" ""
    if [ $SKIP_SSH -eq 0 ]; then
        echo ""
        measure_host "${SSH_HOST}" "ssh ${SSH_HOST}"
    fi
    echo ""
    echo "Notes:"
    echo "  - Counts are file-level (any line match within a transcript)."
    echo "  - 'anchoring candidate' requires all 4 axes in the same file —"
    echo "    strong signal but excludes legitimate plans where only some"
    echo "    axes appear (still informative as a lower bound)."
    echo "  - For line-ordering analysis (choice line BEFORE defect line),"
    echo "    extend with awk/jq — out of scope for this script."
fi
