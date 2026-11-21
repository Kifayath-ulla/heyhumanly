#!/bin/bash
# Builds the zip to upload to the Chrome Web Store: dist/heyhumanly-extension-<version>.zip
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$ROOT/extension/manifest.json")"
mkdir -p "$ROOT/dist"; ZIP="$ROOT/dist/heyhumanly-extension-$V.zip"; rm -f "$ZIP"
(cd "$ROOT/extension" && zip -qr -X "$ZIP" . -x 'README.md' -x '.*')
echo "$ZIP"; unzip -l "$ZIP" | tail -1
