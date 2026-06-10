# Cursor Gotchi

A Tamagotchi-style pet for Cursor that **feeds on your token usage**. Every prompt, completion, and agent turn nourishes your creature. Skip coding for too long and it gets hungry.

```
  ⚡ Toko · Sparkite · Hatchling
  (•ᴗ•) 
  /| |\
   | |  
Content  hunger ███████░  happy ██████░░
fed 12.4k tokens  evolve 42% → 50.0k
```

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

## IDE Canvas panel

Cursor Gotchi also has a **Canvas panel** for the IDE chat — a live pet dashboard beside your conversation.

After install, open `token-gotchi.canvas.tsx` (under `~/.cursor/projects/<your-project>/canvases/`) beside chat using the canvas picker.

The panel shows a **Tamagotchi-style device** with pixel-art sprites, LCD vitals, and mood-based animations. Evolution changes the sprite; hunger and happiness change its expression.

It **syncs automatically** via Cursor hooks on session start/end, after each agent response, and when an agent run stops. The CLI status line also pushes live updates to the canvas. Manual sync:

```bash
python3 ~/.cursor/token-gotchi/scripts/sync_canvas.py <<< '{}'
```

## Menu bar pet (macOS)

### Native app (recommended)

A **real macOS app** — no Python, no Dock icon. Pixel pet in the menu bar; click to open the Tamagotchi panel. Reads the same `state.json` Cursor hooks update.

```bash
~/.cursor/token-gotchi/scripts/install_mac_app.sh
```

Open anytime from Spotlight or **Finder → Applications → Cursor Gotchi**

Restart: `~/.cursor/token-gotchi/scripts/restart_menubar.sh`

Stop: `launchctl bootout gui/$(id -u)/com.cursor.token-gotchi.menubar`

### Legacy Python menu bar

```bash
~/.cursor/token-gotchi/scripts/install_menubar.sh
```

## Install

```bash
git clone <this-repo> ~/cursor-gotchi
cd ~/cursor-gotchi
./scripts/install.sh
```

This copies the package to `~/.cursor/token-gotchi/` and configures `~/.cursor/cli-config.json` with the status line hook.

Requires **Python 3.9+** (stdlib only for core; menu bar pet needs `pip install rumps`).

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

## Test the status line locally

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

## State

Pet data lives at `~/.cursor/token-gotchi/state.json`.

## Roadmap

- [x] **IDE Canvas view** — animated pet panel beside chat
- [x] **Cursor hooks** — sync on agent events; tool-based evolution coming in v2
- [x] **Menu bar pet** — always-on macOS companion
- [ ] **Achievements** — "Fed 1M tokens", "7-day streak", "Shell master"
- [ ] **Multi-pet daycare** — one pet per workspace
- [ ] **Battle/trade** — share gotchi stats with teammates

## License

MIT
