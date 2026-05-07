#!/usr/bin/env python3
"""Generates Fellowship app icon — heart with list lines, warm orange→green gradient."""

import math, os
from PIL import Image, ImageDraw, ImageFilter

SIZE   = 1024
HALF   = SIZE // 2

# ── Warm gradient background ─────────────────────────────────────
img = Image.new("RGBA", (SIZE, SIZE))
draw = ImageDraw.Draw(img)

top_col    = (255, 112, 50)   # vivid orange
bottom_col = (40,  185, 110)  # vivid green

for y in range(SIZE):
    t = y / (SIZE - 1)
    r = int(top_col[0] + (bottom_col[0] - top_col[0]) * t)
    g = int(top_col[1] + (bottom_col[1] - top_col[1]) * t)
    b = int(top_col[2] + (bottom_col[2] - top_col[2]) * t)
    draw.line([(0, y), (SIZE - 1, y)], fill=(r, g, b, 255))

# ── Heart shape (parametric) ─────────────────────────────────────
cx, cy = HALF, HALF - 20
scale  = 270   # bigger

pts = []
for deg in range(360):
    t = math.radians(deg)
    x = 16 * math.sin(t) ** 3
    y = -(13 * math.cos(t) - 5 * math.cos(2*t) - 2 * math.cos(3*t) - math.cos(4*t))
    # same divisor for both axes = natural parametric proportions, no stretching
    pts.append((cx + x * scale / 16, cy + y * scale / 16))

# Soft white heart with slight transparency
heart_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
heart_draw  = ImageDraw.Draw(heart_layer)
heart_draw.polygon(pts, fill=(255, 255, 255, 245))

# Gentle drop shadow under heart
shadow_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
shadow_draw  = ImageDraw.Draw(shadow_layer)
shadow_pts   = [(x + 6, y + 10) for x, y in pts]
shadow_draw.polygon(shadow_pts, fill=(0, 0, 0, 60))
shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(18))

img = Image.alpha_composite(img.convert("RGBA"), shadow_layer)
img = Image.alpha_composite(img, heart_layer)

# ── List lines inside the heart ──────────────────────────────────
line_draw  = ImageDraw.Draw(img)
line_color = (210, 100, 45, 240)  # vivid terracotta, punchy on white
line_w     = 230
line_h     = 28
radius     = 14
offsets    = [-72, -8, 56]

for dy in offsets:
    lx0 = cx - line_w // 2
    ly0 = cy + dy - line_h // 2
    lx1 = lx0 + line_w
    ly1 = ly0 + line_h
    # Shorter first line (like a bold title)
    if dy == offsets[0]:
        lx0 += 30; lx1 -= 30
    line_draw.rounded_rectangle([lx0, ly0, lx1, ly1], radius=radius, fill=line_color)

# ── Export all required sizes ─────────────────────────────────────
ASSET_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "Ours", "Assets.xcassets", "AppIcon.appiconset"
)
os.makedirs(ASSET_DIR, exist_ok=True)

sizes = [1024, 512, 256, 180, 167, 152, 120, 87, 80, 76, 60, 58, 40, 29, 20]
files = []
for s in sizes:
    fname = f"icon_{s}.png"
    img.resize((s, s), Image.LANCZOS).save(os.path.join(ASSET_DIR, fname))
    files.append(fname)
    print(f"  {s}×{s}  ✓")

# ── Write Contents.json ──────────────────────────────────────────
contents = '''{
  "images" : [
    { "filename" : "icon_1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "filename" : "icon_180.png",  "idiom" : "iphone", "scale" : "3x", "size" : "60x60" },
    { "filename" : "icon_120.png",  "idiom" : "iphone", "scale" : "2x", "size" : "60x60" },
    { "filename" : "icon_87.png",   "idiom" : "iphone", "scale" : "3x", "size" : "29x29" },
    { "filename" : "icon_58.png",   "idiom" : "iphone", "scale" : "2x", "size" : "29x29" },
    { "filename" : "icon_80.png",   "idiom" : "iphone", "scale" : "2x", "size" : "40x40" },
    { "filename" : "icon_120.png",  "idiom" : "iphone", "scale" : "3x", "size" : "40x40" },
    { "filename" : "icon_167.png",  "idiom" : "ipad",   "scale" : "2x", "size" : "83.5x83.5" },
    { "filename" : "icon_152.png",  "idiom" : "ipad",   "scale" : "2x", "size" : "76x76" },
    { "filename" : "icon_76.png",   "idiom" : "ipad",   "scale" : "1x", "size" : "76x76" },
    { "filename" : "icon_80.png",   "idiom" : "ipad",   "scale" : "2x", "size" : "40x40" },
    { "filename" : "icon_40.png",   "idiom" : "ipad",   "scale" : "1x", "size" : "40x40" },
    { "filename" : "icon_58.png",   "idiom" : "ipad",   "scale" : "2x", "size" : "29x29" },
    { "filename" : "icon_29.png",   "idiom" : "ipad",   "scale" : "1x", "size" : "29x29" },
    { "filename" : "icon_20.png",   "idiom" : "ipad",   "scale" : "1x", "size" : "20x20" },
    { "filename" : "icon_40.png",   "idiom" : "ipad",   "scale" : "2x", "size" : "20x20" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
'''
with open(os.path.join(ASSET_DIR, "Contents.json"), "w") as f:
    f.write(contents)

print("Icon generated.")
