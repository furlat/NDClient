"""The nonrendering Blue seat for the real Godot spell profiling fixture.

Encounter construction belongs to the existing Gallery recipe. Amber commands
are issued by Play; this companion only advances Blue's legal turns and executes
an explicitly requested Blue action through public choices/preview/commands.
"""
import asyncio
import json
from pathlib import Path
from time import perf_counter_ns
from uuid import uuid4

from dnd_player import (Follower, acknowledge, action_options, all_actions, attach,
    binding_position, binding_subject, connect, follow, next_options, preview, receipt,
    selection_for, status, submit_command, wait_for_cursor)
from studio_cases.adapter import choices


def save(path: Path, value: dict | list) -> None:
    temporary = path.with_suffix('.pending')
    temporary.write_text(json.dumps(value, indent=2))
    temporary.replace(path)


async def drive_blue(url: str, token: str, output: Path) -> None:
    journal = output / 'blue' / 'journal'
    journal.mkdir(parents=True)
    connection = None
    follow_task = None
    controlled, names, commands = set(), {}, []
    completed = set()
    try:
        async with asyncio.timeout(60):
            while True:
                connection = await connect(url, token)
                if connection.bootstrap['status']['published_cursor'] is not None:
                    break
                await connection.http.aclose()
                connection = None
                await asyncio.sleep(.02)
        await attach(connection, {'acquisition_id': str(uuid4()),
            'expected_attachment_epoch': connection.bootstrap['status']['attachment_epoch']})

        async def consume(packet, raw):
            path = journal / f"{packet['cursor']['sequence']:016}.json"
            if path.exists() and path.read_bytes() != raw:
                raise RuntimeError('Blue follower changed original packet bytes')
            path.write_bytes(raw)
            if packet['cursor']['sequence']==0:
                controlled.update(packet['initialization']['audience']['controlled'])
                groups=[packet['initialization']]
            else:groups=packet.get('lineages',[])
            for group in groups:
                names.update({row['actor_uuid']:row['birth']['name'] for row in group.get('bodies',[]) if row.get('birth') is not None})

        follower = Follower(connection, consume)
        follow_task = asyncio.create_task(follow(follower))
        async with asyncio.timeout(900):
            while True:
                if follow_task.done():
                    await follow_task
                    raise RuntimeError('Blue follower stopped before the owned player exited')
                now = await status(connection)
                if now['published_cursor'] is not None:
                    await wait_for_cursor(follower, now['published_cursor'])
                actor = now['boundary']['input_actor_uuid']
                if actor not in controlled:
                    await asyncio.sleep(.025)
                    continue
                if len(commands) >= 180:
                    raise RuntimeError('Blue exceeded the bounded legal turn limit')
                requested = None
                request_path = output / 'blue-request.json'
                if request_path.exists():
                    request = json.loads(request_path.read_text())
                    if request['id'] not in completed and names.get(actor) == request['step']['actor_name']:
                        requested = request
                step = requested['step'] if requested else {'behavior': 'end_turn'}
                await acknowledge(connection, follower.consumed)
                revision = now['boundary']['state_revision']
                record = {'actor': actor, 'actor_name': names.get(actor), 'request': step,
                    'request_id': requested['id'] if requested else None,
                    'start_ns': perf_counter_ns(), 'previews': []}
                intent = {'kind': 'end_turn'}
                if step['behavior'] != 'end_turn':
                    discovered = (await choices(connection, {'actor_uuid': actor,
                        'state_revision': revision, 'force_attack': False,
                        'correlation_id': str(uuid4())}))['choices']
                    offered = [row for row in all_actions(discovered)
                        if row['behavior_id'] == step['behavior'] and row['can_afford']
                        and row.get("availability_status")=="available"
                        and (action_options(discovered, row) or row.get("position_region") is not None)]
                    if not offered:
                        raise RuntimeError('Blue legal choices do not offer ' + step['behavior'])
                    row = min(offered, key=lambda value: (value.get('cast_at_level') or 0, value['discovery_index']))
                    wanted=step['subject_name']
                    point=[int(value) for value in wanted] if isinstance(wanted,list) else None
                    if point is not None and row.get('position_region') is not None:
                        # This is the exact authored optical position; the real
                        # Preview still admits or rejects it before submission.
                        selected=selection_for(row,[],extra_target_positions=[point],prefer_safe=False)
                        subject=None
                    else:
                        targets=[target for target in action_options(discovered,row)
                            if (list(binding_position(discovered,target) or ())==point if point is not None
                                else (binding_subject(discovered,target) or {}).get('name')==wanted)]
                        if not targets:
                            raise RuntimeError('Blue legal choices do not contain the requested subject/position')
                        target=targets[0]
                        subject=(binding_subject(discovered,target) or {}).get('uuid')
                        selected=selection_for(row,[target],prefer_safe=False)
                    for _ in range(16):
                        aimed = (await preview(connection, {'actor_uuid': actor,
                            'state_revision': revision, 'discovery_generation': discovered['discovery_generation'],
                            'correlation_id': str(uuid4()), 'selection': selected}))['preview']
                        record['previews'].append(aimed)
                        if aimed['can_confirm'] and len(selected['target_indices']) >= len(step.get('recipients', [])):
                            break
                        options=[item for item in next_options(aimed)
                            if (list(binding_position(aimed,item) or ())==point if point is not None
                                else (binding_subject(aimed,item) or {}).get('uuid')==subject)]
                        if not options:
                            raise RuntimeError('Blue multi-target preview lost the requested recipient')
                        selected['target_indices'].append(options[0]['index'])
                    else:
                        raise RuntimeError('Blue multi-target preview did not complete')
                    intent = {'kind': 'execute_selection', 'discovery_generation': discovered['discovery_generation'],
                        'selection': selected}
                command = {'command_number': now['next_command_number'], 'actor_uuid': actor,
                    'state_revision': revision, 'intent': intent}
                result = await submit_command(connection, command)
                while result['receipt']['kind'] == 'pending':
                    await asyncio.sleep(.01)
                    result = await receipt(connection, command['command_number'])
                record.update(command=command, receipt=result['receipt'], end_ns=perf_counter_ns())
                commands.append(record)
                save(output / 'blue-commands.json', commands)
                if result['receipt']['kind'] != 'committed':
                    raise RuntimeError('Blue legal command was rejected: ' + str(result['receipt']))
                await wait_for_cursor(follower, result['receipt']['cursor'])
                if requested:
                    completed.add(requested['id'])
                    save(output / 'blue-result.json', {'id': requested['id'], 'receipt': result['receipt']})
    finally:
        if follow_task is not None:
            follow_task.cancel()
            await asyncio.gather(follow_task, return_exceptions=True)
        if connection is not None:
            await connection.http.aclose()
