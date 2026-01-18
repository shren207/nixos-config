# 주요 기능

이 프로젝트가 제공하는 기능들을 소개합니다.

## 목차

- [NixOS 특화 설정](#nixos-특화-설정)
- [CLI 도구](#cli-도구)
  - [파일/검색 도구](#파일검색-도구)
  - [개발 도구](#개발-도구)
    - [Git 설정](#git-설정)
    - [tmux 단축키](#tmux-단축키)
  - [쉘 도구](#쉘-도구)
    - [Atuin 동기화 모니터링](#atuin-동기화-모니터링)
  - [미디어 처리](#미디어-처리)
  - [유틸리티](#유틸리티)
- [Claude Code 설정](#claude-code-설정)
  - [관리 구조](#claude-code-관리-구조)
  - [양방향 수정](#양방향-수정)
  - [플러그인 관리](#플러그인-관리)
  - [플러그인 주의사항](#플러그인-주의사항)
  - [PreToolUse 훅 (nix develop 환경)](#pretooluse-훅-nix-develop-환경)
- [Nix 관련](#nix-관련)
  - [Pre-commit Hooks](#pre-commit-hooks)
  - [SSH 키 자동 로드](#ssh-키-자동-로드)
  - [darwin-rebuild Alias](#darwin-rebuild-alias)
  - [병렬 다운로드 최적화](#병렬-다운로드-최적화)
- [macOS 시스템 설정](#macos-시스템-설정)
  - [키보드 단축키 (Symbolic Hotkeys)](#키보드-단축키-symbolic-hotkeys)
  - [키 바인딩 (백틱/원화)](#키-바인딩-백틱원화)
  - [폰트 관리 (Nerd Fonts)](#폰트-관리-nerd-fonts)
- [터미널 설정](#터미널-설정)
  - [Ghostty 설정](#ghostty-설정)
  - [tmux Extended Keys](#tmux-extended-keys)
- [GUI 앱 (Homebrew Casks)](#gui-앱-homebrew-casks)
  - [Cursor 설정](#cursor-설정)
    - [Tab 자동완성 우선순위](#tab-자동완성-우선순위)
    - [에디터 탭 라벨 커스터마이징](#에디터-탭-라벨-커스터마이징)
    - [기본 앱 설정 (duti)](#기본-앱-설정-duti)
  - [Hammerspoon 단축키](#hammerspoon-단축키)
    - [터미널 Ctrl/Opt 단축키 (한글 입력소스 문제 해결)](#터미널-ctrlopt-단축키-한글-입력소스-문제-해결)
    - [Finder → Ghostty 터미널 열기](#finder--ghostty-터미널-열기)
- [폴더 액션 (launchd)](#폴더-액션-launchd)
- [Secrets 관리](#secrets-관리)

---

## NixOS 특화 설정

MiniPC(greenhead-minipc)에서 사용되는 NixOS 전용 설정입니다.

`modules/nixos/`에서 관리됩니다.

### 시스템 설정

| 설정 | 파일 | 설명 |
|------|------|------|
| sudo NOPASSWD | `configuration.nix` | wheel 그룹에 비밀번호 없이 sudo 허용 |
| nix-ld | `configuration.nix` | 동적 링크 바이너리 지원 (Claude Code 등) |
| Ghostty terminfo | `configuration.nix` | Ghostty 터미널 호환성 |

### 네트워크/보안 설정

| 모듈 | 파일 | 설명 |
|------|------|------|
| SSH 서버 | `programs/ssh.nix` | 공개키 인증, 비밀번호 비활성화 |
| mosh | `programs/mosh.nix` | UDP 60000-61000 포트 오픈 |
| Tailscale | `programs/tailscale.nix` | VPN 접속 (100.79.80.95) |
| fail2ban | `programs/fail2ban.nix` | SSH 무차별 대입 방지 (3회 실패 시 24시간 차단) |

### SSH 서버 설정

```nix
services.openssh = {
  enable = true;
  settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    PubkeyAuthentication = true;
    ClientAliveInterval = 60;
    ClientAliveCountMax = 3;
  };
};
```

### mosh 설정

불안정한 네트워크(모바일 등)에서 연결 유지를 위한 mosh 서버입니다.

```bash
# 클라이언트(Mac/iPhone)에서 접속
mosh greenhead@100.79.80.95

# 또는 tmux와 함께
mosh greenhead@100.79.80.95 -- tmux attach -t main
```

### Tailscale 설정

```nix
services.tailscale = {
  enable = true;
  useRoutingFeatures = "both";  # Funnel/Serve 지원
};

# 개발 서버 포트 (Tailscale 네트워크 내에서만)
networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 3000 3001 5173 8080 ];
```

### fail2ban 설정

SSH 무차별 대입 공격 방지:

```nix
services.fail2ban.jails.sshd.settings = {
  enabled = true;
  maxretry = 3;      # 3회 실패 시
  findtime = "10m";  # 10분 내
  bantime = "24h";   # 24시간 차단
};
```

### 호스트 설정 (`hosts/greenhead-minipc/`)

| 파일 | 내용 |
|------|------|
| `default.nix` | 호스트 진입점, SSH 키, HDD 마운트 |
| `disko.nix` | NVMe 디스크 파티션 설정 |
| `hardware-configuration.nix` | 하드웨어 자동 감지 설정 |

### NixOS Alias (MiniPC에서 사용)

| Alias | 명령어 | 설명 |
|-------|--------|------|
| `nrs` | `~/.local/bin/nrs.sh` | rebuild (미리보기 + 확인 + 적용) |
| `nrs-offline` | `nrs.sh --offline` | 오프라인 rebuild |
| `nrp` | `~/.local/bin/nrp.sh` | 미리보기만 |
| `nrh` | `sudo nix-env --list-generations ...` | 세대 히스토리 |

> **참고**: MiniPC 설정 및 설치 상세 내용은 [MINIPC_PLAN_V3.md](MINIPC_PLAN_V3.md)를 참고하세요.

---

## CLI 도구

### 파일/검색 도구

| 도구      | 대체 | 설명                                         |
| --------- | ---- | -------------------------------------------- |
| `bat`     | -    | 구문 강조가 있는 파일 뷰어                   |
| `broot`   | tree | 인터랙티브 트리 탐색기 (퍼지 검색, Git 통합) |
| `eza`     | ls   | 아이콘, Git 상태 표시                        |
| `fd`      | find | 빠른 파일 검색                               |
| `fzf`     | -    | 퍼지 파인더                                  |
| `ripgrep` | grep | 빠른 텍스트 검색                             |
| `zoxide`  | cd   | 스마트 디렉토리 점프                         |

#### broot (Modern Linux Tree)

기존 `tree`와 다른 철학의 인터랙티브 파일 탐색기입니다.

| 특성            | tree                  | broot                       |
| --------------- | --------------------- | --------------------------- |
| 출력 방식       | 정적 출력 (전체 덤프) | 동적/인터랙티브             |
| 대규모 디렉토리 | 수십~수백 페이지      | 화면에 맞게 요약            |
| 검색            | 불가                  | 실시간 퍼지 검색, 정규식    |
| 파일 작업       | 불가                  | 복사, 이동, 삭제, 생성      |
| Git 통합        | 없음                  | :gf, :gs 명령으로 상태 확인 |
| 미리보기        | 없음                  | Ctrl+→로 파일 미리보기      |
| 디스크 분석     | 없음                  | -w 옵션으로 용량 시각화     |

**사용법:**

```bash
# 인터랙티브 모드 (기본)
br

# tree 스타일 출력 (비인터랙티브)
bt          # alias: br -c :pt
bt ~/path   # 특정 경로

# 디스크 용량 분석
br -w
```

> **참고**: `br` 함수는 broot 종료 시 선택한 디렉토리로 자동 `cd`합니다.
>
> **주의**: `alias tree='broot'`는 옵션 비호환으로 권장하지 않습니다. 대신 `bt` alias를 사용하세요.

### 개발 도구

| 도구      | 설명                                      |
| --------- | ----------------------------------------- |
| `git`     | 버전 관리 ([상세 설정](#git-설정))        |
| `delta`   | Git diff 시각화 (구문 강조, side-by-side) |
| `tmux`    | 터미널 멀티플렉서                         |
| `lazygit` | Git TUI                                   |
| `gh`      | GitHub CLI                                |
| `jq`      | JSON 처리                                 |

#### Git 설정

`modules/shared/programs/git/default.nix`에서 관리됩니다.

**Interactive Rebase 역순 표시**

`git rebase -i` 실행 시 Fork GUI처럼 **최신 커밋이 위**, 오래된 커밋이 아래에 표시됩니다.

| CLI (기본)              | CLI (적용 후)           | Fork GUI                |
| ----------------------- | ----------------------- | ----------------------- |
| 오래된 → 최신 (위→아래) | 최신 → 오래된 (위→아래) | 최신 → 오래된 (위→아래) |

**구현 방식:**

- `sequence.editor`에 커스텀 스크립트 설정
- 편집 전: 커밋 라인을 역순 정렬하여 표시
- 편집 후: 원래 순서로 복원 (rebase 동작 정상 유지)
- `pkgs.writeShellScript`로 Nix store에서 스크립트 관리

**주의사항:**

- squash/fixup은 **아래쪽 커밋**이 **위쪽 커밋**으로 합쳐집니다 (Fork GUI와 동일)
- `git rebase --edit-todo`에서도 역순 표시가 적용됩니다

#### tmux 단축키

`modules/shared/programs/tmux/files/tmux.conf`에서 관리됩니다.

**기본 단축키** (prefix = `Ctrl+b`):

| 단축키       | 기능                             |
| ------------ | -------------------------------- |
| `prefix + r` | 설정 리로드                      |
| `prefix + a` | 도움말 (사용 가능한 단축키 표시) |
| `prefix + s` | 세션 선택                        |
| `prefix + ,` | 창 이름 변경                     |
| `prefix + $` | 세션 이름 변경                   |
| `prefix + P` | Pane 제목 설정                   |

**Pane Notepad 기능:**

각 pane마다 독립적인 노트를 관리할 수 있습니다.

| 단축키       | 기능                        |
| ------------ | --------------------------- |
| `prefix + n` | 노트 편집                   |
| `prefix + y` | 클립보드 내용을 노트에 추가 |
| `prefix + v` | 노트 읽기 전용 보기         |
| `prefix + u` | 노트의 URL 열기             |
| `prefix + N` | 새 노트 생성 (제목 입력)    |
| `prefix + K` | 기존 노트 연결              |
| `prefix + V` | 노트 미리보기               |

**Pane 상태 표시:**

```
[ main]: my-task 🗒️
```

- Git 브랜치 표시 (` main`)
- 커스텀 pane 제목 (`my-task`)
- 노트 아이콘 (`🗒️`) - 노트에 내용이 있을 때 표시

> **참고**: 노트 파일은 `~/.tmux/pane-notes/`에 저장됩니다.

### 쉘 도구

| 도구       | 설명                                        |
| ---------- | ------------------------------------------- |
| `starship` | 프롬프트 커스터마이징                       |
| `atuin`    | 쉘 히스토리 관리/동기화                     |
| `mise`     | 런타임 버전 관리 (Node.js, Ruby, Python 등) |

#### Atuin 모니터링 시스템

> **테스트 버전**: atuin 18.10.0

`modules/darwin/programs/atuin/`에서 관리됩니다.

Atuin 동기화 상태를 모니터링하고, 동기화 지연 시 알림을 전송합니다.

**아키텍처:**

```
auto_sync (atuin 내장)
    │
    └──▶ 터미널 명령 실행 시 sync_frequency (1분) 간격으로 자동 sync

Hammerspoon 메뉴바 (1분마다)
    │
    └──▶ 🐢 아이콘 상태 업데이트

com.green.atuin-watchdog (launchd, 10분마다)
    │
    ├──▶ 동기화 상태 점검
    └──▶ 지연 시 알림 전송
```

> **참고**: 동기화는 atuin 내장 `auto_sync`가 담당합니다. watchdog은 모니터링 + 알림만 수행합니다.

**기능:**

| 컴포넌트 | 역할 |
| ---- | ---- |
| auto_sync (atuin 내장) | 터미널 명령 실행 시 sync_frequency (1분) 간격으로 자동 sync |
| com.green.atuin-watchdog | 10분마다 상태 체크 + 알림 |
| Hammerspoon 메뉴바 | 🐢 아이콘으로 상태 표시, 1분마다 갱신 |

**메뉴바:**

| 항목 | 설명 |
| ---- | ---- |
| 아이콘 | 🐢 (항상 고정) |
| 상태 문장 | ✅ 정상 / ⚠️ 경고 / ❌ 에러 |
| 정보 표시 | 마지막 동기화, 히스토리 개수, 설정값 |

클릭 시 메뉴 예시:
```
🐢
├─ ✅ 정상 (마지막 동기화: 1분 전)
├─ ─────────────
├─ 마지막 동기화: 2026-01-13 17:42:42 (1분 전)
├─ 히스토리: 63개
├─ ─────────────
├─ 상태 체크 주기: 10분마다
└─ 동기화 경고 임계값: 5분
```

**상태 판단 기준:**

| 상태 | 조건 | 표시 |
| ---- | ---- | ---- |
| 정상 | 5분 이내 동기화됨 | ✅ 정상 (마지막 동기화: N분 전) |
| 경고 | 5분 초과 | ⚠️ 동기화 지연 (N분 초과) |
| 에러 | 파일 없음/파싱 실패 | ❌ 오류 발생 |

**알림:**

| 상황 | 알림 |
| ---- | ---- |
| 5분~30분 지연 | macOS 알림 + Hammerspoon |
| 30분 초과 | macOS 알림 + Hammerspoon + Pushover |

**설정값** (`modules/shared/programs/shell/default.nix`에서 중앙 관리):

```nix
programs.atuin.settings = {
  auto_sync = true;
  sync_frequency = "1m";
  sync.records = true;         # v2 API 사용
  search_mode = "fulltext";    # 정확한 검색 (fuzzy 대신)
  # ...
};
```

watchdog 설정 (`modules/darwin/programs/atuin/default.nix`):

```nix
syncCheckInterval = 600;        # 10분 (초) - watchdog 실행 주기
syncThresholdMinutes = 5;       # 5분 - 경고 임계값
```

**Alias:**

| Alias | 명령어 | 설명 |
| ----- | ------ | ---- |
| `awd` | `~/.local/bin/atuin-watchdog.sh` | 수동 실행 |

```bash
# launchd 상태 확인
launchctl list | grep atuin

# 로그 확인
tail -f ~/.local/share/atuin/watchdog.log
```

**알려진 문제:**

| 문제 | 설명 | 상태 |
| ---- | ---- | ---- |
| `atuin status` 404 | Atuin 서버가 Sync v1 API 비활성화 | 무시해도 됨 |
| fuzzy search 오매칭 | 기본 fuzzy 모드는 의도치 않은 결과 포함 | `search_mode = "fulltext"`로 해결 |

> **참고**: 자세한 트러블슈팅은 [TROUBLESHOOTING.md](TROUBLESHOOTING.md#atuin-관련)를 참고하세요.

### 미디어 처리

폴더 액션에서 사용됩니다.

| 도구          | 설명               |
| ------------- | ------------------ |
| `ffmpeg`      | 비디오/오디오 변환 |
| `imagemagick` | 이미지 처리        |
| `rar`         | RAR 압축           |

### 유틸리티

- `curl` - HTTP 클라이언트
- `unzip` - 압축 해제
- `htop` - 프로세스 모니터링

---

## Claude Code 설정

`modules/shared/programs/claude/`에서 관리됩니다.

Claude Code CLI 도구의 설정을 Nix로 선언적으로 관리하면서, 런타임 수정(플러그인 설치/삭제, 설정 변경)도 지원합니다.

### Claude Code 관리 구조

| 항목            | 관리 방식             | 설명                   |
| --------------- | --------------------- | ---------------------- |
| 앱 설치         | `home.activation`     | 설치 스크립트 실행     |
| `settings.json` | `mkOutOfStoreSymlink` | 양방향 수정 가능       |
| `mcp.json`      | `mkOutOfStoreSymlink` | 양방향 수정 가능       |
| hooks           | `home.file`           | Nix store 심볼릭 링크  |

### 양방향 수정

`settings.json`과 `mcp.json`은 `mkOutOfStoreSymlink`를 사용하여 nixos-config 저장소의 실제 파일을 직접 참조합니다.

**심볼릭 링크 구조:**

```
~/.claude/settings.json
    ↓ (symlink)
$HOME/<nixos-config-path>/modules/shared/programs/claude/files/settings.json
```

**장점:**

- **Claude Code → nixos-config**: 플러그인 설치, 설정 변경 시 nixos-config에 바로 반영
- **nixos-config → Claude Code**: 파일 직접 수정 후 즉시 적용 (rebuild 불필요)
- **버전 관리**: `git diff`로 변경사항 확인 후 커밋 가능

**왜 이 방식인가?**

| 방식                    | 플러그인 관리  | 설정 수정 | 문제점                                      |
| ----------------------- | -------------- | --------- | ------------------------------------------- |
| Nix store 심볼릭 링크   | 불가           | 불가      | 읽기 전용이라 CLI로 플러그인 설치/삭제 불가 |
| **mkOutOfStoreSymlink** | CLI로 자유롭게 | 양방향    | 없음                                        |

> **참고**: Cursor의 `settings.json`, `keybindings.json`도 동일한 방식으로 관리됩니다.

### 플러그인 관리

`mkOutOfStoreSymlink` 방식으로 전환 후 플러그인을 CLI로 자유롭게 관리할 수 있습니다.

**플러그인 설치:**

```bash
claude plugin install <plugin-name>@<marketplace> --scope user
```

**플러그인 제거:**

```bash
claude plugin uninstall <plugin-name>@<marketplace> --scope user
```

**플러그인 목록 확인:**

```bash
claude plugin list
```

**UI로 관리:**

Claude Code 내에서 `/plugin` 명령으로 설치된 플러그인을 확인하고 관리할 수 있습니다.

### 플러그인 주의사항

**유령 플러그인 문제 (Claude Code 2.1.4 기준):**

Claude Code에서 플러그인을 활성화/비활성화하면 `settings.json`의 `enabledPlugins` 섹션에 자동으로 기록됩니다:

```json
"enabledPlugins": {
  "frontend-design@claude-plugins-official": true
}
```

그러나 CLI 명령어(`claude plugin uninstall`)를 사용하지 않고 사용자가 직접 `settings.json`에서 해당 프로퍼티를 삭제하면, **유령 플러그인(ghost plugin) 문제**가 발생합니다:

| 상태 | 증상 |
|------|------|
| `/plugin` 명령 | 플러그인이 "설치됨"으로 표시 |
| 설정 변경 | 활성화/비활성화 토글 불가 |
| 플러그인 기능 | 동작하지 않음 |

**해결 방법:**

마켓플레이스 재설치로는 해결되지 않습니다. 유일한 방법은 `settings.json`에 유령 플러그인을 다시 명시한 후 CLI로 제거하는 것입니다:

1. `settings.json`의 `enabledPlugins`에 유령 플러그인 추가:
   ```json
   "enabledPlugins": {
     "ghost-plugin-name@marketplace": true
   }
   ```

2. Claude Code CLI로 플러그인 제거:
   ```bash
   claude plugin uninstall ghost-plugin-name@marketplace --scope user
   ```

> **참고**: 자세한 내용은 [TRIAL_AND_ERROR.md](TRIAL_AND_ERROR.md#2026-01-11-claude-code-유령-플러그인-해결) 참고.

**권장 사항:**

플러그인 설치/제거는 반드시 CLI 명령어를 사용하세요:

```bash
# 마켓플레이스 추가
claude plugin marketplace add anthropics/claude-plugins-official

# 플러그인 설치
claude plugin install plugin-name@marketplace --scope user

# 플러그인 제거
claude plugin uninstall plugin-name@marketplace --scope user
```

**Anthropic 마켓플레이스 현황 (2026-01-11 기준):**

| 마켓플레이스                       | 상태        |
| ---------------------------------- | ----------- |
| `anthropics/claude-code`           | 유지보수 X  |
| `anthropics/claude-plugins-official` | 유지보수 O |

> **참고**: 공식 문서는 [Official Anthropic Marketplace](https://code.claude.com/docs/en/discover-plugins#official-anthropic-marketplace)를 참고하세요.

### Private 플러그인

프로젝트 전용 commands/skills는 Private 저장소(`nixos-config-secret`)에서 별도 플러그인으로 관리합니다.

**특징:**

| 항목      | 설명                                          |
| --------- | --------------------------------------------- |
| 위치      | `nixos-config-secret/plugins/`                |
| 설치 방식 | Home Manager activation으로 symlink 자동 생성 |
| 수정 반영 | 즉시 (darwin-rebuild 불필요)                  |
| 동기화    | git pull → nix flake update → darwin-rebuild  |

**장점:**

- **대외비 분리**: Public 저장소에 노출되지 않음
- **즉시 반영**: symlink이므로 파일 수정 시 바로 적용
- **선언적 관리**: Nix로 자동 설치, 멀티머신 동기화
- **프로젝트별 적용**: 특정 프로젝트에서만 플러그인 활성화

> **참고**: Private 플러그인 상세 내용 및 추가 방법은 `nixos-config-secret/README.md`를 참고하세요.

### PreToolUse 훅 (nix develop 환경)

`.claude/scripts/wrap-git-with-nix-develop.sh`에서 관리됩니다.

이 프로젝트는 `lefthook`을 통해 git pre-commit 훅으로 `gitleaks`, `nixfmt`, `shellcheck`를 실행합니다. 이 도구들은 `nix develop` 환경에서만 사용 가능하므로, Claude Code가 git 명령어를 실행할 때 자동으로 nix develop 환경에서 실행되도록 PreToolUse 훅을 사용합니다.

**왜 필요한가:**

| 환경 | lefthook 도구 | 결과 |
|------|---------------|------|
| `nix develop` 셸 | 사용 가능 | pre-commit 훅 정상 동작 |
| 일반 시스템 셸 | 사용 불가 | pre-commit 훅 실패 또는 우회 |
| Claude Code (기본) | 사용 불가 | pre-commit 훅 실패 또는 우회 |
| Claude Code + 훅 | 사용 가능 | pre-commit 훅 정상 동작 ✅ |

**동작 방식:**

```
[Claude Code가 git 명령어 실행 요청]
        ↓
[PreToolUse 훅 (wrap-git-with-nix-develop.sh)]
        ↓
[명령어를 Base64로 인코딩]
        ↓
[nix develop -c bash로 래핑]
        ↓
[래핑된 명령어 실행]
```

**예시:**

```bash
# 원본 명령어
git add . && git commit -m "feat: 새 기능" && git push

# 래핑된 명령어
echo Z2l0IGFkZC... | base64 -d | nix develop -c bash
```

**처리 대상:**

| 명령어 | 래핑 여부 | 사유 |
|--------|----------|------|
| `git add` | ✅ | lefthook 필요 |
| `git commit` | ✅ | lefthook 필요 |
| `git push` | ✅ | lefthook 필요 |
| `git stash` | ✅ | lefthook 필요 |
| `git status` | ❌ | lefthook 불필요 |
| `git log` | ❌ | lefthook 불필요 |
| `ls`, `cat` 등 | ❌ | git 명령어 아님 |

**Base64 인코딩 장점:**

- 줄바꿈, 따옴표, 백틱, `$변수`, `&&` 등 모든 특수문자 안전 처리
- 단일 라인 출력 → Claude Code 호환성 보장
- 체인 명령어(`&&`)도 전체가 nix develop 환경에서 실행됨

**설정 파일:**

```json
// .claude/settings.local.json (프로젝트별 훅 설정)
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PROJECT_DIR}/.claude/scripts/wrap-git-with-nix-develop.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**디버깅:**

문제 발생 시 스크립트의 디버그 로깅을 활성화할 수 있습니다:

```bash
# .claude/scripts/wrap-git-with-nix-develop.sh 11-13행 주석 해제
exec 2>>/tmp/claude-hook-debug.log
echo "=== $(date) ===" >&2
echo "Input: $input" >&2
```

> **참고**: JSON validation 에러 등 훅 관련 문제는 [TROUBLESHOOTING.md](TROUBLESHOOTING.md#pretooluse-훅-json-validation-에러)를 참고하세요.

---

## Nix 관련

`modules/shared/configuration.nix`와 `modules/shared/programs/shell/default.nix`에서 관리됩니다.

### Pre-commit Hooks

`flake.nix`의 `devShells`와 `lefthook.yml`에서 관리됩니다.

lefthook을 사용하여 커밋 전 자동 검사를 수행합니다. 민감 정보 유출, 포맷 오류, 쉘 스크립트 문제를 커밋 단계에서 차단합니다.

**구성 요소:**

| Hook | 도구 | 기능 |
|------|------|------|
| gitleaks | `gitleaks protect --staged` | 민감 정보(API 키, 비밀번호 등) 커밋 차단 |
| nixfmt | `nixfmt --check` | Nix 파일 포맷 검사 |
| shellcheck | `shellcheck -S warning` | Shell 스크립트 린팅 (warning 이상) |

**사용법:**

```bash
# devShell 진입 (lefthook 자동 설치)
nix develop

# 이후 커밋 시 자동 실행
git commit -m "message"
```

**gitleaks 허용 목록 (.gitleaks.toml):**

| 경로 | 사유 |
|------|------|
| `flake.lock` | 해시값이 시크릿으로 오탐지됨 |
| `*.local.md` | 로컬 전용 문서 (커밋 안 함) |

**탐지 예시:**

```bash
# 차단됨 (Private Key)
-----BEGIN RSA PRIVATE KEY-----

# 차단됨 (실제 형태의 AWS Access Key)
AKIAIOSFODNN7TESTKEY

# 허용됨 (AWS 예시 키 - EXAMPLE로 끝남)
AKIAIOSFODNN7EXAMPLE
```

**gitleaks 내장 allowlist 패턴:**

gitleaks는 `aws-access-token` 규칙에 다음 [내장 allowlist](https://github.com/gitleaks/gitleaks/blob/master/config/gitleaks.toml)를 포함합니다:

```toml
[rules.allowlist]
regexes = [
    '''.+EXAMPLE$''',
]
```

이 패턴은 `EXAMPLE`로 끝나는 모든 문자열을 허용합니다. AWS 공식 문서에서 사용하는 예시 키(`AKIAIOSFODNN7EXAMPLE`)가 false positive로 탐지되는 것을 방지하기 위함입니다.

| 키 | 탐지 여부 | 사유 |
|----|----------|------|
| `AKIAIOSFODNN7EXAMPLE` | 허용 | `EXAMPLE`로 끝남 |
| `AKIA222222222EXAMPLE` | 허용 | `EXAMPLE`로 끝남 |
| `AKIAIOSFODNN7TESTKEY` | **차단** | `EXAMPLE`로 끝나지 않음 |
| `AKIAIOSFODNN7REALKEY` | **차단** | `EXAMPLE`로 끝나지 않음 |

> **주의**: 실제 키를 `...EXAMPLE` 형태로 위장하면 탐지를 우회할 수 있으므로, PR 리뷰 시 주의가 필요합니다.

**주의사항:**

- `nix develop` 환경 외부에서 커밋 시 hook이 실패할 수 있음
- 새 스크립트 추가 시 `shellcheck -S warning`으로 사전 검사 권장

### SSH 키 자동 로드

`modules/darwin/programs/ssh/`에서 관리됩니다.

Private 저장소(`nixos-config-secret`)를 SSH로 fetch하기 위해 SSH 키가 `ssh-agent`에 로드되어 있어야 합니다. 이 설정은 재부팅 후에도 자동으로 키를 로드합니다.

**아키텍처:**

```
macOS 로그인
    │
    ├──▶ com.green.ssh-add-keys (launchd agent)
    │       └──▶ ssh-add ~/.ssh/id_ed25519
    │
    └──▶ 터미널에서 nrs 실행
            └──▶ ensure_ssh_key_loaded() (키 로드 확인)
                    └──▶ darwin-rebuild switch
```

**컴포넌트:**

| 컴포넌트 | 역할 |
| -------- | ---- |
| `programs.ssh` | `~/.ssh/config` 생성 (AddKeysToAgent, IdentityFile) |
| `launchd.agents.ssh-add-keys` | 로그인 시 SSH 키 자동 로드 |
| `nrs.sh` | darwin-rebuild 전 키 로드 확인 |

**생성되는 `~/.ssh/config`:**

```
Host *
  IdentityFile /Users/glen/.ssh/id_ed25519
  AddKeysToAgent yes
```

**확인 방법:**

```bash
# SSH agent에 키 로드 확인
ssh-add -l

# launchd agent 상태 확인
launchctl list | grep ssh-add

# 로그 확인
cat ~/Library/Logs/ssh-add-keys.log
```

> **참고**: 자세한 트러블슈팅은 [TROUBLESHOOTING.md](TROUBLESHOOTING.md#재부팅-후-ssh-키가-ssh-agent에-로드되지-않음)를 참고하세요.

### darwin-rebuild Alias

시스템 설정 적용을 위한 편리한 alias입니다.

| Alias         | 용도                                        |
| ------------- | ------------------------------------------- |
| `nrs`         | 일반 rebuild (미리보기 + 확인 + 적용) |
| `nrs-offline` | 오프라인 rebuild (빠름, 동일한 안전 조치 포함) |
| `nrp`         | 미리보기만 (적용 안 함) |
| `nrp-offline` | 오프라인 미리보기 |
| `nrh`         | 최근 10개 세대 히스토리 (빠름) |
| `nrh -n 20`   | 최근 20개 세대 히스토리 |
| `nrh -a`      | 전체 세대 히스토리 (느림) |
| `hs`          | Hammerspoon CLI                             |
| `hsr`         | Hammerspoon 설정 리로드 (완료 시 알림 표시) |
| `reset-term`  | 터미널 CSI u 모드 리셋 (문제 발생 시 복구)  |

**`nrs` / `nrs-offline` 동작 흐름:**

```
0. 🔑 SSH 키 로드 확인 (private repo fetch 보장)
   └── ssh-add -l로 확인 → 없으면 ssh-add 실행

1. 🧹 launchd 에이전트 정리 (setupLaunchAgents 멈춤 방지)
   └── com.green.* 에이전트 동적 탐색 → bootout + plist 삭제

2. 🔨 darwin-rebuild build + nvd diff (미리보기)
   └── 빌드 실패 시 즉시 종료 (에러 처리)

3. ❓ 사용자 확인 ("Apply these changes? [Y/n]")

4. 🔨 darwin-rebuild switch 실행
   └── --offline 플래그 (nrs-offline만)

5. 🔄 Hammerspoon 완전 재시작 (HOME 오염 방지)
   └── killall → sleep 1 → open -a Hammerspoon

6. 🧹 빌드 아티팩트 정리
   └── ./result* 심볼릭 링크 삭제
```

**구현:**

- 스크립트: `scripts/nrs.sh`, `scripts/nrp.sh`, `scripts/nrh.sh`
- 설치 위치: `~/.local/bin/nrs.sh`, `~/.local/bin/nrp.sh`, `~/.local/bin/nrh.sh`
- alias: `nrs` → `~/.local/bin/nrs.sh`, `nrs-offline` → `~/.local/bin/nrs.sh --offline`

에이전트 목록은 하드코딩하지 않고 `launchctl list | grep com.green`으로 동적 탐색합니다.

**사용 시나리오:**

```bash
# 평소 (설정만 변경, flake.lock 동기화된 상태)
nrs-offline  # ~10초 완료!

# 새 패키지 추가 또는 flake update 후
nrs          # 일반 모드 (다운로드 필요)
```

**`--offline` 플래그의 의미:**

- 네트워크 요청을 하지 않고 로컬 캐시(`/nix/store`)만 사용
- flake input 버전 확인, substituter 확인 등을 스킵
- **속도 향상**: 일반 모드 ~3분 → 오프라인 모드 ~10초 (약 18배 빠름)

**소스 참조 방식 (로컬 vs Remote):**

> **중요**: `nrs`와 `nrs-offline` **모두** `flake.lock`에 잠긴 **Remote Git URL**에서 소스를 참조합니다.

| 항목 | 설명 |
|------|------|
| 소스 위치 | `flake.lock`에 기록된 remote Git URL (SSH) |
| 로컬 경로 | 사용하지 않음 (`path:...` 형태 아님) |
| `--offline` 역할 | 다운로드 스킵 + Nix store 캐시 사용 (로컬 경로 전환이 **아님**) |

예를 들어 `nixos-config-secret`은 다음과 같이 정의되어 있습니다:

```nix
# flake.nix
nixos-config-secret = {
  url = "git+ssh://git@github.com/shren207/nixos-config-secret?ref=main&shallow=1";
  # ...
};
```

- `nrs` 실행 시: SSH로 GitHub에서 해당 커밋을 fetch
- `nrs-offline` 실행 시: 이미 캐시된 버전 사용 (fetch 스킵)
- 로컬에서 `nixos-config-secret` 디렉토리를 수정해도 **빌드에 반영되지 않음**
- 변경사항 반영 순서: `git push` → `nix flake update nixos-config-secret` → `nrs`

**자동 예방 조치:**

| 문제 | 예방 방법 |
|------|----------|
| `setupLaunchAgents`에서 멈춤 | rebuild 전 launchd 에이전트 정리 |
| Hammerspoon HOME이 `/var/root`로 오염 | rebuild 후 Hammerspoon 완전 재시작 |

> **참고**: 문제 상세 내용은 [TROUBLESHOOTING.md](TROUBLESHOOTING.md#darwin-rebuild-시-setuplaunchagents에서-멈춤)를 참고하세요.

**주의사항:**

- `nrs-offline`은 캐시에 모든 패키지가 있어야 동작
- 새 패키지 추가 시에는 `nrs` 사용 필요
- 집/회사 간 `flake.lock`을 git으로 동기화하면 어디서든 `nrs-offline` 사용 가능

### 패키지 변경사항 미리보기 (nvd)

시스템 업데이트 전 변경사항을 미리 확인할 수 있습니다.

| 명령어 | 설명 |
|--------|------|
| `nrp` | 빌드 후 변경사항 미리보기 (적용 안 함) |
| `nrp-offline` | 오프라인 미리보기 |
| `nrh` | 최근 10개 세대 히스토리 (기본) |
| `nrh -n 5` | 최근 5개 세대 히스토리 |
| `nrh -a` | 전체 세대 히스토리 (느림) |

> **참고**: `nrs` 실행 시에도 빌드 후 변경사항을 보여주고 확인을 요청합니다.

**`nrh` 옵션:**
- `-n, --limit N`: 최근 N개 세대만 조회 (기본: 10)
- `-a, --all`: 전체 세대 조회 (세대가 많으면 느림)
- `-h, --help`: 도움말

**출력 예시:**

```
[U*] firefox: 132.0 → 133.0     # 업데이트 (*=의존성 변경)
[A]  new-package: 1.0            # 신규 추가
[R]  removed-package             # 제거
```

**권장 워크플로우:**

```bash
# 1. 집에서 flake update 후 push
nix flake update
nrs
git add flake.lock && git commit -m "update flake.lock" && git push

# 2. 회사에서 pull 후 빠른 rebuild
git pull
nrs-offline  # 네트워크 요청 없이 빠르게 빌드
```

### 병렬 다운로드 최적화

패키지 다운로드 속도를 높이기 위한 설정입니다.

**현재 설정:**

```nix
nix.settings = {
  max-substitution-jobs = 128;  # 동시 다운로드 수 (기본값: 16)
  http-connections = 50;        # 동시 HTTP 연결 수 (기본값: 25)
};
```

**효과:**

| 설정                    | 기본값 | 현재값 | 효과                         |
| ----------------------- | ------ | ------ | ---------------------------- |
| `max-substitution-jobs` | 16     | 128    | 동시에 128개 패키지 다운로드 |
| `http-connections`      | 25     | 50     | HTTP 연결 2배 증가           |

**확인 방법:**

```bash
nix config show | grep -E "(max-substitution|http-connections)"
# 출력:
# http-connections = 50
# max-substitution-jobs = 128
```

> **참고**: 공격적인 설정으로 네트워크 대역폭을 많이 사용합니다. 공유 네트워크에서 문제가 되면 값을 낮추세요. 자세한 트러블슈팅은 [TROUBLESHOOTING.md](TROUBLESHOOTING.md#darwin-rebuild-빌드-속도가-느림)를 참고하세요.

---

## macOS 시스템 설정

`modules/darwin/configuration.nix`에서 관리됩니다.

### 보안

- **Touch ID sudo 인증**: 터미널에서 sudo 실행 시 Touch ID 사용

### Dock

- 자동 숨김 활성화
- 최근 앱 숨김
- 아이콘 크기 36px
- Spaces 자동 재정렬 비활성화
- 최소화 효과: Suck

### Finder

- 숨김 파일 표시
- 모든 확장자 표시

### 키보드

- **KeyRepeat = 1**: 최고 속도 키 반복
- **InitialKeyRepeat = 15**: 빠른 초기 반복

### 마우스/트랙패드

- **자연스러운 스크롤 비활성화**: `com.apple.swipescrolldirection = false`

### 자동 수정 비활성화

- 자동 대문자화
- 맞춤법 자동 수정
- 마침표 자동 삽입
- 따옴표 자동 변환
- 대시 자동 변환

### 키보드 단축키 (Symbolic Hotkeys)

`modules/darwin/configuration.nix`의 `CustomUserPreferences."com.apple.symbolichotkeys"`에서 관리됩니다.

macOS 시스템 키보드 단축키를 nix-darwin으로 선언적으로 관리합니다. `darwin-rebuild switch` 시 `activateSettings -u`로 즉시 적용됩니다.

**스크린샷 설정:**

| ID  | 단축키 | 기능                  | 상태     |
| --- | ------ | --------------------- | -------- |
| 28  | ⇧⌘3    | 화면 → 파일           | 비활성화 |
| 29  | ⌃⇧⌘3   | 화면 → 클립보드       | 활성화   |
| 30  | ⇧⌘4    | 선택 영역 → 파일      | 비활성화 |
| 31  | ⇧⌘4    | 선택 영역 → 클립보드  | 활성화   |
| 32  | ⇧⌘5    | 스크린샷 및 기록 옵션 | 활성화   |

**입력 소스 설정:**

| ID  | 단축키 | 기능           | 상태     |
| --- | ------ | -------------- | -------- |
| 60  | ⌃Space | 이전 입력 소스 | 비활성화 |
| 61  | F18    | 다음 입력 소스 | 활성화   |

> **참고**: Hammerspoon에서 Caps Lock → F18 리매핑을 담당합니다.

**Spotlight 설정:**

| ID  | 단축키  | 기능               | 상태                    |
| --- | ------- | ------------------ | ----------------------- |
| 64  | ⌘Space  | Spotlight 검색     | 비활성화 (Raycast 사용) |
| 65  | ⌥⌘Space | Finder 검색 윈도우 | 활성화                  |

**Mission Control 설정:**

| ID  | 단축키 | 기능            | 상태   |
| --- | ------ | --------------- | ------ |
| 32  | F3     | Mission Control | 활성화 |

**기능 키 설정:**

- `com.apple.keyboard.fnState = true`: F1-F12 키를 표준 기능 키로 사용 (밝기/볼륨 조절 대신)

**Modifier 비트마스크 참조:**

| Modifier | 값                 |
| -------- | ------------------ |
| Shift    | 131072 (0x20000)   |
| Control  | 262144 (0x40000)   |
| Option   | 524288 (0x80000)   |
| Command  | 1048576 (0x100000) |
| Fn       | 8388608 (0x800000) |

**설정 확인:**

```bash
defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys | grep -A 5 '"61"'
```

**즉시 적용**:

`darwin-rebuild switch` 시 `activateSettings -u`를 실행하여 키보드 단축키가 즉시 반영됩니다. 재시작/로그아웃 불필요.

> **참고**: `activateSettings -u`는 `마우스` > `자연스러운 스크롤` 옵션을 **활성화**시키는 부작용이 있어, 직후에 `defaults write`로 재설정합니다. 자세한 내용은 [TROUBLESHOOTING.md](TROUBLESHOOTING.md#killall-cfprefsd로-인한-스크롤-방향-롤백)를 참고하세요.

### 키 바인딩 (백틱/원화)

`modules/darwin/programs/keybindings/`에서 관리됩니다.

한국어 키보드에서 백틱(`) 키 입력 시 원화(₩)가 입력되는 문제를 해결합니다. macOS Cocoa Text System의 `DefaultKeyBinding.dict`를 사용합니다.

| 입력         | 출력    | 설명                       |
| ------------ | ------- | -------------------------- |
| `₩` 키       | `` ` `` | 백틱 입력 (기본 동작 변경) |
| `Option + 4` | `₩`     | 원화 기호 입력 (필요시)    |

**설정 파일 위치:** `~/Library/KeyBindings/DefaultKeyBinding.dict`

**참고:**

- 적용 후 앱 재시작 필요 (일부 앱은 로그아웃/재로그인 필요)
- 참고 자료: [ttscoff/KeyBindings](https://github.com/ttscoff/KeyBindings)

### 폰트 관리 (Nerd Fonts)

`modules/darwin/configuration.nix`에서 관리됩니다.

nix-darwin의 `fonts.packages` 옵션을 사용하여 Nerd Fonts를 선언적으로 관리합니다. 폰트는 `/Library/Fonts/Nix Fonts/`에 자동 설치됩니다.

**현재 설치된 폰트:**

| 폰트                     | 패키지명                    | 용도                            |
| ------------------------ | --------------------------- | ------------------------------- |
| FiraCode Nerd Font       | `nerd-fonts.fira-code`      | 터미널/에디터용 프로그래밍 폰트 |
| JetBrains Mono Nerd Font | `nerd-fonts.jetbrains-mono` | 터미널/에디터용 프로그래밍 폰트 |

**Nerd Fonts vs 일반 폰트:**

| 항목               | 일반 프로그래밍 폰트 | Nerd Font 버전                                    |
| ------------------ | -------------------- | ------------------------------------------------- |
| 기본 문자          | ✓                    | ✓                                                 |
| 리가처 (ligatures) | 폰트에 따라 다름     | 원본 폰트와 동일                                  |
| 아이콘 글리프      | ✗                    | ✓ (Devicons, Font Awesome, Powerline 등 9,000+개) |
| 용도               | 일반 코딩            | 터미널/에디터에서 아이콘 표시 필요 시             |

> Nerd Fonts는 기존 프로그래밍 폰트(FiraCode, JetBrains Mono, Hack 등)에 아이콘 글리프를 패치한 버전입니다.

**Nerd Fonts가 필요한 경우:**

- 터미널 프롬프트(Starship)에서 Git 브랜치 아이콘, 폴더 아이콘 등 표시
- 파일 탐색기(eza, broot)에서 파일 타입별 아이콘 표시
- Neovim/VS Code 플러그인에서 아이콘 사용 시

**설치 경로:** `/Library/Fonts/Nix Fonts/`

**확인 방법:**

```bash
# 설치된 폰트 확인
ls "/Library/Fonts/Nix Fonts/"

# 폰트 목록에서 확인
fc-list | grep -i "FiraCode\|JetBrains"
```

**사용 가능한 Nerd Fonts 목록:**

```bash
nix search nixpkgs nerd-fonts
```

> **참고**: NixOS 25.05+에서는 `nerd-fonts.fira-code` 형식의 개별 패키지를 사용합니다. 구 문법 `(nerdfonts.override { fonts = [...]; })`은 더 이상 사용되지 않습니다. 자세한 내용은 [Nixpkgs nerd-fonts](https://github.com/NixOS/nixpkgs/tree/master/pkgs/data/fonts/nerd-fonts) 참고.

---

## 터미널 설정

### Ghostty 설정

`modules/shared/programs/ghostty/default.nix`에서 관리됩니다.

Ghostty 터미널 설정을 Home Manager의 `xdg.configFile`을 사용하여 선언적으로 관리합니다.

**현재 설정:**

| 옵션                  | 값     | 설명                        |
| --------------------- | ------ | --------------------------- |
| `macos-option-as-alt` | `left` | 왼쪽 Option 키를 Alt로 사용 |

**설정 파일 위치:** `~/.config/ghostty/config`

> **참고**: Ghostty keybind 설정(`keybind = ctrl+c=text:\x03`)은 Claude Code 2.1.0 ~ 2.1.4 버전의 CSI u 모드에서 우회됩니다. 이 버전들에서 Ctrl/Opt 단축키 문제는 **Hammerspoon**에서 처리합니다. 자세한 내용은 [Hammerspoon 단축키](#hammerspoon-단축키)를 참고하세요. (추후 버전에서 해결될 수 있음)

### tmux Extended Keys

`modules/shared/programs/tmux/files/tmux.conf`에서 관리됩니다.

tmux에서 CSI u (Kitty Keyboard Protocol)를 지원하도록 extended-keys를 활성화합니다.

**현재 설정:**

```bash
set -g default-terminal "tmux-256color"
set -g extended-keys on
set -s extended-keys on
set -g extended-keys-format csi-u
set -as terminal-features 'xterm*:extkeys'
```

**효과:**

| 설정                         | 설명                                                    |
| ---------------------------- | ------------------------------------------------------- |
| `default-terminal`           | `screen-256color` → `tmux-256color`로 변경 (CSI u 지원) |
| `extended-keys on`           | extended keys 활성화                                    |
| `extended-keys-format csi-u` | CSI u 형식 사용                                         |
| `terminal-features`          | xterm 계열에서 extkeys 기능 활성화                      |

**터미널 오버라이드:**

```bash
set -ga terminal-overrides ",xterm-256color:Tc"
set -ga terminal-overrides ",xterm-ghostty:Tc"
set -ga terminal-overrides ",tmux-256color:Tc"
```

Ghostty, xterm-256color, tmux-256color에서 True Color(24-bit) 지원을 활성화합니다.

---

## GUI 앱 (Homebrew Casks)

`modules/darwin/programs/homebrew.nix`에서 관리됩니다.

| 앱             | 용도                                               |
| -------------- | -------------------------------------------------- |
| Cursor         | AI 코드 에디터 ([상세 설정](#cursor-기본-앱-설정)) |
| Ghostty        | 터미널                                             |
| Raycast        | 런처 (Spotlight 대체)                              |
| Rectangle      | 창 관리                                            |
| Hammerspoon    | 키보드 리매핑/자동화                               |
| Homerow        | 키보드 네비게이션                                  |
| Docker         | 컨테이너                                           |
| Fork           | Git GUI                                            |
| Slack          | 메신저                                             |
| Figma          | 디자인                                             |
| MonitorControl | 외부 모니터 밝기 조절                              |

### Cursor 설정

`modules/darwin/programs/cursor/`에서 관리됩니다.

#### Tab 자동완성 우선순위

> **참고**: Cursor 2.3.35 기준

Cursor의 Tab 자동완성(AI 기반)과 VS Code IntelliSense(언어 서버 기반)가 동시에 표시될 때, **Tab 키는 Cursor 자동완성을 우선 처리**합니다. IntelliSense 제안은 무시됩니다.

- **Tab**: Cursor AI 자동완성 수락
- **방향키(↑↓)**: IntelliSense 제안 탐색
- **Enter**: IntelliSense 제안 수락

#### 에디터 탭 라벨 커스터마이징

`settings.json`의 `workbench.editor.customLabels.patterns`를 사용하여 Next.js 프로젝트의 탭 가독성을 개선합니다.

**문제 상황**: Next.js App Router 사용 시 `page.tsx`, `layout.tsx` 등 동일한 파일명이 여러 탭에 열리면 구분이 어려움.

**해결**: 폴더명을 함께 표시하여 어느 라우트의 파일인지 즉시 파악 가능.

| 파일 경로                | Before         | After                |
| ------------------------ | -------------- | -------------------- |
| `app/dashboard/page.tsx` | `page.tsx`     | `dashboard/page.tsx` |
| `app/auth/loading.tsx`   | `loading.tsx`  | `auth/loading.tsx`   |
| `pages/api/index.ts`     | `index.ts`     | `api/index.ts`       |
| `features/cart/hooks.ts` | `hooks.ts`     | `cart/hooks.ts`      |
| `lib/api/constants.ts`   | `constants.ts` | `api/constants.ts`   |

**지원 패턴:**

| 패턴         | 대상 파일                                                                | 표시 형식          |
| ------------ | ------------------------------------------------------------------------ | ------------------ |
| App Router   | `page`, `layout`, `loading`, `error`, `not-found`, `template`, `default` | `dirname/filename` |
| Pages Router | `index`, `_app`, `_document`, `_error`                                   | `dirname/filename` |
| 공통 index   | `index.ts(x)`                                                            | `dirname/index`    |
| 유틸리티     | `hook(s)`, `constant(s)`, `util(s)`, `state(s)`, `type(s)`, `style(s)`   | `dirname/filename` |

#### 기본 앱 설정 (duti)

텍스트/코드 파일을 더블클릭 시 Xcode 대신 Cursor로 열리도록 `duti`를 사용하여 파일 연결을 설정합니다.

**설정 대상 확장자:**

```
txt, text, md, mdx, js, jsx, ts, tsx, mjs, cjs,
json, yaml, yml, toml, css, scss, sass, less, nix,
sh, bash, zsh, py, rb, go, rs, lua, sql, graphql, gql,
xml, svg, conf, ini, cfg, env, gitignore, editorconfig, prettierrc, eslintrc
```

**설정 대상 UTI:**

| UTI                  | 설명             |
| -------------------- | ---------------- |
| `public.plain-text`  | 일반 텍스트 파일 |
| `public.source-code` | 소스 코드 파일   |
| `public.data`        | 범용 데이터 파일 |

**동작 방식:**

- Home Manager의 `home.activation`을 사용하여 `darwin-rebuild switch` 시 자동 적용
- `duti -s <bundle-id> .<ext> all` 명령으로 각 확장자 설정
- Xcode 업데이트 시에도 `darwin-rebuild switch` 재실행으로 복구 가능

**확인 방법:**

```bash
# 특정 확장자의 기본 앱 확인
duti -x txt
# 예상 출력: Cursor.app

# Bundle ID 확인 (Cursor 업데이트 시)
mdls -name kMDItemCFBundleIdentifier /Applications/Cursor.app
```

> **참고**: `.html`, `.htm` 확장자는 Safari가 시스템 수준에서 보호하므로 설정 불가. 자세한 내용은 [TRIAL_AND_ERROR.md](TRIAL_AND_ERROR.md#2024-12-25-duti로-htmlhtm-기본-앱-설정-실패) 참고.

### Hammerspoon 단축키

`modules/darwin/programs/hammerspoon/files/init.lua`에서 관리됩니다.

#### 터미널 Ctrl/Opt 단축키 (한글 입력소스 문제 해결)

Claude Code 2.1.0+에서 한글 입력소스일 때 Ctrl/Opt 단축키가 동작하지 않는 문제를 Hammerspoon에서 시스템 레벨로 해결합니다.

**문제 원인:**

- Claude Code가 enhanced keyboard 모드(CSI u)를 활성화
- 한글 입력소스에서 Ctrl/Opt+알파벳 키가 다르게 처리됨
- Ghostty keybind 설정도 CSI u 모드에서 우회됨

**해결 방식:** Hammerspoon이 시스템 레벨에서 키 입력을 가로채서 영어로 전환 후 키 전달

**Ghostty 전용 (Ctrl 키):**

| 단축키   | 기능                   |
| -------- | ---------------------- |
| `Ctrl+C` | 프로세스 종료 (SIGINT) |
| `Ctrl+U` | 줄 삭제                |
| `Ctrl+K` | 커서 뒤 삭제           |
| `Ctrl+W` | 단어 삭제              |
| `Ctrl+A` | 줄 처음으로            |
| `Ctrl+E` | 줄 끝으로              |
| `Ctrl+L` | 화면 지우기            |
| `Ctrl+F` | 앞으로 이동            |

> Ghostty 외 앱에서는 원래 동작을 유지합니다 (예: VS Code에서 Ctrl+C는 복사).

**모든 터미널 앱 (Opt 키):**

| 단축키  | 기능             |
| ------- | ---------------- |
| `Opt+B` | 단어 뒤로 이동   |
| `Opt+F` | 단어 앞으로 이동 |

> 터미널 앱: Ghostty, Terminal.app, Warp, iTerm2

**전역 (모든 앱):**

| 단축키   | 기능                            |
| -------- | ------------------------------- |
| `Ctrl+B` | tmux prefix (영어 전환 후 전달) |

> **참고**: 자세한 트러블슈팅은 [TROUBLESHOOTING.md](TROUBLESHOOTING.md#한글-입력소스에서-ctrlopt-단축키가-동작하지-않음)를 참고하세요.

#### Finder → Ghostty 터미널 열기

| 단축키                    | 동작                                     |
| ------------------------- | ---------------------------------------- |
| `Ctrl + Option + Cmd + T` | 현재 Finder 경로에서 Ghostty 터미널 열기 |

**동작 방식:**

| 상황                     | 동작                                |
| ------------------------ | ----------------------------------- |
| Finder에서 실행          | 현재 폴더 경로로 Ghostty 새 창 열기 |
| Finder 바탕화면에서 실행 | Desktop 경로로 Ghostty 새 창 열기   |
| 다른 앱에서 실행         | Ghostty 새 창 열기 (기본 경로)      |
| Ghostty 미실행 시        | `open -a Ghostty`로 시작            |
| Ghostty 실행 중          | `Cmd+N`으로 새 창 + `cd` 명령어     |

**구현 특징:**

- AppleScript로 Finder 현재 경로 가져오기
- 경로에 특수문자(`[`, `]` 등)나 공백이 있어도 정상 동작 (따옴표 처리)
- Ghostty 실행 중일 때는 클립보드를 활용한 경로 전달 (한글 경로 문제 방지)
- IPC 모듈 로드로 CLI에서 `hs` 명령 사용 가능
- 설정 리로드 완료 시 macOS 알림 표시

> **참고**: 구현 과정에서 발생한 문제와 해결 방법은 [TROUBLESHOOTING.md](TROUBLESHOOTING.md#hammerspoon-관련) 참고.

---

## 폴더 액션 (launchd)

`modules/darwin/programs/folder-actions/`에서 관리됩니다.

macOS launchd의 WatchPaths를 사용하여 특정 폴더를 감시하고, 파일이 추가되면 자동으로 스크립트를 실행합니다.

| 감시 폴더                               | 기능                                  |
| --------------------------------------- | ------------------------------------- |
| `~/FolderActions/compress-rar/`         | RAR 압축 + SHA-256 체크섬 가이드 생성 |
| `~/FolderActions/compress-video/`       | H.265 (HEVC) 비디오 압축              |
| `~/FolderActions/rename-asset/`         | 타임스탬프 기반 파일명 변경           |
| `~/FolderActions/convert-video-to-gif/` | GIF 변환 (15fps, 480px)               |

### 사용 방법

1. 감시 폴더에 파일을 드래그 앤 드롭
2. 자동으로 스크립트가 실행됨
3. 결과물은 `~/Downloads/`에 저장됨

### 로그 확인

```bash
cat ~/Library/Logs/folder-actions/*.log
```

---

## Secrets 관리

민감 정보는 `home-manager-secrets`를 사용하여 age 암호화로 관리합니다.

**Secrets 및 대외비 설정은 별도의 Private 저장소**([nixos-config-secret](https://github.com/shren207/nixos-config-secret))에서 관리됩니다.

### Private 저장소 구조

```
nixos-config-secret/
├── flake.nix                 # homeManagerModules.default로 export
├── green/                    # 공통 설정 (사용자/호스트 무관)
│   ├── default.nix           # 모듈 진입점 (imports)
│   ├── secrets.nix           # pushover credentials (암호화)
│   ├── git.nix               # zfw worktree 디렉토리 패턴 (__wt__*)
│   ├── shell.nix             # 대외비 쉘 함수
│   ├── tmux.nix              # 대외비 pane-note 링크
│   └── secrets/
│       └── pushover-credentials.age
└── green-onlyhome/           # 특정 호스트 전용 (미래용)
    └── default.nix
```

### 관리 대상

| 파일          | 내용                      | 암호화  |
| ------------- | ------------------------- | ------- |
| `secrets.nix` | API 키, credentials       | O (age) |
| `git.nix`     | zfw worktree 디렉토리 패턴 (__wt__*) | X       |
| `shell.nix`   | 회사 전용 쉘 함수         | X       |
| `tmux.nix`    | 회사 관련 링크            | X       |

### 장점

- 암호화된 파일 + 대외비 설정 모두 비공개 저장소에 보관
- 새 컴퓨터 추가 시 SSH 키만 설정하면 됨
- Public 저장소에는 민감 정보 없음

> **참고**: Secrets 추가/수정 방법은 [HOW_TO_EDIT.md](HOW_TO_EDIT.md#secrets-추가)를 참고하세요.
