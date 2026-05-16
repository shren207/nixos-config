#!/usr/bin/env bats
# statusline.sh polh 측정 fallback chain unit tests.
#
# 각 케이스는 mock stdin JSON 과 env 매트릭스를 조합해 statusline.sh 출력을
# 검사한다. 폭은 raw cols 로 입력되며 statusline.sh 내부에서 `EFF_COLS = COLS - 40`
# 보정이 적용된 뒤 RATE_DETAIL 임계값(88/58/40)과 session-id 표시 조건(EFF_COLS>=100)
# 이 평가된다.
#
# 회귀 시 assertion 메시지에는 어떤 fallback 단계가 hit 됐다고 기대했는지
# 명시한다. 출력의 ANSI 이스케이프와 OSC 8 hyperlink 가 grep 패턴을 깨지 않도록
# 패턴은 색 코드 무관한 키 토큰만 매칭한다.

setup() {
  STATUSLINE="${BATS_TEST_DIRNAME}/../statusline.sh"
  MOCK_JSON='{
    "session_id": "abc12345-def6-7890-abcd-ef1234567890",
    "transcript_path": "/tmp/nonexistent.jsonl",
    "cwd": "/tmp",
    "model": {"display_name": "test"},
    "workspace": {"current_dir": "/tmp"},
    "rate_limits": {
      "five_hour": {"used_percentage": 6, "resets_at": 1747400000},
      "seven_day": {"used_percentage": 82, "resets_at": 1747900000}
    },
    "context_window": {
      "current_usage": {
        "cache_read_input_tokens": 8000,
        "cache_creation_input_tokens": 2000
      }
    }
  }'
}

run_statusline() {
  # env 인자: NAME=VALUE 형태로 0개 이상 전달.
  # stdout 만 capture (stderr 누설 노이즈 차단).
  printf '%s' "$MOCK_JSON" | env -u CLAUDE_STATUSLINE_COLUMNS -u COLUMNS "$@" bash "$STATUSLINE" 2>/dev/null
}

@test "env override 200 enables full detail + full UUID" {
  run run_statusline CLAUDE_STATUSLINE_COLUMNS=200
  [ "$status" -eq 0 ]
  # full UUID = 36 자 UUID 형식. session_id 의 long form 이 통째로 나와야 한다.
  echo "$output" | grep -q "abc12345-def6-7890-abcd-ef1234567890" \
    || { echo "expected full UUID from env=200 path; got: $output" >&2; false; }
  # detail=4 시 reset_date 가 `(MM/DD HH:MM)` 형식으로 두 window 모두 표시.
  reset_count=$(echo "$output" | grep -oE '\([0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}\)' | wc -l)
  [ "$reset_count" -eq 2 ] \
    || { echo "expected detail=4 (2 reset_date) from env=200; got count=$reset_count" >&2; false; }
}

@test "env override 50 collapses to compact output (short UUID, no reset_date)" {
  run run_statusline CLAUDE_STATUSLINE_COLUMNS=50
  [ "$status" -eq 0 ]
  # short prefix = 처음 8 자 + space. EFF_COLS=50 < 100 → short.
  echo "$output" | grep -qE 'abc12345[^-]' \
    || { echo "expected short UUID prefix from env=50; got: $output" >&2; false; }
  # full UUID 가 나오면 실패. 추가 확인.
  if echo "$output" | grep -q "abc12345-def6"; then
    echo "expected short UUID, but full UUID leaked from env=50; got: $output" >&2
    false
  fi
  # detail<3 시 reset_date 형식이 없어야 함.
  if echo "$output" | grep -qE '\([0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}\)'; then
    echo "expected no reset_date from env=50 (detail<3); got: $output" >&2
    false
  fi
}

@test "COLUMNS fallback when CLAUDE_STATUSLINE_COLUMNS unset" {
  run run_statusline COLUMNS=150
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "abc12345-def6-7890-abcd-ef1234567890" \
    || { echo "expected full UUID from COLUMNS=150 fallback; got: $output" >&2; false; }
  reset_count=$(echo "$output" | grep -oE '\([0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}\)' | wc -l)
  [ "$reset_count" -eq 2 ] \
    || { echo "expected detail=4 from COLUMNS=150 fallback; got count=$reset_count" >&2; false; }
}

@test "static default 140 enables full detail when all sources unset" {
  run run_statusline
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "abc12345-def6-7890-abcd-ef1234567890" \
    || { echo "expected full UUID from static default 140; got: $output" >&2; false; }
  reset_count=$(echo "$output" | grep -oE '\([0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}\)' | wc -l)
  [ "$reset_count" -eq 2 ] \
    || { echo "expected detail=4 from static default 140; got count=$reset_count" >&2; false; }
}
