# 주요 기능

이 프로젝트가 제공하는 기능들을 소개합니다.

## 목차

- [CLI 도구](#cli-도구)
  - [파일/검색 도구](#파일검색-도구)
  - [개발 도구](#개발-도구)
  - [쉘 도구](#쉘-도구)
  - [미디어 처리](#미디어-처리)
  - [유틸리티](#유틸리티)
- [macOS 시스템 설정](#macos-시스템-설정)
- [GUI 앱 (Homebrew Casks)](#gui-앱-homebrew-casks)
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
| `git` | 버전 관리 |
| `delta` | Git diff 시각화 (구문 강조, side-by-side) |
| `tmux` | 터미널 멀티플렉서 |
| `lazygit` | Git TUI |
| `gh` | GitHub CLI |
| `jq` | JSON 처리 |

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

---

## GUI 앱 (Homebrew Casks)

`modules/darwin/programs/homebrew.nix`에서 관리됩니다.

| 앱 | 용도 |
|----|------|
| Cursor | AI 코드 에디터 |
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
