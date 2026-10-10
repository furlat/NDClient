"""Copy the selected Factory delivery and its live dependencies, never legacy XYZ.

This is offline asset intake. The delivered bindings stay authoritative; only
installed file locations change. No re-export, packing or runtime implementation.
"""
import argparse
from collections import defaultdict
import json
import os
from pathlib import Path

from asset_paths import named_path, write_asset
from prepare_vfx_assets import record_installed_replacements
from vfx_layout import bank_folder


def values(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from values(item)
    elif isinstance(value, list):
        for item in value:
            yield from values(item)


def relocate(value, paths):
    if isinstance(value, str):
        return paths.get(value, value)
    if isinstance(value, dict):
        return {key: relocate(item, paths) for key, item in value.items()}
    if isinstance(value, list):
        return [relocate(item, paths) for item in value]
    return value


def prepare(delivery, factory, engine, destination, copy):
    document = json.loads(delivery.read_text())
    media_root = destination / '.media'
    receipt = destination / '.runtime/vfx-replacements'
    target_root = receipt
    existing = {row['source_path']: row for line in
                (destination / '.runtime/vfx-assets/files.jsonl').read_text().splitlines()
                if (row := json.loads(line))}
    dependencies, modular, bank_owners = defaultdict(set), {}, defaultdict(set)
    for spell in document['spells']:
        owner = 'spells/' + spell['spell']
        for identity, item in spell['media'].items():
            binding = item['binding']
            if binding['kind'] == 'preserved_actor_or_projectile_layer':
                group = 'conditions/' + identity if identity in spell['shared_conditions'] else owner
                for path in values(item['production_storage']):
                    if path.startswith('game/assets/'):
                        dependencies[path].add(group)
            else:
                banks = [binding['bank']] if 'bank' in binding else binding['banks'].values()
                for bank in banks:
                    bank_owners[bank].add(spell['spell'])
        for identity, resource in spell['runtime_resources'].items():
            relative = 'game/assets/' + resource['path'].split('/game/assets/', 1)[1]
            dependencies[relative].add(owner)
            if identity.startswith('/spritesheets/'):
                member = identity.removeprefix('/spritesheets/')
                if (media_root / 'smallscale/modular' / member).is_file():
                    modular[relative] = member

    # Live operator JSON uses sibling texture filenames. Follow those declared
    # files, preserving the directory layout and the original JSON bytes.
    companion_targets = {}
    for relative in list(dependencies):
        if relative.endswith('.json'):
            source = engine / relative
            data = json.loads(source.read_text())
            parent = (destination / existing[relative]['payload'] if relative in existing
                      else media_root / named_path('vfx-assets', {
                          'source_path': relative, 'owners': sorted(dependencies[relative])}))
            for texture in data.get('textures', {}).values():
                dependency = str((source.parent / texture['file']).relative_to(engine))
                dependencies[dependency].update(dependencies[relative])
                companion_targets[dependency] = parent.parent / texture['file']

    if set(bank_owners) != set(document['banks']):
        raise ValueError('Delivered bank references differ: ' + str(
            set(bank_owners).symmetric_difference(document['banks'])))
    jobs, rows, paths = [], [], {}
    bank_documents = {}
    copy_bytes = 0
    for relative, owners in sorted(dependencies.items()):
        if Path(relative).suffix in ('.zip', '.npz', '.npy'):
            raise ValueError('Legacy/archive dependency in live resource selection: ' + relative)
        row = dict(source=str(engine / relative), source_path=relative, owners=sorted(owners))
        if relative in modular:
            target = media_root / 'smallscale/modular' / modular[relative]
        elif relative in existing:
            target = destination / existing[relative]['payload']
        else:
            target = companion_targets.get(relative, media_root / named_path('vfx-assets', row))
            jobs.append((engine / relative, target))
            copy_bytes += (engine / relative).stat().st_size
        row.update(payload=str(target.relative_to(destination)),
                   bytes=(target if target.exists() else engine / relative).stat().st_size)
        rows.append(row)
        paths[relative] = os.path.relpath(target, target_root)
    for bank, entry in document['banks'].items():
        source = factory / entry['manifest']
        bank_media = media_root / bank_folder(sorted(bank_owners[bank])[0], bank)
        target = receipt / 'bank-sources' / bank.replace(':', '-') / 'manifest.json'
        manifest = json.loads(source.read_text())
        jobs.append((source, target))
        copy_bytes += source.stat().st_size + entry['bytes']
        for frame in manifest['frames']:
            for layer in frame['layers'].values():
                for plane in ('appearance', 'geometry'):
                    if layer[plane] is not None:
                        filename = layer[plane]['file']
                        jobs.append((source.parent / filename, bank_media / filename))
                        layer[plane]['file'] = os.path.relpath(bank_media / filename, target.parent)
        bank_documents[target] = manifest
        entry['manifest'] = os.path.relpath(target, target_root)

    # Keep recipes, media identities, windows, sockets, parts and shared condition
    # ownership. Historical paired production_storage/packed_files are NOT a
    # second delivery: the Factory binding replaces them. Source retains them.
    for spell in document['spells']:
        kept_files = set()
        for item in spell['media'].values():
            if item['binding']['kind'] == 'preserved_actor_or_projectile_layer':
                kept_files.update(p for p in values(item['production_storage']) if p in paths)
                item['production_storage'] = relocate(item['production_storage'], paths)
            else:
                item.pop('production_storage', None)
        spell['packed_files'] = {paths[path]: {'exists': True, 'bytes': (engine / path).stat().st_size}
                                 for path in sorted(kept_files)}
        for identity, resource in spell['runtime_resources'].items():
            relative = 'game/assets/' + resource['path'].split('/game/assets/', 1)[1]
            resource['path'] = paths[relative]
            # The original checksum describes source bytes, which are deliberately
            # superseded for modular casting accents by the selected full V1.3.
            resource.pop('sha256', None)
    document['source_snapshot'] = [str(factory / path) for path in document['source_snapshot']]
    document['regeneration_selection'] = str(factory / document['regeneration_selection'])
    report = dict(source_manifest=str(delivery),
                  installed_manifest=str((target_root / 'manifest.json').relative_to(destination)),
                  spell_families=[s['spell'] for s in document['spells']],
                  paired_banks=len(document['banks']),
                  media_ids=len({key for spell in document['spells'] for key in spell['media']}),
                  replaced_media_ids=sorted({key for spell in document['spells']
                      for key, item in spell['media'].items()
                      if item['binding']['kind'] != 'preserved_actor_or_projectile_layer'}),
                  resolved_xyz_references=sorted(document['runtime_pending_xyz_covered']),
                  paired_packet_bytes=sum(bank['bytes'] for bank in document['banks'].values()),
                  copy_files=len(jobs), copy_bytes=copy_bytes,
                  retained_runtime_files=len(rows), renderer_integrated=False)
    print(json.dumps(report, indent=2), flush=True)
    if not copy:
        return
    for index, (source, target) in enumerate(jobs, 1):
        content = ((json.dumps(bank_documents[target], indent=2) + '\n').encode()
                   if target in bank_documents else source.read_bytes())
        write_asset(target, content)
        rows.append(dict(source=str(source), payload=str(target.relative_to(destination)),
                         bytes=len(content)))
        if index % 10000 == 0:
            print(f'Copied {index}/{len(jobs)} files', flush=True)
    write_asset(target_root / 'manifest.json', (json.dumps(document, indent=2) + '\n').encode())
    write_asset(target_root / 'README.md', (
        '# Completed selected VFX delivery\n\n'
        'Entry point: `manifest.json`. The original 23 families plus five additional '
        'spells are installed in named spell/bank folders. This includes 193 paired '
        'banks and the delivered aliases for all 38 formerly pending XYZ references.\n\n'
        'Manifest bank/runtime/packed-file paths are relative to this receipt folder; packet '
        'paths inside each bank manifest are relative to that bank. Conditions and '
        'existing dependencies retain their separate folders; modular accents reuse '
        '`smallscale/modular`. Original source definitions remain for context; '
        'paired bindings replace their historical storage and frame selection. '
        'Historical XYZ archives and replaced packed pages are not imported.\n\n'
        f'[Original author handoff]({delivery.with_name('HANDOFF.md')}). '
        'Recipes, direction mappings, '
        'windows, coalescing groups, matrices, crops and radiance remain authored. '
        'Do not draw historical wall halves twice or treat geometry alpha as opacity. '
        'Copy completion does not implement the renderer; Ice Knife burst still '
        'requires the explicit runtime wiring described in the handoff.\n').encode())
    receipt.mkdir(parents=True, exist_ok=True)
    # Dependency rows already describe newly copied live files; record each
    # destination once, retaining its source owner information.
    by_payload = {}
    for row in rows:
        by_payload.setdefault(row['payload'], row)
    (receipt / 'files.jsonl').write_text(''.join(json.dumps(row) + '\n' for row in by_payload.values()))
    (receipt / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    record_installed_replacements(destination)
    print('Copy complete:', target_root, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--delivery', type=Path, required=True, help='Factory delivery manifest.json')
    parser.add_argument('--factory', type=Path, required=True)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--destination', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--copy', action='store_true')
    args = parser.parse_args()
    prepare(args.delivery, args.factory, args.engine, args.destination, args.copy)
