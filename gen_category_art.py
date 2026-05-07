#!/usr/bin/env python3
"""Generates minimalist white-on-transparent artwork for each Fellowship category."""

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
    contents = f'''{{\n  "images":[{{"filename":"{name}.png","idiom":"universal","scale":"1x"}}],\n  "info":{{"author":"xcode","version":1}}\n}}\n'''
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        f.write(contents)
    print(f"  {name} ✓")

def soft(img, r=2):
    return img.filter(ImageFilter.GaussianBlur(r))

WHITE = (255, 255, 255, 220)
DIM   = (255, 255, 255, 140)

# ── 1. Shopping bag ──────────────────────────────────────────────
def make_shopping():
    img = new_canvas(); d = ImageDraw.Draw(img)

    # Bag body — rounded rect, wider at base
    bx, by, bw, bh = 136, 200, 240, 260
    d.rounded_rectangle([bx, by, bx+bw, by+bh], radius=28, fill=WHITE)

    # Handle cutout highlight — two arcs as filled ellipses overlapping
    h_cx = MID
    for ox in (-56, 56):
        arc_box = [h_cx + ox - 44, by - 90, h_cx + ox + 44, by + 30]
        # draw thick arc by nested ellipses
        d.ellipse(arc_box, outline=WHITE, width=18)

    # Small heart on bag
    hx, hy, hs = MID, by + bh//2 - 10, 38
    pts = []
    for deg in range(360):
        t = math.radians(deg)
        x = 16 * math.sin(t)**3
        y = -(13*math.cos(t) - 5*math.cos(2*t) - 2*math.cos(3*t) - math.cos(4*t))
        pts.append((hx + x*hs/16, hy + y*hs/16))
    d2 = ImageDraw.Draw(img)
    # Draw heart as dark cutout so it shows against white bag
    dark_heart = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    dh = ImageDraw.Draw(dark_heart)
    dh.polygon(pts, fill=(180, 90, 40, 200))
    img = Image.alpha_composite(img, dark_heart)
    return soft(img)

# ── 2. Mountains (Resor) ─────────────────────────────────────────
def make_resor():
    img = new_canvas(); d = ImageDraw.Draw(img)

    # Three mountain peaks — clean triangles, no snow caps (snow caps looked like trees)
    peaks = [
        [(MID, 90),      (MID-175, 390), (MID+175, 390)],  # centre, tallest
        [(MID-130, 185), (MID-290, 390), (MID+10,  390)],  # left
        [(MID+145, 200), (MID-10,  390), (MID+295, 390)],  # right
    ]
    alphas = [220, 130, 130]
    for pts, a in zip(peaks, alphas):
        d.polygon(pts, fill=(255,255,255,a))

    # Moon
    d.ellipse([MID+140, 60, MID+220, 140], fill=(255,255,255,200))
    # Moon crescent cutout
    d.ellipse([MID+155, 50, MID+230, 130], fill=(0,0,0,0))

    return soft(img)

# ── 3. Coins (Ekonomi) ──────────────────────────────────────────
def make_ekonomi():
    img = new_canvas(); d = ImageDraw.Draw(img)

    coins = 4
    coin_w, coin_h = 280, 60
    gap   = 52
    start_y = MID - (coins * gap) // 2 + 20

    for i in range(coins):
        y = start_y + i * gap
        alpha = 180 + i * 12
        # Coin face
        d.ellipse([MID - coin_w//2, y, MID + coin_w//2, y + coin_h],
                  fill=(255,255,255,alpha))
        # Shine line
        d.ellipse([MID - coin_w//2 + 20, y + 10, MID - coin_w//2 + 80, y + 26],
                  fill=(255,255,255,80))

    # Sparkle on top coin
    sy = start_y - 28
    for angle in range(0, 360, 45):
        t = math.radians(angle)
        x1, y1 = MID + math.cos(t)*18, sy + math.sin(t)*18
        x2, y2 = MID + math.cos(t)*36, sy + math.sin(t)*36
        d.line([(x1,y1),(x2,y2)], fill=(255,255,255,160), width=4)

    return soft(img)

# ── 4. Key (Koder & Info) ────────────────────────────────────────
def make_koder():
    img = new_canvas(); d = ImageDraw.Draw(img)

    # Key head — ring
    kx, ky = 170, MID
    r_outer, r_inner = 100, 58
    d.ellipse([kx-r_outer, ky-r_outer, kx+r_outer, ky+r_outer], fill=(255,255,255,220))
    d.ellipse([kx-r_inner, ky-r_inner, kx+r_inner, ky+r_inner], fill=(0,0,0,0))

    # Key shaft
    shaft_x0, shaft_y0 = kx + r_outer - 10, ky - 28
    shaft_x1, shaft_y1 = MID + 180, ky + 28
    d.rounded_rectangle([shaft_x0, shaft_y0, shaft_x1, shaft_y1], radius=18, fill=(255,255,255,220))

    # Teeth (two notches cut into shaft bottom)
    for tx in [shaft_x1 - 70, shaft_x1 - 120]:
        d.rounded_rectangle([tx, ky + 28, tx + 36, ky + 72], radius=10, fill=(255,255,255,220))

    return soft(img)

# ── 5. Binoculars (Discover) ────────────────────────────────────
def make_discover():
    img = new_canvas(); d = ImageDraw.Draw(img)

    r = 108
    lx, rx, cy = MID - 105, MID + 105, MID + 10

    # Outer lens rings
    for cx in (lx, rx):
        d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(255,255,255,200))
        # Inner lens
        d.ellipse([cx-r+22, cy-r+22, cx+r-22, cy+r-22], fill=(255,255,255,60))
        # Lens glint
        d.ellipse([cx-r+30, cy-r+30, cx-r+66, cy-r+66], fill=(255,255,255,160))

    # Bridge connecting the two lenses
    bridge_y = cy - 26
    d.rounded_rectangle([lx + r - 16, bridge_y, rx - r + 16, bridge_y + 52],
                         radius=16, fill=(255,255,255,220))

    # Eye-piece tops
    for cx in (lx, rx):
        d.rounded_rectangle([cx - 38, cy - r - 40, cx + 38, cy - r + 14],
                             radius=12, fill=(255,255,255,200))

    return soft(img)

# ── 6. Cooking pot (Recept) ─────────────────────────────────────
def make_recept():
    img = new_canvas(); d = ImageDraw.Draw(img)

    # Pot body
    px, py, pr = MID, MID + 50, 140
    d.ellipse([px-pr, py-pr, px+pr, py+pr], fill=(255,255,255,210))
    # Darker interior suggestion
    d.ellipse([px-pr+20, py-pr+20, px+pr-20, py+pr-20], fill=(255,255,255,60))

    # Lid
    lid_w, lid_h = 240, 48
    d.rounded_rectangle([px - lid_w//2, py - pr - 22, px + lid_w//2, py - pr + lid_h],
                         radius=20, fill=(255,255,255,220))
    # Lid knob
    d.ellipse([px-20, py-pr-46, px+20, py-pr-8], fill=(255,255,255,220))

    # Handles — explicit symmetric coords to guarantee equal width
    gap, hw = 12, 52
    d.rounded_rectangle([px + pr + gap,      py - 48, px + pr + gap + hw, py + 48],
                         radius=16, fill=(255,255,255,200))
    d.rounded_rectangle([px - pr - gap - hw, py - 48, px - pr - gap,      py + 48],
                         radius=16, fill=(255,255,255,200))

    # Steam lines (3 wavy arcs)
    for i, ox in enumerate((-52, 0, 52)):
        sx = px + ox
        sy0 = py - pr - 70
        pts = []
        for step in range(40):
            t = step / 39
            wx = sx + math.sin(t * math.pi * 2) * 16
            wy = sy0 - t * 90
            pts.append((wx, wy))
        for j in range(len(pts)-1):
            d.line([pts[j], pts[j+1]], fill=(255,255,255,int(180*(1-j/39))), width=8)

    return soft(img)

# ── Generate all ────────────────────────────────────────────────
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
