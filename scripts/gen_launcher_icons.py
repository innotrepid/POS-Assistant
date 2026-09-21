#!/usr/bin/env python3
"""Generate Android launcher icons from assets/images/mercate_logo.png"""
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    import subprocess
    import sys

    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow", "-q"])
    from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
logo = ROOT / "assets" / "images" / "mercate_logo.png"
alt = ROOT / "assets" / "images" / "Mercate Logo.png"

if not logo.exists() or logo.stat().st_size == 0:
    if alt.exists() and alt.stat().st_size > 0:
        logo.write_bytes(alt.read_bytes())

if not logo.exists() or logo.stat().st_size == 0:
    print("No logo found; skip icons")
    raise SystemExit(0)

img = Image.open(logo).convert("RGBA")
sizes = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
for folder, size in sizes.items():
    d = ROOT / "android" / "app" / "src" / "main" / "res" / folder
    d.mkdir(parents=True, exist_ok=True)
    r = img.resize((size, size), Image.Resampling.LANCZOS)
    r.save(d / "ic_launcher.png")
    r.save(d / "ic_launcher_round.png")
print("Launcher icons written")
