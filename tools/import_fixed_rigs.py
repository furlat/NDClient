"""Adopt the existing fixed-character rig records against the installed library."""
import argparse
import json
from pathlib import Path

from game.animation_types import BodyRig
from build_authoring import check_resources, read_catalog
from prepare_character_assets import combined_counterpart


ROOT = Path(__file__).resolve().parents[1]


def adopt(engine, root):
    rows = [json.loads(line) for line in (root / '.runtime/character-assets/files.jsonl').read_text().splitlines()]
    sources = {(Path(row['source']).name, row['member']): row['payload'] for row in rows if row['family'] == 'B'}
    derived = {row['member']: row['payload'] for row in rows if row.get('derivation') == 'paired-visible-shadow-v1'}
    catalog = read_catalog(root / 'authoring')
    count = 0
    for path in sorted((engine / 'game/data/rigs').glob('*.json')):
        document = json.loads(path.read_text())
        identity = document['rig_id']
        if identity in catalog['rigs']:
            raise ValueError('Existing client rig will not be overwritten: ' + identity)
        BodyRig.model_validate_json(json.dumps(document['rig']))
        archive = document['provenance']['archive']['name']
        for address in document['resources']:
            origin = document['provenance']['files'][address]
            if 'archive_member' in origin:
                member = origin['archive_member']
                if '/body/' in address:
                    member = combined_counterpart(member) or member
                payload = sources[(archive, member)]
            else:
                payload = derived[address]
            url = '/media/' + payload.removeprefix('.media/')
            if address in catalog['resources'] and catalog['resources'][address] != url:
                raise ValueError('Existing resource points elsewhere: ' + address)
            catalog['resources'][address] = url
        catalog['rigs'][identity] = document['rig']
        for creature in document['creature_content_refs']:
            if creature in catalog['creature_rigs']:
                raise ValueError('Existing creature assignment will not be overwritten: ' + creature)
            catalog['creature_rigs'][creature] = identity
        count += 1
    check_resources({'resources': catalog['resources']}, root)
    index = json.loads((root / 'authoring/catalog-index.json').read_text())
    for field in ('rigs', 'resources', 'creature_rigs'):
        (root / 'authoring' / index[field]).write_text(json.dumps(catalog[field], indent=2) + '\n')
    print(f'Adopted {count} original fixed rigs and their existing creature/resource associations; artwork unchanged.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    adopt(args.engine, args.root)
