"""A real sorcerer expedition on the existing73x39 Lantern Gallery.

Encounter setup uses public roster/deployment recipes. Every subsequent action
uses the existing Studio SDK recorder; both original faction journals survive.
"""
import argparse
import asyncio
from collections import Counter
import json
from pathlib import Path
import socket
import sys

from dnd.content.characters.premades import FIGHTER_PREMADE_ID, SORCERER_PREMADE_ID
from dnd.core.content.encounters import (EncounterDeploymentSpec, EncounterRecipe,
    EncounterRosterRecipe, PremadeCharacterRosterSource, RosterBehaviorGrant)
from dnd.player.audience import SeatAssignment
from dnd.spells.abjuration import SHIELD_REACTION_DECLARATION
from devtools.player_server_acceptance.fixtures import combat_configuration
from studio_capture import action, record

PROJECT = Path(__file__).resolve().parents[1]
CASTER = 'Expedition sorcerer'
ARCANIST = 'Gallery arcanist'


def setup(output, seed):
    config = combat_configuration('magic_missile', output, seed)
    slots = list(config.recipe.roster_slots)
    hero = slots[0].roster.members[0].model_copy(update={
        'display_name': CASTER,
        'source': PremadeCharacterRosterSource(premade_id=SORCERER_PREMADE_ID),
        'scenario_setup_effects': (RosterBehaviorGrant(behavior_ref=SHIELD_REACTION_DECLARATION.ref),)})
    arcanist = slots[1].roster.members[0].model_copy(update={'display_name': ARCANIST})
    sentries = tuple(slots[1].roster.members[0].model_copy(update={
        'member_id': f'sentry_{i}', 'deployment_role': f'sentry_{i}',
        'display_name': f'Gallery sentry {i}',
        'source': PremadeCharacterRosterSource(premade_id=FIGHTER_PREMADE_ID),
        'scenario_setup_effects': ()}) for i in range(1, 5))
    for i, members in enumerate(((hero,), (arcanist, *sentries))):
        roster = EncounterRosterRecipe.create(**{
            **slots[i].roster.model_dump(exclude={'recipe_digest', 'members'}), 'members': members})
        slots[i] = slots[i].model_copy(update={'roster': roster})
    zones = list(config.recipe.deployment.zones)
    zones[0] = zones[0].model_copy(update={'ordered_slots': ((23, 6),)})
    zones[1] = zones[1].model_copy(update={'ordered_slots': ((30, 6), (34, 6), (38, 10), (42, 10), (43, 6))})
    deployment = EncounterDeploymentSpec.create(**{
        **config.recipe.deployment.model_dump(exclude={'content_digest', 'zones', 'battlefield_id'}),
        'battlefield_id': 'battlefield.lantern_gallery', 'zones': tuple(zones)})
    recipe = EncounterRecipe.create(**{
        **config.recipe.model_dump(exclude={'recipe_digest', 'deployment', 'roster_slots', 'battlefield_id', 'opening_policy'}),
        'battlefield_id': deployment.battlefield_id, 'deployment': deployment,
        'roster_slots': tuple(slots), 'opening_policy': config.recipe.opening_policy})
    config = config.model_copy(update={'game_id': 'studio_gallery_sorcerer', 'recipe': recipe,
        'assignments': tuple(SeatAssignment(slot.roster_slot_id,
            tuple((slot.roster_slot_id, member.member_id) for member in slot.roster.members)) for slot in slots)})
    def hero_action(behavior, **values):
        return action(behavior, actor_name=CASTER, **values)
    steps = [
        hero_action('action.environment.directional_door.open', display_name='Open Door (Lantern gallery door)'),
        hero_action('action.move', position=[26, 6]),
        action('spell.magic_missile', actor_name=ARCANIST, subject_name=CASTER, recipients=[0, 0, 0]),
        hero_action('spell.ray_of_frost', subject_name=ARCANIST),
        hero_action('action.move', position=[30, 5]),
        hero_action('end_turn'),
        hero_action('spell.scorching_ray', subject_name='Gallery sentry 1', recipients=[0, 0, 0]),
        hero_action('action.move', position=[32, 6]),
        hero_action('end_turn'),
        hero_action('spell.acid_splash', subject_name='Gallery sentry 2'),
        hero_action('action.move', position=[36, 7]),
        hero_action('end_turn'),
        hero_action('spell.fireball', position=[42, 10]),
        hero_action('action.move', position=[41, 6]),
        hero_action('end_turn'),
        hero_action('spell.magic_missile', subject_name='Gallery sentry 4', recipients=[0, 0, 0]),
        hero_action('end_turn'),
        hero_action('spell.chill_touch', subject_name='Gallery sentry 4'),
        hero_action('action.move', position=[46, 6]),
        hero_action('end_turn'),
        hero_action('action.move', position=[46, 12]),
        hero_action('action.dash'),
        hero_action('action.move', position=[46, 18]),
        hero_action('end_turn'),
    ]
    return config, steps


def qualify(output, report):
    facts, spells, shield, committed_steps, requested_positions = Counter(), Counter(), [], [], []
    caster = None
    for path in sorted((output/'amber/journal').glob('[0-9]'*16+'.json')):
        packet = json.loads(path.read_bytes())
        if packet['kind'] == 'initialization':
            caster = next(row['actor']['uuid'] for row in packet['initialization']['observations'] if row['actor']['name'] == CASTER)
        for lineage in packet.get('lineages', []):
            for node in lineage['events']:
                fact = node.get('fact')
                if fact is None or node['canceled']:
                    continue
                facts[fact['kind']] += 1
                if fact['kind'] == 'spell':spells[fact.get('behavior_id', '')] += 1
                if fact['kind'] == 'condition' and fact['condition'].get('behavior_id') == 'condition.spell.shield':
                    shield.append({'sequence': packet['cursor']['sequence'], 'event_uuid': node['uuid'], 'fact': fact})
                if fact['kind'] == 'step' and fact['source_entity_uuid'] == caster and fact['committed']:
                    committed_steps.append({'sequence': packet['cursor']['sequence'], 'event_uuid': node['uuid'],
                        'from_position': fact['from_position'], 'to_position': fact['to_position']})
    for command in report['commands']:
        if command['request']['behavior'] == 'action.move':requested_positions.append(command['request']['position'])
    errors = [] if report['ok'] else [report['failure']]
    expected = ('ray_of_frost', 'scorching_ray', 'acid_splash', 'fireball', 'magic_missile', 'chill_touch')
    for spell in expected:
        if not spells['spell.'+spell]:errors.append('Missing real spell fact: '+spell)
    owned_shield = [row for row in shield if row['fact']['target_entity_uuid'] == caster]
    for kind in ('condition_application', 'condition_removal'):
        if not any(row['fact']['event_type'] == kind for row in owned_shield):errors.append('Missing sorcerer Shield '+kind)
    final_position = committed_steps[-1]['to_position'] if committed_steps else None
    if final_position != [46, 18]:errors.append('No final committed sorcerer step reaches the gallery centre')
    return {'id': 'gallery-sorcerer-expedition', 'label': 'Sorcerer expedition · Lantern Gallery',
        'capability': 'Spell composition', 'interaction': 'Large-map expedition',
        'descriptor': 'res://'+(output/'capture-result.json').relative_to(PROJECT).as_posix(),
        'perspectives': [{'id': side, 'label': side.capitalize(), 'journal': 'res://'+(output/side/'journal').relative_to(PROJECT).as_posix()} for side in ('amber', 'blue')],
        'qualification': 'Existing Lantern Gallery battlefield; ordinary premade sorcerer with an explicit scenario Shield reaction grant. Both original SDK follower streams; only legal commands, no manufactured outcomes.',
        'caster_uuid': caster, 'facts': dict(facts), 'spells': dict(spells), 'shield_events': shield,
        'requested_positions': requested_positions, 'committed_steps': committed_steps, 'final_position': final_position,
        'commands': len(report['commands']), 'checks': len(expected)+4, 'failures': errors}


def publish(output, report):
    report['case'] = 'gallery_sorcerer'
    (output/'capture-result.json').write_text(json.dumps(report, indent=2))
    result = qualify(output, report)
    (output/'qualification.json').write_text(json.dumps(result, indent=2))
    if not result['failures']:
        (PROJECT/'generated/studio_gallery_spell_case.json').write_text(json.dumps(result, indent=2)+'\n')
        path = PROJECT/'generated/studio_case_inventory.json'
        inventory = json.loads(path.read_text())
        previous = [row for row in inventory['cases'] if row['name'] == result['id']]
        inventory['cases'] = [row for row in inventory['cases'] if row['name'] != result['id']]
        inventory['cases'].append({'name': result['id'], 'descriptor': result['descriptor'],
            'journal': result['perspectives'][0]['journal'], 'checks': result['checks'],
            'failures': [], 'facts': result['facts'], 'behaviors': result['spells']})
        inventory['checks'] += result['checks']-sum(row.get('checks', 0) for row in previous)
        path.write_text(json.dumps(inventory, indent=2)+'\n')
    return result


async def run(args):
    output = args.output.resolve();output.mkdir(parents=True, exist_ok=False)
    config, steps = setup(output, args.seed)
    path = output/'server.json';path.write_text(config.model_dump_json(indent=2));path.chmod(0o600)
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0));port = sock.getsockname()[1]
    with (output/'server.log').open('wb') as log:
        host = await asyncio.create_subprocess_exec(sys.executable, '-m', 'devtools.player_server_acceptance.test_host',
            '--config', str(path), '--stop', str(output/'server.stop'), '--result', str(output/'host-result.json'),
            '--port', str(port), cwd=args.engine, stdout=log, stderr=log)
        try:
            async with asyncio.timeout(120):
                while not (output/'host.ready').exists():
                    if host.returncode is not None:raise RuntimeError('Owned server failed; inspect '+str(output/'server.log'))
                    await asyncio.sleep(.05)
            async with asyncio.timeout(600):
                report = await record(config, f'http://127.0.0.1:{port}', output, steps, command_limit=180)
        finally:
            (output/'server.stop').touch();await asyncio.wait_for(host.wait(), 30)
    result = publish(output, report)
    print(json.dumps({'commands': result['commands'], 'spells': result['spells'], 'failures': result['failures'], 'output': str(output)}), flush=True)
    return 0 if not result['failures'] else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, default=Path("/home/tommaso/.cache/ndclient/dnd_engine-bedc3d92dc"))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--seed', type=int, default=3)
    raise SystemExit(asyncio.run(run(parser.parse_args())))
