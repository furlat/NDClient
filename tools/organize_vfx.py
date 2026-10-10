"""Relocate the installed VFX once, updating intake references without recopying artwork."""
import argparse
import json
import os
from pathlib import Path

from vfx_layout import bank_folder, ordinary_path


def read_rows(path):
    return [json.loads(line) for line in path.read_text().splitlines()]


def rewrite(value, paths):
    if isinstance(value, str):
        return paths.get(value, value)
    if isinstance(value, dict):
        return {paths.get(k, k): rewrite(v, paths) for k, v in value.items()}
    if isinstance(value, list):
        return [rewrite(v, paths) for v in value]
    return value


def organize(root, apply=False):
    ordinary = root / '.runtime/vfx-assets'
    replacement = root / '.runtime/vfx-replacements'
    summary = json.loads((replacement / 'summary.json').read_text())
    old_entry = root / summary['installed_manifest']
    if (root / 'authoring').exists():
        raise ValueError('Editable authoring exists; update its references explicitly before reorganizing.')
    if old_entry.parent == replacement:
        raise ValueError('This one-time layout migration is already complete.')
    manifest = json.loads(old_entry.read_text())
    rows = read_rows(ordinary / 'files.jsonl') + read_rows(replacement / 'files.jsonl')
    source_rows = {}
    for row in rows:
        if 'source_path' in row:
            target = source_rows.setdefault(row['source_path'], dict(row, owners=[]))
            target['owners'] = sorted(set(target['owners']) | set(row['owners']))
    moves = {}
    for row in source_rows.values():
        if 'modular_member' not in row and row['payload'].startswith('.media/smallscale/modular/'):
            row['modular_member'] = row['payload'].split('.media/smallscale/modular/', 1)[1]
        moves[row['payload']] = str(Path('.media') / ordinary_path(row))
    # Keep JSON mesh/operator data next to the explicitly relative textures.
    for row in source_rows.values():
        old = root / row['payload']
        if old.suffix == '.json':
            data = json.loads(old.read_text())
            for texture in data.get('textures', {}).values():
                sibling = str((old.parent / texture['file']).relative_to(root))
                if sibling not in moves:
                    raise ValueError('Uninstalled declared companion: ' + sibling)
                moves[sibling] = str(Path(moves[row['payload']]).parent / texture['file'])
    bank_owner = {}
    for spell in manifest['spells']:
        for item in spell['media'].values():
            binding = item['binding']
            for bank in ([binding['bank']] if 'bank' in binding else binding.get('banks', {}).values()):
                bank_owner.setdefault(bank, spell['spell'])
    for bank, entry in manifest['banks'].items():
        old = (old_entry.parent / entry['manifest']).resolve()
        new = root / '.media' / bank_folder(bank_owner[bank], bank) / 'manifest.json'
        data = json.loads(old.read_text())
        moves[str(old.relative_to(root))] = str(new.relative_to(root))
        for frame in data['frames']:
            for layer in frame['layers'].values():
                for plane in ('appearance', 'geometry'):
                    if layer[plane]:
                        name = layer[plane]['file']
                        moves[str((old.parent / name).relative_to(root))] = str((new.parent / name).relative_to(root))
    destinations = {}
    for old, new in moves.items():
        if new in destinations and destinations[new] != old:
            raise ValueError(f'Destination collision: {old}, {destinations[new]} -> {new}')
        destinations[new] = old
        if not (root / old).is_file():
            raise ValueError('Missing installed file: ' + old)
        if new != old and (root / new).exists():
            raise ValueError('Destination already exists: ' + new)
    print(json.dumps({'files': len(moves), 'moves': sum(a != b for a, b in moves.items()),
                      'sample': list(moves.items())[:12]}, indent=2), flush=True)
    if not apply:
        return
    # Save readable relocation evidence before the first mutation. No byte hashes.
    (replacement / 'relocation.json').write_text(json.dumps(moves, indent=2) + '\n')
    for old, new in moves.items():
        if new == old:
            continue
        target = root / new
        target.parent.mkdir(parents=True, exist_ok=True)
        (root / old).rename(target)
    new_entry = replacement / 'manifest.json'
    relative = {os.path.relpath(root / old, old_entry.parent):
                os.path.relpath(root / new, new_entry.parent) for old, new in moves.items()}
    manifest = rewrite(manifest, relative)
    new_entry.write_text(json.dumps(manifest, indent=2) + '\n')
    if old_entry != new_entry:
        old_entry.unlink()
    for folder in (ordinary, replacement):
        rows = read_rows(folder / 'files.jsonl')
        for row in rows:
            row['payload'] = moves.get(row['payload'], row['payload'])
        (folder / 'files.jsonl').write_text(''.join(json.dumps(row) + '\n' for row in rows))
    replacements = {**moves, summary['installed_manifest']: str(new_entry.relative_to(root))}
    for folder in (ordinary, replacement):
        for name in ('selection.json', 'summary.json', 'copy-check.json'):
            path = folder / name
            if path.exists():
                path.write_text(json.dumps(rewrite(json.loads(path.read_text()), replacements), indent=2) + '\n')
    for path in list((root / '.media/vfx').glob('*/intake-index.json')) + list((ordinary / 'owners').glob('*/intake-index.json')):
        target = ordinary / 'owners' / path.parent.name / path.name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(rewrite(json.loads(path.read_text()), replacements), indent=2) + '\n')
        if path != target:
            path.unlink()
    # Historical installation notes belong with the receipt, not the image bank.
    old_readme = old_entry.with_name('README.md')
    if old_entry.parent != replacement and old_readme.exists():
        old_readme.rename(replacement / 'original-installation-notes.md')
    for path in sorted((root / '.media/vfx').rglob('*'), reverse=True):
        if path.is_dir() and not any(path.iterdir()):
            path.rmdir()
    (root / '.media/vfx/README.md').write_text(
        '# VFX artwork\n\nNamed spells, area effects, conditions, actions and shared resources.\n'
        'Editable authoring lives in the tracked `authoring/` folder at repository root.\n'
        'Preparation receipts are under `.runtime/vfx-assets/` and `.runtime/vfx-replacements/`.\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    organize(args.root, args.apply)
