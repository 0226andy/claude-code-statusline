#!/bin/bash
# Claude Code status line — https://code.claude.com/docs/en/statusline
# Line 1: session name · model · directory · git branch · session cost
# Line 2: context window usage bar · lines changed · elapsed time
# Line 3: 5h / 7d rate limit usage bars · reset time and countdown

input=$(cat)

# One jq pass so the script stays fast. Fields are joined with US (0x1f):
# a tab would not work here, since bash `read` collapses runs of IFS
# whitespace and would drop empty fields, shifting everything after them.
IFS=$'\x1f' read -r MODEL DIR PCT COST DUR API_DUR ADDED REMOVED EFFORT FAST \
                    H5_PCT H5_RESET D7_PCT D7_RESET SESSION_NAME TRANSCRIPT <<<"$(
  jq -r '[
    .model.display_name              // "claude",
    .workspace.current_dir           // .cwd // ".",
    (.context_window.used_percentage // 0 | floor),
    (.cost.total_cost_usd            // 0),
    (.cost.total_duration_ms         // 0),
    (.cost.total_api_duration_ms     // 0),
    (.cost.total_lines_added         // 0),
    (.cost.total_lines_removed       // 0),
    (.effort.level                   // ""),
    (if .fast_mode then "fast" else "" end),
    (.rate_limits.five_hour.used_percentage | if . == null then "" else floor end),
    (.rate_limits.five_hour.resets_at      // ""),
    (.rate_limits.seven_day.used_percentage | if . == null then "" else floor end),
    (.rate_limits.seven_day.resets_at      // ""),
    (.session_name                   // ""),
    (.transcript_path                // "")
  ] | map(tostring) | join("\u001f")' <<<"$input"
)"

# --- colors ---
DIM=$'\033[2m'; RESET=$'\033[0m'
CYAN=$'\033[36m'; BLUE=$'\033[34m'; MAGENTA=$'\033[35m'
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'

# bar <percent> <width> -> colored progress bar on stdout
bar() {
  local pct=$1 width=$2 filled i out="" col
  (( pct < 0 )) && pct=0
  (( pct > 100 )) && pct=100
  filled=$(( pct * width / 100 ))
  if   (( pct >= 80 )); then col=$RED
  elif (( pct >= 50 )); then col=$YELLOW
  else                       col=$GREEN
  fi
  for ((i = 0; i < width; i++)); do
    if (( i < filled )); then out+="█"; else out+="░"; fi
  done
  printf '%s%s%s' "$col" "$out" "$RESET"
}

# epoch_fmt <epoch_seconds> <strftime_format> -> formatted local time
# macOS ships BSD date (-r takes an epoch); GNU date needs -d "@epoch".
if [[ $OSTYPE == darwin* ]]; then
  epoch_fmt() { date -r "$1" +"$2"; }
else
  epoch_fmt() { date -d "@$1" +"$2"; }
fi

# dur_fmt <milliseconds> -> "45s" / "3m 15s" / "2h 15m 15s"
# Larger units only appear once reached, so short sessions stay short.
dur_fmt() {
  local ms=$1 h m s
  h=$(( ms / 3600000 )); m=$(( (ms / 60000) % 60 )); s=$(( (ms / 1000) % 60 ))
  if   (( h > 0 )); then printf '%dh %02dm %02ds' "$h" "$m" "$s"
  elif (( m > 0 )); then printf '%dm %02ds' "$m" "$s"
  else                   printf '%ds' "$s"
  fi
}

# countdown <epoch_seconds> -> "2h11m" / "3d5h" / "" if past or invalid
countdown() {
  local target=$1 now left d h m
  [[ $target =~ ^[0-9]+$ ]] || return
  now=$(date +%s)
  left=$(( target - now ))
  (( left <= 0 )) && { printf 'now'; return; }
  d=$(( left / 86400 )); h=$(( (left % 86400) / 3600 )); m=$(( (left % 3600) / 60 ))
  if   (( d > 0 )); then printf '%dd %dh' "$d" "$h"
  elif (( h > 0 )); then printf '%dh %dm' "$h" "$m"
  else                   printf '%dm' "$m"
  fi
}

# --- git branch + dirty flag ---
GIT=""
if branch=$(git -C "$DIR" rev-parse --abbrev-ref HEAD 2>/dev/null); then
  dirty=""
  git -C "$DIR" diff --quiet --ignore-submodules HEAD 2>/dev/null || dirty="*"
  GIT=" ${DIM}on${RESET} ${MAGENTA}⎇ ${branch}${dirty}${RESET}"
fi

# --- session name ---
# Prefer session_name from the JSON; versions without that field still
# record /rename in the transcript, so fall back to its last customTitle.
if [[ -z $SESSION_NAME && -f $TRANSCRIPT ]]; then
  SESSION_NAME=$(grep -o '"customTitle":"[^"]*"' "$TRANSCRIPT" 2>/dev/null | tail -n 1 | cut -d'"' -f4)
fi
SESSION=""
[[ -n $SESSION_NAME ]] && SESSION="${YELLOW}✎ ${SESSION_NAME}${RESET} ${DIM}·${RESET} "

# --- formatting helpers ---
COST_FMT=$(printf '%.2f' "$COST")
ELAPSED=$(dur_fmt "$DUR")
API_ELAPSED=$(dur_fmt "$API_DUR")

EXTRA=""
[[ -n $EFFORT ]] && EXTRA+=" ${DIM}·${RESET} ${EFFORT}"
[[ -n $FAST   ]] && EXTRA+=" ${DIM}·${RESET} ⚡${FAST}"

# --- rate limit segments (omitted when the session reports no limits) ---
LIMITS=""
if [[ $H5_PCT =~ ^[0-9]+$ ]]; then
  seg="${DIM}5h${RESET} $(bar "$H5_PCT" 10) ${H5_PCT}%"
  if [[ $H5_RESET =~ ^[0-9]+$ ]]; then
    seg+=" ${DIM}↻$(epoch_fmt "$H5_RESET" '%H:%M') ($(countdown "$H5_RESET"))${RESET}"
  fi
  LIMITS="$seg"
fi
if [[ $D7_PCT =~ ^[0-9]+$ ]]; then
  seg="${DIM}7d${RESET} $(bar "$D7_PCT" 10) ${D7_PCT}%"
  if [[ $D7_RESET =~ ^[0-9]+$ ]]; then
    seg+=" ${DIM}↻$(epoch_fmt "$D7_RESET" '%m/%d %H:%M') ($(countdown "$D7_RESET"))${RESET}"
  fi
  [[ -n $LIMITS ]] && LIMITS+="  ${DIM}·${RESET}  "
  LIMITS+="$seg"
fi

# --- output ---
printf '%s\n' "${SESSION}${CYAN}◆ ${MODEL}${RESET}${EXTRA} ${DIM}·${RESET} ${BLUE}📁 ${DIR}${RESET}${GIT} ${DIM}·${RESET} \$${COST_FMT}"
printf '%s\n' "$(bar "$PCT" 20) ${PCT}% ${DIM}context · ${RESET}${GREEN}+${ADDED}${RESET}/${RED}-${REMOVED}${RESET} ${DIM}· ${ELAPSED} wall · ${API_ELAPSED} api${RESET}"
[[ -n $LIMITS ]] && printf '%s\n' "$LIMITS"
exit 0
