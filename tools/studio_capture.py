"""Finite Studio cases through current server setup and real Python SDK commands.

Run with the engine venv and engine + sdk/python/src on PYTHONPATH. Raw follower
bytes, credentials and command/preview evidence stay under the ignored output.
No engine action application, projected packets or rewritten outcomes are used.
"""
import argparse
import asyncio
from collections import Counter
import json
from pathlib import Path
import socket
import sys
from uuid import uuid4

from dnd_player import (Follower, acknowledge, action_options, all_actions, attach,
    binding_position, binding_subject, choices, connect, follow, next_options,
    preview, preview_positions, receipt, selection_for, status, submit_command, wait_for_cursor)
from dnd.conditions import Poisoned, Prone
from dnd.core.content.encounters import (RosterStartingCondition, RosterStartingDamage, RosterSpellGrant,
    EncounterRecipe, EncounterRosterRecipe, EncounterDeploymentSpec)
from dnd.core.creature_types import DamageType
from dnd.core.content.registration import get_content_declaration
from dnd.core.content.recipes import ContentRecipe
from dnd.player.audience import SeatAssignment
from dnd.player.reduction import reduce_initialization, reduce_operation
from server.protocol import InitializationResponse, PlayerOperation
from dnd.spells.catalog_content import SPELL_CONTENT_IDENTITY_BY_NAME
from devtools.player_server_acceptance.fixtures import combat_configuration
from presentation_scenarios import configuration as movement_configuration

CASES = ('dash', 'dash_comparison', 'dodge', 'disengage', 'hide', 'shove', 'prone', 'rage',
    'action_economy', 'walk', 'walk_diagonal', 'jump', 'oa_walk', 'oa_jump',
    'oa_jump_lethal', 'oa_jump_late_lethal', 'melee', 'ranged', 'magic_missile',
    'hold_person', 'poisoned', 'window', 'window_break', 'elevation',
    'condition_owners', 'condition_suppression', 'invisibility', 'hide_light', 'dying')


def action(behavior, **values):
    return {'behavior': behavior, **values}


def condition_setup(case, output, seed):
    # Existing legal spells provide lifecycle evidence, not a visual migration
    # of these higher-level spells. No runtime condition/state is injected.
    config = combat_configuration('hold_person', output, seed)
    slots = list(config.recipe.roster_slots)
    assignments, zones = [], list(config.recipe.deployment.zones)
    for i, slot in enumerate(slots):
        count = 2 if case == 'condition_owners' and i == 0 else 1
        members = []
        for j in range(count):
            member = slot.roster.members[0]
            level = 1 if case == 'condition_owners' and i == 1 else 15
            original = member.source.recipe
            source = member.source.model_copy(update={'recipe': ContentRecipe.create(ref=original.ref, parameters={'level': level})})
            if case == 'condition_owners':
                names = ['Hold Person' if j == 0 else 'Hold Monster'] if i == 0 else []
            elif case == 'invisibility':
                names = ['Invisibility' if i == 0 else 'See Invisibility']
            else:
                names = ['Mirror Image' if i == 0 else 'Antimagic Field']
            effects = tuple(value for value in member.scenario_setup_effects if value.kind != 'spell_grant')
            if names:
                refs = tuple(get_content_declaration(SPELL_CONTENT_IDENTITY_BY_NAME[name].spell_type).ref for name in names)
                effects += (RosterSpellGrant(spell_refs=refs, caster_level=level),)
            members.append(member.model_copy(update={'member_id': f'unit_{j+1}', 'display_name': f'{slot.roster_slot_id.title()} lifecycle {j+1}', 'deployment_role': f'{slot.roster_slot_id}_{j+1}', 'source': source, 'scenario_setup_effects': effects}))
        roster = EncounterRosterRecipe.create(**{**slot.roster.model_dump(exclude={'recipe_digest','members'}), 'members': tuple(members)})
        slots[i] = slot.model_copy(update={'roster': roster})
        assignments.append(SeatAssignment(slot.roster_slot_id, tuple((slot.roster_slot_id, m.member_id) for m in members)))
        positions = ((3, 7), (3, 8)) if i == 0 else ((9, 7),)
        zones[i] = zones[i].model_copy(update={'ordered_slots': positions[:count]})
    deployment = EncounterDeploymentSpec.create(**{**config.recipe.deployment.model_dump(exclude={'content_digest','zones'}), 'zones': tuple(zones)})
    recipe = EncounterRecipe.create(**{**config.recipe.model_dump(exclude={'recipe_digest','deployment','roster_slots','opening_policy'}), 'deployment': deployment, 'roster_slots': tuple(slots), 'opening_policy': config.recipe.opening_policy})
    config = config.model_copy(update={'recipe': recipe, 'assignments': tuple(assignments)})
    if case == 'condition_owners':
        steps = [action('spell.hold_person', actor_name='Amber lifecycle 1', subject_name='Blue lifecycle 1'),
            action('spell.hold_monster', actor_name='Amber lifecycle 2', subject_name='Blue lifecycle 1'),
            action('action.drop_concentration', actor_name='Amber lifecycle 1'),
            action('action.drop_concentration', actor_name='Amber lifecycle 2')]
    elif case == 'invisibility':
        steps = [action('spell.invisibility', actor_name='Amber lifecycle 1', self_target=True),
            action('action.move', actor_name='Amber lifecycle 1', position=[4, 7]),
            action('spell.see_invisibility', actor_name='Blue lifecycle 1', self_target=True),
            action('action.move', actor_name='Amber lifecycle 1', position=[5, 7]),
            action('action.drop_concentration', actor_name='Amber lifecycle 1')]
    else:
        steps = [action('spell.mirror_image', actor_name='Amber lifecycle 1', self_target=True),
            action('spell.antimagic_field', actor_name='Blue lifecycle 1', self_target=True),
            action('action.move', actor_name='Blue lifecycle 1', position=[5, 7]),
            action('action.move', actor_name='Blue lifecycle 1', position=[6, 7]),
            action('action.drop_concentration', actor_name='Blue lifecycle 1')]
    return config, steps


def setup(case, output, seed):
    if case in ('condition_owners', 'condition_suppression', 'invisibility'):
        return condition_setup(case, output, seed)
    if case in ('magic_missile', 'hold_person', 'poisoned', 'ranged'):
        config = combat_configuration('hold_person' if case == 'poisoned' else case, output, seed)
    else:
        base = case if case in ('walk', 'walk_diagonal', 'jump', 'oa_walk', 'oa_jump', 'oa_jump_lethal', 'oa_jump_late_lethal') else 'walk_fast' if case == 'rage' else 'walk' if case.startswith('window') or case in ('hide','hide_light','dash_comparison') else 'attack'
        config, move = movement_configuration(base, output, seed)
    if case.startswith('window') or case in ('hide','hide_light','elevation'):
        battlefield = 'battlefield.window_proving_ground' if case.startswith('window') else 'battlefield.elevation_proving_ground' if case=='elevation' else 'battlefield.open_floor_dark'
        deployment = config.recipe.deployment
        zones = list(deployment.zones)
        if case == 'window_break':
            zones[0] = zones[0].model_copy(update={'ordered_slots': ((4, 8),)})
        if case == 'elevation':
            zones[0] = zones[0].model_copy(update={'ordered_slots': ((5, 4),)})
            zones[1] = zones[1].model_copy(update={'ordered_slots': ((12, 8),)})
        deployment = EncounterDeploymentSpec.create(**{**deployment.model_dump(exclude={'content_digest','zones'}), 'battlefield_id': battlefield, 'zones': tuple(zones)})
        config = config.model_copy(update={'recipe': config.recipe.model_copy(update={'battlefield_id': battlefield, 'deployment': deployment})})
    if case in ('poisoned', 'prone'):
        slots = list(config.recipe.roster_slots)
        slot_index = 1 if case=='prone' else 0
        members = list(slots[slot_index].roster.members)
        effects = list(members[0].scenario_setup_effects)
        effects.append(RosterStartingCondition(condition_ref=get_content_declaration(Poisoned if case == 'poisoned' else Prone).ref))
        if case == 'poisoned':
            spell = SPELL_CONTENT_IDENTITY_BY_NAME['Lesser Restoration'].spell_type
            effects.append(RosterSpellGrant(spell_refs=(get_content_declaration(spell).ref,), caster_level=7))
        members[0] = members[0].model_copy(update={'scenario_setup_effects': tuple(effects)})
        roster = EncounterRosterRecipe.create(**{**slots[slot_index].roster.model_dump(exclude={'recipe_digest','members'}), 'members': tuple(members)})
        slots[slot_index] = slots[slot_index].model_copy(update={'roster': roster})
        config = config.model_copy(update={'recipe': config.recipe.model_copy(update={'roster_slots': tuple(slots)})})
    if case == 'dying':
        # Existing premade fighters use the engine's death-save lifecycle.
        # Setup damage is an actual engine operation before initiative, not an
        # injected life state. This leaves Blue alive at 4/44 HP.
        slots = list(config.recipe.roster_slots)
        members = list(slots[1].roster.members)
        members[0] = members[0].model_copy(update={'scenario_setup_effects':
            (*members[0].scenario_setup_effects, RosterStartingDamage(amount=40, damage_type=DamageType.FORCE))})
        roster = EncounterRosterRecipe.create(**{**slots[1].roster.model_dump(exclude={'recipe_digest','members'}), 'members': tuple(members)})
        slots[1] = slots[1].model_copy(update={'roster': roster})
        config = config.model_copy(update={'recipe': config.recipe.model_copy(update={'roster_slots': tuple(slots)})})
    # Typed factories authenticate changed recipe data; model_copy does not.
    recipe = config.recipe
    config = config.model_copy(update={'recipe': EncounterRecipe.create(**{
        **recipe.model_dump(exclude={'recipe_digest','deployment','roster_slots','opening_policy'}),
        'deployment': recipe.deployment, 'roster_slots': recipe.roster_slots, 'opening_policy': recipe.opening_policy})})
    end = action('end_turn')
    steps = {
        # Same actor, equal six-tile routes. The first exhausts ordinary
        # movement; only the actual Dash command makes the return possible.
        'dash_comparison': [action('action.move', position=[10, 6]),
            action('action.move', expect_unavailable=True), action('action.dash'),
            action('action.move', position=[4, 6]), end],
        'dash': [action('action.dash'), action('action.move', position=[3, 6]), end, end],
        'dodge': [action('action.dodge'), end, action('action.attack', weapon_slot='MELEE_MAIN'), end],
        'disengage': [action('action.disengage'), action('action.move', position=[3, 6]), end, end],
        'hide': [action('action.item.torch.extinguish'), action('action.hide'), action('action.move', position=[3, 6]), end, end, action('action.attack', weapon_slot='RANGED_MAIN')],
        'hide_light': [
            action('action.item.torch.extinguish', actor_name='Amber presentation actor'),
            action('action.hide', actor_name='Amber presentation actor', light_probe='hidden', expected_light=1, expected_hidden=True),
            # Exercise runtime source activation, not only the setup's on-grant ignition.
            action('action.item.torch.extinguish', actor_name='Blue presentation actor'),
            action('action.item.torch.ignite', actor_name='Blue presentation actor'),
            action('action.move', actor_name='Blue presentation actor', position=[10, 6], light_probe='dim', expected_light=2, expected_hidden=True),
            end,
            action('action.move', actor_name='Blue presentation actor', position=[7, 6], light_probe='bright', expected_light=3, expected_hidden=True),
            action('action.move', actor_name='Blue presentation actor', position=[6, 6], light_probe='very_bright', expected_light=4, expected_hidden=False)],
        'shove': [action('action.shove'), end, end],
        # The maintained engine auto-stands at turn start; no invented Stand Up action.
        'prone': [end, action('action.move', position=[6, 6])],
        'rage': [action('action.class.barbarian.frenzy'), action('action.move', position=[7, 6]), end, end],
        'action_economy': [action('action.attack', weapon_slot='MELEE_MAIN'), action('action.feature.extra_attack', weapon_slot='MELEE_MAIN'), action('action.class.fighter.action_surge'), action('action.attack', weapon_slot='MELEE_MAIN'), action('action.feature.extra_attack', weapon_slot='MELEE_MAIN'), action('action.attack', expect_unavailable=True)],
        'magic_missile': [action('spell.magic_missile', recipients=[0, 1, 0])],
        'hold_person': [action('spell.hold_person'), end, end, action('action.drop_concentration')],
        'poisoned': [action('action.move', position=[4, 7]), action('spell.lesser_restoration', self_target=True)],
        'melee': [action('action.attack', weapon_slot='MELEE_MAIN')],
        'dying': [action('action.attack', weapon_slot='MELEE_MAIN', life_probe=True)] + [action('end_turn', stop_on_death=True) for _ in range(12)],
        'ranged': [action('action.attack', weapon_slot='RANGED_MAIN')],
        'window': [action('action.traverse_connector', position=[5, 6]), action('action.traverse_connector', position=[4, 6])],
        'window_break': [action('action.traverse_connector', expect_unavailable=True), action('action.attack', subject_name='Window grille G8', weapon_slot='MELEE_MAIN'), action('action.feature.extra_attack', subject_name='Window grille G8', weapon_slot='MELEE_MAIN'), action('action.traverse_connector', position=[5, 8])],
        'elevation': [action('action.move', position=[8, 4])],
    }
    if case not in steps:
        steps[case] = [action(move['behavior'], position=list(move['target']))]
    return config, steps[case]


def summarize(journal):
    facts, behaviors, outcomes = Counter(), Counter(), Counter()
    conditions, recipients, steps = [], [], []
    for path in sorted(journal.glob('[0-9]' * 16 + '.json')):
        packet = json.loads(path.read_bytes())
        for lineage in packet.get('lineages', []):
            for node in lineage['events']:
                fact = node.get('fact')
                if fact is None or node['canceled']:
                    continue
                kind = fact['kind']; facts[kind] += 1
                if fact.get('behavior_id'): behaviors[fact['behavior_id']] += 1
                if kind == 'attack': outcomes[fact['attack_outcome']] += 1
                if kind == 'condition': conditions.append(fact)
                if kind == 'step': steps.append(fact)
                if kind == 'spell': recipients.append(fact)
    return {'facts': dict(facts), 'behaviors': dict(behaviors), 'attack_outcomes': dict(outcomes),
        'conditions': conditions, 'steps': steps, 'spells': recipients}


def qualify_light(output, commands):
    """Read original public after-values; never construct an engine outcome."""
    probes, failures, checks = [], [], 0
    expected = [row for row in commands if 'probe_cursors' in row]
    samples = {}
    for side in ('amber', 'blue'):
        boundaries = {row['probe_cursors'][side]['sequence']: row for row in expected}
        state = None
        for path in sorted((output / side / 'journal').glob('[0-9]' * 16 + '.json')):
            raw = path.read_bytes()
            if state is None:
                packet = InitializationResponse.model_validate_json(raw)
                state = reduce_initialization(packet.initialization, content_additions=packet.content_additions)
            else:
                packet = PlayerOperation.model_validate_json(raw)
                state = reduce_operation(state, packet)
            sequence = packet.cursor.sequence
            if sequence not in boundaries:
                continue
            actor = next((a for a in state.actors.values() if a.name == 'Amber presentation actor'), None)
            light_owner = next((a for a in state.actors.values() if a.name == 'Blue presentation actor'), None)
            position = (4, 6)
            tile = state.tiles.get(position)
            senses = state.senses
            hidden = [] if actor is None else [str(c.condition_uuid) for c in actor.conditions if c.behavior_id == 'condition.hidden']
            items = () if light_owner is None else light_owner.controlled_items or ()
            torches = [item.model_dump(mode='json', include={'item_uuid','item_id','is_lit','very_bright_radius_feet','bright_radius_feet','dim_radius_feet'}) for item in items if item.is_lit is not None]
            contact = None if senses is None or actor is None else senses.entities.get(actor.uuid)
            samples[side, sequence] = {'cursor': packet.cursor.model_dump(mode='json'),
                'actor_uuid': None if actor is None else str(actor.uuid), 'sampled_tile': position,
                'actor_position': None if actor is None else actor.last_visual_position,
                'world_resolved_light': None if tile is None else int(tile.resolved_light),
                'tile_currently_visible': senses is not None and position in senses.visible,
                'light_sources': [] if senses is None else [source.model_dump(mode='json')
                    for source in senses.light_sources.values()],
                'observer_effective_light': None if senses is None or position not in senses.effective_light_levels else int(senses.effective_light_levels[position]),
                'sense_modes': [] if senses is None else [str(mode) for mode in senses.sense_modes],
                'hidden_condition_uuids': hidden,
                'observer_contact_position': None if contact is None else contact.position,
                'light_owner_uuid': None if light_owner is None else str(light_owner.uuid),
                'light_owner_position': None if light_owner is None else light_owner.last_visual_position,
                'torches': torches}
    retained_hidden = None
    for row in expected:
        request = row['request']
        views = {side: samples[side, cursor['sequence']] for side, cursor in row['probe_cursors'].items()}
        probe = {'label': request['light_probe'], 'command_step': row['step'], 'request': request,
            'command': row['command'], 'receipt': row['receipt'], 'views': views}
        probes.append(probe)
        own = views['amber']
        source = views['blue']
        if 'position' in request:
            checks += 1
            if source['light_owner_position'] != tuple(request['position']):
                failures.append(request['light_probe'] + ': actual light owner reached requested position')
        for ok, description in [
            (not own['tile_currently_visible'] or own['world_resolved_light'] == request['expected_light'], 'currently visible objective tile level matches requested zone'),
            (not source['tile_currently_visible'] or source['world_resolved_light'] == request['expected_light'], 'other faction agrees on currently disclosed objective tile level'),
            (any(t['is_lit'] and [t['very_bright_radius_feet'],t['bright_radius_feet'],t['dim_radius_feet']] == [10,20,20] for t in source['torches']), 'actual lit source has the expected authored radii'),
            (bool(own['hidden_condition_uuids']) == request['expected_hidden'], 'Hidden after-value matches zone rule'),
            (own['actor_position'] == (4, 6), 'Hidden actor remains at the requested cell')]:
            checks += 1
            if not ok: failures.append(request['light_probe'] + ': ' + description)
        if request['light_probe'] != 'hidden':
            for side, view in views.items():
                checks += 1
                if not view['tile_currently_visible']:
                    failures.append(request['light_probe'] + ': ' + side + ' must actually see the sampled cell')
                checks += 1
                sources = [item for item in view['light_sources'] if item['appearance'] == 'torch'
                    and item['actor_anchored'] and tuple(item['position']) == source['light_owner_position']]
                if not sources or not any(item['affected_tiles'].get('4,6') == request['expected_light'] for item in sources):
                    failures.append(request['light_probe'] + ': ' + side + ' requires the actual optical source and contribution')
            checks += 1
            private_ids = {item['item_uuid'] for item in source['torches']}
            if any(item['source_uuid'] in private_ids or item['anchor_item_uuid'] in private_ids
                    for item in own['light_sources']):
                failures.append(request['light_probe'] + ': optical source must not expose the private carried item identity')
        probe['objective_timing'] = {side: 'current_visible' if view['tile_currently_visible'] else 'remembered_not_current'
            for side, view in views.items()}
        if request['expected_hidden'] and own['hidden_condition_uuids']:
            if retained_hidden is None: retained_hidden = own['hidden_condition_uuids'][0]
            checks += 1
            if own['hidden_condition_uuids'] != [retained_hidden]: failures.append(request['light_probe'] + ': same Hidden owner must persist')
    checks += 1
    if [p['label'] for p in probes] != ['hidden', 'dim', 'bright', 'very_bright']:
        failures.append('All four requested boundaries were captured')
    checks += 1
    if not any(row['seat'] == 'blue' and row['request']['behavior'] == 'action.item.torch.ignite' and row.get('receipt',{}).get('kind') == 'committed' for row in commands):
        failures.append('Blue torch activation must be a real committed ignite command')
    # Application and removal must be real facts, not just a guessed final state.
    condition_events = summarize(output / 'amber' / 'journal')['conditions']
    matched = [fact for fact in condition_events if str(fact['condition']['condition_uuid']) == retained_hidden]
    for kind in ('condition_application', 'condition_removal'):
        checks += 1
        if not any(fact['event_type'] == kind for fact in matched): failures.append('Missing actual ' + kind + ' for the same Hidden UUID')
    return {'checks': checks, 'failures': failures, 'hidden_condition_uuid': retained_hidden,
        'probes': probes, 'condition_events': matched,
        'provenance': 'Independent current Python player reducer over unchanged original public follower packets; per-seat cursor after actual committed commands. Objective tile and observer-effective light are reported separately.'}


def qualify_dying(output):
    checks, failures, views = 0, [], {}
    for side in ('amber', 'blue'):
        state, victim, samples, life, damage = None, None, [], [], []
        for path in sorted((output / side / 'journal').glob('[0-9]' * 16 + '.json')):
            if state is None:
                packet = InitializationResponse.model_validate_json(path.read_bytes())
                state = reduce_initialization(packet.initialization, content_additions=packet.content_additions)
                victim = next(a.uuid for a in state.actors.values() if a.name == 'Blue presentation actor')
                checks += 1
                if state.actors[victim].life_state.value != 'alive' or (side == 'blue' and state.actors[victim].normal_hp != 4):
                    failures.append(side + ': initialization must be alive; controlled Blue must have actual 4 HP')
            else:
                packet = PlayerOperation.model_validate_json(path.read_bytes())
                state = reduce_operation(state, packet)
                for lineage in packet.model_dump(mode='json')['lineages']:
                    for node in lineage['events']:
                        fact = node['fact']
                        if fact is None or node['canceled']: continue
                        if fact['kind'] == 'life' and fact['entity_uuid'] == str(victim):
                            life.append({'sequence': packet.cursor.sequence, 'event_uuid': node['uuid'], 'fact': fact})
                        if fact['kind'] == 'damage' and fact['stage'] == 'applied' and fact['target_entity_uuid'] == str(victim):
                            damage.append({'sequence': packet.cursor.sequence, 'event_uuid': node['uuid'], 'fact': fact})
            actor = state.actors[victim]
            samples.append({'sequence': packet.cursor.sequence, 'actor_uuid': str(victim), 'normal_hp': actor.normal_hp, 'life_state': actor.life_state.value})
        states = [row['fact']['new_state'] for row in life]
        checks += 3
        if states != ['dying', 'dead']: failures.append(side + ': requires actual Dying then Dead facts exactly')
        if not damage or not any(row['applied_damage'] > 0 for row in (d['fact'] for d in damage)):
            failures.append(side + ': requires positive committed damage')
        if samples[-1]['life_state'] != 'dead': failures.append(side + ': final canonical state must be Dead')
        views[side] = {'samples': samples, 'life_events': life, 'damage_events': damage}
    return {'checks': checks, 'failures': failures, 'views': views,
        'provenance': 'Original public follower packets, independent current Python reduction; existing setup damage and actual offered attack commands only.'}


async def record(config, url, output, steps, *, command_limit=40, resolve=None):
    # resolve(step, seat, actor) may complete a request from the seat's own
    # received journal (e.g. a relative move) or return None to skip it.
    seats, trace = [], []
    failure = None
    try:
        for credential in config.credentials:
            connection = await connect(url, credential.token)
            while connection.bootstrap['status']['published_cursor'] is None:
                await connection.http.aclose(); await asyncio.sleep(.02)
                connection = await connect(url, credential.token)
            await attach(connection, {'acquisition_id': str(uuid4()), 'expected_attachment_epoch': connection.bootstrap['status']['attachment_epoch']})
            journal = output / credential.seat_id / 'journal'; journal.mkdir(parents=True)
            seat = {'id': credential.seat_id, 'connection': connection, 'journal': journal, 'controlled': set(), 'names': {}}
            async def consume(packet, raw, owner=seat):
                path = owner['journal'] / f"{packet['cursor']['sequence']:016}.json"
                if path.exists() and path.read_bytes() != raw: raise RuntimeError('Replay changed original packet bytes')
                path.write_bytes(raw)
                if packet['kind'] == 'initialization':
                    owner['controlled'] = set(packet['initialization']['audience']['controlled'])
                    owner['names'] = {row['actor']['uuid']: row['actor']['name'] for row in packet['initialization']['observations']}
                    owner['items'] = {row['actor']['uuid']: row['actor'].get('controlled_items') or [] for row in packet['initialization']['observations']}
            seat['follower'] = Follower(connection, consume)
            seat['task'] = asyncio.create_task(follow(seat['follower']))
            seats.append(seat)
        for ordinal, step in enumerate(steps):
            active = None
            async with asyncio.timeout(30):
                while active is None:
                    for seat in seats:
                        now = await status(seat['connection'])
                        if now['published_cursor'] is not None: await wait_for_cursor(seat['follower'], now['published_cursor'])
                        actor = now['boundary']['input_actor_uuid']
                        if actor is not None and actor in seat['controlled']:
                            active = seat, now; break
                    if active is None: await asyncio.sleep(.01)
            seat, now = active; connection = seat['connection']; actor = now['boundary']['input_actor_uuid']
            if ordinal >= command_limit: raise RuntimeError('Named actor was not reached within bounded legal turns')
            if step.get('actor_name') is not None and seat['names'].get(actor) != step['actor_name']:
                # Advance through the real initiative order, recording every end.
                steps.insert(ordinal, action('end_turn', waiting_for_actor=step['actor_name']))
                step = steps[ordinal]
            if resolve is not None:
                step = resolve(step, seat, actor)
                if step is None: continue
                steps[ordinal] = step
            await acknowledge(connection, seat['follower'].consumed)
            revision = now['boundary']['state_revision']
            row_evidence = {'step': ordinal, 'request': step, 'seat': seat['id'], 'previews': []}
            intent = {'kind': 'end_turn'}
            if step['behavior'] == 'equip':
                items = [item for item in seat['items'].get(actor, []) if item['item_id'] == step['item_id']]
                if len(items) != 1: raise RuntimeError('Expected one observed setup item for equip')
                intent = {'kind': 'equip', 'item': {'item_uuid': items[0]['item_uuid'], 'slot': step['slot']}}
            elif step['behavior'] != 'end_turn':
                discovered = (await choices(connection, {'actor_uuid': actor, 'state_revision': revision, 'force_attack': False, 'correlation_id': str(uuid4())}))['choices']
                (output / f'choices-{ordinal:02}.json').write_text(json.dumps(discovered))
                offered = [row for row in all_actions(discovered) if row['behavior_id'] == step['behavior'] and row['can_afford'] and action_options(discovered, row)
                    and all(row.get(key) == value for key, value in step.items() if key in ('weapon_slot', 'display_name'))
                    and ('position' not in step or step['behavior']!='action.traverse_connector' or row['connector_traversal']['command']['destination_position']==step['position'])]
                if step.get('expect_unavailable'):
                    row_evidence['unavailable'] = not offered; trace.append(row_evidence)
                    if offered: raise RuntimeError('Expected exhausted action is still offered')
                    continue
                if not offered: raise RuntimeError('Current legal choices do not offer '+step['behavior'])
                row = min(offered, key=lambda value: (value.get('cast_at_level') or 0, value['discovery_index']))
                targets = action_options(discovered, row)
                if 'position' in step and step['behavior']!='action.traverse_connector': targets = [target for target in targets if binding_position(discovered, target) == step['position']]
                if step.get('self_target'): targets = [target for target in targets if (binding_subject(discovered, target) or {}).get('uuid') == actor or target['kind']=='self']
                if 'subject_kind' in step: targets = [target for target in targets if (binding_subject(discovered, target) or {}).get('kind') == step['subject_kind']]
                if 'subject_name' in step: targets = [target for target in targets if (binding_subject(discovered, target) or {}).get('name') == step['subject_name']]
                if not targets: raise RuntimeError('Current legal action does not offer requested target: '+str(step))
                target = targets[0]
                if 'affected_position' in step:
                    target = None
                    for candidate in targets:
                        aimed = (await preview(connection, {'actor_uuid': actor, 'state_revision': revision, 'discovery_generation': discovered['discovery_generation'], 'correlation_id': str(uuid4()), 'selection': selection_for(row, [candidate], prefer_safe=False)}))['preview']
                        row_evidence['previews'].append(aimed)
                        if aimed['can_confirm'] and step['affected_position'] in preview_positions(aimed, affected=True):
                            target = candidate; break
                    if target is None: raise RuntimeError('No offered aim affects requested public position')
                first_uuid = (binding_subject(discovered, target) or {}).get('uuid')
                other_uuid = next(((binding_subject(discovered, item) or {}).get('uuid') for item in targets if (binding_subject(discovered, item) or {}).get('uuid') not in (None, first_uuid)), first_uuid)
                sequence = [first_uuid, other_uuid]
                selected = selection_for(row, [target], prefer_safe=False)
                for _ in range(16):
                    result = (await preview(connection, {'actor_uuid': actor, 'state_revision': revision, 'discovery_generation': discovered['discovery_generation'], 'correlation_id': str(uuid4()), 'selection': selected}))['preview']
                    row_evidence['previews'].append(result)
                    wanted_count = len(step.get('recipients', []))
                    if result['can_confirm'] and len(selected['target_indices']) >= wanted_count: break
                    options = next_options(result)
                    if not options: raise RuntimeError('Native preview has no completion: '+str(result))
                    offset = len(selected['target_indices'])
                    wanted_uuid = sequence[step['recipients'][offset]] if offset < wanted_count else first_uuid
                    next_target = next((item for item in options if (binding_subject(result, item) or {}).get('uuid') == wanted_uuid), options[0])
                    selected['target_indices'].append(next_target['index'])
                else: raise RuntimeError('Native selection did not complete in16 steps')
                row_evidence['selected_action'] = row
                intent = {'kind': 'execute_selection', 'discovery_generation': discovered['discovery_generation'], 'selection': selected}
            command = {'command_number': now['next_command_number'], 'actor_uuid': actor, 'state_revision': revision, 'intent': intent}
            result = await submit_command(connection, command)
            while result['receipt']['kind'] == 'pending':
                await asyncio.sleep(.01); result = await receipt(connection, command['command_number'])
            row_evidence.update(command=command, receipt=result['receipt']); trace.append(row_evidence)
            (output / 'commands.json').write_text(json.dumps(trace, indent=2))
            if result['receipt']['kind'] != 'committed': raise RuntimeError('Native command rejected: '+str(result))
            await wait_for_cursor(seat['follower'], result['receipt']['cursor'])
            if step.get('stop_on_death'):
                # Stop on an observed server outcome, never a presumed number
                # of death saves. Both original followers retain that prefix.
                for observer in seats:
                    boundary = await status(observer['connection'])
                    await wait_for_cursor(observer['follower'], boundary['published_cursor'])
                victim = next(identity for identity, name in seats[0]['names'].items() if name == 'Blue presentation actor')
                died = any(node.get('fact') is not None and node['fact']['kind'] == 'life'
                    and node['fact']['entity_uuid'] == victim and node['fact']['new_state'] == 'dead' and not node['canceled']
                    for path in sorted(seats[0]['journal'].glob('[0-9]' * 16 + '.json'))
                    for lineage in json.loads(path.read_bytes()).get('lineages', []) for node in lineage['events'])
                if died: break
            if 'light_probe' in step:
                # Each public seat has its own cursor; retain the actual boundary
                # instead of assuming sequence numbers are shared by audiences.
                row_evidence['probe_cursors'] = {}
                for observer in seats:
                    boundary = await status(observer['connection'])
                    await wait_for_cursor(observer['follower'], boundary['published_cursor'])
                    row_evidence['probe_cursors'][observer['id']] = boundary['published_cursor']
                (output / 'commands.json').write_text(json.dumps(trace, indent=2))
    except Exception as error:
        failure = str(error)
    finally:
        for seat in seats:
            current = await status(seat['connection'])
            if current['published_cursor'] is not None: await wait_for_cursor(seat['follower'], current['published_cursor'])
            seat['task'].cancel()
        await asyncio.gather(*(seat['task'] for seat in seats), return_exceptions=True)
        for seat in seats: await seat['connection'].http.aclose()
    report = {'ok': failure is None, 'failure': failure, 'commands': trace,
        'audiences': {seat['id']: summarize(seat['journal']) for seat in seats},
        'source': 'Current native server setup; public SDK choices/preview/commands; original follower bytes, no outcome rewriting.'}
    if any('light_probe' in step for step in steps):
        report['light_qualification'] = qualify_light(output, trace)
        if report['light_qualification']['failures']:
            report['ok'] = False
            report['failure'] = failure or 'Hide/light qualification failed; see light_qualification'
    if any('life_probe' in step for step in steps):
        report['life_qualification'] = qualify_dying(output)
        if report['life_qualification']['failures']:
            report['ok'] = False
            report['failure'] = failure or 'Dying qualification failed; see life_qualification'
    (output / 'capture-result.json').write_text(json.dumps(report, indent=2))
    return report


async def run(args):
    output = args.output.resolve(); output.mkdir(parents=True, exist_ok=False)
    config, steps = setup(args.case, output, args.seed)
    config_path = output / 'server.json'; config_path.write_text(config.model_dump_json(indent=2)); config_path.chmod(0o600)
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0)); port = sock.getsockname()[1]
    with (output/'server.log').open('wb') as log:
        host = await asyncio.create_subprocess_exec(sys.executable, '-m', 'devtools.player_server_acceptance.test_host', '--config', str(config_path), '--stop', str(output/'server.stop'), '--result', str(output/'host-result.json'), '--port', str(port), cwd=args.engine, stdout=log, stderr=log)
        try:
            async with asyncio.timeout(90):
                while not (output/'host.ready').exists():
                    if host.returncode is not None: raise RuntimeError('Owned host failed; inspect server.log')
                    await asyncio.sleep(.05)
            async with asyncio.timeout(180): report = await record(config, f'http://127.0.0.1:{port}', output, steps)
        finally:
            (output/'server.stop').touch(); await asyncio.wait_for(host.wait(), 25)
    summary = {'case': args.case, 'seed': args.seed, 'ok': report['ok'], 'failure': report['failure'], 'output': str(output),
        'observations': {side: {key: value for key, value in data.items() if key in ('facts', 'behaviors', 'attack_outcomes')} for side, data in report['audiences'].items()}}
    print(json.dumps(summary), flush=True)
    return 0 if report['ok'] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=CASES, required=True); parser.add_argument('--seed', type=int, default=3)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--engine', type=Path, default=Path("/home/tommaso/.cache/ndclient/dnd_engine-9f81d5267"))
    sys.exit(asyncio.run(run(parser.parse_args())))


if __name__ == '__main__': main()
