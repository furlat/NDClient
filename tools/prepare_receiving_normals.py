"""Derive receiving-only normals from retained original Cycles pixel samples.

No source artwork/depth/support is edited. The native color render integrated
multiple source samples; these original averaged normals retain that coverage
instead of promoting a single subpixel plank-edge ray to the whole color pixel.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import zlib
import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
DEFAULT_DATA = PROJECT.parent / 'NDClientData'
DEFAULT_EXPORT = PROJECT.parent.parent / 'assets/fantasy-unified-catalog/environment-geometry-production-2026-10-09/source-recovery/props'

def oct_encode(normal: np.ndarray) -> np.ndarray:
    n = normal / np.linalg.norm(normal, axis=-1, keepdims=True)
    p = n[..., :2] / np.abs(n).sum(axis=-1, keepdims=True)
    back = n[..., 2] < 0
    p[back] = (1 - np.abs(p[back, ::-1])) * np.where(p[back] >= 0, 1., -1.)
    return np.rint(np.clip((p + 1) * 127.5, 0, 255)).astype(np.uint8)

def prepare(data: Path, exports: Path, banks: list[str], authoring: Path = PROJECT / 'authoring') -> dict:
    owners = json.loads((authoring / 'environment/index.json').read_text())['banks']
    outputs, provenance, omitted = {}, [], []
    destination = PROJECT / 'generated/receiving_normals'
    destination.mkdir(parents=True, exist_ok=True)
    for bank_id in banks:
        source = exports / bank_id / 'extraction.json'
        if not source.is_file():
            omitted.append({'bank': bank_id, 'reason': 'No original Cycles extraction receipt'})
            continue
        receipt = json.loads(source.read_text())
        bank = json.loads((authoring / owners[bank_id]).read_text())
        images = {}
        for frame in receipt['frames']:
            pose, index = frame['pose'], frame['frame_index']
            surface = bank['surface_frames_by_pose'][pose][index]
            normal = surface['normal']
            original_path = normal['region']['path']
            raw_path = Path(frame['cycles_filtered_normal_f32'])
            if not raw_path.is_file():
                omitted.append({'bank': bank_id, 'pose': pose, 'frame': index, 'reason': 'Original Cycles normal pass absent'})
                continue
            original = np.asarray(Image.open(data / '.media' / original_path.removeprefix('/media/')).convert('RGBA'))
            if original_path not in images:
                images[original_path] = original.copy()
            x, y, w, h = map(int, normal['region']['rect'])
            width, height = map(int, receipt['native_cell'])
            assert (w, h) == (width, height), (bank_id, pose, index)
            raw = np.frombuffer(zlib.decompress(raw_path.read_bytes()), dtype='<f4').reshape(height, width, 3).astype(np.float64)
            assert np.isfinite(raw).all()
            # Original filtered pass is Blender world, unlike already converted
            # ray packets. Reuse their explicitly documented [X,-Y,Z] source basis.
            raw[..., 1] *= -1
            lengths = np.linalg.norm(raw, axis=-1)
            target = images[original_path][y:y+h, x:x+w]
            covered = (original[y:y+h, x:x+w, 0] != 0) | (original[y:y+h, x:x+w, 1] != 0)
            selected = covered & (lengths > 1e-8)
            target[selected, 2:] = oct_encode(raw[selected])
            provenance.append({'bank': bank_id, 'pose': pose, 'frame': index,
                'original_normal_path': original_path, 'region': [x,y,w,h],
                'original_cycles_normal': str(raw_path), 'source_receipt': str(source),
                'basis': 'original Blender X,Y,Z to registered source X,-Y,Z; normalize after pixel integration',
                'replaced_pixels': int(selected.sum()), 'retained_center_ray_pixels': int((covered & ~selected).sum())})
        for path, pixels in images.items():
            output = destination / (bank_id + '.png')
            if len(images) != 1:
                output = destination / (bank_id + '-' + Path(path).stem + '.png')
            Image.fromarray(pixels).save(output)
            outputs[path] = {'path': 'res://' + str(output.relative_to(PROJECT)),
                'qualification': 'Receiving-only original Cycles pixel-integrated normal, normalized after integration. Not exact ray/physical geometry. Original depth, alpha, support and source registration unchanged.'}
    result = {'version': 1, 'normals': outputs, 'provenance': provenance, 'omitted': omitted}
    (PROJECT / 'generated/environment_receiving_normals.json').write_text(json.dumps(result, indent=2) + '\n')
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data', type=Path, default=DEFAULT_DATA)
    parser.add_argument('--authoring', type=Path, default=PROJECT / 'authoring')
    parser.add_argument('--exports', type=Path, default=DEFAULT_EXPORT)
    parser.add_argument('--banks', nargs='+', default=['prop.interior-writing-desk.intact'])
    args = parser.parse_args()
    result = prepare(args.data, args.exports, args.banks, args.authoring)
    print(json.dumps({'maps': len(result['normals']), 'source_frames': len(result['provenance']), 'omitted': result['omitted']}))
