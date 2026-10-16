#!/bin/bash
# Smoke tests: feed sample session JSON to the script and compare the output
# with ANSI colors stripped.

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/statusline-command.sh"
FAILED=0

# Run from / so the default directory (".") is never inside a git repository.
render() { (cd / && bash "$SCRIPT" <<<"$1") | sed $'s/\033\\[[0-9;]*m//g'; }

check() {
  local name=$1 expected=$2 actual=$3
  if [[ $actual == "$expected" ]]; then
    printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s\n--- expected\n%s\n--- actual\n%s\n' "$name" "$expected" "$actual"
    FAILED=1
  fi
}

check "empty input falls back to defaults" \
"◆ claude · 📁 . · \$0.00
░░░░░░░░░░░░░░░░░░░░ 0% context · +0/-0 · 0s wall · 0s api" \
"$(render '{}')"

check "full session without rate limits" \
"◆ Opus · high · ⚡fast · 📁 /nonexistent · \$1.23
████████░░░░░░░░░░░░ 42% context · +156/-23 · 2h 15m 15s wall · 22m 15s api" \
"$(render '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/nonexistent"},
  "context_window":{"used_percentage":42.7},"effort":{"level":"high"},"fast_mode":true,
  "cost":{"total_cost_usd":1.2345,"total_duration_ms":8115000,"total_api_duration_ms":1335000,
          "total_lines_added":156,"total_lines_removed":23}}')"

# A reset time in the past renders "now", which keeps this case clock-independent
# apart from the formatted timestamp, so only the bars and percentages are compared.
check "rate limit bars" \
"5h ██████░░░░ 63%  ·  7d ██████████ 100%" \
"$(render '{"rate_limits":{"five_hour":{"used_percentage":63.9},"seven_day":{"used_percentage":100}}}' | sed -n 3p)"

check "past reset shows now" \
"(now)" \
"$(render '{"rate_limits":{"five_hour":{"used_percentage":5,"resets_at":1}}}' | sed -n 3p | grep -o '(now)')"

check "session name from JSON" \
"✎ my session · ◆ claude · 📁 . · \$0.00" \
"$(render '{"session_name":"my session"}' | sed -n 1p)"

TRANSCRIPT=$(mktemp)
printf '%s\n' '{"type":"custom-title","customTitle":"old name"}' \
               '{"type":"custom-title","customTitle":"renamed"}' >"$TRANSCRIPT"
check "session name falls back to transcript" \
"✎ renamed · ◆ claude · 📁 . · \$0.00" \
"$(render "{\"transcript_path\":\"$TRANSCRIPT\"}" | sed -n 1p)"
rm -f "$TRANSCRIPT"

exit $FAILED
