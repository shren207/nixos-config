# MiniPC 24시간 클라우드 PC 구성 계획 (v3)

## 목표

MiniPC(현재 OMV)를 NixOS로 전환하여 24시간 원격 개발 환경으로 구성,
iPhone에서 언제 어디서나 Claude Code 작업 가능하게 만들기

---

## 현재 진행 상태

### 완료됨

- [x] v1 계획 검토 및 피드백
- [x] v2 계획 검토 및 피드백
- [x] v3 계획 작성 (`docs/MINIPC_PLAN_V3.md`)
- [x] MiniPC SSH 접속하여 현재 환경 파악
- [x] v3 계획에 환경 스냅샷 및 HDD 보존 경고 추가
- [x] Phase 1.1: flake.nix 확장 (disko input, nixosConfigurations)
- [x] Phase 1.2: shell 모듈 분리 (공통 + darwin.nix + nixos.nix)
- [x] Phase 1.3: darwin/home.nix 수정
- [x] Phase 1.4: modules/nixos/ 생성
- [x] Phase 1.5: hosts/greenhead-minipc/ 생성
- [x] Phase 1.6: Claude 모듈 이동 (darwin → shared)
- [x] Phase 1.7: NixOS용 스크립트 작성
- [x] darwin-rebuild switch 검증 완료

### 다음 단계

- [x] 기존 darwin/programs/claude 디렉토리 삭제
- [x] GitHub push (commit: fec008f)
- [ ] Phase 2: NixOS 설치 (MiniPC에서)
- [ ] Phase 2.5: hardware-configuration.nix 실제 내용으로 교체 후 커밋

---

## 수집된 요구사항

| 항목 | 내용 |
|------|------|
| 현재 OS | OMV (Debian 12) → NixOS로 전환 |
| 아키텍처 | x86_64-linux |
| 호스트명 | greenhead-minipc |
| 사용자명 | greenhead |
| 모바일 기기 | iPhone |
| SSH 클라이언트 | Termius Premium + Blink Shell 비교 검토 |
| VPN | Tailscale (NixOS 모듈로 설치) |
| 터미널 멀티플렉서 | tmux (기존 모듈 재사용) |
| 개발 환경 | Nix/Home Manager (Mac과 유사, modules/shared/ 재사용) |
| 주요 작업 | Claude Code + 프론트엔드 개발 서버 |
| 기술 스택 | JavaScript/TypeScript, Node.js |
| 보안 | Tailscale + 선택적 2FA + fail2ban |

### 스토리지 구성

| 장치 | 용량 | NixOS 설치 시 처리 |
|------|------|-------------------|
| NVMe (HighRel 512GB) | 476.9GB | 포맷 및 NixOS 설치 (swap 포함) |
| HDD (Seagate 2TB) | 1.8TB | 기존 데이터 유지 (295GB media 보존) |

---

## 현재 MiniPC 환경 스냅샷 (2026-01-17 확인)

### 시스템 정보

| 항목 | 현재 값 | NixOS 전환 후 |
|------|---------|--------------|
| OS | Debian 12 (bookworm) - OMV 기반 | NixOS 24.11 |
| Kernel | 6.12.57+deb12-amd64 | NixOS 커널 |
| hostname | `omv` | `greenhead-minipc` |
| 사용자 | greenhead (uid=1000) | 유지 |
| RAM | 16GB | - |
| Swap | 976MB | 8GB |
| LAN IP | 192.168.0.29/24 | 유지 (DHCP) |
| 네트워크 인터페이스 | enp2s0 | 자동 감지 |
| Tailscale | 미설치 | 설치 |
| Docker | 미설치 | 선택적 |
| SMB | 실행 중 | 선택적 |

### 현재 SSH 접속 정보

```bash
ssh greenhead@192.168.0.29
# 비밀번호: [REDACTED]
```

### 현재 디스크 레이아웃

```
NVMe (476.9GB) - /dev/nvme0n1
├── nvme0n1p1: 512MB  vfat  /boot/efi  UUID=058D-817E
├── nvme0n1p2: 475.5GB ext4 /          UUID=dec55aa9-c20e-4cd1-a763-973f102b9aa7
└── nvme0n1p3: 976MB  swap [SWAP]      UUID=e8eb6b11-7327-4e66-8da9-f365878f5ecc

HDD (1.8TB) - /dev/sda
└── sda1: 1.8TB ext4 (295GB/1.8TB 사용, 17%)
    UUID: 3f1111d9-1641-4d5e-9e40-af54f4ce7870
    현재 마운트: /srv/dev-disk-by-uuid-3f1111d9-1641-4d5e-9e40-af54f4ce7870
    NixOS 마운트: /mnt/data
```

### HDD 보존 데이터 (중요!)

```
/srv/dev-disk-by-uuid-3f1111d9-1641-4d5e-9e40-af54f4ce7870/
└── homeserver-data/
    ├── backup/    (4KB)
    ├── docker/    (4KB)
    └── media/     (295GB) ⚠️ 반드시 보존!
        ├── Ebooks/
        └── NSFW/
```

---

## 프로젝트 구조 변경

### 현재 구조 (darwin 전용)

```
nixos-config/
├── flake.nix                    # aarch64-darwin 하드코딩
├── modules/
│   ├── shared/                  # ⚠️ 일부 macOS 전용 코드 포함
│   │   └── programs/
│   │       ├── shell/           # zsh, starship, atuin, zoxide, fzf
│   │       ├── tmux/            # tmux 설정
│   │       ├── git/             # git, delta
│   │       └── vim/             # vim
│   └── darwin/                  # macOS 전용
│       ├── configuration.nix
│       ├── home.nix
│       └── programs/
│           ├── hammerspoon/
│           ├── cursor/
│           ├── claude/
│           └── homebrew.nix
├── libraries/
│   ├── home-manager/
│   └── nixpkgs/
├── scripts/
│   ├── nrs.sh                   # darwin-rebuild 전용
│   ├── nrp.sh
│   └── nrh.sh
└── (hosts/ 디렉토리 없음)
```

### 변경 후 구조

```
nixos-config/
├── flake.nix                              # 다중 플랫폼 지원 (darwin + nixos)
├── modules/
│   ├── shared/                            # 공통 (리팩토링됨)
│   │   └── programs/
│   │       ├── shell/
│   │       │   ├── default.nix            # 공통 설정
│   │       │   ├── darwin.nix             # 🆕 macOS 전용
│   │       │   └── nixos.nix              # 🆕 Linux 전용
│   │       ├── tmux/                      # 그대로 (이미 호환)
│   │       ├── git/                       # 그대로 (이미 호환)
│   │       ├── vim/                       # 그대로 (이미 호환)
│   │       ├── broot/                     # 그대로 (이미 호환)
│   │       └── claude/                    # 🆕 darwin에서 이동
│   │           ├── default.nix            # 공통 설정
│   │           └── files/                 # 설정 파일들
│   ├── darwin/                            # macOS 전용 (기존 유지)
│   │   ├── configuration.nix
│   │   ├── home.nix
│   │   └── programs/
│   │       ├── hammerspoon/
│   │       ├── cursor/
│   │       ├── atuin/                     # macOS 전용 watchdog
│   │       └── homebrew.nix
│   └── nixos/                             # 🆕 Linux 전용
│       ├── configuration.nix              # NixOS 시스템 설정
│       ├── home.nix                       # Home Manager 설정
│       └── programs/
│           ├── tailscale.nix
│           ├── ssh.nix
│           ├── mosh.nix
│           └── fail2ban.nix
├── hosts/                                 # 🆕 호스트별 설정
│   └── greenhead-minipc/
│       ├── default.nix                    # 호스트 진입점
│       ├── hardware-configuration.nix     # 하드웨어 설정 (자동 생성)
│       └── disko.nix                      # 디스크 파티셔닝
├── scripts/
│   ├── nrs.sh                             # 수정: 플랫폼 감지
│   ├── nrp.sh                             # 수정: 플랫폼 감지
│   ├── nrh.sh                             # 수정: 플랫폼 감지
│   └── nixos-install-minipc.sh            # 🆕 설치 스크립트
└── docs/
    └── MINIPC_PLAN_V3.md                  # 이 문서
```

---

## 구현 순서 (중요!)

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. nixos-config 수정 (Mac에서 작업) → GitHub push                   │
│    - flake.nix 확장                                                 │
│    - shell 모듈 분리                                                │
│    - modules/nixos/ 생성                                            │
│    - hosts/greenhead-minipc/ 생성                                   │
├─────────────────────────────────────────────────────────────────────┤
│ 2. NixOS ISO 부팅 (MiniPC에서)                                      │
│    - disko로 NVMe 파티셔닝                                          │
│    - nixos-install --flake github:shren207/nixos-config#...         │
├─────────────────────────────────────────────────────────────────────┤
│ 3. 재부팅 후 초기 설정                                              │
│    - Tailscale 인증                                                 │
│    - SSH 키 복사                                                    │
│    - Atuin key 복사                                                 │
├─────────────────────────────────────────────────────────────────────┤
│ 4. 모바일 UX 설정 (iPhone)                                          │
│    - Termius/Blink 설정                                             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: nixos-config 수정 (Mac에서 작업)

### 1.1 flake.nix 확장

**파일**: `flake.nix` (수정)

```nix
{
  description = "Nix configuration for macOS and NixOS";

  inputs = {
    # 기존 inputs 유지
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-secrets = {
      url = "github:shren207/home-manager-secrets";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-config-secret = {
      url = "git+ssh://git@github.com/shren207/nixos-config-secret?ref=main&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager-secrets.follows = "home-manager-secrets";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 🆕 disko 추가
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      disko,
      ...
    }@inputs:
    let
      # 공유 라이브러리
      home-manager-shared = ./libraries/home-manager;
      nixpkgs-shared = ./libraries/nixpkgs;

      # 🆕 다중 시스템 지원
      systems = {
        darwin = "aarch64-darwin";
        linux = "x86_64-linux";
      };

      # 호스트별 설정 (기존 + 신규)
      darwinHosts = {
        "yunnogduui-MacBookPro" = {
          username = "green";
          hostType = "personal";
          nixosConfigPath = "/Users/green/IdeaProjects/nixos-config";
        };
        "work-MacBookPro" = {
          username = "green";
          hostType = "work";
          nixosConfigPath = "/Users/green/IdeaProjects/nixos-config";
        };
      };

      # 🆕 NixOS 호스트
      nixosHosts = {
        "greenhead-minipc" = {
          username = "greenhead";
          hostType = "server";
          nixosConfigPath = "/home/greenhead/nixos-config";
        };
      };

      # darwinConfiguration 생성 함수 (기존 유지)
      mkDarwinConfig =
        hostname: hostConfig:
        nix-darwin.lib.darwinSystem {
          system = systems.darwin;
          modules = [
            home-manager-shared
            nixpkgs-shared
            home-manager.darwinModules.home-manager
            ./modules/shared/configuration.nix
            ./modules/darwin/configuration.nix
            ./modules/darwin/home.nix
          ];
          specialArgs = {
            inherit inputs hostname;
            inherit (hostConfig) username hostType nixosConfigPath;
          };
        };

      # 🆕 nixosConfiguration 생성 함수
      mkNixosConfig =
        hostname: hostConfig:
        nixpkgs.lib.nixosSystem {
          system = systems.linux;
          modules = [
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            ./hosts/${hostname}
            ./modules/nixos/configuration.nix
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";
                extraSpecialArgs = {
                  inherit inputs hostname;
                  inherit (hostConfig) hostType nixosConfigPath;
                };
                users.${hostConfig.username} = import ./modules/nixos/home.nix;
              };
            }
          ];
          specialArgs = {
            inherit inputs hostname;
            inherit (hostConfig) username hostType nixosConfigPath;
          };
        };

    in
    {
      # 기존 Darwin 설정
      darwinConfigurations = builtins.mapAttrs mkDarwinConfig darwinHosts;

      # 🆕 NixOS 설정
      nixosConfigurations = builtins.mapAttrs mkNixosConfig nixosHosts;

      # 개발 쉘 (다중 시스템)
      devShells = nixpkgs.lib.genAttrs [ systems.darwin systems.linux ] (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
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
        }
      );
    };
}
```

### 1.2 shell 모듈 분리

#### 1.2.1 공통 설정

**파일**: `modules/shared/programs/shell/default.nix` (수정)

```nix
# Shell 설정 - 공통 부분만
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # PATH 추가 (공통)
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # Shell aliases (공통)
  home.shellAliases = {
    # 파일 목록 (eza 사용)
    l = "eza -l";
    ls = "eza -la";
    ll = "eza -la";

    # broot: tree 스타일 출력
    bt = "br -c :pt";

    # Claude Code (기본적으로 --dangerously-skip-permissions 사용)
    claude = "command claude --dangerously-skip-permissions";
  };

  # Zsh 설정 (공통)
  programs.zsh = {
    enable = true;
    autosuggestion = {
      enable = true;
      highlight = "fg=#808080";
      strategy = [ "history" ];
    };
    syntaxHighlighting.enable = true;

    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      share = true;
    };

    # 공통 초기화 스크립트
    initContent = lib.mkMerge [
      (lib.mkBefore ''
        # Mise 활성화 (node, ruby 등 런타임 관리)
        if command -v mise >/dev/null 2>&1; then
          eval "$(mise activate zsh)"
        fi

        # tmux 내부에서 clear 시 history buffer도 함께 삭제
        if [ -n "$TMUX" ]; then
          alias clear='clear && tmux clear-history'
        fi
      '')
    ];
  };

  # Starship 프롬프트
  programs.starship = {
    enable = true;
  };

  # Atuin 히스토리 (공통 설정)
  programs.atuin = {
    enable = true;
    settings = {
      auto_sync = true;
      sync_frequency = "1m";
      sync.records = true;
      network_timeout = 30;
      network_connect_timeout = 5;
      local_timeout = 5;
      style = "compact";
      inline_height = 9;
      show_help = false;
      update_check = false;
    };
  };

  # Zoxide (cd 대체)
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # FZF
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "${lib.getExe pkgs.fd} --strip-cwd-prefix --exclude .git";
    fileWidgetCommand = "${lib.getExe pkgs.fd} --strip-cwd-prefix --exclude .git";
  };
}
```

#### 1.2.2 macOS 전용 설정

**파일**: `modules/shared/programs/shell/darwin.nix` (신규)

```nix
# Shell 설정 - macOS 전용
{
  config,
  pkgs,
  lib,
  ...
}:

let
  scriptsDir = ../../../../scripts;
in
{
  # macOS용 스크립트 설치
  home.file.".local/bin/nrs.sh" = {
    source = "${scriptsDir}/nrs.sh";
    executable = true;
  };

  home.file.".local/bin/nrp.sh" = {
    source = "${scriptsDir}/nrp.sh";
    executable = true;
  };

  home.file.".local/bin/nrh.sh" = {
    source = "${scriptsDir}/nrh.sh";
    executable = true;
  };

  # macOS 전용 환경 변수
  home.sessionVariables = {
    ICLOUD = "$HOME/Library/Mobile Documents/com~apple~CloudDocs";
    BUN_INSTALL = "$HOME/.bun";
  };

  # macOS 전용 PATH
  home.sessionPath = [
    "$HOME/.bun/bin"
    "$HOME/.npm-global/bin"
  ];

  # macOS 전용 aliases
  home.shellAliases = {
    # Nix 시스템 관리 (darwin-rebuild)
    nrs = "~/.local/bin/nrs.sh";
    nrs-offline = "~/.local/bin/nrs.sh --offline";
    nrp = "~/.local/bin/nrp.sh";
    nrp-offline = "~/.local/bin/nrp.sh --offline";
    nrh = "~/.local/bin/nrh.sh";
    nrh-all = "~/.local/bin/nrh.sh --all";

    # Hammerspoon CLI
    hs = "/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs";
    hsr = ''hs -c "hs.reload()"'';

    # 터미널 CSI u 모드 리셋
    reset-term = ''printf "\033[?u\033[<u"'';
  };

  # macOS 전용 Zsh 초기화
  programs.zsh.initContent = lib.mkMerge [
    (lib.mkBefore ''
      # macOS NFD 유니코드 결합 문자 처리
      setopt COMBINING_CHARS

      # Ghostty 쉘 통합 설정
      if [ -n "''${GHOSTTY_RESOURCES_DIR}" ]; then
        builtin source "''${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration"
      fi

      # Homebrew 설정
      eval "$(/opt/homebrew/bin/brew shellenv)"
    '')

    ''
      # cursor 래퍼: 인수 없이 실행 시 현재 디렉터리 열기
      cursor() {
        if [ $# -eq 0 ]; then
          command cursor .
        else
          command cursor "$@"
        fi
      }

      # NVM bash completion
      [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

      # Bun completions
      [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

      # Deno 설정
      [ -f "$HOME/.deno/env" ] && . "$HOME/.deno/env"
    ''
  ];
}
```

#### 1.2.3 Linux 전용 설정

**파일**: `modules/shared/programs/shell/nixos.nix` (신규)

```nix
# Shell 설정 - Linux/NixOS 전용
{
  config,
  pkgs,
  lib,
  ...
}:

let
  scriptsDir = ../../../../scripts;
in
{
  # NixOS용 스크립트 설치
  home.file.".local/bin/nrs.sh" = {
    source = "${scriptsDir}/nrs-nixos.sh";
    executable = true;
  };

  home.file.".local/bin/nrp.sh" = {
    source = "${scriptsDir}/nrp-nixos.sh";
    executable = true;
  };

  # NixOS 전용 aliases
  home.shellAliases = {
    # Nix 시스템 관리 (nixos-rebuild)
    nrs = "~/.local/bin/nrs.sh";
    nrs-offline = "~/.local/bin/nrs.sh --offline";
    nrp = "~/.local/bin/nrp.sh";
    nrp-offline = "~/.local/bin/nrp.sh --offline";

    # NixOS 세대 히스토리
    nrh = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -10";
    nrh-all = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
  };
}
```

### 1.3 darwin/home.nix 수정

**파일**: `modules/darwin/home.nix` (수정)

```nix
# Home Manager 설정 (macOS)
{ config, pkgs, lib, inputs, username, nixosConfigPath, hostType, ... }:

{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";

  home-manager.extraSpecialArgs = { inherit nixosConfigPath hostType; };

  home-manager.users.${username} = { config, pkgs, lib, ... }: {
    home.username = username;
    home.homeDirectory = lib.mkForce "/Users/${username}";

    imports = [
      # Secrets 관리
      inputs.home-manager-secrets.homeManagerModules.home-manager-secrets
      inputs.nixos-config-secret.homeManagerModules.default

      # 공유 프로그램 (공통)
      ../shared/programs/broot
      ../shared/programs/ghostty
      ../shared/programs/git
      ../shared/programs/shell              # 공통 shell 설정
      ../shared/programs/shell/darwin.nix   # 🆕 macOS 전용 추가
      ../shared/programs/tmux
      ../shared/programs/vim
      ../shared/programs/claude             # 🆕 shared로 이동됨

      # macOS 전용
      ./programs/atuin
      ./programs/hammerspoon
      ./programs/cursor
      ./programs/folder-actions
      ./programs/keybindings
      ./programs/ssh
    ];

    home.packages = with pkgs; [
      # (기존 패키지 목록 유지)
      bat broot eza fd fzf ripgrep zoxide
      tmux lazygit gh git shellcheck
      starship atuin
      ffmpeg imagemagick rar
      curl unzip jq htop
      nvd
    ];

    home.stateVersion = "25.05";
  };
}
```

### 1.4 NixOS 모듈 생성

#### 1.4.1 시스템 설정

**파일**: `modules/nixos/configuration.nix` (신규)

```nix
# NixOS 시스템 설정
{ config, pkgs, lib, inputs, username, hostname, ... }:

{
  # 시스템 기본
  system.stateVersion = "24.11";

  # 부트로더
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # 호스트명
  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  # 시간대
  time.timeZone = "Asia/Seoul";

  # 로케일
  i18n.defaultLocale = "ko_KR.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "ko_KR.UTF-8";
  };

  # Nix 설정
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-users = [ "root" username ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # 사용자
  users.users.${username} = {
    isNormalUser = true;
    description = "YOON NOKDOO";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    shell = pkgs.zsh;
    # SSH 키는 nixos-config-secret에서 관리
  };

  # 기본 패키지
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    htop
    nvd
  ];

  # Zsh 활성화
  programs.zsh.enable = true;

  # 프로그램 모듈 임포트
  imports = [
    ./programs/tailscale.nix
    ./programs/ssh.nix
    ./programs/mosh.nix
    ./programs/fail2ban.nix
  ];
}
```

#### 1.4.2 Home Manager 설정

**파일**: `modules/nixos/home.nix` (신규)

```nix
# Home Manager 설정 (NixOS)
{ config, pkgs, lib, inputs, hostType, nixosConfigPath, ... }:

{
  imports = [
    # Secrets 관리
    inputs.home-manager-secrets.homeManagerModules.home-manager-secrets
    inputs.nixos-config-secret.homeManagerModules.default

    # 공유 프로그램 (공통)
    ../shared/programs/broot
    ../shared/programs/git
    ../shared/programs/shell              # 공통 shell 설정
    ../shared/programs/shell/nixos.nix    # Linux 전용 추가
    ../shared/programs/tmux
    ../shared/programs/vim
    ../shared/programs/claude             # Claude Code 설정
  ];

  home = {
    username = config.home.username;  # flake.nix에서 주입
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "24.11";
  };

  # 패키지 (모바일 개발 최적화)
  home.packages = with pkgs; [
    # CLI 도구
    bat
    eza
    fd
    fzf
    ripgrep
    zoxide
    jq
    htop
    nvd

    # 개발 도구
    tmux
    lazygit
    gh
    git
    shellcheck

    # 쉘 도구
    starship
    atuin

    # 런타임 관리
    mise

    # mosh (불안정한 네트워크 대비)
    mosh
  ];

  # Claude 세션 관리 스크립트
  home.file.".local/bin/claude-session" = {
    executable = true;
    text = ''
      #!/bin/bash
      SESSION_NAME="claude"

      # 기존 세션이 있으면 연결, 없으면 생성
      tmux has-session -t $SESSION_NAME 2>/dev/null
      if [ $? != 0 ]; then
          tmux new-session -d -s $SESSION_NAME -c ~/projects
          tmux send-keys -t $SESSION_NAME "claude" Enter
      fi
      tmux attach-session -t $SESSION_NAME
    '';
  };

  programs.home-manager.enable = true;
}
```

#### 1.4.3 Tailscale 모듈

**파일**: `modules/nixos/programs/tailscale.nix` (신규)

```nix
# Tailscale VPN
{ config, pkgs, ... }:

{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";  # Funnel/Serve 지원
  };

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];

    # 개발 서버 포트 (Tailscale 네트워크 내에서만)
    interfaces."tailscale0".allowedTCPPorts = [ 3000 3001 5173 8080 ];
  };

  environment.systemPackages = [ pkgs.tailscale ];
}
```

#### 1.4.4 SSH 서버 모듈

**파일**: `modules/nixos/programs/ssh.nix` (신규)

```nix
# SSH 서버 설정
{ config, ... }:

{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
      X11Forwarding = false;
      AllowTcpForwarding = true;  # 개발 서버 터널링용
      ClientAliveInterval = 60;
      ClientAliveCountMax = 3;
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];
}
```

#### 1.4.5 mosh 모듈

**파일**: `modules/nixos/programs/mosh.nix` (신규)

```nix
# mosh 설정
{ config, ... }:

{
  programs.mosh.enable = true;

  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 61000; }
  ];
}
```

#### 1.4.6 fail2ban 모듈

**파일**: `modules/nixos/programs/fail2ban.nix` (신규)

```nix
# fail2ban 설정
{ config, ... }:

{
  services.fail2ban = {
    enable = true;

    jails = {
      sshd = {
        settings = {
          enabled = true;
          port = "ssh";
          filter = "sshd";
          maxretry = 3;
          findtime = "10m";
          bantime = "24h";
        };
      };
    };
  };
}
```

### 1.5 호스트 설정

#### 1.5.1 호스트 진입점

**파일**: `hosts/greenhead-minipc/default.nix` (신규)

```nix
# greenhead-minipc 호스트 설정
{ config, lib, pkgs, inputs, username, ... }:

{
  imports = [
    ./hardware-configuration.nix  # placeholder → 설치 후 실제 내용으로 교체
    ./disko.nix
  ];

  # SSH 공개키 (nixos-config-secret에서 관리 권장)
  users.users.${username}.openssh.authorizedKeys.keys = [
    # Mac의 ~/.ssh/id_ed25519.pub 내용
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... green@yunnogduui-MacBookPro"
  ];

  # HDD 마운트 (기존 데이터 유지)
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/3f1111d9-1641-4d5e-9e40-af54f4ce7870";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };
}
```

#### 1.5.2 hardware-configuration.nix (placeholder)

**파일**: `hosts/greenhead-minipc/hardware-configuration.nix` (신규)

```nix
# 이 파일은 NixOS 설치 후 실제 내용으로 교체됩니다.
# Phase 2 완료 후: cat /etc/nixos/hardware-configuration.nix 로 내용 확인
# 그 내용을 이 파일에 복사하여 커밋하세요.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # 일반적인 x86_64 시스템용 기본값 (설치 후 실제 값으로 교체됨)
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];

  # disko가 파일시스템을 관리하므로 여기서는 정의하지 않음
  # fileSystems는 disko.nix에서 자동 생성됨

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
```

#### 1.5.3 disko 설정

**파일**: `hosts/greenhead-minipc/disko.nix` (신규)

```
⚠️  중요: disko는 NVMe(/dev/nvme0n1)만 포맷합니다!
    HDD(/dev/sda)는 disko 설정에 포함되지 않으므로 기존 데이터가 보존됩니다.

    만약 실수로 HDD를 포맷하면 295GB의 media 데이터가 손실됩니다.
    disko 실행 전 반드시 lsblk로 디바이스 확인하세요.
```

```nix
# disko 디스크 파티셔닝 설정
# 주의: NVMe만 포맷! HDD(/dev/sda)는 건드리지 않음
{
  disko.devices = {
    disk = {
      nvme = {
        type = "disk";
        device = "/dev/nvme0n1";  # NVMe만 대상
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            swap = {
              size = "8G";  # 16GB RAM의 절반
              content = {
                type = "swap";
                resumeDevice = true;
              };
            };
            root = {
              size = "100%";  # 나머지 전체 (~468GB)
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
      # HDD는 여기에 포함하지 않음 - 기존 데이터 보존!
      # HDD 마운트는 hosts/greenhead-minipc/default.nix에서 fileSystems로 설정
    };
  };
}
```

### 1.6 Claude 모듈을 shared로 이동

**파일**: `modules/shared/programs/claude/default.nix` (신규 - darwin에서 이동)

```nix
# Claude Code 설정 (공통)
{ config, pkgs, lib, nixosConfigPath, ... }:

let
  claudeDir = ./files;
  claudeFilesPath = "${nixosConfigPath}/modules/shared/programs/claude/files";
in
{
  # Binary Claude Code 설치
  home.activation.installClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.local/bin/claude" ]; then
      echo "Installing Claude Code binary..."
      ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh | ${pkgs.bash}/bin/bash
    else
      echo "Claude Code already installed at $HOME/.local/bin/claude"
    fi
  '';

  # ~/.claude/ 디렉토리 관리
  home.file = {
    # 메인 설정 파일 - 양방향 수정 가능
    ".claude/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${claudeFilesPath}/settings.json";

    # MCP 설정 - 양방향 수정 가능
    ".claude/mcp-config.json".source =
      config.lib.file.mkOutOfStoreSymlink "${claudeFilesPath}/mcp-config.json";

    # Agents
    ".claude/agents/document-task.md".source = "${claudeDir}/agents/document-task.md";

    # Commands
    ".claude/commands/catchup.md".source = "${claudeDir}/commands/catchup.md";

    # Skills
    ".claude/skills/document-task" = {
      source = "${claudeDir}/skills/document-task";
      recursive = true;
    };

    # Hooks (macOS 전용 부분은 darwin 모듈에서 처리)
  };
}
```

### 1.7 NixOS용 스크립트

**파일**: `scripts/nrs-nixos.sh` (신규)

```bash
#!/usr/bin/env bash
# nixos-rebuild wrapper script
set -euo pipefail

FLAKE_PATH="$HOME/nixos-config"
OFFLINE_FLAG=""

if [[ "${1:-}" == "--offline" ]]; then
    OFFLINE_FLAG="--offline"
fi

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}$1${NC}"; }
log_warn() { echo -e "${YELLOW}$1${NC}"; }
log_error() { echo -e "${RED}$1${NC}"; }

# SSH 키 로드 확인
ensure_ssh_key_loaded() {
    if ! ssh-add -l 2>/dev/null | grep -q "id_ed25519"; then
        log_info "🔑 Loading SSH key..."
        ssh-add ~/.ssh/id_ed25519
    fi
}

# 빌드 및 미리보기
preview_changes() {
    if [[ -n "$OFFLINE_FLAG" ]]; then
        log_info "🔨 Building (offline, preview)..."
    else
        log_info "🔨 Building (preview)..."
    fi

    # shellcheck disable=SC2086
    if ! sudo nixos-rebuild build --flake "$FLAKE_PATH" $OFFLINE_FLAG; then
        log_error "❌ Build failed!"
        exit 1
    fi

    echo ""
    log_info "📋 Changes to be applied:"
    if ! nvd diff /run/current-system ./result; then
        log_warn "⚠️  nvd diff returned non-zero (possibly identical results)"
    fi
    echo ""
}

# 사용자 확인
confirm_apply() {
    echo -en "${YELLOW}Apply these changes? [Y/n] ${NC}"
    read -r response
    case "$response" in
        [nN]|[nN][oO])
            log_warn "❌ Cancelled by user"
            exit 0
            ;;
    esac
}

# nixos-rebuild switch 실행
run_nixos_rebuild() {
    if [[ -n "$OFFLINE_FLAG" ]]; then
        log_info "🔨 Applying changes (offline)..."
    else
        log_info "🔨 Applying changes..."
    fi

    # shellcheck disable=SC2086
    sudo nixos-rebuild switch --flake "$FLAKE_PATH" $OFFLINE_FLAG
}

# 빌드 아티팩트 정리
cleanup_build_artifacts() {
    log_info "🧹 Cleaning up build artifacts..."

    local count
    count=$(find "$FLAKE_PATH" -maxdepth 1 -name 'result*' -type l 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$count" -gt 0 ]]; then
        sudo rm -f "$FLAKE_PATH"/result*
        log_info "  ✓ Removed $count result symlink(s)"
    fi
}

main() {
    cd "$FLAKE_PATH" || exit 1

    echo ""
    ensure_ssh_key_loaded
    preview_changes
    confirm_apply
    run_nixos_rebuild
    cleanup_build_artifacts
    echo ""
    log_info "✅ Done!"
}

main
```

**파일**: `scripts/nrp-nixos.sh` (신규)

```bash
#!/usr/bin/env bash
# nixos-rebuild preview script (build only, no switch)
set -euo pipefail

FLAKE_PATH="$HOME/nixos-config"
OFFLINE_FLAG=""

if [[ "${1:-}" == "--offline" ]]; then
    OFFLINE_FLAG="--offline"
fi

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}$1${NC}"; }
log_warn() { echo -e "${YELLOW}$1${NC}"; }
log_error() { echo -e "${RED}$1${NC}"; }

main() {
    cd "$FLAKE_PATH" || exit 1

    if [[ -n "$OFFLINE_FLAG" ]]; then
        log_info "🔨 Building (offline, preview only)..."
    else
        log_info "🔨 Building (preview only)..."
    fi

    # shellcheck disable=SC2086
    if ! sudo nixos-rebuild build --flake "$FLAKE_PATH" $OFFLINE_FLAG; then
        log_error "❌ Build failed!"
        exit 1
    fi

    echo ""
    log_info "📋 Changes (preview only, not applied):"
    if ! nvd diff /run/current-system ./result; then
        log_warn "⚠️  nvd diff returned non-zero (possibly identical results)"
    fi

    # 정리
    sudo rm -f "$FLAKE_PATH"/result*

    echo ""
    log_info "✅ Preview complete (no changes applied)"
}

main
```

---

## Phase 2: NixOS 설치 (MiniPC에서)

### 2.1 준비물

1. **NixOS ISO** (https://nixos.org/download.html)
   - NixOS 24.11 또는 25.05 minimal ISO
   - USB에 굽기: `sudo dd if=nixos-*.iso of=/dev/diskX bs=4M status=progress`

2. **nixos-config가 GitHub에 push된 상태** (Phase 1 완료 후)

3. **Mac의 SSH 공개키** (`~/.ssh/id_ed25519.pub` 내용)

### 2.2 설치 절차

```bash
# 1. NixOS ISO로 부팅 후 네트워크 연결 확인
ip a
ping -c 3 google.com

# 2. root로 전환
sudo -i

# 3. ⚠️ 중요: 디바이스 경로 확인 (disko 실행 전 필수!)
#    드물게 BIOS 설정에 따라 NVMe와 HDD의 디바이스명이 바뀔 수 있음
lsblk -o NAME,SIZE,MODEL,TYPE

# 예상 출력:
#   nvme0n1     476.9G  HighRel_SSD_512GB  disk  ← 이것이 NVMe (포맷 대상)
#   sda           1.8T  ST2000LM007        disk  ← 이것이 HDD (보존!)
#
# 만약 다르게 보이면 disko.nix의 device 경로를 수정해야 함!

# 4. disko 설정 다운로드
curl -o /tmp/disko.nix https://raw.githubusercontent.com/shren207/nixos-config/main/hosts/greenhead-minipc/disko.nix

# 5. disko 설정에서 디바이스 경로 재확인
cat /tmp/disko.nix | grep "device ="
# 출력: device = "/dev/nvme0n1";
# 3번에서 확인한 NVMe 경로와 일치하는지 확인!

# 6. disko로 NVMe 파티셔닝 (HDD는 건드리지 않음)
nix --experimental-features "nix-command flakes" run \
  github:nix-community/disko -- \
  --mode disko /tmp/disko.nix

# 7. 마운트 확인
mount | grep /mnt
lsblk  # 파티션 생성 확인

# 8. NixOS 설치 (GitHub에서 설정 가져옴)
#    hardware-configuration.nix는 placeholder로 미리 포함되어 있음
nixos-install --flake github:shren207/nixos-config#greenhead-minipc

# 9. 재부팅
reboot
```

### 2.3 hardware-configuration.nix 처리 (설치 후)

**전략**: `hosts/greenhead-minipc/hardware-configuration.nix`를 미리 placeholder로 생성해두고,
설치 후 실제 내용으로 교체하여 커밋.

**Phase 1에서 미리 생성 (placeholder)**:
```nix
# hosts/greenhead-minipc/hardware-configuration.nix
# 이 파일은 NixOS 설치 후 실제 내용으로 교체됩니다.
# nixos-generate-config --root /mnt 로 생성된 내용을 여기에 붙여넣으세요.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # TODO: 설치 후 실제 hardware-configuration.nix 내용으로 교체
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];

  # disko가 파일시스템을 관리하므로 여기서는 비워둠
  # fileSystems."/" = { ... };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
```

**설치 후 실제 내용으로 교체**:
```bash
# MiniPC에서 (재부팅 후)
cat /etc/nixos/hardware-configuration.nix

# 이 내용을 hosts/greenhead-minipc/hardware-configuration.nix에 복사
# GitHub에 커밋 후 다시 rebuild
cd ~/nixos-config
# (파일 수정)
git add hosts/greenhead-minipc/hardware-configuration.nix
git commit -m "feat(minipc): add actual hardware-configuration.nix"
git push

# 적용
sudo nixos-rebuild switch --flake .#greenhead-minipc
```

---

## Phase 3: 초기 설정 (재부팅 후)

### 3.1 Tailscale 인증

```bash
# MiniPC에서
sudo tailscale up

# 표시되는 URL을 브라우저에서 열어 인증
# 또는 headless 인증:
sudo tailscale up --authkey=tskey-auth-xxxxx

# IP 확인
tailscale ip -4  # 예: 100.x.x.x
```

### 3.2 SSH 접속 테스트 (Mac에서)

```bash
# Tailscale IP로 접속
ssh greenhead@100.x.x.x

# 성공하면 ~/.ssh/config에 추가
cat >> ~/.ssh/config << 'EOF'
Host minipc
    HostName 100.x.x.x
    User greenhead
    IdentityFile ~/.ssh/id_ed25519
EOF

# 이제 간단히 접속 가능
ssh minipc
```

### 3.3 Atuin key 복사 (Mac에서)

```bash
# Atuin 디렉토리 생성
ssh minipc "mkdir -p ~/.local/share/atuin"

# key 복사 (동기화를 위해 동일한 키 필요)
scp ~/.local/share/atuin/key minipc:~/.local/share/atuin/

# MiniPC에서 Atuin 로그인
ssh minipc "atuin login -u greenhead"  # 기존 계정명
ssh minipc "atuin sync"
```

### 3.4 nixos-config 클론 (MiniPC에서)

```bash
# SSH 키 생성 (MiniPC용)
ssh-keygen -t ed25519 -C "greenhead@minipc"

# 공개키를 GitHub에 등록
cat ~/.ssh/id_ed25519.pub
# GitHub → Settings → SSH keys → New SSH key

# nixos-config 클론
mkdir -p ~/nixos-config
git clone git@github.com:shren207/nixos-config.git ~/nixos-config
```

---

## Phase 4: 모바일 UX 설정 (iPhone)

### 4.1 Termius Premium 설정

**호스트 설정**:
| 필드 | 값 |
|------|---|
| Label | greenhead-minipc |
| Hostname | 100.x.x.x (Tailscale IP) |
| Username | greenhead |
| Authentication | SSH Key |

**스니펫**:
| 이름 | 명령어 | 설명 |
|------|--------|------|
| cs | claude-session | Claude 세션 시작/재접속 |
| ta | tmux attach -t claude \|\| tmux new -s claude | 세션 연결 |
| tl | tmux list-sessions | 세션 목록 |
| td | tmux detach | 세션 분리 |
| y | yes | Claude 승인 |
| n | no | Claude 거부 |
| cont | /continue | Claude 계속 |
| comp | /compact | 컨텍스트 압축 |
| help | /help | 도움말 |
| clear | /clear | 대화 초기화 |

### 4.2 Blink Shell 설정 (대안)

```bash
# mosh 연결 (불안정한 네트워크에서 유리)
mosh greenhead@100.x.x.x
```

---

## Phase 5: 원격 배포 (Mac에서)

설정 변경 후 Mac에서 MiniPC로 직접 배포:

```bash
# Tailscale 연결 확인
tailscale status

# 원격 배포
nixos-rebuild switch \
  --flake ~/IdeaProjects/nixos-config#greenhead-minipc \
  --target-host greenhead@minipc \
  --use-remote-sudo
```

---

## 검증 체크리스트

### NixOS 설치 검증
- [ ] `uname -a` → Linux greenhead-minipc ...
- [ ] `nixos-version` → 24.11 또는 25.05
- [ ] `ls /mnt/data/` → 기존 HDD 데이터 확인

### 네트워크 검증
- [ ] `tailscale status` → connected
- [ ] iPhone Tailscale 앱에서 minipc 표시
- [ ] Mac에서 `ssh minipc` 성공

### 개발 환경 검증
- [ ] `claude --version` → 설치 확인
- [ ] `tmux` → 정상 실행
- [ ] `atuin status` → 동기화 상태 확인

### 모바일 UX 검증
- [ ] Termius에서 SSH 접속 성공
- [ ] `claude-session` 실행 → Claude 시작
- [ ] 앱 종료 후 재접속 → tmux 세션 유지

### 개발 서버 검증
- [ ] MiniPC에서 `pnpm create vite test && cd test && pnpm dev`
- [ ] iPhone Safari에서 `http://100.x.x.x:5173` 접속

---

## 파일 변경 요약

### 신규 생성

| 파일 | 용도 |
|------|------|
| `modules/shared/programs/shell/darwin.nix` | macOS 전용 shell 설정 |
| `modules/shared/programs/shell/nixos.nix` | Linux 전용 shell 설정 |
| `modules/shared/programs/claude/` | Claude Code 설정 (darwin에서 이동) |
| `modules/nixos/configuration.nix` | NixOS 시스템 설정 |
| `modules/nixos/home.nix` | NixOS Home Manager 설정 |
| `modules/nixos/programs/tailscale.nix` | Tailscale 모듈 |
| `modules/nixos/programs/ssh.nix` | SSH 서버 모듈 |
| `modules/nixos/programs/mosh.nix` | mosh 모듈 |
| `modules/nixos/programs/fail2ban.nix` | fail2ban 모듈 |
| `hosts/greenhead-minipc/default.nix` | 호스트 진입점 |
| `hosts/greenhead-minipc/disko.nix` | 디스크 파티셔닝 |
| `hosts/greenhead-minipc/hardware-configuration.nix` | 하드웨어 설정 (자동 생성) |
| `scripts/nrs-nixos.sh` | NixOS rebuild 스크립트 |
| `scripts/nrp-nixos.sh` | NixOS preview 스크립트 |

### 수정

| 파일 | 변경 내용 |
|------|----------|
| `flake.nix` | disko input 추가, nixosConfigurations 추가, 다중 시스템 지원 |
| `modules/shared/programs/shell/default.nix` | 공통 설정만 남기고 플랫폼별 분리 |
| `modules/darwin/home.nix` | shell/darwin.nix 임포트 추가, claude를 shared에서 임포트 |

---

## 롤백 계획

```bash
# 부팅 시 systemd-boot 메뉴에서 이전 세대 선택
# 또는 명령어로:
sudo nixos-rebuild switch --rollback

# 특정 세대로 롤백
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo nixos-rebuild switch --generation <번호>
```

---

## LLM 참조 문서

NixOS 설치/설정 시 Claude Code가 참조해야 할 문서:

- https://nixos.org/manual/nixos/stable/
- https://wiki.nixos.org/wiki/NixOS_Installation_Guide
- https://github.com/nix-community/disko
- https://nix-community.github.io/home-manager/

**현재 NixOS stable 버전**: 24.11 (2026년 1월 기준)
