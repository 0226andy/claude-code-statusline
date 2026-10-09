#!/bin/bash
# Installs statusline-command.sh into the Claude Code config directory and
# points settings.json at it. Re-running is safe: existing files are backed up.

set -euo pipefail

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/statusline-command.sh"
DEST="$CONFIG_DIR/statusline-command.sh"
SETTINGS="$CONFIG_DIR/settings.json"
STAMP=$(date +%Y%m%d-%H%M%S)

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq is required (macOS: brew install jq, Debian/Ubuntu: apt install jq)"
[[ -f $SRC ]] || die "statusline-command.sh not found next to install.sh"

mkdir -p "$CONFIG_DIR"

if [[ -f $DEST ]] && ! cmp -s "$SRC" "$DEST"; then
  cp "$DEST" "$DEST.$STAMP.bak"
  printf 'backed up existing script -> %s\n' "$DEST.$STAMP.bak"
fi
cp "$SRC" "$DEST"
chmod +x "$DEST"
printf 'installed %s\n' "$DEST"

[[ -f $SETTINGS ]] || printf '{}\n' >"$SETTINGS"
jq empty "$SETTINGS" 2>/dev/null || die "$SETTINGS is not valid JSON; fix it and re-run"

# Write to a temp file first so a failed jq run cannot truncate settings.json.
TMP=$(mktemp "$SETTINGS.XXXXXX")
trap 'rm -f "$TMP"' EXIT
jq --arg cmd "bash $DEST" '.statusLine = {type: "command", command: $cmd}' "$SETTINGS" >"$TMP"

if cmp -s "$TMP" "$SETTINGS"; then
  printf 'settings.json already points at the script\n'
else
  cp "$SETTINGS" "$SETTINGS.$STAMP.bak"
  mv "$TMP" "$SETTINGS"
  printf 'updated %s (backup: %s)\n' "$SETTINGS" "$SETTINGS.$STAMP.bak"
fi

printf 'done. The status line appears on the next Claude Code prompt.\n'
