# claude-code-statusline

給 [Claude Code](https://code.claude.com/docs/en/statusline) 用的三行 status line dashboard：顯示 model、目錄、git branch、費用、context window 用量，以及 5 小時／7 天 rate limit 的進度條與重置倒數。

[English](README.md)

```text
◆ Opus 5.5 · high · ⚡fast · 📁 /Users/you/project on ⎇ main* · $1.23
████████░░░░░░░░░░░░ 42% context · +156/-23 · 2h 15m 15s wall · 22m 15s api
5h ██████░░░░ 63% ↻22:17 (2h 11m)  ·  7d █░░░░░░░░░ 18% ↻10/13 01:06 (3d 5h)
```

進度條低於 50% 為綠色，50% 起為黃色，80% 起為紅色。

## 各行內容

| 行 | 內容 |
| --- | --- |
| 1 | Model 名稱、effort level、fast mode 標記、目前目錄、git branch（working tree 有未提交變更時加 `*`）、本次 session 費用（USD） |
| 2 | Context window 用量、增加／刪除行數、wall-clock 時間、API 時間 |
| 3 | 5 小時與 7 天 rate limit 用量、重置時間、距離重置的倒數 |

Session 沒有回報 rate limit 時（例如以 API key 計費）第 3 行不會出現。effort、fast mode、git 三個區段同樣只在適用時顯示。

## 需求

- 支援 status line 的 Claude Code
- `bash` 3.2 以上（macOS 內建版本即可）
- [`jq`](https://jqlang.github.io/jq/)
- `git`（選用，用於 branch 區段）
- 支援方塊字元（`█ ░`）與 emoji 的終端機字型

macOS（BSD `date`）與 Linux（GNU `date`）皆可使用。

## 安裝

```bash
git clone https://github.com/0226andy/claude-code-statusline.git
cd claude-code-statusline
./install.sh
```

`install.sh` 會把腳本複製到 `~/.claude/statusline-command.sh`（有設定 `$CLAUDE_CONFIG_DIR` 則用該路徑），並寫入 `settings.json` 的 `statusLine`。既有的腳本與設定檔會先以時間戳記備份。

### 手動安裝

把 `statusline-command.sh` 放到任意位置，並在 `~/.claude/settings.json` 加入：

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

## 不安裝直接試跑

```bash
echo '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":63}}}' \
  | bash statusline-command.sh
```

## 客製化

所有設定都在 `statusline-command.sh`：

- **顏色**：`# --- colors ---` 區塊。
- **門檻**：`bar()` 裡的 50／80。
- **進度條寬度**：`bar` 的第二個參數（context 為 20，rate limit 為 10）。
- **版面**：`# --- output ---` 底下的 `printf`。

腳本只呼叫一次 `jq` 讀取 session JSON，所以新增欄位時，在 `jq` array 加一行，並在 `read` 的變數清單同一位置加一個變數即可。

## 測試

```bash
./test.sh
```

## License

[MIT](LICENSE)
