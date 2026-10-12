"""Index existing owners for the Godot palette; never rewrite authoring or art."""
from pathlib import Path
import argparse
import json
import re
from collections import Counter
from functools import lru_cache

parser=argparse.ArgumentParser()
parser.add_argument('--authoring',default='/home/tommaso/Dev/NDClient/authoring')
args=parser.parse_args()
root=Path(args.authoring)
@lru_cache(maxsize=None)
def read(p): return json.loads((root/p).read_text())
index=read('environment/index.json')
assets=read('assets.json')
world=read('world.json')
entries=[]
sequences={}
missing_samples=[]
for family in ['props','doors','traps']:
    for identity,path in index[family].items():
        owner=read(path)
        states=list(owner.get('intact',{})) if family=='props' else (list(owner['state_frames']) if family=='traps' else ['closed','open.inward','open.outward'])
        entries.append(dict(id=identity,label=identity.removeprefix('environment.').replace('.',' '),group=family,
            kind=family[:-1],asset=identity,owner=path,states=states,breakable=bool(owner.get('destructions')),placeable=True))
        if 'assembly_variants' in owner: entries[-1]['assemblies']=owner['assembly_variants']
        if family=='doors': entries[-1]['outcomes']=list(dict.fromkeys(k.rsplit('.',1)[-1] for k in owner['destructions']))
for material in world['terrain']:
    entries.append(dict(id='terrain/'+material,label=material+' floor',group='terrain',kind='terrain',material=material,placeable=True,breakable=False))
for material in ['stone','wood']:
    entries.append(dict(id='wall/'+material,label=material+' wall',group='walls',kind='wall',material=material,placeable=True,breakable=True))
for identity,record in assets['resources'].items():
    if identity.startswith(('terrain.','stone.wall.','wood.wall.')) or not record['path'].startswith('/media/environment/'): continue
    if identity in [assets['water'][k] for k in ['mask','ripple','normal']]: continue
    entries.append(dict(id='resource/'+identity,label=identity,group='registered',kind='resource',asset=identity,placeable=True,breakable=False))
for identity,path in index['library'].items():
    owner=read(path)
    registered=[i for i,s in enumerate(owner['samples']) if 'pivot' in s and 'scale' in s]
    absent=[{'sample':n,'missing':[key for key in ['pivot','scale'] if key not in s]} for n,s in enumerate(owner['samples']) if 'pivot' not in s or 'scale' not in s]
    if absent: missing_samples.append({'id':identity,'samples':absent})
    reason=''
    if not registered:
        missing=sorted({field for s in owner['samples'] for field in ['pivot','scale'] if field not in s})
        reason='Source samples omit '+', '.join(missing)
    elif absent:
        reason=f'{len(absent)} source samples lack pivot or scale. Only registered samples are available; first available is not necessarily the intact frame.'
    # Preserve the exact source sample index. The renderer selects equivalent
    # authored views from this sample's variant/state/source sequence.
    groups={}
    for n in registered:
        sample=owner['samples'][n]
        sheet=sample['colour']['path']
        view=sample['source_view']
        sheet=re.sub(r'([-_])'+re.escape(view)+r'\.png$',r'\1{view}.png',sheet)
        if 'camera_quadrant' in sample: sheet=re.sub(r'-q'+str(sample['camera_quadrant'])+r'\.png$',r'-q{camera}.png',sheet)
        axes={key:sample[key] for key in ['state','variant_index','variant_name','pitch_degrees','aim_row'] if key in sample}
        key=json.dumps([axes,sheet],sort_keys=True)
        if key not in groups:
            clocks=[c for c in owner.get('clocks',[]) if all(sample.get(k)==c[k] for k in ['state','variant_index','variant_name'] if k in c)]
            clock=clocks[0] if len(clocks)==1 else {}
            labels=[str(v) for k,v in axes.items() if k!='variant_index']+[Path(sheet).parent.name+'/'+Path(sheet).name]
            groups[key]=dict(label=' · '.join(labels),axes=axes,sheet=sheet,views={},
                duration_ms=clock.get('duration_ms',0),fps=clock.get('fps',0) or 0,clear_at_end=clock.get('clear_at_end',False),
                destruction=(sample.get('state')=='destruction' or 'destruction candidate' in sample.get('variant_name','').lower() or sample.get('variant_name') in ['impact-a','impact-b'] or identity=='generated-timber-stair-flight'))
        groups[key]['views'].setdefault(view,[]).append(n)
    sequences[identity]=list(groups.values())
    for group in sequences[identity]:
        for indices in group['views'].values(): indices.sort(key=lambda n:(owner['samples'][n].get('time_ms',0),owner['samples'][n]['frame_index']))
        count=max(len(v) for v in group['views'].values())
        if count<2: group['duration_ms']=0
        elif not group['duration_ms'] and group['fps']: group['duration_ms']=count/group['fps']*1000
        group['destruction']=group['destruction'] and group['duration_ms']>0
    entries.append(dict(id='library/'+identity,label=owner['label'],group='library',kind='library',asset=identity,
        owner=path,placeable=bool(registered),breakable=False,sample=registered[0] if registered else 0,
        source_role=owner['role'],reason=reason,samples=len(owner['samples'])))
    entries[-1]['breakable']=any(g['destruction'] for g in sequences[identity])
def extent(cell,pivot,scale):
    return [max(abs(pivot[n]),abs(cell[n]-pivot[n]))*scale for n in range(2)]

def bank_extent(identity):
    bank=read(index['banks'][identity])
    return [max(extent(bank['cell'],p,bank['scale'])[n] for p in bank.get('physical_source_contact_by_pose',bank['pivots_by_pose']).values()) for n in range(2)]

for entry in entries:
    extents=[]
    kind=entry['kind']
    if kind=='library':
        for s in read(entry['owner'])['samples']:
            if 'pivot' in s and 'scale' in s:
                extents.append(extent(s['colour']['rect'][2:],s.get('physical_source_contact_px',s['pivot']),s['scale']))
    elif kind in ['prop','door','trap']:
        owner=read(entry['owner'])
        for key in ['intact','openings','destructions','destructions_without_attachments']:
            values=owner.get(key,{})
            for bank in ([values] if isinstance(values,str) else values.values()): extents.append(bank_extent(bank))
        for resource in owner.get('frame_resource_by_pose',{}).values():
            record=assets['resources'][resource];extents.append(extent(record['native_size'],record['pivot'],record['scale']))
    else:
        resource_ids=[entry['asset']] if kind=='resource' else ([assets['water']['mask']] if entry['material']=='water' else list(world['terrain'][entry['material']].values())) if kind=='terrain' else list(world[entry['material']+'_wall_straight'].values())+list(world[entry['material']+'_wall_corner'].values())
        for resource in resource_ids:
            record=assets['resources'][resource];extents.append(extent(record['native_size'],record['pivot'],record['scale']))
        if kind=='wall': extents.append(bank_extent(read(index['wall_destructions'])[entry['material']]))
    entry['extent']=[max(e[n] for e in extents) for n in range(2)] if extents else [0,0]
for kind,resources in [('cliff',world['terrain_cliff']['straight']|world['terrain_cliff']['corner']),('stairs',world['terrain_stairs']['poses'])]:
    # These are existing world selectors, not new assets or art registrations.
    rows=[assets['resources'][identity] for identity in resources.values()]
    entries.append(dict(id='world/'+kind,label=kind,group='terrain',kind=kind,placeable=True,breakable=False,
        extent=[max(extent(row['native_size'],row['pivot'],row['scale'])[n] for row in rows) for n in range(2)]))
output=Path(__file__).resolve().parents[1]/'generated/catalog.json'
output.write_text(json.dumps({'entries':entries},indent=2)+'\n')
(output.parent/'library_sequences.json').write_text(json.dumps(sequences,separators=(',',':'))+'\n')
report={'families':dict(Counter(e['group'] for e in entries)), 'placeable':sum(e['placeable'] for e in entries),
        'unregistered':[{'id':e['id'],'reason':e['reason']} for e in entries if not e['placeable']],
        'destruction_selectors':sum(e['breakable'] for e in entries)}
(output.parent/'unregistered_samples.json').write_text(json.dumps(missing_samples,indent=2)+'\n')
(output.parent/'catalog_coverage.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='unregistered'}));print('Missing registration:',len(report['unregistered']))
