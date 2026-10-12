"""Extract source scene drawing records for visual comparison and map conversion."""
from pathlib import Path
from collections import Counter
from functools import lru_cache
import json
import yaml
import struct
import math
from unity_scene import UNITY, SCENE, load_scene, guid_index

OUTPUT=Path(__file__).resolve().parents[1]/'generated'
cache=OUTPUT.parent/'.captures/unity-guid-index.json'
guids={k:Path(v) for k,v in json.loads(cache.read_text()).items()} if cache.exists() else guid_index()
docs=load_scene()
names={k:v['m_Name'] for k,(t,v) in docs.items() if t==1}
transforms={v['m_GameObject']['fileID']:v for t,v in docs.values() if t==4 and 'm_GameObject' in v}
renderers={v['m_GameObject']['fileID']:v for t,v in docs.values() if t==483693784}

@lru_cache(maxsize=None)
def sprite(guid, file_id):
    path=guids[guid]
    metadata=yaml.load(path.with_suffix(path.suffix+'.meta').read_text(),Loader=yaml.CSafeLoader)['TextureImporter']
    with path.open("rb") as stream:
        header=stream.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n": raise ValueError("Expected original PNG: "+str(path))
    size=struct.unpack(">II",header[16:24])
    rect=[0,0,*size]
    pivot=metadata['spritePivot']
    for sub in metadata['spriteSheet']['sprites']:
        if sub.get('internalID')==file_id:
            r=sub['rect'];rect=[r['x'],size[1]-r['y']-r['height'],r['width'],r['height']]
            pivot=sub['pivot'];break
    return {'path':str(path).replace('/mnt/c/','C:/'),'name':path.stem,'rect':rect,
            'pivot':[pivot['x']*rect[2],(1-pivot['y'])*rect[3]],'ppu':metadata['spritePixelsToUnits']}

transforms_by_id={k:v for k,(t,v) in docs.items() if t==4 and 'm_LocalPosition' in v}
@lru_cache(maxsize=None)
def world_transform(identity):
    t=transforms_by_id[identity]
    p=t['m_LocalPosition'];q=t['m_LocalRotation'];scale=t['m_LocalScale']
    angle=2*math.atan2(q['z'],q['w']);c=math.cos(angle);sn=math.sin(angle)
    a,b,cx,d=c*scale['x'],sn*scale['x'],-sn*scale['y'],c*scale['y']
    x,y=p['x'],p['y'];active=docs.get(t.get('m_GameObject',{}).get('fileID'),(0,{}))[1].get('m_IsActive',1)
    parent=t['m_Father']['fileID']
    if parent in transforms_by_id:
        pa,pb,pc,pd,px,py,enabled=world_transform(parent)
        a,b,cx,d,x,y=pa*a+pc*b,pb*a+pd*b,pa*cx+pc*d,pb*cx+pd*d,pa*x+pc*y+px,pb*x+pd*y+py
        active=active and enabled
    return [a,b,cx,d,x,y,bool(active)]
transform_ids={t['m_GameObject']['fileID']:k for k,t in transforms_by_id.items() if 'm_GameObject' in t}

layers=[];sources={};missing=[]
for identity,(kind,data) in docs.items():
    if kind!=1839735485:continue
    go=data['m_GameObject']['fileID'];name=names[go]
    renderer=renderers[go]
    draws=[]
    for i,tile in enumerate(data['m_Tiles']):
        cell=tile['first'];values=tile['second']
        ref=data['m_TileSpriteArray'][values['m_TileSpriteIndex']]['m_Data']
        if not ref.get('guid') or ref['guid'] not in guids:
            missing.append({'layer':name,'cell':cell,'sprite':ref});continue
        key=ref['guid']+':'+str(ref['fileID'])
        if key not in sources:sources[key]=sprite(ref['guid'],ref['fileID'])
        asset=data['m_TileAssetArray'][values['m_TileIndex']]['m_Data']
        draws.append({'cell':[cell['x'],cell['y']], 'sprite':key,
           'tile':guids[asset['guid']].stem if asset.get('guid') in guids else '',
           'matrix':values['m_TileMatrixIndex'],'color':values['m_TileColorIndex']})
    layers.append({'id':identity,'name':name,'order':renderer['m_SortingOrder'], 'enabled':renderer['m_Enabled'],
        'position':transforms[go]['m_LocalPosition'], 'anchor':data['m_TileAnchor'], 'color':data['m_Color'],
        'matrices':[v['m_Data'] for v in data['m_TileMatrixArray']], 'colors':[v['m_Data'] for v in data['m_TileColorArray']],
        'draws':draws})
# Keep non-tile source objects available for the same mapping (props, doors,
# portals); character/UI objects can be classified without losing their origin.
objects=[]
for identity,(kind,data) in docs.items():
    if kind!=212 or "m_GameObject" not in data:continue
    go=data['m_GameObject']['fileID'];ref=data['m_Sprite']
    if ref.get('guid') not in guids:continue
    key=ref['guid']+':'+str(ref['fileID'])
    if key not in sources:sources[key]=sprite(ref['guid'],ref['fileID'])
    objects.append({'id':identity,'name':names.get(go,''),'transform':transforms.get(go,{}),'sprite':key,'order':data['m_SortingOrder'],'color':data['m_Color'],'enabled':data['m_Enabled'],'world_transform':world_transform(transform_ids[go]) if go in transform_ids else None})
# Retain original registrations for unseen sibling views too. A single-view
# scene may never reference the rear roof slopes required after camera rotation.
path_guids={str(path):guid for guid,path in guids.items()}
for entry in list(sources.values()):
    path=Path(entry['path'].replace('C:/','/mnt/c/'))
    if path.stem[-2:-1]!='_' or path.stem[-1] not in 'ENSW':continue
    for view in 'ENSW':
        sibling=path.with_name(path.stem[:-1]+view+path.suffix)
        guid=path_guids.get(str(sibling))
        if guid and guid+':21300000' not in sources:sources[guid+':21300000']=sprite(guid,21300000)

summary={'source':str(SCENE),'layers':[{k:v for k,v in l.items() if k in ['id','name','order','enabled']}|{'count':len(l['draws'])} for l in layers], 'sprites':len(sources),'objects':len(objects),'unresolved':missing}
(OUTPUT/'unity_reference.json').write_text(json.dumps({'source':str(SCENE),'layers':layers,'sprites':sources,'objects':objects},separators=(',',':')))
(OUTPUT/'unity_import_report.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary,indent=2))
