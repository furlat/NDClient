"""Adopt the selected UI assignments once, without copying artwork or rules.

Uses the engine's existing passive owners. Subsequent client builds use only
tracked authoring, with no source handoffs, receipts or engine imports.
"""
import argparse
import json
from pathlib import Path

from pydantic import TypeAdapter

from dnd.core.content.identities import ContentRef
from game.asset_types import ImageResourceSource
from game.ui.media_types import ChoiceRecord, SkinSource, UI_FONT_FAMILIES, UIPresentationDocument
from build_authoring import check_resources


ROOT = Path(__file__).resolve().parents[1]
ICON_BANK = 'ui-icons-bg3-glyphs-2026-10-07'
PORTRAIT_BANKS = (
    'portraits-bg-study-2026-10-08/full-matrix-v2',
    'portraits-bg-study-2026-10-08/white-expansion',
    'creature-portraits-bg1-2026-10-08',
)
# New, reversible defaults for existing premade aliases, not delivered native
# assignments. All selected images also remain available as free portraits.
HERO_DEFAULTS = {
    'hero.barbarian_l5_berserker_torch.hero': ('barbarian--human-white--male', 'Berserker'),
    'hero.fighter_l5_archer_torch.hero': ('fighter--human-white--male--extra-01', 'Archer'),
    'hero.fighter_l5_shield_torch.hero': ('fighter--human-white--male', 'Fighter'),
    'hero.sorcerer_l5_standard_torch.hero': ('sorcerer--human-white--male', 'Sorcerer'),
    'hero.fighter_2_sorcerer_3_spellblade.hero': ('sorcerer--human-white--male--extra-01', 'Spellblade'),
}
SECTIONS = {
    'ui_resources': ('resources.json', TypeAdapter(dict[str, ImageResourceSource])),
    'ui_presentation': ('presentation.json', TypeAdapter(UIPresentationDocument)),
    'ui_choices': ('choices.json', TypeAdapter(tuple[ChoiceRecord, ...])),
    'ui_skin': ('skin.json', TypeAdapter(dict[str, dict[str, SkinSource]])),
    'ui_fonts': ('fonts.json', TypeAdapter(dict[str, tuple[str, ...]])),
}


def read_json(path):
    return json.loads(path.read_text())


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + '\n')


def image_resource(receipt):
    return {'path': '/media/' + receipt['payload'].removeprefix('.media/'),
            'native_size': [receipt['width'], receipt['height']], 'pivot': [0, 0], 'scale': 1}


def prepare(engine, root, apply=False):
    authoring = root / 'authoring'
    destinations = [authoring / 'ui/index.json']
    destinations.extend(authoring / 'ui' / filename for filename, _ in SECTIONS.values())
    destinations.extend(authoring / 'schemas' / (key.replace('_', '-') + '.schema.json')
                        for key in SECTIONS)
    for path in destinations:
        if path.exists():
            raise ValueError(f'Existing client UI authoring will not be overwritten: {path}')

    intake = root / '.runtime/ui-assets'
    sources = intake / 'authoring-reference'
    receipts = {(row['bank'], row['key']): row
                for row in map(json.loads, (intake / 'files.jsonl').read_text().splitlines())}
    replacements = read_json(sources / ICON_BANK / 'replacement-bindings.json')
    resources = {'icon:' + key: image_resource(receipts[ICON_BANK, row['assetKey']])
                 for key, row in replacements.items()}
    presentation = read_json(engine / 'game/data/ui_presentation.json')
    # These selections are now exact new-bank icons. Keep item-specific reuse
    # notes, but retire the blanket provenance note about the recovered bank.
    for row in presentation['direct_features'].values():
        if (row.get('approximation') or '').startswith('Recovered icon;'):
            row['approximation'] = None
    presentation['portrait_choices'] = {}
    creature_rigs = read_json(authoring / 'catalog/creature_rigs.json')
    assigned = set()
    free_keys = set()
    for bank in PORTRAIT_BANKS:
        for row in read_json(sources / bank / 'production-lookup.json')['entries']:
            ref = row.get('contentRef')
            if ref is not None:
                # The supplied roster uses full refs for summons and identity
                # strings for Goblins/Orcs; both refer to existing rig entries.
                identity = ref if isinstance(ref, str) else ContentRef.model_validate(ref).identity_key
                if identity.split(':')[2].split('@')[0] != row['contentId'] or creature_rigs.get(identity) != row['rigId']:
                    raise ValueError('Portrait assignment differs from existing creature rig: ' + row['key'])
                key = row['contentId']
                assigned.add(key)
            else:
                key = row['key']
                free_keys.add(key)
                # A selectable art label does not create a native character.
                label = row.get('label') or row['characterName']
                presentation['portrait_choices'][key] = {
                    'label': label, 'presentation': {'portrait_key': key}}
            resource_id = 'portrait:' + key
            if resource_id in resources:
                raise ValueError('Duplicate selected portrait key: ' + key)
            resources[resource_id] = image_resource(receipts[bank, row['key']])
    for alias, (selected, label) in HERO_DEFAULTS.items():
        resources['portrait:' + alias] = resources['portrait:' + selected]
        presentation['portrait_choices'][alias] = {
            'label': label, 'presentation': {'portrait_key': alias},
            'approximation': 'New premade default from the selected portrait bank; editable selection.'}

    delivered_choices = read_json(sources / ICON_BANK / 'choice-bindings.json')
    choices = []
    for row in delivered_choices:
        facet = row['facetKey']
        requirements = dict(row.get('requires', {}))
        if facet is not None:
            # Requirements on discovery choices use the existing facet names.
            # The same owner's field/facet records retain their native mapping.
            field_facets = {other['field']: other['facetKey'] for other in delivered_choices
                            if other['owner'] == row['owner'] and other['facetKey'] is not None}
            requirements = {field_facets[key]: value for key, value in requirements.items()}
        value = row.get('facetValue', row['value'])
        choice = {'owner': row['owner'], 'facet': facet, 'value': value,
                  'field': row['field'], 'icon_key': row['iconKey'],
                  'label': row['label'], 'requirements': requirements}
        if value != row['value']:
            choice['field_value'] = row['value']
        choices.append(choice)

    for collection in presentation.values():
        for row in collection.values():
            for kind in ('icon', 'portrait'):
                key = row['presentation'].get(kind + '_key')
                if key is not None and kind + ':' + key not in resources:
                    raise ValueError(f'Unresolved UI {kind}: {key}')
    for choice in choices:
        if 'icon:' + choice['icon_key'] not in resources:
            raise ValueError('Unresolved choice icon: ' + choice['icon_key'])
    # Rejected legacy panel/slot chrome is not part of the selected bank.
    documents = {'ui_resources': resources, 'ui_presentation': presentation,
                 'ui_choices': choices, 'ui_skin': {}, 'ui_fonts': UI_FONT_FAMILIES}
    for key, (_, adapter) in SECTIONS.items():
        adapter.validate_json(json.dumps(documents[key]))
    count = check_resources(documents, root)
    report = {'icon_keys': len(replacements), 'assigned_creature_portraits': len(assigned),
              'free_portraits': len(free_keys), 'premade_defaults': len(HERO_DEFAULTS),
              'choices': len(choices), 'distinct_images': count,
              'rigs_without_delivered_portrait': [key for key in creature_rigs
                                                if key.split(':')[2].split('@')[0] not in assigned],
              'written': apply}
    if apply:
        for key, (filename, adapter) in SECTIONS.items():
            write_json(authoring / 'ui' / filename, documents[key])
            schema = adapter.json_schema(mode='serialization')
            schema['$schema'] = 'https://json-schema.org/draft/2020-12/schema'
            write_json(authoring / 'schemas' / (key.replace('_', '-') + '.schema.json'), schema)
        write_json(authoring / 'ui/index.json',
                   {key: 'ui/' + filename for key, (filename, _) in SECTIONS.items()})
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    print(json.dumps(prepare(args.engine.resolve(), args.root.resolve(), args.apply), indent=2))
