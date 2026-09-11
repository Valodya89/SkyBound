#!/usr/bin/env python3
"""Renders the SkyBound app icon (1024x1024) with Pillow. Run from the repo root."""
import math
from PIL import Image, ImageDraw, ImageFilter

S = 1024
img = Image.new("RGB", (S, S), "#14131A")
px = img.load()
# Dawn Valley sky gradient
stops = [(0.0, (0xFF, 0xE2, 0xB0)), (0.58, (0xFF, 0xB6, 0x94)), (1.0, (0xFF, 0x93, 0xA8))]
for y in range(S):
    t = y / (S - 1)
    for i in range(len(stops) - 1):
        a, ca = stops[i]; b, cb = stops[i + 1]
        if a <= t <= b:
            k = (t - a) / (b - a)
            col = tuple(int(ca[j] + (cb[j] - ca[j]) * k) for j in range(3))
            break
    for x in range(S):
        px[x, y] = col

d = ImageDraw.Draw(img, "RGBA")
# Sun with halo
halo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
hd = ImageDraw.Draw(halo)
hd.ellipse((S * 0.40, S * 0.10, S * 0.96, S * 0.66), fill=(255, 245, 215, 120))
halo = halo.filter(ImageFilter.GaussianBlur(70))
img.paste(halo, (0, 0), halo)
d = ImageDraw.Draw(img, "RGBA")
d.ellipse((S * 0.55, S * 0.24, S * 0.81, S * 0.50), fill=(255, 246, 220, 255))

# Hills
def hills(color, base, amp, n, phase):
    pts = [(-40, S)]
    for i in range(n + 1):
        x = -40 + i * (S + 80) / n
        pts.append((x, base - amp * (0.55 + 0.45 * math.sin(i * 1.7 + phase))))
        pts.append((x + (S + 80) / n * 0.5, base - amp * 0.5))
    pts.append((S + 40, S))
    d.polygon(pts, fill=color)

hills((0x8C, 0x3F, 0x64, 255), S * 0.62, S * 0.16, 6, 0.4)
hills((0xC4, 0x65, 0x7F, 255), S * 0.66, S * 0.12, 9, 2.1)

# Ground + road
d.rectangle((0, S * 0.64, S, S), fill=(0x4A, 0x1F, 0x3A, 255))
d.polygon([(S * 0.5, S * 0.64), (S * 0.02, S), (S * 0.98, S)], fill=(0x5C, 0x2C, 0x4F, 255))
for i in range(6):
    t0 = 0.07 + i * 0.16; t1 = t0 + 0.07
    def lane(t, off):
        return (S * 0.5 + off * (t / 1.0) * S * 0.36, S * 0.64 + t * S * 0.36)
    for off in (-1, 1):
        a = lane(t0, off); b = lane(t1, off)
        w0 = 2 + t0 * 10; w1 = 2 + t1 * 10
        d.polygon([(a[0] - w0, a[1]), (a[0] + w0, a[1]), (b[0] + w1, b[1]), (b[0] - w1, b[1])], fill=(255, 225, 205, 150))

# Ship (glider) with glow
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse((S * 0.30, S * 0.66, S * 0.70, S * 0.98), fill=(0xFF, 0x6B, 0x4A, 140))
glow = glow.filter(ImageFilter.GaussianBlur(60))
img.paste(glow, (0, 0), glow)
d = ImageDraw.Draw(img, "RGBA")
cx, cy, r = S * 0.5, S * 0.80, S * 0.17
d.polygon([(cx, cy - r * 1.2), (cx + r * 1.02, cy + r * 0.74), (cx, cy + r * 0.4), (cx - r * 1.02, cy + r * 0.74)], fill=(0xB8, 0x3E, 0x2A, 255))
d.polygon([(cx, cy - r * 1.2), (cx + r * 0.86, cy + r * 0.62), (cx, cy + r * 0.26), (cx - r * 0.86, cy + r * 0.62)], fill=(0xFF, 0x6B, 0x4A, 255))
d.polygon([(cx, cy - r * 0.92), (cx + r * 0.24, cy + r * 0.06), (cx - r * 0.24, cy + r * 0.06)], fill=(255, 255, 255, 235))
d.polygon([(cx - r * 0.18, cy + r * 0.42), (cx, cy + r * 1.0), (cx + r * 0.18, cy + r * 0.42)], fill=(0xFF, 0xD2, 0x7A, 255))

img.save("SkyBound/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
print("icon written")
