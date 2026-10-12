"""Read-only topology study: visible cliff/stair faces separate painted floors."""
from pathlib import Path
from collections import deque,Counter
from functools import lru_cache
import json,re
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
authoring=Path('/home/tommaso/Dev/NDClient/authoring');media=authoring.parent/'.media'
u=json.loads((ROOT/'generated/unity_reference.json').read_text());sources=json.loads((ROOT/'generated/unity_sources.json').read_text())
index=json.loads((authoring/'environment/index.json').read_text())
@lru_cache(None)
def packet(identity):
    info=sources[identity]
    owner=json.loads((authoring/index['library'][info['asset']]).read_text());s=owner['samples'][info['samples'][0]]
    g=s['surface']['geometry'];r=s['surface']['geometry_region'];arr=np.array(Image.open(media/r['path'].removeprefix('/media/')))
    rgb=np.array(Image.open(media/s['colour']['path'].removeprefix('/media/')))
    return s,g,r,arr,rgb
cells=set();cliffs=[];stairs=[]
for l in u['layers']:
    if l['name'] in ['Colliders','Colliders(indestructible)','TileCheck','BuildPreview']:continue
    for row in l['draws']:
        name=u['sprites'][row['sprite']]['name']
        if l['name'].startswith('Ground') and name.startswith('Ground '):cells.add(tuple(row['cell']))
        match=re.match(r'Ground G(\d+)_',name)
        if match and 12<=int(match[1])<=22:
            (stairs if int(match[1]) in [16,17] else cliffs).append(row)
blocked=set()
for row in cliffs+stairs:
    if row['sprite'] not in sources or 'asset' not in sources[row['sprite']]:continue
    s,g,rect,depth,rgba=packet(row['sprite']);sprite=u['sprites'][row['sprite']]
    for du in range(-1,6):
        for dv in range(-1,6):
            px=round(sprite['pivot'][0]+64*(du-dv)*sprite['ppu']/128)
            py=round(sprite['pivot'][1]-32*(du+dv)*sprite['ppu']/128)
            if not(0<=px<256 and 0<=py<256) or rgba[py,px,3]<128:continue
            p=depth[py,px].astype(float);code=p[0]*256+p[1]
            if not code:continue
            z=g['depthRange'][0]+(g['depthRange'][1]-g['depthRange'][0])*(code-1)/65534
            xyz=np.array(g['pixelToRayOrigin'])@np.array([px+.5,py+.5,1])+np.array(g['rayDirection'])*z
            h=(np.array(g['sourceToLocal'])@np.append(xyz,1))[1]
            if .15<h<1.85:blocked.add((row['cell'][0]+du,row['cell'][1]+dv))
remaining=cells-blocked;regions=[];membership={}
while remaining:
    first=remaining.pop();region=[first];queue=deque([first])
    while queue:
        x,y=queue.popleft()
        for p in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
            if p in remaining:remaining.remove(p);queue.append(p);region.append(p)
    i=len(regions);regions.append(region)
    for p in region:membership[p]=i
print('cells',len(cells),'blocked',len(blocked),'regions',len(regions),'sizes',Counter(map(len,regions)).most_common(20))
for row in stairs:
    x,y=row['cell'];low=membership.get((x,y-1));high=membership.get((x+2,y+4))
    print('stairs',row['cell'],'low',low,len(regions[low]) if low is not None else 0,'high',high,len(regions[high]) if high is not None else 0)
(ROOT/'.captures/height-components.json').write_text(json.dumps({'regions':regions,'blocked':list(blocked),'stairs':[r['cell'] for r in stairs]}))
