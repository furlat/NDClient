"""Verify the saved passive inventory against actual authored source assignments.

Run tools/audit_native_migration.py first, then this script. No Godot, media
imports, native rendering, or claims about unassigned effects are involved.
"""
from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
authoring = root / 'authoring'
report = json.loads((root / 'generated/native_migration_inventory.json').read_text())
assets = {row['asset_id']: row for row in report['assets']}
checks = 0


def check(value, label):
    global checks
    checks += 1
    assert value, label


def selected(asset, source):
    check(asset in assets, 'Selected authored source is retained: ' + asset)
    check(any(row['source'] == source and row['kind'] == 'authored_consumer'
              for row in assets[asset]['references']), 'Exact assignment pointer: ' + source)


conditions = json.loads((authoring / 'catalog/condition_recipes.json').read_text())
for side in ('back', 'front'):
    selected(conditions['condition.spell.banishment']['persistent']['absenceEcho'][side],
             'catalog/condition_recipes.json#/condition.spell.banishment/persistent/absenceEcho/' + side)
portals = json.loads((authoring / 'catalog/portals.json').read_text())
for side in ('back', 'front'):
    selected(portals['spell.dimension_door'][side], 'catalog/portals.json#/spell.dimension_door/' + side)
interruptions = json.loads((authoring / 'catalog/interruptions.json').read_text())
for owner, reaction in interruptions['reactions'].items():
    prefix = 'catalog/interruptions.json#/reactions/' + owner + '/'
    selected(reaction['dissipationMask'], prefix + 'dissipationMask')
    for outcome in ('successByCamera', 'failureByCamera'):
        for i, asset in enumerate(reaction[outcome]):selected(asset, prefix + outcome + '/' + str(i))
spell = json.loads((authoring / 'spells/spell.finger_of_death.json').read_text())
for n, track in enumerate(spell['media']):
    for q, asset in enumerate(track['assetIdsByCamera']):
        selected(asset, f'spells/spell.finger_of_death.json#/media/{n}/assetIdsByCamera/{q}')
world = json.loads((authoring / 'world.json').read_text())
for owner, asset in world['residue_particles'].items():selected(asset, 'world.json#/residue_particles/' + owner)
construction_assignments = 0
for owner, family in world['construction_media'].items():
    for direction, view in enumerate(family.get('directions', [])):
        for variant, phases in enumerate(view['variants']):
            for phase in ('application', 'intact', 'destruction', 'removal'):
                for side, asset in enumerate(phases.get(phase) or []):
                    selected(asset, f'world.json#/construction_media/{owner}/directions/{direction}/variants/{variant}/{phase}/{side}')
                    construction_assignments += 1
check(construction_assignments > 0, 'Actual construction source pairs exercise the phase-reference boundary')
references = [reference for row in assets.values() for reference in row['references']]
check(not any('/visualFamily' in row['source'] or '/markerGroup' in row['source'] or '/replaceLayerIds/' in row['source']
              for row in references), 'Label/group/replacement selectors are not invented source assignments')
check(report['totals']['assets'] == len(assets), 'Asset count is distinct media identities')
check(report['totals']['authored_references'] == sum(row['kind'] == 'authored_consumer' for row in references),
      'Authored assignment count excludes registration-only metadata')
check(report['totals']['references'] == report['totals']['authored_references'] + report['totals']['registration_references'],
      'Reference categories partition the reported total')
sources = json.loads((authoring / 'native_effects/index.json').read_text())['sources']
check({row['id'] for row in report['native_sources']} == set(sources), 'Audit preserves selected native source identities')
for row in report['native_sources']:
    check(row['media_ids'] == sources[row['id']].get('media_ids', []), 'Audit preserves exact imported source assignments')
print(f'NATIVE_MIGRATION_INVENTORY {checks} checks; 0 failures')
