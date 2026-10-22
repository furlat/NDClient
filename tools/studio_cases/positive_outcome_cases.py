"""Finite legal positive-outcome studies; every natural failure remains an original."""


def positive_outcome_studies(subjects):
    return [_shove(subjects), *[_stable(subjects, seed) for seed in (4, 5, 6, 7)], _shield(subjects)]


def _shove(subjects):
    return {
        'id': 'action.shove/enhanced_goblin_obstruction_fall',
        'title': 'Shove: Strength advantage, real obstruction and surviving Goblin fall',
        'kind': 'interaction', 'seed': 2,
        'battlefield': 'battlefield.elevation_proving_ground',
        'subjects': subjects(['spell.enhance_ability'],
            ['action.dash', 'action.move', 'action.shove', 'action.drop_concentration'],
            ['condition.spell.enhance_ability', 'condition.prone']),
        'actors': [
            {'role': 'support', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'caster_level': 20, 'spells': ['spell.enhance_ability'], 'at': [4, 4]},
            {'role': 'caster', 'side': 'amber', 'premade': 'fighter', 'at': [5, 4]},
            {'role': 'patient', 'side': 'blue', 'creature': 'creature.goblin', 'at': [8, 4]},
            {'role': 'blocker', 'side': 'amber', 'premade': 'fighter', 'at': [9, 4]}],
        'steps': [
            {'do': 'spell.enhance_ability', 'by': 'support', 'target': 'caster',
             'variant': {'ability': 'strength'}, 'level': 2, 'capture_choices': True},
            {'do': 'action.dash', 'by': 'caster', 'target': 'self'},
            {'do': 'action.move', 'by': 'caster', 'target': [7, 4], 'capture_choices': True},
            {'do': 'action.shove', 'by': 'caster', 'target': 'patient', 'capture_choices': True},
            {'do': 'action.move', 'by': 'blocker', 'target': [10, 4]},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'action.shove', 'by': 'caster', 'target': 'patient', 'capture_choices': True},
            {'do': 'action.move', 'by': 'patient', 'target': [9, 5], 'capture_choices': True},
            {'do': 'action.drop_concentration', 'by': 'support', 'target': 'self'}],
        'required_behaviors': ['spell.enhance_ability', 'action.dash', 'action.shove',
                               'action.move', 'action.drop_concentration'],
        'required_facts': ['shove', 'forced_movement', 'damage', 'movement'],
        'required_conditions': ['condition.spell.enhance_ability', 'condition.prone'],
        'required_condition_ends': ['condition.spell.enhance_ability', 'condition.prone'],
        'required_applied_damage_types': ['Bludgeoning'],
        'required_fact_witnesses': [
            {'kind': 'shove', 'actor_role': 'patient', 'actor_field': 'target_entity_uuid',
             'field': 'push_distance', 'equals': 0, 'where': {'contest_success': True},
             'behavior_id': 'action.shove'},
            {'kind': 'forced_movement', 'actor_role': 'patient', 'actor_field': 'target_entity_uuid',
             'field': 'landing_kind', 'equals': 'fall',
             'where': {'drop_feet': 10, 'start_elevation_feet': 10, 'end_elevation_feet': 0,
                       'start_position': [8, 4], 'end_position': [9, 4]}},
            {'kind': 'step', 'actor_role': 'patient', 'actor_field': 'source_entity_uuid',
             'field': 'committed', 'equals': True, 'perspective': 'blue'}],
        'purpose': 'Actual paid touch Enhance Ability Strength supplies native check advantage to the '
            'unchanged Fighter5. Dash pays one action, Move takes the authored stairs from (5,4) to '
            '(7,4), and Shove pays a separate bonus action. The enemy native Goblin is publicly eligible, '
            '40lb, passive Acrobatics12 and unmodified7HP; this is not the old strong Fighter target. '
            'Its first intended landing (9,4) is occupied by the living blocker, so the exact SAME '
            'completed Shove must have contest_success=true/push_distance0. After the blocker legally '
            'moves to (10,4), a fresh caster turn supplies the second ordinary Shove. The first lower '
            'support (9,4) is a real10ft fall; native1d6 damage cannot kill the uninjured7HP Goblin. '
            'Actual Prone removal and patient Step are required, followed by real concentration drop. '
            'Both checks can still fail naturally. No ally auto-success, stat/HP/map edit, forced die '
            'or repeated-until-success command is used; previous failed originals stay unchanged.'}


def _stable(subjects, seed):
    return {
        'id': 'survival.death_save/ordinary_stable_s' + str(seed),
        'title': 'Ordinary death-save stabilization: fixed seed ' + str(seed),
        'kind': 'interaction', 'seed': seed, 'battlefield': 'battlefield.open_floor_bright',
        'subjects': subjects(['spell.magic_missile']),
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'caster_level': 20, 'at': [3, 6]},
            {'role': 'patient', 'side': 'amber', 'premade': 'fighter', 'at': [4, 6], 'damage': 43},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.generic_caster',
             'level': 20, 'caster_level': 20, 'spells': ['spell.magic_missile'], 'at': [9, 6]}],
        'steps': [
            {'do': 'spell.magic_missile', 'by': 'target', 'target': 'patient', 'level': 1,
             'recipients': ['patient', 'caster', 'caster'], 'capture_choices': True},
            *[{'do': 'end_turn'} for _ in range(24)]],
        'required_behaviors': ['spell.magic_missile'],
        'required_facts': ['damage', 'life', 'death_save'],
        'required_fact_witnesses': [
            {'kind': 'life', 'actor_role': 'patient', 'actor_field': 'entity_uuid',
             'field': 'new_state', 'equals': 'dying',
             'where': {'previous_state': 'alive', 'reason': 'damage'}},
            {'kind': 'death_save', 'actor_role': 'patient', 'actor_field': 'entity_uuid',
             'field': 'succeeded', 'equals': True},
            {'kind': 'life', 'actor_role': 'patient', 'actor_field': 'entity_uuid',
             'field': 'new_state', 'equals': 'stable',
             'where': {'previous_state': 'dying', 'reason': 'stabilization'}}],
        'purpose': 'One of the finite seed4/5/6/7 originals declared together before recording; all four '
            'are retained regardless of results. Existing public RosterStartingDamage43 calls real '
            'receive_damage and leaves native Fighter5 alive at1/44HP; no private HP/counter mutation '
            'or initial Dying/Stable condition is used. Only one actual L1 Magic Missile dart targets '
            'the patient; the other two target the healthy caster20. Real2-5 Force drops the patient '
            'without massive damage. The following24 fixed steps only end published turns: no later '
            'attack, healing, Medicine, Spare the Dying or forced roll. Require the same patient actual '
            'Alive-to-Dying and Dying-to-Stable Life facts, plus real successful DeathSave facts. Raw '
            'proof must join the ordinary third-success result to that stabilization; public DeathSaveFact '
            'does not expose private success counters/became_stable. Natural20 healing, death or no '
            'Stable remains failed. No seed prediction, adaptive reroll loop or replacing failed bytes.'}


def _shield(subjects):
    attacks = [
        {'do': behavior, 'by': 'archer', 'target': 'caster', 'weapon_slot': 'RANGED_MAIN',
         'track': True, 'track_condition': 'condition.spell.shield', 'capture_choices': True}
        for behavior in ('action.attack', 'action.feature.extra_attack')]
    return {
        'id': 'spell.shield/native_archer_ranged_lifecycle_public_v2',
        'title': 'Shield: native Archery Fighter exchange, actual interception, end and walk',
        'kind': 'spell', 'seed': 2, 'battlefield': 'battlefield.open_floor_bright',
        'subjects': subjects(['spell.shield'],
            ['action.attack', 'action.feature.extra_attack', 'action.class.fighter.action_surge', 'action.move'],
            ['condition.spell.shield']),
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'at': [4, 6]},
            {'role': 'archer', 'side': 'blue', 'premade': 'scenario.fighter_l5_archer', 'at': [9, 6]}],
        'steps': [dict(attacks[0]), dict(attacks[1]),
                  {'do': 'action.class.fighter.action_surge', 'by': 'archer', 'target': 'self'},
                  dict(attacks[0]), dict(attacks[1]),
                  {'do': 'end_tracked', 'prefer_turns': True, 'max_turns': 4},
                  {'do': 'tail_walk', 'by': 'caster', 'offset': [-1, 0]}],
        'required_behaviors': ['action.attack', 'action.feature.extra_attack',
            'action.class.fighter.action_surge', 'reaction.spell.shield', 'action.move'],
        'required_facts': ['attack', 'actor_change', 'movement'],
        'required_conditions': ['condition.spell.shield'],
        'required_condition_ends': ['condition.spell.shield'],
        'required_fact_witnesses': [
            {'kind': 'attack', 'actor_role': 'archer', 'actor_field': 'source_entity_uuid',
             'field': 'weapon_slot', 'equals': 'RANGED_MAIN',
             'where': {'source_item_id': 'weapon.longbow', 'attack_source_kind': 'equipped',
                       'attack_outcome': 'Miss'}, 'perspective': perspective}
            for perspective in ('amber', 'blue')],
        'purpose': 'Use the actual shipped scenario.fighter_l5_archer: DEX16, native Archery+2, '
            'proficiency3 and equipped longbow, versus actual generic20 caster DEX14/unarmoredAC12, '
            'native full slots/reaction Shield and160HP. No item/spell/stat grant or reaction override '
            'is added. At25ft the fixed paid Attack/earned Extra/paid Surge/new Attack/new earned Extra '
            'sequence is unconditional. Only an ordinary Hit in [AC,AC+5) can spend real Shield and '
            'change it to Miss; high hits, Crits and ordinary misses do not qualify. This sensible native '
            'setup creates an opportunity, not an outcome guarantee. Track the real own condition UUID, '
            'advance actual turns to retirement, then walk. Required summary behavior/condition and '
            'both-seat equipped ranged Miss witnesses are preliminary guards; independent raw/native '
            'proof must additionally join Attack.intercepted_by_condition_uuid to this recipient own '
            'Shield UUID, effective_handler reaction attribution, exact removal and post-removal Step. '
            'No Magic Missile/melee attack can supply an unrelated Shield here. All earlier miss-only '
            'originals remain failed and unchanged.'}
