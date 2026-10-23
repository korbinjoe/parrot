#!/usr/bin/env python3
"""Export the approved raster identity into native macOS icon resources.

Requires Pillow and macOS iconutil. Source images stay immutable. This script
only cleans near-transparent generation noise, fits the assets to native icon
canvases, and resamples; it does not draw or reinterpret the logo.
"""

from pathlib import Path
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "Resources"
SOURCE = RES / "IconSource"
SCREENSHOTS = ROOT / "docs" / "screenshots"
LANCZOS = Image.Resampling.LANCZOS


def clean_source(filename: str) -> Image.Image:
    image = Image.open(SOURCE / filename).convert("RGBA")
    alpha = image.getchannel("A").point(lambda a: 0 if a <= 8 else 255 if a >= 247 else a)
    image.putalpha(alpha)
    return image.crop(alpha.getbbox())


def fit_canvas(image: Image.Image, side: int, content_side: int) -> Image.Image:
    image = image.copy()
    image.thumbnail((content_side, content_side), LANCZOS)
    canvas = Image.new("RGBA", (side, side))
    canvas.alpha_composite(image, ((side - image.width) // 2, (side - image.height) // 2))
    return canvas


app = fit_canvas(clean_source("AppIcon.generated.png"), 1024, 832)
app.save(RES / "AppIcon-1024.png", optimize=True)

# Template RGB is exactly black; AppKit uses alpha for dark/light menu bars.
menu = clean_source("MenuBar.generated.png")
template = Image.new("RGBA", menu.size, (0, 0, 0, 0))
template.putalpha(menu.getchannel("A"))
menu = fit_canvas(template, 64, 54)
menu.save(RES / "MenuBarIconTemplate.png", optimize=True)

with tempfile.TemporaryDirectory(prefix="parrot-icons-") as directory:
    iconset = Path(directory) / "AppIcon.iconset"
    iconset.mkdir()
    for points in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            pixels = points * scale
            name = f"icon_{points}x{points}{'@2x' if scale == 2 else ''}.png"
            app.resize((pixels, pixels), LANCZOS).save(iconset / name)
    subprocess.run(["iconutil", "-c", "icns", "-o", str(RES / "AppIcon.icns"), str(iconset)], check=True)

SCREENSHOTS.mkdir(parents=True, exist_ok=True)
app.save(SCREENSHOTS / "app-icon.png", optimize=True)
menu_preview = Image.new("RGBA", (128, 128), "#f5f5f7")
menu_preview.alpha_composite(menu, (32, 32))
menu_preview.convert("RGB").save(SCREENSHOTS / "menubar-icon.png")

# A review sheet shows every tiny glyph at its actual pixel size.
sheet = Image.new("RGB", (1040, 620), "#f5f5f7")
draw = ImageDraw.Draw(sheet)
font_path = "/System/Library/Fonts/Helvetica.ttc"
font = ImageFont.truetype(font_path, 17)
small = ImageFont.truetype(font_path, 13)
draw.text((28, 20), "Parrot - native macOS identity", fill="#25262a", font=font)
for y, background, foreground, label in (
    (68, "#ffffff", "#25262a", "Light appearance"),
    (340, "#1c1c1e", "#f5f5f7", "Dark appearance"),
):
    draw.rounded_rectangle((20, y, 1020, y + 252), radius=18, fill=background)
    draw.text((40, y + 16), label, fill=foreground, font=small)
    preview = app.resize((200, 200), LANCZOS)
    sheet.paste(preview, (36, y + 44), preview)
    x = 270
    for size in (128, 64, 32, 16):
        icon = app.resize((size, size), LANCZOS)
        sheet.paste(icon, (x, y + 70 + (128 - size) // 2), icon)
        draw.text((x, y + 214), f"{size} px", fill=foreground, font=small)
        x += size + 38
    x = 850
    for size in (21, 16):
        glyph = menu.resize((size, size), LANCZOS)
        if label.startswith("Dark"):
            light = Image.new("RGBA", glyph.size, "#f5f5f7")
            light.putalpha(glyph.getchannel("A"))
            glyph = light
        sheet.paste(glyph, (x, y + 122), glyph)
        draw.text((x - 2, y + 160), f"{size} px", fill=foreground, font=small)
        x += 76
sheet.save(SCREENSHOTS / "icon-identity-review.png", optimize=True)
print("Exported native app icon (16-1024 px), 64 px template, and review previews.")
