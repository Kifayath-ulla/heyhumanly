# Privacy

HeyHumanly keeps your writing on your computer.

## Mac app

- **What is read:** the single text box you are typing in, after you pause, and text you select when you press the shortcut. Never password fields, and never apps on the "Never read text in" list (password managers, terminals and code editors by default).
- **Where it goes:** to the Ollama endpoint in Settings, which is `localhost` by default. Checking as you type only runs while that endpoint is on this Mac. If you point the coach window at another computer, Settings shows a warning naming it.
- **What is stored:** a session is saved only when you act on a check (accept a fix, start a lesson) or run the coach window. Sessions, review cards, your dictionary, dismissed suggestions and settings live in the app's preferences on this Mac (`~/Library/Preferences/com.heyhumanly.app.plist`). The app's log records timings and categories, not your text.
- **How to remove it:** Settings › Privacy & data › Clear history; Settings › Companion › Forget dismissals; or delete the preferences file.
- **How to stop it:** the menu-bar leaf pauses coaching for an hour or turns off checking as you type. The shortcut still works on demand.
- **Clipboard:** a fix is pasted through the clipboard so the app's own Undo works; your clipboard is restored right after.
- **No** account, analytics, tracking, telemetry or network calls other than to the Ollama endpoint.
- **Permission:** Accessibility, to read the focused text box and paste an accepted fix.

## Chrome extension

- **What is read:** only when you press Alt+Shift+H, click the toolbar button or choose "Tighten with HeyHumanly" from the right-click menu: the selected text, or the text box you are in, on that tab (`activeTab`). No content script runs on pages before that.
- **Where it goes:** only to Ollama on this computer, `http://localhost:11434` or `http://127.0.0.1:11434`. The manifest's `host_permissions` allow no other address.
- **What is stored:** settings (Ollama address and model) in `chrome.storage.local`. Your writing is not stored.
- **Clipboard:** written only when you press Copy, or when Apply can't replace the text in place.
- **No** account, analytics, tracking, telemetry, remote code or HeyHumanly server.
- **How to remove it:** remove the extension in `chrome://extensions`; Chrome deletes its settings.
