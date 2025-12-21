#!/usr/bin/env bash
# Bash 3.x OK

set -euo pipefail

# 1) 현재 prefix 테이블에서 "키"만 추출
#    bind-key ... -T prefix <KEY> ... 형태에서 <KEY>만 뽑는다.
BOUND="$(tmux list-keys -T prefix 2>/dev/null \
  | awk '{
      for (i=1;i<=NF;i++) {
        if ($i=="-T" && $(i+1)=="prefix") { print $(i+2); break }
      }
    }' \
  | tr -d '\r' \
  | sort -u)"

# 2) 후보 키셋 — 필요하면 추가/삭제
CANDIDATES="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_/;,'[]\\="

# 3) 후보 중 미사용 키만 출력 (고정문자 검색: grep -F)
unused() {
  printf "%s" "$CANDIDATES" \
  | awk '{ for (i=1;i<=length($0);i++) print substr($0,i,1) }' \
  | while read k; do
      [ -z "$k" ] && continue
      echo "$BOUND" | grep -F -x -- "$k" >/dev/null 2>&1 || echo "$k"
    done
}

echo "Unused prefix keys:"
unused