#!/usr/bin/env python3
"""Generate a minimalist, Apple HIG-aligned macOS app icon for NetUtil.

Style: standard rounded-rectangle (squircle) app icon, single monochrome
network glyph centered, restrained blue system tint background. No heavy
gradients, no 3D, no drop shadows on the glyph — clinical and enterprise.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

ASSET_DIR = os.path.join(os.path.dirname(__file__), "..", "NetUtil",
                         "Assets.xcassets", "AppIcon.appiconset")

SIZES = [16, 32, 64, 128, 256, 512, 1024]


def rounded_rect_mask(size, radius_ratio=0.2215):
    """macOS icon corner radius ~22.15% of width."""
    size = int(size)
    radius = size * radius_ratio
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def draw_background(size):
    size = int(size)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Background: subtle vertical gradient in system blue family.
    top = (44, 122, 255)     # #2C7AFF-ish, restrained
    bottom = (20, 90, 230)
    for y in range(size):
        t = y / max(1, size - 1)
        r = int(top[0] * (1 - t) + bottom[0] * t)
        g = int(top[1] * (1 - t) + bottom[1] * t)
        b = int(top[2] * (1 - t) + bottom[2] * t)
        d.line([(0, y), (size, y)], fill=(r, g, b, 255))

    # Clip to squircle.
    mask = rounded_rect_mask(size)
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg.paste(img, (0, 0), mask)
    return bg


def draw_network_glyph(size):
    """Draw a centered network node graph: center node + 3 satellites + links.

    Monochrome white, thin strokes, no fills on strokes.
    """
    size = int(size)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    white = (255, 255, 255, 255)

    cx, cy = size / 2, size / 2
    # Satellite radius from center.
    R = size * 0.27
    angles = [-90, 30, 150]  # top, lower-right, lower-left
    nodes = [(cx, cy)]
    for a in angles:
        rad = math.radians(a)
        nodes.append((cx + R * math.cos(rad), cy + R * math.sin(rad)))

    # Links first (behind nodes).
    lw = max(1.5, size * 0.018)
    for n in nodes[1:]:
        d.line([(cx, cy), n], fill=white, width=int(lw))

    # Nodes.
    center_r = size * 0.052
    sat_r = size * 0.040
    # center filled
    d.ellipse([cx - center_r, cy - center_r, cx + center_r, cy + center_r],
              fill=white)
    # satellites outlined with white stroke, transparent center for minimalism
    sw = max(1.5, size * 0.016)
    for n in nodes[1:]:
        d.ellipse([n[0] - sat_r, n[1] - sat_r, n[0] + sat_r, n[1] + sat_r],
                  outline=white, width=int(sw))

    return img


def make_icon(size):
    # Supersample for crisp small sizes.
    scale = 4 if size <= 64 else (2 if size <= 256 else 1)
    big = size * scale
    bg = draw_background(big)
    glyph = draw_network_glyph(big)
    comp = Image.alpha_composite(bg, glyph)
    if scale != 1:
        comp = comp.resize((size, size), Image.LANCZOS)
    mask = rounded_rect_mask(size)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(comp, (0, 0), mask)
    return out.convert("RGBA")


def main():
    os.makedirs(ASSET_DIR, exist_ok=True)
    mapping = {
        16: "icon_16x16.png",
        32: "icon_32x32.png",
        64: "icon_64x64.png",
        128: "icon_128x128.png",
        256: "icon_256x256.png",
        512: "icon_512x512.png",
        1024: "icon_1024x1024.png",
    }
    for size, name in mapping.items():
        icon = make_icon(size)
        path = os.path.join(ASSET_DIR, name)
        icon.save(path, "PNG")
        print(f"wrote {name} ({size}x{size})")


if __name__ == "__main__":
    main()
