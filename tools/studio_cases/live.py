"""One native Godot process for real-player spell safety cases.

Uses fresh legal scenario servers and fresh Play/session owners, retaining
Godot's shared ResourceLoader cache. No production renderer or test server API.
Run under the frozen engine Python environment, with tools on PYTHONPATH.
"""
import argparse
import asyncio
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import time

PROJECT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(PROJECT/'tools'))
import adapter
from cases import spell_baselines
from live_spell_profile import drive_blue
from play import available_port, stop_godot, windows_path


def write(path,value):
    temp=path.with_suffix('.pending')
    temp.write_text(json.dumps(value,indent=1)+'\n');temp.chmod(0o600)
    # Windows can briefly deny replacing a file while Godot reads the previous
    # complete request. Keep the atomic handoff; retry that sharing violation.
    deadline=time.monotonic()+1.0
    while True:
        try:temp.replace(path);return
        except PermissionError:
            if time.monotonic()>=deadline:raise
            time.sleep(.005)


async def run(args):
    if args.out.exists() and any(args.out.iterdir()):
        raise ValueError('Live safety output must be new or empty; use a fresh --out directory to preserve prior journals and avoid stale request/results')
    args.out.mkdir(parents=True,exist_ok=True)
    request=args.out/'requests';request.mkdir();config_path=args.out/'client.json'
    rows=spell_baselines(json.loads((PROJECT/'authoring/server_ids.json').read_text()))
    if args.only!='spell':
        selected=set(args.only.split(','))
        rows=[row for row in rows if selected.intersection(row['subjects']['spell']) or row['id'] in selected]
    if args.start_after:
        position=next(index for index,row in enumerate(rows) if row['id']==args.start_after)
        rows=rows[position+1:]
    if not rows:raise ValueError('No current spell case matches '+args.only)
    results=[]
    with (args.out/'godot.log').open('wb') as log:
        client=await asyncio.create_subprocess_exec(str(args.godot),'--path',windows_path(PROJECT),
            '--rendering-method','forward_plus','--rendering-driver','vulkan',
            '--script','res://tests/live_all_spells_checks.gd','--','--config',windows_path(config_path),
            '--batch='+windows_path(request),stdout=log,stderr=log)
        try:
            for number,scenario in enumerate(rows,1):
                case_log_offset=(args.out/'godot.log').stat().st_size
                folder=args.out/scenario['id'].replace('/','__');folder.mkdir(parents=True,exist_ok=True)
                config=adapter.configuration(scenario,scenario.get('seed',2),folder)
                async def case(url):
                    blue=asyncio.create_task(drive_blue(url,config.credentials[1].token,folder))
                    try:
                        report=folder/'result.json'
                        values={'url':url,'token':config.credentials[0].token,'trusted_operations':True,
                            'journal':windows_path(folder/'amber/journal'),'seat_id':'amber',
                            'test_result':windows_path(report),'blue_request':windows_path(folder/'blue-request.json'),
                            'blue_result':windows_path(folder/'blue-result.json')}
                        write(config_path,values)
                        write(request/f'{number:08}.json',{'id':str(number),'scenario':scenario,'result':windows_path(report)})
                        with (args.out/'godot.log').open(errors='replace') as observed:
                            observed.seek(case_log_offset)
                            async with asyncio.timeout(args.timeout):
                                while not report.exists():
                                    if client.returncode is not None:raise RuntimeError('Native safety process exited; inspect godot.log')
                                    if blue.done():await blue;raise RuntimeError('Blue driver unexpectedly completed')
                                    errors=observed.read()
                                    if any(token in errors for token in ('Parse Error:','Failed loading resource')):
                                        raise RuntimeError('Native parse/load error; inspect godot.log')
                                    await asyncio.sleep(.05)
                        result=json.loads(report.read_text())
                        summary=adapter.journal_summary(folder/'amber/journal')
                        missing=set(scenario.get('required_behaviors',[]))-summary['behaviors'].keys()
                        if result['ok'] and missing:result.update(ok=False,failure='Missing required actual occurrences: '+', '.join(sorted(missing)))
                        for field,observed in (('required_facts',summary['facts']),('required_conditions',summary['conditions']),('required_condition_ends',summary['ended_conditions'])):
                            missing=set(scenario.get(field,()))-set(observed)
                            if result['ok'] and missing:result.update(ok=False,failure=field+' absent from actual journal: '+', '.join(sorted(missing)))
                        result['summary']=summary
                        return result
                    finally:
                        blue.cancel();await asyncio.gather(blue,return_exceptions=True)
                try:
                    result=await adapter.hosted(args.engine,config,folder,case,timeout=args.timeout+30,port=available_port())
                except Exception as error:
                    result={'id':scenario['id'],'ok':False,'failure':f'{type(error).__name__}: {error}'}
                with (args.out/'godot.log').open(errors='replace') as observed:
                    observed.seek(case_log_offset)
                    result['native_errors']=[line for line in observed.read().splitlines()
                        if any(token in line for token in ('ERROR:','Parse Error:','Failed loading resource'))]
                if result['native_errors']:result['ok']=False
                result['evidence']={'result':str(folder/'result.json'),'native_log':str(args.out/'godot.log'),
                    'native_log_start_byte':case_log_offset}
                result['case']=scenario['id'];results.append(result)
                write(args.out/'results.json',{'cases':results,'expected_cases':len(rows),'completed_cases':len(results),
                    'complete':False,'ok':False})
                print(('PASS ' if result['ok'] else 'FAIL ')+scenario['id'],flush=True)
                if client.returncode is not None or 'Native parse/load error' in result.get('failure',''):break
            write(request/'99999999.json',{'id':'stop','stop':True})
            try:await asyncio.wait_for(client.wait(),10)
            except TimeoutError:pass
        finally:
            await stop_godot(client,config_path)
    native_log=(args.out/'godot.log').read_text(errors='replace')
    native_errors=[line for line in native_log.splitlines() if any(token in line for token in ('ERROR:','Parse Error:','Failed loading resource'))]
    ok=len(results)==len(rows) and all(row['ok'] for row in results) and not native_errors and client.returncode==0
    write(args.out/'results.json',{'cases':results,'expected_cases':len(rows),'completed_cases':len(results),
        'complete':len(results)==len(rows),'native_errors':native_errors,'native_exit':client.returncode,'ok':ok})
    if native_errors:print('FAIL native batch log: '+str(len(native_errors))+' error lines',flush=True)
    return ok


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine',type=Path,default=Path('/home/tommaso/.cache/ndclient/dnd_engine-211b71134'))
    parser.add_argument('--godot',type=Path,default=PROJECT.parent/'Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe')
    parser.add_argument('--only',default='spell')
    parser.add_argument('--start-after',help='Resume a recorded inventory partition after this exact case ID; earlier evidence is retained in its original run')
    parser.add_argument('--out',type=Path,default=PROJECT/'.runtime/studio-live'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S'))
    parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args();args.out=args.out.resolve()
    raise SystemExit(0 if asyncio.run(run(args)) else 1)


if __name__=='__main__':main()
