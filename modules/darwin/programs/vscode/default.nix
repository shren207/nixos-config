# VSCode 설정
# Nix로 확장 관리, settings/keybindings는 mkOutOfStoreSymlink (양방향)
{
  config,
  pkgs,
  lib,
  nixosConfigPath,
  ...
}:

let
  vscodeFilesPath = "${nixosConfigPath}/modules/darwin/programs/vscode/files";

  # VSCode bundle identifier (macOS 앱 식별자)
  vscodeBundleId = "com.microsoft.VSCode";

  # VSCode로 열 파일 확장자 목록
  codeExtensions = [
    "txt"
    "text"
    "md"
    "mdx"
    "js"
    "jsx"
    "ts"
    "tsx"
    "mjs"
    "cjs"
    "json"
    "yaml"
    "yml"
    "toml"
    "css"
    "scss"
    "sass"
    "less"
    "nix"
    "sh"
    "bash"
    "zsh"
    "py"
    "rb"
    "go"
    "rs"
    "lua"
    "sql"
    "graphql"
    "gql"
    "xml"
    "svg"
    "conf"
    "ini"
    "cfg"
    "env"
    "gitignore"
    "editorconfig"
    "prettierrc"
    "eslintrc"
  ];

  logSnippet = {
    "Print to console" = {
      prefix = "log";
      body = [
        "console.log('$1');"
        "$2"
      ];
      description = "Log output to console";
    };
  };
in
{
  home.packages = [
    pkgs.duti # macOS 파일 연결 CLI 도구
    pkgs.nixd # Nix LSP (nix-ide 확장 의존성)
    pkgs.nixfmt-rfc-style # Nix 포매터 (nixd formatting 의존성)
  ];

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    mutableExtensionsDir = false;

    profiles.default = {
      extensions =
        # open-vsx (오픈소스 마켓플레이스): https://open-vsx.org/
        (with pkgs.open-vsx; [
          # 개발 도구
          dbaeumer.vscode-eslint
          esbenp.prettier-vscode
          usernamehw.errorlens
          streetsidesoftware.code-spell-checker
          aaron-bond.better-comments

          # Git
          eamodio.gitlens
          github.vscode-pull-request-github

          # 언어
          jnoortheen.nix-ide

          # 유틸리티
          buenon.scratchpads
          kisstkondoros.vscode-gutter-preview

          # 테마/UI
          k--kato.intellij-idea-keybindings

          # Terraform
          hashicorp.terraform

          # Claude Code
          anthropic.claude-code
        ])

        # vscode-marketplace (open-vsx에 없는 확장): https://marketplace.visualstudio.com/vscode
        ++ (with pkgs.vscode-marketplace; [
          fuzionix.code-case-converter
          wix.vscode-import-cost
          imekachi.webstorm-darcula
          atommaterial.a-file-icon-vscode
        ]);

      # 스니펫 (HM이 자동으로 snippets/ 디렉토리에 배치)
      languageSnippets = {
        javascript = logSnippet;
        javascriptreact = logSnippet;
        typescript = logSnippet;
        typescriptreact = logSnippet;
      };

      # userSettings, keybindings는 설정하지 않음
      # → HM 모듈이 Nix store 기반 읽기전용 파일을 생성하여
      #   mkOutOfStoreSymlink과 충돌하기 때문
    };
  };

  # settings.json / keybindings.json — 양방향 수정 가능
  home.file = {
    "Library/Application Support/Code/User/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${vscodeFilesPath}/settings.json";
    "Library/Application Support/Code/User/keybindings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${vscodeFilesPath}/keybindings.json";
  };

  # VSCode를 기본 에디터로 설정 (duti)
  home.activation.setVSCodeAsDefaultEditor = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Setting VSCode as default editor for code files..."

    ${lib.concatMapStringsSep "\n" (
      ext: "${pkgs.duti}/bin/duti -s ${vscodeBundleId} .${ext} all"
    ) codeExtensions}

    # UTI 설정 (public.data 제거 — 범위가 너무 넓음)
    ${pkgs.duti}/bin/duti -s ${vscodeBundleId} public.plain-text all
    ${pkgs.duti}/bin/duti -s ${vscodeBundleId} public.source-code all

    echo "VSCode default settings applied successfully."
  '';
}
