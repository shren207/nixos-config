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
  - [nrs 실행 시 빌드 없이 즉시 종료됨](#nrs-실행-시-빌드-없이-즉시-종료됨)
  - [darwin-rebuild 시 setupLaunchAgents에서 멈춤](#darwin-rebuild-시-setuplaunchagents에서-멈춤)
  - [darwin-rebuild 후 Hammerspoon HOME이 /var/root로 인식](#darwin-rebuild-후-hammerspoon-home이-varroot로-인식)
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
  - [PreToolUse 훅 JSON validation 에러](#pretooluse-훅-json-validation-에러)
- [Ghostty 관련](#ghostty-관련)
  - [한글 입력소스에서 Ctrl/Opt 단축키가 동작하지 않음](#한글-입력소스에서-ctrlopt-단축키가-동작하지-않음)
  - [Ctrl+C 입력 시 "5u9;" 같은 문자가 출력됨](#ctrlc-입력-시-5u9-같은-문자가-출력됨)
- [Zsh 관련](#zsh-관련)
  - [zsh-autosuggestion에서 한글/일본어 경로 레이아웃 깨짐](#zsh-autosuggestion에서-한글일본어-경로-레이아웃-깨짐)
- [Atuin 관련](#atuin-관련)
  - [atuin status가 404 오류 반환](#atuin-status가-404-오류-반환)
  - [Encryption key 불일치로 동기화 실패](#encryption-key-불일치로-동기화-실패)
  - [Atuin daemon 불안정 (deprecated)](#atuin-daemon-불안정-deprecated)
  - [CLI sync (v2)가 last_sync_time 파일 미업데이트](#cli-sync-v2가-last_sync_time-파일-미업데이트)
  - [네트워크 문제로 sync 실패](#네트워크-문제로-sync-실패)
- [NixOS 관련](#nixos-관련)
  - [nixos-install 시 GitHub flake 캐시 문제](#nixos-install-시-github-flake-캐시-문제)
  - [설치 환경에서 Private 저장소 접근 실패](#설치-환경에서-private-저장소-접근-실패)
  - [disko.nix와 hardware-configuration.nix fileSystems 충돌](#diskonix와-hardware-configurationnix-filesystems-충돌)
  - [SSH 키 등록 시 fingerprint 불일치 (O vs 0 오타)](#ssh-키-등록-시-fingerprint-불일치-o-vs-0-오타)
  - [git commit 시 Author identity unknown](#git-commit-시-author-identity-unknown)
  - [첫 로그인 시 zsh-newuser-install 화면](#첫-로그인-시-zsh-newuser-install-화면)
  - [Claude Code 설치 실패 (curl 미설치)](#claude-code-설치-실패-curl-미설치)
  - [동적 링크 바이너리 실행 불가 (nix-ld)](#동적-링크-바이너리-실행-불가-nix-ld)
  - [한글이 ■로 표시됨 (locale 미설정)](#한글이-로-표시됨-locale-미설정)
  - [Mac에서 MiniPC SSH 접속 실패 (Tailscale 만료)](#mac에서-minipc-ssh-접속-실패-tailscale-만료)
  - [sudo에서 SSH 키 인증 실패 (SSH_AUTH_SOCK)](#sudo에서-ssh-키-인증-실패-ssh_auth_sock)
  - [SSH에서 sudo 비밀번호 입력 불가](#ssh에서-sudo-비밀번호-입력-불가)
  - [Ghostty SSH 접속 시 unknown terminal type](#ghostty-ssh-접속-시-unknown-terminal-type)
  - [flake 시스템에서 /etc/nixos/configuration.nix 직접 수정 시 문제](#flake-시스템에서-etcnixosconfigurationnix-직접-수정-시-문제)
  - [nixos-rebuild 실패로 인한 시스템 부팅 불가](#nixos-rebuild-실패로-인한-시스템-부팅-불가)
  - [immich OOM으로 인한 시스템 불안정](#immich-oom으로-인한-시스템-불안정)
- [mise 관련](#mise-관련)
  - [SSH 비대화형 세션에서 pnpm not found](#ssh-비대화형-세션에서-pnpm-not-found)
  - [mise가 .nvmrc 파일을 자동 인식하지 않음](#mise가-nvmrc-파일을-자동-인식하지-않음)

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

### 재부팅 후 SSH 키가 ssh-agent에 로드되지 않음

> **발생 시점**: 2026-01-15
> **해결**: launchd agent + nrs.sh 자동 로드

**증상**: 재부팅 후 `nrs` 또는 `darwin-rebuild switch` 실행 시 private repo fetch 실패.

```
error: Failed to fetch git repository ssh://git@github.com/shren207/nixos-config-secret : git@github.com: Permission denied (publickey).
```

**원인**: macOS의 `ssh-agent`는 재부팅 시 SSH 키를 자동으로 로드하지 않습니다.

```bash
# 재부팅 후 확인
$ ssh-add -l
The agent has no identities.  # ← 키가 없음!

# 일반 ssh 명령은 작동 (macOS Keychain 직접 참조)
$ ssh -T git@github.com
Hi shren207! You've successfully authenticated...
```

nix-daemon은 별도 프로세스로 실행되어 Keychain에 직접 접근하지 못하고, `ssh-agent`만 사용합니다.

**해결**: 두 가지 방법으로 자동화

1. **launchd agent** (`com.green.ssh-add-keys`): 로그인 시 자동으로 `ssh-add` 실행
2. **nrs.sh**: darwin-rebuild 전에 키 로드 여부 확인

**설정 파일**: `modules/darwin/programs/ssh/default.nix`

```nix
# launchd agent - 로그인 시 SSH 키 자동 로드
launchd.agents.ssh-add-keys = {
  enable = true;
  config = {
    Label = "com.green.ssh-add-keys";
    ProgramArguments = [ "${sshAddScript}" ];
    RunAtLoad = true;
    EnvironmentVariables = { HOME = homeDir; };
  };
};
```

**확인 방법**:

```bash
# SSH agent에 키 로드 확인
ssh-add -l

# launchd agent 상태 확인
launchctl list | grep ssh-add

# 로그 확인
cat ~/Library/Logs/ssh-add-keys.log
```

**왜 이전에는 문제가 없었나?**

이 문제는 2026-01-15에 처음 발견되었지만, `nixos-config-secret` (private repo)은 2025-12-21 initial commit부터 사용 중이었습니다. 이전에 문제가 없었던 이유로 추정되는 시나리오:

| 가능성 | 설명 |
|--------|------|
| 캐시된 버전 사용 | `flake.lock`에 저장된 버전으로 빌드, fresh fetch 불필요 |
| 이미 키가 로드된 상태 | 다른 SSH 작업(git push 등) 후 nrs 실행 |
| 첫 재부팅 직후 테스트 | 이번이 처음으로 "재부팅 → 즉시 nrs" 시나리오 |
| `--offline` 주로 사용 | fetch 없이 로컬 캐시만 사용 |

macOS의 `AddKeysToAgent yes` 설정은 SSH를 **처음 사용할 때** 키를 agent에 로드합니다. 이전에는 nrs 전에 우연히 SSH를 사용하는 작업을 했을 가능성이 높습니다:

```
이전: 재부팅 → (git fetch 등) → SSH 키 자동 로드 → nrs 실행 ✅
이번: 재부팅 → 바로 nrs 실행 → SSH 키 없음 ❌
```

**결론**: 원인 진단은 정확하며, 문제는 "우연히 회피"되었을 가능성이 높습니다. 현재 해결책(launchd agent + nrs.sh)은 이러한 우연에 의존하지 않고 명시적으로 키 로드를 보장합니다.

> **참고**: SSH 설정에 대한 자세한 내용은 [FEATURES.md](FEATURES.md#ssh-키-자동-로드)를 참고하세요.

---

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

### nrs 실행 시 빌드 없이 즉시 종료됨

> **발생 시점**: 2026-01-15

**증상**: `nrs` 명령 실행 시 SSH 키 로딩과 launchd 에이전트 정리 메시지만 출력되고, `darwin-rebuild`가 실행되지 않고 즉시 종료됨.

```
❯ nrs

🔑 Loading SSH key...
Identity added: /Users/glen/.ssh/id_ed25519 (greenhead-home-mac-2025-10)
🧹 Cleaning up launchd agents...

❯   ← 빌드 없이 즉시 프롬프트 복귀
```

**원인**: `set -e`와 bash 산술 연산 `(( ))` 조합의 함정.

```bash
set -euo pipefail  # -e: 명령이 실패하면 즉시 종료

local cleaned=0
# ...
((cleaned++))  # ❌ cleaned=0일 때 exit code 1 반환 → 스크립트 종료
```

bash에서 `((expression))`의 exit code는 표현식의 **평가 결과**에 따라 결정됩니다:

| 표현식 | 평가 결과 | Exit code |
|--------|----------|-----------|
| `((0))` | false | 1 |
| `((1))` | true | 0 |
| `((var++))` (var=0) | 0 (증가 전 값) | 1 |
| `((++var))` (var=0) | 1 (증가 후 값) | 0 |

`((var++))`는 **후위 증가**로, 증가 전 값(0)을 반환합니다. `set -e` 환경에서 exit code 1은 스크립트를 즉시 종료시킵니다.

**진단 방법**:

```bash
# 디버그 모드로 실행하여 어디서 멈추는지 확인
bash -x ~/IdeaProjects/nixos-config/scripts/nrs.sh

# 출력 예시 (문제 발생 시):
# + ((cleaned++))
# ← 여기서 스크립트 종료
```

**해결**: 전위 증가 `((++var))` 사용

```bash
# ❌ 문제: 후위 증가 (증가 전 값 반환)
((cleaned++))   # cleaned=0일 때 exit code 1

# ✅ 해결: 전위 증가 (증가 후 값 반환)
((++cleaned))   # cleaned=0일 때 exit code 0
```

**대안적 해결책들**:

| 방법 | 예시 | 설명 |
|------|------|------|
| 전위 증가 | `((++var))` | 증가 후 값 반환 (권장) |
| 명령 대체 | `var=$((var + 1))` | exit code 문제 없음 |
| `\|\| true` | `((var++)) \|\| true` | 실패 무시 |

**예방**:

1. 스크립트에 주석 추가:
   ```bash
   # 주의: ((++var)) 사용 필수. ((var++))는 var=0일 때 exit code 1 반환 → set -e로 스크립트 종료됨
   ```

2. ShellCheck 사용 (정적 분석 도구, `home.nix`에 기본 설치됨):
   ```bash
   # 단일 스크립트 검사
   shellcheck scripts/nrs.sh

   # 프로젝트 내 모든 쉘 스크립트 검사
   shellcheck scripts/*.sh
   ```

   **ShellCheck 한계**: `((var++))` + `set -e` 문제는 shellcheck가 **감지하지 못합니다**. 이처럼 미묘한 edge case는 shellcheck로 잡을 수 없으므로, 주석과 문서화가 여전히 중요합니다.

   ```bash
   # shellcheck가 감지하는 것들
   - SC2086: 따옴표 없는 변수 (word splitting 위험)
   - SC2164: cd 실패 시 처리 없음
   - SC2034: 사용되지 않는 변수

   # shellcheck가 감지하지 못하는 것들
   - ((var++))의 set -e 문제 (이 문서에서 다룬 버그)
   - 논리적 오류, 비즈니스 로직 버그
   ```

**추가 함정 - Nix store 심볼릭 링크**:

`nrs`가 alias로 정의된 경우, 소스 파일과 실제 실행 파일이 다를 수 있습니다.

```bash
# alias 확인
type nrs
# nrs is an alias for ~/.local/bin/nrs.sh

# 심볼릭 링크 확인
ls -la ~/.local/bin/nrs.sh
# -> /nix/store/xxx-home-manager-files/.local/bin/nrs.sh (이전 빌드 버전)
```

소스 파일(`~/IdeaProjects/nixos-config/scripts/nrs.sh`)을 수정해도, `darwin-rebuild`를 실행하기 전까지는 실제 실행 파일(Nix store)에 반영되지 않습니다.

**해결**: 수정된 소스 스크립트를 직접 실행

```bash
# alias 대신 소스 파일 직접 실행
bash ~/IdeaProjects/nixos-config/scripts/nrs.sh

# 빌드 완료 후에는 alias 정상 사용 가능
nrs
```

---

### launchd 에이전트 상태 확인

```bash
# 등록된 에이전트 확인
launchctl list | grep com.green

# 로그 확인
cat ~/Library/Logs/folder-actions/*.log
```

### darwin-rebuild 시 setupLaunchAgents에서 멈춤

> **발생 시점**: 2026-01-14

**증상**: `sudo darwin-rebuild switch --flake .` 실행 시 `Activating setupLaunchAgents` 단계에서 무한 대기.

```
Activating setCursorAsDefaultEditor
Setting Cursor as default editor for code files...
Cursor default settings applied successfully.
Activating setupLaunchAgents
← 여기서 멈춤
```

**원인**: Home Manager의 `setupLaunchAgents`가 launchd 에이전트를 reload할 때 발생하는 문제입니다.

| 원인 | 설명 |
|------|------|
| **launchd 상태 충돌** | 이전 darwin-rebuild가 중단(Ctrl+C)된 후 에이전트가 불완전한 상태로 남음 |
| **sudo GUI 도메인 접근** | sudo로 실행 시 UID가 0이 되어 `gui/501` 도메인 접근에 문제 발생 |
| **타이밍 문제** | `launchctl bootout` 후 내부 상태 정리가 완료되기 전에 재시도 |

**Home Manager의 setupLaunchAgents 동작**:

```bash
# 각 에이전트에 대해 순차 실행
/bin/launchctl bootout "gui/$UID/$agentName"  # 에이전트 중지
sleep 1                                        # 1초 대기
/bin/launchctl bootstrap "gui/$UID" "$dstPath" # 에이전트 시작
```

**해결**:

```bash
# 1. 멈춘 darwin-rebuild를 Ctrl+C로 중단

# 2. 에이전트 수동 정리 (sudo 없이 실행!)
launchctl bootout gui/$(id -u)/com.green.atuin-watchdog 2>/dev/null
launchctl bootout gui/$(id -u)/com.green.folder-action.compress-rar 2>/dev/null
launchctl bootout gui/$(id -u)/com.green.folder-action.compress-video 2>/dev/null
launchctl bootout gui/$(id -u)/com.green.folder-action.convert-video-to-gif 2>/dev/null
launchctl bootout gui/$(id -u)/com.green.folder-action.rename-asset 2>/dev/null

# 3. plist 파일 삭제
rm -f ~/Library/LaunchAgents/com.green.*.plist

# 4. 2-3초 대기 후 재시도
sleep 3
sudo darwin-rebuild switch --flake ~/IdeaProjects/nixos-config
```

**예방**: `nrs` alias 사용 시 자동으로 에이전트를 정리합니다. 자세한 내용은 [FEATURES.md](FEATURES.md#darwin-rebuild-alias)를 참고하세요.

---

### darwin-rebuild 후 Hammerspoon HOME이 /var/root로 인식

> **발생 시점**: 2026-01-14

**증상**: darwin-rebuild 완료 후 Atuin menubar가 "오류 발생" 상태 표시. Hammerspoon이 watchdog 스크립트 실행 실패.

```lua
-- Hammerspoon 콘솔에서 확인
hs -c 'return hs.execute(os.getenv("HOME") .. "/.local/bin/atuin-watchdog.sh --status 2>&1")'
-- 결과: sh: /var/root/.local/bin/atuin-watchdog.sh: Permission denied
```

**원인**: `sudo darwin-rebuild` 실행 중 Hammerspoon이 IPC를 통해 reload되면 환경변수가 오염됩니다.

```
sudo darwin-rebuild switch
   ↓
activation script에서 hs -c "hs.reload()" 실행
   ↓
Hammerspoon이 sudo 환경에서 reload됨
   ↓
os.getenv("HOME") = "/var/root" (root의 HOME)
   ↓
watchdog 스크립트 경로가 /var/root/.local/bin/...로 잘못 해석됨
```

**해결**: Hammerspoon 완전 재시작

```bash
# 방법 1: 메뉴바에서 Quit 후 재실행
# Hammerspoon 아이콘 → Quit Hammerspoon → Spotlight에서 다시 실행

# 방법 2: 터미널에서
killall Hammerspoon && open -a Hammerspoon
```

**예방**: `nrs` alias 사용 시 darwin-rebuild 완료 후 자동으로 Hammerspoon을 재시작합니다.

```bash
# scripts/nrs.sh (일부)
restart_hammerspoon() {
    if pgrep -x "Hammerspoon" > /dev/null; then
        killall Hammerspoon 2>/dev/null || true
        sleep 1
    fi
    open -a Hammerspoon
}
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

### PreToolUse 훅 JSON validation 에러

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
| 체인 명령어 | 첫 번째만 nix 환경 | 전체가 nix 환경 ✅ |
| 특수문자 | 이스케이프 필요 | 안전하게 처리 ✅ |
| JSON 출력 | 멀티라인 가능성 | 항상 단일 라인 ✅ |
| 복잡성 | 분기 로직 필요 | 단순함 ✅ |

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

> **참고**: PreToolUse 훅 기능에 대한 자세한 내용은 [FEATURES.md](FEATURES.md#pretooluse-훅-nix-develop-환경)를 참고하세요.

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

## Zsh 관련

### zsh-autosuggestion에서 한글/일본어 경로 레이아웃 깨짐

> **발생 시점**: 2026-01-17
> **상태**: 부분 해결 (문자 표시는 정상, 커서 위치는 일부 문제)

**증상**: `cd` 입력 시 한글/일본어가 포함된 경로가 zsh-autosuggestion으로 제안되면 터미널 레이아웃이 깨짐.

```
# 정상 동작 (영어 경로)
~ > cd Documents/projects/  # autosuggestion 정상

# 문제 발생 (한글/일본어 경로)
~ > cd Documents/プロジェクト/한글폴더/  # 레이아웃 깨짐
# 다음과 같이 표시됨:
# cd Documents/プロシ<3099>ェクト/한글폴더/  # <3099> 문자 노출, 커서 위치 틀어짐
```

**원인**: macOS 파일 시스템(APFS/HFS+)의 NFD(분해형) 유니코드 정규화.

| 정규화 | 예시 | 바이트 |
| ------ | ---- | ------ |
| NFC (조합형) | `동` | `EB 8F 99` (3바이트) |
| NFD (분해형) | `ᄃ` + `ᅩ` + `ᆼ` | `E1 84 83 E1 85 A9 E1 86 BC` (9바이트) |

macOS는 파일명을 NFD로 저장하므로:
- 한글: `동` → `ᄃ` + `ᅩ` + `ᆼ` (초성+중성+종성 분리)
- 일본어: `ダ` → `タ` + U+3099 (기본자+탁점 분리)

zsh-autosuggestion이 결합 문자(combining character)의 너비를 잘못 계산하여 커서 위치가 틀어짐.

**진단 방법**:

```bash
# 1. 파일명 인코딩 확인
ls Documents/プロジェクト | xxd | head -10
# NFD면 한글이 초성/중성/종성 바이트로 분리됨

# 2. grep으로 NFC/NFD 차이 확인
ls Documents | grep 한글  # NFC "한글"로 검색
# NFD로 저장된 경우 매칭 안 됨!
```

**해결 방법**:

**1. `setopt COMBINING_CHARS` 추가 (핵심)**

zsh 4.3.9부터 도입된 내장 옵션으로, 결합 문자를 기본 문자와 같은 화면 영역에 표시.

```nix
# modules/shared/programs/shell/default.nix
programs.zsh = {
  initContent = lib.mkMerge [
    (lib.mkBefore ''
      # macOS NFD 유니코드 결합 문자 처리 (한글 자모 분리, 일본어 dakuten 등)
      setopt COMBINING_CHARS

      # ... 나머지 설정
    '')
  ];
};
```

**2. autosuggestion 설정 조정 (보조)**

```nix
programs.zsh = {
  autosuggestion = {
    enable = true;
    highlight = "fg=#808080";
    strategy = [ "history" ];  # completion 제외로 cursor 버그 완화
  };
};
```

> **주의**: `strategy = [ "history" ]`는 Tab completion 기반 제안을 비활성화함 (한 번도 실행 안 한 명령어는 제안 안 됨).

**적용 후 확인**:

```bash
# setopt 적용 확인
setopt | grep -i combining  # 출력: combiningchars

# 문자 표시 테스트
echo "テスト 한글"  # 정상 출력되는지 확인
```

**결과**:

| 항목 | 적용 전 | 적용 후 |
| ---- | ------- | ------- |
| 문자 표시 | `タ<3099>` | `ダ` (정상) |
| 커서 위치 | 틀어짐 | 일부 개선 (완전하지 않음) |

**알려진 제한사항**:

- 커서 위치 계산은 zsh-autosuggestions 플러그인 자체 로직의 한계로 완전히 해결되지 않음
- 문제가 심할 경우 `ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=50`으로 긴 경로 제안 제한 검토
- Atuin TUI에서 NFD 한글이 초성만 표시되는 문제는 Ratatui 라이브러리 버그 (업스트림 패치 대기)

**참고 자료**:

- [zsh FAQ - COMBINING_CHARS](https://zsh.sourceforge.io/FAQ/zshfaq05.html)
- [Home Manager - zsh.autosuggestion 옵션](https://mynixos.com/home-manager/options/programs.zsh.autosuggestion)
- [Oh My Zsh - macOS NFD issue #12380](https://github.com/ohmyzsh/ohmyzsh/issues/12380)
- [Ratatui - Korean rendering #1396](https://github.com/ratatui/ratatui/issues/1396)

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

---

### Fuzzy search로 의도치 않은 검색 결과

> **발생 시점**: 2026-01-18 / atuin 18.11.0
> **해결**: `search_mode = "fulltext"` 설정

**증상**: `atuin search "media"` 실행 시 `media`라는 문자열이 온전히 포함되지 않은 결과도 표시됨.

```bash
$ atuin search "media"
2025-09-12 10:47:41     rm -rf ~/Library/Developer/Xcode/DerivedData/   # media가 없는데?
2025-12-21 17:29:38     sudo nix run ... nix-darwin -- switch --flake . # 이것도?
```

**원인**: Atuin의 기본 `search_mode`가 `fuzzy`이기 때문입니다. Fuzzy 검색은 입력한 글자(`m`, `e`, `d`, `i`, `a`)가 **순서대로 흩어져 있기만 하면** 매칭됩니다.

예: `rm -rf ~/Library/Developer/Xcode/DerivedData/`
- **m**: r**m**
- **e**: D**e**veloper
- **d**: **D**erived**D**ata
- **i**: L**i**brary
- **a**: Dat**a**

**해결**: `search_mode`를 `fulltext`로 변경

```nix
# modules/shared/programs/shell/default.nix
programs.atuin.settings = {
  # ... 기존 설정 ...
  search_mode = "fulltext";
};
```

**왜 `fulltext`인가?**

| 모드 | 특징 | 한계 |
|------|------|------|
| `fuzzy` (기본값) | 글자가 순서대로 흩어져 있으면 매칭 | 의도치 않은 결과 다수 포함 |
| `prefix` | 검색어로 **시작**하는 명령어만 검색 | `sudo media...` 검색 불가 |
| `fulltext` | 검색어가 **정확히 포함**된 명령어만 검색 | 가장 균형 잡힌 선택 |

**TUI에서 모드 변경**: `Ctrl+r` 누르면 모드 순환 (Fuzzy → Prefix → Fulltext → Skim)

---

## NixOS 관련

### nixos-install 시 GitHub flake 캐시 문제

> **발생 시점**: 2026-01-17 (MiniPC NixOS 설치)

**증상**: `flake.nix`를 수정하고 GitHub에 push한 후 `nixos-install --flake github:user/repo#host`를 실행해도 이전 버전이 사용됨.

```bash
$ nixos-install --flake github:shren207/nixos-config#greenhead-minipc
# 에러: 방금 수정한 내용이 반영되지 않음
```

**원인**: GitHub의 flake 참조는 캐싱됩니다. `--refresh` 옵션이 `nixos-install`에는 없습니다.

**해결**: 로컬에 clone해서 설치

```bash
# GitHub URL 대신 로컬 clone 사용
git clone https://github.com/user/nixos-config.git /tmp/nixos-config
nixos-install --flake /tmp/nixos-config#hostname
```

**왜 발생하는가?**

| 방식 | 캐싱 | 해결책 |
|------|------|--------|
| `github:user/repo` | GitHub API 캐시 | 로컬 clone 사용 |
| `/tmp/nixos-config` | 없음 (로컬) | 최신 상태 보장 |

> **참고**: `nix build`나 `nix develop`에서는 `--refresh` 옵션으로 캐시를 무시할 수 있지만, `nixos-install`은 이 옵션을 지원하지 않습니다.

---

### 설치 환경에서 Private 저장소 접근 실패

> **발생 시점**: 2026-01-17 (MiniPC NixOS 설치)

**증상**: `nixos-install` 실행 시 private 저장소 fetch 실패.

```
error: Failed to fetch git repository ssh://git@github.com/user/private-repo
git@github.com: Permission denied (publickey).
fatal: Could not read from remote repository.
```

**원인**: NixOS 설치 환경(live USB)에는 SSH 키가 없어서 private 저장소에 접근할 수 없습니다.

**해결**: 설치 시에는 private 저장소 의존성을 임시로 제거

**1. flake.nix에서 private input 주석 처리**

```nix
# 변경 전
private-repo = {
  url = "git+ssh://git@github.com/user/private-repo";
};

# 변경 후 (설치용)
# private-repo = {
#   url = "git+ssh://git@github.com/user/private-repo";
# };
```

**2. home.nix에서 해당 import 주석 처리**

```nix
imports = [
  # inputs.private-repo.homeManagerModules.default  # 설치 후 활성화
];
```

**3. 설치 완료 후 SSH 키 설정하고 다시 활성화**

```bash
# MiniPC에서 SSH 키 생성
ssh-keygen -t ed25519 -C "user@minipc"
cat ~/.ssh/id_ed25519.pub
# → GitHub에 등록

# 주석 해제 후 rebuild
sudo nixos-rebuild switch --flake .#hostname
```

**예방**: 설치 환경에서도 접근 가능한 public 저장소와 private 저장소를 분리하여 관리합니다.

---

### disko.nix와 hardware-configuration.nix fileSystems 충돌

> **발생 시점**: 2026-01-17 (MiniPC NixOS 설치)

**증상**: `nixos-rebuild switch` 실행 시 fileSystems 충돌 에러.

```
error: The option `fileSystems."/".device` has conflicting definition values:
- In `module.nix': "/dev/disk/by-partlabel/disk-nvme-root"
- In `hardware-configuration.nix': "/dev/disk/by-uuid/xxx"
```

**원인**: disko.nix가 파티션과 마운트를 관리하는데, `nixos-generate-config`로 생성된 hardware-configuration.nix에도 동일한 fileSystems 정의가 있어서 충돌.

**해결**: hardware-configuration.nix에서 disko가 관리하는 항목 제거

```nix
# 변경 전 (hardware-configuration.nix)
fileSystems."/" = { device = "/dev/disk/by-uuid/xxx"; fsType = "ext4"; };
fileSystems."/boot" = { device = "/dev/disk/by-uuid/yyy"; fsType = "vfat"; };
swapDevices = [ { device = "/dev/disk/by-uuid/zzz"; } ];
fileSystems."/mnt/data" = { device = "/dev/disk/by-uuid/aaa"; fsType = "ext4"; };  # HDD

# 변경 후
# fileSystems."/" and "/boot" are managed by disko.nix
# swapDevices are managed by disko.nix

# HDD mount (disko가 관리하지 않는 것만 유지)
fileSystems."/mnt/data" = { device = "/dev/disk/by-uuid/aaa"; fsType = "ext4"; };
```

**핵심 원칙**:

| 항목 | 관리 주체 | hardware-configuration.nix |
|------|-----------|---------------------------|
| `/` (root) | disko.nix | 제거 |
| `/boot` (ESP) | disko.nix | 제거 |
| swap | disko.nix | 제거 |
| `/mnt/data` (추가 디스크) | hardware-configuration.nix | 유지 |

---

### SSH 키 등록 시 fingerprint 불일치 (O vs 0 오타)

> **발생 시점**: 2026-01-17 (MiniPC NixOS 설치)

**증상**: SSH 키를 GitHub에 등록했는데 `Permission denied (publickey)` 에러.

```bash
$ ssh -T git@github.com
git@github.com: Permission denied (publickey).
```

**원인**: SSH 공개키를 수동으로 복사할 때 `O`(대문자 O)와 `0`(숫자 0)을 혼동.

```
# MiniPC의 실제 키
ssh-ed25519 AAAAC3Nza...I806sMRc...  # "I806" (숫자 0)

# GitHub에 잘못 등록된 키
ssh-ed25519 AAAAC3Nza...I8O6sMRc...  # "I8O6" (대문자 O)
```

**진단**: fingerprint 비교

```bash
# 로컬 키의 fingerprint
$ ssh-keygen -lf ~/.ssh/id_ed25519.pub
SHA256:rQkj8SQoIe7nFdTrnGfK1+poZquyienxBL6FF5/Ut1k

# GitHub에 등록된 키의 fingerprint (GitHub 설정 페이지에서 확인)
SHA256:aUP+sMvwSClsQoLxP7P30vxpQi7Xe/GGjeB0L0PF/Zc  # 다름!
```

**해결**:

1. GitHub에서 잘못된 키 삭제
2. 터미널에서 `cat ~/.ssh/id_ed25519.pub` 출력
3. **전체를 정확히 복사**하여 GitHub에 재등록

**예방**:

- 터미널 폰트가 `O`와 `0`을 명확히 구분하는지 확인
- 가능하면 `ssh-copy-id`나 클립보드 복사 사용
- 등록 후 `ssh -T git@github.com`으로 즉시 테스트

---

### git commit 시 Author identity unknown

> **발생 시점**: 2026-01-17 (MiniPC NixOS 설치)

**증상**: git commit 실행 시 author 정보 없음 에러.

```
$ git commit -m "message"
Author identity unknown

*** Please tell me who you are.

Run
  git config --global user.email "you@example.com"
  git config --global user.name "Your Name"
```

**원인**: 새로 설치된 NixOS 환경에서 git user 설정이 없음. Home Manager의 git 모듈이 아직 적용되지 않은 상태.

**해결**: 수동으로 git config 설정

```bash
git config --global user.email "your-email@example.com"
git config --global user.name "your-username"
```

**참고**: Home Manager의 `programs.git` 설정이 적용되면 이 설정은 자동으로 관리됩니다. 하지만 첫 rebuild 전에 commit이 필요한 경우 수동 설정이 필요합니다.

---

### 첫 로그인 시 zsh-newuser-install 화면

> **발생 시점**: 2026-01-17 (MiniPC NixOS 설치)

**증상**: 새 사용자로 처음 로그인할 때 zsh 설정 마법사가 나타남.

```
This is the Z Shell configuration function for new users,
zsh-newuser-install.
You are seeing this message because you have no zsh startup files
(the files .zshenv, .zprofile, .zshrc, .zlogin in the directory
~). This function can help you with a few settings that should
make your use of the shell easier.

You can:
(q) Quit and do nothing.
(0) Exit, creating the file ~/.zshrc containing just a comment.
(1) Continue to the main menu.
```

**원인**: Home Manager가 아직 적용되지 않아서 `.zshrc` 파일이 없음.

**해결**: `0` 입력 (빈 .zshrc 생성)

```
---- Type one of the keys in parentheses ---- 0
```

**왜 0을 선택하는가?**

| 선택 | 결과 | 권장 |
|------|------|------|
| `q` | 다음 로그인에도 다시 나타남 | ✗ |
| `0` | 빈 `.zshrc` 생성 → 다시 안 나타남 | ✓ |
| `1` | 수동 설정 → Home Manager와 충돌 가능 | ✗ |

Home Manager가 나중에 `.zshrc`를 관리하므로, 지금은 빈 파일로 넘어가면 됩니다.

---

### Claude Code 설치 실패 (curl 미설치)

> **발생 시점**: 2026-01-17 (MiniPC NixOS 설치)

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

---

### 동적 링크 바이너리 실행 불가 (nix-ld)

> **발생 시점**: 2026-01-17 (MiniPC NixOS 설치)

**증상**: Claude Code 설치 스크립트 실행 후 바이너리 실행 실패.

```
Setting up Claude Code...
Could not start dynamically linked executable: /home/user/.claude/downloads/claude-x.x.x-linux-x64
NixOS cannot run dynamically linked executables intended for generic linux environments out of the box.
For more information, see: https://nix.dev/permalink/stub-ld
```

**원인**: NixOS는 FHS(Filesystem Hierarchy Standard)를 따르지 않아서 일반 Linux 바이너리를 직접 실행할 수 없습니다.

| 일반 Linux | NixOS |
|------------|-------|
| `/lib64/ld-linux-x86-64.so.2` | 존재하지 않음 |
| 동적 링크 바이너리 실행 가능 | 실행 불가 |

**해결**: `programs.nix-ld` 활성화

```nix
# modules/nixos/configuration.nix
programs.nix-ld.enable = true;
```

**nix-ld란?**

- 동적 링크된 바이너리를 NixOS에서 실행할 수 있게 해주는 호환성 레이어
- `/lib64/ld-linux-x86-64.so.2`를 시뮬레이션
- Claude Code, VS Code Server 등 외부 바이너리에 필요

**적용 후**:

```bash
$ sudo nixos-rebuild switch --flake .#hostname

# Claude Code 재설치
$ curl -fsSL https://claude.ai/install.sh | bash
✓ Claude Code successfully installed!
```

---

### 한글이 ■로 표시됨 (locale 미설정)

> **발생 시점**: 2026-01-17 (MiniPC NixOS 설치)

**증상**: NixOS 설치 직후 터미널에서 한글이 ■(검은 사각형)으로 표시됨.

```
[sudo] greenhead ■ ■ :
■ ■ ■ ■ ■ ■ ■ ■ .
```

**원인**:

1. 콘솔 폰트가 한글을 지원하지 않음
2. locale이 아직 완전히 적용되지 않음

**해결**: 이것은 **TTY 콘솔의 정상적인 제한사항**입니다.

- TTY(가상 콘솔)는 유니코드 글꼴 지원이 제한적
- SSH로 접속하거나 GUI 터미널을 사용하면 정상 표시됨

**확인**:

```bash
# locale 설정 확인
$ locale
LANG=ko_KR.UTF-8
LC_TIME=ko_KR.UTF-8

# SSH로 접속하면 정상
$ ssh user@minipc
# 한글 정상 표시됨
```

**참고**: NixOS configuration에서 locale이 올바르게 설정되어 있다면 문제없습니다.

```nix
# modules/nixos/configuration.nix
i18n.defaultLocale = "ko_KR.UTF-8";
```

---

### Mac에서 MiniPC SSH 접속 실패 (Tailscale 만료)

> **발생 시점**: 2026-01-17 (MiniPC NixOS 설치)

**증상**: Mac에서 MiniPC로 SSH 접속 시 타임아웃.

```bash
$ ssh greenhead@100.79.80.95
ssh: connect to host 100.79.80.95 port 22: Operation timed out
```

**원인**: Mac의 Tailscale 세션이 만료됨.

Tailscale 관리 콘솔에서 확인:
```
macbookpro    100.126.197.36    Expired Sep 18, 2025
greenhead-minipc    100.79.80.95    Connected
```

**해결**: Mac에서 Tailscale 재인증

```bash
# macOS GUI
# 메뉴바 Tailscale 아이콘 → Log in

# 또는 CLI (설치된 경우)
$ tailscale up
```

**확인**:

```bash
$ tailscale status
100.65.50.98  greenhead-macbookpro  user@  macOS  -
100.79.80.95  greenhead-minipc      user@  linux  active; direct ...

# SSH 재시도
$ ssh greenhead@100.79.80.95
greenhead@greenhead-minipc:~$  # 성공!
```

**예방**: Tailscale 키 만료 전에 갱신하거나, 자동 갱신 설정 확인.

---

### sudo에서 SSH 키 인증 실패 (SSH_AUTH_SOCK)

> **발생 시점**: 2026-01-18 (MiniPC NixOS 설정)

**증상**: SSH 키가 ssh-agent에 로드되어 있고 `ssh -T git@github.com`은 성공하지만, `sudo nixos-rebuild`에서 private 저장소 접근 실패.

```bash
$ ssh -T git@github.com
Hi shren207! You've successfully authenticated...

$ sudo nixos-rebuild switch --flake .#greenhead-minipc
error: Failed to fetch git repository ssh://git@github.com/user/private-repo
git@github.com: Permission denied (publickey).
```

**원인**: `sudo`는 root 사용자로 명령을 실행하므로, 현재 사용자의 `SSH_AUTH_SOCK` 환경변수를 상속받지 않습니다.

```
일반 사용자 → ssh-agent (SSH_AUTH_SOCK 설정됨)
     ↓
   sudo → root 사용자 (SSH_AUTH_SOCK 없음) → SSH 키 접근 불가
```

**해결**: `SSH_AUTH_SOCK` 환경변수를 sudo에 전달

```bash
sudo SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild switch --flake .#greenhead-minipc
```

**대안**: sudoers에서 환경변수 유지 설정 (NixOS)

```nix
# configuration.nix
security.sudo.extraConfig = ''
  Defaults env_keep += "SSH_AUTH_SOCK"
'';
```

**참고**: 이 문제는 private 저장소를 flake input으로 사용할 때만 발생합니다. public 저장소만 사용하면 SSH 인증이 필요 없습니다.

---

### SSH에서 sudo 비밀번호 입력 불가

> **발생 시점**: 2026-01-18 (MiniPC NixOS 설정)

**증상**: Mac에서 SSH로 MiniPC에 접속 후 sudo 명령 실행 시 비밀번호 입력 불가.

```bash
$ ssh minipc "sudo nixos-rebuild switch --flake .#greenhead-minipc"
sudo: a terminal is required to read the password; either use ssh's -t option or configure an askpass helper
```

**원인**: 비인터랙티브 SSH 세션에서는 sudo가 비밀번호를 입력받을 TTY가 없습니다.

**해결**: NixOS에서 wheel 그룹에 NOPASSWD 설정

```nix
# modules/nixos/configuration.nix
security.sudo.wheelNeedsPassword = false;
```

**보안 고려사항**:

| 우려 | 실제 상황 |
|------|-----------|
| 설정이 public repo에 노출됨 | 정책 설정일 뿐, 민감 정보 아님 |
| 누구나 sudo 가능? | Tailscale + SSH 키 인증 필요 |
| 비밀번호 없이 위험하지 않나? | 이미 SSH 키로 인증됨, 추가 비밀번호는 중복 |

**보안 레이어 구조**:
```
외부 인터넷
     ↓ (Tailscale VPN 필요)
Tailscale 네트워크
     ↓ (SSH 키 인증 필요)
MiniPC SSH 접속
     ↓ (NOPASSWD)
sudo 실행
```

공격자가 sudo 설정을 알아도 Tailscale 네트워크 접근 + SSH 개인키가 없으면 무의미합니다.

**참고**: 많은 NixOS 사용자들이 public dotfiles에 이 설정을 사용합니다.

---

### Ghostty SSH 접속 시 unknown terminal type

> **발생 시점**: 2026-01-18 (MiniPC NixOS 설정)

**증상**: Ghostty 터미널에서 SSH로 MiniPC 접속 시 터미널 타입 에러 및 레이아웃 깨짐.

```bash
$ ssh minipc
$ clear
'xterm-ghostty': unknown terminal type.
```

터미널 레이아웃, 커서 위치가 모두 깨지는 현상 발생.

**원인**: MiniPC (NixOS)에 Ghostty의 terminfo가 설치되지 않음.

| Mac (Ghostty) | MiniPC (NixOS) |
|---------------|----------------|
| TERM=xterm-ghostty 전송 | terminfo 없음 → 에러 |

**해결 1 (임시)**: SSH 접속 시 TERM 변경

```bash
TERM=xterm-256color ssh minipc
```

**해결 2 (영구)**: MiniPC에 ghostty 패키지 설치

```nix
# modules/nixos/home.nix
home.packages = with pkgs; [
  ghostty  # terminfo 포함
  # ...
];
```

```bash
$ sudo nixos-rebuild switch --flake .#greenhead-minipc
# ghostty-1.2.3 설치됨 (terminfo 포함)
```

**확인**:

```bash
$ ssh minipc
$ clear
# 정상 작동, 레이아웃 깨지지 않음
$ infocmp xterm-ghostty
# terminfo 정보 출력됨
```

**참고**: Ghostty는 GUI 앱이지만 terminfo만 필요한 경우에도 전체 패키지를 설치해야 합니다. 서버에서 GUI는 사용하지 않지만 terminfo는 SSH 접속에 필요합니다.

---

## mise 관련

### SSH 비대화형 세션에서 pnpm not found

> **발생 시점**: 2026-01-18 (MiniPC에서 Node.js 프로젝트 작업)

**증상**: Mac에서 SSH로 MiniPC 접속 후 pnpm 명령 실행 시 찾을 수 없음.

```bash
$ ssh minipc 'cd /home/greenhead/IdeaProjects/my-project && pnpm install'
pnpm not found
```

직접 터미널 접속(대화형 세션)에서는 정상 작동하지만, SSH 명령어(비대화형 세션)에서만 실패.

**원인**: SSH 비대화형 세션에서는 `.zshrc`가 로드되지 않아 mise가 활성화되지 않음.

| 세션 타입 | 로드되는 파일 | mise 활성화 |
|----------|--------------|------------|
| 대화형 (ssh 후 쉘) | `.zshenv` + `.zshrc` | ✅ (`.zshrc`에서) |
| 비대화형 (ssh 명령어) | `.zshenv`만 | ❌ |

기존 설정에서는 mise 활성화가 `.zshrc`에만 있었음:

```nix
# modules/shared/programs/shell/default.nix (기존)
programs.zsh.initContent = lib.mkBefore ''
  if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
  fi
'';
```

**해결**: `.zshenv`에 mise shims 활성화 추가, `.zshrc`에 대화형 훅 유지.

```nix
# modules/shared/programs/shell/default.nix
programs.zsh = {
  # .zshenv: SSH 비대화형 세션을 위한 mise shims PATH 추가
  envExtra = ''
    if command -v mise >/dev/null 2>&1 && [[ -z "$MISE_SHELL" ]]; then
      eval "$(mise activate zsh --shims)"
    fi
  '';

  # .zshrc: 대화형 셸을 위한 전체 훅 활성화
  initContent = lib.mkMerge [
    (lib.mkBefore ''
      if command -v mise >/dev/null 2>&1; then
        eval "$(mise activate zsh)"
      fi
    '')
  ];
};
```

**차이점**:

| 활성화 방식 | 용도 | 기능 |
|-----------|------|------|
| `mise activate zsh --shims` | 비대화형 | PATH에 shim 디렉토리만 추가 |
| `mise activate zsh` | 대화형 | 전체 훅 (cd 시 자동 버전 전환 등) |

**확인**:

```bash
$ ssh minipc 'cd /home/greenhead/IdeaProjects/my-project && pnpm --version'
9.15.4
```

**참고**: darwin(Mac)과 NixOS 모두 동일한 설정을 사용하므로, 이 변경은 양쪽에 영향을 줍니다. `MISE_SHELL` 환경변수 체크로 중복 활성화를 방지합니다.

---

### mise가 .nvmrc 파일을 자동 인식하지 않음

> **발생 시점**: 2026-01-18 (MiniPC에서 Node.js 프로젝트 작업)

**증상**: 프로젝트에 `.nvmrc` 파일이 있는데도 mise가 해당 버전을 사용하지 않음.

```bash
$ cat .nvmrc
20.18

$ mise current
node 24.13.0    # .nvmrc의 20.18이 아닌 전역 설정 사용
pnpm 10.28.0
```

**원인**: mise 2025.10.0부터 **idiomatic version file** (`.nvmrc`, `.node-version` 등)이 기본적으로 **비활성화**됨. 이는 버그가 아닌 **의도된 동작**.

**배경**:
- mise 초기에는 모든 언어에 플러그인이 필요했기 때문에 기본 활성화가 합리적이었음
- 이제 대부분의 도구가 코어에 포함되면서, `go.mod`나 `Gemfile`이 있는 것만으로 해당 도구가 자동 설치되는 것이 부자연스럽다고 판단
- "legacy version file" 대신 "idiomatic version file"로 용어 변경 (asdf/mise에 종속되지 않는 파일이므로)

**참고 링크**:
- [GitHub Issue #3212: rename "legacy files" -> "idiomatic files"](https://github.com/jdx/mise/issues/3212)
- [Discussion #4345: idiomatic versions default disabled](https://github.com/jdx/mise/discussions/4345)
- [mise 공식 설정 문서](https://mise.jdx.dev/configuration.html)

**해결**: `idiomatic_version_file_enable_tools` 설정 추가.

```bash
# CLI로 설정
$ mise settings add idiomatic_version_file_enable_tools node
```

또는 `~/.config/mise/config.toml`에 직접 추가:

```toml
[settings]
idiomatic_version_file_enable_tools = ['node']

[tools]
node = "lts"      # 전역 기본값
pnpm = "latest"
```

**NixOS에서 node 설치 시 주의사항**:

mise는 기본적으로 node를 소스에서 빌드하려 하지만, NixOS에서는 python이 없어 실패함.

```bash
# ❌ 실패: python 없음
$ mise use -g node@lts
./configure: line 8: exec: python: not found

# ✅ 성공: 바이너리 버전 사용
$ MISE_NODE_COMPILE=0 mise use -g node@lts
```

**프로젝트별 버전 설치**:

```bash
# 프로젝트의 .nvmrc에 맞는 버전 설치
$ MISE_NODE_COMPILE=0 mise install node@20.18
```

**확인**:

```bash
$ cd /path/to/project
$ mise current
node 20.18.3    # .nvmrc 버전 사용
pnpm 10.28.0
```

**대안: mise.local.toml 사용** (프로젝트에 mise 설정 커밋하지 않을 때):

프로젝트에서 mise를 공식적으로 사용하지 않지만 개인적으로 사용하고 싶을 때:

```bash
# 프로젝트 디렉토리에 로컬 설정 생성
$ cat > mise.local.toml << 'EOF'
[tools]
node = "20.18"
pnpm = "latest"
EOF

# trust 실행 (최초 1회)
$ mise trust
```

> **참고**: `mise.local.toml`과 `.mise.local.toml` 둘 다 global gitignore에 추가되어 있습니다 (`modules/shared/programs/git/default.nix`). mise는 "mise"로 시작하는 파일에 dotfile 버전(`.mise.*`)도 지원합니다.

**참고**: `idiomatic_version_file_enable_tools` 설정이 있으면 `mise.local.toml` 없이도 `.nvmrc`가 인식됩니다. 둘 중 편한 방법을 선택하면 됩니다.

### flake 시스템에서 /etc/nixos/configuration.nix 직접 수정 시 문제

**날짜**: 2026-01-21

**증상**: miniPC에서 로케일 변경을 위해 `/etc/nixos/configuration.nix`를 직접 수정하고 `sudo nixos-rebuild switch`를 실행했으나 실패

```
error: file 'nixos-config' was not found in the Nix search path
```

**원인**:

이 시스템은 **flake 기반 NixOS**입니다:

| 항목 | 전통적 NixOS | Flake 기반 NixOS (현재) |
|------|-------------|----------------------|
| 설정 파일 | `/etc/nixos/configuration.nix` | `~/nixos-config/flake.nix` |
| 빌드 명령 | `nixos-rebuild switch` | `nixos-rebuild switch --flake .#hostname` |
| 설정 위치 | 로컬 | Git 저장소 |

`/etc/nixos/configuration.nix`는 flake 시스템에서 **사용되지 않는 레거시 파일**입니다. 이 파일을 수정해도 빌드에 영향이 없고, 전통적 빌드 명령은 NIX_PATH 오류를 발생시킵니다.

**해결**:

1. `/etc/nixos/configuration.nix` 수정 내용 원복:
```bash
sudo sed -i 's/i18n.defaultLocale.*/# i18n.defaultLocale = "en_US.UTF-8";/' /etc/nixos/configuration.nix
```

2. 로케일 설정은 flake 설정 파일에서 변경:
```nix
# hosts/greenhead-minipc/default.nix 또는 관련 모듈
i18n.defaultLocale = "ko_KR.UTF-8";
i18n.supportedLocales = [ "ko_KR.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" ];
```

**교훈**:

- miniPC에서 설정 변경 시 반드시 flake 기반 명령 사용
- AI 어시스턴트 사용 시 flake 시스템임을 먼저 알려주기
- 설정 변경은 Mac의 nixos-config 레포에서 수정 → push → miniPC에서 pull 후 빌드가 안전함

---

### nixos-rebuild 실패로 인한 시스템 부팅 불가

**날짜**: 2026-01-21

**증상**: `nixos-rebuild switch --flake .#greenhead-minipc` 실행 후 Tailscale, SSH, podman 등 모든 서비스가 사라짐

```bash
# 재부팅 후 서비스가 존재하지 않음
Failed to restart tailscaled.service: Unit tailscaled.service not found.
Failed to stop podman-immich-server.service: Unit podman-immich-server.service not loaded.
```

**원인**:

nixos-rebuild 과정에서 **Git SSH 인증 실패**로 `nixos-config-secret` 프라이빗 레포를 가져오지 못함:

```
error: Failed to fetch git repository ssh://git@github.com/shren207/nixos-config-secret
git@github.com: Permission denied (publickey).
```

이로 인해 불완전한 시스템 설정(세대 30)이 생성되었고, 이 세대로 부팅하면 대부분의 서비스가 없는 상태가 됨.

**해결**:

1. 모니터/키보드로 직접 접속하여 이전 세대로 롤백:
```bash
# 방법 1: 명령으로 롤백
sudo nixos-rebuild switch --rollback

# 방법 2: 세대 목록 확인 후 특정 세대로 전환
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system-29-link/bin/switch-to-configuration switch
```

2. 또는 재부팅 시 GRUB 메뉴에서 이전 세대 선택

**교훈**:

- nixos-rebuild 전 Git SSH 인증 상태 확인 필수:
```bash
ssh-add -l              # SSH agent에 키 로드 확인
ssh -T git@github.com   # GitHub 접근 테스트
```

- sudo 사용 시 SSH_AUTH_SOCK 전달:
```bash
sudo SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild switch --flake .#greenhead-minipc
```

- 불완전한 세대가 생성되면 롤백으로 복구 가능 (NixOS의 장점)

---

### immich OOM으로 인한 시스템 불안정

**날짜**: 2026-01-21

**증상**: miniPC에 Tailscale SSH 접속 불가, 시스템 응답 없음. 모니터 확인 시 OOM 로그 대량 출력:

```
Memory cgroup out of memory: Killed process 93379 (immich) total-vm:28522012kB
Memory cgroup out of memory: Killed process 94003 (immich) total-vm:28810952kB
...
```

**원인**:

immich-ml 컨테이너가 **OpenVINO 버전** (`ghcr.io/immich-app/immich-machine-learning:release-openvino`)을 사용 중이었음. OpenVINO ML 모델은 메모리를 많이 사용하여 4GB 제한을 초과 → OOM Killer 작동 → 컨테이너 재시작 → 다시 OOM → **무한 루프**.

| 컨테이너 | 메모리 제한 | 실제 요구량 (OpenVINO) |
|----------|-----------|---------------------|
| immich-ml | 4GB | 6GB+ |
| immich-server | 4GB | 적정 |

이 과정에서 tailscaled 등 다른 서비스도 영향을 받아 시스템 전체가 불안정해짐.

**해결**:

1. 즉시 조치 (OOM 루프 탈출):
```bash
sudo systemctl stop podman-immich-server podman-immich-ml podman-immich-postgres podman-immich-redis
sudo systemctl restart tailscaled
```

2. 영구 해결 - OpenVINO 대신 일반 이미지 사용:
```nix
# modules/nixos/programs/docker/immich.nix
virtualisation.oci-containers.containers.immich-ml = {
  image = "ghcr.io/immich-app/immich-machine-learning:release";  # openvino 제거
  extraOptions = [
    "--memory=2g"      # 4g에서 2g로 감소
    "--memory-swap=3g"
    # GPU 관련 옵션 제거
  ];
};
```

**변경 전후 비교**:

| 항목 | 변경 전 (OpenVINO) | 변경 후 (CPU) |
|------|-------------------|--------------|
| 이미지 | `release-openvino` | `release` |
| 메모리 | 4GB | 2GB |
| GPU | `/dev/dri` 사용 | 미사용 |
| ML 속도 | 빠름 | 느림 (허용 가능) |
| 안정성 | OOM 위험 | 안정적 |

**교훈**:

- Intel N100 같은 저전력 시스템에서 OpenVINO는 메모리 부담이 큼
- immich ML 작업은 사진 업로드 시에만 발생하므로 속도 저하 체감이 적음
- 컨테이너 메모리 제한 설정 시 실제 사용량 모니터링 필요:
```bash
sudo podman stats --no-stream
```
