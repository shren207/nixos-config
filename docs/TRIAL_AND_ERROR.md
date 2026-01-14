# Trial and Error 기록

이 문서는 nixos-config 저장소에서 시도했다가 실패한 작업들을 기록합니다.

## 목차

- [2026-01-13: Atuin 동기화 모니터링 시스템 구현 시행착오](#2026-01-13-atuin-동기화-모니터링-시스템-구현-시행착오)
- [2026-01-13: Atuin 계정 마이그레이션 실패](#2026-01-13-atuin-계정-마이그레이션-실패)
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

## 2026-01-13: Atuin 동기화 모니터링 시스템 구현 시행착오

> **테스트 환경**: atuin 18.10.0, macOS (Apple Silicon)
>
> Atuin 동기화 상태를 모니터링하는 시스템을 구현하면서 발견한 중요한 사실들과 시행착오를 기록합니다.

### 목표

1. Hammerspoon 메뉴바에 🐢 아이콘으로 동기화 상태 표시
2. 동기화 지연 시 알림 전송 (Pushover, macOS 알림)
3. 설정값 중앙 관리 (하드코딩 제거)

### 시행착오 1: `last_sync_time` 파일이 업데이트되지 않음

**초기 구현**: `~/.local/share/atuin/last_sync_time` 파일의 내용을 파싱하여 마지막 동기화 시간 확인

**문제**: `atuin sync`를 실행해도 `last_sync_time` 파일이 업데이트되지 않음

```bash
# sync 전
$ cat ~/.local/share/atuin/last_sync_time
2026-01-13T07:26:31.004161Z

# sync 후 (변화 없음!)
$ atuin sync
0/0 up/down to record store
Sync complete! 53 items in history database

$ cat ~/.local/share/atuin/last_sync_time
2026-01-13T07:26:31.004161Z  # 동일
```

**원인**: atuin 18.x부터 **record-based sync (v2)**를 사용하면서 `last_sync_time` 파일은 더 이상 업데이트되지 않음. 이 파일은 레거시 sync v1용.

### 시행착오 2: `records.db` mtime도 업데이트되지 않음

**두 번째 시도**: `records.db` 파일의 수정 시간(mtime)을 사용

**문제**: `atuin sync` 실행 시 동기화할 데이터가 없으면 (0/0 up/down) 파일이 수정되지 않음

```bash
$ ls -la ~/.local/share/atuin/records.db
.rw-------@ 94k glen 13 Jan 16:54  # mtime 고정

$ atuin sync
0/0 up/down to record store
Sync complete!

$ ls -la ~/.local/share/atuin/records.db
.rw-------@ 94k glen 13 Jan 16:54  # 변화 없음
```

**원인**: 데이터베이스 파일은 실제 데이터 변경이 있을 때만 수정됨.

### 최종 해결: `atuin doctor`의 `last_sync` 값 사용

**세 번째 시도**: `atuin doctor` 명령의 JSON 출력에서 `last_sync` 값 추출

```bash
$ atuin doctor 2>&1 | grep -o '"last_sync": "[^"]*"'
"last_sync": "2026-01-13 8:12:42.22629 +00:00:00"
```

이 값은 atuin 내부에서 관리되며, sync가 실행될 때마다 정확하게 업데이트됨.

**구현**:

```lua
-- Lua (Hammerspoon)
local output = hs.execute("atuin doctor 2>&1")
local lastSyncStr = output:match('"last_sync":%s*"([^"]+)"')
```

```bash
# Bash (watchdog 스크립트)
LAST_SYNC_RAW=$(atuin doctor 2>&1 | grep -o '"last_sync": "[^"]*"' | cut -d'"' -f4)
```

### 시행착오 3: `auto_sync`가 백그라운드 주기 동기화가 아님

**오해**: `sync_frequency = "1m"` 설정이 1분마다 자동으로 백그라운드 sync를 실행한다고 생각

**실제 동작**: `auto_sync`는 **터미널에서 명령어를 실행한 후**에만 동작

```
# 잘못된 이해
sync_frequency = "1m"  → 1분마다 백그라운드 sync? ❌

# 실제 동작
sync_frequency = "1m"  → 명령어 실행 후, 마지막 sync로부터 1분이 지났으면 sync 시도 ✅
```

**결과**: 터미널을 사용하지 않으면 sync가 발생하지 않음 → 3분 전이 마지막 동기화인 이유

### 해결: daemon 모드 활성화

`~/.config/atuin/config.toml`에 daemon 설정 추가:

```toml
[sync]
records = true  # sync v2 활성화

[daemon]
enabled = true
sync_frequency = 60  # 초 단위 (문자열 "1m"이 아님!)
```

그리고 `atuin daemon`을 launchd로 자동 시작:

```nix
launchd.agents.atuin-daemon = {
  enable = true;
  config = {
    Label = "com.green.atuin-daemon";
    ProgramArguments = [ ".../atuin" "daemon" ];
    RunAtLoad = true;
    KeepAlive = true;
  };
};
```

### 시행착오 4: 하드코딩된 설정값

**문제**: 설정값이 여러 파일에 중복 정의됨

```lua
-- atuin_menubar.lua
local syncThresholdHours = 24
local logRetentionDays = 30
```

```nix
-- default.nix
syncThresholdHours = 24;
logRetentionDays = 30;
```

**해결**: Single Source of Truth 패턴 적용

```
default.nix (설정값 정의)
    │
    ├──▶ JSON 파일 생성 → Hammerspoon에서 읽기
    │
    └──▶ 환경변수 → watchdog 스크립트에서 읽기
```

### 시행착오 5: Hammerspoon에서 atuin 못 찾음

**문제**: 메뉴바에서 "지금 동기화" 버튼을 눌러도 로그에 "Attempting sync..." 메시지가 없음

**원인**: Hammerspoon의 PATH에 atuin 경로가 없음

```lua
-- 스크립트의 PATH
/run/current-system/sw/bin
$HOME/.nix-profile/bin
/opt/homebrew/bin
...

-- atuin 실제 경로 (누락!)
/etc/profiles/per-user/glen/bin/atuin
```

**해결**: PATH에 per-user 경로 추가

```bash
export PATH="/etc/profiles/per-user/$USER/bin:..."
```

### 최종 구현 결과

| 항목 | 초기 | 최종 |
|------|------|------|
| sync 상태 소스 | `last_sync_time` 파일 | `atuin doctor` 출력 |
| 임계값 | 24시간 | 5분 |
| 상태 체크 주기 | 1시간 | 10분 |
| 백그라운드 sync | 없음 | daemon 모드 (60초) |
| 설정 관리 | 하드코딩 | JSON + 환경변수 |
| 스크립트 이름 | `atuin-sync-monitor` | `atuin-watchdog` |

### 교훈

1. **공식 문서만으로는 부족함**: atuin의 `auto_sync`, `sync_frequency` 동작 방식은 문서에 명확히 설명되어 있지 않음. 실제 테스트와 소스 코드 분석이 필요.

2. **레거시 vs 현재**: `last_sync_time` 같은 파일이 존재해도 현재 버전에서 사용되는지 확인 필요. atuin은 sync v1 → v2로 전환하면서 많은 내부 구조가 변경됨.

3. **단일 소스 원칙**: 설정값이 여러 곳에 분산되면 디버깅이 어려움. 처음부터 중앙 관리 설계 권장.

4. **PATH 문제**: Nix 환경에서 Hammerspoon, launchd 등 외부 실행 환경은 쉘과 다른 PATH를 가짐. 명시적으로 설정 필요.

---

## 2026-01-13: Atuin 계정 마이그레이션 실패

> 테스트 환경: atuin 18.10.0 (nixpkgs), 18.11.0 (GitHub 릴리스), macOS Apple Silicon

### 목표

1. 기존 계정(glen)에서 새 계정(greenhead)으로 마이그레이션
2. 62,000개 이상의 히스토리 보존
3. 동기화 모니터링 시스템 구축

### 초기 상태

```bash
$ cat ~/.local/share/atuin/last_sync_time
2025-09-26T04:11:39.71577ZZ  # 약 4개월 전!

$ atuin status
Error: There was an error with the atuin sync service: Status 404.
```

- `atuin sync`는 "Sync complete!" 출력하지만 실제로 동기화 안 됨
- `last_sync_time` 업데이트 안 됨

### 시도 과정

#### 1단계: 새 계정 생성 시도

```bash
# 백업
cp ~/.local/share/atuin/{history.db,key,records.db} ~/.local/share/atuin/*.backup-20260113

# 로그아웃 후 새 계정 등록
atuin logout
atuin register -u greenhead -e <email>
```

**문제**: 새 계정으로 로그인해도 `atuin status`에서 동일한 404 오류

#### 2단계: 데이터 초기화 및 재시도

```bash
rm -f ~/.local/share/atuin/{history.db,key,session,host_id,records.db,...}
atuin login -u greenhead
```

**문제**: 서버에서 기존 히스토리 다운로드 시 encryption key 불일치

```
Error: attempting to decrypt with incorrect key.
currently using k4.lid.XXX..., expecting k4.lid.YYY...
```

#### 3단계: 백업 key 복원 시도

```bash
cp ~/.local/share/atuin/key.backup-20260113 ~/.local/share/atuin/key
atuin sync
```

**결과**:
- 서버에 두 개의 호스트 존재 (기존 + 새로 생성)
- 각 호스트가 다른 key로 암호화된 데이터 보유
- 어떤 key를 사용해도 일부 데이터 복호화 실패

#### 4단계: 버전 업그레이드 시도

```bash
# 18.11.0 직접 다운로드
curl -sLO https://github.com/atuinsh/atuin/releases/download/v18.11.0/atuin-aarch64-apple-darwin.tar.gz
./atuin-aarch64-apple-darwin/atuin status
```

**결과**: 동일한 404 오류. 클라이언트 버전 문제가 아님.

#### 5단계: 소스 코드 분석

```bash
git clone https://github.com/atuinsh/atuin.git ~/IdeaProjects/atuin-source
```

**발견** (`crates/atuin-server/src/router.rs`):

```rust
// Sync v1 routes - can be disabled in favor of record-based sync
if settings.sync_v1_enabled {
    routes = routes
        .route("/sync/status", get(handlers::status::status))
        // ...
}
```

**근본 원인**: Atuin 클라우드 서버(`api.atuin.sh`)가 Sync v1을 비활성화함
- `/sync/status` 엔드포인트가 더 이상 존재하지 않음
- `atuin status`는 v1 API를 사용하므로 404 반환
- `atuin sync`는 v2 API (`/api/v0/*`)를 사용하므로 정상 작동

### 최종 결과

| 항목 | 결과 |
|------|------|
| 계정 마이그레이션 | ❌ 포기 (key 충돌 해결 불가) |
| 기존 히스토리 보존 | ❌ 손실 (백업 파일 삭제됨) |
| 동기화 모니터링 | ✅ 구현 완료 |
| `atuin status` 404 | ⚠️ 서버 측 문제, 해결 불가 |

### 교훈

1. **백업은 여러 곳에**: 작업 중에 백업 파일이 삭제됨. 별도 경로에도 백업 필요.

2. **Encryption key는 신중하게**:
   - 새 계정 로그인 시 새 key가 자동 생성됨
   - 기존 key를 사용하려면 로그인 프롬프트에서 입력 필요
   - key가 다르면 서버 데이터 복호화 불가

3. **404 오류의 다양한 원인**:
   - 처음에는 세션/인증 문제로 추정
   - 실제로는 서버 API 비활성화 (Sync v1 deprecated)

4. **소스 코드 분석의 중요성**:
   - 에러 메시지만으로는 원인 파악 어려움
   - 실제 서버/클라이언트 코드를 읽어야 정확한 원인 발견

### 관련 파일

| 파일 | 설명 |
|------|------|
| `modules/darwin/programs/atuin/default.nix` | launchd 에이전트 설정 |
| `modules/darwin/programs/atuin/files/atuin-sync-monitor.sh` | 모니터링 스크립트 |
| `docs/TROUBLESHOOTING.md` | Atuin 섹션 |
| `docs/ATUIN_ACCOUNT_MIGRATION.md` | 마이그레이션 가이드 (미완성) |

### 향후 계획

- [ ] Atuin GitHub에 이슈 제출 (status 404 문제)
- [ ] 집 맥북에서 동일한 설정 적용
- [ ] 기존 히스토리는 포기, 새로 시작

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

---

## 2026-01-14: Atuin Watchdog 개선 및 Daemon 비활성화

### 배경

회사 환경에서 atuin daemon 재시작 후에도 동기화 지연이 지속되는 문제 발생. 원인 파악 및 해결 과정 기록.

### 타임라인 (사실 기반)

| 시점 | 커밋 | 내용 |
|------|------|------|
| 2026-01-13 17:55 | b44bea2 | daemon 모드 활성화, atuin doctor 사용 시작 |
| 2026-01-14 08:54 | fb8de27 | "동기화 지연 (1948분 초과)" 문제 발견, daemon 자동 복구 기능 추가 |
| 2026-01-14 11:00경 | 이번 세션 | daemon 여전히 불안정, CLI sync로 완전 대체 결정 |

**주목할 점**: b44bea2에서 daemon을 활성화한 후 약 15시간 만에 1948분(32시간) 동기화 지연이 발견됨. 이는 **daemon이 활성화 직후부터 정상 동작하지 않았을 가능성**을 시사함.

### 핵심 발견: daemon sync vs CLI sync의 차이

소스코드 분석을 통해 중요한 차이점 발견:

**daemon sync** (`atuin-daemon/src/server/sync.rs:85`):
```rust
// sync 성공 후 save_sync_time() 호출
tokio::task::spawn_blocking(Settings::save_sync_time).await??;
```

**CLI sync (v2)** (`crates/atuin/src/command/client/sync.rs`):
```rust
pub async fn run(...) -> Result<()> {
    if settings.sync.records {
        // v2 경로: save_sync_time() 호출 없음
        sync::sync(&settings, &db).await?;
    } else {
        // v1 경로: save_sync_time() 있음
        atuin_client::sync::sync(&settings, false, &db).await?;
    }
}
```

**결론**:
- daemon이 정상 동작하면 `last_sync_time` 파일이 업데이트됨
- CLI sync (v2)는 `save_sync_time()`을 호출하지 않음 (버그로 추정되나 확실하지 않음)

### 이전 커밋(b44bea2)이 동작했던 이유에 대한 분석

**사실**:
- b44bea2 커밋에서는 daemon 모드를 활성화하고, `atuin doctor`의 `last_sync` 값을 사용
- daemon sync 코드에는 `save_sync_time()` 호출이 존재함

**추측**:
- daemon이 정상 동작했다면 `save_sync_time()`이 호출되어 `last_sync_time` 파일이 업데이트되었을 것
- 하지만 fb8de27 커밋(활성화 후 약 15시간)에서 1948분 지연이 발견된 것으로 보아, **daemon이 처음부터 정상 동작하지 않았을 가능성**이 높음
- "정상 동작 후 문제 발생"이 아니라 "활성화 직후부터 문제 발생"이었을 수 있음

### 관찰된 daemon 불안정 증상

**확인된 사실** (이번 세션에서 직접 확인):

```bash
$ launchctl print gui/$(id -u)/com.green.atuin-daemon
runs = 218
last exit code = 1
```

- daemon이 218번 재시작됨
- 마지막 종료 코드가 1 (에러)

**추측되는 원인** (확인되지 않음):
- 네트워크 연결 불안정 시 복구 실패
- 시스템 슬립/웨이크 후 복구 실패
- 서버 측 일시적 장애 후 재연결 실패
- atuin daemon 자체의 experimental 특성으로 인한 불안정

**참고**: atuin 공식 문서에서 daemon을 "experimental" 기능으로 분류하고 있음. maintainer도 불안정하다고 언급한 적 있음 (정확한 출처 필요).

### 문제 1: Watchdog이 에러를 무시함

**증상**: watchdog이 sync 실패를 감지하지 못함

**원인**: 기존 코드가 에러를 무시

```bash
# 기존 코드
atuin sync 2>/dev/null || echo "Warning: sync command failed"
```

**해결**: 에러 로깅 및 상세 출력 추가

```bash
sync_output=$(atuin sync 2>&1)
sync_exit_code=$?
if [[ $sync_exit_code -ne 0 ]]; then
    log_error "Sync failed (exit code: $sync_exit_code)"
    log_error "Sync output: $sync_output"
fi
```

### 문제 2: 네트워크 문제와 daemon 문제 구분 불가

**증상**: 네트워크가 안 되는데 daemon을 재시작하려고 시도

**해결**: sync 시도 전 네트워크 확인 추가

```bash
check_network_connectivity() {
    # DNS 확인
    if ! host "$ATUIN_SYNC_SERVER" >/dev/null 2>&1; then
        log_error "DNS resolution failed"
        return 1
    fi

    # HTTPS 연결 확인
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 5 "https://$ATUIN_SYNC_SERVER")

    if [[ "$http_code" == "000" ]]; then
        log_error "No response from server"
        return 1
    fi

    return 0
}
```

### 문제 3: Atuin daemon 불안정

**증상**: daemon이 exit code 1로 218번 재시작됨

```bash
$ launchctl print gui/$(id -u)/com.green.atuin-daemon
runs = 218
last exit code = 1
```

**원인 분석**:
- atuin daemon은 아직 experimental 기능
- maintainer도 불안정하다고 언급
- 장시간 실행 시 좀비 상태로 전환

**해결**: daemon 비활성화, launchd로 주기적 sync 실행

```nix
# daemon 비활성화 (config.toml)
# daemon = { enabled = true; ... }  # 주석 처리

# launchd로 2분마다 sync
launchd.agents.atuin-sync = {
  config = {
    ProgramArguments = [ "/bin/bash" "-c" "atuin sync && ..." ];
    StartInterval = 120;
  };
};
```

### 문제 4: CLI sync (v2)가 last_sync_time 미업데이트

**증상**: `atuin sync` 성공해도 `last_sync_time` 파일이 업데이트되지 않음

**원인**: atuin 소스코드 분석 결과, sync.records = true (v2) 경로에서 `save_sync_time()` 미호출

```rust
// crates/atuin/src/command/client/sync.rs
pub async fn run(...) -> Result<()> {
    if settings.sync.records {
        sync::sync(&settings, &db).await?;  // save_sync_time() 없음!
    } else {
        atuin_client::sync::sync(...).await?;  // save_sync_time() 있음
    }
}
```

**해결**: launchd에서 sync 성공 후 직접 파일 업데이트

```bash
atuin sync && printf '%s' "$(date -u +'%Y-%m-%dT%H:%M:%S.000000Z')" > ~/.local/share/atuin/last_sync_time
```

### 문제 5: last_sync_time 파일 형식 오류

**증상**: `atuin doctor`가 "no last sync" 반환

**원인**: 줄바꿈 문자가 포함되면 파싱 실패

```bash
# 잘못된 방식
echo "2026-01-14T02:45:00.000000Z" > last_sync_time  # 줄바꿈 포함!

# 올바른 방식
printf '%s' "2026-01-14T02:45:00.000000Z" > last_sync_time  # 줄바꿈 없음
```

### 문제 6: launchd 에이전트가 즉시 실행되지 않음

**증상**: `StartInterval = 120` 설정 시 첫 interval이 지난 후에야 실행됨

**해결**: `RunAtLoad = true` 추가

```nix
launchd.agents.atuin-sync = {
  config = {
    RunAtLoad = true;      # 로드 시 바로 첫 실행
    StartInterval = 120;   # 이후 2분마다
  };
};
```

### 교훈

1. **에러를 무시하지 말 것**
   - `2>/dev/null`은 디버깅을 불가능하게 만듦
   - 에러 출력을 로그 파일에 기록하는 것이 필수

2. **네트워크 문제 우선 확인**
   - 앱 문제인지 네트워크 문제인지 구분 필요
   - sync 실패 시 무조건 daemon/앱 재시작이 아닌, 네트워크 확인 선행

3. **experimental 기능에 대한 대비**
   - "experimental"로 표시된 기능은 실제로 불안정할 수 있음
   - 대안(fallback)을 미리 마련해두는 것이 좋음
   - 이번 경우: daemon 대신 launchd + CLI sync 조합으로 대체

4. **소스코드 분석의 중요성**
   - 문서만으로는 동작을 확신할 수 없음
   - `save_sync_time()` 미호출 같은 미묘한 차이는 소스코드에서만 확인 가능
   - 버그인지 의도된 동작인지 판단하려면 소스코드 분석 필수

5. **파일 형식의 엄격함**
   - 줄바꿈 하나가 파싱 실패 유발 (`echo` vs `printf '%s'`)
   - 시간 형식, 타임존 등 정확히 맞춰야 함

6. **launchd 동작 이해**
   - `StartInterval`만으로는 즉시 실행 안 됨
   - `RunAtLoad = true` 추가해야 로드 시 첫 실행

7. **커밋 메시지와 타임라인의 중요성**
   - fb8de27 커밋 메시지에 "1948분 동기화 지연"이 기록됨
   - 이 정보로 "daemon이 처음부터 문제였다"는 것을 역추적할 수 있었음
   - 문제 상황을 커밋 메시지에 상세히 기록하는 것이 나중에 도움이 됨

### 최종 아키텍처

```
launchd
├── com.green.atuin-sync      # 2분마다: atuin sync + last_sync_time 업데이트
└── com.green.atuin-watchdog  # 10분마다: 네트워크 확인 + 상태 체크 + 복구 + 알림
```

**왜 이 구조인가:**
- daemon은 불안정 → launchd의 `StartInterval`로 주기적 sync 대체
- CLI sync (v2)는 `last_sync_time` 미업데이트 → launchd에서 직접 파일 업데이트
- watchdog은 상태 체크 + 복구 전담 (sync 자체는 담당하지 않음)

### 발견한 atuin 동작 특성

> **주의**: 아래 내용이 "버그"인지 "의도된 동작"인지는 확인되지 않음. upstream에 확인 필요.

#### 1. CLI sync (v2)에서 save_sync_time() 미호출

**관찰된 현상**:
- `atuin sync` 명령이 성공해도 `~/.local/share/atuin/last_sync_time` 파일이 업데이트되지 않음
- `atuin doctor`의 `last_sync` 값이 갱신되지 않음

**소스코드 위치**: `crates/atuin/src/command/client/sync.rs`

**비교**:
| 경로 | save_sync_time() 호출 |
|------|----------------------|
| daemon sync | ✅ 있음 (`atuin-daemon/src/server/sync.rs:85`) |
| CLI sync (v1) | ✅ 있음 |
| CLI sync (v2) | ❌ 없음 |

**추측**: v2로 전환하면서 누락된 것으로 보이나, 의도적일 수도 있음.

#### 2. daemon 불안정

**관찰된 현상**:
- launchd에서 218번 재시작됨 (runs = 218)
- exit code 1로 반복 종료
- 프로세스는 실행 중이지만 sync를 수행하지 않는 "좀비" 상태 발생

**추측되는 원인** (확인되지 않음):
- experimental 기능의 특성
- 네트워크/슬립/서버 장애 시 복구 실패

**atuin 문서 참고**: daemon은 "experimental" 기능으로 분류됨.

### 향후 고려사항

1. **atuin upstream 이슈 확인/보고**
   - CLI sync (v2)의 `save_sync_time()` 미호출이 버그인지 확인
   - daemon 불안정 관련 기존 이슈가 있는지 확인

2. **daemon 안정화 시 재검토**
   - atuin 버전 업그레이드 시 daemon 안정성 재평가
   - 안정화되면 daemon으로 복귀 가능 (더 효율적)

3. **모니터링 로그 주기적 확인**
   - `~/.local/share/atuin/watchdog.log` 확인
   - 새로운 패턴의 문제 발생 시 조기 발견
