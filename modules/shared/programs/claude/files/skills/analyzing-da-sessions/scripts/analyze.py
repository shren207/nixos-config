#!/usr/bin/env python3
"""DA 세션 정량 분석 — analyzing-da-sessions Skill의 algorithm SSOT.

PR #670 정정 코멘트의 v2 알고리즘 (분모 정정 + 4-tier fallback + source/confidence 라벨링)
+ severity 전이 (analyze-da-sessions.py:231-248) + StabilitySource resolver (fleiss-kappa.py)
를 통합한 단일 진입점.

Internal boundary (plan D-12):
  1. constants/enums          — VERDICT_CATEGORIES, BUNDLE_MAP, MARKER_REGEX, VERDICT_JSON_BLOCK 등
  2. jsonl payload walker     — extract_text_payloads
  3. finding_id normalizer    — get_bundle, normalize_finding_id
  4. verdict parser pipeline  — extract_strict_verdicts, extract_unmarked_json_verdicts,
                                 extract_kv_verdicts, extract_nl_summary
  5. severity transition extractor — extract_severities_per_finding, severity_rank,
                                      compute_severity_transitions
  6. stability source resolver — resolve_stability_status (fleiss-kappa.py | round summary | unavailable)
  7. aggregate builder        — analyze_session, build_aggregate
  8. markdown renderer        — render_markdown
  9. json renderer            — render_json
  Host handling                — collect_host_files, subprocess.run with fixed argv

CLI:
  --hosts <comma list>     default: mac,minipc. whitelist {mac, minipc} reject-fast (plan D-5)
  --corpus <path>          pinned manifest.json. live home log 분석은 --corpus 미지정 시 (plan D-11)
  --json out=<path>        JSON sidecar 경로 override (default: /tmp/analyze-da-sessions-<ISO>.json)

Output:
  stdout                  markdown 표 + 요약
  JSON sidecar            같은 aggregate 객체에서 렌더링 (불일치 위험 차단)
"""

import argparse
import datetime
import glob
import json
import os
import platform
import re
import subprocess
import sys
from collections import Counter, defaultdict
from typing import Any, Iterable

# ─────────────────────────────────────────────────────────────────────────────
# 1. constants/enums
# ─────────────────────────────────────────────────────────────────────────────

VALID_HOSTS = {"mac", "minipc"}

VERDICT_CATEGORIES = ("CONFIRMED_ISSUE", "NOT_AN_ISSUE", "NEEDS_MORE_INFO")
INTENSITY_VERDICTS = ("FULL", "LITE", "SKIP")

# 4-tier fallback patterns
ARBITER_DIR_MARKER = re.compile(r"/tmp/da-[a-fA-F0-9]+-arbiter-(?!XXXXXX\b)[A-Za-z0-9]+")
INTENSITY_DIR_MARKER = re.compile(r"/tmp/da-[a-fA-F0-9]+-intensity-(?!XXXXXX\b)[A-Za-z0-9]+")
VERDICT_JSON_BLOCK = re.compile(
    r"<!--\s*verdict-json:start\s*-->\s*```json\s*(\{.*?\})\s*```", re.S
)
HUMAN_VERDICT_HEADER = re.compile(
    r"###\s+([A-Za-z][A-Za-z_ ]*?(?:[-]\d+|\s+Finding\s+\d+))\s*[—\-]\s*(CONFIRMED_ISSUE|NOT_AN_ISSUE|NEEDS_MORE_INFO)"
)
FENCED_JSON_BLOCK = re.compile(r"```json\s*(\[?\s*\{.*?\}\s*\]?)\s*```", re.S)
VERDICT_KV = re.compile(
    r"\*\*판정\*\*\s*[:：]\s*\*?\*?(CONFIRMED_ISSUE|NOT_AN_ISSUE|NEEDS_MORE_INFO)\*?\*?"
)
NL_SUMMARY = re.compile(r"(CONFIRMED(?:_ISSUE)?|NOT_AN_ISSUE|NEEDS_MORE_INFO)\s*(\d+)\s*건")
ARBITER_RESULT_HEADER_COUNT = re.compile(r"Arbiter\s+검증\s+결과\s*[:：]?\s*(\d+)\s*건")

# Intensity verdict (인라인 체크리스트 출력의 첫 토큰 — Step 0 결과 라벨)
INTENSITY_VERDICT_LINE = re.compile(
    r"(?:^|\n)\s*\**\s*(?:Review\s+Intensity|검토\s+강도|판정)\s*\**\s*[:：]?\s*\*?\*?(SKIP|LITE|FULL)\*?\*?",
    re.I,
)

# Severity (M-4) — analyze-da-sessions.py SSOT
SEV_LINE = re.compile(
    r"\*\*심각도\*\*\s*[:：]\s*\*?\*?(CRITICAL|HIGH|MEDIUM|LOW)\*?\*?", re.I
)
SEVERITY_RANK = {"CRITICAL": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1}

# Finding ID normalize
FINDING_ID_NORMALIZE = re.compile(
    r"(Correctness|Design|Regression|Maintainability)[-\s]*(?:Finding\s+)?(\d+)", re.I
)
FINDING_ID_LEGACY = re.compile(
    r"(YAGNI|NGMI|HALLUCINATION|SECURITY|SIDE_EFFECT|CONSISTENCY|READABILITY|CLEAN_CODE)-(\d+)",
    re.I,
)
BUNDLE_MAP = {
    "correctness": "Correctness",
    "hallucination": "Correctness",
    "security": "Correctness",
    "design": "Design",
    "yagni": "Design",
    "ngmi": "Design",
    "regression": "Regression",
    "side_effect": "Regression",
    "consistency": "Regression",
    "maintainability": "Maintainability",
    "readability": "Maintainability",
    "clean_code": "Maintainability",
}

# Round summary `selective:` line (M-5 fallback source)
SELECTIVE_LINE = re.compile(
    r"selective\s*:\s*trigger\s+(\d+)건.*?stable\s+(\d+)건.*?split\s+(\d+)건.*?fragmented\s+(\d+)건",
    re.I,
)

# Host path mapping
HOST_PATH_MAP = {
    "mac": {
        "claude": "/Users/green/.claude/projects",
        "codex": "/Users/green/.codex/sessions",
    },
    "minipc": {
        "claude": "/home/greenhead/.claude/projects",
        "codex": "/home/greenhead/.codex/sessions",
    },
}


def current_host() -> str:
    """현재 머신을 mac/minipc로 분류."""
    if platform.system() == "Darwin":
        return "mac"
    return "minipc"


# ─────────────────────────────────────────────────────────────────────────────
# 2. jsonl payload walker
# ─────────────────────────────────────────────────────────────────────────────

def extract_text_payloads(obj: Any, accumulator: list) -> None:
    """JSONL record에서 string payload만 추출 (raw blob regex 금지)."""
    if isinstance(obj, str):
        accumulator.append(obj)
    elif isinstance(obj, dict):
        for v in obj.values():
            extract_text_payloads(v, accumulator)
    elif isinstance(obj, list):
        for v in obj:
            extract_text_payloads(v, accumulator)


# ─────────────────────────────────────────────────────────────────────────────
# 3. finding_id normalizer
# ─────────────────────────────────────────────────────────────────────────────

def get_bundle(finding_id: str | None) -> str | None:
    """finding_id의 reviewer 묶음 매핑."""
    if not finding_id:
        return None
    m = FINDING_ID_NORMALIZE.search(finding_id)
    if m:
        return BUNDLE_MAP.get(m.group(1).lower())
    m = FINDING_ID_LEGACY.search(finding_id)
    if m:
        return BUNDLE_MAP.get(m.group(1).lower())
    return None


# ─────────────────────────────────────────────────────────────────────────────
# 4. verdict parser pipeline (4-tier fallback)
# ─────────────────────────────────────────────────────────────────────────────

def extract_strict_verdicts(text: str) -> list[dict]:
    """Tier 1+2: VERDICT_JSON marker + ### header."""
    verdicts = []
    for m in VERDICT_JSON_BLOCK.finditer(text):
        try:
            v = json.loads(m.group(1))
            verdicts.append({
                "finding_id": v.get("finding_id", ""),
                "verdict": v.get("verdict", ""),
                "confidence": v.get("confidence", "N/A"),
                "stability_status": v.get("stability_status", "N/A"),
                "bundle": get_bundle(v.get("finding_id", "")),
                "source": "verdict_json",
                "source_confidence": "high",
            })
        except Exception:
            pass
    for m in HUMAN_VERDICT_HEADER.finditer(text):
        verdicts.append({
            "finding_id": m.group(1),
            "verdict": m.group(2),
            "confidence": "N/A",
            "stability_status": "N/A",
            "bundle": get_bundle(m.group(1)),
            "source": "md_header",
            "source_confidence": "high",
        })
    return verdicts


def extract_unmarked_json_verdicts(text: str) -> list[dict]:
    """Tier 3: marker 없는 fenced JSON array/object에서 verdict 회수."""
    verdicts = []
    for m in FENCED_JSON_BLOCK.finditer(text):
        body = m.group(1)
        try:
            obj = json.loads(body)
        except Exception:
            continue
        items = obj if isinstance(obj, list) else [obj]
        for item in items:
            if not isinstance(item, dict):
                continue
            v = item.get("verdict")
            if v in VERDICT_CATEGORIES:
                verdicts.append({
                    "finding_id": item.get("finding_id", ""),
                    "verdict": v,
                    "confidence": item.get("confidence", "N/A"),
                    "stability_status": item.get("stability_status", "N/A"),
                    "bundle": get_bundle(item.get("finding_id", "")),
                    "source": "json_unmarked",
                    "source_confidence": "high",
                })
    return verdicts


def extract_kv_verdicts(text: str, arbiter_window_only: bool = True) -> list[dict]:
    """Tier 4: KV `**판정**: VERDICT`. Arbiter 결과 헤더 window 안만."""
    verdicts = []
    if arbiter_window_only:
        for m in re.finditer(r"##\s+Arbiter\s+검증\s+결과", text):
            start = m.end()
            end = min(len(text), start + 30000)
            window = text[start:end]
            nxt = re.search(r"\n##\s", window)
            if nxt:
                window = window[: nxt.start()]
            for vm in VERDICT_KV.finditer(window):
                verdicts.append({
                    "finding_id": "",
                    "verdict": vm.group(1),
                    "confidence": "N/A",
                    "stability_status": "N/A",
                    "bundle": None,
                    "source": "kv",
                    "source_confidence": "medium",
                })
    return verdicts


def extract_nl_summary(text: str) -> tuple[bool, int]:
    """Tier 5 (session-only): NL summary signal. finding-level 분포 미포함."""
    has_signal = False
    estimated_count = 0
    for m in ARBITER_RESULT_HEADER_COUNT.finditer(text):
        has_signal = True
        estimated_count = max(estimated_count, int(m.group(1)))
    for _ in NL_SUMMARY.finditer(text):
        has_signal = True
    return has_signal, estimated_count


def extract_intensity_verdicts(text: str) -> list[str]:
    """M-1: 인라인 체크리스트 출력에서 SKIP/LITE/FULL 첫 토큰 추출."""
    return [m.group(1).upper() for m in INTENSITY_VERDICT_LINE.finditer(text)]


# ─────────────────────────────────────────────────────────────────────────────
# 5. severity transition extractor (M-4, plan D-9 SSOT 정정)
# ─────────────────────────────────────────────────────────────────────────────

def severity_rank(s: str | None) -> int:
    return SEVERITY_RANK.get((s or "").upper(), 0)


def severity_label(rank: int) -> str:
    for label, r in SEVERITY_RANK.items():
        if r == rank:
            return label
    return "NONE"


def find_severity_for_finding(text_blob: str, finding_id: str) -> str | None:
    """analyze-da-sessions.py 패턴: finding header 인접 영역에서 severity 라벨 추출."""
    if not finding_id:
        return None
    # finding_id 등장 위치 + 1000자 window 안에서 severity 라벨 검색
    for m in re.finditer(re.escape(finding_id), text_blob):
        start = max(0, m.start() - 200)
        end = min(len(text_blob), m.end() + 1000)
        window = text_blob[start:end]
        sm = SEV_LINE.search(window)
        if sm:
            return sm.group(1).upper()
    return None


def compute_severity_transitions(
    rounds_data: list[list[dict]],
) -> Counter:
    """라운드별 confirmed finding 집합의 max severity 전이 매트릭스.

    rounds_data: list of [verdict dict, ...] per round.
    Returns Counter of (from_label, to_label) tuples.
    """
    transitions: Counter = Counter()
    for i in range(len(rounds_data) - 1):
        cur_confirmed = [v for v in rounds_data[i] if v.get("verdict") == "CONFIRMED_ISSUE"]
        nxt_confirmed = [v for v in rounds_data[i + 1] if v.get("verdict") == "CONFIRMED_ISSUE"]
        cur_max = max(
            (severity_rank(v.get("severity")) for v in cur_confirmed), default=0
        )
        nxt_max = max(
            (severity_rank(v.get("severity")) for v in nxt_confirmed), default=0
        )
        transitions[(severity_label(cur_max), severity_label(nxt_max))] += 1
    return transitions


# ─────────────────────────────────────────────────────────────────────────────
# 6. stability source resolver (M-5, plan D-10)
# ─────────────────────────────────────────────────────────────────────────────

def resolve_stability_status_from_round_summary(text: str) -> Counter:
    """fallback source: round summary `selective:` 라인 파싱."""
    counter: Counter = Counter()
    for m in SELECTIVE_LINE.finditer(text):
        # trigger, stable, split, fragmented 카운트 누적
        counter["stable"] += int(m.group(2))
        counter["split"] += int(m.group(3))
        counter["fragmented"] += int(m.group(4))
    return counter


def resolve_stability_via_fleiss_kappa(arbiter_results_dir: str) -> Counter | None:
    """1차 source: fleiss-kappa.py 호출 → aggregate envelope의 per_finding[].stability_status."""
    helper_candidates = [
        os.path.expanduser("~/.claude/scripts/fleiss-kappa.py"),
        os.path.expanduser("~/.codex/scripts/fleiss-kappa.py"),
    ]
    helper = next((h for h in helper_candidates if os.path.exists(h)), None)
    if not helper:
        return None

    arbiter_files = sorted(
        glob.glob(os.path.join(arbiter_results_dir, "arbiter-*-result.md"))
    )
    if len(arbiter_files) != 3:
        return None

    try:
        proc = subprocess.run(
            ["python3", helper, *arbiter_files],
            capture_output=True,
            text=True,
            timeout=60,
        )
        if proc.returncode != 0:
            return None
        result = json.loads(proc.stdout)
    except Exception:
        return None

    counter: Counter = Counter()
    for entry in result.get("per_finding", []):
        status = entry.get("stability_status", "N/A")
        counter[status] += 1
    return counter


# ─────────────────────────────────────────────────────────────────────────────
# 7. aggregate builder
# ─────────────────────────────────────────────────────────────────────────────

def analyze_session(path: str) -> dict | None:
    """단일 jsonl 세션 분석. 모든 metric 입력을 추출하여 dict로 반환."""
    has_arbiter_marker = False
    has_intensity_marker = False
    intensity_verdicts: list[str] = []
    all_verdicts: list[dict] = []
    nl_signal_only = False
    nl_estimated = 0
    full_text = []

    try:
        with open(path, "r", errors="replace") as fp:
            for line in fp:
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                payloads: list[str] = []
                extract_text_payloads(obj, payloads)
                for text in payloads:
                    full_text.append(text)
                    if ARBITER_DIR_MARKER.search(text):
                        has_arbiter_marker = True
                    if INTENSITY_DIR_MARKER.search(text):
                        has_intensity_marker = True

                    intensity_verdicts.extend(extract_intensity_verdicts(text))

                    sv = extract_strict_verdicts(text)
                    if sv:
                        all_verdicts.extend(sv)
                        continue
                    uj = extract_unmarked_json_verdicts(text)
                    if uj:
                        all_verdicts.extend(uj)
                        continue
                    kv = extract_kv_verdicts(text, arbiter_window_only=True)
                    if kv:
                        all_verdicts.extend(kv)
                        continue
                    has_signal, est = extract_nl_summary(text)
                    if has_signal:
                        nl_signal_only = True
                        nl_estimated = max(nl_estimated, est)
    except Exception:
        return None

    text_blob = "\n".join(full_text)
    # severity 라벨링 — finding_id 인접 window에서 수집
    for v in all_verdicts:
        if v.get("verdict") == "CONFIRMED_ISSUE" and v.get("finding_id"):
            sev = find_severity_for_finding(text_blob, v["finding_id"])
            if sev:
                v["severity"] = sev

    return {
        "path": path,
        "has_arbiter_marker": has_arbiter_marker,
        "has_intensity_marker": has_intensity_marker,
        "intensity_verdicts": intensity_verdicts,
        "verdicts": all_verdicts,
        "nl_signal_only": nl_signal_only,
        "nl_estimated_count": nl_estimated,
        "round_summary_stability": resolve_stability_status_from_round_summary(text_blob),
    }


def build_aggregate(
    sessions: list[dict],
    hosts: list[str],
    corpus_label: str,
    warnings: list[str],
) -> dict:
    """모든 세션 분석 결과를 통합 aggregate 객체로 빌드."""
    arbiter_marker_sessions = [s for s in sessions if s and s["has_arbiter_marker"]]
    intensity_marker_sessions = [s for s in sessions if s and s["has_intensity_marker"]]

    # M-1: 검토 강도 verdict 분포
    m1_counter: Counter = Counter()
    for s in intensity_marker_sessions:
        for v in s["intensity_verdicts"]:
            if v in INTENSITY_VERDICTS:
                m1_counter[v] += 1
    m1_n = sum(m1_counter.values())

    # M-2: 판정자 verdict 분포 (high+medium confidence subset)
    m2_counter: Counter = Counter()
    source_counter: dict = defaultdict(lambda: {"count": 0, "confidence": ""})
    for s in arbiter_marker_sessions:
        for v in s["verdicts"]:
            if v["source"] in ("verdict_json", "md_header", "json_unmarked", "kv"):
                m2_counter[v["verdict"]] += 1
                src = v["source"]
                source_counter[src]["count"] += 1
                source_counter[src]["confidence"] = v["source_confidence"]
    m2_n = sum(m2_counter.values())

    # M-3: reviewer 묶음별 confirmed-rate
    bundle_total: Counter = Counter()
    bundle_confirmed: Counter = Counter()
    for s in arbiter_marker_sessions:
        for v in s["verdicts"]:
            b = v.get("bundle")
            if not b:
                continue
            bundle_total[b] += 1
            if v["verdict"] == "CONFIRMED_ISSUE":
                bundle_confirmed[b] += 1
    m3 = {}
    for b in ("Correctness", "Design", "Regression", "Maintainability"):
        total = bundle_total[b]
        confirmed = bundle_confirmed[b]
        m3[b] = {
            "total": total,
            "confirmed": confirmed,
            "confirmed_rate": (confirmed / total) if total else 0.0,
        }

    # M-4: severity transition (per-session round 그룹핑)
    transitions: Counter = Counter()
    for s in arbiter_marker_sessions:
        # 라운드 분리: arbiter marker 등장 횟수로 라운드 추정 (단순 휴리스틱).
        # session 안의 verdict 목록을 인접 그룹으로 나누어 round로 간주.
        verdicts = [v for v in s["verdicts"] if v["source"] in ("verdict_json", "md_header")]
        if len(verdicts) < 2:
            continue
        # 단순화: finding_id 중복 등장 시 새 round로 간주
        rounds: list[list[dict]] = []
        seen_ids: set = set()
        cur: list[dict] = []
        for v in verdicts:
            fid = v.get("finding_id", "")
            if fid in seen_ids and cur:
                rounds.append(cur)
                cur = []
                seen_ids = set()
            cur.append(v)
            if fid:
                seen_ids.add(fid)
        if cur:
            rounds.append(cur)
        if len(rounds) >= 2:
            transitions += compute_severity_transitions(rounds)

    # M-5: stability_status 분포
    m5_source = "round_summary_fallback"
    m5_counter: Counter = Counter()
    for s in arbiter_marker_sessions:
        m5_counter += s["round_summary_stability"]
    if not m5_counter:
        m5_source = "unavailable"
    m5_n = sum(m5_counter.values())

    # derived: intensity_full_finding_zero_rate
    full_sessions = [s for s in intensity_marker_sessions if "FULL" in s["intensity_verdicts"]]
    full_zero = [s for s in full_sessions if not any(
        v["verdict"] == "CONFIRMED_ISSUE" for v in s["verdicts"]
    )]
    intensity_full_zero_rate = (
        len(full_zero) / len(full_sessions) if full_sessions else 0.0
    )

    return {
        "schema_version": "1.0",
        "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "hosts": hosts,
        "corpus": corpus_label,
        "session_counts": {
            "total": len([s for s in sessions if s]),
            "arbiter_marker_sessions": len(arbiter_marker_sessions),
            "intensity_marker_sessions": len(intensity_marker_sessions),
        },
        "metrics": {
            "M-1": {
                "denominator": "intensity_marker_sessions",
                "n": m1_n,
                "distribution": dict(m1_counter),
                "percentages": {
                    k: round(100 * v / m1_n, 1) if m1_n else 0.0
                    for k, v in m1_counter.items()
                },
            },
            "M-2": {
                "denominator": "arbiter_marker_sessions_findings_high_medium",
                "n": m2_n,
                "distribution": dict(m2_counter),
                "percentages": {
                    k: round(100 * v / m2_n, 1) if m2_n else 0.0
                    for k, v in m2_counter.items()
                },
                "source_distribution": dict(source_counter),
            },
            "M-3": {"by_bundle": m3},
            "M-4": {"transition_matrix": {f"{a}->{b}": c for (a, b), c in transitions.items()}},
            "M-5": {
                "source": m5_source,
                "n": m5_n,
                "distribution": dict(m5_counter),
            },
        },
        "derived": {
            "intensity_full_finding_zero_rate": round(intensity_full_zero_rate, 3),
        },
        "warnings": warnings,
    }


# ─────────────────────────────────────────────────────────────────────────────
# 8. markdown renderer
# ─────────────────────────────────────────────────────────────────────────────

def render_markdown(agg: dict) -> str:
    out = []
    out.append(f"# DA 세션 정량 분석 — {agg['captured_at']}")
    out.append("")
    out.append("| 항목 | 값 |")
    out.append("|------|-----|")
    out.append(f"| 호스트 | {', '.join(agg['hosts'])} |")
    out.append(f"| corpus | {agg['corpus']} |")
    out.append(f"| 분석 파일 수 | {agg['session_counts']['total']} |")
    out.append(f"| Arbiter marker 세션 | {agg['session_counts']['arbiter_marker_sessions']} |")
    out.append(f"| Intensity marker 세션 | {agg['session_counts']['intensity_marker_sessions']} |")
    out.append("")

    # M-1
    m1 = agg["metrics"]["M-1"]
    out.append(f"## M-1: 검토 강도 verdict 분포 (n={m1['n']})")
    out.append("")
    out.append("| verdict | 카운트 | 비율 |")
    out.append("|---------|--------|------|")
    for v in INTENSITY_VERDICTS:
        c = m1["distribution"].get(v, 0)
        p = m1["percentages"].get(v, 0.0)
        out.append(f"| {v} | {c} | {p}% |")
    out.append("")
    if m1["n"]:
        out.append("```mermaid")
        out.append("pie title 검토 강도 verdict 분포")
        for v in INTENSITY_VERDICTS:
            c = m1["distribution"].get(v, 0)
            if c:
                out.append(f'  "{v}" : {c}')
        out.append("```")
        out.append("")

    # M-2
    m2 = agg["metrics"]["M-2"]
    out.append(f"## M-2: 판정자 verdict 분포 (n={m2['n']})")
    out.append("")
    out.append("| verdict | 카운트 | 비율 |")
    out.append("|---------|--------|------|")
    for v in VERDICT_CATEGORIES:
        c = m2["distribution"].get(v, 0)
        p = m2["percentages"].get(v, 0.0)
        out.append(f"| {v} | {c} | {p}% |")
    out.append("")
    if m2.get("source_distribution"):
        out.append("source 분포:")
        for src, info in m2["source_distribution"].items():
            out.append(f"- {src} ({info['confidence']}): {info['count']}")
        out.append("")

    # M-3
    m3 = agg["metrics"]["M-3"]
    out.append("## M-3: reviewer 묶음별 confirmed-rate")
    out.append("")
    out.append("| 묶음 | total | CONFIRMED_ISSUE | confirmed-rate |")
    out.append("|------|-------|-----------------|----------------|")
    for b, info in m3["by_bundle"].items():
        rate = info["confirmed_rate"]
        out.append(f"| {b} | {info['total']} | {info['confirmed']} | {rate * 100:.1f}% |")
    out.append("")

    # M-4
    m4 = agg["metrics"]["M-4"]
    out.append("## M-4: 동일 세션 max severity 전이 매트릭스")
    out.append("")
    if m4["transition_matrix"]:
        out.append("| from -> to | count |")
        out.append("|------------|-------|")
        for k, v in sorted(m4["transition_matrix"].items()):
            out.append(f"| {k} | {v} |")
    else:
        out.append("(전이 데이터 없음)")
    out.append("")

    # M-5
    m5 = agg["metrics"]["M-5"]
    out.append(f"## M-5: selective consistency stability_status 분포 (source: {m5['source']}, n={m5['n']})")
    out.append("")
    if m5["distribution"]:
        out.append("| stability_status | 카운트 |")
        out.append("|------------------|--------|")
        for k, v in m5["distribution"].items():
            out.append(f"| {k} | {v} |")
    else:
        out.append("(M-5 source unavailable)")
    out.append("")

    # Derived
    out.append("## Derived")
    out.append("")
    d = agg["derived"]
    out.append(f"- intensity_full_finding_zero_rate: {d['intensity_full_finding_zero_rate'] * 100:.1f}%")
    out.append("")

    # Warnings
    if agg["warnings"]:
        out.append("---")
        out.append("⚠ Warnings:")
        for w in agg["warnings"]:
            out.append(f"- {w}")

    return "\n".join(out)


# ─────────────────────────────────────────────────────────────────────────────
# 9. json renderer
# ─────────────────────────────────────────────────────────────────────────────

def render_json(agg: dict) -> str:
    return json.dumps(agg, indent=2, ensure_ascii=False)


# ─────────────────────────────────────────────────────────────────────────────
# Host handling
# ─────────────────────────────────────────────────────────────────────────────

def _validate_host(alias: str) -> None:
    if alias not in VALID_HOSTS:
        raise ValueError(f"invalid host: {alias!r}. valid: {sorted(VALID_HOSTS)}")


def collect_local_files(host: str) -> list[str]:
    """현재 머신의 jsonl 파일 glob."""
    _validate_host(host)
    paths = HOST_PATH_MAP[host]
    files = []
    for base, pattern in [
        (paths["claude"], "**/*.jsonl"),
        (paths["codex"], "**/rollout-*.jsonl"),
    ]:
        glob_path = os.path.join(base, pattern)
        for f in glob.glob(glob_path, recursive=True):
            if "/subagents/" not in f:
                files.append(f)
    return files


def collect_remote_files(host: str, warnings: list[str]) -> list[str]:
    """원격 호스트에서 jsonl 파일 path glob (subprocess.run 고정 argv)."""
    _validate_host(host)
    paths = HOST_PATH_MAP[host]
    all_files: list[str] = []
    for base in (paths["claude"], paths["codex"]):
        try:
            proc = subprocess.run(
                ["ssh", host, "find", base, "-type", "f", "-name", "*.jsonl"],
                capture_output=True,
                text=True,
                timeout=60,
            )
            if proc.returncode != 0:
                warnings.append(
                    f"host {host}: ssh find failed (rc={proc.returncode}) for {base}"
                )
                continue
            for line in proc.stdout.splitlines():
                if "/subagents/" not in line:
                    all_files.append(line)
        except subprocess.TimeoutExpired:
            warnings.append(f"host {host}: ssh timeout for {base} — partial result")
        except FileNotFoundError:
            warnings.append(f"host {host}: ssh binary not found — partial result")
    return all_files


def fetch_remote_file(host: str, path: str) -> str:
    """원격 jsonl 내용 가져오기 (allowlist + 고정 argv)."""
    _validate_host(host)
    if not (path.startswith("/Users/") or path.startswith("/home/")):
        raise ValueError(f"disallowed path: {path!r}")
    proc = subprocess.run(
        ["ssh", host, "cat", path],
        capture_output=True,
        text=True,
        timeout=120,
    )
    if proc.returncode != 0:
        return ""
    return proc.stdout


def analyze_remote_session(host: str, path: str) -> dict | None:
    """원격 jsonl을 fetch하여 임시 파일에 쓰고 analyze_session 호출."""
    content = fetch_remote_file(host, path)
    if not content:
        return None
    import tempfile
    with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False) as tf:
        tf.write(content)
        tmp_path = tf.name
    try:
        return analyze_session(tmp_path)
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

def parse_hosts(s: str) -> list[str]:
    hosts = [h.strip() for h in s.split(",") if h.strip()]
    for h in hosts:
        if h not in VALID_HOSTS:
            raise argparse.ArgumentTypeError(
                f"invalid host: {h!r}. valid: {sorted(VALID_HOSTS)}"
            )
    return hosts


def parse_json_arg(s: str) -> str:
    """--json out=<path> 형식 파싱."""
    if s.startswith("out="):
        return s[4:]
    return s


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="analyze.py",
        description="DA 세션 정량 분석 — analyzing-da-sessions Skill SSOT",
    )
    parser.add_argument(
        "--hosts",
        type=parse_hosts,
        default=["mac", "minipc"],
        help="comma-separated host list (default: mac,minipc). whitelist: mac, minipc",
    )
    parser.add_argument(
        "--corpus",
        type=str,
        default=None,
        help="pinned manifest.json path for ±5% regression gate (default: live home log)",
    )
    parser.add_argument(
        "--json",
        type=parse_json_arg,
        default=None,
        help="JSON sidecar output path (default: /tmp/analyze-da-sessions-<ISO>.json)",
    )
    args = parser.parse_args()

    warnings: list[str] = []
    cur_host = current_host()

    # 파일 수집
    if args.corpus:
        # pinned corpus 모드
        try:
            with open(args.corpus, "r") as fp:
                manifest = json.load(fp)
        except Exception as e:
            print(f"ERROR: corpus manifest read failed: {e}", file=sys.stderr)
            return 1
        all_files = manifest.get("files", [])
        # host 분류는 path prefix로
        files_by_host: dict[str, list[str]] = defaultdict(list)
        for f in all_files:
            if f.startswith("/Users/"):
                files_by_host["mac"].append(f)
            elif f.startswith("/home/"):
                files_by_host["minipc"].append(f)
        corpus_label = manifest.get("snapshot_id", "pinned")
    else:
        files_by_host = defaultdict(list)
        for host in args.hosts:
            if host == cur_host:
                files_by_host[host] = collect_local_files(host)
            else:
                files_by_host[host] = collect_remote_files(host, warnings)
        corpus_label = "live"

    # 분석
    sessions: list[dict] = []
    for host, files in files_by_host.items():
        for path in files:
            if host == cur_host or args.corpus:
                # corpus 모드는 절대 path가 현재 머신에서 read 가능한 경우만 처리
                if args.corpus and host != cur_host:
                    # corpus의 다른 호스트 파일은 SSH로 fetch
                    result = analyze_remote_session(host, path)
                else:
                    result = analyze_session(path)
            else:
                result = analyze_remote_session(host, path)
            if result is not None:
                sessions.append(result)

    # aggregate
    agg = build_aggregate(sessions, args.hosts, corpus_label, warnings)

    # 출력: markdown stdout
    print(render_markdown(agg))

    # 출력: JSON sidecar
    if args.json:
        json_path = args.json
    else:
        ts = datetime.datetime.now().strftime("%Y-%m-%dT%H-%M-%S")
        json_path = f"/tmp/analyze-da-sessions-{ts}.json"
    try:
        with open(json_path, "w") as fp:
            fp.write(render_json(agg))
        print(f"\n---\nJSON sidecar: {json_path}", file=sys.stderr)
    except OSError as e:
        print(f"WARNING: JSON sidecar write failed: {e}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
