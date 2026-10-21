"""Join actual GUI run partitions and explicit retries without replacing evidence.

Inputs are ordered oldest to newest. A corrected retry supersedes only that
same case, while every previous attempt and its original log remain linked.
"""
import argparse
import json
from pathlib import Path
from cases import spell_baselines

PROJECT=Path(__file__).resolve().parents[2]


def legacy_errors(log, cases):
    result={row['case']:[] for row in cases}
    next_case=0
    for number,line in enumerate(log.splitlines(),1):
        if line.startswith('LIVE_SPELL_SAFETY_CASE '):
            row=json.loads(line.split(' ',1)[1]);next_case=int(row['id'])
        elif any(token in line for token in ('ERROR:','Parse Error:','Failed loading resource')) and next_case<len(cases):
            result[cases[next_case]['case']].append({'line':number,'message':line})
    return result


def join(paths):
    inventory=json.loads((PROJECT/'authoring/server_ids.json').read_text())
    scenarios={row['id']:row for row in spell_baselines(inventory)}
    wanted=set(scenarios)
    case_index=PROJECT/'.runtime/studio-library/index.json'
    recorded=json.loads(case_index.read_text()) if case_index.exists() else {'cases':[]}
    blockers={row['id']:{'status':row['status'],'reason':row.get('reason',''),'source':str(case_index.resolve())}
        for row in recorded['cases'] if row.get('status')=='failed' and row['id'] in wanted}
    history={};runs=[]
    for path in paths:
        report=json.loads(path.read_text());log_path=path.parent/'godot.log'
        cases=[]
        for row in report['cases']:
            identity=row['case'] if 'case' in row else row.get('id')
            if identity not in wanted:raise ValueError('GUI result is outside current inventory: '+str(identity))
            cases.append({**row,'case':identity})
        report['cases']=cases
        log=log_path.read_text(errors='replace') if log_path.exists() else ''
        runs.append({'report':str(path.resolve()),'log':str(log_path.resolve()),'native_exit':report.get('native_exit'),
            'expected_cases':report.get('expected_cases'),'completed_cases':len(report['cases']),'complete':report.get('complete',False),
            'warnings':[line for line in log.splitlines() if 'WARNING:' in line]})
        older=legacy_errors(log,report['cases']) if any('native_errors' not in row for row in report['cases']) else {}
        for row in report['cases']:
            identity=row['case']
            errors=row.get('native_errors',older.get(identity,[]))
            result_path=path.parent/identity.replace('/','__')/'result.json'
            raw=json.loads(result_path.read_text()) if result_path.exists() else {}
            steps=row.get('steps',raw.get('steps',[]))
            expected=scenarios[identity]['steps']
            # A successful setup hit is not the later spell whose button was
            # unavailable. Every requested recipe step must actually complete.
            completed_command=len(steps)==len(expected) and all(step.get('ok',False) and step.get('requested')==requested
                for step,requested in zip(steps,expected))
            native_exit=report.get('native_exit')
            attempt={**row,'native_errors':errors,'command_succeeded':completed_command,'native_exit':native_exit,
                'expected_steps':len(expected),'completed_steps':sum(bool(step.get('ok',False)) for step in steps),
                'runtime_safe':bool(native_exit==0 and row.get('ok') and completed_command and not errors),
                'render_trace':row.get('render_trace',raw.get('render_trace',{})),
                'artifact_provenance':{'report':str(path.resolve()),'log':str(log_path.resolve()),
                    'result':str(result_path.resolve()),'native_exit':report.get('native_exit'),
                    'error_attribution':'per_case_log_interval' if 'native_errors' in row else 'native_completion_markers'}}
            history.setdefault(identity,[]).append(attempt)
    cases=[]
    for identity in sorted(history):
        attempts=history[identity]
        latest=attempts[-1].copy();latest['attempts']=attempts
        latest['known_recording_blocker']=blockers.get(identity)
        cases.append(latest)
    return {'scope':'actual_gui_commands_and_native_error_safety','engine':inventory.get('header',{}),
        'expected_cases':len(wanted),'completed_cases':len(cases),'complete':len(cases)==len(wanted),
        'ok':len(cases)==len(wanted) and all(row['runtime_safe'] for row in cases),
        'command_succeeded':sum(row['command_succeeded'] for row in cases),
        'runtime_safe':sum(row['runtime_safe'] for row in cases),
        'native_error_lines':sum(len(row['native_errors']) for row in cases),
        'native_exit':0 if all(run['native_exit']==0 for run in runs) else None,'runs':runs,
        'cases':cases,'missing_cases':sorted(wanted-history.keys()),
        'qualification':'Real player input, actual commands and native error safety; effect witnesses are in render_trace. Command completion alone does not qualify every finite effect tail, provider or visual acceptance.'}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('reports',type=Path,nargs='+')
    args=parser.parse_args();report=join(args.reports)
    args.out.parent.mkdir(parents=True,exist_ok=True)
    pending=args.out.with_suffix('.pending');pending.write_text(json.dumps(report,indent=1)+'\n');pending.replace(args.out)
    print(json.dumps({key:report[key] for key in ['expected_cases','completed_cases','complete','ok','command_succeeded','runtime_safe','native_error_lines']}))


if __name__=='__main__':main()
