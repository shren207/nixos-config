# 트러블슈팅

Claude Code 관련 문제와 해결 방법을 정리합니다.

## 목차

- [플러그인 설치/삭제가 안 됨 (settings.json 읽기 전용)](#플러그인-설치삭제가-안-됨-settingsjson-읽기-전용)
- [PreToolUse 훅 JSON validation 에러](#pretooluse-훅-json-validation-에러)
- [Claude Code 설치 실패 (curl 미설치)](#claude-code-설치-실패-curl-미설치)

---

## 플러그인 설치/삭제가 안 됨 (settings.json 읽기 전용)

**증상**: `claude plugin uninstall` 명령 실행 시 "Plugin not found" 에러 발생. `/plugin` UI에는 설치된 것으로 표시되지만 삭제 불가.

```bash
$ claude plugin uninstall feature-dev@claude-plugins-official --scope user
Plugin not found: feature-dev
```

**원인**: `~/.claude/settings.json`이 Nix store의 읽기 전용 파일로 심볼릭 링크되어 있음.

```bash
$ ls -la ~/.claude/settings.json
lrwxr-xr-x  ... ~/.claude/settings.json -> /nix/store/xxx-claude-settings.json

$ touch ~/.claude/settings.json
touch: ~/.claude/settings.json: Permission denied
```

Claude Code는 플러그인 설치/삭제 시 `settings.json`을 수정하려고 하는데, Nix store 파일은 읽기 전용이므로 실패합니다.

**배경**: Claude Code는 런타임에 `settings.json`을 자동으로 업데이트하는 특성이 있습니다:

- 플러그인 설치/삭제
- CLI에서 설정 변경 (`claude config set ...`)
- Claude Code 버전 업데이트
- 기타 다양한 내부 동작

이는 Cursor가 GUI에서 설정 변경 시 `settings.json`을 자동 수정하는 것과 동일한 패턴입니다. 두 앱 모두 Nix의 불변(immutable) 파일 관리 방식과 충돌이 발생하므로 `mkOutOfStoreSymlink`가 필요합니다.

> **참고**: `mcp-config.json`은 Claude Code가 자동 생성하는 파일이 아닙니다. 사용자가 직접 생성/관리하며, `claude -m` 옵션으로 해당 파일을 MCP 설정으로 지정하여 사용합니다.

**해결**: `mkOutOfStoreSymlink`를 사용하여 nixos-config의 실제 파일을 직접 참조하도록 변경.

**1. `files/settings.json` 생성**

기존에 Nix에서 동적 생성하던 내용을 JSON 파일로 분리:

```bash
# modules/darwin/programs/claude/files/settings.json
{
  "cleanupPeriodDays": 7,
  "alwaysThinkingEnabled": true,
  ...
}
```

**2. `default.nix` 수정**

```nix
# 변경 전: Nix store 심볼릭 링크 (읽기 전용)
".claude/settings.json".source = jsonFormat.generate "claude-settings.json" settingsContent;

# 변경 후: mkOutOfStoreSymlink (양방향 수정 가능)
".claude/settings.json".source =
  config.lib.file.mkOutOfStoreSymlink "${claudeFilesPath}/settings.json";
```

**3. darwin-rebuild 실행**

```bash
nrs  # 또는 darwin-rebuild switch --flake .
```

**검증**:

```bash
# 심볼릭 링크 확인: nixos-config 경로를 가리켜야 함
$ ls -la ~/.claude/settings.json
lrwxr-xr-x  ... -> $HOME/<nixos-config-path>/modules/darwin/programs/claude/files/settings.json

# 쓰기 권한 확인
$ touch ~/.claude/settings.json && echo "O 쓰기 가능"
O 쓰기 가능

# 플러그인 설치/삭제 테스트
$ claude plugin install typescript-lsp@claude-plugins-official --scope user
✔ Successfully installed plugin: typescript-lsp@claude-plugins-official

$ claude plugin uninstall typescript-lsp@claude-plugins-official --scope user
✔ Successfully uninstalled plugin: typescript-lsp
```

**Cursor와의 비교**:

| 항목 | Cursor | Claude Code |
|------|--------|-------------|
| 확장/플러그인 관리 | Nix로 선언적 관리 (UI에서 설치 불가) | CLI로 자유롭게 관리 |
| `settings.json` | `mkOutOfStoreSymlink` (양방향) | `mkOutOfStoreSymlink` (양방향) |
| 런타임 파일 수정 | GUI 설정 변경, 확장 설정 시 자동 수정 | 플러그인/MCP 설정 시 자동 수정 |

두 앱 모두 `settings.json`의 런타임 수정이 필요하므로 `mkOutOfStoreSymlink`를 사용합니다. 차이점은 확장/플러그인 관리 방식뿐입니다: Cursor는 확장을 Nix로 고정 관리하고, Claude Code는 플러그인을 CLI로 자유롭게 관리합니다.

> **참고**: Claude Code 설정은 `modules/shared/programs/claude/default.nix`에서 관리됩니다.

---

## PreToolUse 훅 JSON validation 에러

**증상**: Claude Code에서 git 명령어 실행 시 간헐적으로 다음 에러 발생:

```
PreToolUse:Bash hook error: JSON validation failed: Hook JSON output validation failed:
- : Invalid input
```

특히 체인 명령어(`git add && git commit && git push`) 실행 시 자주 발생.

**원인 분석**:

이 프로젝트는 lefthook 사용을 위해 git 명령어를 `nix develop -c`로 감싸는 PreToolUse 훅을 사용합니다. 문제는 두 가지입니다:

**1. 체인 명령어 처리 실패:**

```bash
# 입력
git add . && git commit -m "test" && git push

# 기존 방식 출력
nix develop -c git add . && git commit -m "test" && git push
#            └── nix 환경 ──┘ └───── 시스템 셸 (nix 환경 아님) ─────┘
```

`nix develop -c`는 첫 번째 명령어만 nix 환경에서 실행하고, `&&` 이후는 원래 셸에서 실행됩니다.

**2. JSON 이스케이프 불안정:**

```bash
# 기존 방식
wrapped_command="nix develop -c $command"
echo "{ \"command\": $(echo "$wrapped_command" | jq -R .) }"
```

커밋 메시지에 따옴표, 한글, 백틱, `$변수` 등 특수문자가 포함되면 JSON 이스케이프 실패.

**해결**: Base64 인코딩으로 모든 특수문자 문제 회피

```bash
# 새로운 방식
encoded=$(printf '%s' "$command" | base64 | tr -d '\n')
wrapped_command="echo $encoded | base64 -d | nix develop -c bash"
```

**장점:**

| 항목 | 기존 방식 | Base64 방식 |
|------|----------|-------------|
| 체인 명령어 | 첫 번째만 nix 환경 | 전체가 nix 환경 O |
| 특수문자 | 이스케이프 필요 | 안전하게 처리 O |
| JSON 출력 | 멀티라인 가능성 | 항상 단일 라인 O |
| 복잡성 | 분기 로직 필요 | 단순함 O |

**수정된 스크립트** (`.claude/scripts/wrap-git-with-nix-develop.sh`):

```bash
#!/bin/bash
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')

if [[ "$tool_name" != "Bash" ]]; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // empty')

if [[ -z "$command" ]]; then
  exit 0
fi

# git add/commit/push/stash로 시작하고, 아직 래핑되지 않은 경우
if [[ "$command" =~ ^git[[:space:]]+(add|commit|push|stash) ]] && \
   [[ ! "$command" =~ ^nix[[:space:]]+develop ]] && \
   [[ ! "$command" =~ ^echo[[:space:]].*base64 ]]; then

  # Base64 인코딩으로 모든 특수문자 문제 회피
  encoded=$(printf '%s' "$command" | base64 | tr -d '\n')
  wrapped_command="echo $encoded | base64 -d | nix develop -c bash"

  jq -n \
    --arg cmd "$wrapped_command" \
    --arg msg "lefthook 사용을 위해 nix develop 환경에서 실행합니다." \
    '{
      hookSpecificOutput: {
        permissionDecision: "allow",
        updatedInput: { command: $cmd }
      },
      systemMessage: $msg
    }'
  exit 0
fi

exit 0
```

**검증**:

```bash
# 1. 체인 명령어 테스트
echo '{"tool_name":"Bash","tool_input":{"command":"git add . && git commit -m \"test\""}}' | \
  bash .claude/scripts/wrap-git-with-nix-develop.sh | jq .

# 2. 한글 메시지 테스트
echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"feat: 새로운 기능\""}}' | \
  bash .claude/scripts/wrap-git-with-nix-develop.sh | jq .

# 3. Base64 디코딩 검증
output=$(echo '{"tool_name":"Bash","tool_input":{"command":"git add . && git commit -m \"test\""}}' | \
  bash .claude/scripts/wrap-git-with-nix-develop.sh)
encoded=$(echo "$output" | jq -r '.hookSpecificOutput.updatedInput.command' | sed 's/echo \([^ ]*\) |.*/\1/')
echo "$encoded" | base64 -d
# 출력: git add . && git commit -m "test"
```

**롤백**:

문제 발생 시 훅을 일시 비활성화할 수 있습니다:

```bash
# 훅 비활성화
mv .claude/settings.local.json .claude/settings.local.json.bak

# 또는 원본 스크립트 복구
git checkout .claude/scripts/wrap-git-with-nix-develop.sh
```

**디버깅**:

스크립트에 디버그 로깅을 활성화하여 문제를 진단할 수 있습니다:

```bash
# .claude/scripts/wrap-git-with-nix-develop.sh 11-13행 주석 해제
exec 2>>/tmp/claude-hook-debug.log
echo "=== $(date) ===" >&2
echo "Input: $input" >&2

# 로그 확인
tail -f /tmp/claude-hook-debug.log
```

> **참고**: PreToolUse 훅은 `~/.claude/hooks/` 디렉토리에서 관리됩니다. 훅 설정 방법은 Claude Code 공식 문서를 참고하세요.

---

## Claude Code 설치 실패 (curl 미설치)

> **발생 시점**: NixOS 초기 설치 시

**증상**: `nixos-rebuild switch` 시 Claude Code 설치 단계에서 실패.

```
Installing Claude Code binary...
Either curl or wget is required but neither is installed
```

**원인**: Home Manager activation 스크립트에서 `${pkgs.curl}/bin/curl`을 사용하는데, `curl`이 `home.packages`에 포함되지 않음.

```nix
# 문제의 코드 (modules/shared/programs/claude/default.nix)
home.activation.installClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh | ${pkgs.bash}/bin/bash
'';
```

**해결**: `home.packages`에 `curl` 추가

```nix
# modules/nixos/home.nix
home.packages = with pkgs; [
  curl  # Claude Code 설치에 필요
  # ... 다른 패키지들
];
```

**참고**: activation 스크립트에서 사용하는 패키지는 명시적으로 의존성에 포함되어야 합니다.
