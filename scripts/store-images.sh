#!/bin/bash
# Renders the Chrome Web Store promo tiles and the popup screenshot from store/chrome/tiles.html with headless Chrome.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHROME="${CHROME:-$(command -v google-chrome || command -v chromium || command -v chrome || echo "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")}"
OUT="$ROOT/store/chrome"
shot() { # id width height file
  "$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files \
    --window-size="$2,$3" --screenshot="$OUT/$4" "file://$OUT/tiles.html?$1" >/dev/null 2>&1
  echo "$4 ($2x$3)"
}
shot small 440 280 tile-small.png
shot marquee 1400 560 tile-marquee.png
shot popup 1280 800 screenshot-4-popup.png
