"""Render pixel sprites as macOS menu bar icons."""

from __future__ import annotations

from typing import TYPE_CHECKING

from AppKit import NSBitmapImageRep, NSDeviceRGBColorSpace, NSImage

from .sprites import SPECIES_BODY_HEX, mood_key, sprite_for

if TYPE_CHECKING:
    from .pet import PetState

OUTLINE = (0x2A, 0x2A, 0x2A)
HIGHLIGHT = (0xFF, 0xFF, 0xFF)
MOUTH = (0x4A, 0x30, 0x30)


def _hex_rgb(hex_color: str) -> tuple[int, int, int]:
    value = hex_color.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)


def _color_for_char(ch: str, body_rgb: tuple[int, int, int]) -> tuple[int, int, int, int] | None:
    if ch == ".":
        return None
    if ch == "B":
        r, g, b = body_rgb
        return r, g, b, 255
    if ch == "H":
        r, g, b = HIGHLIGHT
        return r, g, b, 255
    if ch == "M":
        r, g, b = MOUTH
        return r, g, b, 255
    r, g, b = OUTLINE
    return r, g, b, 255


def sprite_to_nsimage(
    rows: tuple[str, ...],
    species_id: str,
    pixel_size: int = 2,
) -> NSImage:
    body_rgb = _hex_rgb(SPECIES_BODY_HEX.get(species_id, "#599CE7"))
    width = 16 * pixel_size
    height = 16 * pixel_size

    rep = NSBitmapImageRep.alloc().initWithBitmapDataPlanes_pixelsWide_pixelsHigh_bitsPerSample_samplesPerPixel_hasAlpha_isPlanar_colorSpaceName_bytesPerRow_bitsPerPixel_(  # noqa: E501
        None,
        width,
        height,
        8,
        4,
        True,
        False,
        NSDeviceRGBColorSpace,
        width * 4,
        32,
    )
    data = rep.bitmapData()

    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            rgba = _color_for_char(ch, body_rgb)
            if rgba is None:
                continue
            for dy in range(pixel_size):
                for dx in range(pixel_size):
                    px = x * pixel_size + dx
                    py = (15 - y) * pixel_size + dy
                    offset = (py * width + px) * 4
                    data[offset] = rgba[0]
                    data[offset + 1] = rgba[1]
                    data[offset + 2] = rgba[2]
                    data[offset + 3] = rgba[3]

    image = NSImage.alloc().initWithSize_((width, height))
    image.addRepresentation_(rep)
    image.setSize_((18, 18))
    return image


def icon_for_pet(
    state: PetState,
    mood_label: str,
    anim_frame: int = 0,
) -> NSImage:
    mood = mood_key(state.hunger, state.happiness, mood_label)
    rows = sprite_for(state.stage.level, mood, anim_frame)
    return sprite_to_nsimage(rows, state.species)
