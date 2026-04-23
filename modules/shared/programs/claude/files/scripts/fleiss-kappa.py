#!/usr/bin/env python3
"""Run-DA Arbiter selective consistency harness.

v1: Compute vote-shape (3:0/2:1/1:1:1) and stability_status from N Arbiter result
markdown files. Each file must contain VERDICT_JSON blocks with per-finding verdicts
as defined in arbiter-prompt.md "출력 형식" section.

With --offline flag, also compute corpus-level Fleiss' kappa across findings
(Fleiss 1971, chance-corrected agreement among N raters on categorical verdicts).

Threshold policy single source: stability-measurement.md.

Usage:
    fleiss-kappa.py <arbiter1.md> <arbiter2.md> <arbiter3.md> [--offline]

Output: JSON on stdout. See main() for schema.
"""

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

# 단일 진실 원천 (stability-measurement.md와 동기화)
STABLE_MIN = 0.6
ESCALATE_MIN = 0.4

VERDICT_CATEGORIES = ("CONFIRMED_ISSUE", "NOT_AN_ISSUE", "NEEDS_MORE_INFO")

# arbiter-prompt.md "출력 형식 > 기계 파싱용 VERDICT_JSON 블록" 스키마와 일치
VERDICT_JSON_PATTERN = re.compile(
    r"<!-- verdict-json:start -->\s*```json\s*(?P<body>.+?)\s*```\s*<!-- verdict-json:end -->",
    re.DOTALL,
)


def parse_verdict_json_blocks(markdown_path: Path) -> dict:
    """Parse VERDICT_JSON blocks from Arbiter result markdown.

    Returns dict mapping finding_id -> verdict entry dict.
    Malformed JSON blocks are skipped with a warning on stderr.
    """
    text = markdown_path.read_text(encoding="utf-8")
    entries = {}
    for match in VERDICT_JSON_PATTERN.finditer(text):
        raw = match.group("body")
        try:
            entry = json.loads(raw)
        except json.JSONDecodeError as exc:
            print(
                f"warning: malformed VERDICT_JSON in {markdown_path}: {exc}",
                file=sys.stderr,
            )
            continue
        finding_id = entry.get("finding_id")
        if not finding_id:
            print(
                f"warning: VERDICT_JSON without finding_id in {markdown_path}",
                file=sys.stderr,
            )
            continue
        entries[finding_id] = entry
    return entries


def classify_vote_shape(verdicts):
    """Classify verdicts into vote-shape and stability_status.

    Args:
        verdicts: list of verdict strings (each in VERDICT_CATEGORIES)

    Returns:
        (vote_shape, majority_verdict, stability_status)
        - 3:0 → stable (majority_verdict is the unanimous verdict)
        - 2:1 → split (majority_verdict is the majority)
        - 1:1:1 → fragmented (majority_verdict is None)
        Non-N=3 inputs fall through to "unknown".
    """
    counts = Counter(verdicts)
    sorted_counts = sorted(counts.values(), reverse=True)
    if sorted_counts == [3]:
        # "3:0" 표기로 통일 (stability-measurement.md와 일치).
        return "3:0", counts.most_common(1)[0][0], "stable"
    if sorted_counts == [2, 1]:
        return "2:1", counts.most_common(1)[0][0], "split"
    if sorted_counts == [1, 1, 1]:
        return "1:1:1", None, "fragmented"
    # N ≠ 3 이거나 unexpected shape (e.g., N=2, N=4). 정책 범위 밖.
    return ":".join(str(c) for c in sorted_counts), None, "unknown"


def fleiss_kappa(findings):
    """Compute Fleiss' kappa for N raters per item, across multiple items.

    Fleiss 1971, "Measuring Nominal Scale Agreement among Many Raters".

    Args:
        findings: list of per-item verdict lists. Each inner list has N verdicts
                  (raters), all drawn from VERDICT_CATEGORIES.

    Returns:
        kappa in [-1, 1]. Returns float('nan') if ill-defined:
        - empty input
        - fewer than 2 raters
        - unanimous marginal distribution (P_e == 1)

    Raises:
        ValueError if rater counts differ across items.
    """
    if not findings:
        return float("nan")

    n_raters = len(findings[0])
    if any(len(f) != n_raters for f in findings):
        raise ValueError("all findings must have the same number of raters")
    if n_raters < 2:
        return float("nan")

    n_items = len(findings)

    # n_ij: rater count matrix (item i, category j)
    n_ij = []
    for verdicts in findings:
        row = [verdicts.count(cat) for cat in VERDICT_CATEGORIES]
        n_ij.append(row)

    # p_j: marginal proportion of category j across all ratings
    total_ratings = n_items * n_raters
    p_j = [
        sum(row[j] for row in n_ij) / total_ratings
        for j in range(len(VERDICT_CATEGORIES))
    ]

    # P_i: agreement proportion on item i
    P_i = []
    for row in n_ij:
        squared_sum = sum(count * count for count in row)
        P_i.append((squared_sum - n_raters) / (n_raters * (n_raters - 1)))

    P_bar = sum(P_i) / n_items
    P_e = sum(p * p for p in p_j)

    if P_e == 1.0:
        return float("nan")
    return (P_bar - P_e) / (1 - P_e)


def interpret_kappa(kappa):
    """Map kappa to interpretation label using stability-measurement.md thresholds.

    Returns "undefined" for NaN, "stable"/"moderate"/"poor" otherwise.
    """
    if kappa != kappa:  # NaN check without importing math
        return "undefined"
    if kappa >= STABLE_MIN:
        return "stable"
    if kappa >= ESCALATE_MIN:
        return "moderate"
    return "poor"


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Run-DA Arbiter selective consistency harness. "
            "Aggregates vote-shape across N Arbiter result markdown files; "
            "optionally computes offline Fleiss kappa for corpus-level observation."
        ),
    )
    parser.add_argument(
        "arbiter_files",
        nargs="+",
        type=Path,
        help="N Arbiter result markdown files containing VERDICT_JSON blocks",
    )
    parser.add_argument(
        "--offline",
        action="store_true",
        help=(
            "Also compute corpus-level Fleiss kappa (offline observation only; "
            "not a v1 runtime gate — see stability-measurement.md)"
        ),
    )
    args = parser.parse_args()

    arbiter_entries = [parse_verdict_json_blocks(p) for p in args.arbiter_files]
    all_finding_ids = set()
    for entries in arbiter_entries:
        all_finding_ids.update(entries.keys())

    per_finding = []
    missing = {}
    for fid in sorted(all_finding_ids):
        verdicts = []
        missing_indices = []
        for i, entries in enumerate(arbiter_entries):
            entry = entries.get(fid)
            v = entry.get("verdict") if entry else None
            if v in VERDICT_CATEGORIES:
                verdicts.append(v)
            else:
                missing_indices.append(i)
        if missing_indices:
            # Fail-closed: any Arbiter missing a verdict for this finding excludes it
            # from vote-shape classification. protocol.md는 이 경우를 partial_failure로
            # 처리하며, AskUser 미지원 런타임에서는 BLOCKED 상태 지정.
            missing[fid] = {
                "missing_arbiter_indices": missing_indices,
                "partial_verdicts": verdicts,
            }
            continue
        shape, majority, status = classify_vote_shape(verdicts)
        per_finding.append(
            {
                "finding_id": fid,
                "verdicts": verdicts,
                "vote_shape": shape,
                "majority_verdict": majority,
                "stability_status": status,
            }
        )

    result = {
        "n_arbiters": len(args.arbiter_files),
        "n_findings": len(all_finding_ids),
        "n_classified": len(per_finding),
        "per_finding": per_finding,
    }

    if missing:
        result["missing"] = missing
        result["partial_failure"] = True

    if args.offline:
        # Fleiss kappa is a corpus-level metric (requires ≥2 items to be meaningful).
        # See stability-measurement.md: v1에서 kappa는 offline 관찰 전용.
        complete_verdict_matrix = [f["verdicts"] for f in per_finding]
        if len(complete_verdict_matrix) >= 2:
            kappa = fleiss_kappa(complete_verdict_matrix)
            result["kappa"] = kappa
            result["kappa_interpretation"] = interpret_kappa(kappa)
        else:
            result["kappa"] = None
            result["kappa_interpretation"] = "insufficient_items"
        result["kappa_thresholds"] = {
            "STABLE_MIN": STABLE_MIN,
            "ESCALATE_MIN": ESCALATE_MIN,
        }

    json.dump(result, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
