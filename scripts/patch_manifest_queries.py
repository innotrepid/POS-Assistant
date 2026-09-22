#!/usr/bin/env python3
"""Add tel/sms package visibility queries for url_launcher (Android 11+)."""
from pathlib import Path

p = Path("android/app/src/main/AndroidManifest.xml")
if not p.exists():
    raise SystemExit(0)
t = p.read_text()
if "android.intent.action.DIAL" in t:
    raise SystemExit(0)
queries = """
    <queries>
        <intent>
            <action android:name="android.intent.action.DIAL"/>
            <data android:scheme="tel"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.SENDTO"/>
            <data android:scheme="sms"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.SENDTO"/>
            <data android:scheme="smsto"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="tel"/>
        </intent>
    </queries>
"""
if "</manifest>" not in t:
    raise SystemExit("no manifest root")
p.write_text(t.replace("</manifest>", queries + "\n</manifest>", 1))
print("manifest queries added")
