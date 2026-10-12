"""Convert original Unity placements to passive Godot rows, retaining provenance.
Art and authoring are read in place. No source files are written.
"""
from pathlib import Path
from collections import defaultdict, Counter
import json, math
ROOT=Path(__file__).resolve().parents[1]
AUTHORING=Path('/home/tommaso/Dev/NDClient/authoring')
source=json.loads((ROOT/'generated/unity_reference.json').read_text())
index=json.loads((AUTHORING/'environment/index.json').read_text())
sequences=json.loads((ROOT/'generated/library_sequences.json').read_text())
lookup=defaultdict(list);owners={}
for asset,path in index['library'].items():
    owner=json.loads((AUTHORING/path).read_text());owners[asset]=owner
    for i,sample in enumerate(owner['samples']):
        lookup[Path(sample['colour']['path']).name.casefold()].append((asset,i,sample))
views=['e','s','w','n'];directions=['east','north','west','south']
resolved={};unmapped=[];limited=[]
for identity,sprite in source['sprites'].items():
    path=Path(sprite['path'])
    matches=lookup[path.name.casefold()]
    if len({m[0] for m in matches})>1:
        # Animated files are named 0001.png in many unrelated folders. Resolve
        # their original folder suffix, never their basename alone.
        parts=[p.casefold() for p in path.parts]
        def score(match):
            candidate=[p.casefold() for p in Path(match[2]['colour']['path']).parts]
            n=0
            for a,b in zip(reversed(parts),reversed(candidate)):
                if a!=b:break
                n+=1
            return n
        best=max(map(score,matches));matches=[m for m in matches if score(m)==best]
    exact=[m for m in matches if m[2]['colour']['rect']==sprite['rect']]
    if exact:matches=exact
    if len({m[0] for m in matches})>1 or not matches:
        if '/Characters/' in sprite['path'] or '/Equipment/' in sprite['path']:continue
        unmapped.append({'sprite':identity,'path':sprite['path'],'reason':'No unambiguous surviving authoring sample'})
        # Original Unity registration remains usable without claiming depth or
        # normals which the surviving authoring does not supply.
        records=[]
        for q in range(4):
            p=path
            if path.stem[-2:-1]=='_':
                initial=path.stem[-1].lower();p=path.with_name(path.stem[:-1]+views[(views.index(initial)+q)%4].upper()+path.suffix)
            records.append({'path':str(p),'rect':sprite['rect'],'native_size':sprite['rect'][2:],'pivot':sprite['pivot'],'scale':128/sprite['ppu']})
        resolved[identity]={'records':records,'pivot':sprite['pivot'],'scale':128/sprite['ppu'],'name':sprite['name'],'extent':[512,512]}
        continue
    asset,i,sample=matches[0]
    base_view=sample.get('source_view','e');base_view=base_view if base_view in views else 'e'
    choices=[]
    axes=['state','frame_index','variant_index','variant_name','pitch_degrees','aim_row']
    for q in range(4):
        wanted=views[(views.index(base_view)+q)%4]
        candidates=[j for j,s in enumerate(owners[asset]['samples']) if s.get('source_view')==wanted and all(s.get(a)==sample.get(a) for a in axes)]
        choices.append(candidates[0] if candidates else i)
    if len(set(choices))<4:limited.append({'sprite':identity,'asset':asset,'samples':choices})
    sequence=next((j for j,s in enumerate(sequences[asset]) if any(i in ids for ids in s['views'].values())),0)
    pivot=sample.get('physical_source_contact_px',sample.get('pivot',sprite['pivot']))
    if asset=='fantasy.ground.g16':
        pivot=json.loads((AUTHORING/'world.json').read_text())['terrain_stairs']['contacts_px'][base_view][0]
    resolved[identity]={'asset':asset,'samples':choices,'sequence':sequence,'orientation':directions[views.index(base_view)],'pivot':pivot,'scale':128/sprite['ppu'],'name':sprite['name'],'extent':[max(pivot[0],sprite['rect'][2]-pivot[0])*128/sprite['ppu'],max(pivot[1],sprite['rect'][3]-pivot[1])*128/sprite['ppu']]}
    if asset=='fantasy.ground.g16':resolved[identity]['contact_override']=[json.loads((AUTHORING/'world.json').read_text())['terrain_stairs']['contacts_px'][views[(views.index(base_view)+q)%4]][0] for q in range(4)]

helper=['Colliders','Colliders(indestructible)','TileCheck','BuildPreview']
rows=[];counts=Counter();stair_rows=[]
for layer in source['layers']:
    if layer['name'] in helper or not layer['enabled']:continue
    for draw in layer['draws']:
        if draw['sprite'] not in resolved:continue
        info=resolved[draw['sprite']];sprite=source['sprites'][draw['sprite']]
        u,v=draw['cell'];m=layer['matrices'][draw['matrix']]
        # Convert the Unity visual pivot into the existing physical contact,
        # accounting for original127PPU imports and affine shadow transforms.
        dx=(info['pivot'][0]-sprite['pivot'][0])*info['scale'];dy=(info['pivot'][1]-sprite['pivot'][1])*info['scale']
        px=(u-v)*64+layer['position']['x']*128+m['e03']*128+m['e00']*dx-m['e01']*dy
        py=-(u+v+1)*32-layer['position']['y']*128-m['e13']*128-m['e10']*dx+m['e11']*dy
        x=px/128+py/64;z=py/64-px/128
        name=info['name'];layer_name=layer['name']
        # Negative Unity sorting order also contains upright basement walls.
        # Only actual ground/painted ground overlays belong to the floor pass.
        is_ground=name.startswith(('Ground ', 'Shadow')) or 'Shadows' in layer_name or layer_name in ['Water','Foam']
        cliff=name.startswith(tuple('Ground G'+str(n)+'_' for n in [12,13,14,15,18,19,20,21,22]))
        stairs=name.startswith(('Ground G16_','Ground G17_'))
        role='terrain' if is_ground and not cliff and not stairs else ('cliff' if cliff else 'body')
        kind='stairs' if stairs else ('terrain' if role=='terrain' else 'library')
        row={'id':f"unity:{layer['id']}:{u}:{v}",'kind':kind,'source_sprite':draw['sprite'],'position':[round(x,6),round(z,6)],'base_height_steps':0,'support_id':'ground','layer':layer['order'],'sort_role':role,'source_layer':layer_name,'source_cell':[u,v]}
        if 'asset' in info:row.update(asset=info['asset'],sequence=info['sequence'],orientation=info['orientation'])
        row['walkable']=name.startswith('Ground ') and not name.startswith('Ground G') and layer_name.startswith('Ground')
        if stairs:row['walkable']=True
        row['batchable']=role=='terrain' and (name.startswith('Ground ') or name.startswith('Shadow') or 'Shadows' in layer_name or layer_name in ['Water','Foam'])
        if layer_name=='Water':row['water_surface']=True;row['walkable']=False
        if 'Shadows' in layer_name or name.startswith('Shadow') or layer_name=='Foam':row['walkable']=False
        if layer_name.startswith('Roof'):row['roof']=True
        rgba=[layer['color'][c]*layer['colors'][draw['color']][c] for c in ['r','g','b','a']]
        if rgba!=[1,1,1,1]:row['tint']=rgba
        affine=[m['e00'],-m['e10'],-m['e01'],m['e11']]
        if affine!=[1,0,0,1]:row['affine']=affine;row['ground_projection']=True
        rows.append(row);counts[layer_name]+=1
        if stairs:stair_rows.append(row)
# Scene SpriteRenderer objects carry their original world hierarchy transform.
for obj in source['objects']:
    if obj['sprite'] not in resolved or not obj['enabled'] or obj['name']=='Collider':continue
    transform=obj.get('world_transform')
    if not transform or not transform[6]:continue
    info=resolved[obj['sprite']];sprite=source['sprites'][obj['sprite']]
    if '/Characters/' in sprite['path'] or '/Equipment/' in sprite['path']:continue
    a,b,c,d,x,y,_=transform
    dx=(info['pivot'][0]-sprite['pivot'][0])*info['scale'];dy=(info['pivot'][1]-sprite['pivot'][1])*info['scale']
    px=x*128+a*dx-c*dy;py=-y*128-b*dx+d*dy
    row={'id':'unity:object:'+str(obj['id']),'kind':'library','source_sprite':obj['sprite'],
         'position':[px/128+py/64,py/64-px/128],'base_height_steps':0,'support_id':'ground','layer':obj['order'],
         'sort_role':'body','source_layer':'Scene objects','source_cell':[x+2*y-0.5,-x+2*y-0.5],'source_name':obj['name']}
    if 'asset' in info:row.update(asset=info['asset'],sequence=info['sequence'],orientation=info['orientation'])
    tint=[obj['color'][k] for k in ['r','g','b','a']]
    if tint!=[1,1,1,1]:row['tint']=tint
    if [a,-b,-c,d]!=[1,0,0,1]:row['affine']=[a,-b,-c,d]
    rows.append(row);counts['Scene objects']+=1

# Source TileCheck marks building interiors. Connected cells identify a
# building for roof/wall composition; this helper supplies no invented height.
interior=set(tuple(r['cell']) for l in source['layers'] if l['name']=='TileCheck' for r in l['draws'])
buildings=[];membership={};remaining=set(interior)
while remaining:
    first=min(remaining);remaining.remove(first);component={first};todo=[first]
    while todo:
        u,v=todo.pop()
        for p in [(u+1,v),(u-1,v),(u,v+1),(u,v-1)]:
            if p in remaining:remaining.remove(p);component.add(p);todo.append(p)
    identity='building:'+str(len(buildings));buildings.append((identity,component))
    for p in component:membership[p]=identity
for row in rows:
    name=resolved[row['source_sprite']]['name'];u,v=row['source_cell']
    if name.startswith('Roof '):
        footprint=(round(u-2),round(v-2))
        building=membership.get(footprint)
        if not building:
            nearest=min(((abs(p[0]-footprint[0])+abs(p[1]-footprint[1]),identity) for identity,component in buildings for p in component),default=(999,''))
            if nearest[0]<=3:building=nearest[1]
        if building:row['building_id']=building
    elif name.startswith('Wall ') or row['source_layer']=='Scene objects':
        building=membership.get((round(u),round(v)))
        if building:row['building_id']=building

# Height corrections are explicit scene data; source tile layers never imply Z.
corrections_path=ROOT/'unity_elevation.json'
corrections=json.loads(corrections_path.read_text()) if corrections_path.exists() else {'regions':[]}
def inside(p,polygon):
    result=False;j=len(polygon)-1
    for i,a in enumerate(polygon):
        b=polygon[j]
        if (a[1]>p[1])!=(b[1]>p[1]) and p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]:result=not result
        j=i
    return result
ground_beds={}
for row in rows:
    # These source layers form one continuous river. The terrace polygons
    # describe land; applying them to the river produces elevated water strips
    # which happen to look aligned only in the original painted quarter.
    if row.get('water_surface') or row['source_layer']=='Foam':continue
    for region in corrections['regions']:
        if row['kind'] in region.get('exclude_kinds',[]) or row['sort_role'] in region.get('exclude_roles',[]):continue
        if inside(row['source_cell'],region['polygon']):
            if row['kind']=='terrain' and row.get('walkable'):
                cell=tuple(round(p+0.489921) for p in row['position'])
                if cell not in ground_beds or row['layer']<ground_beds[cell]['layer']:
                    ground_beds[cell]=dict(row)
            elif row['sort_role']=='cliff':
                # The flat source painting sometimes uses a cliff-only cell.
                # Once lifted, its former footprint still needs a ground bed
                # on rear views; reuse the existing earth tile there as well.
                cell=tuple(round(p+0.489921) for p in row['position'])
                ground_beds.setdefault(cell,{'kind':'terrain','material':'earth','position':[c-0.489921 for c in cell],
                    'base_height_steps':0,'support_id':'ground','layer':-100,'walkable':True})
            height=region['height'];row['base_height_steps']=height;row['position']=[p+height for p in row['position']];row['elevation_region']=region['id']
            break
# Lifting a painted tile also shifts its physical footprint. Retain its
# original lowest ground sample under that footprint, rather than opening a
# hole in the surrounding floor when the camera turns around.
for cell,bed in ground_beds.items():
    bed.update(id=f"closure:original-bed:{cell}",layer=-100,correction='retain-ground-below-lifted-painting')
    rows.append(bed)
# The observed2-step roof-to-wall offset is a physical mount. All pieces
# of one roof inherit their building floor, including overhanging eaves.
building_heights={identity:0 for identity,_ in buildings}
for row in rows:
    if row.get('building_id') and not resolved[row['source_sprite']]['name'].startswith('Roof '):
        building_heights[row['building_id']]=max(building_heights[row['building_id']],row['base_height_steps'])
for row in rows:
    if row.get('source_sprite') and resolved[row['source_sprite']]['name'].startswith('Roof '):
        height=building_heights.get(row.get('building_id'),row['base_height_steps'])+2
        offset=height-row['base_height_steps']
        row['base_height_steps']=height
        row['position']=[p+offset for p in row['position']]
        row['roof']=True;row['elevation_offset']=2

# Complete missing roof faces from the original footprint and kit. The
# painting advances both cell axes by one for each rising roof band. Match
# existing pieces to cardinally eroded footprint rings; retain their art.
roof_repairs=[]
source_by_name={value['name']:key for key,value in resolved.items()}
face_offsets={'east':(1,0),'west':(-1,0),'north':(0,1),'south':(0,-1)}
roof_faces={'a8':{'E':{'south'},'S':{'west'},'W':{'north'},'N':{'east'}},
            'a6':{'S':{'south','west'},'E':{'south','east'},'W':{'north','west'},'N':{'north','east'}}}
def add_roof_piece(identity,u,v,rise,floor_height,name):
    key=source_by_name[name];info=resolved[key];sprite=source['sprites'][key]
    source_u=u+rise;source_v=v+rise
    dx=(info['pivot'][0]-sprite['pivot'][0])*info['scale'];dy=(info['pivot'][1]-sprite['pivot'][1])*info['scale']
    px=(source_u-source_v)*64+dx;py=-(source_u+source_v+1)*32+dy;height=floor_height+rise
    rows.append({'id':f"unity:roof-closure:{identity}:{rise}:{u}:{v}:{name}",'kind':'library','source_sprite':key,
        'asset':info['asset'],'sequence':info['sequence'],'orientation':info['orientation'],
        'position':[px/128+py/64+height,py/64-px/128+height],'base_height_steps':height,
        'support_id':identity,'building_id':identity,'roof':True,'layer':11,'sort_role':'body',
        'source_layer':'Roof closure','source_cell':[source_u,source_v],'correction':'complete-original-roof'})
def lift_roof(row,rise,floor_height):
    height=floor_height+rise;offset=height-row['base_height_steps']
    row['base_height_steps']=height;row['position']=[p+offset for p in row['position']];row['elevation_offset']=rise
for identity,component in buildings:
    existing=[r for r in rows if r.get('building_id')==identity and resolved[r['source_sprite']]['name'].startswith('Roof ')]
    families={resolved[r['source_sprite']]['asset'] for r in existing if 'asset' in resolved[r['source_sprite']]}
    floor_height=building_heights[identity];before_count=len(rows);lifted=0
    if families and families.issubset({'fantasy.roof.a6','fantasy.roof.a8','fantasy.roof.a7'}):
        rings=[];mask=set(component)
        while mask:
            boundary={p:{face for face,(du,dv) in face_offsets.items() if (p[0]+du,p[1]+dv) not in mask} for p in mask}
            rings.append({p:faces for p,faces in boundary.items() if faces})
            mask={p for p,faces in boundary.items() if not faces}
        covered=defaultdict(set)
        for row in existing:
            family=row['asset'].split('.')[-1];view=resolved[row['source_sprite']]['name'][-1]
            matches=[]
            for ring,boundary in enumerate(rings):
                rise=2+ring;p=tuple(int(c-rise) for c in row['source_cell'])
                faces=roof_faces.get(family,{}).get(view,set())
                if p in boundary and (family=='a7' or faces.issubset(boundary[p])):matches.append((ring,p,faces))
            if not matches:continue
            ring,p,faces=matches[-1]
            lift_roof(row,2+ring,floor_height);lifted+=ring>0
            covered[(ring,p)].update(rings[ring][p] if family=='a7' else faces)
        for ring,boundary in enumerate(rings):
            for (u,v),faces in sorted(boundary.items()):
                missing=set(faces)-covered[(ring,(u,v))]
                while missing:
                    pair=next(((view,parts) for view,parts in roof_faces['a6'].items() if parts.issubset(missing)),None)
                    if pair:
                        view,parts=pair;name='Roof A6_'+view
                    else:
                        face=sorted(missing)[0];parts={face};view=next(view for view,fs in roof_faces['a8'].items() if fs==parts);name='Roof A8_'+view
                    add_roof_piece(identity,u,v,2+ring,floor_height,name);missing-=parts
    elif families=={'fantasy.roof.a1','fantasy.roof.a3','fantasy.roof.a8'}:
        # The long western hall uses an8x3 gable: front/rear eaves at2,
        # and its original A3 ridge in the central row at3.
        us=[p[0] for p in component];vs=[p[1] for p in component]
        left,right,bottom,top=min(us),max(us),min(vs),max(vs)
        if top-bottom!=2 or len(component)!=(right-left+1)*3:continue
        for row in existing:
            if row['asset']=='fantasy.roof.a3':lift_roof(row,3,floor_height);lifted+=1
        for u in range(left,right+1):add_roof_piece(identity,u,top,2,floor_height,'Roof A1_W' if u in [left,right] else 'Roof A8_W')
    else:continue
    roof_repairs.append({'building':identity,'source_pieces':len(existing),'added_pieces':len(rows)-before_count,'raised_ridge_pieces':lifted,'floor_height':floor_height})

# Close the explicit terrace volumes with the same authored cliff kit. Keep
# matching original cliff members; add only absent faces. The low earth bed
# remains below the raised surface, avoiding holes on opposite camera views.
terrain_repairs=[]
all_heights={};floor_rows={};tops={}
for r in rows:
    if r['kind']=='terrain' and r.get('walkable'):
        cell=tuple(round(p+0.489921) for p in r['position'])
        height=r['base_height_steps'];key=(cell,height)
        all_heights[cell]=max(all_heights.get(cell,0),height)
        if key not in floor_rows or r['layer']<floor_rows[key]['layer']:floor_rows[key]=r
        if r.get('elevation_region') and (cell not in tops or height>tops[cell]['base_height_steps'] or (height==tops[cell]['base_height_steps'] and r['layer']<tops[cell]['layer'])):tops[cell]=r
for cell,top in tops.items():
    x,z=top['position'];height=int(top['base_height_steps']);region=top['elevation_region']
    for base in range(0,height,2):
        if (cell,base) not in floor_rows:
            bed={'id':f"closure:bed:{cell}:{base}",'kind':'terrain','material':'earth','position':[x,z],
                'base_height_steps':base,'support_id':'ground','layer':-100,'walkable':base==0,'correction':'terrace-earth-bed'}
            rows.append(bed);floor_rows[(cell,base)]=bed
    for base in range(0,height,2):
        edges=[]
        for direction,(dx,dz) in {'east':(1,0),'north':(0,1),'west':(-1,0),'south':(0,-1)}.items():
            if all_heights.get((cell[0]+dx,cell[1]+dz),0)<=base:edges.append(direction)
        if not edges:continue
        # Each2-step face owns the rim immediately above it, including the
        # intermediate rim of a4-step volume. Pointing a lower face directly
        # at the highest floor would create contradictory covering relations.
        upper=floor_rows[(cell,base+2)]
        existing=next((r for r in rows if r.get('sort_role')=='cliff' and r['base_height_steps']==base and abs(r['position'][0]-x)<.12 and abs(r['position'][1]-z)<.12),None)
        if existing:
            existing['upper_support_id']=upper['id'];continue
        remaining_edges=edges[:];pieces=[]
        while remaining_edges:
            first=remaining_edges.pop(0)
            adjacent=next((edge for edge in remaining_edges if (directions.index(edge)-directions.index(first))%2==1),None)
            piece=[first]
            if adjacent:piece.append(adjacent);remaining_edges.remove(adjacent)
            pieces.append(piece)
        for part,faces in enumerate(pieces):
            rows.append({'id':f"closure:cliff:{cell}:{base}:{part}",'kind':'cliff','position':[x,z],
                'base_height_steps':base,'support_id':'ground','upper_support_id':upper['id'],'boundaries':faces,'orientation':faces[0],
                'layer':0,'correction':'terrace-missing-return'})
        terrain_repairs.append({'region':region,'cell':cell,'base':base,'edges':edges})

# Reuse existing destruction owners for identically named source families.
# The original imported image stays intact; only its authored break bank is
# selected. No destruction is assigned to unrelated tree/prop silhouettes.
for row in rows:
    asset=row.get('asset','');owner='';state='default'
    if asset.startswith('fantasy.wall.'):
        candidate='environment.wall.fantasy_'+asset.split('.')[-1]
        if candidate in index['props']:owner=candidate
    chest={'a1':('environment.chest.fantasy_a1','false'),'a2':('environment.chest.fantasy_a1','true'),
           'a3':('environment.chest.fantasy_a3','false'),'a4':('environment.chest.fantasy_a3','true'),
           'b1':('environment.chest.fantasy_b1','false'),'b2':('environment.chest.fantasy_b1','true')}
    if asset.startswith('fantasy.chest.') and asset.split('.')[-1] in chest:owner,state=chest[asset.split('.')[-1]]
    if owner:row['break_owner']={'kind':'prop','asset':owner,'state':state}

# A cliff's painted upper rim is a component of its support cell. Its lighting
# contact remains at the original base; only the display layer uses that support.
by_id={r['id']:r for r in rows}
for row in rows:
    support=by_id.get(row.get('upper_support_id'))
    if support:
        row['sort_position']=support['position']
        row['sort_height_steps']=support['base_height_steps']

# Source spawn expressed with the same isometric projection.
spawn=[-8.33-2*1.4,-(-8.33)-2*1.4]
rows.append({'id':'player','kind':'actor','position':spawn,'base_height_steps':0,'support_id':'ground','facing':'E','rig':'neuroclient.modular','layer':0})
scene={'id':'smallscale-explore','name':'Smallscale · Exploration','camera_size':12*math.sqrt(2),'camera_focus':[spawn[0],0,spawn[1]],'placements':rows,'source':source['source']}
(ROOT/'generated/unity_map.json').write_text(json.dumps(scene,separators=(',',':')))
(ROOT/'generated/unity_sources.json').write_text(json.dumps(resolved,separators=(',',':')))
report={'placements':len(rows),'bound_destruction_owners':sum('break_owner' in r for r in rows),'layers':counts,'unmapped_registration':unmapped,'limited_view_families':limited,'stairs':[{'cell':r['source_cell'],'position':r['position'],'sprite':r['source_sprite'],'layer':r['source_layer']} for r in stair_rows],'elevation_regions':corrections['regions'],'roof_repairs':roof_repairs,'terrain_returns':terrain_repairs}
(ROOT/'generated/unity_conversion_report.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k not in ['limited_view_families','stairs']},indent=2));print('limited views',len(limited),'stairs',len(stair_rows))
