# HeyHumanly

HeyHumanly is a local-first writing tool for the macOS menu bar. Select text anywhere (Slack, Mail, a browser, Notes), press `⌃⌥Space`, see the rewrite next to your text, and press Enter. Press `⌘/` to see why each change was made.

Everything runs on this Mac with a local [Ollama](https://ollama.com) model. No account, API key, cloud service, analytics or telemetry.

## What it does

- **One shortcut.** Select text and press `⌃⌥Space`. A small panel opens next to the selection and streams the rewrite as a word diff.
- **Keys.** `↩` replaces in place (`⌘Z` right after puts yours back), `esc` closes, `⌘C` copies, `⇥`/`⇧⇥` or `⌘1`–`⌘5` switch style, `⌘/` shows why, `⌘R` tries again.
- **Five styles.** Fix only, Polish (default), Shorter, Friendly, Professional.
- **Menu bar only.** No Dock icon or main window: the menu has Fix selection, Style, Engine, Settings and Quit.
- **Labs: check as I type.** Off by default. When on, mistakes in the text box you are in get underlined after you pause (engines on this Mac only).

## How the teaching works

Explanations come from a built-in rule book (`Sources/WriteCoach/RuleBook.swift`): about 60 hand-written rules for the mistakes people make most (subject–verb agreement, their/they're, since/for, "discuss about", "didn't went", articles, prepositions, common Indian-English phrases, and more). Each rule has a one-line explanation that quotes your words, a memory trick and a practice sentence. They appear instantly and are never invented by the model. When no rule applies, HeyHumanly says plainly what changed instead of guessing at grammar.

The local model only proposes the corrected text. Before anything is shown, `RewriteGuard` checks every change and reverts the ones that alter meaning ("thung" → "file"), touch slang or shorthand ("gng", "ngl"), or only restyle something harmless ("I will" → "I'll", "5pm" → "5 p.m.").

## Install (Mac)

1. Download `HeyHumanly-<version>.dmg` from [heyhumanly.com](https://heyhumanly.com) or the [latest release](https://github.com/Kifayath-ulla/heyhumanly/releases/latest). Verify it with the `.sha256` file on the release page.
2. Open the DMG and drag HeyHumanly into Applications.
3. Open HeyHumanly. It lives in the menu bar. The three-step welcome lets you try `⌃⌥Space` on a sample sentence, asks for Accessibility, and picks an engine (Apple on-device, your Ollama, or free online rewrites if you agree).
4. Allow Accessibility (only needed to replace text in other apps), or choose **Copy instead**.

**Unsigned release:** releases are ad-hoc signed and not notarized, so macOS may refuse the first open. After checking the checksum, use System Settings › Privacy & Security › Open Anyway. If macOS says the DMG "is damaged", check the checksum and run `xattr -d com.apple.quarantine` on that exact file only, for example `xattr -d com.apple.quarantine ~/Downloads/HeyHumanly-0.1.7.dmg`. See [heyhumanly.com/install](https://heyhumanly.com/install/#gatekeeper).

## Chrome extension (Mac, Windows, Linux)

The extension in `extension/` brings the same tone-keeping rewrite to any website: select text and press `Alt+Shift+H`, use the toolbar button, or right-click › Tighten with HeyHumanly. It talks only to Ollama on your own computer (`localhost:11434`). Setup steps for each system: [heyhumanly.com/extension](https://heyhumanly.com/extension/). Until it is in the Chrome Web Store, load it from `chrome://extensions` › Developer mode › Load unpacked.

## Requirements

- macOS 14 or later. The DMG is universal (Apple silicon and Intel). Apple silicon is tested; the Intel build compiles but has not been run on an Intel Mac.
- [Ollama](https://ollama.com) and a model. Default: `qwen2.5:7b` (4.7 GB, Apache-2.0) on Macs with 12 GB+ memory, otherwise `qwen2.5:3b` (1.9 GB, Qwen license; check its terms). You can pick any installed model in Settings.
- About 5 GB free disk; 16 GB memory recommended.

## Build from source

```bash
xcode-select --install        # Command Line Tools (Swift 6)
./scripts/build-app.sh        # debug-friendly local app: HeyHumanly.app
./scripts/release.sh          # universal app + versioned DMG + SHA-256 in dist/<version>/
open HeyHumanly.app
```

`release.sh` ad-hoc signs by default. Ad-hoc builds get a new code hash every release, so macOS silently drops the Accessibility permission after each update (the app then offers **Fix access**). To keep it, sign every release with the same free self-signed certificate: run `scripts/make-signing-cert.sh` once and add `SIGNING_CERT_P12` and `SIGNING_CERT_PASSWORD` as GitHub Actions secrets; `release.sh` then uses it. This is not notarization. For a notarized build set `DEVELOPER_ID` and `NOTARY_PROFILE` (needs an Apple Developer account). CI builds and publishes on a version tag: see `.github/workflows/release.yml`.

The website lives in `site-src/` and `scripts/build-site.py` (static, deployed to Cloudflare). Release version and download URL come from `site-src/release.json`.

## Contributing and reporting problems

Issues and pull requests are welcome; see `CONTRIBUTING.md`. Do not paste private writing into public issues. For security problems, use a private advisory (see `SECURITY.md`).

## License & Contributors

- **Author & Copyright:** Kifayath
- **AI Teammates & Co-authors:** OpenBot, Claude
- **License:** MIT, see `LICENSE`. Third-party word lists are credited in `THIRD_PARTY_NOTICES.md`. Models are separate downloads under their own licenses.

## Permissions

**Accessibility** (System Settings › Privacy & Security › Accessibility): needed to read your selection and replace it in other apps. Without it, copy text first: `⌃⌥Space` rewrites what you copied and Enter copies the result. See `PRIVACY.md`.


## Settings

**General:** shortcut · default style · open at login · Accessibility · apps never read · Labs: check as I type · forget dismissed suggestions · show welcome again.
**Engine:** Apple on-device · free online · offline (managed Ollama) · your Ollama with its model and endpoint.
**Privacy:** where your text goes with each engine.

## Developer checks

```bash
HeyHumanly.app/Contents/MacOS/HeyHumanly --teach "Me and him goes to the office everyday."   # full check, printed
HeyHumanly.app/Contents/MacOS/HeyHumanly --guard "<original>" "<model rewrite>"             # what the meaning guard lets through
HH_NO_LOCATE=1 HeyHumanly.app/Contents/MacOS/HeyHumanly                                      # treat every field like Slack (no word positions)
```

Automated tests (run in CI on every pull request):

```bash
node --test tests/*.test.mjs                               # extension, worker and repo rules (Node 22+)
./scripts/smoke-mac.sh HeyHumanly.app/Contents/MacOS/HeyHumanly   # meaning-guard cases (Mac)
```

## Known limits

- Slack and Discord do not report where each word is on screen, so there are no underlines there; the dot, lessons and fixes still work.
- Google Docs draws its text on a canvas and cannot be read.
- Chrome, WhatsApp and Mail are not yet tested. See `COMPANION_SPEC.md` for the compatibility table.
- Translation quality depends on the local model; Hindi was unreliable on `qwen2.5:7b`.

## Releasing and deploying (maintainers)

1. Bump the version in `Resources/Info.plist` (`CFBundleShortVersionString`), `extension/manifest.json` and `site-src/release.json`, add a `CHANGELOG.md` entry, check with `python3 scripts/check-versions.py`, then run `./scripts/release.sh`.
2. `gh release create vX.Y.Z dist/X.Y.Z/*.dmg dist/X.Y.Z/*.sha256 --notes-file ...`
3. Update `site-src/release.json` (version, file, sha256, size), copying the checksum from the published release, then run `./scripts/deploy.sh`. It refuses to deploy until the release files exist, so the download links can't 404.
`wrangler.jsonc` deploys the preview at `*.workers.dev` (noindex); `wrangler.prod.jsonc` also attaches heyhumanly.com. Hosting is Cloudflare Workers static assets on the free plan (100,000 requests/day).
