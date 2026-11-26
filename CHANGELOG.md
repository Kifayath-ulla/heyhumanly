# Changelog

## 0.1.12 — 2026-11-26

- Grammar slips that small local models leave in are now always fixed: "I has", "we was", "their is", "should of", "he don't" (Mac, Chrome and online).
- Slang you typed stays as you wrote it: "thx", "u", "idk", "btw" and similar are no longer spelled out, except in Professional.
- Not notarized by Apple.

## 0.1.11 — 2026-11-26

Redesign: one shortcut, one small panel.

- Select text in any app and press ⌃⌥Space. A small panel opens next to the text with the rewrite as a word diff. Enter replaces it, ⌘Z undoes, Esc closes, ⌘C copies.
- Five styles: Fix only, Polish, Shorter, Friendly, Professional. Switch with Tab or ⌘1–⌘5; ⌘/ shows why each change was made; ⌘R tries again.
- The app lives in the menu bar only. Settings has three tabs: General, Engine and Privacy.
- A three-step welcome lets you try the panel on a sample before granting any permission. Without Accessibility, ⌃⌥Space rewrites the clipboard instead.
- Removed the dashboard, Insights, review cards, history, dictionary and exercises. Checking as you type is now an opt-in Labs setting.
- Settings from earlier versions are kept when you upgrade.
- Chrome extension: Alt+Shift+H opens the same panel next to your selection with the same five styles; Enter replaces, Tab or 1–5 switches style. The toolbar popup has the five styles too.
- Not notarized by Apple.

## 0.1.10 — 2026-11-26

- Settings → Local AI lists only models that can write. If an embedding model such as `all-minilm` is still saved, the status turns orange and asks you to pick another model, instead of coaching failing.
- Not notarized by Apple.

## 0.1.9 — 2026-11-26

- A message typed all in lowercase stays lowercase after Rephrase (Mac and Chrome).
- Settings → "On this Mac (Ollama)" switches to a model you actually have installed, and says so if Ollama can't be reached or has no writing model.
- Embedding models are never picked for coaching; `mistral` and `mistral:latest` count as the same model.
- Ollama status dots turn red as soon as a coaching finds Ollama stopped, and green again once it's back.
- Not notarized by Apple.

## 0.1.8 — 2026-11-25

- Chrome extension: no longer hangs on "Tightening…" when Chrome never answers whether its built-in model is available; after 2 seconds it uses Ollama instead.
- Online coaching works the first time after the app has been idle (each coaching uses a fresh connection).
- Rephrase fixes clear misspellings ("realy", "alot") while keeping your slang and casing, and names the words it cut instead of saying "Nothing to change".
- First launch says "Welcome", shows the free daily count, and says where your text goes for each engine.
- Settings shows "Check as I type" as off while the engine isn't on this Mac.
- Not notarized by Apple.

## 0.1.7 — 2026-11-25

- Free online coaching now follows the style you pick: Friendly makes text warmer, and Fix only corrects mistakes without cutting or rephrasing.
- Rewrites keep your own opening words and quotes; only labels the model adds (like "Rewrite:") are removed.
- Not notarized by Apple.

## 0.1.6 — 2026-11-23

- Try coaching right away: the coach window works with no Ollama, no API key and no Accessibility permission.
- Engines: Apple's on-device model (macOS 26, Apple Intelligence), free online coaching (asks first; 10 a day), in-app offline coaching (downloads a private Ollama and a model; works with Wi-Fi off), or your own Ollama. Settings › Coaching.
- Accessibility is now the last, optional onboarding step ("Coach in other apps").

## 0.1.5 (2026-11-19)

- Settings › Chrome extension › **Allow**: one button lets the Chrome extension use your local Ollama, without Terminal. The setting is kept after a restart, and Ollama restarts once.
- Not notarized by Apple.

## 0.1.4 (2026-11-18)

- New Chrome extension (`HeyHumanly-Chrome-0.1.4.zip`, see heyhumanly.com/extension).
- New checks: wordy phrases, passive voice and repeated sentence openers, plus readability grade and reading time. Adapted from [Lexicon](https://github.com/AashishH15/Lexicon) (MIT); see `THIRD_PARTY_NOTICES.md`.
- Light by default, redesigned in a Lexicon-inspired paper style (serif headlines, mono labels). Richer research notes.
- Not notarized by Apple.

## 0.1.3 (2026-11-17)

- Keeps your tone: casual stays casual; only filler, repeats and extra words are trimmed.
- Research notes with sources on tips. Fixed contrast bugs and the timeout with thinking models (gemma4); works with any Ollama model.
- New dark design and icon. Not notarized by Apple.

## 0.1.2 (2026-11-17)

- Graphite and silver design, new icon, light and dark website. Not notarized by Apple.

## 0.1.1 (2026-11-17)

- App recoloured from blue to the logo's forest green, sage and cream (light and dark).
- Website redesigned. Still not notarized by Apple; Intel build untested.

## 0.1.0 (2026-11-17): first public release

- Free, open-source (MIT) Mac app. Universal DMG (Apple silicon tested; Intel build included but untested).
- Local writing coach: marks mistakes as you type, teaches the rule, tone and translation rewrites, review cards.
- New: in-app setup for the local model. Start Ollama, download the model with progress and retry, then try an example.
- Default model is chosen by memory: `qwen2.5:7b` on 12 GB+ Macs, `qwen2.5:3b` otherwise.
- Known: not notarized by Apple; Intel build untested; no automatic update check; Slack shows the dot but no underlines.

## 2026-11-17

### Teaching
- New built-in rule book: exact one-line rules, memory tricks and practice sentences for about 60 common mistakes. Explanations no longer come from the model, so they are instant and never invented.
- Lessons now end with practice on a new sentence ("Same rule, new sentence"), and the summary lists the rules you practised.
- A sentence that was largely rewritten is taught as one idea instead of as diff fragments.

### Accuracy
- Meaning guard: model changes that swap in a different word, alter slang or shorthand, or only restyle (contractions, "5pm") are reverted before anything is shown.
- Word-by-word pairing only happens for related words, so nonsense pairs like "to → affect" are gone.

### Fixed
- Crash when a lesson was closed, or when Undo was pressed in the lesson summary.
- Garbled text in the next lesson step after "Use it" (the app reacted to its own paste and shifted positions twice).
- "Use this" failing with "The text changed" after a single fix had been accepted.
- Lesson card cut off at the bottom; mode switch clipped on the right; summary buttons clipped.
- The dot overlapping an open suggestion card; panel left open with no Undo after "Fix mistakes only".
- Double space left behind when a word was removed during a lesson.

### Added
- New leaf icon (Dock, menu bar, window).
- First-run tour (skippable, replay from Settings).
- `esc` closes a card, lesson or panel. Dismissed suggestions are remembered; "Add to dictionary" on spelling cards.
- Menu-bar pause (one hour) and on/off switch.
- Settings: what clicking the dot does, typing pause, mistakes only vs. wording ideas, forget dismissals.
