"""Ordinary equipped-weapon casts, real use and authoritative retirement.

Run these dictionaries through the existing worker.py/adapter, never by editing
conditions or saved packets. Magic Weapon's item-owned public disclosure is a
required observation, not an assumed actor condition.
"""
from cases import subjects


def studies():
    result = []
    for name in ('magic_weapon', 'shillelagh', 'divine_favor'):
        spell = 'spell.' + name
        condition = 'condition.spell.' + name
        roster = [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'caster_level': 20, 'spells': [spell], 'at': [4, 6],
             'items': [{'id': 'weapon.quarterstaff', 'slot': 'MELEE_MAIN'},
                       {'id': 'weapon.longsword', 'placement': 'inventory'}]},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.ogre',
             'at': [5, 6]}]
        cast = {'do': spell, 'by': 'caster', 'target': 'self'}
        if name in ('magic_weapon', 'shillelagh'):
            cast['variant'] = {'form': 'MELEE_MAIN'}
        attack = {'do': 'action.attack', 'by': 'caster', 'target': 'target',
                  'weapon_slot': 'MELEE_MAIN'}
        end_turn = {'do': 'end_turn', 'by': 'caster'}
        steps = [cast, dict(end_turn), dict(attack), dict(end_turn)]
        if name != 'shillelagh':
            steps += [{'do': 'action.drop_concentration', 'by': 'caster',
                       'target': 'self'}, dict(attack), dict(end_turn)]
        steps += [{'do': 'unequip', 'by': 'caster', 'slot': 'MELEE_MAIN'}, dict(end_turn),
                  {'do': 'equip', 'by': 'caster', 'item': 'weapon.longsword',
                   'slot': 'MELEE_MAIN'}, dict(end_turn), dict(attack)]
        result.append({
            'id': spell + '/equipped_use_retire_replace',
            'title': name.replace('_', ' ').title() + ': actual held item, use, retirement and replacement',
            'kind': 'spell', 'subjects': subjects([spell], ['action.attack'], [condition]),
            'actors': roster, 'steps': steps, 'seed': 2,
            'required_behaviors': [spell, 'action.attack'] +
                ([] if name == 'shillelagh' else ['action.drop_concentration']),
            'required_conditions': [condition],
            'required_condition_ends': [condition], 'required_facts': ['attack'],
            'purpose': 'Exact real equipped item lifecycle and public owner evidence. '
                       'A missing authoritative owner is a failed requirement, never a fabricated lifetime.'})
    return result
