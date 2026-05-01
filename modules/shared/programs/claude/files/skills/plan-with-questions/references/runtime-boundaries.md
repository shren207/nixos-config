# Runtime Boundaries

plan-with-questions의 런타임 지원·용어·도구 매핑·미지원 대응 SSOT.

## 지원 런타임

| 런타임 | 지원 여부 |
|--------|----------|
| Claude Code 세션 | 완전 지원 |
| Codex Plan mode (`request_user_input` 지원 시) | 완전 지원 |
| Codex 일반 세션 (Plan mode 미사용) | BLOCKED ("질문 도구 미지원 대응" 섹션) |
| headless 세션 (CI · `claude -p` · `codex exec`) | BLOCKED ("질문 도구 미지원 대응" 섹션) |

## 용어 정책

이 스킬은 Claude Code 세션과 Codex 세션 양쪽에서 호출된다. 본문은 **도구-중립 용어**를 쓰며, 런타임별 실제 도구 binding은 [run-da의 "런타임 도구 매핑" 표](../../run-da/SKILL.md#런타임-도구-매핑)를 단일 진실 원천으로 참조한다 (중복 복제 금지).

| 용어 유형 | 처리 |
|----------|------|
| 사용자 질문 실행 지시 | "질문 도구" |
| 사용자 승인 요청 지시 | "승인 요청 도구" (런타임별 실제 도구는 아래 "런타임 도구 매핑" 표의 "계획 승인 요청" 행 참조) — **plan-with-questions 국소 용어** (run-da SSOT 미정의; sibling 자동 전파 대상 아님) |
| 파일 읽기/검색 지시 | "파일 읽기 도구" (또는 명시적 셸 명령 `rg -n` / `sed -n` / `find`) |
| 파일 편집 지시 | "파일 편집 도구" |

## 런타임 도구 매핑 (plan-with-questions 고유)

이 표는 plan-with-questions 고유 행만 정의한다. 사용자 질문/fan-out/파일 읽기·편집은 [run-da 런타임 도구 매핑 표](../../run-da/SKILL.md#런타임-도구-매핑)를 단일 진실 원천으로 참조한다 (중복 복제 금지).

**미지원 런타임 처리**: Codex 일반 세션·headless는 본 표의 어떤 행에도 도달하지 않는다 (Step 4/Step I-4에서 질문 도구 호출 시점에 BLOCKED). 상세는 위 "지원 런타임" 표와 "질문 도구 미지원 대응" 섹션이 단일 소스다.

| 행동 | Claude Code 세션 | Codex Plan mode |
|------|------------------|-----------------|
| 계획 추적 상태 진입 | `EnterPlanMode` (계획 파일 경로 배정 + write 제한 모드) | `update_plan` (단계별 chat state 추적; 파일 IO 없음) |
| 계획 파일 작성/편집 | `Write`/`Edit`로 진입 시 배정된 경로에 작성 | `apply_patch`로 `.claude/plans/<slug>.md`에 직접 작성 |
| 계획 승인 요청 | `ExitPlanMode`로 계획 파일 제시 및 승인 대기 | 계획 파일 경로/요약을 `request_user_input`으로 제시하고 confirm 대기 |

본문의 "계획 추적 도구", "파일 편집 도구", "승인 요청 도구"는 위 표의 런타임별 실제 도구를 가리킨다. 최종 산출물은 두 지원 런타임 모두 `.claude/plans/<slug>.md` 계획 **파일**이다.

## 질문 도구 미지원 대응

이 섹션은 Step 4 / Step I-4 / Step 7에서 참조되는 BLOCKED 처리 정책의 단일 소스다.

현재 런타임에서 질문 도구를 호출할 수 없으면 (Codex 일반 세션 + Plan mode 미사용, headless 세션 등), plan-with-questions는 **BLOCKED 처리**한다. 인터뷰 기반 SKILL의 본질상 사용자 입력 없는 자동 진행이 불가능하므로 자동 전이를 채택하지 않는다.

처리 절차:
1. 현재 단계(Step 4 / Step I-4 / Step 7 등)와 차단 사유(질문 도구 미지원)를 plain-text로 보고한다 (보고 채널이 없는 headless에서는 silent exit한다).
2. SKILL 절차를 종료한다.
3. 사용자가 새 메시지에서 명시 재개("계속 진행" 등)하거나 질문 도구 지원 런타임으로 전환할 때까지 자동 재개하지 않는다. **지원 런타임 전환 방법**: Claude Code 세션 사용 또는 Codex Plan mode 활성화. Codex Plan mode 활성화 절차는 사용자 codex 환경 설정에 따른다 (이 SKILL의 책임 범위 밖).

이 정책은 [run-da의 "질문 도구 미지원 대응"](../../run-da/references/arbiter-scaling.md#질문-도구-미지원-대응) 섹션과 결을 같이 하지만, plan-with-questions 인터뷰 컨텍스트 전용으로 적용 규칙이 다르다 (자동 승격/LITE 승격/5라운드 종료 같은 DA 흐름 규칙은 적용하지 않는다).
