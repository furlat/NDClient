"""One-time environment layout and source-record adoption, without new artwork.

Preview by default; --apply moves only installed copies, updates their authoring
URLs/receipts and splits the existing EnvironmentDocument into family files.
Original engine and artist documents are never modified.
"""
import argparse
import json
from pathlib import Path

from environment_layout import environment_media_path, write_environment


def replace_urls(value, replacements):
    if isinstance(value, str):
        return replacements.get(value, value)
    if isinstance(value, list):
        return [replace_urls(child, replacements) for child in value]
    if isinstance(value, dict):
        return {key: replace_urls(child, replacements) for key, child in value.items()}
    return value


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + '\n')


def source_records(root, environment, rows):
    source_root = root / '.runtime/environment-assets/authoring-reference/catalog'
    delivery = json.loads((source_root / 'data-authoring-2026-10-09/authoring-records.json').read_text())
    catalog = {row['id']: row for row in json.loads((source_root / 'catalog.json').read_text())['entries']}
    groups = {'door': 'doors', 'misc': 'props', 'ambiguous': 'props',
              'interior': 'interiors', 'decal': 'decals'}
    output = {}
    # Preserve units, confidence/proposal qualifications and camera conventions
    # once; records point back here instead of replicating them per asset.
    output['environment/source-records/context.json'] = {
        key: delivery[key] for key in ('schema', 'authored_date', 'status', 'units',
                                      'source_documents', 'excluded_content_decisions')}
    for entry in delivery['records']:
        record = entry['record']
        identity = record['catalog_id']
        identities = {identity, record.get('modified_id')} - {None}
        relative = f"environment/source-records/{groups[entry['section']]}/{identity}.json"
        installed = {}
        for row in rows:
            if identities.intersection(row['owners']):
                original = row['source'].split('/fantasy-unified-catalog/', 1)[-1]
                installed[original] = '/media/' + row['payload'].removeprefix('.media/')
        output[relative] = dict(entry, context='../context.json', installed_media=installed)
        # Retain only existing native assignments, never create a binding for a
        # library asset or turn a source proposal into collision/placement truth.
        for source_id in identities:
            for native_id in catalog.get(source_id, {}).get('native_ids', []):
                for section in ('doors', 'props'):
                    if native_id in environment[section]:
                        environment[section][native_id]['authoring_record'] = relative
    return output


def prepare(root, apply=False):
    authoring = root / 'authoring'
    old_document = authoring / 'environment.json'
    if (authoring / 'environment/index.json').exists():
        raise ValueError('Environment already organized; edit its tracked files directly.')
    environment = json.loads(old_document.read_text())
    receipt = root / '.runtime/environment-assets/files.jsonl'
    rows = [json.loads(line) for line in receipt.read_text().splitlines()]
    moves, replacements, targets = {}, {}, set()
    for row in rows:
        previous = row['payload']
        target = str(Path('.media') / environment_media_path(row['source']))
        if target in targets:
            raise ValueError('Two sources would overwrite the same file: ' + target)
        targets.add(target)
        if not (root / previous).is_file():
            raise FileNotFoundError(previous)
        if target != previous:
            if (root / target).exists():
                raise ValueError('Destination already exists: ' + target)
            moves[previous] = target
            replacements['/media/' + previous.removeprefix('.media/')] = '/media/' + target.removeprefix('.media/')
        row['payload'] = target
    environment = replace_urls(environment, replacements)
    records = source_records(root, environment, rows)
    changed = {}
    for path in authoring.rglob('*.json'):
        if path == old_document:
            continue
        value = json.loads(path.read_text())
        updated = replace_urls(value, replacements)
        if updated != value:
            changed[path] = updated
    world_path = authoring / 'world.json'
    world = changed.get(world_path, json.loads(world_path.read_text()))
    # Existing game/app.py wall rule; cliffs already have their own authored map.
    world['wall_corner_faces'] = {'e': ['north', 'east'], 's': ['east', 'south'],
                                 'w': ['south', 'west'], 'n': ['west', 'north']}
    changed[world_path] = world
    report = {'installed_files_to_move': len(moves), 'changed_authoring_files': len(changed),
              'banks': len(environment['banks']), 'source_records': len(records) - 1,
              'applied': apply}
    if not apply:
        return report
    # Keep a small local relocation record. This is not a runtime manifest and
    # contains no copied media or checksum bookkeeping.
    write_json(root / '.runtime/environment-assets/relocation.json', moves)
    for previous, target in moves.items():
        destination = root / target
        destination.parent.mkdir(parents=True, exist_ok=True)
        (root / previous).rename(destination)
    for path, value in changed.items():
        write_json(path, value)
    for relative, record in records.items():
        write_json(authoring / relative, record)
    write_environment(authoring, environment)
    old_document.unlink()
    receipt.write_text(''.join(json.dumps(row) + '\n' for row in rows))
    # Remove emptied import wrapper directories only.
    for path in sorted((root / '.media/environment').rglob('*'), key=lambda p: len(p.parts), reverse=True):
        if path.is_dir() and not any(path.iterdir()):
            path.rmdir()
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    print(json.dumps(prepare(args.root, args.apply), indent=2))
