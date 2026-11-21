# HeyHumanly

HeyHumanly is a local-first writing coach for macOS. It sits beside whatever you are writing (Slack, Mail, a browser, Notes), catches mistakes after you pause, and teaches you the rule so you stop making them. Its promise: **fix this sentence now, or learn why it could be better.**

Everything runs on this Mac with a local [Ollama](https://ollama.com) model. No account, API key, cloud service, analytics or telemetry.

## What it does

- **Checks as you type.** After a short typing pause it reads the one text box you are in. Real mistakes get a red wavy underline, optional wording ideas a violet dashed one, and a small dot shows the count. The dot sits outside the text and hides while you type.
- **Teach me (default).** Click the dot: pick the right version, read the rule in one line with a way to remember it, then practise the same rule on a new sentence. A summary lists what you practised.
- **Fix now.** `⌃⌥↩` fixes every mistake in one paste; `⌘Z` in the app (or `⌃⌥Z`) undoes it. Click any underline for a single fix.
- **Dismiss.** `esc` closes a card. Dismissed suggestions are remembered and do not come back; "Stop flagging…" mutes a whole type; "Add to dictionary" keeps a word as written.
- **Whole-message versions.** Suggested, Just fixes, Shorter, Warmer, Clearer, Professional, and Translate.
- **Coach window.** Type or paste text, or select text anywhere and press your shortcut. Quick Fix, Teach Me, per-change accept/undo, Copy, Replace.
- **Insights and Review.** The mistakes you make most, and spaced-repetition cards made from your own sentences. Only real usage is counted.

## How the teaching works

Explanations come from a built-in rule book (`Sources/WriteCoach/RuleBook.swift`): about 60 hand-written rules for the mistakes people make most (subject–verb agreement, their/they're, since/for, "discuss about", "didn't went", articles, prepositions, common Indian-English phrases, and more). Each rule has a one-line explanation that quotes your words, a memory trick and a practice sentence. They appear instantly and are never invented by the model. When no rule applies, HeyHumanly says plainly what changed instead of guessing at grammar.

The local model only proposes the corrected text. Before anything is shown, `RewriteGuard` checks every change and reverts the ones that alter meaning ("thung" → "file"), touch slang or shorthand ("gng", "ngl"), or only restyle something harmless ("I will" → "I'll", "5pm" → "5 p.m.").

## Install (Mac)

1. Download `HeyHumanly-<version>.dmg` from [heyhumanly.com](https://heyhumanly.com) or the [latest release](https://github.com/Kifayath-ulla/heyhumanly/releases/latest). Verify it with the `.sha256` file on the release page.
2. Open the DMG and drag HeyHumanly into Applications.
3. Open HeyHumanly. The first-run tour checks for [Ollama](https://ollama.com) and the model. **Get Ollama** opens its download page; **Download model** pulls the model with a progress bar.
4. Allow Accessibility when asked (needed to read the text box you are typing in), then try the example.

**Unsigned release:** releases are ad-hoc signed and not notarized, so macOS may refuse the first open. After checking the checksum, use System Settings › Privacy & Security › Open Anyway. See [heyhumanly.com/install](https://heyhumanly.com/install/#gatekeeper).

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

`release.sh` ad-hoc signs by default. For a notarized build set `DEVELOPER_ID` and `NOTARY_PROFILE` (needs an Apple Developer account). CI builds and publishes on a version tag: see `.github/workflows/release.yml`.

The website lives in `site-src/` and `scripts/build-site.py` (static, deployed to Cloudflare). Release version and download URL come from `site-src/release.json`.

## Contributing and reporting problems

Issues and pull requests are welcome; see `CONTRIBUTING.md`. Do not paste private writing into public issues. For security problems, use a private advisory (see `SECURITY.md`).

## License & Contributors

- **Author & Copyright:** Kifayath
- **AI Teammates & Co-authors:** OpenBot, Claude
- **License:** MIT, see `LICENSE`. Third-party word lists are credited in `THIRD_PARTY_NOTICES.md`. Models are separate downloads under their own licenses.

## Permissions

**Accessibility** (System Settings › Privacy & Security › Accessibility): needed to read the text box you are typing in and to paste a fix you accepted. Without it, the coach window still works with typed or pasted text. See `PRIVACY.md`.


## Settings

Check as I type · what clicking the dot does (teach or fix) · typing pause before a check · mistakes only or also wording ideas · learn by sentence or word · explanation language · apps never read · mistake types to teach · default writing style and per-app styles · Ollama endpoint and model · shortcut · appearance · personal dictionary · forget dismissals · replay the tour · clear history.

The menu-bar leaf pauses coaching for an hour or turns it off.

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
3. Update `site-src/release.json` (version, file, sha256, size), run `python3 scripts/build-site.py`, then `wrangler deploy -c wrangler.prod.jsonc`.
`wrangler.jsonc` deploys the preview at `*.workers.dev` (noindex); `wrangler.prod.jsonc` also attaches heyhumanly.com. Hosting is Cloudflare Workers static assets on the free plan (100,000 requests/day).
