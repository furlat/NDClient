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

    def contact(effect, damage_type, *, exposure=None):
        result = {'perspective': 'blue', 'kind': 'damage', 'stage': 'applied',
                  'actor_role': 'target', 'actor_field': 'target_entity_uuid',
                  'where': {'damage_type': damage_type}, 'field': 'effect_id', 'equals': effect}
        if exposure is not None:
            result.update(field='spatial_source', when={'exposure': exposure})
            result.pop('equals')
            result['where']['effect_id'] = effect
        return result

    fire = field('spell.wall_of_fire', 'contact_heat_end',
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
                 witnesses=[contact('wall_of_fire.exposure', 'Fire', exposure='contact'),
                            contact('wall_of_fire.exposure', 'Fire', exposure='radiated_heat')])
    fire['purpose'] += ' The ordered eastward segment heats its positive-y side. Five adjacent steps '
    fire['purpose'] += 'spend 25ft, cross the one-cell flame row and return to8,8 before the real turn end. '
    fire['purpose'] += 'Only the first native entry per turn may burn; the return does not demand another proc.'

    thorns = field('spell.wall_of_thorns', 'crossing_end',
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
                   witnesses=[contact('wall_of_thorns.exposure', 'Slashing')])
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
        row = {'id': spell + ('/frigid_contact_end' if material == 'ice' else '/aperture_end'),
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
            row['required_fact_witnesses'] = [contact('wall_of_ice.frigid_air', 'Cold')]
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


def wall_public_witness_studies(subjects):
    """New originals retain the exact V1 route; only public witness scope changes."""
    selected = {'spell.wall_of_fire/contact_heat_end', 'spell.wall_of_thorns/crossing_end',
                'spell.wall_of_ice/frigid_contact_end'}
    result = []
    for row in wall_continuation_studies(subjects):
        if row['id'] not in selected:
            continue
        # Each call constructs fresh literal scenario data. The original
        # function, case IDs and recorded failures remain untouched.
        source_id = row['id']
        row['id'] += '_public_v2'
        row['title'] += ' · actual public witnesses v2'

        def contact(damage_type, exposure='contact'):
            return {'perspective': 'blue', 'kind': 'damage', 'stage': 'applied',
                    'actor_role': 'target', 'actor_field': 'target_entity_uuid',
                    'where': {'damage_type': damage_type}, 'field': 'spatial_source',
                    'when': {'exposure': exposure}}

        if source_id.startswith('spell.wall_of_fire/'):
            row['required_fact_witnesses'] = [contact('Fire'), contact('Fire', 'radiated_heat')]
            row['purpose'] += ' V2 changes witness scope only: the actual recipient DamageFacts '
            row['purpose'] += 'carry spatial_source.exposure=contact or radiated_heat, with exact '
            row['purpose'] += 'current owner UUID/source position in that public packet; they have no '
            row['purpose'] += 'flat effect_id. Keep positive component attribution, owner identity, '
            row['purpose'] += 'recipient, native turn ancestry and retirement correlated from actual '
            row['purpose'] += 'bytes. Do not invent a per-damage condition UUID or another audience result.'
        elif source_id.startswith('spell.wall_of_thorns/'):
            row['required_behaviors'] = [identity for identity in row['required_behaviors']
                                         if identity != 'action.dash']
            row['required_fact_witnesses'] = [contact('Slashing'),
                {'perspective': 'blue', 'kind': 'action', 'behavior_id': 'action.dash',
                 'actor_role': 'target', 'actor_field': 'source_entity_uuid',
                 'field': 'behavior_id', 'equals': 'action.dash'}]
            row['purpose'] += ' V2 retains Dash as an exact completed Blue actor fact, rather '
            row['purpose'] += 'than requiring that hidden recipient action in Amber summary. Actual '
            row['purpose'] += 'Slashing has spatial_source.exposure=contact and the real owner UUID; '
            row['purpose'] += 'flat effect_id and caster/component source IDs may be absent under '
            row['purpose'] += 'current visibility. Preserve public owner, positions, costly movement '
            row['purpose'] += 'and retirement proof without filling hidden caster attribution.'
        else:
            row['required_facts'] = [kind for kind in row['required_facts'] if kind != 'object_destroyed']
            row['required_fact_witnesses'] = [contact('Cold'),
                {'perspective': 'amber', 'kind': 'spell', 'behavior_id': 'spell.disintegrate',
                 'actor_role': 'caster', 'actor_field': 'source_entity_uuid',
                 'where': {'target_position': [6, 7]}, 'field': 'target_kind', 'equals': 'object'}]
            row['purpose'] = ('V2 keeps the identical actual Ice panel/ordinary object Disintegrate/'
                              'crossing/drop route, actors, stats, map and seed. The public accepted '
                              'Disintegrate names the actual section object at6,7 and target_kind=object; '
                              'neither journal emits ObjectDestroyed for this actual branch. The exact '
                              'public object removal, linked new three-cell FrigidAir owner, later Blue '
                              'positive Cold contact spatial_source UUID and subsequent owner retirement '
                              'must be correlated in the raw original. The scalar accepted-object witness '
                              'and contact witness do not independently establish that cross-packet UUID '
                              'join. No invented destruction fact, previous item, caller, command-derived '
                              'renderer point, private UUID, effect_id or hidden result. V1 remains a '
                              'failed original. No outcome retry or native/art/audio acceptance is implied.')
        result.append(row)
    return result
