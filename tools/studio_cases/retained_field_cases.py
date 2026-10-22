"""Fixed legal retained-field continuation originals; outcomes stay producer-owned."""


def retained_field_studies(subjects):
    def caster(at, spells):
        return {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
                'level': 20, 'caster_level': 20, 'spells': spells, 'at': at}

    def target(at):
        return {'role': 'target', 'side': 'blue', 'creature': 'creature.generic_caster',
                'level': 20, 'caster_level': 20, 'spells': [], 'at': at}

    def command(behavior, by='caster', target=None, **values):
        return {'do': behavior, 'by': by, **({'target': target} if target is not None else {}), **values}

    rows = []
    for spell, damage in [('spell.cloudkill', 'Poison'), ('spell.stinking_cloud', None)]:
        inventory = subjects([spell], ['action.move', 'action.drop_concentration'])
        inventory['spatial_effect'] = ['spatial_effect.' + spell]
        steps = [command(spell, target=[10, 7], level=5 if damage else 3, capture_choices=True),
                 command('end_turn'),
                 command('action.move', 'target', [10, 13]),
                 command('end_turn', 'target'),
                 command('end_turn'),
                 command('action.move', 'target', [12, 9]),
                 command('end_turn', 'target'),
                 command('action.drop_concentration', target='self'),
                 command('action.move', 'target', [14, 9])]
        row = {'id': spell + '/turn_contact_movement_retirement',
               'title': spell.removeprefix('spell.').replace('_', ' ').title() + ': turn, move, re-entry and retirement',
               'kind': 'spell', 'seed': 2, 'battlefield': 'battlefield.open_floor_bright',
               'subjects': inventory, 'actors': [caster([3, 7], [spell]), target([10, 7])],
               'steps': steps, 'required_behaviors': [spell, 'action.move', 'action.drop_concentration'],
               'required_facts': ['spell', 'saving_throw', 'movement'],
               'purpose': 'One fixed legal same-seed route on ordinary unedited native actors. The real target turn '
                          'occurs within the cloud before its actual exit/re-entry and concentration removal. '
                          'Cloudkill owns its real caster-turn drift. Stinking Cloud preserves its actual save '
                          'outcome; Nauseated is not forced or required from a successful save. Exact observed '
                          'spatial UUID/coverage/retirement and any attributed result must be inspected in '
                          'the original bytes; creation alone or a save does not accept a positive contact. '
                          'No scene/source/recipient/outcome is fabricated. Native output and all art/audio '
                          'acceptance remain separate.'}
        if damage:
            row['required_facts'].append('damage')
            row['required_applied_damage_types'] = [damage]
        rows.append(row)

    for element in ['radiant', 'necrotic']:
        spell = 'spell.spirit_guardians'
        inventory = subjects([spell], ['action.move', 'action.drop_concentration'],
                             ['condition.spell.spirit_guardians.slowed'])
        inventory['spatial_effect'] = ['spatial_effect.spell.spirit_guardians']
        rows.append({'id': spell + '/turn_reentry_' + element,
                     'title': 'Spirit Guardians: actual ' + element + ' turn, slow, moving owner and retirement',
                     'kind': 'spell', 'seed': 2, 'battlefield': 'battlefield.open_floor_bright',
                     'subjects': inventory, 'actors': [caster([8, 7], [spell]), target([10, 7])],
                     'steps': [command(spell, target='self', level=3, variant={'damage_type': element}, capture_choices=True),
                               command('end_turn'), command('action.move', 'target', [12, 7]),
                               command('end_turn', 'target'), command('action.move', target=[8, 8]),
                               command('end_turn'), command('action.move', 'target', [10, 7]),
                               command('end_turn', 'target'), command('action.drop_concentration', target='self'),
                               command('action.move', 'target', [14, 7])],
                     'required_behaviors': [spell, 'action.move', 'action.drop_concentration'],
                     'required_facts': ['spell', 'saving_throw', 'damage', 'movement'],
                     'required_conditions': ['condition.spell.spirit_guardians.slowed'],
                     'required_condition_ends': ['condition.spell.spirit_guardians.slowed'],
                     'required_applied_damage_types': [element.title()],
                     'purpose': 'Select only the real public damage_type facet. Ordinary turn-start damage, '
                                'leave/slow withdrawal, actual caster movement, re-entry and concentration '
                                'retirement remain in one fixed route. The native level20 generic target '
                                'keeps its ordinary HP/source/size/equipment and public observations; no '
                                'chosen save/damage roll or inserted membership. Inspect exact owner UUID '
                                'and coverage changes from originals before declaring each branch covered. '
                                'Native rendering, timing and all human art/audio review stay separate.'})
    # The cloud hides the recipient's save from Amber; only its own seat owns it.
    # Keep the earlier primary-seat failure as a distinct immutable original.
    recipient_save = {**rows[1], 'id': 'spell.stinking_cloud/recipient_turn_save_end',
                      'title': 'Stinking Cloud: actual recipient-seat save, movement and retirement',
                      'required_facts': ['spell', 'movement'],
                      'required_fact_witnesses': [{'perspective': 'blue', 'kind': 'saving_throw',
                                                   'actor_role': 'target', 'actor_field': 'target_entity_uuid',
                                                   'field': 'ability_name', 'equals': 'constitution'}],
                      'purpose': rows[1]['purpose'] + ' The unchanged fixed route now requires its '
                                 'actual Constitution save only from the recipient Blue journal. The '
                                 'preserved earlier primary-Amber check failed despite the real Blue save. '
                                 'No hidden recipient event is copied into Amber and no outcome is forced.'}
    rows.append(recipient_save)
    return rows
