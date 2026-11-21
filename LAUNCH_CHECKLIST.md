# Launch checklist

Status as of 2026-11-21. Merge order matters: #2 → #3 → #6 and #8 (retarget both to `main`) → #4, #5, #7 in any order.

## Merge (owner)
- [ ] [#1](https://github.com/Kifayath-ulla/heyhumanly/pull/1) Audit, eval set and this checklist
- [ ] [#2](https://github.com/Kifayath-ulla/heyhumanly/pull/2) Extension setup page, real readiness check, actionable errors (P0-1, P1-E1–E5, E8, E9)
- [ ] [#3](https://github.com/Kifayath-ulla/heyhumanly/pull/3) Unit tests, Mac meaning-guard smoke test, CI (P0-3; also fixes changed numbers getting through the guard)
- [ ] [#6](https://github.com/Kifayath-ulla/heyhumanly/pull/6) Explanation cards match the rewrite, hedging as advice, casual detection (P1-Q1, Q2, E7). Retarget to `main` after #2; Mac CI then compiles the Swift side
- [ ] [#8](https://github.com/Kifayath-ulla/heyhumanly/pull/8) Mac visual-audit fixes: long-text freeze, status dot, tour, layout at min sizes, dark toggles, code spans, typo cards (V-P0-1, V-P1-1, 3–13). Retarget to `main` after #3
- [ ] [#4](https://github.com/Kifayath-ulla/heyhumanly/pull/4) Chrome Web Store materials and extension privacy section (P0-2, P1-W3)
- [ ] [#5](https://github.com/Kifayath-ulla/heyhumanly/pull/5) Website: nothing cut off on phones (P1-W1)
- [ ] [#7](https://github.com/Kifayath-ulla/heyhumanly/pull/7) Changelog, CONTRIBUTING, templates, SECURITY, README, version check (P1-R1, R2, R4, R5)

## Decide (owner) — see "Decisions" in AUDIT.md
- [ ] Mac shortcut default (on hold)
- [ ] Apple Developer Program for notarization (P1-M4) — costs money
- [ ] Browser scope: Chrome only, or Edge/Firefox too
- [ ] `OLLAMA_ORIGINS` in the Mac app: pin to the store ID once it exists (P1-M1). The extension setup page in #2 already pins to the extension's own ID
- [ ] Confirm #6's choices: hedging is advice, not a cut; a long message needs two casual signals
- [ ] Default model per RAM size (eval: `qwen2.5:7b` 97%, `qwen2.5:3b` 92% and changes casual style)
- [ ] JSON-LD "AI contributor" entries
- [ ] Update check (P1-M2) would add a network call beyond Ollama; needs your OK or stays out

## Still to fix before launch
- [ ] Filler check flags "you know" in "let you know" and "kind of" in "what kind of" (found while making store screenshots; awaiting go-ahead)
- [ ] P1-Q3 prompt: all 5 models keep "So basically, at the end of the day"; "Shorter" cuts < 25% on 4 of 5
- [ ] P1-Q4 one shared source (or cross-check test) for the Swift and JS prompt/detectors
- [ ] P1-E6 editors inside iframes (TinyMCE, CKEditor, some webmail)
- [ ] P1-W4 real screenshots/GIF on the website (the store screenshots in #4 can be reused)
- [ ] P1-R3 Homebrew cask
- [ ] Mac: "should of went" still not corrected by qwen2.5:3b (V-P1-10); V-P1-2 shortcut warning on hold; P2 polish list in AUDIT.md
- [ ] Mac/Windows `OLLAMA_ORIGINS` commands from #2 tried on real machines

## Release steps (owner only — not done by Devin)
- [ ] Bump version in Info.plist, manifest.json, release.json; `python3 scripts/check-versions.py`
- [ ] Run the release workflow / create the GitHub release
- [ ] `./scripts/package-extension.sh`, then upload the zip and `store/chrome/` assets in the Chrome Web Store dashboard and submit
- [ ] After the store ID exists: pin `OLLAMA_ORIGINS` to it, update the site's extension page
- [ ] `python3 scripts/build-site.py` and `wrangler deploy -c wrangler.prod.jsonc`
- [ ] Spot-check heyhumanly.com on a phone and in dark mode after deploy
