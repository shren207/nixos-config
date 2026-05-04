# Review Intensity 판단 절차 (메인 LLM 인라인 체크리스트)

Review Intensity 판단의 실행 절차. 판단 알고리즘 규칙 SSOT는 [`intensity-rules.md`](intensity-rules.md)다.

Review Intensity 판정은 **메인 LLM이 인라인으로 8 룰 체크리스트를 기계적으로 적용**한다. 별도 독립 process(codex exec / native subagent)를 띄우지 않는다. 메인 LLM은 룰을 자유롭게 추론해서는 안 되고, [`intensity-rules.md`](intensity-rules.md)의 룰 1-8을 순서대로 평가해 결과 표를 plan/대화에 남겨야 한다.

`full` modifier가 있으면 이 단계를 건너뛰고 exhaustive override(8개 세부 도메인)로 직행한다.

## 3단계

| 단계 | 에이전트 수 | 사용자 승인 | 설명 |
|------|-----------|-----------|------|
| SKIP | 0 | 질문 도구 **필수** (런타임별 매핑: [`runtime-mapping.md`](runtime-mapping.md)) | DA 완전 생략 |
| LITE | Correctness 필수 + 관련 reviewer bundles | 불필요 | 필요한 bundle만 선택 실행 |
| FULL | 4 reviewer bundles | 불필요 | 4 reviewer bundle 기본 리뷰 |

`full` modifier는 위 표의 FULL과 다르다. 자동 FULL은 4 reviewer bundle이고,
modifier `full`은 Review Intensity를 건너뛰고 exhaustive 8-domain path로 진입한다.

## 인라인 체크리스트 절차 (강제)

메인 LLM은 `/run-da` 호출 진입 시 다음을 순서대로 수행한다. **자유 추론 금지** — 8 룰 체크리스트를 기계적으로 적용한다.

1. **변경 규모 입력 수집**
   - for_pr: `git diff --stat main...HEAD` (파일 목록 + 라인 수)
   - for_plan: 계획 요약 (변경 대상 파일 목록 + 변경 유형)

2. **8 룰 체크리스트 평가** — [`intensity-rules.md`](intensity-rules.md)의 8 룰을 순서대로 평가한다. 각 룰에 대해 다음을 명시한다:

   ```text
   | 룰 번호 | 매치/미매치/불확실 | 입력 근거 |
   |---------|--------------------|-----------|
   | 1. full modifier | 미매치 | (modifier 인자 없음) |
   | 2. 보안 관련 변경 | 매치 | files/secrets.nix:42 권한 mode 변경 |
   | 3. 새 모듈/서비스/아키텍처 | 미매치 | 기존 모듈 내부 수정 |
   | 4. 설정/포트/환경변수/의존성 | 미매치 | (해당 변경 없음) |
   | 5. 단일 함수 소규모 수정 | 미매치 | 다중 파일 변경 |
   | 6. 순수 문서/주석 (정책 파일 예외) | 미매치 | 코드 변경 포함 |
   | 7. 혼합 변경 → 가장 높은 단계 | 매치 | 룰 2 매치로 FULL |
   | 8. 불명확 → FULL | (적용 안 함) | 룰 2 명확히 매치 |
   ```

3. **판정 결정** — [`intensity-rules.md`](intensity-rules.md)의 판단 알고리즘 (먼저 매치된 조건 우선)을 적용. 위 예시: 룰 2 매치 → **FULL**.

4. **fail-closed 절차** — 다음 조건 중 하나라도 해당되면 **강한 검토(FULL)로 강제**:
   - 룰 2-4 (보안 / 모듈/서비스 / 설정) 후보가 하나라도 "매치" 또는 "불확실"
   - rule 번호와 입력 근거를 명시하지 못함 (체크리스트 불완전)
   - 입력 정보 부족으로 어느 룰에도 confident하게 답할 수 없음

5. **결과 보고** — 판정(SKIP/LITE/FULL)과 위 체크리스트를 plan/대화에 명시 기록한다. SKIP일 경우 사용자 승인 절차로 진입.

## 메인 LLM의 의무 (합리화 방지)

- "이건 단순한 변경이니 SKIP/LITE 정도면 될 것 같다"는 **자유 추론은 금지**. 반드시 8 룰 체크리스트를 기계적으로 적용한다.
- 보안/모듈/설정/의존성 관련 변경에서는 룰 2-4 매칭 여부를 우선 점검한다. "코드 양이 적다", "단순한 설정 변경"이라는 표현으로 룰 2-4를 우회하지 않는다.
- 체크리스트 표를 생략하면 SKIP/LITE 판정 자체가 무효이며 강한 검토로 fail-closed 처리된다.
- 판정자(Arbiter) 결과 판정 대체는 여전히 금지 ([`hardening-contract.md`](hardening-contract.md) 참조).

## SKIP 절차

1. 질문 도구로 사용자에게 DA 생략 승인을 요청한다:
   - 변경 내용 요약
   - SKIP 판단 근거 (위 체크리스트 표 인용)
   - "DA를 생략해도 괜찮겠습니까?"
2. 사용자가 승인하면 DA를 생략하고 해당 모드(for_plan/for_pr)를 종료하여 상위 워크플로로 복귀한다.
3. 사용자가 거부하면 LITE 또는 FULL로 승격하여 DA를 진행한다.

질문 도구를 호출할 수 없는 런타임에서는 [`arbiter-scaling.md`](arbiter-scaling.md)의 "질문 도구 미지원 대응" 섹션을 따른다 (자동 LITE 승격 등).

## LITE 절차

1. `Correctness`는 항상 포함한다. (`SECURITY`와 `HALLUCINATION` 안전장치를 함께 유지한다.)
2. 코드 변경이면 `Regression`도 기본 포함한다 (기존 호출부 회귀 검출을 위해).
3. 나머지 bundle 중 변경 성격에 직접 관련된 bundle만 선택한다.
   선택 판단 기준: 해당 bundle의 "집중 대상"([`da-domains.md`](da-domains.md))이 이번 변경에 적용되는가.
4. 선택되지 않은 bundle은 `NOT_RUN`으로 기록한다.
5. 선택된 bundle만으로 [`../modes/for_plan.md`](../modes/for_plan.md) / [`../modes/for_pr.md`](../modes/for_pr.md)의 절차를 수행한다.
6. 종료 조건: **선택된 bundle 전부 CLEAR** (`NOT_RUN` bundle은 평가 대상 아님).

### LITE 예시

단일 함수명 정리 리팩터링 → **Correctness** + **Regression** + **Maintainability** 실행.
미실행: Design(NOT_RUN).
이유: Correctness는 항상 포함, Regression은 코드 변경이므로 기본 포함,
Maintainability는 이름/가독성 변화에 직접 관련된다.

### LITE 라운드 요약 형식

```text
Round N 요약 (LITE: 선택 M개/전체 4개 reviewer bundles): DA 발견 X건
→ Arbiter: CONFIRMED Y건, NOT_AN_ISSUE Z건, NEEDS_MORE_INFO W건
bundle별: Correctness CLEAR, Regression 2건(CONFIRMED 1, NOT_AN_ISSUE 1), ...
미실행: Design(NOT_RUN), ...
selective: trigger P건 → stable Q건, split R건, fragmented S건, partial_failure T건  ← selective consistency 발동 라운드에만 추가
```

selective consistency가 발동하지 않은 라운드는 마지막 줄을 생략한다. stability_status 집계 규칙은 [`protocol.md`](protocol.md)의 "라운드 요약 기록" 참조.

## 회귀 검증 (Intensity fixture replay) — 수동 replay 가이드

[`../evals/intensity-fixtures.json`](../evals/intensity-fixtures.json)에 8 룰 회귀 검증용 케이스가 정의되어 있다. 본 파일은 **수동 replay 가이드**이며, 자동 eval runner에는 아직 연결되지 않았다 (현재 `run-eval.sh`는 `evals/queries.json`만 batch discovery).

**수동 replay 절차** (인라인 체크리스트 변경 시 PR 작성자 책임):
1. 각 fixture의 `changed_files` + `change_summary`를 입력으로 메인 LLM의 8 룰 인라인 체크리스트를 수행한다.
2. 산출 verdict가 fixture의 `expected_intensity`와 일치하는지 확인한다.
3. 미일치 1건이라도 회귀로 간주하고 PR 본문에 명시한다.

**자동 eval runner 연결은 follow-up 범위**다 — fixture 스키마(`fixtures[]`)와 `run-eval.sh` activation eval 스키마가 다르므로, 별도 runner 또는 스키마 통합이 필요하다 (관련 follow-up issue는 본 PR 본문 참조).
