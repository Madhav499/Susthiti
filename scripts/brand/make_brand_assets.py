"""Builds every SUSTHITI brand asset from the official logo.

    python scripts/brand/make_brand_assets.py path/to/official_logo.(png|jpg|webp)

The logo itself is never redrawn or recoloured. Everything here is either the logo as supplied
(converted losslessly to PNG), the same pixels with the white background made transparent, or a
crop of its emblem (shield, figure and leaves) for places that need a compact square mark.

Outputs
  app/assets/branding/susthiti_logo.png              official logo, as supplied (white background)
  app/assets/branding/susthiti_logo_transparent.png  same logo, white made transparent (identical over white)
  app/assets/branding/susthiti_mark.png              emblem only, transparent, square
  app/web/favicon.png, app/web/icons/*               web favicon and PWA icons
  app/android/.../mipmap-*/ic_launcher*.png          Android launcher + adaptive icon
  app/android/.../drawable*/launch_logo.png          Android launch screen emblem
  app/ios/Runner/Assets.xcassets/AppIcon.appiconset  iOS app icons
  app/ios/Runner/Assets.xcassets/LaunchImage.imageset iOS launch screen emblem
"""

import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "app"
BRANDING = APP / "assets" / "branding"
WHITE = (255, 255, 255)

# The emblem sits above a clean horizontal gap (y 886-903 on the 1254 px logo) that separates it
# from the SUSTHITI wordmark. Expressed as fractions so a larger original works the same way.
EMBLEM_BOTTOM_FRACTION = 895 / 1254
EMBLEM_MAX_X_FRACTION = 1000 / 1254


def color_to_alpha(img: Image.Image) -> Image.Image:
    """Makes white transparent while preserving appearance: composited back over white the result is
    identical to the original. Soft glows and anti-aliased edges keep their partial transparency."""
    rgb = img.convert("RGB")
    out = Image.new("RGBA", rgb.size)
    src = rgb.load()
    dst = out.load()
    w, h = rgb.size
    for y in range(h):
        for x in range(w):
            r, g, b = src[x, y]
            a = 255 - min(r, g, b)
            if a <= 3:  # compression noise in the white background
                dst[x, y] = (255, 255, 255, 0)
                continue
            f = 255.0 / a

            def channel(c: int) -> int:
                return max(0, min(255, round(255 - (255 - c) * f)))

            dst[x, y] = (channel(r), channel(g), channel(b), a)
    return out


def emblem(transparent: Image.Image) -> Image.Image:
    w, h = transparent.size
    region = transparent.crop((0, 0, round(w * EMBLEM_MAX_X_FRACTION), round(h * EMBLEM_BOTTOM_FRACTION)))
    bbox = region.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    return region.crop(bbox)


def square(img: Image.Image, size: int, fill: float, background=None) -> Image.Image:
    """img centred in a size x size square, occupying `fill` of the side, aspect ratio preserved."""
    canvas = Image.new("RGBA", (size, size), (*(background or WHITE), 255 if background else 0))
    scale = fill * size / max(img.size)
    resized = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    canvas.alpha_composite(resized, ((size - resized.width) // 2, (size - resized.height) // 2))
    return canvas


def save(img: Image.Image, path: Path, rgb: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    (img.convert("RGB") if rgb else img).save(path, optimize=True)
    print(f"  {path.relative_to(ROOT)}  {img.size[0]}x{img.size[1]}")


def main(source: Path) -> None:
    logo = Image.open(source).convert("RGB")
    print(f"Official logo: {source} ({logo.width}x{logo.height})")
    transparent = color_to_alpha(logo)
    mark = emblem(transparent)
    mark_square = square(mark, 1024, 0.92)

    print("Flutter assets")
    save(logo, BRANDING / "susthiti_logo.png", rgb=True)
    save(transparent, BRANDING / "susthiti_logo_transparent.png")
    save(mark_square, BRANDING / "susthiti_mark.png")

    print("Web")
    save(square(mark, 64, 0.94), APP / "web" / "favicon.png")
    # Shown by index.html while Flutter loads (before the in-app splash takes over).
    splash = transparent.copy()
    splash.thumbnail((840, 840), Image.LANCZOS)
    save(splash, APP / "web" / "splash" / "susthiti_logo.png")
    for size in (192, 512):
        save(square(mark, size, 0.82, WHITE), APP / "web" / "icons" / f"Icon-{size}.png", rgb=True)
        # Maskable icons must keep content inside the central 80% circle.
        save(square(mark, size, 0.62, WHITE), APP / "web" / "icons" / f"Icon-maskable-{size}.png", rgb=True)

    print("Android")
    res = APP / "android" / "app" / "src" / "main" / "res"
    for density, legacy, adaptive in (("mdpi", 48, 108), ("hdpi", 72, 162), ("xhdpi", 96, 216), ("xxhdpi", 144, 324), ("xxxhdpi", 192, 432)):
        save(square(mark, legacy, 0.80, WHITE), res / f"mipmap-{density}" / "ic_launcher.png", rgb=True)
        # Adaptive foreground: the launcher crops to the central 72/108; keep the emblem within ~58%.
        save(square(mark, adaptive, 0.58), res / f"mipmap-{density}" / "ic_launcher_foreground.png")
        save(square(mark, legacy * 2, 0.9), res / f"drawable-{density}" / "launch_logo.png")
    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n', encoding="utf-8")
    values = res / "values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#FFFFFF</color>\n</resources>\n', encoding="utf-8")
    print(f"  {anydpi.relative_to(ROOT)}/ic_launcher.xml, values/ic_launcher_background.xml")

    print("iOS")
    appicon = APP / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    contents = json.loads((appicon / "Contents.json").read_text(encoding="utf-8"))
    for entry in contents["images"]:
        points = float(entry["size"].split("x")[0])
        pixels = round(points * int(entry["scale"].rstrip("x")))
        # iOS app icons must be opaque; iOS applies its own rounded mask.
        save(square(mark, pixels, 0.80, WHITE), appicon / entry["filename"], rgb=True)
    launch = APP / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    for scale, name in ((1, "LaunchImage.png"), (2, "LaunchImage@2x.png"), (3, "LaunchImage@3x.png")):
        save(square(mark, 120 * scale, 1.0), launch / name)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(Path(sys.argv[1]))
