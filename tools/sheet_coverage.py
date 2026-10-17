"""Measure how much of each modular layer sheet holds visible pixels.

For every layer directory and the given clips, report:
- alpha: fraction of sheet pixels with alpha > 0;
- cells: fraction of the 15x8 cells that hold any pixel;
- boxes: per-cell tight bounding boxes, summed, as a fraction of the sheet.
A whole-actor composite is estimated by OR-ing the alpha of one layer per
category (Body/Head/Chest/Legs/...) for the same clip.
"""
import sys, pathlib, collections
import numpy as np
from PIL import Image

ROOT = pathlib.Path(sys.argv[1])
CLIPS = sys.argv[2].split(",")
CELL = 128

def measure(alpha):
    h, w = alpha.shape
    cells = alpha.reshape(h // CELL, CELL, w // CELL, CELL).transpose(0, 2, 1, 3)
    used = 0
    box = 0
    for row in cells:
        for cell in row:
            ys, xs = np.nonzero(cell)
            if len(ys):
                used += 1
                box += (ys.max() - ys.min() + 1) * (xs.max() - xs.min() + 1)
    n = cells.shape[0] * cells.shape[1]
    return alpha.mean(), used / n, box / (h * w)

rows = collections.defaultdict(list)
first = {}
for layer in sorted(p for p in ROOT.iterdir() if p.is_dir()):
    for clip in CLIPS:
        path = layer / f"{clip}.png"
        if not path.exists():
            continue
        alpha = np.asarray(Image.open(path).convert("RGBA"))[:, :, 3] > 0
        if alpha.shape[0] % CELL or alpha.shape[1] % CELL:
            continue
        a, c, b = measure(alpha)
        category = layer.name.rstrip("0123456789")
        rows[category].append((a, c, b))
        first.setdefault((category, clip), alpha)

print(f"{'category':<10}{'n':>4}{'alpha':>8}{'cells':>8}{'boxes':>8}")
total = [[], [], []]
for category, values in sorted(rows.items()):
    m = np.mean(values, axis=0)
    for i in range(3):
        total[i] += [v[i] for v in values]
    print(f"{category:<10}{len(values):>4}{m[0]:>8.3f}{m[1]:>8.3f}{m[2]:>8.3f}")
print(f"{'ALL':<10}{len(total[0]):>4}{np.mean(total[0]):>8.3f}{np.mean(total[1]):>8.3f}{np.mean(total[2]):>8.3f}")

for clip in CLIPS:
    layers = [a for (cat, c), a in first.items() if c == clip and cat not in ("Effect", "GunFire", "Magic")]
    if layers:
        union = np.logical_or.reduce(layers)
        a, c, b = measure(union)
        print(f"composite {clip}: {len(layers)} categories, alpha {a:.3f} cells {c:.3f} boxes {b:.3f}")
