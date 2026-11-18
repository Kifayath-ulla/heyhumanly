# HeyHumanly for Chrome

Tighten what you write on any website, in your own voice, and learn why each change helps.
Runs on your local Ollama model. No server, no account, no analytics.

## Install (until the Chrome Web Store listing)
1. Install Ollama and a model, for example `ollama pull qwen2.5:3b`.
2. Let Chrome reach Ollama: `launchctl setenv OLLAMA_ORIGINS "chrome-extension://*"`, then quit and reopen Ollama.
3. Open `chrome://extensions`, turn on Developer mode, choose Load unpacked, and pick this folder.
4. Select text in any text box and press Alt+Shift+H (or right-click, Tighten with HeyHumanly).

## Privacy
The extension only runs when you press the shortcut or use the context menu. It sends the selected text to the Ollama address on your own computer and nowhere else.

Wordy-phrase list, passive-voice check, repeated-opener check and the Flesch-Kincaid formula are adapted from Lexicon (MIT) by Aashish Harishchandre. MIT License.
