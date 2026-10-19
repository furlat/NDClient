extends "res://presentation/sprite_sources.gd"

@export var exploration_mode = false
const Exploration = preload("res://exploration.gd")
const TerrainBatches = preload("res://terrain_batches.gd")
const ViewBuild = preload("res://view_build.gd")
const GridRenderer = preload("res://grid_renderer.gd")
var gpu_grid: Dictionary = {}
var view_build: Dictionary = {}
var view_thread: Thread
var view_revision = 0
var last_sort_job_ms = 0.0
var terrain_batches: Array = []
var batches_dirty = true
var exploration_ui: Control
var follow_player = false

const Walking = preload("res://walking.gd")
const MapData = preload("res://map_data.gd")
const Editor = preload("res://editor.gd")
const Modular = preload("res://modular.gd")
const MODULAR_SHADER = preload("res://modular.gdshader")
const ACTOR_SHADER = preload("res://actor.gdshader")
const SHADOW_SHADER = preload("res://shadow.gdshader")
# The workshop lights sprites with its movable 3D lamp, not the game's light table.
const WORKSHOP_SHADERS = {
    preload("res://environment.gdshader"): preload("res://workshop/environment_3d.gdshader"),
    preload("res://modular.gdshader"): preload("res://workshop/modular_3d.gdshader"),
    preload("res://water.gdshader"): preload("res://workshop/water_3d.gdshader"),
    preload("res://presentation/fixture_flame.gdshader"): preload("res://workshop/fixture_flame_3d.gdshader"),
}
var active_texture_paths: Dictionary = {}
var texture_gc_dirty = true
var composition_cache: Dictionary = {}
var lamp: OmniLight3D
var scene_index = 0
var actor_action: OptionButton
var outfit_choice = "Leather Armor"
var effect_choice = ""
var equipment_choices = {"body_armor":"Leather Armor","weapon":"Longsword","offhand":"Shield","helmet":""}
var effect_choices = {}
var equipment_controls = {}
var effect_controls = {}
var player_clip = "Idle"
var capturing = false
var preview_mode = true
var selected_id = ""
var asset_catalog: Array = []
var catalog_by_id: Dictionary = {}
var palette_id = ""
var palette_list: ItemList
var height_control: SpinBox
var orientation_control: OptionButton
var editor_info: Label
var editor_tool = "select"
var source_choice: OptionButton
var frame_control: SpinBox
var loaded_rows: Dictionary = {}
var undo_history: Array = []
var map_serial = 0
var stats_elapsed = 0.0
var performance_label: Label
var last_frame_usec = 0
var frame_ms = 0.0
var worst_frame_ms = 0.0
var view_update_ms = 0.0
var view_pending = false
var pending_rows = 0
var refresh_queue: Array = []
var refresh_cursor = 0
var visible_queue: Array = []
var visible_signature: Array = []
var visible_cursor = 0
var composition_dirty = false
var support_cells: Dictionary = {}
var stair_definition: Dictionary = {}
var stair_rows: Array = []
var placement_buckets: Array = [{},{},{},{}]
var map_min_height = 0.0
var rows_by_id: Dictionary = {}


func sprite_shader(shader: Shader) -> Shader:
    return WORKSHOP_SHADERS.get(shader, shader)

func _ready() -> void:
    DisplayServer.window_set_title("NDClient — Smallscale GPU exploration" if exploration_mode else "NDClient — Authoring workshop")
    RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
    var catalog = Catalog.read_file("catalog-index.json", catalog_cache)
    rig_config = Catalog.read_file(catalog.rig, catalog_cache)
    rigs = Catalog.read_file(catalog.rigs, catalog_cache)
    resources = Catalog.read_file(catalog.resources, catalog_cache)
    stair_definition = Catalog.environment_world(catalog_cache).terrain_stairs
    scenes = JSON.parse_string(FileAccess.get_file_as_string("res://scenes.json")).scenes
    asset_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://generated/catalog.json")).entries
    for entry in asset_catalog: catalog_by_id[entry.id] = entry
    scenes.append({} if exploration_mode else MapData.catalog_map(asset_catalog))
    if exploration_mode: scenes.append(JSON.parse_string(FileAccess.get_file_as_string("res://generated/unity_map.json")))
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.near = 0.1
    camera.far = 100.0
    add_child(camera)
    camera.current = true
    lamp = OmniLight3D.new()
    lamp.position = Vector3(-1.4, 2.8, 1.2)
    lamp.light_color = Color(1.0, 0.7, 0.35)
    lamp.light_energy = 3.0
    lamp.omni_range = 8.0
    lamp.shadow_enabled = false
    add_child(lamp)
    var marker = MeshInstance3D.new()
    var sphere = SphereMesh.new()
    sphere.radius = 0.06
    sphere.height = 0.12
    marker.mesh = sphere
    var marker_material = StandardMaterial3D.new()
    marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    marker_material.albedo_color = lamp.light_color
    marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    marker_material.no_depth_test = true
    marker_material.render_priority = 127
    marker.material_override = marker_material
    lamp.add_child(marker)
    if exploration_mode:
        exploration_ui = Exploration.new()
        exploration_ui.world = self
        var hud = CanvasLayer.new()
        add_child(hud)
        hud.add_child(exploration_ui)
        performance_label = exploration_ui.performance
        load_scene(4)
        lamp.visible = false
    else:
        build_controls()
        Editor.build(self)
        load_scene(3)
    if "--workshop-check" in OS.get_cmdline_user_args():
        capturing = true
        capture_workshop.call_deferred()
    if "--capture" in OS.get_cmdline_user_args():
        capturing = true
        capture_views.call_deferred()

func texture(path: String) -> Texture2D:
    texture_last_use[path] = Time.get_ticks_msec()
    if not textures.has(path):
        var decode_started = Time.get_ticks_usec()
        var source = Image.load_from_file(Catalog.media_path(path))
        FrameProfile.end_phase(profile,"texture_decode",decode_started)
        var upload_started = Time.get_ticks_usec()
        assert(source != null, "Missing source image: " + path)
        source_images[path] = source
        textures[path] = ImageTexture.create_from_image(source)
        FrameProfile.end_phase(profile,"texture_upload",upload_started)
    return textures[path]

func prune_texture_cache(limit: int = 2147483647) -> void:
    if textures.size() <= 96: return
    var active = active_texture_paths
    if texture_gc_dirty:
        active.clear()
    for entry in entries if texture_gc_dirty else []:
        if entry.has("texture_path"): active[entry.texture_path] = true
        active.merge(entry.get("geometry_paths",{}))
        var record: Dictionary = entry.get("record",{})
        if record.is_empty(): continue
        active[record.path] = true
        for field in ["geometry_region","hit_mask","door_partition"]:
            if record.has(field): active[record[field].path] = true
        if record.has("normal"): active[record.normal.region.path] = true
        for role in record.get("roles",[]):
            if role.selection.kind == "mask": active[role.selection.mask.region.path] = true
        if record.has("water"): active[Catalog.environment_resources(catalog_cache).resources[record.water.ripple].path] = true
    for playback in destruction.values() if texture_gc_dirty else []:
        if playback.phase!=2: active.merge(playback.get_meta("numeric_pages",{}))
    texture_gc_dirty = false
    var oldest = textures.keys()
    oldest.sort_custom(func(a,b): return texture_last_use[a] < texture_last_use[b])
    for path in oldest:
        if textures.size() <= maxi(96,active.size()): break
        if active.has(path): continue
        textures.erase(path)
        source_images.erase(path)
        texture_last_use.erase(path)
        limit -= 1
        if limit <= 0: break

func load_scene(index: int) -> void:
    TerrainBatches.clear(self)
    batches_dirty = true
    undo_history.clear()
    selected_id = ""
    for entry in entries:
        remove_child(entry.node)
        entry.node.queue_free()
    entries.clear()
    refresh_queue.clear()
    refresh_cursor = 0
    actor_entries.clear()
    composition_cache.clear()
    for playback in playbacks.values(): playback.queue_free()
    playbacks.clear()
    actor_rows.clear()
    loaded_rows.clear()
    visible_signature.clear()
    view_pending = false
    for playback in destruction.values(): playback.queue_free()
    destruction.clear()
    scene_index = index
    placements = scenes[index].placements.duplicate(true)
    camera_focus = Vector3(0, 1.6 if index in [1,3] else 0, 0)
    if scenes[index].has("camera_focus"):
        var focus: Array = scenes[index].camera_focus
        camera_focus = Vector3(focus[0],focus[1],focus[2])
    camera.size = scenes[index].camera_size
    for row in placements:
        if row.kind == "actor":
            row.rig = "neuroclient.modular"
            if not row.has("equipment"): row.equipment = equipment_choices.values().filter(func(item): return item != "")
            if not row.has("effects"): row.effects = effect_choices.duplicate()
            actor_rows.append(row)
            if row.id == "player":
                player = row
                sync_character_controls()
            playbacks[row.id] = Graphs.character(self, rigs[row.rig])
    index_map()
    if exploration_mode:
        position_camera()
        lamp.position=camera_focus+Vector3(-1.4,2.8,1.2)
        gpu_grid=GridRenderer.create(self)
        for row in actor_rows:
            loaded_rows[row.id]=row
            add_modular_entries(row)
            # Locomotion is the exploration input. Load its selected layers
            # with the map so the first WASD press cannot trigger sheet I/O.
            var run_sheets: Dictionary=rigs[row.rig].clips.Run.sheets
            for layer in Modular.layers(row,rigs[row.rig],catalog_cache):
                if run_sheets.has(layer.category):texture(resources[run_sheets[layer.category]])
    update_camera(true, exploration_mode)
    prune_texture_cache()

func index_map() -> void:
    support_cells = Walking.index(placements, stair_definition)
    stair_rows = placements.filter(func(row):return row.kind == "stairs")
    placement_buckets = [{},{},{},{}]
    rows_by_id.clear()
    map_min_height=0.0
    for row in placements:
        map_min_height=minf(map_min_height,row.base_height_steps)
        rows_by_id[row.id] = row
        if row.kind == "actor": continue
        var extent = placement_extent(row)
        for q in range(4):
            var p = Placement.project(v2(row.position),row.base_height_steps,q)
            var start = ((p-extent)/512.0).floor()
            var end = ((p+extent)/512.0).floor()
            for x in range(int(start.x),int(end.x)+1):
                for y in range(int(start.y),int(end.y)+1):
                    var key = Vector2i(x,y)
                    if not placement_buckets[q].has(key): placement_buckets[q][key] = []
                    placement_buckets[q][key].append(row)

func placement_extent(row: Dictionary) -> Vector2:
    if row.has("source_sprite"):
        if not catalog_cache.has("unity_sources"):
            catalog_cache.unity_sources = JSON.parse_string(FileAccess.get_file_as_string("res://generated/unity_sources.json"))
        return v2(catalog_cache.unity_sources[row.source_sprite].extent) * (2.0 if row.has("affine") else 1.0)
    var id: String = row.get("catalog_id", "")
    if id.is_empty():
        if row.kind in ["terrain","wall"]: id = row.kind + "/" + row.material
        elif row.kind in ["cliff","stairs"]: id = "world/" + row.kind
        else: id = row.get("asset", "")
    if catalog_by_id.has(id): return v2(catalog_by_id[id].extent)
    var record = Catalog.environment(row,0,catalog_cache)
    var pivot = v2(record.pivot)
    var size = v2(record.native_size)
    return Vector2(maxf(absf(pivot.x),absf(size.x-pivot.x)),maxf(absf(pivot.y),absf(size.y-pivot.y))) * record.scale

func view_rect() -> Rect2:
    var centre = Placement.project(Vector2(camera_focus.x,camera_focus.z),camera_focus.y / Placement.HEIGHT_UNIT,quarter)
    var size = get_viewport().get_visible_rect().size
    var extent = Vector2(size.x/size.y,1) * camera.size * Placement.PIXELS_PER_UNIT * 0.5
    return Rect2(centre-extent,extent*2)

func in_view(row: Dictionary) -> bool:
    if row.kind == "actor": return true
    var projected = Placement.project(v2(row.position), row.base_height_steps, quarter)
    var extent = placement_extent(row)
    return view_rect().intersects(Rect2(projected-extent,extent*2))

func activate_visible(incremental: bool = false) -> bool:
    var phase_started = Time.get_ticks_usec()
    var changed = false
    var visible_rect = view_rect()
    if exploration_mode:
        # Keep a small padded region resident. Following the character should
        # not rescan thousands of placements for every subpixel camera move.
        var start = (visible_rect.position/256.0).floor()*256.0
        var end = (visible_rect.end/256.0).ceil()*256.0
        visible_rect = Rect2(start,end-start)
    var signature = [quarter, visible_rect]
    if not incremental or signature != visible_signature:
        visible_signature = signature
        visible_queue.clear()
        visible_cursor = 0
        var wanted = {}
        var candidates = {}
        var start = (visible_rect.position/512.0).floor()
        var end = (visible_rect.end/512.0).floor()
        for x in range(int(start.x),int(end.x)+1):
            for y in range(int(start.y),int(end.y)+1):
                for row in placement_buckets[quarter].get(Vector2i(x,y),[]): candidates[row.id] = row
        for row in candidates.values():
            var projected = Placement.project(v2(row.position),row.base_height_steps,quarter)
            var extent = placement_extent(row)
            if not visible_rect.intersects(Rect2(projected-extent,extent*2)):continue
            wanted[row.id] = true
            if not loaded_rows.has(row.id): visible_queue.append(row)
        for row in actor_rows:
            wanted[row.id] = true
            if not loaded_rows.has(row.id): visible_queue.push_front(row)
        for i in range(entries.size()-1,-1,-1):
            var id: String = entries[i].placement.id
            if not wanted.has(id):
                entries[i].retired = true
                entries[i].node.queue_free()
                entries.remove_at(i)
                loaded_rows.erase(id)
                changed = true
    var started = Time.get_ticks_usec()
    while visible_cursor < visible_queue.size():
        var row: Dictionary = visible_queue[visible_cursor]
        loaded_rows[row.id] = row
        var first = entries.size()
        if row.kind == "actor": add_modular_entries(row)
        else: add_environment_entries(row)
        for i in range(first, entries.size()):
            initialize_entry(entries[i])
            if exploration_mode and entries[i].placement.kind != "actor":
                entries[i].pending_activation = entries[i].node.visible
                entries[i].node.visible = false
        visible_cursor += 1
        changed = true
        if incremental and Time.get_ticks_usec()-started > 4000: break
    pending_rows = visible_queue.size()-visible_cursor
    FrameProfile.end_phase(profile,"visibility",phase_started)
    return changed

func break_object(row: Dictionary) -> bool:
    if destruction.has(row.id) or row.kind == "actor": return false
    var duration = Catalog.break_duration(row,catalog_cache)
    if duration <= 0: return false
    var page_started = Time.get_ticks_usec()
    var pages = EnvironmentMedia.animation_pages(row,catalog_cache)
    if not pages.errors.is_empty():
        for error in pages.errors: push_error(error)
        return false
    # The legacy workshop loader is synchronous. Complete its finite numeric
    # page admission before requesting the animation; this cold cost is not a
    # live-player performance claim. Play retains its asynchronous media gate.
    for path in pages.paths:
        if texture(path)==null: return false
    var playback = Graphs.destruction(self, duration)
    playback.set_meta("numeric_pages",pages.paths)
    playback.set_meta("numeric_page_preparation_ms",(Time.get_ticks_usec()-page_started)/1000.0)
    texture_gc_dirty = true
    destruction[row.id] = playback
    Graphs.request(playback, "Breaking")
    if not gpu_grid.is_empty():
        GridRenderer.hide_placement(self,row.id,true)
        loaded_rows[row.id]=row
        var first=entries.size()
        add_environment_entries(row)
        for i in range(first,entries.size()):initialize_entry(entries[i])
    if row.has("parent_id") and rows_by_id.has(row.parent_id): rows_by_id[row.parent_id].attachment_absent = true
    for child in loaded_rows.values():
        if child.get("parent_id","") == row.id: update_environment(child)
    update_environment(row)
    return true

func update_environment(row: Dictionary, recompose: bool = true) -> void:
    if not gpu_grid.is_empty():
        for entry in entries:
            if entry.placement.id==row.id:set_environment(entry,Basis(Vector3.UP,quarter*PI*0.5))
        composition_dirty=true
        if recompose:compose()
        return
    var mobile = exploration_mode and row.has("break_owner")
    if exploration_mode and not mobile:
        TerrainBatches.clear(self)
        batches_dirty = true
    if not mobile:composition_cache.clear()
    texture_gc_dirty = true
    var rotation = Basis(Vector3.UP, quarter * PI * 0.5)
    for entry in entries:
        if entry.placement.id == row.id: set_environment(entry, rotation)
    composition_dirty = true
    if recompose and not view_pending: compose()

func reset_destruction() -> void:
    for playback in destruction.values(): playback.queue_free()
    destruction.clear()
    if not gpu_grid.is_empty():
        gpu_grid.state_image.fill(Color.BLACK)
        gpu_grid.state_texture.update(gpu_grid.state_image)
        for i in range(entries.size()-1,-1,-1):
            if entries[i].placement.kind!="actor":
                loaded_rows.erase(entries[i].placement.id)
                entries[i].node.queue_free();entries.remove_at(i)
    for row in placements:
        row.erase("attachment_absent")
        row.erase("preview_sequence")
    update_camera()

func update_camera(refresh_materials: bool = true, incremental: bool = false) -> void:
    var started = Time.get_ticks_usec()
    position_camera()
    if not gpu_grid.is_empty():
        if refresh_materials:
            for entry in entries:initialize_entry(entry)
            update_actor_frames()
            GridRenderer.camera_changed(self)
            update_highlight()
        view_pending=false;pending_rows=0
        view_update_ms=(Time.get_ticks_usec()-started)/1000.0
        FrameProfile.end_phase(profile,"camera_update",started)
        return
    if exploration_mode:incremental=true
    if refresh_materials and exploration_mode:
        composition_dirty = true
        TerrainBatches.clear(self)
        batches_dirty = true
        refresh_queue.clear()
        refresh_cursor = 0
        for entry in entries:
            if entry.placement.kind == "actor":initialize_entry(entry)
            else:
                entry.node.visible = false
                refresh_queue.append(entry)
    elif refresh_materials:
        for entry in entries: initialize_entry(entry)
    var changed = activate_visible(incremental)
    if changed and exploration_mode:
        batches_dirty = true
    var sources_refreshed = false
    if exploration_mode:
        var refresh_started = Time.get_ticks_usec()
        while refresh_cursor<refresh_queue.size():
            var entry: Dictionary=refresh_queue[refresh_cursor]
            refresh_cursor+=1
            if entry.get("retired",false):continue
            initialize_entry(entry)
            sources_refreshed = true
            entry.pending_activation=entry.node.visible
            entry.node.visible=false
            if Time.get_ticks_usec()-refresh_started>4000:break
        pending_rows+=refresh_queue.size()-refresh_cursor
        if refresh_cursor>=refresh_queue.size():refresh_queue.clear();refresh_cursor=0
    # Pan and zoom do not change source-space bounds, lighting transforms or
    # sprite samples. Only new/retired membership needs a new composition.
    update_actor_frames()
    if refresh_materials or changed or sources_refreshed:
        update_highlight()
    if refresh_materials or changed:
        composition_cache.clear()
        texture_gc_dirty = true
        if exploration_mode:
            composition_dirty = true
            ViewBuild.invalidate(self)
    if exploration_mode:
        if pending_rows==0 and (composition_dirty or not view_build.is_empty()):
            var publication_started=Time.get_ticks_usec()
            ViewBuild.step(self)
            FrameProfile.end_phase(profile,"view_publication",publication_started)
        view_pending=pending_rows>0 or not view_build.is_empty() or composition_dirty
    else:
        if refresh_materials or changed or composition_dirty:compose()
        view_pending=pending_rows>0
    view_update_ms = (Time.get_ticks_usec()-started)/1000.0
    FrameProfile.end_phase(profile,"camera_update",started)

func update_highlight() -> void:
    if not gpu_grid.is_empty():GridRenderer.highlight(self)
    for entry in entries:
        var row: Dictionary = entry.placement
        if row.kind == "actor": continue
        SourceMaterial.set_parameter(entry,"highlighted", Input.is_physical_key_pressed(KEY_ALT) and Catalog.break_duration(row,catalog_cache) > 0 and not destruction.has(row.id) and entry.source_role != 2)

func add_modular_entries(row: Dictionary) -> void:
    var rig: Dictionary = rigs[row.rig]
    var layers = Modular.layers(row, rig, catalog_cache)
    for i in range(layers.size()):
        var layer: Dictionary = layers[i]
        add_entry(row, "shadow" if layer.slot == "shadow" else "body", i, MODULAR_SHADER)
        var entry: Dictionary = entries.back()
        entry.actor_layer = layer
        SourceMaterial.set_parameter(entry,"layer_alpha", layer.alpha)
        SourceMaterial.set_parameter(entry,"shadow", layer.slot == "shadow")
        SourceMaterial.set_parameter(entry,"tint", Modular.rgb(layer.tint))

func update_actor_frames() -> void:
    var phase_started = Time.get_ticks_usec()
    var visibility_changed = false
    for entry in actor_entries:
        var row: Dictionary = entry.placement
        if row.kind != "actor": continue
        var rig: Dictionary = rigs[row.rig]
        var playback: Node = playbacks[row.id]
        var clip: Dictionary = rig.clips[playback.clip]
        var category: String = entry.actor_layer.category
        var visible_now = clip.sheets.has(category)
        visibility_changed = visibility_changed or entry.node.visible != visible_now
        entry.node.visible = visible_now
        if not entry.node.visible: continue
        var cycle: Array = rig_config.FACING_CYCLE
        var direction: String = cycle[posmod(cycle.find(row.facing) + quarter * cycle.size() / 4, cycle.size())]
        var frame = mini(int(playback.sample_seconds * clip.fps), int(clip.frames) - 1)
        var sheet = texture(resources[clip.sheets[category]])
        if entry.get("texture_path","") != resources[clip.sheets[category]]:texture_gc_dirty = true
        entry.texture_path = resources[clip.sheets[category]]
        var size = sheet.get_size()
        SourceMaterial.set_parameter(entry,"sheet", sheet,true)
        SourceMaterial.set_parameter(entry,"frame_uv", Vector4(frame * rig.cell_width / size.x,
            rig.facing_rows[direction] * rig.cell_height / size.y, rig.cell_width / size.x, rig.cell_height / size.y))
        CharacterGeometry.bind(entry,entry.texture_path,catalog_cache,texture,source_depth,source_normals)
        entry.node.position = Placement.contact(row)
        update_bounds(entry)
    if visibility_changed:
        composition_dirty = true
        if not exploration_mode:composition_cache.clear()
    FrameProfile.end_phase(profile,"actor_frames",phase_started)

func refresh_modular() -> void:
    actor_entries.clear()
    for i in range(entries.size() - 1, -1, -1):
        if entries[i].placement.kind == "actor":
            entries[i].node.queue_free()
            entries.remove_at(i)
    for row in actor_rows:
        row.equipment = equipment_choices.values().filter(func(item): return item != "")
        row.effects = effect_choices.duplicate()
        add_modular_entries(row)
    sync_character_controls()
    update_camera()

func sync_character_controls() -> void:
    for group in equipment_controls:
        var control: OptionButton = equipment_controls[group]
        control.select(0)
        equipment_choices[group] = ""
        for i in range(1,control.item_count):
            if control.get_item_text(i) in player.equipment:
                control.select(i)
                equipment_choices[group] = control.get_item_text(i)
                break
    effect_choices = player.effects.duplicate()
    for slot in effect_controls:
        var control: OptionButton = effect_controls[slot]
        control.select(0)
        for i in range(1,control.item_count):
            if control.get_item_text(i) == effect_choices.get(slot,""): control.select(i); break

func compose() -> void:
    var phase_started = Time.get_ticks_usec()
    composition_dirty = false
    if not gpu_grid.is_empty():
        GridRenderer.insert_dynamic(self)
        FrameProfile.end_phase(profile,"composition",phase_started)
        return
    var visible_entries: Array
    if exploration_mode and composition_cache.has("visible_entries"):
        visible_entries = composition_cache.visible_entries
    else:
        visible_entries = entries.filter(func(entry): return entry.node.visible or entry.get("batched",false) or (exploration_mode and entry.get("mobile",false)))
    var graph_started = Time.get_ticks_usec()
    var result = Placement.compose_exploration(visible_entries, quarter, composition_cache) if exploration_mode else Placement.compose(visible_entries, quarter, composition_cache)
    FrameProfile.end_phase(profile,"composition_order",graph_started)
    var apply_started = Time.get_ticks_usec()
    if exploration_mode: composition_cache.visible_entries = visible_entries
    if result.has("changed_start"):
        for rank in range(result.changed_start,result.changed_end):draw_order[rank]=visible_entries[result.order[rank]]
    else:
        draw_order = result.order.map(func(index): return visible_entries[index])
    unresolved = result.unresolved
    if not unresolved.is_empty():
        push_error("Composition cycle: " + str(unresolved))
    for rank in range(result.get("changed_start",0),result.get("changed_end",result.order.size())):
        # A renderer sort offset changes draw order only, never world placement
        # or lighting. Far-plane spacing dominates every visible node distance.
        var entry: Dictionary = visible_entries[result.order[rank]]
        if entry.get("draw_rank",-1) != rank:
            entry.node.sorting_offset = rank * camera.far
            entry.draw_rank = rank
    FrameProfile.end_phase(profile,"composition_apply",apply_started)
    update_status()
    FrameProfile.end_phase(profile,"composition",phase_started)

func supports_at(position: Vector2) -> Array:
    return Walking.supports_at(position, support_cells, stair_definition)

func select_support(row: Dictionary) -> void:
    player.support_id = row.id
    player.base_height_steps = row.base_height_steps

func _process(delta: float) -> void:
    FrameProfile.frame(profile,get_viewport(),{"scene":scenes[scene_index].id,"zoom":camera.size,"quarter":quarter,"focus":[camera_focus.x,camera_focus.y,camera_focus.z],"placements":placements.size(),"draws":draw_order.size(),"loaded":loaded_rows.size(),"renderer":"gpu_grid" if not gpu_grid.is_empty() else "workshop","resident_static_components":gpu_grid.manifest.views[quarter].count if not gpu_grid.is_empty() else 0,"resident_static_blocks":gpu_grid.manifest.views[quarter].blocks*4 if not gpu_grid.is_empty() else 0,"pending":pending_rows,"view_stage":view_build.get("phase","ready"),"background_sort_wall_ms":last_sort_job_ms,"textures":textures.size(),"actor_height":player.base_height_steps})
    var process_started = Time.get_ticks_usec()
    var now = Time.get_ticks_usec()
    if last_frame_usec > 0:
        frame_ms = (now-last_frame_usec)/1000.0
        worst_frame_ms = maxf(worst_frame_ms, frame_ms)
    last_frame_usec = now
    stats_elapsed += delta
    if stats_elapsed > 0.25:
        stats_elapsed = 0.0
        update_status()
        if not view_pending: prune_texture_cache(4)
        performance_label.text = ("  RECORDING PROFILE\n" if profile.recording else "")+"  %s FPS  ·  %.1f ms\n  Worst frame %.1f ms · view %.1f ms\n  %s draws · %s waiting to load  " % [Engine.get_frames_per_second(),frame_ms,worst_frame_ms,view_update_ms,draw_order.size(),pending_rows]
    if exploration_mode:
        performance_label.text = ("REC ●   " if profile.recording else "")+"%s FPS  ·  %.1f ms  ·  %s draw calls%s" % [Engine.get_frames_per_second(),frame_ms,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),("  ·  Loading "+str(pending_rows) if pending_rows>0 else "  ·  Preparing view") if view_pending else ""]
        if follow_player and not capturing:
            var focus = Placement.contact(player)
            if not camera_focus.is_equal_approx(focus):
                camera_focus = focus
                position_camera()
                view_pending = true
    if view_pending: update_camera(false, true)
    if capturing:
        FrameProfile.end_phase(profile,"process",process_started)
        return
    water_clock_seconds += delta
    for entry in water_materials:
        if is_instance_valid(entry.node): SourceMaterial.set_parameter(entry,"displayed_time_seconds",water_clock_seconds)
    water_materials = water_materials.filter(func(entry):return is_instance_valid(entry.node))
    var walking_started = Time.get_ticks_usec()
    var direction = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
        float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
    if get_viewport().gui_get_focus_owner() is LineEdit: direction = Vector2.ZERO
    if exploration_mode and not direction.is_zero_approx():
        direction = Placement.rotate_grid(Vector2(direction.x+direction.y,direction.y-direction.x),(4-quarter)%4).normalized()
    player_clip = "Idle" if direction.is_zero_approx() else "Run"
    var actor_playback: Node = playbacks[player.id]
    if actor_playback.clip in ["Idle", "Run"] or (not direction.is_zero_approx() and actor_playback.clip in ["Idle2","Idle4"]):
        Graphs.request(actor_playback, player_clip)
    if not direction.is_zero_approx():
        var p = v2(player.position) + direction.normalized() * delta * 1.4
        var support = Walking.destination(player,p,support_cells,stair_definition)
        if not support.is_empty():
            player.position = [p.x, p.y]
            select_support(support)
        var cycle: Array = rig_config.FACING_CYCLE
        player.facing = cycle[posmod(roundi((atan2(direction.y, direction.x) + PI / 4) / (TAU / cycle.size())) + cycle.find("E"), cycle.size())]
    FrameProfile.end_phase(profile,"walking",walking_started)
    var animation_started = Time.get_ticks_usec()
    var move = Vector3(float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
        float(Input.is_physical_key_pressed(KEY_PAGEUP)) - float(Input.is_physical_key_pressed(KEY_PAGEDOWN)),
        float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
    lamp.position += move * delta * 2
    for playback in playbacks.values(): Graphs.advance(playback, delta)
    for identity in destruction:
        var playback: Node = destruction[identity]
        if playback.phase == 2: continue
        Graphs.advance(playback, delta)
        var row: Dictionary = rows_by_id[identity]
        var record = record_for(row)
        var key = str(playback.phase) + ":" + str(record.get("frame", 0))
        if playback.get_meta("rendered", "") != key:
            update_environment(row, false)
            playback.set_meta("rendered", key)
    FrameProfile.end_phase(profile,"animation",animation_started)
    update_actor_frames()
    if (not direction.is_zero_approx() or composition_dirty) and (not exploration_mode or not view_pending):
        compose()
    if exploration_mode and gpu_grid.is_empty() and batches_dirty and not view_pending:
        TerrainBatches.rebuild(self)
        batches_dirty = false
    FrameProfile.end_phase(profile,"process",process_started)
    if profile.recording and profile.recorded.size()>=18000: toggle_profile()

func toggle_profile() -> void:
    if profile.recording:
        profile.recording = false
        editor_notice("Profile saved: "+FrameProfile.save(profile,get_viewport()))
    else:
        profile.recorded.clear()
        profile.recording = true
        editor_notice("Recording frame profile. F8 stops and saves JSON (up to18000 frames).")

func dump_profile() -> void:
    editor_notice("Frame dump: "+FrameProfile.save(profile,get_viewport(),"frame-dump",false))

func _input(event: InputEvent) -> void:
    var focus = get_viewport().gui_get_focus_owner()
    if focus == null: return
    if focus is LineEdit and event is InputEventKey and event.pressed and event.physical_keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
        focus.release_focus()
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE]:
        if not focus.get_global_rect().has_point(event.position): focus.release_focus()

func _unhandled_input(event: InputEvent) -> void:
    if exploration_mode and event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode == KEY_G:
            grid_visible = not grid_visible
            return
        if event.physical_keycode == KEY_SPACE:
            follow_player = not follow_player
            camera_focus = Placement.contact(player)
            position_camera()
            view_pending = true
            return
        if event.physical_keycode in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_H,KEY_DELETE]: return
    if event is InputEventKey and event.physical_keycode == KEY_ALT:
        update_highlight()
        return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.physical_keycode:
            KEY_F8: toggle_profile(); return
            KEY_F9: dump_profile(); return
            KEY_R: reset_destruction(); return
            KEY_4: load_scene(3); return
            KEY_DELETE: delete_selected(); return
            KEY_1: load_scene(0); return
            KEY_2: load_scene(1); return
            KEY_3: load_scene(2); return
            KEY_Q: quarter = posmod(quarter - 1, 4)
            KEY_E: quarter = posmod(quarter + 1, 4)
            KEY_B: source_depth = not source_depth
            KEY_N: source_normals = not source_normals
            KEY_L: lamp.visible = not lamp.visible
            KEY_F:
                var cycle: Array = rig_config.FACING_CYCLE
                player.facing = cycle[posmod(cycle.find(player.facing) + 1, cycle.size())]
            KEY_H:
                var supports = supports_at(v2(player.position))
                if not supports.is_empty():
                    var selected = 0
                    for i in range(supports.size()):
                        if supports[i].id == player.support_id:
                            selected = (i + 1) % supports.size()
                    select_support(supports[selected])
            _: return
        update_camera()
    if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
        follow_player = false
        var plane = Plane(Vector3.UP,camera_focus.y)
        var current = plane.intersects_ray(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
        var previous = plane.intersects_ray(camera.project_ray_origin(event.position-event.relative),camera.project_ray_normal(event.position-event.relative))
        if current != null and previous != null:
            camera_focus += previous-current
            position_camera()
            view_pending = true
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT and not preview_mode and editor_tool in ["place","move"]:
            if editor_tool == "place": place_at(event.position)
            else: move_selected(event.position)
            return
        if event.button_index == MOUSE_BUTTON_LEFT and (not exploration_mode or not view_pending):
            var hit = pick_object(event.position)
            if not hit.is_empty():
                selected_id = hit.id
                if preview_mode:
                    if not break_object(hit): editor_notice("No authored destruction selected for " + hit.id)
                else:
                    if hit.has("assembly_id"): hit = rows_by_id[hit.assembly_id]; selected_id = hit.id
                    palette_id = hit.get("catalog_id", "")
                    configure_source_choices(hit)
                    height_control.value = hit.base_height_steps
                    orientation_control.select(["east","north","west","south"].find(hit.get("orientation","east")))
                    editor_notice(hit.get("catalog_id",hit.id) + "\n" + str(hit.position) + " at height " + str(hit.base_height_steps))
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera.size = maxf(4.0, camera.size * 0.9)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera.size = minf(50.0, camera.size / 0.9)
        if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
            view_pending = true

func pick_object(screen: Vector2) -> Dictionary:
    if not gpu_grid.is_empty():return GridRenderer.pick(self,screen)
    var size = get_viewport().get_visible_rect().size
    for i in range(draw_order.size() - 1, -1, -1):
        var entry: Dictionary = draw_order[i]
        if entry.get("ground_overlay",false): continue
        if not entry.node.visible and not entry.get("batched",false):continue
        if entry.placement.kind == "actor" or entry.role == "shadow": continue
        var contact = camera.unproject_position(entry.node.position)
        var scale: float = size.y / camera.size / Placement.PIXELS_PER_UNIT * entry.scale
        var uv = (screen - contact) / scale + entry.pivot
        if uv.x < 0 or uv.y < 0 or uv.x >= entry.cell.x or uv.y >= entry.cell.y: continue
        var record: Dictionary = entry.record
        var rect: Array = record.get("rect", [0,0,entry.cell.x,entry.cell.y])
        var pixel = Vector2i(int(rect[0] + uv.x), int(rect[1] + uv.y))
        var colour: Color = source_images[record.path].get_pixelv(pixel)
        if colour.a <= 0.05: continue
        if entry.source_role == 2: return {} if preview_mode else entry.placement
        if record.has("hit_mask"):
            var mask: Dictionary = record.hit_mask
            var p = Vector2i(int(mask.rect[0]+uv.x),int(mask.rect[1]+uv.y))
            if source_images[mask.path].get_pixelv(p).r < 0.5: continue
        var shadow = false
        for role in record.get("roles",[]):
            if role.role == "ground_shadow" and pixel_selected(role.selection,uv,colour): shadow = true; break
        if not shadow: return entry.placement
    return {}

func build_controls() -> void:
    var canvas = CanvasLayer.new()
    add_child(canvas)
    var panel = PanelContainer.new()
    panel.position = Vector2(16, 16)
    canvas.add_child(panel)
    var column = VBoxContainer.new()
    panel.add_child(column)
    var title = Label.new()
    title.text = "  MODULAR CHARACTERS · ENVIRONMENT WORKSHOP  "
    title.add_theme_font_size_override("font_size", 22)
    column.add_child(title)
    var controls = Label.new()
    controls.text = "  1–3 placement checks · 4 catalog · Q/E camera · WASD character · H support height\n  Middle-drag pan · Wheel zoom · Click break · Alt highlight · R restore\n  Arrows/PgUp/PgDn move light · B lighting depth · N normals · L light  "
    column.add_child(controls)
    var appearance_controls = HBoxContainer.new()
    column.add_child(appearance_controls)
    var inventory = Catalog.read_file("items/visuals.json",catalog_cache).categories
    for group in equipment_choices:
        var choice = OptionButton.new()
        choice.custom_minimum_size.x = 135
        choice.add_item("No "+group.replace("_"," "))
        var names: Array[String] = [""]
        for item in inventory:
            var slot: String = item.equipment_slot
            if (group=="weapon" and slot in ["weapon_melee_main","weapon_ranged_main"]) or (group=="offhand" and slot=="weapon_melee_off") or slot==group:
                choice.add_item(item.base_category)
                names.append(item.base_category)
        choice.select(names.find(equipment_choices[group]))
        choice.item_selected.connect(func(index): equipment_choices[group]=names[index]; refresh_modular())
        appearance_controls.add_child(choice)
        equipment_controls[group] = choice
    var animation_controls = HBoxContainer.new()
    column.add_child(animation_controls)
    actor_action = OptionButton.new()
    for clip in rigs["neuroclient.modular"].clips: actor_action.add_item(clip)
    actor_action.select(rigs["neuroclient.modular"].clips.keys().find("Idle"))
    actor_action.item_selected.connect(func(index): Graphs.request(playbacks[player.id], actor_action.get_item_text(index)))
    animation_controls.add_child(actor_action)
    Editor.button(animation_controls,"Play action",func(): Graphs.request(playbacks[player.id],actor_action.get_item_text(actor_action.selected)))
    Editor.button(animation_controls,"Face ↻",func():
        var cycle: Array = rig_config.FACING_CYCLE
        player.facing=cycle[posmod(cycle.find(player.facing)+1,cycle.size())]
        update_actor_frames())
    for slot in ["effect","effect2","effect3"]:
        var effect = OptionButton.new()
        effect.add_item("No "+slot)
        var names: Array[String] = [""]
        var categories = {}
        for clip in rigs["neuroclient.modular"].clips.values():
            for category in clip.sheets:
                if category.begins_with("Effect") or category.begins_with("Magic"): categories[category] = true
        for category in categories: effect.add_item(category); names.append(category)
        effect.item_selected.connect(func(index):
            if index==0: effect_choices.erase(slot)
            else: effect_choices[slot]=names[index]
            refresh_modular())
        animation_controls.add_child(effect)
        effect_controls[slot] = effect
    status = Label.new()
    column.add_child(status)
    var performance_panel = PanelContainer.new()
    performance_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    performance_panel.position = Vector2(16, -145)
    performance_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(performance_panel)
    performance_label = Label.new()
    performance_label.add_theme_font_size_override("font_size", 22)
    performance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var performance_column = VBoxContainer.new()
    performance_panel.add_child(performance_column)
    performance_column.add_child(performance_label)
    var profile_controls = HBoxContainer.new()
    performance_column.add_child(profile_controls)
    Editor.button(profile_controls,"F8 Record / stop",toggle_profile)
    Editor.button(profile_controls,"F9 Dump frames",dump_profile)

func update_status() -> void:
    if status:
        status.text = "  %s · view %s · actor height %s · depth %s · normals %s%s  " % [scenes[scene_index].name,
            Placement.POSES[quarter].to_upper(), player.base_height_steps, "ON" if source_depth else "OFF",
            "ON" if source_normals else "OFF", " · COMPOSITION CYCLE" if not unresolved.is_empty() else ""]
        status.text += " · " + playbacks[player.id].clip
        status.text += "\n  %s placements · %s visible draws · %s FPS · %s textures" % [placements.size(), draw_order.size(), Engine.get_frames_per_second(), textures.size()]

func save_capture(name: String) -> void:
    update_status()
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png("res://.captures/" + name + ".png")
    print("CAPTURE ", name)

func capture_views() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures"))
    for scene in range(3):
        load_scene(scene)
        for q in range(4):
            quarter = q
            update_camera()
            await save_capture(scenes[scene].id + "-q" + str(q))
    load_scene(0)
    for q in range(4):
        quarter = q
        for side in [0.1, 0.9]:
            player.position = [side, 0]
            update_camera()
            await save_capture("boundary-q%s-x%s" % [q, side])
    load_scene(0)
    quarter = 0
    source_depth = false
    update_camera()
    await save_capture("composition-depth-off")
    source_depth = true
    source_normals = false
    update_camera()
    await save_capture("composition-normals-off")
    source_normals = true
    lamp.visible = false
    update_camera()
    await save_capture("composition-light-off")
    print("SCENE_CAPTURE_COMPLETE")
    get_tree().quit()

func editor_notice(message: String) -> void:
    if editor_info: editor_info.text = message
    if exploration_mode: exploration_ui.notice.text = message

func locate_palette() -> void:
    for row in placements:
        if row.get("catalog_id", "") == palette_id:
            camera_focus = Placement.contact(row)
            lamp.position = camera_focus + Vector3(-1.4,2.8,1.2)
            update_camera()
            selected_id = row.id
            configure_source_choices(row)
            editor_notice(catalog_by_id[palette_id].label+"\n"+catalog_by_id[palette_id].get("reason",""))
            return
    editor_notice("This palette asset has no placement in the current map.")

func bring_character() -> void:
    var position = Vector2(roundf(camera_focus.x)-1,roundf(camera_focus.z)+1)
    var supports = supports_at(position)
    if supports.is_empty(): return
    player.position = [position.x,position.y]
    select_support(supports.back())
    update_camera()

func place_at(screen: Vector2) -> void:
    if not catalog_by_id.has(palette_id): editor_notice("Choose a palette asset first."); return
    var entry: Dictionary = catalog_by_id[palette_id]
    if not entry.placeable: editor_notice(entry.reason); return
    var height = height_control.value
    var plane = Plane(Vector3.UP,height * Placement.HEIGHT_UNIT)
    var hit = plane.intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
    if hit == null: return
    map_serial += 1
    var row = MapData.placement(entry,"placed_"+str(Time.get_ticks_usec())+"_"+str(map_serial),Vector2(roundf(hit.x),roundf(hit.z)),height,orientation_control.get_item_text(orientation_control.selected))
    undo_history.append({"before":null,"after":row.duplicate(true)})
    apply_choice_to(row)
    placements.append_array(MapData.assembly(row,catalog_by_id))
    selected_id = row.id
    index_map()
    update_camera()

func remove_placement(identity: String) -> void:
    var removed = {identity:true}
    for i in range(placements.size()-1,-1,-1):
        if placements[i].id == identity or placements[i].get("assembly_id","") == identity:
            removed[placements[i].id] = true
            placements.remove_at(i)
    for id in removed:
        loaded_rows.erase(id)
        if destruction.has(id): destruction[id].queue_free(); destruction.erase(id)
    for i in range(entries.size()-1,-1,-1):
        if removed.has(entries[i].placement.id):
            entries[i].node.queue_free(); entries.remove_at(i)
    index_map()

func delete_selected() -> void:
    for row in placements:
        if row.id == selected_id and row.kind != "actor":
            undo_history.append({"before":row.duplicate(true),"after":null})
            remove_placement(row.id)
            update_camera()
            return

func transform_selected() -> void:
    if not rows_by_id.has(selected_id): return
    var row: Dictionary = rows_by_id[selected_id].duplicate(true)
    if row.kind == "actor": return
    var before = row.duplicate(true)
    row.base_height_steps = height_control.value
    var old_turn = ["east","north","west","south"].find(row.get("orientation","east"))
    row.orientation = orientation_control.get_item_text(orientation_control.selected)
    if row.has("boundaries"):
        var directions = ["east","north","west","south"]
        row.boundaries = row.boundaries.map(func(face): return directions[posmod(directions.find(face)+orientation_control.selected-old_turn,4)])
    apply_choice_to(row)
    replace_edit(before,row)

func configure_source_choices(row: Dictionary) -> void:
    source_choice.clear()
    var entry: Dictionary = catalog_by_id.get(palette_id,{})
    if entry.is_empty(): return
    if entry.kind == "library" and entry.placeable:
        var options = Catalog.sequences(row,catalog_cache)
        for i in range(options.size()):
            source_choice.add_item(str(i)+" · "+options[i].label.left(58))
            source_choice.set_item_metadata(i,{"sequence":i})
        source_choice.select(int(row.get("sequence",0)))
    else:
        for state in entry.get("states",["default"]):
            for outcome in entry.get("outcomes",[""]):
                var i = source_choice.item_count
                source_choice.add_item(state+ (" / "+outcome if not outcome.is_empty() else ""))
                source_choice.set_item_metadata(i,{"state":state,"outcome":outcome})
                if state==row.get("state","default") and outcome==row.get("outcome",entry.get("outcomes",[""])[0]): source_choice.select(i)
    update_frame_range()
    frame_control.value = row.get("frame",0)

func update_frame_range() -> void:
    frame_control.max_value = 0
    if not catalog_by_id.has(palette_id) or source_choice.selected<0: return
    var entry: Dictionary = catalog_by_id[palette_id]
    if entry.kind == "library" and entry.placeable:
        var sequence: Dictionary = Catalog.sequences(entry,catalog_cache)[source_choice.selected]
        for indices in sequence.views.values(): frame_control.max_value = maxf(frame_control.max_value,indices.size()-1)
        source_choice.tooltip_text = sequence.label

func apply_choice_to(row: Dictionary) -> void:
    if source_choice.selected<0: return
    if row.get("catalog_id","") != palette_id: return
    row.merge(source_choice.get_item_metadata(source_choice.selected),true)
    if row.kind == "library": row.frame = int(frame_control.value)

func preview_selected_sequence() -> void:
    if not rows_by_id.has(selected_id): editor_notice("Select a placed asset to preview its source sequence."); return
    transform_selected()
    var row: Dictionary = rows_by_id[selected_id]
    if row.kind == "library": row.preview_sequence = true
    if not break_object(row): editor_notice("This source sequence has no authored animation clock. Use Source frame to inspect it.")

func replace_edit(before: Dictionary, after: Dictionary) -> void:
    undo_history.append({"before":before,"after":after.duplicate(true)})
    remove_placement(before.id)
    placements.append_array(MapData.assembly(after,catalog_by_id))
    index_map()
    update_camera()

func move_selected(screen: Vector2) -> void:
    if not rows_by_id.has(selected_id): editor_notice("Select an object before moving it."); return
    var before: Dictionary = rows_by_id[selected_id].duplicate(true)
    var plane = Plane(Vector3.UP,before.base_height_steps*Placement.HEIGHT_UNIT)
    var hit = plane.intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
    if hit==null: return
    var after = before.duplicate(true)
    after.position = [roundf(hit.x),roundf(hit.z)]
    replace_edit(before,after)

func undo_edit() -> void:
    if undo_history.is_empty(): return
    var edit: Dictionary = undo_history.pop_back()
    if edit.after != null: remove_placement(edit.after.id)
    elif edit.before != null: remove_placement(edit.before.id)
    if edit.before != null: placements.append_array(MapData.assembly(edit.before,catalog_by_id))
    index_map()
    update_camera()

func save_map() -> void:
    var file = FileAccess.open("user://workshop-map.json",FileAccess.WRITE)
    var saved_rows = placements.duplicate(true)
    for row in saved_rows:
        row.erase("attachment_absent")
        row.erase("preview_sequence")
    file.store_string(JSON.stringify({"name":"Saved workshop","placements":saved_rows,"camera_size":camera.size},"  "))
    editor_notice("Saved map: " + ProjectSettings.globalize_path("user://workshop-map.json"))

func load_map() -> void:
    if not FileAccess.file_exists("user://workshop-map.json"): editor_notice("No saved workshop map yet."); return
    var saved = JSON.parse_string(FileAccess.get_file_as_string("user://workshop-map.json"))
    saved.id = "saved"
    scenes[3] = saved
    load_scene(3)
    undo_history.clear()
    editor_notice("Loaded saved map. Destruction preview is reset.")

func resize_catalog(copies: int) -> void:
    scenes[3] = MapData.catalog_map(asset_catalog,copies)
    load_scene(3)
    editor_notice("Catalog map: " + str(scenes[3].asset_count) + " asset placements. Middle-drag to explore; use Locate asset.")

func capture_workshop() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures"))
    await save_capture("workshop-start")
    print("WORKSHOP ",placements.size()," placements; ",draw_order.size()," draws; ",textures.size()," textures")
    for id in ["environment.blocker.crate","environment.storage_chest","environment.door.fantasy_a1","environment.window.fantasy_g8.wall"]:
        palette_id = id
        locate_palette()
        bring_character()
        await save_capture(id.replace(".","-")+"-intact")
        for row in placements:
            if row.get("catalog_id","") != id: continue
            if break_object(row):
                var playback: Node = destruction[row.id]
                Graphs.advance(playback,0.5)
                update_environment(row)
                await save_capture(id.replace(".","-")+"-breaking")
                quarter = 1
                update_camera()
                await save_capture(id.replace(".","-")+"-breaking-rotated")
                Graphs.advance(playback,10.0)
                Graphs.advance(playback,0.0)
                update_environment(row)
                await save_capture(id.replace(".","-")+"-settled")
            break
    print("WORKSHOP_CAPTURE_COMPLETE")
    get_tree().quit()

func _exit_tree() -> void:
    if view_thread != null:
        view_thread.wait_to_finish()
        view_thread = null
