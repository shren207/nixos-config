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
