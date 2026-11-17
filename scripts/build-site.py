#!/usr/bin/env python3
"""Generates the static site in site/ from site-src/release.json. Run: python3 scripts/build-site.py"""
import json, os, shutil, html
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = json.load(open(os.path.join(ROOT, 'site-src/release.json')))
OUT = os.path.join(ROOT, 'site'); SITE = R['site']
V = R['version']; REPO = R['repo']
DMG = f"https://github.com/{REPO}/releases/download/v{V}/{R['file']}"
REL = f"https://github.com/{REPO}/releases/tag/v{V}"
SRC = f"https://github.com/{REPO}"
shutil.rmtree(OUT, ignore_errors=True)
for sub in ['install', 'privacy']: os.makedirs(os.path.join(OUT, sub), exist_ok=True)
for f in ['favicon.png', 'apple-touch-icon.png', 'og.png', 'app.png', 'icon-192.png']:
    s = os.path.join(ROOT, 'site-src', f)
    if os.path.exists(s): shutil.copy(s, os.path.join(OUT, f))

CSS = """
:root{--bg:#f7f4ec;--ink:#12261b;--mute:#4d5f54;--green:#0e3b25;--sage:#8fbc84;--line:#dcd6c4;--card:#fffdf7;--warn:#8a4b00}
*{box-sizing:border-box}html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--ink);font:17px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif}
a{color:var(--green)}a:focus-visible,button:focus-visible{outline:3px solid #2f7d4f;outline-offset:3px;border-radius:6px}
.skip{position:absolute;left:-999px}.skip:focus{left:12px;top:12px;background:#fff;padding:8px 12px;z-index:9}
header.top{display:flex;align-items:center;justify-content:space-between;gap:12px;max-width:1080px;margin:0 auto;padding:16px 20px}
.brand{display:flex;align-items:center;gap:10px;font-weight:700;color:var(--ink);text-decoration:none;font-size:19px}
.brand img{width:34px;height:34px;border-radius:8px}
nav.links{display:flex;gap:18px;align-items:center}nav.links a{color:var(--mute);text-decoration:none;font-size:15px}
.btn{display:inline-flex;align-items:center;gap:8px;background:var(--green);color:#fff!important;text-decoration:none;font-weight:650;padding:13px 22px;border-radius:12px;border:0;font-size:17px}
.btn:hover{background:#16543a}.btn.sm{padding:9px 16px;font-size:15px}
.btn.ghost{background:transparent;color:var(--green)!important;border:1.5px solid var(--green)}
main{max-width:1080px;margin:0 auto;padding:0 20px}
.hero{display:grid;grid-template-columns:1.05fr .95fr;gap:40px;align-items:center;padding:36px 0 56px}
h1{font:600 clamp(34px,5.4vw,58px)/1.07 ui-serif,Georgia,"Times New Roman",serif;margin:0 0 18px;letter-spacing:-.01em}
h1 em{color:#2f7d4f}
h2{font:600 clamp(26px,3.6vw,36px)/1.15 ui-serif,Georgia,serif;margin:0 0 14px}h3{margin:0 0 6px;font-size:18px}
.lede{font-size:20px;color:var(--mute);margin:0 0 24px;max-width:34em}
.cta{display:flex;flex-wrap:wrap;gap:12px;align-items:center}.fine{font-size:14px;color:var(--mute);margin-top:12px}
.shot{max-width:460px;justify-self:center;background:var(--card);border:1px solid var(--line);border-radius:16px;padding:10px;box-shadow:0 18px 40px -22px rgba(14,59,37,.45)}
.shot img{display:block;width:100%;height:auto;border-radius:10px}.shot figcaption{font-size:13px;color:var(--mute);padding:8px 6px 2px}
section{padding:44px 0;border-top:1px solid var(--line)}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:16px;margin-top:20px}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:20px}.card p{margin:0;color:var(--mute);font-size:16px}
ol.steps{counter-reset:s;list-style:none;padding:0;margin:20px 0 0;display:grid;gap:14px}
ol.steps li{counter-increment:s;background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px 18px 16px 62px;position:relative}
ol.steps li::before{content:counter(s);position:absolute;left:18px;top:14px;width:30px;height:30px;border-radius:50%;background:var(--green);color:#fff;display:grid;place-items:center;font-weight:700;font-size:15px}
.note{background:#fff7e6;border:1px solid #ecd6a2;border-radius:12px;padding:14px 16px;color:var(--warn);font-size:15.5px}
.ok{background:#eef7ee;border:1px solid #bcd9bc;border-radius:12px;padding:14px 16px;font-size:15.5px}
table{border-collapse:collapse;width:100%;font-size:15.5px;background:var(--card);border:1px solid var(--line);border-radius:12px;overflow:hidden}
th,td{text-align:left;padding:10px 14px;border-bottom:1px solid var(--line);vertical-align:top}th{background:#efe9d8}
details{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px 18px;margin:10px 0}summary{cursor:pointer;font-weight:650}
details p{margin:10px 0 0;color:var(--mute)}code,kbd{background:#ece6d4;border-radius:6px;padding:2px 6px;font:14.5px ui-monospace,Menlo,monospace;word-break:break-all}
footer{border-top:1px solid var(--line);margin-top:30px;padding:28px 20px;color:var(--mute);font-size:14.5px;max-width:1080px;margin-inline:auto;display:flex;flex-wrap:wrap;gap:8px 22px;justify-content:space-between}
#notmac{display:none}
@media(max-width:820px){.hero{grid-template-columns:1fr}nav.links a.hide-s{display:none}}
@media(prefers-reduced-motion:no-preference){.btn{transition:background .15s}}
"""

def page(path, title, desc, body, schema=None, noindex=False, canonical=None):
    url = SITE + canonical if canonical is not None else SITE + path
    ld = f'<script type="application/ld+json">{json.dumps(schema)}</script>' if schema else ''
    robots = '<meta name="robots" content="noindex">' if noindex else ''
    out = f"""<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)}</title><meta name="description" content="{html.escape(desc)}">{robots}
<link rel="canonical" href="{url}"><link rel="icon" href="/favicon.png" type="image/png"><link rel="apple-touch-icon" href="/apple-touch-icon.png">
<meta property="og:type" content="website"><meta property="og:site_name" content="HeyHumanly"><meta property="og:title" content="{html.escape(title)}">
<meta property="og:description" content="{html.escape(desc)}"><meta property="og:url" content="{url}"><meta property="og:image" content="{SITE}/og.png">
<meta name="twitter:card" content="summary_large_image"><meta name="theme-color" content="#0e3b25">
<style>{CSS}</style>{ld}</head><body><a class="skip" href="#main">Skip to content</a>
<header class="top"><a class="brand" href="/"><img src="/favicon.png" alt="" width="34" height="34">HeyHumanly</a>
<nav class="links" aria-label="Main"><a class="hide-s" href="/#how">How it works</a><a class="hide-s" href="/#setup">Install</a><a class="hide-s" href="/#faq">FAQ</a><a class="hide-s" href="{SRC}">View source</a><a class="btn sm dl" href="{DMG}" data-dl>Download for Mac</a></nav></header>
<main id="main">{body}</main>
<footer><span>HeyHumanly {V} · MIT License · Free and open source</span><span><a href="{SRC}">Source</a> · <a href="{REL}">Release notes &amp; checksum</a> · <a href="/privacy/">Privacy</a> · <a href="{SRC}/issues">Report a bug</a></span></footer>
<script>
(function(){{var mac=/Mac/i.test(navigator.platform||navigator.userAgent);var n=document.getElementById('notmac');if(n&&!mac)n.style.display='block';
document.querySelectorAll('[data-dl]').forEach(function(a){{a.addEventListener('click',function(){{try{{if(location.pathname==='/install/'||sessionStorage.getItem('hhgo'))return;sessionStorage.setItem('hhgo','1');
setTimeout(function(){{location.href='/install/?started=1'}},900)}}catch(e){{}}}})}})}})();
</script></body></html>"""
    p = os.path.join(OUT, path.strip('/'), 'index.html') if path.endswith('/') and path != '/' else (os.path.join(OUT, path.strip('/')) if path != '/' else os.path.join(OUT, 'index.html'))
    os.makedirs(os.path.dirname(p), exist_ok=True); open(p, 'w').write(out)

dl = f'<a class="btn dl" href="{DMG}" data-dl>Download for Mac</a>'
hero = f"""
<div class="hero"><div>
<h1>Get better at writing, <em>not just corrected</em>.</h1>
<p class="lede">HeyHumanly is a free Mac app that watches what you type, marks real mistakes, and teaches you the rule so you stop repeating them. The AI model runs on your Mac.</p>
<div class="cta">{dl}<a class="btn ghost" href="{SRC}">View source</a></div>
<p class="fine">Version {V} · macOS 14 or later · {R['size_mb']} MB · Free, MIT license · No account</p>
<p class="note" id="notmac" role="note">HeyHumanly is for Mac only. You can read about it here, and download it later from a Mac.</p>
</div>
<figure class="shot"><img src="/app.png" width="607" height="683" alt="HeyHumanly's Teach Me window showing a sentence with a mistake underlined and the rule explained"><figcaption>The real app, running on a Mac with a local model.</figcaption></figure></div>"""

how = """
<section id="how"><h2>What it does</h2><p class="lede">You write in Slack, Safari or any text box. HeyHumanly helps after you stop typing.</p>
<div class="grid">
<div class="card"><h3>Marks mistakes in place</h3><p>After a short pause, real mistakes get a red wavy underline and wording ideas a dashed one. A small dot shows how many.</p></div>
<div class="card"><h3>Teaches, not just fixes</h3><p>Click the dot, pick the better version, read the rule in one line, then practise it on a new sentence. Or press <kbd>⌃⌥↩</kbd> to just fix everything.</p></div>
<div class="card"><h3>Tone and translation</h3><p>Rewrite a message shorter, warmer, clearer or more professional, or translate it. You see the change before it is pasted.</p></div>
<div class="card"><h3>Keeps your progress</h3><p>See the mistakes you make most and review short cards made from your own sentences.</p></div>
</div></section>"""

setup = f"""
<section id="setup"><h2>Install in four steps</h2>
<ol class="steps">
<li><h3>Download and open the DMG</h3><p>{dl.replace('btn dl','btn sm dl')} Open <code>{R['file']}</code> from your Downloads folder.</p></li>
<li><h3>Drag HeyHumanly into Applications</h3><p>In the window that opens, drag the leaf icon onto the Applications folder. Then open HeyHumanly from Applications.</p></li>
<li><h3>Set up the local model (once)</h3><p>HeyHumanly uses <a href="https://ollama.com">Ollama</a>, a free app that runs the model on your Mac. The first-run tour shows a <b>Get Ollama</b> button, then a <b>Download</b> button for the model with a progress bar. The model is about 4.7 GB on a 16 GB Mac (1.9 GB on smaller Macs).</p></li>
<li><h3>Allow Accessibility, then try it</h3><p>macOS asks before any app can read a text box. Allow HeyHumanly under <b>System Settings → Privacy &amp; Security → Accessibility</b>. Then type a sentence with a mistake in the coach window or any app, and pause.</p></li>
</ol>
<p class="note" style="margin-top:18px"><b>About the first open.</b> Version {V} is not yet notarized by Apple, so macOS may say it cannot check the app for malicious software. Details and the safe way to open it are on the <a href="/install/#gatekeeper">install help page</a>. You can compare the file with the checksum on the <a href="{REL}">release page</a>, or build it yourself from source.</p>
<h3 style="margin-top:28px">Requirements</h3>
<table><tr><th>macOS</th><td>14 (Sonoma) or later. Tested here on macOS 27.</td></tr>
<tr><th>Mac</th><td>Apple silicon (M1 or later): tested. Intel: the download includes an Intel build, but it has not been tested on an Intel Mac yet.</td></tr>
<tr><th>Memory</th><td>16 GB recommended for the 7B model. 8 GB Macs should use the smaller 3B model; it misses more mistakes.</td></tr>
<tr><th>Disk</th><td>About 5 GB free for the model plus the app.</td></tr>
<tr><th>Internet</th><td>Only for the one-time downloads of Ollama and the model.</td></tr></table></section>"""

privacy = f"""
<section id="privacy"><h2>Where your writing goes</h2>
<div class="ok"><b>Your text is checked by a model on your Mac.</b> HeyHumanly has no account, analytics or tracking, and sends your text only to the Ollama address in its Settings, which is <code>localhost</code> (this Mac) by default.</div>
<div class="grid">
<div class="card"><h3>What it reads</h3><p>Only the one text box you are typing in, after you pause. Never password fields, password managers, terminals or code editors.</p></div>
<div class="card"><h3>What it stores</h3><p>Sessions, review cards, your dictionary and settings stay in this app's preferences on your Mac. You can clear them in Settings.</p></div>
<div class="card"><h3>What still uses the internet</h3><p>Downloading Ollama and the model (done by Ollama and your browser, not by HeyHumanly), and loading this website. HeyHumanly does not check for updates yet.</p></div>
</div><p class="fine">Read the full <a href="/privacy/">privacy page</a>. If you point HeyHumanly at another computer in Settings, it warns you, because then your text leaves this Mac.</p></section>"""

limits = """
<section id="limits"><h2>Honest limits</h2><ul>
<li>It works well in Slack, Safari and TextEdit, where it was tested. Chrome, Mail, WhatsApp and other apps are not fully tested.</li>
<li>In Slack it shows the dot but cannot underline words, because Slack does not share word positions with other apps.</li>
<li>Local models are weaker than the biggest cloud models. The 3B model misses some grammar, and Hindi translation is unreliable.</li>
<li>Explanations for long rewrites can take 5 to 10 seconds.</li>
<li>Version 0.1.0 is early. There is no automatic update yet: download a new version from this page.</li></ul></section>"""

faqs = [
 ("Is HeyHumanly really free?", "Yes. The app is MIT-licensed and free to use. The only costs are your own disk space and the time to download the model. There is no account or subscription."),
 ("Does it work offline?", "After Ollama and the model are downloaded, the coach runs on your Mac without internet. Downloading them needs internet once."),
 ("Do I need Ollama?", "Yes. HeyHumanly asks Ollama to run the model. The first-run tour links to the Ollama download and then downloads the model for you with a progress bar. Already have Ollama? HeyHumanly finds it automatically."),
 ("Which model does it use?", "On a Mac with 12 GB of memory or more it uses Qwen 2.5 7B (Apache-2.0 license, about 4.7 GB). On smaller Macs it uses Qwen 2.5 3B (about 1.9 GB), which has its own Qwen license. You can pick any installed model in Settings."),
 ("Why does it need Accessibility permission?", "macOS only lets an app read a text box in another app if you allow it. HeyHumanly uses it to read the one box you are typing in, and to paste a fix you accepted. Without it, the coach window still works with text you type or paste into it."),
 ("macOS says it cannot verify the app. What do I do?", "That is expected for version 0.1.0, which is not notarized by Apple. See the install help page for the steps, and verify the checksum first."),
 ("Is it a Grammarly alternative?", "It does a similar job of marking mistakes, but its main aim is teaching: it explains the rule and has you practise it, and it runs on a local model instead of a cloud service."),
 ("Can I contribute or report a bug?", f"Yes. The code is on <a href='{SRC}'>GitHub</a>. Open an issue for bugs. Do not paste private text into public issues."),
]
faq = '<section id="faq"><h2>Questions</h2>' + ''.join(f'<details><summary>{q}</summary><p>{a}</p></details>' for q, a in faqs) + '</section>'
final = f'<section style="text-align:center"><h2>Try it on your next message</h2><div class="cta" style="justify-content:center">{dl}<a class="btn ghost" href="{SRC}">View source</a></div></section>'

schema = {"@context": "https://schema.org", "@type": "SoftwareApplication", "name": "HeyHumanly", "operatingSystem": "macOS 14 or later",
  "applicationCategory": "ProductivityApplication", "softwareVersion": V, "downloadUrl": DMG, "license": "https://opensource.org/license/mit",
  "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"}, "url": SITE + "/",
  "description": "Free, open-source Mac writing coach that marks mistakes and teaches the rule, using a local AI model."}
page('/', 'HeyHumanly: free Mac writing coach that teaches, using a local model',
     'HeyHumanly is a free, open-source Mac app that marks writing mistakes as you type, explains the rule, and runs on a local AI model with no account.',
     hero + how + setup + privacy + limits + faq + final, schema)

inst = f"""
<section style="border:0"><h1 style="font-size:clamp(30px,4.5vw,44px)">Install HeyHumanly</h1>
<p class="ok" id="started" style="display:none">Your download should have started. Look in your Downloads folder for <code>{R['file']}</code>. We cannot tell if it finished, so use the link below if it did not.</p>
<p><a class="btn dl" href="{DMG}" data-dl>Download again</a> &nbsp; <span class="fine">{R['file']} · {R['size_mb']} MB · SHA-256 <code>{R['sha256']}</code></span></p>
<ol class="steps">
<li><h3>Open the DMG</h3><p>Double-click <code>{R['file']}</code>. If macOS shows a warning here, see below.</p></li>
<li><h3>Drag to Applications</h3><p>Drag HeyHumanly onto the Applications folder in the window. Eject the disk image afterwards.</p></li>
<li><h3>Open HeyHumanly from Applications</h3><p>A short tour opens. It checks for Ollama and the model, and offers buttons to install each.</p></li>
<li><h3>Allow Accessibility</h3><p>Open <b>System Settings → Privacy &amp; Security → Accessibility</b> and switch HeyHumanly on. If you said no, you can turn it on later in the same place; until then the coach window still works with pasted text.</p></li>
<li><h3>Try your first sentence</h3><p>In the tour choose <b>Try an example</b>, or type "Please send me that thung when you have time." in the coach window and press Teach Me. You are ready when you see the corrected sentence and the rule.</p></li></ol>
<h2 id="gatekeeper" style="margin-top:34px">If macOS says it cannot check the app</h2>
<p class="note">Version {V} is signed only with an ad-hoc signature and is <b>not notarized</b> by Apple, so macOS may block the first open. This is a known limit of this release, not something to ignore.</p>
<p>Check the file first: in Terminal run <code>shasum -a 256 ~/Downloads/{R['file']}</code> and compare it to <code>{R['sha256']}</code>. If it matches and you want to continue, try to open HeyHumanly once, then open <b>System Settings → Privacy &amp; Security</b>, scroll to Security, and choose <b>Open Anyway</b> next to HeyHumanly. You can also read or build the <a href="{SRC}">source code</a> yourself. Do not turn off Gatekeeper or other security settings.</p>
<h2 style="margin-top:34px">Problems</h2>
<details><summary>The download did not start</summary><p>Use the <a href="{DMG}">direct link</a>. If your browser blocks it, copy the link into a new tab. The file is hosted on GitHub Releases.</p></details>
<details><summary>"Ollama isn't running" in the app</summary><p>Open the Ollama app from Applications, or press <b>Start Ollama</b> in HeyHumanly. HeyHumanly rechecks every few seconds.</p></details>
<details><summary>The model download stopped</summary><p>Press Download again; partial downloads resume. Make sure you have about 5 GB free and a working connection. You can also run <code>ollama pull qwen2.5:7b</code> in Terminal.</p></details>
<details><summary>HeyHumanly cannot read text in other apps</summary><p>Accessibility is probably off. After installing a new version, remove HeyHumanly from the Accessibility list with the minus button, then add it again.</p></details>
<details><summary>Which Mac do I have?</summary><p>Choose the Apple menu → About This Mac. This one download contains both Apple silicon and Intel builds, so you do not need to choose. Apple silicon is tested; Intel is not yet.</p></details>
<p class="fine">Requirements: macOS 14 or later, about 5 GB free disk, 16 GB memory recommended. <a href="/">Back to the home page</a>.</p></section>
<script>if(location.search.indexOf('started=1')>-1)document.getElementById('started').style.display='block';</script>"""
page('/install/', 'Install HeyHumanly on Mac: steps, requirements and help',
     'Step-by-step help to install HeyHumanly on a Mac: open the DMG, drag to Applications, set up the local model, allow Accessibility and try your first sentence.', inst)

priv = f"""
<section style="border:0"><h1 style="font-size:clamp(30px,4.5vw,44px)">Privacy</h1>
<p>This is a plain list of what HeyHumanly does with your writing. It comes from the app's source code, which you can read at <a href="{SRC}">{SRC.replace('https://','')}</a>.</p>
<h2>In the app</h2><ul>
<li><b>Read:</b> the single text box you are typing in, after you pause, and text you select when you press the shortcut. Never password fields, and never apps on the "Never read" list (password managers, terminals and code editors by default).</li>
<li><b>Sent:</b> to the Ollama address in Settings, <code>localhost</code> by default, meaning this Mac. Checking as you type only runs while that address is on this Mac.</li>
<li><b>Stored:</b> a session is saved only when you accept a fix, start a lesson or use the coach window. It is kept in the app's preferences on your Mac. The log records timings, not your text.</li>
<li><b>Network:</b> HeyHumanly makes no calls other than to that Ollama address. It has no analytics, accounts, tracking or automatic update check.</li>
<li><b>Remove:</b> Settings → Privacy &amp; data → Clear history.</li></ul>
<h2>Outside the app</h2><ul>
<li><b>Ollama and the model:</b> downloaded by Ollama from its model library. Ollama's own privacy terms apply to that download.</li>
<li><b>This website:</b> is hosted on Cloudflare, which keeps standard server logs. The site sets no cookies and loads no analytics or third-party scripts.</li>
<li><b>The DMG:</b> is hosted on GitHub Releases, which GitHub operates.</li></ul>
<h2>Report a security problem</h2><p>Open a private advisory on <a href="{SRC}/security/advisories/new">GitHub</a>. Please do not post private text in public issues.</p></section>"""
page('/privacy/', 'HeyHumanly privacy: what it reads, stores and sends',
     'What HeyHumanly reads, stores and sends, based on the source code: local model by default, no account, no analytics, no tracking.', priv)

nf = '<section style="border:0;text-align:center;padding:90px 0"><h1>Page not found</h1><p class="lede" style="margin-inline:auto">That page does not exist.</p><a class="btn" href="/">Go to the home page</a></section>'
page('/404.html', 'Page not found · HeyHumanly', 'Page not found.', nf, noindex=True, canonical='/')

open(os.path.join(OUT, 'robots.txt'), 'w').write(f"User-agent: *\nAllow: /\n\nSitemap: {SITE}/sitemap.xml\n")
urls = ['/', '/install/', '/privacy/']
open(os.path.join(OUT, 'sitemap.xml'), 'w').write('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + ''.join(f'<url><loc>{SITE}{u}</loc><lastmod>{R["date"]}</lastmod></url>\n' for u in urls) + '</urlset>\n')
# Staging hosts stay out of search; production is not affected.
open(os.path.join(OUT, '_headers'), 'w').write("/*\n  X-Content-Type-Options: nosniff\n  Referrer-Policy: strict-origin-when-cross-origin\n  Content-Security-Policy: default-src 'self'; img-src 'self' data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'self'; form-action 'none'\n")
print('site built', V)
