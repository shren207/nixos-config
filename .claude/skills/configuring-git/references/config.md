# Git 설정

Git 관련 설정 및 도구 구성입니다.

## 목차

- [개발 도구](#개발-도구)
- [Git 설정](#git-설정)
- [Interactive Rebase 역순 표시](#interactive-rebase-역순-표시)
- [git-cleanup](#git-cleanup)

---

`modules/shared/programs/git/default.nix`에서 관리됩니다.

## 개발 도구

| 도구      | 설명                                      |
| --------- | ----------------------------------------- |
| `git`     | 버전 관리                                 |
| `delta`   | Git diff 시각화 (구문 강조, side-by-side) |
| `lazygit` | Git TUI                                   |
| `gh`      | GitHub CLI                                |

## Git 설정

### Interactive Rebase 역순 표시

`git rebase -i` 실행 시 Fork GUI처럼 **최신 커밋이 위**, 오래된 커밋이 아래에 표시됩니다.

| CLI (기본)              | CLI (적용 후)           | Fork GUI                |
| ----------------------- | ----------------------- | ----------------------- |
| 오래된 → 최신 (위→아래) | 최신 → 오래된 (위→아래) | 최신 → 오래된 (위→아래) |

**구현 방식:**

- `sequence.editor`에 커스텀 스크립트 설정
- 편집 전: 커밋 라인을 역순 정렬하여 표시
- 편집 후: 원래 순서로 복원 (rebase 동작 정상 유지)
- `pkgs.writeShellScript`로 Nix store에서 스크립트 관리

**주의사항:**

- squash/fixup은 **아래쪽 커밋**이 **위쪽 커밋**으로 합쳐집니다 (Fork GUI와 동일)
- `git rebase --edit-todo`에서도 역순 표시가 적용됩니다

## git-cleanup

`scripts/git-cleanup.sh`에서 관리됩니다.

더 이상 사용되지 않는 로컬 브랜치를 식별하고 정리하는 스크립트입니다. `git cleanup` 또는 `git-cleanup` 명령어로 실행합니다.

**삭제 기준:**

| 상태 | 아이콘 | 설명 | 삭제 방식 |
|------|--------|------|----------|
| gone | O | 원격에서 삭제된 브랜치 (PR 머지 후 삭제됨) | `-D` (강제) |
| stale | 경고 | 30일 이상 된 로컬 전용 브랜치 | `-D` (강제) |
| protected | 잠금 | 보호 브랜치 (main, master, develop, stage) | 삭제 불가 |
| current | 현재 | 현재 체크아웃된 브랜치 | 삭제 불가 |

**사용법:**

```bash
# 삭제 대상 미리보기 (권장)
git cleanup --dry-run

# 실제 정리
git cleanup

# 도움말
git cleanup --help
```

**메뉴 옵션:**

| 옵션 | 설명 |
|------|------|
| `[a]` | gone 상태 전체 삭제 |
| `[b]` | stale 상태 전체 삭제 |
| `[s]` | 하나씩 선택하여 삭제 (Y/n/q) |
| `[q]` | 취소 |

**출력 예시:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Git Branch Cleanup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

── gone (3개) ──
  O [gone] feat/login (origin/feat/login)
  O [gone] fix/bug-123 (origin/fix/bug-123)
  O [gone] JIRA-456 (origin/JIRA-456)

── stale (2개) ──
  경고 [stale] experiment/test (45일 경과)
  경고 [stale] old-feature (120일 경과)

── 보호됨 ──
  잠금 main
  현재 develop (현재)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**동작 흐름:**

1. `git fetch --prune` 자동 실행 (원격 정보 동기화)
2. 브랜치 목록 수집 및 분류
3. 삭제 대상 표시
4. 사용자 선택에 따라 삭제 진행

> **참고**: 네트워크 오류 시에도 로컬 정보로 계속 진행합니다.
