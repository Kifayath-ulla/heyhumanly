#!/usr/bin/env python3
"""Generates the static site in site/ from site-src/release.json. Run: python3 scripts/build-site.py"""
import json, os, shutil, html
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = json.load(open(os.path.join(ROOT, 'site-src/release.json')))
KEY = 'a3f9c2d17b8e4a60b5d1c9e2f7a40831'
OUT = os.path.join(ROOT, 'site'); SITE = R['site']
V = R['version']; REPO = R['repo']
DMG = f"https://github.com/{REPO}/releases/download/v{V}/{R['file']}"
REL = f"https://github.com/{REPO}/releases/tag/v{V}"
SRC = f"https://github.com/{REPO}"
shutil.rmtree(OUT, ignore_errors=True)
for sub in ['install', 'privacy', 'writing-habits', 'local-ai-writing-coach-mac']: os.makedirs(os.path.join(OUT, sub), exist_ok=True)
for f in ['favicon.png', 'apple-touch-icon.png', 'og.png', 'app.png', 'icon-192.png']:
    s = os.path.join(ROOT, 'site-src', f)
    if os.path.exists(s): shutil.copy(s, os.path.join(OUT, f))

CSS = """
:root{color-scheme:light;--bg:#ffffff;--ink:#131316;--mute:#5b5c64;--green:#131316;--btnink:#ffffff;--btnhov:#2e2f35;--deep:#131316;--sage:#c4c6cc;--cream:#f2f2f3;--line:#e6e6e3;--card:#f7f7f5;--card2:#efefed;--win:#ffffff;--hdr:rgba(255,255,255,.86);--warn:#6b4a00;--warnbg:#f7f3e6;--warnline:#ecd6a2}
:root[data-theme=dark]{color-scheme:dark;--bg:#0e0e10;--ink:#f2f2f3;--mute:#9b9da6;--green:#f2f2f3;--btnink:#131316;--btnhov:#d9dadd;--deep:#17181b;--sage:#c4c6cc;--line:#26272c;--card:#151618;--card2:#1e1f23;--win:#17181b;--hdr:rgba(14,14,16,.86);--warn:#e8c878;--warnbg:#241f12;--warnline:#4a3d1c}
*{box-sizing:border-box}html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--ink);font:17px/1.6 "SF Pro Display",-apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif;-webkit-font-smoothing:antialiased}
a{color:var(--green)}a:focus-visible,button:focus-visible,summary:focus-visible{outline:3px solid #4a4a4a;outline-offset:3px;border-radius:8px}
.skip{position:absolute;left:-999px}.skip:focus{left:12px;top:12px;background:#fff;padding:8px 12px;z-index:99}
.bar{background:var(--deep);color:var(--cream);text-align:center;font-size:14.5px;padding:9px 16px}.bar a{color:var(--sage);font-weight:600}
header.top{position:sticky;top:0;z-index:20;background:var(--hdr);backdrop-filter:blur(12px);border-bottom:1px solid var(--line)}
.nav{display:flex;align-items:center;justify-content:space-between;gap:12px;max-width:1160px;margin:0 auto;padding:14px 24px}
.brand{display:flex;align-items:center;gap:10px;font-weight:750;color:var(--ink);text-decoration:none;font-size:20px;letter-spacing:-.01em}
.brand img{width:36px;height:36px;border-radius:9px}
nav.links{display:flex;gap:26px;align-items:center}nav.links a{color:var(--mute);text-decoration:none;font-size:15.5px;font-weight:500}nav.links a:hover{color:var(--ink)}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;background:var(--green);color:var(--btnink)!important;text-decoration:none;font-weight:650;padding:15px 28px;border-radius:999px;border:0;font-size:17px;cursor:pointer;box-shadow:0 8px 22px -12px rgba(0,0,0,.6)}
.btn:hover{background:var(--btnhov)}.btn.sm{padding:10px 20px;font-size:15px;box-shadow:none}
.btn.ghost{background:transparent;color:var(--green)!important;border:1.5px solid var(--line);box-shadow:none}.btn.ghost:hover{background:var(--card2)}
.btn.cream{background:#f2f2f3;color:#131316!important}.btn.cream:hover{background:#fff}
main{overflow:hidden}.wrap{max-width:1160px;margin:0 auto;padding:0 24px}
.hero{text-align:center;padding:56px 0 8px}
.eyebrow{display:inline-block;font-size:13px;letter-spacing:.14em;text-transform:uppercase;font-weight:700;color:var(--mute);margin-bottom:16px}
h1{font-weight:750;font-size:clamp(40px,7.2vw,84px);line-height:1.02;letter-spacing:-.035em;margin:0 auto 22px;max-width:15em}
h1 em{font-style:normal;background:linear-gradient(100deg,var(--mute),var(--ink));-webkit-background-clip:text;background-clip:text;color:transparent}
h2{font-weight:750;font-size:clamp(30px,4.6vw,52px);line-height:1.06;letter-spacing:-.03em;margin:0 0 14px}h3{margin:0 0 6px;font-size:19px;letter-spacing:-.01em}
.lede{font-size:clamp(18px,2vw,22px);color:var(--mute);margin:0 auto 30px;max-width:36em}
.cta{display:flex;flex-wrap:wrap;gap:12px;align-items:center;justify-content:center}.fine{font-size:14.5px;color:var(--mute);margin-top:16px}
.stage{margin:44px auto 0;max-width:980px;border-radius:32px;padding:clamp(18px,4vw,44px);background:radial-gradient(120% 120% at 20% 0%,#2b2b2b 0%,#0a0a0a 45%,#0a0a0a 100%);box-shadow:0 40px 80px -40px rgba(0,0,0,.45)}
.win{background:var(--win);border-radius:18px;text-align:left;box-shadow:0 20px 50px -20px rgba(0,0,0,.55);overflow:hidden}
.win .top{display:flex;align-items:center;gap:7px;padding:11px 14px;background:var(--card2);border-bottom:1px solid var(--line);font-size:13px;color:var(--mute)}
.win .top i{width:11px;height:11px;border-radius:50%;background:var(--line);display:block}.win .top span{margin-left:8px}
.win .body{padding:22px 24px 18px;min-height:150px;font-size:clamp(17px,2.2vw,21px);line-height:1.55;position:relative}
.u-m{background:#ffe3e0;color:#9b2218;border-radius:4px;padding:0 3px}.lab{font-size:11px;letter-spacing:.14em;font-weight:700;color:#8a8a8a;margin-bottom:6px}.win .body{min-height:0}.better{border-top:1px solid var(--line);opacity:0;transition:.4s}.better.on{opacity:1}.better #demo-new{font-weight:550}.rc.nx{background:var(--green);border-color:var(--green)}.rc.nx small{color:var(--btnink);opacity:.85}.rc.nx .tag{background:var(--btnink);color:var(--green)}
.fixed mark{background:var(--card2);color:var(--ink);border-radius:5px;padding:0 3px}
.dot{position:absolute;right:16px;bottom:14px;background:var(--green);color:var(--btnink);border-radius:999px;min-width:30px;height:30px;display:grid;place-items:center;font-size:14px;font-weight:700;opacity:0;transform:scale(.6);transition:.25s}
.dot.on{opacity:1;transform:none}
.cards{display:grid;gap:8px;padding:0 24px 22px}.rc{display:grid;grid-template-columns:auto 1fr;gap:12px;align-items:start;background:var(--card2);border:1px solid var(--line);border-radius:12px;padding:10px 14px;font-size:15px;opacity:0;transform:translateY(6px);transition:.35s}
.rc.on{opacity:1;transform:none}.rc b{font-weight:650}.rc s{color:#c0392b}.rc .gd{color:#1d7a46;font-weight:650}.rc small{display:block;color:var(--mute);font-size:13.5px;line-height:1.4;margin-top:2px}
.tag{font-size:11.5px;font-weight:700;padding:2px 8px;border-radius:999px;background:#fde1de;color:#a12a22;align-self:start;margin-top:2px}.tag.t{background:#dfe9fb;color:#264f9c}.tag.g{background:#e3dcf7;color:#4a3a9a}
section{padding:72px 0}#how{padding-top:64px}#setup{padding-top:24px}#privacy{padding:48px 0 24px}#limits{padding:24px 0 48px}#faq{padding:48px 0 56px}.center{text-align:center}.center .lede{margin-left:auto;margin-right:auto}
.proof{display:flex;flex-wrap:wrap;gap:12px 34px;justify-content:center;color:var(--mute);font-size:15.5px;padding:34px 0 0}.proof span::before{content:"✓ ";color:var(--mute);font-weight:800}
.split{display:grid;grid-template-columns:1fr 1fr;gap:56px;align-items:center}
.panel{background:var(--card);border:1px solid var(--line);border-radius:28px;padding:30px;box-shadow:0 24px 50px -34px rgba(0,0,0,.5)}
.tabs{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:18px}.tabs button{border:1.5px solid var(--line);background:var(--bg);border-radius:999px;padding:8px 16px;font:600 15px inherit;color:var(--mute);cursor:pointer}
.tabs button[aria-selected=true]{background:var(--green);border-color:var(--green);color:var(--btnink)}
.out{font-size:19px;line-height:1.55;min-height:132px}.orig{color:var(--mute);font-size:15px;margin-bottom:12px;padding-bottom:12px;border-bottom:1px dashed var(--line)}
.steps3{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;margin-top:44px;text-align:left}
.step{background:var(--card);border:1px solid var(--line);border-radius:28px;padding:30px}.step .n{width:42px;height:42px;border-radius:50%;background:var(--green);color:var(--btnink);display:grid;place-items:center;font-weight:750;margin-bottom:18px}
.step p{margin:0;color:var(--mute);font-size:16.5px}
.bento{display:grid;grid-template-columns:repeat(6,1fr);gap:18px;margin-top:44px;text-align:left}
.tile{background:var(--card);border:1px solid var(--line);border-radius:28px;padding:30px;grid-column:span 2}.tile.w{grid-column:span 3}.tile.dark{background:var(--deep);color:#f2f2f3;border-color:var(--deep)}.tile.dark p{color:#bdbdbd}
.tile p{margin:0;color:var(--mute);font-size:16.5px}.tile h3{font-size:22px;margin-bottom:8px}
.band{background:var(--deep);color:#f2f2f3}.band .lede{color:#bdbdbd}.band h2{color:#fff}.band .eyebrow{color:var(--sage)}
ol.steps{list-style:none;padding:0;margin:26px 0 0;display:grid;gap:14px;counter-reset:s;text-align:left}
ol.steps li{counter-increment:s;background:var(--card);border:1px solid var(--line);border-radius:20px;padding:18px 20px 18px 68px;position:relative;color:var(--ink)}
ol.steps li::before{content:counter(s);position:absolute;left:20px;top:17px;width:32px;height:32px;border-radius:50%;background:var(--green);color:var(--btnink);display:grid;place-items:center;font-weight:750;font-size:15px}
ol.steps li p{margin:2px 0 0;color:var(--mute)}
.note{background:var(--warnbg);border:1px solid var(--warnline);border-radius:16px;padding:14px 18px;color:var(--warn);font-size:15.5px;text-align:left}
.ok{background:var(--card2);border:1px solid var(--line);border-radius:16px;padding:14px 18px;font-size:16px;text-align:left}
table{border-collapse:collapse;width:100%;font-size:16px;background:var(--card);border:1px solid var(--line);border-radius:18px;overflow:hidden;text-align:left}
th,td{padding:12px 16px;border-bottom:1px solid var(--line);vertical-align:top}th{background:var(--card2);width:120px}tr:last-child th,tr:last-child td{border-bottom:0}
details{background:var(--card);border:1px solid var(--line);border-radius:18px;padding:18px 22px;margin:10px 0;text-align:left}summary{cursor:pointer;font-weight:650;font-size:18px}
details p{margin:10px 0 0;color:var(--mute)}code,kbd{white-space:nowrap;background:var(--card2);border-radius:7px;padding:2px 7px;font:14.5px ui-monospace,Menlo,monospace;word-break:break-all}
.final{margin:16px 24px 56px;border:1px solid var(--line);border-radius:40px;background:radial-gradient(120% 140% at 80% 0%,#2b2b2b,#0a0a0a 50%,#0a0a0a);color:#f2f2f3;text-align:center;padding:clamp(44px,7vw,80px) 24px}
.final h2{color:#fff;max-width:14em;margin-inline:auto}.final .lede{color:#bdbdbd}
footer{background:var(--card);border-top:1px solid var(--line);padding:56px 0 30px;color:var(--mute);font-size:15px}
.fgrid{display:grid;grid-template-columns:1.4fr repeat(3,1fr);gap:32px}footer h4{margin:0 0 12px;color:var(--ink);font-size:15px}footer a{display:block;color:var(--mute);text-decoration:none;padding:3px 0}footer a:hover{color:var(--ink)}
.legal{margin-top:36px;padding-top:20px;border-top:1px solid var(--line);display:flex;flex-wrap:wrap;gap:8px 20px;justify-content:space-between}
#notmac{display:none;margin-top:16px}
.tg{width:38px;height:38px;border-radius:50%;border:1.5px solid var(--line);background:transparent;color:var(--ink);cursor:pointer;font-size:17px;line-height:1;display:grid;place-items:center}.tg:hover{background:var(--card2)}
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin:20px 0}.card{background:var(--card);border:1px solid var(--line);border-radius:22px;padding:24px;text-align:left}.card p{margin:0;color:var(--mute);font-size:16px}.card h3{font-size:18px}
#privacy .wrap,#limits .wrap,#setup .wrap{max-width:980px}#privacy h2,#limits h2{margin-bottom:18px}
#limits ul{list-style:none;margin:0;padding:0;display:grid;gap:10px}#limits li{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:14px 18px 14px 46px;position:relative;color:var(--mute);font-size:16.5px}#limits li::before{content:"!";position:absolute;left:16px;top:14px;width:22px;height:22px;border-radius:50%;background:var(--card2);color:var(--ink);display:grid;place-items:center;font-size:13px;font-weight:800}
.fine{margin-top:12px}
@media(max-width:860px){.split,.steps3{grid-template-columns:1fr}.bento{grid-template-columns:1fr}.tile,.tile.w{grid-column:auto}.fgrid{grid-template-columns:1fr 1fr}nav.links a.hide-s{display:none}section{padding:48px 0}.grid{grid-template-columns:1fr}}
@media(prefers-reduced-motion:reduce){*{transition:none!important}}
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
<meta name="twitter:card" content="summary_large_image"><meta name="theme-color" content="#0a0a0a">
<script>(function(){{try{{var t=localStorage.getItem("hhtheme")||(matchMedia("(prefers-color-scheme:dark)").matches?"dark":"light");document.documentElement.setAttribute("data-theme",t)}}catch(e){{}}}})()</script><style>{CSS}</style>{ld}</head><body><a class="skip" href="#main">Skip to content</a>
<div class="bar">Free and open source. Runs on your Mac. <a href="{REL}">What's new in {V}</a></div>
<header class="top"><div class="nav"><a class="brand" href="/"><img src="/favicon.png" alt="" width="36" height="36">HeyHumanly</a>
<nav class="links" aria-label="Main"><a class="hide-s" href="/#how">How it works</a><a class="hide-s" href="/#styles">Rewrites</a><a class="hide-s" href="/install/">Install</a><a class="hide-s" href="/#faq">FAQ</a><a class="hide-s" href="{SRC}">GitHub</a><button class="tg" id="tg" type="button" aria-label="Switch between light and dark theme">◐</button><a class="btn sm dl" href="{DMG}" data-dl>Download for Mac</a></nav></div></header>
<main id="main">{body}</main>
<footer><div class="wrap"><div class="fgrid"><div><a class="brand" href="/"><img src="/favicon.png" alt="" width="32" height="32">HeyHumanly</a><p style="margin:12px 0 0;max-width:22em">A free Mac writing coach that teaches the rule, with an AI model on your Mac.</p></div>
<div><h4>Product</h4><a href="/#how">How it works</a><a href="/#styles">Rewrites</a><a href="/#privacy">Privacy</a><a href="/#faq">FAQ</a><a href="/writing-habits/">Writing habits guide</a><a href="/local-ai-writing-coach-mac/">Local AI setup</a></div>
<div><h4>Get started</h4><a href="{DMG}" data-dl>Download for Mac</a><a href="/install/">Install help</a><a href="{REL}">Release notes &amp; checksum</a></div>
<div><h4>Open source</h4><a href="{SRC}">Source code</a><a href="{SRC}/issues">Report a bug</a><a href="{SRC}/blob/main/LICENSE">MIT license</a><a href="/privacy/">Privacy details</a></div></div>
<div class="legal"><span>HeyHumanly {V} · MIT License · Mac only (macOS 14+)</span><span>Models are separate downloads under their own licenses.</span></div></div></footer>
<script>
(function(){{var tg=document.getElementById('tg');tg.addEventListener('click',function(){{var r=document.documentElement,n=r.getAttribute('data-theme')==='dark'?'light':'dark';r.setAttribute('data-theme',n);try{{localStorage.setItem('hhtheme',n)}}catch(e){{}}}});var mac=/Mac/i.test(navigator.platform||navigator.userAgent);var n=document.getElementById('notmac');if(n&&!mac)n.style.display='block';
document.querySelectorAll('[data-dl]').forEach(function(a){{a.addEventListener('click',function(){{try{{if(location.pathname==='/install/'||sessionStorage.getItem('hhgo'))return;sessionStorage.setItem('hhgo','1');
setTimeout(function(){{location.href='/install/?started=1'}},900)}}catch(e){{}}}})}})}})();
</script></body></html>"""
    p = os.path.join(OUT, path.strip('/'), 'index.html') if path.endswith('/') and path != '/' else (os.path.join(OUT, path.strip('/')) if path != '/' else os.path.join(OUT, 'index.html'))
    os.makedirs(os.path.dirname(p), exist_ok=True); open(p, 'w').write(out)

dl = f'<a class="btn dl" href="{DMG}" data-dl>Download for Mac</a>'
hero = f"""
<div class="wrap hero"><span class="eyebrow">AI writing coach for Mac</span>
<h1>Say it better. <em>Learn why.</em></h1>
<p class="lede">HeyHumanly rewrites what you write or dictate so it's clearer, then shows you exactly which habits got in the way, so next time you get it right yourself.</p>
<div class="cta">{dl}<a class="btn ghost" href="{SRC}">View source</a></div>
<p class="fine">Free · macOS 14 or later · The AI runs on your Mac · Version {V}</p>
<p class="note" id="notmac" role="note">HeyHumanly is for Mac only. You can read about it here and download it later from a Mac.</p>
<div class="stage" aria-label="Animated example of HeyHumanly rephrasing a rambling message and explaining why"><div class="win"><div class="top"><i></i><i></i><i></i><span>HeyHumanly</span></div>
<div class="body"><div class="lab">YOU WROTE</div><div id="demo-text" aria-live="polite"></div></div>
<div class="body better" id="demo-better"><div class="lab">BETTER</div><div id="demo-new"></div></div>
<div class="cards" id="demo-cards">
<div class="rc"><span class="tag">Buried the point</span><div><small>Your main point doesn't appear until word 48 of 72. A reader decides whether to keep reading in the first sentence. Open with it.</small></div></div>
<div class="rc"><span class="tag">Hedging</span><div><small>You hedged 6 times (“maybe”, “kind of”, “I think”, “probably”). Each one tells the reader you don't stand behind the point.</small></div></div>
<div class="rc"><span class="tag">Filler</span><div><small>5 filler phrases in 72 words (“So basically”, “um”, “kind of”, “you know”). They add no information.</small></div></div>
<div class="rc nx"><span class="tag">Next time</span><div><small>Finish the sentence “What I need from you is…” and start with that.</small></div></div></div></div></div>
<div class="proof"><span>Explains every change</span><span>Tracks your habits over time</span><span>Runs on your Mac</span><span>No account</span></div></div>
""" + """<script>(function(){var T=document.getElementById('demo-text'),B=document.getElementById('demo-better'),N=document.getElementById('demo-new'),cs=[].slice.call(document.querySelectorAll('#demo-cards .rc'));
var raw="So basically I was thinking, um, that maybe we could kind of look at the thing about the launch, because I talked to Priya yesterday and she said, you know, the design is mostly done but there are some issues, and I think we should probably, like, maybe push the launch, but I'm not sure, so can you let me know by Friday if you think we can still ship on Monday?";
var out="Should we push the launch? Priya said the design is mostly done but there are some issues. Can you let me know by Friday if we can still ship on Monday?";
var ph=["So basically","um","maybe","kind of","the thing about the launch","you know","I think","probably","like","not sure"];
function esc(x){return x.replace(/&/g,'&amp;').replace(/</g,'&lt;')}
function mark(t){var h=esc(t);ph.forEach(function(p){h=h.replace(new RegExp('(^|[^a-z])('+p+')(?![a-z])','i'),function(m,a,b){return a+'<mark class="u-m">'+b+'</mark>'})});return h}
function reset(){T.textContent='';B.className='body better';N.textContent='';cs.forEach(function(c){c.classList.remove('on')})}
function show(){T.innerHTML=mark(raw);B.className='body better on';N.textContent=out;cs.forEach(function(c){c.classList.add('on')})}
if(matchMedia('(prefers-reduced-motion:reduce)').matches){show();return}
function w(ms){return new Promise(function(r){setTimeout(r,ms)})}
async function run(){for(;;){reset();for(var i=6;i<=raw.length;i+=6){T.textContent=raw.slice(0,i);await w(18)}T.textContent=raw;await w(700);T.innerHTML=mark(raw);await w(1100);B.className='body better on';N.textContent=out;await w(900);for(var k=0;k<cs.length;k++){cs[k].classList.add('on');await w(650)}await w(5000)}}run()})();</script>"""

how = """
<section id="how" class="center"><div class="wrap"><span class="eyebrow">How it works</span><h2>Not just rephrased. Explained.</h2>
<p class="lede">Other tools rewrite your text and leave you guessing. HeyHumanly shows you why, so you improve.</p>
<div class="steps3"><div class="step"><div class="n">1</div><h3>Paste or dictate</h3><p>Drop in a message you wrote, or something you dictated. Rambling is fine.</p></div>
<div class="step"><div class="n">2</div><h3>See it rephrased</h3><p>Get a clearer version that leads with the point, with your own filler, hedges and vague words highlighted.</p></div>
<div class="step"><div class="n">3</div><h3>Learn the habit</h3><p>Each change names the habit behind it, quotes your words and tells you what to do next time. Insights shows which habits you repeat.</p></div></div></div></section>

<section id="styles" class="band"><div class="wrap split"><div><span class="eyebrow">Rewrites</span><h2>Same message, the tone you want.</h2>
<p class="lede" style="margin-left:0">Rewrite a whole message shorter, warmer or more professional. You see the change before anything is pasted.</p>
<p class="fine" style="color:#bdbdbd">These examples were written by the app's own model on a Mac.</p></div>
<div class="panel" style="color:var(--ink)"><div class="tabs" role="tablist" aria-label="Rewrite style">
<button role="tab" aria-selected="true" data-k="fix">Just fixes</button><button role="tab" aria-selected="false" data-k="short">Shorter</button></div>
<div class="orig">You wrote: "hey richard, i have exam this sunday so i might not be available, just wanted to let u know"</div><div class="out" id="tone-out" aria-live="polite"></div></div></div></section>
<script>(function(){var o={fix:"Hey Richard, I have an exam this Sunday, so I might not be available. Just wanted to let you know.",short:"Hey Richard, I have an exam on Sunday and might not be available. Just letting you know."};
var out=document.getElementById('tone-out');out.textContent=o.fix;document.querySelectorAll('[role=tab]').forEach(function(b){b.addEventListener('click',function(){document.querySelectorAll('[role=tab]').forEach(function(x){x.setAttribute('aria-selected','false')});b.setAttribute('aria-selected','true');out.textContent=o[b.dataset.k]})})})();</script>

<section class="center"><div class="wrap"><span class="eyebrow">Built to teach</span><h2>More than a spellchecker.</h2>
<div class="bento"><div class="tile w dark"><h3>Rules, not guesses</h3><p>About 60 hand-written rules explain the mistakes people make most: subject and verb agreement, their and they're, since and for, missing articles. They are never invented by the model.</p></div>
<div class="tile w"><h3>Keeps your meaning</h3><p>A guard reverts changes that swap in a different word, alter slang, or only restyle something harmless. You see what changed.</p></div>
<div class="tile"><h3>Review cards</h3><p>Practise with sentences you wrote yourself.</p></div><div class="tile"><h3>Your dictionary</h3><p>Names and jargon stay as you wrote them.</p></div><div class="tile"><h3>Pause any app</h3><p>Password managers and terminals are never read.</p></div></div></div></section>"""

setup = f"""
<section id="setup"><div class="wrap center"><span class="eyebrow">Install</span><h2>Ready in about five minutes.</h2>
<p class="lede">Most of that is the one-time model download.</p>
<ol class="steps">
<li><h3>Download and open the DMG</h3><p>Open <code>{R['file']}</code> from your Downloads folder.</p></li>
<li><h3>Drag HeyHumanly into Applications</h3><p>Then open it from Applications.</p></li>
<li><h3>Set up the local model (once)</h3><p>The first-run tour has a <b>Get Ollama</b> button, then a <b>Download</b> button with a progress bar. The model is about 4.7 GB on a 16 GB Mac (1.9 GB on smaller Macs).</p></li>
<li><h3>Allow Accessibility, then try the example</h3><p>macOS asks before any app can read a text box. Allow it in <b>System Settings → Privacy &amp; Security → Accessibility</b>.</p></li></ol>
<p class="note" style="margin-top:20px"><b>About the first open.</b> Version {V} is not yet notarized by Apple, so macOS may warn you. See <a href="/install/#gatekeeper">install help</a>, check the checksum on the <a href="{REL}">release page</a>, or build it from source.</p>
<h3 style="margin:36px 0 12px;text-align:left">Requirements</h3>
<table><tr><th>macOS</th><td>14 (Sonoma) or later. Tested on macOS 27.</td></tr>
<tr><th>Mac</th><td>Apple silicon (M1 or later): tested. Intel: included in the download, not tested yet.</td></tr>
<tr><th>Memory</th><td>16 GB recommended for the 7B model. 8 GB Macs should use the 3B model; it misses more mistakes.</td></tr>
<tr><th>Disk</th><td>About 5 GB free.</td></tr>
<tr><th>Internet</th><td>Only for the one-time downloads of Ollama and the model.</td></tr></table></div></section>"""

privacy = f"""
<section id="privacy"><div class="wrap"><h2>Where your writing goes</h2>
<div class="ok"><b>Your text is checked by a model on your Mac.</b> HeyHumanly has no account, analytics or tracking, and sends your text only to the Ollama address in its Settings, which is <code>localhost</code> (this Mac) by default.</div>
<div class="grid">
<div class="card"><h3>What it reads</h3><p>Only the one text box you are typing in, after you pause. Never password fields, password managers, terminals or code editors.</p></div>
<div class="card"><h3>What it stores</h3><p>Sessions, review cards, your dictionary and settings stay in this app's preferences on your Mac. You can clear them in Settings.</p></div>
<div class="card"><h3>What still uses the internet</h3><p>Downloading Ollama and the model (done by Ollama and your browser, not by HeyHumanly), and loading this website. HeyHumanly does not check for updates yet.</p></div>
</div><p class="fine">Read the full <a href="/privacy/">privacy page</a>. If you point HeyHumanly at another computer in Settings, it warns you, because then your text leaves this Mac.</p></div></section>"""

limits = f"""
<section id="limits"><div class="wrap"><h2>Honest limits</h2><ul>
<li>It works well in Slack, Safari and TextEdit, where it was tested. Chrome, Mail, WhatsApp and other apps are not fully tested.</li>
<li>In Slack it shows the dot but cannot underline words, because Slack does not share word positions with other apps.</li>
<li>Local models are weaker than the biggest cloud models. The 3B model misses some grammar, and Hindi translation is unreliable.</li>
<li>Explanations for long rewrites can take 5 to 10 seconds.</li>
<li>Version {V} is early. There is no automatic update yet: download a new version from this page.</li></ul></div></section>"""

faqs = [
 ("Is HeyHumanly really free?", "Yes. The app is MIT-licensed and free to use. The only costs are your own disk space and the time to download the model. There is no account or subscription."),
 ("Does it work offline?", "After Ollama and the model are downloaded, the coach runs on your Mac without internet. Downloading them needs internet once."),
 ("Do I need Ollama?", "Yes. HeyHumanly asks Ollama to run the model. The first-run tour links to the Ollama download and then downloads the model for you with a progress bar. Already have Ollama? HeyHumanly finds it automatically."),
 ("Which model does it use?", "On a Mac with 12 GB of memory or more it uses Qwen 2.5 7B (Apache-2.0 license, about 4.7 GB). On smaller Macs it uses Qwen 2.5 3B (about 1.9 GB), which has its own Qwen license. You can pick any installed model in Settings."),
 ("Why does it need Accessibility permission?", "macOS only lets an app read a text box in another app if you allow it. HeyHumanly uses it to read the one box you are typing in, and to paste a fix you accepted. Without it, the coach window still works with text you type or paste into it."),
 ("macOS says it cannot verify the app. What do I do?", "That is expected for this early version, which is not notarized by Apple. See the install help page for the steps, and verify the checksum first."),
 ("Is it a Grammarly alternative?", "It does a similar job of marking mistakes, but its main aim is teaching: it explains the rule and has you practise it, and it runs on a local model instead of a cloud service."),
 ("Can I contribute or report a bug?", f"Yes. The code is on <a href='{SRC}'>GitHub</a>. Open an issue for bugs. Do not paste private text into public issues."),
]
faq = '<section id="faq"><div class="wrap" style="max-width:820px"><h2 class="center">Questions</h2>' + ''.join(f'<details><summary>{q}</summary><p>{a}</p></details>' for q, a in faqs) + '</div></section>'
final = f'<div class="final"><h2>Write better, starting with your next message.</h2><p class="lede">Free, open source and private by design.</p><div class="cta"><a class="btn cream dl" href="{DMG}" data-dl>Download for Mac</a></div><p class="fine" style="color:#bdbdbd">macOS 14 or later · {R["size_mb"]} MB</p></div>'

import re as _re
_faq=[{"@type":"Question","name":q,"acceptedAnswer":{"@type":"Answer","text":_re.sub('<[^>]+>','',x)}} for q,x in faqs]
schema = {"@context": "https://schema.org", "@graph": [
  {"@type": "WebSite", "@id": SITE + "/#website", "url": SITE + "/", "name": "HeyHumanly", "alternateName": ["Hey Humanly", "heyhumanly.com"]},
  {"@type": "SoftwareApplication", "@id": SITE + "/#app", "name": "HeyHumanly", "alternateName": ["Hey Humanly", "HeyHumanly Mac"], "operatingSystem": "macOS 14 or later",
   "applicationCategory": "EducationalApplication", "softwareVersion": V, "downloadUrl": DMG, "license": "https://opensource.org/license/mit",
   "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"}, "url": SITE + "/", "sameAs": [SRC],
   "description": "Free, open-source Mac writing coach that rephrases your writing for clarity and explains the habits behind each change, using a local AI model.",
   "author": {"@type": "Person", "name": "Kifayath", "sameAs": "https://github.com/Kifayath-ulla"},
   "contributor": [{"@type": "Thing", "name": "Claude", "description": "AI Contributor"}, {"@type": "Thing", "name": "OpenBot", "description": "AI Contributor"}]},
  {"@type": "Organization", "@id": SITE + "/#org", "name": "HeyHumanly", "url": SITE, "logo": SITE + "/apple-touch-icon.png", "sameAs": [SRC]},
  {"@type": "FAQPage", "mainEntity": _faq}]}
page('/', 'HeyHumanly: free Mac writing coach that rephrases and explains why',
     'HeyHumanly (Hey Humanly) is a free, open-source Mac app that rephrases what you write or dictate so it is clearer, shows the habits behind each change, and runs on a local AI model.',
     hero + how + setup + privacy + limits + faq + final, schema)

inst = f"""
<section style="border:0"><div class="wrap" style="max-width:820px"><h1 style="font-size:clamp(32px,5vw,52px);margin-left:0;text-align:left">Install HeyHumanly</h1>
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
<section style="border:0"><div class="wrap" style="max-width:820px"><h1 style="font-size:clamp(32px,5vw,52px);margin-left:0;text-align:left">Privacy</h1>
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
<h2>Report a security problem</h2><p>Open a private advisory on <a href="{SRC}/security/advisories/new">GitHub</a>. Please do not post private text in public issues.</p></div></section>"""
page('/privacy/', 'HeyHumanly privacy: what it reads, stores and sends',
     'What HeyHumanly reads, stores and sends, based on the source code: local model by default, no account, no analytics, no tracking.', priv)


habit_items = [
 ("Buried the point","Your main point or request comes late.","Before: “So I was thinking about the launch, and Priya said the design has issues, so can you tell me if we can still ship Monday?” After: “Can we still ship Monday? Priya says the design has issues.”","Finish the sentence “What I need from you is…” and start with that."),
 ("Filler","Words that add nothing: um, you know, basically, kind of.","Before: “So basically, um, the report is kind of late.” After: “The report is late.”","Pause silently. A pause sounds more confident than a filler word."),
 ("Hedging","Several maybes in a row weaken a message you mean.","Before: “I think we should probably maybe push it.” After: “Let's push it, unless the design is fixed by Thursday.”","Say it plainly, or name the condition."),
 ("Vague wording","Words like thing and stuff make the reader guess.","Before: “Can you look at the thing about the launch?” After: “Can you review the launch checklist?”","Replace “thing” with the noun you'd use if someone asked “which one?”."),
 ("Too much in one sentence","Several ideas joined by and, but and so.","Before: one 70-word sentence. After: three short sentences, one idea each.","Start a new sentence whenever the subject changes."),
 ("Repetition","Saying the same idea twice.","Before: “We need to decide, we need to decide soon.” After: “We need to decide soon.”","Say it once, in the strongest place."),
]
hb = ''.join(f'<details open><summary>{n}</summary><p><b>What it is:</b> {d}</p><p><i>Example.</i> {ex}</p><p><b>Next time:</b> {t}</p></details>' for n,d,ex,t in habit_items)
habits_page = f"""<section style="border:0"><div class="wrap" style="max-width:820px"><span class="eyebrow">Guide</span><h1 style="font-size:clamp(32px,5vw,52px);margin-left:0;text-align:left">Writing habits that make messages unclear, and how to fix them</h1>
<p class="lede" style="margin-left:0;text-align:left">Most unclear writing isn't a grammar problem. It comes from a few habits, especially when you write the way you speak. These are the six HeyHumanly looks for in your own text, with an example of each.</p>{hb}
<p class="ok" style="margin-top:24px">HeyHumanly finds these habits in your own messages, quotes your exact words, and tracks which ones you repeat. <a href="/">See how it works</a> or <a href="{DMG}" data-dl>download it free for Mac</a>.</p></div></section>"""
page('/writing-habits/', 'Writing habits that make messages unclear (and how to fix them) | HeyHumanly',
     'Six writing habits that make messages unclear: buried point, filler, hedging, vague wording, long sentences and repetition. Examples and a fix for each.', habits_page)
ol_page = f"""<section style="border:0"><div class="wrap" style="max-width:820px"><span class="eyebrow">Guide</span><h1 style="font-size:clamp(32px,5vw,52px);margin-left:0;text-align:left">Set up a local AI writing coach on a Mac with Ollama</h1>
<p class="lede" style="margin-left:0;text-align:left">A local model means your writing is processed on your Mac, not sent to a cloud service. HeyHumanly uses <a href="https://ollama.com">Ollama</a> to run it. This is the whole setup.</p>
<ol class="steps"><li><h3>Check your Mac</h3><p>macOS 14 or later. 16 GB of memory is comfortable for the 7B model (about 4.7 GB). On 8 GB use the 3B model (about 1.9 GB). Allow about 5 GB of free disk.</p></li>
<li><h3>Install Ollama</h3><p>Download it from <a href="https://ollama.com/download/mac">ollama.com</a> and open it once.</p></li>
<li><h3>Download a model</h3><p>HeyHumanly can do this for you with a progress bar. Or in Terminal run <code>ollama pull qwen2.5:7b</code> (or <code>qwen2.5:3b</code>), then <code>ollama list</code> to confirm.</p></li>
<li><h3>Open HeyHumanly</h3><p><a href="/install/">Install it</a>, open it, and it finds the running model automatically. Try pasting a rambling message into Rephrase.</p></li></ol>
<h2 style="font-size:28px;margin-top:36px">Licenses and honesty notes</h2><p>Qwen 2.5 7B is Apache-2.0. The 3B model has its own Qwen license. Local models are weaker than the largest cloud models; HeyHumanly's explanations come from rules in the app and your own text, not from guesses by the model. Downloading Ollama and the model needs internet once; after that the coach works offline.</p></div></section>"""
page('/local-ai-writing-coach-mac/', 'Set up a local AI writing coach on Mac with Ollama | HeyHumanly',
     'How to run a local AI writing coach on a Mac: install Ollama, download Qwen 2.5, requirements for 8 GB and 16 GB Macs, and licenses.', ol_page)
nf = '<section style="border:0;text-align:center;padding:90px 0"><h1>Page not found</h1><p class="lede" style="margin-inline:auto">That page does not exist.</p><a class="btn" href="/">Go to the home page</a></section>'
page('/404.html', 'Page not found · HeyHumanly', 'Page not found.', nf, noindex=True, canonical='/')

open(os.path.join(OUT, 'robots.txt'), 'w').write(f"User-agent: *\nAllow: /\n\nSitemap: {SITE}/sitemap.xml\n")
urls = ['/', '/install/', '/writing-habits/', '/local-ai-writing-coach-mac/', '/privacy/']
open(os.path.join(OUT, 'sitemap.xml'), 'w').write('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + ''.join(f'<url><loc>{SITE}{u}</loc><lastmod>{R["date"]}</lastmod></url>\n' for u in urls) + '</urlset>\n')
# Staging hosts stay out of search; production is not affected.
open(os.path.join(OUT, '_headers'), 'w').write("/*\n  X-Content-Type-Options: nosniff\n  Referrer-Policy: strict-origin-when-cross-origin\n  Content-Security-Policy: default-src 'self'; img-src 'self' data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'self'; form-action 'none'\n")
open(os.path.join(OUT, KEY + '.txt'), 'w').write(KEY)
print('site built', V)
