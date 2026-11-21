# Security

## Reporting

Report vulnerabilities privately through GitHub: **Security › Report a vulnerability** on this repository. Please don't open a public issue, and don't include private writing in reports.

## Scope

- **Mac app**: reads the focused text box through Accessibility and pastes accepted fixes. It sends text only to the Ollama address in Settings (localhost by default).
- **Chrome extension**: reads the selection or text box on the active tab only after you press the shortcut, click the button or use the menu. Its permissions allow requests only to `localhost:11434` and `127.0.0.1:11434`.
- **Website and Cloudflare Worker** (heyhumanly.com): static pages, redirects and headers.

Especially relevant: anything that sends text off the computer, reads text without a user action, lets a web page or another extension drive HeyHumanly or Ollama, or tampers with downloads and checksums.

## Supported versions

Only the latest release gets fixes.
