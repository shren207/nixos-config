# 주요 기능

이 프로젝트가 제공하는 기능들을 소개합니다.

## 목차

- [CLI 도구](#cli-도구)
  - [파일/검색 도구](#파일검색-도구)
  - [개발 도구](#개발-도구)
    - [Git 설정](#git-설정)
  - [쉘 도구](#쉘-도구)
  - [미디어 처리](#미디어-처리)
  - [유틸리티](#유틸리티)
- [macOS 시스템 설정](#macos-시스템-설정)
  - [키 바인딩 (백틱/원화)](#키-바인딩-백틱원화)
  - [폰트 관리 (Nerd Fonts)](#폰트-관리-nerd-fonts)
- [GUI 앱 (Homebrew Casks)](#gui-앱-homebrew-casks)
  - [Cursor 기본 앱 설정](#cursor-기본-앱-설정)
  - [Hammerspoon 단축키](#hammerspoon-단축키)
- [폴더 액션 (launchd)](#폴더-액션-launchd)
- [Secrets 관리](#secrets-관리)

---

## CLI 도구

### 파일/검색 도구

| 도구 | 대체 | 설명 |
|------|------|------|
| `bat` | cat | 구문 강조 |
| `broot` | tree | 인터랙티브 트리 탐색기 (퍼지 검색, Git 통합) |
| `eza` | ls | 아이콘, Git 상태 표시 |
| `fd` | find | 빠른 파일 검색 |
| `fzf` | - | 퍼지 파인더 |
| `ripgrep` | grep | 빠른 텍스트 검색 |
| `zoxide` | cd | 스마트 디렉토리 점프 |

#### broot (Modern Linux Tree)

기존 `tree`와 다른 철학의 인터랙티브 파일 탐색기입니다.

| 특성 | tree | broot |
|------|------|-------|
| 출력 방식 | 정적 출력 (전체 덤프) | 동적/인터랙티브 |
| 대규모 디렉토리 | 수십~수백 페이지 | 화면에 맞게 요약 |
| 검색 | 불가 | 실시간 퍼지 검색, 정규식 |
| 파일 작업 | 불가 | 복사, 이동, 삭제, 생성 |
| Git 통합 | 없음 | :gf, :gs 명령으로 상태 확인 |
| 미리보기 | 없음 | Ctrl+→로 파일 미리보기 |
| 디스크 분석 | 없음 | -w 옵션으로 용량 시각화 |

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

| 도구 | 설명 |
|------|------|
| `git` | 버전 관리 ([상세 설정](#git-설정)) |
| `delta` | Git diff 시각화 (구문 강조, side-by-side) |
| `tmux` | 터미널 멀티플렉서 |
| `lazygit` | Git TUI |
| `gh` | GitHub CLI |
| `jq` | JSON 처리 |

#### Git 설정

`modules/shared/programs/git/default.nix`에서 관리됩니다.

**Interactive Rebase 역순 표시**

`git rebase -i` 실행 시 Fork GUI처럼 **최신 커밋이 위**, 오래된 커밋이 아래에 표시됩니다.

| CLI (기본) | CLI (적용 후) | Fork GUI |
|------------|---------------|----------|
| 오래된 → 최신 (위→아래) | 최신 → 오래된 (위→아래) | 최신 → 오래된 (위→아래) |

**구현 방식:**

- `sequence.editor`에 커스텀 스크립트 설정
- 편집 전: 커밋 라인을 역순 정렬하여 표시
- 편집 후: 원래 순서로 복원 (rebase 동작 정상 유지)
- `pkgs.writeShellScript`로 Nix store에서 스크립트 관리

**주의사항:**

- squash/fixup은 **아래쪽 커밋**이 **위쪽 커밋**으로 합쳐집니다 (Fork GUI와 동일)
- `git rebase --edit-todo`에서도 역순 표시가 적용됩니다

### 쉘 도구

| 도구 | 설명 |
|------|------|
| `starship` | 프롬프트 커스터마이징 |
| `atuin` | 쉘 히스토리 관리/동기화 |
| `mise` | 런타임 버전 관리 (Node.js, Ruby, Python 등) |

### 미디어 처리

폴더 액션에서 사용됩니다.

| 도구 | 설명 |
|------|------|
| `ffmpeg` | 비디오/오디오 변환 |
| `imagemagick` | 이미지 처리 |
| `rar` | RAR 압축 |

### 유틸리티

- `curl` - HTTP 클라이언트
- `unzip` - 압축 해제
- `htop` - 프로세스 모니터링

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

### Finder

- 숨김 파일 표시
- 모든 확장자 표시

### 키보드

- **KeyRepeat = 1**: 최고 속도 키 반복
- **InitialKeyRepeat = 15**: 빠른 초기 반복
- 자연스러운 스크롤 비활성화

### 자동 수정 비활성화

- 자동 대문자화
- 맞춤법 자동 수정
- 마침표 자동 삽입
- 따옴표 자동 변환
- 대시 자동 변환

### 키 바인딩 (백틱/원화)

`modules/darwin/programs/keybindings/`에서 관리됩니다.

한국어 키보드에서 백틱(`) 키 입력 시 원화(₩)가 입력되는 문제를 해결합니다. macOS Cocoa Text System의 `DefaultKeyBinding.dict`를 사용합니다.

| 입력 | 출력 | 설명 |
|------|------|------|
| `₩` 키 | `` ` `` | 백틱 입력 (기본 동작 변경) |
| `Option + 4` | `₩` | 원화 기호 입력 (필요시) |

**설정 파일 위치:** `~/Library/KeyBindings/DefaultKeyBinding.dict`

**참고:**
- 적용 후 앱 재시작 필요 (일부 앱은 로그아웃/재로그인 필요)
- 참고 자료: [ttscoff/KeyBindings](https://github.com/ttscoff/KeyBindings)

### 폰트 관리 (Nerd Fonts)

`modules/darwin/configuration.nix`에서 관리됩니다.

nix-darwin의 `fonts.packages` 옵션을 사용하여 Nerd Fonts를 선언적으로 관리합니다. 폰트는 `/Library/Fonts/Nix Fonts/`에 자동 설치됩니다.

**현재 설치된 폰트:**

| 폰트 | 패키지명 | 용도 |
|------|---------|------|
| FiraCode Nerd Font | `nerd-fonts.fira-code` | 터미널/에디터용 프로그래밍 폰트 |
| JetBrains Mono Nerd Font | `nerd-fonts.jetbrains-mono` | 터미널/에디터용 프로그래밍 폰트 |

**Nerd Fonts vs 일반 폰트:**

| 항목 | 일반 프로그래밍 폰트 | Nerd Font 버전 |
|------|---------------------|----------------|
| 기본 문자 | ✓ | ✓ |
| 리가처 (ligatures) | 폰트에 따라 다름 | 원본 폰트와 동일 |
| 아이콘 글리프 | ✗ | ✓ (Devicons, Font Awesome, Powerline 등 9,000+개) |
| 용도 | 일반 코딩 | 터미널/에디터에서 아이콘 표시 필요 시 |

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

## GUI 앱 (Homebrew Casks)

`modules/darwin/programs/homebrew.nix`에서 관리됩니다.

| 앱 | 용도 |
|----|------|
| Cursor | AI 코드 에디터 ([상세 설정](#cursor-기본-앱-설정)) |
| Ghostty | 터미널 |
| Raycast | 런처 (Spotlight 대체) |
| Rectangle | 창 관리 |
| Hammerspoon | 키보드 리매핑/자동화 |
| Homerow | 키보드 네비게이션 |
| Docker | 컨테이너 |
| Fork | Git GUI |
| Slack | 메신저 |
| Figma | 디자인 |
| MonitorControl | 외부 모니터 밝기 조절 |

### Cursor 기본 앱 설정

`modules/darwin/programs/cursor/default.nix`에서 관리됩니다.

텍스트/코드 파일을 더블클릭 시 Xcode 대신 Cursor로 열리도록 `duti`를 사용하여 파일 연결을 설정합니다.

**설정 대상 확장자:**

```
txt, text, md, mdx, js, jsx, ts, tsx, mjs, cjs,
json, yaml, yml, toml, css, scss, sass, less, nix,
sh, bash, zsh, py, rb, go, rs, lua, sql, graphql, gql,
xml, svg, conf, ini, cfg, env, gitignore, editorconfig, prettierrc, eslintrc
```

**설정 대상 UTI:**

| UTI | 설명 |
|-----|------|
| `public.plain-text` | 일반 텍스트 파일 |
| `public.source-code` | 소스 코드 파일 |
| `public.data` | 범용 데이터 파일 |

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

#### Finder → Ghostty 터미널 열기

| 단축키 | 동작 |
|--------|------|
| `Ctrl + Option + Cmd + T` | 현재 Finder 경로에서 Ghostty 터미널 열기 |

**동작 방식:**

| 상황 | 동작 |
|------|------|
| Finder에서 실행 | 현재 폴더 경로로 Ghostty 새 창 열기 |
| Finder 바탕화면에서 실행 | Desktop 경로로 Ghostty 새 창 열기 |
| 다른 앱에서 실행 | Ghostty 새 창 열기 (기본 경로) |
| Ghostty 미실행 시 | `open -a Ghostty`로 시작 |
| Ghostty 실행 중 | `Cmd+N`으로 새 창 + `cd` 명령어 |

**구현 특징:**

- AppleScript로 Finder 현재 경로 가져오기
- 경로에 특수문자(`[`, `]` 등)나 공백이 있어도 정상 동작 (따옴표 처리)
- Ghostty 실행 중일 때는 키 입력 시뮬레이션으로 새 창 열기

> **참고**: 구현 과정에서 발생한 문제와 해결 방법은 [TROUBLESHOOTING.md](TROUBLESHOOTING.md#hammerspoon-관련) 참고.

---

## 폴더 액션 (launchd)

`modules/darwin/programs/folder-actions/`에서 관리됩니다.

macOS launchd의 WatchPaths를 사용하여 특정 폴더를 감시하고, 파일이 추가되면 자동으로 스크립트를 실행합니다.

| 감시 폴더 | 기능 |
|----------|------|
| `~/FolderActions/compress-rar/` | RAR 압축 + SHA-256 체크섬 가이드 생성 |
| `~/FolderActions/compress-video/` | H.265 (HEVC) 비디오 압축 |
| `~/FolderActions/rename-asset/` | 타임스탬프 기반 파일명 변경 |
| `~/FolderActions/convert-video-to-gif/` | GIF 변환 (15fps, 480px) |

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
│   ├── git.nix               # 대외비 gitignore 패턴
│   ├── shell.nix             # 대외비 쉘 함수
│   ├── tmux.nix              # 대외비 pane-note 링크
│   └── secrets/
│       └── pushover-credentials.age
└── green-onlyhome/           # 특정 호스트 전용 (미래용)
    └── default.nix
```

### 관리 대상

| 파일 | 내용 | 암호화 |
|------|------|--------|
| `secrets.nix` | API 키, credentials | O (age) |
| `git.nix` | 회사 프로젝트 브랜치 패턴 | X |
| `shell.nix` | 회사 전용 쉘 함수 | X |
| `tmux.nix` | 회사 관련 링크 | X |

### 장점

- 암호화된 파일 + 대외비 설정 모두 비공개 저장소에 보관
- 새 컴퓨터 추가 시 SSH 키만 설정하면 됨
- Public 저장소에는 민감 정보 없음

> **참고**: Secrets 추가/수정 방법은 [HOW_TO_EDIT.md](HOW_TO_EDIT.md#secrets-추가)를 참고하세요.
