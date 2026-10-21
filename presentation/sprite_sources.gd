extends Node3D
# Original source-sprite creation shared by workshop/live views and the passive
# quarter builder. No session, input, rules or displayed-state ownership lives here.
const SourceMaterial=preload("res://presentation/source_material.gd")
const FrameProfile = preload("res://frame_profile.gd")
const Placement = preload("res://placement.gd")
const Catalog = preload("res://source_catalog.gd")
const GroundGeometry = preload("res://presentation/ground_data.gd")
const EnvironmentSource=preload("res://presentation/environment_source.gd")
const Graphs = preload("res://animation/graphs.gd")
const ENVIRONMENT_SHADER = preload("res://environment.gdshader")
const WATER_SHADER = preload("res://water.gdshader")
var profile = FrameProfile.create()
var catalog_cache: Dictionary = {}
var entries: Array = []
var actor_entries: Array = []
var rig_config: Dictionary
var rigs: Dictionary
var camera: Camera3D
var quarter = 0
var source_depth = true
var source_normals = true
var destruction: Dictionary = {}
var water_clock_seconds := 0.0
var water_materials: Array = []
var source_images: Dictionary = {}
const Order = preload("res://grid_order.gd")
const FIXTURE_FLAME_SHADER = preload("res://presentation/fixture_flame.gdshader")
var static_entries: Array = []
# Active source-owned animated scenery, maintained at ordinary row publication.
var world_media_entries: Array = []
var fixture_entries: Array = []
var fixture_clips: Dictionary = {}
var fixture_clock_owner: Node
var fixture_frame_energy: Dictionary = {}
var fixture_frame_centroids: Dictionary = {}
var presentation_errors: Array = []
var media_issue = ""
var sprite_parent: Node3D
# Host members shared by the live player and the workshop (moved from main.gd
# so the live player no longer extends the workshop).
const CharacterGeometry = preload("res://presentation/character_geometry.gd")
const QuadShapes = preload("res://presentation/quad_shapes.gd")
const EnvironmentMedia = preload("res://presentation/environment_media.gd")
var grid_visible = false
var textures: Dictionary = {}
var texture_last_use: Dictionary = {}
var scenes: Array
var placements: Array = []
var actor_rows: Array = []
var player: Dictionary
var resources: Dictionary
var components: Dictionary
var status: Label
var playbacks: Dictionary = {}
var unresolved: Array = []
var draw_order: Array = []
var camera_focus = Vector3.ZERO

func texture(_path: String) -> Texture2D:
    assert(false,"A source renderer requires its owning prepared texture loader")
    return null

func _light_entry(_entry: Dictionary) -> void:
    pass

func matrix3(rows: Array) -> Basis:
    return Basis(Vector3(rows[0][0], rows[1][0], rows[2][0]), Vector3(rows[0][1], rows[1][1], rows[2][1]), Vector3(rows[0][2], rows[1][2], rows[2][2]))

func matrix4(rows: Array) -> Transform3D:
    return Transform3D(matrix3(rows), Vector3(rows[0][3], rows[1][3], rows[2][3]))

func v2(values: Array) -> Vector2:
    return Vector2(values[0], values[1])

func v4(values: Array) -> Vector4:
    return Vector4(values[0], values[1], values[2], values[3])

func add_environment_entries(row: Dictionary) -> void:
    var role: String = row.get("sort_role", row.kind if row.kind in ["terrain", "wall", "cliff"] else "body")
    add_entry(row, "shadow", int(row.get("layer", 0)) * 10, ENVIRONMENT_SHADER, 0)
    if row.kind == "door":
        add_entry(row,role,int(row.get("layer",0))*10,ENVIRONMENT_SHADER,3)
        add_entry(row,role,int(row.get("layer",0))*10+1,ENVIRONMENT_SHADER,2)
    add_entry(row, role, int(row.get("layer", 0)) * 10 + 2, ENVIRONMENT_SHADER, 1)

func record_for(row: Dictionary) -> Dictionary:
    var phase = 0
    var time = 0.0
    if destruction.has(row.id):
        var playback: Node = destruction[row.id]
        phase = playback.phase
        time = playback.sample_seconds
    return Catalog.environment(row, quarter, catalog_cache, phase, time)

## The shader a sprite of this kind uses here. The workshop substitutes its
## 3D-lit variants; the game uses the light-table shaders as given.
func sprite_shader(shader: Shader) -> Shader:
    return shader

func add_entry(row: Dictionary, role: String, layer: int, shader: Shader, source_role: int = -1) -> void:
    shader = sprite_shader(shader)
    var node = MeshInstance3D.new()
    node.mesh = QuadShapes.mesh(Vector2.ONE)
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.sorting_use_aabb_center = false
    var material = ShaderMaterial.new()
    material.shader = shader
    node.material_override = material
    (sprite_parent if sprite_parent != null and row.kind != "actor" else self).add_child(node)
    entries.append({"id": row.id + ":" + str(layer) + ":" + role, "placement": row, "role": role,
        "layer": layer, "source_role": source_role, "node": node, "material": material, "screen_rect": Rect2(),
        "mobile":row.kind=="actor"})
    SourceMaterial.initialize(entries.back())
    if row.kind == "actor": actor_entries.append(entries.back())

func initialize_entry(entry: Dictionary) -> void:
    var row: Dictionary = entry.placement
    entry.node.position = Placement.contact(row)
    entry.node.basis = camera.basis
    if row.kind == "actor":
        var rig: Dictionary = rigs[row.rig]
        var cell = Vector2(rig.cell_width, rig.cell_height)
        var pivot = Vector2(cell.x * 0.5, cell.y - rig.origin_y_from_ground)
        set_quad(entry, cell, pivot, 128.0 / rig_config.TILE_W)
        if entry.role == "shadow": SourceMaterial.set_parameter(entry,"shadow", true)
    else:
        set_environment(entry, Basis(Vector3.UP, quarter * PI * 0.5))

func set_quad(entry: Dictionary, cell: Vector2, pivot: Vector2, scale: float) -> void:
    var mesh: QuadMesh = QuadShapes.mesh(cell * scale / Placement.PIXELS_PER_UNIT,
        Vector3((cell.x * 0.5 - pivot.x) * scale / Placement.PIXELS_PER_UNIT,
        (pivot.y - cell.y * 0.5) * scale / Placement.PIXELS_PER_UNIT, 0.0))
    entry.node.mesh = mesh
    entry.material.set_shader_parameter("source_quad_size", mesh.size)
    entry.node.custom_aabb = mesh.get_aabb()
    entry.cell = cell
    entry.pivot = pivot
    entry.scale = scale
    update_bounds(entry)

func update_bounds(entry: Dictionary) -> void:
    var row: Dictionary = entry.placement
    var origin = Placement.project(v2(row.position), row.base_height_steps, quarter)
    entry.screen_rect = Rect2(origin - entry.pivot * entry.scale, entry.cell * entry.scale)
    if row.kind!="actor" or entry.get("body_scale",1.0)==1.0:return
    # These rectangles use canonical painter pixels, not viewport/zoom pixels.
    # The actual model owns body scale, mirroring and any passage composition.
    var mesh:QuadMesh=entry.node.mesh
    var inverse:Basis=camera.global_basis.inverse()
    var bounds:Rect2
    var first:bool=true
    for x in [-.5,.5]:
        for y in [-.5,.5]:
            var local:Vector3=mesh.center_offset+Vector3(x*mesh.size.x,y*mesh.size.y,0)
            var projected:Vector3=inverse*(entry.node.global_transform*local-Placement.contact(row))
            var point:Vector2=origin+Vector2(projected.x,-projected.y)*Placement.PIXELS_PER_UNIT
            bounds=Rect2(point,Vector2.ZERO) if first else bounds.expand(point)
            first=false
    entry.screen_rect=bounds

func _register_water_clock(entry:Dictionary)->void:
    if entry.get("water_clock_registered",false):return
    water_materials.append(entry)
    entry.water_clock_registered=true
    entry.node.tree_exited.connect(_release_water_clock.bind(entry),CONNECT_ONE_SHOT)

func _release_water_clock(entry:Dictionary)->void:
    water_materials.erase(entry)
    entry.erase("water_clock_registered")

func _environment_quad(entry:Dictionary,value:Dictionary)->void:
    entry.node.mesh=QuadShapes.mesh(value.mesh_size,value.mesh_center)
    entry.material.set_shader_parameter("source_quad_size",value.mesh_size)
    entry.node.custom_aabb=value.aabb
    entry.cell=value.cell;entry.pivot=value.pivot;entry.scale=value.scale
    entry.screen_rect=value.screen_rect
    if entry.placement.has("affine"):entry.node.basis=value.basis

func _apply_environment_descriptor(entry:Dictionary,value:Dictionary)->void:
    entry.record=value.record
    if value.get("empty",false):entry.node.visible=false;return
    _environment_quad(entry,value)
    entry.node.visible=value.visible;entry.floor_group=value.floor_group
    SourceMaterial.set_parameter(entry,"door_leaf_partition",0)
    SourceMaterial.apply(entry,value.parameters)
    for name in value.texture_parameters:
        SourceMaterial.set_parameter(entry,name,texture(value.texture_parameters[name]))
    if value.record.has("hit_mask"):texture(value.record.hit_mask.path)

## Sample the exact registered frame through the existing environment material.
## Preparation owns the complete source closure; this path creates no textures.
func sample_world_media_frame(entry:Dictionary,content:String,role:String,orientation:String,frame:int,visible:bool=true)->bool:
    var key:Array=[content,role,orientation,frame,quarter,source_depth,source_normals]
    if entry.get("world_media_frame_key",[])!=key:
        var record:Dictionary=Catalog.world_media_record(content,role,quarter,orientation,frame,catalog_cache)
        record=Catalog.texture_layout(Catalog.receiving_normal(record,catalog_cache),catalog_cache)
        if record.is_empty():entry.node.visible=false;return false
        entry.placement.orientation=orientation
        SourceMaterial.structural_change(entry)
        entry.node.position=Placement.contact(entry.placement);entry.node.basis=camera.basis
        _apply_environment_descriptor(entry,EnvironmentSource.describe(entry.placement,record,int(entry.get("source_role",1)),quarter,camera.basis,source_depth,source_normals))
        _light_entry(entry)
        entry.world_media_frame_key=key
        entry.world_media_content=content;entry.world_media_role=role;entry.world_media_frame=frame;entry.world_media_orientation=orientation
        entry.world_media_source_visible=entry.node.visible
    entry.node.visible=visible and entry.get("world_media_source_visible",false)
    return true

static func _world_media_token(value:Variant)->String:
    return JSON.stringify(value) if value is bool else str(value)

## State changes and source ages come from the existing observed owner cut.
## A first sight of an already open portal begins at hold, not a fake opening.
static func world_media_sample(program:Dictionary,role:String,token:String,owner:Dictionary,at_ms:float)->Dictionary:
    var observation:Dictionary={}
    var field:String=str(program.get("state_field","trap_state"))
    for row in owner.get("spatial_observations",[]):
        if float(row.at_ms)>at_ms:continue
        if row.get(field if field=="pressed" else "state")!=null:observation=row
    var elapsed:float=maxf(0.0,at_ms-float(observation.get("at_ms",owner.get("start_ms",at_ms))))
    if program.get("kind")=="portal":
        var source:Dictionary=program.get("roles",{}).get(role,{})
        var fps:float=float(source.get("fps",0.0))
        if fps<=0.0:return {"frame":0,"visible":false}
        var opening:bool=token=="activated"
        var changed:bool=not observation.is_empty() and (observation.get("previous_state")!=observation.get("state") or observation.get("operation")=="created")
        if role in ["hatch","hatch_front"]:
            var frames:Array=source.get("opening" if opening else "closing",[])
            if frames.is_empty():return {"frame":0,"visible":false}
            return {"frame":int(frames[mini(frames.size()-1,floori(elapsed*fps/1000.0))]) if changed else int(frames.back()),"visible":true}
        var count:int=int(source.get("opening_frames",0));var hold:int=int(source.get("hold_frames",0));var close:int=int(source.get("closing_frames",0))
        if opening:
            var cursor:int=floori(elapsed*fps/1000.0)+(0 if changed else count)
            return {"frame":cursor if cursor<count else count+posmod(cursor-count,maxi(1,hold)),"visible":true}
        var closing_frame:int=floori(elapsed*fps/1000.0)
        return {"frame":count+hold+mini(maxi(0,close-1),closing_frame),"visible":changed and closing_frame<close}
    var frame:int=int(program.get("state_frames",{}).get(token,0))
    if not observation.is_empty():
        var previous:Variant=observation.get("previous_pressed" if field=="pressed" else "previous_state")
        var current:Variant=observation.get("pressed" if field=="pressed" else "state")
        var frames:Array=program.get("transition_frames",{}).get(_world_media_token(previous)+":"+_world_media_token(current),[])
        var index:int=floori(elapsed*float(program.get("fps",0.0))/1000.0)
        if index>=0 and index<frames.size():frame=int(frames[index])
    return {"frame":frame,"visible":true}

func sample_world_media(owners:Dictionary,at_ms:float,samples:Array)->bool:
    var visibility_changed:bool=false
    var finite:Dictionary={}
    for component in samples:
        if component.get("kind")=="world_activation" and component.get("role","")!="portal_exit" and component.get("status")!="missing" and component.get("mechanism_uuid")!=null:
            finite[str(component.mechanism_uuid)]=true
    var programs:Dictionary=Catalog.environment_index(catalog_cache).get("spatial_media",{})
    for entry in world_media_entries:
        var row:Dictionary=entry.placement
        var owner:Dictionary=owners.get(row.spatial_effect_uuid,{})
        var program:Dictionary=programs.get(row.world_media_content,{})
        var sampled:Dictionary=world_media_sample(program,row.world_media_role,row.world_media_state,owner,at_ms)
        var admitted:bool=not owner.is_empty() and at_ms<float(owner.get("end_ms",INF)) and not finite.has(row.spatial_effect_uuid)
        var was_visible:bool=entry.node.visible
        sample_world_media_frame(entry,row.world_media_content,row.world_media_role,row.orientation,int(sampled.frame),admitted and bool(sampled.visible))
        visibility_changed=visibility_changed or (not entry.has("actor_depth_bands") and was_visible!=entry.node.visible)
    return visibility_changed

## Private sibling draws retain their original source owner's lifetime. Their
## only difference is the exact (lower, upper] painter-depth utility band.
func _release_actor_depth_bands(entry:Dictionary)->void:
    for band in entry.get("actor_depth_bands",[]):
        actor_entries.erase(band)
        if is_instance_valid(band.node):band.node.queue_free()
    entry.actor_depth_bands=[]

func prepare_actor_depth_bands(sources:Array,budget:Dictionary,tracks:Array=[])->bool:
    var complete:bool=true
    var programs:Dictionary=Catalog.environment_index(catalog_cache).get("spatial_media",{})
    for entry in sources:
        if entry.get("actor_depth_band",false) or int(entry.get("source_role",-1))!=1:continue
        var content:String=str(entry.get("world_media_content",entry.placement.get("world_media_content","")))
        var descriptor:Dictionary=programs.get(content,{}).get("actor_depth",{})
        if descriptor.is_empty():continue
        var peers:Dictionary={}
        var plane:int=int(Order.key(entry.placement,entry.role,entry.layer,quarter)[0])
        for peer in static_entries+actor_entries:
            if peer.get("actor_depth_band",false) or peer.placement.id==entry.placement.id or not peer.node.visible:continue
            if int(Order.key(peer.placement,peer.role,peer.layer,quarter)[0])!=plane:continue
            if entry.get("screen_rect",Rect2()).intersects(peer.get("screen_rect",Rect2())):peers[str(peer.placement.id)]=true
        for track in tracks:
            var actor_id:String=str(track.get("actor_uuid",""))
            var rig:Dictionary=rigs.get(track.get("rig",""),{})
            var actor:Dictionary=track.get("presentation_actor",{})
            var appearance:Dictionary=actor.get("appearance",{})
            if actor_id.is_empty() or rig.is_empty() or appearance.is_empty() or track.get("from_position")==null \
                or track.get("to_position")==null or not track.has("from_elevation_feet") or not track.has("to_elevation_feet"):continue
            var scale:float=128.0/float(rig_config.TILE_W)*float(appearance.visual_scale)
            var size:Vector2=Vector2(float(rig.cell_width)*absf(float(appearance.visual_scale_x)),float(rig.cell_height))*scale
            var pivot:Vector2=Vector2(size.x*0.5,(float(rig.cell_height)-float(rig.origin_y_from_ground))*scale)
            var a:Vector2=Placement.project(v2(track.from_position),float(track.from_elevation_feet)/5.0,quarter)
            var b:Vector2=Placement.project(v2(track.to_position),float(track.to_elevation_feet)/5.0,quarter)
            var swept:Rect2=Rect2(a-pivot,size).merge(Rect2(b-pivot,size))
            var lift:float=maxf(0.0,float(track.get("arc_height_px",0.0)))
            for key in track.get("lift_pixels_keys",[]):lift=maxf(lift,float(key[1]))
            if lift>0.0:swept.position.y-=lift;swept.size.y+=lift
            if entry.get("screen_rect",Rect2()).intersects(swept):peers[actor_id]=true
        var count:int=peers.size()+1
        if not entry.has("actor_depth_bands"):
            entry.actor_depth_bands=[]
            entry.node.tree_exiting.connect(_release_actor_depth_bands.bind(entry),CONNECT_ONE_SHOT)
        while entry.actor_depth_bands.size()<count:
            if budget.used_usec>=budget.limit_usec:complete=false;break
            var started:int=Time.get_ticks_usec()
            var node=MeshInstance3D.new();node.visible=false;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            node.sorting_use_aabb_center=false
            var material=ShaderMaterial.new();material.shader=entry.material.shader;node.material_override=material
            (sprite_parent if sprite_parent!=null else self).add_child(node)
            var band:Dictionary={"id":entry.id+":depth:"+str(entry.actor_depth_bands.size()),"node":node,"material":material,
                "placement":entry.placement,"role":entry.role,"layer":entry.layer,"source_role":1,"screen_rect":Rect2(),
                "actor_depth_band":true,"actor_depth_owner":entry,"mobile":false}
            SourceMaterial.initialize(band);entry.actor_depth_bands.append(band);actor_entries.append(band)
            budget.used_usec+=Time.get_ticks_usec()-started
    return complete

func sample_actor_depth_bands(sources:Array)->bool:
    var visibility_changed:bool=false
    var depth_sources:Array=sources.filter(func(entry):return entry.has("actor_depth_bands"))
    if depth_sources.is_empty():return false
    var programs:Dictionary=Catalog.environment_index(catalog_cache).get("spatial_media",{})
    var peers:Array=[]
    for peer in static_entries+actor_entries:
        if peer.node.visible and not peer.get("actor_depth_band",false):peers.append(peer)
    for entry in depth_sources:
        var bands:Array=entry.actor_depth_bands
        var content:String=str(entry.get("world_media_content",entry.placement.get("world_media_content","")))
        var descriptor:Dictionary=programs.get(content,{}).get("actor_depth",{})
        var record:Dictionary=Catalog.environment_resources(catalog_cache).resources.get(descriptor.get("asset_id",""),{})
        var cuts:Dictionary={}
        if entry.node.visible and not record.is_empty():
            var plane:int=int(Order.key(entry.placement,entry.role,entry.layer,quarter)[0])
            for peer in peers:
                if peer.placement.id==entry.placement.id or int(Order.key(peer.placement,peer.role,peer.layer,quarter)[0])!=plane                     or not entry.screen_rect.intersects(peer.get("screen_rect",Rect2())):continue
                var depth:float=Placement.sort_contact(peer.placement,quarter).y
                if not cuts.has(depth):cuts[depth]=[]
                cuts[depth].append(peer)
        var depths:Array=cuts.keys();depths.sort()
        var wanted:bool=entry.node.visible and not record.is_empty()
        var inputs:Array=[]
        for depth in depths:
            var contacts:Array=[]
            for peer in cuts[depth]:contacts.append([peer.node.get_instance_id(),Order.key(peer.placement,peer.role,peer.layer,quarter)])
            inputs.append([depth,contacts])
        if entry.get("actor_depth_order_inputs",[])!=inputs:entry.actor_depth_order_status="available"
        entry.actor_depth_order_inputs=inputs
        var active:bool=wanted and bands.size()>=depths.size()+1 and entry.get("actor_depth_order_status")!="incompatible_peer_order"
        entry.actor_depth_needs_preparation=wanted and bands.size()<depths.size()+1
        var lower:float=-1.0e30
        for index in bands.size():
            var band:Dictionary=bands[index]
            if not active or index>depths.size():band.node.visible=false;continue
            var upper:float=float(depths[index]) if index<depths.size() else 1.0e30
            band.placement=entry.placement
            if band.get("actor_depth_source_key",[])!=entry.get("world_media_frame_key",[]):band.erase("world_media_frame_key")
            if not sample_world_media_frame(band,content,str(entry.get("world_media_role","body")),str(entry.get("world_media_orientation",entry.placement.get("orientation","east"))),int(entry.get("world_media_frame",entry.placement.get("world_media_frame",0)))):
                band.node.visible=false;continue
            band.actor_depth_source_key=entry.get("world_media_frame_key",[])
            var pose:String=Placement.pose(str(entry.placement.get("orientation","east")),quarter)
            var cell:Array=descriptor.cell
            SourceMaterial.apply(band,{"use_actor_depth":true,"actor_depth_texture":texture(record.path),
                "actor_depth_rect":Vector4(float(entry.get("world_media_frame",0))*float(cell[0]),float(descriptor.rows_by_pose[pose])*float(cell[1]),float(cell[0]),float(cell[1])),
                "actor_depth_range":v2(descriptor.depth_range),"actor_depth_scale":float(descriptor.pixels_per_unit_by_pose[pose])*float(entry.get("scale",1.0)),
                "actor_depth_origin":Placement.sort_contact(entry.placement,quarter).y,"actor_depth_limits":Vector2(lower,upper)})
            band.actor_depth_path=record.path
            band.actor_depth_before=[];band.actor_depth_after=[]
            for depth in depths:
                if float(depth)>=upper:band.actor_depth_before.append_array(cuts[depth])
                if float(depth)<=lower:band.actor_depth_after.append_array(cuts[depth])
            lower=upper
        var original_visible:bool=entry.node.visible
        if active:entry.node.visible=false
        if entry.get("actor_depth_draw_visible",original_visible)!=entry.node.visible:visibility_changed=true
        entry.actor_depth_draw_visible=entry.node.visible
    return visibility_changed

func set_environment(entry: Dictionary, _rotation: Basis) -> void:
    SourceMaterial.structural_change(entry)
    var row: Dictionary = entry.placement
    var record = Catalog.door_frame(row,quarter,catalog_cache) if entry.source_role == 2 else Catalog.environment_role(record_for(row),entry.source_role)
    if record.is_empty(): entry.node.visible = false; return
    if row.get("water_surface",false):
        record=record.duplicate();record.water=Catalog.environment_resources(catalog_cache).water
    if not record.has("water"):
        _apply_environment_descriptor(entry,EnvironmentSource.describe(row,record,entry.source_role,quarter,camera.basis,source_depth,source_normals))
        return
    entry.record=record
    var mat:ShaderMaterial=entry.material
    var cell:Vector2=v2(record.native_size)
    _environment_quad(entry,EnvironmentSource.quad(row,record,quarter,camera.basis))
    SourceMaterial.set_parameter(entry,"source_tint",v4(row.get("tint",[1,1,1,1])))
    if record.has("water"):
        entry.node.visible = entry.source_role == 1
        if mat.shader != sprite_shader(WATER_SHADER):
            mat.shader = sprite_shader(WATER_SHADER)
            SourceMaterial.initialize(entry)
        mat.set_shader_parameter("source_quad_size",entry.node.mesh.size)
        SourceMaterial.set_parameter(entry,"source_tint",v4(row.get("tint",[1,1,1,1])))
        SourceMaterial.set_parameter(entry,"displayed_time_seconds",water_clock_seconds)
        _register_water_clock(entry)
        var water: Dictionary = record.water
        var water_bounds: AABB = entry.node.mesh.get_aabb()
        var plane_ray: Vector3 = -camera.basis.z
        for x in [-0.5,0.5]:
            for y in [-0.5,0.5]:
                var painted: Vector3 = entry.node.basis*(entry.node.mesh.center_offset+Vector3(x*entry.node.mesh.size.x,y*entry.node.mesh.size.y,0))
                var receiver: Vector3 = painted+plane_ray*(-painted.y/plane_ray.y)
                water_bounds = water_bounds.expand(entry.node.basis.inverse()*receiver)
        entry.node.custom_aabb = water_bounds
        SourceMaterial.set_parameter(entry,"mask_texture",texture(record.path))
        SourceMaterial.set_parameter(entry,"ripple_texture",texture(Catalog.environment_resources(catalog_cache).resources[water.ripple].path))
        SourceMaterial.set_parameter(entry,"origin",Placement.project(v2(row.position),row.base_height_steps,quarter)-v2(record.pivot)*record.scale)
        SourceMaterial.set_parameter(entry,"placement_origin",Placement.contact(row))
        SourceMaterial.set_parameter(entry,"camera_quarter",quarter)
        SourceMaterial.set_parameter(entry,"cell",cell)
        SourceMaterial.set_parameter(entry,"image_scale",record.scale)
        SourceMaterial.set_parameter(entry,"shallow_color",v4(water.shallowColor))
        SourceMaterial.set_parameter(entry,"deep_color",v4(water.deepColor))
        SourceMaterial.set_parameter(entry,"tint",v4(water.tint))
        SourceMaterial.set_parameter(entry,"ripple_pan",v2(water.ripplePan))
        for mapping in [["uv_scale","uvScale"],["depth_strength","depthBlendStrength"],["ripple_tiling","rippleTilingMultiplier"],["ripple_amount","rippleAmount"],["sheen_strength","sheenStrength"],["sheen_sharpness","sheenSharpness"],["alpha_strength","alphaDepthStrength"],["overall_alpha","overallAlpha"],["alpha_cutoff","alphaCutoff"]]:
            SourceMaterial.set_parameter(entry,mapping[0],water[mapping[1]])
        return

static func environment_parameter_names()->Dictionary:
    # Called on the scene owner before a finite private-resource task starts.
    if not SourceMaterial.declared_parameters.has(ENVIRONMENT_SHADER):
        var names:Dictionary={}
        for row in ENVIRONMENT_SHADER.get_shader_uniform_list():names[StringName(row.name)]=null
        SourceMaterial.declared_parameters[ENVIRONMENT_SHADER]=names
    return SourceMaterial.declared_parameters[ENVIRONMENT_SHADER]

func adopt_environment_row(_row:Dictionary,prepared_entries:Array)->void:
    # The worker built and configured the node, including the environment
    # light policy (derive_static); only scene attachment is left.
    var parent:Node=sprite_parent if sprite_parent!=null else self
    for entry in prepared_entries:
        var value:Dictionary=entry.prepared_source
        entry.erase("mesh")
        entry.screen_rect=Rect2()
        entry.record=value.record
        if not value.get("empty",false):
            entry.cell=value.cell;entry.pivot=value.pivot;entry.scale=value.scale
            entry.screen_rect=value.screen_rect;entry.floor_group=value.floor_group
        entry.erase("prepared_source")
        parent.add_child(entry.node)
    entries.append_array(prepared_entries);static_entries.append_array(prepared_entries)

func _ground_sort(rows: Array, packets: Dictionary) -> void:
    preload("res://presentation/ground_data.gd").sort_rows(rows,packets,quarter)

func _ground_packet(row: Dictionary, entry: Dictionary, packet: Dictionary) -> void:
    if packet.has("data"): return
    var transform := Transform3D(camera.basis,Placement.contact(row))
    var b = transform.basis; var o = transform.origin
    # Native 3D MultiMesh buffer: row-major transform, white RGBA, visibility.
    # Keep our CPU copy; never read the renderer's buffer back to edit a value.
    packet.data = PackedFloat32Array([b.x.x,b.y.x,b.z.x,o.x,b.x.y,b.y.y,b.z.y,o.y,
        b.x.z,b.y.z,b.z.z,o.z,1,1,1,1,0,0,0,0])
    packet.bounds = transform * entry.ground_receiver_bounds

func _ground_begin(rows: Array, prepared_packets: Dictionary = {}, source_ranks: Dictionary = {}) -> Dictionary:
    if source_ranks.is_empty():
        for i in rows.size(): source_ranks[rows[i].id] = i
    var packets = prepared_packets
    if packets.is_empty(): _ground_sort(rows,packets)
    var row: Dictionary = rows[0]
    add_entry(row,"terrain",0,ENVIRONMENT_SHADER,1)
    var entry: Dictionary = entries.back()
    initialize_entry(entry)
    _light_entry(entry)
    entry.ground_receiver_bounds = entry.node.custom_aabb
    var multi = MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = entry.node.mesh
    multi.use_custom_data = true
    multi.use_colors = true
    SourceMaterial.set_parameter(entry,"use_instance_visibility",true)
    multi.instance_count = ceili(rows.size()/256.0)*256
    multi.visible_instance_count = rows.size()
    return {"rows":rows,"entry":entry,"multi":multi,"index":0,"bounds":AABB(),
        "packets":packets,"indices":{},"buffer":PackedFloat32Array(),
        "geometry":{"rows":rows,"records":{},"indices":{},"source_ranks":source_ranks,
            "bounds":AABB(),"receiver_bounds":entry.ground_receiver_bounds,"quarter":quarter,"basis":camera.basis}}

func _ground_fill(job: Dictionary, limit: int = 64) -> bool:
    var rows: Array = job.rows
    var end = mini(rows.size(),job.index+limit)
    for i in range(job.index,end):
        var packet: Dictionary = job.packets[rows[i].id]
        _ground_packet(rows[i],job.entry,packet)
        job.indices[rows[i].id] = i
        job.geometry.indices[rows[i].id] = i
        job.geometry.records[rows[i].id] = GroundGeometry._geometry(rows[i],job.entry.ground_receiver_bounds,quarter,camera.basis)
        job.buffer.append_array(packet.data)
        job.bounds = packet.bounds if i == 0 else job.bounds.merge(packet.bounds)
    job.index = end
    return end == rows.size()

func _ground_finish(job: Dictionary) -> void:
    var multi: MultiMesh = job.multi
    var entry: Dictionary = job.entry
    multi.custom_aabb = job.bounds
    job.buffer.resize(multi.instance_count*20)
    multi.buffer = job.buffer
    var batch = MultiMeshInstance3D.new()
    batch.multimesh = multi
    batch.material_override = entry.material
    batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    batch.sorting_use_aabb_center = false
    (sprite_parent if sprite_parent != null else self).add_child(batch)
    entry.node.queue_free()
    entry.node = batch
    entry.batch_rows = job.rows
    entry.ground_packets = job.packets
    entry.ground_indices = job.indices
    entry.ground_buffer = job.buffer
    job.geometry.bounds = job.bounds
    entry.ground_geometry = job.geometry
    entry.ground_version = 0
    entry.scenery_values = []
    for row in job.rows: entry.scenery_values.append(0.0)
    static_entries.append(entry)

func _ground_update(entry: Dictionary, rows: Array) -> void:
    entry.ground_version = entry.get("ground_version",0)+1
    # Direct/manual updates have no prepared geometry receipt. Never carry a
    # receipt from an older worker publication into the exact fallback path.
    entry.erase("geometry_changes")
    entry.erase("prepared_address_token")
    var packets: Dictionary = entry.ground_packets
    _ground_sort(rows,packets)
    var retained = {}; var indices = {}; var buffer = PackedFloat32Array(); var bounds = AABB(); var values: Array = []
    for i in range(rows.size()):
        var row: Dictionary = rows[i]
        var packet: Dictionary = packets[row.id]
        _ground_packet(row,entry,packet)
        retained[row.id] = packet
        indices[row.id] = i
        buffer.append_array(packet.data)
        values.append(packet.data[16])
        bounds = packet.bounds if retained.size()==1 else bounds.merge(packet.bounds)
    var multi: MultiMesh = entry.node.multimesh
    if multi.instance_count < rows.size(): multi.instance_count = ceili(rows.size()/256.0)*256
    buffer.resize(multi.instance_count*20)
    multi.custom_aabb = bounds
    multi.buffer = buffer
    multi.visible_instance_count = rows.size()
    entry.batch_rows = rows; entry.ground_packets = retained; entry.ground_indices = indices
    entry.ground_buffer = buffer; entry.scenery_values = values
    entry.ground_geometry = GroundGeometry.capture_previous({"packets":retained,"receiver_bounds":entry.ground_receiver_bounds,
        "capacity":multi.instance_count,"ground_version":entry.ground_version},quarter,camera.basis).geometry
    # The representative is part of picking/order/source identity even though
    # all instances still use the same original material/quad.
    entry.placement = rows[0]; entry.id = rows[0].id+":0:terrain"
    update_bounds(entry)

func _ground_publish(entry: Dictionary, packet: Dictionary) -> void:
    if packet.get("sparse",false):
        _ground_publish_changes(entry,packet)
        return
    entry.ground_version = entry.get("ground_version",0)+1
    var changes: Dictionary = packet.get("geometry_changes",{})
    if changes.is_empty(): entry.erase("geometry_changes")
    else:
        entry.geometry_changes = {"base_version":changes.base_version,"version":entry.ground_version,
            "changed":changes.changed,"removed":changes.removed}
    var multi: MultiMesh = entry.node.multimesh
    var rows: Array = packet.rows
    if multi.instance_count<rows.size(): multi.instance_count = ceili(rows.size()/256.0)*256
    multi.custom_aabb = packet.bounds; multi.buffer = packet.buffer
    multi.visible_instance_count = rows.size()
    entry.batch_rows = rows; entry.ground_packets = packet.packets; entry.ground_indices = packet.indices
    entry.ground_buffer = packet.buffer; entry.scenery_values = packet.values
    entry.ground_geometry = packet.geometry
    # Only this prepared publication certifies row packet/buffer address equality.
    # It never claims those copied addresses match the atlas's current layout.
    entry.prepared_address_version = entry.ground_version
    entry.prepared_address_token = packet.get("address_token",[])
    entry.placement = rows[0]; entry.id = rows[0].id+":0:terrain"
    update_bounds(entry)

func _ground_publish_changes(entry: Dictionary, packet: Dictionary) -> void:
    # The completed candidate owns numeric geometry only. Preserve the current
    # published visibility/atlas channels and edit K native transform slots.
    var patch: Dictionary = packet.geometry_patch
    var base_version: int = entry.get("ground_version",0)
    GroundGeometry.apply_geometry(entry.ground_geometry,patch)
    var multi: MultiMesh = entry.node.multimesh
    for id in patch.records:
        var index: int = patch.indices[id]
        var record: Dictionary = patch.records[id]
        var current: Dictionary = entry.ground_packets[id]
        var transformed: Dictionary = GroundGeometry._packet(record,false)
        var data: PackedFloat32Array = current.data
        for channel in 12:
            data[channel] = transformed.data[channel]
            entry.ground_buffer[index*20+channel] = data[channel]
        current.data = data; current.row = record.row; current.y = record.y; current.bounds = record.bounds
        entry.batch_rows[index] = record.row
    # ground_buffer mirrors the native buffer and now holds these transforms
    # (the same float encoding). Submitting it whole avoids per-instance writes,
    # which would first read the uploaded buffer back from the GPU.
    multi.buffer = entry.ground_buffer
    multi.custom_aabb = patch.bounds
    entry.ground_version = base_version+1
    entry.geometry_changes = {"base_version":base_version,"version":entry.ground_version,"changed":patch.changed,"removed":[]}
    entry.erase("prepared_address_token"); entry.erase("prepared_address_version")
    entry.placement = entry.batch_rows[0]; entry.id = entry.placement.id+":0:terrain"
    update_bounds(entry)

func _ground_visibility(entry: Dictionary, index: int, value: float) -> void:
    entry.scenery_values[index] = value
    entry.ground_packets[entry.batch_rows[index].id].data[16] = value

func _ground_flush_visibility(entry: Dictionary, indices: Array) -> void:
    var buffer: PackedFloat32Array = entry.ground_buffer
    for index in indices: buffer[index*20+16] = entry.scenery_values[index]
    entry.ground_buffer = buffer
    entry.node.multimesh.buffer = buffer

func _ground_batch(rows: Array) -> void:
    var job = _ground_begin(rows)
    _ground_fill(job,rows.size())
    _ground_finish(job)

func _environment_row(row: Dictionary) -> void:
    if row.has("views"): row.asset = row.views[Placement.pose(row.orientation,quarter)]
    var variants: Array = [row]
    if row.has("wall_members"): variants.append_array(row.wall_members)
    for variant in variants:
        var first = entries.size()
        add_environment_entries(variant)
        for i in range(first,entries.size()):
            var entry: Dictionary = entries[i]
            initialize_entry(entry)
            _light_entry(entry)
            static_entries.append(entry)
            if variant.has("world_media_content"):world_media_entries.append(entry)
            if variant.kind in ["wall","cliff"]:
                entry.wall_source = row
                entry.wall_variant = "joined" if variant.has("wall_members") else variant.id
                entry.wall_source_visible = entry.node.visible
                entry.id += ":"+entry.wall_variant
                # Precreated original member sources serve mixed-opacity corners
                # and explicit targeting. Their registration never changes.
                if variant != row: entry.node.visible = false
            if variant.has("wall_members") and entry.role!="shadow":
                var picks: Array = []
                for member in row.wall_members:
                    var record: Dictionary = Catalog.environment(member,quarter,catalog_cache)
                    texture(record.path)
                    picks.append({"row":member,"record":record,"key":Order.key(member,"wall",entry.layer,quarter)})
                picks.sort_custom(func(a,b):return Order.less(a.key,b.key) if a.key!=b.key else a.row.id<b.row.id)
                entry.wall_picks = picks
    if row.has("lit_animation"): _add_fixture_flame(row)

func _add_fixture_flame(row: Dictionary) -> void:
    var name: String = row.lit_animation
    var assets = Catalog.environment_resources(catalog_cache)
    if not fixture_clips.has(name):
        var authored: Dictionary = assets.animations[name]
        var images: Array[Image] = []
        var energy: Array = []
        var heights: Array = []
        var total = 0.0
        var height_total = 0.0
        for frame in authored.frames:
            var path: String = assets.resources[frame].path
            if not source_images.has(path) or not fixture_frame_energy.has(path) or not fixture_frame_centroids.has(path):
                var message = "Media preparation missed authored fixture frame: " + path
                if message not in presentation_errors: presentation_errors.append(message)
                media_issue = message
                return
            images.append(source_images[path])
            var amount: float = fixture_frame_energy[path]
            energy.append(amount); total += amount
            var resource: Dictionary = assets.resources[frame]
            heights.append((float(resource.pivot[1])-fixture_frame_centroids[path].y)*float(resource.scale)/64.0)
            height_total += heights.back()
        var mean = total/maxi(1,energy.size())
        for i in range(energy.size()):
            energy[i] = clampf(energy[i]/maxf(mean,0.0000001),0.85,1.15)
        var sheets = Texture2DArray.new()
        var started = Time.get_ticks_usec()
        var result = sheets.create_from_images(images)
        FrameProfile.end_phase(profile,"texture_upload",started)
        assert(result == OK,"Cannot prepare authored fixture animation: "+name)
        var duration: float = authored.frames.size()/float(authored.fps)
        var clock_node = Graphs.clip_clock(fixture_clock_owner if fixture_clock_owner!=null else self,{"Idle":[maxf(duration,0.001),true]})
        fixture_clips[name] = {"authored":authored,"frames":sheets,"clock":clock_node,"index":0,"energy":energy,"heights":heights,"mean_height":height_total/maxi(1,heights.size())}
    var clip: Dictionary = fixture_clips[name]
    var record: Dictionary = assets.resources[clip.authored.frames[0]]
    add_entry(row,"body",100,FIXTURE_FLAME_SHADER,1)
    var entry: Dictionary = entries.back()
    entry.record = record
    entry.node.basis = camera.basis
    entry.node.position = Placement.contact(row)
    set_quad(entry,v2(record.native_size),v2(record.pivot),record.scale)
    SourceMaterial.set_parameter(entry,"frames",clip.frames,true)
    # All 16 original torch frames have border alpha0/1. Keep other effects
    # untouched and retain positive glow above that one-byte padding pedestal.
    SourceMaterial.set_parameter(entry,"alpha_pedestal",1.0/255.0 if name=="torch.flame" else 0.0,true)
    static_entries.append(entry)
    fixture_entries.append(entry)

func position_camera() -> void:
    camera.transform=Placement.camera_transform(camera_focus,quarter)

func pixel_selected(selection: Dictionary, pixel: Vector2, colour: Color) -> bool:
    if selection.kind == "source_rgba":
        var values = [roundi(colour.r*255),roundi(colour.g*255),roundi(colour.b*255),roundi(colour.a*255)]
        for i in range(4):
            if values[i] < selection.bounds.minimum[i] or values[i] > selection.bounds.maximum[i]: return false
        return true
    var mask: Dictionary = selection.mask
    var p = (pixel.floor()*v2(mask.sampling.scale)+v2(mask.sampling.offset)).floor()
    if p.x<0 or p.y<0 or p.x>=mask.region.rect[2] or p.y>=mask.region.rect[3]: return false
    var value = roundi(source_images[mask.region.path].get_pixelv(Vector2i(p)+Vector2i(mask.region.rect[0],mask.region.rect[1])).r*255)
    return value in selection.values
