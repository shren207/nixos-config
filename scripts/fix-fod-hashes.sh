#!/usr/bin/env bash
# scripts/fix-fod-hashes.sh
# Fixed-Output Derivation (FOD) hash mismatch 자동 감지 및 수정
#
# nixpkgs 등 input 업데이트 후 FOD hash가 깨지면
# 빌드 에러에서 올바른 hash를 추출해 .nix 파일을 자동 교체한다.
#
# 사용법:
#   ./scripts/fix-fod-hashes.sh          # 독립 실행
#   ./scripts/update-input.sh nixpkgs    # 내부에서 자동 호출
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# 현재 시스템의 flake output attribute 결정
if [[ "$(uname)" == "Darwin" ]]; then
  HOST=$(scutil --get LocalHostName)
  ATTR="darwinConfigurations.\"${HOST}\".config.system.build.toplevel"
else
  HOST=$(hostname -s)
  ATTR="nixosConfigurations.\"${HOST}\".config.system.build.toplevel"
fi

MAX_ROUNDS=3
fixed=0

echo "═══ FOD Hash 검증 ═══"
echo "대상: ${HOST}"

for (( round=1; round<=MAX_ROUNDS+1; round++ )); do
  echo ""
  if (( round <= MAX_ROUNDS )); then
    echo "빌드 검증 중... (${round}/${MAX_ROUNDS})"
  else
    echo "최종 검증 빌드..."
  fi

  build_output=""
  if build_output=$(nix build ".#${ATTR}" --no-link 2>&1); then
    break
  fi

  # 최대 수정 횟수 도달 — 더 이상 수정 없이 실패
  if (( round > MAX_ROUNDS )); then
    echo "❌ ${MAX_ROUNDS}회 수정 후에도 빌드 실패:"
    echo "$build_output" | tail -20
    exit 1
  fi

  # hash mismatch 파싱 (nix 출력 형식: "  specified: sha256-..." / "  got: sha256-...")
  mapfile -t old_hashes < <(awk '/specified:.*sha256-/{print $2}' <<< "$build_output")
  mapfile -t new_hashes < <(awk '/got:.*sha256-/{print $2}' <<< "$build_output")

  if (( ${#old_hashes[@]} == 0 )); then
    echo "❌ hash mismatch가 아닌 빌드 에러:"
    echo "$build_output" | tail -20
    exit 1
  fi

  for i in "${!old_hashes[@]}"; do
    old="${old_hashes[$i]}"
    new="${new_hashes[$i]}"

    # -F: 고정 문자열 매칭 (hash를 정규식으로 해석하지 않음)
    file=$(grep -Frl --include='*.nix' "$old" . | head -1 || true)
    if [[ -z "$file" ]]; then
      echo "❌ hash를 포함하는 .nix 파일을 찾을 수 없음: $old"
      exit 1
    fi

    echo "  수정: ${file#./}"
    echo "    ${old} → ${new}"
    # Nix SRI hash는 [A-Za-z0-9+/=-]만 포함하여 sed 구분자 '|'와 충돌 없음.
    # macOS BSD sed 호환을 위해 tmpfile 패턴 사용.
    tmp=$(mktemp)
    sed "s|${old}|${new}|" "$file" > "$tmp" && mv "$tmp" "$file"
    ((fixed++))
  done
done

echo ""
if (( fixed > 0 )); then
  echo "✓ ${fixed}개 FOD hash 자동 수정 완료"
  echo ""
  echo "변경 파일:"
  git diff --name-only
else
  echo "✓ FOD hash mismatch 없음"
fi
