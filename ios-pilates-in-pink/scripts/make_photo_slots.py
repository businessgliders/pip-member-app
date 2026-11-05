#!/usr/bin/env python3
"""Creates empty photo slots (imagesets) for real studio photos, plus a film-grain tile.
Drop a JPG/PNG into any slot folder and add its filename to that slot's Contents.json "1x"/universal entry
(or just drag the photo onto the slot in Xcode). Until then the app draws a warm gradient placeholder."""
import json, os, random
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "PilatesInPinkTM", "Assets.xcassets")
SLOTS = [f"hero_{i}" for i in range(1, 6)] + [
    "class_sculpt", "class_core", "class_rise", "class_poise", "class_rose",
    "class_jump", "class_intro", "studio_brampton", "signin_bg",
]
EMPTY = {"images": [{"idiom": "universal", "scale": s} for s in ("1x", "2x", "3x")],
         "info": {"author": "xcode", "version": 1}}

for name in SLOTS:
    d = os.path.join(ROOT, f"{name}.imageset")
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, "Contents.json")
    if not os.path.exists(path):
        with open(path, "w") as f:
            json.dump(EMPTY, f, indent=2)

# Grain: 256px tileable monochrome noise, mid-grey centred, used at low opacity with overlay blend.
random.seed(7)
g = Image.new("LA", (256, 256))
px = g.load()
for y in range(256):
    for x in range(256):
        v = random.randint(0, 255)
        px[x, y] = (v, random.randint(40, 90))
d = os.path.join(ROOT, "grain.imageset")
os.makedirs(d, exist_ok=True)
g.save(os.path.join(d, "grain.png"))
with open(os.path.join(d, "Contents.json"), "w") as f:
    json.dump({"images": [{"idiom": "universal", "filename": "grain.png"}],
               "info": {"author": "xcode", "version": 1}}, f, indent=2)
print("ok")
