#!/usr/bin/env python3
"""Ensure core library desugaring is either fully configured or fully off.

Newer Flutter templates often have no app-level dependencies {} block. Enabling
isCoreLibraryDesugaringEnabled without adding coreLibraryDesugaring(...) makes
Gradle fail. We do not need desugar for current deps, so we prefer OFF unless
both flag + dependency can be set cleanly.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
candidates = [
    ROOT / "android" / "app" / "build.gradle.kts",
    ROOT / "android" / "app" / "build.gradle",
]
path = next((p for p in candidates if p.exists()), None)
if path is None:
    print("No app gradle file; skip")
    raise SystemExit(0)

text = path.read_text()
is_kts = path.suffix == ".kts"

# Always strip any half-applied desugar enable so builds stay green.
# (We currently do not require desugaring.)
if is_kts:
    text = text.replace(
        "isCoreLibraryDesugaringEnabled = true\n",
        "",
    )
    text = text.replace(
        "isCoreLibraryDesugaringEnabled = true",
        "false  // mercate: desugar off",
    )
else:
    text = text.replace(
        "coreLibraryDesugaringEnabled true\n",
        "",
    )
    text = text.replace(
        "coreLibraryDesugaringEnabled true",
        "coreLibraryDesugaringEnabled false",
    )

path.write_text(text)
print(f"Desugar normalized (off) in {path.name}")
