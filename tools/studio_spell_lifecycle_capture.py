"""Record whole spell lifecycles for the Studio through real server commands.

Each case shows the cast and its delivery, the lasting condition on its
recipient, that recipient walking with the condition on, the condition ending
through an ordinary engine rule (duration expiry by ended turns, dropped
concentration, donned armour, a woken sleeper, the next turn start), and a
short walk afterwards. Spells without a lasting condition record the cast,
its impact and the recipient walking afterwards.

Setup uses the same published encounter recipe edits as
studio_spell_capture.py; every later action is a legal SDK choice/preview/
command through studio_capture.record. Nothing is injected or rewritten.
Both original faction journals stay under the ignored output directory; the
compact inventory names the lifecycle events. With --godot the published
Studio times of those events are read back through the Studio's own index
(tools/studio_spell_lifecycle_times.gd) and merged into the inventory.

Run with the pinned engine's Python environment, the engine and its
sdk/python/src on PYTHONPATH, and --engine pointing at that engine copy.
"""
import argparse
import asyncio
from collections import Counter
import json
from pathlib import Path
import socket
import subprocess
import sys

from dnd.content.characters.premades import FIGHTER_PREMADE_ID
from dnd.core.content.encounters import (EncounterDeploymentSpec, EncounterRecipe,
    EncounterRosterRecipe, PremadeCharacterRosterSource, RosterStartingDamage,
    RosterSpellGrant, RosterItemGrant, RosterItemPlacement)
from dnd.core.creature_types import DamageType
from dnd.core.equipment_types import BodyPart
from dnd.core.content.registration import get_content_declaration
from dnd.spells.catalog_content import SPELL_CONTENT_IDENTITY_BY_NAME
from dnd.spells.infernal import THAUMATURGY_SPELL_DECLARATION
from dnd.player.audience import SeatAssignment
from dnd.player.reduction import reduce_initialization, reduce_operation
from server.protocol import InitializationResponse, PlayerOperation
from devtools.player_server_acceptance.fixtures import combat_configuration
from studio_capture import action, record
from studio_spell_capture import CASE_SEEDS, FAMILIES, resource_path

PROJECT = Path(__file__).resolve().parents[1]
CASTER, RECIPIENT, ALLY, HELPER = 'Amber spell caster', 'Blue spell recipient', 'Amber spell recipient', 'Blue spell helper'
FAMILIES = {**FAMILIES, 'aid': 'Protection / maximum HP', 'bless': 'Condition / concentration',
    'false_life': 'Self / temporary HP', 'sacred_flame': 'Save / damage',
    'shield_ranged': 'Reaction / ranged weapon', 'shield_walk': 'Reaction / opportunity attack'}
LANDING = {'acid_splash', 'eldritch_blast', 'fire_bolt', 'fireball', 'ice_knife', 'magic_missile', 'produce_flame', 'scorching_ray',
    'sacred_flame', 'poison_spray', 'burning_hands', 'thunderwave', 'true_strike', 'chill_touch', 'ray_of_frost', 'guiding_bolt',
    'shocking_grasp', 'cure_wounds', 'healing_word'}
# Reviewed seeds whose server-rolled outcomes show the whole lifecycle (hit or
# failed save, Shield turning the weapon attack). Other seeds remain fallbacks.
LIFECYCLE_SEEDS = {'acid_splash': 2, 'poison_spray': 2, 'sleep': 2, 'web': 2, 'bane': 2, 'command': 2, 'burning_hands': 2,
    'thunderwave': 2, 'guidance': 2, 'light': 2, 'thaumaturgy': 2, 'shield_of_faith': 2, 'sacred_flame': 2, 'shield_walk': 17, 'shield_ranged': 17}
HOLD, TAIL = (0, 4), (4, 0)  # tiles walked with the condition on, then after it ends (about two seconds)


def case_id(spell):
    # The extra Shield cases are further recordings of the same spell capability.
    return 'native-spell-' + {'shield_ranged': 'shield-ranged', 'shield_walk': 'shield-walk'}.get(spell, spell)


def plan(spell):
    """Recipient, tracked condition, ordered steps and the engine rule that ends it."""
    def cast(**values):
        return action('spell.' + spell, actor_name=CASTER, **values)
    def walk(name, offset):
        return action('action.move', actor_name=name, offset=list(offset))
    def turns(condition, count=60):
        # Ordinary end_turn commands only until the server publishes the removal.
        return [action('end_turn', skip_if_removed=condition) for _ in range(count)]
    p = {'recipient': RECIPIENT, 'position': (8, 7), 'condition': None, 'gaps': []}
    self_cast = cast(self_target=True)
    on_recipient = cast(subject_name=RECIPIENT)
    instant = {
        'acid_splash': on_recipient, 'eldritch_blast': cast(subject_name=RECIPIENT, recipients=[0, 0]),
        'fire_bolt': on_recipient, 'fireball': cast(position=[8, 7]), 'ice_knife': on_recipient,
        'magic_missile': cast(subject_name=RECIPIENT, recipients=[0, 0, 0]), 'produce_flame': on_recipient,
        'scorching_ray': cast(subject_name=RECIPIENT, recipients=[0, 0, 0]), 'sacred_flame': on_recipient,
        'poison_spray': on_recipient, 'burning_hands': cast(affected_position=[5, 7]),
        'thunderwave': cast(affected_position=[5, 7]), 'true_strike': on_recipient}
    if spell in instant:
        p['position'] = (4, 7) if spell == 'true_strike' else (5, 7) if spell in ('poison_spray', 'burning_hands', 'thunderwave') else (8, 7)
        # Leaving an adjacent caster's reach would provoke; Disengage keeps the tail to the walk.
        p['steps'] = [instant[spell], *([action('action.disengage', actor_name=RECIPIENT)] if spell == 'true_strike' else []), walk(RECIPIENT, (3, 0))]
        p['ending'] = 'No lasting condition: the recipient walks after the impact.'
    elif spell in ('cure_wounds', 'healing_word', 'thaumaturgy'):
        p.update(recipient=CASTER, steps=[self_cast, walk(CASTER, (0, 3))])
        p['ending'] = 'No lasting condition: the caster walks after the cast.'
    elif spell == 'false_life':
        # The engine grants a temporary hit point pool with no condition or duration;
        # it ends only when damage spends it. The recipient's ordinary shortbow attacks do that.
        p.update(recipient=CASTER, pool='temporary_hit_points')
        shot = lambda behavior: action(behavior, actor_name=RECIPIENT, subject_name=CASTER, weapon_slot='RANGED_MAIN')
        p['steps'] = [self_cast, walk(CASTER, HOLD), shot('action.attack'), shot('action.feature.extra_attack'), walk(CASTER, TAIL)]
        p['ending'] = 'Rule: the temporary hit points end when damage spends them (enemy shortbow hits); False Life has no condition or duration.'
    elif spell in ('chill_touch', 'ray_of_frost', 'guiding_bolt'):
        p['condition'] = {'chill_touch': 'condition.spell.no_healing', 'ray_of_frost': 'condition.spell.ray_of_frost',
            'guiding_bolt': 'condition.spell.guiding_bolt.marked'}[spell]
        p['steps'] = [on_recipient, walk(RECIPIENT, HOLD), *turns(p['condition']), walk(RECIPIENT, TAIL)]
        p['ending'] = {'chill_touch': 'Duration: ends at the start of the caster\'s next turn.',
            'ray_of_frost': 'Duration: ends at the start of the caster\'s next turn.',
            'guiding_bolt': 'Duration: ends at the end of the caster\'s next turn (no attack consumed it).'}[spell]
    elif spell in ('shocking_grasp', 'shield', 'shield_ranged'):
        p['condition'] = 'condition.no_reactions' if spell == 'shocking_grasp' else 'condition.spell.shield'
        p['position'] = (4, 7) if spell == 'shocking_grasp' else (8, 7)
        first = on_recipient if spell == 'shocking_grasp' else action('spell.magic_missile', actor_name=CASTER,
            subject_name=RECIPIENT, recipients=[0, 0, 0]) if spell == 'shield' else action('action.attack',
            actor_name=CASTER, subject_name=RECIPIENT, weapon_slot='RANGED_MAIN')
        tail = [action('action.disengage', actor_name=RECIPIENT)] if spell == 'shocking_grasp' else []
        p['steps'] = [first, *turns(p['condition']), *tail, walk(RECIPIENT, (3, 0) if spell == 'shocking_grasp' else TAIL)]
        p['ending'] = 'Duration: ends at the start of the recipient\'s next turn.' if spell == 'shocking_grasp' else \
            'Duration: Shield ends at the start of its caster\'s next turn.'
        p['gaps'].append('The condition ends when the recipient\'s own next turn starts, so it is never on during a turn in which the recipient can walk.'
            + (' The Shield · opportunity attack case shows Shield held while walking.' if spell != 'shocking_grasp' else ''))
    elif spell == 'shield_walk':
        # Shield cast on the recipient's own turn: leaving the caster's reach provokes
        # the server's automatic opportunity attack, and the rest of the walk keeps Shield.
        p.update(condition='condition.spell.shield', position=(4, 7))
        p['steps'] = [action('end_turn', actor_name=CASTER), walk(RECIPIENT, HOLD), *turns(p['condition']), walk(RECIPIENT, TAIL)]
        p['ending'] = 'Duration: Shield ends at the start of its caster\'s next turn.'
    elif spell == 'command':
        p['condition'] = 'condition.spell.command.grovel'
        # Standing from Prone costs half of the following turn's movement.
        p['steps'] = [on_recipient, *turns(p['condition']), walk(RECIPIENT, (3, 0))]
        p['ending'] = 'Rule: Grovel spends the target\'s next turn prone and ends when that commanded turn ends; Prone ends when it stands at its following turn.'
        p['gaps'].append('Command (Grovel, the only word the SDK offers) denies the commanded turn, so the target cannot walk with it on.')
    elif spell == 'sleep':
        p['condition'] = 'condition.spell.sleep'
        p['steps'] = [cast(position=[8, 7]), walk(HELPER, (0, -4)), action('action.shake_awake', actor_name=HELPER, subject_name=RECIPIENT),
            walk(RECIPIENT, TAIL)]
        p['ending'] = 'Rule: an adjacent ally uses Shake Awake.'
        p['gaps'].append('A sleeping creature is unconscious and has no movement; its turn passes while asleep.')
    elif spell == 'web':
        p['condition'] = 'condition.spell.web.restrained'
        p['steps'] = [cast(position=[8, 7]), action('end_turn', actor_name=CASTER), action('end_turn', actor_name=RECIPIENT),
            action('action.drop_concentration', actor_name=CASTER), walk(RECIPIENT, TAIL)]
        p['ending'] = 'Rule: the caster drops concentration; the web and its restraint end.'
        p['gaps'].append('Restrained by the web, the recipient has no movement until it ends.')
    elif spell == 'bane':
        p['condition'] = 'condition.spell.bane'
        p['steps'] = [on_recipient, walk(RECIPIENT, HOLD), action('action.drop_concentration', actor_name=CASTER), walk(RECIPIENT, TAIL)]
        p['ending'] = 'Rule: the caster drops concentration (Bane has no shorter duration here).'
    elif spell in ('bless', 'aid', 'guidance', 'light'):
        p.update(recipient=ALLY, position=(8, 7))
        p['condition'] = 'condition.spell.' + spell
        target = cast(subject_name=ALLY)
        if spell in ('guidance', 'light'):
            p['steps'] = [target, walk(ALLY, HOLD), *turns(p['condition']), walk(ALLY, TAIL)]
            p['ending'] = 'Duration: the 10-round effect expires through ended turns.'
        elif spell == 'bless':
            p['steps'] = [target, walk(ALLY, HOLD), action('action.drop_concentration', actor_name=CASTER), walk(ALLY, TAIL)]
            p['ending'] = 'Rule: the caster drops concentration.'
        else:
            p['steps'] = [target, walk(ALLY, HOLD)]
            p['ending'] = 'Aid lasts 8 hours with no dismissal; it cannot end inside an encounter.'
            p['gaps'].append('Aid has no in-encounter end: no expiry within combat rounds and no dismiss action.')
    elif spell in ('resistance', 'sanctuary', 'shield_of_faith', 'mage_armor'):
        p.update(recipient=CASTER)
        p['condition'] = 'condition.spell.' + spell
        if spell in ('resistance', 'sanctuary'):
            p['steps'] = [self_cast, walk(CASTER, HOLD), *turns(p['condition']), walk(CASTER, TAIL)]
            p['ending'] = 'Duration: the 10-round effect expires through ended turns.'
        elif spell == 'shield_of_faith':
            p['steps'] = [self_cast, walk(CASTER, HOLD), action('end_turn', actor_name=CASTER),
                action('action.drop_concentration', actor_name=CASTER), walk(CASTER, TAIL)]
            p['ending'] = 'Rule: the caster drops concentration on its next turn.'
        else:
            p['steps'] = [self_cast, walk(CASTER, HOLD), action('end_turn', actor_name=CASTER),
                action('equip', actor_name=CASTER, item_id='armor.leather', slot=BodyPart.BODY.value), walk(CASTER, TAIL)]
            p['ending'] = 'Rule: Mage Armor ends when its wearer dons armour (8-hour duration otherwise).'
    else:
        raise ValueError('No lifecycle plan for '+spell)
    return p


def setup(spell, output, seed):
    # Same recipe edits as studio_spell_capture.setup. The Shield cases keep the
    # generic caster recipient with its normal automatic Shield reaction.
    p = plan(spell)
    shield = spell.startswith('shield') and spell != 'shield_of_faith'
    config = combat_configuration('magic_missile', output, seed)
    slots = list(config.recipe.roster_slots)
    names = {key.lower().replace(' ', '_'): key for key in SPELL_CONTENT_IDENTITY_BY_NAME}
    for i, slot in enumerate(slots):
        member = slot.roster.members[0]
        if i == 1 and not shield:
            member = member.model_copy(update={'source': PremadeCharacterRosterSource(premade_id=FIGHTER_PREMADE_ID)})
        effects = tuple(effect for effect in member.scenario_setup_effects if effect.kind != 'spell_grant')
        if i == 0 and not shield:
            ref = THAUMATURGY_SPELL_DECLARATION.ref if spell == 'thaumaturgy' else \
                get_content_declaration(SPELL_CONTENT_IDENTITY_BY_NAME[names.get(spell, spell.replace('_', ' ').title())].spell_type).ref
            effects += (RosterSpellGrant(spell_refs=(ref,), caster_level=7),)
        if i == 0 and spell == 'mage_armor':
            effects += (RosterItemGrant(item_id='armor.leather', placement=RosterItemPlacement.INVENTORY),)
        if (i == 0 and spell in ('cure_wounds', 'healing_word')) or (i == 1 and spell == 'sleep'):
            effects += (RosterStartingDamage(amount=15 if i == 0 else 35, damage_type=DamageType.FORCE),)
        member = member.model_copy(update={'scenario_setup_effects': effects, 'display_name': CASTER if i == 0 else RECIPIENT})
        members = (member,)
        fighter = lambda name, member_id, role: member.model_copy(update={'member_id': member_id, 'display_name': name,
            'deployment_role': role, 'source': PremadeCharacterRosterSource(premade_id=FIGHTER_PREMADE_ID), 'scenario_setup_effects': ()})
        if i == 0 and p['recipient'] == ALLY:
            members += (fighter(ALLY, 'unit_2', 'amber_2'),)
        if i == 1 and spell == 'sleep':
            members += (fighter(HELPER, 'unit_2', 'blue_2'),)
        roster = EncounterRosterRecipe.create(**{**slot.roster.model_dump(exclude={'recipe_digest', 'members'}), 'members': members})
        slots[i] = slot.model_copy(update={'roster': roster})
    zones = list(config.recipe.deployment.zones)
    zones[0] = zones[0].model_copy(update={'ordered_slots': ((3, 7), (4, 7)) if p['recipient'] == ALLY else ((3, 7),)})
    # The Sleep helper starts outside the 20-foot sphere and walks in to wake the sleeper.
    zones[1] = zones[1].model_copy(update={'ordered_slots': (p['position'], (8, 12)) if spell == 'sleep' else (p['position'],)})
    deployment = EncounterDeploymentSpec.create(**{**config.recipe.deployment.model_dump(exclude={'content_digest', 'zones'}), 'zones': tuple(zones)})
    recipe = EncounterRecipe.create(**{**config.recipe.model_dump(exclude={'recipe_digest', 'deployment', 'roster_slots', 'opening_policy'}),
        'deployment': deployment, 'roster_slots': tuple(slots), 'opening_policy': config.recipe.opening_policy})
    assignments = tuple(SeatAssignment(slot.roster_slot_id, tuple((slot.roster_slot_id, m.member_id) for m in slot.roster.members)) for slot in slots)
    return config.model_copy(update={'recipe': recipe, 'assignments': assignments}), p


class Seats:
    """Each seat's own received journal, read once and reduced by the public Python player reducer."""
    def __init__(self):
        self.seen = {}

    def read(self, seat):
        state, done, conditions = self.seen.get(seat['id'], (None, -1, set()))
        while True:
            path = seat['journal'] / f'{done+1:016}.json'
            if not path.exists(): break
            raw = path.read_bytes()
            if state is None:
                packet = InitializationResponse.model_validate_json(raw)
                state = reduce_initialization(packet.initialization, content_additions=packet.content_additions)
            else:
                state = reduce_operation(state, PlayerOperation.model_validate_json(raw))
                for lineage in json.loads(raw).get('lineages', []):
                    for node in lineage['events']:
                        fact = node.get('fact')
                        if fact is not None and not node['canceled'] and fact['kind'] == 'condition':
                            conditions.add((fact['event_type'], fact['condition'].get('behavior_id')))
            done += 1
        self.seen[seat['id']] = (state, done, conditions)
        return state, conditions

    def resolve(self, step, seat, actor):
        state, conditions = self.read(seat)
        if 'skip_if_removed' in step:
            # Ordinary end_turn commands until the server publishes the removal.
            # A condition that was never applied (resisted) has nothing to wait for.
            behavior = step['skip_if_removed']
            if ('condition_removal', behavior) in conditions or ('condition_application', behavior) not in conditions: return None
            return {key: value for key, value in step.items() if key != 'skip_if_removed'} | {'until_removed': behavior}
        if 'offset' in step:
            x, y = next(row for key, row in state.actors.items() if str(key) == actor).last_visual_position
            step = {**{key: value for key, value in step.items() if key != 'offset'}, 'position': [x + step['offset'][0], y + step['offset'][1]],
                'requested_offset': step['offset']}
        return step


def facts(journal):
    for path in sorted(journal.glob('[0-9]' * 16 + '.json')):
        packet = json.loads(path.read_bytes())
        for lineage in packet.get('lineages', []):
            for offset, node in enumerate(lineage['events']):
                if node.get('fact') is not None and not node['canceled']:
                    yield packet['cursor']['sequence'], lineage['lineage_uuid'], offset, node


def names(journal):
    packet = json.loads((journal/('0'*16+'.json')).read_bytes())
    return {row['actor']['name']: row['actor']['uuid'] for row in packet['initialization']['observations']}


def lifecycle(spell, p, output, result):
    """Name the recorded lifecycle events (Amber's journal) and qualify the case."""
    journal = output/'amber/journal'
    actors = names(journal)
    recipient = actors.get(p['recipient'])
    rows = [{'sequence': s, 'lineage_uuid': l, 'event_offset': o, 'event_uuid': n['uuid'], 'fact': n['fact']} for s, l, o, n in facts(journal)]
    events, failures = [], [] if result['ok'] else [result['failure']]
    def add(role, row, **extra):
        events.append({'role': role, 'sequence': row['sequence'], 'event_uuid': row['event_uuid'], 'kind': row['fact']['kind'], **extra})
    behavior = 'action.attack' if spell == 'shield_ranged' else 'spell.magic_missile' if spell == 'shield' else 'spell.'+spell
    # The cast is the action's root spell fact; per-recipient applications and
    # secondary effects (Ice Knife's burst) precede it in the lineage.
    casts = [row for row in rows if row['fact']['kind'] in ('spell', 'attack') and row['fact'].get('behavior_id') == behavior]
    roots = [row for row in casts if row['fact']['kind'] == 'spell' and row['fact'].get('application') is None]
    cast = next((row for row in roots if row['fact'].get('effect_id') is None), roots[0] if roots else casts[0] if casts else None)
    if cast is None and spell in ('shield_ranged', 'shield_walk'):
        cast = next((row for row in rows if row['fact']['kind'] == 'attack'), None)
    if cast is None:
        failures.append('No uncanceled cast evidence for '+behavior)
        return events, failures
    add('cast', cast, behavior_id=behavior)
    impacts = [row for row in rows if row['sequence'] == cast['sequence'] and row['fact']['kind'] in ('damage', 'heal', 'saving_throw', 'attack', 'forced_movement', 'area_reach')
        and row is not cast and (row['fact']['kind'] != 'damage' or row['fact'].get('stage') == 'applied')]
    # The reviewed impact is the landed damage/healing when the spell has one.
    landed = [row for row in impacts if row['fact']['kind'] == 'heal' or row['fact'].get('applied_damage', 0) > 0]
    if spell in LANDING and not landed:
        failures.append('No landed damage or healing (the server roll missed or was resisted)')
    impacts = landed or impacts
    if impacts:
        add('impact', impacts[0], fact_kind=impacts[0]['fact']['kind'])
        if len(impacts) > 1: add('impact_last', impacts[-1], fact_kind=impacts[-1]['fact']['kind'])
    def steps(actor, after, before=None):
        return [row for row in rows if row['fact']['kind'] == 'step' and row['fact'].get('committed') and row['fact']['source_entity_uuid'] == actor
            and (row['sequence'], row['event_offset']) > after and (before is None or (row['sequence'], row['event_offset']) < before)]
    applied = ended = None
    if p.get('pool'):
        applied = next((row for row in rows if row['fact']['kind'] == 'temporary_hit_points' and row['fact']['entity_uuid'] == recipient and (row['fact'].get('grant') or {}).get('source_id') == behavior), None)
        if applied is None:
            failures.append('No temporary hit points granted')
            return events, failures
        add('applied', applied, recipient_uuid=recipient, temporary_hp=applied['fact']['resulting_temporary_hp'])
        # Damage reports what it leaves of the pool; the first applied damage that leaves none ends it.
        ended = next((row for row in rows if row['fact']['kind'] in ('temporary_hit_points', 'damage') and row['fact'].get('resulting_temporary_hp') == 0
            and recipient in (row['fact'].get('entity_uuid'), row['fact'].get('target_entity_uuid')) and row['fact'].get('stage', 'applied') == 'applied'
            and (row['sequence'], row['event_offset']) > (applied['sequence'], applied['event_offset'])), None)
        held = steps(recipient, (applied['sequence'], applied['event_offset']), None if ended is None else (ended['sequence'], ended['event_offset']))
        if held:
            add('move_start', held[0], actor_uuid=recipient, from_position=held[0]['fact']['from_position'])
            add('moved', held[-1], actor_uuid=recipient, to_position=held[-1]['fact']['to_position'], tiles=len(held))
        if ended is None:
            failures.append('Damage did not spend the temporary hit points')
        else:
            add('ended', ended, recipient_uuid=recipient, temporary_hp=0)
    elif p['condition']:
        applied = next((row for row in rows if row['fact']['kind'] == 'condition' and row['fact']['event_type'] == 'condition_application'
            and row['fact']['condition'].get('behavior_id') == p['condition'] and row['fact']['target_entity_uuid'] == recipient), None)
        if applied is None:
            failures.append('Lasting condition was not applied: '+p['condition'])
            return events, failures
        holder = applied['fact']['target_entity_uuid']
        identity = applied['fact']['condition']['condition_uuid']
        add('applied', applied, condition_uuid=identity, recipient_uuid=holder, behavior_id=p['condition'])
        ended = next((row for row in rows if row['fact']['kind'] == 'condition' and row['fact']['event_type'] == 'condition_removal'
            and row['fact']['condition']['condition_uuid'] == identity), None)
        held = steps(holder, (applied['sequence'], applied['event_offset']), None if ended is None else (ended['sequence'], ended['event_offset']))
        if held:
            add('move_start', held[0], actor_uuid=holder, condition_uuid=identity, recipient_uuid=holder, from_position=held[0]['fact']['from_position'])
            add('moved', held[-1], actor_uuid=holder, condition_uuid=identity, recipient_uuid=holder, to_position=held[-1]['fact']['to_position'], tiles=len(held))
        elif not p['gaps']:
            failures.append('Recipient did not walk while the condition was on')
        if ended is not None:
            add('ended', ended, condition_uuid=identity, recipient_uuid=holder)
        elif 'cannot end' not in p['ending'] and 'no removal' not in p['ending']:
            failures.append('Lasting condition did not end')
    after = (ended or applied or cast)
    # A condition that cannot end has no afterwards; its walk is the held walk.
    tail = [] if (p['condition'] or p.get('pool')) and ended is None else steps(recipient, (after['sequence'], after['event_offset']))
    if tail:
        add('tail_start', tail[0], actor_uuid=recipient, from_position=tail[0]['fact']['from_position'])
        add('tail', tail[-1], actor_uuid=recipient, to_position=tail[-1]['fact']['to_position'], tiles=len(tail))
    elif not ((p['condition'] or p.get('pool')) and ended is None):
        failures.append('No walk after the effect ends')
    if spell in ('shield_ranged', 'shield_walk'):
        if not any(row['fact']['kind'] == 'attack' and row['fact'].get('attack_outcome') not in (None, 'hit', 'critical_hit') for row in rows):
            failures.append('Shield did not turn the weapon attack')
    return events, failures


def command_labels(commands):
    # Library labels; consecutive repeats (turns waiting for an expiry) are counted.
    labels = [entry['request']['behavior'].removeprefix('spell.').removeprefix('action.').replace('_', ' ').capitalize()+' · '+entry['seat'].capitalize() for entry in commands]
    runs = []
    for label in labels:
        if runs and runs[-1][0] == label: runs[-1][1] += 1
        else: runs.append([label, 1])
    return [label if count == 1 else f'{label} ×{count}' for label, count in runs]


def summarize(spell, p, output, result, seed):
    journal = output/'amber/journal'
    counted, behaviors, conditions, evidence = Counter(), Counter(), [], []
    for sequence, lineage, offset, node in facts(journal):
        fact = node['fact']; counted[fact['kind']] += 1
        if fact.get('behavior_id'): behaviors[fact['behavior_id']] += 1
        if fact['kind'] not in {'spell', 'damage', 'heal', 'condition', 'forced_movement', 'life', 'attack', 'saving_throw', 'area_reach', 'spatial_effect_state'}:
            continue
        identity = {'sequence': sequence, 'lineage_uuid': lineage, 'event_uuid': node['uuid'], 'event_offset': offset, 'fact': fact}
        evidence.append(identity)
        if fact['kind'] == 'condition': conditions.append(identity)
    events, failures = lifecycle(spell, p, output, result)
    variants = {'shield_ranged': 'Shield · ranged weapon', 'shield_walk': 'Shield · opportunity attack while walking'}
    spell_id = 'shield' if spell in variants else spell
    return {'id': case_id(spell), 'spell_id': spell_id,
        'label': variants.get(spell, spell.replace('_', ' ').title()),
        'capability': 'Spell composition', 'interaction': FAMILIES[spell], 'seed': seed,
        'descriptor': resource_path(output/'capture-result.json'),
        'perspectives': [{'id': side, 'label': side.capitalize(), 'journal': resource_path(output/side/'journal')} for side in ('amber', 'blue')],
        'qualification': 'Original server follower packets; legal SDK commands for the cast, the walk with the condition on, its rule-based end and a walk afterwards. Fact coverage only, not native rendering or artistic approval.',
        'checks': 2+len(events), 'failures': failures, 'facts': dict(counted), 'behaviors': dict(behaviors),
        'sequence': command_labels(result['commands']),
        'events': evidence, 'conditions': conditions,
        'condition_lifecycle': dict(Counter(row['fact']['event_type'] for row in conditions)),
        'applied_damage': sum(row['fact'].get('applied_damage', 0) for row in evidence if row['fact']['kind'] == 'damage' and row['fact'].get('stage') == 'applied'),
        'lifecycle': events, 'tracked_condition': p['condition'] or p.get('pool'), 'recipient': p['recipient'], 'ending': p['ending'], 'lifecycle_gaps': p['gaps'],
        'native_effects_authored': 'spell.'+spell_id in json.loads((PROJECT/'authoring/native_effects/index.json').read_text()).get('spells', {})}


async def capture(spell, seed, args):
    output = args.output.resolve() / f'{spell}-seed{seed}'
    if output.exists():  # a finished capture is re-qualified, never re-recorded
        if not (output/'capture-result.json').exists(): raise RuntimeError('Incomplete earlier capture: '+str(output))
        return summarize(spell, plan(spell), output, json.loads((output/'capture-result.json').read_text()), seed)
    output.mkdir(parents=True)
    config, p = setup(spell, output, seed)
    config_path = output/'server.json'; config_path.write_text(config.model_dump_json(indent=2)); config_path.chmod(0o600)
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0)); port = sock.getsockname()[1]
    with (output/'server.log').open('wb') as log:
        host = await asyncio.create_subprocess_exec(sys.executable, '-m', 'devtools.player_server_acceptance.test_host',
            '--config', str(config_path), '--stop', str(output/'server.stop'), '--result', str(output/'host-result.json'), '--port', str(port),
            cwd=args.engine, stdout=log, stderr=log)
        try:
            async with asyncio.timeout(90):
                while not (output/'host.ready').exists():
                    if host.returncode is not None: raise RuntimeError('Owned server failed: '+str(output/'server.log'))
                    await asyncio.sleep(.05)
            async with asyncio.timeout(600):
                result = await record(config, 'http://127.0.0.1:'+str(port), output, list(p['steps']), command_limit=160, resolve=Seats().resolve)
        finally:
            (output/'server.stop').touch()
            await asyncio.wait_for(host.wait(), 25)
    return summarize(spell, p, output, result, seed)


def publish_times(args, inventory):
    """Read published Studio times back through the Studio's own index and seek."""
    report = args.output.resolve()/'published-times.json'
    command = [str(args.godot), '--headless', '--path', '.', '--script', 'res://tools/studio_spell_lifecycle_times.gd', '--',
        '--inventory=' + resource_path(args.inventory.resolve()), '--output=' + resource_path(report)]
    completed = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True, timeout=1800)
    print(completed.stdout[-2000:], flush=True)
    times = json.loads(report.read_text())
    for row in inventory['cases']:
        views = times['cases'].get(row['id'], {})
        for event in row.get('lifecycle', []):
            # published_ms is where the Studio places the role (start of a cast or
            # walk, commit of an impact or condition change, arrival of a walk).
            timing = {side: next((entry for entry in view.get('events', []) if entry['event_uuid'] == event['event_uuid'] and entry['role'] == event['role']), {})
                for side, view in views.items()}
            event['published_ms'] = {side: entry.get('published_ms') for side, entry in timing.items()}
            event['studio_interval_ms'] = {side: {key: entry[key] for key in ('start_ms', 'commit_ms', 'end_ms') if key in entry} for side, entry in timing.items()}
            if event['role'] in ('cast', 'impact', 'applied', 'ended'):
                event['studio_rows'] = {side: entry.get('rows', []) for side, entry in timing.items()}
        row['presentation_end_ms'] = {side: view.get('presentation_end_ms') for side, view in views.items()}
        row['after_end_ms'] = {side: view['after_end_ms'] for side, view in views.items() if 'after_end_ms' in view}
        prefix = row['id']+' / '
        row['studio_seek_failures'] = [failure for failure in times['failures'] if failure.startswith(prefix)]
    inventory['studio_seek'] = {'checks': times['checks'], 'failed': times['failed'], 'tool': 'res://tools/studio_spell_lifecycle_times.gd'}
    return times['failed']


async def run(args):
    wanted = args.spells.split(',') if args.spells else list(FAMILIES)
    unknown = set(wanted)-FAMILIES.keys()
    if unknown: raise ValueError('Unknown spells: '+str(sorted(unknown)))
    seeds = [int(value) for value in args.seeds.split(',')]
    inventory = {'scope': 'Spell lifecycles: cast, held condition, walk with it on, rule-based end and a walk afterwards; real server recordings only.',
        'deferred': [], 'cases': [], 'failures': []}
    if args.inventory.exists() and args.resume:
        inventory = json.loads(args.inventory.read_text())
    rows = {row['id']: row for row in inventory['cases']}
    for spell in wanted:
        row = None
        preferred = LIFECYCLE_SEEDS.get(spell, CASE_SEEDS.get(spell, 3))
        for seed in [preferred] + [value for value in seeds if value != preferred]:
            # Saves, hits and reactions are server-rolled; keep the first seed whose real outcome shows the lifecycle.
            row = await capture(spell, seed, args)
            print(json.dumps({'spell': spell, 'seed': seed, 'failures': row['failures'], 'lifecycle': [event['role'] for event in row['lifecycle']]}), flush=True)
            if not row['failures']: break
        rows[row['id']] = row
        order = [case_id(key) for key in FAMILIES]
        inventory['cases'] = [rows[key] for key in order if key in rows]
        inventory['failures'] = [{'spell_id': row['spell_id'], 'case': row['id'], 'reason': failure} for row in inventory['cases'] for failure in row['failures']]
        inventory['native_authoring_missing'] = sorted({row['spell_id'] for row in inventory['cases'] if not row.get('native_effects_authored', True)})
        args.inventory.parent.mkdir(parents=True, exist_ok=True)
        args.inventory.write_text(json.dumps(inventory, indent=2)+'\n')
    failed = 0
    if args.godot:
        failed = publish_times(args, inventory)
        args.inventory.write_text(json.dumps(inventory, indent=2)+'\n')
    return 1 if inventory['failures'] or failed else 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--engine', type=Path, required=True, help='Pinned engine copy (also on PYTHONPATH with its sdk/python/src)')
    parser.add_argument('--output', type=Path, default=PROJECT/'.runtime/studio-spells-20261018')
    parser.add_argument('--inventory', type=Path, default=PROJECT/'generated/studio_spell_case_inventory.json')
    parser.add_argument('--seeds', default='3,2,4,5,6,7,8,9', help='Seeds tried after the reviewed per-spell seed; the first whose recorded outcome qualifies is kept')
    parser.add_argument('--spells', help='Comma-separated subset; default all')
    parser.add_argument('--resume', action='store_true', help='Merge into the existing inventory (finished capture folders are always reused)')
    parser.add_argument('--godot', type=Path, help='Godot executable: add published Studio times and seek checks')
    sys.exit(asyncio.run(run(parser.parse_args())))
