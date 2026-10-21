extends RefCounted
## Native source resources and sampling only. Occurrence timing/placement belongs
## to the production compiler/sampler; this helper never advances that clock.
const INDEX = "res://assets/vfx/extensions/input-reduction-20261021/sources/c01045673105f08e25ae/index.json"
const ClassPalette = preload("res://assets/vfx/sources/a6152572c743ba091fbc/native_effect_palette.gdshader")

static func source_age_ms(component:Dictionary,age_ms:float)->float:
    var age:float=component.get("source_age_ms",age_ms)*component.get("native_age_rate",1.0)
    return fposmod(age,component.source_duration_ms) if component.get("loop",false) else age

static func weapon_context(component:Dictionary,actor:Dictionary,rig:Dictionary,cycle:Array,quarter:int)->Dictionary:
    # Borrow the admitted measured path. The native source copies its points
    # into its own mesh state; neither caller changes authoring or pose data.
    var pose:Dictionary=component.get("weapon_pose",{})
    var track:Dictionary=component.get("source_track",{})
    var fps:float=rig.get("clips",{}).get(pose.get("clip",""),{}).get("fps",0.0)
    var contact:float=component.get("weapon_contact_seconds",0.0)
    if pose.is_empty() or cycle.size()!=8 or fps<=0 or contact<=0:
        return {"error":"Native Strike needs its selected measured path, clip FPS and contact source time","context":{}}
    var direction:String=actor.get("facing","SW")
    var origin:Variant=track.get("from_position")
    var target:Variant=track.get("target_position")
    if origin!=null and target!=null:
        var delta=Vector2(target[0]-origin[0],target[1]-origin[1])
        if not delta.is_zero_approx():direction=cycle[posmod(roundi((atan2(delta.y,delta.x)+PI/4)/(TAU/8))+cycle.find("E"),8)]
    if direction not in cycle:return {"error":"Native Strike has no admitted facing","context":{}}
    var facing:String=cycle[posmod(cycle.find(direction)+quarter*2,8)]
    var path:Array=pose.get("pointsByFacing",{}).get(facing,[])
    if path.size()<2:return {"error":"Native Strike has no measured weapon path for "+facing,"context":{}}
    return {"error":"","context":{"weapon_path":path,"weapon_path_fps":fps,
        "weapon_contact_seconds":contact,"weapon_scale_x":actor.get("scale_x",1.0)}}

static func source_record(id: String, cache: Dictionary = {}) -> Dictionary:
    if not cache.has(INDEX):
        var parsed = JSON.parse_string(VfxPackageIO_e75a72d184.text(INDEX))
        if not parsed is Dictionary: return {}
        cache[INDEX] = parsed
    return cache[INDEX].get("sources", {}).get(id, {})

static func prepare(source_ids: Array, cache: Dictionary) -> Dictionary:
    # Existing ResourceLoader jobs own asset decode. The caller's current/next
    # component set is finite; no native scene nodes are created on a worker.
    var pending=0
    var errors:Array=[]
    var paths={}
    for id in source_ids:
        var record=source_record(str(id),cache)
        if record.is_empty():errors.append("Native source not selected: "+str(id));continue
        for path in record.get("preload_paths",[record.get("scene",record.get("script",""))]):paths[path]=true
    for path in paths:
        var status=ResourceLoader.load_threaded_get_status(path)
        if status==ResourceLoader.THREAD_LOAD_LOADED:
            cache[path]=ResourceLoader.load_threaded_get(path)
            continue
        if ResourceLoader.has_cached(path):continue
        if status==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            var error=ResourceLoader.load_threaded_request(path)
            if error!=OK:errors.append("Native resource preparation failed: "+str(path));continue
            pending+=1
        elif status==ResourceLoader.THREAD_LOAD_FAILED:errors.append("Native resource preparation failed: "+str(path))
        else:pending+=1
    return {"ready":pending==0 and errors.is_empty(),"pending":pending,"errors":errors}

static func make(parent: Node3D, record: Dictionary, occurrence_seed: int = 0) -> Dictionary:
    if record.is_empty(): return {"error":"Native source is not selected"}
    var handle = {"record":record,"root":Node3D.new(),"subject":null,"players":[],
        "emitters":[],"clocks":[],"age":0.0,"initialized":false,"pending":false,
        "history":[],"error":"","seed":occurrence_seed}
    var subject: Node3D
    match record.kind:
        "class_component":
            var script: Script = VfxPackageIO_e75a72d184.resource(record.script)
            if script == null: return _fail(handle,"Missing native source: "+str(record.script))
            subject = script.new()
            subject.kind = record.properties.kind
            subject.side_name = "all" # one composition, never duplicate rear/front exports
            subject.quadrant = int(record.properties.get("quadrant",0))
        "authored_script":
            var script:Script=VfxPackageIO_e75a72d184.resource(record.script)
            if script==null:return _fail(handle,"Missing native source: "+str(record.script))
            subject=script.new()
            for property in record.get("properties",{}):subject.set(property,record.properties[property])
        "scene":
            var scene: PackedScene = VfxPackageIO_e75a72d184.resource(record.scene)
            if scene == null: return _fail(handle,"Missing native scene: "+str(record.scene))
            subject = scene.instantiate()
            handle.subject=subject
            handle.root.add_child(subject)
            _isolate(subject)
            if record.has("scene_scale"):
                var scale_value: Array=record.scene_scale
                subject.scale=Vector3(scale_value[0],scale_value[1],scale_value[2])
            if record.has("scene_rotation_degrees"):
                var angles:Array=record.scene_rotation_degrees
                subject.rotation_degrees=Vector3(angles[0],angles[1],angles[2])
            if record.has("scene_offset"):
                var offset: Array=record.scene_offset
                subject.position=subject.basis.orthonormalized()*Vector3(offset[0],offset[1],offset[2])
            for path in record.get("node_properties",{}):
                var node=subject.get_node_or_null(path)
                if node==null:return _fail(handle,"Missing source property owner: "+path)
                for property in record.node_properties[path]:node.set(property,record.node_properties[path][property])
            for binding in record.get("material_resources",[]):
                var node=subject.get_node_or_null(binding.path)
                if node==null or not node.material_override is ShaderMaterial:
                    return _fail(handle,"Missing source animated resource owner: "+binding.path)
                var resource:Resource=node.material_override.get_shader_parameter(binding.parameter)
                if resource==null:return _fail(handle,"Missing source animated resource: "+binding.parameter)
                node.material_override.set_shader_parameter(binding.parameter,resource.duplicate(true))
            _material_rules(subject,record.get("material_rules",[]))
            for path in record.get("suppressed_lights",[]):
                var light:Light3D=subject.get_node_or_null(path)
                if light==null:return _fail(handle,"Missing declared source light: "+path)
                light.light_cull_mask=0
                light.visible=false
        _:
            return _fail(handle,"Unsupported native source kind: "+str(record.kind))
    handle.subject = subject
    if subject.get_parent()==null:handle.root.add_child(subject)
    for binding in record.get("animations",[]):
        var player: AnimationPlayer = subject.get_node_or_null(binding.path)
        if player == null or not player.has_animation(binding.clip):
            return _fail(handle,"Missing declared animation: "+str(binding))
        player.autoplay = ""
        player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
        # Emission keys are crossings, not continuously re-applied true values.
        # Other property tracks use seek(update_only), suppressing audio/methods.
        var original: Animation = player.get_animation(binding.clip)
        var animation: Animation = original.duplicate(true)
        var emissions: Array = []
        for track in animation.get_track_count():
            var path: NodePath = animation.track_get_path(track)
            if animation.track_get_type(track)==Animation.TYPE_VALUE and path.get_subname_count()==1 and path.get_subname(0)=="emitting":
                var emitter: GPUParticles3D = subject.get_node_or_null(NodePath(path.get_concatenated_names()))
                if emitter == null: return _fail(handle,"Emission track has no native emitter: "+str(path))
                for key in animation.track_get_key_count(track):
                    emissions.append({"node":emitter,"time":animation.track_get_key_time(track,key),"value":animation.track_get_key_value(track,key)})
                animation.track_set_enabled(track,false)
        var library = AnimationLibrary.new()
        library.add_animation("sample",animation)
        for name in player.get_animation_library_list(): player.remove_animation_library(name)
        player.add_animation_library("",library)
        player.assigned_animation = "sample"
        handle.players.append({"node":player,"emissions":emissions})
    for binding in record.get("emitters",[]):
        var emitter: GPUParticles3D = subject.get_node_or_null(binding.path)
        if emitter == null: return _fail(handle,"Missing declared emitter: "+str(binding.path))
        var initially_emitting = emitter.emitting
        emitter.use_fixed_seed = true
        emitter.seed = int(binding.seed)+occurrence_seed
        emitter.fixed_fps = int(binding.fixed_fps)
        emitter.speed_scale = 0.0
        emitter.emitting = false
        var events:Array=[]
        for player in handle.players:
            for event in player.emissions:
                if event.node==emitter:events.append(event)
        events.sort_custom(func(a,b):return a.time<b.time)
        handle.emitters.append({"node":emitter,"initial":initially_emitting,"events":events})
    for binding in record.get("shader_clocks",[]):
        var node: GeometryInstance3D = subject.get_node_or_null(binding.path)
        if node == null or not node.material_override is ShaderMaterial:
            return _fail(handle,"Missing declared shader clock: "+str(binding.path))
        # VisualShader regenerates its embedded code from the graph on load.
        # Bind the explicit selected source's clock AFTER that generation.
        var code:String=node.material_override.shader.code
        var token=RegEx.new();token.compile("\\bTIME\\b")
        if token.search(code):
            var shader=Shader.new()
            shader.code=token.sub(code,binding.uniform,true).replace("shader_type spatial;","shader_type spatial;\n uniform float "+binding.uniform+"=0.0;")
            node.material_override.shader=shader
        handle.clocks.append({"material":node.material_override,"uniform":binding.uniform})
    parent.add_child(handle.root)
    subject.set_process(false)
    subject.set_physics_process(false)
    return handle

static func _fail(handle: Dictionary, message: String) -> Dictionary:
    if is_instance_valid(handle.get("root")): handle.root.free()
    return {"error":message}

static func _isolate(node: Node) -> void:
    # Share source textures/meshes; only mutable material owners are copied.
    if node is GeometryInstance3D and node.material_override != null:
        node.material_override = node.material_override.duplicate(false)
    # A whole-mesh override supersedes surface materials. Duplicating that same
    # override into each surface adds unused RD dependencies during teardown.
    if node is MeshInstance3D and node.mesh != null and node.material_override == null:
        for surface in node.mesh.get_surface_count():
            var material: Material = node.get_active_material(surface)
            if material != null: node.set_surface_override_material(surface,material.duplicate(false))
    for child in node.get_children(): _isolate(child)

static func _material_rules(subject: Node3D, rules: Array) -> void:
    # Exact Factory keyed_native_donor substitutions on fresh source instances.
    for rule in rules:
        var shader=Shader.new();shader.code=VfxPackageIO_e75a72d184.text(rule.shader_source)
        for node in subject.find_children("*","GeometryInstance3D",true,false):
            var original:Material=node.material_override
            if not original is BaseMaterial3D:continue
            if original.blend_mode!=int(rule.match.blend_mode):continue
            if rule.match.requires_texture and original.albedo_texture==null:continue
            var material=ShaderMaterial.new();material.shader=shader
            material.render_priority=original.render_priority
            for uniform in rule.source_parameters:material.set_shader_parameter(uniform,original.get(rule.source_parameters[uniform]))
            for uniform in rule.parameters:material.set_shader_parameter(uniform,rule.parameters[uniform])
            node.material_override=material

static func _properties(handle: Dictionary, age: float) -> void:
    if handle.record.kind in ["class_component","authored_script"]:
        handle.subject.set_age(age)
    for binding in handle.players:
        binding.node.seek(age,true,true)
        binding.node.pause()
    for binding in handle.clocks:
        binding.material.set_shader_parameter(binding.uniform,age)

static func _reset(handle: Dictionary) -> void:
    for binding in handle.emitters:
        binding.node.restart(true)
        binding.node.emitting = binding.initial
    handle.age = 0.0
    handle.initialized = false
    handle.emissions_through=0.0

static func _emissions(handle: Dictionary, previous: float, current: float) -> void:
    for binding in handle.players:
        for event in binding.emissions:
            if event.time>previous and event.time<=current: event.node.emitting = event.value

static func _after_draw(handle: Dictionary, age: float) -> void:
    if not is_instance_valid(handle.get("root")): return
    handle.age = age
    handle.pending = false
    # The next requested display sample explicitly supplies another delta.
    for binding in handle.emitters:binding.node.speed_scale=0.0

static func _history_transform(history:Array,age:float)->Transform3D:
    if history.is_empty():return Transform3D.IDENTITY
    var low=0;var high=history.size()
    while low<high:
        var middle=(low+high)/2
        if float(history[middle].age_seconds)<age:low=middle+1
        else:high=middle
    if low==0:return history[0].transform
    if low==history.size():return history[-1].transform
    if float(history[low].age_seconds)==age:return history[low].transform
    var before:Dictionary=history[low-1];var after:Dictionary=history[low]
    var fraction=(age-float(before.age_seconds))/maxf(.000001,float(after.age_seconds)-float(before.age_seconds))
    return before.transform.interpolate_with(after.transform,fraction)

static func sample(handle: Dictionary, seconds: float, history: Array = [], sampling:Dictionary = {}) -> Dictionary:
    if not handle.get("error","").is_empty(): return {"ready":false,"error":handle.error}
    if not is_instance_valid(handle.get("root")): return {"ready":false,"error":"Native source released"}
    var age = maxf(0.0,seconds)
    if handle.record.get("weapon_path",false):
        var path:Array=sampling.get("weapon_path",[])
        var fps=float(sampling.get("weapon_path_fps",0.0))
        var contact=float(sampling.get("weapon_contact_seconds",0.0))
        var scale_x=float(sampling.get("weapon_scale_x",1.0))
        if path.size()<2 or fps<=0 or contact<=0:
            return {"ready":false,"error":"Native Strike needs its selected measured path, clip FPS and contact source time"}
        var rate=contact/.67*fps
        if not is_same(path,handle.get("weapon_path",null)) or handle.get("weapon_path_rate",0.0)!=rate or handle.get("weapon_scale_x",0.0)!=scale_x:
            var values:Array=[]
            for point in path:values.append(null if point==null else [float(point.x),float(point.y)])
            handle.subject.paths=[values];handle.subject.heading=0
            handle.subject.native_path_rate=rate;handle.subject.native_scale_x=scale_x
            handle.weapon_path=path;handle.weapon_path_rate=rate;handle.weapon_scale_x=scale_x
            handle.initialized=false
    if handle.emitters.is_empty():
        if not handle.initialized or handle.age!=age:
            _properties(handle,age)
            handle.age=age;handle.initialized=true
        return {"ready":true,"age":age,"error":""}
    if handle.pending:return {"ready":false,"age":handle.age,"error":""}
    if not history.is_empty():
        if not history[0] is Dictionary or not history[-1].has("age_seconds") or float(history[-1].age_seconds)<age:
            return {"ready":false,"age":handle.age,"error":"Emitter transform history does not cover requested source age"}
    if age<handle.age or (not history.is_empty() and not is_same(history,handle.history)):
        handle.history=history
        handle.initialized=false
    if not handle.initialized:
        _reset(handle);_properties(handle,0.0);_emissions(handle,-1.0,0.0)
        handle.initialized=true
    if is_equal_approx(age,handle.age):return {"ready":true,"age":handle.age,"error":""}
    var frame_seconds=float(sampling.get("native_frame_seconds",handle.root.get_process_delta_time()))
    # Scene construction may precede the first process delta. Wait for that
    # real frame instead of inventing time or rejecting a valid source.
    if frame_seconds<=0:return {"ready":false,"age":handle.age,"waiting_for_frame":true,"error":""}
    var continuous=bool(sampling.get("native_continuous",false))
    var next=age
    if not continuous:
        # One original native frame per draw during a seek. No second clock:
        # the supplied requested age is the ceiling and the declared history
        # gives the finite cadence. Paused, already-prepared samples do no work.
        if history.is_empty():
            var fps=int(handle.emitters[0].node.fixed_fps)
            next=minf(age,(floor(handle.age*fps+.00001)+1.0)/fps)
        else:
            for row in history:
                if float(row.age_seconds)>handle.age+.000001:
                    next=minf(age,float(row.age_seconds));break
    if not history.is_empty():handle.root.transform=_history_transform(history,next)
    if continuous and sampling.has("native_transform"):handle.root.transform=sampling.native_transform
    _properties(handle,next)
    _emissions(handle,handle.get("emissions_through",0.0),next)
    handle.emissions_through=next
    # Use the original native fixed_fps accumulator/interpolation, including its
    # initial clear step. request_particles_process has different substep rules
    # and therefore is deliberately not used for the selected native scenes.
    var rate=(next-float(handle.age))/minf(frame_seconds,.1)
    for binding in handle.emitters:binding.node.speed_scale=rate
    handle.pending=true
    # Distinct closures own concurrent occurrence completions. On the native
    # build, same-method bound Callables compare equal despite different args.
    RenderingServer.frame_post_draw.connect(func():_after_draw(handle,next),CONNECT_ONE_SHOT)
    return {"ready":false,"age":handle.age,"submitted_age":next,"error":""}

static func set_view(handle: Dictionary, camera_basis: Basis) -> void:
    if handle.get("record",{}).get("kind","")!="class_component": return
    var origin: Vector3=handle.root.position
    var direction=Vector2(camera_basis.z.x,camera_basis.z.z)
    for node in handle.subject.ribbons+handle.subject.motes:
        node.material_override.set_shader_parameter("camera_ground",direction)
        node.material_override.set_shader_parameter("source_origin",origin)

static func add_palette_pass(viewport: SubViewport, record: Dictionary, source_texture: Texture2D = null) -> ShaderMaterial:
    var palette: Dictionary=record.get("palette",{})
    if palette.is_empty(): return null
    var material=ShaderMaterial.new()
    match palette.operator:
        "class_neutral":
            material.shader=ClassPalette
            for i in 3:material.set_shader_parameter(["palette_low","palette_middle","palette_high"][i],Color(palette.colors[i]))
        "factory_cie":
            material.shader=VfxPackageIO_e75a72d184.resource(palette.shader)
            material.set_shader_parameter("palette_texture",_palette_texture(palette.palette))
            material.set_shader_parameter("palette_count",palette.palette.size())
            material.set_shader_parameter("ramp_texture",_palette_texture(palette.ramp))
            material.set_shader_parameter("ramp_count",palette.ramp.size())
            for name in palette.parameters:material.set_shader_parameter(name,palette.parameters[name])
        _:return null
    if source_texture!=null:
        # Forward+ screen-copy alpha is opaque. The original transparent source
        # viewport texture preserves RGBA, as Factory's data-finish path does.
        var shader=Shader.new()
        shader.code=material.shader.code.replace("hint_screen_texture, ","")
        material.shader=shader
        material.set_shader_parameter("screen_texture",source_texture)
    var layer=CanvasLayer.new()
    var rectangle=ColorRect.new()
    rectangle.size=Vector2(viewport.size)
    rectangle.mouse_filter=Control.MOUSE_FILTER_IGNORE
    rectangle.material=material
    layer.add_child(rectangle)
    viewport.add_child(layer)
    return material

static func _palette_texture(colors: Array) -> ImageTexture:
    var image=Image.create(colors.size(),1,false,Image.FORMAT_RGBA8)
    for i in colors.size():image.set_pixel(i,0,Color(colors[i]))
    return ImageTexture.create_from_image(image)

static func _materials_during_release(node: Node, materials: Array) -> void:
    # Geometry destruction can flush another pending native instance update.
    # Retain each material RID until ALL source instances have been destroyed,
    # rather than freeing a unique child material partway through root.free().
    if node is GeometryInstance3D:
        if node.material_override!=null:materials.append(node.material_override)
        if node.material_overlay!=null:materials.append(node.material_overlay)
    if node is MeshInstance3D and node.mesh!=null:
        materials.append(node.mesh)
        for index in node.mesh.get_surface_count():
            var material=node.get_surface_override_material(index)
            if material!=null:materials.append(material)
            material=node.mesh.surface_get_material(index)
            if material!=null:materials.append(material)
    if node is GPUParticles3D:
        if node.process_material!=null:materials.append(node.process_material)
        for index in node.draw_passes:
            var mesh:Mesh=node.get_draw_pass_mesh(index)
            if mesh!=null:
                materials.append(mesh)
                for surface in mesh.get_surface_count():
                    var material=mesh.surface_get_material(surface)
                    if material!=null:materials.append(material)
    for child in node.get_children():_materials_during_release(child,materials)

static func release(handle: Dictionary) -> void:
    var materials:Array=[]
    if is_instance_valid(handle.get("root")):
        _materials_during_release(handle.root,materials)
        handle.root.free()
    handle.clear()
    materials.clear()

const VfxPackageIO_e75a72d184 = preload("res://assets/vfx/extensions/input-reduction-20261021/scoped_resource_io.gd")
