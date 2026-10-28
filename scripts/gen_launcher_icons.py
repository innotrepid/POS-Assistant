#!/usr/bin/env python3
"""Generate Android launcher icons from assets/images/mercate_logo.png"""
from __future__ import annotations

import importlib
import subprocess
import sys
from pathlib import Path

# Install Pillow into a local folder so GitHub Actions always finds it
_PILLOW_DIR = Path("/tmp/mercate_pillow")


def ensure_pillow() -> None:
    try:
        import PIL  # noqa: F401

        return
    except ImportError:
        pass

    _PILLOW_DIR.mkdir(parents=True, exist_ok=True)
    cmd = [
        sys.executable,
        "-m",
        "pip",
        "install",
        "pillow",
        "--disable-pip-version-check",
        "--target",
        str(_PILLOW_DIR),
    ]
    print("Installing pillow:", " ".join(cmd))
    subprocess.check_call(cmd)
    if str(_PILLOW_DIR) not in sys.path:
        sys.path.insert(0, str(_PILLOW_DIR))
    importlib.invalidate_caches()


ensure_pillow()
from PIL import Image  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
logo = ROOT / "assets" / "images" / "mercate_logo.png"
alt = ROOT / "assets" / "images" / "Mercate Logo.png"

if not logo.exists() or logo.stat().st_size == 0:
    if alt.exists() and alt.stat().st_size > 0:
        logo.write_bytes(alt.read_bytes())
        print("Copied Mercate Logo.png -> mercate_logo.png")

if not logo.exists() or logo.stat().st_size == 0:
    print("No logo found; skipping icon generation")
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
    r.save(d / "ic_launcher_foreground.png")
print("Launcher icons written")
