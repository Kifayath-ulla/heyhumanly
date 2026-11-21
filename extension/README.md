# HeyHumanly for Chrome

Tighten what you write on any website, in your own voice, and learn why each change helps.
Runs on your local Ollama model. No server, no account, no analytics.

## Install (until the Chrome Web Store listing)
1. Install [Ollama](https://ollama.com/download) (Mac, Windows or Linux) and open it.
2. Open `chrome://extensions`, turn on Developer mode, choose Load unpacked, and pick this folder.
3. A setup page opens. It checks that Ollama is running, that Ollama allows this extension (`OLLAMA_ORIGINS`), and that a writing model is installed. For each missing step it shows the exact command for your system and can download the model. You can reopen it from the popup under "Setup checks".
4. Select text in any text box and press Alt+Shift+H (or right-click, Tighten with HeyHumanly).

## Privacy
The extension only runs when you press the shortcut or use the context menu. It sends the selected text to the Ollama address on your own computer and nowhere else.

Wordy-phrase list, passive-voice check, repeated-opener check and the Flesch-Kincaid formula are adapted from Lexicon (MIT) by Aashish Harishchandre. MIT License.
