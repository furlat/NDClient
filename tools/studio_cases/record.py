#!/usr/bin/env python3
"""Record current engine cases through legal SDK commands, preserving both seats.

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

from cases import first_cohort, spell_baselines

PROJECT=Path(__file__).resolve().parents[2]
ENGINE=Path('/home/tommaso/.cache/ndclient/dnd_engine-211b71134')
PYTHON=Path('/home/tommaso/.cache/dnd-engine/venv/bin/python')


def resource(path):
    return 'res://'+str(path.resolve().relative_to(PROJECT))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine',type=Path,default=ENGINE)
    parser.add_argument('--python',type=Path,default=PYTHON)
    parser.add_argument('--only',default='cohort')
    parser.add_argument('--out',type=Path,default=PROJECT/'.runtime/studio-library')
    parser.add_argument('--timeout',type=int,default=300)
    args=parser.parse_args();args.out=args.out.resolve()
    if args.timeout<90:parser.error('--timeout must leave at least90s for bounded host/driver cleanup')
    args.out.mkdir(parents=True,exist_ok=True)
    environment=dict(os.environ,PYTHONPATH=f'{args.engine}:{args.engine}/sdk/python/src',PYTHONDONTWRITEBYTECODE='1',PYTHONHASHSEED='0')
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
    index={'version':1,'engine':{'path':str(args.engine),**identity},'engine_ids':resource(args.out/'engine_ids.json'),'cases':[]}
    index_path=args.out/'index.json'
    if index_path.exists():
        previous=json.loads(index_path.read_text())
        if previous.get('engine')==index['engine']:index['cases']=previous['cases']
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
        entry={key:scenario[key] for key in ('id','title','kind','subjects','seed')}
        entry['subjects']={kind:list(ids) for kind,ids in entry['subjects'].items()}
        actual_ids=list(result.get('summary',{}).get('behaviors',{}))+result.get('summary',{}).get('conditions',[])
        actual_ids.extend(actor['creature'] for actor in scenario['actors'] if 'creature' in actor)
        actual_ids.extend(item if isinstance(item,str) else item['id'] for actor in scenario['actors'] for item in actor.get('items',[]))
        for kind,ids in inventory['ids'].items():
            observed=[content for content in actual_ids if content in ids]
            if observed:entry['subjects'][kind]=sorted(set(entry['subjects'].get(kind,[])+observed))
        entry.update(journals={seat:resource(folder/seat/'journal') for seat in ('amber','blue')},
            moments=result.get('moments',[]),status='recorded' if result['ok'] else 'failed',reason=result.get('failure') or '',
            scenario=resource(scenario_path),studio_checked=False,errors=[])
        index['cases']=[row for row in index['cases'] if row['id']!=entry['id']]+[entry]
        index_path.write_text(json.dumps(index,indent=1)+'\n')
        failed+=not result['ok'];print(f"{entry['status']:8} {entry['id']} {entry['reason']}",flush=True)
    print(json.dumps({'cases':len(candidates),'failed':failed,'index':str(index_path)}))
    raise SystemExit(1 if failed else 0)


if __name__=='__main__':main()
