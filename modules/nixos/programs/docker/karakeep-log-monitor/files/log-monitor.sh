# shellcheck shell=bash
# shellcheck source=/dev/null
source "$PUSHOVER_CRED_FILE"
# shellcheck source=/dev/null
source "$SERVICE_LIB"

COPYPARTY_UPLOAD_URL="${COPYPARTY_FALLBACK_URL:-https://copyparty.greenhead.dev/archive-fallback/}"
DEDUP_WINDOW_SEC=1800
FAILED_URL_QUEUE_FILE="${FAILED_URL_QUEUE_FILE:-/var/lib/karakeep-log-monitor/failed-urls.queue}"
FAILED_URL_QUEUE_MAX="${FAILED_URL_QUEUE_MAX:-200}"
LAST_CRAWL_URL=""
declare -A NOTIFIED_URLS=()

mkdir -p "$(dirname "$FAILED_URL_QUEUE_FILE")"
touch "$FAILED_URL_QUEUE_FILE"

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

should_notify_url() {
  local url="$1"
  local now previous
  now=$(date +%s)
  previous="${NOTIFIED_URLS[$url]-0}"

  if (( now - previous < DEDUP_WINDOW_SEC )); then
    return 1
  fi

  NOTIFIED_URLS[$url]="$now"
  return 0
}

enqueue_failed_url() {
  local failed_url="$1"
  local tmp

  if [ -z "$failed_url" ] || [ "$failed_url" = "(unknown URL)" ]; then
    return 0
  fi

  if grep -Fxq "$failed_url" "$FAILED_URL_QUEUE_FILE"; then
    return 0
  fi

  printf "%s\n" "$failed_url" >> "$FAILED_URL_QUEUE_FILE"
  tmp=$(mktemp)
  tail -n "$FAILED_URL_QUEUE_MAX" "$FAILED_URL_QUEUE_FILE" > "$tmp"
  mv "$tmp" "$FAILED_URL_QUEUE_FILE"
}

send_failure_alert() {
  local reason="$1"
  local priority="$2"
  local explicit_url="${3:-}"
  local failed_url short_url message

  if [ -n "$explicit_url" ]; then
    failed_url="$explicit_url"
  elif [ -n "$LAST_CRAWL_URL" ]; then
    failed_url="$LAST_CRAWL_URL"
  else
    failed_url="(unknown URL)"
  fi

  enqueue_failed_url "$failed_url"

  if ! should_notify_url "$failed_url"; then
    echo "Dedup: skipped alert for ${failed_url}"
    return 0
  fi

  short_url=$(shorten_url "$failed_url")
  message=$(printf "아카이브 실패: %s\n원인: %s\n수동 보관: %s" "$short_url" "$reason" "$COPYPARTY_UPLOAD_URL")
  send_notification "Karakeep" "$message" "$priority"
  echo "Alert sent: ${reason} (${short_url})"
}

echo "Karakeep log monitor started"
echo "Watching podman-karakeep.service..."

while IFS= read -r line; do
  if [[ "$line" =~ Will\ crawl\ \"([^\"]+)\" ]]; then
    LAST_CRAWL_URL="${BASH_REMATCH[1]}"
    echo "Tracked URL: ${LAST_CRAWL_URL}"
    continue
  fi

  if [[ "$line" =~ FATAL\ ERROR.*heap ]]; then
    send_failure_alert "V8 heap OOM" 1
    continue
  fi

  if [[ "$line" =~ OOM\ killed\ \(exit\ code\ [0-9]+\) ]]; then
    send_failure_alert "Parser subprocess OOM" 0
    continue
  fi

  if [[ "$line" =~ Crawling\ job\ failed: ]]; then
    failed_url=""
    if [[ "$line" =~ \"([^\"]+)\" ]]; then
      failed_url="${BASH_REMATCH[1]}"
    fi
    send_failure_alert "Crawling job failed" 0 "$failed_url"
    continue
  fi
done < <(journalctl -u podman-karakeep.service -f -o cat --since "now" --no-pager)
