# Claude Code 설정
{ config, pkgs, lib, ... }:

let
  claudeDir = ./files;
  homeDir = config.home.homeDirectory;
  jsonFormat = pkgs.formats.json { };

  # settings.json 내용 (동적 경로 포함)
  settingsContent = {
    cleanupPeriodDays = 7;
    alwaysThinkingEnabled = true;
    includeCoAuthoredBy = false;
    env = {
      CLAUDE_CODE_ENABLE_UNIFIED_READ_TOOL = "true";
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "true";
    };
    permissions = {
      deny = [
        "Bash(rm -rf /)"
        "Bash(rm -rf ~)"
        "Bash(rm -rf ~/*)"
        "Bash(rm -rf /*)"
      ];
      additionalDirectories = [ "~/Downloads" "~/Documents" "~/IdeaProjects" ];
    };
    hooks = {
      Stop = [
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "${homeDir}/.claude/hooks/stop-notification.sh";
            }
          ];
        }
      ];
    };
  };
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
    # 메인 설정 파일
    # ".claude/CLAUDE.md".source = "${claudeDir}/CLAUDE.md"; # 현재 user 스코프의 CLAUDE.md 파일은 사용하지 않음
    # settings.json은 동적 경로를 위해 pkgs.formats.json으로 생성 (pretty-printed)
    ".claude/settings.json".source = jsonFormat.generate "claude-settings.json" settingsContent;
    ".claude/mcp-config.json".source = "${claudeDir}/mcp-config.json";

    # Agents
    ".claude/agents/document-task.md".source = "${claudeDir}/agents/document-task.md";

    # Commands (slash commands)
    ".claude/commands/catchup-legacy.md".source = "${claudeDir}/commands/catchup-legacy.md";
    ".claude/commands/catchup.md".source = "${claudeDir}/commands/catchup.md";

    # Skills
    ".claude/skills/document-task" = {
      source = "${claudeDir}/skills/document-task";
      recursive = true;
    };
    ".claude/skills/skill-creator" = {
      source = "${claudeDir}/skills/skill-creator";
      recursive = true;
    };

    # Hooks (외부 스크립트로 분리)
    ".claude/hooks/stop-notification.sh" = {
      source = "${claudeDir}/hooks/stop-notification.sh";
      executable = true;
    };
  };
}
