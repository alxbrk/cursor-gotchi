#!/usr/bin/env python3
"""Cursor Gotchi macOS menu bar companion."""

from __future__ import annotations

import fcntl
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

try:
    import rumps
    from rumps import events
except ImportError as exc:
    raise SystemExit(
        "rumps is required for the menu bar pet.\n"
        "Install with: pip3 install --user rumps\n"
        "Or run: ~/.cursor/token-gotchi/scripts/install_menubar.sh"
    ) from exc

from popover_panel import TamagotchiMenuPanel  # noqa: E402
from sync_canvas import CANVAS_FILENAME, sync_from_state_file  # noqa: E402
from token_gotchi.icon import icon_for_pet  # noqa: E402
from token_gotchi.pet import PetEngine  # noqa: E402
from token_gotchi.render import _format_tokens  # noqa: E402

LOCK_PATH = Path.home() / ".cursor" / "token-gotchi" / "menubar.lock"


def acquire_single_instance_lock() -> int:
    LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    lock_fd = os.open(str(LOCK_PATH), os.O_CREAT | os.O_RDWR, 0o644)
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(lock_fd)
        print("Cursor Gotchi menu bar is already running.", file=sys.stderr)
        raise SystemExit(0)
    os.ftruncate(lock_fd, 0)
    os.write(lock_fd, str(os.getpid()).encode())
    return lock_fd


def find_canvas_files() -> list[Path]:
    projects = Path.home() / ".cursor" / "projects"
    if not projects.exists():
        return []
    return list(projects.glob(f"*/canvases/{CANVAS_FILENAME}"))


class TokenGotchiMenuBar(rumps.App):
    POLL_SECONDS = 3

    def __init__(self) -> None:
        super().__init__("Cursor Gotchi", title=None, quit_button=None, menu=[])
        self.engine = PetEngine()
        self._menu_panel: TamagotchiMenuPanel | None = None
        self._menu_installed = False
        self._last_stage_level: int | None = None
        self.anim_frame = 0

    def install_menu_panel(self) -> None:
        if self._menu_installed or not hasattr(self, "_nsapp"):
            return
        self._menu_panel = TamagotchiMenuPanel(self)
        self._menu_panel.attach(self._nsapp.nsstatusitem)
        self.refresh_panel()
        state = self.engine.store.load()
        self._render(state)
        self._menu_installed = True

    def refresh_panel(self) -> None:
        if self._menu_panel:
            self._menu_panel.refresh()

    def on_sync(self) -> None:
        sync_from_state_file()
        self._render()
        self.refresh_panel()

    def on_canvas(self) -> None:
        self.open_canvas(None)

    def on_quit(self) -> None:
        rumps.quit_application()

    @rumps.timer(POLL_SECONDS)
    def refresh(self, _: object) -> None:
        state = self.engine.store.load()
        state = self.engine.apply_time_decay(state)
        self.engine.store.save(state)
        self.anim_frame = (self.anim_frame + 1) % 2
        self._render(state)

    def _set_status_icon(self, state, mood: str) -> None:
        image = icon_for_pet(state, mood, self.anim_frame)
        self._icon_nsimage = image
        if hasattr(self, "_nsapp"):
            self._nsapp._icon_nsimage = image
            self._nsapp.setStatusBarIcon()

    def _render(self, state=None) -> None:
        if state is None:
            state = self.engine.store.load()
            state = self.engine.apply_time_decay(state)
        stage = state.stage
        mood = self.engine.mood_label(state)

        if self._last_stage_level is not None and stage.level > self._last_stage_level:
            rumps.notification(
                title="Cursor Gotchi evolved!",
                subtitle=stage.name,
                message=f"{state.name} reached {stage.name} at {_format_tokens(state.lifetime_tokens)} tokens",
            )
        self._last_stage_level = stage.level

        self.title = None
        self._set_status_icon(state, mood)

    def open_canvas(self, _: object) -> None:
        canvases = find_canvas_files()
        if not canvases:
            rumps.alert(
                title="Canvas not found",
                message="Install the canvas with install_canvas.sh, then open it once in Cursor.",
                ok="OK",
            )
            return

        target = max(canvases, key=lambda path: path.stat().st_mtime)
        try:
            subprocess.run(
                ["open", "-a", "Cursor", str(target)],
                check=True,
                capture_output=True,
            )
        except subprocess.CalledProcessError:
            rumps.alert(
                title="Could not open Cursor",
                message=f"Open this file manually:\n{target}",
                ok="OK",
            )


def main() -> int:
    acquire_single_instance_lock()
    app = TokenGotchiMenuBar()

    @events.before_start
    def _setup_menu(*_args) -> None:
        app.install_menu_panel()

    app.run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
