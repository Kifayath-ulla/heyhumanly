# HeyHumanly Companion — spec and status (2026-11-10)

## 1. Research brief (verified = source-backed; see agent reports in chat)
- Users leave writing assistants over typing lag, popups that cover UI, false positives and "it flattened my voice" (Grammarly engineering blog on input lag, Feb 2025; LanguageTool forum; review sites). Strong for lag, anecdotal for the rest.
- People expect to review every change; silent all-or-nothing edits get criticised (Apple Writing Tools reviews). Anecdotal.
- No data shows people read explanations; so explanations are one click away, never inline by default.
- Trust: local-only processing, per-app block lists and password-field exclusion are what reassure people (Harper, Grammarly block list). Strong.
- Price anchor for local tools: one-time $29–79 or ~$30–50/yr; subscriptions without server costs get backlash.
- AX compatibility: Electron needs `AXManualAccessibility`; Chrome/WebKit contenteditable bounds and writes are unreliable; Google Docs is canvas (unsupported); AX writes are not undoable, paste is.
- Still pending: HeyClicky interaction teardown and learner-needs research (agents running when the battery ran low).

## 2. Product strategy
Primary user: non-native and busy professionals writing chat/email on a Mac.
Jobs: (1) send a clean message now with one action; (2) get better over time without a textbook.
Differentiators: on-device by default, keeps your voice, separates mistakes from style, teaches with try-first questions, one-step undo.
Excluded for now: cloud models, Google Docs, grammar scores, gamified streak pressure.

## 3. Interaction spec
- **Detect:** after a 1.1 s typing pause in a focused text field (≥4 words), the field is checked. Never: secure fields, paused apps, non-local endpoints.
- **Annotate:** red wave = mistake, violet dashes = optional style idea, one mark per visual line, drawn in with a 40 ms stagger. While you type, marks shift with the text; edited ones disappear.
- **Companion dot** at the end of the text: spinner while reading, count (red if any mistake, violet if only style), green check when done.
- **Hover (350 ms) or click an underline:** card under the word with before/after, one-line why, Accept / Dismiss / Don't flag this type.
- **Click the dot (or the main shortcut):** panel under the text: whole-message rewrite with changes tinted, tones (Suggested, Just fixes, Shorter, Warmer, Clearer, Professional, Translate → 10 languages), Use this, Fix mistakes only (⌃⌥↩), Learn (⌃⌥L), Pause in this app, tip for next time.
- **Learn:** card glides to each step; Sentence or Word mode switchable in the card. Step: "Which reads better?" → result → before/after → top 3 reasons (quoting your words) → Use it / Keep mine / I know this. Summary: score, whole-message tip, saved to Review.
- **Undo:** all edits are pasted (app's own ⌘Z works) plus an Undo pill (⌃⌥Z) for 4 s.
- **Shortcuts exist only while suggestions are on screen:** ⌃⌥↩, ⌃⌥L, ⌃⌥Z, ⌃⌥. .

## 4. Design system (overlays)
Solid surface cards (no decorative blur), 0.75 px hairline, radius 14 (cards) / 8 (buttons) / capsule (chips), two shadows (16/8 soft + 1 px contact). SF Pro 11–15 pt; one action blue, red for mistakes, violet for style/learning, green for success. Motion: 0.32 s ease-out glide, spring for state changes, all motion off with Reduce Motion.

## 5. Architecture
`Watcher.swift` (pause detection, privacy gates, Electron AX enable) → `Inline.swift` InlineSession (one local model call per check: rewrite; diff → changes; background "teach" call labels each change error/style, level, why, tip) → `Overlay.swift` (AppKit panels, Core Animation marks) + `CompanionViews.swift` (SwiftUI cards). Writes: select range via AX, paste, verify by reading the value back; fall back to AX set; never write if the text changed. Model: qwen2.5:7b on Ollama, ~2 s rewrite warm, teach 4–10 s in background.

## 6. Validation (this session, real app, TextEdit)
| Test | Result |
|---|---|
| Auto-check after typing pause, no shortcut | Passed (1.95 s) |
| Per-line underlines, mistake vs style colours | Passed |
| Companion panel opens on click, tones listed | Passed |
| Slack example rewrite (prompt C, 3/3 runs) | "Hey Richard, quick heads up. I have an exam this Sunday, so I might not be available. Just wanted to let you know." |
| Learn sentence mode, try-first, Exactly feedback | Passed |
| Use it writes into TextEdit | Passed (text verified) |
| ⌘Z / ⇧⌘Z in TextEdit after Use it | Passed, single step |
| Lesson summary | Passed; tip copied the prompt example → prompt fixed, not re-tested |
| Hover card (0.35 s), with surrounding words | Passed (context added after test) |
| Fix all (⌃⌥↩) as one paste, "Fixed · Undo" pill | Passed |
| Undo (⌃⌥Z) restores original, suggestions return | Passed |
| Tone: Shorter, built from the clean version, ~3.5 s | Passed: "Hey Richard, I have an exam on Sunday and might not be available. Just letting you know." |
| Translate quality (offline check) | Spanish/French/German good; Hindi poor (changed Sunday to Saturday) → warning shown |
| **Slack** (own DM, nothing sent): detect, companion badge, panel, Use this, ⌘Z | Passed. Slack gives no word positions, so no underlines there; companion docks to the message box |
| Slack draft cleared afterwards | Done |
| Safari textarea: underlines on the right words | Passed |
| Safari contenteditable: underlines + Fix all | Passed after two fixes (double space from a deleted word; Safari's non-breaking spaces broke the write check) |
| Cursor returns to the end after an edit | Built, not re-checked |
| Learn, Word mode | Passed: light edits step word by word with context; heavily rewritten sentences stay one step |
| Learn question shows before the explanation arrives | Passed (was ~10 s wait) |
| Settings > Companion card | Passed (renders); paused apps now show names |
| Chrome (profile picker blocked the test), WhatsApp, Mail, Pause app button | Not tested |

## 6b. Compatibility (measured)
| App | Read text | Word positions | Write (paste) | ⌘Z |
|---|---|---|---|---|
| TextEdit | ✓ | ✓ | ✓ | ✓ |
| Safari (textarea, contenteditable) | ✓ | ✓ | ✓ | not checked |
| Slack | ✓ (after AXManualAccessibility) | — (AXBoundsForRange fails; text markers return the whole window, rejected) | ✓ | ✓ |

## Known limits
- Safari/system spellcheck draws its own red dots under some of the same words; HeyHumanly can't turn that off in other apps.
- Explanations for long rewrites take 5–10 s on qwen2.5:7b; questions no longer wait for them.
- Hindi translation is unreliable on this model.

## 7. Roadmap
Next: test the untested rows above; Clicky-inspired motion pass once that research lands; first-run permission onboarding; Review cards from Learn; per-app default tone; notarised build and licence.

## Dot placement (2026-11-11)
| App | Dot position | Hides while typing | Clears when emptied |
|---|---|---|---|
| TextEdit | Below the last line, off the text — passed | Passed | not checked |
| Slack (own DM, nothing sent) | Badge on the message box top-right border — passed | Passed | Passed |
| Discord | Not tested |  |  |


## 2026-11-17 test run (build of 00:20)
Driven without keyboard input where possible: test text set through AppleScript, HeyHumanly's own buttons pressed through Accessibility, results read back from the target app.

| Where | What was checked | Result |
|---|---|---|
| TextEdit | Auto-check, underline alignment, dot below last line | Passed |
| TextEdit | Lesson: guess, rule, memory tip, practice on a new sentence, Use it x3, summary | Passed; text read back correct |
| TextEdit | Close lesson; Undo last in summary | Passed (both crashed before) |
| TextEdit | Just fix it panel, Fix mistakes only, Fixed pill, Undo, suggestions return | Passed |
| TextEdit | Click underline: card, esc closes, Dismiss, dismissed fix not flagged on re-check | Passed |
| Safari textarea (message-box sized) | Dot outside the box, card above the box, lesson, Use it, Undo last | Passed; text read back correct |
| Safari textarea with HH_NO_LOCATE=1 (stands in for Slack/Discord) | No underlines, dot outside the box, lesson card above the box | Passed |
| App | First-run tour (5 steps), Settings > Companion, coach window Quick Fix ("thung" -> "thing") | Passed |

Not tested in this run: Slack and Discord themselves, Chrome, WhatsApp, Mail, hover (mouse-over) card, tone chips and Translate, "Pause in app", menu-bar pause items, dark-mode dashboard, a non-English explanation language.
