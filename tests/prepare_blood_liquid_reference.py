"""Independent NumPy field oracle from old Pygame surface_residue.py.

Consumes original real SDK residue after-values plus installed artwork. Outputs
float32 fields to ignored storage; never writes artwork or invents a deposit.
"""
import argparse
import json
from pathlib import Path
import numpy as np


def collect(value, tiles):
    if isinstance(value, dict):
        for row in value.get('tile_changes', []):
            for residue in row.get('changes', {}).get('residues', []):
                if residue['residue_id'] == 'residue.blood':
                    tiles[tuple(row['position'])] = residue
        for child in value.values():
            collect(child, tiles)
    elif isinstance(value, list):
        for child in value:
            collect(child, tiles)


def field(position, residue, style):
    # Deliberately uses the original pointwise inverse-ellipse formula rather
    # than the native adapter's affine quad transforms or bounds culling.
    y, x = np.indices((64, 64), dtype=np.float32)
    x, y = (x + .5) / 64 - .5, (y + .5) / 64 - .5
    result = np.zeros((64, 64), np.float32)
    for contribution in residue['contributions']:
        scale = np.sqrt(contribution['amount'] / residue['max_amount'])
        for ellipse in contribution['ellipses']:
            center = ellipse['center']
            world = center[0] + position[0], center[1] + position[1]
            index = round(world[0] * 100) * 31 + round(world[1] * 100) * 17
            template = style['templates'][index % len(style['templates'])]
            co, si = np.cos(ellipse['angle']), np.sin(ellipse['angle'])
            dx, dy = x - center[0], y - center[1]
            u = (dx * co + dy * si) / ellipse['radius_x']
            v = (-dx * si + dy * co) / ellipse['radius_y']
            for particle in template['particles']:
                a, b = particle['target']
                for kernel in particle['kernels']:
                    du = u - (a + (kernel['x'] - a) * scale)
                    dv = v - (b + (kernel['y'] - b) * scale)
                    kc, ks = np.cos(kernel['angle']), np.sin(kernel['angle'])
                    q = ((du * kc + dv * ks) / (kernel['rx'] * scale)) ** 2 + ((-du * ks + dv * kc) / (kernel['ry'] * scale)) ** 2
                    result += kernel['mass'] * np.maximum(0, 1 - q / 1.5) ** 2
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--operation', required=True, type=Path)
    parser.add_argument('--authoring', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    style = json.loads((args.authoring / 'catalog/action_media_assets.json').read_text())['particles.region.blood']['region']
    tiles = {}
    collect(json.loads(args.operation.read_text()), tiles)
    assert tiles, 'Real operation has no blood tile after-values'
    args.output.mkdir(parents=True, exist_ok=True)
    for position, residue in tiles.items():
        field(position, residue, style).astype('<f4').tofile(args.output / ('%d,%d.bin' % position))
    (args.output / 'source.json').write_text(json.dumps({'operation': str(args.operation), 'tiles': len(tiles), 'formula': 'game_obsolete/surface_residue.py::_deposit_patch'}, indent=2))
    print(f'Wrote {len(tiles)} independent real-after-value fields')


if __name__ == '__main__':
    main()
