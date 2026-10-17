extends SceneTree
## Offline: record native clips into baked bundles (.derived/baked_effects).
## The clip is built exactly as the renderer builds it (Factory.make, the
## renderer's emitter seeds), sampled one recording step per frame, and its
## particle states read back from the GPU. Run with --fixed-fps 60 so every
## frame advances the source exactly one step.
##   --script res://tools/bake_native_effects.gd -- --spells=fireball,fire_bolt [--clips=id,...] [--variants=3]
const Capture=preload("res://presentation/baked_effect_capture.gd")
const Baked=preload("res://presentation/baked_effect.gd")
const Bundle=preload("res://presentation/baked_effect_bundle.gd")
const Factory=preload("res://presentation/native_factory_source.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const PARTICLES=preload("res://presentation/baked_particles.gdshader")
const RATE:=60.0
const MAX_SECONDS:=8.0
const QUIET_FRAMES:=6
## Per particle per frame: 20 recorded values and alive.
const VALUES:=21
const VAT_TEXELS:=6
const NODE_PROPERTIES:={"Node3D":["transform","visible"],"Light3D":["light_energy","light_color","light_size","light_indirect_energy"],
    "OmniLight3D":["omni_range","omni_attenuation"],"Decal":["albedo_mix","emission_energy","modulate","size","upper_fade","lower_fade","normal_fade"],
    "GeometryInstance3D":["transparency"]}
const REMOVED:=["AnimationPlayer","AnimationTree","GPUParticlesCollision3D","GPUParticlesAttractor3D"]
var report:Array=[]
## --float keeps 32-bit recordings (twice the size of the default half floats).
var full_precision:bool=false

func _initialize()->void:run.call_deferred()

func frame()->void:
    await process_frame;await RenderingServer.frame_post_draw

func run()->void:
    var arguments:Dictionary={}
    for argument in OS.get_cmdline_user_args():
        var parts:PackedStringArray=argument.trim_prefix("--").split("=",true,1)
        arguments[parts[0]]=parts[1] if parts.size()>1 else "true"
    if not OS.get_cmdline_args().has("--fixed-fps"):
        push_warning("Run with --fixed-fps 60: recording steps assume a fixed frame delta")
    var clips:Array=_clips(arguments.get("spells","").split(",",false),arguments.get("clips","").split(",",false))
    full_precision=arguments.has("float")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Baked.DIRECTORY))
    var variants:int=clampi(int(arguments.get("variants","3")),1,Baked.MAX_VARIANTS)
    for clip in clips:
        for variant in Baked.MAX_VARIANTS:
            if variant>=variants and FileAccess.file_exists(Baked.path_for(clip.id,variant)):DirAccess.remove_absolute(ProjectSettings.globalize_path(Baked.path_for(clip.id,variant)))
        for variant in variants:
            var started:int=Time.get_ticks_msec()
            var result:Dictionary=await bake(clip,variant)
            result.bake_ms=Time.get_ticks_msec()-started
            report.append(result)
            print("BAKED ",JSON.stringify(result))
    FileAccess.open("res://.runtime/baked-effects-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    quit(0 if report.all(func(entry):return entry.error.is_empty()) else 1)

func _clips(spells:Array,ids:Array)->Array:
    var cache:Dictionary={}
    var owner:Dictionary=Sources.admission(cache)
    var result:Array=[]
    for behavior in owner.index.spells:
        var record:Resource=Sources.find(behavior,cache)
        if record==null:continue
        var selection:Dictionary=record.selection
        var spell:String=str(selection.get("id",behavior))
        for id in selection.get("clip_by_id",{}):
            if spell in spells or behavior in spells or id in ids:result.append(selection.clip_by_id[id])
    return result

func bake(clip:Dictionary,variant:int)->Dictionary:
    var result:Dictionary={"clip":clip.id,"variant":variant,"error":"","gaps":[],"systems":0,"particles":0,"frames":0,"tracks":0,"bytes":0}
    if not clip.get("view_direction",{}).is_empty():
        result.error="view_direction: camera-dependent source parameter";return result
    var capture=Capture.new()
    root.add_child(capture.viewport)
    var holder:=Node3D.new();capture.world.add_child(holder)
    var handle:Dictionary=Factory.make(holder,clip,1<<1,false)
    if not handle.error.is_empty():
        result.error=handle.error;capture.viewport.queue_free();return result
    for index in handle.emitters.size():
        handle.emitters[index].use_fixed_seed=true;handle.emitters[index].seed=Baked.bake_seed(variant)+index
    var materials:Array=Baked.material_locations(handle.root)
    var nodes:Array=handle.root.find_children("*","Node3D",true,false)
    # Script-driven trails record the emitter's own motion history; they are
    # left for path playback (reported) and never sampled here.
    handle.scripts.clear()
    var emitters:Array=handle.emitters.filter(func(particles):return particles.get_script()==null or not particles.get_script().resource_path.ends_with("Trail3D.gd"))
    var script_trails:Array=handle.emitters.filter(func(particles):return particles not in emitters).map(func(particles):return str(handle.root.get_path_to(particles)))
    for path in clip.get("motion_trails",[]):result.gaps.append("motion_trail:"+str(path))
    for node in handle.root.find_children("*","",true,false):
        if node.get_script()!=null and node.get_script().resource_path.ends_with("Trail3D.gd"):result.gaps.append("script_trail_hidden:"+str(handle.root.get_path_to(node)))
    var world_space:Array=[]
    for particles in emitters:
        var path:String=str(handle.root.get_path_to(particles))
        if not particles.local_coords:world_space.append(path)
        if particles.trail_enabled:result.gaps.append("trail_history:"+path)
        if particles.draw_order in [GPUParticles3D.DRAW_ORDER_LIFETIME,GPUParticles3D.DRAW_ORDER_REVERSE_LIFETIME]:result.gaps.append("lifetime_draw_order:"+path)
        particles.fixed_fps=0;particles.interpolate=false
    capture.bind(emitters)
    handle.root.show()
    var base_frames:int=int(ceil(float(handle.clip.seconds)*RATE))+1
    # Continuous emitters never fall quiet: record one longest lifetime past
    # the clip, which covers every life the clip's own time can start.
    var tail:float=0.0
    for particles in emitters:tail=maxf(tail,particles.lifetime/maxf(0.01,particles.speed_scale if particles.speed_scale>0 else float(handle.emitter_speeds.get(particles.get_instance_id(),1.0))))
    var last_frame:int=mini(base_frames+int(ceil(tail*RATE)),int(MAX_SECONDS*RATE))
    var total:int=0
    var offsets:Array=[]
    for particles in emitters:offsets.append(total);total+=int(particles.amount)
    var states:Array=[]
    var snapshots:Array=[]
    var quiet:int=0
    var step:int=0
    while true:
        var seconds:float=float(step)/RATE
        Factory.sample(handle,seconds,0.0 if step==0 else 1.0/RATE,seconds)
        snapshots.append(_snapshot(handle.root,nodes,materials))
        capture.update_reference()
        await frame()
        var data:PackedFloat32Array=capture.read_floats()
        var alive:bool=false
        var compact:=PackedFloat32Array();compact.resize(total*VALUES)
        var at:int=0
        for index in emitters.size():
            for number in int(emitters[index].amount):
                var state:Dictionary=capture.particle(data,index,number)
                alive=alive or state.alive
                for c in 20:compact[at+c]=state.values[c]
                compact[at+20]=1.0 if state.alive else 0.0
                at+=VALUES
        states.append(compact)
        step+=1
        quiet=0 if alive else quiet+1
        if step>=base_frames and quiet>=QUIET_FRAMES:break
        if step>=last_frame:
            if alive and last_frame>=int(MAX_SECONDS*RATE):result.gaps.append("truncated_at_seconds:"+str(MAX_SECONDS))
            break
    var frames:int=states.size()
    var tracks:Array=_tracks(snapshots)
    for track in tracks:
        if track.kind=="node" and track.property=="transform":
            var target:Node=handle.root.get_node(track.path)
            for particles in emitters:
                if target==particles or target.is_ancestor_of(particles):result.gaps.append("moving_emitter:"+track.path)
    var systems:Array=[]
    for index in emitters.size():
        var vat:Dictionary=_vat(states,offsets[index],int(emitters[index].amount),frames)
        systems.append({"path":str(handle.root.get_path_to(emitters[index])),"amount":vat.amount,"vat":vat.texture,"first":vat.first,"bounds":vat.bounds,"world_space":not emitters[index].local_coords})
        result.particles+=vat.amount;result.bytes+=vat.amount*VAT_TEXELS*vat.texture.get_width()*(16 if full_precision else 8)
    handle.root.free();capture.viewport.queue_free()
    var template:Dictionary=_template(clip,systems,tracks,materials.size(),script_trails)
    if not template.error.is_empty():result.error=template.error;return result
    result.gaps.append_array(template.gaps)
    var bundle:=Bundle.new()
    bundle.clip_id=clip.id;bundle.clip_hash=Baked.clip_hash(Baked._comparable(clip))
    bundle.rate=RATE;bundle.frames=frames;bundle.seconds=float(frames-1)/RATE
    bundle.scene=template.scene
    bundle.systems=systems.map(func(system):return {"path":system.path,"amount":system.amount,"vat":system.vat,"first":system.first,"world_space":system.world_space})
    bundle.tracks=tracks;bundle.private_materials=template.private_materials;bundle.gaps=result.gaps
    var error:int=ResourceSaver.save(bundle,Baked.path_for(clip.id,variant))
    if error!=OK:result.error="save failed: "+str(error)
    result.systems=systems.size();result.frames=frames;result.tracks=tracks.size();result.world_space=world_space
    result.track_names=tracks.map(func(track):return (track.path if track.kind=="node" else "material "+str(track.material))+":"+track.property)
    return result

func _snapshot(root_node:Node3D,nodes:Array,materials:Array)->Dictionary:
    var values:Dictionary={}
    for node in nodes:
        if node is GPUParticles3D:continue
        var path:String=str(root_node.get_path_to(node))
        for type in NODE_PROPERTIES:
            if not node.is_class(type):continue
            for property in NODE_PROPERTIES[type]:values["node|"+path+"|"+property]=node.get(property)
    for index in materials.size():
        var material:Material=materials[index].material
        if material is ShaderMaterial and material.shader!=null:
            for uniform in material.shader.get_shader_uniform_list():
                if int(uniform.type)==TYPE_OBJECT:continue
                values["material|"+str(index)+"|"+uniform.name]=material.get_shader_parameter(uniform.name)
        elif material is BaseMaterial3D:
            for property in ["albedo_color","emission","emission_energy_multiplier","uv1_offset"]:
                values["material|"+str(index)+"|"+property]=material.get(property)
    return values

## Values that change over the recording become tracks.
func _tracks(snapshots:Array)->Array:
    var result:Array=[]
    for key in snapshots[0]:
        var changes:bool=false
        for snapshot in snapshots:
            if snapshot.get(key)!=snapshots[0][key]:changes=true;break
        if not changes:continue
        var parts:PackedStringArray=key.split("|")
        var values:Array=snapshots.map(func(snapshot):return snapshot.get(key))
        var blend:bool=typeof(values[0]) in [TYPE_FLOAT,TYPE_VECTOR2,TYPE_VECTOR3,TYPE_VECTOR4,TYPE_COLOR,TYPE_TRANSFORM3D]
        var track:Dictionary={"kind":parts[0],"property":parts[2],"values":values,"blend":blend}
        if parts[0]=="node":track.path=parts[1]
        else:track.material=int(parts[1]);track.kind="material"
        result.append(track)
    return result

## Rows per particle (VAT_TEXELS, as baked_particles.gdshader reads them):
## basis x + origin.x, basis y + origin.y, basis z + origin.z, colour, custom,
## (alive, life start frame). Only particles that are ever alive are kept (in
## order), and only the frames from the first to the last live one.
func _vat(states:Array,first_particle:int,amount:int,frames:int)->Dictionary:
    var kept:Array=[];var first:int=frames;var last:int=-1
    for particle in amount:
        var base:int=(first_particle+particle)*VALUES+20
        var ever:bool=false
        for f in frames:
            if states[f][base]>0.5:
                ever=true;first=mini(first,f);last=maxi(last,f)
        if ever:kept.append(particle)
    if kept.is_empty():
        var empty:=Image.create_empty(1,VAT_TEXELS,false,Image.FORMAT_RGBAH)
        return {"texture":ImageTexture.create_from_image(empty),"first":0,"amount":1,"bounds":AABB(Vector3(-1,-1,-1),Vector3(2,2,2))}
    var width:int=last-first+1
    var values:=PackedFloat32Array();values.resize(width*kept.size()*VAT_TEXELS*4)
    var bounds:=AABB();var has_bounds:bool=false;var reach:float=0.0
    for slot in kept.size():
        var particle:int=kept[slot]
        var start:int=-1;var previous_age:float=-1.0;var was_alive:bool=false
        var row:int=slot*VAT_TEXELS
        for f in range(first,last+1):
            var base:int=(first_particle+particle)*VALUES
            var v:PackedFloat32Array=states[f].slice(base,base+VALUES)
            if v[20]<0.5:
                was_alive=false
                continue
            var age:float=v[17]
            if not was_alive or age<previous_age-0.0001:start=f
            was_alive=true;previous_age=age
            var origin:=Vector3(v[9],v[10],v[11])
            if has_bounds:bounds=bounds.expand(origin)
            else:bounds=AABB(origin,Vector3.ZERO);has_bounds=true
            reach=maxf(reach,maxf(Vector3(v[0],v[1],v[2]).length(),maxf(Vector3(v[3],v[4],v[5]).length(),Vector3(v[6],v[7],v[8]).length())))
            var texels:Array=[[v[0],v[1],v[2],v[9]],[v[3],v[4],v[5],v[10]],[v[6],v[7],v[8],v[11]],[v[12],v[13],v[14],v[15]],[v[16],v[17],v[18],v[19]],[1.0,float(start),0.0,0.0]]
            for k in texels.size():
                var at:int=((row+k)*width+(f-first))*4
                for c in 4:values[at+c]=texels[k][c]
    var image:=Image.create_from_data(width,kept.size()*VAT_TEXELS,false,Image.FORMAT_RGBAF,values.to_byte_array())
    if not full_precision:image.convert(Image.FORMAT_RGBAH)
    return {"texture":ImageTexture.create_from_image(image),"first":first,"amount":kept.size(),"bounds":bounds.grow(reach*2.0+0.1)}

## The runtime scene: the same clip built again at source time 0, with nothing
## left that runs (animation players, scripts, collision) and every emitter
## replaced by recorded playback.
func _template(clip:Dictionary,systems:Array,tracks:Array,material_count:int,script_trails:Array)->Dictionary:
    var result:Dictionary={"error":"","gaps":[],"scene":null,"private_materials":[]}
    var holder:=Node3D.new();root.add_child(holder)
    var handle:Dictionary=Factory.make(holder,clip,1<<1,false)
    if not handle.error.is_empty():result.error="template: "+handle.error;holder.free();return result
    var scene_root:Node3D=handle.root
    var materials:Array=Baked.material_locations(scene_root)
    if materials.size()!=material_count:result.error="template material order differs from the recording";holder.free();return result
    for system in systems:
        var particles:GPUParticles3D=scene_root.get_node(system.path)
        var process:=ShaderMaterial.new();process.shader=PARTICLES
        process.set_shader_parameter("vat",system.vat)
        process.set_shader_parameter("vat_rate",RATE)
        process.set_shader_parameter("vat_frames",system.vat.get_width())
        process.set_shader_parameter("vat_first",system.first)
        particles.amount=system.amount
        particles.process_material=process
        particles.lifetime=1000.0;particles.one_shot=true;particles.explosiveness=1.0;particles.randomness=0.0
        particles.preprocess=0.0;particles.fixed_fps=0;particles.interpolate=false;particles.speed_scale=1.0
        particles.local_coords=true;particles.sub_emitter=NodePath("");particles.amount_ratio=1.0
        particles.emitting=true
    for path in script_trails:scene_root.get_node(path).visible=false
    for node in scene_root.find_children("*","",true,false):
        if REMOVED.any(func(type):return node.is_class(type)):
            node.get_parent().remove_child(node);node.free()
    for node in scene_root.find_children("*","",true,false):
        if node.get_script()!=null:node.set_script(null)
    var private:Array=[]
    for index in materials.size():
        if Baked.bindable(scene_root,materials[index].locations):private.append(index)
        else:result.gaps.append("shared_material:"+str(index))
    for track in tracks:
        if track.kind=="material" and int(track.material) not in private:result.error="tracked material cannot be private: "+str(track.material)
    result.private_materials=private
    holder.remove_child(scene_root)
    for node in scene_root.find_children("*","",true,false):
        node.owner=scene_root;node.scene_file_path=""
    var visited:Dictionary={}
    _unshare(scene_root,visited)
    for node in scene_root.find_children("*","",true,false):_unshare(node,visited)
    var packed:=PackedScene.new()
    var error:int=packed.pack(scene_root)
    scene_root.free();holder.free()
    if error!=OK:result.error="pack failed: "+str(error);return result
    result.scene=packed
    return result

## Scene-local resources are copied on every instantiate (an ArrayMesh copy
## reads its vertex buffers back from the GPU). Embed private copies instead.
func _unshare(object:Object,visited:Dictionary)->void:
    for property in object.get_property_list():
        if not int(property.usage)&PROPERTY_USAGE_STORAGE or int(property.type)!=TYPE_OBJECT:continue
        var value:Variant=object.get(property.name)
        if not value is Resource or value is Script:continue
        if value.resource_local_to_scene:
            var copy:Resource=visited.get(value)
            if copy==null:
                copy=value.duplicate();copy.resource_local_to_scene=false
                visited[value]=copy;visited[copy]=copy
                _unshare(copy,visited)
            object.set(property.name,copy)
        elif not visited.has(value):
            visited[value]=value
            _unshare(value,visited)
