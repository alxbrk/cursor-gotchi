"""Floating Tamagotchi-style device window for macOS."""

from __future__ import annotations

import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from token_gotchi.pet import PetEngine, PetState  # noqa: E402
from token_gotchi.render import _format_tokens  # noqa: E402
from token_gotchi.sprites import SPECIES_BODY_HEX, mood_key, sprite_for  # noqa: E402

try:
    import AppKit
    import Foundation
except ImportError as exc:
    raise SystemExit("PyObjC AppKit is required for the device window.") from exc

NSColor = AppKit.NSColor
NSView = AppKit.NSView
NSWindow = AppKit.NSWindow
NSBezierPath = AppKit.NSBezierPath
NSFont = AppKit.NSFont
NSMakeRect = Foundation.NSMakeRect
NSBackingStoreBuffered = AppKit.NSBackingStoreBuffered
NSWindowStyleMaskTitled = AppKit.NSWindowStyleMaskTitled
NSWindowStyleMaskClosable = AppKit.NSWindowStyleMaskClosable
NSWindowStyleMaskMiniaturizable = AppKit.NSWindowStyleMaskMiniaturizable
NSFloatingWindowLevel = AppKit.NSFloatingWindowLevel


def _rgb(hex_color: str) -> AppKit.NSColor:
    hex_color = hex_color.lstrip("#")
    r = int(hex_color[0:2], 16) / 255.0
    g = int(hex_color[2:4], 16) / 255.0
    b = int(hex_color[4:6], 16) / 255.0
    return NSColor.colorWithRed_green_blue_alpha_(r, g, b, 1.0)


class TamagotchiDeviceView(NSView):
    def initWithFrame_(self, frame):
        self = super().initWithFrame_(frame)
        if self is None:
            return None
        self.state: PetState | None = None
        self.mood_label = "Content"
        self.progress = 0
        self.next_target: int | None = None
        self._frame = 0
        return self

    def setPetData_(self, data) -> None:
        self.state = data["state"]
        self.mood_label = data["mood_label"]
        self.progress = data["progress"]
        self.next_target = data["next_target"]
        self._frame = data["anim_frame"]
        self.setNeedsDisplay_(True)

    def drawRect_(self, rect) -> None:
        bounds = self.bounds()
        width = bounds.size.width
        height = bounds.size.height

        shell = _rgb("#F4C2D0")
        shell_edge = _rgb("#D8899E")
        lcd_bg = _rgb("#8FA68A")
        lcd_edge = _rgb("#5E6F59")
        outline = _rgb("#2A2A2A")
        highlight = _rgb("#FFFFFF")
        mouth = _rgb("#4A3030")

        shell_rect = NSMakeRect(16, 24, width - 32, height - 48)
        shell_path = NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(
            shell_rect, 28.0, 28.0
        )
        shell.set()
        shell_path.fill()
        shell_edge.set()
        shell_path.setLineWidth_(2.0)
        shell_path.stroke()

        lcd_rect = NSMakeRect(36, 96, width - 72, 150)
        lcd_path = NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(
            lcd_rect, 8.0, 8.0
        )
        lcd_bg.set()
        lcd_path.fill()
        lcd_edge.set()
        lcd_path.setLineWidth_(2.0)
        lcd_path.stroke()

        if self.state is None:
            return

        species = self.state.species_info
        mood = mood_key(self.state.hunger, self.state.happiness, self.mood_label)
        rows = sprite_for(self.state.stage.level, mood, self._frame)
        body = _rgb(SPECIES_BODY_HEX.get(self.state.species, "#599CE7"))

        pixel = 5.0
        grid_w = 16 * pixel
        grid_h = 16 * pixel
        origin_x = lcd_rect.origin.x + (lcd_rect.size.width - grid_w) / 2.0
        origin_y = lcd_rect.origin.y + (lcd_rect.size.height - grid_h) / 2.0 + 6

        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == ".":
                    continue
                px = origin_x + x * pixel
                py = origin_y + (15 - y) * pixel
                tile = NSMakeRect(px, py, pixel - 0.5, pixel - 0.5)
                if ch == "O":
                    outline.set()
                elif ch == "B":
                    body.set()
                elif ch == "E":
                    outline.set()
                elif ch == "H":
                    highlight.set()
                elif ch == "M":
                    mouth.set()
                elif ch == "X":
                    outline.set()
                else:
                    body.set()
                NSBezierPath.fillRect_(tile)

        attrs = {
            Foundation.NSFontAttributeName: NSFont.boldSystemFontOfSize_(11),
            Foundation.NSForegroundColorAttributeName: outline,
        }
        title = f"{self.state.name}  {species.emoji}"
        title.drawAtPoint_withAttributes_((36, height - 36), attrs)

        small_font = NSFont.monospacedSystemFontOfSize_weight_(10, 0.0)
        small_attrs = {
            Foundation.NSFontAttributeName: small_font,
            Foundation.NSForegroundColorAttributeName: outline,
        }
        hunger_bar = self._bar(self.state.hunger)
        happy_bar = self._bar(self.state.happiness)
        f"HUN {hunger_bar} {self.state.hunger:.0f}".drawAtPoint_withAttributes_(
            (40, 72), small_attrs
        )
        f"HAP {happy_bar} {self.state.happiness:.0f}".drawAtPoint_withAttributes_(
            (40, 56), small_attrs
        )

        evolve = (
            f"EVO {self.progress}%"
            if self.next_target is not None
            else "EVO MAX"
        )
        fed = _format_tokens(self.state.lifetime_tokens)
        f"{evolve}  fed {fed}".drawAtPoint_withAttributes_((40, 40), small_attrs)

    @staticmethod
    def _bar(value: float, width: int = 8) -> str:
        filled = int(round(value / 100.0 * width))
        filled = max(0, min(width, filled))
        return "█" * filled + "░" * (width - filled)


class TamagotchiDeviceWindow:
    WIDTH = 260
    HEIGHT = 320

    def __init__(self) -> None:
        self.engine = PetEngine()
        self.window: NSWindow | None = None
        self.view: TamagotchiDeviceView | None = None
        self._anim_frame = 0
        self._last_anim = 0.0

    @property
    def is_visible(self) -> bool:
        return self.window is not None and self.window.isVisible()

    def show(self) -> None:
        if self.window is None:
            frame = NSMakeRect(0, 0, self.WIDTH, self.HEIGHT)
            self.view = TamagotchiDeviceView.alloc().initWithFrame_(frame)
            style = (
                NSWindowStyleMaskTitled
                | NSWindowStyleMaskClosable
                | NSWindowStyleMaskMiniaturizable
            )
            self.window = NSWindow.alloc().initWithContentRect_styleMask_backing_defer_(
                frame, style, NSBackingStoreBuffered, False
            )
            self.window.setTitle_("Cursor Gotchi")
            self.window.setLevel_(NSFloatingWindowLevel)
            self.window.setContentView_(self.view)
            self.window.center()
        self.refresh()
        self.window.makeKeyAndOrderFront_(None)
        AppKit.NSApp.activateIgnoringOtherApps_(True)

    def refresh(self) -> None:
        if self.view is None:
            return
        now = time.time()
        if now - self._last_anim >= 0.6:
            self._anim_frame = (self._anim_frame + 1) % 2
            self._last_anim = now

        state = self.engine.store.load()
        state = self.engine.apply_time_decay(state)
        self.engine.store.save(state)
        mood = self.engine.mood_label(state)
        progress, next_target = self.engine.progress_to_next(state)
        self.view.setPetData_(
            {
                "state": state,
                "mood_label": mood,
                "progress": progress,
                "next_target": next_target,
                "anim_frame": self._anim_frame,
            }
        )
