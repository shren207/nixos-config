# green/nixos-config

macOS 개발 환경을 **nix-darwin + Home Manager**로 선언적으로 관리하는 프로젝트입니다.

## 목차

- [새 Mac 설정 가이드](#새-mac-설정-가이드)
- [디렉토리 구조](#디렉토리-구조)
- [자주 사용하는 명령어](#자주-사용하는-명령어)
- [문서 안내](#문서-안내)

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

## 디렉토리 구조

```
nixos-config/
├── flake.nix                     # 메인 Flake 설정
├── flake.lock                    # 의존성 잠금
├── modules/
│   ├── shared/                   # 공유 설정 (macOS/Linux)
│   │   ├── configuration.nix     # Nix 기본 설정
│   │   └── programs/
│   │       ├── broot/            # broot (Modern Linux Tree)
│   │       ├── git/              # Git 설정
│   │       ├── shell/            # Zsh/Starship/Atuin/Mise
│   │       ├── tmux/             # tmux 설정
│   │       └── vim/              # Vim 설정
│   └── darwin/                   # macOS 전용
│       ├── configuration.nix     # 시스템 설정 (Touch ID, Dock 등)
│       ├── home.nix              # Home Manager 설정
│       └── programs/
│           ├── homebrew.nix      # GUI 앱 (Homebrew Casks)
│           ├── hammerspoon/      # 키보드 리매핑
│           ├── claude/           # Claude Code 설정
│           ├── cursor/           # Cursor IDE 설정
│           └── folder-actions/   # 폴더 액션 (launchd)
└── libraries/
    ├── home-manager/             # Home Manager 공유 설정
    └── nixpkgs/                  # nixpkgs overlay
```

---

## 자주 사용하는 명령어

```bash
# 설정 적용
darwin-rebuild switch --flake .

# 롤백
darwin-rebuild switch --rollback

# 설정 업데이트 (flake.lock 갱신)
nix flake update

# Private secrets 저장소만 업데이트
nix flake update nixos-config-secret

# 개발 쉘 (rage, nixfmt 사용 가능)
nix develop
```

---

## 문서 안내

| 문서 | 설명 |
|------|------|
| [FEATURES.md](docs/FEATURES.md) | CLI 도구, GUI 앱, 폴더 액션, Secrets 등 주요 기능 |
| [HOW_TO_EDIT.md](docs/HOW_TO_EDIT.md) | 패키지, 쉘, Git, macOS 설정 수정 방법 |
| [CURSOR_EXTENSIONS.md](docs/CURSOR_EXTENSIONS.md) | Cursor 확장 프로그램 선언적 관리 |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | 자주 발생하는 문제 해결 |
