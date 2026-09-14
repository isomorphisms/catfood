# Codex meter

Small Codex quota meter for shell status lines, tmux, and Waybar.

Default output:

```text
Codex 5h 73% · 7d 41%
```

It reads the existing Codex OAuth login from `~/.codex/auth.json`. It does not store or print the token.

## Install

From this checkout:

```sh
sh codex-meter/install.sh
```

The installer writes a tiny wrapper into `$PREFIX/bin` on Termux or `~/.local/bin` elsewhere. The wrapper points back at the script in this checkout, so a later `git pull` updates the meter without copying it again.

Run `codex login` first if needed.

## tmux

```tmux
set -g status-interval 60
set -g status-right '#(codex-meter) | %H:%M'
```

## Waybar

```json
"custom/codex": {
  "exec": "codex-meter --waybar",
  "return-type": "json",
  "interval": 60
}
```

Then add `"custom/codex"` to `modules-right`.

## JSON

```sh
codex-meter --json
```

Window labels are derived from the server's window duration instead of assuming that `primary` always means five hours or one week.

## Environment

- `CODEX_HOME` — alternate Codex directory.
- `CODEX_METER_BASE_URL` — alternate backend base URL.
- `CODEX_CHATGPT_BASE_URL` — older alias for the same override.
- `CODEX_METER_BIN_DIR` — installer destination override.
- `CODEX_METER_PYTHON` — Python executable override.

For ChatGPT backend URLs containing `/backend-api`, the meter uses the `/wham/usage` route. For Codex API-style base URLs it uses `/api/codex/usage`, matching current Codex path selection.
