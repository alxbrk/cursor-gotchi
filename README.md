# Cursor Gotchi

A Tamagotchi-style pet for [Cursor](https://cursor.com) that **feeds on your token usage**. Every prompt, completion, and agent turn nourishes your creature. Skip coding for too long and it gets hungry.

```
  ⚡ Toko · Sparkite · Hatchling
  (•ᴗ•)
  /| |\
   | |
hunger ███████░  happy ██████░░
fed 12.4k tokens  evolve 42% → 50.0k
```

It lives in three places (use any or all):

- **CLI status line** — a tiny pet line under your Cursor CLI prompt
- **IDE canvas panel** — an animated pet dashboard beside chat
- **macOS menu bar app** — an always-on pixel pet showing your live usage %

---

## Quick install

```bash
git clone https://github.com/alxbrk/cursor-gotchi.git ~/cursor-gotchi
cd ~/cursor-gotchi
./scripts/install.sh
```

This copies the package to `~/.cursor/token-gotchi/`, wires up the **CLI status line**, registers **Cursor hooks** for the canvas, and prints the optional menu bar app command.

### Add the macOS menu bar app (recommended)

```bash
~/.cursor/token-gotchi/scripts/install_mac_app.sh
```

A real `.app` (no Python, no Dock icon) lands in **Applications → Cursor Gotchi** and starts on login. Click the menu bar pet to open the floating Tamagotchi panel.

---

## Requirements

- **Python 3.9+** — core pet logic and CLI/canvas (standard library only)
- **macOS 14+** and the **Swift toolchain** (Xcode Command Line Tools: `xcode-select --install`) — only for the native menu bar app
- **Cursor** signed in on this machine — the menu bar app reads your usage % from Cursor's local database (read-only)

> Your Cursor token is never stored or transmitted anywhere except to Cursor's own API to read your usage. Nothing is committed or logged. See [Privacy](#privacy).

---

## How it works

Cursor Gotchi hooks into the **Cursor CLI status line**, which receives live session data including token counts on every conversation update. The pet:

1. Detects new tokens since the last update
2. Feeds your gotchi (hunger + happiness go up)
3. Tracks lifetime tokens toward evolution
4. Slowly gets hungry when you're away

### Evolution stages

| Stage | Lifetime tokens |
|-------|-----------------|
| Egg | 0 |
| Hatchling | 5,000 |
| Juvenile | 50,000 |
| Adult | 500,000 |
| Mega | 5,000,000 |

### Species

Pick your starter (cosmetic for now — activity-based evolution coming in v2):

| Species | Emoji | Trait |
|---------|-------|-------|
| Sparkite | ⚡ | Loves fast completions |
| Deepite | 🌊 | Thrives on long context |
| Codite | 💎 | Evolves through edits |
| Shellite | 🔥 | Powered by terminal runs |
| MCPite | 🔗 | Connects to everything |

---

## Menu bar app

The native app shows a pixel pet plus your **usage %** for the current billing period. Click it for a panel with the pet, a usage bar, and when your plan resets. The full dollar breakdown is available on hover.

```bash
# Install / update
~/.cursor/token-gotchi/scripts/install_mac_app.sh

# Restart
~/.cursor/token-gotchi/scripts/restart_menubar.sh

# Stop
launchctl bootout gui/$(id -u)/com.cursor.token-gotchi.menubar
```

Open anytime from Spotlight or **Finder → Applications → Cursor Gotchi**.

> The app is built and signed locally (ad-hoc). The installer clears the quarantine attribute so Gatekeeper won't block your own build.

### Legacy Python menu bar

A `rumps`-based alternative (requires `pip install rumps`):

```bash
~/.cursor/token-gotchi/scripts/install_menubar.sh
```

---

## IDE canvas panel

A live pet dashboard for the Cursor chat — a Tamagotchi-style device with pixel-art sprites, LCD vitals, and mood-based animations. Evolution changes the sprite; hunger and happiness change its expression.

It **syncs automatically** via Cursor hooks (session start/end, after each agent response, and when a run stops). The CLI status line also pushes live updates.

After install, open `token-gotchi.canvas.tsx` (under `~/.cursor/projects/<your-project>/canvases/`) beside chat using the canvas picker. Manual sync:

```bash
python3 ~/.cursor/token-gotchi/scripts/sync_canvas.py <<< '{}'
```

---

## CLI commands

```bash
# Show your pet
python3 ~/.cursor/token-gotchi/scripts/gotchi.py show

# Rename
python3 ~/.cursor/token-gotchi/scripts/gotchi.py rename Pixel

# Pick species
python3 ~/.cursor/token-gotchi/scripts/gotchi.py species deepite

# Debug: manually feed tokens
python3 ~/.cursor/token-gotchi/scripts/gotchi.py feed 5000

# Reset to egg
python3 ~/.cursor/token-gotchi/scripts/gotchi.py reset
```

### Test the status line locally

```bash
echo '{
  "model": {"display_name": "Composer"},
  "context_window": {
    "total_input_tokens": 8000,
    "total_output_tokens": 1200,
    "used_percentage": 12.5,
    "context_window_size": 200000
  }
}' | python3 ~/.cursor/token-gotchi/scripts/statusline.py
```

Run it again with higher token counts to watch your pet eat.

---

## Privacy

- **No telemetry.** Cursor Gotchi sends nothing to any third party.
- **Token handling.** The menu bar app reads your Cursor access token **read-only** from Cursor's local database (`state.vscdb`) solely to call Cursor's own usage API. It is never written to disk by this app.
- **Local state only.** Pet data lives at `~/.cursor/token-gotchi/state.json`; cached usage at `~/.cursor/token-gotchi/usage.json`. These are git-ignored and never leave your machine.

---

## Uninstall

```bash
# Menu bar app + LaunchAgent
launchctl bootout gui/$(id -u)/com.cursor.token-gotchi.menubar 2>/dev/null
rm -f ~/Library/LaunchAgents/com.cursor.token-gotchi.menubar.plist
rm -rf "/Applications/Cursor Gotchi.app"

# Package + state
rm -rf ~/.cursor/token-gotchi
```

Then remove the `statusLine` block from `~/.cursor/cli-config.json` and the Cursor Gotchi entries from `~/.cursor/hooks.json` if you no longer want the CLI/canvas integration.

---

## Roadmap

- [x] **IDE Canvas view** — animated pet panel beside chat
- [x] **Cursor hooks** — sync on agent events; tool-based evolution coming in v2
- [x] **Menu bar pet** — always-on macOS companion
- [ ] **Achievements** — "Fed 1M tokens", "7-day streak", "Shell master"
- [ ] **Multi-pet daycare** — one pet per workspace
- [ ] **Battle/trade** — share gotchi stats with teammates

---

## License

MIT
