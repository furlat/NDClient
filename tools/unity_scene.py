"""Read the user's Unity demo as placement data; never modify Unity or artwork."""
from pathlib import Path
import re
import yaml

UNITY = Path('/mnt/c/Users/tommaso/Documents/UnityProjects/SmallscaleExplore')
SCENE = UNITY / 'Assets/SmallScaleInt/Fantasy kingdom Tileset/Example scene/Example scene.unity'

def documents(path):
    for block in re.split(r'^--- !u!', path.read_text(encoding='utf-8-sig'), flags=re.M)[1:]:
        header, body = block.split('\n', 1)
        kind, identity = re.match(r'(\d+) &(-?\d+)', header).groups()
        yield int(kind), int(identity), body

def load_scene():
    result = {}
    for kind, identity, body in documents(SCENE):
        if kind not in [1,4,212,1839735485,483693784,156049354,20,1001]: continue
        data = next(iter(yaml.load(body, Loader=yaml.CSafeLoader).values()))
        result[identity] = (kind, data)
    return result

def guid_index():
    result = {}
    for meta in (UNITY/'Assets/SmallScaleInt/Fantasy kingdom Tileset').rglob('*.meta'):
        with meta.open(encoding='utf-8-sig') as stream:
            header = stream.read(180)
        match = re.search(r'^guid: (\w+)',header,re.M)
        if match: result[match[1]] = meta.with_suffix('')
    return result

if __name__ == '__main__':
    from collections import Counter
    docs = load_scene()
    names = {k:v['m_Name'] for k,(t,v) in docs.items() if t==1}
    transforms = {v['m_GameObject']['fileID']:v for t,v in docs.values() if t==4 and 'm_GameObject' in v}
    for identity,(kind,d) in docs.items():
        if kind==1839735485:
            print(identity,names[d['m_GameObject']['fileID']],len(d['m_Tiles']), 'tile defs',len(d['m_TileAssetArray']))
            print('anchor',d['m_TileAnchor'],'origin',d['m_Origin'],'size',d['m_Size'])
            print('assets',d['m_TileAssetArray'][:3],'sprite',d['m_TileSpriteArray'][:1], 'matrices',d['m_TileMatrixArray'][:2])
    print('sprite renderers',sum(t==212 for t,v in docs.values()))
    print('world objects',[(names.get(v['m_GameObject']['fileID']),v['m_LocalPosition']) for t,v in docs.values() if t==4 and 'm_GameObject' in v][:60])
