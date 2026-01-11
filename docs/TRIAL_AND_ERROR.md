# Trial and Error 기록

이 문서는 nixos-config 저장소에서 시도했다가 실패한 작업들을 기록합니다.

## 목차

- [2026-01-11: Claude Code 유령 플러그인 해결](#2026-01-11-claude-code-유령-플러그인-해결)
- [2026-01-10: cat → bat alias 제거 (호환성 문제)](#2026-01-10-cat--bat-alias-제거-호환성-문제)
- [2026-01-10: VS Code customLabels에서 동적 앱 이름 추출 실패](#2026-01-10-vs-code-customlabels에서-동적-앱-이름-추출-실패)
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

## 2026-01-11: Claude Code 유령 플러그인 해결

> 테스트 환경: Claude Code 2.1.4, macOS

### 배경

`settings.json`의 `enabledPlugins`에서 플러그인 프로퍼티를 직접 삭제하면 **유령 플러그인(ghost plugin)** 문제가 발생:

| 상태 | 증상 |
|------|------|
| `/plugin` 명령 | 플러그인이 "설치됨"으로 표시 |
| 설정 변경 | 활성화/비활성화 토글 불가 |
| 플러그인 기능 | 동작하지 않음 |

### 시도 1: 마켓플레이스 재설치 (실패)

```bash
claude plugin marketplace remove claude-plugins-official
claude plugin marketplace add anthropics/claude-plugins-official
```

**결과**: ❌ 유령 플러그인 여전히 존재

마켓플레이스를 재설치해도 기존 `enabledPlugins` 상태와의 동기화 문제는 해결되지 않음.

### 해결: settings.json에 유령 플러그인 직접 명시

**원리**: Claude Code가 플러그인을 인식하려면 `enabledPlugins`에 해당 플러그인이 존재해야 함. 유령 상태에서는 CLI도 플러그인을 찾지 못함.

**해결 순서**:

1. `settings.json`에 유령 플러그인을 다시 명시:
   ```json
   "enabledPlugins": {
     "ghost-plugin-name@marketplace": true
   }
   ```

2. Claude Code 재시작 (또는 `/plugin` 명령으로 확인)

3. CLI로 플러그인 제거:
   ```bash
   claude plugin uninstall ghost-plugin-name@marketplace --scope user
   ```

4. 정상적으로 제거됨 확인

### 교훈

1. **플러그인 제거는 반드시 CLI 사용**
   - `settings.json` 직접 편집으로 플러그인을 삭제하면 동기화 문제 발생
   - `claude plugin uninstall` 명령 사용 필수

2. **유령 플러그인 복구 방법**
   - `settings.json`에 유령 플러그인을 다시 추가하여 Claude Code가 인식하게 만든 후 CLI로 제거
   - 마켓플레이스 재설치로는 해결 불가

3. **Nix 선언적 관리 시 주의**
   - `mkOutOfStoreSymlink`로 `settings.json` 관리 시, 직접 편집이 가능하므로 실수 가능
   - 플러그인 관련 변경은 항상 Claude Code CLI 사용 권장

---

## 2026-01-10: cat → bat alias 제거 (호환성 문제)

> 테스트 환경: bat 0.26.1, macOS cat

### 배경

`cat` 명령어를 `bat`으로 alias하여 기본 파일 출력에 구문 강조를 적용하려 했음.

```nix
# modules/shared/programs/shell/default.nix
home.shellAliases = {
  # 파일 출력 (bat 사용)
  cat = "bat";
};
```

### 기대

`bat`이 `cat`의 완전한 상위호환이라고 가정:

- 모든 `cat` 옵션이 `bat`에서도 동일하게 작동
- 기존 스크립트나 명령어가 영향받지 않음

### 실패 원인

**`bat`은 `cat`의 상위호환이 아님.** 일부 옵션은 호환되지만, 핵심 진단 옵션들이 에러를 발생시킴.

macOS cat 옵션: `cat [-belnstuv]`

| 옵션 | macOS cat 동작 | bat 0.26.1 동작 |
|------|----------------|-----------------|
| `-v` | 비출력 문자 표시 (`^A`, `^[` 등) | ❌ 에러: `unexpected argument '-v' found` |
| `-e` | 줄 끝에 `$` 표시 + `-v` 암시 | ❌ 에러 |
| `-t` | 탭을 `^I`로 표시 + `-v` 암시 | ❌ 에러 |
| `-b` | 비어있지 않은 줄에만 번호 | ❌ 에러 |
| `-n` | 모든 줄에 번호 | ✅ 동일 (`-n, --number`) |
| `-s` | 연속 빈 줄 압축 | ✅ 동일 (`-s, --squeeze-blank`) |
| `-u` | 버퍼링 비활성화 | ✅ 동일 (`-u, --unbuffered`) |
| `-A` | ❌ macOS에서 미지원 (GNU cat 전용) | ✅ 지원 (`-A, --show-all`) |

**실제 문제 상황:**

```bash
# CSI u 모드 진단 시 키 입력 테스트 (TROUBLESHOOTING.md 참조)
cat -v
# 기대: 입력 대기 후 비출력 문자 표시
# 실제 (alias 적용 시): 에러 발생
#   error: unexpected argument '-v' found
#     tip: to pass '-v' as a value, use '-- -v'
```

### 해결

alias 제거:

```nix
home.shellAliases = {
  # cat = "bat";  # 삭제: -v, -e, -t, -b 옵션 비호환
};
```

`bat`은 독립적으로 사용하고, `cat`은 원본 유지.

### 교훈

1. **CLI 도구 alias 전에 옵션 호환성 확인 필수**
   - "상위호환"이라는 가정은 위험
   - 특히 시스템 유틸리티(`cat`, `ls`, `grep` 등)는 옵션 체계가 표준화되어 있음

2. **alias가 기존 스크립트/문서에 영향을 줄 수 있음**
   - 문서에 `cat -v` 같은 명령어가 있으면 alias로 인해 오작동
   - 디버깅 시 혼란 야기

3. **대체 도구는 명시적으로 호출하는 것이 안전**
   - `bat file.txt` (명시적)
   - `cat file.txt` (alias로 bat 호출) ← 혼란 유발

4. **부분 호환은 더 위험할 수 있음**
   - `-n`, `-s`, `-u`는 호환되어 평소에는 문제없이 작동
   - 특정 상황(진단, 디버깅)에서만 `-v` 등을 사용할 때 갑자기 실패
   - "잘 되다가 갑자기 안 됨" → 원인 파악이 어려움

---

## 2026-01-10: VS Code customLabels에서 동적 앱 이름 추출 실패

> 테스트 환경: Cursor 2.3.33 (VS Code 1.93.0 기반)

### 배경

Next.js Page Router + Turbopack 모노레포 구조에서 에디터 탭 레이블을 커스터마이징하려 했음. 여러 앱(`web`, `admin`, `mobile` 등)의 `pages/` 폴더에서 동일한 파일명(`index.tsx`)이 열릴 때 구분하기 어려운 문제.

**목표**: `apps/admin/pages/settings/index.tsx` → `(admin) settings/index.tsx`

### 시도 1: Named Capture Group 문법 (실패)

정규식의 Named Capture Group을 사용하여 앱 이름을 동적으로 추출하려 시도.

```json
"**/apps/${app:([^/]+)}/pages/**/index.{ts,tsx}": "(${app}) ${dirname}/index.${extname}"
```

**결과**: 동작하지 않음.

**원인**: VS Code의 `customLabels.patterns`는 Named Capture Group이나 정규식 캡처를 **지원하지 않음**.

### 시도 2: `**` 와일드카드 + `${dirname(N)}` 조합 (실패)

`**` 패턴으로 가변 깊이 경로를 매칭하고, `${dirname(N)}`으로 특정 위치의 폴더명을 추출하려 시도.

```json
"**/apps/*/pages/**/index.{ts,tsx}": "(${dirname(3)}) ${dirname}/index.${extname}"
```

**결과**: 앱 이름이 아닌 다른 폴더명이 표시됨.

| 경로 | 기대 결과 | 실제 결과 |
|------|----------|----------|
| `apps/admin/pages/settings/index.tsx` | `(admin) settings/index.tsx` | `(apps) settings/index.tsx` |
| `apps/admin/pages/a/b/index.tsx` | `(admin) b/index.tsx` | `(pages) b/index.tsx` |

**원인**: `${dirname(N)}`은 **파일 기준 절대 인덱싱**이므로, `**`가 매칭하는 경로 깊이에 따라 N번째 폴더가 달라짐.

### VS Code customLabels의 한계

**지원되는 변수 (전부)**:

| 변수 | 설명 |
|------|------|
| `${filename}` | 확장자 제외 파일명 |
| `${extname}` | 확장자 |
| `${dirname}` | 직접 상위 폴더명 |
| `${dirname(N)}` | N번째 상위 폴더명 (파일 기준 절대 인덱싱) |

**지원되지 않는 기능**:

- Named Capture Group (`${name:pattern}`)
- 정규식 캡처 (`$1`, `$2`)
- 패턴 매칭 위치 기반 변수 추출
- `**` 와일드카드와 상대적 인덱싱 조합

### 해결 방법 (우회)

앱별로 명시적인 패턴을 작성하는 수밖에 없음.

```json
"**/apps/web/pages/**/index.{ts,tsx}": "(web) ${dirname}/index.${extname}",
"**/apps/admin/pages/**/index.{ts,tsx}": "(admin) ${dirname}/index.${extname}",
"**/apps/mobile/pages/**/index.{ts,tsx}": "(mobile) ${dirname}/index.${extname}"
```

**단점**: 앱이 추가될 때마다 패턴을 수동으로 추가해야 함.

### 교훈

1. **VS Code customLabels는 단순한 템플릿 치환만 지원**
   - 정규식 캡처, 동적 변수 추출 등 고급 기능 없음
   - glob 패턴은 파일 매칭용일 뿐, 값 추출용이 아님

2. **`${dirname(N)}`은 절대 인덱싱**
   - 파일 위치 기준으로 고정된 깊이만 참조 가능
   - `**` 와일드카드와 함께 사용하면 예측 불가능한 결과

3. **모노레포에서는 앱별 명시적 패턴이 필요**
   - 동적으로 앱 이름을 추출하는 방법 없음
   - 앱 목록이 자주 변경되지 않는다면 수동 관리가 현실적

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
