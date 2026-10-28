#!/usr/bin/env python3
"""Fully enable core library desugaring (required by flutter_local_notifications).

Must set BOTH:
  - isCoreLibraryDesugaringEnabled / coreLibraryDesugaringEnabled = true
  - coreLibraryDesugaring dependency
Half-config (flag without dependency) makes Gradle fail.
"""
from pathlib import Path
import re

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
DEP_KTS = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
DEP_GROOVY = "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"

# Remove previous half-config / off markers we may have written
text = text.replace("false  // mercate: desugar off", "true")
text = re.sub(
    r"isCoreLibraryDesugaringEnabled\s*=\s*false", "isCoreLibraryDesugaringEnabled = true", text
)
text = re.sub(
    r"coreLibraryDesugaringEnabled\s+false", "coreLibraryDesugaringEnabled true", text
)

if is_kts:
    if "isCoreLibraryDesugaringEnabled" not in text:
        if "compileOptions {" in text:
            text = text.replace(
                "compileOptions {",
                "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
                1,
            )
        else:
            # Insert a minimal compileOptions block inside android {
            text = text.replace(
                "android {",
                "android {\n    compileOptions {\n        isCoreLibraryDesugaringEnabled = true\n"
                "        sourceCompatibility = JavaVersion.VERSION_17\n"
                "        targetCompatibility = JavaVersion.VERSION_17\n    }",
                1,
            )
    if "desugar_jdk_libs" not in text:
        if re.search(r"dependencies\s*\{", text):
            text = re.sub(
                r"dependencies\s*\{",
                "dependencies {\n    " + DEP_KTS,
                text,
                count=1,
            )
        else:
            text += "\ndependencies {\n    " + DEP_KTS + "\n}\n"
else:
    if "coreLibraryDesugaringEnabled" not in text:
        if "compileOptions {" in text:
            text = text.replace(
                "compileOptions {",
                "compileOptions {\n        coreLibraryDesugaringEnabled true",
                1,
            )
        else:
            text = text.replace(
                "android {",
                "android {\n    compileOptions {\n        coreLibraryDesugaringEnabled true\n"
                "        sourceCompatibility JavaVersion.VERSION_17\n"
                "        targetCompatibility JavaVersion.VERSION_17\n    }",
                1,
            )
    if "desugar_jdk_libs" not in text:
        if re.search(r"dependencies\s*\{", text):
            text = re.sub(
                r"dependencies\s*\{",
                "dependencies {\n    " + DEP_GROOVY,
                text,
                count=1,
            )
        else:
            text += "\ndependencies {\n    " + DEP_GROOVY + "\n}\n"

path.write_text(text)
print(f"Desugar fully enabled in {path.name}")
