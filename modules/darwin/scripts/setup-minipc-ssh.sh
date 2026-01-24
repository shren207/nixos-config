#!/usr/bin/env bash
# setup-minipc-ssh.sh - Mac에서 MiniPC SSH 설정 스크립트
#
# 용도: MiniPC 설치 후 Mac에서 SSH 연결 설정
#       - ~/.ssh/config에 minipc 호스트 추가
#       - SSH 접속 테스트
#       - Atuin key 복사 (shell history 동기화용)
#
# 실행 시점: MiniPC post-install-minipc.sh 완료 후 Mac에서 실행
# 참고: 이 스크립트는 Nix 설정에서 참조되지 않음 (수동 실행용)

set -euo pipefail

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo_info "=== MiniPC SSH 설정 (Mac) ==="
echo ""

# 1. Tailscale IP 입력
echo_warn "MiniPC의 Tailscale IP를 입력하세요."
echo_info "MiniPC에서 'tailscale ip -4' 명령으로 확인 가능"
echo ""
read -p "Tailscale IP (100.x.x.x): " TAILSCALE_IP

if [[ ! "$TAILSCALE_IP" =~ ^100\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo_warn "입력한 IP가 Tailscale 형식(100.x.x.x)이 아닙니다."
    read -p "계속하시겠습니까? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 2. SSH config에 추가
echo ""
echo_info "$HOME/.ssh/config에 minipc 설정 추가 중..."

# 기존 minipc 설정 제거
if grep -q "^Host minipc$" ~/.ssh/config 2>/dev/null; then
    echo_warn "기존 minipc 설정을 제거합니다."
    sed -i.bak '/^Host minipc$/,/^Host /{ /^Host minipc$/d; /^Host /!d; }' ~/.ssh/config
fi

# 새 설정 추가
cat >> ~/.ssh/config << EOF

Host minipc
    HostName $TAILSCALE_IP
    User greenhead
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes
EOF

echo_info "SSH config 설정 완료"
echo ""

# 3. SSH 접속 테스트
echo_info "SSH 접속 테스트..."
if ssh -o ConnectTimeout=5 minipc "echo 'SSH 연결 성공!'"; then
    echo_info "SSH 접속 성공!"
else
    echo_warn "SSH 접속 실패. Tailscale과 SSH 설정을 확인하세요."
    exit 1
fi

# 4. Atuin key 복사
echo ""
echo_info "Atuin key 복사 중..."
if [[ -f ~/.local/share/atuin/key ]]; then
    ssh minipc "mkdir -p ~/.local/share/atuin"
    scp ~/.local/share/atuin/key minipc:~/.local/share/atuin/
    echo_info "Atuin key 복사 완료"
    echo ""
    echo_warn "MiniPC에서 다음 명령을 실행하세요:"
    echo "  atuin login -u greenhead"
    echo "  atuin sync"
else
    echo_warn "$HOME/.local/share/atuin/key 파일이 없습니다."
    echo_info "Atuin key 복사를 건너뜁니다."
fi

echo ""
echo_info "=== 설정 완료! ==="
echo ""
echo_info "MiniPC 접속: ssh minipc"
echo_info "tmux 세션: ssh minipc -t 'tmux new-session -A -s main'"
