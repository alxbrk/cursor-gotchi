"""Tamagotchi menu panel for the macOS menu bar dropdown."""

from __future__ import annotations

import sys
from pathlib import Path

import objc
from AppKit import (
    NSBezierPath,
    NSFont,
    NSMenu,
    NSMenuItem,
    NSMomentaryLightButton,
    NSView,
)

import Foundation

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from token_gotchi.pet import PetEngine, PetState  # noqa: E402
from token_gotchi.sprites import SPECIES_BODY_HEX, mood_key, sprite_for  # noqa: E402


def _rgb(hex_color: str):
    value = hex_color.lstrip("#")
    r = int(value[0:2], 16) / 255.0
    g = int(value[2:4], 16) / 255.0
    b = int(value[4:6], 16) / 255.0
    return Foundation.NSColor.colorWithRed_green_blue_alpha_(r, g, b, 1.0)


def _draw_sprite(rows, species_id, origin_x, origin_y, pixel) -> None:
    outline = _rgb("#E4E4E4")
    highlight = _rgb("#FFFFFF")
    mouth = _rgb("#8A8A8A")
    body = _rgb(SPECIES_BODY_HEX.get(species_id, "#599CE7"))

    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            px = origin_x + x * pixel
            py = origin_y + (15 - y) * pixel
            tile = Foundation.NSMakeRect(px, py, pixel - 0.5, pixel - 0.5)
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
            else:
                body.set()
            NSBezierPath.fillRect_(tile)


def _center_align():
    style = Foundation.NSMutableParagraphStyle.alloc().init()
    style.setAlignment_(Foundation.NSTextAlignmentCenter)
    return style


def _right_align():
    style = Foundation.NSMutableParagraphStyle.alloc().init()
    style.setAlignment_(Foundation.NSTextAlignmentRight)
    return style


def _draw_meter(x, y, width, label, value, fill, text, track) -> None:
    attrs = {
        Foundation.NSFontAttributeName: NSFont.systemFontOfSize_weight_(11, 0.0),
        Foundation.NSForegroundColorAttributeName: text,
    }
    value_str = f"{round(value)}"
    Foundation.NSString.stringWithString_(label).drawAtPoint_withAttributes_(
        (x, y + 14), attrs
    )
    Foundation.NSString.stringWithString_(value_str).drawInRect_withAttributes_(
        Foundation.NSMakeRect(x + width - 36, y + 14, 36, 14),
        attrs | {Foundation.NSParagraphStyleAttributeName: _right_align()},
    )
    bar_h = 8.0
    track_path = NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(
        Foundation.NSMakeRect(x, y, width, bar_h), 4.0, 4.0
    )
    track.set()
    track_path.fill()
    fill_w = max(0.0, min(width, width * (value / 100.0)))
    if fill_w > 0:
        fill_path = NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(
            Foundation.NSMakeRect(x, y, fill_w, bar_h), 4.0, 4.0
        )
        fill.set()
        fill_path.fill()


class TamagotchiMenuPanelView(NSView):
    WIDTH = 220.0
    HEIGHT = 280.0

    def initWithFrame_(self, frame):
        self = objc.super(TamagotchiMenuPanelView, self).initWithFrame_(frame)
        if self is None:
            return None
        self.state: PetState | None = None
        self.mood_label = "Content"
        self._frame = 0
        return self

    def isFlipped(self):
        return True

    def setPetData_(self, data) -> None:
        self.state = data["state"]
        self.mood_label = data["mood_label"]
        self._frame = data["anim_frame"]
        self.setNeedsDisplay_(True)

    def drawRect_(self, _rect) -> None:
        width = self.bounds().size.width
        height = self.bounds().size.height

        bg = _rgb("#2A2A2A")
        bg_path = NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(
            Foundation.NSMakeRect(0, 0, width, height), 14.0, 14.0
        )
        bg.set()
        bg_path.fill()

        if self.state is None:
            return

        stage = self.state.stage
        subtitle = f"{stage.name} · {self.mood_label}"
        subtitle_attrs = {
            Foundation.NSFontAttributeName: NSFont.systemFontOfSize_weight_(12, 0.0),
            Foundation.NSForegroundColorAttributeName: _rgb("#9A9A9A"),
            Foundation.NSParagraphStyleAttributeName: _center_align(),
        }
        Foundation.NSString.stringWithString_(subtitle).drawInRect_withAttributes_(
            Foundation.NSMakeRect(12, 16, width - 24, 18), subtitle_attrs
        )

        mood = mood_key(self.state.hunger, self.state.happiness, self.mood_label)
        rows = sprite_for(stage.level, mood, self._frame)
        pixel = 5.0
        grid_w = 16 * pixel
        origin_x = (width - grid_w) / 2.0
        _draw_sprite(rows, self.state.species, origin_x, 52.0, pixel)

        text = _rgb("#B0B0B0")
        track = _rgb("#404040")
        bar_width = width - 48
        bar_x = 24.0
        _draw_meter(
            bar_x, 210.0, bar_width, "HUN", self.state.hunger,
            _rgb("#E3944C"), text, track,
        )
        _draw_meter(
            bar_x, 238.0, bar_width, "HAP", self.state.happiness,
            _rgb("#3FA266"), text, track,
        )


class MenuActionTarget(Foundation.NSObject):
    def initWithHandler_(self, handler):
        self = objc.super(MenuActionTarget, self).init()
        self.handler = handler
        return self

    def sync_(self, _sender) -> None:
        self.handler.on_sync()

    def canvas_(self, _sender) -> None:
        self.handler.on_canvas()

    def quit_(self, _sender) -> None:
        self.handler.on_quit()


class MenuOpenDelegate(Foundation.NSObject):
    def initWithHandler_(self, handler):
        self = objc.super(MenuOpenDelegate, self).init()
        self.handler = handler
        return self

    def menuWillOpen_(self, _menu) -> None:
        self.handler.refresh_panel()


class TamagotchiMenuPanel:
    PANEL_HEIGHT = 280.0

    def __init__(self, handler) -> None:
        self.handler = handler
        self.engine = PetEngine()
        self.panel_view = TamagotchiMenuPanelView.alloc().initWithFrame_(
            Foundation.NSMakeRect(0, 0, TamagotchiMenuPanelView.WIDTH, self.PANEL_HEIGHT)
        )
        self.menu = NSMenu.alloc().init()
        self.delegate = MenuOpenDelegate.alloc().initWithHandler_(handler)
        self.menu.setDelegate_(self.delegate)

        panel_item = NSMenuItem.alloc().init()
        panel_item.setView_(self.panel_view)
        panel_item.setEnabled_(False)
        self.menu.addItem_(panel_item)
        self.menu.setMinimumWidth_(TamagotchiMenuPanelView.WIDTH + 16)
        self.menu.addItem_(NSMenuItem.separatorItem())

        actions = MenuActionTarget.alloc().initWithHandler_(handler)
        self._add_action("Sync now", actions, "sync:")
        self._add_action("Open canvas in Cursor", actions, "canvas:")
        self._add_action("Quit Cursor Gotchi", actions, "quit:")

    def _add_action(self, title, target, action) -> None:
        item = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(title, action, "")
        item.setTarget_(target)
        self.menu.addItem_(item)

    def attach(self, status_item) -> None:
        status_item.setMenu_(self.menu)

    def refresh(self) -> None:
        state = self.engine.store.load()
        state = self.engine.apply_time_decay(state)
        self.engine.store.save(state)
        mood = self.engine.mood_label(state)
        self.panel_view.setPetData_(
            {
                "state": state,
                "mood_label": mood,
                "anim_frame": self.handler.anim_frame,
            }
        )
