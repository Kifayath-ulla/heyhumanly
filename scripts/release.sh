#!/bin/zsh
# Builds a universal HeyHumanly.app and a versioned DMG with an Applications shortcut, plus a SHA-256 checksum.
# Usage: scripts/release.sh            (ad-hoc signed; NOT notarized)
#        SIGNING_CERT_P12=<base64 .p12> SIGNING_CERT_PASSWORD=… scripts/release.sh
#          (self-signed, free: keeps Accessibility across updates; NOT notarized; see scripts/make-signing-cert.sh)
#        DEVELOPER_ID="Developer ID Application: Name (TEAMID)" NOTARY_PROFILE=heyhumanly scripts/release.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
OUT="$ROOT/dist/$VERSION"; rm -rf "$OUT"; mkdir -p "$OUT" work/module-cache
export CLANG_MODULE_CACHE_PATH="$ROOT/work/module-cache"
swift build -c release --arch arm64 --arch x86_64
BIN="$(find .build -path '*Products/Release/HeyHumanly' -type f | head -1)"
APP="$OUT/HeyHumanly.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/HeyHumanly"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/HeyHumanly.icns "$APP/Contents/Resources/HeyHumanly.icns"
mkdir -p "$APP/Contents/Resources/Fonts" && cp Resources/Fonts/*.ttf "$APP/Contents/Resources/Fonts/"
lipo -archs "$APP/Contents/MacOS/HeyHumanly"
if [ -n "${DEVELOPER_ID:-}" ]; then
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP"
elif [ -n "${SIGNING_CERT_P12:-}" ]; then
  # Same certificate every release => same designated requirement => macOS keeps the Accessibility grant.
  KC="$(mktemp -d)/heyhumanly-release.keychain-db"; KCPASS="$(openssl rand -hex 16)"; P12="${KC:h}/signing.p12"
  OLD_KCS=("${(@f)$(security list-keychains -d user | sed 's/^ *"//; s/"$//')}")
  trap 'security list-keychains -d user -s "${OLD_KCS[@]}"; security delete-keychain "$KC" 2>/dev/null; rm -rf "${KC:h}"' EXIT
  print -rn -- "$SIGNING_CERT_P12" | base64 --decode > "$P12"
  security create-keychain -p "$KCPASS" "$KC"; security set-keychain-settings "$KC"; security unlock-keychain -p "$KCPASS" "$KC"
  security import "$P12" -k "$KC" -P "${SIGNING_CERT_PASSWORD:-}" -T /usr/bin/codesign >/dev/null
  security set-key-partition-list -S apple-tool:,apple: -s -k "$KCPASS" "$KC" >/dev/null
  security list-keychains -d user -s "$KC" "${OLD_KCS[@]}"   # codesign only finds identities in the search list
  IDENTITY="$(security find-identity -p codesigning "$KC" | awk '/^ *1\)/ {print $2; exit}')"
  codesign --force --keychain "$KC" --sign "$IDENTITY" "$APP"
  codesign -d -r- "$APP" 2>&1 | grep designated; echo "WARNING: self-signed, not notarized."
else
  codesign --force --sign - "$APP"; echo "WARNING: ad-hoc signed, not notarized. Not a frictionless public release."
fi
DMG="$OUT/HeyHumanly-$VERSION.dmg"
STAGE="$(mktemp -d)"; cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "HeyHumanly" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
if [ -n "${DEVELOPER_ID:-}" ]; then
  codesign --sign "$DEVELOPER_ID" --timestamp "$DMG"
  if [ -n "${NOTARY_PROFILE:-}" ]; then xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait && xcrun stapler staple "$DMG"; fi
fi
(cd "$OUT" && shasum -a 256 "HeyHumanly-$VERSION.dmg" > "HeyHumanly-$VERSION.dmg.sha256")
echo "Built $DMG"; cat "$OUT/HeyHumanly-$VERSION.dmg.sha256"
