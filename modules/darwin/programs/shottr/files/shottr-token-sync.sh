#!/usr/bin/env bash
# Vaultwarden -> agenix 반자동 동기화
# 결과물: secrets/shottr-upload-token.age (TOKEN=...)

set -euo pipefail
umask 077

ITEM_NAME="shottr-upload-token"
FIELD_NAME="token"
DRY_RUN=0
REPO_PATH="${SHOTTR_CONFIG_REPO:-$PWD}"

usage() {
  cat <<'USAGE'
Usage: shottr-token-sync [--item <name>] [--field <name>] [--repo <path>] [--dry-run]

Options:
  --item     Vaultwarden item name (default: shottr-upload-token)
  --field    Custom field name for token (default: token)
  --repo     nixos-config repo path (default: $SHOTTR_CONFIG_REPO or current dir)
  --dry-run  Validate inputs without writing .age file
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --item)
      ITEM_NAME="${2:-}"
      shift 2
      ;;
    --field)
      FIELD_NAME="${2:-}"
      shift 2
      ;;
    --repo)
      REPO_PATH="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command not found: $1" >&2
    exit 1
  fi
}

require_cmd bw
require_cmd jq
require_cmd nix

if [ -z "$ITEM_NAME" ] || [ -z "$FIELD_NAME" ] || [ -z "$REPO_PATH" ]; then
  echo "Error: item/field/repo must not be empty." >&2
  exit 1
fi

if [ ! -d "$REPO_PATH" ]; then
  echo "Error: repo path not found: $REPO_PATH" >&2
  exit 1
fi

SECRETS_NIX="$REPO_PATH/secrets/secrets.nix"
AGE_FILE="$REPO_PATH/secrets/shottr-upload-token.age"

if [ ! -f "$SECRETS_NIX" ]; then
  echo "Error: secrets.nix not found: $SECRETS_NIX" >&2
  exit 1
fi

status="$(bw status 2>/dev/null | jq -r '.status // empty' || true)"
if [ "$status" != "unlocked" ]; then
  echo "Error: Bitwarden session is not unlocked. Run 'bw unlock' first." >&2
  exit 2
fi

search_json="$(bw list items --search "$ITEM_NAME")"
item_count="$(printf '%s' "$search_json" | jq --arg name "$ITEM_NAME" '[.[] | select(.name == $name)] | length')"

if [ "$item_count" -ne 1 ]; then
  echo "Error: expected exactly one item named '$ITEM_NAME', got $item_count." >&2
  exit 3
fi

item_json="$(printf '%s' "$search_json" | jq -c --arg name "$ITEM_NAME" '[.[] | select(.name == $name)][0]')"

token_value="$(printf '%s' "$item_json" | jq -r --arg field "$FIELD_NAME" '
  ([.fields[]? | select(.name == $field and (.value // "") != "") | .value][0]) // empty
')"

if [ -z "$token_value" ]; then
  token_value="$(printf '%s' "$item_json" | jq -r '.login.password // empty')"
fi

token_value="$(printf '%s' "$token_value" | tr -d '\r')"
token_value="${token_value%\"}"
token_value="${token_value#\"}"

if [ -z "$token_value" ]; then
  echo "Error: token is empty in Vaultwarden item '$ITEM_NAME'." >&2
  exit 4
fi

case "$token_value" in
  *$'\n'*)
    echo "Error: token contains a newline, refusing to write." >&2
    exit 4
    ;;
esac

recipients_json="$(
  cd "$REPO_PATH"
  nix eval --impure --json --expr 'let s = import ./secrets/secrets.nix; in s."shottr-upload-token.age".publicKeys'
)"

recipients=()
while IFS= read -r recipient; do
  recipients+=("$recipient")
done < <(printf '%s' "$recipients_json" | jq -r '.[]')

if [ "${#recipients[@]}" -eq 0 ]; then
  echo "Error: no recipients found for shottr-upload-token.age in secrets.nix." >&2
  exit 5
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run OK:"
  echo "  repo: $REPO_PATH"
  echo "  item: $ITEM_NAME"
  echo "  field: $FIELD_NAME"
  echo "  recipients: ${#recipients[@]}"
  exit 0
fi

tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT
printf 'TOKEN=%s\n' "$token_value" > "$tmpfile"

age_args=()
for recipient in "${recipients[@]}"; do
  age_args+=("-r" "$recipient")
done

if ! nix shell nixpkgs#age -c age "${age_args[@]}" -o "$AGE_FILE" "$tmpfile" >/dev/null 2>&1; then
  echo "Error: failed to encrypt $AGE_FILE" >&2
  exit 5
fi

if ! nix shell nixpkgs#age -c age -d -i "$HOME/.ssh/id_ed25519" "$AGE_FILE" >/dev/null 2>&1; then
  echo "Error: encrypted file verification failed: $AGE_FILE" >&2
  exit 6
fi

echo "Updated: $AGE_FILE"
echo "Next step: run nrs"
