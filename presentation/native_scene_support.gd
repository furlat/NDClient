extends RefCounted
## Receiver geometry for native VFX, sourced from the same displayed records as
## the sprite renderer. No inferred walls, physics bodies or CPU pixel meshes.
const Placement=preload("res://placement.gd")
const Shadows=preload("res://presentation/canvas_shadows.gd")
const Geometry=preload("res://presentation/character_geometry.gd")
const SocketSamples=preload("res://presentation/surface_socket_samples.gd")
const FloorDepth=preload("res://presentation/native_effect_depth.gdshader")
const CharacterDepth=preload("res://presentation/native_scene_support.gdshader")
const DepthCopy=preload("res://presentation/native_scene_depth_copy.gdshader")
const LAYER=1<<14
const DEPTH_LAYER=1<<13
var actors:Dictionary={}
var floors:Dictionary={}
var owner:Node3D
var _plane:PlaneMesh
var _floor_material:ShaderMaterial
var viewport:SubViewport
var camera:Camera3D
var depth_copy:MeshInstance3D
var solid_masks:Dictionary={}
var issues:Array=[]
var _outputs:Array=[]
var _source_bindings:Dictionary={}
var clear_effect:CompositorEffect
var enabled:bool=true
var last_sync_phases:Dictionary={}

static func required_paths(path:String,slot:String,cache:Dictionary)->Dictionary:
    var record=Geometry.record(path,slot,cache)
    if record.is_empty() or not record.has("reference"):return {}
    var root:String=Geometry._root(record)
    var reference:String=root.path_join(record.reference)
    # The delivered reference owns the mask directory; no guessed asset ID.
    return {"colour":path,"depth":root.path_join(record.files.depth),
        "support":root.path_join(record.files.support),
        "solid":reference.get_base_dir().path_join("solid-valid.png")}

static func socket_samples_ready(path:String,slot:String,cache:Dictionary)->bool:
    var record=Geometry.record(path,slot,cache)
    return not record.is_empty() and SocketSamples.ready(path,record,cache)

static func cpu_required_paths(path:String,slot:String,cache:Dictionary,prepare_samples:bool=false)->Dictionary:
    var paths=required_paths(path,slot,cache)
    if paths.is_empty():return {}
    var record=Geometry.record(path,slot,cache)
    var compact:bool=SocketSamples.prepare(path,record,Geometry._root(record),cache) if prepare_samples else SocketSamples.ready(path,record,cache)
    var result={paths.colour:true}
    if not compact:
        for value in paths.values():result[value]=true
    return result

func prepare(path:String,slot:String,host:Node)->void:
    if solid_masks.has(path) and solid_masks[path]!=null:return
    var paths=required_paths(path,slot,host.catalog_cache)
    if paths.is_empty():return
    # Fixture callers explicitly load before playback. The player loader only
    # accepts images already admitted by its ordinary media preparation owner.
    var mask:Texture2D=host.texture(paths.solid)
    if mask!=null:solid_masks[path]=mask

func adopt(host:Node)->Dictionary:
    var pending:Array=[]
    for visual in host.visual_actors.values():
        for entry in visual.entries:
            if entry.role=="shadow" or not entry.actor_layer.get("effect",{}).is_empty():continue
            var path:String=entry.get("texture_path","")
            if path.is_empty():continue
            var paths=required_paths(path,entry.actor_layer.slot,host.catalog_cache)
            if paths.is_empty():continue
            if not host.textures.has(paths.solid):pending.append(paths.solid);continue
            solid_masks[path]=host.textures[paths.solid]
    return {"ready":pending.is_empty(),"pending":pending}

func attach_shared(host:Node3D)->void:
    _attach(host,host,null)


func attach(host:Node3D,native_viewport:SubViewport,effect_camera:Camera3D)->void:
    _attach(host,native_viewport,effect_camera)

func _attach(host:Node3D,viewport_parent:Node,effect_camera:Camera3D)->void:
    owner=Node3D.new();owner.name="NativeEffectReceivers";host.add_child(owner)
    _plane=PlaneMesh.new();_plane.size=Vector2.ONE
    _floor_material=ShaderMaterial.new();_floor_material.shader=FloorDepth
    viewport=SubViewport.new();viewport.world_3d=host.get_world_3d()
    viewport.transparent_bg=true;viewport.use_hdr_2d=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    viewport_parent.add_child(viewport)
    RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
    camera=Camera3D.new();camera.cull_mask=LAYER;viewport.add_child(camera)
    depth_copy=MeshInstance3D.new();depth_copy.mesh=QuadMesh.new();depth_copy.mesh.size=Vector2(2,2)
    depth_copy.material_override=ShaderMaterial.new();depth_copy.material_override.shader=DepthCopy
    depth_copy.material_override.set_shader_parameter("receiver_depth",viewport.get_texture())
    depth_copy.layers=DEPTH_LAYER;depth_copy.position.z=-1
    depth_copy.custom_aabb=AABB(Vector3(-10000,-10000,-10000),Vector3(20000,20000,20000))
    depth_copy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if effect_camera!=null:effect_camera.add_child(depth_copy)
    else:owner.add_child(depth_copy)
    host.camera.cull_mask &= ~(LAYER|DEPTH_LAYER)

func set_enabled(value:bool)->void:
    if enabled==value:return
    enabled=value
    owner.visible=value
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
    if not value:
        for material in _outputs:material.set_shader_parameter("native_scene_enabled",false)
        _outputs.clear()
        _source_bindings.clear()
        solid_masks.clear()
        for node in actors.values():
            for parameter in ["sheet","received","component_depth","component_support","component_solid"]:
                node.material_override.set_shader_parameter(parameter,null)

func _floor(id:int)->MeshInstance3D:
    if not floors.has(id):
        var node=MeshInstance3D.new();node.mesh=_plane;node.material_override=_floor_material
        node.layers=LAYER;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        owner.add_child(node);floors[id]=node
    return floors[id]

func _actor(id:String)->MeshInstance3D:
    if not actors.has(id):
        var node=MeshInstance3D.new();node.material_override=ShaderMaterial.new()
        node.material_override.shader=CharacterDepth
        node.layers=LAYER;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        owner.add_child(node);actors[id]=node
    return actors[id]

func prepare_hidden(static_entries:Array,visual_actors:Dictionary)->void:
    # Only already-displayed receiver geometry, under a hidden owner and a
    # disabled viewport. No output uniforms, future state or texture pins.
    if enabled:return
    var started:int=Time.get_ticks_usec()
    var created:int=0
    var retained_floors:Dictionary={}
    for entry in static_entries:
        if entry.role!="terrain" or not entry.node.visible:continue
        var id:int=entry.node.get_instance_id()
        retained_floors[id]=true
        if floors.has(id):continue
        _floor(id).position=Placement.contact(entry.placement)
        created+=1
        if created>=2 or Time.get_ticks_usec()-started>=500:return
    var retained_actors:Dictionary={}
    for visual in visual_actors.values():
        for source in visual.entries:
            if source.role=="shadow" or not source.actor_layer.get("effect",{}).is_empty() \
                    or not source.node.visible:continue
            retained_actors[source.id]=true
            if actors.has(source.id):continue
            _actor(source.id).mesh=source.node.mesh
            created+=1
            if created>=2 or Time.get_ticks_usec()-started>=500:return
    for pair in [[floors,retained_floors],[actors,retained_actors]]:
        for id in pair[0].keys():
            if pair[1].has(id):continue
            pair[0][id].free();pair[0].erase(id)
            created+=1
            if created>=2 or Time.get_ticks_usec()-started>=500:return

func sync(static_entries:Array,visual_actors:Dictionary,view_camera:Camera3D)->void:
    var phase_started:int=Time.get_ticks_usec()
    var previous_outputs:Array=_outputs
    _outputs=[]
    var live_outputs:Dictionary={}
    viewport.size=Vector2i(view_camera.get_viewport().get_visible_rect().size)
    camera.global_transform=view_camera.global_transform
    for property in ["projection","keep_aspect","size","near","far"]:camera.set(property,view_camera.get(property))
    last_sync_phases={"camera":(Time.get_ticks_usec()-phase_started)/1000.0}
    phase_started=Time.get_ticks_usec()
    var retained={}
    var floor_created:int=0;var floor_retired:int=0;var floor_repositioned:int=0
    var floor_binding_usec:int=0
    var floor_sources:Array=[]
    for entry in static_entries:
        if entry.role!="terrain" or not entry.node.visible:continue
        var binding_started:int=Time.get_ticks_usec()
        # A batched terrain representative can change while its displayed
        # geometry owner remains the same. Follow that owner, not its row ID.
        var id:int=entry.node.get_instance_id();retained[id]=true
        floor_sources.append([entry.id,id])
        if not floors.has(id):floor_created+=1
        var floor_node:MeshInstance3D=_floor(id)
        var contact:Vector3=Placement.contact(entry.placement)
        if floor_node.position!=contact:floor_repositioned+=1
        floor_node.position=contact
        if entry.has("received_material"):
            _outputs.append(entry.received_material)
            live_outputs[entry.received_material]=true
            entry.received_material.set_shader_parameter("native_scene_enabled",true)
            entry.received_material.set_shader_parameter("native_scene_plane",true)
        floor_binding_usec+=Time.get_ticks_usec()-binding_started
    var floor_retirement_started:int=Time.get_ticks_usec()
    for id in floors.keys():
        if not retained.has(id):floors[id].free();floors.erase(id);floor_retired+=1
    var floor_retirement_usec:int=Time.get_ticks_usec()-floor_retirement_started
    last_sync_phases.floor=(Time.get_ticks_usec()-phase_started)/1000.0
    last_sync_phases.floor_binding=floor_binding_usec/1000.0
    last_sync_phases.floor_retirement=floor_retirement_usec/1000.0
    last_sync_phases.floor_scan=last_sync_phases.floor-last_sync_phases.floor_binding-last_sync_phases.floor_retirement
    last_sync_phases.static_entries=static_entries.size()
    last_sync_phases.floor_receivers=retained.size()
    last_sync_phases.floor_created=floor_created
    last_sync_phases.floor_retired=floor_retired
    last_sync_phases.floor_repositioned=floor_repositioned
    last_sync_phases.floor_sources=floor_sources
    phase_started=Time.get_ticks_usec()
    retained={}
    for visual in visual_actors.values():
        for source in visual.entries:
            if source.role=="shadow" or not source.actor_layer.get("effect",{}).is_empty():continue
            var has_geometry:bool=source.material.get_shader_parameter("has_component_geometry")==true
            if source.has("received_material"):
                var output:ShaderMaterial=source.received_material
                _outputs.append(output)
                live_outputs[output]=true
                output.set_shader_parameter("native_scene_enabled",has_geometry and source.node.visible)
                output.set_shader_parameter("native_scene_plane",false)
                output.set_shader_parameter("native_scene_pivot",source.pivot)
                if has_geometry:output.set_shader_parameter("native_scene_ground_height",source.get("geometry_ground_pixels",19.0)*source.material.get_shader_parameter("component_units"))
            if not source.node.visible or not source.has("received_material"):continue
            # Translucent bodies require transparent compositing, not an
            # invisible opaque blocker. This bridge admits solid surfaces only.
            var condition_alpha:Variant=source.material.get_shader_parameter("condition_alpha")
            if condition_alpha!=null and float(condition_alpha)<1.0:continue
            var solid:Texture2D=solid_masks.get(source.texture_path)
            var id:String=source.id
            retained[id]=true
            var node:MeshInstance3D=_actor(id)
            node.mesh=source.node.mesh;node.global_transform=source.node.global_transform
            node.sorting_use_aabb_center=false;node.sorting_offset=source.node.sorting_offset
            var material:ShaderMaterial=node.material_override
            material.render_priority=source.material.render_priority
            for parameter in ["received","source_crop","atlas_region"]:
                material.set_shader_parameter(parameter,source.received_material.get_shader_parameter(parameter))
            # Production sprite bindings publish a version only after the
            # complete frame/geometry material changes. Unstamped callers keep
            # the exhaustive path; moving the proxy still updates every frame.
            var binding:Array=[source.material,source.material.shader,source.get("source_version")]
            if not source.has("source_version") or _source_bindings.get(id)!=binding:
                for parameter in Shadows.CASTER_PARAMETERS:material.set_shader_parameter(parameter,source.material.get_shader_parameter(parameter))
                _source_bindings[id]=binding
            material.set_shader_parameter("has_geometry",has_geometry and solid!=null)
            material.set_shader_parameter("component_solid",solid)
            material.set_shader_parameter("component_cell_size",source.get("geometry_cell_size",source.cell))
            material.set_shader_parameter("display_basis",view_camera.global_basis)
            material.set_shader_parameter("sprite_pivot",source.pivot)
            if has_geometry:material.set_shader_parameter("ground_height",source.get("geometry_ground_pixels",19.0)*source.material.get_shader_parameter("component_units"))
    for id in actors.keys():
        if not retained.has(id):actors[id].free();actors.erase(id);_source_bindings.erase(id)
    last_sync_phases.actors=(Time.get_ticks_usec()-phase_started)/1000.0
    last_sync_phases.actor_receivers=retained.size()
    phase_started=Time.get_ticks_usec()
    # Output materials retained by this pass keep their enabled state. Reset
    # only retired owners rather than disabling/re-enabling every floor/body.
    for material in previous_outputs:
        if not live_outputs.has(material):material.set_shader_parameter("native_scene_enabled",false)
    last_sync_phases.retirement=(Time.get_ticks_usec()-phase_started)/1000.0

func close()->void:
    clear_effect=null
    for material in _outputs:material.set_shader_parameter("native_scene_enabled",false)
    _outputs.clear()
    _source_bindings.clear()
    solid_masks.clear()
    if is_instance_valid(depth_copy):depth_copy.free()
    if is_instance_valid(owner):owner.free()
    if is_instance_valid(viewport):viewport.free()
    actors.clear();floors.clear()
