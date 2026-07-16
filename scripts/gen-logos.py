#!/usr/bin/env python3
"""Génère tous les assets logo/icône Ubuntu RP depuis une source carrée.

Usage : python gen_logos.py <source.png>
Produit :
  - config/server-icon.png                                   (96x96)
  - resources/[custom]/ubuntu-loadscreen/html/assets/logo.png (512x512)
  - wiki/assets/logo.png                                      (560x560)
La source est recadrée au carré (centre) puis redimensionnée en Lanczos,
en préservant la transparence (RGBA).
"""
import sys
from pathlib import Path
from PIL import Image

REPO = Path(__file__).resolve()
# Le repo est passé en 2e arg pour éviter toute ambiguïté de cwd.
if len(sys.argv) < 3:
    print("Usage: python gen_logos.py <source.png> <repo_root>")
    sys.exit(1)

src_path = Path(sys.argv[1])
repo = Path(sys.argv[2])

TARGETS = [
    (repo / "config/server-icon.png", 96),
    (repo / "resources/[custom]/ubuntu-loadscreen/html/assets/logo.png", 512),
    (repo / "wiki/assets/logo.png", 560),
]

img = Image.open(src_path).convert("RGBA")
w, h = img.size
side = min(w, h)
left = (w - side) // 2
top = (h - side) // 2
img = img.crop((left, top, left + side, top + side))

for dest, size in TARGETS:
    out = img.resize((size, size), Image.LANCZOS)
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest, "PNG", optimize=True)
    print(f"écrit {dest}  ({size}x{size})")

print("Terminé.")
