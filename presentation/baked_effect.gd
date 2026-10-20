extends RefCounted
## Recorded effect playback (the package's `recorded` approach). An occurrence
## is one instanced scene plus one clock texel: emitters read their recorded
## particle states at the clock's source time on the GPU, and recorded
## node/material values are applied by index. There is no simulation, so a
## late start or a seek draws directly. The recordings carry no playback
## shader: each system names its role and this assigns the client's shader.
const LightUnits=preload("res://presentation/native_light_units.gd")
const FORMAT:="res://assets/vfx/format/recording.gd"
const PARTICLES=preload("res://presentation/baked_particles.gdshader")
const TRAILING=preload("res://presentation/baked_trailing_particles.gdshader")
const PATH_TRAIL=preload("res://presentation/baked_path_trail.gdshader")
const SLOTS:=256
## Extra recording variants (beyond each clip's first) load only while this is
## true; Play sets it while no action is playing, so no file lands mid-cast.
static var background_allowed:bool=true
static var _clock_image:Image
static var _clock_texture:ImageTexture
static var _free_slots:Array=[]
static var _clock_dirty:bool=false
static var _bundles:Dictionary={}
static var _requested:Dictionary={}
static var _queue_first:Array=[]
static var _queue_rest:Array=[]
static var _owners:Dictionary={}
static var _loading:String=""
static var _pumping:bool=false
## Loaded bundles whose recorded-state textures are still being created
## (one per frame), and the textures made so far, by bundle.
static var _uploads:Array=[]
static var _pump_frame:int=-1
static var _textures:Dictionary={}
## Process materials with each bundle's constant parameters, by bundle; an
## occurrence copies them and sets only its clock slot and path.
static var _prototypes:Dictionary={}
static var _still_path:ImageTexture
## Columns per second of an occurrence's path history (PATH_RATE in
## baked_path.gdshaderinc).
const PATH_RATE:=60.0
const MAX_PATH_SECONDS:=40.0

## The same recorded seed family shares its physical loader even when a caller
## selects one exact approach. A replaced recording path owns another cache.
static func recording_key(clip:Dictionary)->String:
    var recorded:Array=_recorded_approaches(clip)
    return JSON.stringify([str(clip.get("id","")),recorded.map(func(approach):return [str(approach.id),str(approach.path)])])

static func _recorded_approaches(clip:Dictionary)->Array:
    var result:Array=clip.get("approaches",[]).filter(func(approach):return approach.kind=="recorded")
    result.sort_custom(func(a,b):return int(a.get("variant",0))<int(b.get("variant",0)))
    return result

static func _selected_recordings(clip:Dictionary,bundles:Array,complete:bool)->Variant:
    var exact:String=str(clip.get("approach_id",""))
    if exact.is_empty():return bundles if not bundles.is_empty() else null
    for approach in _recorded_approaches(clip):
        if str(approach.id)!=exact:continue
        for bundle in bundles:
            if str(bundle.resource_path)==str(approach.path):return [bundle]
        return false if complete else null
    return false

## Threaded load of a clip's recorded variants (the package records three
## seeds per clip). Files load one at a time: each carries megabytes of
## states, and several finishing together stall the frame that uploads them.
## Every clip's first variant loads before any further variant, and a clip is
## usable once one variant is uploaded (more variants join as they arrive). A
## clip needed now (`urgent`) moves to the front. Returns the usable bundles,
## null while none is ready yet, and false when the clip has no recording.
static func request(clip:Dictionary,urgent:bool=false)->Variant:
    var id:String=recording_key(clip)
    if _bundles.has(id):return _selected_recordings(clip,_bundles[id],true) if _bundles[id] is Array else _bundles[id]
    if not _requested.has(id):
        var recorded:Array=_recorded_approaches(clip)
        var paths:Array=recorded.map(func(approach):return str(approach.path))
        if paths.is_empty():_bundles[id]=false;return false
        _requested[id]={"paths":paths,"loaded":[],"done":0}
        for path in paths:_owners[path]=id
        _queue_first.append(paths[0]);_queue_rest.append_array(paths.slice(1))
    var owner:Dictionary=_requested[id]
    if urgent:
        for queue in [_queue_first,_queue_rest]:
            var mine:Array=owner.paths.filter(func(path):return path in queue)
            for path in mine:queue.erase(path)
            for index in mine.size():queue.insert(index,mine[index])
        for bundle in owner.loaded:
            if bundle in _uploads:_uploads.erase(bundle);_uploads.push_front(bundle)
    _pump()
    var usable:Array=owner.loaded.filter(func(bundle):return _uploaded([bundle]))
    if not usable.is_empty():
        if usable.size()==owner.paths.size():_bundles[id]=usable
        return _selected_recordings(clip,usable,owner.done==owner.paths.size() and _uploaded(owner.loaded))
    if owner.done==owner.paths.size() and owner.loaded.is_empty():_bundles[id]=false;return false
    return null

## True once every texture of these bundles exists.
static func _uploaded(bundles:Array)->bool:
    return bundles.all(func(bundle):return _textures.has(bundle) and _textures[bundle].size()==bundle.systems.size())

## Creates the next pending texture (one per frame), takes the file in flight
## once it has loaded, and starts the next queued file.
static func _pump()->void:
    if _pump_frame!=Engine.get_process_frames() and not _uploads.is_empty():
        _pump_frame=Engine.get_process_frames()
        var bundle:Resource=_uploads[0]
        var made:Array=_textures[bundle]
        # A clip without emitters (meshes, lights and decals only) has none.
        if made.size()<bundle.systems.size():made.append(ImageTexture.create_from_image(bundle.systems[made.size()].vat_image))
        if made.size()>=bundle.systems.size():_uploads.pop_front()
    if not _pumping:
        _pumping=true
        RenderingServer.frame_pre_draw.connect(_pump)
    if not _loading.is_empty():
        var status:int=ResourceLoader.load_threaded_get_status(_loading)
        if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS:return
        var owner:Dictionary=_requested.get(_owners.get(_loading,""),{"paths":[],"loaded":[],"done":0})
        owner.done+=1
        if status!=ResourceLoader.THREAD_LOAD_LOADED:
            push_warning("Recorded effect failed to load (status %d); skipping it: %s"%[status,_loading])
        else:
            var bundle:Resource=ResourceLoader.load_threaded_get(_loading)
            if bundle==null or bundle.get_script()==null or bundle.get_script().resource_path!=FORMAT:
                push_warning("Not a package recording; skipping it: "+_loading)
            else:
                owner.loaded.append(bundle)
                _textures[bundle]=[];_uploads.append(bundle)
        _loading=""
    var next:Array=_queue_first if not _queue_first.is_empty() else _queue_rest if background_allowed else []
    if next.is_empty():return
    _loading=next.pop_front()
    ResourceLoader.load_threaded_request(_loading,"",false)

## The recording for `choice` (an effect seed), null while its files load,
## false when the clip has none.
static func ready_for(clip:Dictionary,choice:int=0,urgent:bool=false)->Variant:
    var bundles:Variant=request(clip,urgent)
    if not bundles is Array:return bundles
    return bundles[posmod(choice,bundles.size())]

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

## Process materials for a bundle's systems (by role) and path trails, with
## the parameters every occurrence shares.
static func _prototype(bundle:Resource)->Dictionary:
    if _prototypes.has(bundle):return _prototypes[bundle]
    var systems:Array=[];var trails:Array=[]
    for index in bundle.systems.size():
        var system:Dictionary=bundle.systems[index]
        var process:=ShaderMaterial.new();process.shader=TRAILING if system.get("role","static")=="trailing" else PARTICLES
        process.set_shader_parameter("vat_rate",bundle.rate)
        process.set_shader_parameter("vat_frames",system.vat_image.get_width())
        process.set_shader_parameter("vat_first",int(system.first))
        process.set_shader_parameter("vat",_textures[bundle][index])
        systems.append(process)
    for trail in bundle.trails:
        var process:=ShaderMaterial.new();process.shader=PATH_TRAIL
        # The trail's original process parameters (emitter track or offset,
        # step, billboard); occurrence path and cue values are set per cast.
        for name in trail.get("parameters",{}):
            if trail.parameters[name]!=null:process.set_shader_parameter(name,trail.parameters[name])
        trails.append(process)
    _prototypes[bundle]={"systems":systems,"trails":trails}
    return _prototypes[bundle]

## Prepare the actual recorded scene's programs, including the generated
## StandardMaterial3D variants. The manifest's warm list describes live effects;
## it cannot stand in for the recorded scene. No nodes or clocks are created.
static func material_programs(bundle:Resource)->Array[Material]:
    var prototype:Dictionary=_prototype(bundle)
    if not prototype.has("programs"):
        var programs:Array[Material]=[]
        var seen:Dictionary={}
        _scene_programs(bundle.scene,programs,seen)
        for material in prototype.systems+prototype.trails:_material_program(material,programs,seen)
        prototype.programs=programs
    return prototype.programs

static func _material_program(material:Material,programs:Array[Material],seen:Dictionary)->void:
    if material==null or seen.has(material):return
    seen[material]=true;programs.append(material)
    _material_program(material.next_pass,programs,seen)

static func _scene_programs(scene:PackedScene,programs:Array[Material],seen:Dictionary)->void:
    if scene==null or seen.has(scene):return
    seen[scene]=true
    var state:SceneState=scene.get_state()
    for node in state.get_node_count():
        _scene_programs(state.get_node_instance(node),programs,seen)
        for property in state.get_node_property_count(node):
            var value:Variant=state.get_node_property_value(node,property)
            if value is Material:_material_program(value,programs,seen)
            elif value is Mesh and not seen.has(value):
                seen[value]=true
                for surface in value.get_surface_count():_material_program(value.surface_get_material(surface),programs,seen)

static func make(parent:Node3D,bundle:Resource,clip:Dictionary,layer_mask:int)->Dictionary:
    _ensure_clock()
    var handle={"root":null,"components":{},"players":[],"emitters":[],"scripts":[],"carriers":[],"clocks":[],"geometry":[],
        "opacity_bindings":[],"particle_units":[],"emitter_speeds":{},"light_units":{},"motion_trails":{},"motion_age":0.0,
        "native_animation_end":0.0,"initialized":true,"age":0.0,"error":"","clip":clip.duplicate(false),"layer_mask":layer_mask,
        "baked":true,"seekable":true,"bundle":bundle,"slot":-1,"process_materials":[],"tracks":[],"emission_stop":INF,
        "path_materials":[],"trail_draws":[],"history":null,"history_image":null,"history_filled":-1,"presentation":0.0}
    if _free_slots.is_empty():
        handle.error="Recorded effect clock slots exhausted";return handle
    var started:int=Time.get_ticks_usec()
    var phases:Dictionary={}
    var phase_started:int=started
    handle.slot=_free_slots.pop_back()
    _clock_image.set_pixel(handle.slot,0,Color(0,0,0,0));_clock_dirty=true
    var root:Node3D=bundle.scene.instantiate()
    phases.baked_scene_instantiate=(Time.get_ticks_usec()-phase_started)/1000.0
    phase_started=Time.get_ticks_usec()
    root.hide()
    parent.add_child(root)
    handle.root=root
    phases.baked_attach=(Time.get_ticks_usec()-phase_started)/1000.0
    phase_started=Time.get_ticks_usec()
    var materials:Array=material_locations(root)
    phases.baked_material_locations=(Time.get_ticks_usec()-phase_started)/1000.0
    phase_started=Time.get_ticks_usec()
    var copies:Dictionary={}
    for index in bundle.private_materials:
        var copy:Material=materials[index].material.duplicate()
        copies[index]=copy
        for location in materials[index].locations:_bind(root,location,copy)
    phases.baked_private_materials=(Time.get_ticks_usec()-phase_started)/1000.0
    phase_started=Time.get_ticks_usec()
    if _still_path==null:_still_path=ImageTexture.create_from_image(Image.create_from_data(1,3,false,Image.FORMAT_RGBAF,PackedFloat32Array([1,0,0,0, 0,1,0,0, 0,0,1,0]).to_byte_array()))
    var prototype:Dictionary=_prototype(bundle)
    phases.baked_prototypes=(Time.get_ticks_usec()-phase_started)/1000.0
    phase_started=Time.get_ticks_usec()
    for index in bundle.systems.size():
        var system:Dictionary=bundle.systems[index]
        var particles:GPUParticles3D=root.get_node(system.path)
        var process:ShaderMaterial=prototype.systems[index].duplicate()
        process.set_shader_parameter("clock_slot",handle.slot)
        particles.process_material=process
        particles.emitting=true
        handle.process_materials.append(process)
        if system.get("role","static")=="trailing":process.set_shader_parameter("root_history",_still_path);handle.path_materials.append(process)
    for index in bundle.trails.size():
        var trail:Dictionary=bundle.trails[index]
        var node:GPUParticles3D=root.get_node(trail.path)
        var process:ShaderMaterial=prototype.trails[index].duplicate()
        process.set_shader_parameter("clock_slot",handle.slot);process.set_shader_parameter("root_history",_still_path)
        node.process_material=process
        node.emitting=true
        handle.path_materials.append(process)
        handle.trail_draws.append({"node":node,"scroll":trail.scroll,"motion":trail.motion,"process":process})
    phases.baked_particle_materials=(Time.get_ticks_usec()-phase_started)/1000.0
    phase_started=Time.get_ticks_usec()
    for track in bundle.tracks:
        var target:Object=root.get_node(track.path) if track.kind in ["node","bone"] else copies.get(int(track.material))
        if target==null:handle.error="Recorded track target missing: "+str(track);return handle
        handle.tracks.append({"target":target,"track":track})
    phases.baked_tracks=(Time.get_ticks_usec()-phase_started)/1000.0
    phase_started=Time.get_ticks_usec()
    for node in root.find_children("*","",true,false):
        if node is Light3D:
            var shown:bool=node.visible;node.hide()
            node.light_cull_mask=layer_mask;node.layers=layer_mask;node.visible=shown
            if node is OmniLight3D:handle.light_units[node.get_instance_id()]=LightUnits.prepare(node)
        if node is Decal:node.cull_mask=1
        if node is GeometryInstance3D:
            handle.geometry.append({"node":node,"path":str(root.get_path_to(node)),"selected":node.visible and node.layers!=0,"layer_enabled":node.layers!=0})
            if node.layers!=0:node.layers=layer_mask
    phases.baked_geometry_lights=(Time.get_ticks_usec()-phase_started)/1000.0
    phase_started=Time.get_ticks_usec()
    var opacity_uniform:String=clip.get("opacity_uniform","")
    if not opacity_uniform.is_empty():
        for index in materials.size():
            var material:Material=copies.get(index,materials[index].material)
            if not material is ShaderMaterial or material.shader==null:continue
            if not material.shader.get_shader_uniform_list().any(func(uniform):return uniform.name==opacity_uniform):continue
            if not copies.has(index):
                handle.error="Recorded opacity control is not private: "+opacity_uniform;return handle
            var value=material.get_shader_parameter(opacity_uniform)
            handle.opacity_bindings.append({"material":material,"uniform":opacity_uniform,"native":1.0 if value==null else float(value)})
        if handle.opacity_bindings.is_empty():handle.error="Missing opacity control: "+str(clip.get("id",""))+" / "+opacity_uniform
    phases.baked_opacity_bindings=(Time.get_ticks_usec()-phase_started)/1000.0
    phase_started=Time.get_ticks_usec()
    for draw in handle.trail_draws:
        var mesh:Mesh=draw.node.get_draw_pass_mesh(0)
        draw.material=draw.node.material_override if draw.node.material_override!=null else mesh.surface_get_material(0) if mesh!=null else null
    phases.baked_trail_materials=(Time.get_ticks_usec()-phase_started)/1000.0
    phases.baked_instantiate=(Time.get_ticks_usec()-started)/1000.0
    handle.construction_phases=phases
    return handle

## A moving occurrence's path: the root's world transform per presentation
## frame since the cue began, written as the cue plays (and for any frames a
## jump skipped, from `root_at(cue seconds)`). Trailing particles and trails
## read it on the GPU; the cue's own time mapping is set once.
static func follow(handle:Dictionary,cue:Dictionary,presentation:float,root_at:Callable)->void:
    handle.presentation=presentation
    if handle.path_materials.is_empty():return
    _clock_image.set_pixel(handle.slot,0,Color(float(handle.age),presentation,0,0));_clock_dirty=true
    if handle.history==null:
        var width:int=int(ceil(minf(maxf(float(cue.get("end",0.0)),presentation),MAX_PATH_SECONDS)*PATH_RATE))+2
        handle.history_image=Image.create_empty(width,3,false,Image.FORMAT_RGBAF)
        handle.history=ImageTexture.create_from_image(handle.history_image)
        var flight:bool=cue.get("role","")=="flight" and not cue.has("lifecycle")
        for material in handle.path_materials:
            material.set_shader_parameter("root_history",handle.history)
            material.set_shader_parameter("cue_mode",1 if flight else 0)
            material.set_shader_parameter("cue_launch",float(cue.get("launch",0.0)));material.set_shader_parameter("cue_contact",float(cue.get("contact",0.0)))
            material.set_shader_parameter("source_launch",float(cue.get("source_launch",0.0)));material.set_shader_parameter("source_contact",float(cue.get("source_contact",0.0)))
            material.set_shader_parameter("source_rate",float(cue.get("source_rate",1.0)))
        for draw in handle.trail_draws:
            draw.release=float(cue.get("launch",0.0)) if draw.motion else -1000000.0
            draw.process.set_shader_parameter("release_time",draw.release)
    var image:Image=handle.history_image
    var column:int=clampi(int(floor(presentation*PATH_RATE)),0,image.get_width()-1)
    var current:Transform3D=handle.root.global_transform
    for index in range(int(handle.history_filled)+1,column+1):
        _write_column(image,index,current if index==column else root_at.call(float(index)/PATH_RATE))
    if column<=int(handle.history_filled):_write_column(image,column,current)
    handle.history_filled=maxi(int(handle.history_filled),column)
    handle.history.update(image)
    for draw in handle.trail_draws:
        if draw.material is ShaderMaterial and draw.scroll!=Vector2.ZERO:
            var elapsed:float=maxf(0.0,presentation-maxf(float(draw.release),0.0))
            draw.material.set_shader_parameter("uv_offset",(draw.scroll*elapsed).posmod(1.0))

static func _write_column(image:Image,column:int,transform:Transform3D)->void:
    for row in 3:
        image.set_pixel(column,row,Color(transform.basis.x[row],transform.basis.y[row],transform.basis.z[row],transform.origin[row]))

## Source seconds -> recorded state. The renderer still owns placement,
## opacity envelopes and named hides (Playback.controls).
static func sample(handle:Dictionary,seconds:float)->void:
    var bundle:Resource=handle.bundle
    var frame:float=clampf(seconds*bundle.rate,0.0,float(bundle.frames-1))
    var low:int=int(frame)
    var high:int=mini(low+1,bundle.frames-1)
    var weight:float=frame-float(low)
    if not is_equal_approx(float(handle.age),seconds) or not handle.get("sampled",false):
        _clock_image.set_pixel(handle.slot,0,Color(seconds,float(handle.presentation),0,0));_clock_dirty=true
        # Recorded values are source values; restore before applying them so
        # the unit conversion and opacity below never compound.
        LightUnits.restore(handle.light_units)
        for binding in handle.opacity_bindings:binding.material.set_shader_parameter(binding.uniform,binding.native)
        for entry in handle.tracks:
            var track:Dictionary=entry.track
            var values:Array=track.values
            var value:Variant=values[low]
            if track.blend and high!=low:value=_blend(values[low],values[high],weight)
            if track.kind=="bone":entry.target.set_bone_pose(int(track.property),value)
            elif track.kind=="node" or not entry.target is ShaderMaterial:entry.target.set(track.property,value)
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
        TYPE_TRANSFORM3D:
            # A node scaled to nothing has no rotation to interpolate: blend
            # its axes linearly instead (as the Factory's reference player).
            if is_zero_approx(a.basis.determinant()) or is_zero_approx(b.basis.determinant()):
                return Transform3D(Basis(a.basis.x.lerp(b.basis.x,weight),a.basis.y.lerp(b.basis.y,weight),a.basis.z.lerp(b.basis.z,weight)),a.origin.lerp(b.origin,weight))
            return a.interpolate_with(b,weight)
    return a

## Every material reachable from the scene's geometry, in a stable order, with
## each place it is bound. Recordings index their private and tracked
## materials in the Factory recorder's order: a node's override, then its
## mesh surfaces, then its particle draw passes (also those an override hides).
static func material_locations(root:Node)->Array:
    var order:Array=[]
    var by_material:Dictionary={}
    var nodes:Array=[root]
    nodes.append_array(root.find_children("*","",true,false))
    for node in nodes:
        if not node is GeometryInstance3D:continue
        var path:String=str(root.get_path_to(node))
        var found:Array=[]
        if node.material_override!=null:
            found.append([{"path":path,"kind":"override"},node.material_override])
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
            # An override is the only material such a node draws with; a pass
            # material it hides is never bound over it.
            elif node.material_override==null:node.material_override=material
