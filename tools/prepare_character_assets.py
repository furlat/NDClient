"""Copy original Smallscale A/B sheets; preserve existing authoring, never bind it.

This is offline intake, not a runtime catalog or a renderer. PNG bytes are copied
unchanged into the plan's ignored media store; the receipt preserves source names.
"""
import argparse
import json
from pathlib import Path
import struct
import zipfile
from asset_paths import named_path, write_asset


def combined_counterpart(member: str) -> str | None:
    """Vendor source pairing only; separate shadows/effects are not body copies."""
    if {'Shadows', 'Effects'} & set(Path(member).parts):
        return None
    for separate, combined in (
        ('/Shadowless/', '/With shadow/'),
        ('Zombies Shadowless/', 'Zombies with shadow/'),
        ('/Seperate shadows and effects/', '/Combined/'),
        ('Spritesheets with seperated shadows and effects/', 'Combined/'),
    ):
        if separate in member:
            return member.replace(separate, combined, 1).replace('_Shadowless.png', '.png')
    return None


def prepare(engine: Path, destination: Path, assets: Path) -> None:
    record_root = destination / '.runtime/character-assets'
    record_root.mkdir(parents=True, exist_ok=True)
    records = []
    summaries = []

    def retain(data: bytes, family: str, pack: str, origin: str, member: str) -> None:
        if data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
            raise ValueError(f'Not a PNG: {origin}: {member}')
        width, height = struct.unpack('>II', data[16:24])
        row = dict(family=family, pack=pack, source=origin, member=member,
                   bytes=len(data), width=width, height=height)
        path = destination / '.media' / named_path('character-assets', row)
        write_asset(path, data)
        row['payload'] = str(path.relative_to(destination))
        records.append(row)

    def archive(pack: str, family: str, path: Path, sheets_only: bool) -> None:
        start = len(records)
        with zipfile.ZipFile(path) as source:
            members = set(source.namelist())
            for entry in source.infolist():
                parts = Path(entry.filename).parts
                if entry.is_dir() or not entry.filename.lower().endswith('.png'):
                    continue
                if sheets_only and 'Spritesheets' not in parts:
                    continue
                if family == 'B' and combined_counterpart(entry.filename) in members:
                    continue
                retain(source.read(entry), family, pack, str(path), entry.filename)
        summaries.append(dict(pack=pack, family=family, sheets=len(records)-start,
                              source_bytes=sum(r['bytes'] for r in records[start:])))
        print(json.dumps(summaries[-1]), flush=True)

    preserved = Path('/home/tommaso/Dev/neurodragon_art/sources')
    archive('modular-creator-v1.3', 'A', preserved / 'item-equipment-20261002' /
            'Stand-alone Character creator - 2D Fantasy V1.3.zip', True)
    for pack, filename in (
        ('animals', '2D Animals mega Pack 1 V2.zip'),
        ('barbarian', '2D HD Barbarian pack 1.zip'),
        ('character', '2D HD Character pack 1 V1.2.zip'),
        ('enemy', '2D HD Enemy pack 1 (1).zip'),
        ('undead', '2D HD Undead pack 1.zip'),
        ('hdz', '2D HD Zombie pack 1 V1.1.zip'),
        ('top', '2D Zombie pack 2 - Top down v1.1.zip'),
    ):
        archive(pack, 'B', assets / filename, pack != 'top')
    archive('orcs_goblins', 'B', preserved / 'goblins-20261003' /
            '2D Orcs and Goblins - TopDown - V1.0.zip', False)
    archive('demons', 'B', preserved / 'summoning-creatures-20261003' /
            '2D Demons - TopDown assetpack v1.1.zip', False)

    # The selected dinosaur archive is already extracted in the engine workspace.
    rar = assets / '2D Dinosaurs Pack 1.rar'
    extracted = engine / '.runtime/pack-study-20260930/animal-dinosaur-completion/dinosaurs'
    start = len(records)
    for path in sorted(extracted.rglob('*.png')):
        member = str(path.relative_to(extracted))
        if '/Spritesheets/' not in member:
            continue
        counterpart = combined_counterpart(member)
        if counterpart and (extracted / counterpart).is_file():
            continue
        retain(path.read_bytes(), 'B', 'dinosaurs', str(rar), member)
    if len(records) == start:
        raise ValueError('Extracted dinosaur sheets are missing')
    summaries.append(dict(pack='dinosaurs', family='B', sheets=len(records)-start,
                          source_bytes=sum(r['bytes'] for r in records[start:])))
    print(json.dumps(summaries[-1]), flush=True)

    # Keep existing authored metadata. Original source members resolve directly
    # to the complete packs above; only genuinely derived shadows need extra files.
    source_members = {(Path(row['source']).name, row['member']): row for row in records
                      if row['family'] == 'B'}
    authored = sorted((engine / 'game/data/rigs').glob('*.json'))
    authored += [engine / 'game/data/neuroclient' / name for name in
                 ('bindings.json', 'rig-tables.json', 'pose-sockets.json')]
    authored += [engine / 'agent_docs/audits' / name for name in (
        'FIXED_CHARACTER_ANIMATION_MAPPINGS_2026-10-01.json',
        'FIXED_CHARACTER_ANIMATION_MAPPINGS_2026-10-01.md',
        'FIXED_CHARACTER_RENDERER_INTEGRATION_2026-10-01.md',
    )]
    snapshots = []
    start = len(records)
    for path in authored:
        data = path.read_bytes()
        target = record_root / 'authoring-reference' / path.relative_to(engine)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        snapshots.append(dict(source=str(path), snapshot=str(target.relative_to(destination)),
                              bytes=len(data)))
        if path.parent != engine / 'game/data/rigs':
            continue
        document = json.loads(data)
        provenance = document['provenance']
        archive_name = provenance['archive']['name']
        for address, local_path in document['resources'].items():
            if '/body/' in address:
                continue  # Combined vendor bodies are the selected B artwork.
            origin = provenance['files'][address]
            if 'archive_member' in origin:
                original = source_members[(archive_name, origin['archive_member'])]
                records.append(dict(family='B', pack='existing-authored-resources',
                    source=str(path), member=address, bytes=original['bytes'],
                    width=original['width'], height=original['height'],
                    payload=original['payload']))
            else:
                if origin['derivation'] != 'paired-visible-shadow-v1':
                    raise ValueError('Unknown authored image derivation: ' + address)
                original = source_members[(archive_name, origin['combined']['archive_member'])]
                target = Path(original['payload'].replace('/With shadow/', '/Derived shadows/'))
                payload = (engine / local_path).read_bytes()
                write_asset(destination / target, payload)
                width, height = struct.unpack('>II', payload[16:24])
                records.append(dict(family='B', pack='existing-authored-resources',
                    source=str(path), member=address, bytes=len(payload), width=width,
                    height=height, payload=str(target), derivation=origin['derivation']))
    summaries.append(dict(pack='existing-authored-resources', sheets=len(records)-start,
                          source_bytes=sum(r['bytes'] for r in records[start:])))
    result = dict(purpose='Original A/B sheet intake only; no new bindings or runtime release',
                  packs=summaries, source_records=len(records),
                  copied_bytes=sum(r['bytes'] for r in records), authoring_references=snapshots)
    (record_root / 'files.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in records))
    (record_root / 'summary.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'authoring_references'}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--destination', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--assets', type=Path,
                        default=Path('/mnt/c/Users/tommaso/Documents/assets/smallscale'))
    args = parser.parse_args()
    prepare(args.engine, args.destination, args.assets)
