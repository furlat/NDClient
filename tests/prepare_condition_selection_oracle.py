"""Exercise the original pure marker selector on actual condition owner records.

This is a composition probe, not a claim the combined owners co-occurred in one
server encounter. Original source and recordings are explicit arguments.
"""
import argparse
import ast
import json
from pathlib import Path
from types import SimpleNamespace


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--authoring', type=Path, required=True)
    parser.add_argument('--recording', type=Path, action='append', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    tree = ast.parse(args.source.read_text())
    functions = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'select_condition_markers']
    assert len(functions) == 1
    module = ast.Module(body=[ast.ImportFrom(module='__future__', names=[ast.alias(name='annotations')], level=0), *functions], type_ignores=[])
    ns = {}
    exec(compile(ast.fix_missing_locations(module), str(args.source), 'exec'), ns)
    recipes = json.loads((args.authoring / 'catalog/condition_recipes.json').read_text())
    found = {}
    def visit(value):
        if isinstance(value, dict):
            if 'condition_uuid' in value and value.get('behavior_id') in recipes:
                found.setdefault(value['behavior_id'], value)
            for child in value.values(): visit(child)
        elif isinstance(value, list):
            for child in value: visit(child)
    for path in args.recording:
        for file in sorted(path.glob('*.json')): visit(json.loads(file.read_text()))
    names = ['condition.poisoned', 'condition.paralyzed', 'class_feature.barbarian.raging']
    assert all(k in found for k in names), (names, list(found))
    base=[]
    for name in names:
        for original in recipes[name]['persistent']['layers']:
            layer={'activeDuring':['idle','move','jump','forced_move','attack','cast','act','hit'], 'lifeStates':['alive','dying','stable','dead'], 'opacity':1.0,'startOffsetMs':0.0,'phaseOffsetMs':0.0,'markerGroup':None, **original}
            base.append({'layer':layer,'condition':found[name],'owner_uuid':found[name]['condition_uuid'],'age_ms':600.0,'application':True,'alpha':1.0,'removal_age_ms':None})
    cases=[]
    for activity,life in [('idle','alive'),('move','alive'),('hit','dead')]:
        for time in [0,1799,1800,3599,3600]:
            for fading in [False,True]:
                rows=json.loads(json.dumps(base))
                if fading:
                    for row in rows:
                        if row['condition']['behavior_id']=='condition.paralyzed':row['removal_age_ms']=10.0
                raw=[SimpleNamespace(**{**row,'layer':SimpleNamespace(**row['layer'])}) for row in rows]
                expected=ns['select_condition_markers'](tuple(raw),time,activity=activity,life_state=life)
                cases.append({'name':f'{activity}-{life}-{time}-fading{fading}','time_ms':time,'activity':activity,'life_state':life,'rows':rows,'expected':[[r.owner_uuid,r.layer.id] for r in expected]})
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps({'source':str(args.source),'recordings':[str(x) for x in args.recording],'conditions':found,'cases':cases},indent=2)+'\n')
    print(json.dumps({'cases':len(cases),'output':str(args.output)}))

if __name__=='__main__':main()
