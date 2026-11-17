# Changelog

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
