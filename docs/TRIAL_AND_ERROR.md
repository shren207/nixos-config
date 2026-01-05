# Trial and Error 기록

이 문서는 nixos-config 저장소에서 시도했다가 실패한 작업들을 기록합니다.

## 목차

- [2025-01-05: inshellisense tmux 호환성 시도 및 포기](#2025-01-05-inshellisense-tmux-호환성-시도-및-포기)
- [2025-01-05: inshellisense useNerdFont=true 설정 실패](#2025-01-05-inshellisense-usenerdfonttrue-설정-실패)
- [2024-12-25: duti로 .html/.htm 기본 앱 설정 실패](#2024-12-25-duti로-htmlhtm-기본-앱-설정-실패)
- [2024-12-24: Anki 애드온 Nix 선언적 관리 시도 (보류)](#2024-12-24-anki-애드온-nix-선언적-관리-시도-보류)
  - [목표](#목표)
  - [시도한 방식들](#시도한-방식들)
    - [방식 1: AnkiWeb 직접 다운로드 (실패)](#방식-1-ankiweb-직접-다운로드-실패)
    - [방식 2: 로컬 소스 패키징 (반려)](#방식-2-로컬-소스-패키징-반려)
    - [방식 3: GitHub 저장소 활용 (보류)](#방식-3-github-저장소-활용-보류)
  - [방식 3의 실패 원인](#방식-3의-실패-원인)
  - [교훈](#교훈)
  - [대상 애드온 목록 (참고용)](#대상-애드온-목록-참고용)
  - [결론](#결론)

---

## 2025-01-05: inshellisense tmux 호환성 시도 및 포기

### 배경

inshellisense를 설치한 후 터미널에서는 정상 작동하지만, tmux 세션 내부에서는 자동완성 UI가 표시되지 않는 문제 발생.

### 증상

```bash
# tmux 외부: 정상 작동
git <Space>  # IDE 스타일 자동완성 드롭다운 표시됨

# tmux 내부: 작동 안 함
tmux
git <Space>  # 자동완성 표시 안 됨

# is 명령어 실행 시
❯ is
inshellisense session [live]  # 세션은 활성화되지만 UI 미표시
```

### 시도한 방법들

#### 시도 1: TMUX 환경변수 해제 (부분 성공)

```bash
if [[ -n "${TMUX}" ]]; then
  _IS_TMUX_BACKUP="$TMUX"
  unset TMUX
fi
eval "$(is init zsh)"
# 복원...
```

**결과**: 간헐적으로만 작동. 터미널 창이 완전히 새로고침되는 경우에만 작동.

#### 시도 2: TMUX + TMUX_PANE 환경변수 해제 (부분 성공)

```bash
if [[ -n "${TMUX}" ]]; then
  _IS_TMUX_BACKUP="$TMUX"
  _IS_TMUX_PANE_BACKUP="${TMUX_PANE:-}"
  unset TMUX TMUX_PANE
fi
eval "$(is init zsh)"
# 복원...
```

**결과**: 여전히 간헐적. "inshellisense session [live]"가 출력되면 작동 안 함.

#### 시도 3: is -s zsh 직접 실행 (실패)

```bash
if [[ -n "${TMUX}" ]]; then
  TMUX= TMUX_PANE= is -s zsh
else
  is -s zsh
fi
exit
```

**결과**: 완전히 작동하지 않음. 이전보다 악화.

### 원인 분석

1. **inshellisense 개발팀의 공식 답변** ([Issue #204](https://github.com/microsoft/inshellisense/issues/204)):
   > "tmux는 다중 쉘 멀티플렉싱이므로 하나의 세션으로 여러 프롬프트 지점을 추적하는 것이 구조적으로 불가능"

2. **PTY 중첩 문제**:
   - tmux 내부에서 inshellisense를 실행하면 중첩 PTY 발생
   - Terminal → tmux PTY → inshellisense PTY → zsh
   - UI 렌더링이 제대로 전달되지 않음

3. **TMUX 환경변수 우회의 한계**:
   - 환경변수를 해제해도 inshellisense 코드에서 TMUX를 직접 감지하지 않음
   - 문제는 환경변수가 아니라 PTY/터미널 레이어 차원

### 최종 해결책: 환경별 분기

tmux 내부에서 inshellisense를 사용하는 것을 포기하고, 대안으로 fzf-tab을 도입:

| 환경 | 도구 | 설명 |
|------|------|------|
| tmux 외부 | inshellisense | IDE 스타일 자동완성 |
| tmux 내부 | fzf-tab | 퍼지 검색 자동완성, tmux popup 지원 |

```nix
# inshellisense: tmux 외부에서만 실행
if [[ -z "${TMUX}" ]] && command -v is >/dev/null 2>&1; then
  eval "$(is init zsh)"
fi

# fzf-tab: tmux 내부에서 팝업 사용
if [[ -n "${TMUX}" ]]; then
  zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
fi
```

### 교훈

1. **공식 지원 여부 확인 필수**
   - 도구 도입 전 GitHub Issues에서 환경 호환성 확인
   - "workaround"는 근본적 해결이 아님

2. **대안 도구 준비**
   - 하나의 도구가 모든 환경에서 작동하지 않을 수 있음
   - 환경별 분기로 최적의 사용자 경험 제공

3. **PTY 중첩은 복잡함**
   - tmux, screen 같은 터미널 멀티플렉서와의 호환성은 별도 고려 필요
   - 특히 UI 렌더링이 관련된 도구에서 문제 발생 가능성 높음

---

## 2025-01-05: inshellisense useNerdFont=true 설정 실패

### 배경

inshellisense(Microsoft의 IDE 스타일 쉘 자동완성 도구)를 nixos-config에 추가하면서, Nerd Font 아이콘을 사용하도록 `useNerdFont = true` 옵션을 설정.

### 시도한 내용

```toml
# ~/.config/inshellisense/rc.toml
useNerdFont = true

[bindings.acceptSuggestion]
key = "return"
# ...
```

### 결과

```
❯ is
/Users/glen/.config/inshellisense/rc.toml is invalid: data must NOT have additional properties
```

inshellisense가 실행되지 않고 설정 파일 유효성 검사 오류 발생.

### 원인 분석

1. **nixpkgs 버전과 최신 버전의 차이**
   - nixpkgs 버전: `0.0.1-rc.21`
   - npm 최신 버전에서는 `useNerdFont` 옵션 지원
   - 구버전에서는 해당 옵션이 스키마에 없어 "additional properties" 오류 발생

2. **관련 이슈**
   - GitHub Issue: [useNerdFont break inshellisense #365](https://github.com/microsoft/inshellisense/issues/365)
   - 해당 이슈에서도 비슷한 문제가 보고됨

### 해결 방법

**`useNerdFont` 옵션 제거 (적용)**

```toml
# useNerdFont = true  # 제거

[bindings.acceptSuggestion]
key = "return"

[bindings.nextSuggestion]
key = "tab"
# ...
```

### 교훈

1. **nixpkgs 패키지 버전은 npm 최신 버전과 다를 수 있음**
   - 문서나 GitHub README의 옵션이 nixpkgs 버전에서 지원되지 않을 수 있음
   - 설정 전 `<패키지> --version`으로 버전 확인 필요

2. **JSON Schema 유효성 검사**
   - inshellisense는 TOML → JSON 변환 후 JSON Schema로 유효성 검사
   - `additionalProperties: false` 설정으로 알려지지 않은 속성 차단

3. **대안**
   - 최신 기능이 필요하면 npm global 설치 고려 (`npm install -g @microsoft/inshellisense`)
   - nixpkgs 버전 업데이트 대기

---

## 2024-12-25: duti로 .html/.htm 기본 앱 설정 실패

### 배경

macOS에서 텍스트/코드 파일(.txt, .md, .js 등)을 더블클릭 시 Xcode 대신 Cursor로 열리도록 `duti`를 사용하여 설정.

### 시도한 내용

```nix
codeExtensions = [
  "txt" "text" "md" "mdx" "js" "jsx" "ts" "tsx" "mjs" "cjs"
  "json" "yaml" "yml" "toml" "html" "htm" "css" "scss" "sass" "less"
  # ... 기타 확장자
];

home.activation.setCursorAsDefaultEditor = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  ${lib.concatMapStringsSep "\n" (ext:
    "${pkgs.duti}/bin/duti -s ${cursorBundleId} .${ext} all"
  ) codeExtensions}
'';
```

### 결과

```
failed to set com.todesktop.230313mzl4w4u92 as handler for public.html (error -54)
```

- **error -54**: macOS 권한 에러 (`permErr`)
- `.html`, `.htm` 확장자만 실패, 나머지는 성공

### 원인 분석

1. **Safari가 `public.html` UTI를 시스템 수준에서 선점**
   - macOS는 Safari를 HTML 파일의 기본 핸들러로 강하게 보호
   - `duti`가 `public.html` UTI 설정 시도 시 권한 거부됨

2. **duti의 확장자 설정 동작**
   - `.html` 확장자 설정 시 내부적으로 `public.html` UTI도 함께 설정 시도
   - UTI 설정 실패 시 에러 출력 (치명적이지 않음)

### 해결 방법

**방법 1: 확장자 목록에서 html/htm 제거 (적용)**

```nix
codeExtensions = [
  "txt" "text" "md" "mdx" "js" "jsx" "ts" "tsx" "mjs" "cjs"
  "json" "yaml" "yml" "toml" "css" "scss" "sass" "less"  # html, htm 제거
  # ...
];
```

**방법 2: Finder에서 수동 설정 (필요시)**

1. `.html` 파일 우클릭 → 정보 가져오기 (Cmd+I)
2. "다음으로 열기" → Cursor 선택 → "모두 변경" 클릭

### 교훈

1. **macOS Launch Services는 시스템 앱(Safari, Preview 등)을 보호함**
   - 특정 UTI는 사용자가 변경할 수 없도록 잠겨 있음
   - CLI 도구로 강제 변경 불가

2. **duti 에러는 치명적이지 않음**
   - 개별 확장자 설정 실패해도 다른 확장자에 영향 없음
   - activation 전체가 중단되지 않음

3. **HTML 파일은 브라우저로 여는 것이 macOS 기본 정책**
   - 개발자 워크플로우와 충돌하는 부분
   - 필요시 수동 설정으로 대응

---

## 2024-12-24: Anki 애드온 Nix 선언적 관리 시도 (보류)

### 목표

Anki 애드온 10개를 Nix로 선언적 관리하여 재현 가능한 환경 구축.

### 시도한 방식들

#### 방식 1: AnkiWeb 직접 다운로드 (실패)

AnkiWeb에서 애드온을 직접 다운로드하여 관리하는 방식.

```
https://ankiweb.net/shared/download/{addon_id}
```

**실패 원인:** AnkiWeb의 다운로드 URL은 직접 접근을 차단함. 브라우저 세션/쿠키가 필요하여 `fetchurl`로 다운로드 불가.

---

#### 방식 2: 로컬 소스 패키징 (반려)

애드온 소스 코드를 nixos-config 저장소에 직접 포함하여 관리하는 방식.

```
modules/darwin/programs/anki/
└── sources/
    ├── 24411424/
    ├── 31746032/
    └── ...
```

**반려 사유:** 각 애드온의 소스코드(수백 개 파일)를 전부 git으로 관리해야 하므로 저장소 규모가 너무 커짐. diff도 과도하게 많이 발생.

---

#### 방식 3: GitHub 저장소 활용 (보류)

`fetchFromGitHub`를 사용하여 GitHub에서 애드온 소스를 다운로드하는 방식.

```nix
pkgs.fetchFromGitHub {
  owner = "addon-author";
  repo = "addon-repo";
  rev = "<commit-hash>";
  sha256 = "...";
};
```

**생성했던 파일 구조:**

```
modules/darwin/programs/anki/
├── default.nix          # 메인 모듈
├── addons.nix           # fetchFromGitHub 애드온 정의
└── files/               # 설정 파일
    ├── customize-shortcuts-meta.json
    ├── add-hyperlink-config.json
    ├── note-linker-config.json
    └── add-table-config.json
```

### 방식 3의 실패 원인

#### 1. GitHub 저장소 구조 불일치

대부분의 Anki 애드온 GitHub 저장소는 개발용 구조로 되어 있음:
- `src/` 디렉토리에 소스 코드
- `forms6/` (Qt Designer UI 파일에서 빌드되는 Python 모듈)이 빌드되어야 함
- AnkiWeb 배포판에만 빌드된 파일이 포함됨

| 애드온 | 문제점 |
|---|---|
| Add Table (1237621971) | `forms6` 모듈 누락 |
| Add Hyperlink (318752047) | `forms6` 모듈 누락 |
| Customize Shortcuts (24411424) | Qt 버전 호환성 문제 |

#### 2. 저장소별 srcDir 상이

각 저장소마다 실제 애드온 파일 위치가 다름:
- `custom_shortcuts/` (24411424)
- `src/` (31746032, 318752047, 1237621971)
- `src/image_occlusion_enhanced/` (1374772155)
- `src/enhanced_cloze/` (1990296174)
- `.` 루트 (1077002392, 1124670306)

### 교훈

1. **AnkiWeb 배포판 vs GitHub 소스는 다르다**
   - GitHub 소스에는 빌드 과정에서 생성되는 파일(`forms6/` 등)이 없음
   - `fetchFromGitHub` 방식은 대부분의 애드온에서 작동하지 않음

2. **작업 전 항상 백업**
   - 데이터를 삭제하기 전에 반드시 백업 생성
   - 특히 설정 파일, 커스텀 설정이 있는 경우

3. **Anki 애드온 관리의 현실적 대안**
   - AnkiWeb에서 직접 설치/관리 (기존 방식)
   - AnkiWeb API를 사용한 다운로드 (불안정할 수 있음)
   - 애드온별 릴리스 아티팩트 사용 (있는 경우에만)

### 대상 애드온 목록 (참고용)

| ID | 이름 |
|---|---|
| 24411424 | Customize Keyboard Shortcuts |
| 31746032 | AnkiWebView Inspector |
| 318752047 | Add Hyperlink |
| 805891399 | Extended Editor for Field |
| 1077002392 | Anki Note Linker |
| 1124670306 | Set Added Date |
| 1237621971 | Add Table |
| 1374772155 | Image Occlusion Enhanced |
| 1990296174 | Enhanced Cloze |
| 2491935955 | Quick Colour Changing |

### 결론

Anki 애드온의 Nix 선언적 관리는 **현실적으로 어려움**. AnkiWeb에서 직접 관리하는 것이 가장 안정적.
