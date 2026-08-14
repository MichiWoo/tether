#!/usr/bin/env python3
"""Genera los iconos de Tether (macOS, Android, iOS y tray) desde el logo fuente.

Uso:
    python3 scripts/generate_icons.py

Fuente: assets/icon_source.png (logo 1254x1254).
Genera:
  - macOS Dock:  macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png
  - Android:     android/app/src/main/res/mipmap-*/ic_launcher.png
  - iOS:         ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png
  - Tray (menú): assets/tray_icon.png (silueta monocroma, template)
"""

import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "icon_source.png")
MARGIN = 0.02  # margen (fracción) por cada lado tras recortar el canvas


def load_source() -> Image.Image:
    img = Image.open(SOURCE).convert("RGBA")
    # Recorta el canvas vacío para que el logo llene el icono.
    bbox = img.getchannel("A").getbbox()
    if bbox:
        img = img.crop(bbox)
    return img


def icon_with_margin(src: Image.Image, size: int) -> Image.Image:
    """Logo centrado con margen sobre fondo transparente."""
    inner = max(1, round(size * (1 - 2 * MARGIN)))
    logo = src.resize((inner, inner), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = (size - inner) // 2
    canvas.paste(logo, (offset, offset))
    return canvas


def silhouette(src: Image.Image, size: int) -> Image.Image:
    """Silueta monocroma: negro con el canal alfa del logo."""
    content = icon_with_margin(src, size)
    _, _, _, alpha = content.split()
    black = Image.new("L", (size, size), 0)
    return Image.merge("RGBA", (black, black, black, alpha))


def save(img: Image.Image, path: str) -> None:
    img.save(path, "PNG")


def main() -> None:
    src = load_source()

    # macOS Dock
    mac_dir = os.path.join(
        ROOT, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset"
    )
    for n in (16, 32, 64, 128, 256, 512, 1024):
        save(icon_with_margin(src, n), os.path.join(mac_dir, f"app_icon_{n}.png"))

    # Android launcher
    android_sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    res_root = os.path.join(ROOT, "android", "app", "src", "main", "res")
    for dpi, px in android_sizes.items():
        save(
            icon_with_margin(src, px),
            os.path.join(res_root, f"mipmap-{dpi}", "ic_launcher.png"),
        )

    # iOS AppIcon (parsea Contents.json para saber tamaños y nombres)
    ios_dir = os.path.join(
        ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
    )
    with open(os.path.join(ios_dir, "Contents.json"), encoding="utf-8") as f:
        contents = json.load(f)
    scale_map = {"1x": 1, "2x": 2, "3x": 3}
    for entry in contents["images"]:
        points = float(entry["size"].split("x")[0])
        px = int(round(points * scale_map[entry["scale"]]))
        save(icon_with_margin(src, px), os.path.join(ios_dir, entry["filename"]))

    # Tray (silueta monocroma)
    save(silhouette(src, 128), os.path.join(ROOT, "assets", "tray_icon.png"))

    print("Iconos generados correctamente.")


if __name__ == "__main__":
    main()
