# 트러블슈팅

자주 발생하는 문제와 해결 방법을 정리합니다.

## 목차

- [Nix 관련](#nix-관련)
  - [darwin-rebuild 빌드 속도가 느림](#darwin-rebuild-빌드-속도가-느림)
  - [experimental Nix feature 'nix-command' is disabled](#experimental-nix-feature-nix-command-is-disabled)
  - [flake 변경이 인식되지 않음](#flake-변경이-인식되지-않음)
  - [상세 에러 확인](#상세-에러-확인)
- [nix-darwin 관련](#nix-darwin-관련)
  - [왜 darwin-rebuild에 sudo가 필요한가?](#왜-darwin-rebuild에-sudo가-필요한가)
  - [darwin-rebuild: command not found (부트스트랩 전)](#darwin-rebuild-command-not-found-부트스트랩-전)
  - [darwin-rebuild: command not found (설정 적용 후)](#darwin-rebuild-command-not-found-설정-적용-후)
  - [/etc/bashrc, /etc/zshrc 충돌](#etcbashrc-etczshrc-충돌)
  - [primary user does not exist](#primary-user-does-not-exist)
- [SSH/인증 관련](#ssh인증-관련)
  - [sudo 사용 시 Private 저장소 접근 실패](#sudo-사용-시-private-저장소-접근-실패)
  - [SSH 키 invalid format](#ssh-키-invalid-format)
- [Home Manager 관련](#home-manager-관련)
  - [home.file의 recursive + executable이 작동하지 않음](#homefile의-recursive--executable이-작동하지-않음)
  - [builtins.toJSON이 한 줄로 생성됨](#builtinstojson이-한-줄로-생성됨)
- [Git 관련](#git-관련)
  - [delta가 적용되지 않음](#delta가-적용되지-않음)
  - [~/.gitconfig과 Home Manager 설정이 충돌함](#gitconfig과-home-manager-설정이-충돌함)
- [launchd 관련](#launchd-관련)
- [Hammerspoon 관련](#hammerspoon-관련)
  - [Ghostty가 새 인스턴스로 열림 (Dock에 여러 아이콘)](#ghostty가-새-인스턴스로-열림-dock에-여러-아이콘)
  - [Ghostty +new-window가 macOS에서 동작하지 않음](#ghostty-new-window가-macos에서-동작하지-않음)
  - [open --args가 이미 실행 중인 앱에 인수 전달 안 됨](#open---args가-이미-실행-중인-앱에-인수-전달-안-됨)
  - [cd 명령어가 기존 창에 입력됨 (타이밍 문제)](#cd-명령어가-기존-창에-입력됨-타이밍-문제)
  - [경로에 특수문자가 있으면 zsh 에러 발생](#경로에-특수문자가-있으면-zsh-에러-발생)
- [Cursor 관련](#cursor-관련)
  - [Spotlight에서 Cursor가 2개로 표시됨](#spotlight에서-cursor가-2개로-표시됨)
  - [Cursor Extensions GUI에서 확장이 0개로 표시됨](#cursor-extensions-gui에서-확장이-0개로-표시됨)
  - ["Extensions have been modified on disk" 경고](#extensions-have-been-modified-on-disk-경고)
  - [Cursor에서 확장 설치/제거가 안 됨](#cursor에서-확장-설치제거가-안-됨)

---

## Nix 관련

### darwin-rebuild 빌드 속도가 느림

**증상**: `darwin-rebuild switch` 실행 시 특정 호스트에서 비정상적으로 오래 걸림

```
# 예시: 동일한 설정인데 호스트마다 속도 차이
집 맥북 (M1 Max): ~1분
회사 맥북 (M3 Pro): ~3-5분
```

**원인 분석**:

`darwin-rebuild`는 다음 단계를 거칩니다:

| 단계 | 설명 | 소요 시간 |
|------|------|----------|
| 1. flake input 확인 | GitHub에 접속하여 새 버전 확인 | ~1-2분 |
| 2. substituter 확인 | cache.nixos.org에서 패키지 확인 | ~30초 |
| 3. 빌드 | 로컬에서 derivation 빌드 | ~10초 |

대부분의 시간이 **네트워크 I/O**에 소비됩니다 (CPU 사용률이 6% 정도로 매우 낮음).

**진단 방법**:

```bash
# 1. CPU 사용률 확인 (낮으면 I/O 병목)
time sudo darwin-rebuild switch --flake .
# 출력 예: 5.73s user 5.97s system 6% cpu 2:56.01 total
#          ↑ CPU 시간은 12초, 총 시간은 3분 → I/O 대기가 대부분

# 2. 네트워크 속도 테스트
curl -o /dev/null -s -w '%{time_total}' https://api.github.com/rate_limit
curl -o /dev/null -s -w '%{time_total}' https://cache.nixos.org/nix-cache-info

# 3. 캐시 상태 확인
ls -d /nix/store/*-source 2>/dev/null | wc -l
```

**해결 방법**:

**방법 1: `--offline` 플래그 사용 (가장 효과적)**

```bash
# flake.lock이 동기화되어 있고, 새 패키지가 없는 경우
sudo darwin-rebuild switch --flake . --offline

# 또는 alias 사용
nrs-offline
```

- 네트워크 요청 없이 로컬 캐시만 사용
- **속도**: 3분 → 10초 (약 18배 향상)

**방법 2: 병렬 다운로드 설정 증가**

`modules/shared/configuration.nix`:

```nix
nix.settings = {
  max-substitution-jobs = 128;  # 기본값 16
  http-connections = 50;        # 기본값 25
};
```

**방법 3: GitHub 토큰 설정 (rate limit 해제)**

```bash
mkdir -p ~/.config/nix
echo 'access-tokens = github.com=ghp_YOUR_TOKEN' >> ~/.config/nix/nix.conf
```

**권장 워크플로우**:

```bash
# 1. 한 호스트에서 flake update 후 push
nix flake update
nrs  # 또는 sudo darwin-rebuild switch --flake .
git add flake.lock && git commit -m "update" && git push

# 2. 다른 호스트에서 pull 후 offline rebuild
git pull
nrs-offline  # ~10초 완료!
```

> **참고**: alias 사용법은 [FEATURES.md](FEATURES.md#darwin-rebuild-alias)를 참고하세요.

---

### experimental Nix feature 'nix-command' is disabled

**에러 메시지**:
```
error: experimental Nix feature 'nix-command' is disabled; add '--extra-experimental-features nix-command' to enable it
```

**원인**: Nix의 새로운 명령어(`nix run`, `nix develop` 등)와 flakes 기능은 기본적으로 비활성화되어 있습니다.

**해결**:

**방법 1: 임시 활성화 (일회성)**
```bash
nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake .
```

**방법 2: 영구 활성화 (권장)**
```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

이후에는 옵션 없이 사용 가능:
```bash
nix run nix-darwin -- switch --flake .
```

### flake 변경이 인식되지 않음

Nix flakes는 git으로 추적되는 파일만 인식합니다:
```bash
git add <changed-files>
darwin-rebuild switch --flake .
```

### 상세 에러 확인

```bash
darwin-rebuild switch --flake . --show-trace
```

---

## nix-darwin 관련

### 왜 darwin-rebuild에 sudo가 필요한가?

`darwin-rebuild switch`는 **시스템 수준 설정**을 변경하기 때문에 root 권한이 필요합니다.

**sudo가 필요한 이유**:

| 변경 대상 | 예시 |
|----------|------|
| `/etc/` 파일 | `/etc/nix/nix.conf`, `/etc/bashrc`, `/etc/zshrc` |
| 시스템 심볼릭 링크 | `/run/current-system` |
| launchd 서비스 | 시스템 데몬 등록 |
| macOS 시스템 설정 | `system.defaults` (Dock, Finder 등) |

**실행 방법**:
```bash
# Private 저장소 사용 시 SSH_AUTH_SOCK 유지 필요
sudo --preserve-env=SSH_AUTH_SOCK darwin-rebuild switch --flake .
```

> **참고**: Home Manager만 단독으로 사용하면 (`home-manager switch`) sudo 없이 가능합니다. 하지만 nix-darwin과 통합된 구조에서는 `darwin-rebuild`가 시스템 + 사용자 설정을 모두 처리하므로 sudo가 필요합니다.

### darwin-rebuild: command not found (부트스트랩 전)

**에러 메시지**:
```
zsh: command not found: darwin-rebuild
```

**원인**: `darwin-rebuild` 명령어는 nix-darwin이 설치된 후에만 사용할 수 있습니다. 새 Mac에서 처음 설정할 때 이 에러가 발생합니다.

**해결**: 먼저 nix-darwin 부트스트랩을 완료해야 합니다:
```bash
nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake .
```

부트스트랩 완료 후에는 `darwin-rebuild switch --flake .` 명령어를 사용할 수 있습니다.

### darwin-rebuild: command not found (설정 적용 후)

새 터미널에서 `darwin-rebuild` 명령어를 찾지 못하는 경우:

```bash
# 방법 1: 전체 경로로 실행
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .

# 방법 2: 쉘 재시작 후 다시 시도
exec $SHELL
darwin-rebuild switch --flake .
```

### /etc/bashrc, /etc/zshrc 충돌

**에러 메시지**:
```
error: Unexpected files in /etc, aborting activation
The following files have unrecognized content and would be overwritten:

  /etc/bashrc
  /etc/zshrc

Please check there is nothing critical in these files, rename them by adding .before-nix-darwin to the end, and then try again.
```

**원인**: nix-darwin이 `/etc/bashrc`와 `/etc/zshrc`를 관리하려고 하지만, 기존 시스템 파일이 있어서 충돌이 발생합니다.

**해결**: 기존 파일을 백업 후 다시 시도:

```bash
sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin
sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin
sudo --preserve-env=SSH_AUTH_SOCK nix run nix-darwin -- switch --flake .
```

> **참고**: 백업된 파일은 나중에 필요하면 복원할 수 있습니다.

### primary user does not exist

**에러 메시지**:
```
error: primary user `username` does not exist, aborting activation
Please ensure that `system.primaryUser` is set to the name of an existing user.
```

**원인**: `flake.nix`의 `username` 변수가 현재 macOS 사용자와 일치하지 않습니다.

**해결**:

1. 현재 사용자명 확인:
   ```bash
   whoami
   ```

2. `flake.nix`에서 `username` 수정:
   ```nix
   username = "your-actual-username";  # whoami 결과로 변경
   ```

3. 다시 빌드:
   ```bash
   sudo --preserve-env=SSH_AUTH_SOCK nix run nix-darwin -- switch --flake .
   ```

---

## SSH/인증 관련

### sudo 사용 시 Private 저장소 접근 실패

**에러 메시지**:
```
warning: $HOME ('/Users/glen') is not owned by you, falling back to the one defined in the 'passwd' file ('/var/root')
git@github.com: Permission denied (publickey).
error: Failed to fetch git repository 'ssh://git@github.com/shren207/nixos-config-secret'
```

**원인**: `sudo`로 실행하면 root 사용자로 전환되어 현재 사용자의 SSH 키(`~/.ssh/id_ed25519`)에 접근할 수 없습니다. Private 저장소 fetch 시 SSH 인증이 실패합니다.

**해결**: SSH agent를 사용하여 키를 메모리에 로드하고, `sudo` 실행 시 `SSH_AUTH_SOCK` 환경변수를 유지합니다:

```bash
# 1. SSH agent에 키 추가
ssh-add ~/.ssh/id_ed25519

# 2. SSH_AUTH_SOCK 환경변수를 유지하면서 sudo 실행
sudo --preserve-env=SSH_AUTH_SOCK nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake .
```

**왜 sudo가 필요한가?**

nix-darwin은 시스템 설정을 변경하기 때문에 root 권한이 필요합니다:
- `/run/current-system` 심볼릭 링크 생성
- `/etc/nix/nix.conf` 수정
- launchd 서비스 등록

### SSH 키 invalid format

**에러 메시지**:
```
Load key "/Users/username/.ssh/id_ed25519": invalid format
git@github.com: Permission denied (publickey).
```

**원인**: SSH 키 파일이 손상되었거나, 복사/붙여넣기 과정에서 형식이 깨졌습니다. 일반적인 원인:
1. 파일 끝에 빈 줄(newline)이 없음
2. 줄 끝에 불필요한 공백이 있음
3. 줄바꿈 문자가 잘못됨 (Windows CRLF vs Unix LF)

**해결**:

1. **파일 끝에 빈 줄 추가**:
   ```bash
   echo "" >> ~/.ssh/id_ed25519
   ```

2. **줄 끝 공백 제거**:
   ```bash
   sed -i '' 's/[[:space:]]*$//' ~/.ssh/id_ed25519
   ```

3. **원본 파일 다시 복사** (권장):
   - USB, AirDrop, scp 등으로 **파일 자체**를 복사
   - 텍스트 복사/붙여넣기 대신 바이너리 복사 사용

**검증**:
```bash
# SSH 키 유효성 검사
ssh-keygen -y -f ~/.ssh/id_ed25519
# 공개키가 출력되면 정상

# GitHub 연결 테스트
ssh -T git@github.com
```

---

## Home Manager 관련

### home.file의 recursive + executable이 작동하지 않음

`recursive = true`와 `executable = true`를 함께 사용하면 실행 권한이 적용되지 않습니다:

```nix
# ❌ 작동 안 함
".claude/hooks" = {
  source = "${claudeDir}/hooks";
  recursive = true;
  executable = true;  # 무시됨
};

# ✅ 해결: 개별 파일로 지정
".claude/hooks/stop-notification.sh" = {
  source = "${claudeDir}/hooks/stop-notification.sh";
  executable = true;
};
```

### builtins.toJSON이 한 줄로 생성됨

**문제**: `home.file.".config/app/settings.json".text = builtins.toJSON { ... }`를 사용하면 JSON이 minified(한 줄)로 생성됩니다.

**원인**: `builtins.toJSON`은 공백/줄바꿈 없이 compact JSON을 생성합니다.

**해결**: `pkgs.formats.json`을 사용하여 pretty-printed JSON 생성:

```nix
let
  jsonFormat = pkgs.formats.json { };
  settingsContent = {
    key1 = "value1";
    key2 = true;
  };
in
{
  home.file.".config/app/settings.json".source =
    jsonFormat.generate "settings.json" settingsContent;
}
```

**차이점**:
- `builtins.toJSON`: `{"key1":"value1","key2":true}` (한 줄)
- `pkgs.formats.json`: 들여쓰기와 줄바꿈이 포함된 readable JSON

---

## Git 관련

### delta가 적용되지 않음

**증상**: `programs.delta.enable = true`를 설정했는데 `git diff`에서 delta가 사용되지 않음

**원인**: `enableGitIntegration`이 명시적으로 설정되지 않음. Home Manager 최신 버전에서는 자동 활성화가 deprecated됨.

**진단**:
```bash
# delta 설치 확인
which delta
# 예상: /etc/profiles/per-user/<username>/bin/delta

# git pager 설정 확인
git config --get core.pager
# 비어있으면 문제
```

**해결**: `enableGitIntegration = true` 추가

```nix
# modules/shared/programs/git/default.nix
programs.delta = {
  enable = true;
  enableGitIntegration = true;  # 이 줄이 필수!
  options = {
    navigate = true;
    dark = true;
  };
};
```

> **참고**: `programs.delta`는 `programs.git`과 별도 모듈입니다. 이전에는 `programs.git.delta`였지만, 현재는 분리되었습니다.

### ~/.gitconfig과 Home Manager 설정이 충돌함

**증상**: NixOS로 Git 설정을 관리하는데, 수동 설정(`~/.gitconfig`)이 계속 적용됨

**원인**: Git은 여러 설정 파일을 병합하여 사용합니다:

| 우선순위 | 경로 | 설명 |
|---------|------|------|
| 1 | `~/.gitconfig` | 수동 관리 (존재하면 읽음) |
| 2 | `~/.config/git/config` | Home Manager 관리 |
| 3 | `.git/config` | 프로젝트별 로컬 |

Home Manager는 XDG 표준 경로(`~/.config/git/config`)를 사용하므로, `~/.gitconfig`이 있으면 두 설정이 병합됩니다.

**해결**: `~/.gitconfig` 삭제

```bash
# 백업 후 삭제 (권장)
mv ~/.gitconfig ~/.gitconfig.backup

# 또는 바로 삭제
rm ~/.gitconfig
```

**확인**:
```bash
# Home Manager가 관리하는 설정만 표시되어야 함
git config --list --show-origin | grep "\.config/git"
```

---

## launchd 관련

### launchd 에이전트 상태 확인

```bash
# 등록된 에이전트 확인
launchctl list | grep com.green

# 로그 확인
cat ~/Library/Logs/folder-actions/*.log
```

---

## Hammerspoon 관련

Finder → Ghostty 터미널 열기 단축키 구현 시 발생한 문제들입니다.

### Ghostty가 새 인스턴스로 열림 (Dock에 여러 아이콘)

**증상**: 단축키로 Ghostty를 열 때마다 Dock에 새로운 Ghostty 아이콘이 생성됨

**원인**: `hs.task.new`로 바이너리를 직접 실행하면 매번 새 인스턴스가 생성됨

```lua
-- ❌ 새 인스턴스 생성됨
hs.task.new("/Applications/Ghostty.app/Contents/MacOS/ghostty", nil, args):start()
```

**해결**: `open` 명령어를 사용하거나, 실행 중인 앱에 키 입력 시뮬레이션 사용

```lua
-- ✅ 기존 인스턴스 사용
hs.task.new("/usr/bin/open", nil, {"-a", "Ghostty"}):start()

-- ✅ 또는 키 입력 시뮬레이션
ghostty:activate()
hs.eventtap.keyStroke({"cmd"}, "n")  -- 새 창
```

---

### Ghostty +new-window가 macOS에서 동작하지 않음

**증상**: `ghostty +new-window --working-directory=/path` 실행해도 아무 일도 일어나지 않음

**원인**: Ghostty의 `+new-window` 액션은 **GTK (Linux) 전용**이며 macOS에서는 지원되지 않음

```bash
$ ghostty +new-window --help
# ...
# Only supported on GTK.
```

**해결**: macOS에서는 다른 방법 사용 필요:
- Ghostty 미실행 시: `open -a Ghostty --args --working-directory=/path`
- Ghostty 실행 중: `Cmd+N` 키 입력 + `cd` 명령어 타이핑

---

### open --args가 이미 실행 중인 앱에 인수 전달 안 됨

**증상**: `open -a Ghostty --args --working-directory=/path` 실행해도 Ghostty가 해당 경로에서 열리지 않음

**원인**: macOS의 `open` 명령어는 앱이 이미 실행 중이면 **인수를 전달하지 않고 단순 활성화**만 함

**해결**: Ghostty가 실행 중인지 확인하고 분기 처리

```lua
local ghostty = hs.application.get("Ghostty")

if ghostty then
  -- 실행 중: Cmd+N으로 새 창 + cd 명령어
  ghostty:activate()
  hs.timer.doAfter(0.2, function()
    hs.eventtap.keyStroke({"cmd"}, "n")
    hs.timer.doAfter(0.6, function()
      hs.eventtap.keyStrokes('cd "' .. path .. '" && clear')
      hs.eventtap.keyStroke({}, "return")
    end)
  end)
else
  -- 미실행: open으로 시작
  hs.task.new("/usr/bin/open", nil, {"-a", "Ghostty", "--args", "--working-directory=" .. path}):start()
end
```

---

### cd 명령어가 기존 창에 입력됨 (타이밍 문제)

**증상**: 단축키 실행 시 새 창이 아닌 기존 창에 `cd` 명령어가 입력됨

**원인**: `Cmd+N`으로 새 창이 열리기 전에 `cd` 명령어가 입력됨 (딜레이 부족)

**해결**: 적절한 딜레이 추가

```lua
-- ❌ 딜레이 부족
hs.timer.doAfter(0.1, function()
  hs.eventtap.keyStroke({"cmd"}, "n")
  hs.timer.doAfter(0.2, function()  -- 너무 짧음
    hs.eventtap.keyStrokes('cd ...')
  end)
end)

-- ✅ 충분한 딜레이
hs.timer.doAfter(0.2, function()
  hs.eventtap.keyStroke({"cmd"}, "n")
  hs.timer.doAfter(0.6, function()  -- 새 창이 완전히 열릴 때까지 대기
    hs.eventtap.keyStrokes('cd ...')
  end)
end)
```

> **참고**: 딜레이는 시스템 성능에 따라 조정이 필요할 수 있음. 0.6초가 안정적.

---

### 경로에 특수문자가 있으면 zsh 에러 발생

**증상**: `[FA]Get Compressed Video` 같은 폴더에서 실행 시 에러

```
zsh: no matches found: /Users/green/FolderActions/[FA]Get
```

**원인**: `[`, `]` 등의 특수문자가 zsh glob 패턴으로 해석됨. 공백도 문제 발생.

**해결**: 경로를 큰따옴표로 감싸기

```lua
-- ❌ 특수문자/공백 문제
hs.eventtap.keyStrokes('cd ' .. path .. ' && clear')

-- ✅ 따옴표로 감싸기
hs.eventtap.keyStrokes('cd "' .. path .. '" && clear')
```

---

## Cursor 관련

### Spotlight에서 Cursor가 2개로 표시됨

**원인**: `programs.vscode.package = pkgs.code-cursor` 사용 시 Nix store에도 Cursor가 설치됨

**해결**: 현재 설정은 이 문제를 해결한 구조입니다:
- Cursor 앱: Homebrew Cask로만 설치 (`homebrew.nix`)
- 확장 관리: `home.file`로 직접 관리 (`cursor/default.nix`)

```bash
# 확인: Nix store에 Cursor 앱이 없어야 함
nix-store -qR /nix/var/nix/profiles/system | grep -i "cursor.*Applications"
# (출력 없음이 정상)
```

### Cursor Extensions GUI에서 확장이 0개로 표시됨

**원인**: `extensions.json` 형식이 Cursor가 기대하는 형식과 다름

**해결**: `extensions.json`에 `location`과 `metadata` 필드가 필요:

```json
{
  "identifier": {"id": "..."},
  "version": "...",
  "location": {"$mid": 1, "path": "/Users/.../.cursor/extensions/...", "scheme": "file"},
  "relativeLocation": "...",
  "metadata": {"installedTimestamp": 0, "targetPlatform": "undefined"}
}
```

현재 `cursor/default.nix`는 이 형식으로 생성하도록 구성되어 있습니다.

```bash
# 확인: extensions.json 형식
cat ~/.cursor/extensions/extensions.json | jq '.[0]'
```

### "Extensions have been modified on disk" 경고

**원인**: `darwin-rebuild switch` 실행 시 `~/.cursor/extensions` 심볼릭 링크가 새 Nix store 경로로 변경됨

**해결**: 정상적인 동작입니다
- "Reload Window" 클릭
- 또는 Cursor 재시작

이 경고는 Nix 기반 불변(immutable) 확장 관리의 특성입니다.

### Cursor에서 확장 설치/제거가 안 됨

**원인**: `~/.cursor/extensions`가 Nix store로 심볼릭 링크되어 읽기 전용

**해결**: 의도된 동작입니다. 확장 관리는 Nix로만 가능:

```bash
# 1. cursor/default.nix에서 cursorExtensions 수정
# 2. 적용
git add modules/darwin/programs/cursor/default.nix
darwin-rebuild switch --flake .
# 3. Cursor 재시작
```

> **참고**: Cursor 확장 관리에 대한 자세한 내용은 [CURSOR_EXTENSIONS.md](CURSOR_EXTENSIONS.md)를 참고하세요.
