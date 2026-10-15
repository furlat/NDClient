"""Finite real-server prospective targeting queries; submits no game commands."""
import asyncio
import json
from pathlib import Path
import socket
import sys
from uuid import uuid4

from dnd_player import (Follower, acknowledge, action_options, all_actions, attach,
    binding_position, binding_subject, choices, connect, follow, next_options,
    preview, preview_positions, selection_for, status, wait_for_cursor)
from devtools.player_server_acceptance.fixtures import combat_configuration

PROJECT = Path(__file__).resolve().parents[1]
ENGINE = PROJECT.parent / 'dnd_engine'

async def run():
    output = PROJECT / '.runtime' / ('targeting-preview-' + uuid4().hex[:8])
    output.mkdir(parents=True)
    config = combat_configuration('fireball_six_goblins', output, 3)
    config_path = output / 'server.json'
    config_path.write_text(config.model_dump_json(indent=2))
    config_path.chmod(0o600)
    with socket.socket() as sock:
        sock.bind(('127.0.0.1',0)); port = sock.getsockname()[1]
    failures, checks, records = [], [], []
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
            actor = before['boundary']['input_actor_uuid']
            revision = before['boundary']['state_revision']
            domain = (await choices(connection,{'actor_uuid':actor,'state_revision':revision,'force_attack':False,'correlation_id':str(uuid4())}))['choices']
            async def aim(action, indices):
                selection = {'action_index':action.get('discovery_index',0),'target_indices':list(indices),'extra_target_positions':[],'prefer_safe':True}
                value = (await preview(connection,{'actor_uuid':actor,'state_revision':revision,'discovery_generation':domain['discovery_generation'],
                    'correlation_id':str(uuid4()),'selection':selection}))['preview']
                records.append({'behavior':action['behavior_id'],'selection':selection,'preview':value})
                return value
            fireball = next(a for a in all_actions(domain) if a['behavior_id']=='spell.fireball' and a['can_afford'] and action_options(domain,a))
            empty = await aim(fireball,[])
            check(empty['area_preview']!='computed' and not preview_positions(empty,affected=True),'Empty Fireball prefix has no invented AoE')
            pool = action_options(domain,fireball)
            target = min(pool,key=lambda t:sum((a-b)**2 for a,b in zip(binding_position(domain,t),(9,7))))
            area = await aim(fireball,[target['index']])
            check(area['area_preview']=='computed' and bool(preview_positions(area,affected=True)),'Prospective Fireball target computes actual affected tiles')
            check(bool(area.get('affected_entity_uuids')),'Prospective Fireball retains actual affected recipients')
            check(area['can_confirm'],'Prospective Fireball may be confirmed without executing')
            again = await aim(fireball,[target['index']])
            check(again==area,'Same prospective Fireball query is stable')
            other = next(t for t in pool if t['index']!=target['index'])
            moved_area = await aim(fireball,[other['index']])
            check(moved_area['area_preview']=='computed' and preview_positions(moved_area,affected=True)!=preview_positions(area,affected=True),
                'Moving Fireball aim queries its own native footprint')
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
            after = await status(connection)
            check(after['boundary']['state_revision']==revision,'All prospective/undo requests leave authoritative state revision unchanged')
            check(after['next_command_number']==before['next_command_number'],'No preview spends or allocates a game command')
            check(after['published_cursor']==before['published_cursor'],'Preview-only inspection publishes no new gameplay packet')
            report={'ok':not failures,'checks':len(checks),'failures':failures,'assertions':checks,'choices':domain,'records':records,
                'before_status':before,'after_status':after,'scope':'Independent real server and current Python SDK; exact Fireball AoE and missile prefix/undo queries; no game commands'}
            (output/'checks.json').write_text(json.dumps(report,indent=2))
            print(json.dumps({'ok':not failures,'checks':len(checks),'failures':failures,'output':str(output)}),flush=True)
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
