"""Created intrinsic weapon through actual equip boundaries and native expiry."""


def flame_blade_weapon_study(subjects):
    inventory = subjects(['spell.flame_blade'], ['action.move', 'action.attack'],
                         ['condition.spell.flame_blade'])
    inventory['item'] = ['weapon.flame_blade', 'weapon.longsword']
    attack = {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'MELEE_MAIN'}
    end = {'do': 'end_turn', 'by': 'caster'}
    return {
        'id': 'spell.flame_blade/equipped_reequip_expire_replace',
        'title': 'Flame Blade: actual created Scimitar, movement, contact, re-equip and expiry',
        'kind': 'spell', 'subjects': inventory, 'seed': 2,
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'caster_level': 20, 'spells': ['spell.flame_blade'], 'at': [4, 6],
             'items': [{'id': 'weapon.longsword', 'placement': 'inventory'}]},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.ogre_zombie', 'at': [6, 6]}],
        'steps': [
            {'do': 'spell.flame_blade', 'by': 'caster', 'target': 'self', 'level': 2},
            {'do': 'action.move', 'by': 'caster', 'target': [5, 6]}, dict(attack), dict(end),
            {'do': 'unequip', 'by': 'caster', 'slot': 'MELEE_MAIN'}, dict(end),
            {'do': 'equip', 'by': 'caster', 'item': 'weapon.flame_blade', 'slot': 'MELEE_MAIN'},
            {'do': 'action.move', 'by': 'caster', 'target': [5, 5]}, dict(attack),
            *[dict(end) for _ in range(10)],
            {'do': 'equip', 'by': 'caster', 'item': 'weapon.longsword', 'slot': 'MELEE_MAIN'},
            {'do': 'action.move', 'by': 'caster', 'target': [5, 6]}, dict(attack)],
        'required_behaviors': ['spell.flame_blade', 'action.move', 'action.attack'],
        'required_conditions': ['condition.spell.flame_blade'],
        'required_condition_ends': ['condition.spell.flame_blade'],
        'required_facts': ['movement', 'attack', 'damage'],
        'required_applied_damage_types': ['Fire'],
        'purpose': 'Actual spell-created item UUID and two real equipped intervals, including same-item '
                   're-equip, observed native lifetime expiry and plain replacement. No substitute '
                   'weapon body, fabricated holder/membership, inferred expiry or client light.'}
