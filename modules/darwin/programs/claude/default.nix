# Claude Code 설정
# Homebrew로 앱 설치, Nix로 설정 관리
{ config, pkgs, lib, nixosConfigPath, ... }:

let
  claudeDir = ./files;
  # mkOutOfStoreSymlink용 절대 경로 (양방향 수정 가능)
  claudeFilesPath = "${nixosConfigPath}/modules/darwin/programs/claude/files";
in
{
  # Binary Claude Code 설치 (Node.js 버전 의존성 없음)
  home.activation.installClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.local/bin/claude" ]; then
      echo "Installing Claude Code binary..."
      ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh | ${pkgs.bash}/bin/bash
    else
      echo "Claude Code already installed at $HOME/.local/bin/claude"
    fi
  '';

  # 공식 마켓플레이스 초기화 (SSH로 GitHub 클론)
  home.activation.initClaudeMarketplace = lib.hm.dag.entryAfter [ "installClaudeCode" ] ''
    MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/claude-plugins-official"
    MARKETPLACE_REPO="anthropics/claude-plugins-official"
    CLAUDE_BIN="$HOME/.local/bin/claude"

    # Git 저장소 유효성 검사 (git status보다 가벼운 rev-parse 사용)
    is_valid_git_repo() {
      ${pkgs.git}/bin/git -C "$1" rev-parse --git-dir >/dev/null 2>&1
    }

    if [ -d "$MARKETPLACE_DIR" ]; then
      if is_valid_git_repo "$MARKETPLACE_DIR"; then
        echo "Claude 공식 마켓플레이스가 이미 설정되어 있습니다: $MARKETPLACE_DIR"
      else
        echo "Claude 공식 마켓플레이스가 손상되었습니다. 재초기화 중..."
        run rm -rf "$MARKETPLACE_DIR"
        if run "$CLAUDE_BIN" plugin marketplace add "$MARKETPLACE_REPO" 2>/dev/null; then
          echo "Claude 공식 마켓플레이스 재초기화 완료"
        else
          echo "경고: Claude 공식 마켓플레이스 재초기화 실패"
          echo "수동 설치: claude plugin marketplace add $MARKETPLACE_REPO"
        fi
      fi
    else
      echo "Claude 공식 마켓플레이스 설치 중..."
      run mkdir -p "$HOME/.claude/plugins/marketplaces"

      if run "$CLAUDE_BIN" plugin marketplace add "$MARKETPLACE_REPO" 2>/dev/null; then
        echo "Claude 공식 마켓플레이스 설치 완료"
      else
        echo "경고: Claude 공식 마켓플레이스 설치 실패"
        echo "원인: non-interactive 환경에서 SSH agent가 실행되지 않음"
        echo ""
        echo "터미널에서 수동으로 실행하세요:"
        echo "  claude plugin marketplace add $MARKETPLACE_REPO"
      fi
    fi
  '';

  # ~/.claude/ 디렉토리 관리 (선택적 파일만)
  home.file = {
    # 메인 설정 파일 - 양방향 수정 가능 (nixos-config 직접 참조)
    # Claude Code에서 플러그인 설치/설정 변경 시 nixos-config에 바로 반영됨
    ".claude/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${claudeFilesPath}/settings.json";

    # MCP 설정 - 양방향 수정 가능
    ".claude/mcp-config.json".source =
      config.lib.file.mkOutOfStoreSymlink "${claudeFilesPath}/mcp-config.json";

    # Agents
    ".claude/agents/document-task.md".source = "${claudeDir}/agents/document-task.md";

    # Commands (slash commands)
    # ".claude/commands/catchup-legacy.md".source = "${claudeDir}/commands/catchup-legacy.md";
    ".claude/commands/catchup.md".source = "${claudeDir}/commands/catchup.md";

    # Skills
    ".claude/skills/document-task" = {
      source = "${claudeDir}/skills/document-task";
      recursive = true;
    };

    # Hooks (외부 스크립트로 분리)
    ".claude/hooks/stop-notification.sh" = {
      source = "${claudeDir}/hooks/stop-notification.sh";
      executable = true;
    };
  };
}
