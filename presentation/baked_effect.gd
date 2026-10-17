extends RefCounted
## Baked native clip playback. An occurrence is one instanced scene plus one
## clock texel: emitters read their recorded particle states at the clock's
## source time on the GPU, and recorded node/material values are applied by
## index. There is no simulation, so a late start or a seek draws directly.
const LightUnits=preload("res://presentation/native_light_units.gd")
const Bundle=preload("res://presentation/baked_effect_bundle.gd")
const DIRECTORY:="res://.derived/baked_effects/"
const SLOTS:=256
static var enabled:bool=true
static var _clock_image:Image
static var _clock_texture:ImageTexture
static var _free_slots:Array=[]
static var _clock_dirty:bool=false
static var _bundles:Dictionary={}
static var _requested:Dictionary={}

## Each clip has up to MAX_VARIANTS recordings made with different seeds;
## an occurrence picks one by its effect seed, as the native source varies.
const MAX_VARIANTS:=4

## Emitter seeds of a recording variant (emitter i uses this plus i, as the
## renderer seeds native emitters).
static func bake_seed(variant:int)->int:
    return 1000+variant*7919

static func path_for(clip_id:String,variant:int=0)->String:
    return DIRECTORY+clip_id.replace("/","__")+("" if variant==0 else ".v"+str(variant))+".res"

static func clip_hash(clip:Dictionary)->String:
    return str(JSON.stringify(clip,"",true).hash())

## Threaded load of all of a clip's recordings at once. Returns the array of
## bundles once loaded, null while loading, and false when there is no
## current recording for this clip.
static func request(clip:Dictionary)->Variant:
    if not enabled:return false
    var id:String=clip.get("id","")
    if _bundles.has(id):return _bundles[id]
    if not _requested.has(id):
        var paths:Array=[]
        for variant in MAX_VARIANTS:
            if ResourceLoader.exists(path_for(id,variant)):paths.append(path_for(id,variant))
        if paths.is_empty():_bundles[id]=false;return false
        for path in paths:ResourceLoader.load_threaded_request(path,"",false)
        _requested[id]=paths
    # Results are taken only once every variant has loaded (a taken result
    # is no longer known to the loader).
    for path in _requested[id]:
        var status:int=ResourceLoader.load_threaded_get_status(path)
        if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS:return null
        if status!=ResourceLoader.THREAD_LOAD_LOADED:
            push_warning("Baked native clip failed to load (status %d); using the native source: %s"%[status,path])
            _bundles[id]=false;return false
    var bundles:Array=[]
    for path in _requested[id]:
        var bundle:Resource=ResourceLoader.load_threaded_get(path)
        if bundle==null or bundle.get_script()!=Bundle or bundle.clip_hash!=clip_hash(_comparable(clip)):
            push_warning("Baked native clip is stale; using the native source: "+id)
            _bundles[id]=false;return false
        bundles.append(bundle)
    _bundles[id]=bundles
    return bundles

## The baked recording for this source when it can replace the native one:
## the bundle for `choice` (an effect seed), null while its files load, false
## when the native source plays it. A moving projectile's world-space
## particles trail behind its path and script trails follow it; neither is
## baked yet, so those stay native.
static func ready_for(clip:Dictionary,choice:int=0)->Variant:
    var bundles:Variant=request(clip)
    if not bundles is Array:return bundles
    var bundle:Resource=bundles[0]
    for gap in bundle.gaps:
        if str(gap).begins_with("moving_emitter:") or str(gap).begins_with("script_trail_hidden:"):return false
    if clip.get("stage","")=="travel" and bundle.systems.any(func(system):return system.get("world_space",false)):return false
    return bundles[posmod(choice,bundles.size())]

## Fields the renderer adds per occurrence are not part of the recording.
static func _comparable(clip:Dictionary)->Dictionary:
    var result:Dictionary=clip.duplicate(false)
    result.erase("opacity_uniform")
    return result

static func _ensure_clock()->void:
    if _clock_texture!=null:return
    _clock_image=Image.create_empty(SLOTS,1,false,Image.FORMAT_RGBAF)
    _clock_texture=ImageTexture.create_from_image(_clock_image)
    RenderingServer.global_shader_parameter_set(&"baked_effect_clock",_clock_texture)
    _free_slots=range(SLOTS-1,-1,-1)
    RenderingServer.frame_pre_draw.connect(flush)

## One texture upload per frame for every playing occurrence, before drawing.
static func flush()->void:
    if _clock_dirty:_clock_texture.update(_clock_image);_clock_dirty=false

static func make(parent:Node3D,bundle:Resource,clip:Dictionary,layer_mask:int)->Dictionary:
    _ensure_clock()
    var handle={"root":null,"components":{},"players":[],"emitters":[],"scripts":[],"carriers":[],"clocks":[],"geometry":[],
        "opacity_bindings":[],"particle_units":[],"emitter_speeds":{},"light_units":{},"motion_trails":{},"motion_age":0.0,
        "native_animation_end":0.0,"initialized":true,"age":0.0,"error":"","clip":clip.duplicate(false),"layer_mask":layer_mask,
        "baked":true,"bundle":bundle,"slot":-1,"process_materials":[],"tracks":[],"emission_stop":INF}
    if _free_slots.is_empty():
        handle.error="Baked native clock slots exhausted";return handle
    var started:int=Time.get_ticks_usec()
    handle.slot=_free_slots.pop_back()
    _clock_image.set_pixel(handle.slot,0,Color(0,0,0,0));_clock_dirty=true
    var root:Node3D=bundle.scene.instantiate()
    root.hide()
    parent.add_child(root)
    handle.root=root
    var materials:Array=material_locations(root)
    var copies:Dictionary={}
    for index in bundle.private_materials:
        var copy:Material=materials[index].material.duplicate()
        copies[index]=copy
        for location in materials[index].locations:_bind(root,location,copy)
    for system in bundle.systems:
        var particles:GPUParticles3D=root.get_node(system.path)
        var process:ShaderMaterial=particles.process_material.duplicate()
        process.set_shader_parameter("clock_slot",handle.slot)
        particles.process_material=process
        handle.process_materials.append(process)
    for track in bundle.tracks:
        var target:Object=root.get_node(track.path) if track.kind=="node" else copies.get(int(track.material))
        if target==null:handle.error="Baked track target missing: "+str(track);return handle
        handle.tracks.append({"target":target,"track":track})
    for node in root.find_children("*","",true,false):
        if node is Light3D:
            var shown:bool=node.visible;node.hide()
            node.light_cull_mask=layer_mask;node.layers=layer_mask;node.visible=shown
            if node is OmniLight3D:handle.light_units[node.get_instance_id()]=LightUnits.prepare(node)
        if node is Decal:node.cull_mask=1
        if node is GeometryInstance3D:
            handle.geometry.append({"node":node,"path":str(root.get_path_to(node)),"selected":node.visible and node.layers!=0,"layer_enabled":node.layers!=0})
            if node.layers!=0:node.layers=layer_mask
    var opacity_uniform:String=clip.get("opacity_uniform","")
    if not opacity_uniform.is_empty():
        for index in materials.size():
            var material:Material=copies.get(index,materials[index].material)
            if not material is ShaderMaterial or material.shader==null:continue
            if not material.shader.get_shader_uniform_list().any(func(uniform):return uniform.name==opacity_uniform):continue
            if not copies.has(index):
                handle.error="Baked opacity control is not private: "+opacity_uniform;return handle
            var value=material.get_shader_parameter(opacity_uniform)
            handle.opacity_bindings.append({"material":material,"uniform":opacity_uniform,"native":1.0 if value==null else float(value)})
        if handle.opacity_bindings.is_empty():handle.error="Missing native opacity control: "+str(clip.get("id",""))+" / "+opacity_uniform
    handle.construction_phases={"baked_instantiate":(Time.get_ticks_usec()-started)/1000.0}
    return handle

## Source seconds -> recorded state. The renderer still owns placement,
## opacity envelopes and named hides (Playback.controls).
static func sample(handle:Dictionary,seconds:float)->void:
    var bundle:Resource=handle.bundle
    var frame:float=clampf(seconds*bundle.rate,0.0,float(bundle.frames-1))
    var low:int=int(frame)
    var high:int=mini(low+1,bundle.frames-1)
    var weight:float=frame-float(low)
    if not is_equal_approx(float(handle.age),seconds) or not handle.get("sampled",false):
        _clock_image.set_pixel(handle.slot,0,Color(seconds,0,0,0));_clock_dirty=true
        # Recorded values are source values; restore before applying them so
        # the unit conversion and opacity below never compound.
        LightUnits.restore(handle.light_units)
        for binding in handle.opacity_bindings:binding.material.set_shader_parameter(binding.uniform,binding.native)
        for entry in handle.tracks:
            var track:Dictionary=entry.track
            var values:Array=track.values
            var value:Variant=values[low]
            if track.blend and high!=low:value=_blend(values[low],values[high],weight)
            if track.kind=="node":entry.target.set(track.property,value)
            else:entry.target.set_shader_parameter(track.property,value)
        for binding in handle.opacity_bindings:
            binding.native=float(binding.material.get_shader_parameter(binding.uniform))
        LightUnits.apply(handle.light_units,absf(handle.root.global_basis.get_scale().x))
        handle.age=seconds;handle.sampled=true
    else:
        LightUnits.rescale(handle.light_units,absf(handle.root.global_basis.get_scale().x))

## New particle lives stop at this source time (emitting=false in the source).
static func stop_emission(handle:Dictionary,source_seconds:float)->void:
    if is_equal_approx(float(handle.emission_stop),source_seconds):return
    handle.emission_stop=source_seconds
    var frame:float=source_seconds*float(handle.bundle.rate) if is_finite(source_seconds) else 1000000.0
    for material in handle.process_materials:material.set_shader_parameter("emission_stop_frame",frame)

static func release(handle:Dictionary)->void:
    if int(handle.get("slot",-1))>=0:
        _free_slots.append(handle.slot);handle.slot=-1

static func _blend(a:Variant,b:Variant,weight:float)->Variant:
    match typeof(a):
        TYPE_FLOAT,TYPE_VECTOR2,TYPE_VECTOR3,TYPE_VECTOR4,TYPE_COLOR:return lerp(a,b,weight)
        TYPE_TRANSFORM3D:return a.interpolate_with(b,weight)
    return a

## Every material reachable from the scene's geometry, in a stable order, with
## each place it is bound. Bake and playback use the same traversal.
static func material_locations(root:Node)->Array:
    var order:Array=[]
    var by_material:Dictionary={}
    var nodes:Array=[root]
    nodes.append_array(root.find_children("*","",true,false))
    for node in nodes:
        if not node is GeometryInstance3D:continue
        var path:String=str(root.get_path_to(node))
        var found:Array=[]
        if node.material_override!=null:found.append([{"path":path,"kind":"override"},node.material_override])
        if node is MeshInstance3D and node.mesh!=null:
            for surface in node.mesh.get_surface_count():
                var material:Material=node.get_surface_override_material(surface)
                if material==null:material=node.mesh.surface_get_material(surface)
                if material!=null:found.append([{"path":path,"kind":"surface","surface":surface},material])
        if node is GPUParticles3D:
            for pass_index in node.draw_passes:
                var mesh:Mesh=node.get_draw_pass_mesh(pass_index)
                if mesh==null:continue
                for surface in mesh.get_surface_count():
                    var material:Material=mesh.surface_get_material(surface)
                    if material!=null:found.append([{"path":path,"kind":"pass","pass":pass_index,"surface":surface},material])
        for pair in found:
            var material:Material=pair[1]
            if not by_material.has(material):
                by_material[material]=order.size()
                order.append({"material":material,"locations":[]})
            order[by_material[material]].locations.append(pair[0])
    return order

## True when every location of this material can take a private copy without
## copying vertex data (an ArrayMesh copy reads its buffers back from the GPU).
static func bindable(root:Node,locations:Array)->bool:
    for location in locations:
        if location.kind!="pass":continue
        var node:GPUParticles3D=root.get_node(location.path)
        var mesh:Mesh=node.get_draw_pass_mesh(location.pass)
        if not mesh is PrimitiveMesh and not (node.draw_passes==1 and mesh.get_surface_count()==1):return false
    return true

static func _bind(root:Node,location:Dictionary,material:Material)->void:
    var node:GeometryInstance3D=root.get_node(location.path)
    match location.kind:
        "override":node.material_override=material
        "surface":node.set_surface_override_material(location.surface,material)
        "pass":
            var mesh:Mesh=node.get_draw_pass_mesh(location.pass)
            if mesh is PrimitiveMesh:
                if not mesh.has_meta("baked_private"):
                    mesh=mesh.duplicate();mesh.set_meta("baked_private",true)
                    node.set_draw_pass_mesh(location.pass,mesh)
                mesh.material=material
            else:node.material_override=material
