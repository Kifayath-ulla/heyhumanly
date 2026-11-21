# HeyHumanly launch audit (Phase 1)

Audited version 0.1.5 (`main` at `1ae97f3`). Nothing here has been fixed yet. Each item says where I found it and how I checked it.

**Priorities**
- **P0**: blocks launch. Users hit it on the main path, or it blocks a store listing.
- **P1**: should be fixed before launch. A real bug, a misleading message, a privacy or accessibility gap, or missing launch infrastructure.
- **P2**: polish, or worth doing soon after launch.

**How each item was checked**
- **Verified**: reproduced on this machine (real Chrome, real Ollama 0.40.17 on CPU, `wrangler dev`, Lighthouse 12, Node).
- **Code**: found by reading the source, not reproduced.
- **Mac (earlier E2E)**: from the macOS session that ran on 2026-11-20.

The Mac app's screens have not yet been audited visually in this round (light and dark, VoiceOver, small windows). See "Not covered yet".

## Summary

| Surface | P0 | P1 | P2 |
|---|---|---|---|
| Chrome extension | 2 | 9 | 9 |
| Rewrite quality and detectors (shared) | 0 | 4 | 5 |
| Website | 0 | 4 | 6 |
| Mac app | 0 | 4 | 4 |
| Repo, docs, CI, distribution | 1 | 5 | 3 |

The biggest launch risk: **on a fresh install the extension does not work.** With default settings, Ollama rejects requests from any browser extension (HTTP 403). Only Mac users get instructions for this, and the popup still says "Ollama connected".

---

## P0: blocks launch

### P0-1 Extension is blocked by Ollama by default, and only Mac users get a fix (Verified)
- On Ollama 0.40.17 with default settings, `/api/generate` returns **403** for any `chrome-extension://` or `moz-extension://` origin. `curl -H "Origin: chrome-extension://x" localhost:11434/api/tags` → 403.
- So every new extension user hits this before their first rewrite.
- The error (`extension/core.js` `httpError`) only offers the Mac app button or `launchctl setenv`. Windows and Linux users get no working steps.
- The `/extension/` page has the same macOS-only steps.
- **Fix:**
  - Add first-run onboarding with live checks: Ollama running, model installed, origin allowed.
  - Give per-OS copy-paste steps: macOS `launchctl`; Windows `setx OLLAMA_ORIGINS` and restart the tray app; Linux `systemctl edit ollama`, add `Environment=`, then restart.
  - Once the store ID exists, pin the origin to `chrome-extension://<store-id>` (see P1-S1).

### P0-2 No Chrome Web Store assets or privacy disclosure (Code)
The store needs things that are missing:
- 1280×800 screenshots.
- 440×280 small and 1400×560 marquee promo tiles.
- A store description and a single-purpose statement.
- Justifications for the `activeTab`, `scripting`, `contextMenus`, `storage` and `localhost:11434` permissions.
- A privacy policy that covers the extension. `PRIVACY.md` and `/privacy/` only describe the Mac app.

The icons (16/32/48/128) exist and have the right sizes.

### P0-3 No automated tests or CI (Code)
- There is no `Tests/` target in `Package.swift`, and no JS tests.
- The only workflow is the manual `release.yml`.
- Detector logic is copied by hand across `extension/core.js`, `Rephrase.swift`, `ProseQuality.swift` and `StyleRulesData.swift`. The same is true of the rewrite prompt. Nothing checks that the copies stay in sync.
- A launch without at least a build-and-test CI risks shipping broken releases.

---

## P1: fix before launch

### Chrome extension
- **P1-E1 Popup says "Ollama connected" when every rewrite will fail (Verified).** `GET /api/tags` succeeds because Chrome sends no Origin on that GET, but the rewrite `POST` gets 403. (Screenshot in the PR.) The status should test a real request and report "blocked".
- **P1-E2 No timeout on Ollama calls (Code).** `listModels`/`tighten` use `fetch` with no `AbortController`. A slow or stuck model spins forever. On this machine's CPU the median time per message was 8.8 s for `qwen2.5:7b` and 21.9 s for `gemma4:12b`, and the first call also has to load the model. Add a timeout plus a message like "Still working… a smaller model is faster", with a Cancel button.
- **P1-E3 Apply can overwrite text you typed after opening the panel (Code).** `content.js` saves the selection offsets/range when the panel opens and replaces exactly that range on Apply. It does not check that the text is still the same. The Mac app does guard this ("The text changed"). The extension should re-check and fall back to Copy.
- **P1-E4 Long text is silently cut off (Code).** `num_predict` is capped at 700 tokens and there is no input limit. A long email comes back truncated and is shown as the rewrite. Detect `done_reason: "length"`, or limit/split the input and tell the user.
- **P1-E5 The address setting allows any host, but permissions only cover `localhost:11434` / `127.0.0.1:11434` (Code).** A different port or LAN host fails with "Can't reach Ollama". Either validate the address and explain why, or request optional host permissions.
- **P1-E6 Editors inside iframes don't work (Code).** `executeScript({allFrames:false})` means many CMS editors (TinyMCE, CKEditor) and some webmail show "Select some text".
- **P1-E7 Rule checks treat a whole message as casual from one word (Verified).**
  - `isCasual` returns true for a single "hey", "u", "ya", any emoji, or text that starts in lowercase. That turns off the Hedging, Wordy, Passive and Vague checks.
  - Example: "Hey Sam, I think we should probably maybe consider perhaps delaying, I guess, due to the fact that…" gets **no** hedging or wordy flags.
  - Example: "The U.S. team…" counts as casual (`\bu\b`).
- **P1-E8 Slow on large text (Verified).** `quickCheck` on 20,000 words took 11.7 s in Node. A 2,000-times repeated filler phrase took 4.2 s. It runs in the service worker and popup, and the UI freezes. Cap the input or optimise `detect`.
- **P1-E9 Error messages without a next step (Code).**
  - "The extension could not run. Reload the page and try again."
  - "Ollama returned an error (500)."
  - Shortcut on `chrome://`, Web Store or PDF pages: nothing happens at all.
  - Each needs a plain next step.

### Rewrite quality and explanations (shared by Mac and extension)
- **P1-Q1 "What changed, and why" cards aren't checked against the rewrite (Code).** `detect()` only looks at the original. So a card can say "“basically” *cut*" when the model kept it. This breaks the "every change explained" promise. Keep only cards whose `before` phrase is actually gone from or changed in the rewrite.
- **P1-Q2 Hedging is shown as struck-through "cut", but the prompt says to keep doubt (Code).** `CUTS` includes Hedging, while `buildPrompt` says "keep that doubt". The card and the rewrite contradict each other. Show Hedging as advice, not a cut.
- **P1-Q3 The models leave filler in, and "Shorter" barely shortens (Verified, `eval/`).**
  - All 5 models kept "So basically, at the end of the day".
  - "Shorter" cut less than 25% on 4 of 5 models.
  - `qwen2.5:3b` capitalises lowercase text and expands slang.
  - See the results table below.
- **P1-Q4 The prompt, the detectors and the slang list are copied in Swift and JS (Code).** Already drifting: Swift has three wordy lists against JS's one. Share one data file, or add a cross-check test (see P0-3).

### Website
- **P1-W1 Content cut off on phones (Verified, 360 px).**
  - The `/extension/` setup steps run past the right edge and are cut by `main{overflow:hidden}`. The commands can't be read. (Screenshot in the PR.)
  - On `/install/` the SHA-256 line and `shasum` command are cut the same way.
  - In the header, "HeyHumanly" is truncated to "HeyHuman" behind the theme button.
- **P1-W2 Text contrast below WCAG AA (Verified, Lighthouse).** These demo chips on the home page fail:
  - `#507a53` on `#edf3ec`: 4.38.
  - `#3c80ad` on `#e1f3fe`: 3.77.
  - `#a47921` on `#fbf3db`: 3.55.
  - AA needs 4.5.
- **P1-W3 The privacy page has no section on the extension (Code).** It's needed for the store (P0-2) and for honesty.
- **P1-W4 No real screenshots or GIF of the app or extension (Code).** The site uses an illustration (`app.png`) and HTML mock-ups.

### Mac app
- **P1-M1 "Allow" for the Chrome extension lets every extension use Ollama (Code).**
  - `BrowserAccess.swift` sets `OLLAMA_ORIGINS="chrome-extension://*,…"` via `launchctl` and a LaunchAgent that runs at every login.
  - After that, any installed extension can call the local Ollama: generate, pull and delete models.
  - Pin it to HeyHumanly's extension ID(s), and explain the setting in the UI.
- **P1-M2 No update check (Code).** Users of 0.1.x never hear about fixes. The CHANGELOG already lists this as a known issue.
- **P1-M3 No unit tests for the detectors, the meaning guard or the rule book (Code).** `--guard`/`--teach` CLI modes exist and are a good base for tests.
- **P1-M4 Not notarized (Code).** Gatekeeper blocks a first launch. `scripts/release.sh` already supports `DEVELOPER_ID` + `NOTARY_PROFILE`; it only needs an Apple Developer account, which is your decision.

### Repo, docs, CI
- **P1-R1 `CHANGELOG.md` stops at 0.1.1.** The app is at 0.1.5.
- **P1-R2 Missing contributor files.** No `CONTRIBUTING.md`, no issue templates, no PR template. `SECURITY.md` is 3 lines and mentions only the Mac app.
- **P1-R3 No Homebrew cask and no packaging script for the extension zip (Code).**
- **P1-R4 The README is Mac-first.** The extension, Windows and Linux are barely covered. It has duplicate "License" and "License & Contributors" sections.
- **P1-R5 Release metadata is set by hand.** The version lives in `release.json`, `manifest.json` and the Swift `Info.plist`, with nothing checking they match.

---

## P2: polish

### Extension
- Panel and popup have no dark mode (hard-coded white).
- Panel a11y:
  - `role="dialog"`, but focus isn't moved into it.
  - No `aria-live` for "Tightening…" or the result.
  - Buttons stay enabled while a request runs.
- Popup a11y: the textarea has only a placeholder (no label), `<html>` has no `lang`, and status isn't announced.
- `navigator.clipboard.writeText` isn't awaited, so "copied" shows even if copying failed.
- The panel is fixed bottom-right and can cover the field being edited.
- `pickModel` falls back to `models[0]`, which can be an embedding-only model.
- Rule checks fire inside URLs, emails and code:
  - "in order to" inside a URL gets flagged as wordy.
  - Repetition flags "com in order".
  - `` `kind of` `` inside code gets flagged as filler.
- The readability "Grade" for Arabic or Hindi is meaningless (it shows "Grade 1"). Hide it for non-Latin text.
- `ui.highlight` adds `<mark>`s to an HTML string one by one. A later phrase like "bad" or "class" can match inside earlier markup.
- Firefox needs `background.scripts` and `browser_specific_settings.gecko.id`. Edge can use the Chrome zip as-is.

### Rewrite and detectors
- "Buried the point" only compares against the rewrite's first sentence.
- Repetition 3-grams cross sentence boundaries.
- Thinking models: `think:false` is sent, and `<think>` blocks are stripped. A model that ignores `think:false` still costs the full thinking time; we could show "thinking…" instead.
- Model recommendation: the code picks 7b at RAM ≥ 15 GB, but the CHANGELOG says 12 GB.
- The Mac setting is the full `/api/generate` URL, but the extension uses the base URL. They should match.

### Website
- `heading-order` fails on most pages (h4 straight after h2).
- The comparison table on `/grammarly-alternative/` has no `<th scope>` (`td-has-header`).
- Mobile LCP in Lighthouse was 3.3 s (home) and 4.2 s (install). This was local and CPU-contended, so treat it as a rough indication.
- The LCP element is text, waiting on Newsreader (128 KB + 143 KB italic). Preload the regular weight, consider dropping the italic file, and serve images as WebP/AVIF.
- JSON-LD lists `contributor` entries as `@type: Thing` ("Claude", "OpenBot"). `contributor` expects Person or Organization. Fix or remove.
- CSP allows `script-src 'unsafe-inline'`. Hashes would be tighter. Low risk on a static site.
- A few small tap targets outside running text.

### Mac
- `as!` casts on AX values (`Inline.swift` ×5, `Services.swift:404`). Low risk, since they are CF casts, but `guard`/`CFGetTypeID` would be safer.
- The default shortcut ⌃⌥Space clashes with a macOS shortcut (Settings shows a warning). **On hold: you asked for no changes without your go-ahead.**
- Earlier E2E skipped: Accessibility-based replacement in other apps, and the global shortcut.
- `COMPANION_SPEC.md` is in the repo root. Check it's still accurate, or move it to `docs/`.

### Repo
- `.wrangler/` is in the working tree. It is ignored, but confirm it never gets committed.
- Google and Bing verification files are fine to keep.
- Licence notices: Lexicon, retext-* (MIT), Newsreader, Geist and JetBrains Mono (OFL) are credited in `THIRD_PARTY_NOTICES.md`.
  - The extension zip doesn't include `THIRD_PARTY_NOTICES.md`/`LICENSE`, even though `core.js` contains Lexicon-derived lists. Include them in the package.

---

## Rewrite-quality eval

`eval/cases.json` holds 17 cases: casual, formal, mixed, rambling, a very long sentence, URL and email, code, Spanish, Arabic (RTL), emoji, questions, doubt, and the "Shorter" and "More formal" goals.

`eval/run.mjs` sends each case through the extension's exact prompt (`buildPrompt`/`cleanRewrite` from `extension/core.js`) and scores it on these checks:
- Facts, names and numbers kept.
- Questions kept.
- Doubt kept.
- No added formality.
- Lowercase and slang kept.
- Same language and script.
- Cut enough, or barely changed when already tight.
- No bloat, no invented words.
- Long sentence split.

Run it:

```bash
node eval/run.mjs --models qwen2.5:3b,qwen2.5:7b --out eval/results   # --case <id> for one case
```

Results (Ollama 0.40.17, CPU only, 8 cores, temperature 0.2, seed 7):

| model | score | cases fully passed | median latency | failed checks |
|---|---|---|---|---|
| qwen2.5:3b | 92% | 10/17 | 4.6s | casual-slang:keepsLowercase, casual-lowercase-doubt:keepsLowercase, casual-lowercase-doubt:keepsSlang, rambling-meeting:removesFiller, inline-code:removesFiller, arabic-rtl:removesFiller, very-long-sentence:cutsEnough, goal-shorter:removesFiller, goal-shorter:cutsEnough |
| llama3.2 | 97% | 13/17 | 5.6s | rambling-meeting:removesFiller, spanish:removesFiller, arabic-rtl:removesFiller, doubt-question:keepsQuestion |
| qwen2.5:7b | 97% | 14/17 | 8.8s | casual-lowercase-doubt:keepsSlang, casual-lowercase-doubt:noInvention, rambling-meeting:removesFiller, goal-shorter:cutsEnough |
| qwen3.5:9b | 96% | 12/17 | 18.7s | casual-lowercase-doubt:removesFiller, rambling-meeting:removesFiller, mixed-update:removesFiller, very-long-sentence:cutsEnough, goal-shorter:cutsEnough |
| gemma4:12b | 98% | 15/17 | 21.9s | mixed-update:removesFiller, goal-shorter:cutsEnough |

What the table shows:
- **All 5 models kept "So basically, at the end of the day"** in the rambling sample, even though the prompt names "So basically" as filler to cut. The prompt needs a worked example, or a cleanup step after the model.
- **"Shorter" barely shortens.** 4 of 5 models cut less than 25%. `qwen2.5:3b` and `qwen2.5:7b` kept "Um, so I just wanted to quickly check in".
- **`qwen2.5:3b` changes casual tone.** It capitalises lowercase messages ("Yo bro", "U still…"), turns "tmrw/ur" into "tomorrow/you're", and keeps "um" filler. It is the default on Macs under 15 GB, so most users get it.
- **`llama3.2` turned a question into a statement** ("…until Q4 budget is approved."). It left the Spanish text unchanged and kept the Arabic filler "يعني".
- **`gemma4:12b` scored best (98%), but took 22 s per message on CPU.** `qwen2.5:7b` was the best quality for its speed (97%, 8.8 s).
- **Facts, names, numbers, URLs, emails, code and the language were kept in every case by every model.**

The automatic checks are deliberately simple. The JSON file has each rewrite so you can read them yourself.

Latency is CPU-only. On an Apple-silicon Mac it will be several times faster.

## Not covered yet
- **Mac app visual audit:**
  - Every screen in light and dark.
  - VoiceOver labels; 95 `accessibilityLabel`s exist for about 98 buttons.
  - Small windows and long text.
  - Replace-in-app in Slack, Safari, Notes, Mail and Chrome.
  - This needs a macOS session with Accessibility granted.
- Real-device mobile Safari check of the site (Chrome mobile emulation only).
- Firefox/Edge install test.

## Decisions for Kifayath
1. **Mac shortcut default:** keep ⌃⌥Space or pick a new default. On hold until you say.
2. **Apple Developer Program ($99/yr):** needed for notarization and a smooth Homebrew cask. I will not buy it.
3. **Browser scope for launch:** Chrome only, or also Edge (same zip) and Firefox (small build variant)?
4. **Windows/Linux:** extension-only at launch (with OS-specific Ollama setup), or plan a desktop app? I'll write the Tauri vs Electron vs native comparison in Phase 2 without starting a port.
5. **Hedging:** treat it as a coaching tip only (keep the doubt, as the prompt says), or let "Shorter" remove hedges?
6. **Casual detection:** should one "hey" or an emoji switch off the formal-writing checks for the whole message?
7. **`OLLAMA_ORIGINS` scope:** pin it to the store ID (safer, but unpacked dev builds then need their own ID), or keep the wildcard and say so plainly?
8. **JSON-LD "AI contributor" entries:** keep, fix the type, or remove?
9. **Default model:** the eval suggests `qwen2.5:7b` when there is enough RAM. On smaller Macs, either keep `qwen2.5:3b` (fast, but it changes casual tone) or try `llama3.2` (keeps tone, but once turned a question into a statement). Confirm before I change `pickModel` or `recommendedModel`.
