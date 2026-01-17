# 설정 수정 가이드

## 목차

- [Rebuild vs Update 이해하기](#rebuild-vs-update-이해하기)
- [CLI 패키지 추가/제거](#cli-패키지-추가제거)
- [폰트 추가/제거 (Nerd Fonts)](#폰트-추가제거-nerd-fonts)
- [쉘 Alias 추가](#쉘-alias-추가)
- [쉘 함수 추가](#쉘-함수-추가)
- [런타임 버전 관리 (mise)](#런타임-버전-관리-mise)
- [broot 설정 변경](#broot-설정-변경)
- [Git 설정 변경](#git-설정-변경)
- [macOS 시스템 설정 변경](#macos-시스템-설정-변경)
- [Homebrew GUI 앱 추가](#homebrew-gui-앱-추가)
- [새 프로그램 모듈 추가](#새-프로그램-모듈-추가)
- [폴더 액션 추가](#폴더-액션-추가)
- [Secrets 추가](#secrets-추가)
- [대외비 설정 추가](#대외비-설정-추가-쉘-함수-gitignore-등)
- [Claude Code Private 플러그인 추가](#claude-code-private-플러그인-추가)
- [VSCode(Cursor) 확장 프로그램 관리](#vscodecursor-확장-프로그램-관리)

---

## Rebuild vs Update 이해하기

Nix에서 `rebuild`와 `update`는 서로 다른 개념입니다.

### 핵심 차이점

| 명령어 | 하는 일 | flake.lock | 패키지 버전 |
|--------|---------|------------|-------------|
| `darwin-rebuild switch` | 설정 파일 변경사항 적용 | 변경 안 함 | 고정된 버전 유지 |
| `nix flake update` | 의존성(nixpkgs 등) 최신화 | **변경됨** | 최신 버전으로 |

### Rebuild란?

`flake.nix`, `home.nix` 등 **설정 파일의 변경사항을 시스템에 적용**하는 것입니다.

```bash
# 설정 파일 수정 후 적용
darwin-rebuild switch --flake .
```

- 패키지를 추가/제거하거나 설정을 변경했을 때 사용
- `flake.lock`에 기록된 버전 그대로 유지
- 네트워크 요청 최소화 (캐시된 패키지 사용)

### Update란?

`flake.lock`에 기록된 **의존성(nixpkgs, home-manager 등)을 최신 커밋으로 업데이트**하는 것입니다.

```bash
# 의존성 업데이트 후 적용
nix flake update
darwin-rebuild switch --flake .
```

- nixpkgs가 업데이트되면 그 안의 모든 패키지(neovim, git 등)가 새 버전으로 바뀔 수 있음
- 네트워크에서 새 버전을 다운로드하므로 시간이 더 걸림

> **참고**: `nix flake update`는 각 패키지의 "최신 릴리스"가 아닌, **nixpkgs 저장소의 최신 커밋**을 가져옵니다. 패키지의 새 버전이 nixpkgs에 반영되기까지 며칠 지연될 수 있습니다.

### 언제 Rebuild만 하면 되는가?

```
✅ flake.nix, home.nix 등 설정 파일을 수정했을 때
✅ 새 패키지를 추가했을 때 (예: programs.htop.enable = true)
✅ 기존 패키지 설정을 변경했을 때
✅ 다른 기기와 동기화할 때 (git pull 후)
✅ 현재 설정을 다시 적용하고 싶을 때
```

### 언제 Update가 필요한가?

```
✅ 보안 취약점이 발견되어 패치가 필요할 때
✅ 특정 패키지의 새 기능/버그 수정이 필요할 때
✅ 주기적인 시스템 업데이트 (예: 월 1회)
```

### 권장 사용 패턴 (집-회사 동기화)

```bash
# 집 (메인 기기): 여기서만 update
nix flake update
darwin-rebuild switch --flake .
git add flake.lock && git commit -m "update: flake.lock" && git push

# 회사 (서브 기기): rebuild만 (--offline으로 더 빠르게)
git pull
darwin-rebuild switch --flake . --offline
```

### `--offline` 플래그

네트워크 요청 없이 로컬 캐시만 사용하여 빠르게 빌드합니다.

```bash
darwin-rebuild switch --flake . --offline
```

**사용 조건**:
- `flake.lock`이 이미 동기화되어 있어야 함 (git pull 후)
- 새 패키지를 추가하지 않았어야 함 (캐시에 없으면 에러)

**장점**: 네트워크 확인 단계를 건너뛰어 빌드 시간 단축

### Update 시 주의사항

```bash
# 1. update 전에 현재 상태 확인
git status  # 변경사항 없는지 확인

# 2. update 실행
nix flake update

# 3. 빌드 테스트 (switch 대신 build로 먼저 테스트)
darwin-rebuild build --flake .

# 4. 문제 없으면 적용
darwin-rebuild switch --flake .

# 5. 문제 있으면 롤백
git checkout flake.lock  # update 취소
darwin-rebuild switch --flake .  # 이전 버전으로 복구
```

### 요약

```bash
# 평소 (설정 변경 후)
darwin-rebuild switch --flake .

# 빠른 빌드 (캐시만 사용)
darwin-rebuild switch --flake . --offline

# 패키지 버전 업그레이드 (월 1회 정도)
nix flake update && darwin-rebuild switch --flake .
```

### 시스템 업데이트 워크플로우

1. **변경사항 미리보기** (선택사항):
   ```bash
   nrp  # 빌드 후 변경될 패키지 목록 확인
   ```

2. **시스템 적용**:
   ```bash
   nrs  # 미리보기 → 확인 → 적용
   ```

3. **히스토리 확인** (선택사항):
   ```bash
   nrh  # 과거 시스템 세대 변경 이력
   ```

**팁:**
- `nrp`로 먼저 확인하면 예상치 못한 패키지 변경을 감지할 수 있습니다
- `nrs` 실행 시 변경사항을 보여주고 확인을 요청합니다

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

### 추가 가능한 Nerd Fonts 예시

> **현재 설치된 폰트**: `fira-code`, `jetbrains-mono` (2개)

아래 표는 추가로 설치할 수 있는 인기 Nerd Fonts 목록입니다:

| 패키지명 | 폰트 이름 |
|---------|----------|
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

> **대외비 gitignore**: zfw worktree 디렉토리 패턴 (`__wt__*`) 등은 Private 저장소(`nixos-config-secret/green/git.nix`)에서 `lib.mkAfter`로 추가됩니다.

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

## Claude Code Private 플러그인 추가

프로젝트 전용 Claude Code 플러그인(commands, skills)을 Private 저장소에서 관리합니다.

### 기본 워크플로우

```bash
# 1. Private 저장소에서 플러그인 생성/수정
cd ~/IdeaProjects/nixos-config-secret
# plugins/ 디렉토리에서 작업...

# 2. 커밋 & 푸시
git add . && git commit -m "feat: add plugin" && git push

# 3. Public 저장소에서 적용
cd ~/IdeaProjects/nixos-config
nix flake update nixos-config-secret
sudo darwin-rebuild switch --flake .
```

### 핵심 포인트

| 항목 | 설명 |
|------|------|
| 위치 | `nixos-config-secret/plugins/` |
| 수정 반영 | symlink이므로 즉시 적용 (darwin-rebuild 불필요) |
| 동기화 | git pull → nix flake update → darwin-rebuild |

> **상세 가이드**: 플러그인 구조, Nix 모듈 등록, 상세 예시는 `nixos-config-secret/README.md`를 참고하세요.

---

## VSCode(Cursor) 확장 프로그램 관리

Cursor 확장 프로그램 관리는 별도 문서를 참고하세요: [CURSOR_EXTENSIONS.md](CURSOR_EXTENSIONS.md)
