extends RefCounted
const GroundReceiving = preload("res://presentation/ground_receiving.gd")
# Native Canvas lights receive into isolated straight-RGBA cells. Original 3D
# quads, source materials, painter order and picking remain their original owners.
const Output = preload("res://presentation/canvas_received.gdshader")
const EnvironmentReceiver = preload("res://presentation/canvas_environment.gdshader")
const ShadowReceiver = preload("res://presentation/canvas_environment_unshaded.gdshader")
const ModularReceiver = preload("res://presentation/canvas_modular.gdshader")
const WaterReceiver = preload("res://presentation/canvas_water.gdshader")
const NonreceivingDebug = preload("res://presentation/canvas_nonreceiving_debug.gdshader")
const FlameReceiver = preload("res://presentation/canvas_fixture_flame.gdshader")
const MAX_SIZE = 8192
var viewport: SubViewport
var receivers: Array = []
var membership: Array = []
var groups: Dictionary = {}
var crop_cache: Dictionary = {}
var parameter_names: Dictionary = {}
var white: Texture2D
var owner: Node3D
var errors: Array = []
var revision := 0
var repack_count := 0
var canvas_key: Array = []
var packed_pixels := 0
var live_receivers := 0
var last_sync_ms := 0.0
var last_pack_ms := 0.0
var layout_members: Dictionary = {}
var projection_root: Node2D
var plane_basis := Basis.IDENTITY
var plane_to_screen := Transform2D.IDENTITY
var static_receivers: Array = []
var dynamic_receivers: Array = []
var static_live_receivers := 0
var admission_stamp: Array = []
var visibility_stamp: Array = []
var dynamic_members: Array = []
var output_stamp: Array = []
var known_entry_count := -1
var last_reconcile_ms := 0.0
var last_projection_ms := 0.0
var last_reconcile_phases: Dictionary = {}
var projection_dirty: Array = []

func attach(parent: Node3D) -> void:
    owner = parent
    viewport = SubViewport.new()
    viewport.name = "Native2DReceiving"
    viewport.disable_3d = true
    viewport.transparent_bg = true
    viewport.size = Vector2i(MAX_SIZE,1024)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    parent.add_child(viewport)
    projection_root=Node2D.new()
    projection_root.name="ReceivingProjection"
    viewport.add_child(projection_root)
    var ambient = CanvasModulate.new()
    ambient.color = Color(0.18,0.18,0.18,1.0)
    viewport.add_child(ambient)
    RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
    var pixel = Image.create(1,1,false,Image.FORMAT_RGBA8)
    pixel.fill(Color.WHITE)
    white = ImageTexture.create_from_image(pixel)

var normals_visible = false
var normal_shaders: Dictionary = {}

func set_normals_visible(value: bool) -> void:
    if normals_visible==value: return
    normals_visible=value
    membership.clear(); admission_stamp.clear()

func _normal_shader(source: Shader) -> Shader:
    if not normal_shaders.has(source):
        var shader=Shader.new()
        var code: String=source.code.replace("blend_disabled;","blend_disabled, unshaded;")
        code=code.replace('#include "','#include "res://presentation/')
        shader.code="#define SHOW_SOURCE_NORMALS\n"+code
        normal_shaders[source]=shader
    return normal_shaders[source]

func _entry_info(entry: Dictionary) -> Dictionary:
    var source: Shader = entry.material.shader
    var previous: Dictionary = entry.get("atlas_source_info",{})
    if not previous.is_empty() and previous.source==source and previous.role==entry.role and previous.kind==entry.placement.kind and previous.get("normals_visible",false)==normals_visible: return previous
    var path: String = source.resource_path
    var modular: bool = path.ends_with("modular.gdshader")
    var water: bool = path.ends_with("water.gdshader")
    var flame: bool = path.ends_with("fixture_flame.gdshader")
    var shader: Shader = ModularReceiver if modular else WaterReceiver if water else FlameReceiver if flame else ShadowReceiver if entry.role=="shadow" else EnvironmentReceiver
    if normals_visible:
        if entry.role=="shadow" or flame: shader=NonreceivingDebug
        elif shader in [ModularReceiver,WaterReceiver,EnvironmentReceiver]: shader=_normal_shader(shader)
    var output: Shader = Output
    var result={"normals_visible":normals_visible,"source":source,"role":entry.role,"kind":entry.placement.kind,"shader":shader,"output":output,"water":water,"dynamic":entry.placement.kind=="actor" or flame}
    entry.atlas_source_info=result
    return result

func _shader(entry: Dictionary) -> Shader:
    return _entry_info(entry).shader

func _output_shader(entry: Dictionary) -> Shader:
    return _entry_info(entry).output

func _dynamic(entry: Dictionary) -> bool:
    return _entry_info(entry).dynamic

func _issue(message: String) -> void:
    if message not in errors: errors.append(message)

func _crop(entry: Dictionary, world: Node, info: Dictionary = {}) -> Dictionary:
    var cell = Vector2i(entry.cell)
    # Animated sheets retain one stable authored cell throughout frame changes.
    # Static sources use their exact nonzero-alpha bounds, never an alpha cutoff.
    if info.is_empty(): info=_entry_info(entry)
    if info.dynamic or info.water:
        return {"pixels":Rect2i(Vector2i.ZERO,cell),"uv":Vector4(0,0,1,1)}
    var record: Dictionary = entry.get("record",{})
    var path: String = record.get("path","")
    if not world.source_images.has(path):
        _issue("Native light atlas needs prepared original colour image: "+path)
        return {}
    var image: Image = world.source_images[path]
    var r: Array = record.get("rect",[0,0,cell.x,cell.y])
    var region = Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))
    var key = [image.get_instance_id(),region,cell]
    if crop_cache.has(key): return crop_cache[key]
    if not Rect2i(Vector2i.ZERO,image.get_size()).encloses(region) or not region.has_area() or cell.x<1 or cell.y<1:
        _issue("Native light atlas original region is outside its prepared image: "+path)
        return {}
    var used: Rect2i = image.get_region(region).get_used_rect()
    var pixels = Rect2i(Vector2i.ZERO,Vector2i.ONE)
    if used.has_area():
        var scale = Vector2(cell)/Vector2(region.size)
        var start = (Vector2(used.position)*scale).floor()
        var end = (Vector2(used.end)*scale).ceil()
        pixels = Rect2i(Vector2i(start),Vector2i(end-start))
    var uv = Vector4(float(pixels.position.x)/cell.x,float(pixels.position.y)/cell.y,
        float(pixels.size.x)/cell.x,float(pixels.size.y)/cell.y)
    var result = {"pixels":pixels,"uv":uv}
    crop_cache[key] = result
    return result

static func plan_layout(specs: Array, minimum: Vector2i, limit: int = MAX_SIZE) -> Dictionary:
    # Pure planning: an overflow cannot mutate the last published atlas, nodes,
    # material overrides or floor addresses.
    var positions = {}; var x = 1; var y = 1; var row_height = 0; var pixels = 0
    for spec in specs:
        var size: Vector2i = spec.crop.pixels.size
        if size.x+2>limit or size.y+2>limit:
            return {"ok":false,"error":"Native light atlas source cell exceeds %d: %s" % [limit,size]}
        if x+size.x+1>limit:
            x=1; y+=row_height+2; row_height=0
        positions[spec.id] = Vector2i(x,y)
        x+=size.x+2; row_height=maxi(row_height,size.y); pixels+=size.x*size.y
    var needed = maxi(y+row_height+1,minimum.y)
    if needed>limit or minimum.x>limit:
        return {"ok":false,"error":"Native light atlas exceeds %d pixels: %s" % [limit,Vector2i(minimum.x,needed)]}
    var height = maxi(1,minimum.y)
    while height<needed: height=mini(limit,height*2)
    return {"ok":true,"size":Vector2i(limit,height),"positions":positions,"pixels":pixels}

func _copy_parameters(group: Dictionary) -> void:
    var source: ShaderMaterial = group.entry.material
    var key = [source.shader.get_instance_id(),group.material.shader.get_instance_id()]
    if not parameter_names.has(key):
        var accepted = {}
        for row in group.material.shader.get_shader_uniform_list(): accepted[row.name]=true
        var names: Array = []
        for row in source.shader.get_shader_uniform_list():
            if accepted.has(row.name): names.append(row.name)
        parameter_names[key]=names
    for name in parameter_names[key]: group.material.set_shader_parameter(name,source.get_shader_parameter(name))
    group.material.set_shader_parameter("use_instance_visibility",false)
    group.material.set_shader_parameter("source_crop",group.crop.uv)
    group.material.set_shader_parameter("atlas_cell_size",Vector2(group.crop.pixels.size))
    group.material.set_shader_parameter("receiver_visibility",group.visibility)
    group.material.set_shader_parameter("ground_join_mask",group.get("join_mask",0))
    group.version = group.entry.get("source_version",0)
    group.source_shader = source.shader
    group.highlighted = null

func _group(entry: Dictionary, crop: Dictionary, visibility: float, receiver_id: String, info: Dictionary = {}, join_mask: int = 0) -> Dictionary:
    # GLES3 reserves 16 vec4 slots per instance-uniform CanvasItem and has only
    # 4096 hardware slots here. Native region UV carries packing without that
    # allocation. Binary memory style uses two shared materials per source.
    if info.is_empty(): info=_entry_info(entry)
    var id: Array = [entry.material.get_instance_id(),visibility,receiver_id if info.water else "",join_mask]
    var group: Dictionary = groups.get(id,{})
    var shader: Shader = info.shader
    if group.is_empty():
        var material = ShaderMaterial.new(); material.shader=shader
        group={"id":id,"entry":entry,"material":material,"crop":crop,"version":-1,"source_shader":null,"highlighted":null,"visibility":visibility,"join_mask":join_mask,"rank":groups.size()}
        groups[id]=group
    elif group.material.shader!=shader or group.crop!=crop:
        group.material.shader=shader; group.crop=crop; group.version=-1
    group.entry=entry
    group.water=info.water
    return group

func _make_receiver(spec: Dictionary, group: Dictionary) -> Dictionary:
    var node = Sprite2D.new()
    node.texture=white; node.centered=false; node.material=group.material
    node.region_enabled=true; node.region_filter_clip_enabled=false
    # Cells never overlap. This only groups native draw calls, within lights
    # default Z range; it has no relation to original 3D painter/game elevation.
    node.z_index=group.rank%1024
    node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; node.visible=false
    projection_root.add_child(node)
    return {"id":spec.id,"entry":spec.entry,"index":spec.index,"node":node,"group":group,
        "crop":spec.crop,"position":Vector2i.ZERO,"projection":[],"visibility":-1.0,"bounds":Rect2()}

func _publish_addresses() -> void:
    var floors = {}
    var target = Vector2(viewport.size)
    for receiver in receivers:
        var entry: Dictionary = receiver.entry
        if receiver.index>=0:
            var id: int = entry.node.get_instance_id()
            if not floors.has(id): floors[id]={"entry":entry,"receivers":[]}
            floors[id].receivers.append(receiver)
        else:
            var origin = Vector2(receiver.position)/target
            var size = Vector2(receiver.crop.pixels.size)/target
            var output: ShaderMaterial = entry.received_material
            output.set_shader_parameter("source_crop",receiver.crop.uv)
            output.set_shader_parameter("atlas_region",Vector4(origin.x,origin.y,size.x,size.y))
    for floor in floors.values():
        var entry: Dictionary = floor.entry
        var first: Dictionary = floor.receivers[0]
        var output: ShaderMaterial = entry.received_material
        output.set_shader_parameter("source_crop",first.crop.uv)
        output.set_shader_parameter("atlas_cell_size",Vector2(first.crop.pixels.size)/target)
        # Hold the full packed array once per batch, rather than round-tripping
        # it through a Dictionary for every scalar address assignment.
        var buffer: PackedFloat32Array = entry.ground_buffer
        for receiver in floor.receivers:
            # Compatibility packs custom channels to half floats. Normalized UV
            # loses up to two texels in an 8192px atlas. Small integer pieces
            # preserve all 13 bits per axis without a new texture or draw.
            var pixel: Vector2i = receiver.position
            var low_x: int = pixel.x%1024
            var low_y: int = pixel.y%1024
            var high: int = (pixel.x/1024)+8*(pixel.y/1024)
            var offset: int = receiver.index*20
            buffer[offset+17]=low_x; buffer[offset+18]=low_y; buffer[offset+19]=high
            var packet: Dictionary = entry.ground_packets[entry.batch_rows[receiver.index].id]
            var data: PackedFloat32Array = packet.data
            data[17]=low_x; data[18]=low_y; data[19]=high; packet.data=data
        entry.ground_buffer=buffer
        entry.node.multimesh.buffer=buffer

func _reconcile(world: Node) -> bool:
    var phase = Time.get_ticks_usec()
    last_reconcile_phases={}
    var key: Array = []
    var entries: Array = []
    var geometry: Dictionary = {}
    var information: Dictionary = {}
    for entry in world.entries:
        if not is_instance_valid(entry.node) or entry.node.is_queued_for_deletion() or not entry.has("cell"): continue
        entries.append(entry)
        var info=_entry_info(entry)
        var source = [] if info.dynamic else [entry.get("record",{}).get("path",""),entry.get("record",{}).get("rect",[]),info.shader]
        var id: int = entry.node.get_instance_id()
        information[id]=info
        if not info.dynamic:
            var mesh: QuadMesh = entry.node.multimesh.mesh if entry.has("batch_rows") else entry.node.mesh
            geometry[id]=[entry.node.global_transform,mesh.size,mesh.center_offset]
        key.append([id,entry.cell,entry.get("ground_version",0),source,geometry.get(id,[])])
    last_reconcile_phases.members_ms=(Time.get_ticks_usec()-phase)/1000.0
    var screen_size = Vector2i(world.get_viewport().get_visible_rect().size)
    var resize_needed: bool = screen_size.x>viewport.size.x or screen_size.y>viewport.size.y
    if key==membership and not resize_needed: return true
    phase=Time.get_ticks_usec()
    var specs: Array = []; var next_members = {}
    var ground_supports: Dictionary = GroundReceiving.heights(entries)
    for entry in entries:
        var source_id: int = entry.node.get_instance_id()
        var info: Dictionary = information[source_id]
        var crop = _crop(entry,world,info)
        if crop.is_empty(): return false
        var batched: bool = entry.has("batch_rows")
        var count: int = entry.batch_rows.size() if batched else 1
        var prefix: String = str(source_id)+":"
        var material_id: int = entry.material.get_instance_id()
        var source_base: Array = geometry.get(source_id,[])
        for index in count:
            var row_id: String = str(entry.batch_rows[index].id) if batched else "source"
            var id: String = prefix+row_id
            var source_geometry: Array = []
            if not info.dynamic:
                var instance_transform: PackedFloat32Array = entry.ground_packets[row_id].data.slice(0,12) if batched else PackedFloat32Array()
                source_geometry=[source_base,crop.uv,instance_transform]
            var row: Dictionary = entry.batch_rows[index] if batched else entry.placement
            var join_mask: int = GroundReceiving.mask(row,ground_supports)
            specs.append({"join_mask":join_mask,"id":id,"entry":entry,"index":index if batched else -1,"crop":crop,"source_geometry":source_geometry,"source_id":source_id,"info":info,"material_id":material_id})
            next_members[id]=crop
    last_reconcile_phases.specs_ms=(Time.get_ticks_usec()-phase)/1000.0
    var repack: bool = next_members!=layout_members or resize_needed
    var plan = {}
    if repack:
        var started = Time.get_ticks_usec()
        plan=plan_layout(specs,Vector2i(screen_size.x,maxi(viewport.size.y,screen_size.y)))
        last_pack_ms=(Time.get_ticks_usec()-started)/1000.0
        if not plan.ok:
            _issue(plan.error); return false
    phase=Time.get_ticks_usec()
    var kept = {}; var next: Array = []; var used_groups = {}; var reusable: Array = []
    var entry_groups: Dictionary = {}
    for receiver in receivers:
        kept[receiver.id]=receiver
        if not next_members.has(receiver.id): reusable.append(receiver)
    var binding_reused := 0
    for spec in specs:
        var receiver: Dictionary = kept.get(spec.id,{})
        var retained: bool = not receiver.is_empty() and is_same(receiver.entry,spec.entry) and receiver.crop==spec.crop and receiver.get("source_material",0)==spec.material_id and receiver.get("receiving_shader")==spec.info.shader and receiver.get("join_mask",0)==spec.join_mask
        if retained:
            # A prepared floor can change row indices or a few transforms while
            # retaining its original native source/material. No rebind is needed
            # for the other thousands of receiver cells.
            kept.erase(spec.id)
            receiver.index=spec.index
            used_groups[receiver.group.id]=true
            binding_reused+=1
        else:
            var visibility: float = spec.entry.scenery_values[spec.index] if spec.index>=0 else float(spec.entry.get("scenery_value",1.0))
            if not entry_groups.has(spec.source_id): entry_groups[spec.source_id]={}
            var choices: Dictionary = entry_groups[spec.source_id]
            var style_key = [visibility,spec.join_mask,spec.id if spec.info.water else ""]
            var group: Dictionary = choices.get(style_key,{})
            if group.is_empty():
                group=_group(spec.entry,spec.crop,visibility,spec.id,spec.info,spec.join_mask)
                choices[style_key]=group
            used_groups[group.id]=true
            if receiver.is_empty():
                if reusable.is_empty(): receiver=_make_receiver(spec,group)
                else:
                    receiver=reusable.pop_back(); kept.erase(receiver.id); receiver.id=spec.id
            else: kept.erase(spec.id)
            receiver.entry=spec.entry; receiver.index=spec.index; receiver.crop=spec.crop; receiver.group=group
            receiver.dynamic=spec.info.dynamic; receiver.water=spec.info.water
            receiver.source_material=spec.material_id; receiver.receiving_shader=spec.info.shader
            if receiver.node.material!=group.material: receiver.node.material=group.material
            receiver.visibility=visibility
            receiver.join_mask=spec.join_mask
        if receiver.get("source_geometry",[])!=spec.source_geometry or receiver.projection.is_empty():
            receiver.projection=[]
            if not receiver.dynamic: projection_dirty.append(receiver)
        receiver.source_geometry=spec.source_geometry
        if repack:
            var next_position: Vector2i = plan.positions[spec.id]
            var region=Rect2(Vector2(next_position),Vector2(receiver.crop.pixels.size))
            if receiver.get("region",Rect2())!=region:
                receiver.node.region_rect=region; receiver.region=region
            receiver.position=next_position
        next.append(receiver)
    # All dimensions were validated before any published state changed.
    for receiver in kept.values(): receiver.node.visible=false; receiver.node.queue_free()
    for id in groups.keys():
        if not used_groups.has(id): groups.erase(id)
    var rank = 0
    for group in groups.values(): group.rank=rank; rank+=1
    for receiver in next:
        var z: int = receiver.group.rank%1024
        if receiver.get("rank",-1)!=z: receiver.node.z_index=z; receiver.rank=z
    receivers=next; membership=key; layout_members=next_members
    static_receivers=[]; dynamic_receivers=[]
    for receiver in receivers:
        (dynamic_receivers if receiver.dynamic else static_receivers).append(receiver)
    if repack:
        viewport.size=plan.size; packed_pixels=plan.pixels; revision+=1; repack_count+=1
    last_reconcile_phases.receivers_ms=(Time.get_ticks_usec()-phase)/1000.0
    last_reconcile_phases.bindings_reused=binding_reused
    phase=Time.get_ticks_usec()
    for entry in entries:
        var new_output: bool = not entry.has("received_material")
        if new_output:
            var output = ShaderMaterial.new(); output.shader=_output_shader(entry)
            entry.received_material=output
        if new_output:
            entry.received_material.set_shader_parameter("received",viewport.get_texture())
            entry.received_material.set_shader_parameter("use_instance_atlas",entry.has("batch_rows"))
        if entry.node.material_override!=entry.received_material: entry.node.material_override=entry.received_material
    # A prepared floor publication can replace its packed buffer while retaining
    # exactly the same tile IDs. Restore addresses even when no repack occurred.
    _publish_addresses()
    last_reconcile_phases.addresses_ms=(Time.get_ticks_usec()-phase)/1000.0
    last_reconcile_phases.projected_receivers=projection_dirty.size()
    return true

func _plane(point: Vector3) -> Vector2:
    var value=plane_basis*point
    return Vector2(value.x,value.y)

func _project(receiver: Dictionary, force: bool) -> void:
    var entry: Dictionary = receiver.entry
    var mesh: QuadMesh = entry.node.multimesh.mesh if receiver.index>=0 else entry.node.mesh
    var identity: Array = [entry.get("ground_version",0),entry.node.global_transform,mesh.size,mesh.center_offset] if receiver.index>=0 else [entry.node.global_transform,mesh.size,mesh.center_offset]
    if not force and identity==receiver.projection: return
    receiver.projection=identity
    var transform: Transform3D
    if receiver.index>=0:
        var data: PackedFloat32Array = entry.ground_buffer
        var i: int = receiver.index*20
        transform=entry.node.global_transform*Transform3D(Basis(Vector3(data[i],data[i+4],data[i+8]),Vector3(data[i+1],data[i+5],data[i+9]),Vector3(data[i+2],data[i+6],data[i+10])),Vector3(data[i+3],data[i+7],data[i+11]))
    else: transform=entry.node.global_transform
    var local = mesh.center_offset+Vector3(-mesh.size.x*.5,mesh.size.y*.5,0)
    var origin = _plane(transform*local)
    var axis_x = _plane(transform.basis*Vector3(mesh.size.x,0,0))
    var axis_y = _plane(transform.basis*Vector3(0,-mesh.size.y,0))
    var crop: Vector4 = receiver.crop.uv
    origin+=axis_x*crop.x+axis_y*crop.y
    axis_x*=crop.z; axis_y*=crop.w
    receiver.node.transform=Transform2D(axis_x/receiver.crop.pixels.size.x,axis_y/receiver.crop.pixels.size.y,origin)
    if receiver.water:
        receiver.group.material.set_shader_parameter("receiver_world_origin",transform.origin)
    receiver.world_origin=transform.origin
    receiver.bounds=Rect2(origin,Vector2.ZERO).expand(origin+axis_x).expand(origin+axis_y).expand(origin+axis_x+axis_y)

func _visibility(receiver: Dictionary, screen: Rect2) -> bool:
    var shown: bool = receiver.entry.node.is_visible_in_tree() and (plane_to_screen*receiver.bounds).intersects(screen)
    if receiver.node.visible!=shown: receiver.node.visible=shown
    return shown

func _style(receiver: Dictionary) -> void:
    var entry: Dictionary = receiver.entry
    var visibility: float = entry.scenery_values[receiver.index] if receiver.index>=0 else float(entry.get("scenery_value",1.0))
    if visibility==receiver.visibility: return
    receiver.group=_group(entry,receiver.crop,visibility,receiver.id,{},receiver.get("join_mask",0))
    receiver.node.material=receiver.group.material
    receiver.rank=receiver.group.rank%1024
    receiver.node.z_index=receiver.rank
    receiver.visibility=visibility
    if receiver.water:
        receiver.group.material.set_shader_parameter("receiver_world_origin",receiver.get("world_origin",Vector3.ZERO))

func sync(world: Node, published: Array = [], styles: Array = []) -> void:
    var started = Time.get_ticks_usec()
    projection_dirty=[]
    last_reconcile_phases={}
    last_pack_ms=0.0
    var screen_size = world.get_viewport().get_visible_rect().size
    # Published scene stamps are not received SDK revisions: queued preparation
    # never enters this atlas. Exact dynamic native IDs catch same-count outfits.
    var moving: Array = []
    if not published.is_empty():
        for entry in world.actor_entries:
            if entry.has("cell") and is_instance_valid(entry.node) and not entry.node.is_queued_for_deletion(): moving.append([entry.node.get_instance_id(),entry.cell])
        for entry in world.fixture_entries:
            if entry.has("cell") and is_instance_valid(entry.node) and not entry.node.is_queued_for_deletion(): moving.append([entry.node.get_instance_id(),entry.cell])
    var reconcile: bool = published.is_empty() or published!=admission_stamp or moving!=dynamic_members or world.entries.size()!=known_entry_count or screen_size.x>viewport.size.x or screen_size.y>viewport.size.y
    var phase = Time.get_ticks_usec()
    if reconcile:
        if not _reconcile(world):
            for issue in errors:
                if issue not in world.presentation_errors: world.presentation_errors.append(issue)
            last_sync_ms=(Time.get_ticks_usec()-started)/1000.0
            return
        admission_stamp=published.duplicate(); dynamic_members=moving; known_entry_count=world.entries.size()
    last_reconcile_ms=(Time.get_ticks_usec()-phase)/1000.0
    var camera: Camera3D = world.camera
    var key = [camera.global_transform,camera.size,screen_size]
    var camera_changed: bool = key!=canvas_key
    canvas_key=key
    var basis = Basis(camera.global_basis.x,-camera.global_basis.y,camera.global_basis.z).transposed()
    var basis_changed: bool = basis!=plane_basis
    plane_basis=basis
    if camera_changed:
        # One affine native parent handles all orthographic pan/zoom. The
        # shader reads MODEL_MATRIX for receiving, then bypasses it for storage.
        var zero = camera.unproject_position(Vector3.ZERO)
        plane_to_screen=Transform2D(camera.unproject_position(camera.global_basis.x)-zero,camera.unproject_position(-camera.global_basis.y)-zero,zero)
        projection_root.transform=plane_to_screen
    var restyle: bool = reconcile or styles.is_empty() or styles!=visibility_stamp
    if restyle:
        for receiver in static_receivers: _style(receiver)
        visibility_stamp=styles.duplicate()
    for receiver in dynamic_receivers: _style(receiver)
    # Source updates are few material groups, never one native call per tile.
    # Highlight remains independently polled because hover/Alt owns that value.
    for group in groups.values():
        var entry: Dictionary = group.entry
        var copied: bool = group.version!=entry.get("source_version",0) or group.source_shader!=entry.material.shader
        if copied: _copy_parameters(group)
        var highlighted = entry.material.get_shader_parameter("highlighted")
        if highlighted!=group.highlighted:
            group.material.set_shader_parameter("highlighted",highlighted); group.highlighted=highlighted
        if basis_changed or copied: group.material.set_shader_parameter("world_to_canvas",basis)
        if camera_changed or copied: group.material.set_shader_parameter("actual_scene_viewport_size",screen_size)
        if group.water:
            var seconds = entry.material.get_shader_parameter("displayed_time_seconds")
            group.material.set_shader_parameter("displayed_time_seconds",seconds)
    phase=Time.get_ticks_usec()
    var screen=Rect2(Vector2.ZERO,screen_size)
    if basis_changed:
        for receiver in static_receivers: _project(receiver,true)
    else:
        for receiver in projection_dirty: _project(receiver,true)
    if reconcile or camera_changed or restyle:
        static_live_receivers=0
        for receiver in static_receivers:
            if _visibility(receiver,screen): static_live_receivers+=1
    live_receivers=static_live_receivers
    for receiver in dynamic_receivers:
        _project(receiver,basis_changed)
        if _visibility(receiver,screen): live_receivers+=1
    last_projection_ms=(Time.get_ticks_usec()-phase)/1000.0
    last_sync_ms=(Time.get_ticks_usec()-started)/1000.0

func sync_output(world: Node, published: Array = []) -> void:
    # Only after painter/mask publication. The original texture RID remains live
    # across mask redraws; source/material admissions invalidate this stamp.
    if not published.is_empty() and published==output_stamp: return
    output_stamp=published.duplicate()
    for entry in world.entries:
        if not entry.has("received_material") or not is_instance_valid(entry.node): continue
        var output: ShaderMaterial = entry.received_material
        output.render_priority=entry.material.render_priority
        if entry.has("wall_source"):
            for name in ["wall_opacity","wall_mask_enabled","wall_mask_id","wall_mask_texture"]:
                var value = entry.material.get_shader_parameter(name)
                if output.get_shader_parameter(name)!=value: output.set_shader_parameter(name,value)

func close() -> void:
    var restored = {}
    for receiver in receivers:
        var entry: Dictionary = receiver.entry
        if not is_instance_valid(entry.node): continue
        var id: int = entry.node.get_instance_id()
        if restored.has(id): continue
        restored[id]=true
        entry.node.material_override=entry.material
        if entry.has("batch_rows"):
            var buffer: PackedFloat32Array = entry.ground_buffer
            for index in entry.batch_rows.size():
                buffer[index*20+17]=0; buffer[index*20+18]=0; buffer[index*20+19]=0
                var packet: Dictionary = entry.ground_packets[entry.batch_rows[index].id]
                var data: PackedFloat32Array = packet.data
                data[17]=0; data[18]=0; data[19]=0; packet.data=data
            entry.ground_buffer=buffer; entry.node.multimesh.buffer=buffer
    receivers.clear(); static_receivers.clear(); dynamic_receivers.clear(); groups.clear(); membership.clear(); layout_members.clear(); crop_cache.clear()
    admission_stamp.clear(); visibility_stamp.clear(); dynamic_members.clear(); output_stamp.clear(); canvas_key.clear(); known_entry_count=-1
    if is_instance_valid(viewport): viewport.queue_free()
    viewport=null
