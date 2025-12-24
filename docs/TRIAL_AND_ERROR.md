# Trial and Error 기록

이 문서는 nixos-config 저장소에서 시도했다가 실패한 작업들을 기록합니다.

## 목차

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
