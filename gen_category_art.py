#!/usr/bin/env python3
"""Fellowship category artwork — clean flat silhouettes, light fill on transparent bg."""

import math, os
from PIL import Image, ImageDraw, ImageFilter

SIZE = 512
MID  = SIZE // 2

BASE = os.path.dirname(os.path.abspath(__file__))
OUT  = os.path.join(BASE, "Ours", "Assets.xcassets")

def new_canvas():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

def save(img, name):
    folder = os.path.join(OUT, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, f"{name}.png"))
    contents = f'{{\n  "images":[{{"filename":"{name}.png","idiom":"universal","scale":"1x"}}],\n  "info":{{"author":"xcode","version":1}}\n}}\n'
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        f.write(contents)
    print(f"  {name} ✓")

def soft(img, r=1.2):
    return img.filter(ImageFilter.GaussianBlur(r))

# Shared light fill — semi-transparent white/cream, reads over any card colour
FILL  = (255, 248, 240, 210)
FILL2 = (255, 248, 240, 140)  # lighter secondary shapes

def heart_pts(cx, cy, size):
    pts = []
    for deg in range(360):
        t = math.radians(deg)
        x = 16 * math.sin(t) ** 3
        y = -(13*math.cos(t) - 5*math.cos(2*t) - 2*math.cos(3*t) - math.cos(4*t))
        pts.append((cx + x*size/16, cy + y*size/16))
    return pts

# ── 1. Shopping bag ──────────────────────────────────────────────
def make_shopping():
    img = new_canvas()
    d = ImageDraw.Draw(img)

    # Bag body
    d.rounded_rectangle([164, 210, 348, 390], radius=22, fill=FILL)

    # Handles (two arcs drawn as thick strokes)
    for cx in (MID - 46, MID + 46):
        d.arc([cx - 34, 148, cx + 34, 230], start=200, end=340, fill=FILL, width=22)

    # Heart
    heart = new_canvas(); dh = ImageDraw.Draw(heart)
    dh.polygon(heart_pts(MID, 304, 44), fill=(255, 220, 200, 160))
    img = Image.alpha_composite(img, heart)

    return soft(img)

# ── 2. Mountains + moon ──────────────────────────────────────────
def make_resor():
    img = new_canvas()
    d = ImageDraw.Draw(img)

    BY = 392  # base y

    # Back peaks (lighter) — drawn first
    d.polygon([(130, 205), (10,  BY), (298, BY)], fill=FILL2)
    d.polygon([(384, 215), (212, BY), (500, BY)], fill=FILL2)

    # Main centre peak — wide base so it reads as mountain not tree
    d.polygon([(MID, 142), (44, BY), (468, BY)], fill=FILL)

    # Moon
    d.ellipse([MID + 128, 78, MID + 184, 134], fill=FILL)

    return soft(img)

# ── 3. Credit card ───────────────────────────────────────────────
def make_ekonomi():
    img = new_canvas()
    d = ImageDraw.Draw(img)

    # Card body
    d.rounded_rectangle([110, 175, 400, 337], radius=22, fill=FILL)

    # Magnetic stripe
    d.rectangle([110, 215, 400, 258], fill=(255, 248, 240, 100))

    # Chip
    d.rounded_rectangle([148, 270, 206, 310], radius=7, fill=(255, 248, 240, 120))

    return soft(img)

# ── 4. Key ───────────────────────────────────────────────────────
def make_koder():
    img = new_canvas()
    d = ImageDraw.Draw(img)

    kx, ky = 172, MID
    ro, ri = 96, 58

    # Key ring
    d.ellipse([kx - ro, ky - ro, kx + ro, ky + ro], fill=FILL)
    d.ellipse([kx - ri, ky - ri, kx + ri, ky + ri], fill=(0, 0, 0, 0))

    # Shaft
    sx0 = kx + ro - 10
    sx1 = MID + 190
    d.rectangle([sx0, ky - 22, sx1, ky + 22], fill=FILL)

    # Teeth
    for tx in [sx1 - 50, sx1 - 100]:
        d.rectangle([tx, ky + 22, tx + 28, ky + 60], fill=FILL)

    return soft(img)

# ── 5. Binoculars ────────────────────────────────────────────────
def make_discover():
    img = new_canvas()
    d = ImageDraw.Draw(img)

    r  = 96
    lx = MID - 106
    rx = MID + 106
    cy = MID + 20

    # Two barrels
    for cx in (lx, rx):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=FILL)
        # Inner lens ring (darker hole)
        d.ellipse([cx - r + 26, cy - r + 26, cx + r - 26, cy + r - 26],
                  fill=(255, 248, 240, 70))

    # Bridge
    bw = rx - r - lx - r
    d.rounded_rectangle([lx + r - 4, cy - 20, rx - r + 4, cy + 20],
                        radius=12, fill=FILL)

    # Top eyecups
    for cx in (lx, rx):
        d.rounded_rectangle([cx - 36, cy - r - 40, cx + 36, cy - r + 10],
                             radius=12, fill=FILL)

    return soft(img)

# ── 6. Cooking pot ───────────────────────────────────────────────
def make_recept():
    img = new_canvas()
    d = ImageDraw.Draw(img)

    px, py = MID, MID + 40
    pw, ph = 200, 160

    # Pot body
    d.rounded_rectangle([px - pw//2, py - ph//2, px + pw//2, py + ph//2],
                        radius=28, fill=FILL)

    # Lid
    d.rounded_rectangle([px - pw//2 + 10, py - ph//2 - 30, px + pw//2 - 10, py - ph//2 + 14],
                        radius=14, fill=FILL)
    # Lid knob
    d.ellipse([px - 18, py - ph//2 - 52, px + 18, py - ph//2 - 20], fill=FILL)

    # Handles
    for sign in (-1, 1):
        hx = px + sign * (pw//2 + 8)
        x0 = min(hx - 4, hx + sign * 42)
        x1 = max(hx - 4, hx + sign * 42)
        d.rounded_rectangle([x0, py - 34, x1, py + 34], radius=14, fill=FILL)

    # Heart
    heart = new_canvas(); dh = ImageDraw.Draw(heart)
    dh.polygon(heart_pts(px, py + 14, 38), fill=(255, 220, 200, 160))
    img = Image.alpha_composite(img, heart)

    # Steam
    d = ImageDraw.Draw(img)
    for ox in (-44, 0, 44):
        sx = px + ox
        sy0 = py - ph//2 - 60
        pts = []
        for step in range(20):
            frac = step / 19
            pts.append((sx + math.sin(frac * math.pi * 2) * 10, sy0 - frac * 52))
        for j in range(len(pts) - 1):
            a = int(130 * (1 - j / 19))
            d.line([pts[j], pts[j+1]], fill=(255, 248, 240, a), width=6)

    return soft(img)


# ── Generate ─────────────────────────────────────────────────────
for name, fn in [
    ("art-shopping", make_shopping),
    ("art-resor",    make_resor),
    ("art-ekonomi",  make_ekonomi),
    ("art-koder",    make_koder),
    ("art-discover", make_discover),
    ("art-recept",   make_recept),
]:
    save(fn(), name)

print("All category artwork generated.")
