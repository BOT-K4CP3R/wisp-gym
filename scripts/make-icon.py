#!/usr/bin/env python3
"""Generates the Wisp Gym launcher icon (background + foreground layers) with Pillow.
Usage: python3 scripts/make-icon.py   (needs `pip install pillow`)
Draws at 2x and downsamples for smooth edges; no external assets."""
from PIL import Image, ImageDraw, ImageFilter
import math

N, W, S = 1024, 2048, 2

def radial(size, center, radius, stops):
    im = Image.new('RGBA', (size, size)); px = im.load(); cx, cy = center
    for y in range(size):
        for x in range(size):
            d = min(1, math.hypot(x - cx, y - cy) / radius)
            for i in range(len(stops) - 1):
                t0, c0 = stops[i]; t1, c1 = stops[i + 1]
                if t0 <= d <= t1:
                    k = (d - t0) / (t1 - t0) if t1 > t0 else 0
                    px[x, y] = tuple(int(c0[j] + (c1[j] - c0[j]) * k) for j in range(4)); break
    return im

def B(x0, y0, x1, y1): return (x0 * S, y0 * S, x1 * S, y1 * S)

# background: flat charcoal (matches the app's surfaces), no gradient
bg = Image.new('RGBA', (N, N), (28, 29, 36, 255))

fg = Image.new('RGBA', (W, W), (0, 0, 0, 0))

def shaded_ellipse(box, c_light, c_base, c_dark):
    x0, y0, x1, y1 = box; w, h = x1 - x0, y1 - y0
    mask = Image.new('L', (W, W), 0); ImageDraw.Draw(mask).ellipse(box, fill=255)
    g = radial(W, ((x0 + x1) / 2 - 0.25 * w, (y0 + y1) / 2 - 0.3 * h), max(w, h) * 0.85,
               [(0, c_light + (255,)), (0.5, c_base + (255,)), (1, c_dark + (255,))])
    layer = Image.new('RGBA', (W, W), (0, 0, 0, 0)); layer.paste(g, (0, 0), mask); return layer

base, light, dark, deep = (244, 138, 110), (255, 196, 160), (205, 84, 86), (168, 62, 76)
for box in (B(170, 520, 330, 800), B(694, 520, 854, 800)):
    fg = Image.alpha_composite(fg, shaded_ellipse(box, (230, 110, 100), dark, deep))
fg = Image.alpha_composite(fg, shaded_ellipse(B(250, 540, 774, 980), light, base, dark))
fg = Image.alpha_composite(fg, shaded_ellipse(B(250, 200, 774, 700), light, base, dark))

belly = Image.new('RGBA', (W, W), (0, 0, 0, 0))
ImageDraw.Draw(belly).ellipse(B(350, 650, 674, 920), fill=(255, 226, 205, 170))
fg = Image.alpha_composite(fg, belly.filter(ImageFilter.GaussianBlur(8)))

# the "wisp": a smooth curling flame made of shrinking circles along a curve
tuft = Image.new('RGBA', (W, W), (0, 0, 0, 0)); td = ImageDraw.Draw(tuft)
for i in range(61):
    t = i / 60
    x, y = 512 + 34 * math.sin(t * 2.4) * t, 232 - 176 * t
    r = 54 * (1 - t) ** 0.75 + 3
    td.ellipse(((x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S), fill=(255, int(210 + 20 * t), int(150 + 60 * t), 255))
fg = Image.alpha_composite(fg, tuft.filter(ImageFilter.GaussianBlur(2)))

cheeks = Image.new('RGBA', (W, W), (0, 0, 0, 0)); cd = ImageDraw.Draw(cheeks)
cd.ellipse(B(290, 440, 380, 490), fill=(255, 110, 150, 120)); cd.ellipse(B(644, 440, 734, 490), fill=(255, 110, 150, 120))
fg = Image.alpha_composite(fg, cheeks.filter(ImageFilter.GaussianBlur(8)))

d = ImageDraw.Draw(fg)
for x in (410, 614):
    d.ellipse(B(x - 52, 330, x + 52, 450), fill=(255, 255, 255, 255))
    d.ellipse(B(x - 26, 362, x + 26, 440), fill=(29, 26, 58, 255))
    d.ellipse(B(x - 22, 368, x - 4, 386), fill=(255, 255, 255, 255))
    d.ellipse(B(x + 6, 420, x + 16, 430), fill=(255, 255, 255, 255))
d.arc(B(432, 430, 592, 540), 20, 160, fill=(29, 26, 58, 255), width=22)
fg = fg.resize((N, N), Image.LANCZOS)

for p in ('AppScope/resources/base/media/', 'entry/src/main/resources/base/media/'):
    bg.save(p + 'background.png'); fg.save(p + 'foreground.png')
fg.resize((256, 256), Image.LANCZOS).save('entry/src/main/resources/base/media/startIcon.png')
Image.alpha_composite(bg, fg).resize((512, 512), Image.LANCZOS).save('docs/app-icon.png')
print('icon written')
