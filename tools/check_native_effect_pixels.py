"""Compare native class captures to the original source pack and palette operator.
Requires Pillow/numpy. Run native_effect_render_checks.gd first; no art is changed.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
CAPTURES = PROJECT / '.captures/native-effects'
levels = np.array([26, 49, 78, 109, 143, 177, 211, 239], dtype=np.uint8)
# Exact selected original preview.js palette, independent of the production shader.
palette = np.array([[73, 108, 132], [146, 185, 203], [221, 188, 137]], np.float64)
rows = []
for path in sorted(CAPTURES.glob('*-original.png')):
    original = np.array(Image.open(path))
    raw = np.array(Image.open(str(path).replace('-original.png', '-raw.png')))
    # Original class source pack.py equations, including its float32 boundary.
    values = original.astype(np.float32)
    alpha = values[:, :, 3] / 255.
    rgb = values[:, :, :3] / 255.
    linear = np.where(rgb <= .04045, rgb / 12.92, ((rgb + .055) / 1.055) ** 2.4)
    linear = np.clip(linear / np.maximum(alpha[:, :, None], 1 / 255.), 0, 1)
    energy = np.where(linear <= .0031308, linear * 12.92, 1.055 * linear ** (1 / 2.4) - .055).mean(axis=2) * 255.
    n = values.shape[0] // 2
    weights = alpha.reshape(n, 2, n, 2).sum(axis=(1, 3))
    weighted = (energy * alpha).reshape(n, 2, n, 2).sum(axis=(1, 3))
    energy = np.divide(weighted, weights, out=np.zeros_like(weighted), where=weights > 0).repeat(2, 0).repeat(2, 1)
    indices = np.argmin(abs(energy[:, :, None] - levels), axis=2)
    position = levels[indices] / 239. * 2
    first = np.minimum(1, np.floor(position).astype('int64'))
    fraction = position - first
    expected = np.zeros(original.shape, dtype=np.uint8)
    expected[:, :, :3] = np.floor(palette[first] * (1 - fraction[:, :, None]) + palette[first + 1] * fraction[:, :, None] + .5)
    expected[:, :, 3] = original[:, :, 3]
    expected[expected[:, :, 3] < 3] = 0
    received = np.array(Image.open(str(path).replace('-original.png', '-palette.png')))
    row = {'sample': path.stem, 'raw_different_pixels': int(np.any(original != raw, axis=2).sum()),
           'palette_different_pixels': int(np.any(expected != received, axis=2).sum())}
    rows.append(row)
    Image.fromarray(expected).save(str(path).replace('-original.png', '-cpu-palette.png'))
passed = sum(r['raw_different_pixels'] == 0 for r in rows) + sum(r['palette_different_pixels'] == 0 for r in rows)
report = {'passed': passed, 'failed': 48 - passed, 'expected_samples': 24, 'samples': rows,
          'scope': 'Native source and original composition palette RGBA; four quarters, three ages, original rear/front halves. Production actor occlusion is separate.',
          'renderer': json.loads((PROJECT / '.runtime/native-effects/render.json').read_text())['renderer']}
(PROJECT / 'generated/native_effect_render_checks.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: v for k, v in report.items() if k != 'samples'}))
assert len(rows) == 24 and report['failed'] == 0, report
