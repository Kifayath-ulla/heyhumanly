#!/usr/bin/env python3
"""Fail if the Mac app, the Chrome extension and the website disagree on the version.
Usage: check-versions.py [vX.Y.Z]   (with a tag, it must match too)"""
import json, plistlib, sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
release = json.loads((root / "site-src/release.json").read_text())
found = {
    "Resources/Info.plist": plistlib.loads((root / "Resources/Info.plist").read_bytes())["CFBundleShortVersionString"],
    "extension/manifest.json": json.loads((root / "extension/manifest.json").read_text())["version"],
    "site-src/release.json": release["version"],
}
if len(sys.argv) > 1:
    found["tag"] = sys.argv[1].removeprefix("v")
problems = [] if len(set(found.values())) == 1 else ["versions differ"]
if release["file"] != f"HeyHumanly-{release['version']}.dmg":
    problems.append(f"site-src/release.json file is {release['file']}")
for name, version in found.items():
    print(f"{version:10} {name}")
if problems:
    sys.exit("error: " + "; ".join(problems))
