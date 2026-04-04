# Direct Codex Native-Subagent Hardening Implementation Plan

**Issue:** `#419`

**Goal:** direct Codex 세션에서만 적용되는 review/audit/planning fan-out hardening 규칙을 문서와 생성 경로에 반영해, 저품질 subagent 강등, 조급한 중간 kill, write 경계 위반, 중복 GitHub write, lock-sensitive 명령 오남용을 줄인다.

**Architecture:** `run-da`와 그 reference 문서를 canonical contract로 삼는다. direct-Codex 전용 hardening의 상세 규칙은 여기서만 정의하고, `parallel-audit`, `plan-with-questions`, `AGENTS.override.md`, generated override 템플릿, `sync.sh`는 concise summary와 링크만 유지한다. 이번 이슈는 Codex core 변경이나 `codex exec` 경로 재설계가 아니라, direct Codex path의 orchestration contract hardening에 한정한다.

**Tech Stack:** Markdown, Bash, `gh`, `rg`, `sed`, `shellcheck`

---

## Verified Baseline

- issue `#419`는 open 상태이고, 현재 워크트리는 clean이다.
- direct Codex vs fallback `codex exec` 분기와 thread-cap 규칙은 이미 [run-da/SKILL.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/run-da/SKILL.md#L75), [arbiter-scaling.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/run-da/references/arbiter-scaling.md#L31), [parallel-audit/SKILL.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/parallel-audit/SKILL.md#L25), [plan-with-questions/SKILL.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/plan-with-questions/SKILL.md#L103)에 이미 분산되어 있다.
- 현재 repo 기본 Codex 설정은 [config.toml](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/codex/files/config.toml#L2)와 [config.toml](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/codex/files/config.toml#L5)에서 `gpt-5.4` / `xhigh`로 고정돼 있고, 현재 런타임 `spawn_agent` 계약도 per-agent `model`, `reasoning_effort`를 지원한다.
- `parallel-audit`는 read-only 계약을 전제로 하고 있고 [parallel-audit/SKILL.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/parallel-audit/SKILL.md#L23), [parallel-audit/SKILL.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/parallel-audit/SKILL.md#L97), Arbiter/Intensity도 review-only 계약을 가진다 [arbiter-scaling.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/run-da/references/arbiter-scaling.md#L55).
- 현재 [AGENTS.override.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/AGENTS.override.md#L1)는 markerless 수기 파일이고, template/sync 경로는 marker 기반 auto-generated 구조를 전제로 한다 [agents-override-template.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/syncing-codex-harness/references/agents-override-template.md#L17), [sync.sh](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/syncing-codex-harness/references/sync.sh#L329).
- PR `#415` follow-up comment와 issue 본문에서 `gpt-5.4 xhigh` pin, conservative wait, single-writer, duplicate GitHub comment 방지, `wt`/`nrs`/rebuild 계열 보호가 명시적으로 요구된다.

---

## File Structure

| Action | Path | 역할 |
|--------|------|------|
| Modify | `modules/shared/programs/claude/files/skills/run-da/SKILL.md` | direct Codex hardening canonical contract, terminology/precedence, conservative wait, authority boundary, violation flow를 주 규칙으로 수렴 |
| Modify | `modules/shared/programs/claude/files/skills/run-da/references/arbiter-scaling.md` | Arbiter/Intensity direct path 실행 계약에 model pin, no-write, conservative wait, violation escalation 반영 |
| Modify | `modules/shared/programs/claude/files/skills/run-da/references/da-domains.md` | reviewer prompt 템플릿에 scratch-only PoC, tracked/main-agent-only 경계, violation reporting 규칙 반영 |
| Modify | `modules/shared/programs/claude/files/skills/parallel-audit/SKILL.md` | read-only 계약 유지, direct-Codex hardening summary/link 추가, `wt`/`nrs`/rebuild main-agent-only 명시 |
| Modify | `modules/shared/programs/claude/files/skills/plan-with-questions/SKILL.md` | `/run-da for_plan` 연계 시 canonical contract 참조, conservative wait, reviewer write boundary를 run-da와 정합적으로 요약 |
| Modify | `AGENTS.override.md` | marker 기반 구조로 좁게 이행하고, concise direct-Codex invariant만 auto-generated block에 배치 |
| Modify | `modules/shared/programs/claude/files/skills/syncing-codex-harness/references/agents-override-template.md` | generated override 설명을 새 markerized 구조와 concise invariant 기준으로 갱신 |
| Modify | `modules/shared/programs/claude/files/skills/syncing-codex-harness/references/sync.sh` | generated override bullet을 canonical contract 링크/요약 중심으로 조정 |

---

## Phase 1: Canonical Hardening Contract In `run-da`

**Files:**
- Modify: `modules/shared/programs/claude/files/skills/run-da/SKILL.md`
- Modify: `modules/shared/programs/claude/files/skills/run-da/references/arbiter-scaling.md`
- Modify: `modules/shared/programs/claude/files/skills/run-da/references/da-domains.md`

- [ ] **Step 1: `run-da/SKILL.md`에 direct-Codex hardening terminology/precedence 섹션 추가**

  `런타임 경로`와 `피드백 프로토콜` 사이에 direct Codex 전용 공통 정의 섹션을 추가한다. 이 섹션은 다음 용어를 canonical로 정의한다.

  - `conservative wait`: 명시적 실패 신호, documented violation, 또는 `wait_agent` 실패 없이 reviewer/auditor/Arbiter/Intensity thread를 조급하게 kill하지 않는다. self-auditing 대체도 금지한다.
  - `single-writer`: tracked workspace write, branch mutation, commit/push, GitHub comment/issue/PR write, 최종 파일 수정은 메인 에이전트 소유다. explicit delegation이 있는 경우만 예외다.
  - `main-agent-only commands`: `wt`, `nrs`, rebuild-class command는 direct Codex fan-out subagent가 직접 실행하지 않는다. main agent 또는 explicit delegated owner만 실행한다.
  - `violation taxonomy`: `recoverable`(출력 형식/범위 위반) vs `stateful`(workspace/branch/GitHub/host mutation, main-agent-only command 위반)로 나눈다.

- [ ] **Step 2: direct-path 실행 규칙을 canonical contract로 승격**

  [run-da/SKILL.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/run-da/SKILL.md)의 direct path reviewer/Arbiter/Intensity 절차에 다음을 추가한다.

  - reviewer, Arbiter, Intensity subagent spawn 시 `model="gpt-5.4"`와 `reasoning_effort="xhigh"`를 명시한다.
  - `wait_agent`는 conservative wait 원칙으로 운용하고, explicit failure signal 또는 documented violation이 아닌 이상 중간 kill을 금지한다.
  - direct path reviewer는 out-of-repo scratch PoC만 허용한다. tracked file write, branch mutation, commit/push, GitHub write, rebuild/worktree command는 main-agent-only로 적는다.
  - violation 발생 시 해당 review unit은 `CLEAR` 계산에서 제외하고, recoverable violation은 discard 후 rerun, stateful violation은 즉시 중단 + cleanup/incident 처리 후 rerun 또는 사용자 보고로 분기한다.

- [ ] **Step 3: `arbiter-scaling.md`에 Arbiter/Intensity 전용 no-write 계약 명시**

  [arbiter-scaling.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/run-da/references/arbiter-scaling.md)에 direct Codex path 규칙을 보강한다.

  - Arbiter/Intensity는 review-only/no-write를 유지한다.
  - subagent spawn 시 `model="gpt-5.4"` / `reasoning_effort="xhigh"` pin을 명시한다.
  - conservative wait를 명시하고, completed thread close 전까지 slot을 점유한다는 기존 문장을 유지한다.
  - stateful violation 또는 main-agent-only command 위반 시 `NEEDS_MORE_INFO` 승격이 아니라 즉시 중단/incident 기록 규칙으로 분기한다.

- [ ] **Step 4: `da-domains.md` prompt 템플릿에 reviewer authority boundary 반영**

  [da-domains.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/run-da/references/da-domains.md)의 공통 프롬프트 구조를 보강한다.

  - reviewer는 direct Codex path에서 scratch/out-of-repo PoC만 허용한다.
  - tracked workspace write, branch mutation, commit/push, GitHub write, `wt`/`nrs`/rebuild 실행은 명시적 위임 없이는 금지한다.
  - 규칙 위반을 발견하면 finding 본문에 포함하지 말고 별도 violation 결과로 반환하도록 적는다.

---

## Phase 2: Consumer Skills Alignment

**Files:**
- Modify: `modules/shared/programs/claude/files/skills/parallel-audit/SKILL.md`
- Modify: `modules/shared/programs/claude/files/skills/plan-with-questions/SKILL.md`

- [ ] **Step 1: `parallel-audit`에 read-only 유지 + canonical contract 링크 추가**

  [parallel-audit/SKILL.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/parallel-audit/SKILL.md)의 direct path/주의사항 섹션을 수정한다.

  - auditor는 계속 read-only다. repo write와 tracked revert 예외를 추가하지 않는다.
  - `wt`, `nrs`, rebuild-class command는 lock-sensitive가 아니라 main-agent-only 명령으로 적는다.
  - violation 발생 시 `SAFE`로 종료하지 않고 `BLOCKED (VIOLATION)` 또는 동등한 명시 상태로 보고하도록 적는다.
  - 상세 hardening 정의는 `run-da` canonical contract를 링크로 참조한다.

- [ ] **Step 2: `plan-with-questions`의 Step 5/6을 `run-da` canonical contract로 정렬**

  [plan-with-questions/SKILL.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/plan-with-questions/SKILL.md)의 `/run-da for_plan` 연계 설명을 요약형으로 고친다.

  - direct Codex path에서도 conservative wait를 적용하고 premature kill/self-auditing substitution을 금지한다고 적는다.
  - reviewer는 full tool access를 악용해 tracked write를 하지 않으며, 필요한 PoC는 scratch/out-of-repo에 한정한다고 적는다.
  - 상세 authority/violation 규칙은 `run-da` canonical contract를 보라고 링크한다.

---

## Phase 3: Override And Generated Output Alignment

**Files:**
- Modify: `AGENTS.override.md`
- Modify: `modules/shared/programs/claude/files/skills/syncing-codex-harness/references/agents-override-template.md`
- Modify: `modules/shared/programs/claude/files/skills/syncing-codex-harness/references/sync.sh`

- [ ] **Step 1: 현재 `AGENTS.override.md`를 marker 기반 구조로 수동 이행**

  현재 [AGENTS.override.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/AGENTS.override.md#L1)는 markerless라 sync 경로 밖에 있다. 이 파일을 template 구조에 맞춰 다음 형태로 재구성한다.

  - 상단 title/role 소개 유지
  - `<!-- AUTO-GENERATED BY syncing-codex-harness -->` / `<!-- END ... -->` 블록 추가
  - `## 스킬 사용`, `## 도구 차이`는 auto-generated 블록 안으로 이동
  - 기존 `## 빌드` 규칙은 `## 사용자 커스텀` 아래에 남긴다

  이번 이슈에서는 generic ownership refactor나 markerless-file auto-upgrade 로직까지 넓히지 않는다.

- [ ] **Step 2: override/template/sync의 direct-Codex invariant를 concise summary로 제한**

  [AGENTS.override.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/AGENTS.override.md), [agents-override-template.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/syncing-codex-harness/references/agents-override-template.md), [sync.sh](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/modules/shared/programs/claude/files/skills/syncing-codex-harness/references/sync.sh)는 상세 규칙을 복제하지 않고 다음 invariant만 유지한다.

  - direct Codex path는 native subagent + `gpt-5.4` / `xhigh` hardening contract를 따른다
  - completed thread close 의무
  - `wt`/`nrs`/rebuild/GitHub write는 main-agent-only unless explicitly delegated
  - 상세 wait/write/violation 규칙은 `run-da` canonical contract를 보라고 링크 또는 문장으로 지시

- [ ] **Step 3: `sync.sh agents-override`가 markerized repo 파일과 정합적으로 동작하도록 확인**

  `sync.sh`의 auto-generated content 조립부는 새 concise invariant를 출력하도록 수정하되, marker replace 방식 자체는 유지한다. 이 단계의 목적은 현재 repo 파일을 marker 구조로 맞춘 뒤 future sync drift를 줄이는 것이다.

---

## Verification

- [ ] `git diff --check`
- [ ] `bash ./scripts/ai/warn-skill-consistency.sh`
- [ ] `bash ./tests/run-eval-tests.sh`
- [ ] `shellcheck modules/shared/programs/claude/files/skills/syncing-codex-harness/references/sync.sh`
- [ ] `bash ./modules/shared/programs/claude/files/skills/syncing-codex-harness/references/sync.sh agents-override "$PWD"` 실행 후, markerized [AGENTS.override.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/AGENTS.override.md)에서 auto-generated block만 갱신되고 `## 사용자 커스텀` 내용이 보존되는지 확인
- [ ] `bash ./scripts/ai/verify-ai-compat.sh`
- [ ] `nix flake check --no-build --all-systems`

---

## Side Effects To Handle

- direct Codex hardening을 여러 문서에 평면 복제하지 않는다. 상세 규칙 drift를 막기 위해 `run-da` canonical contract에만 full detail을 둔다.
- `parallel-audit`의 read-only 계약을 깨지 않는다. tracked write 허용 범위를 audit/Arbiter/Intensity까지 넓히지 않는다.
- stateful violation을 단순 discard로 덮지 않는다. invalidated unit은 `CLEAR`/`SAFE` 계산에서 제외하고, cleanup/incident 또는 rerun 없이는 완료로 간주하지 않는다.
- `wt`/`nrs`/rebuild/GitHub write는 main-agent-only로 유지해 current repo rule과 충돌하지 않게 한다.

---

## Rollback

문서 hardening이 과도하거나 generated override 흐름이 깨지면, 구현 커밋 하나를 기준으로 revert하고 아래를 다시 확인한다.

- markerized [AGENTS.override.md](/Users/green/Workspace/nixos-config/.claude/worktrees/issue_419/AGENTS.override.md)가 이전 구조로 복원되는지
- `sync.sh agents-override "$PWD"`가 기존 auto-generated block만 갱신하는지
- `warn-skill-consistency`, `run-eval-tests`, `verify-ai-compat`, `nix flake check --no-build --all-systems`가 이전 baseline으로 돌아오는지
