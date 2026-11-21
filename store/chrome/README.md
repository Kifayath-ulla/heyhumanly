# Chrome Web Store listing: HeyHumanly

Copy for the Chrome Web Store developer dashboard. Nothing here is submitted automatically.

## Store listing tab

**Name:** HeyHumanly

**Summary** (132 characters max; the manifest `description` is used):
> Tighten your writing on any website in your own voice, and learn why each change helps. Runs locally with Chrome's AI or Ollama.

**Category:** Productivity → Tools (or "Workflow & Planning")

**Language:** English

**Description:**

> HeyHumanly tightens what you write on any website and keeps your voice. Select text in a text box, press Alt+Shift+H (or right-click → Tighten with HeyHumanly), and a panel shows a shorter version plus what changed and why.
>
> Your writing stays on your computer. HeyHumanly sends text only to Ollama, a free app that runs AI models on your own machine, at http://localhost:11434. There is no account, no analytics, no tracking and no HeyHumanly server.
>
> What it does
> • Tightens text and keeps your tone: casual messages stay casual, slang and lowercase stay as written.
> • Keeps facts: names, numbers, dates, links and code are preserved.
> • Explains each change: filler, wordy phrases, passive voice and repeated openers, with a short reason and a source you can check.
> • Shorter and More formal versions when you want them.
> • Apply replaces the text in place; Copy puts it on your clipboard.
> • Works in text boxes and most rich-text editors. On pages Chrome protects (chrome://, the Web Store, PDFs), paste text into the toolbar popup instead.
>
> Setup
> 1. Install Ollama from ollama.com.
> 2. Allow the extension in Ollama: the setup page that opens on install shows one command for Mac, Windows or Linux and checks it live.
> 3. Download a writing model (qwen2.5:7b recommended) from the same page.
>
> Free and open source (MIT): https://github.com/Kifayath-ulla/heyhumanly
> Privacy: https://heyhumanly.com/privacy/#extension

## Privacy practices tab

**Single purpose:**
> HeyHumanly rewrites text the user selects to be clearer and shorter, using an AI model running on the user's own computer through Ollama, and explains each change.

**Permission justifications:**

| Permission | Justification |
|---|---|
| `activeTab` | Reads the text the user selected, or the focused text box, on the current tab only after the user presses the shortcut, clicks the toolbar button or picks the right-click menu item. |
| `scripting` | Injects the HeyHumanly panel into the current tab at that moment, to show the rewrite and apply it in place. No content script runs on pages by default. |
| `contextMenus` | Adds "Tighten with HeyHumanly" to the right-click menu for selected text. |
| `storage` | Saves the user's settings (Ollama address and chosen model) on this computer with `chrome.storage.local`. No writing is stored. |
| Host `http://localhost:11434/*`, `http://127.0.0.1:11434/*` | Sends the selected text to Ollama running on the user's own computer, which produces the rewrite. These are the only network addresses the extension can reach. |

**Remote code:** No. All code ships in the package; no remote scripts or `eval`.

**Data usage** (answers for the form):
- Collected data types: **none**. Text is processed by Ollama on the user's own computer and is never sent to the developer or any third party. "Website content" is read locally only for the user-requested rewrite and is not collected, stored or transmitted off the device.
- Certify: not sold to third parties; not used or transferred for purposes unrelated to the single purpose; not used for creditworthiness or lending.

**Privacy policy URL:** https://heyhumanly.com/privacy/#extension

## Graphics

| Asset | Size | File |
|---|---|---|
| Store icon | 128×128 | `extension/icons/icon128.png` |
| Screenshot 1: panel on a draft | 1280×800 | `store/chrome/screenshot-1-panel.png` |
| Screenshot 2: what changed and why | 1280×800 | `store/chrome/screenshot-2-why.png` |
| Screenshot 3: setup page | 1280×800 | `store/chrome/screenshot-3-setup.png` |
| Screenshot 4: toolbar popup | 1280×800 | `store/chrome/screenshot-4-popup.png` |
| Small promo tile | 440×280 | `store/chrome/tile-small.png` |
| Marquee promo tile | 1400×560 | `store/chrome/tile-marquee.png` |

Screenshots are real captures of the extension against a local Ollama (`qwen2.5:7b`). Tiles are rendered from `store/chrome/tiles.html` (see `scripts/store-images.sh`).

## Package

`./scripts/package-extension.sh` builds `dist/heyhumanly-extension-<version>.zip` from `extension/` for upload.
