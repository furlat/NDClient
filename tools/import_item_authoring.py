"""Adopt existing item presentation documents once; reuse the installed artwork.

Run with the engine's Python and PYTHONPATH. The regular client build reads the
tracked result without the engine, source ledger, receipts or raster loading.
"""
import argparse
import json
from pathlib import Path
import struct

from dnd.items.authored_variant_inventory import AuthoredItemVariantInventory
from game.animation_types import BodyRig
from game.item_appearance import ItemAppearanceDocument, ItemMaterialDocument, SourcePaletteDocument
from build_authoring import check_resources, read_catalog


ROOT = Path(__file__).resolve().parents[1]
SECTIONS = {
    'item_appearances': ('items/appearances.json', 'game/data/item_appearances.json', ItemAppearanceDocument),
    'item_materials': ('items/materials.json', 'game/data/item-materials.json', ItemMaterialDocument),
    'item_visuals': ('items/visuals.json', 'content_data/ledgers/neuroclient_authored_item_visuals.json', AuthoredItemVariantInventory),
    'source_palettes': ('materials/source-palettes.json', 'game/data/neuroclient/source/src/render/data/animation/paletteMap.json', SourcePaletteDocument),
}


def item_sprites(appearances, inventory):
    sprites = set()
    for row in appearances['hands']:
        sprites.update(layer['sprite_key'] for layer in row['layers'])
    for row in appearances['ground']:
        sprites.add(row['sprite_key'])
        sprites.update(layer['sprite_key'] for layer in row.get('layers', []))
        if row.get('shadow_sprite_key'):
            sprites.add(row['shadow_sprite_key'])
    for category in inventory['categories']:
        for row in (category['base_presentation'], *category['variants']):
            sprites.update(layer['sprite_key'] for layer in row['equipment_layers'])
    return sprites


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + '\n')


def prepare(engine, root, apply=False):
    authoring = root / 'authoring'
    schemas = authoring / 'schemas'
    destinations = [authoring / 'items/index.json']
    destinations.extend(authoring / entry[0] for entry in SECTIONS.values())
    destinations.extend(schemas / (section.replace('_', '-') + '.schema.json') for section in SECTIONS)
    for path in destinations:
        if path.exists():
            raise ValueError(f'Existing client item authoring will not be overwritten: {path}')
    documents = {}
    for section, (_, source, model) in SECTIONS.items():
        value = json.loads((engine / source).read_text())
        if section == 'item_visuals':
            value = value['inventory']
        # Preserve source values, including ground contacts and unsupported rows;
        # the existing passive owner validates them without native registration.
        model.model_validate_json(json.dumps(value))
        documents[section] = value

    catalog = read_catalog(authoring)
    rig = catalog['rigs'][catalog['root_rig']]
    resources = catalog['resources']
    sprites = item_sprites(documents['item_appearances'], documents['item_visuals'])
    categories = {key for values in rig['slot_categories'].values() for key in values}
    if sprites - categories:
        raise ValueError('Item layers outside existing root-rig categories: ' + str(sorted(sprites - categories)))
    additions = []
    for name, clip in rig['clips'].items():
        for sprite in sorted(sprites):
            identity = clip['sheets'].get(sprite, f"/spritesheets/{sprite}/{clip['source_clip']}.png")
            url = '/media/smallscale/modular/' + identity.removeprefix('/spritesheets/')
            if identity in resources and resources[identity] != url:
                raise ValueError('Existing item sheet uses another registration: ' + identity)
            if sprite not in clip['sheets'] or identity not in resources:
                path = root / '.media' / url.removeprefix('/media/')
                # The current BodyClip's canvas/clock remains authoritative.
                # Read the PNG header once during intake, never during play.
                with path.open('rb') as file:
                    header = file.read(24)
                expected = (rig['cell_width'] * clip['frames'],
                            rig['cell_height'] * (max(rig['facing_rows'].values()) + 1))
                if header[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', header[16:24]) != expected:
                    raise ValueError(f'{path}: source canvas does not match existing clip {name}')
                clip['sheets'][sprite] = identity
                resources[identity] = url
                additions.append(identity)
    BodyRig.model_validate_json(json.dumps(rig))
    check_resources({'resources': resources}, root)
    report = {'hands': len(documents['item_appearances']['hands']),
              'ground': len(documents['item_appearances']['ground']),
              'categories': len(documents['item_visuals']['categories']),
              'variants': sum(len(c['variants']) for c in documents['item_visuals']['categories']),
              'material_recipes': len(documents['item_materials']['recipes']),
              'source_palettes': len(documents['source_palettes']['entries']),
              'connected_existing_sheets': len(additions), 'written': apply}
    if not apply:
        return report
    for section, (relative, _, model) in SECTIONS.items():
        write_json(authoring / relative, documents[section])
        schema = model.model_json_schema(mode='serialization')
        schema['$schema'] = 'https://json-schema.org/draft/2020-12/schema'
        write_json(schemas / (section.replace('_', '-') + '.schema.json'), schema)
    write_json(authoring / 'items/index.json', {section: entry[0] for section, entry in SECTIONS.items()})
    index = json.loads((authoring / 'catalog-index.json').read_text())
    write_json(authoring / index['rigs'], catalog['rigs'])
    write_json(authoring / index['resources'], resources)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    print(json.dumps(prepare(args.engine.resolve(), args.root.resolve(), args.apply), indent=2))
