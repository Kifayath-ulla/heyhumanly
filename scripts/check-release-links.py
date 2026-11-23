#!/usr/bin/env python3
"""Fail if the website would link to release files that don't exist on GitHub yet, or show a wrong checksum.
Run before every deploy (scripts/deploy.sh does). Usage: check-release-links.py"""
import json, sys, urllib.error, urllib.request
from pathlib import Path

R = json.loads((Path(__file__).resolve().parent.parent / "site-src/release.json").read_text())
V, REPO = R["version"], R["repo"]
BASE = f"https://github.com/{REPO}/releases"
urls = {
    "release page": f"{BASE}/tag/v{V}",
    "Mac DMG": f"{BASE}/download/v{V}/{R['file']}",
    "DMG checksum": f"{BASE}/download/v{V}/{R['file']}.sha256",
    "Chrome zip": f"{BASE}/download/v{V}/HeyHumanly-Chrome-{V}.zip",
}

def fetch(url, method="HEAD"):
    req = urllib.request.Request(url, method=method, headers={"User-Agent": "heyhumanly-link-check"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read() if method == "GET" else b""

problems = []
for name, url in urls.items():
    try: fetch(url)
    except urllib.error.HTTPError as e: problems.append(f"{name}: HTTP {e.code} {url}")
    except urllib.error.URLError as e: problems.append(f"{name}: {e.reason} {url}")
if not problems:
    published = fetch(urls["DMG checksum"], "GET").decode().split()[0]
    if published != R["sha256"]:
        problems.append(f"site-src/release.json sha256 {R['sha256']} != published {published}")
if problems:
    print("Release v%s is not ready for the website:\n  " % V + "\n  ".join(problems))
    print("Publish the release first (release workflow), then copy its checksum into site-src/release.json.")
    sys.exit(1)
print(f"Release v{V} links and checksum OK")
