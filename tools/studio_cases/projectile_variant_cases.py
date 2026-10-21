"""Actual chosen-element declarations and missed projectile originals."""


def projectile_variant_studies(actors, subjects):
    result = []
    for spell, elements in [('spell.sorcerous_burst', ('acid', 'cold', 'fire', 'lightning', 'poison', 'psychic', 'thunder')),
                            ('spell.chromatic_orb', ('acid', 'cold', 'fire', 'lightning', 'poison', 'thunder'))]:
        for element in elements:
            roster = actors([spell])
            roster[2] = {'role': 'target', 'side': 'blue', 'creature': 'creature.knight', 'at': [4, 7]}
            result.append({'id': spell + '/' + element + '_original', 'title': spell + ': actual ' + element + ' choice',
                           'kind': 'spell', 'subjects': subjects([spell]), 'actors': roster, 'seed': 2,
                           'steps': [{'do': spell, 'by': 'caster', 'target': 'target',
                                      'variant': {'damage_type': element}, 'capture_choices': True}],
                           'required_behaviors': [spell],
                           'purpose': 'Preserve literal public declaration and recipient outcome for supported production dispatch; no inferred element from damage.'})
    roster = actors(['spell.acid_arrow'])
    roster[2]['at'] = [6, 7]
    result.append({'id': 'spell.acid_arrow/miss_original', 'title': 'Acid Arrow: actual Dodge and missed projectile',
                   'kind': 'spell', 'subjects': subjects(['spell.acid_arrow'], ['action.dodge']), 'actors': roster, 'seed': 2,
                   'steps': [{'do': 'action.dodge', 'by': 'target', 'target': 'self'},
                             {'do': 'spell.acid_arrow', 'by': 'caster', 'target': 'target', 'level': 2}],
                   'required_behaviors': ['spell.acid_arrow', 'action.dodge'],
                   'purpose': 'Actual finite missed delivery/splash, with no fabricated residue cells or poisoned condition.'})
    # A bounded legal seed cohort retains Hits as Hits; only an original
    # disclosed Miss can qualify the missed delivery branch.
    for seed in (3, 5, 7):
        roster = actors(['spell.acid_arrow'])
        roster[2]['at'] = [6, 7]
        result.append({'id': 'spell.acid_arrow/dodge_seed_' + str(seed),
                       'title': 'Acid Arrow: Dodge outcome, seed ' + str(seed),
                       'kind': 'spell', 'subjects': subjects(['spell.acid_arrow'], ['action.dodge']), 'actors': roster, 'seed': seed,
                       'steps': [{'do': 'action.dodge', 'by': 'target', 'target': 'self'},
                                 {'do': 'spell.acid_arrow', 'by': 'caster', 'target': 'target', 'level': 2}],
                       'required_behaviors': ['spell.acid_arrow', 'action.dodge'],
                       'purpose': 'Actual original hit/miss outcome cohort; no retargeting, outcome relabeling or fabricated residue cells.'})
    return result
