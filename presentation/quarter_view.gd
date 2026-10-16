extends "res://presentation/sprite_sources.gd"
# Passive native scene preparation. It owns source sprites for one quarter,
# never a session, timeline, input controller, or temporary live-world state.
const WallReveal = preload("res://presentation/wall_reveal.gd")
const WorldRows = preload("res://presentation/world.gd")
const COVERAGE = preload("res://presentation/wall_coverage.gdshader")
var host: Node
var generation = -1
var style_key: Array = []
var completed_style: Array = []
var phase = "idle"
var cursor = 0
var rows: Array = []
var ground: Dictionary = {}
var ground_keys: Array = []
var ground_job: Dictionary = {}
var groups: Dictionary = {}
var ground_groups: Dictionary = {}
var geometry: Dictionary = {}
var tiles: Array = []
var sources: Array = []
var source_ids: Dictionary = {}
var scenery_consumers: Dictionary = {}
var wall_entries: Array = []
var current_visibility: Dictionary = {}
var visible_cells: Dictionary = {}
var wall_mode = "solid"
var choices: Dictionary = {}
var faded: Dictionary = {}
var order: Array = []
var picks: Array = []
var support_candidates = 0
var max_member_candidates = 0
var background = true
var mask_viewport: SubViewport
var mask_nodes: Array[ColorRect] = []
var mask_sources: Array = []
var mask_view: Array = []
var projection_key: Array = []
var mask_cursor = 0
var batch_cursor = 0
var is_prepared = false
var slice_max_ms = 0.0

func release_handles() -> Array:
    # Keep each material and its passive entry alive until its individual node
    # is released. Dropping a whole hidden view otherwise destroys every native
    # draw and resource together at the end of one frame.
    var held = entries
    entries = []; static_entries = []; fixture_entries = []; actor_entries = []
    groups = {}; ground_groups = {}; scenery_consumers = {}; wall_entries = []
    order = []; picks = []; mask_sources = []; mask_nodes = []
    ground_job = {}; ground = {}; rows = []; tiles = []
    return held

func texture(path: String) -> Texture2D:
    return host.texture(path)

func _light_entry(entry: Dictionary) -> void:
    host._light_entry(entry)

func configure(owner: Node, target: int, cached: Dictionary = {}) -> void:
    host = owner; fixture_clock_owner = owner; quarter = target; visible = false; is_prepared = false
    generation = host.world_generation
    catalog_cache = host.catalog_cache; profile = host.profile
    source_images = host.source_images; source_depth = host.source_depth; source_normals = host.source_normals
    fixture_clips = host.fixture_clips; fixture_frame_energy = host.fixture_frame_energy; fixture_frame_centroids = host.fixture_frame_centroids
    presentation_errors = host.presentation_errors
    background = host.ground_is_background
    if camera == null:
        camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; add_child(camera)
    camera.current = false
    set_target_camera()
    if not cached.is_empty():
        entries = cached.entries; static_entries = entries; fixture_entries = cached.fixtures
        groups = cached.groups; ground_groups = cached.ground
        scenery_consumers = cached.get("scenery_consumers",{})
        wall_entries = cached.get("wall_entries",[]); sources = cached.get("wall_sources",[])
        order = cached.order; picks = cached.wall_pick_order
        geometry = cached.geometry
        faded = {}
        for id in cached.faded: faded[id] = true
        mask_viewport = cached.mask_viewport; mask_nodes = cached.mask_nodes; mask_sources = cached.mask_sources; mask_view = cached.mask_view
        support_candidates = cached.support_candidates; max_member_candidates = cached.max_member_candidates
        # The root is retained with its geometry, material selection and mask.
        begin_style()
    else:
        rows = host.world_visual_rows
        phase = "rows"; cursor = 0
        geometry = {"targets":{},"buckets":{},"versions":{},"revision":1,"candidates":{},"generation":generation}

func set_target_camera() -> void:
    camera.size = host.camera.size; camera.near = host.camera.near; camera.far = host.camera.far
    camera.transform=Placement.camera_transform(host.camera_focus,quarter)

func begin_style() -> void:
    wall_mode = host.wall_mode
    current_visibility = host.scenery_visibility.duplicate()
    visible_cells = {}
    var senses: Variant = host.timeline.state.get("senses")
    for position in senses.get("visible",[]) if senses != null else []: visible_cells[WorldRows.cell_key(position)] = true
    style_key = [wall_mode,current_visibility,visible_cells]
    set_target_camera()
    if completed_style == style_key:
        phase = "mask_position"; cursor = 0
        return
    choices = {}; faded = {}; support_candidates = 0; max_member_candidates = 0
    sources = []; source_ids = {}; scenery_consumers = {}; wall_entries = []
    for entry in static_entries:
        if entry.has("wall_source") and not source_ids.has(entry.wall_source.id):
            sources.append(entry.wall_source); source_ids[entry.wall_source.id] = true
    phase = "walls"; cursor = 0

func projection_is_current() -> bool:
    return projection_key == [host.camera_focus,host.camera.size,host.get_viewport().get_visible_rect().size]

func refresh_projection() -> void:
    is_prepared = false; phase = "mask_position"; cursor = 0

func style_is_current() -> bool:
    if style_key.is_empty(): return true
    if wall_mode != host.wall_mode or current_visibility != host.scenery_visibility: return false
    var senses: Variant = host.timeline.state.get("senses")
    var positions: Array = senses.get("visible",[]) if senses != null else []
    if positions.size() != visible_cells.size(): return false
    for position in positions:
        if not visible_cells.has(WorldRows.cell_key(position)): return false
    return true

func step(budget_usec: int = 3000) -> void:
    if is_prepared: return
    var started = Time.get_ticks_usec()
    if not style_is_current() and phase not in ["rows","ground","tiles"]: begin_style()
    # A large visibility guard can consume the whole slice. Still advance one
    # existing unit, or an otherwise valid target could starve indefinitely.
    var advanced = false
    while not is_prepared and (not advanced or Time.get_ticks_usec()-started < budget_usec):
        advanced = true
        match phase:
            "rows":
                if cursor == rows.size():
                    ground_keys = ground.keys(); phase = "ground"; cursor = 0; continue
                var row: Dictionary = rows[cursor]; cursor += 1
                if background and row.kind=="terrain" and row.base_height_steps==0 and row.material!="water":
                    if not ground.has(row.material): ground[row.material] = []
                    ground[row.material].append(row)
                else:
                    var first = static_entries.size()
                    _environment_row(row.duplicate(true))
                    groups[row.id] = {"row":row,"entries":static_entries.slice(first)}
            "ground":
                if cursor == ground_keys.size():
                    tiles = host.timeline.presentation_state().tiles.values(); phase = "tiles"; cursor = 0; continue
                var key: String = ground_keys[cursor]
                if ground_job.is_empty(): ground_job = _ground_begin(ground[key].duplicate(true))
                elif _ground_fill(ground_job):
                    _ground_finish(ground_job)
                    ground_groups[key] = {"rows":ground[key],"entries":[ground_job.entry]}
                    ground_job = {}; cursor += 1
            "tiles":
                if cursor == tiles.size(): begin_style(); continue
                WallReveal.add_tile(geometry,tiles[cursor],quarter); cursor += 1
            "walls":
                if cursor == sources.size(): phase = "style"; cursor = 0; batch_cursor = 0; order = []; picks = []; continue
                var source: Dictionary = sources[cursor]; cursor += 1
                if wall_mode != "solid":
                    for member in source.get("wall_members",[source]):
                        var targets = WallReveal.targets(member,geometry,quarter)
                        support_candidates += targets.size(); max_member_candidates = maxi(max_member_candidates,targets.size())
                        if targets.any(func(target):return visible_cells.has(target.cell)): faded[member.id] = true
                choices[source.id] = WallReveal.variants(source,faded,wall_mode,current_visibility)
            "style":
                if cursor == static_entries.size():
                    order.sort_custom(before); picks.sort_custom(before)
                    phase = "mask"; cursor = 0; mask_cursor = 0
                    continue
                var entry: Dictionary = static_entries[cursor]
                if entry.has("batch_rows"):
                    var end = mini(batch_cursor+64,entry.batch_rows.size())
                    var values: Array = entry.get("scenery_values",[])
                    for i in range(batch_cursor,end):
                        var value = 1.0 if current_visibility.get(entry.batch_rows[i].id,false) else 0.0
                        _ground_visibility(entry,i,value)
                    entry.scenery_values = values; batch_cursor = end
                    if end < entry.batch_rows.size(): continue
                    _ground_flush_visibility(entry,range(entry.batch_rows.size()))
                    batch_cursor = 0
                elif entry.material.shader in [ENVIRONMENT_SHADER,WATER_SHADER]:
                    var id: String = entry.placement.id
                    if not scenery_consumers.has(id): scenery_consumers[id] = []
                    scenery_consumers[id].append({"entry":entry,"index":-1})
                    var value = 1.0 if current_visibility.get(entry.placement.id,false) else 0.0
                    SourceMaterial.set_parameter(entry,&"current_visibility",value); entry.scenery_value = value
                if entry.has("wall_source"):
                    wall_entries.append(entry)
                    var alpha: float = choices[entry.wall_source.id].get(entry.wall_variant,0.0)
                    entry.node.visible = alpha>0 and entry.wall_source_visible
                    entry.wall_opacity = alpha; SourceMaterial.set_parameter(entry,&"wall_opacity",alpha)
                    entry.wall_mask_enabled = wall_mode=="translucent" and entry.role!="shadow"
                    SourceMaterial.set_parameter(entry,&"wall_mask_enabled",wall_mode=="translucent" and entry.role!="shadow")
                    if entry.role!="shadow" and entry.wall_variant!="joined" and entry.wall_source_visible: picks.append(entry)
                entry.order_key = Order.key(entry.placement,entry.role,entry.layer,quarter,background); entry.order_quarter = quarter
                if entry.node.visible: order.append(entry)
                cursor += 1
            "mask":
                if wall_mode != "translucent":
                    phase = "mask_position"; cursor = 0; completed_style = style_key.duplicate(true); continue
                if mask_viewport == null:
                    mask_viewport = SubViewport.new(); mask_viewport.disable_3d = true; mask_viewport.transparent_bg = true
                    mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED; add_child(mask_viewport)
                    RenderingServer.viewport_set_measure_render_time(mask_viewport.get_viewport_rid(),true)
                if cursor == 0: mask_sources = []
                if cursor == order.size():
                    while mask_nodes.size()>mask_cursor: mask_nodes.pop_back().queue_free()
                    # A stable camera can still have a different joined/member
                    # source at each coverage index after a style change.
                    mask_view = []
                    phase = "mask_position"; cursor = 0; completed_style = style_key.duplicate(true); continue
                var entry: Dictionary = order[cursor]; cursor += 1
                if entry.placement.kind not in ["wall","cliff"] or entry.role=="shadow": continue
                var rect: ColorRect
                if mask_cursor == mask_nodes.size():
                    rect = ColorRect.new(); rect.material = ShaderMaterial.new(); rect.material.shader = COVERAGE
                    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; mask_viewport.add_child(rect); mask_nodes.append(rect)
                else: rect = mask_nodes[mask_cursor]
                mask_cursor += 1
                var source_key = [entry.node.get_instance_id(),entry.material.get_instance_id(),entry.get("source_version",0)]
                if rect.material.get_meta("coverage_source",[]) != source_key:
                    for parameter in ["colour_texture","colour_size","colour_rect","use_selection","invert_selection","selection_kind","rgba_min","rgba_max","selection_mask","selection_rect","selection_scale","selection_offset","selection_values"]:
                        rect.material.set_shader_parameter(parameter,SourceMaterial.value(entry,StringName(parameter)))
                    rect.material.set_meta("coverage_source",source_key)
                rect.material.set_shader_parameter("wall_mask_id",mask_cursor)
                SourceMaterial.set_parameter(entry,&"wall_mask_id",mask_cursor)
                SourceMaterial.set_parameter(entry,&"wall_mask_texture",mask_viewport.get_texture())
                SourceMaterial.set_parameter(entry,&"wall_mask_enabled",wall_mode=="translucent")
                mask_sources.append(entry)
            "mask_position":
                var view = [camera.global_transform,camera.size,host.get_viewport().get_visible_rect().size]
                if cursor == 0:
                    projection_key = [host.camera_focus,host.camera.size,host.get_viewport().get_visible_rect().size]
                    set_target_camera()
                    view = [camera.global_transform,camera.size,host.get_viewport().get_visible_rect().size]
                    if wall_mode != "translucent": phase = "finish"; continue
                    if view == mask_view: phase = "finish"; continue
                    mask_view = view; mask_viewport.size = Vector2i(view[2])
                if cursor == mask_nodes.size(): phase = "finish"; continue
                var source: MeshInstance3D = mask_sources[cursor].node
                var mesh: QuadMesh = source.mesh
                var start = camera.unproject_position(source.global_transform*(mesh.center_offset+Vector3(-mesh.size.x*.5,mesh.size.y*.5,0)))
                var end = camera.unproject_position(source.global_transform*(mesh.center_offset+Vector3(mesh.size.x*.5,-mesh.size.y*.5,0)))
                mask_nodes[cursor].position = start; mask_nodes[cursor].size = end-start
                cursor += 1
            "finish":
                if mask_viewport != null:
                    mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if wall_mode=="translucent" else SubViewport.UPDATE_DISABLED
                fixture_entries = static_entries.filter(func(entry):return entry.material.shader == FIXTURE_FLAME_SHADER)
                is_prepared = true
    slice_max_ms = maxf(slice_max_ms,(Time.get_ticks_usec()-started)/1000.0)
    FrameProfile.end_phase(profile,"rotation_prepare",started)

func before(a: Dictionary,b: Dictionary) -> bool:
    return Order.less(a.order_key,b.order_key) if a.order_key!=b.order_key else a.id<b.id

func snapshot() -> Dictionary:
    return {"root":self,"groups":groups,"ground":ground_groups,"entries":static_entries,"fixtures":fixture_entries,
        "order":order,"order_dirty":false,"order_count":static_entries.size(),"wall_pick_order":picks,
        "mask_viewport":mask_viewport,"mask_nodes":mask_nodes,"mask_sources":mask_sources,"mask_view":mask_view,
        "scenery_consumers":scenery_consumers,"wall_sources":sources,"wall_entries":wall_entries,
        "geometry":geometry,"faded":faded.keys(),"visible_cells":host.wall_visible_cells.duplicate(),
        "support_candidates":support_candidates,"max_member_candidates":max_member_candidates}
