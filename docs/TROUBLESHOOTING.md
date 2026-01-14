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
  - [killall cfprefsd로 인한 스크롤 방향 롤백](#killall-cfprefsd로-인한-스크롤-방향-롤백)
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
- [Claude Code 관련](#claude-code-관련)
  - [플러그인 설치/삭제가 안 됨 (settings.json 읽기 전용)](#플러그인-설치삭제가-안-됨-settingsjson-읽기-전용)
- [Ghostty 관련](#ghostty-관련)
  - [한글 입력소스에서 Ctrl/Opt 단축키가 동작하지 않음](#한글-입력소스에서-ctrlopt-단축키가-동작하지-않음)
  - [Ctrl+C 입력 시 "5u9;" 같은 문자가 출력됨](#ctrlc-입력-시-5u9-같은-문자가-출력됨)
- [Atuin 관련](#atuin-관련)
  - [atuin status가 404 오류 반환](#atuin-status가-404-오류-반환)
  - [Encryption key 불일치로 동기화 실패](#encryption-key-불일치로-동기화-실패)
  - [Atuin daemon 불안정 (deprecated)](#atuin-daemon-불안정-deprecated)
  - [CLI sync (v2)가 last_sync_time 파일 미업데이트](#cli-sync-v2가-last_sync_time-파일-미업데이트)
  - [네트워크 문제로 sync 실패](#네트워크-문제로-sync-실패)

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

### killall cfprefsd로 인한 스크롤 방향 롤백

**증상**: `darwin-rebuild switch` 후 스크롤 방향이 "자연스러운 스크롤"로 변경됨 (설정은 비활성화했는데)

**원인**: activation script에서 `killall cfprefsd` 실행 시 발생하는 타이밍 문제

```
1. killall cfprefsd 실행
   ↓
2. CFPreferences 데몬 종료 → 모든 사용자 설정 캐시 플러시
   ↓
3. 시스템이 자동으로 cfprefsd 재시작
   ↓
4. 재시작된 cfprefsd가 plist에서 설정 다시 로드
   ↓
5. nix-darwin의 새 설정과 기존 설정 간 타이밍 충돌
   ↓
6. 일부 설정(스크롤 방향)이 기본값으로 롤백
```

**해결**: `activateSettings -u` 실행 후 스크롤 방향을 명시적으로 재설정

```nix
# ❌ 문제가 되는 코드: activateSettings만 사용
system.activationScripts.postActivation.text = ''
  /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
'';

# ❌ 더 심각한 문제: killall cfprefsd 사용
system.activationScripts.postActivation.text = ''
  killall cfprefsd 2>/dev/null || true  # 모든 설정 캐시 플러시 → 다양한 설정 롤백
'';

# ✅ 권장: activateSettings 후 스크롤 방향 재설정
system.activationScripts.postActivation.text = ''
  # 키보드 단축키 등 설정 즉시 적용
  /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

  # activateSettings가 스크롤 방향을 롤백시키므로 명시적으로 재설정
  defaults write -g com.apple.swipescrolldirection -bool false
'';
```

**핵심**:
- `activateSettings -u`: 키보드 단축키 등 설정을 즉시 반영 (재시작/로그아웃 불필요)
- 단, 스크롤 방향을 롤백시키는 부작용이 있음
- 해결: `activateSettings` 직후 `defaults write`로 스크롤 방향 재설정
- `killall cfprefsd`는 **절대 사용 금지** (더 심각한 문제 유발)

**임시 복구** (이미 발생한 경우):

```bash
# 스크롤 방향 다시 적용 (자연스러운 스크롤 비활성화)
defaults write -g com.apple.swipescrolldirection -bool false
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
```

**영향받는 설정들**:

- 스크롤 방향 (`com.apple.swipescrolldirection`)
- 기타 NSGlobalDomain 설정들

> **참고**: `activateSettings -u`만으로 키보드 단축키 등 대부분의 설정이 즉시 반영됩니다. `cfprefsd` 재시작은 불필요합니다.

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

### hs CLI 명령어가 작동하지 않음 (IPC 오류)

**증상**: `hs -c 'hs.notify...'` 실행 시 오류 발생

```
error: can't access Hammerspoon message port Hammerspoon; is it running with the ipc module loaded?
```

**원인**: `init.lua`에 IPC 모듈이 로드되지 않음

**해결**: `init.lua` 상단에 IPC 모듈 로드 추가

```lua
-- init.lua 최상단에 추가
require("hs.ipc")
```

**추가 문제**: IPC 포트 불안정 (장시간 실행 후)

```
ipc port is no longer valid (early)
stack overflow
```

**해결**: Hammerspoon 재시작

```bash
pkill Hammerspoon && open -a Hammerspoon
# 또는
hsr  # alias 사용 (IPC가 작동할 때만)
```

**영향**: IPC 모듈이 없으면 `darwin-rebuild` 시 자동 리로드가 작동하지 않음

`modules/darwin/configuration.nix`의 activation script에서 `hs -c "hs.reload()"`를 실행하는데, IPC 모듈이 로드되지 않은 상태에서는 이 명령이 실패합니다 (`|| true`로 무시됨).

```nix
# darwin-rebuild 시 실행되는 activation script
/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -c "hs.reload()" 2>/dev/null || true
```

**결과**: IPC 모듈 추가 전에는 `nrs` 실행 후에도 Hammerspoon 설정이 자동 리로드되지 않아 수동 리로드가 필요했음. 오랫동안 원인을 모른 채 수동 리로드를 해왔는데, IPC 모듈 누락이 원인이었음.

---

### keyStrokes로 한글 경로 입력 시 깨짐

**증상**: 경로에 한글이 포함되면 `cd` 명령어가 제대로 입력되지 않음

**원인**: `hs.eventtap.keyStrokes`는 글자를 한 자씩 타이핑하므로, 입력 소스 상태에 영향받음

**해결**: 클립보드를 활용한 방식으로 변경

```lua
-- ❌ keyStrokes 방식 (한글 경로 문제)
hs.eventtap.keyStrokes('cd "' .. path .. '" && clear')

-- ✅ 클립보드 방식 (한글 경로 안전)
local prevClipboard = hs.pasteboard.getContents()
hs.pasteboard.setContents('cd "' .. path .. '" && clear')
hs.eventtap.keyStroke({"cmd"}, "v")
hs.eventtap.keyStroke({}, "return")
-- 클립보드 복원
hs.timer.doAfter(0.1, function()
    if prevClipboard then
        hs.pasteboard.setContents(prevClipboard)
    end
end)
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

---

## Claude Code 관련

### 플러그인 설치/삭제가 안 됨 (settings.json 읽기 전용)

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
$ touch ~/.claude/settings.json && echo "✅ 쓰기 가능"
✅ 쓰기 가능

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

> **참고**: Claude Code 설정에 대한 자세한 내용은 [FEATURES.md](FEATURES.md#claude-code-설정)를 참고하세요.

---

## Ghostty 관련

### 한글 입력소스에서 Ctrl/Opt 단축키가 동작하지 않음

**증상**: Claude Code 2.1.0+ 사용 시, 한글 입력소스에서 Ctrl+C, Ctrl+U, Opt+B 등의 단축키가 동작하지 않음. 영문 입력소스로 전환하면 정상 동작.

**원인**: Claude Code 2.1.0이 enhanced keyboard 모드(CSI u)를 적극 활용하면서 발생하는 문제입니다.

| 환경 | Ctrl 단축키 | Opt+B/F |
|------|------------|---------|
| Terminal.app | ✅ 입력소스 무관 | ❌ 한글일 때 문제 |
| Ghostty + Claude Code | ❌ 영문일 때만 | ❌ 영문일 때만 |

**왜 Ghostty keybind로 해결 안 되는가?**

```
[일반 CLI 앱] (cat, vim 등)
Ghostty keybind → legacy 시퀀스 전송 → 정상 동작 ✓

[Claude Code 2.1.0+]
Claude Code가 enhanced keyboard 모드 활성화 → Ghostty keybind 우회됨 ✗
```

`cat -v`에서는 한글 입력소스에서도 `^C`가 정상 출력되지만, Claude Code에서는 동작하지 않습니다.

**해결**: Hammerspoon에서 시스템 레벨로 처리

Hammerspoon이 키 입력을 **시스템 레벨**에서 가로채서 영어로 전환 후 키를 다시 전달합니다. Claude Code보다 먼저 처리되므로 확실히 동작합니다.

**설정 파일**: `modules/darwin/programs/hammerspoon/files/init.lua`

```lua
-- Ghostty 전용: Ctrl 키 조합
local ghosttyCtrlKeys = {'c', 'u', 'k', 'w', 'a', 'e', 'l', 'f'}

for _, key in ipairs(ghosttyCtrlKeys) do
    local bind
    bind = hs.hotkey.bind({'ctrl'}, key, function()
        if isGhostty() then
            convertToEngAndSendKey(bind, {'ctrl'}, key)
        else
            bind:disable()
            hs.eventtap.keyStroke({'ctrl'}, key)
            bind:enable()
        end
    end)
end

-- 모든 터미널: Opt 키 조합
local terminalOptKeys = {'b', 'f'}

for _, key in ipairs(terminalOptKeys) do
    local bind
    bind = hs.hotkey.bind({'alt'}, key, function()
        if isTerminalApp() then
            convertToEngAndSendKey(bind, {'alt'}, key)
        else
            bind:disable()
            hs.eventtap.keyStroke({'alt'}, key)
            bind:enable()
        end
    end)
end
```

**검증**:

```bash
# Hammerspoon 콘솔에서 확인
hs -c 'print(hs.application.frontmostApplication():bundleID())'
# 예상: com.mitchellh.ghostty

# Ghostty에서 한글 입력소스로 테스트
# 1. claude 실행
# 2. Ctrl+C → 정상 중단되어야 함
# 3. Ctrl+U → 줄 삭제되어야 함
# 4. Opt+B/F → 단어 이동되어야 함
```

**주의사항**:

| 항목 | 설명 |
|------|------|
| Ghostty 외 앱 | Ctrl 키는 원래 동작 유지 (VS Code에서 Ctrl+C는 복사) |
| 터미널 외 앱 | Opt 키는 원래 동작 유지 (브라우저에서 특수문자 입력) |
| 입력소스 전환 | 메뉴바 아이콘이 잠깐 깜빡일 수 있음 (기능 문제 없음) |

> **참고**: 터미널 단축키에 대한 자세한 내용은 [FEATURES.md](FEATURES.md#터미널-ctrlopt-단축키-한글-입력소스-문제-해결)를 참고하세요.

---

### Ctrl+C 입력 시 "5u9;" 같은 문자가 출력됨

**증상**: Ghostty 터미널에서 Ctrl+C를 누르면 프로세스가 중단되지 않고 `5u9;` 같은 문자가 출력됨. 간헐적으로 발생하며, 새 탭을 열거나 Ghostty를 재시작하면 정상으로 돌아옴.

**원인**: CSI u (Kitty Keyboard Protocol) 이스케이프 시퀀스가 해석되지 않고 raw 문자로 출력됨.

```
"5u9;" = ESC [ 99 ; 5 u 의 일부
         ↑    ↑    ↑
         |    |    └── Ctrl modifier 비트
         |    └── ASCII 'c' (99)
         └── CSI u 형식
```

**근본 원인**: Claude Code 등 일부 CLI 도구가 CSI u 모드를 활성화한 후 비활성화하지 않음. 터미널이 CSI u 모드에 "갇힌" 상태가 됨.

**해결**:

이 프로젝트에서는 **Hammerspoon**으로 해결합니다. 자세한 내용은 [한글 입력소스에서 Ctrl/Opt 단축키가 동작하지 않음](#한글-입력소스에서-ctrlopt-단축키가-동작하지-않음)을 참고하세요.

**임시 복구** (CSI u 모드에 갇힌 경우):

```bash
# reset-term alias 사용
reset-term

# 또는 직접 실행
printf "\033[?u\033[<u"

# 또는 새 탭 열기/Ghostty 재시작
```

> **참고**: 터미널 설정에 대한 자세한 내용은 [FEATURES.md](FEATURES.md#터미널-설정)를 참고하세요.

---

## Atuin 관련

### atuin status가 404 오류 반환

> **발생 시점**: 2026-01-13 / atuin 18.10.0, 18.11.0 모두 동일

**증상**: `atuin status` 명령 실행 시 404 오류 발생. `atuin sync`는 정상 작동.

```
Error: There was an error with the atuin sync service: Status 404.
If the problem persists, contact the host

Location:
    .../api_client.rs:186:9
```

**원인**: Atuin 클라우드 서버(`api.atuin.sh`)가 **Sync v1 API를 비활성화**했기 때문입니다.

소스 코드 분석 결과 (`crates/atuin-server/src/router.rs`):

```rust
// Sync v1 routes - can be disabled in favor of record-based sync
if settings.sync_v1_enabled {
    routes = routes
        .route("/sync/status", get(handlers::status::status))
        // ... 다른 v1 라우트들
}
```

`/sync/status` 엔드포인트는 `sync_v1_enabled = true`일 때만 활성화됩니다. Atuin 클라우드 서버에서 이 설정을 비활성화하면서 404가 반환됩니다.

**영향 범위**:

| 명령어 | 사용 API | 상태 |
|--------|----------|------|
| `atuin sync` | v2 (`/api/v0/*`) | ✅ 정상 |
| `atuin doctor` | 로컬 + 서버 | ✅ 정상 |
| `atuin status` | v1 (`/sync/status`) | ❌ 404 |

**해결**: 클라이언트에서 해결할 수 없음. Atuin 팀의 업데이트 필요.

**현재 상태**: `atuin status`는 정보 표시용이므로 **실제 동기화 기능에 영향 없음**. 무시해도 됩니다.

**동기화 상태 확인 방법**:

```bash
# atuin doctor 사용 (권장)
atuin doctor 2>&1 | grep -o '"last_sync": "[^"]*"'
# 예: "last_sync": "2026-01-13 8:12:42.22629 +00:00:00"

# watchdog 스크립트 수동 실행
awd
```

> **주의**: atuin CLI sync (v2)는 `last_sync_time` 파일을 업데이트하지 않는 버그가 있습니다. 현재 설정에서는 launchd의 `com.green.atuin-sync` 에이전트가 sync 성공 후 직접 파일을 업데이트합니다. 자세한 내용은 [CLI sync (v2)가 last_sync_time 파일 미업데이트](#cli-sync-v2가-last_sync_time-파일-미업데이트)를 참고하세요.

---

### Encryption key 불일치로 동기화 실패

**증상**: `atuin sync` 실행 시 key 불일치 오류 발생

```
Error: attempting to decrypt with incorrect key.
currently using k4.lid.XXX..., expecting k4.lid.YYY...
```

**원인**: 서버에 저장된 히스토리가 다른 encryption key로 암호화되어 있음. 주로 다음 상황에서 발생:

1. 새 계정 생성 시 새 key가 자동 생성됨
2. 다른 기기에서 다른 key를 사용 중
3. key 파일을 백업하지 않고 재설치

**해결**:

**방법 1: 기존 key 복원** (기존 히스토리 유지)
```bash
# 백업된 key가 있는 경우
cp ~/.local/share/atuin/key.backup ~/.local/share/atuin/key
atuin sync
```

**방법 2: 완전히 새로 시작** (히스토리 포기)
```bash
# 모든 atuin 데이터 삭제
rm -rf ~/.local/share/atuin

# 새 계정 등록
atuin register -u <username> -e <email>
```

**예방**: key 파일을 안전하게 백업하거나, nixos-config-secret으로 관리

```bash
# key 백업
cp ~/.local/share/atuin/key ~/.local/share/atuin/key.backup-$(date +%Y%m%d)
```

> **참고**: Atuin 모니터링 시스템에 대한 자세한 내용은 [FEATURES.md](FEATURES.md#atuin-모니터링-시스템)를 참고하세요. 구현 과정에서의 시행착오는 [TRIAL_AND_ERROR.md](TRIAL_AND_ERROR.md#2026-01-13-atuin-동기화-모니터링-시스템-구현-시행착오)를 참고하세요.

---

### Atuin daemon 불안정 (deprecated)

> **발생 시점**: 2026-01-14
> **해결**: daemon 비활성화, launchd로 대체

**증상**: daemon 프로세스가 불안정하게 동작. exit code 1로 반복 종료되거나, 실행 중이지만 sync를 수행하지 않음.

```bash
# launchd 상태 확인
launchctl print gui/$(id -u)/com.green.atuin-daemon
# 결과: runs = 218, last exit code = 1  ← 218번 재시작, 에러로 종료
```

**원인**: atuin daemon은 아직 experimental 기능으로, 다음과 같은 문제가 있음:

- 장시간 실행 시 좀비 상태로 전환
- 네트워크 연결 불안정 시 복구 실패
- 시스템 슬립/웨이크 후 복구 실패
- CLI sync (v2)와 달리 save_sync_time() 호출 로직이 있으나 실제로 동작하지 않는 경우 있음

**해결**: daemon 대신 launchd로 주기적 sync 실행

```nix
# modules/darwin/programs/atuin/default.nix
launchd.agents.atuin-sync = {
  enable = true;
  config = {
    Label = "com.green.atuin-sync";
    ProgramArguments = [
      "/bin/bash" "-c"
      "atuin sync && printf '%s' \"$(date -u +'%Y-%m-%dT%H:%M:%S.000000Z')\" > ~/.local/share/atuin/last_sync_time"
    ];
    RunAtLoad = true;
    StartInterval = 120;  # 2분마다
  };
};
```

**현재 상태**:

| 에이전트 | 상태 | 역할 |
| -------- | ---- | ---- |
| `com.green.atuin-daemon` | 삭제됨 | - |
| `com.green.atuin-sync` | 활성화 | 2분마다 sync |
| `com.green.atuin-watchdog` | 활성화 | 10분마다 상태 체크 |

---

### CLI sync (v2)가 last_sync_time 파일 미업데이트

> **발생 시점**: 2026-01-14
> **상태**: atuin 버그, 우회 적용

**증상**: `atuin sync` 명령이 성공해도 `~/.local/share/atuin/last_sync_time` 파일이 업데이트되지 않음.

```bash
$ cat ~/.local/share/atuin/last_sync_time
2026-01-13T12:57:07.715542Z  # 어제 시간

$ atuin sync
0/0 up/down to record store
Sync complete! 51888 items in history database, force: false

$ cat ~/.local/share/atuin/last_sync_time
2026-01-13T12:57:07.715542Z  # 여전히 어제 시간!
```

**원인**: atuin 소스코드 분석 결과, CLI sync (v2)에서 `save_sync_time()` 함수가 호출되지 않음.

```rust
// crates/atuin/src/command/client/sync.rs
// sync.records = true (v2) 경로에서 save_sync_time() 미호출
pub async fn run(...) -> Result<()> {
    if settings.sync.records {
        // v2 sync - save_sync_time() 없음!
        sync::sync(&settings, &db).await?;
    } else {
        // v1 sync - save_sync_time() 있음
        atuin_client::sync::sync(&settings, false, &db).await?;
    }
}
```

**해결**: launchd에서 sync 성공 후 직접 파일 업데이트

```bash
atuin sync && printf '%s' "$(date -u +'%Y-%m-%dT%H:%M:%S.000000Z')" > ~/.local/share/atuin/last_sync_time
```

**주의사항**:

- 줄바꿈 없이 작성해야 함 (`echo` 대신 `printf '%s'`)
- UTC 시간으로 작성해야 함 (`date -u`)
- 형식: `YYYY-MM-DDTHH:MM:SS.000000Z`

---

### 네트워크 문제로 sync 실패

> **발생 시점**: 2026-01-14

**증상**: 회사 네트워크 등에서 sync가 실패하지만 원인을 알 수 없음.

**원인**: 기존 watchdog이 에러를 무시(`2>/dev/null`)하고, 네트워크 상태를 확인하지 않았음.

**해결**: watchdog에 네트워크 확인 및 로깅 추가

```bash
# 네트워크 확인 (DNS + HTTPS)
host api.atuin.sh
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://api.atuin.sh

# 로그 확인
tail -f ~/.local/share/atuin/watchdog.log
```

**로그 파일**: `~/.local/share/atuin/watchdog.log`

```
[2026-01-14 11:29:51] [INFO] === Atuin Watchdog ===
[2026-01-14 11:29:51] [INFO] Host: work-MacBookPro
[2026-01-14 11:29:51] [INFO] Checking network to api.atuin.sh...
[2026-01-14 11:29:51] [ERROR] DNS resolution failed for api.atuin.sh
[2026-01-14 11:29:51] [ERROR] Network issue detected - skipping recovery
```

> **참고**: 자동 복구 기능에 대한 자세한 내용은 [FEATURES.md](FEATURES.md#atuin-모니터링-시스템)를 참고하세요.
