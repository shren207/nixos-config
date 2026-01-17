{
  description = "green/nixos-config - macOS Development Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 민감 정보 관리 (home-manager-secrets)
    home-manager-secrets = {
      url = "github:shren207/home-manager-secrets";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Private secrets 저장소
    nixos-config-secret = {
      url = "git+ssh://git@github.com/shren207/nixos-config-secret?ref=main&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager-secrets.follows = "home-manager-secrets";
    };

    # VSCode/Cursor 확장 프로그램 관리
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      ...
    }@inputs:
    let
      system = "aarch64-darwin";
      username = "{유저네임}"; # 확인: whoami

      # 공유 라이브러리
      home-manager-shared = ./libraries/home-manager;
      nixpkgs-shared = ./libraries/nixpkgs;

      # 호스트별 설정 (확인: scutil --get LocalHostName)
      hosts = {
        "yunnogduui-MacBookPro" = {
          hostType = "personal";
          nixosConfigPath = "/Users/${username}/IdeaProjects/nixos-config";
        };
        "work-MacBookPro" = {
          hostType = "work";
          nixosConfigPath = "/Users/${username}/IdeaProjects/nixos-config";
        };
      };

      # darwinConfiguration 생성 함수
      mkDarwinConfig =
        hostname: hostConfig:
        nix-darwin.lib.darwinSystem {
          inherit system;
          modules = [
            home-manager-shared
            nixpkgs-shared
            home-manager.darwinModules.home-manager
            ./modules/shared/configuration.nix
            ./modules/darwin/configuration.nix
            ./modules/darwin/home.nix
          ];
          specialArgs = {
            inherit inputs username hostname;
            inherit (hostConfig) hostType nixosConfigPath;
          };
        };

    in
    {
      darwinConfigurations = builtins.mapAttrs mkDarwinConfig hosts;

      # 개발 쉘
      devShells.${system}.default =
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.mkShell {
          buildInputs = with pkgs; [
            nixfmt
            rage
            lefthook
            gitleaks
            shellcheck
          ];
          shellHook = ''
            lefthook install 2>/dev/null || true
          '';
        };
    };
}
