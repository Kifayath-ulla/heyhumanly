# Privacy

HeyHumanly keeps your writing on your Mac.

- **What is read:** the single text box you are typing in, after you pause, and text you select when you press the shortcut. Never password fields, and never apps on the "Never read text in" list (password managers, terminals and code editors by default).
- **Where it goes:** to the Ollama endpoint in Settings, which is `localhost` by default. Checking as you type only runs while that endpoint is on this Mac. If you point the coach window at another computer, Settings shows a warning naming it.
- **What is stored:** a session is saved only when you act on a check (accept a fix, start a lesson) or run the coach window. Sessions, review cards, your dictionary, dismissed suggestions and settings live in the app's preferences on this Mac (`~/Library/Preferences/com.heyhumanly.app.plist`). The app's log records timings and categories, not your text.
- **How to remove it:** Settings › Privacy & data › Clear history; Settings › Companion › Forget dismissals; or delete the preferences file.
- **How to stop it:** the menu-bar leaf pauses coaching for an hour or turns off checking as you type. The shortcut still works on demand.
- **Clipboard:** a fix is pasted through the clipboard so the app's own Undo works; your clipboard is restored right after.
- **No** account, analytics, tracking, telemetry or network calls other than to the Ollama endpoint.
- **Permission:** Accessibility, to read the focused text box and paste an accepted fix.
