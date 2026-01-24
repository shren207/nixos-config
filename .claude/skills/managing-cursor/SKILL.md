---
name: managing-cursor
description: |
  This skill should be used when the user installs Cursor extensions,
  or encounters "Extensions have been modified on disk" warning,
  extension loading issues. Covers extensions.json Nix management.
---

# Cursor 확장 관리

Cursor IDE 확장 프로그램 관리 가이드입니다.

## Known Issues

**Spotlight에 Cursor 2개 표시**
- Homebrew Cask로 설치된 Cursor와 다른 경로의 Cursor가 공존
- 해결: `/Applications/Cursor.app` 외 다른 Cursor 삭제

**"Extensions have been modified on disk" 경고**
- Nix로 확장이 관리되어 외부 수정 감지됨
- 무시해도 됨, 재시작하면 사라짐

**GUI에서 확장 설치/제거 안 됨**
- extensions.json이 Nix로 관리되어 읽기 전용
- 해결: Nix 설정에서 추가/제거 후 `nrs`

## 빠른 참조

### 확장 관리 구조

```
~/.cursor/
├── extensions/           # 확장 파일 (Nix buildEnv)
├── extensions.json       # 확장 목록 (mkOutOfStoreSymlink)
└── settings.json         # 설정 (mkOutOfStoreSymlink)
```

**mkOutOfStoreSymlink 패턴**
- Nix store 대신 실제 파일 경로로 심볼릭 링크
- 양방향 수정 가능

### 확장 추가 방법

1. VSCode Marketplace에서 확장 ID 찾기
2. `modules/darwin/programs/cursor/default.nix`에 추가:

```nix
extensions = {
  # open-vsx.org에서 설치
  vscode-open-vsx = [
    "dbaeumer.vscode-eslint"
    "esbenp.prettier-vscode"
  ];
  # marketplace.visualstudio.com에서 설치
  vscode-marketplace = [
    "ms-vscode.vscode-typescript-next"
  ];
};
```

3. `nrs` 실행

### 확장 소스

| 소스 | 용도 | 예시 |
|------|------|------|
| `vscode-open-vsx` | 오픈소스 확장 | ESLint, Prettier |
| `vscode-marketplace` | MS 전용 확장 | TypeScript, C# |

## 자주 발생하는 문제

1. **확장 0개 표시**: extensions.json 심볼릭 링크 확인
2. **설치 안 됨**: Nix 설정에서 추가 필요
3. **Spotlight 중복**: 불필요한 Cursor 앱 삭제

## 레퍼런스

- 트러블슈팅: [references/troubleshooting.md](references/troubleshooting.md)
- 확장 목록: [references/extensions.md](references/extensions.md)
