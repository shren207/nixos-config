# green/nixos-config

macOS와 NixOS 개발 환경을 **nix-darwin/NixOS + Home Manager**로 선언적으로 관리하는 프로젝트입니다.

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

## Getting Started

### 새 Mac 설정

```bash
# 1. Nix 설치
curl -L https://nixos.org/nix/install | sh
# 설치 후 터미널 재시작

# 2. 저장소 클론
mkdir -p ~/IdeaProjects && cd ~/IdeaProjects
git clone https://github.com/shren207/nixos-config.git
cd nixos-config

# 3. SSH 키 복원 (~/.ssh/id_ed25519)
# 상세: .claude/skills/managing-ssh/ 참고

# 4. flake.nix에서 username/hostname 수정
# username: whoami 출력값
# hostname: scutil --get LocalHostName 출력값

# 5. nix-darwin 부트스트랩
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin
sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin
ssh-add ~/.ssh/id_ed25519
sudo --preserve-env=SSH_AUTH_SOCK nix run nix-darwin -- switch --flake .

# 6. 이후 설정 적용
nrs
```

### MiniPC 접속

```bash
ssh minipc              # Tailscale VPN 연결 시
ssh greenhead@100.79.80.95  # 직접 IP
```

설치/복구 가이드: `.claude/skills/managing-minipc/` 참고

---

## 문서

상세 문서는 `.claude/skills/` 폴더에서 관리됩니다.
Claude Code 세션에서 질문하면 관련 스킬이 자동으로 로드됩니다.

| 주제 | 스킬 |
|------|------|
| macOS 설정 | `managing-macos` |
| NixOS/MiniPC | `managing-minipc` |
| Nix/flake | `understanding-nix` |
| SSH/Tailscale | `managing-ssh` |

전체 스킬 목록은 `CLAUDE.md`를 참고하세요.
