#!/usr/bin/env python3
"""Draws the HeyHumanly icon (silver speech-bubble mascot on graphite) and exports icns, png and og assets."""
import os, subprocess, math
from PIL import Image, ImageDraw, ImageFilter, ImageFont
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 4096  # supersample canvas
def vgrad(w, h, top, bot):
    g = Image.new('RGB', (1, h))
    for y in range(h):
        t = y / (h - 1); g.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return g.resize((w, h))
def squircle_mask(size, r):
    m = Image.new('L', (size, size), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, size - 1, size - 1), r, fill=255); return m
def icon(out=1024, pad=0.0, mono_bg=True):
    base = vgrad(S, S, (0x3a, 0x3c, 0x42), (0x14, 0x14, 0x17)).convert('RGBA')
    d = ImageDraw.Draw(base)
    # soft top highlight
    hl = Image.new('RGBA', (S, S), (0, 0, 0, 0)); ImageDraw.Draw(hl).ellipse((-S*0.2, -S*0.7, S*1.2, S*0.45), fill=(255, 255, 255, 14))
    base = Image.alpha_composite(base, hl.filter(ImageFilter.GaussianBlur(S*0.09)))
    # bubble with tail
    bx0, by0, bx1, by1 = S*0.18, S*0.21, S*0.82, S*0.69
    bub = Image.new('RGBA', (S, S), (0, 0, 0, 0)); bd = ImageDraw.Draw(bub)
    bd.rounded_rectangle((bx0, by0, bx1, by1), S*0.17, fill=(255, 255, 255, 255))
    bd.polygon([(S*0.30, by1 - S*0.02), (S*0.25, S*0.80), (S*0.46, by1 - S*0.02)], fill=(255, 255, 255, 255))
    # silver gradient fill
    sil = vgrad(S, S, (0xf7, 0xf7, 0xf8), (0xc4, 0xc6, 0xcc)).convert('RGBA'); sil.putalpha(bub.split()[3])
    sh = Image.new('RGBA', (S, S), (0, 0, 0, 0)); ImageDraw.Draw(sh).bitmap((0, S*0.018), bub.split()[3], fill=(0, 0, 0, 120))
    base = Image.alpha_composite(base, sh.filter(ImageFilter.GaussianBlur(S*0.02)))
    base = Image.alpha_composite(base, sil)
    # slanted eyes
    eye = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    for cx, ang in ((S*0.385, 0), (S*0.615, 0)):
        e = Image.new('RGBA', (int(S*0.2), int(S*0.2)), (0, 0, 0, 0))
        ImageDraw.Draw(e).rounded_rectangle((e.width*0.30, e.height*0.16, e.width*0.70, e.height*0.84), e.width*0.20, fill=(0x16, 0x16, 0x19, 255))
        e = e.rotate(ang, resample=Image.BICUBIC)
        eye.alpha_composite(e, (int(cx - e.width/2), int(S*0.36 - e.height/2)))
    base = Image.alpha_composite(base, eye)
    # smile
    sm = Image.new('RGBA', (S, S), (0, 0, 0, 0)); ImageDraw.Draw(sm).arc((S*0.41, S*0.40, S*0.59, S*0.58), 20, 160, fill=(0x16, 0x16, 0x19, 255), width=int(S*0.026))
    base = Image.alpha_composite(base, sm)
    mask = squircle_mask(S, int(S*0.225))
    base.putalpha(mask)
    if pad:
        c = Image.new('RGBA', (S, S), (0, 0, 0, 0)); k = int(S*(1-2*pad)); c.paste(base.resize((k, k), Image.LANCZOS), (int(S*pad), int(S*pad))); base = c
    return base.resize((out, out), Image.LANCZOS)
res = os.path.join(ROOT, 'Resources')
big = icon(1024, pad=0.0)
big.save(os.path.join(res, 'HeyHumanlyIcon.png')); big.save(os.path.join(res, 'HeyHumanlyIcon_mono.png'))
iset = os.path.join(ROOT, 'work', 'HeyHumanly.iconset'); os.makedirs(iset, exist_ok=True)
for n in (16, 32, 128, 256, 512):
    icon(n).save(f'{iset}/icon_{n}x{n}.png'); icon(n*2).save(f'{iset}/icon_{n}x{n}@2x.png')
subprocess.run(['iconutil', '-c', 'icns', iset, '-o', os.path.join(res, 'HeyHumanly.icns')], check=True)
sd = os.path.join(ROOT, 'site-src')
icon(64).save(f'{sd}/favicon.png'); icon(192).save(f'{sd}/icon-192.png'); icon(180).save(f'{sd}/apple-touch-icon.png')
# social card
card = vgrad(1200, 630, (0x26, 0x27, 0x2b), (0x0e, 0x0e, 0x10)).convert('RGBA')
card.alpha_composite(icon(220), (90, 150))
d = ImageDraw.Draw(card)
def font(sz, bold=True):
    for p in ('/System/Library/Fonts/SFNS.ttf', '/System/Library/Fonts/Helvetica.ttc'):
        try: return ImageFont.truetype(p, sz)
        except Exception: pass
    return ImageFont.load_default()
d.text((350, 170), 'HeyHumanly', font=font(92), fill=(245, 245, 247))
d.text((350, 290), 'Say it better. Learn why.', font=font(52), fill=(190, 192, 198))
d.text((350, 380), 'Free Mac writing coach. Runs on your Mac.', font=font(34), fill=(140, 142, 150))
card.convert('RGB').save(f'{sd}/og.png')
print('icons done')
