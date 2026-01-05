# 설정 수정 가이드

## 목차

- [CLI 패키지 추가/제거](#cli-패키지-추가제거)
- [폰트 추가/제거 (Nerd Fonts)](#폰트-추가제거-nerd-fonts)
- [쉘 Alias 추가](#쉘-alias-추가)
- [쉘 함수 추가](#쉘-함수-추가)
- [런타임 버전 관리 (mise)](#런타임-버전-관리-mise)
- [broot 설정 변경](#broot-설정-변경)
- [inshellisense 설정 변경](#inshellisense-설정-변경)
- [Git 설정 변경](#git-설정-변경)
- [macOS 시스템 설정 변경](#macos-시스템-설정-변경)
- [Homebrew GUI 앱 추가](#homebrew-gui-앱-추가)
- [새 프로그램 모듈 추가](#새-프로그램-모듈-추가)
- [폴더 액션 추가](#폴더-액션-추가)
- [Secrets 추가](#secrets-추가)
- [대외비 설정 추가](#대외비-설정-추가-쉘-함수-gitignore-등)
- [VSCode(Cursor) 확장 프로그램 관리](#vscodecursor-확장-프로그램-관리)

---

설정을 수정한 후에는 항상 다음 명령어로 적용합니다:

```bash
git add <수정한-파일>
darwin-rebuild switch --flake .
```

---

## CLI 패키지 추가/제거

**파일**: `modules/darwin/home.nix`

```nix
home.packages = with pkgs; [
  # 기존 패키지들...
  neovim        # ← 추가
  # htop        # ← 주석 처리로 제거
];
```

---

## 폰트 추가/제거 (Nerd Fonts)

**파일**: `modules/darwin/configuration.nix`

### 폰트 추가

```nix
fonts.packages = with pkgs.nerd-fonts; [
  fira-code
  jetbrains-mono
  hack              # ← 추가
  meslo-lg          # ← 추가
];
```

### 사용 가능한 폰트 검색

```bash
# 전체 Nerd Fonts 목록
nix search nixpkgs nerd-fonts

# 특정 폰트 검색
nix search nixpkgs nerd-fonts | grep -i "hack"
```

### 폰트 제거

```nix
fonts.packages = with pkgs.nerd-fonts; [
  fira-code
  # jetbrains-mono  # ← 주석 처리로 제거
];
```

### 주요 Nerd Fonts 목록

| 패키지명 | 폰트 이름 |
|---------|----------|
| `fira-code` | FiraCode Nerd Font |
| `jetbrains-mono` | JetBrains Mono Nerd Font |
| `hack` | Hack Nerd Font |
| `meslo-lg` | MesloLG Nerd Font |
| `iosevka` | Iosevka Nerd Font |
| `cascadia-code` | CaskaydiaCove Nerd Font |
| `ubuntu-mono` | UbuntuMono Nerd Font |
| `roboto-mono` | RobotoMono Nerd Font |

> **참고**: NixOS 25.05+에서는 `nerd-fonts.fira-code` 형식을 사용합니다. 구 문법 `(nerdfonts.override { fonts = [...]; })`은 더 이상 지원되지 않습니다.

---

## 쉘 Alias 추가

**파일**: `modules/shared/programs/shell/default.nix`

```nix
programs.zsh.shellAliases = {
  # 기존 alias들...
  myalias = "echo hello";    # ← 추가
};
```

---

## 쉘 함수 추가

**파일**: `modules/shared/programs/shell/default.nix`

```nix
programs.zsh.initContent = lib.mkMerge [
  # 기존 설정들...
  ''
    # 새 함수 추가
    myfunc() {
      echo "Hello, $1"
    }
  ''
];
```

> **대외비 함수**: 회사 관련 쉘 함수는 Private 저장소(`nixos-config-secret/green/shell.nix`)에서 관리합니다. `lib.mkAfter`를 사용하여 Public 설정 이후에 추가됩니다.

---

## 런타임 버전 관리 (mise)

Node.js, Ruby, Python 등 런타임 버전은 `mise`로 관리합니다.

### 기본 사용법

```bash
# 사용 가능한 버전 목록
mise ls-remote node

# 특정 버전 설치 및 사용
mise use node@20

# 현재 디렉토리에 .mise.toml 생성 (프로젝트별 버전 고정)
mise use --pin node@20

# 전역 기본 버전 설정
mise use -g node@20

# 설치된 런타임 목록
mise ls

# mise 상태 확인
mise doctor
```

### 프로젝트별 버전 설정

프로젝트 루트에 `.mise.toml` 또는 기존 파일(`.node-version`, `.ruby-version`)을 생성하면 해당 디렉토리 진입 시 자동으로 버전이 전환됩니다.

```toml
# .mise.toml 예시
[tools]
node = "20"
ruby = "3.3"
python = "3.12"
```

> **참고**: mise는 `.zshrc`에서 `eval "$(mise activate zsh)"`로 활성화됩니다 (`modules/shared/programs/shell/default.nix`).

---

## broot 설정 변경

**파일**: `modules/shared/programs/broot/default.nix`

broot는 Home Manager의 `programs.broot` 모듈로 선언적으로 관리됩니다.

### 기본 설정

```nix
programs.broot = {
  enable = true;
  enableZshIntegration = true;  # br 함수 자동 생성

  settings = {
    modal = false;  # vim 모드 비활성화 (기본값)
  };
};
```

### 주요 옵션

| 옵션 | 설명 |
|------|------|
| `enableZshIntegration` | `br` 함수 자동 생성 (디렉토리 이동 지원) |
| `settings.modal` | vim 모드 활성화 (`true`로 설정) |
| `settings.verbs` | 커스텀 verb 정의 |
| `settings.skin` | 색상 테마 설정 |

### 커스텀 Verb 추가

```nix
settings = {
  verbs = [
    {
      invocation = "edit";
      shortcut = "e";
      execution = "$EDITOR {file}";
    }
    {
      invocation = "create {subpath}";
      execution = "$EDITOR {directory}/{subpath}";
    }
  ];
};
```

### Alias 설정

**파일**: `modules/shared/programs/shell/default.nix`

```nix
home.shellAliases = {
  bt = "br -c :pt";   # tree 스타일 출력
};
```

> **참고**: `alias tree='broot'`는 기존 tree 명령어와 옵션이 호환되지 않아 권장하지 않습니다. 대신 `bt` alias를 사용하세요.

### 참고 자료

- [broot 공식 문서](https://dystroy.org/broot/)
- [Home Manager broot 모듈](https://github.com/nix-community/home-manager/blob/master/modules/programs/broot.nix)

---

## inshellisense 설정 변경

**파일**: `modules/shared/programs/inshellisense/default.nix`

inshellisense는 Microsoft에서 개발한 IDE 스타일 명령줄 자동완성 도구입니다.

### 키바인딩 변경

```nix
xdg.configFile."inshellisense/rc.toml".text = ''
  [bindings.acceptSuggestion]
  key = "return"           # Enter로 수락

  [bindings.nextSuggestion]
  key = "tab"              # Tab으로 다음

  [bindings.previousSuggestion]
  key = "tab"
  shift = true             # Shift+Tab으로 이전

  [bindings.dismissSuggestions]
  key = "escape"           # Esc로 닫기
'';
```

### 사용 가능한 키 이름

Node.js keypress 이벤트 이름을 사용합니다:

| 키 | 이름 |
|---|------|
| Enter | `return` |
| Tab | `tab` |
| Escape | `escape` |
| 방향키 | `up`, `down`, `left`, `right` |
| Space | `space` |

### Modifier 키

```toml
[bindings.nextSuggestion]
key = "tab"
shift = true      # Shift 키 조합
control = true    # Control 키 조합
```

### 자동 시작 비활성화

자동 시작을 비활성화하려면 zsh initContent를 제거합니다:

```nix
# 아래 블록을 주석 처리 또는 삭제
programs.zsh.initContent = lib.mkAfter ''
  if command -v is >/dev/null 2>&1; then
    eval "$(is init zsh)"
  fi
'';
```

수동 시작: 터미널에서 `is` 명령어 실행

### 참고 자료

- [inshellisense GitHub](https://github.com/microsoft/inshellisense)
- [설정 파일 문서](https://github.com/microsoft/inshellisense#configuration)

> **주의**: nixpkgs 버전(0.0.1-rc.21)에서는 `useNerdFont` 옵션이 지원되지 않습니다. 이 옵션을 사용하면 "data must NOT have additional properties" 오류가 발생합니다.

---

## Git 설정 변경

**파일**: `modules/shared/programs/git/default.nix`

### Git 설정 파일 탐색 순서

Git은 여러 위치에서 설정을 읽습니다:

| 우선순위 | 경로 | 관리 방식 |
|---------|------|----------|
| 1 | `~/.gitconfig` | 수동 (사용하지 않음) |
| 2 | `~/.config/git/config` | **Home Manager** (Nix store 심볼릭 링크) |
| 3 | `.git/config` | 프로젝트별 로컬 설정 |

> **중요**: Home Manager는 XDG 표준 경로(`~/.config/git/config`)를 사용합니다. `~/.gitconfig`이 있으면 두 설정이 병합되므로, `~/.gitconfig`은 삭제하거나 사용하지 않는 것이 좋습니다.

### 기본 설정

```nix
programs.git = {
  enable = true;

  settings = {
    user = {
      name = "Your Name";
      email = "your@email.com";
    };

    alias = {
      s = "status -s";
      # 새 alias 추가
    };
  };
};
```

### Delta (Git diff 시각화)

```nix
programs.delta = {
  enable = true;
  enableGitIntegration = true;  # core.pager = delta 설정
  options = {
    navigate = true;
    dark = true;
  };
};
```

> **참고**: `programs.delta`는 `programs.git`과 별도로 설정합니다. `enableGitIntegration = true`가 있어야 Git에서 delta를 pager로 사용합니다.

> **대외비 gitignore**: 회사 프로젝트 브랜치 패턴 등은 Private 저장소(`nixos-config-secret/green/git.nix`)에서 `lib.mkAfter`로 추가됩니다.

---

## macOS 시스템 설정 변경

**파일**: `modules/darwin/configuration.nix`

### Dock 설정

```nix
system.defaults.dock = {
  autohide = true;
  show-recents = false;
  tilesize = 36;
  mru-spaces = false;  # Spaces 자동 재정렬 비활성화
};
```

### Finder 설정

```nix
system.defaults.finder = {
  AppleShowAllFiles = true;
  AppleShowAllExtensions = true;
  ShowPathbar = true;
};
```

### 키보드 설정

```nix
system.defaults.NSGlobalDomain = {
  KeyRepeat = 1;           # 더 빠른 키 반복
  InitialKeyRepeat = 15;
  "com.apple.swipescrolldirection" = false;  # 자연스러운 스크롤 비활성화

  # 자동 수정 비활성화
  NSAutomaticCapitalizationEnabled = false;
  NSAutomaticSpellingCorrectionEnabled = false;
  NSAutomaticPeriodSubstitutionEnabled = false;
  NSAutomaticQuoteSubstitutionEnabled = false;
  NSAutomaticDashSubstitutionEnabled = false;
};
```

> **참고**: `AppleInterfaceStyle`은 `"Dark"` 또는 `null`만 허용됩니다. Light 모드를 사용하려면 해당 설정을 생략하거나 `null`로 설정하세요.

> **중요**: macOS 시스템 설정(`system.defaults`)은 `darwin-rebuild switch` 실행 후 **로그아웃 또는 재부팅**해야 완전히 반영됩니다. 일부 설정(Dock, Finder 등)은 즉시 적용되지만, 키보드 반복 속도 등은 재로그인이 필요합니다.

---

## Homebrew GUI 앱 추가

**파일**: `modules/darwin/programs/homebrew.nix`

```nix
homebrew.casks = [
  # 기존 앱들...
  "notion"      # ← 추가
];
```

---

## 새 프로그램 모듈 추가

### 1. 폴더 생성

```bash
mkdir -p modules/darwin/programs/<프로그램명>
```

### 2. default.nix 작성

```nix
{ config, pkgs, lib, ... }:

{
  home.file.".<설정파일>" = {
    source = ./files/<설정파일>;
  };

  # 또는 직접 작성
  home.file.".<설정파일>".text = ''
    설정 내용
  '';
}
```

### 3. home.nix에서 import

**파일**: `modules/darwin/home.nix`

```nix
imports = [
  # 기존 imports...
  ./programs/<프로그램명>
];
```

---

## 폴더 액션 추가

**파일**: `modules/darwin/programs/folder-actions/`

### 1. 스크립트 생성

`files/scripts/<액션명>.sh` 파일 생성

### 2. default.nix 수정

```nix
# 스크립트 배치
home.file.".local/bin/<액션명>.sh" = {
  source = "${scriptsDir}/<액션명>.sh";
  executable = true;
};

# 감시 폴더 생성 (activation에 추가)
mkdir -p "${folderActionsDir}/<액션명>"

# launchd 에이전트 추가
launchd.agents.folder-action-<액션명> = {
  enable = true;
  config = {
    Label = "com.green.folder-action.<액션명>";
    ProgramArguments = [ "${homeDir}/.local/bin/<액션명>.sh" ];
    WatchPaths = [ "${folderActionsDir}/<액션명>" ];
    StandardOutPath = "${logsDir}/<액션명>.log";
    StandardErrorPath = "${logsDir}/<액션명>.error.log";
  };
};
```

---

## Secrets 추가

Secrets는 Private 저장소(`nixos-config-secret`)에서 관리합니다.

```bash
# 1. Private 저장소로 이동
cd ~/IdeaProjects/nixos-config-secret

# 2. 개발 쉘 진입 (rage 사용)
nix develop

# 3. 암호화
echo "API_KEY=xxx" | rage -r "$(cat ~/.ssh/id_ed25519.pub)" -o green/secrets/<name>.age

# 4. green/secrets.nix에서 정의
secrets.file."<name>" = {
  source = ./secrets/<name>.age;
  mode = "0400";
  symlinks = [ "${config.xdg.configHome}/<app>/credentials" ];
};

# 5. Private 저장소 커밋 & 푸시
git add . && git commit -m "feat: add <name> secret" && git push

# 6. Public 저장소에서 flake 업데이트 & 적용
cd ~/IdeaProjects/nixos-config
nix flake update nixos-config-secret
darwin-rebuild switch --flake .
```

---

## 대외비 설정 추가 (쉘 함수, gitignore 등)

암호화가 필요 없는 대외비 설정도 Private 저장소에서 관리합니다.

```bash
# 1. Private 저장소로 이동
cd ~/IdeaProjects/nixos-config-secret

# 2. 해당 파일 수정
# - 쉘 함수: green/shell.nix
# - gitignore 패턴: green/git.nix
# - tmux/pane-note 링크: green/tmux.nix

# 3. lib.mkAfter로 기존 설정에 추가
# 예시 (green/shell.nix):
programs.zsh.initContent = lib.mkAfter ''
  myfunction() {
    echo "회사 전용 함수"
  }
'';

# 4. Private 저장소 커밋 & 푸시
git add . && git commit -m "feat: add myfunction" && git push

# 5. Public 저장소에서 flake 업데이트 & 적용
cd ~/IdeaProjects/nixos-config
nix flake update nixos-config-secret
darwin-rebuild switch --flake .
```

---

## VSCode(Cursor) 확장 프로그램 관리

Cursor 확장 프로그램 관리는 별도 문서를 참고하세요: [CURSOR_EXTENSIONS.md](CURSOR_EXTENSIONS.md)
