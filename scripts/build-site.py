#!/usr/bin/env python3
"""Generates the static site in site/ from site-src/release.json. Run: python3 scripts/build-site.py
Visual language adapted from Lexicon (https://github.com/AashishH15/Lexicon, MIT)."""
import json, os, shutil, html
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = json.load(open(os.path.join(ROOT, 'site-src/release.json')))
KEY = 'a3f9c2d17b8e4a60b5d1c9e2f7a40831'
OUT = os.path.join(ROOT, 'site'); SITE = R['site']
V = R['version']; REPO = R['repo']
DMG = f"https://github.com/{REPO}/releases/download/v{V}/{R['file']}"
EXT_FILE = f"HeyHumanly-Chrome-{V}.zip"
EXT = f"https://github.com/{REPO}/releases/download/v{V}/{EXT_FILE}"
REL = f"https://github.com/{REPO}/releases/tag/v{V}"
SRC = f"https://github.com/{REPO}"
shutil.rmtree(OUT, ignore_errors=True)
for sub in ['install', 'privacy', 'writing-habits', 'local-ai-writing-coach-mac', 'extension', 'fonts', 'grammarly-alternative', 'private-writing-assistant']: os.makedirs(os.path.join(OUT, sub), exist_ok=True)
for f in ['favicon.png', 'apple-touch-icon.png', 'og.png', 'app.png', 'icon-192.png', 'grain.png']:
    s = os.path.join(ROOT, 'site-src', f)
    if os.path.exists(s): shutil.copy(s, os.path.join(OUT, f))
for f in os.listdir(os.path.join(ROOT, 'site-src', 'fonts')): shutil.copy(os.path.join(ROOT, 'site-src', 'fonts', f), os.path.join(OUT, 'fonts', f))

CSS = """
@font-face{font-family:Newsreader;src:url(/fonts/newsreader.woff2) format("woff2");font-weight:200 800;font-style:normal;font-display:swap}
@font-face{font-family:Newsreader;src:url(/fonts/newsreader-italic.woff2) format("woff2");font-weight:200 800;font-style:italic;font-display:swap}
@font-face{font-family:Geist;src:url(/fonts/geist.woff2) format("woff2");font-weight:100 900;font-display:swap}
@font-face{font-family:"JetBrains Mono";src:url(/fonts/jetbrains-mono.woff2) format("woff2");font-weight:100 800;font-display:swap}
:root{color-scheme:light;--bg:#F7F6F3;--surface:#fff;--surface2:#F9F9F8;--subtle:#F3F3F4;--ink:#111;--mute:#636360;--line:rgba(0,0,0,.065);--line2:rgba(0,0,0,.14);
--btn:#111;--btnink:#fff;--btnhov:#2b2b2b;--nav:rgba(255,255,255,.55);--grain:url(/grain.png);
--bluebg:#E1F3FE;--bluetx:#1F6C9F;--greenbg:#EDF3EC;--greentx:#346538;--redbg:#FDEBEC;--redtx:#9F2F2D;--yellowbg:#FBF3DB;--yellowtx:#956400;
--serif:Newsreader,Georgia,serif;--sans:Geist,-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;--mono:"JetBrains Mono",ui-monospace,SFMono-Regular,monospace;
--shadow:0 2px 10px -2px rgba(0,0,0,.035);--lift:0 20px 40px -15px rgba(0,0,0,.12);--r:14px;--rl:18px}
:root[data-theme=dark]{color-scheme:dark;--bg:#0b0b0d;--surface:#131316;--surface2:#101012;--subtle:#1a1a1e;--ink:#f1f1f2;--mute:#a0a0a8;--line:rgba(255,255,255,.08);--line2:rgba(255,255,255,.18);
--btn:#f1f1f2;--btnink:#0b0b0d;--btnhov:#d6d6d9;--nav:rgba(19,19,22,.6);--grain:none;--bluebg:#10222f;--bluetx:#8cc7ee;--greenbg:#12201a;--greentx:#92d4a0;--redbg:#2a1517;--redtx:#f0a2a2;--yellowbg:#2a2210;--yellowtx:#e8c878;--shadow:none;--lift:0 20px 40px -15px rgba(0,0,0,.6)}
*{box-sizing:border-box;margin:0;padding:0}html{scroll-behavior:smooth}img{max-width:100%;height:auto}
body{background:var(--bg) var(--grain);background-size:256px;background-blend-mode:multiply;color:var(--ink);font:16px/1.625 var(--sans);-webkit-font-smoothing:antialiased;overflow-x:hidden}
h1,h2,h3,h4,.brand{font-family:var(--serif);font-weight:400;letter-spacing:-.02em;line-height:1.15}
h1{font-size:clamp(40px,6.4vw,76px);letter-spacing:-.03em;line-height:1.05;margin:0 auto 22px;max-width:14em}
h1 em,h2 em{font-style:italic}
h2{font-size:clamp(30px,4vw,46px);margin-bottom:16px}h3{font-size:1.3rem;margin-bottom:6px}
a{color:var(--ink);text-decoration:underline;text-underline-offset:3px;text-decoration-color:var(--line2);transition:.25s}a:hover{text-decoration-color:var(--ink)}
a:focus-visible,button:focus-visible,summary:focus-visible{outline:2px solid var(--ink);outline-offset:3px;border-radius:8px}
.skip{position:absolute;left:-999px}.skip:focus{left:12px;top:12px;background:var(--surface);padding:8px 12px;z-index:99}
.wrap{max-width:1160px;margin:0 auto;padding:0 32px}main{overflow:hidden}
.mono,.eyebrow,.badge,nav.links a,kbd,.tag,.lab,footer h4,.legal{font-family:var(--mono)}
.badge{display:inline-flex;align-items:center;gap:8px;padding:4px 12px;border-radius:999px;font-size:.72rem;font-weight:500;letter-spacing:.06em;text-transform:uppercase;background:var(--bluebg);color:var(--bluetx)}
.badge.g{background:var(--greenbg);color:var(--greentx)}.badge.y{background:var(--yellowbg);color:var(--yellowtx)}.badge.r{background:var(--redbg);color:var(--redtx)}
.eyebrow{display:inline-block;font-size:.72rem;letter-spacing:.14em;text-transform:uppercase;font-weight:500;color:var(--mute);margin-bottom:14px}
/* floating glass nav */
header.top{position:fixed;top:0;left:50%;transform:translateX(-50%);width:100%;z-index:50;padding:14px 0;border-bottom:1px solid var(--line);background:var(--nav);-webkit-backdrop-filter:blur(18px) saturate(1.6);backdrop-filter:blur(18px) saturate(1.6);transition:top .45s cubic-bezier(.22,1,.36,1),width .45s cubic-bezier(.22,1,.36,1),border-radius .45s,padding .45s,box-shadow .45s}
header.top.scrolled{top:14px;width:min(calc(100% - 28px),1120px);border-radius:999px;border-bottom:0;padding:10px 0;box-shadow:inset 0 0 0 1px rgba(255,255,255,.5),0 12px 40px -12px rgba(0,0,0,.18)}
.nav{display:flex;align-items:center;justify-content:space-between;gap:12px;max-width:1160px;margin:0 auto;padding:0 28px}
.brand{display:flex;align-items:center;gap:10px;font-weight:500;color:var(--ink);text-decoration:none;font-size:1.3rem}.brand img{width:28px;height:28px;border-radius:7px}
nav.links{display:flex;gap:28px;align-items:center}nav.links a{color:var(--ink);opacity:.6;text-decoration:none;font-size:.74rem;text-transform:uppercase;letter-spacing:.08em;font-weight:500}nav.links a:hover{opacity:1}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;background:var(--btn);color:var(--btnink)!important;text-decoration:none;font-weight:500;padding:13px 24px;border-radius:10px;border:1px solid var(--btn);font-size:15px;cursor:pointer;transition:.25s}
.btn:hover{background:var(--btnhov);transform:translateY(-1px)}.btn.sm{padding:9px 16px;font-size:14px;border-radius:999px}
nav.links a.btn{opacity:1;text-transform:none;font-family:var(--sans);letter-spacing:0;font-size:14px;font-weight:500}
.btn.ghost{background:var(--surface);color:var(--ink)!important;border:1px solid var(--line2)}.btn.ghost:hover{background:var(--subtle)}
.btn.cream{background:#f7f6f3;color:#111!important;border-color:#f7f6f3}.btn.cream:hover{background:#fff}
.tg{width:36px;height:36px;border-radius:50%;border:1px solid var(--line2);background:var(--surface);color:var(--ink);cursor:pointer;font-size:15px;display:grid;place-items:center}.tg:hover{background:var(--subtle)}
/* hero */
.hero{text-align:center;padding:150px 0 10px}
.lede{font-size:clamp(17px,1.9vw,20px);color:var(--mute);margin:0 auto 28px;max-width:38em}
.cta{display:flex;flex-wrap:wrap;gap:12px;align-items:center;justify-content:center}.fine{font-size:13px;color:var(--mute);margin-top:14px;font-family:var(--mono)}
.stage{margin:48px auto 0;max-width:960px;border-radius:24px;padding:clamp(14px,3vw,34px);background:radial-gradient(110% 120% at 15% 0%,#ece6d8 0%,#e9e5dc 40%,#e4e1da 100%);box-shadow:var(--lift);border:1px solid var(--line)}
:root[data-theme=dark] .stage{background:radial-gradient(110% 120% at 15% 0%,#1d1d22,#121215)}
.win{background:var(--surface);border-radius:16px;text-align:left;box-shadow:0 20px 50px -24px rgba(0,0,0,.35);overflow:hidden;border:1px solid var(--line)}
.win .top{display:flex;align-items:center;gap:7px;padding:10px 14px;background:var(--surface2);border-bottom:1px solid var(--line);font-size:12px;color:var(--mute);font-family:var(--mono)}
.win .top i{width:10px;height:10px;border-radius:50%;background:var(--line2);display:block}.win .top span{margin-left:8px}
.win .body{padding:20px 22px 16px;font-size:clamp(16px,2vw,19px);line-height:1.55;position:relative}
.u-m{background:var(--redbg);color:var(--redtx);border-radius:4px;padding:0 3px}.lab{font-size:10.5px;letter-spacing:.12em;font-weight:500;color:var(--mute);margin-bottom:6px;text-transform:uppercase}
.better{border-top:1px solid var(--line);opacity:0;transition:.4s}.better.on{opacity:1}.better #demo-new{font-weight:500}
.cards{display:grid;gap:8px;padding:0 22px 20px}.rc{display:grid;grid-template-columns:auto 1fr;gap:12px;align-items:start;background:var(--surface2);border:1px solid var(--line);border-radius:12px;padding:10px 14px;font-size:14.5px;opacity:0;transform:translateY(6px);transition:.35s}
.rc.on{opacity:1;transform:none}.rc small{display:block;color:var(--mute);font-size:13.5px;line-height:1.45}
.rc.nx{background:var(--ink);border-color:var(--ink)}.rc.nx small{color:var(--bg);opacity:.9}.rc.nx .tag{background:var(--bg);color:var(--ink)}
.tag{font-size:10.5px;font-weight:500;padding:2px 9px;border-radius:999px;background:var(--redbg);color:var(--redtx);align-self:start;margin-top:2px;letter-spacing:.04em;text-transform:uppercase;white-space:nowrap}
.tag.t{background:var(--bluebg);color:var(--bluetx)}.tag.g{background:var(--greenbg);color:var(--greentx)}.tag.y{background:var(--yellowbg);color:var(--yellowtx)}
.dot{position:absolute;right:16px;bottom:14px;background:var(--ink);color:var(--bg);border-radius:999px;min-width:28px;height:28px;display:grid;place-items:center;font-size:13px;font-weight:600;opacity:0;transform:scale(.6);transition:.25s}.dot.on{opacity:1;transform:none}
section{padding:80px 0}.center{text-align:center}.center .lede{margin-left:auto;margin-right:auto}
.proof{display:flex;flex-wrap:wrap;gap:10px 30px;justify-content:center;color:var(--mute);font-size:13px;padding:30px 0 0;font-family:var(--mono)}.proof span::before{content:"✓ ";color:var(--greentx);font-weight:700}
.steps3{display:grid;grid-template-columns:repeat(3,1fr);gap:18px;margin-top:40px;text-align:left}
.step,.tile,.card,.panel{background:var(--surface);border:1px solid var(--line);border-radius:var(--rl);padding:28px;box-shadow:var(--shadow);transition:.3s}
.step:hover,.tile:hover{box-shadow:0 12px 28px -6px rgba(0,0,0,.08);transform:translateY(-2px)}
.step .n{width:34px;height:34px;border-radius:50%;background:var(--ink);color:var(--bg);display:grid;place-items:center;font-family:var(--mono);font-size:13px;margin-bottom:16px}
.step p,.tile p,.card p{color:var(--mute);font-size:15.5px}
.bento{display:grid;grid-template-columns:repeat(6,1fr);gap:16px;margin-top:40px;text-align:left}.tile{grid-column:span 2}.tile.w{grid-column:span 3}
.tile .meta{font-family:var(--mono);font-size:.7rem;letter-spacing:.1em;text-transform:uppercase;color:var(--mute);display:block;margin-bottom:14px}
.tile h3{font-size:1.45rem;margin-bottom:8px}.tile.g{background:var(--greenbg);border-color:transparent}.tile.b{background:var(--bluebg);border-color:transparent}.tile.y{background:var(--yellowbg);border-color:transparent}.tile.r{background:var(--redbg);border-color:transparent}
.tile.g p,.tile.b p,.tile.y p,.tile.r p{color:inherit;opacity:.85}.tile.g{color:var(--greentx)}.tile.b{color:var(--bluetx)}.tile.y{color:var(--yellowtx)}.tile.r{color:var(--redtx)}
.tile.g h3,.tile.b h3,.tile.y h3,.tile.r h3,.tile.g .meta,.tile.b .meta,.tile.y .meta,.tile.r .meta{color:inherit}
.band{background:var(--surface);border-top:1px solid var(--line);border-bottom:1px solid var(--line)}
.split{display:grid;grid-template-columns:1fr 1fr;gap:56px;align-items:center}
.panel{padding:26px}.tabs{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:16px}
.tabs button{border:1px solid var(--line2);background:var(--surface);border-radius:999px;padding:7px 15px;font:500 13px var(--mono);color:var(--mute);cursor:pointer}
.tabs button[aria-selected=true]{background:var(--ink);border-color:var(--ink);color:var(--bg)}
.out{font-size:18px;line-height:1.55;min-height:120px}.orig{color:var(--mute);font-size:14.5px;margin-bottom:12px;padding-bottom:12px;border-bottom:1px dashed var(--line2)}
/* extension */
.ext{background:var(--surface);border:1px solid var(--line);border-radius:22px;padding:clamp(18px,3vw,34px);box-shadow:var(--shadow);margin-top:36px;text-align:left}
.ext .bar{display:flex;align-items:center;justify-content:space-between;font-family:var(--mono);font-size:12px;color:var(--mute);margin-bottom:16px}
.ext .shell{border:1px solid var(--line2);border-radius:14px;overflow:hidden;background:var(--bg)}
.ext .chrome{display:flex;align-items:center;gap:7px;padding:9px 12px;background:var(--subtle);border-bottom:1px solid var(--line)}.ext .chrome i{width:10px;height:10px;border-radius:50%;background:var(--line2);display:block}
.ext .url{margin-left:10px;flex:1;background:var(--surface);border:1px solid var(--line);border-radius:999px;padding:3px 12px;font-family:var(--mono);font-size:11.5px;color:var(--mute)}
.ext .pill{font-family:var(--mono);font-size:11px;background:var(--greenbg);color:var(--greentx);padding:3px 10px;border-radius:999px}
.ext .compose{padding:22px;background:var(--surface)}.ext .meta{font-family:var(--mono);font-size:12px;color:var(--mute);margin-bottom:10px}
.ext .chip{margin-top:14px;display:inline-flex;gap:10px;align-items:center;flex-wrap:wrap;background:var(--surface2);border:1px solid var(--line2);border-radius:12px;padding:8px 12px;font-size:14px}
.ext .chip b{font-family:var(--mono);font-size:10.5px;font-weight:500;letter-spacing:.06em;text-transform:uppercase;background:var(--yellowbg);color:var(--yellowtx);padding:2px 9px;border-radius:999px}
.ext .chip s{color:var(--redtx)}.ext .chip .ap{background:var(--ink);color:var(--bg);border-radius:8px;padding:3px 12px;font-size:13px}
/* manifesto */
.manifesto{background:var(--surface);border:1px solid var(--line);border-radius:26px;padding:clamp(28px,5vw,64px);text-align:center;box-shadow:var(--shadow)}
.manifesto .eyebrow{background:var(--subtle);padding:5px 14px;border-radius:999px}
.manifesto h2{font-size:clamp(32px,4.4vw,52px);max-width:14em;margin-inline:auto}
.manifesto p.t{max-width:40em;margin:0 auto 14px;color:var(--mute);font-size:17px}
.trust{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;margin-top:34px;text-align:left}.trust div{border-top:1px solid var(--line2);padding-top:16px}.trust h4{font-family:var(--serif);font-size:1.15rem;font-weight:500;margin-bottom:4px}.trust p{color:var(--mute);font-size:14.5px}
ol.steps{list-style:none;margin:26px 0 0;display:grid;gap:12px;counter-reset:s;text-align:left}
ol.steps li{counter-increment:s;background:var(--surface);border:1px solid var(--line);border-radius:16px;padding:16px 20px 16px 64px;position:relative}
ol.steps li::before{content:counter(s);position:absolute;left:18px;top:16px;width:30px;height:30px;border-radius:50%;background:var(--ink);color:var(--bg);display:grid;place-items:center;font-family:var(--mono);font-size:13px}
ol.steps li p{margin:2px 0 0;color:var(--mute)}ol.steps li h3{font-size:1.1rem;font-family:var(--sans);font-weight:600;letter-spacing:0}
.note{background:var(--yellowbg);border:1px solid transparent;border-radius:14px;padding:14px 18px;color:var(--yellowtx);font-size:15px;text-align:left}
.ok{background:var(--greenbg);border:1px solid transparent;border-radius:14px;padding:14px 18px;font-size:15.5px;text-align:left;color:var(--greentx)}.ok b{color:inherit}
table{border-collapse:collapse;width:100%;font-size:15px;background:var(--surface);border:1px solid var(--line);border-radius:14px;overflow:hidden;text-align:left}
th,td{padding:12px 16px;border-bottom:1px solid var(--line);vertical-align:top}th{background:var(--surface2);width:120px;font-family:var(--mono);font-size:12px;text-transform:uppercase;letter-spacing:.06em;font-weight:500}tr:last-child th,tr:last-child td{border-bottom:0}
details{background:var(--surface);border:1px solid var(--line);border-radius:14px;padding:16px 20px;margin:10px 0;text-align:left}summary{cursor:pointer;font-weight:600;font-size:16.5px}
details p{margin:10px 0 0;color:var(--mute)}code,kbd{white-space:nowrap;background:var(--subtle);border:1px solid var(--line);border-radius:6px;padding:1px 7px;font:13px var(--mono);word-break:break-all}
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin:20px 0}.card{text-align:left;padding:24px}.card h3{font-size:1.2rem}
#privacy .wrap,#limits .wrap,#setup .wrap{max-width:960px}#privacy,#limits{padding:40px 0}#limits ul{list-style:none;display:grid;gap:10px}
#limits li{background:var(--surface);border:1px solid var(--line);border-radius:14px;padding:13px 18px 13px 46px;position:relative;color:var(--mute);font-size:15.5px}
#limits li::before{content:"!";position:absolute;left:15px;top:13px;width:22px;height:22px;border-radius:50%;background:var(--yellowbg);color:var(--yellowtx);display:grid;place-items:center;font:600 12px var(--mono)}
.final{margin:20px 24px 56px;border-radius:28px;background:#111;color:#f7f6f3;text-align:center;padding:clamp(44px,7vw,84px) 24px;border:1px solid var(--line)}
.final h2{color:#f7f6f3;max-width:14em;margin-inline:auto}.final .lede{color:#b9b8b3}
footer{border-top:1px solid var(--line);padding:52px 0 28px;color:var(--mute);font-size:14px;background:var(--surface2)}
.fgrid{display:grid;grid-template-columns:1.4fr repeat(3,1fr);gap:30px}footer h4{margin:0 0 12px;color:var(--ink);font-size:.72rem;letter-spacing:.1em;text-transform:uppercase;font-weight:500}footer a{display:block;color:var(--mute);text-decoration:none;padding:3px 0}footer a:hover{color:var(--ink)}
.legal{margin-top:34px;padding-top:18px;border-top:1px solid var(--line);display:flex;flex-wrap:wrap;gap:8px 20px;justify-content:space-between;font-size:12px}
#notmac{display:none;margin-top:16px}
main>section:first-child,main>.wrap:first-child{}
@media(max-width:860px){.split,.steps3,.trust,.grid{grid-template-columns:1fr}.bento{grid-template-columns:1fr}.tile,.tile.w{grid-column:auto}.fgrid{grid-template-columns:1fr 1fr}nav.links a.hide-s{display:none}section{padding:56px 0}.hero{padding-top:120px}}
@media(prefers-reduced-motion:reduce){*{transition:none!important}}
"""

def page(path, title, desc, body, schema=None, noindex=False, canonical=None):
    url = SITE + canonical if canonical is not None else SITE + path
    crumbs = ''
    if path not in ('/', '/404.html'):
        crumbs = '<script type="application/ld+json">' + json.dumps({"@context": "https://schema.org", "@type": "BreadcrumbList", "itemListElement": [
            {"@type": "ListItem", "position": 1, "name": "HeyHumanly", "item": SITE + "/"},
            {"@type": "ListItem", "position": 2, "name": title.split(' | ')[0].split(':')[0], "item": SITE + path}]}) + '</script>'
    ld = (f'<script type="application/ld+json">{json.dumps(schema)}</script>' if schema else '') + crumbs
    robots = '<meta name="robots" content="noindex">' if noindex else ''
    out = f"""<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)}</title><meta name="description" content="{html.escape(desc)}">{robots}
<link rel="canonical" href="{url}"><link rel="icon" href="/favicon.png" type="image/png"><link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="alternate" type="text/plain" href="/llms.txt" title="LLMs.txt">
<link rel="preload" href="/fonts/newsreader.woff2" as="font" type="font/woff2" crossorigin><link rel="preload" href="/fonts/geist.woff2" as="font" type="font/woff2" crossorigin>
<meta property="og:type" content="website"><meta property="og:site_name" content="HeyHumanly"><meta property="og:title" content="{html.escape(title)}">
<meta property="og:description" content="{html.escape(desc)}"><meta property="og:url" content="{url}"><meta property="og:image" content="{SITE}/og.png">
<meta name="twitter:card" content="summary_large_image"><meta name="theme-color" content="#F7F6F3"><meta name="google-site-verification" content="Z0gdQHwUIRf05KhmeTaF1pIuTKwzJaGXkySy6l3MHhY"><meta name="msvalidate.01" content="7214F04580277B31B88F4F83CF229AA0">
<script>(function(){{try{{var t=localStorage.getItem("hhtheme")||"light";document.documentElement.setAttribute("data-theme",t)}}catch(e){{}}}})()</script><style>{CSS}</style>{ld}</head><body><a class="skip" href="#main">Skip to content</a>
<header class="top" id="top"><div class="nav"><a class="brand" href="/"><img src="/favicon.png" alt="" width="28" height="28">HeyHumanly</a>
<nav class="links" aria-label="Main"><a class="hide-s" href="/#how">How it works</a><a class="hide-s" href="/#features">Features</a><a class="hide-s" href="/extension/">Chrome</a><a class="hide-s" href="/install/">Install</a><a class="hide-s" href="/#faq">FAQ</a><a class="hide-s" href="{SRC}">GitHub</a><button class="tg" id="tg" type="button" aria-label="Switch between light and dark theme">◐</button><a class="btn sm dl" href="{DMG}" data-dl>Download for Mac</a></nav></div></header>
<main id="main">{body}</main>
<footer><div class="wrap"><div class="fgrid"><div><a class="brand" href="/"><img src="/favicon.png" alt="" width="28" height="28">HeyHumanly</a><p style="margin:12px 0 0;max-width:22em">A free writing coach for Mac and Chrome. It keeps your tone and teaches you why each change helps, with an AI model on your own computer.</p></div>
<div><h4>Product</h4><a href="/#how">How it works</a><a href="/#features">Features</a><a href="/extension/">Chrome extension</a><a href="/#privacy">Privacy</a><a href="/#faq">FAQ</a><a href="/writing-habits/">Writing habits guide</a><a href="/local-ai-writing-coach-mac/">Local AI setup</a><a href="/grammarly-alternative/">Grammarly alternative</a><a href="/private-writing-assistant/">Private writing assistant</a></div>
<div><h4>Get started</h4><a href="{DMG}" data-dl>Download for Mac</a><a href="{EXT}">Chrome extension (zip)</a><a href="/install/">Install help</a><a href="{REL}">Release notes &amp; checksum</a></div>
<div><h4>Open source</h4><a href="{SRC}">Source code</a><a href="{SRC}/issues">Report a bug</a><a href="{SRC}/blob/main/LICENSE">MIT license</a><a href="/privacy/">Privacy details</a><a href="/llms.txt">llms.txt</a></div></div>
<div class="legal"><span>HeyHumanly {V} · MIT License · Mac (macOS 14+) and Chrome</span><span>Design inspired by Lexicon (MIT). Models are separate downloads under their own licenses.</span></div></div></footer>
<script>
(function(){{var h=document.getElementById('top');function s(){{h.classList.toggle('scrolled',window.scrollY>40)}}s();addEventListener('scroll',s,{{passive:true}});
var tg=document.getElementById('tg');tg.addEventListener('click',function(){{var r=document.documentElement,n=r.getAttribute('data-theme')==='dark'?'light':'dark';r.setAttribute('data-theme',n);try{{localStorage.setItem('hhtheme',n)}}catch(e){{}}}});
var mac=/Mac/i.test(navigator.platform||navigator.userAgent);var n=document.getElementById('notmac');if(n&&!mac)n.style.display='block';
document.querySelectorAll('[data-dl]').forEach(function(a){{a.addEventListener('click',function(){{try{{if(location.pathname==='/install/'||sessionStorage.getItem('hhgo'))return;sessionStorage.setItem('hhgo','1');
setTimeout(function(){{location.href='/install/?started=1'}},900)}}catch(e){{}}}})}})}})();
</script></body></html>"""
    p = os.path.join(OUT, path.strip('/'), 'index.html') if path.endswith('/') and path != '/' else (os.path.join(OUT, path.strip('/')) if path != '/' else os.path.join(OUT, 'index.html'))
    os.makedirs(os.path.dirname(p), exist_ok=True); open(p, 'w').write(out)

dl = f'<a class="btn dl" href="{DMG}" data-dl>Download for Mac</a>'
hero = f"""
<div class="wrap hero"><span class="badge">Free · Open source · Mac &amp; Chrome</span><div style="height:18px"></div>
<h1>Say it better. <em>Learn why.</em></h1>
<p class="lede">HeyHumanly tightens what you write in your own voice. Casual stays casual. It cuts the filler, shows you what changed and why, and links the research, so next time you get it right yourself.</p>
<div class="cta">{dl}<a class="btn ghost" href="/extension/">Add to Chrome</a></div>
<p class="fine">Free · macOS 14+ · Runs on your computer · Version {V}</p>
<p class="note" id="notmac" role="note">The desktop app is for Mac. You can still use the Chrome extension on any computer.</p>
<div class="stage" aria-label="Animated example of HeyHumanly tightening a rambling message and explaining why"><div class="win"><div class="top"><i></i><i></i><i></i><span>HeyHumanly</span></div>
<div class="body"><div class="lab">You wrote</div><div id="demo-text" aria-live="polite"></div></div>
<div class="body better" id="demo-better"><div class="lab">Maybe this reads better · same tone</div><div id="demo-new"></div></div>
<div class="cards" id="demo-cards">
<div class="rc"><span class="tag">Filler</span><div><small>5 filler phrases in 72 words (“So basically”, “um”, “kind of”, “you know”). They add no information, and the reader has to get through them to reach the point.</small></div></div>
<div class="rc"><span class="tag y">Hedging</span><div><small>You hedged 6 times (“maybe”, “kind of”, “I think”, “probably”). Each one can make you sound less sure of the point.</small></div></div>
<div class="rc"><span class="tag t">Research</span><div><small>Nielsen Norman Group found concise text measurably easier to use, because most people skim instead of reading every word.</small></div></div>
<div class="rc nx"><span class="tag">Next time</span><div><small>Pause silently instead of saying “um”. A pause sounds confident.</small></div></div></div></div></div>
<div class="proof"><span>Keeps your tone</span><span>Explains every change</span><span>Links the research</span><span>Runs on your computer</span><span>No account</span></div></div>
""" + """<script>(function(){var T=document.getElementById('demo-text'),B=document.getElementById('demo-better'),N=document.getElementById('demo-new'),cs=[].slice.call(document.querySelectorAll('#demo-cards .rc'));
var raw="So basically I was thinking, um, that maybe we could kind of look at the thing about the launch, because I talked to Priya yesterday and she said, you know, the design is mostly done but there are some issues, and I think we should probably, like, maybe push the launch, but I'm not sure, so can you let me know by Friday if you think we can still ship on Monday?";
var out="I was thinking maybe we could look at the thing about the launch. I talked to Priya yesterday and she said the design is mostly done but there are some issues. I think we should probably push the launch, but I'm not sure, so can you let me know by Friday if we can still ship on Monday?";
var ph=["So basically","um","maybe","kind of","you know","I think","probably","like","not sure"];
function esc(x){return x.replace(/&/g,'&amp;').replace(/</g,'&lt;')}
function mark(t){var h=esc(t);ph.forEach(function(p){h=h.replace(new RegExp('(^|[^a-z])('+p+')(?![a-z])','i'),function(m,a,b){return a+'<mark class="u-m">'+b+'</mark>'})});return h}
function reset(){T.textContent='';B.className='body better';N.textContent='';cs.forEach(function(c){c.classList.remove('on')})}
function show(){T.innerHTML=mark(raw);B.className='body better on';N.textContent=out;cs.forEach(function(c){c.classList.add('on')})}
if(matchMedia('(prefers-reduced-motion:reduce)').matches){show();return}
function w(ms){return new Promise(function(r){setTimeout(r,ms)})}
async function run(){for(;;){reset();for(var i=6;i<=raw.length;i+=6){T.textContent=raw.slice(0,i);await w(18)}T.textContent=raw;await w(700);T.innerHTML=mark(raw);await w(1100);B.className='body better on';N.textContent=out;await w(900);for(var k=0;k<cs.length;k++){cs[k].classList.add('on');await w(650)}await w(5000)}}run()})();</script>"""

how = """
<section id="how" class="center"><div class="wrap"><span class="eyebrow">How it works</span><h2>Not just rephrased. <em>Explained.</em></h2>
<p class="lede">Other tools rewrite your text and leave you guessing. HeyHumanly shows you why, so you improve.</p>
<div class="steps3"><div class="step"><div class="n">01</div><h3>Write it your way</h3><p>Paste a message, dictate it, or type in any text box on the web. Slang and casual are fine.</p></div>
<div class="step"><div class="n">02</div><h3>See a lighter edit</h3><p>Your tone and energy stay. Only filler, repeats and extra words are trimmed, with your own words highlighted.</p></div>
<div class="step"><div class="n">03</div><h3>Learn the habit</h3><p>Each change names the habit, quotes you, links the research behind the tip and tells you what to do next time.</p></div></div></div></section>

<section id="features" class="center"><div class="wrap"><span class="eyebrow">Built to teach</span><h2>More than a spellchecker.</h2>
<div class="bento">
<div class="tile w g"><span class="meta">Your voice</span><h3>Keeps your tone</h3><p>Casual stays casual. HeyHumanly reads your register first, then makes small cuts only. It never turns “yo gang” into a corporate email.</p></div>
<div class="tile w b"><span class="meta">The evidence</span><h3>Tips with sources</h3><p>Concise text, readable wording and hedging each link to the study behind the tip. Where the research is mixed, it says so.</p></div>
<div class="tile"><span class="meta">Style</span><h3>Wordy phrases</h3><p>“In order to” becomes “to”. “Due to the fact that” becomes “because”.</p></div>
<div class="tile"><span class="meta">Clarity</span><h3>Passive and repeats</h3><p>Flags hidden doers and three sentences in a row that start the same way.</p></div>
<div class="tile y"><span class="meta">Progress</span><h3>Your habits over time</h3><p>Insights shows which habits you repeat, so you work on one thing at a time.</p></div>
<div class="tile w"><span class="meta">Any local model</span><h3>Works with every model in Ollama</h3><p>Qwen, Gemma, Llama, Mistral, whatever you already run. HeyHumanly lists what is installed and recommends one for your Mac.</p></div>
<div class="tile w r"><span class="meta">Review</span><h3>Practice with your own sentences</h3><p>Short drills built from your past mistakes, spaced out so the fixes stick.</p></div>
</div></div></section>

<section id="styles" class="band"><div class="wrap split"><div><span class="eyebrow">Rewrites</span><h2>Same message, <em>your</em> voice.</h2>
<p class="lede" style="margin-left:0">Keep your tone, go shorter, or make one message more formal. You see the change before anything is pasted.</p>
<p class="fine">These examples were written by the app's own model on a Mac.</p></div>
<div class="panel"><div class="tabs" role="tablist" aria-label="Rewrite style">
<button role="tab" aria-selected="true" data-k="fix">Keep my tone</button><button role="tab" aria-selected="false" data-k="short">Shorter</button></div>
<div class="orig">You wrote: "hey richard, i have exam this sunday so i might not be available, just wanted to let u know"</div><div class="out" id="tone-out" aria-live="polite"></div></div></div></section>
<script>(function(){var o={fix:"hey richard, i have an exam this sunday so i might not be available, just wanted to let you know",short:"Hey Richard, I have an exam on Sunday and might not be available. Just letting you know."};
var out=document.getElementById('tone-out');out.textContent=o.fix;document.querySelectorAll('[role=tab]').forEach(function(b){b.addEventListener('click',function(){document.querySelectorAll('[role=tab]').forEach(function(x){x.setAttribute('aria-selected','false')});b.setAttribute('aria-selected','true');out.textContent=o[b.dataset.k]})})})();</script>

<section id="extension" class="center"><div class="wrap"><span class="eyebrow">The Chrome extension <span class="badge g" style="margin-left:6px">New</span></span><h2>Tighten anything you type on the web.</h2>
<p class="lede">Emails, posts and comments. Select your text, press the shortcut, and see the same tone-keeping edit with the reason behind it. It uses the model already on your computer.</p>
<div class="ext" aria-hidden="true"><div class="bar"><span>HeyHumanly for Chrome</span><span>Connected · local model</span></div>
<div class="shell"><div class="chrome"><i></i><i></i><i></i><div class="url">mail.example.com/compose</div><span class="pill">HeyHumanly on</span></div>
<div class="compose"><div class="meta">To: sam@example.com · Subject: Quick follow-up</div>
<p>hey sam, i just wanted to reach out and let you know that, um, i think the report is kind of late</p>
<div class="chip"><b>Filler</b><span><s>i just wanted to reach out and let you know that, um,</s></span><span class="ap">Apply</span></div></div></div></div>
<div class="cta" style="margin-top:28px"><a class="btn" href="/extension/">Get the Chrome extension</a><a class="btn ghost" href="/extension/#setup">Setup takes two minutes</a></div></div></section>
"""

setup = f"""
<section id="setup"><div class="wrap center"><span class="eyebrow">Install the Mac app</span><h2>Ready in about five minutes.</h2>
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

manifesto = """
<section id="manifesto"><div class="wrap"><div class="manifesto"><span class="eyebrow">Why HeyHumanly was built</span>
<h2>A coach, not a <em>correction machine</em>.</h2>
<p class="t">Most writing tools fix your sentence and move on, so you make the same mistake tomorrow. HeyHumanly keeps your voice, shows what could be tighter, and tells you why, so the habit changes.</p>
<p class="t">Built for people who write things they would not want sitting on someone else's server.</p>
<div class="trust"><div><h4>Zero telemetry</h4><p>No tracking and no analytics. Your writing stays on your computer.</p></div><div><h4>Open source (MIT)</h4><p>Free and open. Read every line on GitHub.</p></div><div><h4>No subscription</h4><p>No account, no paywall, no trial that expires.</p></div></div></div></div></section>"""

privacy = f"""
<section id="privacy"><div class="wrap"><h2>Where your writing goes</h2>
<div class="ok"><b>Your text is checked by a model on your computer.</b> HeyHumanly has no account, analytics or tracking, and sends your text only to the Ollama address in its Settings, which is <code>localhost</code> (this computer) by default.</div>
<div class="grid">
<div class="card"><h3>What it reads</h3><p>Only the one text box you are typing in, after you pause. Never password fields, password managers, terminals or code editors.</p></div>
<div class="card"><h3>What it stores</h3><p>Sessions, review cards, your dictionary and settings stay in this app's preferences on your Mac. You can clear them in Settings.</p></div>
<div class="card"><h3>What still uses the internet</h3><p>Downloading Ollama and the model (done by Ollama and your browser, not by HeyHumanly), and loading this website. HeyHumanly does not check for updates yet.</p></div>
</div><p class="fine">Read the full <a href="/privacy/">privacy page</a>. If you point HeyHumanly at another computer in Settings, it warns you, because then your text leaves this computer.</p></div></section>"""

limits = f"""
<section id="limits"><div class="wrap"><h2>Honest limits</h2><ul>
<li>It works well in Slack, Safari and TextEdit, where it was tested. Chrome, Mail, WhatsApp and other apps are not fully tested.</li>
<li>In Slack it shows the dot but cannot underline words, because Slack does not share word positions with other apps.</li>
<li>Local models are weaker than the biggest cloud models. The 3B model misses some grammar, and Hindi translation is unreliable.</li>
<li>Explanations for long rewrites can take 5 to 10 seconds.</li>
<li>The research notes cite real studies, but no study proves one rewrite is best for everyone. Where the evidence is mixed, the app says so.</li>
<li>Version {V} is early. There is no automatic update yet: download a new version from this page.</li></ul></div></section>"""

faqs = [
 ("Is HeyHumanly really free?", "Yes. The app and the Chrome extension are MIT-licensed and free to use. The only costs are your own disk space and the time to download the model. There is no account or subscription."),
 ("Will it make my message sound formal?", "No. HeyHumanly reads your register first. A casual message stays casual, and only filler, repeated words and extra words are trimmed. A \"More formal\" button exists for the times you want it."),
 ("Where do the research notes come from?", "Each tip links to the study or report behind it, such as Nielsen Norman Group's web-reading research and Oppenheimer's 2006 paper on plain writing. Where evidence is mixed, for example on leading with your point, the app says so."),
 ("Does it work offline?", "After Ollama and the model are downloaded, HeyHumanly runs on your computer without internet. Downloading them needs internet once."),
 ("Do I need Ollama?", "Yes. HeyHumanly asks Ollama to run the model. The first-run tour links to the Ollama download and then downloads the model for you with a progress bar. Already have Ollama? HeyHumanly finds it automatically."),
 ("Which model does it use?", "Any model in Ollama. On a Mac with 12 GB of memory or more it recommends Qwen 2.5 7B (Apache-2.0 license, about 4.7 GB). On smaller Macs it recommends Qwen 2.5 3B (about 1.9 GB). You can pick any installed model in Settings."),
 ("How do I use the Chrome extension?", "Install it, allow it to reach Ollama on your computer (one button in the Mac app's Settings, or one Terminal command, explained on the extension page), then select text in any text box and press the shortcut. It shows the edit, the reason and the research, and lets you apply or copy it."),
 ("Why does the Mac app need Accessibility permission?", "macOS only lets an app read a text box in another app if you allow it. HeyHumanly uses it to read the one box you are typing in, and to paste a fix you accepted. Without it, the coach window still works with text you type or paste into it."),
 ("macOS says it cannot verify the app. What do I do?", "That is expected for this early version, which is not notarized by Apple. See the install help page for the steps, and verify the checksum first."),
 ("Is it a Grammarly alternative?", "It does a similar job of marking mistakes, but its main aim is teaching: it keeps your tone, explains the rule, links the research, and runs on a local model instead of a cloud service."),
 ("Can I contribute or report a bug?", f"Yes. The code is on <a href='{SRC}'>GitHub</a>. Open an issue for bugs. Do not paste private text into public issues."),
]
faq = '<section id="faq"><div class="wrap" style="max-width:820px"><h2 class="center">Questions</h2>' + ''.join(f'<details><summary>{q}</summary><p>{a}</p></details>' for q, a in faqs) + '</div></section>'
final = f'<div class="final"><h2>Write better, starting with your next message.</h2><p class="lede">Free, open source and private by design.</p><div class="cta"><a class="btn cream dl" href="{DMG}" data-dl>Download for Mac</a><a class="btn cream" style="background:transparent;color:#f7f6f3!important;border-color:#555" href="/extension/">Add to Chrome</a></div><p class="fine" style="color:#b9b8b3">macOS 14 or later · {R["size_mb"]} MB</p></div>'

import re as _re
_faq=[{"@type":"Question","name":q,"acceptedAnswer":{"@type":"Answer","text":_re.sub('<[^>]+>','',x)}} for q,x in faqs]
schema = {"@context": "https://schema.org", "@graph": [
  {"@type": "WebSite", "@id": SITE + "/#website", "url": SITE + "/", "name": "HeyHumanly", "alternateName": ["Hey Humanly", "heyhumanly.com"]},
  {"@type": "SoftwareApplication", "@id": SITE + "/#app", "name": "HeyHumanly", "alternateName": ["Hey Humanly", "HeyHumanly Mac"], "operatingSystem": "macOS 14 or later, Chrome",
   "applicationCategory": "EducationalApplication", "softwareVersion": V, "downloadUrl": DMG, "license": "https://opensource.org/license/mit",
   "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"}, "url": SITE + "/", "sameAs": [SRC],
   "description": "Free, open-source writing coach for Mac and Chrome that keeps your tone, trims filler and extra words, and explains the habit behind each change with research, using a local AI model.",
   "author": {"@type": "Person", "name": "Kifayath", "sameAs": "https://github.com/Kifayath-ulla"},
   "contributor": [{"@type": "Thing", "name": "Claude", "description": "AI Contributor"}, {"@type": "Thing", "name": "OpenBot", "description": "AI Contributor"}]},
  {"@type": "Organization", "@id": SITE + "/#org", "name": "HeyHumanly", "url": SITE, "logo": SITE + "/apple-touch-icon.png", "sameAs": [SRC]},
  {"@type": "FAQPage", "mainEntity": _faq}]}
page('/', 'HeyHumanly: free writing coach for Mac and Chrome',
     'Free, open-source writing coach for Mac and Chrome. Keeps your tone, trims filler, and explains every change with research. Runs on a local AI model.',
     hero + how + setup + manifesto + privacy + limits + faq + final, schema)

ext_page = f"""
<section style="padding-top:140px"><div class="wrap" style="max-width:820px"><span class="badge g">New</span><h1 style="margin-left:0;text-align:left;font-size:clamp(34px,5vw,56px)">HeyHumanly for Chrome</h1>
<p class="lede" style="margin-left:0;text-align:left">Select text in any text box on the web and get the same tone-keeping edit, with the reason and the research behind it. It uses the model already running on your computer, so your writing never leaves it.</p>
<div class="cta" style="justify-content:flex-start"><a class="btn" href="{EXT}">Download the extension (zip)</a><a class="btn ghost" href="{SRC}/tree/main/extension">View source</a></div>
<p class="fine" style="text-align:left">Version {V} · free · MIT · Chrome and other Chromium browsers</p>
<h2 id="setup" style="margin-top:44px;font-size:32px">Set it up in two minutes</h2>
<ol class="steps">
<li><h3>Install Ollama and a model</h3><p>The Mac app can do this for you. Or install <a href="https://ollama.com/download">Ollama</a> and run <code>ollama pull qwen2.5:3b</code>.</p></li>
<li><h3>Let Chrome talk to Ollama</h3><p>Easiest: open the HeyHumanly Mac app, go to <b>Settings → Chrome extension</b> and press <b>Allow</b>. It restarts Ollama once and keeps the setting after a restart. No Mac app? In Terminal run <code>launchctl setenv OLLAMA_ORIGINS "chrome-extension://*"</code>, then quit and reopen Ollama.</p></li>
<li><h3>Load the extension</h3><p>Unzip the download. Open <code>chrome://extensions</code>, switch on <b>Developer mode</b>, choose <b>Load unpacked</b> and pick the unzipped folder. A Chrome Web Store listing will come later.</p></li>
<li><h3>Try it</h3><p>Click into any text box, select your text and press <kbd>Alt</kbd> + <kbd>Shift</kbd> + <kbd>H</kbd>, or click the HeyHumanly button that appears.</p></li></ol>
<div class="ok" style="margin-top:22px"><b>Private by design.</b> The extension has no server, no account and no analytics. It sends your selected text only to the Ollama address on your own computer. It reads a text box only when you ask it to.</div>
<h2 style="margin-top:40px;font-size:30px">What it does</h2>
<div class="grid" style="grid-template-columns:1fr 1fr"><div class="card"><h3>Keeps your tone</h3><p>Casual stays casual. Only filler, repeats and extra words are trimmed.</p></div><div class="card"><h3>Shows why</h3><p>Each change names the habit and links the study behind the tip.</p></div><div class="card"><h3>Checks offline</h3><p>Wordy phrases, passive voice and repeated openers are found instantly, even without the model.</p></div><div class="card"><h3>You decide</h3><p>Apply, copy or dismiss. Nothing changes unless you click.</p></div></div>
<p class="fine" style="margin-top:20px">Back to the <a href="/">home page</a> · <a href="/install/">Mac app install help</a></p></div></section>"""
page('/extension/', 'HeyHumanly for Chrome: a tone-keeping writing coach for any text box',
     'Free Chrome extension that tightens what you write on any website, keeps your tone, and explains each change with research. Runs on your local Ollama model.', ext_page)

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
<h2 id="extension">In the Chrome extension</h2><ul>
<li><b>Read:</b> only when you press <code>Alt+Shift+H</code>, click the HeyHumanly button or choose <b>Tighten with HeyHumanly</b> from the right-click menu. Then it reads the text you selected, or the text box you are in, on that one tab. No script runs on pages before that.</li>
<li><b>Sent:</b> only to Ollama on this computer, <code>http://localhost:11434</code> or <code>http://127.0.0.1:11434</code>. The extension's permissions do not allow any other address.</li>
<li><b>Stored:</b> your settings (the Ollama address and model) in Chrome's local extension storage. Your writing is not stored.</li>
<li><b>Clipboard:</b> written only when you press <b>Copy</b>, or when <b>Apply</b> cannot replace the text in place.</li>
<li><b>Network:</b> no analytics, accounts, tracking, remote code or HeyHumanly server. The setup page's model download is done by Ollama.</li>
<li><b>Remove:</b> remove the extension from <code>chrome://extensions</code>; that deletes its settings.</li></ul>
<h2>Outside the app</h2><ul>
<li><b>Ollama and the model:</b> downloaded by Ollama from its model library. Ollama's own privacy terms apply to that download.</li>
<li><b>This website:</b> is hosted on Cloudflare, which keeps standard server logs. The site sets no cookies and loads no analytics or third-party scripts.</li>
<li><b>The DMG:</b> is hosted on GitHub Releases, which GitHub operates.</li>
<li><b>The Chrome extension:</b> is installed through the Chrome Web Store, which Google operates.</li></ul>
<h2>Report a security problem</h2><p>Open a private advisory on <a href="{SRC}/security/advisories/new">GitHub</a>. Please do not post private text in public issues.</p></div></section>"""
page('/privacy/', 'HeyHumanly privacy: what it reads, stores and sends',
     'What the HeyHumanly Mac app and Chrome extension read, store and send, based on the source code: local model by default, no account, no analytics, no tracking.', priv)


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

ga = f"""<section style="padding-top:140px"><div class="wrap" style="max-width:820px"><span class="eyebrow">Comparison</span><h1 style="margin-left:0;text-align:left;font-size:clamp(32px,5vw,54px)">A Grammarly alternative that keeps your tone and runs on your computer</h1>
<p class="lede" style="margin-left:0;text-align:left">Grammarly is a polished tool, and for many people it is the right one. HeyHumanly is built for a different job: keeping your voice, teaching you why a change helps, and never sending your writing to a server.</p>
<h2 style="font-size:30px;margin-top:34px">The short comparison</h2>
<table><tr><th></th><td><b>HeyHumanly</b></td><td><b>Cloud grammar tools</b></td></tr>
<tr><th>Where text goes</th><td>A model on your own computer (Ollama). Nothing is uploaded.</td><td>Sent to the company's servers to be checked.</td></tr>
<tr><th>Your tone</th><td>Kept. Casual stays casual; only filler, repeats and extra words are trimmed.</td><td>Varies by tool and setting. Many push towards a polished, formal register.</td></tr>
<tr><th>Explains why</th><td>Names the habit, quotes your words, links the study behind the tip.</td><td>Usually shows the fix and a short rule.</td></tr>
<tr><th>Price</th><td>Free and open source (MIT). No account.</td><td>Free tier plus paid plans.</td></tr>
<tr><th>Platforms</th><td>Mac app and Chrome extension.</td><td>Most platforms and apps.</td></tr>
<tr><th>Grammar depth</th><td>Good, not exhaustive. Depends on the model you run.</td><td>Mature, large rule sets and years of tuning.</td></tr></table>
<h2 style="font-size:30px;margin-top:38px">Who HeyHumanly is for</h2>
<p style="color:var(--mute)">People who want to get better at writing, not just have sentences fixed. People who write things they would not want on someone else's server. People who find formal rewrites sound unlike them.</p>
<h2 style="font-size:30px;margin-top:30px">Who should stay with a cloud tool</h2>
<p style="color:var(--mute)">If you need deep grammar coverage across Windows, mobile and Office apps, or team features and style guides, HeyHumanly does not replace that today. It also needs a local model, which takes disk space and a few minutes to download.</p>
<div class="cta" style="justify-content:flex-start;margin-top:26px">{dl}<a class="btn ghost" href="/extension/">Add to Chrome</a></div>
<p class="fine" style="text-align:left;margin-top:18px">See also: <a href="/private-writing-assistant/">private writing assistant</a> · <a href="/writing-habits/">writing habits guide</a> · <a href="/">home</a></p></div></section>"""
page('/grammarly-alternative/', 'A free Grammarly alternative that keeps your tone | HeyHumanly',
     'Compare HeyHumanly with cloud grammar tools: it runs on your computer, keeps your tone, explains why, and is free and open source. See who it suits.', ga)

pw = f"""<section style="padding-top:140px"><div class="wrap" style="max-width:820px"><span class="eyebrow">Guide</span><h1 style="margin-left:0;text-align:left;font-size:clamp(32px,5vw,54px)">A private writing assistant: how to check your writing without uploading it</h1>
<p class="lede" style="margin-left:0;text-align:left">Most writing helpers send what you type to a server. If you write contracts, health notes, job applications, or just things you would rather keep private, there is another way: run the model on your own computer.</p>
<h2 style="font-size:30px;margin-top:30px">How a local writing assistant works</h2>
<ol class="steps"><li><h3>A model runs on your computer</h3><p>Tools like <a href="https://ollama.com">Ollama</a> download an open model and run it locally. Your text never leaves the machine, and it works offline once the model is downloaded.</p></li>
<li><h3>An app asks the model for an edit</h3><p>HeyHumanly sends your text only to the Ollama address on your own computer, by default <code>localhost</code>. It keeps your tone and trims filler, repeats and extra words.</p></li>
<li><h3>Rules explain the change</h3><p>The explanations come from fixed rules and your own words, not from guesses by the model, so each tip names a habit and links its source.</p></li></ol>
<h2 style="font-size:30px;margin-top:34px">What to check in any "private" tool</h2>
<ul style="color:var(--mute);margin:12px 0 0 20px;display:grid;gap:8px"><li>Does it work with the network turned off?</li><li>Is the source code public so you can see what it sends?</li><li>Does it need an account, and does it send analytics?</li><li>Where do saved sessions live, and can you delete them?</li></ul>
<p style="margin-top:14px">HeyHumanly's answers: yes it works offline after setup, the code is on <a href="{SRC}">GitHub</a>, there is no account or analytics, and sessions are stored in the app's preferences on your Mac and can be cleared in Settings. Read the full <a href="/privacy/">privacy page</a>.</p>
<h2 style="font-size:30px;margin-top:34px">Honest limits</h2>
<p style="color:var(--mute)">Local models are smaller than the biggest cloud models, so they miss some mistakes. The first setup downloads a model of 2 to 5 GB. In return, nothing you write is uploaded.</p>
<div class="cta" style="justify-content:flex-start;margin-top:26px">{dl}<a class="btn ghost" href="/local-ai-writing-coach-mac/">Local AI setup guide</a></div>
<p class="fine" style="text-align:left;margin-top:18px">See also: <a href="/grammarly-alternative/">Grammarly alternative</a> · <a href="/extension/">Chrome extension</a> · <a href="/">home</a></p></div></section>"""
page('/private-writing-assistant/', 'A private writing assistant that runs on your computer | HeyHumanly',
     'How to check and improve your writing without uploading it: run a local model, keep your tone, and see why each change helps. Free and open source.', pw)
nf = '<section style="border:0;text-align:center;padding:90px 0"><h1>Page not found</h1><p class="lede" style="margin-inline:auto">That page does not exist.</p><a class="btn" href="/">Go to the home page</a></section>'
page('/404.html', 'Page not found · HeyHumanly', 'Page not found.', nf, noindex=True, canonical='/')

open(os.path.join(OUT, 'robots.txt'), 'w').write(f"User-agent: *\nAllow: /\n\nSitemap: {SITE}/sitemap.xml\n")
urls = ['/', '/extension/', '/grammarly-alternative/', '/private-writing-assistant/', '/install/', '/writing-habits/', '/local-ai-writing-coach-mac/', '/privacy/']
open(os.path.join(OUT, 'sitemap.xml'), 'w').write('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + ''.join(f'<url><loc>{SITE}{u}</loc><lastmod>{R["date"]}</lastmod></url>\n' for u in urls) + '</urlset>\n')
# Staging hosts stay out of search; production is not affected.
open(os.path.join(OUT, '_headers'), 'w').write("/*\n  X-Content-Type-Options: nosniff\n  Referrer-Policy: strict-origin-when-cross-origin\n  Content-Security-Policy: default-src 'self'; img-src 'self' data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'self'; form-action 'none'\n\n/fonts/*\n  Cache-Control: public, max-age=31536000, immutable\n\n/*.png\n  Cache-Control: public, max-age=604800\n")
open(os.path.join(OUT, KEY + '.txt'), 'w').write(KEY)
open(os.path.join(OUT, 'llms.txt'), 'w').write(f"""# HeyHumanly

> Free, open-source writing coach for Mac and Chrome. It keeps the writer's tone, trims filler, repeated words and extra words, and explains the habit behind each change with research. It runs on a local AI model (Ollama) on the user's own computer.

## Quick links

- [Website]({SITE}/)
- [Chrome extension]({SITE}/extension/)
- [Install help]({SITE}/install/)
- [Privacy]({SITE}/privacy/)
- [Writing habits guide]({SITE}/writing-habits/)
- [Source code]({SRC})
- [Releases]({SRC}/releases)
- [License (MIT)]({SRC}/blob/main/LICENSE)

## What it is

A teaching-first alternative to cloud writing tools. Casual messages stay casual. Each suggestion names the writing habit, quotes the writer's own words, and links the study behind the tip (Nielsen Norman Group on concise writing, Oppenheimer 2006 on plain writing, Hosman on hedging). Where evidence is mixed, it says so.

## Key details

- Version: {V}
- License: MIT
- Platforms: macOS 14+ app, Chrome extension
- Models: any model installed in Ollama
- Privacy: no account, no analytics, no cloud; text goes only to the user's local Ollama address
""")
open(os.path.join(OUT, 'BingSiteAuth.xml'), 'w').write('<?xml version="1.0"?>\n<users>\n\t<user>7214F04580277B31B88F4F83CF229AA0</user>\n</users>')
open(os.path.join(OUT, 'googlee5c1608434939199.html'), 'w').write('google-site-verification: googlee5c1608434939199.html')
print('site built', V)
