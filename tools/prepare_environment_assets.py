"""Copy the agreed environment artwork and authored source records, unchanged.

Offline intake only: uses existing selections and catalog entries, writes a copy
receipt, and never creates runtime bindings or modifies the original sources.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import struct

from asset_paths import named_path, write_asset


AUTHORING_DELIVERY = 'data-authoring-2026-10-09'


def authoring_references(catalog: Path):
    source = catalog / AUTHORING_DELIVERY
    if not (source / 'authoring-records.json').is_file():
        raise FileNotFoundError(f'Authored delivery missing: {source}')
    # Copy data and reproducible measurement provenance, not review artwork or
    # HTML galleries. Relative evidence paths remain in their original layout.
    suffixes = {'.json', '.csv', '.txt', '.meta', '.asset', '.py', '.mjs'}
    return {path: Path('catalog') / path.relative_to(catalog)
            for path in sorted(source.rglob('*'))
            if path.is_file() and path.suffix in suffixes}


def copy_references(destination: Path, references):
    snapshots = []
    for path, relative in sorted(references.items()):
        data = path.read_bytes()
        target = destination / '.runtime/environment-assets/authoring-reference' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        snapshots.append(dict(source=str(path), snapshot=str(target.relative_to(destination)),
                              bytes=len(data)))
    return snapshots


def prepare_authoring_only(destination: Path, catalog: Path) -> None:
    receipt = destination / '.runtime/environment-assets'
    # This mode supplements an existing artwork intake; it cannot manufacture
    # a media receipt or activate the supplied candidate profiles.
    summary = json.loads((receipt / 'summary.json').read_text())
    existing = {row['snapshot']: row for row in
                map(json.loads, (receipt / 'references.jsonl').read_text().splitlines())}
    delivered = copy_references(destination, authoring_references(catalog))
    existing.update({row['snapshot']: row for row in delivered})
    rows = sorted(existing.values(), key=lambda row: row['snapshot'])
    (receipt / 'references.jsonl').write_text(''.join(json.dumps(row) + '\n' for row in rows))
    summary.update(reference_files=len(rows), reference_bytes=sum(row['bytes'] for row in rows))
    (receipt / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(dict(delivery=AUTHORING_DELIVERY, copied_reference_files=len(delivered),
                          copied_reference_bytes=sum(row['bytes'] for row in delivered),
                          reference_files=summary['reference_files'],
                          reference_bytes=summary['reference_bytes']), indent=2))


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from strings(child)


def prepare(engine: Path, destination: Path, catalog: Path) -> None:
    receipt = destination / '.runtime/environment-assets'
    receipt.mkdir(parents=True, exist_ok=True)
    art = json.loads((engine / 'game/data/environment_art.json').read_text())
    selected = json.loads((catalog / 'provenance/production/fantasy-selected-media.json').read_text())
    entries = json.loads((catalog / 'catalog.json').read_text())['entries']
    # Current documents own the payloads; the catalog supplies the agreed Fantasy scope.
    current = {section: {key: art[section][key] for key in values}
               for section, values in selected.items() if section in art}
    assets = json.loads((engine / 'game/data/assets.json').read_text())
    world = json.loads((engine / 'game/data/world_bindings.json').read_text())
    world_roles = {key: world[key] for key in (
        'terrain', 'terrain_cliff', 'terrain_stairs', 'stone_wall_straight',
        'stone_wall_corner', 'wood_wall_straight', 'wood_wall_corner',
        'stone_door_frame', 'wood_door_closed', 'wood_door_open', 'props')}
    world_roles['spatial_effects'] = {k: v for k, v in world['spatial_effects'].items()
                                     if k.startswith('spatial_effect.environment.')}
    world_roles['animations'] = assets['animations']
    world_roles['water'] = assets['water']
    resource_ids = sorted(set(strings(world_roles)) & assets['resources'].keys())
    devices = json.loads((engine / 'game/data/spell_devices.json').read_text())
    portals = json.loads((engine / 'game/data/portals.json').read_text())
    hatch = portals['bindings']['spatial_effect.environment.portal_hatch']['hatch']

    media = {}
    references = {}
    exclusions = []
    entry_records = []

    def add_media(path, category, owner, status='existing source'):
        row = media.setdefault(path, dict(source=str(path), categories=set(), owners=set(), statuses=set()))
        row['categories'].add(category)
        row['owners'].add(owner)
        row['statuses'].add(status)

    def add_reference(path, relative):
        if not path.is_file():
            raise FileNotFoundError(f'Authored reference missing: {path}')
        references[path] = Path(relative)

    def add_tree(source, relative, suffixes):
        for path in sorted(source.rglob('*')):
            if path.is_file() and path.suffix in suffixes:
                add_reference(path, Path(relative) / path.relative_to(source))

    def current_payloads(document, owner):
        for value in sorted(set(strings(document))):
            if value.lower().endswith(('.png', '.webp', '.bin')):
                add_media(engine / 'game/assets' / value, 'current-environment', owner, 'currently selected')

    current_payloads(current, 'environment_art.json Fantasy selections')
    current_payloads({key: assets['resources'][key] for key in resource_ids}, 'assets.json world resources')
    current_payloads(devices, 'spell_devices.json')
    current_payloads(hatch, 'portals.json hatch')

    # Review composites are documentary output, not source animation frames.
    review_names = {'review-contact.png', 'source-rest-comparison.png', 'contact.png',
                    'aim-contact.png', 'author-component-review.png', 'author-finish-review.png',
                    'author-floor-review.png', 'author-review.png', 'depth-contact.png',
                    'phase-contact.png', 'room-review.png', 'comparison.png'}
    for entry in entries:
        identity = entry['id']
        outside = (identity.startswith('created.arena.') or
                   entry['kind'] in {'Characters', 'Other', 'Source metadata'} or
                   identity.startswith('vendor-package.animations-effects-') or
                   identity == 'vendor-package.animations-props-skeleton-explosion')
        if outside:
            exclusions.append(dict(source=identity, reason='arena/crowd, other family or archive/provenance package'))
            continue
        category = 'original-fantasy' if entry['group'] == 'A' else 'authored-environment'
        entry_records.append(dict(id=identity, status=entry['status'],
                                  native_ids=entry.get('native_ids', []),
                                  variants=[{k: v[k] for k in ('name', 'status', 'metadata') if k in v}
                                            for v in entry['variants']]))
        if entry['group'] == 'A':
            chosen = set(entry['files'])
        else:
            # Curated variants contain source sheets/states/companions. The wider
            # entry also lists Blender dependencies and old loose raw exports.
            chosen = {p for variant in entry['variants'] for p in variant.get('files', [])}
            chosen.update(view['path'] for view in entry['views'].values())
            chosen.update(p for p in entry['files'] if p.startswith('provenance/door-trap-depth/'))
            chosen.update(p for p in entry['files'] if Path(p).suffix in {'.json', '.md'})
            # Static decals have no animation variant.
            if entry['kind'] == 'decals':
                chosen.update(entry['files'])
        frame_exports = set()
        for variant in entry['variants']:
            meta = variant.get('metadata')
            if not meta:
                continue
            mp = catalog / meta
            chosen.add(meta)
            data = json.loads(mp.read_text())
            packed = [value for key in ('sheet', 'sheets') for value in strings(data.get(key))
                      if value.endswith('.png') and (mp.parent / value).is_file()]
            if packed:
                for frame in data.get('frames', []):
                    if isinstance(frame, dict) and 'file' in frame:
                        frame_exports.add(str((Path(meta).parent / frame['file'])))
                chosen.update(str(Path(meta).parent / p) for p in packed)
        for name in sorted(chosen):
            path = catalog / name
            if path.suffix == '.png':
                if path.name in review_names:
                    exclusions.append(dict(source=str(path), reason='review composite'))
                elif name in frame_exports:
                    exclusions.append(dict(source=str(path), reason='loose frame already represented by declared source sheet'))
                else:
                    add_media(path, category, identity, entry['status'])
                    if entry['group'] == 'A':
                        rel = name.removeprefix('a-original/vendor/Fantasy tileset - 2D Isometric/')
                        candidates = [rel, rel.replace('Environment/', 'Environment/Sprites/', 1)]
                        for item in candidates:
                            sidecar = catalog / 'a-original/unity-import-provenance' / (item + '.meta')
                            if sidecar.is_file():
                                add_reference(sidecar, Path('catalog') / sidecar.relative_to(catalog))
            elif path.suffix in {'.json', '.md', '.anim', '.controller'}:
                add_reference(path, Path('catalog') / name)

    # Existing metadata is preserved byte-for-byte; these are source snapshots,
    # not a second editable registry or a production presentation release.
    engine_files = ['game/data/' + name for name in (
        'assets.json', 'world_bindings.json', 'environment_art.json',
        'environment_prop_sources.json', 'window_media_sources.json',
        'solid_wall_media_sources.json', 'spell_devices.json', 'portals.json')]
    engine_files += ['dnd/content/items/' + name for name in (
        'world_prop_builders.py', 'environment_item_builders.py', 'door_profiles.py',
        'window_definitions.py', 'window_builders.py', 'trap_hardware_builders.py',
        'ground_hardware_builders.py', 'authored_item_definitions.py')]
    engine_files += ['dnd/types/world_placement.py', 'game/projection.py',
                     'game/environment_art.py', 'game/asset_types.py', 'game/world_binding_types.py']
    engine_files += ['agent_docs/' + name for name in (
        'PIXI_WALL_DOOR_ELEVATION_POSITIONING_HANDOFF_2026-10-08.md',
        'NDCLIENT_ENVIRONMENT_ASSET_RECOVERY_HANDOFF_2026-10-08.md',
        'WALL_BREAKABILITY_PIXI_HANDOFF_2026-10-08.md',
        'WALL_FLOOR_ASSET_ALIGNMENT_HANDOFF_2026-10-06.md',
        'audits/WALL_FLOOR_ASSET_ALIGNMENT_AUDIT_2026-10-06.json')]
    for name in engine_files:
        add_reference(engine / name, Path('engine') / name)
    add_tree(engine / 'agent_docs/audits/ndclient-environment-assets-20261009',
             'migration-handoff', {'.md', '.csv'})
    for name in ('catalog.json', 'provenance/production/fantasy-selected-media.json'):
        add_reference(catalog / name, Path('catalog') / name)
    for path in (catalog / 'provenance/production').glob('*.json'):
        add_reference(path, Path('catalog') / path.relative_to(catalog))
    references.update(authoring_references(catalog))
    for name in ('c-new-props/arena-kit/tile-connections.json',
                 'c-new-props/arena-kit/constructor/themes/ground-sources.json',
                 'c-new-props/arena-kit/constructor/themes/roof-sources.json'):
        add_reference(catalog / name, Path('catalog') / name)
    registration = Path('/mnt/c/Users/tommaso/Documents/assets/environment-production-audit/placement-registration-53')
    add_tree(registration, 'placement-registration-53', {'.json', '.txt', '.md'})
    architecture = Path('/home/tommaso/.codex/worktrees/23a9/dnd_engine/output/environment-sprites')
    add_tree(architecture / 'architecture-handoff', 'architecture-handoff', {'.json', '.md', '.txt'})
    for path in sorted((architecture / 'door-workshop/families').glob('fantasy-*/metadata.json')):
        add_reference(path, Path('door-workshop') / path.relative_to(architecture / 'door-workshop'))
    prefab = Path('/home/tommaso/Dev/terrain-prefab-study-2026-09-24/house-prefabs/room-dressing/prefab-review')
    for path in sorted(prefab.glob('*-layout.json')):
        add_reference(path, Path('prefab-review') / path.name)
    constructor = Path('/mnt/c/Users/tommaso/Documents/assets/arena-study/prototype-v1/grid-kit/constructor')
    for name in ('review/unity-reference/compositions.json', 'DISTRICT_RULES.md', 'RULES.md',
                 'themes/source-manifest.json', 'themes/ground-sources.json', 'themes/roof-sources.json',
                 'encounter-art/unity-motifs.json', 'encounter-art/manifest.json'):
        add_reference(constructor / name, Path('constructor-reference') / name)
    editor = Path('/home/tommaso/Dev/NeuroMapEditor')
    for sub in ('src/model', 'src/import'):
        add_tree(editor / sub, Path('editor') / sub, {'.ts'})
    for name in ('src/render/spritePresentation.ts', 'src/render/orderPhaseOne.ts',
                 'docs/PHASE_ONE_IMPLEMENTATION_RECORD.md',
                 'docs/WESTERN_MULTI_HEIGHT_VERTICAL_COMPLETION_STUDY.md',
                 'public/assets/unity-reference/scene.json',
                 'public/assets/unity-reference/semantics.json',
                 'public/assets/unity-reference/manifest.json'):
        add_reference(editor / name, Path('editor') / name)

    for path in media:
        if not path.is_file():
            raise FileNotFoundError(f'Artwork missing: {path}')
    records = []
    for index, (path, selected_by) in enumerate(sorted(media.items())):
        data = path.read_bytes()
        row = {k: sorted(v) if isinstance(v, set) else v for k, v in selected_by.items()}
        payload = destination / '.media' / named_path('environment-assets', row)
        write_asset(payload, data)
        row.update(bytes=len(data), payload=str(payload.relative_to(destination)))
        if path.suffix.lower() == '.png':
            if data[:8] != b'\x89PNG\r\n\x1a\n':
                raise ValueError(f'Expected PNG: {path}')
            row['width'], row['height'] = struct.unpack('>II', data[16:24])
        records.append(row)
        if index % 500 == 0:
            print(f'Copied {index + 1}/{len(media)} source media files', flush=True)
    snapshots = copy_references(destination, references)
    categories = {}
    for category in ('original-fantasy', 'authored-environment', 'current-environment'):
        grouped = [row for row in records if category in row['categories']]
        payloads = {row['payload']: row['bytes'] for row in grouped}
        categories[category] = dict(source_files=len(grouped), files=len(payloads),
                                    copied_bytes=sum(payloads.values()))
    result = dict(purpose='Environment artwork and authored-data intake; no new bindings or runtime release',
                  source_files=len(records), copied_bytes=sum(r['bytes'] for r in records),
                  reference_files=len(snapshots), reference_bytes=sum(x['bytes'] for x in snapshots),
                  categories=categories, entry_count=len(entry_records),
                  current_bank_count=len(current['banks']), current_world_resources=len(resource_ids),
                  exclusions_by_reason=dict(Counter(x['reason'] for x in exclusions)))
    (receipt / 'files.jsonl').write_text(''.join(json.dumps(row) + '\n' for row in records))
    (receipt / 'references.jsonl').write_text(''.join(json.dumps(row) + '\n' for row in snapshots))
    (receipt / 'entries.json').write_text(json.dumps(entry_records, indent=2) + '\n')
    (receipt / 'excluded.jsonl').write_text(''.join(json.dumps(row) + '\n' for row in exclusions))
    (receipt / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--destination', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--catalog', type=Path, default=Path('/mnt/c/Users/tommaso/Documents/assets/fantasy-unified-catalog'))
    parser.add_argument('--authoring-only', action='store_true',
                        help='Supplement the existing receipt with the 9 October metadata delivery; do not process artwork')
    args = parser.parse_args()
    if args.authoring_only:
        prepare_authoring_only(args.destination, args.catalog)
    else:
        prepare(args.engine, args.destination, args.catalog)
