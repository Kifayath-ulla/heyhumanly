# Contributing to HeyHumanly

Thanks for helping. Bug reports, fixes, new writing rules and docs are all welcome.

## Ground rules

- **Privacy is the product.** Text goes only to the coaching engine the user chose: on this Mac (Apple, offline runtime, or their Ollama), or HeyHumanly's online coaching after explicit consent (text, goal, a random install ID and a random per-coaching request ID only; never background checks). The only other network call is the one-time offline download the user confirms. Don't add analytics, telemetry, crash reporting, remote config, accounts or any other network call.
- **Keep the writer's voice.** Casual stays casual. A change to the prompt, the detectors or the meaning guard should keep facts, names, numbers, questions and doubt.
- **Cite real research.** A research note needs a source the reader can open. If there is no solid evidence, give the tip without a citation.
- **Credit what you borrow.** Ported word lists, code or design go in `THIRD_PARTY_NOTICES.md` with their licence (MIT-compatible only).
- Never paste private writing into issues, tests or fixtures.

## Layout

| Path | What |
|---|---|
| `Sources/WriteCoach/` | Mac app (Swift, SwiftUI, AppKit) |
| `extension/` | Chrome extension (Manifest V3, no build step) |
| `site-src/`, `scripts/build-site.py`, `site/` | Website (generated static HTML) |
| `worker/` | Cloudflare Worker (redirects, headers) |
| `eval/` | Rewrite-quality test cases and scorer |

The rewrite prompt and habit detectors exist in both Swift (`Rephrase.swift`, `ProseQuality.swift`) and JS (`extension/core.js`). Change both.

## Build and check

```bash
# Mac app (macOS 14+, Swift 6 Command Line Tools)
./scripts/build-app.sh
HeyHumanly.app/Contents/MacOS/HeyHumanly --guard "<original>" "<model rewrite>"

# Website: edit scripts/build-site.py or site-src/, then regenerate and commit site/
python3 scripts/build-site.py

# Rewrite quality against your local Ollama
node eval/run.mjs --models qwen2.5:7b

# Versions in Info.plist, manifest.json and release.json must match
python3 scripts/check-versions.py
```

Load the extension from `chrome://extensions` › Developer mode › Load unpacked › `extension/`.

## Pull requests

- One topic per PR, with a short description of what changed and why.
- Say how you tested it: the commands you ran, and for UI changes a screenshot (light and dark where it applies).
- Don't bump versions or edit `site-src/release.json` in feature PRs; the maintainer does that when releasing.

By contributing you agree your work is released under the MIT License.
