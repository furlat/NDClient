"""Copy original Smallscale A/B sheets; preserve existing authoring, never bind it.

This is offline intake, not a runtime catalog or a renderer. PNG bytes are copied
unchanged into the plan's ignored media store; the receipt preserves source names.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import zipfile
import zlib


def prepare(engine: Path, destination: Path, assets: Path, downloads: Path) -> None:
    objects = destination / '.media/objects'
    record_root = destination / '.runtime/character-assets'
    objects.mkdir(parents=True, exist_ok=True)
    record_root.mkdir(parents=True, exist_ok=True)
    records = []
    summaries = []
    unique = {}

    def retain(data: bytes, family: str, pack: str, origin: str, member: str) -> None:
        if data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
            raise ValueError(f'Not a PNG: {origin}: {member}')
        digest = hashlib.sha256(data).hexdigest()
        path = objects / f'{digest}.png'
        if digest not in unique:
            if path.exists():
                if path.read_bytes() != data:
                    raise ValueError(f'Conflicting existing payload: {path}')
            else:
                path.write_bytes(data)
                if path.read_bytes() != data:
                    raise ValueError(f'Copy differs: {path}')
            unique[digest] = len(data)
        width, height = struct.unpack('>II', data[16:24])
        records.append(dict(family=family, pack=pack, source=origin, member=member,
                            sha256=digest, bytes=len(data), width=width, height=height,
                            payload=str(path.relative_to(destination))))

    def archive(pack: str, family: str, path: Path, sheets_only: bool) -> None:
        start = len(records)
        with zipfile.ZipFile(path) as source:
            for entry in source.infolist():
                parts = Path(entry.filename).parts
                if entry.is_dir() or not entry.filename.lower().endswith('.png'):
                    continue
                if sheets_only and 'Spritesheets' not in parts:
                    continue
                retain(source.read(entry), family, pack, str(path), entry.filename)
        summaries.append(dict(pack=pack, family=family, sheets=len(records)-start,
                              source_bytes=sum(r['bytes'] for r in records[start:])))
        print(json.dumps(summaries[-1]), flush=True)

    preserved = Path('/home/tommaso/Dev/neurodragon_art/sources')
    archive('modular-creator-v1.3', 'A', preserved / 'item-equipment-20261002' /
            'Stand-alone Character creator - 2D Fantasy V1.3.zip', True)
    archive('modular-x256', 'A', downloads / 'x256 Spritesheets.zip', False)
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

    # Read the already extracted RAR sheets; verify them against its actual table.
    seven_zip = '/mnt/c/Program Files/NVIDIA Corporation/NVIDIA App/7z.exe'
    rar = assets / '2D Dinosaurs Pack 1.rar'
    win_rar = subprocess.check_output(['wslpath', '-w', str(rar)], text=True).strip()
    listing = subprocess.check_output([seven_zip, 'l', '-slt', win_rar], text=True)
    extracted = engine / '.runtime/pack-study-20260930/animal-dinosaur-completion/dinosaurs'
    start = len(records)
    for block in listing.split('\n\n'):
        fields = dict(line.split(' = ', 1) for line in block.splitlines() if ' = ' in line)
        member = fields.get('Path', '').replace('\\', '/')
        if '/Spritesheets/' not in member or not member.lower().endswith('.png'):
            continue
        data = (extracted / member).read_bytes()
        if len(data) != int(fields['Size']) or f'{zlib.crc32(data):08X}' != fields['CRC']:
            raise ValueError(f'Extracted dinosaur sheet differs from source archive: {member}')
        retain(data, 'B', 'dinosaurs', str(rar), member)
    if len(records) == start:
        raise ValueError('RAR listing did not contain dinosaur sheets')
    summaries.append(dict(pack='dinosaurs', family='B', sheets=len(records)-start,
                          source_bytes=sum(r['bytes'] for r in records[start:])))
    print(json.dumps(summaries[-1]), flush=True)

    # Existing installed adaptations (e.g. recovered animal shadows) remain exact.
    # These resource addresses already exist; no new rig/action mapping is created.
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
                              sha256=hashlib.sha256(data).hexdigest(), bytes=len(data)))
        if path.parent == engine / 'game/data/rigs':
            document = json.loads(data)
            resources, family = document['resources'], 'B'
        elif path.name == 'bindings.json':
            document = json.loads(data)
            resources = {k: v for k, v in document['resources'].items()
                         if v.startswith('game/assets/neuroclient/spritesheets/')}
            family = 'A'
        else:
            continue
        for address, local_path in resources.items():
            resource = engine / local_path
            retain(resource.read_bytes(), family, 'existing-authored-resources',
                   str(path), address)
    summaries.append(dict(pack='existing-authored-resources', sheets=len(records)-start,
                          source_bytes=sum(r['bytes'] for r in records[start:])))
    result = dict(purpose='Original A/B sheet intake only; no new bindings or runtime release',
                  packs=summaries, source_records=len(records), unique_payloads=len(unique),
                  unique_bytes=sum(unique.values()), authoring_references=snapshots)
    (record_root / 'files.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in records))
    (record_root / 'summary.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'authoring_references'}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--destination', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--assets', type=Path,
                        default=Path('/mnt/c/Users/tommaso/Documents/assets/smallscale'))
    parser.add_argument('--downloads', type=Path,
                        default=Path('/mnt/c/Users/tommaso/Downloads'))
    args = parser.parse_args()
    prepare(args.engine, args.destination, args.assets, args.downloads)
