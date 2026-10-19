"""Record an actual Expedition-seat walk through the authored Lantern Gallery.

Only public SDK discovery, preview and commands drive the encounter. The journal
contains original response bytes; the current engine player reducer is read-only
decision input. The distant curator is deliberately not an attack target.
"""
import argparse
import asyncio
import json
from pathlib import Path
import socket
import sys
from time import monotonic
from uuid import UUID, uuid4

from dnd_player import (Follower, acknowledge, attach, choices, connect, follow,
    preview, receipt, status, submit_command, wait_for_cursor, action_options,
    all_actions, binding_position, binding_subject, next_options)
from dnd.player.facts import PlayerState
from dnd.player.reduction import reduce_initialization, reduce_operation
from server.protocol import InitializationResponse, PlayerOperation
from devtools.player_server_acceptance.fixtures import configuration


ROUTE = (
    ('Crypt passage', 'open'), ('move', (10, 6)),
    ('Burial hall door', 'open'), ('move', (13, 6)),
    ('Gallery passage', 'open'), ('move', (22, 6)),
    ('Lantern gallery door', 'open'),
    ('gallery_entry', (26, 6)), ('gallery_nave', (46, 6)),
    ('gallery_centre', (46, 20)), ('gallery_far', (68, 20)),
)


def rows(discovered):
    return [row for row in all_actions(discovered)
        if row['can_afford'] and action_options(discovered, row)]


def move_toward(discovered, available, current, destinations):
    if not destinations:
        return None
    distance = lambda p: min(abs(p[0]-d[0])+abs(p[1]-d[1]) for d in destinations)
    offered = [(row, target) for row in available if row['behavior_id'] == 'action.move'
        for target in action_options(discovered, row)
        if binding_position(discovered, target) is not None
        and distance(binding_position(discovered, target)) < distance(current)]
    return min(offered, key=lambda pair: (distance(binding_position(discovered, pair[1])), pair[1].get('path_cost') or 0), default=None)


def select(state, actor, discovered, stage, leader):
    available = rows(discovered)
    current = state.actors[UUID(actor)].last_visual_position
    enemies = {str(key) for key, value in state.actors.items()
        if key not in state.viewing_audience.controlled and value.present
        and value.normal_hp > 0 and value.name != 'Gallery Curator'}
    attacks = [(row, target) for row in available
        if row['performs_attack'] or row['behavior_id'] == 'spell.magic_missile'
        for target in action_options(discovered, row)
        if (binding_subject(discovered, target) or {}).get('uuid') in enemies]
    if attacks:
        return min(attacks, key=lambda pair: (pair[0]['behavior_id'] != 'spell.magic_missile',
            pair[0]['behavior_id'] != 'spell.fire_bolt', pair[1].get('distance') or 0)), stage
    if actor != leader:
        # The other original hero stays with the expedition, using offered paths.
        destination = state.actors[UUID(leader)].last_visual_position
        selected = move_toward(discovered, available, current, (destination,))
        return selected, stage
    name, goal = ROUTE[stage]
    if goal == 'open':
        identity = next((str(key) for key, value in state.objects.items() if value.item.name == name), None)
        option = next((row for row in discovered['world_interactions']
            if row['subject_uuid'] == identity and row['behavior_id'].endswith('.open')), None)
        if option is None:
            raise RuntimeError(f'No disclosed opening interaction for route door {name}')
        for row in available:
            if row['behavior_id'] != option['behavior_id'] or row['template_name'] != option['template_name']:
                continue
            target = next((target for target in action_options(discovered, row)
                if row.get('source_item_uuid') == identity
                or (binding_subject(discovered, target) or {}).get('uuid') == identity), None)
            if target is not None:
                return (row, target), stage + 1
        selected = move_toward(discovered, available, current, option['contact_positions'])
    else:
        selected = move_toward(discovered, available, current, (goal,))
    if selected is not None:
        return selected, stage
    dash = next((row for row in available if row['behavior_id'] == 'action.dash'), None)
    return ((dash, action_options(discovered, dash)[0]) if dash else None), stage


async def record(url, token, output):
    journal = output / 'journal'
    journal.mkdir()
    connection = await connect(url, token)
    while connection.bootstrap['status']['published_cursor'] is None:
        await connection.http.aclose()
        await asyncio.sleep(.05)
        connection = await connect(url, token)
    await attach(connection, {'acquisition_id': str(uuid4()),
        'expected_attachment_epoch': connection.bootstrap['status']['attachment_epoch']})
    state: PlayerState | None = None
    records = byte_count = 0

    async def consume(packet, raw):
        nonlocal state, records, byte_count
        byte_count += len(raw)
        if byte_count > 512 * 1024 * 1024:
            raise RuntimeError('Actual recording exceeded 512 MiB quota')
        path = journal / f"{packet['cursor']['sequence']:016}.json"
        if path.exists() and path.read_bytes() != raw:
            raise RuntimeError('Server replay changed bytes at a committed cursor')
        path.write_bytes(raw)
        if packet['kind'] == 'initialization':
            parsed = InitializationResponse.model_validate_json(raw)
            state = reduce_initialization(parsed.initialization, content_additions=parsed.content_additions)
        else:
            assert state is not None
            state = reduce_operation(state, PlayerOperation.model_validate_json(raw))
        records += 1

    follower = Follower(connection, consume)
    following = asyncio.create_task(follow(follower))
    stage = 0
    leader = None
    trace, milestones = [], []
    started = monotonic()
    try:
        async with asyncio.timeout(1200):
            while stage < len(ROUTE):
                if following.done():
                    await following
                    raise RuntimeError('Encounter ended before the gallery route completed')
                now = await status(connection)
                if now['published_cursor'] is not None:
                    await wait_for_cursor(follower, now['published_cursor'])
                actor = now['boundary']['input_actor_uuid']
                if actor is None:
                    await asyncio.sleep(.02)
                    continue
                assert state is not None
                if leader is None:
                    leader = next(str(key) for key in state.viewing_audience.controlled
                        if state.actors[key].name == 'Shield Fighter')
                name, goal = ROUTE[stage]
                current = state.actors[UUID(leader)].last_visual_position
                if goal != 'open' and tuple(current) == goal:
                    milestones.append({'name': name, 'position': list(current), 'cursor': follower.consumed,
                        'commands': len(trace), 'disclosed_tiles': len(state.tiles),
                        'disclosed_objects': len(state.objects), 'seconds': monotonic() - started})
                    (output / 'milestones.json').write_text(json.dumps(milestones, indent=2))
                    print(json.dumps({'milestone': milestones[-1]}), flush=True)
                    stage += 1
                    continue
                await acknowledge(connection, follower.consumed)
                revision = now['boundary']['state_revision']
                answer = await choices(connection, {'actor_uuid': actor, 'state_revision': revision,
                    'force_attack': False, 'correlation_id': str(uuid4())})
                discovered = answer['choices']
                selected, next_stage = select(state, actor, discovered, stage, leader)
                intent, label, behavior = {'kind': 'end_turn'}, 'End turn', None
                if selected is not None:
                    row, target = selected
                    selection = {'action_index': row['discovery_index'], 'target_indices': [target['index']],
                        'extra_target_positions': []}
                    for _ in range(12):
                        result = await preview(connection, {'actor_uuid': actor, 'state_revision': revision,
                            'discovery_generation': discovered['discovery_generation'],
                            'correlation_id': str(uuid4()), 'selection': selection})
                        if result['preview']['can_confirm']:
                            break
                        options = next_options(result['preview'])
                        if not options:
                            raise RuntimeError(f'Native preview rejected route selection: {result}')
                        selection['target_indices'].append(options[0]['index'])
                    else:
                        raise RuntimeError('Native preview selection did not complete')
                    intent = {'kind': 'execute_selection', 'discovery_generation': discovered['discovery_generation'],
                        'selection': selection}
                    label, behavior = row['display_name'], row['behavior_id']
                command = {'command_number': now['next_command_number'], 'actor_uuid': actor,
                    'state_revision': revision, 'intent': intent}
                outcome = await submit_command(connection, command)
                while outcome['receipt']['kind'] == 'pending':
                    await asyncio.sleep(.01)
                    outcome = await receipt(connection, command['command_number'])
                if outcome['receipt']['kind'] != 'committed':
                    raise RuntimeError(f'Command did not commit: {outcome}')
                await wait_for_cursor(follower, outcome['receipt']['cursor'])
                stage = next_stage
                trace.append({'command': command, 'action': label, 'behavior_id': behavior, 'stage': stage,
                    'actor_name': state.actors[UUID(actor)].name,
                    'position': state.actors[UUID(actor)].last_visual_position,
                    'hp': state.actors[UUID(actor)].normal_hp, 'cursor': follower.consumed,
                    'disclosed_tiles': len(state.tiles), 'disclosed_objects': len(state.objects)})
                (output / 'trace.json').write_text(json.dumps(trace, indent=2))
                print(json.dumps({key: value for key, value in trace[-1].items() if key != 'command'}), flush=True)
                if len(trace) >= 400:
                    raise RuntimeError('Route exceeded 400 actual commands')
        final = {'scenario': 'encounter.lantern_gallery', 'actor_uuid': leader,
            'actor_name': state.actors[UUID(leader)].name, 'commands': len(trace), 'records': records,
            'bytes': byte_count, 'final_cursor': follower.consumed, 'terminal': follower.completed,
            'final_position': state.actors[UUID(leader)].last_visual_position,
            'disclosed_tiles': len(state.tiles), 'disclosed_objects': len(state.objects),
            'seconds': monotonic() - started,
            'source': 'Original public SDK response bytes, current Python reducer, native choices/preview/commands. No state edits or synthetic packets.'}
        (output / 'result.json').write_text(json.dumps(final, indent=2))
        print(json.dumps(final, indent=2), flush=True)
    finally:
        following.cancel()
        await asyncio.gather(following, return_exceptions=True)
        await connection.http.aclose()


async def run(args):
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    settings = configuration('crypt_gallery', output)
    config = output / 'server.json'
    config.write_text(settings.model_dump_json(indent=2))
    config.chmod(0o600)
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    with (output / 'server.log').open('wb') as log:
        host_entry = [str(Path(__file__).with_name('gallery_timing.py'))] if args.action_timings else [
            '-m', 'devtools.player_server_acceptance.test_host']
        host = await asyncio.create_subprocess_exec(sys.executable, *host_entry, '--config', str(config),
            '--stop', str(output / 'server.stop'), '--result', str(output / 'host-result.json'),
            '--port', str(port), cwd=args.engine, stdout=log, stderr=log)
        try:
            async with asyncio.timeout(60):
                while not (output / 'host.ready').exists():
                    if host.returncode is not None:
                        raise RuntimeError('Owned host exited during startup; inspect server.log')
                    await asyncio.sleep(.05)
            async with asyncio.timeout(1250):
                await record(f'http://127.0.0.1:{port}', settings.credentials[0].token, output)
        finally:
            (output / 'server.stop').touch()
            await asyncio.wait_for(host.wait(), 25)


if __name__ == '__main__':
    project = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, default=Path("/home/tommaso/.cache/ndclient/dnd_engine-211b71134"))
    parser.add_argument('--output', type=Path, default=project / '.runtime/gallery-route')
    parser.add_argument('--action-timings', action='store_true', help='Use the isolated diagnostic worker timing hooks')
    asyncio.run(run(parser.parse_args()))
