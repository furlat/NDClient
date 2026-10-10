"""Seed editable NDClient authoring ONCE from the engine's effective presentation export.

Run with the engine's uv Python, PYTHONPATH pointing at that engine. Existing
client authoring is never overwritten. Media refresh tools do not call this.
"""
import argparse
import json
from pathlib import Path
import re

from pydantic import TypeAdapter

from game.animation_data import load_animation_data
from game.animation_types import AnimationData, PairedFrameBank
from game.presentation_export import export_catalog
from game.world_binding_types import AssetDocument, WorldBindingsSource
from vfx_layout import ordinary_path
from asset_paths import write_asset


ROOT = Path(__file__).resolve().parents[1]


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from strings(child)


def write_json(path, value, compact=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=None if compact else 2,
                              separators=(',', ':') if compact else None, allow_nan=False) + '\n')


def location_map(root):
    paths = {}
    for family in ('vfx-assets', 'vfx-replacements', 'environment-assets'):
        for line in (root / '.runtime' / family / 'files.jsonl').read_text().splitlines():
            row = json.loads(line)
            source = row.get('source_path')
            if source is None and '/game/assets/' in row['source']:
                source = 'game/assets/' + row['source'].split('/game/assets/', 1)[1]
            if source:
                paths[source] = '/media/' + row['payload'].removeprefix('.media/')
    return paths


def relocate(value, paths):
    if isinstance(value, str):
        if value in paths:
            return paths[value]
        if value.startswith('game/assets/') and '{' in value:
            prefix = value[:value.index('{')].rsplit('/', 1)[0] + '/'
            expression = re.compile('^' + re.sub(r'\\\{[^}]+\\\}', '[^/]+', re.escape(value)) + '$')
            matches = [(old, new) for old, new in paths.items() if expression.match(old)]
            if not matches:
                raise ValueError('Unresolved authored media pattern: ' + value)
            old, new = matches[0]
            tail = old[len(prefix):]
            if not new.endswith(tail):
                raise ValueError('Pattern moved inconsistently: ' + value)
            new_prefix = new[:-len(tail)]
            if any(new_prefix + a[len(prefix):] != b for a, b in matches):
                raise ValueError('Pattern spans different destination layouts: ' + value)
            return new_prefix + value[len(prefix):]
        return value
    if isinstance(value, dict):
        return {key: relocate(child, paths) for key, child in value.items()}
    if isinstance(value, list):
        return [relocate(child, paths) for child in value]
    return value


def replacement_banks(root, delivery):
    result = {}
    owners = {}
    for spell in delivery['spells']:
        for item in spell['media'].values():
            b = item['binding']
            for bank in ([b['bank']] if 'bank' in b else b.get('banks', {}).values()):
                owners.setdefault(bank, spell['spell'])
    accepted = {f.alias or key for key, f in PairedFrameBank.model_fields.items()}
    manifest_root = root / '.runtime/vfx-replacements'
    for identity, entry in delivery['banks'].items():
        path = (manifest_root / entry['manifest']).resolve()
        raw = json.loads(path.read_text())
        bank = {key: value for key, value in raw.items() if key in accepted}
        for frame in bank['frames']:
            if frame['camera_matrices'] == bank['camera_matrices']:
                frame['camera_matrices'] = None
            for layer in frame['layers'].values():
                for name in ('appearance', 'geometry'):
                    if layer[name] is not None:
                        plane = layer[name]
                        layer[name] = {'file': '/media/' + str((path.parent / plane['file']).resolve().relative_to(root / '.media')),
                                       'decoded_bytes': plane['decoded_bytes']}
        # Source phase annotations are optional, not a second timing owner.
        for key in ('phases', 'radiance_calibration', 'timing'):
            if bank.get(key) is None:
                bank.pop(key, None)
        result[identity] = PairedFrameBank.model_validate_json(json.dumps(bank)).model_dump(mode='json', by_alias=True)
    return result, owners


def amend_recipes(value, replacements, banks, amendments, pointer=''):
    if isinstance(value, dict):
        identity = value.get('assetId')
        if identity in replacements:
            binding = replacements[identity]
            bank_id = binding['bank'] if 'bank' in binding else next(iter(binding['banks'].values()))
            fps = binding.get('playback_fps', banks[bank_id]['fps'])
            changes = {}
            if value.get('composition') == 'xyz_volume':
                changes['composition'] = 'paired_depth'
                # The bank owns pixel/world calibration; these were old XYZ scales.
                if 'scale' in value:
                    changes['scale'] = 1.0
            if 'fps' in value:
                changes['fps'] = fps
            if changes:
                amendments.append({'pointer': pointer, 'assetId': identity,
                                   'before': {key: value.get(key) for key in changes}, 'after': changes})
                value.update(changes)
        for key, child in value.items():
            amend_recipes(child, replacements, banks, amendments, pointer + '/' + str(key))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            amend_recipes(child, replacements, banks, amendments, pointer + '/' + str(index))


def prepare(engine, root, apply=False):
    authoring = root / 'authoring'
    if authoring.exists():
        raise ValueError('Editable authoring already exists. Import will not overwrite client edits.')
    # Existing exporter provides effective authoring rather than stale Factory snapshots.
    source = json.loads(export_catalog(load_animation_data(), engine))
    catalog = source['catalog']
    world = source['world']
    delivery = json.loads((root / '.runtime/vfx-replacements/manifest.json').read_text())
    selected = {}
    for spell in delivery['spells']:
        for identity, item in spell['media'].items():
            if item['binding']['kind'] != 'preserved_actor_or_projectile_layer':
                if identity in selected and selected[identity] != item['binding']:
                    raise ValueError('Conflicting delivered binding: ' + identity)
                selected[identity] = item['binding']
    # Sunbeam's source numbers are effect headings, NOT rowOrder indices.
    # Recover the explicit mapping from the existing componentsByFacing metadata.
    beam = selected['solar.sunbeam.surface']
    source_components = catalog['projectile_storage']['solar.sunbeam.surface']['phases']['impact']['surfaceFrames']['componentsByFacing']
    beam['banks'] = {facing: beam['banks'][re.search(r'beam-(\d+)-surface', parts[0]['archive']['file']).group(1)]
                     for facing, parts in source_components.items()}
    selected['wall.frigid_air_d0.hold.back']['selection_basis'] = 'wall_axis'
    banks, owners = replacement_banks(root, delivery)
    amendments = []
    for identity, binding in selected.items():
        asset = catalog['projectile_assets'][identity]
        first = binding['bank'] if 'bank' in binding else next(iter(binding['banks'].values()))
        bank = banks[first]
        if binding['frame_window'] is None:
            binding['frame_window'] = [0, bank['frame_count']]
        start, end = binding['frame_window']
        fps = binding.get('playback_fps', bank['fps'])
        phases = {key: phase for key, phase in asset['phases'].items() if phase is not None}
        asset.update(sheet=None, preview=None, source=None, fps=fps, defaultScale=1.0,
                     anchorsByFacing=None,
                     frame={'width': bank['source_size_pixels'][0], 'height': bank['source_size_pixels'][1],
                            'cols': 1, 'rows': len(asset['rowOrder'])},
                     anchor={'x': bank['pivot_pixels'][0] / bank['source_size_pixels'][0],
                             'y': bank['pivot_pixels'][1] / bank['source_size_pixels'][1]})
        for name, phase in phases.items():
            phase.update(start=0, frames=end-start, fps=fps, loop=binding.get('loop', phase['loop']))
            # Named formed/clear anchors remain phase-relative and unchanged.
        catalog['projectile_storage'][identity] = {'phases': {name: {'paired': binding} for name in phases}}
    catalog['paired_banks'] = banks
    amend_recipes({key: value for key, value in catalog.items()
                   if key not in ('projectile_assets', 'projectile_storage', 'paired_banks')},
                  selected, banks, amendments, '/catalog')
    amend_recipes(world, selected, banks, amendments, '/world')
    # Frigid Air's replacement is 128 frames; the old 256-frame atlas is retired.
    for mapping in (catalog['spatial_media'], world['spatial_media']):
        binding = mapping['spatial_effect.spell.frigid_air']
        binding['holdStartFrame'] = 0
        binding['holdFrames'] = 128
    impact = catalog['drafts']['spell.ice_knife']['projectile']['impact']
    impact.update(enabled=True, composition='paired_depth', scale=1.0)
    amendments.append({'pointer': '/catalog/drafts/spell.ice_knife/projectile/impact/enabled',
                       'before': False, 'after': True, 'reason': 'Explicit delivered Ice Knife burst amendment'})
    # Retain all recipes and lifecycle sections. Remove only unreachable registrations.
    excluded = {'projectile_assets', 'projectile_storage', 'resources', 'paired_banks', 'context_source_json'}
    roots = {key: value for key, value in catalog.items() if key not in excluded}
    references = set(strings(roots)) | set(strings(world))
    asset_ids = set(catalog['projectile_assets'])
    wanted = references & asset_ids
    while True:
        more = set()
        for identity in wanted:
            more.update(strings(catalog['projectile_assets'][identity]))
            more.update(strings(catalog['projectile_storage'].get(identity, {})))
        references |= more
        new = wanted | (more & asset_ids)
        if new == wanted:
            break
        wanted = new
    catalog['projectile_assets'] = {k: v for k, v in catalog['projectile_assets'].items() if k in wanted}
    catalog['projectile_storage'] = {k: v for k, v in catalog['projectile_storage'].items() if k in wanted}
    if any(phase.get('surfaceFrames') for storage in catalog['projectile_storage'].values() for phase in storage['phases'].values()):
        raise ValueError('Selected authoring still contains retired XYZ storage')
    paths = location_map(root)
    image_assets = source['assets']
    image_assets['resources'] = {k: v for k, v in image_assets['resources'].items()
                                 if k in references or k in set(strings(image_assets['animations']))}
    # Complete real reference gaps exposed by the effective catalog, including
    # child spell outcomes omitted by the earlier copy tool. No broad directory copy.
    required = {v for v in strings(catalog) if v.startswith('game/assets/') and '{' not in v}
    required.update('game/assets/' + v['path'] for v in image_assets['resources'].values())
    required.difference_update(catalog['resources'].values())
    required.update(path for identity, path in catalog['resources'].items() if identity in references
                    and not identity.startswith('/spritesheets/'))
    asset_consumers = {}
    for draft_id, draft in catalog['drafts'].items():
        for asset_id in set(strings(draft)) & wanted:
            asset_consumers.setdefault(asset_id, set()).add('spells/' + draft_id.removeprefix('spell.'))
    file_consumers = {}
    for identity, storage in catalog['projectile_storage'].items():
        for filename in set(strings(storage)):
            if filename.startswith('game/assets/'):
                file_consumers.setdefault(filename, set()).update(asset_consumers.get(identity, ()))
    additions = []
    for relative in sorted(required - paths.keys()):
        source_path = engine / relative
        if source_path.suffix in ('.zip', '.npz', '.npy') or not source_path.is_file():
            raise ValueError('Unavailable selected source dependency: ' + relative)
        owners_for_file = set(file_consumers.get(relative, ()))
        if not owners_for_file:
            owners_for_file.add('shared/' + relative.split('/')[2])
        row = {'source': str(source_path), 'source_path': relative,
               'owners': sorted(owners_for_file), 'bytes': source_path.stat().st_size}
        row['payload'] = '.media/' + str(ordinary_path(row))
        if (root / row['payload']).exists():
            raise ValueError('New dependency collides with an installed file: ' + row['payload'])
        paths[relative] = '/media/' + row['payload'].removeprefix('.media/')
        additions.append(row)
    resources = {}
    for identity, path in catalog['resources'].items():
        if identity not in references:
            continue
        if identity.startswith('/spritesheets/'):
            member = identity.removeprefix('/spritesheets/')
            if (root / '.media/smallscale/modular' / member).is_file():
                resources[identity] = '/media/smallscale/modular/' + member
                continue
        resources[identity] = paths.get(path, path)
    catalog['resources'] = resources
    catalog['media_root'] = '.'
    catalog = relocate(catalog, paths)
    world = relocate(world, paths)
    for image in image_assets['resources'].values():
        image['path'] = paths['game/assets/' + image['path']]
    unresolved = sorted({v for v in strings(catalog) if v.startswith('game/assets/')})
    if unresolved:
        raise ValueError('Unresolved selected resource paths: ' + json.dumps(unresolved[:20]))
    # Validate the new copy against the same passive owners plus paired storage.
    checked = TypeAdapter(AnimationData).validate_json(json.dumps(catalog))
    WorldBindingsSource.model_validate_json(json.dumps(world))
    AssetDocument.model_validate_json(json.dumps(image_assets))
    compact_catalog = TypeAdapter(AnimationData).dump_python(checked, mode='json', by_alias=True, exclude_defaults=True)
    report = {'spell_and_effect_drafts': len(catalog['drafts']),
              'condition_recipes': len(catalog['condition_recipes']),
              'condition_layers': len(catalog['condition_media']),
              'media_assets': len(catalog['projectile_assets']), 'paired_banks': len(banks),
              'replacement_media_ids': len(selected), 'resources': len(resources),
              'source': str(engine), 'amendments': amendments,
              'additional_referenced_files': len(additions), 'additional_bytes': sum(r['bytes'] for r in additions)}
    print(json.dumps({k: v for k, v in report.items() if k != 'amendments'}, indent=2), flush=True)
    if not apply:
        return report
    for row in additions:
        write_asset(root / row['payload'], Path(row['source']).read_bytes())
    receipt = root / '.runtime/vfx-assets/files.jsonl'
    with receipt.open('a') as output:
        for row in additions:
            output.write(json.dumps(row) + '\n')
    # One file per existing map entry where useful; no duplicated draft/condition catalogs.
    mapping = {}
    split_fields = {'drafts': 'spells', 'projectile_assets': 'media/definitions',
                    'projectile_storage': 'media/storage', 'paired_banks': 'media/banks'}
    for key, value in compact_catalog.items():
        if key in world:
            if catalog[key] != world[key]:
                raise ValueError('Source world/catalog disagree: ' + key)
            mapping[key] = 'world.json#/' + key
            continue
        if key in split_fields:
            mapping[key] = {}
            for identity, item in value.items():
                filename = identity.replace(':', '-') + '.json'
                path = authoring / split_fields[key] / filename
                write_json(path, item, compact=key in ('projectile_storage', 'paired_banks'))
                mapping[key][identity] = str(path.relative_to(authoring))
        else:
            path = authoring / 'catalog' / (key + '.json')
            write_json(path, value)
            mapping[key] = str(path.relative_to(authoring))
    write_json(authoring / 'catalog-index.json', mapping)
    write_json(authoring / 'world.json', WorldBindingsSource.model_validate_json(json.dumps(world)).model_dump(mode='json', by_alias=True, exclude_defaults=True))
    write_json(authoring / 'assets.json', AssetDocument.model_validate_json(json.dumps(image_assets)).model_dump(mode='json', by_alias=True))
    schema = TypeAdapter(AnimationData).json_schema(mode='serialization')
    schema['$schema'] = 'https://json-schema.org/draft/2020-12/schema'
    write_json(authoring / 'schemas/animation.schema.json', schema)
    write_json(root / '.runtime/vfx-assets/authoring-import.json', report)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    prepare(args.engine.resolve(), args.root.resolve(), args.apply)
