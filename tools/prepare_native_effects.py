"""Adopt the selected native effect closure; never edits the original sources.
Run after reading ASSETS.md. Original Factory/class roots are explicit arguments.
"""
from pathlib import Path
import argparse,re,json
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--factory',type=Path,required=True)
parser.add_argument('--class-source',type=Path,required=True)
parser.add_argument('--class-selection',type=Path,required=True)
args=parser.parse_args()
P=Path(__file__).resolve().parents[1]
F=args.factory
C=args.class_source
D=P/'assets/native_effects'
TEXT={'.tscn','.tres','.gd','.gdshader','.gdshaderinc'}
receipt=[]
def intake(root,first,prefix):
    pending=list(first);seen=set()
    while pending:
        rel=pending.pop()
        if rel in seen:continue
        seen.add(rel);source=root/rel
        if source.is_dir():continue
        if not source.is_file():raise FileNotFoundError(source)
        target=D/prefix/rel;target.parent.mkdir(parents=True,exist_ok=True)
        if source.suffix.lower() in TEXT:
            value=source.read_text();pending.extend(re.findall(r'res://([^"\s]+)',value))
            value=value.replace('res://','res://assets/native_effects/'+prefix+'/')
            target.write_text(value)
        else:target.write_bytes(source.read_bytes())
        receipt.append({'source':str(source),'path':str(target.relative_to(P)),'bytes':source.stat().st_size})
    return seen
intake(C/'authoring/project',['ClassComponents.gd','Strike.gd'],'class_actions')
b='library/lelu/pack_lelu_godot_blood_premium/VFX/'
intake(F,[b+'Scenes/'+n+'.tscn' for n in ['VFX_Blood_Hit_A1','VFX_Blood_Hit_A2','VFX_Blood_Mark_J1','Decal_Blood_Animated_A1']],'factory')
m='library/lelu/pack_lelu_godot_magic_projectiles_premium_demo_project/VFX/'
intake(F,[m+'Scenes/VFX_Cube_projectile.tscn',m+'Scenes/VFX_Hit_cyber.tscn','factory/shaders/energy_palette_v1.gdshader','archive/objects/73/73682ae4aa57cb2f9264cf5550437223fa5c5c0a3129f00096fc640aaefe4091'],'factory')
# Only the two selected liquid source shaders declare a live clock. Preserve
# every equation; explicitly replace that one source clock in this adopted copy.
for name in ['ss_Disolver_subUV_small_Liquid_Treshold_p.gdshader','s_Disolver_small_Liquid_p_Treshold_ds.tres']:
    p=D/'factory'/b/'shaders'/name;s=p.read_text()
    assert s.count('TIME')==1
    s=s.replace('TIME','native_effect_seconds').replace('shader_type spatial;', 'shader_type spatial;\nuniform float native_effect_seconds = 0.0;')
    s=re.sub(r'^graph_offset =.*\n','',s,flags=re.MULTILINE)
    p.write_text(s)
# One native composition, view-dependent original half planes. No duplicate
# particles or source clock. Only the adopted copies acquire these adapters.
class_script=D/'class_actions/ClassComponents.gd'
v=class_script.read_text()
v=v.replace('var mat = StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED\n  mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color = Color(.83,.83,.83,.65)', 'var mat = ShaderMaterial.new(); mat.shader = load("res://presentation/native_effect_mote.gdshader")\n  mat.set_shader_parameter("source_colour", Color(.83,.83,.83,.65))')
v=v.replace('motes[i].material_override.albedo_color = Color(.88,.88,.88,alpha)', 'motes[i].material_override.set_shader_parameter("source_colour", Color(.88,.88,.88,alpha))')
class_script.write_text(v)
flow=D/'class_actions/Flow.gdshader';v=flow.read_text()
v=v.replace('varying vec3 world_p;', 'uniform vec3 source_origin=vec3(0.0);\nvarying vec3 world_p;\nvarying float requested_side;')
v=v.replace('void vertex(){ world_p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }', 'void vertex(){ world_p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; requested_side=(CAMERA_VISIBLE_LAYERS & (1u<<19u))!=0u ? 1.0 : ((CAMERA_VISIBLE_LAYERS & (1u<<18u))!=0u ? -1.0 : side); }')
v=v.replace('dot(world_p.xz,camera_ground)', 'dot(world_p.xz-source_origin.xz,camera_ground)').replace('side < -0.5','requested_side < -0.5').replace('side > 0.5','requested_side > 0.5')
flow.write_text(v)
# Strike keeps the authored mesh/shader equations. Only its selected pose path
# and source-clip sampling rate become caller inputs, matching the recovered
# weapon_trail_media contact retiming. Missing measured points omit the smear.
strike=D/'class_actions/Strike.gd';v=strike.read_text()
v=v.replace('var paths=[]', 'var paths=[]\nvar native_path_rate=12.0\nvar native_scale_x=1.0')
v=v.replace('var f=clampf(t*12.,0.,14.);var p0=paths[heading][int(f)];var p1=paths[heading][mini(int(f)+1,14)]',
 'var f=clampf(t*native_path_rate,0.,float(paths[heading].size()-1));var p0=paths[heading][int(f)];var p1=paths[heading][mini(int(f)+1,paths[heading].size()-1)]')
v=v.replace('var sx=(p.x-64.)*2.;', 'var sx=(p.x-64.)*2.*native_scale_x;')
v=v.replace('func set_age(t:float):', """func path_available(t:float)->bool:
 var f=clampf(t*native_path_rate,0.,float(paths[heading].size()-1))
 return paths[heading][int(f)]!=null and paths[heading][mini(int(f)+1,paths[heading].size()-1)]!=null
func set_age(t:float):""")
v=v.replace('  for j in range(24):', """  for j in range(25):
   var tt=lerpf(old,latest,float(j)/24.)
   if not path_available(tt) or not path_available(tt-.008) or not path_available(tt+.008):
    trail.visible=false
    return
  for j in range(24):""")
strike.write_text(v)
records={}
base={'kind':'class_component','script':'res://assets/native_effects/class_actions/ClassComponents.gd','sample_hz':32,'canvas':[384,384],'pivot':[192,249.6],'pixels_per_unit':64*2**.5,'camera_target':[0,.9*.816496580927726,0],'source':str(C/'authoring/project/ClassComponents.gd'),'qualification':'Exact selected source mechanisms; native final-frame comparison pending.'}
for id,kind,duration,loop,palette,media in [
 ('class.action_surge','burst',28/32,False,['#496c84','#92b9cb','#ddbc89'],['class.action_surge.burst-q0-back','class.action_surge.burst-q0-front']),
 ('class.second_wind','heal',48/32,False,['#3e6457','#72a582','#c4d2a3'],['class.second_wind.heal-q0-back','class.second_wind.heal-q0-front']),
 ('class.rage.mantle','mantle',64/32,True,[],['class.rage.mantle-q0-back','class.rage.mantle-q0-front']),
 ('class.rage.ground','ground',64/32,True,[],['class.rage.ground-q0-ground']),
 ('class.frenzy.ground','ground',64/32,True,[],['class.frenzy.ground-q0-ground']),
]:
    # Selected palette comes from original conversion record, never guessed.
    old=json.loads(args.class_selection.read_text())
    family=id.split('.')[1]
    palette=next(r['palette'] for r in old['conversions'] if r['selected'].startswith(family+'/'))
    records[id]={**base,'id':id,'properties':{'kind':kind,'side_name':'all','quadrant':0},'capture_halves':['all'] if kind=='ground' else ['back','front'],'duration':duration,'loop':loop,'media_ids':media,'palette':{'operator':'class_neutral','colors':palette,'neutral_levels':[26,49,78,109,143,177,211,239],'source':str(C/'authoring/pack.py'),'mapping_source':str(C/'preview.js')},'requirements':['production_painter_integration']}
impact_palette=next(r['palette'] for r in old['conversions'] if r['selected']=='martial/impact-q0-all.png')
records['class.martial.impact']={**base,'id':'class.martial.impact','kind':'authored_script',
 'script':'res://assets/native_effects/class_actions/Strike.gd','source':str(C/'authoring/project/Strike.gd'),
 'properties':{'kind':'impact','heading':0},'duration':24/32,'loop':False,
 'canvas':[256,256],'pivot':[128,185.6],'media_ids':['class.martial.impact'],
 'palette':{'operator':'class_neutral','colors':impact_palette,'neutral_levels':[26,49,78,109,143,177,211,239],
 'source':str(C/'authoring/pack.py'),'mapping_source':str(C/'preview.js')},
 'requirements':['production_painter_integration'],
 'qualification':'Original Strike impact plane, texture,18shards and explicit source animation; selected original palette.'}
records['class.martial.slash']={**records['class.martial.impact'], 'id':'class.martial.slash',
 'properties':{'kind':'slash','heading':0}, 'duration':32/32, 'canvas':[384,384], 'pivot':[192,249.6],
 'media_ids':['class.martial.melee1.attack1'], 'camera_relative':True, 'weapon_path':True,
 'qualification':'Original Strike24-segment smear and source clock; caller supplies the actual measured weapon path, clip FPS/contact retiming and horizontal scale for current rig/facing.'}
for ident,name,duration,emitters in [
 ('blood.hit_a1','VFX_Blood_Hit_A1',1.5,['bloodpop','mist']),
 ('blood.hit_a2','VFX_Blood_Hit_A2',1.0,['bloodpop','mist','splatter2']),
 ('blood.deposit_j1','VFX_Blood_Mark_J1',8.0,[]),
 ('blood.deposit_a1','Decal_Blood_Animated_A1',4.0,[])]:
 records[ident]={'id':ident,'kind':'scene','scene':'res://assets/native_effects/factory/'+b+'Scenes/'+name+'.tscn','source':str(F/b/'Scenes'/(name+'.tscn')),'sample_hz':60,'duration':duration,'loop':False,'animations':[{'path':'AnimationPlayer','clip':'Init'}],'emitters':[{'path':path,'seed':73000+i,'fixed_fps':60} for i,path in enumerate(emitters)],'shader_clocks':[{'path':path,'uniform':'native_effect_seconds'} for path in emitters if path!='mist'],'canvas':[384,384],'pivot':[192,249.6],'pixels_per_unit':64*2**.5,'camera_target':[0,.9*.816496580927726,0],'palette':{},'requirements':['production_painter_integration','native_surface_lighting']+(['depth_receiver'] if 'deposit' in ident else []),'qualification':'Original complete Lelu source; new response assignment and production surface qualification pending.'}
for ident in ['blood.hit_a1','blood.hit_a2']: records[ident]['actor_partition']=True
# Original ground counterpart is a PlaneMesh. Register its existing centre on
# the caller's declared support contact; preserve its geometry and animation.
ground=records['blood.deposit_a1']
ground.update({'scene_offset':[0,-.0879795,1.8917],'canvas':[640,640],
 'pivot':[320,320], 'camera_target':[0,0,0], 'source_surface':'plane',
 'material_resources':[{'path':'Blood_Animated_1','parameter':'Dissolver_Texture'}],
 'shader_clocks':[{'path':'Blood_Animated_1','uniform':'native_effect_seconds'}],
 'qualification':'Original ground PlaneMesh with original dissolve/normal/roughness animation; registered at the supplied support contact.'})
for phase in ['travel','impact']:
    contract=json.loads((F/('recipes/data/official_windows_validation_20261008/magic_missile-default-'+phase+'-E.json')).read_text())
    spec=contract['components'][0]; inp=spec['input']
    def paths(value):
        if isinstance(value,str):return value.replace('res://','res://assets/native_effects/factory/')
        if isinstance(value,list):return [paths(v) for v in value]
        if isinstance(value,dict):return {k:paths(v) for k,v in value.items()}
        return value
    ident='spell.magic_missile.'+phase
    records[ident]={'id':ident,'kind':'scene','scene':paths(inp['scene']),'source':str(F/inp['scene'].removeprefix('res://')),'sample_hz':144,'duration':contract['clock']['capture_ticks'][-1]/144,'loop':phase=='travel','animations':inp['native_animations'],'emitters':[{**{k:v for k,v in e.items() if k in ['seed','fixed_fps']},'path':e['path'].removeprefix('Donor/')} for e in contract['emitters']],'shader_clocks':[], 'scene_scale':inp['scale'],'scene_offset':inp['local_offset'],'scene_rotation_degrees':spec.get('rotation_degrees',[0,0,0]),'node_properties':inp.get('node_properties',{}),'material_rules':paths(inp['material_rules']),'suppressed_lights':['OmniLight3D'],'canvas':[256,256],'pivot':[128,256],'pixels_per_unit':64*2**.5,'camera_target':[0,.75,0],'palette':{'operator':'factory_cie',**paths(contract['palette_pass'])},'requirements':['production_painter_integration','effect_light_binding','native_palette_parity'],'media_ids':['lelu.magic-missile.rune-dart-lifecycle-256.godot-cie-lab-force-wine10-capture8-final-block2.temporal16-10-18.v1'],'phase':phase,'qualification':'Factory selected donor/seed/material recipe; native production export parity explicitly pending in source recipe. No donor lights imported.'}
for record in records.values():
    record['preload_paths']=[record.get('scene',record.get('script'))]
    if record['kind']=='class_component':
        record['preload_paths'] += ['res://assets/native_effects/class_actions/Flow.gdshader','res://presentation/native_effect_mote.gdshader','res://assets/native_effects/class_actions/vfx_1/arc_charge/textures/flow_noise.tres']
    if record['kind']=='authored_script':
        record['preload_paths'] += ['res://assets/native_effects/class_actions/Strike.gdshader','res://assets/native_effects/class_actions/strike_hit.png']
    if record.get('palette',{}).get('shader'):
        record['preload_paths'].append(record['palette']['shader'])
(P/'authoring/native_effects/index.json').write_text(json.dumps({'sources':records},indent=2)+'\n')
(P/'.runtime').mkdir(exist_ok=True)
(P/'.runtime/native-effect-intake.json').write_text(json.dumps({'files':receipt,'count':len(receipt),'bytes':sum(r['bytes'] for r in receipt),'adaptations':['res:// paths rebased into selected local closure','two explicit blood liquid TIME uniforms renamed to native_effect_seconds; all source equations retained']},indent=2)+'\n')
print(len(receipt),'selected files',sum(r['bytes'] for r in receipt),'source bytes')

# Independent original source used by the native acceptance fixture only.
reference=P/'.runtime/native-effects/reference';reference.mkdir(parents=True,exist_ok=True)
original=(C/'authoring/project/ClassComponents.gd').read_text().replace('res://','res://assets/native_effects/class_actions/').replace('res://assets/native_effects/class_actions/Flow.gdshader','res://.runtime/native-effects/reference/Flow.gdshader')
(reference/'ClassComponents.gd').write_text(original)
(reference/'Flow.gdshader').write_text((C/'authoring/project/Flow.gdshader').read_text())
