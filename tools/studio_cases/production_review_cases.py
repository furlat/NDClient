"""Legal successor production recordings; unchanged original scenarios stay evidence.

This module creates commands and requirements only. Every membership, chosen
facet, damage result, holder, source and lifetime comes from the real recorder.
"""
import json
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
PRESERVED_SCENARIOS = (
    'tests/fixtures/schema16/root-target-save/saved-head-programs/scenario.json',
    'tests/fixtures/schema16/weapon-enchantment-lifecycle/divine-favor/scenario.json',
    'tests/fixtures/schema16/weapon-enchantment-lifecycle/magic-weapon/scenario.json',
    'tests/fixtures/schema16/weapon-enchantment-lifecycle/shillelagh/scenario.json',
    'tests/fixtures/schema16/typed-variants-miss/scenario.json',
)
ITEM_OWNERS = {
    'spell.magic_weapon/wield_attack_remove': 'condition.spell.magic_weapon',
    'spell.magic_weapon/equipped_use_retire_replace': 'condition.spell.magic_weapon',
    'action.class.paladin.sacred_weapon/expiry': 'condition.class.paladin.sacred_weapon',
}


def repair_item_owner_requirements(case):
    """Correct the observer guard; never edit the preserved old scenario file."""
    owner = ITEM_OWNERS.get(case['id'])
    if owner is None:
        return case
    case = json.loads(json.dumps(case))
    case['required_conditions'] = [value for value in case.get('required_conditions', ()) if value != owner]
    case['required_condition_ends'] = [value for value in case.get('required_condition_ends', ()) if value != owner]
    case['required_item_effects'] = sorted(set(case.get('required_item_effects', ())) | {owner})
    case['required_item_effect_ends'] = sorted(set(case.get('required_item_effect_ends', ())) | {owner})
    for step in case['steps']:
        if step.get('track_condition') == owner:
            step.pop('track_condition')
            step['track_item_effect'] = owner
    return case


def production_review_studies(actors, subjects):
    result = [repair_item_owner_requirements(json.loads((PROJECT / path).read_text()))
              for path in PRESERVED_SCENARIOS]
    for option, form in ((2, 'attack'), (3, 'inaction'), (4, 'damage')):
        roster = actors(['spell.bestow_curse'])
        result.append({
            'id': 'spell.bestow_curse/option_' + str(option) + '_original',
            'title': 'Bestow Curse: actual offered ' + form + ' form',
            'kind': 'spell', 'subjects': subjects(['spell.bestow_curse']),
            'actors': roster, 'seed': 2,
            'steps': [{'do': 'spell.bestow_curse', 'by': 'caster', 'target': 'target',
                       'variant': {'form': form}, 'capture_choices': True}],
            'required_behaviors': ['spell.bestow_curse'],
            'purpose': 'Select the actually offered exact facet; retain native save and condition outcomes without forcing a failed save.'})
    roster = actors(['spell.blindness_deafness'])
    roster[2]['level'] = 1
    result.append({
        'id': 'spell.blindness_deafness/deafened_original',
        'title': 'Deafness: genuine offered form and actual recipient head owner',
        'kind': 'spell', 'subjects': subjects(['spell.blindness_deafness'], conditions=['condition.deafened']),
        'actors': roster, 'seed': 2,
        'steps': [{'do': 'spell.blindness_deafness', 'by': 'caster', 'target': 'target',
                   'variant': {'form': 'deafened'}, 'capture_choices': True},
                  {'do': 'action.move', 'by': 'caster', 'target': [2, 7]}],
        'required_behaviors': ['spell.blindness_deafness', 'action.move'],
        'required_conditions': ['condition.deafened'],
        'purpose': 'Require an actual disclosed Deafened owner for finite optical qualification. A real successful save remains a failed prerequisite, never a relabeled outcome.'})
    for energy in ('acid', 'cold', 'lightning', 'thunder'):
        result.append({
            'id': 'spell.protection_from_energy/' + energy + '_original',
            'title': 'Protection from Energy: actual offered ' + energy + ' form',
            'kind': 'spell', 'subjects': subjects(['spell.protection_from_energy'], conditions=['condition.spell.protection_from_energy']),
            'actors': actors(['spell.protection_from_energy']), 'seed': 2,
            'steps': [{'do': 'spell.protection_from_energy', 'by': 'caster', 'target': 'self',
                       'variant': {'damage_type': energy}, 'capture_choices': True},
                      {'do': 'action.drop_concentration', 'by': 'caster', 'target': 'self'}],
            'required_behaviors': ['spell.protection_from_energy', 'action.drop_concentration'],
            'required_conditions': ['condition.spell.protection_from_energy'],
            'required_condition_ends': ['condition.spell.protection_from_energy'],
            'purpose': 'Preserve exact actual option, native selected condition state and independent concentration removal.'})
    result.append({
        'id': 'spell.continual_flame/held_club_move_unequip_reequip',
        'title': 'Continual Flame: exact held Club, movement and same-item unequip/re-equip',
        'kind': 'spell', 'subjects': subjects(['spell.continual_flame'], ['action.move']),
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster', 'level': 20,
             'caster_level': 20, 'spells': ['spell.continual_flame'], 'at': [3, 7],
             'items': [{'id': 'weapon.club', 'slot': 'MELEE_MAIN'}]},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.generic_caster', 'level': 20, 'at': [10, 7]}],
        'seed': 2,
        'steps': [{'do': 'spell.continual_flame', 'by': 'caster', 'target': {'object': 'Club'},
                   'track': True, 'track_item_effect': 'condition.spell.continual_flame', 'capture_choices': True},
                  {'do': 'hold_walk', 'offset': [1, 0]},
                  {'do': 'unequip', 'by': 'caster', 'slot': 'MELEE_MAIN'},
                  {'do': 'end_turn', 'by': 'caster'},
                  {'do': 'equip', 'by': 'caster', 'slot': 'MELEE_MAIN', 'item': 'weapon.club'},
                  {'do': 'end_turn', 'by': 'caster'},
                  {'do': 'hold_walk', 'offset': [0, 1]}],
        'required_behaviors': ['spell.continual_flame', 'action.move'],
        'required_item_effects': ['condition.spell.continual_flame'],
        'required_facts': ['movement'],
        'purpose': 'Actual held source packet, immutable item/effect owner and native same-item equipment transitions. Unequip hides the decoration without inventing condition removal or restarting owner age; no transfer/proxy claim.'})
    for seed in (2, 3, 5):
        result.append({
            'id': 'spell.blur/history_damage_material_overlap_seed_' + str(seed),
            'title': 'History overlap: independent Blur, Barkskin, Fly and actual Fire Bolt, seed ' + str(seed),
            'kind': 'spell', 'seed': seed,
            'subjects': subjects(['spell.blur', 'spell.barkskin', 'spell.fly', 'spell.fire_bolt'],
                                 ['action.move', 'action.drop_concentration'],
                                 ['condition.spell.blur', 'condition.spell.barkskin', 'condition.spell.fly']),
            'actors': [
                {'role': 'victim', 'side': 'amber', 'creature': 'creature.generic_caster', 'level': 20, 'caster_level': 20,
                 'spells': ['spell.blur'], 'at': [5, 7]},
                {'role': 'bark_caster', 'side': 'amber', 'creature': 'creature.generic_caster', 'level': 20, 'caster_level': 20,
                 'spells': ['spell.barkskin'], 'at': [4, 7]},
                {'role': 'fly_caster', 'side': 'amber', 'creature': 'creature.generic_caster', 'level': 20, 'caster_level': 20,
                 'spells': ['spell.fly'], 'at': [5, 6]},
                {'role': 'attacker', 'side': 'blue', 'creature': 'creature.generic_caster', 'level': 20, 'caster_level': 20,
                 'spells': ['spell.fire_bolt'], 'at': [10, 7]}],
            'steps': [{'do': 'spell.blur', 'by': 'victim', 'target': 'self', 'track': True,
                       'track_condition': 'condition.spell.blur'},
                      {'do': 'spell.barkskin', 'by': 'bark_caster', 'target': 'victim'},
                      {'do': 'spell.fly', 'by': 'fly_caster', 'target': 'victim'},
                      {'do': 'action.move', 'by': 'victim', 'target': [6, 7]},
                      {'do': 'spell.fire_bolt', 'by': 'attacker', 'target': 'victim'},
                      {'do': 'action.move', 'by': 'victim', 'target': [6, 8]},
                      {'do': 'spell.fire_bolt', 'by': 'attacker', 'target': 'victim'},
                      {'do': 'end_turn', 'by': 'attacker'},
                      {'do': 'spell.fire_bolt', 'by': 'attacker', 'target': 'victim'},
                      {'do': 'end_turn', 'by': 'attacker'},
                      {'do': 'spell.fire_bolt', 'by': 'attacker', 'target': 'victim'},
                      {'do': 'end_tracked', 'strategy': 'concentration'},
                      {'do': 'action.drop_concentration', 'by': 'bark_caster', 'target': 'self'},
                      {'do': 'action.drop_concentration', 'by': 'fly_caster', 'target': 'self'},
                      {'do': 'action.move', 'by': 'victim', 'target': [7, 8]}],
            'required_behaviors': ['spell.blur', 'spell.barkskin', 'spell.fly', 'spell.fire_bolt', 'action.move', 'action.drop_concentration'],
            'required_conditions': ['condition.spell.blur', 'condition.spell.barkskin', 'condition.spell.fly'],
            'required_condition_ends': ['condition.spell.blur', 'condition.spell.barkskin', 'condition.spell.fly'],
            'required_applied_damage_types': ['Fire'],
            'purpose': 'Distinct actual concentration casters preserve body treatment/history ownership during native enemy attack/damage and movement. Bounded independent seeds retain all real misses or concentration loss; positive applied Fire is a required witness, not manufactured damage.'})
    return result
