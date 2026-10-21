"""Six source-backed class media originals; only actual native prerequisites qualify.

Saved class progression is the existing direct-character composition path. Each
case has one real party journal; no second faction or successful roll is invented.
"""


def legacy_six_studies(subjects):
    root = 'tools/studio_cases/scenarios/'
    def step(behavior, by='caster', target='self', **extra):
        return {'do': behavior, 'by': by, 'target': target, **extra}
    def study(identity, title, profile, steps, actions, spells=(), **extra):
        return {'id': identity, 'title': title, 'kind': 'action', 'seed': 2,
            'subjects': subjects(spells, actions),
            'actors': [{'role': 'caster', 'side': 'party'}, {'role': 'ally', 'side': 'party'}],
            'player_builds_source': root+profile+'.json', 'steps': steps,
            'required_behaviors': list(actions),
            'purpose': 'Real progressed class owners and legal public choices. Natural save/witness prerequisites stay explicit; failed originals are preserved.', **extra}
    forward = 'action.class.sorcerer.convert_sorcery_points_to_slot'
    reverse = 'action.class.sorcerer.convert_slot_to_sorcery_points'
    wings = 'action.class.sorcerer.dragon_wings.toggle'
    font_steps = [step('spell.magic_missile', target='Goblin 1', level=1),
        step(forward, variant={'rank': '1'}, capture_choices=True)]
    def font_witness(behavior, direction, points, slots):
        return {'kind': 'action', 'behavior_id': behavior, 'field': 'font_conversion', 'actor_role': 'caster', 'actor_field': 'source_entity_uuid',
            'when': {'direction': direction, 'slot_level': 1, 'sorcery_points_delta': points, 'spell_slots_delta': slots}}
    # The original party choices disclose [6,12]. Its native radius-four
    # circle includes the ally at [10,12], excluding the caster at [10,10].
    # Preview remains authoritative for every paid cast; no allied entity
    # target or successful passive outcome is supplied by the scenario.
    return [
        study(forward+'/actual_font_conversion', 'Font of Magic: real spent slot restored with sorcery points',
            'legacy_sorcerer14_fighter17', font_steps, [forward], ['spell.magic_missile'],
            required_fact_witnesses=[font_witness(forward, 'points_to_slot', -2, 1)]),
        study(reverse+'/actual_font_conversion', 'Font of Magic: real slot converted into available sorcery points',
            'legacy_sorcerer14_fighter17', font_steps+[step('end_turn'), step(reverse, variant={'rank': '1'}, capture_choices=True)],
            [forward, reverse], ['spell.magic_missile'],
            required_fact_witnesses=[font_witness(forward, 'points_to_slot', -2, 1), font_witness(reverse, 'slot_to_points', 1, -1)]),
        study(wings+'/apply_move_dismiss', 'Dragon Wings: actual application, independent movement and exact dismissal',
            'legacy_sorcerer14_fighter17', [step(wings, capture_choices=True), step('action.move', target=[9, 10]),
                step('end_turn'), step(wings, capture_choices=True)], [wings, 'action.move'],
            required_conditions=['class_feature.sorcerer.dragon_wings.active'],
            required_condition_ends=['class_feature.sorcerer.dragon_wings.active']),
        study('action.class.barbarian.extend_intimidating_presence/actual_extension',
            'Intimidating Presence: actual fear, legal Action Surge and same-turn extension',
            'legacy_berserker10_fighter2_party', [step('action.class.barbarian.intimidating_presence', target='Goblin 2', capture_choices=True),
                step('action.class.fighter.action_surge'),
                step('action.class.barbarian.extend_intimidating_presence', target='Goblin 2', capture_choices=True)],
            ['action.class.barbarian.intimidating_presence', 'action.class.fighter.action_surge', 'action.class.barbarian.extend_intimidating_presence'],
            required_conditions=['condition.frightened'],
            purpose='The preserved failed 9f original offered Goblin 2 for Intimidating Presence, not Goblin 1. Select that exact public recipient for the initial fear and same-turn extension; a natural save still leaves the required fear/extension genuinely unavailable.'),
        study('class_feature.fighter.indomitable/actual_successful_reroll',
            'Indomitable: actual failed save, native reroll and disclosed successful witness',
            'legacy_sorcerer14_fighter17', [step('spell.fireball', target=[6, 12], level=3, capture_choices=True),
                step('end_turn', by='caster'), step('end_turn', by='ally'),
                step('spell.fireball', target=[6, 12], level=3, capture_choices=True),
                step('end_turn', by='caster'), step('end_turn', by='ally'),
                step('spell.fireball', target=[6, 12], level=3, capture_choices=True)], [], ['spell.fireball'],
            required_facts=['saving_throw'],
            required_fact_witnesses=[{'kind': 'saving_throw', 'field': 'indomitable_reroll', 'actor_role': 'ally', 'actor_field': 'target_entity_uuid', 'when': {'succeeded': True}}],
            purpose='The preserved failed 9f ChoicesResponse discloses aim [6,12], caster [10,10] and ally [10,12]; the original [10,16] aim was outside line of sight. Native Fireball radius-four squared distances are caster 20>16 and ally 16<=16; both originally nearby Goblins are outside (17>16). The later [11,14] original recorded a genuine successful Indomitable witness but killed both Goblins and ended combat before its end_turn. Keep this fight active and explicitly pass each actual caster/ally turn. Each preview/paid cast remains authoritative, and an absent successful witness still fails.'),
        study('class_feature.barbarian.relentless_rage/actual_taken_intervention',
            'Relentless Rage: actual Rage, legal area damage and native lethal TAKEN intervention',
            'legacy_sorcerer14_barbarian11', [
                step('end_turn', by='caster'),
                step('action.class.barbarian.frenzy', by='ally', capture_choices=True), step('end_turn', by='ally'),
                step('spell.fireball', target=[6, 12], level=7, capture_choices=True),
                step('end_turn', by='caster'), step('end_turn', by='ally'),
                step('spell.fireball', target=[6, 12], level=6, capture_choices=True),
                step('end_turn', by='caster'), step('end_turn', by='ally'),
                step('spell.fireball', target=[6, 12], level=5, capture_choices=True),
                step('end_turn', by='caster'), step('end_turn', by='ally'),
                step('spell.fireball', target=[6, 12], level=5, capture_choices=True),
                step('end_turn', by='caster'), step('end_turn', by='ally'),
                step('spell.fireball', target=[6, 12], level=4, capture_choices=True),
                step('end_turn', by='caster'), step('end_turn', by='ally'),
                step('spell.fireball', target=[6, 12], level=4, capture_choices=True)],
            ['action.class.barbarian.frenzy'], ['spell.fireball'], required_facts=['damage'],
            required_conditions=['class_feature.barbarian.raging'],
            required_fact_witnesses=[{'kind': 'damage', 'stage': 'taken', 'field': 'relentless_rage', 'actor_role': 'ally', 'actor_field': 'target_entity_uuid', 'when': {'succeeded': True}}],
            purpose='The preserved failed 9f original proves Magic Missile offers only hostile Goblins, so it cannot supply an allied target. The next original reached the correct ally turn, but this real Berserker progression replaces Rage with Frenzy (native barbarian_grants.py); select that actual action and its actual Raging parent. Pass caster/ally turns explicitly, then use ordinary paid Fireballs at disclosed [6,12]: ally [10,12] is inside the radius-four footprint (distance squared 16), caster [10,10] is outside (20), and both originally nearby Goblins are outside (17). No hit points, saves or intervention are prescribed; an absent successful completed TAKEN witness remains a failure.'),
    ]
