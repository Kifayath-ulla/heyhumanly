# Decision: first-run coaching without setup (2026-11-21)

Goal: download → open → coach immediately → free allowance → optional unlimited offline coaching, with no terminal and no API key.

Legend: **[V]** verified in official docs or measured here. **[A]** assumption, not yet verified.

## Options

| Option | Who gets it | Cost / quota | Data handling | Effort | Verdict |
|---|---|---|---|---|---|
| Apple on-device model (Foundation Models) | macOS 26+ on Apple Intelligence Macs, enabled, supported region [V] | Free, unlimited, offline [V] | Stays on the Mac [V] | Small: one Swift provider behind `#if canImport(FoundationModels)` | **Use first when available** |
| Apple Private Cloud Compute for developers | App Store apps in the Small Business Program, under 2M downloads, with the PCC entitlement [V] | Free only while eligible [V] | Apple PCC | — | **Rejected**: HeyHumanly ships as a DMG outside the App Store and needs Accessibility, so it is not eligible |
| Hosted allowance on Cloudflare Workers AI, in the existing Worker | Every Mac, including macOS 14/15, Intel and Apple Intelligence off | 10,000 neurons/day free per account, reset 00:00 UTC [V]. On Workers Free, requests fail once used up and nothing is billed [V] | Zero data retention, no training on content [V]. Metadata (model, time, sizes, status) may be kept [V] | Medium: one route, a Durable Object counter, no new vendor | **Use as the allowance** for Macs without Apple's model |
| Gemini API free tier | — | Free | Unpaid content can be used to improve Google products and read by human reviewers; unpaid use not offered in EEA/UK/CH [V] | — | **Rejected** for privacy |
| Groq free tier | — | Free, org-level limits that change [V] | No retention by default [V] | Medium + a new vendor account and secret | **Deferred**: only if Workers AI quality is not good enough |
| In-app offline runtime (Ollama's signed standalone build, managed by HeyHumanly) | Every Apple Silicon/Intel Mac with ~2–5 GB free | Free, unlimited [V] | Stays on the Mac [V] | Medium: download 179 MB runtime [V], check SHA-256 [V], run it on a private port, pull a model | **Use for "unlimited offline"** |
| Embedded llama.cpp (XCFramework) | Same | Free | Stays on the Mac | Large: new inference code, prompt templates, model file hosting | **Deferred**: more code for the same result |
| Connect existing Ollama | Users who already run Ollama | Free | Local | Already built | **Keep**, moved to Advanced |
| Chrome built-in AI (Prompt API, Gemini Nano) | Chrome 138+ extensions on Windows 10/11, macOS 13+, Linux, Chromebook Plus; 22 GB free disk; GPU >4 GB VRAM or 16 GB RAM + 4 cores [V] | Free, unlimited after a one-time model download [V] | Local after download; no data to Google [V] | Small: one provider in `core.js` | **Use first in the extension** |
| Extension → hosted allowance | All Chrome users | Shares the same 10,000-neuron pool | As above | Small, but adds a host permission and a second abuse surface | **Deferred** until store listing and demand are known |
| Extension → Mac app companion | Mac users with both | Free | Local | Large: native messaging host, install step | **Deferred** |

## Recommendation (simplest that meets the goal)

Mac, in this order, picked automatically on first launch:
1. Apple's on-device model if `SystemLanguageModel.default.availability == .available`. No download, no allowance, works offline.
2. Otherwise the online allowance, only after the user taps **Try online coaching** on a consent card that names Cloudflare Workers AI and says the selected text is sent there.
3. **Enable unlimited offline coaching** downloads Ollama's standalone runtime (pinned v0.40.17, SHA-256 checked) into `~/Library/Application Support/HeyHumanly/Runtime`, runs it on `127.0.0.1:11435`, then downloads the recommended model with progress, cancel and retry.
4. An Ollama already on `localhost:11434` with a writing model is detected and offered as **Use my Ollama**.
Model names, endpoints and keys live in Settings → Advanced.

Chrome extension: Chrome's built-in model when available, otherwise local Ollama (current setup page). It works on its own and does not need the Mac app. It stays labeled **Developer preview** until a Chrome Web Store listing is approved.

## Allowance

- **Daily, not one-time** [decision]: the provider pool resets daily [V], and a daily limit lets a user keep trying while the offline download runs.
- **10 coaching requests per install per day**, 3 left triggers the "few sessions left" banner [decision].
- Global budget: the Worker stops at **8,000 neurons/day** (80% of the free 10,000) so the pool is never exceeded [decision]. Neurons are estimated from token counts at the model's published price.
- Measured request size here: prompt avg 403 tokens (max 439), output avg 30 (max 63) over the 17 eval cases [V]. Assuming ~600 in / 150 out per real request [A], `@cf/google/gemma-4-26b-a4b-it` ($0.10 / $0.30 per M tokens [V]) costs ~9.5 neurons, so 8,000 neurons ≈ **840 requests/day ≈ 84 users at the full 10** [A]. If launch demand is higher, the options are a paid budget (~$0.0001 per request [A], needs your approval) or a smaller allowance.
- Failed, cancelled or provider-error requests are refunded, not counted.
- Abuse limits without signup: per-install ID limit, per-IP limit (IP hashed with a daily secret salt, never stored raw), 4,000-character input cap, server-built prompt (the endpoint is not a general chatbot), output token cap.

## Privacy

- Offline modes (Apple on-device, offline runtime, own Ollama, Chrome built-in): "your writing never leaves your computer".
- Online mode: selected text and the chosen goal are sent to heyhumanly.com and processed by Cloudflare Workers AI. Not logged or stored by HeyHumanly. Cloudflare states zero data retention and no training [V]; it may keep request metadata [V].
- The Worker never logs request bodies. Observability/logpush for the Worker stays off.

## External steps you must do (not done by me)

1. Cloudflare: add the Workers AI binding and the Durable Object to the production Worker, set the `IP_SALT` secret, and deploy. Keep the account on Workers Free so the cap can't bill.
2. Apple Developer Program ($99/yr) for Developer ID signing and notarization; without it Gatekeeper blocks the first open.
3. Chrome Web Store developer account and listing approval before showing **Add to Chrome**.
4. A GitHub release with the new DMG.
