#!/usr/bin/env bash
# scripts/create-improvement-issues.sh
# 프로젝트 구조 분석 결과 도출된 개선 이슈 일괄 등록
# 사용법: bash scripts/create-improvement-issues.sh
# 전제: gh auth login 완료 상태
set -euo pipefail

REPO="shren207/nixos-config"

echo "=== 프로젝트 구조 분석 — 개선 이슈 일괄 등록 ==="
echo ""

# 0. area:maintenance 라벨 생성 (없으면)
if ! gh label list --repo "$REPO" --json name --jq '.[].name' | grep -q '^area:maintenance$'; then
  echo "Creating label: area:maintenance"
  gh label create "area:maintenance" \
    --repo "$REPO" \
    --description "코드 유지보수, 리팩토링, 데드코드 정리, 네이밍 일관성" \
    --color "d4c5f9"
else
  echo "Label area:maintenance already exists, skipping"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# Issue 1: nrs.sh/nrp.sh 스크립트 중복 제거
# ─────────────────────────────────────────────────────────────
echo "Creating issue 1/10: nrs.sh 스크립트 중복 제거"
gh issue create --repo "$REPO" \
  --title "refactor: nrs.sh/nrp.sh 스크립트 공통 함수 추출 — darwin/nixos 간 60-70% 중복 제거" \
  --label "enhancement,priority:medium,area:maintenance" \
  --body "$(cat <<'EOF'
## Summary

darwin/nixos 양쪽의 nrs.sh, nrp.sh에서 60-70% 동일한 함수가 중복 정의되어 있어, 공통 부분을 별도 파일로 추출하여 유지보수 비용을 줄인다.

## Context

- `modules/darwin/scripts/nrs.sh` (196줄)과 `modules/nixos/scripts/nrs.sh` (146줄)에 동일한 함수 다수 존재
- 중복 함수: `log_info`, `log_warn`, `log_error` (색상 로깅), `update_external_packages` (codex-cli 업데이트), `preview_changes` (nvd diff), `cleanup_build_artifacts`
- 공통 함수 수정 시 양쪽을 반드시 같이 고쳐야 하며, 어긋날 위험이 있음
- nrp.sh도 동일한 패턴으로 중복 존재

## Related Commits

N/A

## Affected Files

| File | Role | Required Change |
|------|------|-----------------|
| `modules/shared/scripts/rebuild-common.sh` | (신규) 공통 함수 라이브러리 | 공통 함수 추출하여 생성 |
| `modules/darwin/scripts/nrs.sh` | macOS 빌드 스크립트 | 공통 함수 source로 교체, darwin 전용만 유지 |
| `modules/nixos/scripts/nrs.sh` | NixOS 빌드 스크립트 | 공통 함수 source로 교체, nixos 전용만 유지 |
| `modules/darwin/scripts/nrp.sh` | macOS 미리보기 스크립트 | 공통 함수 source로 교체 |
| `modules/nixos/scripts/nrp.sh` | NixOS 미리보기 스크립트 | 공통 함수 source로 교체 |

## Proposed Changes

- [ ] `modules/shared/scripts/rebuild-common.sh` 생성 — `log_info/warn/error`, `update_external_packages`, `preview_changes`, `cleanup_build_artifacts` 추출
- [ ] darwin/nrs.sh에서 공통 함수 제거, `source` 로딩으로 교체
- [ ] nixos/nrs.sh에서 공통 함수 제거, `source` 로딩으로 교체
- [ ] darwin/nrp.sh, nixos/nrp.sh에서도 동일하게 공통 함수 교체
- [ ] 양쪽 `nrs`, `nrp` alias가 정상 동작하는지 검증

## Acceptance Criteria

- [ ] `nrs`, `nrp` 명령이 darwin/nixos 양쪽에서 기존과 동일하게 동작
- [ ] 공통 함수가 단일 파일(`rebuild-common.sh`)에만 존재
- [ ] shellcheck 통과

## Notes

- darwin 전용 함수: `cleanup_launchd_agents`, `restart_hammerspoon`
- nixos 전용 함수: `run_nixos_rebuild`
- 이들은 각 플랫폼 스크립트에 유지
EOF
)"
echo "  -> Created"

# ─────────────────────────────────────────────────────────────
# Issue 2: ensure_ssh_key_loaded 데드코드 제거
# ─────────────────────────────────────────────────────────────
echo "Creating issue 2/10: ensure_ssh_key_loaded 데드코드 제거"
gh issue create --repo "$REPO" \
  --title "chore: ensure_ssh_key_loaded() 데드코드 제거 — darwin/nixos nrs.sh 양쪽에서 미사용" \
  --label "enhancement,priority:low,area:maintenance" \
  --body "$(cat <<'EOF'
## Summary

darwin/nixos 양쪽 nrs.sh에 정의된 `ensure_ssh_key_loaded()` 함수가 어디에서도 호출되지 않으므로 제거한다.

## Context

- `modules/darwin/scripts/nrs.sh:37`과 `modules/nixos/scripts/nrs.sh:36`에 동일한 함수 정의
- `main()` 함수에서 호출하지 않음
- 양쪽 모두 동일한 데드코드
- 나중에 필요하면 git history에서 복구 가능

## Related Commits

N/A

## Affected Files

| File | Role | Required Change |
|------|------|-----------------|
| `modules/darwin/scripts/nrs.sh` | macOS 빌드 스크립트 | `ensure_ssh_key_loaded()` 함수 삭제 |
| `modules/nixos/scripts/nrs.sh` | NixOS 빌드 스크립트 | `ensure_ssh_key_loaded()` 함수 삭제 |

## Proposed Changes

- [ ] `modules/darwin/scripts/nrs.sh`에서 `ensure_ssh_key_loaded()` 함수 전체 삭제
- [ ] `modules/nixos/scripts/nrs.sh`에서 `ensure_ssh_key_loaded()` 함수 전체 삭제

## Acceptance Criteria

- [ ] 양쪽 nrs.sh에 `ensure_ssh_key_loaded` 문자열 없음
- [ ] `nrs` 명령이 기존과 동일하게 동작
- [ ] shellcheck 통과

## Notes

- #1 (nrs.sh 공통 함수 추출)과 함께 처리하면 효율적
EOF
)"
echo "  -> Created"

# ─────────────────────────────────────────────────────────────
# Issue 3: Caddy virtualHosts 반복 패턴 제거
# ─────────────────────────────────────────────────────────────
echo "Creating issue 3/10: Caddy virtualHosts 반복 패턴 제거"
gh issue create --repo "$REPO" \
  --title "refactor: Caddy virtualHosts 반복 패턴을 리스트 기반 자동 생성으로 변경" \
  --label "enhancement,priority:medium,area:infrastructure" \
  --body "$(cat <<'EOF'
## Summary

caddy.nix에서 4개 서비스의 virtualHost 정의가 거의 동일한 구조를 반복하고 있어, 리스트 기반 자동 생성으로 변경하여 서비스 추가 시 복붙 실수를 방지한다.

## Context

- `modules/nixos/programs/caddy.nix:73-103`에서 immich, uptimeKuma, copyparty, vaultwarden 4개 서비스가 동일 구조 반복:
  ```nix
  virtualHosts."${subdomains.X}.${base}" = {
    listenAddresses = [ minipcTailscaleIP ];
    extraConfig = ''
      ${securityHeaders}
      reverse_proxy localhost:${toString constants.network.ports.X}
    '';
  };
  ```
- 서비스 추가 시 복붙 후 수정 누락 가능성 있음
- `builtins.listToAttrs` 또는 `lib.genAttrs` 패턴으로 자동 생성 가능

## Related Commits

N/A

## Affected Files

| File | Role | Required Change |
|------|------|-----------------|
| `modules/nixos/programs/caddy.nix` | Caddy HTTPS 리버스 프록시 | virtualHosts를 서비스 리스트에서 자동 생성하도록 리팩토링 |

## Proposed Changes

- [ ] subdomain → port 매핑 리스트 정의 (예: `services = [ { sub = subdomains.immich; port = ports.immich; } ... ]`)
- [ ] `builtins.listToAttrs` 또는 `lib.genAttrs`로 virtualHosts 자동 생성
- [ ] 기존 4개 virtualHost 블록을 생성된 코드로 교체

## Acceptance Criteria

- [ ] Caddy 설정이 기존과 동일하게 평가됨 (`nix eval` 또는 `nrp`로 검증)
- [ ] 새 서비스 추가 시 리스트에 한 줄만 추가하면 됨
- [ ] `nix eval --impure --file tests/eval-tests.nix` 통과

## Notes

- dev-proxy는 별도 모듈(`dev-proxy/default.nix`)이므로 이 리팩토링 범위에 포함하지 않음
- 서비스별 custom extraConfig가 필요해지면 그때 리스트 구조를 확장
EOF
)"
echo "  -> Created"

# ─────────────────────────────────────────────────────────────
# Issue 4: vaultwarden-update 모듈 추가
# ─────────────────────────────────────────────────────────────
echo "Creating issue 4/10: vaultwarden-update 모듈 추가"
gh issue create --repo "$REPO" \
  --title "feat: vaultwarden-update 모듈 추가 — 다른 서비스와 동일한 버전 체크/알림 패턴 적용" \
  --label "enhancement,priority:low,area:maintenance" \
  --body "$(cat <<'EOF'
## Summary

immich, uptime-kuma, copyparty에는 모두 mk-update-module.nix 기반 update 모듈이 있으나, vaultwarden만 빠져 있다. 동일 패턴을 적용하여 버전 체크 + Pushover 알림을 추가한다.

## Context

- `mk-update-module.nix`가 이미 범용 추상화로 존재하여 추가 비용이 낮음
- 기존 패턴: immich-update, uptime-kuma-update, copyparty-update
- vaultwarden은 GitHub releases(`dani-garcia/vaultwarden`)에서 버전 확인 가능
- 현재 vaultwarden 이미지 태그는 `1.35.2`로 pinned — 업데이트 알림이 없으면 놓칠 수 있음

## Related Commits

N/A

## Affected Files

| File | Role | Required Change |
|------|------|-----------------|
| `modules/nixos/programs/vaultwarden-update/default.nix` | (신규) 버전 체크 모듈 | mk-update-module.nix로 생성 |
| `modules/nixos/programs/vaultwarden-update/files/update-vaultwarden.sh` | (신규) 업데이트 스크립트 | 기존 패턴 참고하여 작성 |
| `modules/nixos/options/homeserver.nix` | 홈서버 옵션 정의 | `vaultwardenUpdate` 옵션 추가 |
| `modules/nixos/configuration.nix` | NixOS 설정 | `homeserver.vaultwardenUpdate.enable = true` 추가 |
| `secrets/secrets.nix` | agenix 시크릿 정의 | pushover-vaultwarden 시크릿 추가 (기존 것 재사용 가능한지 확인) |

## Proposed Changes

- [ ] `homeserver.vaultwardenUpdate` 옵션 정의 (homeserver.nix)
- [ ] `vaultwarden-update/default.nix` 생성 — `mk-update-module.nix` 호출
- [ ] `vaultwarden-update/files/update-vaultwarden.sh` 생성 — 기존 copyparty-update 패턴 참고
- [ ] homeserver.nix imports에 vaultwarden-update 추가
- [ ] configuration.nix에 `homeserver.vaultwardenUpdate.enable = true` 추가
- [ ] Pushover 시크릿 설정 (기존 pushover-system-monitor 재사용 또는 신규 생성)

## Acceptance Criteria

- [ ] `vaultwarden-version-check` systemd timer가 등록됨
- [ ] 수동 실행 시 GitHub releases에서 최신 버전 확인 가능
- [ ] 버전 불일치 시 Pushover 알림 발송
- [ ] `nix eval --impure --file tests/eval-tests.nix` 통과

## Notes

- vaultwarden 이미지가 pinned tag(`1.35.2`)이므로 update 스크립트에서 tag 업데이트까지 자동화할지 아니면 알림만 할지 결정 필요
- 기존 다른 서비스(copyparty, immich)는 rolling tag + digest 비교 방식이라 vaultwarden과 전략이 다를 수 있음
EOF
)"
echo "  -> Created"

# ─────────────────────────────────────────────────────────────
# Issue 5: caddy-security-headers 실효성 점검
# ─────────────────────────────────────────────────────────────
echo "Creating issue 5/10: caddy-security-headers 실효성 주석 추가"
gh issue create --repo "$REPO" \
  --title "docs: caddy-security-headers.nix에 Tailscale 전용 환경 맥락 주석 추가" \
  --label "documentation,priority:low,area:security" \
  --body "$(cat <<'EOF'
## Summary

Tailscale 내부 전용 환경에서 HSTS, X-Frame-Options 등 보안 헤더의 실질적 효과가 제한적임을 주석으로 명시하여, 향후 디버깅 시 불필요한 시간 낭비를 방지한다.

## Context

- `modules/nixos/lib/caddy-security-headers.nix`에 HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy 등 설정
- 모든 서비스가 Tailscale IP(`100.79.80.95:443`)에만 바인딩되어 외부 노출 없음
- HSTS: 브라우저가 HTTPS 강제하는 헤더이나, Tailscale MagicDNS + 내부 Caddy이므로 실질적 공격 벡터 없음
- X-Frame-Options: iframe 삽입 공격 방지이나, 같은 Tailnet 내에서만 접근 가능
- 해가 되지는 않으나, 새 서비스 추가 시 이 헤더 때문에 예상치 못한 동작이 있을 수 있음
- 외부 노출 전환 시에는 이 헤더들이 필요해지므로 삭제보다 주석이 적절

## Related Commits

N/A

## Affected Files

| File | Role | Required Change |
|------|------|-----------------|
| `modules/nixos/lib/caddy-security-headers.nix` | Caddy 공통 보안 헤더 | Tailscale 전용 맥락 주석 추가 |

## Proposed Changes

- [ ] 파일 상단에 "Tailscale 내부 전용 환경에서는 실질적 보안 효과 제한적" 주석 추가
- [ ] 외부 노출 전환 시 반드시 유지해야 하는 헤더 표시

## Acceptance Criteria

- [ ] 주석이 명확하고 간결하게 맥락을 설명
- [ ] Caddy 설정 동작에 변경 없음

## Notes

- 외부 노출 계획이 전혀 없으므로 priority:low
- 헤더 자체를 제거하는 것이 아님 — 주석 추가만
EOF
)"
echo "  -> Created"

# ─────────────────────────────────────────────────────────────
# Issue 6: nix-ld.libraries Playwright 의존성 분리
# ─────────────────────────────────────────────────────────────
echo "Creating issue 6/10: nix-ld.libraries Playwright 의존성 모듈 분리"
gh issue create --repo "$REPO" \
  --title "refactor: nix-ld.libraries Playwright 의존성 30개를 별도 모듈로 분리" \
  --label "enhancement,priority:low,area:maintenance" \
  --body "$(cat <<'EOF'
## Summary

configuration.nix에 agent-browser용 Playwright 의존성 30개+가 인라인으로 나열되어 있어, 별도 모듈로 분리하여 configuration.nix 가독성을 개선하고 필요시 비활성화할 수 있게 한다.

## Context

- `modules/nixos/configuration.nix:96-130`에 X11, GTK, mesa 등 30개+ 라이브러리가 `programs.nix-ld.libraries`에 직접 나열
- agent-browser (Playwright Chromium) 전용이나 configuration.nix에 inline으로 존재
- nix-ld.libraries는 모든 동적 링크 바이너리에 영향을 줌
- agent-browser 사용 빈도에 비해 configuration.nix에서 차지하는 비중이 큼 (~35줄)

## Related Commits

N/A

## Affected Files

| File | Role | Required Change |
|------|------|-----------------|
| `modules/nixos/programs/agent-browser-deps.nix` | (신규) Playwright 의존성 모듈 | nix-ld.libraries 설정 이동 |
| `modules/nixos/configuration.nix` | NixOS 시스템 설정 | nix-ld.libraries 인라인 블록을 import로 교체 |

## Proposed Changes

- [ ] `modules/nixos/programs/agent-browser-deps.nix` 생성 — `programs.nix-ld.libraries` 설정 이동
- [ ] configuration.nix에서 해당 블록 제거, import 추가
- [ ] `programs.nix-ld.enable = true`는 configuration.nix에 유지 (agent-browser 외에도 필요할 수 있음)

## Acceptance Criteria

- [ ] configuration.nix에서 Playwright 라이브러리 목록 제거됨
- [ ] agent-browser가 기존과 동일하게 동작
- [ ] `nix eval --impure --file tests/eval-tests.nix` 통과

## Notes

- 당장 agent-browser를 비활성화할 필요는 없으므로 단순 파일 분리만 수행
- 향후 필요 시 mkEnableOption으로 전환 가능하나 현재는 YAGNI
EOF
)"
echo "  -> Created"

# ─────────────────────────────────────────────────────────────
# Issue 7: .agents/skills 투영 로직 복잡도 점검
# ─────────────────────────────────────────────────────────────
echo "Creating issue 7/10: Codex 스킬 투영 로직 복잡도 점검"
gh issue create --repo "$REPO" \
  --title "chore: Codex 스킬 투영 activation script 복잡도 점검 — 사용 빈도 대비 70줄 로직" \
  --label "enhancement,priority:low,area:maintenance" \
  --body "$(cat <<'EOF'
## Summary

Codex CLI용 `.agents/skills/` 투영 로직이 activation script 70줄으로 복잡한데, Codex 사용 빈도가 낮다면 간소화를 검토한다.

## Context

- `modules/shared/programs/codex/default.nix`의 `createCodexProjectSymlinks` activation이 ~70줄
- 처리 내용: `.claude/skills/` → `.agents/skills/` SKILL.md 복사, openai.yaml 생성, 심링크 관리, 고아 정리
- pre-commit에 `warn-skill-consistency.sh`도 별도 존재
- `.agents/skills/`에는 viewing-immich-photo가 빠져있는 등 불일치 존재
- Codex CLI 실제 사용 빈도에 따라 이 복잡도가 정당화되는지 판단 필요

## Related Commits

N/A

## Affected Files

| File | Role | Required Change |
|------|------|-----------------|
| `modules/shared/programs/codex/default.nix` | Codex CLI 설정 | 투영 로직 간소화 검토 |
| `scripts/ai/warn-skill-consistency.sh` | pre-commit 스킬 일관성 경고 | 필요성 재평가 |

## Proposed Changes

- [ ] Codex CLI 실제 사용 빈도 확인 (사용하지 않으면 투영 로직 전체 비활성화 고려)
- [ ] 사용한다면: viewing-immich-photo 누락 등 불일치 수정
- [ ] 사용하지 않는다면: activation script 간소화 또는 제거

## Acceptance Criteria

- [ ] 사용 여부에 따른 명확한 결정이 반영됨
- [ ] 유지하는 경우: `.agents/skills/`와 `.claude/skills/` 간 불일치 해소
- [ ] 제거하는 경우: codex/default.nix에서 투영 로직 제거, warn-skill-consistency.sh 정리

## Notes

- Codex를 적극 사용 중이라면 현 구조 유지가 정당함
- 판단은 사용자 확인 후 진행
EOF
)"
echo "  -> Created"

# ─────────────────────────────────────────────────────────────
# Issue 8: homeserver 옵션 네이밍/백업 활성화 불일치
# ─────────────────────────────────────────────────────────────
echo "Creating issue 8/10: homeserver 백업 옵션 활성화 패턴 통일"
gh issue create --repo "$REPO" \
  --title "refactor: homeserver 백업 옵션 활성화 패턴 통일 — immichBackup vs vaultwarden-backup 불일치" \
  --label "enhancement,priority:medium,area:maintenance" \
  --body "$(cat <<'EOF'
## Summary

immich 백업은 별도 `homeserver.immichBackup.enable`로 독립 제어 가능하나, vaultwarden 백업은 `homeserver.vaultwarden.enable`에 암묵적으로 종속되어 있어 패턴이 불일치한다. 하나로 통일한다.

## Context

- `immich-backup.nix:106` — `lib.mkIf (cfg.enable && immichCfg.enable)` — 별도 enable 옵션
- `vaultwarden-backup.nix:75` — `lib.mkIf cfg.enable` — vaultwarden.enable에 종속
- immich 백업: `homeserver.immichBackup.enable = true`로 독립 제어
- vaultwarden 백업: vaultwarden을 켜면 자동으로 백업도 활성화 (별도 제어 불가)
- 향후 "백업만 끄고 서비스는 유지" 또는 반대 상황에서 혼란 발생 가능

## Related Commits

N/A

## Affected Files

| File | Role | Required Change |
|------|------|-----------------|
| `modules/nixos/options/homeserver.nix` | 홈서버 옵션 정의 | 통일 방향에 따라 옵션 추가 또는 제거 |
| `modules/nixos/programs/docker/vaultwarden-backup.nix` | Vaultwarden 백업 | mkIf 조건 변경 |
| `modules/nixos/configuration.nix` | NixOS 설정 | 필요 시 enable 라인 추가 |

## Proposed Changes

두 가지 방향 중 택1:

**방향 A: 모든 백업을 서비스에 종속 (간단)**
- [ ] `homeserver.immichBackup` 옵션 제거
- [ ] `immich-backup.nix`의 mkIf를 `immichCfg.enable`만으로 변경
- [ ] configuration.nix에서 `homeserver.immichBackup.enable = true` 제거

**방향 B: 모든 백업을 독립 옵션으로 분리 (유연)**
- [ ] `homeserver.vaultwardenBackup` 옵션 추가 (homeserver.nix)
- [ ] `vaultwarden-backup.nix`의 mkIf를 `vaultwardenBackupCfg.enable && vaultwardenCfg.enable`으로 변경
- [ ] configuration.nix에 `homeserver.vaultwardenBackup.enable = true` 추가

## Acceptance Criteria

- [ ] 모든 백업 서비스의 활성화 패턴이 동일
- [ ] `nix eval --impure --file tests/eval-tests.nix` 통과
- [ ] 백업 timer가 기존과 동일하게 동작

## Notes

- 현재 서비스와 백업을 따로 끌 필요가 실질적으로 없으므로 방향 A(서비스 종속)가 YAGNI 원칙에 부합
- 다만 방향 B가 기존 immich 패턴과 일관성 있음
EOF
)"
echo "  -> Created"

# ─────────────────────────────────────────────────────────────
# Issue 9: darwin/nixos home.nix 공통 import 추출
# ─────────────────────────────────────────────────────────────
echo "Creating issue 9/10: home.nix 공통 import 목록 추출"
gh issue create --repo "$REPO" \
  --title "refactor: darwin/nixos home.nix 공통 import 10개를 단일 리스트로 추출" \
  --label "enhancement,priority:low,area:maintenance" \
  --body "$(cat <<'EOF'
## Summary

darwin/nixos 양쪽 home.nix에서 동일한 10개 공유 모듈 import 목록이 중복되어 있어, 단일 파일로 추출하여 공유 모듈 추가 시 한 곳만 수정하면 되도록 한다.

## Context

- `modules/darwin/home.nix:38-54`과 `modules/nixos/home.nix:23-40`에 동일한 import 목록:
  - agenix, secrets, broot, agent-browser, claude, codex, direnv, git, lazygit, shell, tmux, neovim
- 공유 모듈 추가 시 양쪽을 같이 수정해야 함
- 누락 시 한쪽에서만 모듈이 로딩되지 않는 문제 발생 가능

## Related Commits

N/A

## Affected Files

| File | Role | Required Change |
|------|------|-----------------|
| `libraries/shared-home-imports.nix` | (신규) 공통 import 리스트 | 공유 모듈 import 목록 정의 |
| `modules/darwin/home.nix` | macOS Home Manager | import를 shared-home-imports 참조로 교체 |
| `modules/nixos/home.nix` | NixOS Home Manager | import를 shared-home-imports 참조로 교체 |

## Proposed Changes

- [ ] `libraries/shared-home-imports.nix` 생성 — 공유 모듈 경로 리스트 반환
- [ ] darwin/home.nix에서 공통 import를 `shared-home-imports` + darwin 전용으로 분리
- [ ] nixos/home.nix에서 공통 import를 `shared-home-imports` + nixos 전용으로 분리

## Acceptance Criteria

- [ ] 공유 모듈 추가 시 `shared-home-imports.nix`만 수정하면 양쪽 반영
- [ ] darwin/nixos 양쪽 빌드 성공 (darwin은 `ssh mac "nrp"`, nixos는 `nrp`)
- [ ] 기존과 동일한 프로그램이 설치됨

## Notes

- 공유 모듈 추가 빈도가 낮다면 우선순위 낮음
- `inputs`를 import 리스트에서 참조해야 하므로 함수 형태(`{ inputs }: [...]`)로 구현 필요
EOF
)"
echo "  -> Created"

# ─────────────────────────────────────────────────────────────
# Issue 10: TODO 주석 정리
# ─────────────────────────────────────────────────────────────
echo "Creating issue 10/10: lm-sensors TODO 주석 정리"
gh issue create --repo "$REPO" \
  --title "chore: configuration.nix의 lm-sensors TODO 주석을 이슈로 이관 후 제거" \
  --label "enhancement,priority:low,area:maintenance" \
  --body "$(cat <<'EOF'
## Summary

configuration.nix에 방치된 lm-sensors 온도 모니터링 TODO 주석을 이슈로 이관하고, 코드에서 TODO를 제거한다.

## Context

- `modules/nixos/configuration.nix:85-87`에 다음 TODO 존재:
  ```
  # TODO: lm-sensors 온도 모니터링 + Pushover 알림 (향후 구현)
  # 현재: lm_sensors 패키지만 설치. 수동 확인: sensors
  # 계획: systemd timer 온도 체크 + 임계값 초과 시 Pushover (pushover-system-monitor 재사용)
  ```
- 코드 내 TODO는 잊혀지기 쉬움
- 이슈로 추적하는 것이 더 효과적

## Related Commits

N/A

## Affected Files

| File | Role | Required Change |
|------|------|-----------------|
| `modules/nixos/configuration.nix` | NixOS 시스템 설정 | TODO 주석 3줄 제거, 간단한 현 상태 주석으로 대체 |

## Proposed Changes

- [ ] TODO 주석 3줄 제거
- [ ] `# lm_sensors: 수동 확인만 가능 (sensors). 자동화는 별도 이슈 참조.` 한 줄로 대체
- [ ] lm-sensors 자동화 구현이 필요하면 별도 이슈 생성 (이 이슈 범위 아님)

## Acceptance Criteria

- [ ] configuration.nix에 TODO 키워드 없음
- [ ] lm_sensors 패키지 설치는 유지됨

## Notes

- lm-sensors 온도 모니터링 자동화 자체의 구현 여부는 이 이슈 범위 밖
- 실제로 구현할 의향이 있으면 별도 feat 이슈로 생성
EOF
)"
echo "  -> Created"

echo ""
echo "=== 완료: 10개 이슈 생성됨 ==="
echo ""
echo "확인: gh issue list --repo $REPO --limit 20"
