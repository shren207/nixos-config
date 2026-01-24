---
name: understanding-nix
description: |
  This skill should be used when the user asks about "nix flake update",
  "flake change detection", "slow build", "substituter", "derivation",
  "direnv", "devShell", "experimental features", or encounters Nix
  build issues common to NixOS and nix-darwin.
---

# Nix 공통 이슈

NixOS와 nix-darwin 모두에 해당하는 Nix 공통 개념 및 이슈입니다.

## 핵심 개념

### Flake 시스템

```bash
# flake.nix: 입력과 출력 정의
# flake.lock: 입력 버전 고정

# flake 업데이트
nix flake update

# 특정 입력만 업데이트
nix flake lock --update-input nixpkgs
```

### Experimental Features

```bash
# 필요한 기능들
experimental-features = nix-command flakes

# 설정 위치
~/.config/nix/nix.conf        # 사용자별
/etc/nix/nix.conf             # 시스템 전역
```

## 빠른 참조

### flake 변경이 인식되지 않음

```bash
# 원인 1: git에서 추적되지 않는 파일
# 해결: git add 필요
git add .
nrs

# 원인 2: nixos-config-secret 업데이트 후 flake.lock 미갱신
# 해결: nrs --update 사용
nrs --update  # flake.lock 자동 업데이트 후 rebuild
```

### flake.lock과 캐시

```bash
# flake.lock에 특정 commit이 잠김
# nixos-config-secret을 수정해도 flake.lock 업데이트 전까지 반영 안 됨

# nrs 실행 시 자동 감지 및 경고:
# ⚠️  nixos-config-secret이 업데이트되었지만 flake.lock에 반영되지 않았습니다
#    locked: 10ece02
#    remote: abc1234
#    💡 'nrs --update' 또는 'nix flake update nixos-config-secret' 실행 필요
```

### 빌드 속도 최적화

| 방법 | 명령어 | 효과 |
|------|--------|------|
| 오프라인 빌드 | `nrs-offline` | 네트워크 요청 없음, 가장 빠름 |
| 병렬 다운로드 | `max-substitution-jobs = 128` | 다운로드 병렬화 |
| GitHub 토큰 | `access-tokens = github.com=...` | rate limit 해제 |

### 에러 디버깅

```bash
# 상세 빌드 로그
nix build --show-trace

# derivation 확인
nix derivation show .#darwinConfigurations.<host>.system
```

## 자주 발생하는 문제

1. **flake 인식 안 됨**: `git add` 필요 (untracked 무시)
2. **experimental features**: `nix-command flakes` 활성화 필요
3. **빌드 느림**: `--offline` 사용 또는 substituter 확인

## 레퍼런스

- 트러블슈팅: [references/troubleshooting.md](references/troubleshooting.md)
- 기능 목록: [references/features.md](references/features.md)
