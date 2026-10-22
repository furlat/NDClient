"""Finite real-server prospective targeting queries; submits no game commands."""
import asyncio
import json
from pathlib import Path
import socket
import sys
import traceback
from uuid import uuid4

from pydantic import TypeAdapter

from dnd.core.cells import mask_positions
from dnd.player import reduction
from dnd_player import (Follower, acknowledge, action_options, all_actions, attach,
    binding_position, binding_subject, choices, connect, follow, next_options,
    preview, preview_positions, selection_for, status, wait_for_cursor)
from devtools.player_server_acceptance.fixtures import combat_configuration
from server.protocol import InitializationResponse

PROJECT = Path(__file__).resolve().parents[1]
ENGINE = Path('/home/tommaso/.cache/ndclient/dnd_engine-1f044792b1')

async def run():
    output = PROJECT / '.runtime' / ('targeting-preview-' + uuid4().hex[:8])
    output.mkdir(parents=True)
    config = combat_configuration('fireball_six_goblins', output, 3)
    config_path = output / 'server.json'
    config_path.write_text(config.model_dump_json(indent=2))
    config_path.chmod(0o600)
    with socket.socket() as sock:
        sock.bind(('127.0.0.1',0)); port = sock.getsockname()[1]
    failures, checks, records, http_records = [], [], [], []
    upcast_records, indexed_fireballs, empty_floor = [], [], {}
    def check(value, label):
        checks.append(label)
        if not value: failures.append(label)
    with (output/'server.log').open('wb') as log:
        host = await asyncio.create_subprocess_exec(sys.executable,'-m','devtools.player_server_acceptance.test_host',
            '--config',str(config_path),'--stop',str(output/'server.stop'),'--result',str(output/'host-result.json'),
            '--port',str(port),cwd=ENGINE,stdout=log,stderr=log)
        connection = task = None
        try:
            async with asyncio.timeout(90):
                while not (output/'host.ready').exists():
                    if host.returncode is not None: raise RuntimeError('Owned server failed; inspect log')
                    await asyncio.sleep(.05)
            credential = next(c for c in config.credentials if c.seat_id=='amber')
            connection = await connect(f'http://127.0.0.1:{port}',credential.token)
            async with asyncio.timeout(90):
                while connection.bootstrap['status']['published_cursor'] is None:
                    await connection.http.aclose()
                    await asyncio.sleep(.05)
                    connection = await connect(f'http://127.0.0.1:{port}',credential.token)
            await attach(connection,{'acquisition_id':str(uuid4()),'expected_attachment_epoch':connection.bootstrap['status']['attachment_epoch']})
            async def consume(packet, raw):
                (output/f"{packet['cursor']['sequence']:016}.json").write_bytes(raw)
            follower = Follower(connection,consume)
            task = asyncio.create_task(follow(follower))
            before = await status(connection)
            await wait_for_cursor(follower,before['published_cursor'])
            await acknowledge(connection,follower.consumed)
            before = await status(connection)
            async def retain_response(response):
                endpoint=response.request.url.path.rsplit('/',1)[-1]
                if endpoint not in ('choices','preview'):
                    return
                # Retain the original public response before the SDK's strict
                # admission. Rejected producer values remain failed evidence.
                raw=await response.aread()
                stem=f'{len(http_records)+1:04}-{endpoint}'
                (output/(stem+'-response.json')).write_bytes(raw)
                (output/(stem+'-request.json')).write_bytes(response.request.content)
                http_records.append({'endpoint':endpoint,'status':response.status_code,
                    'request':stem+'-request.json','response':stem+'-response.json'})
            connection.http.event_hooks['response'].append(retain_response)
            actor = before['boundary']['input_actor_uuid']
            revision = before['boundary']['state_revision']
            domain = (await choices(connection,{'actor_uuid':actor,'state_revision':revision,'force_attack':False,'correlation_id':str(uuid4())}))['choices']
            async def aim(action, indices, positions=(), *, record_into=records):
                selection = {'action_index':action.get('discovery_index',0),'target_indices':list(indices),'extra_target_positions':[list(p) for p in positions],'prefer_safe':True}
                if action.get('cast_at_level') is not None:
                    selection['cast_at_level'] = action['cast_at_level']
                value = (await preview(connection,{'actor_uuid':actor,'state_revision':revision,'discovery_generation':domain['discovery_generation'],
                    'correlation_id':str(uuid4()),'selection':selection}))['preview']
                record_into.append({'behavior':action['behavior_id'],'selection':selection,'preview':value})
                return value
            fireball = next(a for a in all_actions(domain) if a['behavior_id']=='spell.fireball' and a['can_afford'] and action_options(domain,a))
            pool = action_options(domain,fireball)
            target = min(pool,key=lambda t:sum((a-b)**2 for a,b in zip(binding_position(domain,t),(9,7))))
            free_aim = fireball.get('position_region') is not None
            if not free_aim:
                empty = await aim(fireball,[])
                check(empty['area_preview']!='computed' and not preview_positions(empty,affected=True),'Empty Fireball prefix has no invented AoE')
            # Free-aim rows do not offer an empty Preview. Query actual points
            # through the region route, exactly as the interactive client does.
            target_indices = [] if free_aim else [target['index']]
            target_positions = [binding_position(domain,target)] if free_aim else []
            area = await aim(fireball,target_indices,target_positions)
            check(area['area_preview']=='computed' and bool(preview_positions(area,affected=True)),'Prospective Fireball target computes actual affected tiles')
            check(bool(area.get('affected_entity_uuids')),'Prospective Fireball retains actual affected recipients')
            check(area['can_confirm'],'Prospective Fireball may be confirmed without executing')
            again = await aim(fireball,target_indices,target_positions)
            check(again==area,'Same prospective Fireball query is stable')
            other = next(t for t in pool if t['index']!=target['index'])
            moved_area = await aim(fireball,[] if free_aim else [other['index']],
                                   [binding_position(domain,other)] if free_aim else [])
            check(moved_area.get('geometry',{}).get('center')==list(binding_position(domain,other)),
                'Moved Fireball geometry keeps the exact requested center')
            check(moved_area['area_preview']=='computed' and preview_positions(moved_area,affected=True)!=preview_positions(area,affected=True),
                'Moving Fireball aim queries its own native footprint')
            # Read the actual initialization through the reference reducer;
            # the deliberately empty floor aim is visible and has no body.
            initial = TypeAdapter(InitializationResponse).validate_json((output/'0000000000000000.json').read_bytes())
            state = reduction.reduce_initialization(initial.initialization, content_additions=initial.content_additions)
            floor = (8,5)
            visible = floor in mask_positions(state.senses.visible)
            occupied = floor in {a.last_visual_position for a in state.actors.values() if a.present}
            check(visible and not occupied,'Explicit Fireball floor aim is visible and unoccupied in actual initialization')
            floor_area = await aim(fireball,[],[floor])
            empty_floor = {'position':list(floor),'visible':visible,'occupied':occupied,'geometry':floor_area.get('geometry')}
            check(floor_area['can_confirm'] and floor_area['area_preview']=='computed',
                'Empty-floor Fireball aim has a confirmable computed native area')
            check(floor_area.get('geometry',{}).get('center')==list(floor),
                'Empty-floor Fireball geometry keeps the exact requested center')
            for offered, free_area in ((target,area),(other,moved_area)):
                indexed = await aim(fireball,[offered['index']],record_into=indexed_fireballs)
                position = binding_position(domain,offered)
                check(indexed.get('geometry')==free_area.get('geometry'),
                    f'Indexed Fireball at {position} preserves the free-aim geometry')
                check(preview_positions(indexed,affected=True)==preview_positions(free_area,affected=True),
                    f'Indexed Fireball at {position} preserves the free-aim affected cells')
            missile = next(a for a in all_actions(domain) if a['behavior_id']=='spell.magic_missile' and a['can_afford'] and action_options(domain,a))
            current = await aim(missile,[])
            selected, sequence, stages = [], [], []
            subjects = [binding_subject(current,t)['uuid'] for t in next_options(current) if binding_subject(current,t)]
            check(len(subjects)>=2,'Real missile continuation has two distinct admitted recipients')
            for wanted in (subjects[0],subjects[1],subjects[0]):
                target = next(t for t in next_options(current) if binding_subject(current,t) and binding_subject(current,t)['uuid']==wanted)
                selected.append(target['index']); sequence.append(wanted)
                current = await aim(missile,selected)
                stages.append(current)
            check(current['can_confirm'],'A/B/A target prefix is confirmable')
            check(current.get('effective_target_uuids')==sequence,'Actual effective allocation retains A/B/A order and repeats')
            undone = await aim(missile,selected[:-1])
            check(undone==stages[1],'Undo recomputes exactly the original A/B continuation')
            upcast = dict(missile,cast_at_level=2)
            check(2 in missile.get('cast_levels',[]) and upcast.get('num_projectiles')==3,
                'Actual missile row offers level2 while retaining its base three-projectile metadata')
            current = await aim(upcast,[],record_into=upcast_records)
            upcast_selected, upcast_sequence = [], []
            for index in range(4):
                target = next(t for t in next_options(current) if binding_subject(current,t))
                upcast_selected.append(target['index'])
                upcast_sequence.append(binding_subject(current,target)['uuid'])
                current = await aim(upcast,upcast_selected,record_into=upcast_records)
                if index==2:
                    check(current['can_confirm'] and bool(next_options(current)),
                        'Level2 missile after three targets still offers an actual continuation')
            check(current['can_confirm'] and not next_options(current) and not preview_positions(current),
                'Level2 missile after four targets has exhausted its actual continuation')
            check(current.get('effective_target_uuids')==upcast_sequence,
                'Level2 missile retains all four actual allocations')
            after = await status(connection)
            check(after['boundary']['state_revision']==revision,'All prospective/undo requests leave authoritative state revision unchanged')
            check(after['next_command_number']==before['next_command_number'],'No preview spends or allocates a game command')
            check(after['published_cursor']==before['published_cursor'],'Preview-only inspection publishes no new gameplay packet')
            report={'ok':not failures,'checks':len(checks),'failures':failures,'assertions':checks,'choices':domain,'records':records,
                'empty_floor':empty_floor,'upcast_records':upcast_records,'indexed_fireballs':indexed_fireballs,
                'before_status':before,'after_status':after,'http_records':http_records,
                'scope':'Independent real server and current Python SDK; exact occupied/empty-floor Fireball geometry and base/upcast missile prefix queries; no game commands'}
            (output/'checks.json').write_text(json.dumps(report,indent=2))
            print(json.dumps({'ok':not failures,'checks':len(checks),'failures':failures,'output':str(output)}),flush=True)
        except Exception as error:
            failures.append(type(error).__name__+': '+str(error))
            (output/'checks.json').write_text(json.dumps({'ok':False,'checks':len(checks),
                'failures':failures,'assertions':checks,'records':records,'http_records':http_records,
                'empty_floor':empty_floor,'upcast_records':upcast_records,'indexed_fireballs':indexed_fireballs,
                'scope':'Original public requests/responses retained; failed SDK admission is not bypassed.'},indent=2))
            print(json.dumps({'ok':False,'checks':len(checks),'failures':failures,'output':str(output)}),flush=True)
            traceback.print_exc()
        finally:
            if task:
                task.cancel()
                await asyncio.gather(task,return_exceptions=True)
            if connection: await connection.http.aclose()
            (output/'server.stop').touch()
            await asyncio.wait_for(host.wait(),25)
    return 1 if failures else 0

if __name__=='__main__':
    sys.exit(asyncio.run(run()))
