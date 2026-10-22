"""Fixed public wall continuations; ordinary commands own every later result."""


def wall_continuation_studies(subjects):
    def mage(role, side, at, spells=()):
        return {'role': role, 'side': side, 'creature': 'creature.generic_caster',
                'level': 20, 'caster_level': 20, 'spells': list(spells), 'at': at}

    def command(behavior, by='caster', target=None, **values):
        return {'do': behavior, 'by': by, **({'target': target} if target is not None else {}), **values}

    def field(spell, case, title, level, steps, actions, *, witnesses=(), extra_spatial=()):
        inventory = subjects([spell], actions, ['condition.concentrating'])
        inventory['spatial_effect'] = ['spatial_effect.' + spell, *extra_spatial]
        return {'id': spell + '/' + case, 'title': title, 'kind': 'spell', 'seed': 2,
                'battlefield': 'battlefield.open_floor_bright', 'subjects': inventory,
                'actors': [mage('caster', 'amber', [3, 7], [spell]), mage('target', 'blue', [8, 9])],
                'steps': [command(spell, target=[6, 7], positions=[[10, 7]], level=level,
                                  variant={'form': 'segment'}, capture_choices=True), *steps],
                'required_behaviors': [spell, *actions],
                'required_facts': ['spell', 'movement', 'spatial_effect_state'],
                'required_conditions': ['condition.concentrating'],
                'required_condition_ends': ['condition.concentrating'],
                'required_fact_witnesses': list(witnesses),
                'purpose': 'Continuation of the preserved cast-only original, using the actual public segment '
                           'facet and both explicit endpoints. Each adjacent target step has a literal '
                           'destination, so the route cannot be satisfied by detouring around the wall. '
                           'Real turns, saves, damage, observations, owner UUIDs and removal remain native; '
                           'no HP/stat/resource edits, forced result, seed search or retry. Recipient-result '
                           'requirements belong only to the real Blue recipient journal. Inspect exact '
                           'spatial owner/source/result lineage and coverage changes in the saved originals '
                           'before accepting each branch. Recording success alone is not native output or '
                           'human art/audio acceptance.'}

    def contact(damage_type, exposure='contact'):
        return {'perspective': 'blue', 'kind': 'damage', 'stage': 'applied',
                'actor_role': 'target', 'actor_field': 'target_entity_uuid',
                'where': {'damage_type': damage_type}, 'field': 'spatial_source',
                'when': {'exposure': exposure}}

    fire = field('spell.wall_of_fire', 'contact_heat_end_public_v2',
                 'Wall of Fire: actual crossing, hot-side turn end and retirement', 4,
                 [command('action.move', 'target', [8, 8]),
                  command('action.move', 'target', [8, 7]),
                  command('action.move', 'target', [8, 6]),
                  command('action.move', 'target', [8, 7]),
                  command('action.move', 'target', [8, 8]),
                  command('end_turn', 'target'),
                  command('action.drop_concentration', target='self'),
                  command('action.move', target=[3, 6]),
                  command('action.move', 'target', [8, 6])],
                 ['action.move', 'action.drop_concentration'],
                 witnesses=[contact('Fire'), contact('Fire', 'radiated_heat')])
    fire['required_field_lifecycle'] = {'perspective': 'blue', 'spell': 'spell.wall_of_fire',
        'content_id': 'spatial_effect.spell.wall_of_fire', 'damage_type': 'Fire',
        'exposures': ['contact', 'radiated_heat']}
    fire['purpose'] += ' The ordered eastward segment heats its positive-y side. Five adjacent steps '
    fire['purpose'] += 'spend 25ft, cross the one-cell flame row and return to8,8 before the real turn end. '
    fire['purpose'] += 'Only the first native entry per turn may burn; the return does not demand another proc.'

    thorns = field('spell.wall_of_thorns', 'crossing_end_public_v2',
                   'Wall of Thorns: actual costly passage, turn end and retirement', 6,
                   [command('action.dash', 'target', 'self'),
                    command('action.move', 'target', [8, 8]),
                    command('action.move', 'target', [8, 7]),
                    command('action.move', 'target', [8, 6]),
                    command('end_turn', 'target'),
                    command('action.move', 'target', [8, 5]),
                    command('action.drop_concentration', target='self'),
                    command('action.move', target=[3, 6]),
                    command('action.move', 'target', [8, 7])],
                   ['action.dash', 'action.move', 'action.drop_concentration'],
                   witnesses=[contact('Slashing'),
                       {'perspective': 'blue', 'kind': 'action', 'behavior_id': 'action.dash',
                        'actor_role': 'target', 'actor_field': 'source_entity_uuid',
                        'field': 'behavior_id', 'equals': 'action.dash'}])
    thorns['required_behaviors'].remove('action.dash')
    thorns['required_field_lifecycle'] = {'perspective': 'blue', 'spell': 'spell.wall_of_thorns',
        'content_id': 'spatial_effect.spell.wall_of_thorns', 'damage_type': 'Slashing',
        'exposures': ['contact']}
    thorns['purpose'] += ' The actual5ft physical width touches rows6,7,8. Dash supplies60ft; '
    thorns['purpose'] += 'the three distinct destination cells each cost20ft. After the real turn end, '
    thorns['purpose'] += 'the next turn exits to8,5 at ordinary floor cost. Slashing exposure cannot '
    thorns['purpose'] += 'be supplied by the preserved Piercing creation-only branch. Natural save, '
    thorns['purpose'] += 'survival, refused movement or missing observation remains a factual failure.'

    rows = [fire, thorns]
    for material, level, end, variant in [('ice', 6, [8, 7], {'form': 'panels', 'side': 'left'}),
                                          ('stone', 5, [10, 7], {'form': 'panels', 'side': 'left', 'width': '20'})]:
        spell = 'spell.wall_of_' + material
        actions = ['action.move', 'action.drop_concentration']
        inventory = subjects([spell, 'spell.disintegrate'], actions, ['condition.concentrating'])
        inventory['spatial_effect'] = ['spatial_effect.' + spell]
        if material == 'ice':
            inventory['spatial_effect'].append('spatial_effect.spell.frigid_air')
        steps = [command(spell, target=[6, 7], positions=[end], level=level,
                         variant=variant, capture_choices=True),
                 command('end_turn'),
                 command('spell.disintegrate', target={'object': 'Wall of ' + material.title() + ' section'},
                         level=6, capture_choices=True)]
        if material == 'ice':
            steps += [command('action.move', 'target', [7, 7]), command('action.move', 'target', [7, 6])]
        steps += [command('action.drop_concentration', target='self'),
                  command('action.move', target=[3, 6]),
                  command('action.move', 'target', [7, 7]), command('action.move', 'target', [7, 8])]
        row = {'id': spell + ('/frigid_contact_end_public_v2' if material == 'ice' else '/aperture_end'),
               'title': 'Wall of ' + material.title() + ': actual section disintegration and retirement',
               'kind': 'spell', 'seed': 2, 'battlefield': 'battlefield.open_floor_bright',
               'subjects': inventory,
               'actors': [mage('caster', 'amber', [3, 7], [spell, 'spell.disintegrate']),
                          mage('target', 'blue', [7, 8])],
               'steps': steps, 'required_behaviors': [spell, 'spell.disintegrate', *actions],
               'required_facts': ['spell', 'object_destroyed', 'movement'],
               'required_conditions': ['condition.concentrating'],
               'required_condition_ends': ['condition.concentrating'],
               'purpose': 'One real public panel construction followed on the next caster turn by the '
                          'ordinary seen-object Disintegrate branch. Exactly one section has the literal '
                          'offered name selected by the existing object selector; no hidden UUID, forced '
                          'damage, attack roll, HP edit or source mutation. The real object destruction '
                          'fact/previous item/placement and actual spatial geometry must establish what '
                          'changed, retaining all surviving coverage and owner identity. Actual drop and '
                          'adjacent post-removal steps remain normal commands. Native output/art/audio '
                          'review are separate; an unavailable object, refusal or natural loss is retained.'}
        if material == 'ice':
            row['required_fact_witnesses'] = [contact('Cold'),
                {'perspective': 'amber', 'kind': 'spell', 'behavior_id': 'spell.disintegrate',
                 'actor_role': 'caster', 'actor_field': 'source_entity_uuid',
                 'where': {'target_position': [6, 7]}, 'field': 'target_kind', 'equals': 'object'}]
            row['required_field_lifecycle'] = {'perspective': 'blue', 'spell': spell,
                'content_id': 'spatial_effect.spell.frigid_air', 'damage_type': 'Cold',
                'exposures': ['contact'], 'ice_section': True}
            row['purpose'] += ' The unique10ft Ice panel is wholly retired; its real FrigidAir child '
            row['purpose'] += 'owns only that destroyed section. Two adjacent steps cross its actual '
            row['purpose'] += 'former sheet before dropping concentration retires the linked child. '
            row['purpose'] += 'No formation target occupies the wall; Cold cannot be supplied by initial displacement.'
        else:
            row['purpose'] += ' The unique20ft Stone panel uses the actually offered width20 facet. '
            row['purpose'] += 'Disintegrate removes a native10ft volume, retaining that same section UUID '
            row['purpose'] += 'and remaining geometry before concentration drop. No permanence loop or '
            row['purpose'] += 'complete-destruction claim substitutes for the real partial aperture.'
        rows.append(row)

    spell = 'spell.wall_of_force'
    inventory = subjects(['spell.see_invisibility', spell, 'spell.disintegrate'], ['action.move'])
    inventory['spatial_effect'] = ['spatial_effect.' + spell]
    rows.append({'id': spell + '/seen_disintegrate_end',
                 'title': 'Wall of Force: actual sight, whole construction disintegration and passage',
                 'kind': 'spell', 'seed': 2, 'battlefield': 'battlefield.open_floor_bright',
                 'subjects': inventory,
                 'actors': [mage('caster', 'amber', [3, 7], ['spell.see_invisibility', spell, 'spell.disintegrate']),
                            mage('target', 'blue', [7, 8])],
                 'steps': [command('spell.see_invisibility', target='self', level=2), command('end_turn'),
                           command(spell, target=[6, 7], positions=[[10, 7]], level=5,
                                   variant={'form': 'panels', 'side': 'left'}, capture_choices=True),
                           command('end_turn'),
                           command('spell.disintegrate', target={'object': 'Wall of Force section'},
                                   level=6, capture_choices=True),
                           command('action.move', target=[3, 6]),
                           command('action.move', 'target', [7, 7]),
                           command('action.move', 'target', [7, 6])],
                 'required_behaviors': ['spell.see_invisibility', spell, 'spell.disintegrate', 'action.move'],
                 'required_facts': ['spell', 'object_destroyed', 'movement'],
                 'purpose': 'Actual SeeInvisibility supplies the sight that mere creator knowledge does '
                            'not. On distinct real caster turns, create two ordinary10ft sections then '
                            'Disintegrate one actually offered named object. The native Force section '
                            'rule removes the complete owner and both real section identities; the target '
                            'then crosses the former sheet through adjacent destinations. No hidden UUID, '
                            'SeeInvisible condition injection, damageable-Force fiction, guessed removal, '
                            'retry or forced outcome. Inspect real sight/discovery, accepted object spell, '
                            'whole-owner/section retirement and actual post-removal path from both original '
                            'journals. This is neither an unseen-force eligibility bypass nor native/art/audio acceptance.'})
    return rows
