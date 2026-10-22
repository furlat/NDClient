#!/usr/bin/env python3
"""Record current engine cases through legal SDK commands, preserving actual seats.

    python3 tools/studio_cases/record.py --only cohort
    python3 tools/studio_cases/record.py --only spell.fire_bolt
    python3 tools/studio_cases/record.py --only spell

The index reports capture safety independently from Studio, providers and art
approval. Studio checks fill studio_checked/errors through the shared replay gate.
"""
import argparse
from datetime import datetime, timezone
import json
import os
import signal
from pathlib import Path
import subprocess

from cases import first_cohort, spell_baselines, spell_baseline_exclusions

PROJECT=Path(__file__).resolve().parents[2]
ENGINE=Path('/home/tommaso/.cache/ndclient/dnd_engine-bedc3d92dc')
PYTHON=Path('/home/tommaso/.cache/dnd-engine/venv/bin/python')


def compatible_cases(previous, expected):
    """Retain playable originals with their actual engine across same-wire fixes."""
    actual=previous.get('engine',{})
    fields=('protocol_version','player_schema_version','schema_digest')
    if any(actual.get(key) is None or actual.get(key)!=expected.get(key) for key in fields):
        raise ValueError('Existing library uses another wire contract; select a separate --out')
    return [dict(row,engine=(row.get('engine') or {}) if 'engine' in row else actual.copy())
            for row in previous.get('cases',[])]


def resource(path):
    return 'res://'+str(path.resolve().relative_to(PROJECT))


def entry_for(scenario,result,folder,inventory):
    entry={key:scenario[key] for key in ('id','title','kind','subjects','seed')}
    entry['subjects']={kind:list(ids) for kind,ids in entry['subjects'].items()}
    actual_ids=list(result.get('summary',{}).get('behaviors',{}))+result.get('summary',{}).get('conditions',[])+result.get('summary',{}).get('item_effects',[])
    actual_ids.extend(actor['creature'] for actor in scenario['actors'] if 'creature' in actor)
    actual_ids.extend(item if isinstance(item,str) else item['id'] for actor in scenario['actors'] for item in actor.get('items',[]))
    for kind,ids in inventory['ids'].items():
        observed=[content for content in actual_ids if content in ids]
        if observed:entry['subjects'][kind]=sorted(set(entry['subjects'].get(kind,[])+observed))
    journals={}
    for seat in result.get('perspectives',('party',) if scenario.get('player_builds_source') else ('amber','blue')):
        path=folder/seat/'journal'
        if not path.joinpath('0000000000000000.json').exists():path=folder/seat
        journals[seat]=resource(path)
    entry.update(journals=journals,moments=result.get('moments',[]),status='recorded' if result['ok'] else 'failed',
        reason=result.get('failure') or '',scenario=resource(folder/'scenario.json'),studio_checked=False,errors=[],
        engine=result.get('engine') or {})
    return entry


def import_recordings(roots,out):
    """Publish preserved original captures; no backend, packet edits or review claims."""
    inventory=json.loads((PROJECT/'authoring/server_ids.json').read_text())
    identity={key:inventory['header'][key] for key in ('commit','protocol_version','player_schema_version','schema_digest')}
    path=out/'index.json'
    index=json.loads(path.read_text()) if path.exists() else {'version':1,'engine':{'path':str(ENGINE),**identity},'cases':[]}
    index['spell_baseline_exclusions']=spell_baseline_exclusions(inventory)
    if any(index['engine'].get(key)!=value for key,value in identity.items()):
        # Imports preserve historical originals alongside new current captures.
        # Pin each retained row to its original producer before changing the
        # index default; the ordinary Library/Journal still owns admission.
        previous_engine=index['engine']
        index['cases']=[dict(row,engine=(row.get('engine') or {}) if 'engine' in row else previous_engine.copy())
                        for row in index['cases']]
        index['engine']={'path':str(ENGINE),**identity}
    files=sorted({record.resolve() for root in roots for record in root.rglob('recording.json')})
    if not files:raise ValueError('No preserved recording.json was found')
    published=[]
    for record in files:
        result=json.loads(record.read_text());folder=record.parent
        actual=result.get('engine') or {}
        # A setup failure may precede any initialized producer journal. Keep
        # that failed original inspectable without assigning it the expected
        # engine; successful or identified captures must match exactly.
        if (actual or result.get('ok')) and any(actual.get(key)!=value for key,value in identity.items()):
            raise ValueError('Original recording engine does not match current authoring: '+str(record))
        entry=entry_for(json.loads((folder/'scenario.json').read_text()),result,folder,inventory)
        if entry['id'] in published:
            raise ValueError('Multiple captures for one case; select one original directory: '+entry['id'])
        if result['ok']:
            for journal in entry['journals'].values():
                if not (PROJECT/journal.removeprefix('res://')/'0000000000000000.json').exists():
                    raise FileNotFoundError('Missing original initialization: '+journal)
        previous=next((row for row in index['cases'] if row['id']==entry['id']),None)
        if previous and all(previous.get(key)==entry[key] for key in ('journals','scenario','status')):
            # Re-publishing the same immutable capture retains its separate
            # playback/output/review evidence. A different capture resets it.
            entry={**previous,**entry,'studio_checked':previous.get('studio_checked',False),'errors':previous.get('errors',[])}
        index['cases']=[row for row in index['cases'] if row['id']!=entry['id']]+[entry]
        published.append(entry['id'])
    out.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(index,indent=1)+'\n')
    return {'imported':published,'index':str(path),'backend_started':False,
            'spell_baseline_exclusions':index['spell_baseline_exclusions']}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine',type=Path,default=ENGINE)
    parser.add_argument('--sdk',type=Path,help='Explicit immutable Python SDK source root (default: selected engine export SDK)')
    parser.add_argument('--python',type=Path,default=PYTHON)
    parser.add_argument('--only',default='cohort')
    parser.add_argument('--out',type=Path,default=PROJECT/'.runtime/studio-library')
    parser.add_argument('--timeout',type=int,default=300)
    parser.add_argument('--import-recordings',type=Path,nargs='+',help='Publish preserved original capture directories without starting a backend')
    args=parser.parse_args();args.out=args.out.resolve()
    if args.import_recordings:
        print(json.dumps(import_recordings(args.import_recordings,args.out)));return
    if args.timeout<90:parser.error('--timeout must leave at least90s for bounded host/driver cleanup')
    args.out.mkdir(parents=True,exist_ok=True)
    selected_sdk=(args.sdk or args.engine/'sdk/python/src').resolve()
    sdk_provenance={'path':str(selected_sdk),'query_adapter':'strict_selected_SDK_choices'}
    sdk_source=selected_sdk.parents[2]/'.source.json'
    if sdk_source.exists():sdk_provenance['source']=json.loads(sdk_source.read_text())
    environment=dict(os.environ,PYTHONPATH=f'{args.engine}:{selected_sdk}',PYTHONDONTWRITEBYTECODE='1',PYTHONHASHSEED='0',
                     NDCLIENT_STUDIO_SDK_PROVENANCE=json.dumps(sdk_provenance))
    extracted=subprocess.run([str(args.python),'-B',str(PROJECT/'tools/snapshot_server_ids.py'),'--extract','--engine',str(args.engine)],
        env=environment,cwd=args.engine,capture_output=True,text=True,timeout=180,check=True)
    inventory=json.loads(extracted.stdout)
    (args.out/'engine_ids.json').write_text(json.dumps(inventory,indent=1)+'\n')
    candidates=first_cohort()+spell_baselines(inventory)
    if args.only=='cohort':candidates=first_cohort()
    elif args.only=='spell':candidates=spell_baselines(inventory)
    elif args.only not in ('all','failed'):
        wanted=set(args.only.split(','))
        candidates=[row for row in candidates if row['id'] in wanted or wanted.intersection(row['subjects']['spell'])]
    if not candidates:parser.error('No current scenario matches '+args.only)
    identity={key:inventory['header'][key] for key in ('commit','protocol_version','player_schema_version','schema_digest')}
    index={'version':1,'engine':{'path':str(args.engine),**identity},'engine_ids':resource(args.out/'engine_ids.json'),
           'spell_baseline_exclusions':spell_baseline_exclusions(inventory),'cases':[]}
    index_path=args.out/'index.json'
    if index_path.exists():
        previous=json.loads(index_path.read_text())
        index['cases']=compatible_cases(previous,index['engine'])
    if args.only=='failed':
        failed_ids={row['id'] for row in index['cases'] if row.get('status')!='recorded'}
        candidates=[row for row in candidates if row['id'] in failed_ids]
    failed=0
    for scenario in candidates:
        folder=args.out/'cases'/scenario['id'].replace('/','__')/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
        folder.mkdir(parents=True,exist_ok=True)
        scenario_path=folder/'scenario.json';scenario_path.write_text(json.dumps(scenario,indent=1)+'\n')
        with (folder/'runner.log').open('w') as log:
            try:
                process=subprocess.run([str(args.python),'-B',str(Path(__file__).with_name('worker.py')),
                    '--engine',str(args.engine),'--scenario',str(scenario_path),'--out',str(folder),'--timeout',str(args.timeout-60)],
                    cwd=args.engine,env=environment,stdout=log,stderr=subprocess.STDOUT,timeout=args.timeout)
                result=json.loads((folder/'recording.json').read_text())
            except (subprocess.TimeoutExpired,OSError,ValueError) as error:
                (folder/'server.stop').touch()
                if (folder/'host.pid').exists():
                    try:os.killpg(int((folder/'host.pid').read_text()),signal.SIGTERM)
                    except ProcessLookupError:pass
                result={'ok':False,'failure':f'{type(error).__name__}: {error}'}
        entry=entry_for(scenario,result,folder,inventory)
        index['cases']=[row for row in index['cases'] if row['id']!=entry['id']]+[entry]
        index_path.write_text(json.dumps(index,indent=1)+'\n')
        failed+=not result['ok'];print(f"{entry['status']:8} {entry['id']} {entry['reason']}",flush=True)
    print(json.dumps({'cases':len(candidates),'failed':failed,'index':str(index_path),
                      'spell_baseline_exclusions':index['spell_baseline_exclusions']}))
    raise SystemExit(1 if failed else 0)


if __name__=='__main__':main()
