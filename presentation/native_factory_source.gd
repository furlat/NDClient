extends RefCounted
## Shared Factory source sampler. The caller owns occurrence time and placement.
const Resources=preload("res://assets/native_effects/sandbox/projectiles/factory/core/resource_graph.gd")
const Variants=preload("res://presentation/native_source_variants.gd")
const Native = preload("res://presentation/native_effects.gd")
const Admission=preload("res://presentation/native_source_admission.gd")
const DEFAULT_LAYER = 1 << 19
const ParticleUnits=preload("res://presentation/native_particle_units.gd")
const LightUnits=preload("res://presentation/native_light_units.gd")
const Programs=preload("res://assets/native_effects/sandbox/projectiles/factory/core/native_source_resources.gd")
static var source_revision:int=0
static var _prepared_packets:Dictionary={}

static func invalidate_authoring()->void:
    source_revision+=1
    _prepared_packets={}

static func admitted_packet(spec:Dictionary,clip:Dictionary={})->Resource:
    return _prepared_packets.get(Variants.path_for(Variants.component_spec(spec,clip)))

static func _program_policy(script:String)->bool:
    # These exact adapters only replace programs or write material uniforms.
    # Recoloring adapters (including Chill) still own private VisualShader graphs.
    return script in [
        "res://assets/native_effects/sandbox/projectiles/factory/components/native_scene_effect.gd",
        "res://assets/native_effects/sandbox/projectiles/factory/components/recipient/clocked_source.gd",
        "res://assets/native_effects/sandbox/projectiles/factory/components/recipient/selected_projectile.gd",
        "res://assets/native_effects/sandbox/projectiles/factory/components/recipient/ice_projectile.gd"]

## Packets mark every resource scene-local. Instancing copies a scene-local
## ArrayMesh by reading its vertex buffers back from the GPU, a full GPU stall
## (10-16 ms per construction, every occurrence). Vertex data nothing rewrites
## is shared instead: ArrayMeshes without surface materials; runtime mesh edits
## (Trail3D, silk_area) use ImmediateMeshes or new meshes, never these.
static func _share_vertex_data(packet:Resource)->void:
    var state:SceneState=packet.scene.get_state()
    for index in state.get_node_count():
        for property in state.get_node_property_count(index):
            var mesh:Variant=state.get_node_property_value(index,property)
            if not mesh is ArrayMesh or not mesh.resource_local_to_scene:continue
            if range(mesh.get_surface_count()).all(func(surface):return mesh.surface_get_material(surface)==null):mesh.resource_local_to_scene=false

static func _constructor_input(spec:Dictionary)->Dictionary:
    var input:Dictionary=spec.input.duplicate(true)
    if _program_policy(spec.script):input.share_shader_programs=true
    if spec.script=="res://assets/native_effects/sandbox/projectiles/factory/components/projectile_formation.gd":
        input.source.share_shader_programs=true
    return input

static func make(parent: Node3D, clip: Dictionary, layer_mask:int=DEFAULT_LAYER,use_prepared:bool=true) -> Dictionary:
    var make_started:int=Time.get_ticks_usec()
    var make_phases:Dictionary={}
    var handle = {"root":Node3D.new(),"components":{},"players":[],"emitters":[],
        "scripts":[],"carriers":[],"clocks":[],"geometry":[],"opacity_bindings":[],"particle_units":[],"emitter_speeds":{},"light_units":{},"motion_trails":{},"motion_age":0.0,"native_animation_end":0.0,"initialized":false,"age":0.0,"error":"","clip":clip.duplicate(false),"layer_mask":layer_mask}
    if not Admission.begin_mutation():
        handle.error="Native construction admission is pending"
        return handle
    # Preparation must never briefly register donor default layers/lights in
    # the player world before their private render masks are assigned.
    handle.root.hide()
    parent.add_child(handle.root)
    var prepared_materials:Array=[]
    var prepared_overrides:Dictionary={}
    var all_prepared:bool=use_prepared
    for spec in clip.components:
        var component_started:int=Time.get_ticks_usec()
        var component:Node3D
        var after_ready:Array=[]
        if use_prepared and Variants.supported(spec):
            var prepared_spec:Dictionary=Variants.component_spec(spec,clip)
            var packet:Resource=admitted_packet(prepared_spec)
            if packet==null:
                handle.error="Prepared native source was not admitted before construction: "+spec.id
                return handle
            var prepared:Dictionary=Variants.instantiate(prepared_spec,packet)
            if not prepared.error.is_empty():
                handle.error=prepared.error
                return handle
            component=prepared.component
            after_ready=prepared.after_ready
            component.name=spec.id
            handle.clocks.append_array(prepared.clocks)
            prepared_materials.append_array(prepared.materials)
            for value in prepared.material_overrides:
                prepared_overrides[str(spec.id)+"/"+str(value.node)+":"+str(value.property)]=true
        else:
            all_prepared=false
            var script: Script = load(spec.script)
            if script==null or not script.has_method("make_component"):
                handle.error = "Missing Factory constructor: "+spec.script
                return handle
            component = script.make_component(_constructor_input(spec))
            if component==null:
                handle.error = "Factory construction failed: "+spec.id
                return handle
            # Recovered import assignments must precede source recolouring, ready
            # callbacks and animation sampling (not overwrite their results later).
            for binding in spec.get("material_bindings",[]):
                component.get_node(binding.node).set_surface_override_material(int(binding.surface),load(binding.resource).duplicate(true))
            for binding in spec.get("animation_bindings",[]):
                var player:AnimationPlayer=component.get_node(binding.node)
                var library:AnimationLibrary=player.get_animation_library(binding.library).duplicate(true)
                library.remove_animation(binding.animation)
                var animation:Animation=load(binding.resource).duplicate(true)
                # Recovered imports can retain source keys beyond a truncated
                # declared length. Authoring may restore that original key range.
                if binding.has("length_seconds"):animation.length=float(binding.length_seconds)
                for track in animation.get_track_count():
                    if str(animation.track_get_path(track)) in binding.get("disabled_tracks",[]):animation.track_set_enabled(track,false)
                library.add_animation(binding.animation,animation)
                player.remove_animation_library(binding.library);player.add_animation_library(binding.library,library)
            component.name = spec.id
            # native_scene_effect intentionally shares source materials in export;
            # each editable sandbox instance must own its mutable material values.
            if spec.script.ends_with("/native_scene_effect.gd"): Resources.isolate_node(component,{"share_shader_programs":true})
        make_phases["instantiate"] = make_phases.get("instantiate",0)+(Time.get_ticks_usec()-component_started)/1000.0
        var attach_started:int=Time.get_ticks_usec()
        handle.root.add_child(component)
        Variants.after_attach(component,after_ready)
        handle.components[spec.id] = component
        component.sample(0.0)
        if clip.has("carrier_path"):
            handle.carriers.append({"component":component,"node":component.get_node(clip.carrier_path),"origin":component.position})
        if clip.has("carrier_property"):
            handle.carriers.append({"component":component,"node":component.get(clip.carrier_property),"origin":component.position})
        make_phases["attach_sample_zero"] = make_phases.get("attach_sample_zero",0)+(Time.get_ticks_usec()-attach_started)/1000.0
    var overrides_started:int=Time.get_ticks_usec()
    # Explicit native scene tuning belongs to authoring, before unit conversion.
    for override in clip.get("property_overrides",[]):
        var target:Node=handle.root.get_node(override.node)
        var property:NodePath=NodePath(override.property)
        if prepared_overrides.has(str(override.node)+":"+str(override.property)) and target.get_indexed(property)==override.value:continue
        target.set_indexed(property,override.value)
    for override in clip.get("mesh_overrides",[]):
        var node:MeshInstance3D=handle.root.get_node(override.node)
        var original:Material=node.get_active_material(0)
        var sphere=SphereMesh.new()
        sphere.radius=float(override.radius);sphere.height=float(override.height)
        sphere.radial_segments=int(override.get("radial_segments",32));sphere.rings=int(override.get("rings",16))
        node.mesh=sphere;node.material_override=original
    make_phases.overrides=(Time.get_ticks_usec()-overrides_started)/1000.0
    var scan_started:int=Time.get_ticks_usec()
    var seen = {}
    if all_prepared:
        for material in prepared_materials:seen[material]=true
    for node in handle.root.find_children("*","",true,false):
        if node is AnimationPlayer:
            node.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
            node.advance(0.0)
            handle.players.append(node)
            if not node.current_animation.is_empty():handle.native_animation_end=maxf(handle.native_animation_end,node.current_animation_length)
            if not handle.clip.get("bounded_formation",false) and not node.current_animation.is_empty():
                handle.clip.seconds=maxf(handle.clip.seconds,node.current_animation_length)
        if node is GPUParticles3D:
            handle.emitter_speeds[node.get_instance_id()]=node.speed_scale
            node.speed_scale = 0
            var units=ParticleUnits.prepare(node,all_prepared)
            if not units.is_empty():handle.particle_units.append(units)
            handle.emitters.append(node)
        if node is Light3D:
            # Native material self-lighting belongs to the effect geometry.
            # Painted actors/floors receive this source through PointLight2D
            # only, so they cannot be lit twice by the same source.
            _light_layer(node,int(handle.layer_mask))
            if node is OmniLight3D:handle.light_units[node.get_instance_id()]=LightUnits.prepare(node)
        if node is Decal:
            # Native decals project onto the painted scene's reconstructed
            # surface positions, never onto the packed depth measurement pass.
            node.cull_mask=1
        if node is GeometryInstance3D:
            handle.geometry.append({"node":node,"path":str(handle.root.get_path_to(node)),"selected":node.visible and node.layers!=0,"layer_enabled":node.layers!=0})
            if node.layers!=0: node.layers=int(handle.layer_mask)
        if node.get_script()!=null:
            node.set_process(false); node.set_physics_process(false)
            # Donor gameplay controllers do not own this fixture's movement.
            # The selected trail scripts alone need native frame callbacks.
            if node.get_script().resource_path.ends_with("Trail3D.gd"): handle.scripts.append(node)
        if not all_prepared:
            for property in node.get_property_list():
                if int(property.usage)&PROPERTY_USAGE_STORAGE:
                    var resource = node.get(property.name)
                    if resource is Resource: _materials(resource,seen,handle.clocks)
    make_phases.scan=(Time.get_ticks_usec()-scan_started)/1000.0
    var final_started:int=Time.get_ticks_usec()
    for binding in clip.get("emitters",[]):
        var emitter: GPUParticles3D = handle.components[binding.component].get_node(binding.path)
        emitter.use_fixed_seed=true; emitter.seed=int(binding.seed); emitter.fixed_fps=int(binding.fixed_fps)
    var opacity_uniform:String=clip.get("opacity_uniform",clip.get("placement",{}).get("opacity_uniform",""))
    if not opacity_uniform.is_empty():
        for resource in seen:
            if not resource is ShaderMaterial or resource.shader==null:continue
            for uniform in resource.shader.get_shader_uniform_list():
                if uniform.name==opacity_uniform:
                    var value=resource.get_shader_parameter(opacity_uniform)
                    # Both admitted source opacity controls declare a neutral
                    # default of1; unset material overrides are reported null.
                    handle.opacity_bindings.append({"material":resource,"uniform":opacity_uniform,"native":1.0 if value==null else float(value)})
                    break
        if handle.opacity_bindings.is_empty():handle.error="Missing native opacity control: "+clip.id+" / "+opacity_uniform
    for path in clip.get("motion_trails",[]):
        var trail:GPUParticles3D=handle.root.get_node(path)
        handle.motion_trails[trail.get_instance_id()]={"node":trail,"released":false}
        trail.hide()
    handle.root.hide()
    for player in handle.players:player.clear_caches()
    make_phases.finalize=(Time.get_ticks_usec()-final_started)/1000.0
    make_phases.total=(Time.get_ticks_usec()-make_started)/1000.0
    handle.construction_phases=make_phases
    return handle

static func _materials(resource: Resource, seen: Dictionary, clocks: Array) -> void:
    if seen.has(resource): return
    seen[resource]=true
    if resource is Shader or resource is Texture2D:return
    if resource is Material:
        if resource is ShaderMaterial and Programs.apply_clock(resource,"sandbox_source_seconds",false):
            clocks.append(resource)
        if resource.next_pass!=null:_materials(resource.next_pass,seen,clocks)
        return
    if resource is Mesh:
        for i in resource.get_surface_count():
            var material=resource.surface_get_material(i)
            if material!=null:_materials(material,seen,clocks)
        return
    for property in resource.get_property_list():
        if int(property.usage)&PROPERTY_USAGE_STORAGE:
            var child=resource.get(property.name)
            if child is Resource:_materials(child,seen,clocks)

static func sample(handle: Dictionary, seconds: float, frame_seconds: float, motion_seconds:float=NAN) -> void:
    # Duplicate display sampling must not cancel the GPU delta submitted for
    # this frame. The post-draw completion alone stops that native advance.
    var motion_age:float=maxf(0.0,seconds if is_nan(motion_seconds) else motion_seconds)
    var releasing_trail:bool=(is_nan(motion_seconds) or motion_seconds>=0.0) and handle.motion_trails.values().any(func(binding):return not binding.released)
    if handle.initialized and is_equal_approx(seconds,handle.age) and not releasing_trail and (handle.motion_trails.is_empty() or is_equal_approx(motion_age,handle.motion_age)):
        LightUnits.rescale(handle.light_units,absf(handle.root.global_basis.get_scale().x))
        return
    var delta: float=maxf(0.0,seconds-handle.age)
    var motion_delta:float=maxf(0.0,motion_age-handle.motion_age)
    var native_frame:float=handle.root.get_process_delta_time()
    if delta>0 and frame_seconds>0 and native_frame<=0:return
    handle.initialized=true
    # Restore the last source-owned envelope before its next sample. Authored
    # attenuation is applied separately, including repeated paused sampling.
    for binding in handle.opacity_bindings:binding.material.set_shader_parameter(binding.uniform,binding.native)
    ParticleUnits.restore(handle.particle_units)
    LightUnits.restore(handle.light_units)
    for carrier in handle.carriers: carrier.component.position=carrier.origin
    for binding in handle.clip.bindings:
        if binding.kind=="sample":
            handle.components[binding.component].sample(seconds*float(binding.rate)+float(binding.offset_seconds))
    for player in handle.players:
        var step=delta
        for cue in handle.clip.get("animation_cues",[]):
            if handle.root.get_node(cue.node)!=player:continue
            if float(cue.at_seconds)>handle.age and float(cue.at_seconds)<=seconds:
                player.play(cue.animation)
                step=seconds-float(cue.at_seconds)
        player.advance(step)
    var mask:int=int(handle.layer_mask)
    for piece in handle.geometry:
        if piece.node.layers!=0 and piece.node.layers!=mask:piece.node.layers=mask
    for carrier in handle.carriers:
        carrier.component.position-=handle.root.to_local(carrier.node.global_position)
    for material in handle.clocks: material.set_shader_parameter("sandbox_source_seconds",seconds)
    for binding in handle.opacity_bindings:
        binding.native=float(binding.material.get_shader_parameter(binding.uniform))
    for binding in handle.motion_trails.values():
        if not binding.released and (is_nan(motion_seconds) or motion_seconds>=0.0):
            var trail:GPUParticles3D=binding.node
            # A held source may follow the casting hand. Only the released
            # projectile owns this native world-space ribbon's history.
            trail.restart()
            trail.show()
            binding.released=true
            RenderingServer.frame_pre_draw.connect(func():
                if not is_instance_valid(trail):return
                trail.set("_old_pos",trail.global_position)
                trail.call("_update_billboard_transform",-trail.global_basis.z),CONNECT_ONE_SHOT)
    for node in handle.scripts:
        if node is Node3D and not node.is_visible_in_tree(): continue
        var script_delta:float=motion_delta if handle.motion_trails.has(node.get_instance_id()) else delta
        if script_delta>0:
            if node.has_method("_process"): node.call("_process",script_delta)
            if node.has_method("_physics_process"): node.call("_physics_process",script_delta)
    # Source time may be stepped or slowed independently of the renderer. GPU
    # particles multiply speed_scale by the current native frame delta, not by
    # the requested playback step. Keep them on the same clock as source keys.
    var speed = delta/minf(native_frame,.1) if frame_seconds>0 and native_frame>0 else 0.0
    var motion_speed:float=motion_delta/minf(native_frame,.1) if frame_seconds>0 and native_frame>0 else 0.0
    for emitter in handle.emitters:
        var native_speed:float=motion_speed if handle.motion_trails.has(emitter.get_instance_id()) else speed
        emitter.speed_scale=native_speed*float(handle.emitter_speeds[emitter.get_instance_id()])
    ParticleUnits.apply(handle.particle_units,handle.root.global_basis.get_scale().x)
    LightUnits.apply(handle.light_units,absf(handle.root.global_basis.get_scale().x))
    handle.age=seconds
    handle.motion_age=motion_age
    if speed>0 or motion_speed>0:
        RenderingServer.frame_post_draw.connect(func():
            if not is_instance_valid(handle.get("root")):return
            for emitter in handle.emitters:
                if is_instance_valid(emitter): emitter.speed_scale=0.0,CONNECT_ONE_SHOT)

static func view(handle:Dictionary,camera:Camera3D)->void:
    var binding:Dictionary=handle.clip.get("view_direction",{})
    if binding.is_empty():return
    var component:Node3D=handle.components[binding.component]
    var old:Array=component.parameters[binding.property]
    var before=Vector3(old[0],old[1],old[2]).normalized()
    var direction=(handle.root.global_basis.inverse()*camera.global_basis.z).normalized()
    component.parameters[binding.property]=[direction.x,direction.y,direction.z]
    # Preserve the donor's animated twist when rotating a paused preview.
    if binding.has("node"):
        var mark:Node3D=handle.root.get_node(binding.node)
        mark.quaternion=Quaternion(Vector3.UP,direction)*Quaternion(Vector3.UP,before).inverse()*mark.quaternion

static func close(handle: Dictionary) -> void:
    if is_instance_valid(handle.get("root")): Native.release(handle)

static func set_layer(handle:Dictionary,mask:int)->void:
    var previous:int=handle.layer_mask
    if previous==mask:return
    handle.layer_mask=mask
    # Unpair before changing either side of a native light/geometry mask.
    # Godot caches the light cull mask; changing it while paired can leave
    # stale geometry references which fail on a later seek/instance release.
    var light_visibility:Array=[]
    for entry in handle.light_units.values():
        light_visibility.append({"node":entry.node,"visible":entry.node.visible})
        entry.node.hide()
    for piece in handle.geometry:
        # Visibility can be keyed later by the source AnimationPlayer. An
        # initially hidden mesh still belongs to the source's render layer.
        var enabled:bool=piece.layer_enabled if previous==0 else piece.node.layers!=0
        piece.node.layers=mask if enabled else 0
    for entry in light_visibility:
        entry.node.light_cull_mask=mask;entry.node.layers=mask
        entry.node.visible=entry.visible

static func _light_layer(light:Light3D,mask:int)->void:
    var shown:bool=light.visible
    light.hide()
    light.light_cull_mask=mask;light.layers=mask
    light.visible=shown

static func resource_paths(clip:Dictionary)->Array:
    if clip.has("source_resource_paths"):return clip.source_resource_paths
    var result:Dictionary={}
    _resource_values(clip.get("components",[]),result)
    return result.keys()

static func _resource_values(value:Variant,result:Dictionary)->void:
    if value is Dictionary:
        for key in value:_resource_values(value[key],result)
    elif value is Array:
        for item in value:_resource_values(item,result)
    elif value is String and value.begins_with("res://") and value.get_extension() in ["gd","tscn","tres","res","scn","png","jpg","jpeg","webp","svg","gdshader","material","mesh"]:
        result[value]=true

static func prepare(clips:Array,cache:Dictionary)->Dictionary:
    if int(cache.get("native_source_revision",0))!=source_revision:
        cache.clear();cache.native_source_revision=source_revision
    var paths:Dictionary={}
    var errors:Array=[]
    var original_specs:Array=[]
    var prepared_paths:Array=[]
    var metadata_pending:int=0
    for clip in clips:
        for spec in clip.get("components",[]):
            var admitted:Dictionary=Variants.admission(Variants.component_spec(spec,clip))
            if admitted.supported:
                if admitted.pending:metadata_pending+=1
                elif not admitted.error.is_empty():errors.append(admitted.error)
                else:
                    paths[admitted.path]=true
                    if admitted.path not in prepared_paths:prepared_paths.append(admitted.path)
            else:
                original_specs.append(spec)
                _resource_values(spec,paths)
    for path in prepared_paths:
        if _prepared_packets.has(path):cache[path]=_prepared_packets[path]
    var loading:Dictionary=Admission.prepare(paths.keys(),cache,source_revision>0)
    var pending:int=loading.pending+metadata_pending
    var program_pending:int=0
    errors.append_array(loading.errors)
    if pending==0 and errors.is_empty():
        for path in prepared_paths:
            var packet:Resource=cache[path]
            if not Admission.prepare_materials(packet,packet.program_materials,cache):
                program_pending+=1
            else:
                if not _prepared_packets.has(path):_share_vertex_data(packet)
                _prepared_packets[path]=packet
        pending+=program_pending
    if not clips.is_empty() and not Admission.can_mutate():pending+=1
    if pending==0 and errors.is_empty():
        if not cache.has("native_program_sources"):cache.native_program_sources={}
        var jobs:Dictionary={}
        for spec in original_specs:
            var formation:bool=spec.script=="res://assets/native_effects/sandbox/projectiles/factory/components/projectile_formation.gd"
            if not _program_policy(spec.script) and not formation:continue
            var input:Dictionary=spec.input.source if formation else spec.input
            var uniform:String="sandbox_source_seconds" if spec.script.ends_with("/native_scene_effect.gd") else "source_clock"
            var sources:Array=[{"path":input.get("scene",""),"raw":false}]
            for rule in input.get("material_rules",[]):sources.append({"path":rule.shader_source,"raw":true})
            for binding in spec.get("material_bindings",[]):sources.append({"path":binding.resource,"raw":false})
            for source in sources:
                var key:String=source.path+"|"+uniform+("|rule" if source.raw else "")
                if not cache.native_program_sources.has(key):
                    if not Programs.reserve_discovery():
                        program_pending+=1
                        continue
                    Admission.begin_mutation()
                    var source_jobs:Dictionary={}
                    if cache.has(source.path):
                        var resource:Resource=cache[source.path]
                        if source.raw:source_jobs[resource.code]=true
                        Programs.collect(resource,uniform,uniform=="source_clock",source_jobs,{})
                    cache.native_program_sources[key]=source_jobs
                jobs.merge(cache.native_program_sources[key])
        if jobs.keys().any(func(code):return not Programs.programs.has(code)):Admission.begin_mutation()
        program_pending+=Programs.prepare(jobs)
        pending+=program_pending
    return {"ready":pending==0 and errors.is_empty(),"pending":pending,"errors":errors,
        "program_pending":program_pending,"cached_programs":Programs.programs.size()}
