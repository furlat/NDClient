"""Author accent colour-treatment masks without recomposing character artwork.

Offline source comparison only. Runtime reads a selection or an aligned L8 mask,
then applies the existing palette material to original RGB, preserving alpha.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import io
import json
from pathlib import Path
import zipfile

import numpy as np
from PIL import Image
from pydantic import TypeAdapter
from scipy.spatial import cKDTree

from game.animation_types import AnimationData
from game.sprite_components import SheetComponents
from author_character_components import rgba_selection, write_json
from build_authoring import read_catalog


ROOT = Path(__file__).resolve().parents[1]


def chromaticity(rgb):
    values = rgb.astype('float64')
    return values / np.maximum(values.sum(-1, keepdims=True), 1)


def colour_tree(rgb):
    palette = np.unique(rgb.reshape(-1, 3), axis=0)
    palette = palette[palette.sum(1) > 0]
    return cKDTree(chromaticity(palette)) if len(palette) else None


def accent_influence(combined, body, labels, effect=None, idle_body=None):
    """Material membership, not reconstructed opacity or a physical depth mask.

    A changed body sample belongs to glow treatment when its chromaticity is
    closer to the supplied effect palette than to the corresponding clean body
    sample. Brightness-only changes do not select anatomy. Where the vendor's
    body already includes opaque effects, effect colours absent from its idle
    body palette extend the material mask without rewriting geometry labels.
    """
    selected = labels == 3
    palette = (effect[effect[:, :, 3] > 0, :3] if effect is not None
               else combined[selected, :3])
    tree = colour_tree(palette)
    if tree is None:
        return selected.astype('uint8') * 255
    candidates = (body[:, :, 3] > 0) & (combined[:, :, 3] > 0) & (labels != 2)
    target = chromaticity(combined[candidates, :3])
    original = chromaticity(body[candidates, :3])
    effect_distance = tree.query(target)[0]
    body_distance = np.linalg.norm(target - original, axis=1)
    # Ignore one-byte export quantization; the chromaticity epsilon is float
    # equality, not an artistic colour tolerance or a frame/asset budget.
    changed = np.max(np.abs(combined[candidates, :3].astype('int16')
                            - body[candidates, :3].astype('int16')), axis=1) > 1
    affected = (effect_distance + 1e-7 < body_distance) & changed
    if effect is None and idle_body is not None:
        native = colour_tree(idle_body[idle_body[:, :, 3] > 0, :3])
        if native is not None:
            native_distance = native.query(target)[0]
            affected |= (effect_distance < 1e-7) & (native_distance > 1e-7)
    selected[candidates] |= affected
    return selected.astype('uint8') * 255


def author(root, engine, workers):
    path = root / 'authoring/characters/sheet-components.json'
    document = json.loads(path.read_text())
    if any('accent_material_mask' in row for row in document.values()):
        raise ValueError('Refusing to overwrite editable accent material authoring')
    evidence = json.loads((root / '.runtime/character-components/source-evidence.json').read_text())
    rows = {row['payload']: row for row in map(json.loads,
            (root / '.runtime/character-assets/files.jsonl').read_text().splitlines())}
    needed = [u for u, e in evidence.items() if e.get('visible_pixels', {}).get('accent', 0)
              or 'accent_body_overlap' in document[u].get('limitations', ())]
    archive_paths = {rows['.media/' + u.removeprefix('/media/')]['source'] for u in needed
                     if rows['.media/' + u.removeprefix('/media/')]['pack'] != 'dinosaurs'}
    archives = {p: zipfile.ZipFile(p) for p in archive_paths}
    dinosaur_root = engine / '.runtime/pack-study-20260930/animal-dinosaur-completion/dinosaurs'
    names = {p: archive.namelist() for p, archive in archives.items()}
    dinosaur_names = [str(p.relative_to(dinosaur_root)) for p in dinosaur_root.rglob('*.png')]

    def source_image(row, name):
        source = (dinosaur_root / name if row['pack'] == 'dinosaurs'
                  else io.BytesIO(archives[row['source']].read(name)))
        with Image.open(source) as image:
            return np.array(image.convert('RGBA'))

    def local_image(url):
        with Image.open(root / '.media' / url.removeprefix('/media/')) as image:
            return np.array(image.convert('RGBA'))

    # One native palette per actual source character, not one assumed palette
    # per pack. Read original paired idle sheets only as authoring evidence.
    idle_bodies = {}
    for url in needed:
        if 'accent' in document[url].get('source_layers', {}):
            continue
        row = rows['.media/' + url.removeprefix('/media/')]
        parent = str(Path(evidence[url]['source_body']).parent)
        key = (row['source'], parent)
        if key in idle_bodies:
            continue
        members = dinosaur_names if row['pack'] == 'dinosaurs' else names[row['source']]
        idle = sorted(n for n in members if str(Path(n).parent) == parent
                      and n.lower().endswith('.png') and 'idle' in Path(n).stem.lower())
        idle_bodies[key] = source_image(row, idle[0]) if idle else None

    reports = {}

    def one(url):
        record = document[url]
        row = rows['.media/' + url.removeprefix('/media/')]
        combined = local_image(url)
        body = source_image(row, evidence[url]['source_body'])
        selection = record['selection']
        if selection['kind'] == 'mask':
            with Image.open(root / '.media' / selection['mask']['path'].removeprefix('/media/')) as image:
                labels = np.array(image)
        else:
            labels = rgba_selection(combined, selection)
        effect_url = record.get('source_layers', {}).get('accent')
        effect = local_image(effect_url) if effect_url else None
        idle = idle_bodies.get((row['source'], str(Path(evidence[url]['source_body']).parent)))
        influence = accent_influence(combined, body, labels, effect, idle)
        if np.array_equal(influence > 0, labels == 3):
            result = {'kind': 'selection'}
        else:
            relative = Path(row['payload']).relative_to('.media/smallscale/authored')
            target = Path('.media/smallscale/authored') / relative.parts[0] / 'Material masks' / Path(*relative.parts[1:])
            (root / target).parent.mkdir(parents=True, exist_ok=True)
            Image.fromarray(influence).save(root / target)
            result = {'kind': 'image', 'mask': {'path': '/media/' + str(target).removeprefix('.media/'),
                                              'rect': [0, 0, combined.shape[1], combined.shape[0]]}}
        report = {'material_pixels': int(np.count_nonzero(influence)),
                  'body_overlap_pixels': int(np.count_nonzero((influence > 0) & (labels == 1))),
                  'method': 'paired_body_and_effect_palette' if effect_url else 'paired_body_and_character_idle_palette',
                  'native_idle_available': idle is not None}
        return url, result, report

    for url, record in document.items():
        if record['selection'] == {'kind': 'whole', 'role': 'accent'}:
            record['accent_material_mask'] = {'kind': 'selection'}
    with ThreadPoolExecutor(max_workers=workers) as pool:
        for i, (url, result, report) in enumerate(pool.map(one, needed)):
            document[url]['accent_material_mask'] = result
            reports[url] = report
            SheetComponents.model_validate(document[url])
            if (i + 1) % 200 == 0:
                print(f'{i + 1}/{len(needed)} material selections authored', flush=True)
    for archive in archives.values():
        archive.close()
    catalog = read_catalog(root / 'authoring')
    catalog['sheet_components'] = document
    TypeAdapter(AnimationData).validate_json(json.dumps(catalog))
    write_json(path, document)
    schema = TypeAdapter(AnimationData).json_schema(mode='serialization')
    schema['$schema'] = 'https://json-schema.org/draft/2020-12/schema'
    write_json(root / 'authoring/schemas/animation.schema.json', schema)
    write_json(root / '.runtime/character-components/material-evidence.json', reports)
    print(json.dumps({'operations': sum('accent_material_mask' in row for row in document.values()),
                      'influence_images': sum(row.get('accent_material_mask', {}).get('kind') == 'image'
                                              for row in document.values())}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--workers', type=int, default=4)
    args = parser.parse_args()
    author(args.root, args.engine, args.workers)
