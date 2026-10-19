"""One owned recording process. Its parent selects the frozen engine environment."""
import argparse
import asyncio
import json
from pathlib import Path

import adapter


async def record(args):
    scenario=json.loads(args.scenario.read_text())
    args.out.mkdir(parents=True, exist_ok=True)
    config=adapter.configuration(scenario, scenario.get('seed',2), args.out)
    async def drive(url):
        return await adapter.drive(config,url,args.out,scenario['steps'],scenario)
    result=await adapter.hosted(args.engine,config,args.out,drive,timeout=args.timeout)
    summary=adapter.journal_summary(args.out/'amber/journal')
    missing=set(scenario.get('required_behaviors',()))-summary['behaviors'].keys()
    if missing and result['ok']:
        result['ok']=False
        result['failure']='Required actual spell/action occurrence absent: '+', '.join(sorted(missing))
    for field,observed in (('required_facts',summary['facts']),('required_conditions',summary['conditions']),('required_condition_ends',summary['ended_conditions'])):
        missing=set(scenario.get(field,()))-set(observed)
        if missing and result['ok']:
            result.update(ok=False,failure=field+' absent from actual journal: '+', '.join(sorted(missing)))
    if not result['ok'] and not result.get('failure'):
        result['failure']='; '.join(str(row['reason']) for row in result.get('gaps',[]))
    moments=[]
    for faction in adapter.SIDES:
        moments.extend(dict(row,faction=faction) for row in adapter.moments(args.out/faction/'journal'))
    result.update(summary=summary, moments=moments, engine=adapter.engine_identity(args.engine))
    (args.out/'recording.json').write_text(json.dumps(result,indent=1,default=str)+'\n')
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine',type=Path,required=True)
    parser.add_argument('--scenario',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--timeout',type=int,default=240)
    args=parser.parse_args()
    try:
        result=asyncio.run(asyncio.wait_for(record(args),args.timeout))
    except Exception as error:
        result={'ok':False,'failure':f'{type(error).__name__}: {error}'}
        args.out.mkdir(parents=True,exist_ok=True)
        (args.out/'recording.json').write_text(json.dumps(result,indent=1)+'\n')
    print(json.dumps({'ok':result['ok'],'reason':result.get('failure'),'out':str(args.out)}),flush=True)
    raise SystemExit(0 if result['ok'] else 1)


if __name__=='__main__':main()
