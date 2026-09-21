#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / "android" / "app" / "build.gradle.kts"
if not path.exists():
    path = ROOT / "android" / "app" / "build.gradle"
if not path.exists():
    print("No gradle file; skip desugar")
    raise SystemExit(0)

text = path.read_text()
is_kts = path.name.endswith(".kts")
if is_kts:
    if "isCoreLibraryDesugaringEnabled" not in text and "compileOptions {" in text:
        text = text.replace(
            "compileOptions {",
            "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
            1,
        )
    if "desugar_jdk_libs" not in text and "dependencies {" in text:
        text = text.replace(
            "dependencies {",
            'dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n',
            1,
        )
else:
    if "coreLibraryDesugaringEnabled" not in text and "compileOptions {" in text:
        text = text.replace(
            "compileOptions {",
            "compileOptions {\n        coreLibraryDesugaringEnabled true",
            1,
        )
    if "desugar_jdk_libs" not in text and "dependencies {" in text:
        text = text.replace(
            "dependencies {",
            "dependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n",
            1,
        )
path.write_text(text)
print("Desugar patch applied")
