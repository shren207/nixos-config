---
name: syncing-atuin
description: |
  This skill should be used when the user encounters Atuin sync issues,
  "atuin status" 4XX errors, encryption key mismatch, daemon problems,
  or asks about shell history backup. Covers zsh-autosuggestion conflicts
  and last_sync_time troubleshooting.
---

# Atuin 히스토리 동기화

Atuin 쉘 히스토리 동기화 및 모니터링 가이드입니다.

## Known Issues

**Atuin v1 API deprecated**
- `atuin status` 명령어가 4XX 에러 반환 가능
- v2 API 사용 중, `last_sync_time` 파일이 CLI sync에서 자동 업데이트되지 않음
- 동기화 자체는 정상 작동

## 빠른 참조

### 상태 확인

```bash
# 동기화 상태 (4XX 에러 발생 가능)
atuin status

# 마지막 동기화 시간 확인
cat ~/.local/share/atuin/last_sync_time

# 수동 동기화
atuin sync
```

### 주요 파일 위치

| 파일 | 용도 |
|------|------|
| `~/.config/atuin/config.toml` | Atuin 설정 |
| `~/.local/share/atuin/` | 데이터 디렉토리 |
| `~/.local/share/atuin/last_sync_time` | 마지막 동기화 타임스탬프 |

### 모니터링 (Hammerspoon)

Hammerspoon 메뉴바에서 Atuin 동기화 상태 모니터링 가능:
- 정상: 초록색
- 경고 (1시간 이상 미동기화): 노란색
- 에러: 빨간색

## 자주 발생하는 문제

1. **atuin status 4XX**: v1 API deprecated, 동기화는 정상
2. **encryption key 불일치**: 계정별 고유 키, 마이그레이션 불가
3. **zsh 한글 레이아웃 깨짐**: zsh-autosuggestion + 한글 경로 조합 문제

## 레퍼런스

- 트러블슈팅: [references/troubleshooting.md](references/troubleshooting.md)
- 모니터링 설정: [references/monitoring.md](references/monitoring.md)
