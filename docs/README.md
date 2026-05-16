# docs/

## Governance surface 조회

```bash
# claude hooks
find modules/shared/programs/claude/files/hooks -type f | wc -l
find modules/shared/programs/claude/files/hooks -type f -exec wc -l {} + | tail -1

# codex hooks
find modules/shared/programs/codex/files/hooks -type f | wc -l
find modules/shared/programs/codex/files/hooks -type f -exec wc -l {} + | tail -1

# claude lib
find modules/shared/programs/claude/files/lib -type f | wc -l
find modules/shared/programs/claude/files/lib -type f -exec wc -l {} + | tail -1

# claude skills (SKILL.md + references/*)
find modules/shared/programs/claude/files/skills -type f \( -name 'SKILL.md' -o -path '*/references/*' \) | wc -l
find modules/shared/programs/claude/files/skills -type f \( -name 'SKILL.md' -o -path '*/references/*' \) -exec wc -l {} + | tail -1
```
