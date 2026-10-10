"""Independent source-image endpoint expectations, streamed to the browser test."""
import base64
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
components = json.loads((ROOT / 'authoring/characters/sheet-components.json').read_text())
for line in sys.stdin:
    request = json.loads(line)
    url = request['url']
    region = request['frame'] * 128, request['direction'] * 128
    def load(source):
        if source is None:
            return np.zeros((128, 128, 4), dtype=np.float64)
        with Image.open(ROOT / '.media' / source.removeprefix('/media/')) as image:
            rgba = np.asarray(image.convert('RGBA').crop((*region, region[0]+128, region[1]+128))).astype(np.float64) / 255
        rgba[..., :3] *= rgba[..., 3:]
        return rgba
    layers = components[url]['source_layers']
    c, b, s, e = [load(u) for u in (url, layers['body'], layers['shadow'], layers.get('accent'))]
    has_accent = components[url]['composition']['has_accent']
    def over(a, z):
        return a + (1-a[..., 3:]) * z
    expected = dict(neutral=c, body=b, shadow=s, accent=e,
                    bodyOff=over(e,s) if has_accent else s,
                    effectOff=over(b,s) if has_accent else c,
                    allOff=np.zeros_like(c))
    background = np.array(request['backdrop']) / 255
    result = {}
    for name, value in expected.items():
        opaque = value.copy()
        opaque[..., :3] += (1-value[..., 3:]) * background
        opaque[..., 3] = 1
        result[name] = base64.b64encode(np.rint(opaque * 255).clip(0,255).astype('uint8').tobytes()).decode()
    print(json.dumps(result), flush=True)
