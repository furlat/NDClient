"""Legal retained payload, granted action and recipient outcome recordings."""


def event_family_studies(actors, subjects):
    result = []
    for spell, form in [('spell.freezing_sphere', 'launch'), ('spell.freezing_sphere', 'portable'),
                        ('spell.delayed_blast_fireball', 'concentration_end')]:
        roster = actors([spell])
        steps = [{'do': spell, 'by': 'caster', 'target': [6, 7], 'capture_choices': True}]
        actions = []
        if form == 'portable':
            steps = [{'do': spell, 'by': 'caster', 'target': 'ally', 'variant': {'form': 'portable'}},
                     {'do': 'action.spell.payload.throw', 'by': 'ally', 'target': [6, 7], 'capture_choices': True}]
            actions = ['action.spell.payload.throw']
        elif form == 'launch':
            steps[0]['variant'] = {'form': 'launch'}
        else:
            steps += [{'do': 'action.move', 'by': 'caster', 'target': [2, 7]},
                      {'do': 'action.drop_concentration', 'by': 'caster', 'target': 'self'}]
            actions = ['action.drop_concentration']
        result.append({'id': spell + '/' + form + '_detonation', 'title': spell + ': actual ' + form + ' detonation',
                       'kind': 'spell', 'seed': 2, 'actors': roster, 'steps': steps,
                       'subjects': subjects([spell], actions), 'required_behaviors': [spell] + actions,
                       'required_facts': ['damage'], 'required_applied_damage_types': ['Cold' if spell.endswith('freezing_sphere') else 'Fire'],
                       'purpose': 'Legal release/retirement and original applied results; no fabricated payload state or blast admission.'})
    roster = actors(['spell.vitriolic_sphere'])
    result.append({'id': 'spell.vitriolic_sphere/delayed_end_results',
                   'title': 'Vitriolic Sphere: original recipient END damage and residue removal',
                   'kind': 'spell', 'seed': 2, 'actors': roster,
                   'subjects': subjects(['spell.vitriolic_sphere'], conditions=['condition.spell.vitriolic_sphere.residue']),
                   'steps': [{'do': 'spell.vitriolic_sphere', 'by': 'caster', 'target': [6, 7]}]
                            + [{'do': 'end_turn'} for _ in range(6)],
                   'required_behaviors': ['spell.vitriolic_sphere'],
                   'required_conditions': ['condition.spell.vitriolic_sphere.residue'],
                   'required_condition_ends': ['condition.spell.vitriolic_sphere.residue'],
                   'required_applied_damage_types': ['Acid'],
                   'purpose': 'Original independent seat journals retain actual delayed results and exact residue owners; no turn counting in rendering.'})
    for element in ('acid', 'cold', 'fire', 'lightning', 'poison'):
        roster = actors(['spell.dragons_breath'])
        result.append({'id': 'spell.dragons_breath/' + element + '_grant_exhale_end',
                       'title': "Dragon's Breath: " + element + ' grant, actual recipient exhale and end',
                       'kind': 'spell', 'seed': 2, 'actors': roster,
                       'subjects': subjects(['spell.dragons_breath'], ['action.spell.dragons_breath.exhale', 'action.drop_concentration'],
                                            ['condition.spell.dragons_breath']),
                       'steps': [{'do': 'spell.dragons_breath', 'by': 'caster', 'target': 'ally', 'variant': {'damage_type': element}},
                                 {'do': 'action.spell.dragons_breath.exhale', 'by': 'ally', 'target': [5, 7], 'capture_choices': True},
                                 {'do': 'action.drop_concentration', 'by': 'caster', 'target': 'self'}],
                       'required_behaviors': ['spell.dragons_breath', 'action.spell.dragons_breath.exhale', 'action.drop_concentration'],
                       'required_conditions': ['condition.spell.dragons_breath'],
                       'required_condition_ends': ['condition.spell.dragons_breath'],
                       'required_applied_damage_types': [element.title()],
                       'purpose': 'Actual granted action, native condition UUID and disclosed results. Element/readiness are never inferred from concentration.'})
    for outcome, wounds, conditions in [('deafened', 14, ['condition.deafened']),
                                         ('blinded_deafened', 24, ['condition.blinded', 'condition.deafened']),
                                         ('blinded_deafened_stunned', 34, ['condition.blinded', 'condition.deafened', 'condition.stunned']),
                                         ('death', 44, [])]:
        roster = actors(['spell.divine_word'])
        roster[2] = {'role': 'target', 'side': 'blue', 'creature': 'creature.knight', 'at': [4, 7], 'damage': wounds}
        result.append({'id': 'spell.divine_word/' + outcome + '_outcome', 'title': 'Divine Word: actual ' + outcome + ' outcome',
                       'kind': 'spell', 'seed': 2, 'actors': roster,
                       'subjects': subjects(['spell.divine_word'], conditions=conditions),
                       'steps': [{'do': 'spell.divine_word', 'by': 'caster', 'target': 'target', 'recipients': ['target'], 'capture_choices': True}],
                       'required_behaviors': ['spell.divine_word'], 'required_conditions': conditions,
                       'required_facts': ['life'] if outcome == 'death' else [],
                       'purpose': 'Legal wounded target setup; renderer must consume actual child membership/life outcomes, never evaluate HP tiers.'})
    return result
