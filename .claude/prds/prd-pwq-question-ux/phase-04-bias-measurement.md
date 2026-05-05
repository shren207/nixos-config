# Phase 4: Bias Measurement

Parent PRD: [PRD: plan-with-questions Question UX](../prd-pwq-question-ux.md)
Status: Not Started
Last Updated: 2026-05-05

## Objective

`references/bias-measurement.md` + `scripts/ai/measure-anchoring-bias.sh` (또는 동등 위치 스크립트)의 라벨 측정 metric을 새 라벨 정책 ("허용 조건 컨텍스트 외 라벨 0건")에 맞춰 갱신한다. anti-anchoring 1번 규칙 폐기에 따른 metric 인프라 drift 차단.

## Context From Master PRD

- Goals covered: G-6 (anchoring 측정 metric 동시 갱신)
- Success Criteria: SC-5
- Requirements covered: FR-8
- Key scenarios touched: Scenario 1 (라벨 부착 시 measure 통과 확인)

## Phase Discovery Gate

코드 편집 전에 재확인한다:
- [ ] 관련 코드/파일: `~/.claude/skills/plan-with-questions/references/bias-measurement.md`, `~/.claude/skills/plan-with-questions/scripts/ai/measure-anchoring-bias.sh` (실제 위치 확인 — `scripts/` 상대 경로일 수도 또는 `~/.claude/scripts/` global일 수도)
- [ ] Phase 1, 2, 3 산출물 — 라벨 정책 변경 + Anti-anchoring 1번 폐기가 모두 반영됨
- [ ] 관련 docs/spec: `~/.claude/skills/plan-with-questions/references/consulting-step.md` Anti-anchoring 4 규칙 (Phase 1 결과)
- [ ] 관련 command: `bash`/`zsh` (스크립트 실행), `rg`
- [ ] Master PRD assumption 유효
- [ ] 스크립트 실제 경로를 `find ~/.claude -name "measure-anchoring-bias.sh"`로 1차 확인 후 implementation 진입

## Scope

### In Scope

- `references/bias-measurement.md` 라벨 측정 metric 단락 — "라벨 0건" 가정에서 "허용 조건 컨텍스트 외 라벨 0건"으로 갱신.
- `scripts/ai/measure-anchoring-bias.sh` 또는 동등 위치 스크립트 — 라벨 grep 패턴을 새 정책에 맞춰 갱신 (예: "(Recommended) — 자문+합의 결과" 컨텍스트는 통과, 그 외는 검출).
- bias-measurement.md에 새 baseline 산출 절차 단락 추가 (현 정책: "합의 미달 라벨 0건"이 baseline).

### Out of Scope

- F-OQ-2: D4 anchoring 효과 손상 정량 측정 방법의 *세부 baseline* — 본 phase는 metric 변경만, 세부 baseline은 dogfooding 누적 후 별도 follow-up issue.
- 다른 anchoring metric (framing/defect/resistance 후보 탐지) 변경 — Anti-anchoring 1번 폐기와 무관, 본 phase 범위 외.

## Implementation Checklist

- [ ] `find ~/.claude -name "measure-anchoring-bias.sh"` 또는 `find . -name "measure-anchoring-bias.sh"` 등으로 스크립트 실제 경로 확인. PRD master Discovery Summary에 명시된 경로(`~/.claude/scripts/measure-anchoring-bias.sh` 또는 nixos-config/scripts) 둘 중 하나 또는 다른 위치 가능.
- [ ] `references/bias-measurement.md` "anchoring metric" 또는 동등 단락 — 현재 "라벨 0건 grep" 단락 확인 후 "허용 조건 컨텍스트 외 라벨 0건"으로 갱신.
- [ ] `references/bias-measurement.md` 새 baseline 산출 절차 단락 추가 — Phase 1 합의 알고리즘 통과한 라벨은 통과, 그 외는 검출.
- [ ] 스크립트 grep 패턴 갱신 — `(Recommended)` 단순 매칭에서 컨텍스트 인식 매칭 (예: "(Recommended)" 다음 줄 또는 같은 line에 "자문+합의" 또는 "합의 결과" 키워드가 있으면 통과)으로 변경. 또는 `rg "Recommended"` + `rg -A 2 "Recommended"`로 컨텍스트 확인.
- [ ] 스크립트 실행 후 본 PRD 변경 후 0건이 나오는지 확인 (manual run).
- [ ] `references/bias-measurement.md`에 본 phase의 변경 사항 + 새 baseline 절차를 Change Log 또는 동등 위치에 기록.

## Validation Strategy

본 phase는 metric 변경 + 스크립트 grep 패턴 변경이라 스크립트 실행 검증이 핵심.

- 스크립트 실행: `bash scripts/ai/measure-anchoring-bias.sh` (실제 위치) → exit 0 + 출력에 "라벨 위반 0건" 또는 동등.
- 정적 grep: `rg "Recommended" ~/.claude/skills/plan-with-questions/` → Phase 1-3 변경 결과로 "허용 조건" 컨텍스트만 매칭 (SC-2 + SC-5 통합).
- 정적 grep: `rg "허용 조건 컨텍스트" ~/.claude/skills/plan-with-questions/references/bias-measurement.md` ≥ 1건.

## Validation Checklist

- [ ] Static check 통과: `find ~/.claude -name "measure-anchoring-bias.sh"`로 스크립트 위치 확인 (1+개)
- [ ] Script 실행 통과: `bash <스크립트 경로>` exit 0 + 출력 정상 (라벨 위반 0건)
- [ ] Static check 통과: `rg "허용 조건" ~/.claude/skills/plan-with-questions/references/bias-measurement.md` ≥ 1건
- [ ] Static check 통과: `rg "Recommended" ~/.claude/skills/plan-with-questions/` → 허용 컨텍스트만 (SC-2 + SC-5 동시 검증)
- [ ] 자동 test: N/A
- [ ] API/CLI workflow 검증: 스크립트 실행 자체가 검증
- [ ] Manual smoke check: bias-measurement.md read 후 다음 LLM이 metric 의미 파악 가능?
- [ ] error 상태: 스크립트가 라벨 위반 1+건 검출 시 nonzero exit 또는 에러 메시지 명시 확인

## Exit Criteria

- [ ] Phase objective 달성 — bias-measurement.md + 스크립트 갱신 완료
- [ ] FR-8 구현
- [ ] Validation checklist 완료
- [ ] Phase 5 시작을 막는 blocker 없음

## Phase-End Multi-Pass Review

- [ ] 1. Intent/coverage — bias-measurement.md + 스크립트가 새 라벨 정책 일관 측정
- [ ] 2. Correctness — 스크립트 grep 패턴이 "허용 조건 컨텍스트"를 정확히 식별 (false positive/negative 점검)
- [ ] 3. Simplicity — 스크립트 변경이 grep 패턴 갱신 정도로 최소 변경
- [ ] 4. Code quality — 스크립트 주석에 새 정책 의도 명시
- [ ] 5. Duplication/cleanup — 기존 라벨 0건 가정 단락 제거 또는 명시적 폐기 표기
- [ ] 6. Security/privacy — N/A
- [ ] 7. Performance/load — 스크립트 실행 시간 (PWQ 본문 grep)
- [ ] 8. Validation — 스크립트 실행 + 정적 grep이 risk에 적절
- [ ] 9. Future-phase review — Phase 5 dogfooding이 스크립트 통과 baseline 사용
- [ ] 10. PRD sync review — master PRD Phase Index Status `Phase 4` → `Complete`, `Active Phase File`을 phase-05로 갱신

## Discoveries / Decisions

(phase 진행 중 갱신 — 특히 스크립트 실제 위치, grep 패턴 결정 근거)

## Phase Change Log

- 2026-05-05: Phase file created.
