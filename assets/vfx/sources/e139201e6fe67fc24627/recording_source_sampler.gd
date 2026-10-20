extends "res://assets/vfx/sources/30ef867264d6f398c2d7/native_factory_source.gd"
## Production source construction with its root hidden before scene registration.
## This prevents soft-shadow pair counter errors while configuring native light
## masks. The pinned sampler hides it only after construction. No artwork or
## lighting value is changed; all other source behavior remains the same.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
const RuntimeParticleUnits = preload("res://assets/vfx/sources/dce4978aa79c8ef7fd8e/runtime_particle_units.gd")
const Interfaces = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")

static func make(parent: Node3D, clip: Dictionary, layer_mask:int=DEFAULT_LAYER) -> Dictionary:
    var handle = {"root":Node3D.new(),"components":{},"players":[],"emitters":[],
        "scripts":[],"carriers":[],"clocks":[],"geometry":[],"opacity_bindings":[],"particle_units":[],"emitter_speeds":{},"light_units":{},"motion_trails":{},"motion_age":0.0,"native_animation_end":0.0,"initialized":false,"age":0.0,"error":"","clip":clip,"layer_mask":layer_mask}
    handle.root.hide() # Construction cannot register visible light/geometry pairs.
    parent.add_child(handle.root)
    for spec in clip.components:
        preload("res://assets/vfx/sources/c1e0733a7ef81c657ab9/immutable_materials.gd").bind(spec.input.get("_prepared_materials", []))
        var script: Script = VfxPackageIO_e139201e6f.resource(spec.script)
        if script==null or not script.has_method("make_component"):
            handle.error = "Missing Factory constructor: "+spec.script
            return handle
        Profile.begin("component_construction")
        var component: Node3D = script.make_component(spec.input.duplicate(true))
        Profile.end("component_construction")
        if component==null:
            handle.error = "Factory construction failed: "+spec.id
            return handle
        var source_error: Variant = component.get("construction_error")
        if source_error is String and not source_error.is_empty():
            handle.error = "Factory source rejected operands: "+spec.id+" / "+source_error
            component.free()
            return handle
        # Recovered import assignments must precede source recolouring, ready
        # callbacks and animation sampling (not overwrite their results later).
        for binding in spec.get("material_bindings",[]):
            component.get_node(binding.node).set_surface_override_material(int(binding.surface),VfxPackageIO_e139201e6f.resource(binding.resource).duplicate(true))
        for binding in spec.get("animation_bindings",[]):
            var player:AnimationPlayer=component.get_node(binding.node)
            var library:AnimationLibrary=player.get_animation_library(binding.library).duplicate(true)
            library.remove_animation(binding.animation)
            var animation:Animation=VfxPackageIO_e139201e6f.resource(binding.resource).duplicate(true)
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
        if spec.script.ends_with("/native_scene_effect.gd"): Resources.isolate_node(component,{})
        # An explicitly prepared source may set its existing enabled geometry
        # to the supplied mask before entering the world. Avoid registering
        # every native draw once on its donor layer and again on the real one.
        # Zero-mask construction retains the conservative path so later layer
        # recovery still knows which original source draws were enabled.
        if layer_mask != 0 and component.has_method("prepare_source_layer_mask"):
            Profile.begin("source_layer_mask_preparation")
            component.prepare_source_layer_mask(layer_mask)
            Profile.end("source_layer_mask_preparation")
        Profile.begin("component_tree_registration")
        handle.root.add_child(component)
        Profile.end("component_tree_registration")
        source_error = component.get("construction_error")
        if source_error is String and not source_error.is_empty():
            handle.error = "Factory source preparation failed: "+spec.id+" / "+source_error
            component.free()
            return handle
        handle.components[spec.id] = component
        Profile.begin("initial_source_sample")
        component.sample(0.0)
        Profile.end("initial_source_sample")
        if clip.has("carrier_path"):
            handle.carriers.append({"component":component,"node":component.get_node(clip.carrier_path),"origin":component.position})
        if clip.has("carrier_property"):
            handle.carriers.append({"component":component,"node":component.get(clip.carrier_property),"origin":component.position})
    # Explicit native scene tuning belongs to authoring, before unit conversion.
    for override in clip.get("property_overrides",[]):
        handle.root.get_node(override.node).set_indexed(NodePath(override.property),override.value)
    for override in clip.get("mesh_overrides",[]):
        var node:MeshInstance3D=handle.root.get_node(override.node)
        var original:Material=node.get_active_material(0)
        var sphere=SphereMesh.new()
        sphere.radius=float(override.radius);sphere.height=float(override.height)
        sphere.radial_segments=int(override.get("radial_segments",32));sphere.rings=int(override.get("rings",16))
        node.mesh=sphere;node.material_override=original
    Profile.begin("sampler_registration")
    var seen = {}
    Profile.begin("declared_binding_collection")
    var declared: Dictionary = _declared_bindings(handle)
    Profile.end("declared_binding_collection")
    if not declared.is_empty():
        Profile.begin("declared_geometry_registration")
        for node in declared.geometry:
            handle.geometry.append({"node":node,"path":str(handle.root.get_path_to(node)),"selected":node.visible and node.layers!=0,"layer_enabled":node.layers!=0})
            if node.layers!=0 and node.layers!=int(handle.layer_mask):
                node.layers=int(handle.layer_mask)
            # A prepared topology can include native emitters. Keep the same
            # source-step/units ownership as the conservative discovery path;
            # omitting this would freeze a correctly declared particle scene.
            if node is GPUParticles3D:
                Profile.begin("declared_emitter_registration")
                handle.emitter_speeds[node.get_instance_id()]=node.speed_scale
                node.speed_scale=0.0
                var units=ParticleUnits.prepare(node)
                if not units.is_empty():handle.particle_units.append(units)
                handle.emitters.append(node)
                Profile.end("declared_emitter_registration")
        Profile.end("declared_geometry_registration")
        for player in declared.get("players", []):
            assert(player is AnimationPlayer)
            # Same native initial zero advance and clip-length extension as
            # conservative discovery, using explicit prepared player handles.
            player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
            player.advance(0.0)
            handle.players.append(player)
            if not player.current_animation.is_empty():
                handle.native_animation_end=maxf(handle.native_animation_end,player.current_animation_length)
                if not handle.clip.get("bounded_formation",false):
                    handle.clip.seconds=maxf(handle.clip.seconds,player.current_animation_length)
        for light in declared.get("lights", []):
            light.light_cull_mask=int(handle.layer_mask)
            light.layers=int(handle.layer_mask)
            if light is OmniLight3D:handle.light_units[light.get_instance_id()]=LightUnits.prepare(light)
        for material in declared.materials:
            Profile.begin("sampler_material_discovery")
            _declared_material(material,seen,handle.clocks)
            Profile.end("sampler_material_discovery")
        handle.static_material_topology=true
        handle.static_geometry_layers=declared.get("static_geometry_layers",true)
    else:
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
                var units=ParticleUnits.prepare(node)
                if not units.is_empty():handle.particle_units.append(units)
                handle.emitters.append(node)
            if node is Light3D:
                # Native material self-lighting belongs to the effect geometry.
                # Painted actors/floors receive this source through PointLight2D
                # only, so they cannot be lit twice by the same source.
                node.light_cull_mask=int(handle.layer_mask)
                node.layers=int(handle.layer_mask)
                if node is OmniLight3D:handle.light_units[node.get_instance_id()]=LightUnits.prepare(node)
            if node is Decal:
                # Native decals project onto the painted scene's reconstructed
                # surface positions, never onto the packed depth measurement pass.
                node.cull_mask=1
            if node is GeometryInstance3D:
                handle.geometry.append({"node":node,"path":str(handle.root.get_path_to(node)),"selected":node.visible and node.layers!=0,"layer_enabled":node.layers!=0})
                if node.layers!=0 and node.layers!=int(handle.layer_mask): node.layers=int(handle.layer_mask)
            if node.get_script()!=null:
                node.set_process(false); node.set_physics_process(false)
                # Donor gameplay controllers do not own this fixture's movement.
                # The selected trail scripts alone need native frame callbacks.
                if node.get_script().resource_path.ends_with("Trail3D.gd"): handle.scripts.append(node)
            for property in node.get_property_list():
                if int(property.usage)&PROPERTY_USAGE_STORAGE:
                    var resource = node.get(property.name)
                    if resource is Resource:
                        Profile.begin("sampler_material_discovery")
                        if resource is ShaderMaterial and resource.has_meta("factory_prepared_shader") and resource.get_meta("factory_prepared_shader")==resource.shader:
                            # Explicit immutable programs have already resolved
                            # their clocks and texture interface. Preserve the
                            # next-pass chain without reflecting every sampler.
                            _declared_material(resource,seen,handle.clocks)
                        else:
                            _materials(resource,seen,handle.clocks)
                        Profile.end("sampler_material_discovery")
    for binding in clip.get("emitters",[]):
        var emitter: GPUParticles3D = handle.components[binding.component].get_node(binding.path)
        emitter.use_fixed_seed=true; emitter.seed=int(binding.seed); emitter.fixed_fps=int(binding.fixed_fps)
    Profile.begin("source_opacity_interface_registration")
    var opacity_uniform:String=clip.get("opacity_uniform",clip.get("placement",{}).get("opacity_uniform",""))
    if not opacity_uniform.is_empty():
        for resource in seen:
            if not resource is ShaderMaterial or resource.shader==null:continue
            if opacity_uniform in Interfaces.declared_uniforms(resource.shader):
                var value=resource.get_shader_parameter(opacity_uniform)
                # Read the immutable program interface once, not one renderer
                # uniform-list reflection for every occurrence material.
                handle.opacity_bindings.append({"material":resource,"uniform":opacity_uniform,"native":1.0 if value==null else float(value)})
        if handle.opacity_bindings.is_empty():handle.error="Missing native opacity control: "+clip.id+" / "+opacity_uniform
    Profile.end("source_opacity_interface_registration")
    for path in clip.get("motion_trails",[]):
        var trail:GPUParticles3D=handle.root.get_node(path)
        handle.motion_trails[trail.get_instance_id()]={"node":trail,"released":false}
        trail.hide()
    handle.materials=[]
    for resource in seen:
        if resource is Material:
            handle.materials.append(resource)
    handle.root.hide()
    for player in handle.players:player.clear_caches()
    Profile.end("sampler_registration")
    return handle



static func sample(handle: Dictionary, seconds: float, frame_seconds: float, motion_seconds:float=NAN) -> void:
    # Duplicate display sampling must not cancel the GPU delta submitted for
    # this frame. The post-draw completion alone stops that native advance.
    var motion_age:float=maxf(0.0,seconds if is_nan(motion_seconds) else motion_seconds)
    var releasing_trail:bool=(is_nan(motion_seconds) or motion_seconds>=0.0) and handle.motion_trails.values().any(func(binding):return not binding.released)
    if handle.initialized and is_equal_approx(seconds,handle.age) and not releasing_trail and (handle.motion_trails.is_empty() or is_equal_approx(motion_age,handle.motion_age)):
        var actual_transform: Transform3D = handle.root.global_transform
        var transform_changed: bool = not handle.has("last_sample_transform") or handle.last_sample_transform != actual_transform
        if handle.get("source_inputs_dirty",false) or transform_changed:
            # Audited adaptive sources can refresh geometry/owner uniforms at a
            # held source age. Do not run native players, emitter speed writes,
            # trail release or delta callbacks here: an earlier same-frame
            # advancing sample may still have a pending GPU simulation step.
            for binding in handle.clip.bindings:
                if binding.kind != "sample": continue
                var component: Node = handle.components[binding.component]
                if component.has_method("refresh_live_inputs"):
                    component.refresh_live_inputs(seconds*float(binding.rate)+float(binding.offset_seconds))
            handle.source_inputs_dirty=false
            handle.last_sample_transform=actual_transform
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
    RuntimeParticleUnits.restore(handle.particle_units)
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
    # Static-layer admission is an explicit runtime hint, never inferred from
    # a still image. Source layers that may change retain the conservative pass.
    if not handle.get("static_geometry_layers", false):
        for piece in handle.geometry:
            var layers: int = piece.node.layers
            if layers != 0 and layers != int(handle.layer_mask):
                piece.node.layers = int(handle.layer_mask)
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
    RuntimeParticleUnits.apply(handle.particle_units,handle.root.global_basis.get_scale().x)
    LightUnits.apply(handle.light_units,absf(handle.root.global_basis.get_scale().x))
    handle.age=seconds
    handle.motion_age=motion_age
    handle.source_inputs_dirty=false
    handle.last_sample_transform=handle.root.global_transform
    if not handle.emitters.is_empty() and (speed>0 or motion_speed>0):
        RenderingServer.frame_post_draw.connect(func():
            if not is_instance_valid(handle.get("root")):return
            for emitter in handle.emitters:
                if is_instance_valid(emitter): emitter.speed_scale=0.0,CONNECT_ONE_SHOT)



static func _declared_bindings(handle: Dictionary) -> Dictionary:
    var nodes: Array=[]
    var materials: Array=[]
    var lights: Array=[]
    var players: Array=[]
    var static_geometry_layers:=true
    for component in handle.components.values():
        if not component.has_method("source_bindings"):
            return {}
        var bindings: Dictionary=component.source_bindings()
        if not bindings.get("static_material_topology",false):
            return {}
        static_geometry_layers=static_geometry_layers and bindings.get("static_geometry_layers",true)
        for node in bindings.geometry:
            assert(node is GeometryInstance3D and component.is_ancestor_of(node), "Declared geometry must belong to this source")
            nodes.append(node)
        for light in bindings.get("lights", []):
            assert(light is Light3D and component.is_ancestor_of(light), "Declared light must belong to this source")
            lights.append(light)
        for player in bindings.get("players", []):
            assert(player is AnimationPlayer and component.is_ancestor_of(player), "Declared player must belong to this source")
            if player not in players:players.append(player)
        for material in bindings.materials:
            assert(material is Material, "Declared material must be an actual displayed resource")
            if material not in materials:
                materials.append(material)
    return {"geometry":nodes,"materials":materials,"lights":lights,"players":players,"static_geometry_layers":static_geometry_layers}


static func _declared_material(material: Material, seen: Dictionary, clocks: Array) -> void:
    if seen.has(material):
        return
    seen[material]=true
    if material is ShaderMaterial and material.shader!=null and (not material.has_meta("factory_prepared_shader") or material.get_meta("factory_prepared_shader")!=material.shader):
        var token=RegEx.new()
        token.compile("\\bTIME\\b")
        if token.search(material.shader.code):
            # The established source sampler preserves original default textures.
            _materials(material,{},clocks)
    if material.next_pass!=null:
        _declared_material(material.next_pass,seen,clocks)

const VfxPackageIO_e139201e6f = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
