# claude-code-statusline

A three-line status line dashboard for [Claude Code](https://code.claude.com/docs/en/statusline): model, directory, git branch, cost, context window usage, and 5-hour / 7-day rate limit bars with reset countdowns.

[繁體中文說明](README.zh-TW.md)

```text
◆ Opus 5.5 · high · ⚡fast · 📁 /Users/you/project on ⎇ main* · $1.23
████████░░░░░░░░░░░░ 42% context · +156/-23 · 2h 15m 15s wall · 22m 15s api
5h ██████░░░░ 63% ↻22:17 (2h 11m)  ·  7d █░░░░░░░░░ 18% ↻10/13 01:06 (3d 5h)
```

Bars are green below 50%, yellow from 50%, and red from 80%.

## What each line shows

| Line | Content |
| --- | --- |
| 1 | Model name, effort level, fast mode flag, current directory, git branch (`*` when the working tree is dirty), session cost in USD |
| 2 | Context window usage bar, lines added / removed, wall-clock time, API time |
| 3 | 5-hour and 7-day rate limit usage, reset time, and countdown to reset |

Line 3 is omitted when the session reports no rate limits (for example, API key billing). The effort, fast mode, and git segments are likewise hidden when they do not apply.

## Requirements

- Claude Code with status line support
- `bash` 3.2 or newer (the stock macOS bash works)
- [`jq`](https://jqlang.github.io/jq/)
- `git` (optional, for the branch segment)
- A terminal font with block characters (`█ ░`) and emoji

Works on macOS (BSD `date`) and Linux (GNU `date`).

## Install

```bash
git clone https://github.com/0226andy/claude-code-statusline.git
cd claude-code-statusline
./install.sh
```

`install.sh` copies the script to `~/.claude/statusline-command.sh` (or `$CLAUDE_CONFIG_DIR` if set) and sets `statusLine` in `settings.json`. Any existing script or settings file is backed up with a timestamp first.

### Manual install

Copy `statusline-command.sh` anywhere you like and add this to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

## Try it without installing

```bash
echo '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":63}}}' \
  | bash statusline-command.sh
```

## Customizing

Everything lives in `statusline-command.sh`:

- **Colors**: the `# --- colors ---` block.
- **Thresholds**: the 50 / 80 cutoffs in `bar()`.
- **Bar width**: the second argument to `bar` (20 for context, 10 for rate limits).
- **Layout**: the `printf` lines under `# --- output ---`.

The script reads the session JSON once with a single `jq` call, so adding a field means adding one line to the `jq` array and one variable to the `read` list, in the same position.

## Test

```bash
./test.sh
```

## License

[MIT](LICENSE)
