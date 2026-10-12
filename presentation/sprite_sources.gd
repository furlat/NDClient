extends Node3D
# Original source-sprite creation shared by workshop/live views and the passive
# quarter builder. No session, input, rules or displayed-state ownership lives here.
const FrameProfile = preload("res://frame_profile.gd")
const Placement = preload("res://placement.gd")
const Catalog = preload("res://source_catalog.gd")
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
var water_materials: Array[WeakRef] = []
var source_images: Dictionary = {}
const Order = preload("res://grid_order.gd")
const FIXTURE_FLAME_SHADER = preload("res://presentation/fixture_flame.gdshader")
var static_entries: Array = []
var fixture_entries: Array = []
var fixture_clips: Dictionary = {}
var fixture_clock_owner: Node
var fixture_frame_energy: Dictionary = {}
var fixture_frame_centroids: Dictionary = {}
var presentation_errors: Array = []
var media_issue = ""
var sprite_parent: Node3D

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
    var separate_shadow = not row.has("source_sprite")
    if row.has("source_sprite"):
        var record = record_for(row)
        separate_shadow = record.get("roles",[]).any(func(part):return part.role=="ground_shadow") or Catalog.break_duration(row,catalog_cache)>0
    if separate_shadow:
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
    var source_row = row
    if row.get("attachment_absent",false): source_row = row
    var record = Catalog.environment(source_row, quarter, catalog_cache, phase, time)
    if row.has("parent_id") and destruction.has(row.parent_id) and Catalog.owner_for(row,catalog_cache).get("omit_with_destroyed_parent",false):
        record = record.duplicate()
        record.hidden = true
    return record

func add_entry(row: Dictionary, role: String, layer: int, shader: Shader, source_role: int = -1) -> void:
    var node = MeshInstance3D.new()
    node.mesh = QuadMesh.new()
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.sorting_use_aabb_center = false
    var material = ShaderMaterial.new()
    material.shader = shader
    node.material_override = material
    (sprite_parent if sprite_parent != null and row.kind != "actor" else self).add_child(node)
    entries.append({"id": row.id + ":" + str(layer) + ":" + role, "placement": row, "role": role,
        "layer": layer, "source_role": source_role, "node": node, "material": material, "screen_rect": Rect2(),
        "mobile":row.kind=="actor" or row.has("break_owner")})
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
        if entry.role == "shadow": entry.material.set_shader_parameter("shadow", true)
    else:
        set_environment(entry, Basis(Vector3.UP, quarter * PI * 0.5))

func set_quad(entry: Dictionary, cell: Vector2, pivot: Vector2, scale: float) -> void:
    var mesh: QuadMesh = entry.node.mesh
    mesh.size = cell * scale / Placement.PIXELS_PER_UNIT
    mesh.center_offset = Vector3((cell.x * 0.5 - pivot.x) * scale / Placement.PIXELS_PER_UNIT,
        (pivot.y - cell.y * 0.5) * scale / Placement.PIXELS_PER_UNIT, 0.0)
    entry.node.custom_aabb = mesh.get_aabb()
    entry.cell = cell
    entry.pivot = pivot
    entry.scale = scale
    update_bounds(entry)

func update_bounds(entry: Dictionary) -> void:
    var row: Dictionary = entry.placement
    var origin = Placement.project(v2(row.position), row.base_height_steps, quarter)
    entry.screen_rect = Rect2(origin - entry.pivot * entry.scale, entry.cell * entry.scale)

func set_environment(entry: Dictionary, rotation: Basis) -> void:
    var row: Dictionary = entry.placement
    var record = Catalog.door_frame(row,quarter,catalog_cache) if entry.source_role == 2 else record_for(row)
    if record.is_empty(): entry.node.visible = false; return
    entry.record = record
    var mat: ShaderMaterial = entry.material
    var cell = v2(record.native_size)
    set_quad(entry, cell, v2(record.pivot), record.scale)
    mat.set_shader_parameter("source_tint",v4(row.get("tint",[1,1,1,1])))
    if row.has("affine"):
        var affine: Array = row.affine
        var a = Vector2(affine[0],affine[1])
        var b = Vector2(affine[2],affine[3])
        if row.get("ground_projection",false):
            a = Placement.project(Placement.rotate_grid(Vector2(a.x/128+a.y/64,a.y/64-a.x/128),quarter),0,0)
            b = Placement.project(Placement.rotate_grid(Vector2(b.x/128+b.y/64,b.y/64-b.x/128),quarter),0,0)
        entry.node.basis = camera.basis * Basis(Vector3(a.x,-a.y,0),Vector3(-b.x,b.y,0),Vector3(0,0,1))
        var bounds = Rect2()
        var origin = Placement.project(v2(row.position),row.base_height_steps,quarter)
        for corner in [Vector2.ZERO,Vector2(cell.x,0),cell,Vector2(0,cell.y)]:
            var p = (corner-v2(record.pivot))*record.scale
            var point = origin+a*p.x+b*p.y
            bounds = Rect2(point,Vector2.ZERO) if corner==Vector2.ZERO else bounds.expand(point)
        entry.screen_rect = bounds
    if row.get("water_surface",false):
        record = record.duplicate()
        record.water = Catalog.read_file("assets.json",catalog_cache).water
        entry.record = record
    if record.has("water"):
        entry.node.visible = entry.source_role == 1
        mat.shader = WATER_SHADER
        mat.set_shader_parameter("displayed_time_seconds",water_clock_seconds)
        if not entry.get("water_clock_registered",false):
            water_materials.append(weakref(mat))
            entry.water_clock_registered = true
        var water: Dictionary = record.water
        var water_bounds: AABB = entry.node.mesh.get_aabb()
        var plane_ray: Vector3 = -camera.basis.z
        for x in [-0.5,0.5]:
            for y in [-0.5,0.5]:
                var painted: Vector3 = entry.node.basis*(entry.node.mesh.center_offset+Vector3(x*entry.node.mesh.size.x,y*entry.node.mesh.size.y,0))
                var receiver: Vector3 = painted+plane_ray*(-painted.y/plane_ray.y)
                water_bounds = water_bounds.expand(entry.node.basis.inverse()*receiver)
        entry.node.custom_aabb = water_bounds
        mat.set_shader_parameter("mask_texture",texture(record.path))
        mat.set_shader_parameter("ripple_texture",texture(Catalog.read_file("assets.json",catalog_cache).resources[water.ripple].path))
        mat.set_shader_parameter("origin",Placement.project(v2(row.position),row.base_height_steps,quarter)-v2(record.pivot)*record.scale)
        mat.set_shader_parameter("placement_origin",Placement.contact(row))
        mat.set_shader_parameter("camera_quarter",quarter)
        mat.set_shader_parameter("cell",cell)
        mat.set_shader_parameter("image_scale",record.scale)
        mat.set_shader_parameter("shallow_color",v4(water.shallowColor))
        mat.set_shader_parameter("deep_color",v4(water.deepColor))
        mat.set_shader_parameter("tint",v4(water.tint))
        mat.set_shader_parameter("ripple_pan",v2(water.ripplePan))
        for mapping in [["uv_scale","uvScale"],["depth_strength","depthBlendStrength"],["ripple_tiling","rippleTilingMultiplier"],["ripple_amount","rippleAmount"],["sheen_strength","sheenStrength"],["sheen_sharpness","sheenSharpness"],["alpha_strength","alphaDepthStrength"],["overall_alpha","overallAlpha"],["alpha_cutoff","alphaCutoff"]]:
            mat.set_shader_parameter(mapping[0],water[mapping[1]])
        return
    mat.set_shader_parameter("colour_texture", texture(record.path))
    mat.set_shader_parameter("colour_size", cell)
    mat.set_shader_parameter("colour_rect", v4(record.get("rect", [0, 0, cell.x, cell.y])))
    entry.node.visible = not record.get("hidden", false)
    mat.set_shader_parameter("door_leaf_partition",0)
    if entry.source_role == 3 or (entry.source_role == 1 and row.kind == "door"):
        var partition: Dictionary = record.get("door_partition",{})
        if partition.is_empty():
            # Banks without this authored registration, including destruction,
            # retain the ordinary single leaf draw rather than duplicate alpha.
            if entry.source_role == 3: entry.node.visible = false
        else:
            mat.set_shader_parameter("door_leaf_partition",-1 if entry.source_role == 3 else 1)
            mat.set_shader_parameter("door_depth_texture",texture(partition.path))
            mat.set_shader_parameter("door_depth_rect",v4(partition.rect))
            mat.set_shader_parameter("door_depth_cell",v2(partition.cell))
            mat.set_shader_parameter("door_depth_range",v2(partition.range))
            mat.set_shader_parameter("door_depth_scale",partition.scale)
            mat.set_shader_parameter("door_depth_offset",partition.offset)
            var origin = Placement.project(v2(row.position),0,quarter)
            mat.set_shader_parameter("door_frame_depth",Placement.sort_contact(row,quarter).y-origin.y)
    var shadow_selection: Dictionary = {}
    for source_role in record.get("roles", []):
        if source_role.role == "ground_shadow": shadow_selection = source_role.selection; break
    var shadow_pass: bool = entry.source_role == 0
    if shadow_pass and shadow_selection.is_empty(): entry.node.visible = false
    entry.floor_group = record.get("flat_ground", false)
    mat.set_shader_parameter("source_unlit", shadow_pass)
    mat.set_shader_parameter("highlighted", Input.is_physical_key_pressed(KEY_ALT) and Catalog.break_duration(row,catalog_cache) > 0 and not destruction.has(row.id) and entry.source_role != 2)
    if record.has("hit_mask"): texture(record.hit_mask.path)
    mat.set_shader_parameter("use_selection", not shadow_selection.is_empty())
    mat.set_shader_parameter("invert_selection", not shadow_pass)
    if not shadow_selection.is_empty():
        var selection = shadow_selection
        mat.set_shader_parameter("selection_kind", 1 if selection.kind == "source_rgba" else 0)
        if selection.kind == "source_rgba":
            mat.set_shader_parameter("rgba_min", v4(selection.bounds.minimum))
            mat.set_shader_parameter("rgba_max", v4(selection.bounds.maximum))
        elif selection.kind == "mask":
            var mask: Dictionary = selection.mask
            mat.set_shader_parameter("selection_mask", texture(mask.region.path))
            mat.set_shader_parameter("selection_rect", v4(mask.region.rect))
            mat.set_shader_parameter("selection_scale", v2(mask.sampling.scale))
            mat.set_shader_parameter("selection_offset", v2(mask.sampling.offset))
            var values = [-1.0, -1.0, -1.0, -1.0]
            for i in range(mini(4, selection.values.size())): values[i] = selection.values[i]
            mat.set_shader_parameter("selection_values", v4(values))
    mat.set_shader_parameter("has_geometry", record.has("geometry"))
    if not record.has("geometry"): return
    var g: Dictionary = record.geometry
    var sampling: Dictionary = record.geometry_sampling
    mat.set_shader_parameter("geometry_texture", texture(record.geometry_region.path))
    mat.set_shader_parameter("normal_texture", texture(record.normal.region.path))
    mat.set_shader_parameter("geometry_rect", v4(record.geometry_region.rect))
    mat.set_shader_parameter("normal_rect", v4(record.normal.region.rect))
    mat.set_shader_parameter("sample_scale", v2(sampling.scale))
    mat.set_shader_parameter("sample_offset", v2(sampling.offset))
    mat.set_shader_parameter("sample_center", v2(sampling.pixel_center))
    mat.set_shader_parameter("normal_scale", v2(record.normal.sampling.scale))
    mat.set_shader_parameter("normal_offset", v2(record.normal.sampling.offset))
    mat.set_shader_parameter("pixel_to_ray", matrix3(g.pixelToRayOrigin))
    mat.set_shader_parameter("ray_direction", Vector3(g.rayDirection[0], g.rayDirection[1], g.rayDirection[2]))
    mat.set_shader_parameter("depth_range", v2(g.depthRange))
    mat.set_shader_parameter("source_to_local", matrix4(g.sourceToLocal))
    mat.set_shader_parameter("normal_to_local", matrix3(record.normal.normalToLocal))
    var world_basis = rotation * Basis.from_scale(Vector3(1, Placement.HEIGHT_UNIT, 1))
    if g.basis == "object_local":
        var orientation: String = row.get("orientation", "east")
        world_basis = Basis(Vector3.UP, -["east", "north", "west", "south"].find(orientation) * PI / 2) * Basis.from_scale(Vector3(1, Placement.HEIGHT_UNIT, 1))
    mat.set_shader_parameter("local_to_world", Transform3D(world_basis, Placement.contact(row)))
    mat.set_shader_parameter("local_normal_to_world", world_basis.inverse().transposed())
    mat.set_shader_parameter("use_source_depth", source_depth)
    mat.set_shader_parameter("use_source_normals", source_normals)
    # LIGHT_VERTEX changes light reception without moving painted vertices.
    # Native culling needs the union of both volumes. The authored affine packet
    # reaches its extrema at these eight corners; no per-texel CPU scan is needed.
    var receiver_to_quad: Transform3D = Transform3D(entry.node.basis.inverse()*world_basis,Vector3.ZERO)*matrix4(g.sourceToLocal)
    var pixel_ray: Basis = matrix3(g.pixelToRayOrigin)
    var ray := Vector3(g.rayDirection[0],g.rayDirection[1],g.rayDirection[2])
    var bounds: AABB = entry.node.mesh.get_aabb()
    for x in [0.0,float(record.geometry_region.rect[2])]:
        for y in [0.0,float(record.geometry_region.rect[3])]:
            for depth in g.depthRange:
                var point: Vector3 = pixel_ray*Vector3(x+sampling.pixel_center[0],y+sampling.pixel_center[1],1)+ray*float(depth)
                bounds = bounds.expand(receiver_to_quad*point)
    entry.node.custom_aabb = bounds

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

func _ground_begin(rows: Array, prepared_packets: Dictionary = {}) -> Dictionary:
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
    entry.material.set_shader_parameter("use_instance_visibility",true)
    multi.instance_count = ceili(rows.size()/256.0)*256
    multi.visible_instance_count = rows.size()
    return {"rows":rows,"entry":entry,"multi":multi,"index":0,"bounds":AABB(),
        "packets":packets,"indices":{},"buffer":PackedFloat32Array()}

func _ground_fill(job: Dictionary, limit: int = 64) -> bool:
    var rows: Array = job.rows
    var end = mini(rows.size(),job.index+limit)
    for i in range(job.index,end):
        var packet: Dictionary = job.packets[rows[i].id]
        _ground_packet(rows[i],job.entry,packet)
        job.indices[rows[i].id] = i
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
    entry.scenery_values = []
    for row in job.rows: entry.scenery_values.append(0.0)
    static_entries.append(entry)

func _ground_update(entry: Dictionary, rows: Array) -> void:
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
    # The representative is part of picking/order/source identity even though
    # all instances still use the same original material/quad.
    entry.placement = rows[0]; entry.id = rows[0].id+":0:terrain"
    update_bounds(entry)

func _ground_publish(entry: Dictionary, packet: Dictionary) -> void:
    var multi: MultiMesh = entry.node.multimesh
    var rows: Array = packet.rows
    if multi.instance_count<rows.size(): multi.instance_count = ceili(rows.size()/256.0)*256
    multi.custom_aabb = packet.bounds; multi.buffer = packet.buffer
    multi.visible_instance_count = rows.size()
    entry.batch_rows = rows; entry.ground_packets = packet.packets; entry.ground_indices = packet.indices
    entry.ground_buffer = packet.buffer; entry.scenery_values = packet.values
    entry.placement = rows[0]; entry.id = rows[0].id+":0:terrain"
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
    var assets = Catalog.read_file("assets.json",catalog_cache)
    if not fixture_clips.has(name):
        var authored: Dictionary = assets.animations[name]
        var images: Array[Image] = []
        var energy: Array = []
        var heights: Array = []
        var total = 0.0
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
        var mean = total/maxi(1,energy.size())
        for i in range(energy.size()):
            energy[i] = clampf(energy[i]/maxf(mean,0.0000001),0.85,1.15)
        var sheets = Texture2DArray.new()
        var started = Time.get_ticks_usec()
        var result = sheets.create_from_images(images)
        FrameProfile.end_phase(profile,"texture_upload",started)
        assert(result == OK,"Cannot prepare authored fixture animation: "+name)
        var duration: float = authored.frames.size()/float(authored.fps)
        var clock_node = Graphs.make(fixture_clock_owner if fixture_clock_owner!=null else self,{"Idle":Graphs.animation("Idle",duration,true)},"Idle",[])
        fixture_clips[name] = {"authored":authored,"frames":sheets,"clock":clock_node,"index":0,"energy":energy,"heights":heights}
    var clip: Dictionary = fixture_clips[name]
    var record: Dictionary = assets.resources[clip.authored.frames[0]]
    add_entry(row,"body",100,FIXTURE_FLAME_SHADER,1)
    var entry: Dictionary = entries.back()
    entry.record = record
    entry.node.basis = camera.basis
    entry.node.position = Placement.contact(row)
    set_quad(entry,v2(record.native_size),v2(record.pivot),record.scale)
    entry.material.set_shader_parameter("frames",clip.frames)
    static_entries.append(entry)
    fixture_entries.append(entry)
