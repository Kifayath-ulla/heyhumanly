# Privacy

HeyHumanly keeps your writing on your computer in offline mode. Optional online coaching on the Mac sends only the text you choose, and only after you agree.

## Mac app

- **What is read:** the single text box you are typing in, after you pause, and text you select when you press the shortcut. Never password fields, and never apps on the "Never read text in" list (password managers, terminals and code editors by default).
- **Where it goes:** depends on the coaching mode shown in Settings › Coaching:
  - **On this Mac (Apple)**, **On this Mac (offline)** and **On this Mac (Ollama)**: nothing leaves your Mac. Offline coaching runs a private copy of Ollama on `127.0.0.1:11435` with its models in `~/Library/Application Support/HeyHumanly`.
  - **Online (Cloudflare)**, only after you choose "Try online coaching": the text you coach in the coach window or with the shortcut is sent to HeyHumanly's server (`heyhumanly.com/api/v1/coach`), where Cloudflare Workers AI rewrites it. Only the text, the goal, a random install ID and a random ID for that one coaching (so a retry after a dropped connection is not counted twice) are sent; no app name, history or dictionary. HeyHumanly doesn't store or log it; Cloudflare says it doesn't keep or train on it. As with any web request, your IP address reaches the server; it keeps only per-day counts by install ID and a daily-salted hash of the IP, to enforce the free limit. Cloudflare may keep request metadata (time, size, model, status). Turn it off in Settings › Coaching.
  - Checking as you type only runs on an engine on this Mac; it never sends text online.
- **What is stored:** a session is saved only when you act on a check (accept a fix, start a lesson) or run the coach window. Sessions, review cards, your dictionary, dismissed suggestions and settings live in the app's preferences on this Mac (`~/Library/Preferences/com.heyhumanly.app.plist`). The app's log records timings and categories, not your text.
- **How to remove it:** Settings › Privacy & data › Clear history; Settings › Companion › Forget dismissals; or delete the preferences file.
- **How to stop it:** the menu-bar leaf pauses coaching for an hour or turns off checking as you type. The shortcut still works on demand.
- **Clipboard:** a fix is pasted through the clipboard so the app's own Undo works; your clipboard is restored right after.
- **No** account, analytics, tracking or telemetry. Network calls: the coaching mode you chose, and the one-time offline-coaching download (Ollama from GitHub, the model from Ollama's library).
- **Permission:** Accessibility, to read the focused text box and paste an accepted fix.

## Chrome extension

- **What is read:** only when you press Alt+Shift+H, click the toolbar button or choose "Tighten with HeyHumanly" from the right-click menu: the selected text, or the text box you are in, on that tab (`activeTab`). No content script runs on pages before that.
- **Where it goes:** to Chrome's built-in model on this computer when available, otherwise only to Ollama on this computer, `http://localhost:11434` or `http://127.0.0.1:11434`. The manifest's `host_permissions` allow no other address.
- **What is stored:** settings (Ollama address and model) in `chrome.storage.local`. Your writing is not stored.
- **Clipboard:** written only when you press Copy, or when Apply can't replace the text in place.
- **No** account, analytics, tracking, telemetry, remote code or HeyHumanly server.
- **How to remove it:** remove the extension in `chrome://extensions`; Chrome deletes its settings.
