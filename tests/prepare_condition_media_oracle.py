"""Execute the original pure condition sampler against delivered Hold Person banks."""
import argparse
import ast
from dataclasses import dataclass, replace
from math import floor
import json
from pathlib import Path
from types import SimpleNamespace


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--authoring',type=Path,required=True)
    parser.add_argument('--recording',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    wanted={'ConditionMediaSample','_loop_samples','sample_condition_media'}
    nodes=[n for n in ast.parse(args.source.read_text()).body if isinstance(n,(ast.FunctionDef,ast.ClassDef)) and n.name in wanted]
    assert len(nodes)==3
    module=ast.Module(body=[ast.ImportFrom(module='__future__',names=[ast.alias(name='annotations')],level=0),*nodes],type_ignores=[])
    ns={'dataclass':dataclass,'replace':replace,'floor':floor}
    exec(compile(ast.fix_missing_locations(module),str(args.source),'exec'),ns)
    recipes=json.loads((args.authoring/'catalog/condition_recipes.json').read_text())
    sources=json.loads((args.authoring/'catalog/condition_media.json').read_text())
    condition=None
    def visit(value):
        nonlocal condition
        if isinstance(value,dict):
            if value.get('behavior_id')=='condition.spell.hold_person' and 'condition_uuid'in value:condition=value
            for child in value.values():visit(child)
        elif isinstance(value,list):
            for child in value:visit(child)
    for path in args.recording.glob('*.json'):visit(json.loads(path.read_text()))
    assert condition is not None
    @dataclass(frozen=True)
    class Resolved:
        layer:object
        media:object
        age_ms:float
        application:bool
        alpha:float=1.0
        removal_age_ms:float|None=None
        fade_in_age_ms:float|None=None
        finite:bool=False
    cases=[]
    for layer_json in recipes['condition.spell.hold_person']['persistent']['layers']:
        layer=SimpleNamespace(**{'startOffsetMs':0,'phaseOffsetMs':0,'fadeInMs':0,'fps':32,'opacity':1,**layer_json})
        meta=sources[layer.assetId]
        media=SimpleNamespace(**{'application_asset_id':None,'application_fade_ms':[1500,2000],'application_mode':'crossfade','removal_asset_id':None,'removal_crossfade_ms':0,'removal_mask_asset_id':None,'sustain_start_ms':0,'loop_crossfade_ms':0,**meta})
        assets={}
        for name in [media.asset_id,media.application_asset_id,media.removal_asset_id]:
            definition=json.loads((args.authoring/'media/definitions'/f'{name}.json').read_text())
            assets[name]=SimpleNamespace(fps=definition['fps'],phases=SimpleNamespace(impact=SimpleNamespace(**definition['phases']['impact'])))
        data=SimpleNamespace(projectile_assets=assets)
        probes=[(initial,age,None,None) for initial in [False,True] for age in [0,100,600,602.5,620,662.5,700,2200]]
        probes += [(initial,end+removal,end,removal) for initial in [False,True] for end in [100,620,1000] for removal in [0,1,75,149,150,500,2718.74,2718.75]]
        for initial,clock,end,removal in probes:
            resolved=Resolved(layer,media,clock if end is None else end,not initial,removal_age_ms=removal,fade_in_age_ms=max(0,end-layer.startOffsetMs) if end is not None and not initial else None)
            expected=ns['sample_condition_media'](data,resolved)
            cases.append({'name':f'{layer.id}-{initial}-{clock}-{end}','layer':layer_json,'metadata':meta,'initial':initial,'age_ms':clock,'removal_age_ms':removal,'expected':[{'asset_id':v.asset_id,'frame':v.frame,'alpha':v.alpha*layer.opacity} for v in expected]})
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps({'source':str(args.source),'recording':str(args.recording),'condition':condition,'cases':cases},indent=2)+'\n')
    print(json.dumps({'cases':len(cases),'output':str(args.output)}))
if __name__=='__main__':main()
