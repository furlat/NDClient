extends RefCounted
const SourceMaterial=preload("res://presentation/source_material.gd")
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
var lit_sprites:=false # Sprites display their own lit materials (play.gd lit_sprites).
var actors:Dictionary={}
var floors:Dictionary={}
var owner:Node3D
var _plane:PlaneMesh
var _floor_material:ShaderMaterial
var viewport:SubViewport
var camera:Camera3D
var depth_copy:MeshInstance3D
var solid_masks:Dictionary={}
# Inputs of the last adopt(): residency revision and selected (path, slot) pairs.
var _adopt_key:Array=[]
var _adopt_result:Dictionary={}
var issues:Array=[]
var ready:bool=true
var _outputs:Array=[]
var _source_bindings:Dictionary={}
var clear_effect:CompositorEffect
var enabled:bool=true
var last_sync_phases:Dictionary={}

static func required_paths(path:String,slot:String,cache:Dictionary)->Dictionary:
    return Geometry.BodySources.descriptor(path,slot,cache).get("optical_paths",{})

static func socket_samples_ready(path:String,slot:String,cache:Dictionary)->bool:
    return Geometry.BodySources.descriptor(path,slot,cache).get("sockets",{}).get("valid",false)

static func cpu_required_paths(path:String,slot:String,cache:Dictionary,_prepare_samples:bool=false)->Dictionary:
    var descriptor:Dictionary=Geometry.BodySources.descriptor(path,slot,cache)
    var paths:Dictionary=descriptor.get("optical_paths",{})
    if paths.is_empty():return {}
    var result:Dictionary={paths.colour:true}
    if not descriptor.get("sockets",{}).get("valid",false):
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
    # The result depends only on each selected layer's displayed path/slot and
    # on which textures are resident. A host that tracks residency changes
    # skips the descriptor walk while neither changed.
    var revision:Variant=host.get("texture_revision")
    var key:Array=[revision]
    for visual in host.visual_actors.values():
        for entry in visual.entries:
            if entry.role=="shadow" or not entry.actor_layer.get("effect",{}).is_empty():continue
            var path:String=entry.get("texture_path","")
            if not path.is_empty():key.append(path);key.append(entry.actor_layer.slot)
    if revision!=null and key==_adopt_key:return _adopt_result
    var pending:Array=[]
    for index in range(1,key.size(),2):
        var path:String=key[index]
        var paths=required_paths(path,key[index+1],host.catalog_cache)
        if paths.is_empty():continue
        if not host.textures.has(paths.solid):pending.append(paths.solid);continue
        solid_masks[path]=host.textures[paths.solid]
    _adopt_key=key;_adopt_result={"ready":pending.is_empty(),"pending":pending}
    return _adopt_result

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
        solid_masks.clear();_adopt_key=[]
        for node in actors.values():
            for parameter in ["sheet","received","component_depth","component_support","component_solid"]:
                node.material_override.set_shader_parameter(parameter,null)
            node.material_override.remove_meta(&"native_scene_written")

func _floor(id:int)->MeshInstance3D:
    if not floors.has(id):
        var node=MeshInstance3D.new();node.visible=false;node.mesh=_plane;node.material_override=_floor_material
        node.layers=LAYER;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        owner.add_child(node);floors[id]=node
    return floors[id]

func _batch_floor(entry:Dictionary)->MultiMeshInstance3D:
    var id:int=entry.node.get_instance_id()
    if not floors.has(id):
        var node=MultiMeshInstance3D.new();node.visible=false
        node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
        node.multimesh.mesh=_plane;node.material_override=_floor_material
        node.layers=LAYER;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        owner.add_child(node);floors[id]=node
    var receiver:MultiMeshInstance3D=floors[id]
    # Ground publication owns this version. Camera and lighting updates do not
    # rebuild unchanged world-space contact planes. Unversioned callers refresh.
    if entry.has("ground_version") and receiver.get_meta("ground_version",-1)==entry.ground_version:return receiver
    var rows:Array=entry.batch_rows
    receiver.multimesh.instance_count=rows.size()
    for index in rows.size():
        receiver.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY,Placement.contact(rows[index])))
    if entry.has("ground_version"):receiver.set_meta("ground_version",entry.ground_version)
    return receiver

func _actor(id:String)->MeshInstance3D:
    if not actors.has(id):
        var node=MeshInstance3D.new();node.visible=false;node.material_override=ShaderMaterial.new()
        node.material_override.shader=CharacterDepth
        node.layers=LAYER;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        owner.add_child(node);actors[id]=node
    return actors[id]

func prepare_membership(static_entries:Array,visual_actors:Dictionary,budget:Dictionary={})->Dictionary:
    # Membership/geometry allocation belongs to the existing cue preparation
    # account. New proxies stay hidden until sync publishes the displayed cut.
    var result:Dictionary={"ready":true,"pending":0}
    var retained_floors:Dictionary={}
    for entry in static_entries:
        if entry.role!="terrain" or not entry.node.visible:continue
        var id:int=entry.node.get_instance_id();retained_floors[id]=true
        var changed:bool=not floors.has(id) or (entry.has("batch_rows") and (not entry.has("ground_version") or floors[id].get_meta("ground_version",-1)!=entry.ground_version))
        if not changed:continue
        if not budget.is_empty() and budget.used_usec>=budget.limit_usec:
            result.ready=false;result.pending+=1;continue
        var started:int=Time.get_ticks_usec()
        if entry.has("batch_rows"):_batch_floor(entry)
        else:_floor(id).position=Placement.contact(entry.placement)
        if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
    var retained_actors:Dictionary={}
    for visual in visual_actors.values():
        for source in visual.entries:
            if source.role=="shadow" or not source.actor_layer.get("effect",{}).is_empty() or not source.node.visible or (not lit_sprites and not source.has("received_material")):continue
            var alpha:Variant=SourceMaterial.value(source,"condition_alpha")
            if alpha!=null and float(alpha)<1.0:continue
            retained_actors[source.id]=true
            if actors.has(source.id):continue
            if not budget.is_empty() and budget.used_usec>=budget.limit_usec:
                result.ready=false;result.pending+=1;continue
            var started:int=Time.get_ticks_usec()
            _actor(source.id).mesh=source.node.mesh
            if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
    for pair in [[floors,retained_floors],[actors,retained_actors]]:
        for id in pair[0].keys():
            if pair[1].has(id):continue
            pair[0][id].visible=false
            if not budget.is_empty() and budget.used_usec>=budget.limit_usec:continue
            var started:int=Time.get_ticks_usec()
            pair[0][id].free();pair[0].erase(id);_source_bindings.erase(id)
            if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
    return result

func prepare_boundary(candidate:Node3D,jobs:Array,state:Dictionary,budget:Dictionary)->bool:
    if state.is_empty():state.merge({"cursor":0,"floors":{},"actors":{},"published":false})
    while state.cursor<jobs.size():
        if budget.used_usec>=budget.limit_usec:return false
        var started:int=Time.get_ticks_usec()
        var job:Dictionary=jobs[state.cursor];var entry:Dictionary=job.entry
        var snapshot:Dictionary=job.get("prepared",{}).get("snapshot",entry)
        if entry.role=="terrain":
            var id:int=entry.node.get_instance_id()
            var same:bool=floors.has(id) and (not snapshot.has("batch_rows") or (snapshot.has("ground_version") and floors[id].get_meta("ground_version",-1)==snapshot.ground_version))
            if not same:
                var node:GeometryInstance3D
                if snapshot.has("batch_rows"):
                    var batch=MultiMeshInstance3D.new();batch.multimesh=MultiMesh.new()
                    batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.mesh=_plane
                    var rows:Array=snapshot.batch_rows
                    batch.multimesh.instance_count=rows.size()
                    for index in rows.size():
                        var row:Dictionary=snapshot.get("ground_row_changes",{}).get(str(rows[index].id),rows[index])
                        batch.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY,Placement.contact(row)))
                    if snapshot.has("ground_version"):batch.set_meta("ground_version",snapshot.ground_version)
                    node=batch
                else:
                    var floor_node=MeshInstance3D.new();floor_node.mesh=_plane
                    floor_node.position=Placement.contact(snapshot.placement);node=floor_node
                node.visible=false;node.material_override=_floor_material;node.layers=LAYER
                node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                candidate.add_child(node);state.floors[id]=node
        elif entry.has("actor_layer") and entry.role!="shadow" and entry.actor_layer.get("effect",{}).is_empty() and not actors.has(entry.id):
            var node=MeshInstance3D.new();node.visible=false;node.mesh=entry.node.mesh
            node.material_override=ShaderMaterial.new();node.material_override.shader=CharacterDepth
            node.layers=LAYER;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            candidate.add_child(node);state.actors[entry.id]=node
        state.cursor+=1;budget.used_usec+=Time.get_ticks_usec()-started
    return true

func publish_boundary(state:Dictionary)->void:
    if state.is_empty() or state.published:return
    for pair in [[floors,state.floors],[actors,state.actors]]:
        for id in pair[1]:
            var node:GeometryInstance3D=pair[1][id]
            if pair[0].has(id):pair[0][id].visible=false;pair[0][id].queue_free()
            node.reparent(owner,false);pair[0][id]=node
    state.floors={};state.actors={};state.published=true

func prepare_hidden(static_entries:Array,visual_actors:Dictionary)->void:
    # Retained for fixture/prewarm callers; ordinary sampling never invokes it.
    if enabled:return
    prepare_membership(static_entries,visual_actors,{"used_usec":0,"limit_usec":500})

func sync(static_entries:Array,visual_actors:Dictionary,view_camera:Camera3D)->void:
    ready=true;issues.clear()
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
        if not floors.has(id):
            ready=false;issues.append("Native floor receiver not prepared: "+str(entry.id));continue
        if entry.has("batch_rows"):
            if entry.has("ground_version") and floors[id].get_meta("ground_version",-1)!=entry.ground_version:
                ready=false;issues.append("Native floor receiver membership not prepared: "+str(entry.id));continue
        else:
            var floor_node:MeshInstance3D=floors[id]
            var contact:Vector3=Placement.contact(entry.placement)
            if floor_node.position!=contact:floor_repositioned+=1
            floor_node.position=contact
        floors[id].visible=true
        if lit_sprites or entry.has("received_material"):
            var displayed:ShaderMaterial=_displayed(entry)
            _outputs.append(displayed)
            live_outputs[displayed]=true
            displayed.set_shader_parameter("native_scene_enabled",true)
            displayed.set_shader_parameter("native_scene_plane",true)
        floor_binding_usec+=Time.get_ticks_usec()-binding_started
    var floor_retirement_started:int=Time.get_ticks_usec()
    for id in floors.keys():
        if not retained.has(id):floors[id].visible=false
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
    var proxy_writes:int=0
    for visual in visual_actors.values():
        for source in visual.entries:
            if source.role=="shadow" or not source.actor_layer.get("effect",{}).is_empty():continue
            var has_geometry:bool=SourceMaterial.value(source,"has_component_geometry")==true
            if lit_sprites or source.has("received_material"):
                var output:ShaderMaterial=_displayed(source)
                _outputs.append(output)
                live_outputs[output]=true
                output.set_shader_parameter("native_scene_enabled",has_geometry and source.node.visible)
                output.set_shader_parameter("native_scene_plane",false)
                output.set_shader_parameter("native_scene_pivot",source.pivot)
                if has_geometry:output.set_shader_parameter("native_scene_ground_height",source.get("geometry_ground_pixels",19.0)*SourceMaterial.value(source,"component_units"))
            if not source.node.visible or (not lit_sprites and not source.has("received_material")):continue
            # Translucent bodies require transparent compositing, not an
            # invisible opaque blocker. This bridge admits solid surfaces only.
            var condition_alpha:Variant=SourceMaterial.value(source,"condition_alpha")
            if condition_alpha!=null and float(condition_alpha)<1.0:continue
            var solid:Texture2D=solid_masks.get(source.texture_path)
            var id:String=source.id
            retained[id]=true
            if not actors.has(id):
                ready=false;issues.append("Native actor receiver not prepared: "+str(id));continue
            var node:MeshInstance3D=actors[id];node.visible=true
            node.mesh=source.node.mesh;node.global_transform=source.node.global_transform
            node.sorting_use_aabb_center=false;node.sorting_offset=source.node.sorting_offset
            var material:ShaderMaterial=node.material_override
            material.render_priority=source.material.render_priority
            # Production sprite bindings publish a version only after the
            # complete frame/geometry material changes. Unstamped callers keep
            # the exhaustive path; moving the proxy still updates every frame.
            var binding:Array=[source.material,source.material.shader,source.get("source_version")]
            if not source.has("source_version") or _source_bindings.get(id)!=binding:
                for parameter in Shadows.CASTER_PARAMETERS:material.set_shader_parameter(parameter,SourceMaterial.value(source,parameter))
                _source_bindings[id]=binding
            # Lit sprites address their cell texel directly; atlas outputs name it by atlas address.
            var received:ShaderMaterial=null if lit_sprites else source.received_material
            var values:Array=[received.get_shader_parameter("received") if received!=null else null,
                received.get_shader_parameter("source_crop") if received!=null else Vector4(0,0,1,1),
                received.get_shader_parameter("atlas_region") if received!=null else Vector4.ZERO,received!=null,has_geometry and solid!=null,solid,
                source.get("geometry_cell_size",source.cell),view_camera.global_basis,source.pivot,
                source.get("geometry_ground_pixels",19.0)*SourceMaterial.value(source,"component_units") if has_geometry else null]
            # The proxy owns these uniforms; write them only when a value changed.
            if material.get_meta(&"native_scene_written",[])!=values:
                for index in PROXY_PARAMETERS.size():
                    if values[index]!=null or index<PROXY_PARAMETERS.size()-1:material.set_shader_parameter(PROXY_PARAMETERS[index],values[index])
                material.set_meta(&"native_scene_written",values)
                proxy_writes+=1
    for id in actors.keys():
        if not retained.has(id):actors[id].visible=false
    last_sync_phases.actors=(Time.get_ticks_usec()-phase_started)/1000.0
    last_sync_phases.actor_receivers=retained.size()
    last_sync_phases.actor_uniform_writes=proxy_writes
    phase_started=Time.get_ticks_usec()
    # Output materials retained by this pass keep their enabled state. Reset
    # only retired owners rather than disabling/re-enabling every floor/body.
    for material in previous_outputs:
        if not live_outputs.has(material):material.set_shader_parameter("native_scene_enabled",false)
    last_sync_phases.retirement=(Time.get_ticks_usec()-phase_started)/1000.0

const PROXY_PARAMETERS=["received","source_crop","atlas_region","atlas_addressed","has_geometry","component_solid","component_cell_size",
    "display_basis","sprite_pivot","ground_height"]

func close()->void:
    clear_effect=null
    for material in _outputs:material.set_shader_parameter("native_scene_enabled",false)
    _outputs.clear()
    _source_bindings.clear()
    solid_masks.clear();_adopt_key=[]
    if is_instance_valid(depth_copy):depth_copy.free()
    if is_instance_valid(owner):owner.free()
    if is_instance_valid(viewport):viewport.free()
    actors.clear();floors.clear()

# The atlas output, or the sprite's own material when sprites are lit in place.
func _displayed(entry:Dictionary)->ShaderMaterial:
    return entry.material if lit_sprites else entry.received_material
