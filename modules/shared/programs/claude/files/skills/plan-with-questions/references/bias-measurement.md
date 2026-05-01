# Bias Measurement

**Status**: stub (Phase 5에서 본문 채움)

이 reference는 plan-with-questions 개편의 Phase 5(`bias-measurement + 검증 + 문서화`) 산출물이다.

## Baseline 수치 — 동적 확인 명령

baseline은 본 파일에 하드코딩하지 않는다. Phase 5 진입 시 다음 명령으로 산출:

```bash
# main 세션 plan-with-questions 호출 건수 (최근 N일)
find ~/.claude/projects -name '*.jsonl' -mtime -N | xargs rg -l '/plan-with-questions' 2>/dev/null | wc -l

# DA correction 신호 동반 세션
find ~/.claude/projects -name '*.jsonl' -mtime -N | xargs rg -l 'CONFIRMED_ISSUE|재설계|기각' 2>/dev/null | wc -l

# MiniPC 보조 데이터 가용성
ssh minipc "find ~/.claude/projects -name '*.jsonl' -mtime -N | wc -l"
```

`-mtime -N`의 N은 측정 시점에 결정한다 (Phase 5 schedule 절차).

## Phase 5에서 채울 내용

### 4축 grep 패턴

```bash
# 1. 사용자 선택 포착
rg "사용자 결정|사용자 확인 완료|선호|선택|추천|A 방식|B 방식|어느 쪽|AskUserQuestion|충분|인지"

# 2. 추천 프레이밍
rg "추천|권장|기본값|best|Recommended|강력히"

# 3. 사후 결함
rg "DA Round|CONFIRMED_ISSUE|NEEDS_MORE_INFO|YAGNI|NGMI|REGRESSION|overbuilt|missing|conflicting|parallel-audit|review-implementation"

# 4. 재설계 저항
rg "사용자 결정에 따라|현상 유지|기각|생략|그래도|재설계.*거부|redesign.*reject|추천대로"
```

### 핵심 metric

- **`choice_then_defect_rate`**: 같은 파일에서 선택 라인이 결함 라인보다 앞서는 경우만 집계.
- **`leading_question_ratio`**: 선택 라인 부근 추천/권장/기본값 표현 비율 (window 크기는 측정 시 결정).
- **`defect_after_user_choice_severity`**: 이후 `CONFIRMED_ISSUE`, `YAGNI`, `overbuilt` 건수.
- **`redesign_resistance_rate`**: 결함 이후 `현상 유지|기각|생략|사용자 결정에 따라` 출현 비율.

### 측정 schedule

- Phase 5 구현 직후 baseline 산출.
- 새 구조 도입 후 측정 (간격은 Phase 5 schedule 절차에서 결정).
- metric 변화 추이 기록 (Decision Log DL 추가).
- 인과 단정 금지 — bias candidate 식별 위주 (codex 권고).

## Phase 1 단계 임시 적용

baseline metric 산출은 Phase 5에서 수행. 현재는 Phase 1 commit + Phase 2-4 구현 우선.
