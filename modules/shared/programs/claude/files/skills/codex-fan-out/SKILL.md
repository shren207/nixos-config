---
name: codex-fan-out
argument-hint: "\"주제\" [에이전트수]"
description: |
  codex exec 기반 병렬 fan-out. Agent tool 대신 사용하여 fan-in cache miss를 방지한다.
  Trigger: 'codex fan-out', '병렬 조사', 'codex 에이전트', 'fan-out 실행'.
  NOT for DA (use run-da). NOT for 전수조사 (use parallel-audit).
---

# codex exec 병렬 fan-out

Agent tool로 서브에이전트를 병렬 호출하면 fan-in 시 cache miss가 발생한다
(TASK_NOTIFICATION attachment 가변 순서 누적 → cache prefix 불일치).
codex exec는 별도 프로세스로 실행되어 메인 컨텍스트에 attachment를 주입하지 않는다.

이 스킬은 **codex exec 병렬 호출 패턴만 정의**한다.
역할 카탈로그, fan-in 통합 전략, 프롬프트 내용은 호출자의 책임이다.

## 호출

```
/codex-fan-out "주제" 6
```

- 첫 인자: 조사 주제 또는 작업 설명
- 두 번째 인자: 에이전트 수 (기본 4, 최대 6)

호출자는 에이전트별 역할과 프롬프트 내용을 직접 결정한다.
이 스킬은 실행 기계만 제공한다.

## 런타임 분기

run-da의 3-way contract와 동일한 구조를 따른다.

| 경로 | 조건 | 실행 |
|------|------|------|
| **Claude Code 세션** | `Agent` tool 사용 가능 | codex exec 기본. 사전점검 실패 시 Agent tool fallback |
| **headless 세션** | CI, `claude -p`, `codex exec` subprocess | codex exec only. 실패 시 에러 |
| **Codex 세션** | `spawn_agent` API 사용 가능 | 이 스킬 대상 아님. native subagent 사용 |

### 사전점검

```zsh
command -v codex >/dev/null && codex --version >/dev/null 2>&1
```

- 성공 → codex exec 실행
- 실패 + Claude Code 세션 → Agent tool fallback (`run_in_background: true`)
- 실패 + headless 세션 → 에러 보고 후 중단

## 실행 패턴

using-codex-exec 패턴 1 (기본 exec)과 run-da의 codex exec 경로 위생 규칙을 따른다.

### 세션 네임스페이스

```zsh
_FO_SID="${CODEX_COMPANION_SESSION_ID:+${CODEX_COMPANION_SESSION_ID:0:8}}"
[ -z "$_FO_SID" ] && _FO_SID="$(printf '%s' "$PWD" | shasum | head -c 8)"
```

### 프롬프트 생성 + 실행

1. 임시 디렉토리를 생성한다:
   ```zsh
   FO_DIR=$(mktemp -d /tmp/fo-${_FO_SID}-XXXXXX)
   echo "FO_DIR=$FO_DIR"
   ```

2. 에이전트별 프롬프트 파일을 생성한다 (`$FO_DIR/{agent-N}.md`):
   ```zsh
   (umask 077; cat > "$FO_DIR/agent-1.md" <<'PROMPT'
   {호출자가 결정한 프롬프트 내용}

   파일을 수정하지 마라. 읽기와 검색만 수행하라.
   PROMPT
   )
   ```

   **no-write boundary 필수**: 모든 에이전트 프롬프트 마지막에
   `"파일을 수정하지 마라. 읽기와 검색만 수행하라."` 를 포함한다.

3. 각 에이전트를 **background Bash tool 호출**로 병렬 실행한다:
   ```zsh
   cat "$FO_DIR/agent-1.md" | codex exec --full-auto --ephemeral \
     -c model_reasoning_effort="high" \
     -o "$FO_DIR/agent-1-result.md" \
     - \
     2>"$FO_DIR/agent-1-stderr.log"
   ```
   - `run_in_background: true`로 Bash tool을 호출한다.
   - `$FO_DIR`은 첫 호출에서 출력한 리터럴 경로를 사용한다 (Bash tool 간 변수 비공유).
   - stdin pipe가 EOF를 닫으므로 `< /dev/null`은 불필요하다.

4. 모든 background 완료 후, 각 결과 파일을 Read 도구로 수집한다.

### reasoning effort

| 기본 | 심층 조사 |
|------|----------|
| `-c model_reasoning_effort="high"` | `-c model_reasoning_effort="xhigh"` |

기본은 `high`. 호출자가 명시적으로 심층 조사를 요청한 경우에만 `xhigh`를 사용한다.

## 실패 처리

| 상황 | 대응 |
|------|------|
| 결과 파일 없음 | 해당 에이전트만 재실행 |
| 빈 결과 파일 | 해당 에이전트만 재실행 |
| exit code 비정상 | stderr 확인 후 해당 에이전트만 재실행 |
| 재실행 실패 + Claude Code | Agent tool fallback |
| 재실행 실패 + headless | 에러 보고 (부분 결과로 진행 여부는 호출자 판단) |

## Agent tool fallback (Claude Code 세션 한정)

codex exec 사용 불가 시 Agent tool로 대체한다.

```
Agent({
  description: "...",
  subagent_type: "Explore",
  prompt: "{프롬프트 내용}\n\n파일을 수정하지 마라.",
  run_in_background: true,
  model: "sonnet"
})
```

- `model: "sonnet"` — fan-out 에이전트는 Sonnet으로 실행
- no-write boundary를 프롬프트에 포함 (구조적 보증이 아닌 프롬프트 수준 제약)

## 다른 스킬에서 참조

다른 스킬에서 codex exec fan-out 패턴이 필요하면 이 스킬의 실행 패턴 섹션을 참조한다.
Skill tool 호출이 아닌 문서 참조 방식이다.

참조 예시 (plan-with-questions Step I-1):
```
codex exec fan-out 패턴은 /codex-fan-out 스킬 참조.
```

## 주의사항

- `--full-auto`는 workspace-write 권한을 부여하므로, 반드시 no-write boundary를 프롬프트에 명시한다.
- `& + wait` shell-level 병렬을 사용하지 않는다. Bash tool의 `run_in_background`를 사용한다.
- 인라인 인자 `"$(cat file)"`는 사용하지 않는다. stdin pipe만 사용한다.
- 정리: fan-out 완료 후 `rm -rf "$FO_DIR"`로 임시 디렉토리를 정리한다.
