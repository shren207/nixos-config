# Cursor 확장 프로그램 관리

이 프로젝트는 `nix-vscode-extensions`를 사용하여 Cursor 확장 프로그램을 선언적으로 관리합니다.

**파일**: `modules/darwin/programs/cursor/default.nix`

## 목차

- [관리 구조](#관리-구조)
- [왜 이 구조인가?](#왜-이-구조인가)
- [확장 프로그램 추가 방법](#확장-프로그램-추가-방법)
- [확장 프로그램 검색 팁](#확장-프로그램-검색-팁)
- [open-vsx vs vscode-marketplace 판별](#open-vsx-vs-vscode-marketplace-판별)
- [확장 프로그램 제거](#확장-프로그램-제거)
- [현재 Nix로 관리되는 확장 목록](#현재-nix로-관리되는-확장-목록)
- [내부 동작 방식](#내부-동작-방식)
- [주의사항](#주의사항)

---

## 관리 구조

```
Cursor 앱 설치: Homebrew Cask (homebrew.nix)
확장 관리:      Nix + home.file (cursor/default.nix)
설정 파일:      Nix store 심볼릭 링크 (읽기 전용)
단축키 파일:    mkOutOfStoreSymlink (양방향 수정)
```

---

## 왜 이 구조인가?

| 방식 | 앱 설치 | 확장 관리 | 장점 |
|------|---------|----------|------|
| Homebrew only | Homebrew Cask | Cursor UI | 간편하지만 선언적 관리 불가 |
| Nix only | `pkgs.code-cursor` | `programs.vscode` | Spotlight에 Cursor 2개 표시 문제 |
| **현재 방식** | Homebrew Cask | `home.file` + `buildEnv` | 중복 없이 선언적 관리 |

---

## 확장 프로그램 추가 방법

### 1. 확장 프로그램 ID 찾기

[VSCode Marketplace](https://marketplace.visualstudio.com/)에서 확장 프로그램을 검색합니다.

```
URL: https://marketplace.visualstudio.com/items?itemName=atommaterial.a-file-icon-vscode
                                                         └─────────────┬───────────────┘
                                                                    확장 ID
```

확장 ID 형식: `publisher.extension-name` (예: `atommaterial.a-file-icon-vscode`)

### 2. 마켓플레이스 선택 및 추가

- **open-vsx**: 오픈소스 확장 (대부분의 확장)
- **vscode-marketplace**: Microsoft/비공개 확장 (open-vsx에 없는 경우)

```nix
# modules/darwin/programs/cursor/default.nix
cursorExtensions =
  # open-vsx (오픈소스)
  (with pkgs.open-vsx; [
    dbaeumer.vscode-eslint
    esbenp.prettier-vscode
    # 새 확장 추가
  ])

  # vscode-marketplace (open-vsx에 없는 확장)
  ++ (with pkgs.vscode-marketplace; [
    atommaterial.a-file-icon-vscode
    # 새 확장 추가
  ]);
```

### 3. 적용

```bash
git add modules/darwin/programs/cursor/default.nix
darwin-rebuild switch --flake .
# Cursor 재시작 또는 "Reload Window"
```

---

## 확장 프로그램 검색 팁

### 방법 1: VSCode Marketplace 웹사이트

1. https://marketplace.visualstudio.com/ 접속
2. 확장 프로그램 검색 (예: "gutter preview")
3. 확장 페이지에서 "Unique Identifier" 확인

### 방법 2: Cursor 내에서 확인

1. Cursor에서 확장 프로그램 탭 열기 (`Cmd+Shift+X`)
2. 설치된 확장 프로그램 클릭
3. 확장 ID 복사 (우클릭 → "Copy Extension ID")

---

## open-vsx vs vscode-marketplace 판별

```bash
# darwin-rebuild 시도 후 에러 확인
darwin-rebuild switch --flake .

# 에러 메시지 예시:
# error: attribute 'a-file-icon-vscode' missing
# → open-vsx에 없음, vscode-marketplace로 이동 필요
```

또는 https://open-vsx.org/ 에서 직접 검색

---

## 확장 프로그램 제거

```nix
cursorExtensions = with pkgs.open-vsx; [
  dbaeumer.vscode-eslint
  # esbenp.prettier-vscode  # ← 주석 처리 또는 삭제
];
```

---

## 현재 Nix로 관리되는 확장 목록

| 확장 | 마켓플레이스 | 용도 |
|------|-------------|------|
| `dbaeumer.vscode-eslint` | open-vsx | ESLint |
| `esbenp.prettier-vscode` | open-vsx | Prettier |
| `usernamehw.errorlens` | open-vsx | 인라인 에러 |
| `streetsidesoftware.code-spell-checker` | open-vsx | 맞춤법 |
| `aaron-bond.better-comments` | open-vsx | 주석 하이라이트 |
| `eamodio.gitlens` | open-vsx | Git 통합 |
| `github.vscode-pull-request-github` | open-vsx | GitHub PR |
| `bbenoist.nix` | open-vsx | Nix 언어 |
| `buenon.scratchpads` | open-vsx | 스크래치패드 |
| `kisstkondoros.vscode-gutter-preview` | open-vsx | 이미지 프리뷰 |
| `k--kato.intellij-idea-keybindings` | open-vsx | IntelliJ 키바인딩 |
| `anthropic.claude-code` | open-vsx | Claude Code |
| `fuzionix.code-case-converter` | vscode-marketplace | 케이스 변환 |
| `wix.vscode-import-cost` | vscode-marketplace | Import 비용 |
| `imekachi.webstorm-darcula` | vscode-marketplace | 테마 |
| `atommaterial.a-file-icon-vscode` | vscode-marketplace | 파일 아이콘 |

---

## 내부 동작 방식

```
1. cursorExtensions 리스트에서 각 확장 derivation 수집
2. pkgs.buildEnv로 모든 확장을 단일 디렉토리로 통합
3. extensions.json 생성 (Cursor GUI 인식용)
4. ~/.cursor/extensions → Nix store 심볼릭 링크
```

### extensions.json 구조

Cursor가 GUI에 표시하기 위해 필요한 형식:

```json
{
  "identifier": {"id": "dbaeumer.vscode-eslint"},
  "version": "3.0.16",
  "location": {"$mid": 1, "path": "/Users/.../.cursor/extensions/...", "scheme": "file"},
  "relativeLocation": "dbaeumer.vscode-eslint",
  "metadata": {"installedTimestamp": 0, "targetPlatform": "undefined"}
}
```

---

## 주의사항

### 확장 디렉토리는 읽기 전용

`~/.cursor/extensions`가 Nix store로 심볼릭 링크되어 있어:
- Cursor에서 확장을 수동으로 추가/제거할 수 없음
- 확장 추가/제거는 반드시 `default.nix` 수정 후 `darwin-rebuild` 실행

### settings.json은 읽기 전용

`home.file`로 관리되므로 Nix store 심볼릭 링크:
- Cursor 내에서 설정 변경 불가
- 설정 변경은 `modules/darwin/programs/cursor/files/settings.json` 직접 수정

### keybindings.json은 양방향 수정 가능

`mkOutOfStoreSymlink`로 관리되므로:
- Cursor에서 단축키 변경 가능
- 변경사항이 `nixos-config`에 바로 반영됨

### darwin-rebuild 후 Cursor 새로고침 필요

`darwin-rebuild switch` 실행 후:
- "Extensions have been modified on disk" 경고가 표시될 수 있음
- "Reload Window" 클릭 또는 Cursor 재시작으로 해결
