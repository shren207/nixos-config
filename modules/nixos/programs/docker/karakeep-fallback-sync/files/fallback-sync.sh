# shellcheck shell=bash
# shellcheck source=/dev/null
source "$PUSHOVER_CRED_FILE"
# shellcheck source=/dev/null
source "$SERVICE_LIB"

: "${FALLBACK_DIR:?FALLBACK_DIR is required}"
: "${FAILED_URL_QUEUE_FILE:?FAILED_URL_QUEUE_FILE is required}"
: "${KARAKEEP_BASE_URL:?KARAKEEP_BASE_URL is required}"

STATE_DIR=$(dirname "$FAILED_URL_QUEUE_FILE")
LOCK_FILE="${STATE_DIR}/fallback-sync.lock"
PROCESSED_FILE="${STATE_DIR}/fallback-processed.tsv"
NOTIFY_STATE_FILE="${STATE_DIR}/fallback-notify-state.tsv"
NOTIFY_DEDUP_WINDOW_SEC=1800

mkdir -p "$STATE_DIR"
touch "$FAILED_URL_QUEUE_FILE" "$PROCESSED_FILE" "$NOTIFY_STATE_FILE"

if command -v flock > /dev/null 2>&1; then
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    echo "Another karakeep-fallback-sync run is in progress"
    exit 0
  fi
else
  echo "WARNING: flock command not found; running without lock"
fi

API_KEY="${KARAKEEP_API_KEY:-${KARAKEEP_SINGLEFILE_API_KEY:-}}"
if [ -z "$API_KEY" ]; then
  echo "KARAKEEP_API_KEY is not set in PUSHOVER_CRED_FILE; skipping auto relink"
  exit 0
fi

normalize_url() {
  local url="$1"
  url="${url#http://}"
  url="${url#https://}"
  url="${url%%#*}"
  url="${url%/}"
  printf "%s" "$url"
}

normalize_url_loose() {
  local url
  url=$(normalize_url "$1")
  url="${url%%\?*}"
  printf "%s" "$url"
}

shorten_url() {
  local url="$1"
  if [ "$url" = "(unknown URL)" ]; then
    printf "%s" "$url"
    return 0
  fi
  url="${url#http://}"
  url="${url#https://}"
  url="${url%%\?*}"
  url="${url%/}"
  printf "%s" "$url"
}

should_notify_key() {
  local key="$1"
  local now previous tmp
  now=$(date +%s)
  previous=$(awk -F '\t' -v key="$key" '$1 == key { print $2 }' "$NOTIFY_STATE_FILE" | tail -n 1)
  previous="${previous:-0}"

  if (( now - previous < NOTIFY_DEDUP_WINDOW_SEC )); then
    return 1
  fi

  tmp=$(mktemp)
  awk -F '\t' -v key="$key" '$1 != key { print }' "$NOTIFY_STATE_FILE" > "$tmp"
  printf "%s\t%s\n" "$key" "$now" >> "$tmp"
  mv "$tmp" "$NOTIFY_STATE_FILE"
  return 0
}

remove_queue_url() {
  local target="$1"
  local tmp
  tmp=$(mktemp)

  awk -v target="$target" '
    BEGIN { removed = 0 }
    {
      if (!removed && $0 == target) {
        removed = 1
        next
      }
      print
    }
    END {
      if (!removed) exit 1
    }
  ' "$FAILED_URL_QUEUE_FILE" > "$tmp" || {
    rm -f "$tmp"
    return 1
  }

  mv "$tmp" "$FAILED_URL_QUEUE_FILE"
  return 0
}

extract_url_candidates() {
  local file="$1"
  local snippet
  snippet=$(mktemp)
  head -c 2097152 "$file" > "$snippet"

  {
    grep -Eoi '<link[^>]+rel=["'"'"'"'"'"'"'"'"']canonical["'"'"'"'"'"'"'"'"'][^>]*>' "$snippet" \
      | sed -En 's/.*href=["'"'"'"'"'"'"'"'"']([^"'"'"'"'"'"'"'"'"']+)["'"'"'"'"'"'"'"'"'].*/\1/ip'
    grep -Eoi '<meta[^>]+property=["'"'"'"'"'"'"'"'"']og:url["'"'"'"'"'"'"'"'"'][^>]*>' "$snippet" \
      | sed -En 's/.*content=["'"'"'"'"'"'"'"'"']([^"'"'"'"'"'"'"'"'"']+)["'"'"'"'"'"'"'"'"'].*/\1/ip'
    grep -Eoi '<meta[^>]+name=["'"'"'"'"'"'"'"'"']twitter:url["'"'"'"'"'"'"'"'"'][^>]*>' "$snippet" \
      | sed -En 's/.*content=["'"'"'"'"'"'"'"'"']([^"'"'"'"'"'"'"'"'"']+)["'"'"'"'"'"'"'"'"'].*/\1/ip'
    grep -Eom200 'https?://[^"'"'"'"'"'"'"'"'"' <>)]+' "$snippet"
  } | sed -E 's/&amp;/\&/g' | grep -E '^https?://' | sort -u

  rm -f "$snippet"
}

find_matching_failed_url() {
  local file="$1"
  local queue_url queue_norm queue_loose
  local candidate candidate_norm candidate_loose
  local -a queue_urls candidates

  mapfile -t queue_urls < "$FAILED_URL_QUEUE_FILE"
  [ "${#queue_urls[@]}" -gt 0 ] || return 1

  mapfile -t candidates < <(extract_url_candidates "$file")
  [ "${#candidates[@]}" -gt 0 ] || return 1

  for queue_url in "${queue_urls[@]}"; do
    queue_norm=$(normalize_url "$queue_url")
    queue_loose=$(normalize_url_loose "$queue_url")
    for candidate in "${candidates[@]}"; do
      candidate_norm=$(normalize_url "$candidate")
      candidate_loose=$(normalize_url_loose "$candidate")
      if [ "$candidate_norm" = "$queue_norm" ] || [ "$candidate_loose" = "$queue_loose" ]; then
        printf "%s" "$queue_url"
        return 0
      fi
    done
  done

  return 1
}

upload_singlefile_archive() {
  local file="$1"
  local url="$2"
  local endpoint
  endpoint="${KARAKEEP_BASE_URL%/}/api/v1/bookmarks/singlefile?ifexists=overwrite"

  curl -sf --max-time 240 \
    -H "Authorization: Bearer ${API_KEY}" \
    --form-string "url=${url}" \
    -F "file=@${file}" \
    "$endpoint" > /dev/null
}

process_file() {
  local file="$1"
  local file_hash failed_url short_url notify_key
  file_hash=$(sha256sum "$file" | cut -d ' ' -f 1)

  if grep -Fq "${file_hash}" "$PROCESSED_FILE"; then
    return 0
  fi

  failed_url=$(find_matching_failed_url "$file" || true)
  if [ -z "$failed_url" ]; then
    notify_key="unmatched:${file_hash}"
    if should_notify_key "$notify_key"; then
      send_notification "Karakeep" \
        "자동 재연결 보류: $(basename "$file")\n원인: 실패 URL 매칭 불가\n확인 경로: ${FALLBACK_DIR}" 0
    fi
    echo "No matching failed URL for file: $file"
    return 0
  fi

  if upload_singlefile_archive "$file" "$failed_url"; then
    remove_queue_url "$failed_url" || true
    printf "%s\t%s\t%s\t%s\n" "$file_hash" "$failed_url" "$file" "$(date -Iseconds)" >> "$PROCESSED_FILE"
    short_url=$(shorten_url "$failed_url")
    send_notification "Karakeep" \
      "자동 재연결 완료: ${short_url}\n파일: $(basename "$file")" 0
    echo "Auto relink succeeded: $failed_url <- $file"
    return 0
  fi

  notify_key="upload-failed:$(normalize_url_loose "$failed_url")"
  if should_notify_key "$notify_key"; then
    send_notification "Karakeep" \
      "자동 재연결 실패: $(shorten_url "$failed_url")\n파일: $(basename "$file")\njournalctl -u karakeep-fallback-sync 확인 필요" 0
  fi
  echo "Auto relink failed: $failed_url <- $file"
  return 1
}

if [ ! -d "$FALLBACK_DIR" ]; then
  echo "Fallback directory does not exist: $FALLBACK_DIR"
  exit 0
fi

if ! [ -s "$FAILED_URL_QUEUE_FILE" ]; then
  echo "No pending failed URLs in queue"
  exit 0
fi

mapfile -t fallback_files < <(
  find "$FALLBACK_DIR" -maxdepth 1 -type f \( -name "*.html" -o -name "*.htm" -o -name "*.xhtml" \) \
    -printf '%T@ %p\n' | sort -n | sed -E 's/^[0-9.]+ //'
)

if [ "${#fallback_files[@]}" -eq 0 ]; then
  echo "No fallback HTML files found"
  exit 0
fi

for file in "${fallback_files[@]}"; do
  process_file "$file" || break
done
