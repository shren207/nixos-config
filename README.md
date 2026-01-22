# green/nixos-config

macOS와 NixOS 개발 환경을 **nix-darwin/NixOS + Home Manager**로 선언적으로 관리하는 프로젝트입니다.

## 목차

- [플랫폼 구성](#플랫폼-구성)
- [새 Mac 설정 가이드](#새-mac-설정-가이드)
- [MiniPC(NixOS) 설정 가이드](#minipcnixos-설정-가이드)
- [디렉토리 구조](#디렉토리-구조)
- [자주 사용하는 명령어](#자주-사용하는-명령어)
- [문서 안내](#문서-안내)

---

## 플랫폼 구성

| 호스트 | OS | 용도 | 접속 방법 |
|--------|-----|------|----------|
| MacBook Pro | macOS (nix-darwin) | 메인 개발 환경 | 로컬 |
| greenhead-minipc | NixOS | 24시간 원격 개발 서버 | `ssh minipc` |

**공유 설정** (`modules/shared/`):
- 쉘 환경 (zsh, starship, atuin, fzf, zoxide)
- 개발 도구 (git, tmux, vim, lazygit)
- Claude Code 설정

**플랫폼별 설정**:
- macOS: Homebrew GUI 앱, Hammerspoon, Cursor, 폴더 액션
- NixOS: SSH 서버, mosh, Tailscale VPN, fail2ban

---

## 새 Mac 설정 가이드

### 1. Nix 설치

```bash
curl -L https://nixos.org/nix/install | sh
```

설치 후 터미널 재시작 또는:
```bash
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### 2. 저장소 클론

```bash
mkdir -p ~/IdeaProjects
cd ~/IdeaProjects
git clone https://github.com/shren207/nixos-config.git
cd nixos-config
```

### 3. flake.nix 수정 (사용자명/호스트 설정)

`flake.nix`에서 사용자명과 호스트를 본인 환경에 맞게 수정합니다:

```bash
# 현재 사용자명 확인
whoami

# 현재 호스트명 확인
scutil --get LocalHostName
```

```nix
# flake.nix
let
  system = "aarch64-darwin";       # Apple Silicon: aarch64-darwin, Intel: x86_64-darwin
  username = "your-username";      # ← 본인 사용자명으로 변경

  # 호스트별 설정
  hosts = {
    "your-MacBookPro" = {          # ← 본인 호스트명으로 변경
      hostType = "personal";       # personal 또는 work
      nixosConfigPath = "/Users/${username}/IdeaProjects/nixos-config";
    };
    # 추가 호스트 (예: 회사 맥북)
    "work-MacBookPro" = {
      hostType = "work";
      nixosConfigPath = "/Users/${username}/IdeaProjects/nixos-config";
    };
  };
in
```

> **참고**: `nixosConfigPath`는 `mkOutOfStoreSymlink`에서 사용되는 절대 경로입니다. 프로젝트 위치를 변경하면 이 값도 수정해야 합니다.
>
> **호스트 추가**: 새 Mac을 추가하려면 `hosts` 블록에 호스트명과 설정을 추가하면 됩니다. `hostType`은 Private 저장소에서 호스트별 설정 분기에 사용됩니다.

### 4. SSH 키 복원

Secrets 복호화 및 Private 저장소 접근을 위해 SSH 키가 필요합니다:
```bash
# iCloud 또는 백업에서 SSH 키 복원
mkdir -p ~/.ssh
# id_ed25519, id_ed25519.pub 복사

# 권한 설정 (필수!)
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# GitHub에 SSH 키 등록 확인
ssh -T git@github.com
# "Hi username! You've successfully authenticated..." 출력되면 성공
```

> **참고**: 같은 SSH 키를 사용하는 모든 컴퓨터에서 동일한 secrets에 접근 가능합니다.
>
> **주의**: SSH 키 파일은 반드시 **파일 끝에 빈 줄(EOL)**이 있어야 합니다. 복사/붙여넣기 과정에서 빈 줄이 누락되면 `invalid format` 에러가 발생합니다.

### 5. Nix experimental features 활성화

Flakes와 nix-command를 사용하려면 experimental features를 활성화해야 합니다:

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### 6. nix-darwin 부트스트랩

```bash
# SSH agent에 키 추가 (Private 저장소 접근용)
ssh-add ~/.ssh/id_ed25519

# 기존 시스템 파일 백업 (충돌 방지)
sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin
sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin

# nix-darwin 부트스트랩 (sudo + SSH_AUTH_SOCK 유지)
sudo --preserve-env=SSH_AUTH_SOCK nix run nix-darwin -- switch --flake .
```

> **참고**: 첫 실행 시 10~20분 정도 소요될 수 있습니다.

### 7. 설정 적용 (이후)

부트스트랩 완료 후에는 간단한 명령어로 설정을 적용할 수 있습니다:

```bash
darwin-rebuild switch --flake .
```

---

## MiniPC(NixOS) 설정 가이드

MiniPC는 NixOS로 24시간 원격 개발 환경으로 구성되어 있습니다.

### 접속 정보

| 항목 | 값 |
|------|-----|
| Tailscale IP | 100.79.80.95 |
| hostname | greenhead-minipc |
| user | greenhead |
| SSH 접속 | `ssh minipc` |

### 원격 접속 방법

```bash
# Mac에서 SSH 접속
ssh minipc

# 모바일(Termius)에서 접속
# Host: 100.79.80.95, User: greenhead, Key: Mac SSH 키 사용

# 불안정한 네트워크에서 mosh 사용 (연결 유지)
mosh greenhead@100.79.80.95
```

### 설정 적용 (MiniPC에서)

```bash
# 일반 rebuild
nrs

# 오프라인 rebuild (빠름)
nrs-offline

# 미리보기만
nrp
```

### SSH로 원격 관리 (Mac에서)

```bash
# Private repo 접근 시 SSH_AUTH_SOCK 유지 필요
ssh minipc "sudo SSH_AUTH_SOCK=\$SSH_AUTH_SOCK nixos-rebuild switch --flake ~/nixos-config"
```

---

## 디렉토리 구조

```
nixos-config/
├── flake.nix                     # 메인 Flake 설정 (darwin + nixos)
├── flake.lock                    # 의존성 잠금
├── hosts/                        # 호스트별 설정
│   └── greenhead-minipc/         # MiniPC NixOS
│       ├── default.nix           # 호스트 진입점
│       ├── disko.nix             # 디스크 파티셔닝
│       └── hardware-configuration.nix
├── modules/
│   ├── shared/                   # 공유 설정 (macOS/Linux)
│   │   ├── configuration.nix     # Nix 기본 설정
│   │   └── programs/
│   │       ├── broot/            # broot (Modern Linux Tree)
│   │       ├── claude/           # Claude Code 설정
│   │       ├── git/              # Git 설정
│   │       ├── shell/            # Zsh/Starship/Atuin/Mise
│   │       │   ├── default.nix   # 공통 설정
│   │       │   ├── darwin.nix    # macOS 전용
│   │       │   └── nixos.nix     # NixOS 전용
│   │       ├── tmux/             # tmux 설정
│   │       └── vim/              # Vim 설정
│   ├── darwin/                   # macOS 전용
│   │   ├── configuration.nix     # 시스템 설정 (Touch ID, Dock 등)
│   │   ├── home.nix              # Home Manager 설정
│   │   └── programs/
│   │       ├── homebrew.nix      # GUI 앱 (Homebrew Casks)
│   │       ├── hammerspoon/      # 키보드 리매핑
│   │       ├── cursor/           # Cursor IDE 설정
│   │       ├── folder-actions/   # 폴더 액션 (launchd)
│   │       └── keybindings/      # 키 바인딩 (백틱/원화)
│   └── nixos/                    # NixOS 전용
│       ├── configuration.nix     # 시스템 설정
│       ├── home.nix              # Home Manager 설정
│       └── programs/
│           ├── ssh.nix           # SSH 서버
│           ├── mosh.nix          # mosh 서버
│           ├── tailscale.nix     # Tailscale VPN
│           └── fail2ban.nix      # 보안 설정
├── scripts/                      # 관리 스크립트
│   ├── nrs.sh                    # darwin-rebuild
│   ├── nrs-nixos.sh              # nixos-rebuild
│   └── ...
└── libraries/
    ├── home-manager/             # Home Manager 공유 설정
    └── nixpkgs/                  # nixpkgs overlay
```

---

## 자주 사용하는 명령어

### macOS (darwin-rebuild)

```bash
# 설정 적용 (미리보기 → 확인 → 적용)
nrs

# 오프라인 빌드 (빠름, 캐시 사용)
nrs-offline

# 미리보기만 (적용 안 함)
nrp

# 롤백
darwin-rebuild switch --rollback

# 설정 업데이트 (flake.lock 갱신)
nix flake update

# Private secrets 저장소만 업데이트
nix flake update nixos-config-secret
```

### NixOS (nixos-rebuild)

```bash
# MiniPC에서 설정 적용
nrs

# 오프라인 빌드 (빠름)
nrs-offline

# 미리보기만
nrp

# 롤백
sudo nixos-rebuild switch --rollback

# 세대 히스토리
nrh
```

### 공통

```bash
# 개발 쉘 (rage, nixfmt 사용 가능)
nix develop
```

---

## 문서 안내

문서는 Claude Code 플러그인(skills)으로 관리됩니다. Claude Code 세션에서 질문하면 관련 문서가 자동으로 로드됩니다.

### Skills 라우팅

| 주제 | Skill | 내용 |
|------|-------|------|
| NixOS/MiniPC | `managing-minipc` | 설치, rebuild, disko, 부팅 문제 |
| macOS/nix-darwin | `managing-macos` | 시스템 설정, Homebrew, 스크롤 롤백 |
| Nix 공통 | `understanding-nix` | flake, 빌드 속도, experimental features |
| Atuin | `syncing-atuin` | 히스토리 동기화, zsh 레이아웃 |
| Claude Code | `configuring-claude-code` | 플러그인, 훅 설정 |
| Hammerspoon | `automating-hammerspoon` | 단축키, launchd, Ghostty |
| 컨테이너 | `running-containers` | Podman, immich |
| Git | `configuring-git` | delta, rerere 설정 |
| mise | `managing-mise` | 런타임 버전, .nvmrc |
| tmux | `managing-tmux` | 단축키, pane notepad |
| SSH | `managing-ssh` | 키 관리, Tailscale |
| Cursor | `managing-cursor` | 확장 관리 |

> **참고**: 플러그인은 `nixos-config-secret` 저장소에서 관리됩니다.
