#!/usr/bin/env python3
"""Рисует карту уровня (вид сверху) из build/map.json → build/map.png."""
import json, sys
from PIL import Image, ImageDraw

src = sys.argv[1] if len(sys.argv) > 1 else "build/map.json"
dst = sys.argv[2] if len(sys.argv) > 2 else "build/map.png"
d = json.load(open(src))
minX, maxX, minZ, maxZ = d["bounds"]
step = d["step"]
H = d["heights"]
rows, cols = len(H), len(H[0])
lo = min(c[0] for r in H for c in r)
hi = max(c[0] for r in H for c in r)
S = 2  # пикселей на клетку
img = Image.new("RGB", (cols * S, rows * S))
px = img.load()
for j, r in enumerate(H):
    for i, (h, creek) in enumerate(r):
        t = (h - lo) / (hi - lo + 1e-9)
        # отмывка по склону (свет с северо-запада)
        hn = H[j - 1][i][0] if j > 0 else h
        hw = r[i - 1][0] if i > 0 else h
        shade = max(-1, min(1, ((hn - h) + (hw - h)) / 6))
        base = 150 + 90 * t
        v = int(max(0, min(255, base + 40 * shade)))
        col = (v - 10, v - 4, v + 6) if not creek else (40, 80, 120)
        for a in range(S):
            for b in range(S):
                px[i * S + a, j * S + b] = col
dr = ImageDraw.Draw(img)
def P(x, z):
    return ((x - minX) / step * S, (z - minZ) / step * S)
pts = [P(w["x"], w["z"]) for w in d["route"]]
dr.line(pts, fill=(200, 60, 40), width=3)
for o in d["outcrops"]:
    x, y = P(o["x"], o["z"]); r = o["size"] / step * S
    dr.ellipse([x - r, y - r, x + r, y + r], fill=(70, 70, 80))
for t in d["trees"]:
    x, y = P(t["x"], t["z"])
    c = (230, 200, 90) if t.get("blaze") else (30, 80, 50)
    dr.ellipse([x - 2, y - 2, x + 2, y + 2], fill=c)
for p in d["poles"]:
    x, y = P(p["x"], p["z"])
    dr.rectangle([x - 1, y - 1, x + 1, y + 1], fill=(255, 0, 0) if not p["toppled"] else (120, 0, 0))
for p in d["piles"]:
    x, y = P(p["x"], p["z"]); dr.rectangle([x - 2, y - 2, x + 2, y + 2], fill=(140, 90, 40))
for p in d["ice"]:
    x, y = P(p["x"], p["z"]); dr.ellipse([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=(20, 40, 60) if p["thin"] else (220, 240, 255))
for p in d["logs"]:
    x, y = P(p["x"], p["z"]); dr.rectangle([x - 3, y - 3, x + 3, y + 3], outline=(120, 70, 30), width=2)
for f in d["fires"]:
    x, y = P(f["x"], f["z"]); dr.ellipse([x - 5, y - 5, x + 5, y + 5], fill=(255, 140, 0)); dr.text((x + 7, y - 6), f["id"], fill=(255, 220, 160))
c = d["cedar"]; x, y = P(c["x"], c["z"]); dr.ellipse([x - 6, y - 6, x + 6, y + 6], outline=(0, 60, 20), width=3)
h = d["hut"]; x, y = P(h["x"], h["z"]); dr.rectangle([x - 6, y - 5, x + 6, y + 5], fill=(110, 70, 40)); dr.text((x + 8, y - 6), "hut", fill=(255, 220, 160))
w0 = d["route"][0]; x, y = P(w0["x"], w0["z"]); dr.polygon([(x, y - 7), (x - 6, y + 5), (x + 6, y + 5)], fill=(220, 100, 40)); dr.text((x + 8, y - 6), "tent", fill=(255, 220, 160))
for zn in d["zones"]:
    x, y = P(zn["x"], zn["z"]); dr.text((x - 60, y), zn["id"].upper(), fill=(255, 255, 255))
img.save(dst)
print("saved", dst, img.size)
