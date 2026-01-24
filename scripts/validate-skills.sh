#!/bin/bash
# scripts/validate-skills.sh

set -e

echo "=== Skills Validation ==="
echo "Date: $(date)"
echo

# 의존성 체크
command -v yq >/dev/null 2>&1 || { echo "Error: yq required. Install: brew install yq"; exit 1; }

echo "## 1. YAML 구문 검증"
for f in .claude/skills/*/SKILL.md; do
  if sed -n '2,/^---$/p' "$f" | head -n -1 | yq -e '.name, .description' > /dev/null 2>&1; then
    echo "✅ $(basename "$(dirname "$f")")"
  else
    echo "❌ $(basename "$(dirname "$f")")"
  fi
done

echo
echo "## 2. 길이 검증 (150-260자)"
for f in .claude/skills/*/SKILL.md; do
  len=$(sed -n '2,/^---$/p' "$f" | head -n -1 | yq -r '.description' | wc -c)
  name=$(basename "$(dirname "$f")")
  if [ "$len" -lt 150 ] || [ "$len" -gt 260 ]; then
    echo "⚠️  $name: ${len}자 (범위 초과)"
  else
    echo "✅ $name: ${len}자"
  fi
done
