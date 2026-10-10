"""Prepare smooth48 icons and the selected 192x256 portrait exports.

Offline preparation only. Exact supplied assignments and portrait crops remain
unchanged; receipts locate payloads without introducing another binding catalog.
Run with the engine's existing Python/Pillow environment.
"""
import argparse
from collections import Counter
from io import BytesIO
import json
from pathlib import Path

from PIL import Image

from asset_paths import named_path, write_asset


ICON_BANK = 'ui-icons-bg3-glyphs-2026-10-07'
PORTRAIT_BANKS = (
    'portraits-bg-study-2026-10-08/full-matrix-v2',
    'portraits-bg-study-2026-10-08/white-expansion',
    'creature-portraits-bg1-2026-10-08',
)


def prepare(source: Path, destination: Path, engine: Path, portrait_role: str) -> None:
    receipt = destination / '.runtime/ui-assets'
    receipt.mkdir(parents=True, exist_ok=True)
    records, references = [], []
    banks = source / 'banks'

    def snapshot(path: Path, relative: Path) -> None:
        data = path.read_bytes()
        target = receipt / 'authoring-reference' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        references.append(dict(source=str(path), snapshot=str(target.relative_to(destination)),
                               bytes=len(data)))

    def retain(data: bytes, path: Path, bank: str, key: str, role: str,
               size: tuple[int, int], operation: str) -> None:
        row = dict(bank=bank, key=key, role=role, source=str(path), operation=operation,
                   bytes=len(data), width=size[0], height=size[1])
        target = destination / '.media' / named_path('ui-assets', row)
        write_asset(target, data)
        row['payload'] = str(target.relative_to(destination))
        records.append(row)

    def image_copy(bank: str, key: str, role: str, item: dict) -> None:
        path = banks / bank / item['file']
        data = path.read_bytes()
        with Image.open(BytesIO(data)) as image:
            image.load()
            if image.size != tuple(item['size']):
                raise ValueError(f'Unexpected source size: {path}: {image.size}')
            if 'mode' in item and image.mode != item['mode']:
                raise ValueError(f'Unexpected source mode: {path}: {image.mode}')
            if role == 'smooth144':
                # Premultiplied alpha prevents dark/coloured transparent-edge halos.
                resized = image.convert('RGBA').convert('RGBa').resize(
                    (48, 48), Image.Resampling.LANCZOS).convert('RGBA')
                output = BytesIO()
                resized.save(output, format='PNG')
                retain(output.getvalue(), path, bank, key, 'smooth48',
                       resized.size, 'premultiplied-alpha Lanczos downsample')
            else:
                retain(data, path, bank, key, role, image.size, 'exact copy')

    icon_root = banks / ICON_BANK
    icons = json.loads((icon_root / 'manifest.json').read_text())
    bindings = json.loads((icon_root / 'replacement-bindings.json').read_text())
    choices = json.loads((icon_root / 'choice-bindings.json').read_text())
    icon_keys = {r['key'] for r in icons['rows']}
    if len(icon_keys) != len(icons['rows']):
        raise ValueError('Repeated icon image keys in the source manifest')
    for key, binding in bindings.items():
        if binding['assetKey'] not in icon_keys:
            raise ValueError(f'Icon assignment has no image: {key}')
    for choice in choices:
        if choice['iconKey'] not in bindings:
            raise ValueError(f'Choice has no exact icon assignment: {choice["iconKey"]}')
    for row in icons['rows']:
        image_copy(ICON_BANK, row['key'], 'smooth144', row['unpixelated'])
    print(f'Prepared {len(icon_keys)} smooth48 icons', flush=True)

    portrait_counts, bound = {}, []
    for bank in PORTRAIT_BANKS:
        lookup = json.loads((banks / bank / 'production-lookup.json').read_text())
        portrait_counts[bank] = len(lookup['entries'])
        keys = [row['key'] for row in lookup['entries']]
        if len(set(keys)) != len(keys):
            raise ValueError(f'Repeated portrait keys: {bank}')
        for row in lookup['entries']:
            if row.get('contentRef') is not None:
                if not row.get('rigId'):
                    raise ValueError(f'Assigned portrait lacks its supplied rig: {row["key"]}')
                bound.append((bank, row['key']))
            image_copy(bank, row['key'], portrait_role, row['files'][portrait_role])
        print(f'Copied {len(keys)} portraits at {portrait_role}: {bank}', flush=True)

    snapshot(source / 'README.md', Path('archive/README.md'))
    for name in ('HANDOFF.md', 'manifest.json', 'replacement-bindings.json',
                 'choice-bindings.json', 'colour-bindings.json'):
        snapshot(icon_root / name, Path(ICON_BANK) / name)
    for bank in PORTRAIT_BANKS:
        for name in ('manifest.json', 'production-lookup.json'):
            snapshot(banks / bank / name, Path(bank) / name)
        handoff = 'DELIVERY.md' if bank.endswith('full-matrix-v2') else 'HANDOFF.md'
        snapshot(banks / bank / handoff, Path(bank) / handoff)
    snapshot(banks / PORTRAIT_BANKS[-1] / 'ROSTER.md', Path(PORTRAIT_BANKS[-1]) / 'ROSTER.md')
    for name in ('ui_media.json', 'ui_presentation.json'):
        snapshot(engine / 'game/data' / name, Path('engine/game/data') / name)

    groups = {}
    for bank in (ICON_BANK, *PORTRAIT_BANKS):
        grouped = [r for r in records if r['bank'] == bank]
        payloads = {r['payload']: r['bytes'] for r in grouped}
        groups[bank] = dict(image_records=len(grouped), files=len(payloads),
                           copied_bytes=sum(payloads.values()))
    result = dict(purpose='New icons/portraits preparation; source assignments preserved',
                  smooth_icon_baseline=48, portrait_role=portrait_role,
                  icon_images=len(icon_keys), icon_keys=len(bindings), choice_bindings=len(choices),
                  portraits=sum(portrait_counts.values()), portrait_banks=portrait_counts,
                  assigned_creature_portraits=len(bound),
                  unassigned_creature_portraits=portrait_counts[PORTRAIT_BANKS[-1]]-len(bound),
                  selectable_character_portraits=sum(portrait_counts[b] for b in PORTRAIT_BANKS[:2]),
                  image_records=len(records), copied_bytes=sum(r['bytes'] for r in records),
                  reference_files=len(references), reference_bytes=sum(r['bytes'] for r in references),
                  roles=dict(Counter(r['role'] for r in records)), banks=groups,
                  excluded=['high-resolution masters', 'rejected/review/reference pictures',
                            'archives and duplicate clothing-v1 portraits', 'older icon/portrait banks',
                            'smooth144 and CIE28 icon copies', 'unselected portrait size roles'])
    (receipt / 'files.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in records))
    (receipt / 'references.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in references))
    (receipt / 'summary.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path,
                        default=Path('/mnt/c/Users/tommaso/Documents/assets/dnd-engine-icons-and-portraits'))
    parser.add_argument('--destination', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--portrait-role', default='preview',
                        choices=('preview',),
                        help='Single portrait export; user-selected default is preview (192x256)')
    args = parser.parse_args()
    prepare(args.source, args.destination, args.engine, args.portrait_role)
