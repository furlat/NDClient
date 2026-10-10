"""Author source pixel roles from installed Smallscale sheets and original layers.

Offline only. Reads archive body counterparts as evidence without installing a
shadowless library. Original appearance pixels, clips and rig placements stay intact.
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

from game.animation_types import AnimationData
from game.sprite_components import SheetComponents
from build_authoring import read_catalog


ROOT = Path(__file__).resolve().parents[1]
ROLES = {'body': 1, 'shadow': 2, 'accent': 3}


def rgba_selection(pixels, selection):
    """Reference source-byte classifier; shader consumers use the same data."""
    visible = pixels[:, :, 3] > 0
    if selection['kind'] == 'whole':
        return visible.astype('uint8') * ROLES[selection['role']]
    if selection['kind'] != 'source_rgba':
        raise ValueError('Mask selections are sampled from their registered image')
    labels = visible.astype('uint8') * ROLES[selection['remainder']]
    unmatched = visible.copy()
    for rule in selection['rules']:
        selected = unmatched & np.all(pixels >= rule['minimum'], 2) & np.all(pixels <= rule['maximum'], 2)
        labels[selected] = ROLES[rule['role']]
        unmatched[selected] = False
    return labels


def source_body_member(member):
    for combined, separate in (
        ('/With shadow/', '/Shadowless/'),
        ('Zombies with shadow/', 'Zombies Shadowless/'),
        ('/Combined/', '/Seperate shadows and effects/'),
        ('Combined/', 'Spritesheets with seperated shadows and effects/'),
    ):
        if combined in member:
            result = member.replace(combined, separate, 1)
            return result[:-4] + '_Shadowless.png' if combined == '/With shadow/' else result
    return None


def rgba_range(role, minimum, maximum):
    return {'role': role, 'minimum': minimum, 'maximum': maximum}


def visible_components(combined, body, shadow=None, accent=None, *, retain_coloured_edges=False,
                       mismatched_body=False):
    """Partition visible samples; do not pretend to unmix baked overlapping colours.

    Separate source coverage protects translucent anatomy. For the HD/animal
    packs, inspected shadow pixels are RGB 0..1. HD zombie coloured fringes belong
    to the body, not a swoosh. The vendor Wizard Run counterpart has another pose.
    """
    visible = combined[:, :, 3] > 0
    body_coverage = body[:, :, 3] > 0
    labels = visible.astype('uint8')
    if shadow is None:
        shadow_pixels = visible & (combined[:, :, 3] < 255) & (combined[:, :, :3].max(2) <= 1)
        if not mismatched_body:
            shadow_pixels &= ~body_coverage
        labels[shadow_pixels] = 2
        if not retain_coloured_edges:
            effect_pixels = visible & (combined[:, :, 3] < 255) & ~shadow_pixels
            if not mismatched_body:
                effect_pixels &= ~body_coverage
            labels[effect_pixels] = 3
    else:
        exposed = visible & ~body_coverage
        effect_pixels = (accent[:, :, 3] > 0) if accent is not None else np.zeros(visible.shape, bool)
        shadow_pixels = exposed & (shadow[:, :, 3] > 0) & ~effect_pixels
        labels[shadow_pixels] = 2
        labels[exposed & effect_pixels] = 3
        # Combined exports can extend slightly beyond the separate shadow mask.
        # Extend only with colour values actually observed in that sheet's exposed
        # shadow, never with an assumed universal black threshold.
        if shadow_pixels.any():
            colours = combined[:, :, :3].astype('uint32')
            packed = colours[:, :, 0] + 256 * colours[:, :, 1] + 65536 * colours[:, :, 2]
            palette = np.unique(packed[shadow_pixels])
            continuation = exposed & ~effect_pixels & np.isin(packed, palette)
            labels[continuation] = 2
        if accent is not None:
            # Preserve residual translucent effect fringes around the supplied
            # effect. Opaque unassigned samples remain body rather than disappearing.
            labels[exposed & (labels != 2) & (combined[:, :, 3] < 255)] = 3
    return labels


def compact_selection(pixels, labels):
    """Choose ranges only if they reproduce this sheet's authored mask exactly."""
    present = set(np.unique(labels)) - {0}
    if len(present) == 1:
        return {'kind': 'whole', 'role': next(k for k, v in ROLES.items() if v in present)}
    rules = []
    for role in ('shadow', 'accent'):
        selected = pixels[labels == ROLES[role]]
        if selected.size:
            rules.append(rgba_range(role, selected.min(0).tolist(), selected.max(0).tolist()))
    if not rules:
        return {'kind': 'whole', 'role': 'body'}
    result = {'kind': 'source_rgba', 'rules': rules, 'remainder': 'body'}
    return result if np.array_equal(rgba_selection(pixels, result), labels) else None


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + '\n')


def author(engine, root, workers):
    destination = root / 'authoring/characters/sheet-components.json'
    if destination.exists():
        raise ValueError('Refusing to overwrite editable client component authoring')
    rows = [json.loads(line) for line in (root / '.runtime/character-assets/files.jsonl').read_text().splitlines()]
    unique = {}
    for row in rows:
        unique.setdefault(row['payload'], row)
    archives = {path: zipfile.ZipFile(path) for path in {row['source'] for row in unique.values()
                if row['family'] == 'B' and row['pack'] not in ('dinosaurs', 'existing-authored-resources')}}
    members = {path: set(source.namelist()) for path, source in archives.items()}
    originals = {(row['source'], row['member']): row for row in rows}
    dinosaurs = engine / '.runtime/pack-study-20260930/animal-dinosaur-completion/dinosaurs'

    def exists(row, name):
        return (dinosaurs / name).is_file() if row['pack'] == 'dinosaurs' else name in members[row['source']]

    def read(row, name):
        if row['pack'] == 'dinosaurs':
            with Image.open(dinosaurs / name) as image:
                return np.array(image.convert('RGBA'))
        with Image.open(io.BytesIO(archives[row['source']].read(name))) as image:
            return np.array(image.convert('RGBA'))

    def one(row):
        url = '/media/' + row['payload'].removeprefix('.media/')
        parts = Path(row['payload']).parts
        if row['family'] == 'A':
            category = Path(row['payload']).parent.name
            role = ('shadow' if category == 'Shadow' else 'accent'
                    if category.startswith(('Effect', 'Magic', 'Slash', 'GunFire')) else 'body')
            return url, {'selection': {'kind': 'whole', 'role': role}}, {'basis': 'original_modular_layer'}
        if {'Shadows', 'Derived shadows'} & set(parts):
            return url, {'selection': {'kind': 'whole', 'role': 'shadow'}}, {'basis': 'original_shadow_layer'}
        if 'Effects' in parts:
            return url, {'selection': {'kind': 'whole', 'role': 'accent'}}, {'basis': 'original_effect_layer'}
        counterpart = source_body_member(row['member'])
        if counterpart is None or not exists(row, counterpart):
            raise ValueError('Missing original source body counterpart: ' + url)
        with Image.open(root / row['payload']) as image:
            combined = np.array(image.convert('RGBA'))
        body = read(row, counterpart)
        if combined.shape != body.shape:
            raise ValueError('Source body registration size differs: ' + url)
        companions = {}
        source_layers = {}
        for folder, role in [('Shadows', 'shadow'), ('Effects', 'accent')]:
            name = str(Path(counterpart).parent / folder / Path(counterpart).name)
            if exists(row, name):
                companions[role] = read(row, name)
                if companions[role].shape != combined.shape:
                    raise ValueError('Source component registration size differs: ' + url)
                installed = originals[(row['source'], name)]['payload']
                source_layers[role] = '/media/' + installed.removeprefix('.media/')
        mismatch = row['pack'] == 'character' and counterpart.endswith('/3Wizard/Run_Shadowless.png')
        labels = visible_components(combined, body, companions.get('shadow'), companions.get('accent'),
                                    retain_coloured_edges=row['pack'] == 'hdz', mismatched_body=mismatch)
        selection = compact_selection(combined, labels)
        if selection is None:
            relative = Path(row['payload']).relative_to('.media/smallscale/authored')
            mask_path = Path('.media/smallscale/authored') / relative.parts[0] / 'Component masks' / Path(*relative.parts[1:])
            path = root / mask_path
            path.parent.mkdir(parents=True, exist_ok=True)
            Image.fromarray(labels).save(path)
            selection = {'kind': 'mask', 'mask': {'path': '/media/' + str(mask_path).removeprefix('.media/'),
                         'rect': [0, 0, combined.shape[1], combined.shape[0]]}}
        result = {'selection': selection, 'limitations': ['visible_partition_only']}
        if mismatch:
            result['limitations'].append('source_body_pose_mismatch')
        if source_layers:
            result['source_layers'] = source_layers
        changed_body = np.any(combined != body, 2) & (body[:, :, 3] > 0)
        report = {'basis': 'source_body_and_components' if companions else 'source_body_and_reviewed_shadow_colour',
                  'source_body': counterpart, 'source_body_pose_mismatch': mismatch,
                  'body_source_differs_pixels': int(changed_body.sum()),
                  'visible_pixels': {name: int(np.count_nonzero(labels == code)) for name, code in ROLES.items()},
                  'body_alpha_is_binary': bool(np.all((body[:, :, 3] == 0) | (body[:, :, 3] == 255))),
                  'scope': 'visible_partition_not_colour_unmixing'}
        if 'accent' in companions:
            report['accent_over_body_pixels'] = int(np.count_nonzero(
                (companions['accent'][:, :, 3] > 0) & (body[:, :, 3] > 0)))
            if report['accent_over_body_pixels']:
                result['limitations'].append('accent_body_overlap')
        return url, result, report

    selections = {}
    evidence = {}
    with ThreadPoolExecutor(max_workers=workers) as pool:
        for i, (url, selection, report) in enumerate(pool.map(one, unique.values())):
            SheetComponents.model_validate_json(json.dumps(selection))
            selections[url] = selection
            evidence[url] = report
            if (i + 1) % 1000 == 0:
                print(f'{i + 1}/{len(unique)} sheets authored', flush=True)
    for source in archives.values():
        source.close()
    # A referenced component is useful only if the ordinary build sees it.
    catalog = read_catalog(root / 'authoring')
    catalog['sheet_components'] = selections
    TypeAdapter(AnimationData).validate_json(json.dumps(catalog))
    write_json(destination, dict(sorted(selections.items())))
    index_path = root / 'authoring/catalog-index.json'
    index = json.loads(index_path.read_text())
    index['sheet_components'] = 'characters/sheet-components.json'
    write_json(index_path, index)
    schema = TypeAdapter(AnimationData).json_schema(mode='serialization')
    schema['$schema'] = 'https://json-schema.org/draft/2020-12/schema'
    write_json(root / 'authoring/schemas/animation.schema.json', schema)
    write_json(root / '.runtime/character-components/source-evidence.json', evidence)
    counts = {kind: sum(v['selection']['kind'] == kind for v in selections.values())
              for kind in ('whole', 'source_rgba', 'mask')}
    print(json.dumps({'sheets': len(selections), **counts}, indent=2), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--workers', type=int, default=4)
    args = parser.parse_args()
    author(args.engine, args.root, args.workers)
