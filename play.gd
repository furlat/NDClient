extends "res://main.gd"
# Godot scene specialization: reuse the tested sprite/material helpers. This
# scene owns no offline movement, editor handlers, collision or game rules.
const Session = preload("res://presentation/session.gd")
const Timeline = preload("res://presentation/timeline.gd")
const Characters = preload("res://presentation/characters.gd")
const WorldRows = preload("res://presentation/world.gd")
const PlayerHUD = preload("res://play_hud.gd")
const Interaction = preload("res://presentation/interaction.gd")
const Lighting = preload("res://presentation/lighting_2d.gd")
const NativeLightAtlas = preload("res://presentation/native_light_atlas.gd")
const GeneratedShadows = preload("res://presentation/canvas_shadows.gd")
var native_light_atlas = NativeLightAtlas.new()
var generated_shadows = GeneratedShadows.new()
var generated_shadow_ids: Array = []
const RenderSettings = preload("res://presentation/render_settings.gd")
var character_light_profile = RenderSettings.DEFAULT_PROFILE
var fire_light_flicker = RenderSettings.DEFAULT_FIRE_LIGHT_FLICKER
var light_strength = RenderSettings.DEFAULT_LIGHT_STRENGTH
const PLAYER_ENVIRONMENT = preload("res://presentation/player_environment.tres")
const MediaWarmup = preload("res://presentation/media_warmup.gd")
const WallReveal = preload("res://presentation/wall_reveal.gd")
const WALL_COVERAGE_SHADER = preload("res://presentation/wall_coverage.gdshader")
const QuarterView = preload("res://presentation/quarter_view.gd")
const WorldPreparation = preload("res://presentation/world_preparation.gd")
var pending_world: Variant
var world_prepare_epoch = -1
var world_prepared_count = 0
var world_prepare_worker_ms = 0.0
var world_generation = 0
var world_visual_rows: Array = []
var world_row_cache: Dictionary = {}
var world_changes: Dictionary = {}
var sampled_supports: Dictionary = {}
var scenery_new_consumers: Dictionary = {}
var scenery_wall_sources: Dictionary = {}
var scenery_batches: Array = []
var scenery_consumers: Dictionary = {}
var scenery_visible_cells: Dictionary = {}
var wall_sources: Array = []
var wall_entries: Array = []
var scenery_index_dirty := true
var scenery_index_count := -1
var scenery_generation := -1
var requested_quarter = -1
var pending_view: Variant
var rotation_publication_frame = -1
signal presentation_updated
var session = Session.new()
var timeline = Timeline.new()
var hud: Control
var game_config: Dictionary = {}
var visual_actors: Dictionary = {}
var actor_facings: Dictionary = {}
var animation_templates: Array = []
var actor_revision = -1
var actor_group = ""
var sampled_loadouts: Dictionary = {}
var sampled_staged_ids: Array = []
var sampled_support_ids: Array = []
var world_revision = -1
var world_quarter = -1
var world_groups: Dictionary = {}
var ground_groups: Dictionary = {}
var static_views: Dictionary = {}
var retiring_views: Array = []
var retirement_frame = -1
var retiring_node_count = 0
var static_order: Array = []
var static_complete_order: Array = []
var static_sort_nodes: Dictionary = {}
var static_order_dirty = true
var static_order_count = -1
var initial_focus = false
var selected_mode = "action.move"
var action_request = -1
var pending_request: Dictionary = {}
var available_actions: Dictionary = {}
var action_revision = ""
var notice_text = "Connecting…"
var command_busy = false
var preview_selection: Dictionary = {}
var displayed_samples: Dictionary = {}
var preview_positions: Array = []
var receipt_due = 0
var selected_action: Dictionary = {}
var target_selection: Dictionary = {}
var selection_preview: Dictionary = {}
var selection_serial = 0
var force_attack = false
var choices_force_attack = false
var attack_preference = "MELEE_MAIN"
var attack_preferences: Dictionary = {}
var pending_approach: Dictionary = {}
var loot_object_uuid = ""
var loot_actor_uuid = ""
var pending_loot_open: Dictionary = {}
var frame_evidence: Array = []
var await_command_cursor = -1
var context_menu = PopupMenu.new()
var context_options: Array = []
var hover_hit: Dictionary = {}
var hover_preview: Dictionary = {}
var hover_request = -1
var hover_context: Dictionary = {}
var hover_key: Array = []
var hover_due = 0
var normals_visible = false
var source_lighting = Lighting.new()
var light_revision = -1
var wall_visibility_revision = -1
var scenery_revision := -1
var scenery_world_revision := -1
var scenery_quarter := -1
var scenery_visibility: Dictionary = {}
var water_entries: Array = []
var water_display_seconds := -1.0
var wall_visible_cells: Array = []
var faded_walls: Array = []
const WALL_MODES = ["solid","translucent","hidden"]
var wall_mode = "solid"
var announced_ready = false
var reported_session_issue = ""
var wall_mask_viewport: SubViewport
var wall_mask_nodes: Array[ColorRect] = []
var wall_mask_sources: Array = []
var wall_mask_dirty = true
var wall_mask_view: Array = []
var fixture_energy: Dictionary = {}
var fixture_heights: Dictionary = {}
var fixture_shadow_heights: Dictionary = {}
var media_warmup = MediaWarmup.create()
var media_plan: Dictionary = {"required":{},"upcoming":{},"errors":[],"upcoming_errors":[]}
var media_plan_key: Array = []
var media_initial_ready = false
var media_metadata_ready = false
var media_metadata_ms = 0.0
var media_group_plans: Dictionary = {}
var media_empty_key: Array = []
var media_empty_plan: Dictionary = {}
var media_requested_key: Array = []
var media_plan_epoch = -1
var media_environment_required: Dictionary = {}
var draw_order_dirty = true
var wall_pick_order: Array = []
var wall_support_candidates = 0
var wall_max_member_candidates = 0
var wall_geometry_views: Dictionary = {}
var ground_is_background := true
var pick_heights_revision = -1
var pick_heights: Array = []

func _ready() -> void:
    var settings = RenderSettings.read()
    character_light_profile = settings.profile
    fire_light_flicker = settings.fire_light_flicker
    source_lighting.fire_light_flicker = fire_light_flicker
    light_strength = settings.light_strength
    source_lighting.light_strength = light_strength
    if settings.error != OK: presentation_errors.append("Cannot read local rendering settings: "+error_string(settings.error))
    native_light_atlas.attach(self)
    source_lighting.attach(native_light_atlas.viewport)
    generated_shadows.attach(self)
    timeline.media_ready = _media_ready
    timeline.world_ready = _world_ready
    timeline.retire_group = session.retire_group
    RenderingServer.frame_post_draw.connect(_record_frame_evidence)
    DisplayServer.window_set_title("NDClient · Live player · Wall composition & frame profiling")
    RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
    var catalog = Catalog.read_file("catalog-index.json",catalog_cache)
    rig_config = Catalog.read_file(catalog.rig,catalog_cache)
    rigs = Catalog.read_file(catalog.rigs,catalog_cache)
    resources = Catalog.read_file(catalog.resources,catalog_cache)
    scenes = [{"id":"player"}]
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 12
    camera.near = 0.1
    camera.far = 300
    add_child(camera)
    add_child(context_menu)
    context_menu.id_pressed.connect(_context_chosen)
    camera.current = true
    position_camera()
    var environment = WorldEnvironment.new()
    # Native indirect/readability layer, independent of disclosed direct sources.
    # Retained terrain/objects are last-known data; ambient is not a FOW mask.
    environment.environment = PLAYER_ENVIRONMENT.duplicate()
    add_child(environment)
    source_lighting.set_directionals(Catalog.read_file("world.json",catalog_cache).lighting)
    presentation_errors.append_array(source_lighting.issues)
    hud = PlayerHUD.new()
    hud.world = self
    var canvas = CanvasLayer.new()
    add_child(canvas)
    canvas.add_child(hud)
    grid_visible = true
    var args = OS.get_cmdline_user_args()
    for i in range(args.size()-1):
        if args[i] == "--config": game_config = JSON.parse_string(FileAccess.get_file_as_string(args[i+1]))
        if args[i] == "--recording":
            var replay = session.open_recording(args[i+1])
            notice_text = "Playing recorded subjective events." if replay.ok else str(replay.error)
            return
    if game_config.is_empty():
        notice_text = "Start a live encounter with play.cmd; it starts the server and connects this player."
        return
    var opened = session.start(game_config)
    if not opened.ok: notice_text = str(opened.error)

func set_character_light_profile(profile_name: String) -> bool:
    if not RenderSettings.PROFILES.has(profile_name): return false
    character_light_profile = profile_name
    var error = RenderSettings.write(profile_name)
    if error != OK: notice_text = "Setting applied; cannot save it: "+error_string(error)
    return true

func set_fire_light_flicker(enabled: bool) -> void:
    fire_light_flicker = enabled
    source_lighting.fire_light_flicker = enabled
    var error = RenderSettings.write_fire_light_flicker(enabled)
    if error != OK: notice_text = "Setting applied; cannot save it: "+error_string(error)

func set_light_strength(value: float, persist: bool = true) -> void:
    if not is_finite(value): return
    light_strength = clampf(value,0.0,RenderSettings.MAX_LIGHT_STRENGTH)
    source_lighting.light_strength = light_strength
    if persist:
        var error = RenderSettings.write_light_strength(light_strength)
        if error != OK: notice_text = "Setting applied; cannot save it: "+error_string(error)

func _process(delta: float) -> void:
    var started = Time.get_ticks_usec()
    var phase = Time.get_ticks_usec()
    var subphase = Time.get_ticks_usec()
    _warm_media()
    _prune_character_media()
    FrameProfile.end_phase(profile,"media_publication",subphase)
    subphase = Time.get_ticks_usec()
    session.poll()
    FrameProfile.end_phase(profile,"session_poll",subphase)
    subphase = Time.get_ticks_usec()
    for message in session.take_prepared():
        timeline.accept(message)
    _prepare_media()
    _prepare_initial_world()
    _prepare_future_world()
    _step_world_preparation()
    FrameProfile.end_phase(profile,"preparation_step",subphase)
    subphase = Time.get_ticks_usec()
    _poll_actions()
    FrameProfile.end_phase(profile,"action_responses",subphase)
    subphase = Time.get_ticks_usec()
    timeline.advance(delta*1000)
    FrameProfile.end_phase(profile,"timeline_advance",subphase)
    session.set_displayed_sequence(timeline.sequence)
    FrameProfile.end_phase(profile,"session_timeline",phase)
    if not timeline.state.is_empty() and world_prepare_epoch==timeline.initialization_revision and (world_revision>=0 or (pending_world!=null and pending_world.epoch==timeline.initialization_revision and pending_world.initial and pending_world.prepared)):
        if light_revision != timeline.revision:
            phase = Time.get_ticks_usec()
            source_lighting.sync(timeline.presentation_state())
            light_revision = timeline.revision
            FrameProfile.end_phase(profile,"source_lighting_resolve",phase)
        var supports = timeline.staged_tiles().keys()
        if _environment_sources_ready() and _world_can_publish() and (timeline.world_revision != world_revision or sampled_support_ids != supports):
            phase = Time.get_ticks_usec()
            _sync_world()
            FrameProfile.end_phase(profile,"world_sync",phase)
            world_revision = timeline.world_revision
            sampled_support_ids = supports
        displayed_samples = timeline.actor_samples()
        phase = Time.get_ticks_usec()
        _sync_actors()
        FrameProfile.end_phase(profile,"actor_sync",phase)
        phase = Time.get_ticks_usec()
        _sample_actors()
        FrameProfile.end_phase(profile,"actor_sample",phase)
        phase = Time.get_ticks_usec()
        var scenery_started = Time.get_ticks_usec()
        _sync_scenery()
        FrameProfile.end_phase(profile,"scenery_sync",scenery_started)
        _sample_fixtures()
        var light_anchors = {}
        for row in actor_rows: light_anchors[row.id] = row
        source_lighting.sample(light_anchors,fixture_energy,fixture_heights,fixture_shadow_heights)
        FrameProfile.end_phase(profile,"source_lighting",phase)
        if not initial_focus and not actor_rows.is_empty():
            camera_focus = Placement.contact(actor_rows[0])
            position_camera()
            initial_focus = true
        if wall_visibility_revision != timeline.revision:
            var senses: Variant = timeline.state.get("senses")
            var visible_cells: Array = senses.get("visible",[]) if senses != null else []
            if wall_visibility_revision < 0 or visible_cells != wall_visible_cells:
                update_wall_visibility(false)
            wall_visibility_revision = timeline.revision
        _prepare_rotation()
        phase = Time.get_ticks_usec()
        _sync_native_lighting()
        FrameProfile.end_phase(profile,"native_2d_lighting",phase)
        # Wall member selection precedes the final painter order and coverage mask.
        phase = Time.get_ticks_usec()
        _sort_draws()
        native_light_atlas.sync_output(self,[world_generation,quarter,scenery_revision,wall_mode,native_light_atlas.revision])
        FrameProfile.end_phase(profile,"draw_order",phase)
        phase = Time.get_ticks_usec()
        _discover()
        _poll_storage()
        _update_hover()
        _capture_frame_evidence()
        FrameProfile.end_phase(profile,"interaction",phase)
        if not announced_ready and command_ready():
            announced_ready = true
            print("PLAYER_READY: initialized, acknowledged, and current choices available")
    if not media_issue.is_empty():
        var preparing: Dictionary = timeline.current if not timeline.current.is_empty() else (timeline.queue[0] if not timeline.queue.is_empty() else {})
        if not preparing.is_empty(): timeline.record_preparation_issue(preparing.id,media_issue)
    if media_metadata_ready and not MediaWarmup.boot_ready(media_warmup):
        var progress = MediaWarmup.preload_progress(media_warmup)
        notice_text = "Preparing visible assets: %d / %d" % [progress.startup_ready,progress.startup_required]
    elif notice_text.begins_with("Preparing visible assets:"): notice_text = ""
    if not session.issue.is_empty(): notice_text = session.issue.message
    elif not media_issue.is_empty(): notice_text = media_issue
    elif not session.status_issue.is_empty(): notice_text = "Reconnecting to encounter status…"
    if not session.issue.is_empty() and str(session.issue) != reported_session_issue:
        reported_session_issue = str(session.issue)
        push_error("PLAYER_CONNECTION_FAILED: " + session.issue.message)
    FrameProfile.end_phase(profile,"player_process",started)
    FrameProfile.frame(profile,get_viewport(),{"scene":"live_player","zoom":camera.size,"quarter":quarter,
        "native_2d_repack_count":native_light_atlas.repack_count,"native_2d_receivers":native_light_atlas.live_receivers,"native_2d_atlas_pixels":native_light_atlas.packed_pixels,"generated_shadows":generated_shadows.diagnostics(),
        "native_2d_reconcile_ms":native_light_atlas.last_reconcile_ms,"native_2d_projection_ms":native_light_atlas.last_projection_ms,"native_2d_pack_ms":native_light_atlas.last_pack_ms,
        "native_2d_reconcile_phases":native_light_atlas.last_reconcile_phases,
        "native_2d_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(native_light_atlas.viewport.get_viewport_rid()),
        "rotation_pending":rotation_pending(),"requested_quarter":requested_quarter,"cached_quarters":static_views.size(),"retiring_views":retiring_views.size(),"retiring_nodes":retiring_node_count,"world_generation":world_generation,"world_preparing":pending_world!=null,"world_prepare_phase":pending_world.phase if pending_world!=null else "idle","world_prepared_count":world_prepared_count,"world_prepare_worker_ms":world_prepare_worker_ms,"world_waiting":timeline.waiting_for_world,"session_execution":session.diagnostics(),"displayed_sequence":timeline.sequence,"consumed_sequence":session.latest_sequence,"queued_groups":timeline.queue.size(),
        "profile_stage":profile.label,"wall_mode":wall_mode,"wall_support_candidates":wall_support_candidates,"wall_max_member_candidates":wall_max_member_candidates,
        "wall_mask_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(wall_mask_viewport.get_viewport_rid()) if wall_mask_viewport!=null and wall_mode=="translucent" else 0.0,
        "wall_mask_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(wall_mask_viewport.get_viewport_rid()) if wall_mask_viewport!=null and wall_mode=="translucent" else 0.0,"textures":textures.size(),"media_pending":media_warmup.pending.size(),"encounter_preload":MediaWarmup.preload_progress(media_warmup),"preload_ready":media_warmup.boot_complete,"character_media":MediaWarmup.diagnostics(media_warmup),"environment_media":MediaWarmup.diagnostics(media_warmup,true),"media_metadata_ms":media_metadata_ms,"media_metadata_pending":media_warmup.plan_task>=0,"media_waiting":timeline.waiting_for_media,"actors":actor_rows.size(),"placements":placements.size(),"draws":static_entries.size()+actor_entries.size()})
    hud.queue_redraw()
    presentation_updated.emit()

func _prepare_initial_world() -> void:
    if timeline.state.is_empty(): return
    if world_prepare_epoch!=timeline.initialization_revision:
        if pending_world!=null:
            if not pending_world.worker_finished(): return
            _discard_world_preparation()
        world_prepare_epoch = timeline.initialization_revision
        world_revision = -1
    if world_revision>=0 or pending_world!=null or not _environment_sources_ready(): return
    var candidate = {"key":["initial",timeline.initialization_revision],"state":timeline.state,
        "presentation_state":timeline.presentation_state(),"changes":{"full":true,"tiles":{},"objects":{},"senses":true}}
    pending_world = WorldPreparation.new(); add_child(pending_world)
    pending_world.configure(self,candidate,true)

func _prepare_future_world() -> void:
    if world_revision<0 or world_prepare_epoch!=timeline.initialization_revision: return
    if pending_world!=null and (pending_world.initial or pending_world.admitted): return
    var candidate: Dictionary = timeline.preview_world()
    if pending_world!=null:
        if not candidate.is_empty() and pending_world.epoch==timeline.initialization_revision and pending_world.quarter==quarter and pending_world.boundary.preparation_key==candidate.preparation_key: return
        if not pending_world.worker_finished(): return
        _discard_world_preparation()
    if candidate.is_empty(): return
    # The accepted group plan publishes immutable authoring before projection.
    # Texture decode/upload can continue while its passive world is derived.
    if not media_group_plans.has(candidate.source_group_id): return
    pending_world = WorldPreparation.new(); add_child(pending_world)
    pending_world.configure(self,candidate)

func _prepared_world_sources_ready(candidate: Dictionary) -> bool:
    var plan: Dictionary = media_group_plans.get(candidate.source_group_id,{})
    return not plan.is_empty() and plan.errors.is_empty() and MediaWarmup.ready(media_warmup,plan.environment)

func _step_world_preparation() -> void:
    if pending_world==null: return
    if pending_world.epoch!=timeline.initialization_revision or pending_world.quarter!=quarter:
        if pending_world.worker_finished(): _discard_world_preparation()
        return
    # Only passive projection runs ahead of texture residency. Godot resource
    # binding stays on the scene thread and uses this boundary's exact plan.
    if not pending_world.initial and not _prepared_world_sources_ready(pending_world.boundary): return
    pending_world.step()
    if not pending_world.media_issue.is_empty(): media_issue = pending_world.media_issue

func _world_ready(candidate: Dictionary) -> bool:
    if world_revision<0: return false
    if pending_world!=null:
        if pending_world.admitted: return false # Publish before accepting another boundary.
        if pending_world.epoch!=timeline.initialization_revision or pending_world.quarter!=quarter or pending_world.boundary.preparation_key!=candidate.preparation_key:
            if not pending_world.worker_finished(): return false
            _discard_world_preparation()
        elif pending_world.prepared:
            pending_world.admitted = true
            return true
        else: return false
    pending_world = WorldPreparation.new(); add_child(pending_world)
    pending_world.configure(self,candidate)
    return false

func _world_can_publish() -> bool:
    return pending_world==null or (pending_world.epoch==timeline.initialization_revision and pending_world.prepared and (pending_world.admitted or pending_world.initial))

func _discard_world_preparation() -> void:
    if pending_world==null: return
    _retire_view(pending_world,null,pending_world.entries)
    pending_world = null

func _finish_world_preparation() -> void:
    if pending_world==null or not (pending_world.admitted or pending_world.initial): return
    world_prepare_worker_ms = pending_world.result.worker_ms
    world_prepared_count += 1
    # All adopted native nodes have moved to the stable displayed parent.
    pending_world.entries = []; pending_world.static_entries = []
    pending_world.native_groups = {}; pending_world.native_ground = {}
    _discard_world_preparation()

func _sync_world() -> void:
    var prepared: Dictionary = pending_world.result if pending_world!=null and pending_world.epoch==timeline.initialization_revision and pending_world.prepared and (pending_world.admitted or pending_world.initial) else {}
    # Explicit renderer fixtures may replace a state while preparation is pending.
    if prepared.is_empty() and pending_world!=null: _discard_world_preparation()
    var phase = Time.get_ticks_usec()
    world_changes = timeline.take_world_changes(world_revision)
    world_revision = timeline.world_revision
    var supports: Dictionary = timeline.staged_tiles()
    for key in supports:
        if not sampled_supports.has(key) or sampled_supports[key]!=supports[key]: world_changes.tiles[key] = true
    for key in sampled_supports:
        if not supports.has(key): world_changes.tiles[key] = true
    sampled_supports = supports
    var derived: Dictionary
    if not prepared.is_empty():
        session.retire_group(world_row_cache)
        world_row_cache = prepared.retained
        derived = prepared.derived
    else: derived = WorldRows.update_rows(timeline.presentation_state(),catalog_cache,world_row_cache,world_changes)
    _queue_wall_geometry_changes(world_changes)
    FrameProfile.end_phase(profile,"world_rows",phase)
    unresolved = derived.unresolved
    var rotated = world_quarter != quarter
    var background: bool = world_row_cache.negative.is_empty()
    var changed: bool = world_row_cache.changed or ground_is_background != background
    ground_is_background = background
    world_visual_rows = derived.visual_rows
    if changed: world_generation += 1
    if not prepared.get("geometry",{}).is_empty():
        prepared.geometry.generation = world_generation
        wall_geometry_views[quarter] = prepared.geometry
    if not changed and not rotated:
        _finish_world_preparation()
        return
    # Inactive views belong to one canonical world, not a state revision: HP,
    # log and actor updates must not invalidate otherwise identical artwork.
    phase = Time.get_ticks_usec()
    if changed: _clear_static_view_cache()
    if rotated:
        _deactivate_static_view(not changed)
        if static_views.has(quarter):
            _activate_static_view(quarter)
            placements = derived.rows
            FrameProfile.end_phase(profile,"world_views",phase)
            _finish_world_preparation()
            return
    FrameProfile.end_phase(profile,"world_views",phase)
    if sprite_parent == null:
        sprite_parent = QuarterView.new(); add_child(sprite_parent)
    # Keep canonical rows separate from camera-selected asset IDs and Hidden
    # corner substitutions, so a no-op world revision remains a no-op.
    placements = derived.rows
    var wanted: Dictionary = prepared.get("wanted",{})
    var ground: Dictionary = prepared.get("ground",{})
    if prepared.is_empty():
        for row in derived.visual_rows:
            if ground_is_background and row.kind == "terrain" and row.base_height_steps == 0 and row.material != "water":
                if not ground.has(row.material): ground[row.material] = []
                ground[row.material].append(row)
            else: wanted[row.id] = row
    var removed = {}
    var entries_changed = rotated
    var walls_changed = rotated
    phase = Time.get_ticks_usec()
    for id in world_groups:
        var group: Dictionary = world_groups[id]
        if not rotated and wanted.has(id) and wanted[id] == group.row: continue
        if group.row.kind in ["wall","cliff"]: walls_changed = true
        entries_changed = true
        _scenery_remove(group.entries)
        for entry in group.entries:
            removed[entry.node.get_instance_id()] = true
            entry.node.queue_free()
    FrameProfile.end_phase(profile,"world_objects",phase)
    phase = Time.get_ticks_usec()
    for key in ground_groups:
        var group: Dictionary = ground_groups[key]
        if not rotated and ground.has(key): continue
        entries_changed = true
        _scenery_remove(group.entries)
        for entry in group.entries:
            removed[entry.node.get_instance_id()] = true
            entry.node.queue_free()
    FrameProfile.end_phase(profile,"world_ground",phase)
    var fresh_groups = {}
    var fresh_ground = {}
    var retained: Array = []
    phase = Time.get_ticks_usec()
    for id in wanted:
        var row: Dictionary = wanted[id]
        var old: Dictionary = world_groups.get(id,{})
        if not rotated and not old.is_empty() and old.row == row:
            fresh_groups[id] = old
        else:
            if not prepared.is_empty() and pending_world.native_groups.has(id):
                fresh_groups[id] = pending_world.native_groups[id]
                for entry in fresh_groups[id].entries: entry.node.reparent(sprite_parent,false)
                entries.append_array(fresh_groups[id].entries)
            else:
                var first = static_entries.size()
                _environment_row(row.duplicate(true))
                fresh_groups[id] = {"row":row,"entries":static_entries.slice(first)}
            _scenery_add(fresh_groups[id].entries)
            entries_changed = true
            if row.kind in ["wall","cliff"]: walls_changed = true
        retained.append_array(fresh_groups[id].entries)
    FrameProfile.end_phase(profile,"world_objects",phase)
    phase = Time.get_ticks_usec()
    for key in ground:
        var rows: Array = ground[key]
        var old: Dictionary = ground_groups.get(key,{})
        if not rotated and not old.is_empty():
            if old.rows != rows:
                var prior: Dictionary = old.entries[0].placement
                if not prepared.is_empty() and prepared.packets.has(key): _ground_publish(old.entries[0],prepared.packets[key])
                else: _ground_update(old.entries[0],rows.duplicate())
                if prior!=old.entries[0].placement: entries_changed = true
                old.rows = rows
            fresh_ground[key] = old
        else:
            if not prepared.is_empty() and pending_world.native_ground.has(key):
                fresh_ground[key] = pending_world.native_ground[key]
                for entry in fresh_ground[key].entries: entry.node.reparent(sprite_parent,false)
                entries.append_array(fresh_ground[key].entries)
            else:
                var first = static_entries.size()
                _ground_batch(rows.duplicate())
                fresh_ground[key] = {"rows":rows,"entries":static_entries.slice(first)}
            _scenery_add(fresh_ground[key].entries)
            entries_changed = true
            for row in rows: scenery_new_consumers[row.id] = true
        retained.append_array(fresh_ground[key].entries)
    FrameProfile.end_phase(profile,"world_ground",phase)
    if not removed.is_empty():
        entries = entries.filter(func(entry):return not removed.has(entry.node.get_instance_id()))
    static_entries = retained
    fixture_entries = static_entries.filter(func(entry):return entry.material.shader == FIXTURE_FLAME_SHADER)
    world_groups = fresh_groups
    ground_groups = fresh_ground
    if not prepared.is_empty(): pending_world.publish_order()
    # New floor instances start remembered; current grants are applied through
    # their direct packed index without rebuilding one consumer per known tile.
    for key in world_row_cache.changed_tiles:
        var row: Dictionary = world_row_cache.tile_rows.get(key,{})
        if not row.is_empty(): scenery_new_consumers[row.id] = true
    scenery_index_count = static_entries.size()
    world_quarter = quarter
    draw_order_dirty = draw_order_dirty or entries_changed
    static_order_dirty = static_order_dirty or entries_changed
    wall_visibility_revision = -1
    wall_mask_dirty = wall_mask_dirty or walls_changed
    _finish_world_preparation()

func _clear_static_view_cache() -> void:
    _cancel_rotation()
    for view in static_views.values():
        _retire_view(view.root,view.get("mask_viewport"),view.entries)
    static_views = {}

func _retire_view(source: Node3D, mask: SubViewport, source_entries: Array = []) -> void:
    if source == null: return
    source.visible = false
    source.process_mode = Node.PROCESS_MODE_DISABLED
    if mask != null: mask.render_target_update_mode = SubViewport.UPDATE_DISABLED
    var held = {}
    for entry in source.release_handles():
        if is_instance_valid(entry.node): held[entry.node.get_instance_id()] = entry
    for entry in source_entries:
        if is_instance_valid(entry.node): held[entry.node.get_instance_id()] = entry
    var pending: Array = [source]
    if mask != null and not source.is_ancestor_of(mask): pending.append(mask)
    var nodes: Array = []
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        nodes.append(node); pending.append_array(node.get_children())
    retiring_views.append({"nodes":nodes,"entries":held})
    retiring_node_count += nodes.size()

func _dispose_views() -> void:
    # Native destruction can execute after our callback. Bound count as well as
    # measured CPU work, and never run this slice twice in one native frame.
    if retiring_views.is_empty() or retirement_frame==Engine.get_process_frames(): return
    retirement_frame = Engine.get_process_frames()
    var started = Time.get_ticks_usec()
    var released = 0
    while not retiring_views.is_empty() and released<16 and Time.get_ticks_usec()-started<2000:
        var view: Dictionary = retiring_views[0]
        var node = view.nodes.pop_back()
        if is_instance_valid(node):
            var id = node.get_instance_id()
            node.free()
            view.entries.erase(id)
        retiring_node_count -= 1
        released += 1
        if view.nodes.is_empty(): retiring_views.pop_front()
    FrameProfile.end_phase(profile,"view_retirement",started)

func _deactivate_static_view(retain: bool) -> void:
    if retain and world_quarter >= 0:
        sprite_parent.visible = false
        var visibility = {}
        for position in wall_visible_cells: visibility[WorldRows.cell_key(position)] = true
        sprite_parent.completed_style = [wall_mode,scenery_visibility.duplicate(),visibility] if not static_order_dirty and wall_visibility_revision==timeline.revision else []
        if wall_mask_viewport != null: wall_mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
        static_views[world_quarter] = {"root":sprite_parent,"groups":world_groups,"ground":ground_groups,
            "entries":static_entries,"fixtures":fixture_entries,"order":static_order,
            "order_dirty":static_order_dirty,"order_count":static_order_count,"wall_pick_order":wall_pick_order,
            "scenery_consumers":scenery_consumers,"wall_sources":wall_sources,"wall_entries":wall_entries,"geometry":wall_geometry_views.get(world_quarter,{}),"mask_viewport":wall_mask_viewport,"mask_nodes":wall_mask_nodes,
            "mask_sources":wall_mask_sources,"mask_view":wall_mask_view,"faded":faded_walls,"visible_cells":wall_visible_cells,
            "support_candidates":wall_support_candidates,"max_member_candidates":wall_max_member_candidates}
    else:
        _retire_view(sprite_parent,wall_mask_viewport,static_entries)
    entries = entries.filter(func(entry):return entry.placement.kind=="actor")
    sprite_parent = null
    world_groups = {}; ground_groups = {}; static_entries = []; fixture_entries = []; static_order = []
    static_complete_order = []; static_sort_nodes = {}
    static_order_count = -1; static_order_dirty = true
    wall_mask_viewport = null; wall_mask_nodes = []; wall_mask_sources = []; wall_mask_view = []

func _activate_static_view(view_quarter: int) -> void:
    var view: Dictionary = static_views[view_quarter]
    static_views.erase(view_quarter)
    sprite_parent = view.root; sprite_parent.visible = true
    world_groups = view.groups; ground_groups = view.ground
    scenery_consumers = view.get("scenery_consumers",{})
    wall_sources = view.get("wall_sources",[]); wall_entries = view.get("wall_entries",[])
    scenery_wall_sources = {}
    for source in wall_sources: scenery_wall_sources[source.id] = source
    scenery_batches = []
    for group in ground_groups.values(): scenery_batches.append_array(group.entries)
    scenery_index_dirty = scenery_consumers.is_empty(); scenery_index_count = view.entries.size()
    scenery_generation = world_generation
    static_entries = view.entries; fixture_entries = view.fixtures
    static_order = view.order; static_order_count = view.order_count; static_order_dirty = view.order_dirty
    wall_pick_order = view.wall_pick_order
    wall_mask_viewport = view.mask_viewport; wall_mask_nodes = view.mask_nodes; wall_mask_sources = view.mask_sources; wall_mask_view = view.mask_view
    wall_geometry_views[view_quarter] = view.geometry
    faded_walls = view.faded; wall_visible_cells = view.visible_cells
    wall_support_candidates = view.support_candidates; wall_max_member_candidates = view.max_member_candidates
    entries.append_array(static_entries)
    world_quarter = view_quarter; draw_order_dirty = true
    wall_visibility_revision = timeline.revision; wall_mask_dirty = false
    scenery_quarter = view_quarter; scenery_world_revision = world_revision; scenery_revision = timeline.world_revision
    water_entries = static_entries.filter(func(entry):return entry.material.shader==WATER_SHADER)
    water_display_seconds = -1.0

func _sample_fixtures() -> void:
    fixture_energy.clear()
    fixture_heights.clear()
    fixture_shadow_heights.clear()
    if fixture_entries.is_empty(): return
    var assets = Catalog.read_file("assets.json",catalog_cache)
    for name in fixture_clips:
        var clip: Dictionary = fixture_clips[name]
        Graphs.sample(clip.clock,"Idle",timeline.display_ms/1000.0,name)
        var frame: float = clip.clock.sample_seconds*clip.authored.fps
        clip.index = mini(int(frame),clip.authored.frames.size()-1)
        var blend = smoothstep(0.0,1.0,frame-floorf(frame))
        clip.strength = lerpf(clip.energy[clip.index],clip.energy[(clip.index+1)%clip.energy.size()],blend)
        clip.optical_height = lerpf(clip.heights[clip.index],clip.heights[(clip.index+1)%clip.heights.size()],blend)
    for entry in fixture_entries:
        var clip: Dictionary = fixture_clips[entry.placement.lit_animation]
        fixture_energy[entry.placement.id] = clip.strength
        fixture_heights[entry.placement.id] = clip.optical_height
        fixture_shadow_heights[entry.placement.id] = clip.mean_height
        if entry.get("flame_frame",-1) != clip.index:
            entry.flame_frame = clip.index
            entry.record = assets.resources[clip.authored.frames[clip.index]]
            entry.material.set_shader_parameter("frame_index",clip.index)
            entry.source_version = entry.get("source_version",0)+1

func _scenery_remove(group_entries: Array) -> void:
    for entry in group_entries:
        var id: String = entry.placement.id
        if scenery_consumers.has(id):
            scenery_consumers[id] = scenery_consumers[id].filter(func(value):return not is_same(value.entry,entry))
            if scenery_consumers[id].is_empty(): scenery_consumers.erase(id)
        water_entries.erase(entry); scenery_batches.erase(entry)
        if entry.has("wall_source"):
            wall_entries.erase(entry); scenery_wall_sources.erase(entry.wall_source.id)
    wall_sources = scenery_wall_sources.values()

func _scenery_add(group_entries: Array) -> void:
    for entry in group_entries:
        if entry.has("wall_source"):
            wall_entries.append(entry); scenery_wall_sources[entry.wall_source.id] = entry.wall_source
        if entry.material.shader == WATER_SHADER: water_entries.append(entry)
        if entry.material.shader not in [ENVIRONMENT_SHADER,WATER_SHADER]: continue
        if entry.has("batch_rows"):
            scenery_batches.append(entry)
            for row in entry.batch_rows: scenery_new_consumers[row.id] = true
            continue
        var id: String = entry.placement.id
        if not scenery_consumers.has(id): scenery_consumers[id] = []
        scenery_consumers[id].append({"entry":entry,"index":-1})
        scenery_new_consumers[id] = true
    wall_sources = scenery_wall_sources.values()

func _sync_scenery(force: bool = false, refresh_sight: bool = false) -> void:
    var rebuild = force or scenery_index_dirty or scenery_index_count!=static_entries.size() or scenery_quarter!=world_quarter
    if rebuild:
        scenery_consumers = {}; water_entries = []; wall_sources = []; wall_entries = []; scenery_wall_sources = {}; scenery_batches = []
        _scenery_add(static_entries)
        # A fresh quarter's packed instances already carry its prepared style.
        # Full fixtures/initialization also need explicit current support grants.
        for group in ground_groups.values():
            for row in group.rows: scenery_new_consumers[row.id] = true
        scenery_index_count = static_entries.size(); scenery_index_dirty = false
    if rebuild or refresh_sight or scenery_revision!=timeline.world_revision or scenery_generation!=world_generation or not scenery_new_consumers.is_empty():
        var state: Dictionary = timeline.presentation_state()
        var boundaries: Dictionary = WorldRows.boundary_index(state) if force or world_row_cache.is_empty() else world_row_cache.boundaries
        var current = WorldRows.current_ids(state,boundaries,scenery_visible_cells)
        var changed = {}
        for id in current:
            if not scenery_visibility.has(id): changed[id] = true
        for id in scenery_visibility:
            if not current.has(id): changed[id] = false
        for id in scenery_new_consumers: changed[id] = current.has(id)
        scenery_new_consumers = {}
        if current != scenery_visibility: wall_visibility_revision = -1
        scenery_visibility = current
        var batches = {}
        for id in changed:
            var value = 1.0 if changed[id] else 0.0
            for entry in scenery_batches:
                var index: int = entry.ground_indices.get(id,-1)
                if index>=0 and entry.scenery_values[index]!=value:
                    _ground_visibility(entry,index,value)
                    var key: int = entry.node.get_instance_id()
                    if not batches.has(key): batches[key] = {"entry":entry,"indices":[]}
                    batches[key].indices.append(index)
            for consumer in scenery_consumers.get(id,[]):
                if consumer.index>=0: continue # Older prepared snapshots may retain floor lookups.
                var entry: Dictionary = consumer.entry
                if entry.get("scenery_value",-1.0) != value:
                    entry.material.set_shader_parameter("current_visibility",value)
                    entry.scenery_value = value
        for batch in batches.values(): _ground_flush_visibility(batch.entry,batch.indices)
        scenery_revision = timeline.world_revision
        scenery_world_revision = world_revision
        scenery_generation = world_generation
        scenery_quarter = world_quarter
    var seconds: float = timeline.display_ms / 1000.0
    if water_display_seconds != seconds:
        for entry in water_entries: entry.material.set_shader_parameter("displayed_time_seconds",seconds)
        water_display_seconds = seconds

func _light_entry(entry: Dictionary) -> void:
    source_lighting.apply(entry.material)
    if entry.placement.kind in ["wall","door"] and entry.role != "shadow":
        entry.material.set_shader_parameter("two_sided_receiver",true)

func _sync_actors() -> void:
    # Initial raw state can arrive before its worker-prepared source catalog.
    # Do not fall back to synchronous JSON parsing while that job is running.
    if not media_metadata_ready: return
    var group: String = timeline.current.get("id","")
    var staged: Dictionary = timeline.staged_actors()
    var rendered_state: Dictionary = timeline.presentation_state()
    var loadouts = {}
    for id in displayed_samples:
        if displayed_samples[id].has("visual_loadout"): loadouts[id] = displayed_samples[id].visual_loadout
    if actor_revision == timeline.revision and actor_group == group and sampled_loadouts == loadouts and sampled_staged_ids == staged.keys(): return
    sampled_loadouts = loadouts
    sampled_staged_ids = staged.keys()
    actor_group = group
    var ids: Array = timeline.state.actors.keys()
    for id in staged:
        if not id in ids: ids.append(id)
    for id in visual_actors.keys():
        if id not in ids: _retire_actor(id)
    for id in actor_facings.keys():
        if id not in ids: actor_facings.erase(id)
    for id in ids:
        var actor: Dictionary = timeline.state.actors.get(id,staged.get(id,{}))
        if loadouts.has(id):
            actor = actor.duplicate()
            actor.visual_loadout = loadouts[id]
        if not WorldRows.visible_actor(actor,timeline.state,staged.has(id)):
            _retire_actor(id)
            continue
        var resolved = Characters.resolve(actor,rendered_state,catalog_cache)
        if not resolved.ok:
            if not resolved.error.message in presentation_errors: presentation_errors.append(resolved.error.message)
            _retire_actor(id)
            continue
        if resolved.value == null:
            _retire_actor(id)
            continue
        var row: Dictionary = resolved.value
        row.facing = actor_facings.get(id,row.facing)
        if visual_actors.has(id):
            var old: Dictionary = visual_actors[id]
            row.facing = old.row.facing
            if old.row.rig == row.rig and old.row.appearance == row.appearance and old.row.equipment_layers == row.equipment_layers:
                old.row.merge(row,true)
                old.valid = true
                continue
            _retire_actor(id)
        draw_order_dirty = true
        actor_rows.append(row)
        var rig: Dictionary = rigs[row.rig]
        playbacks[id] = Graphs.character(self,rig,true,animation_templates)
        var created: Array = []
        var layers: Array = Characters.layers(row,rig,catalog_cache)
        for i in range(layers.size()):
            var layer: Dictionary = layers[i]
            add_entry(row,"shadow" if layer.slot == "shadow" else "body",i,MODULAR_SHADER)
            var entry: Dictionary = entries.back()
            entry.actor_layer = layer
            entry.material.set_shader_parameter("layer_alpha",layer.alpha)
            entry.material.set_shader_parameter("shadow",layer.slot == "shadow")
            source_lighting.apply(entry.material)
            entry.material.set_shader_parameter("tint",Modular.rgb(layer.tint))
            var cell = Vector2(rig.cell_width,rig.cell_height)
            var pivot = Vector2(cell.x*0.5,cell.y-rig.origin_y_from_ground)
            set_quad(entry,cell,pivot,128.0/rig_config.TILE_W*row.scale)
            created.append(entry)
        visual_actors[id] = {"row":row,"entries":created,"valid":true}
    actor_revision = timeline.revision

func _retire_actor(id: String) -> void:
    if not visual_actors.has(id): return
    var old: Dictionary = visual_actors[id]
    actor_facings[id] = old.row.facing
    for entry in old.entries:
        entry.node.visible = false
        entry.node.queue_free()
        entries.erase(entry)
        actor_entries.erase(entry)
    playbacks[id].queue_free()
    playbacks.erase(id)
    actor_rows.erase(old.row)
    visual_actors.erase(id)
    draw_order_dirty = true

func _prepare_media(first: Dictionary = {}) -> void:
    if timeline.state.is_empty(): return
    var groups: Array = []
    if not timeline.current.is_empty(): groups.append(timeline.current)
    elif not first.is_empty(): groups.append(first)
    for group in timeline.queue:
        if groups.size() >= 2: break
        if groups.is_empty() or group.id != groups[0].id: groups.append(group)
    var ids: Array = groups.map(func(group):return group.id)
    # A group union includes every staged/committed outfit and world after-value.
    # Position/HP commits inside that same group cannot add a new media demand.
    var key: Array = [timeline.initialization_revision,ids,timeline.revision if ids.is_empty() else 0]
    if key == media_plan_key: return
    var started = Time.get_ticks_usec()
    media_plan_key = key
    if media_plan_epoch != timeline.initialization_revision:
        media_plan_epoch = timeline.initialization_revision
        media_group_plans.clear()
        media_empty_key = []
        media_empty_plan = {}
    for id in media_group_plans.keys():
        if id not in ids: media_group_plans.erase(id)
    var ready: Dictionary = media_empty_plan if ids.is_empty() and media_empty_key==key else media_group_plans.get(ids[0],{}) if not ids.is_empty() else {}
    var upcoming: Dictionary = media_group_plans.get(ids[1],{}) if ids.size()>1 else {}
    var needs_plan = ready.is_empty() or (ids.size()>1 and upcoming.is_empty())
    if needs_plan and media_requested_key != key:
        media_requested_key = key
        MediaWarmup.request_plan(media_warmup,key,timeline.state,groups)
    media_metadata_ready = not ready.is_empty()
    if not media_metadata_ready:
        FrameProfile.end_phase(profile,"media_plan",started)
        return
    media_plan = {"required":ready.character,"upcoming":upcoming.get("character",{}),
        "errors":ready.errors,"upcoming_errors":upcoming.get("errors",[])}
    media_environment_required = ready.environment
    var environment: Dictionary = ready.environment.duplicate()
    environment.merge(upcoming.get("environment",{}))
    var fixtures: Dictionary = ready.get("fixtures",{}).duplicate()
    fixtures.merge(upcoming.get("fixtures",{}))
    var gpu_only: Dictionary = ready.get("gpu_only",{}).duplicate()
    gpu_only.merge(upcoming.get("gpu_only",{}))
    var cpu_required: Dictionary = ready.get("cpu_required",{}).duplicate()
    cpu_required.merge(upcoming.get("cpu_required",{}))
    var wanted = {}
    for paths in [media_plan.required,media_environment_required,media_plan.upcoming,upcoming.get("environment",{})]:
        for path in paths: wanted[path] = Catalog.media_path(path)
    MediaWarmup.demand(media_warmup,wanted,environment,fixtures,gpu_only,cpu_required)
    media_issue = ""
    for message in media_plan.errors+media_plan.upcoming_errors:
        if not message in presentation_errors: presentation_errors.append(message)
    if not media_plan.errors.is_empty(): media_issue = media_plan.errors[0]
    var required: Dictionary = media_plan.required.duplicate()
    required.merge(media_environment_required)
    for path in required:
        if media_warmup.failed.has(path): media_issue = media_warmup.failed[path]
    _prune_character_media()
    FrameProfile.end_phase(profile,"media_plan",started)

func _media_ready(group: Dictionary) -> bool:
    _prepare_media(group)
    media_initial_ready = media_metadata_ready and not timeline.state.is_empty() and media_issue.is_empty() and media_plan.errors.is_empty() and MediaWarmup.ready(media_warmup,media_plan.required) and _environment_sources_ready() and MediaWarmup.boot_ready(media_warmup)
    return media_initial_ready and world_revision>=0 and not (pending_world!=null and pending_world.admitted)

func _environment_media_ready() -> bool:
    return world_revision>=0 and _environment_sources_ready()

func _environment_sources_ready() -> bool:
    return media_metadata_ready and media_plan.errors.is_empty() and MediaWarmup.ready(media_warmup,media_environment_required)

func _adopt_media_plan(completed: Dictionary) -> void:
    if completed.is_empty() or completed.key[0] != timeline.initialization_revision: return
    # Worker-published raw authoring is immutable; avoid synchronous JSON loads
    # when this exact prepared outfit/world first binds on the scene thread.
    catalog_cache.merge(completed.get("source_files",{}),false)
    if completed.has("error"):
        var message: String = completed.error
        if message not in presentation_errors: presentation_errors.append(message)
        var failed = {"character":{},"environment":{},"errors":[message],"fixtures":{}}
        if completed.key[1].is_empty():
            media_empty_key = completed.key
            media_empty_plan = failed
        else:
            for id in completed.key[1]:
                if not media_group_plans.has(id): media_group_plans[id] = failed
        media_plan_key = []
        return
    media_metadata_ms = completed.elapsed_ms
    var value: Dictionary = completed.value
    MediaWarmup.adopt_encounter(media_warmup,value.encounter,timeline.initialization_revision)
    var ids: Array = completed.key[1]
    var first_fixtures = {}
    var next_fixtures = {}
    for path in value.fixtures:
        if value.environment_required.has(path): first_fixtures[path] = true
        if value.environment_upcoming.has(path): next_fixtures[path] = true
    var first = {"character":value.required,"environment":value.environment_required,"errors":value.errors,"fixtures":first_fixtures}
    first.merge(MediaWarmup.roles_for(value,value.required))
    if ids.is_empty():
        media_empty_key = completed.key
        media_empty_plan = first
    else:
        if not media_group_plans.has(ids[0]): media_group_plans[ids[0]] = first
        if ids.size()>1 and not media_group_plans.has(ids[1]):
            media_group_plans[ids[1]] = {"character":value.upcoming,"environment":value.environment_upcoming,"errors":value.upcoming_errors,"fixtures":next_fixtures}
            media_group_plans[ids[1]].merge(MediaWarmup.roles_for(value,value.upcoming))
    media_plan_key = []

func set_normals_visible(value: bool) -> void:
    if normals_visible == value: return
    normals_visible = value
    native_light_atlas.set_normals_visible(value)
    for entry in actor_entries:
        if entry.get("generated_shadow",false): entry.node.visible = not value
    draw_order_dirty = true

func texture(path: String) -> Texture2D:
    # All live source reads are admitted by preparation before world creation.
    # A selector miss is a visible test failure, never a synchronous disk read.
    if textures.has(path): return textures[path]
    var message = "Media preparation missed displayed environment source: " + path
    if message not in presentation_errors: presentation_errors.append(message)
    media_issue = message
    return null

func _prune_character_media() -> void:
    for path in MediaWarmup.release_cold_images(media_warmup): source_images.erase(path)
    for path in MediaWarmup.prune(media_warmup):
        # Hidden actors can retain material references long after disclosure.
        # Release those handles as well as the CPU/GPU cache dictionaries.
        for visual in visual_actors.values():
            for entry in visual.entries:
                if entry.get("texture_path","") == path:
                    entry.material.set_shader_parameter("sheet",null)
                    entry.erase("texture_path")
                    entry.node.visible = false
                if entry.get("geometry_paths",{}).has(path): CharacterGeometry.clear(entry)
        textures.erase(path)
        source_images.erase(path)
        texture_last_use.erase(path)

func _warm_media() -> void:
    _adopt_media_plan(MediaWarmup.poll_plan(media_warmup))
    var loaded = MediaWarmup.poll(media_warmup)
    if loaded.is_empty(): return
    if loaded.has("error"):
        var message: String = loaded.error
        if not message in presentation_errors: presentation_errors.append(message)
        if media_plan.required.has(loaded.path) or media_environment_required.has(loaded.path): media_issue = message
        return
    var started = Time.get_ticks_usec()
    source_images[loaded.path] = loaded.image
    if loaded.has("energy"): fixture_frame_energy[loaded.path] = loaded.energy
    if loaded.has("emission_centroid"): fixture_frame_centroids[loaded.path] = loaded.emission_centroid
    if not textures.has(loaded.path): textures[loaded.path] = ImageTexture.create_from_image(loaded.image)
    texture_last_use[loaded.path] = Time.get_ticks_msec()
    MediaWarmup.published(media_warmup,loaded)
    _prune_character_media()
    FrameProfile.end_phase(profile,"media_upload",started)

func _sample_actors() -> void:
    var rendered_state = timeline.presentation_state()
    var staged: Dictionary = timeline.staged_actors()
    for id in visual_actors:
        var visual: Dictionary = visual_actors[id]
        var row: Dictionary = visual.row
        var actor: Dictionary = timeline.state.actors.get(id,staged.get(id,{}))
        if actor.is_empty() or not visual.valid or actor.get("last_visual_position") == null:
            for entry in visual.entries: entry.node.visible = false
            continue
        var show = WorldRows.visible_actor(actor,timeline.state,staged.has(id))
        show = show and actor.get("spatial_disposition","present") == "present" and actor.get("remains_disposition","intact") != "disintegrated"
        if not show:
            for entry in visual.entries: entry.node.visible = false
            continue
        var sample: Dictionary = displayed_samples.get(id,{})
        row.visual_height = float(sample.get("lift_pixels",0))*(128.0/rig_config.TILE_W)/64.0
        var rig: Dictionary = rigs[row.rig]
        var resting = Characters.rest_sample(actor,rig,catalog_cache)
        if not resting.ok:
            if not resting.error.message in presentation_errors: presentation_errors.append(resting.error.message)
            for entry in visual.entries: entry.node.visible = false
            continue
        var idle: String = resting.value.clip
        var seconds = timeline.display_ms/1000.0
        var occurrence = "idle:"+id
        row.position = actor.last_visual_position.duplicate()
        var support: Dictionary = rendered_state.tiles.get(WorldRows.cell_key(actor.last_visual_position),{})
        if support.has("elevation_steps"): row.base_height_steps = support.elevation_steps
        if actor.life_state in ["dead","dying","stable"]:
            seconds = resting.value.source_seconds
            occurrence = "terminal:"+id
        if not sample.is_empty():
            idle = sample.clip
            seconds = sample.source_seconds
            occurrence = sample.occurrence
            if sample.has("position"):
                row.position = sample.position
                row.base_height_steps = sample.base_height_steps
            var target: Variant = sample.get("target_position",sample.get("to_position"))
            var origin: Variant = sample.get("from_position")
            if target != null and origin != null:
                var direction = Vector2(target[0]-origin[0],target[1]-origin[1])
                if not direction.is_zero_approx(): row.facing = _facing(direction)
        var sampled = Graphs.sample(playbacks[id],idle,seconds,occurrence)
        if not sampled.ok:
            if not sampled.error.message in presentation_errors: presentation_errors.append(sampled.error.message)
            for entry in visual.entries: entry.node.visible = false
            continue
        var playback: Node = playbacks[id]
        var clip: Dictionary = rig.clips[playback.clip]
        var cycle: Array = rig_config.FACING_CYCLE
        var facing: String = cycle[posmod(cycle.find(row.facing)+quarter*2,8)]
        var frame = mini(int(playback.sample_seconds*clip.fps),int(clip.frames)-1)
        var complete_outfit = true
        for entry in visual.entries:
            var layer: Dictionary = entry.actor_layer
            if not clip.sheets.has(layer.category) or layer.slot in sample.get("hidden_slots",[]): continue
            var path: String = layer.paths[playback.clip]
            if not textures.has(path) or not source_images.has(path): complete_outfit = false; break
            for companion in CharacterGeometry.paths(path,layer.slot,catalog_cache):
                if not textures.has(companion): complete_outfit = false; break
        if not complete_outfit:
            for entry in visual.entries: entry.node.visible = false
            if media_initial_ready:
                var message = "Character media preparation missed displayed outfit: " + id + "/" + playback.clip
                if not message in presentation_errors: presentation_errors.append(message)
                media_issue = message
            continue
        for entry in visual.entries:
            var layer: Dictionary = entry.actor_layer
            entry.node.visible = show and clip.sheets.has(layer.category) and not layer.slot in sample.get("hidden_slots",[])
            if not entry.node.visible: continue
            var path: String = layer.get("paths",{}).get(playback.clip,resources[clip.sheets[layer.category]])
            # Current sampling never falls back to synchronous disk/decode.
            # A missing initial sheet remains hidden until preparation finishes;
            # an active group's full exact demand was gated before its commits.
            if not textures.has(path) or not source_images.has(path):
                entry.node.visible = false
                continue
            var sheet: Texture2D = textures[path]
            MediaWarmup.touch(media_warmup,path)
            var source_key = [path,frame,facing,character_light_profile,source_depth,source_normals,row.get("scale_x",1.0)]
            if entry.get("sampled_source_key",[]) != source_key:
                entry.sampled_source_key = source_key
                entry.source_version = entry.get("source_version",0)+1
            entry.texture_path = path
            entry.material.set_shader_parameter("sheet",sheet)
            entry.material.set_shader_parameter("frame_uv",Vector4(frame*rig.cell_width/sheet.get_width(),rig.facing_rows[facing]*rig.cell_height/sheet.get_height(),float(rig.cell_width)/sheet.get_width(),float(rig.cell_height)/sheet.get_height()))
            CharacterGeometry.bind(entry,path,catalog_cache,texture,source_depth,source_normals,character_light_profile)
            entry.node.basis = camera.basis.scaled_local(Vector3(row.get("scale_x",1.0),1,1))
            entry.node.position = Placement.contact(row)
            if entry.role != "shadow": entry.node.position.y += float(sample.get("lift_pixels",0))*(128.0/rig_config.TILE_W)/64.0*Placement.HEIGHT_UNIT
            update_bounds(entry)

func _facing(direction: Vector2) -> String:
    var cycle: Array = rig_config.FACING_CYCLE
    return cycle[posmod(roundi((atan2(direction.y,direction.x)+PI/4)/(TAU/8))+cycle.find("E"),8)]

func _sync_native_lighting() -> void:
    var phase = Time.get_ticks_usec()
    source_lighting.project(camera)
    FrameProfile.end_phase(profile,"native_2d_projection",phase)
    phase = Time.get_ticks_usec()
    native_light_atlas.sync(self,
        [world_generation,world_revision,quarter,wall_mode,scenery_revision,source_depth,source_normals],
        [world_generation,quarter,scenery_revision,wall_mode])
    FrameProfile.end_phase(profile,"native_2d_atlas",phase)
    phase = Time.get_ticks_usec()
    # Remove stale handles before the helper retires hidden actors. Source
    # components and picking continue to use the original visual.entries list.
    actor_entries = actor_entries.filter(func(entry):return not entry.get("generated_shadow",false))
    var shadows = generated_shadows.sync(visual_actors.values(),camera,source_lighting.canvas_sources())
    if normals_visible:
        for entry in shadows: entry.node.visible = false
    var ids = shadows.map(func(entry):return entry.node.get_instance_id())
    if ids != generated_shadow_ids:
        generated_shadow_ids = ids
        draw_order_dirty = true
    actor_entries.append_array(shadows)
    FrameProfile.end_phase(profile,"modular_shadows",phase)
    for issue in source_lighting.issues+generated_shadows.issues:
        if issue not in presentation_errors: presentation_errors.append(issue)

func _sort_draws() -> void:
    # Source geometry establishes one total order. Changing which wall variants
    # are visible selects a subsequence; it does not change those ordering keys.
    if static_order_dirty or static_order_count != static_entries.size():
        var ordering_started = Time.get_ticks_usec()
        var changed = static_complete_order.size()!=static_entries.size()
        for entry in static_entries:
            if not static_sort_nodes.has(entry.node.get_instance_id()): changed = true
            if not is_same(entry.get("order_placement"),entry.placement) or entry.get("order_quarter",-1)!=quarter or entry.get("order_background")!=ground_is_background or entry.get("order_id")!=entry.id:
                entry.order_key = Order.key(entry.placement,entry.role,entry.layer,quarter,ground_is_background)
                entry.order_placement = entry.placement
                entry.order_quarter = quarter
                entry.order_background = ground_is_background
                entry.order_id = entry.id
                changed = true
        if changed:
            static_complete_order = static_entries.duplicate()
            static_complete_order.sort_custom(_entry_before)
            static_sort_nodes = {}
            for entry in static_entries: static_sort_nodes[entry.node.get_instance_id()] = true
        static_order = static_complete_order.filter(func(entry):return entry.node.visible)
        wall_pick_order = static_complete_order.filter(func(entry):return entry.has("wall_source") and entry.role!="shadow" and entry.wall_variant!="joined" and entry.wall_source_visible)
        static_order_count = static_entries.size()
        static_order_dirty = false
        draw_order_dirty = true
        FrameProfile.end_phase(profile,"static_order",ordering_started)
    for entry in actor_entries:
        var shown: bool = entry.node.visible
        if entry.get("sort_visible") != shown:
            entry.sort_visible = shown
            draw_order_dirty = true
        if not shown: continue
        var key = Order.key(entry.placement,entry.role,entry.layer,quarter,ground_is_background)
        if entry.get("order_key",[]) != key:
            entry.order_key = key
            draw_order_dirty = true
        entry.order_quarter = quarter
    var forward = -camera.global_basis.z
    if draw_order_dirty:
        var moving = actor_entries.filter(func(entry):return entry.node.visible)
        moving.sort_custom(_entry_before)
        draw_order = []
        var fixed_index = 0
        for actor in moving:
            while fixed_index < static_order.size() and _entry_before(static_order[fixed_index],actor):
                draw_order.append(static_order[fixed_index]); fixed_index += 1
            draw_order.append(actor)
        while fixed_index < static_order.size():
            draw_order.append(static_order[fixed_index]); fixed_index += 1
        for i in range(draw_order.size()): _apply_draw_rank(draw_order[i],i,forward)
        draw_order_dirty = false
    else:
        # Jump height can move a node without changing its ground painter key.
        for entry in actor_entries:
            if entry.node.visible: _apply_draw_rank(entry,entry.draw_rank,forward)
    _sync_wall_mask()

func _entry_before(a: Dictionary, b: Dictionary) -> bool:
    return Order.less(a.order_key,b.order_key) if a.order_key != b.order_key else a.id < b.id

func _apply_draw_rank(entry: Dictionary, rank: int, forward: Vector3) -> void:
    var position: Vector3 = entry.node.global_position
    if entry.placement.kind != "actor" and entry.get("draw_rank",-1)==rank and entry.get("draw_quarter",-1)==quarter and entry.get("draw_position")==position: return
    var offset: float = float(rank)*8.0+forward.dot(position)
    if entry.get("draw_offset") != offset:
        entry.node.sorting_offset = offset
        entry.draw_offset = offset
    entry.draw_rank = rank
    entry.draw_quarter = quarter
    entry.draw_position = position

func _sync_wall_mask() -> void:
    var started = Time.get_ticks_usec()
    if wall_mask_viewport == null:
        wall_mask_viewport = SubViewport.new()
        wall_mask_viewport.size = Vector2i(get_viewport().get_visible_rect().size)
        wall_mask_viewport.disable_3d = true
        wall_mask_viewport.transparent_bg = true
        wall_mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
        add_child(wall_mask_viewport)
        RenderingServer.viewport_set_measure_render_time(wall_mask_viewport.get_viewport_rid(),true)
    var rebuilt = wall_mask_dirty
    if rebuilt:
        wall_mask_sources.clear()
        var index = 0
        for entry in draw_order:
            if not entry.placement.kind in ["wall","cliff"] or entry.role == "shadow": continue
            index += 1
            var node: ColorRect
            var material: ShaderMaterial
            if index > wall_mask_nodes.size():
                node = ColorRect.new()
                material = ShaderMaterial.new()
                material.shader = WALL_COVERAGE_SHADER
                node.material = material
                node.mouse_filter = Control.MOUSE_FILTER_IGNORE
                wall_mask_viewport.add_child(node)
                wall_mask_nodes.append(node)
            else:
                node = wall_mask_nodes[index-1]
                material = node.material
            for parameter in ["colour_texture","colour_size","colour_rect","use_selection","invert_selection","selection_kind",
                    "rgba_min","rgba_max","selection_mask","selection_rect","selection_scale","selection_offset","selection_values"]:
                material.set_shader_parameter(parameter,entry.material.get_shader_parameter(parameter))
            material.set_shader_parameter("wall_mask_id",index)
            wall_mask_sources.append(entry)
            entry.material.set_shader_parameter("wall_mask_id",index)
            entry.material.set_shader_parameter("wall_mask_texture",wall_mask_viewport.get_texture())
            entry.material.set_shader_parameter("wall_mask_enabled",wall_mode=="translucent")
        while wall_mask_nodes.size()>index:
            var retired: ColorRect = wall_mask_nodes.pop_back()
            wall_mask_viewport.remove_child(retired)
            retired.queue_free()
        wall_mask_dirty = false
    var view = [camera.global_transform,camera.size,get_viewport().get_visible_rect().size]
    if rebuilt or view != wall_mask_view:
        wall_mask_view = view
        wall_mask_viewport.size = Vector2i(view[2])
        for i in range(wall_mask_nodes.size()):
            var source: MeshInstance3D = wall_mask_sources[i].node
            var mesh: QuadMesh = source.mesh
            var start = camera.unproject_position(source.global_transform*(mesh.center_offset+Vector3(-mesh.size.x*.5,mesh.size.y*.5,0)))
            var end = camera.unproject_position(source.global_transform*(mesh.center_offset+Vector3(mesh.size.x*.5,-mesh.size.y*.5,0)))
            wall_mask_nodes[i].position = start
            wall_mask_nodes[i].size = end-start
        # Keep the target live: UPDATE_ONCE left the first mask stale in the
        # native Compatibility regression; continuous coverage preserves it.
        wall_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    wall_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if wall_mode=="translucent" else SubViewport.UPDATE_DISABLED
    FrameProfile.end_phase(profile,"mask_sync",started)

func rotation_pending() -> bool:
    return requested_quarter >= 0 and requested_quarter != world_quarter

func request_view(target: int) -> void:
    requested_quarter = posmod(target,4)
    if pending_view != null and pending_view.quarter != requested_quarter: _cancel_rotation()
    if requested_quarter == world_quarter:
        _cancel_rotation()
        position_camera()
        return
    _prepare_rotation()

func _rotate_view() -> void:
    # Compatibility for callers which previously assigned quarter first. Restore
    # the current camera/input identity until its complete target is published.
    var target = quarter
    quarter = maxi(world_quarter,0)
    request_view(target)

func _cancel_rotation() -> void:
    if pending_view == null: return
    _retire_view(pending_view,pending_view.mask_viewport)
    pending_view = null
    rotation_publication_frame = -1

func _prepare_rotation() -> void:
    _dispose_views()
    # Bound discarded native views even under repeated cancellation. Current
    # view, input and the authoritative presentation clock keep running.
    if not retiring_views.is_empty(): return
    if not rotation_pending() or not _environment_media_ready(): return
    if pending_view != null and pending_view.generation != world_generation: _cancel_rotation()
    if pending_view == null:
        if static_views.has(requested_quarter):
            var cached: Dictionary = static_views[requested_quarter]
            static_views.erase(requested_quarter)
            pending_view = cached.root
            pending_view.configure(self,requested_quarter,cached)
        else:
            pending_view = QuarterView.new(); add_child(pending_view)
            pending_view.configure(self,requested_quarter)
        rotation_publication_frame = -1
    if not pending_view.media_issue.is_empty():
        media_issue = pending_view.media_issue
        return
    if not pending_view.is_prepared:
        pending_view.step()
        return
    if not pending_view.style_is_current():
        pending_view.is_prepared = false; pending_view.begin_style(); rotation_publication_frame = -1; return
    if not pending_view.projection_is_current():
        pending_view.refresh_projection(); rotation_publication_frame = -1; return
    # Let prepared mask textures complete a native frame before publication.
    if rotation_publication_frame < 0:
        rotation_publication_frame = Engine.get_process_frames(); return
    if Engine.get_process_frames() <= rotation_publication_frame: return
    var started = Time.get_ticks_usec()
    var target: int = pending_view.quarter
    var prepared: Dictionary = pending_view.snapshot()
    pending_view = null; rotation_publication_frame = -1
    _deactivate_static_view(true)
    static_views[target] = prepared
    quarter = target; position_camera(); _activate_static_view(target)
    _sample_actors(); _sample_fixtures(); _sync_scenery()
    _sort_draws()
    hover_key = []; hover_hit = {}; hover_preview = {}
    FrameProfile.end_phase(profile,"rotation_publish",started)

func _discover() -> void:
    if command_busy or action_request >= 0 or not session.ready_for_input(timeline.sequence) or timeline.busy() or timeline.sequence < await_command_cursor: return
    var boundary: Dictionary = session.status.boundary
    if action_revision == boundary.state_revision and choices_force_attack == force_attack: return
    action_revision = boundary.state_revision
    cancel_selection(false)
    pending_request = {"kind":"choices","force_attack":force_attack,"revision":action_revision}
    action_request = session.request("choices",{"actor_uuid":boundary.input_actor_uuid,"state_revision":boundary.state_revision,"force_attack":force_attack,"correlation_id":Session.uuid()})

func command_ready() -> bool:
    return media_initial_ready and media_issue.is_empty() and not command_busy and action_request < 0 and not available_actions.is_empty() and not timeline.busy() \
        and not timeline.paused and timeline.sequence >= await_command_cursor and session.ready_for_input(timeline.sequence) \
        and action_revision == session.status.boundary.state_revision and choices_force_attack == force_attack \
        and available_actions.entity_uuid == timeline.state.current_actor_uuid

func cancel_selection(clear_approach: bool = true) -> void:
    selection_serial += 1
    selected_action = {}
    target_selection = {}
    selection_preview = {}
    preview_positions = []
    hover_preview = {}
    hover_key = []
    if clear_approach:
        pending_approach = {}
        pending_loot_open = {}
    if pending_request.get("kind") == "preview": command_busy = false
    selected_mode = "action.move"
    context_menu.hide()

func select_action(row: Dictionary) -> void:
    if not command_ready(): return
    if row.discovery_generation != available_actions.discovery_generation or row.discovery_actor_uuid != available_actions.entity_uuid: return
    if row.availability_status != "available": notice_text = row.availability_status.replace("_"," ").capitalize(); return
    cancel_selection()
    selected_action = row
    if row.get("weapon_slot") in ["MELEE_MAIN","RANGED_MAIN"]:
        attack_preference = row.weapon_slot
        attack_preferences[available_actions.entity_uuid] = attack_preference
    selected_mode = row.behavior_id
    target_selection = Interaction.selection(row,[])
    notice_text = row.display_name + ": choose a target."
    if row.target_type == "self":
        target_selection.target_indices = [row.valid_targets[0].index]
        _request_selection(true)
    else: _request_selection(false)

func _request_selection(auto_confirm: bool) -> void:
    if action_request >= 0 or selected_action.is_empty(): return
    selection_serial += 1
    preview_selection = target_selection.duplicate(true)
    selection_preview = {}
    command_busy = auto_confirm
    pending_request = {"kind":"preview","serial":selection_serial,"auto_confirm":auto_confirm,
        "revision":action_revision,"generation":available_actions.discovery_generation}
    action_request = session.request("preview",{"actor_uuid":available_actions.entity_uuid,"state_revision":action_revision,
        "discovery_generation":available_actions.discovery_generation,"correlation_id":Session.uuid(),"selection":preview_selection})

func _execute_admitted(value: Dictionary, keep_approach: bool = false) -> void:
    cancel_selection(not keep_approach)
    selected_action = value.action
    selected_mode = selected_action.behavior_id
    target_selection = value.selection.duplicate(true)
    _request_selection(true)

func confirm_selection() -> void:
    if not command_ready() or selected_action.is_empty() or not selection_preview.get("can_confirm",false): return
    if selected_action.behavior_id == "action.environment.storage_chest.open":
        pending_loot_open = {"object":selected_action.source_item_uuid,"actor":available_actions.entity_uuid}
    _submit({"kind":"execute_selection","discovery_generation":available_actions.discovery_generation,"selection":target_selection.duplicate(true)})

func storage_view() -> Dictionary:
    if loot_object_uuid.is_empty(): return {}
    var object: Dictionary = timeline.state.get("objects",{}).get(loot_object_uuid,{})
    if timeline.state.get("current_actor_uuid","") != loot_actor_uuid or object.get("contained_items") == null:
        close_storage()
        return {}
    return object

func open_storage(object_uuid: String) -> void:
    if not command_ready(): return
    var object: Dictionary = timeline.state.objects.get(object_uuid,{})
    if object.get("contained_items") == null: return
    cancel_selection()
    loot_object_uuid = object_uuid
    loot_actor_uuid = timeline.state.current_actor_uuid
    hud.open_loot()

func close_storage() -> void:
    loot_object_uuid = ""
    loot_actor_uuid = ""
    pending_loot_open = {}
    if hud == null or hud.loot_panel == null: return
    var focus = get_viewport().gui_get_focus_owner()
    if focus != null and hud.loot_panel.is_ancestor_of(focus): focus.release_focus()
    hud.loot_panel.hide()

func _poll_storage() -> void:
    if not loot_object_uuid.is_empty(): storage_view()
    if pending_loot_open.is_empty(): return
    if timeline.state.get("current_actor_uuid","") != pending_loot_open.actor:
        pending_loot_open = {}; return
    if not command_ready(): return
    var id: String = pending_loot_open.object
    pending_loot_open = {}
    open_storage(id)

func storage_action(item_uuid: String = "") -> Dictionary:
    if not command_ready(): return {}
    var object = storage_view()
    if object.is_empty() or object.contained_items.is_empty(): return {}
    if not item_uuid.is_empty() and not object.contained_items.any(func(item):return item.item_uuid == item_uuid): return {}
    var behavior = "action.environment.storage_chest.loot_all" if item_uuid.is_empty() else "action.environment.storage_chest.loot"
    for row in Interaction.actions(available_actions):
        if row.behavior_id != behavior or row.get("source_item_uuid") != loot_object_uuid: continue
        if not item_uuid.is_empty() and row.get("loot_item_uuid") != item_uuid: continue
        if not row.can_afford or row.availability_status != "available" or row.target_type != "self": continue
        if row.valid_targets.size() == 1:
            return {"action":row,"selection":Interaction.selection(row,[row.valid_targets[0].index])}
    return {}

func loot_storage(item_uuid: String = "") -> void:
    var admitted = storage_action(item_uuid)
    if admitted.is_empty(): return
    _execute_admitted(admitted)
    hud.loot_panel.refresh()

func _capture_frame_evidence() -> void:
    frame_evidence.clear()
    if DisplayServer.get_name() == "headless": return
    var viewport = get_viewport().get_visible_rect()
    for actor_id in displayed_samples:
        var sample: Dictionary = displayed_samples[actor_id]
        var track_id: String = sample.get("trace_track_id","")
        if track_id.is_empty(): continue
        var evidence = {"trace_track_id":track_id,"display_ms":timeline.display_ms,"visible":false,"reason":"not_visible"}
        var visual: Dictionary = visual_actors.get(actor_id,{})
        if not visual.is_empty():
            if not visual.valid:
                evidence.reason = "invalid_character_rig"
            else:
                var submitted = false
                var onscreen = false
                for entry in visual.entries:
                    if entry.role == "shadow" or not entry.node.is_visible_in_tree() or entry.get("texture_path","").is_empty(): continue
                    if playbacks[actor_id].clip != sample.clip: continue
                    submitted = true
                    var mesh: QuadMesh = entry.node.mesh
                    var transform: Transform3D = entry.node.global_transform
                    var start = camera.unproject_position(transform*(mesh.center_offset+Vector3(-mesh.size.x*.5,mesh.size.y*.5,0)))
                    var end = camera.unproject_position(transform*(mesh.center_offset+Vector3(mesh.size.x*.5,-mesh.size.y*.5,0)))
                    if Rect2(start,end-start).abs().intersects(viewport): onscreen = true; break
                evidence.visible = onscreen
                if submitted: evidence.reason = "" if onscreen else "offscreen"
                elif WorldRows.visible_actor(timeline.state.actors.get(actor_id,timeline.staged_actors().get(actor_id,{})),timeline.state,timeline.staged_actors().has(actor_id)):
                    evidence.reason = "no_valid_body_sample"
        frame_evidence.append(evidence)

func _record_frame_evidence() -> void:
    # Capture the clock and exact sampled tracks before draw, acknowledge only
    # after the native renderer has submitted that frame. Idle is not evidence.
    if frame_evidence.is_empty(): return
    timeline.record_presented(frame_evidence)
    frame_evidence.clear()

func inventory_intent(intent: Dictionary) -> void:
    if not command_ready(): return
    if not intent.get("kind") in ["equip","unequip","toggle_handler"]: return
    cancel_selection()
    _submit(intent)

func choose_target(position: Array, actor_id: String = "") -> void:
    if not command_ready(): return
    if not selected_action.is_empty():
        target_selection.prefer_safe = not Input.is_physical_key_pressed(KEY_SHIFT)
        if position in selection_preview.get("next_positions",[]):
            target_selection.extra_target_positions.append(position)
            _request_selection(false)
            return
        var candidate = Interaction.target(selection_preview.get("next_targets",selected_action.valid_targets),position,actor_id)
        if candidate.is_empty(): notice_text = selection_preview.get("reason") if selection_preview.get("reason") != null else "Choose a highlighted legal target."; return
        target_selection.target_indices.append(candidate.index)
        var position_spec: Variant = selected_action.get("position_selection")
        var explicit = selected_action.target_type == "multi_entity" or (position_spec != null and position_spec.kind in ["path","entity_destination"])
        _request_selection(not explicit)
        return
    var selected: Dictionary = {}
    var target: Dictionary = {}
    var behavior = "action.attack" if not actor_id.is_empty() and selected_mode == "action.move" else selected_mode
    for family in ["entity_actions","position_actions","self_actions","object_actions"]:
        for action in available_actions[family]:
            if action.behavior_id != behavior or not action.can_afford: continue
            for candidate in action.valid_targets:
                if (not actor_id.is_empty() and candidate.get("target_uuid")==actor_id) or (actor_id.is_empty() and candidate.get("position")==position):
                    selected = action
                    target = candidate
                    break
            if not target.is_empty(): break
        if not target.is_empty(): break
    if target.is_empty(): notice_text = "No disclosed legal target for this action."; return
    _execute_admitted({"action":selected,"selection":Interaction.selection(selected,[target.index],not Input.is_physical_key_pressed(KEY_SHIFT))})

func end_turn() -> void:
    if not command_ready(): return
    cancel_selection()
    _submit({"kind":"end_turn"})

func _submit(intent: Dictionary) -> void:
    var command = {"command_number":session.status.next_command_number,"actor_uuid":session.status.boundary.input_actor_uuid,"state_revision":session.status.boundary.state_revision,"intent":intent}
    pending_request = {"kind":"command","number":command.command_number}
    command_busy = true
    hover_preview = {}
    context_menu.hide()
    action_request = session.request("submit_command",command)

func _poll_actions() -> void:
    if action_request < 0 and command_busy and pending_request.get("kind") == "receipt" and Time.get_ticks_msec() >= receipt_due:
        action_request = session.request("receipt",{"number":pending_request.number})
    if action_request < 0 or not session.responses.has(action_request): return
    var response: Dictionary = session.responses[action_request]
    session.responses.erase(action_request)
    session.retire_record(response)
    action_request = -1
    if not response.ok:
        notice_text = response.error.message
        if pending_request.kind in ["command","receipt"]:
            # A lost HTTP reply does not mean the command failed. Query its
            # original number; never automatically send another game command.
            pending_request.kind = "receipt" if response.error.get("retryable",false) else "unresolved"
            receipt_due = Time.get_ticks_msec()+1000
            notice_text = "Checking command %s after a connection error…" % pending_request.number if pending_request.kind == "receipt" else "Command %s: %s. R checks its receipt again." % [pending_request.number,response.error.message]
            return
        command_busy = false
        action_revision = ""
        return
    match pending_request.kind:
        "choices":
            if pending_request.force_attack != force_attack or pending_request.revision != session.status.boundary.state_revision:
                action_revision = ""
                return
            var value: Dictionary = response.normalized
            session.retire_record(available_actions)
            available_actions = value.choices
            attack_preference = attack_preferences.get(available_actions.entity_uuid,"MELEE_MAIN")
            choices_force_attack = value.force_attack
            hover_key = []
            notice_text = ""
            _continue_approach()
        "preview":
            if pending_request.serial != selection_serial or pending_request.revision != session.status.boundary.state_revision or pending_request.generation != available_actions.discovery_generation:
                command_busy = false
                return
            var preview: Dictionary = response.normalized.preview
            selection_preview = preview
            preview_positions = preview.get("affected_positions",[])
            command_busy = false
            if pending_request.auto_confirm and preview.can_confirm: confirm_selection()
            else: notice_text = (preview.reason if preview.get("reason") != null else ("Enter to confirm · Backspace to undo" if preview.can_confirm else "Choose a target"))
        "command", "receipt":
            var receipt: Dictionary = response.normalized.receipt
            if receipt.kind == "pending":
                pending_request = {"kind":"receipt","number":receipt.command_number}
                receipt_due = Time.get_ticks_msec()+100
            elif receipt.kind in ["indeterminate","expired","unknown"]:
                pending_request = {"kind":"unresolved","number":receipt.command_number}
                notice_text = "Command %s is %s; input is held. R checks its receipt again." % [receipt.command_number,receipt.kind]
            else:
                command_busy = false
                if receipt.kind == "committed": await_command_cursor = int(receipt.cursor.sequence)
                else:
                    pending_approach = {}
                    pending_loot_open = {}
                cancel_selection(false)
                action_revision = ""
                notice_text = "Playing committed action…" if receipt.kind == "committed" else "Command "+receipt.kind

func pick_cell(screen: Vector2) -> Dictionary:
    if timeline.state.is_empty(): return {}
    var origin = camera.project_ray_origin(screen)
    var ray = camera.project_ray_normal(screen)
    if pick_heights_revision != timeline.world_revision:
        var heights = {}
        for tile in timeline.state.tiles.values(): heights[tile.elevation_steps] = true
        pick_heights = heights.keys(); pick_heights.sort(); pick_heights.reverse()
        pick_heights_revision = timeline.world_revision
    for height in pick_heights:
        var point: Variant = Plane(Vector3.UP,float(height)*Placement.HEIGHT_UNIT).intersects_ray(origin,ray)
        if point == null: continue
        var position = [roundi(point.x),roundi(point.z)]
        var tile: Dictionary = timeline.state.tiles.get(WorldRows.cell_key(position),{})
        if not tile.is_empty() and tile.elevation_steps == height: return {"position":position,"height":height}
    return {}

func _choose_world_option(option: Dictionary) -> void:
    if not command_ready(): return
    var admitted = Interaction.admitted(available_actions,option)
    if admitted.size() == 1:
        _execute_admitted(admitted[0])
    elif admitted.size() > 1:
        context_options = admitted.map(func(value):return {"admitted":value})
        _show_context(admitted.map(func(value):return value.action.display_name))
    else:
        var approach = Interaction.approach(available_actions,option)
        if approach.is_empty():
            notice_text = option.reason if option.get("reason") != null else "No affordable safe approach is available."
            return
        pending_approach = {"option":option.duplicate(true),"actor":available_actions.entity_uuid,"generation":available_actions.discovery_generation}
        _execute_admitted(approach,true)

func _continue_approach() -> void:
    if pending_approach.is_empty(): return
    if available_actions.entity_uuid != pending_approach.actor:
        pending_approach = {}; return
    if available_actions.discovery_generation == pending_approach.generation: return
    var original: Dictionary = pending_approach.option
    pending_approach = {}
    for option in Interaction.world_options(available_actions,original.subject_uuid):
        if not Interaction.same_option(original,option): continue
        var admitted = Interaction.admitted(available_actions,option)
        if admitted.size() == 1: _execute_admitted(admitted[0]); return
        notice_text = "Approach complete. Choose the interaction again."; return
    notice_text = "That interaction is no longer offered."

func _show_context(labels: Array) -> void:
    context_menu.clear()
    for i in range(labels.size()): context_menu.add_item(labels[i],i)
    context_menu.position = Vector2i(get_viewport().get_mouse_position())
    context_menu.popup()

func _context_chosen(index: int) -> void:
    if index < 0 or index >= context_options.size() or not command_ready(): return
    var option: Dictionary = context_options[index]
    if option.has("row"): select_action(option.row)
    elif option.has("inspect"): notice_text = option.inspect.label
    elif option.has("admitted"): _execute_admitted(option.admitted)
    else: _choose_world_option(option)

func activate_world_label(id: String) -> void:
    _world_click(_identity_hit(id))

func _identity_hit(id: String) -> Dictionary:
    for row in actor_rows + placements:
        if row.id != id: continue
        var label: String = id
        if timeline.state.actors.has(id): label = timeline.state.actors[id].name
        elif timeline.state.objects.has(id): label = str(timeline.state.objects[id].item.get("name",timeline.state.objects[id].item.item_id))
        return {"id":id,"kind":row.kind,"label":label,"position":row.position,"screen":camera.unproject_position(Placement.contact(row)+Vector3.UP*0.25)}
    return {}

func world_labels() -> Array:
    var result: Array = []
    var seen = {}
    for option in available_actions.get("world_interactions",[]):
        if seen.has(option.subject_uuid): continue
        seen[option.subject_uuid] = true
        var hit = _identity_hit(option.subject_uuid)
        if not hit.is_empty(): result.append(hit)
    return result

func _world_click(hit: Dictionary, alternative: bool = false) -> void:
    if not command_ready(): return
    if not selected_action.is_empty():
        choose_target(hit.get("position",[]),hit.get("id","")); return
    if hit.is_empty(): return
    var id: String = hit.get("id","")
    if id.is_empty():
        if not force_attack and not alternative: choose_target(hit.position)
        return
    if alternative and hit.kind == "actor":
        context_options = [{"inspect":hit}]
        _show_context([hit.label]); return
    if (hit.kind == "actor" or force_attack) and not alternative:
        var attack = Interaction.main_attack(available_actions,id,attack_preference)
        if not attack.is_empty(): _execute_admitted(attack)
        else: notice_text = hit.label + ": no legal " + ("ranged" if attack_preference=="RANGED_MAIN" else "melee") + " attack."
        return
    if not alternative and timeline.state.objects.get(id,{}).get("contained_items") != null:
        open_storage(id)
        return
    var options = Interaction.world_options(available_actions,id)
    if options.is_empty(): notice_text = hit.label; return
    var defaults: Array = options.filter(func(option):return option.default_priority == options[0].default_priority)
    if not alternative and defaults.size() == 1: _choose_world_option(defaults[0]); return
    context_options = options
    _show_context(options.map(func(option):return option.label))

func pick_world(screen: Vector2) -> Dictionary:
    # Ctrl deliberately targets the original native members, including hidden
    # ones. Ordinary clicks use only displayed opaque artwork.
    var forced: Dictionary = {}
    if force_attack:
        for i in range(wall_pick_order.size()-1,-1,-1):
            if _entry_contains(wall_pick_order[i],screen):
                forced = wall_pick_order[i]
                break
    for i in range(draw_order.size()-1,-1,-1):
        var entry: Dictionary = draw_order[i]
        if entry.role=="shadow" or not entry.node.visible: continue
        # Background batches cannot cover an actor. Interleaved individual
        # terrain can, and its original opaque pixels own ordinary picking.
        if entry.placement.kind=="terrain":
            if entry.has("batch_rows") or not _entry_contains(entry,screen): continue
            if not forced.is_empty(): return _identity_hit(forced.placement.id)
            return {"id":"","kind":"ground","label":"","position":entry.placement.position}
        if entry.has("wall_source"):
            if force_attack or entry.get("wall_opacity",1.0)<1.0: continue
        if not _entry_contains(entry,screen): continue
        if not forced.is_empty() and _entry_before(entry,forced): return _identity_hit(forced.placement.id)
        if entry.has("wall_picks"):
            var hit = _pick_wall_member(entry,_wall_relative_pixel(entry,screen))
            if not hit.is_empty(): return hit
            continue
        return _identity_hit(entry.placement.id)
    if not forced.is_empty(): return _identity_hit(forced.placement.id)
    var cell = pick_cell(screen)
    return {"id":"","kind":"ground","label":"","position":cell.position} if not cell.is_empty() else {}

func _wall_relative_pixel(entry: Dictionary, screen: Vector2) -> Vector2:
    var contact = Placement.contact(entry.placement)
    var origin = camera.unproject_position(contact)
    var pixels_per_unit = origin.distance_to(camera.unproject_position(contact+camera.basis.x))
    return (screen-origin)*Placement.PIXELS_PER_UNIT/pixels_per_unit

func _pick_wall_member(entry: Dictionary, relative: Vector2) -> Dictionary:
    for j in range(entry.wall_picks.size()-1,-1,-1):
        var pick: Dictionary = entry.wall_picks[j]
        var point = relative/pick.record.scale+v2(pick.record.pivot)
        if _environment_contains(pick.record,point,1): return _identity_hit(pick.row.id)
    return {}

func update_wall_visibility(refresh_sight: bool = true) -> void:
    _sync_scenery(false,refresh_sight)
    var started = Time.get_ticks_usec()
    var senses: Variant = timeline.state.get("senses")
    var geometry = _wall_geometry()
    var visible: Dictionary = scenery_visible_cells
    geometry.visible = visible
    FrameProfile.end_phase(profile,"wall_targets",started)
    var candidates_started = Time.get_ticks_usec()
    var faded = {}
    var choices = {}
    wall_support_candidates = 0
    wall_max_member_candidates = 0
    for source in wall_sources:
        for member in source.get("wall_members",[source]):
            var targets = _wall_member_targets(member,geometry)
            wall_support_candidates += targets.size()
            wall_max_member_candidates = maxi(wall_max_member_candidates,targets.size())
            if wall_mode!="solid" and targets.any(func(target):return visible.has(target.cell)):
                faded[member.id] = true
        choices[source.id] = WallReveal.variants(source,faded,wall_mode,scenery_visibility)
    faded_walls = faded.keys()
    for entry in wall_entries:
        var selection: Dictionary = choices[entry.wall_source.id]
        var alpha: float = selection.get(entry.wall_variant,0.0)
        var shown: bool = alpha>0.0 and entry.wall_source_visible
        if entry.node.visible != shown:
            entry.node.visible = shown
            static_order_dirty = true
            draw_order_dirty = true
            wall_mask_dirty = true
        if entry.get("wall_opacity",-1.0) != alpha:
            entry.wall_opacity = alpha
            entry.material.set_shader_parameter("wall_opacity",alpha)
        var masked = wall_mode=="translucent" and entry.role!="shadow"
        if entry.get("wall_mask_enabled") != masked:
            entry.wall_mask_enabled = masked
            entry.material.set_shader_parameter("wall_mask_enabled",masked)
    FrameProfile.end_phase(profile,"wall_candidates",candidates_started)
    wall_visibility_revision = timeline.revision
    wall_visible_cells = senses.get("visible",[]).duplicate(true) if senses != null else []
    _sort_draws()
    FrameProfile.end_phase(profile,"wall_visibility",started)

func _queue_wall_geometry_changes(changes: Dictionary) -> void:
    # A quarter can remain inactive through several source publications. Retain
    # the union of changed cells for each view until that view is inspected.
    for view in wall_geometry_views.values():
        view.pending_full = view.get("pending_full",false) or changes.full
        view.pending_objects = view.get("pending_objects",false) or not changes.objects.is_empty()
        if not view.has("pending_tiles"): view.pending_tiles = {}
        for cell in changes.tiles: view.pending_tiles[cell] = true

func _wall_geometry() -> Dictionary:
    if not wall_geometry_views.has(quarter):
        wall_geometry_views[quarter] = {"targets":{},"buckets":{},"versions":{},"revision":0,"candidates":{},"pending_full":true}
    var view: Dictionary = wall_geometry_views[quarter]
    var full: bool = view.get("pending_full",false)
    # Independently prepared views already have their own exact geometry.
    # An untracked source replacement still takes the complete refresh path.
    if view.get("generation",-1)!=world_generation and not view.has("pending_tiles"): full = true
    var cells: Dictionary = view.get("pending_tiles",{})
    var objects_changed: bool = view.get("pending_objects",false)
    view.generation = world_generation
    if not full and cells.is_empty() and not objects_changed: return view
    var tiles: Dictionary = timeline.presentation_state().tiles
    if full:
        for cell in view.targets: cells[cell] = true
        for cell in tiles: cells[cell] = true
    view.revision += 1
    for cell in cells:
        var target: Dictionary = view.targets.get(cell,{})
        var tile: Dictionary = tiles.get(cell,{})
        if not target.is_empty() and not tile.is_empty() and tile.elevation_steps==target.elevation and tile.position==target.position: continue
        if not target.is_empty():
            for bucket in target.buckets:
                view.buckets[bucket].erase(target)
                view.versions[bucket] = view.revision
            view.targets.erase(cell)
        if not tile.is_empty(): WallReveal.add_tile(view,tile,quarter)
    if full or objects_changed:
        var owners = {}
        for entry in static_entries:
            if entry.role=="shadow" or not entry.placement.kind in ["wall","cliff"]: continue
            owners[entry.placement.id] = true
            if entry.has("wall_source"):
                for member in entry.wall_source.get("wall_members",[entry.wall_source]): owners[member.id] = true
        for id in view.candidates.keys():
            if not owners.has(id): view.candidates.erase(id)
    view.pending_tiles = {}
    view.pending_full = false
    view.pending_objects = false
    return view

func _wall_member_targets(row: Dictionary, geometry: Dictionary) -> Array:
    return WallReveal.targets(row,geometry,quarter)

func toggle_attack_preference() -> void:
    attack_preference = "RANGED_MAIN" if attack_preference == "MELEE_MAIN" else "MELEE_MAIN"
    if not available_actions.is_empty(): attack_preferences[available_actions.entity_uuid] = attack_preference
    hover_key = []

func select_behavior(behavior: String) -> void:
    if not command_ready(): return
    var rows = Interaction.actions(available_actions).filter(func(row):return row.behavior_id==behavior and row.availability_status=="available")
    if rows.is_empty(): notice_text = "That action has no disclosed legal choice."; return
    if rows.size()==1: select_action(rows[0]); return
    context_options = rows.map(func(row):return {"row":row})
    _show_context(rows.map(func(row):return row.display_name))

func _entry_contains(entry: Dictionary, screen: Vector2) -> bool:
    var transform: Transform3D = entry.node.global_transform
    var normal = transform.basis.z.normalized()
    var intersection: Variant = Plane(normal,normal.dot(transform.origin)).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
    if intersection == null: return false
    var local: Vector3 = transform.affine_inverse()*intersection
    var mesh: QuadMesh = entry.node.mesh
    var uv = Vector2((local.x-mesh.center_offset.x)/mesh.size.x+0.5,0.5-(local.y-mesh.center_offset.y)/mesh.size.y)
    if uv.x < 0 or uv.y < 0 or uv.x >= 1 or uv.y >= 1: return false
    if entry.placement.kind == "actor":
        var frame: Vector4 = entry.material.get_shader_parameter("frame_uv")
        var source: Image = source_images[entry.texture_path]
        var pixel = Vector2i((frame.x+uv.x*frame.z)*source.get_width(),(frame.y+uv.y*frame.w)*source.get_height())
        if source.get_pixelv(pixel).a <= 0.05: return false
    else:
        return _environment_contains(entry.record,uv*entry.cell,entry.source_role)
    return true

func _environment_contains(record: Dictionary, point: Vector2, source_role: int) -> bool:
    var cell = v2(record.native_size)
    if point.x<0 or point.y<0 or point.x>=cell.x or point.y>=cell.y: return false
    var rect: Array = record.get("rect",[0,0,cell.x,cell.y])
    var colour: Color = source_images[record.path].get_pixelv(Vector2i(rect[0]+point.x,rect[1]+point.y))
    if colour.a <= 0.05: return false
    if source_role != 2:
        if record.has("hit_mask"):
            var mask: Dictionary = record.hit_mask
            if source_images[mask.path].get_pixelv(Vector2i(mask.rect[0]+point.x,mask.rect[1]+point.y)).r < 0.5: return false
        for role in record.get("roles",[]):
            if role.role == "ground_shadow" and pixel_selected(role.selection,point,colour): return false
    return true

func _update_hover() -> void:
    if hover_request >= 0 and session.responses.has(hover_request):
        var response: Dictionary = session.responses[hover_request]
        session.responses.erase(hover_request)
        session.retire_record(response)
        hover_request = -1
        if response.ok and hover_context.get("key") == hover_key and command_ready() and selected_action.is_empty():
            hover_preview = response.value.preview
    var now = Time.get_ticks_msec()
    if now < hover_due: return
    hover_due = now+100
    if hud.pointer_over_controls() or not command_ready() or not selected_action.is_empty():
        hover_hit = {}; hover_key = []; hover_preview = {}; return
    hover_hit = pick_world(get_viewport().get_mouse_position())
    var key = [hover_hit.get("id"),hover_hit.get("position"),Input.is_physical_key_pressed(KEY_SHIFT),action_revision,available_actions.discovery_generation,force_attack]
    if key == hover_key: return
    hover_key = key
    hover_preview = {}
    if hover_request >= 0: hover_key = []; return
    var value = {}
    if hover_hit.get("id","").is_empty():
        for row in available_actions.position_actions:
            if row.behavior_id != "action.move" or not row.variant_facets.any(func(f):return f.key=="movement" and f.value=="walking"): continue
            var target = Interaction.target(row.valid_targets,hover_hit.get("position",[]))
            if not target.is_empty(): value = {"action":row,"selection":Interaction.selection(row,[target.index],not key[2])}; break
    elif hover_hit.kind == "actor" or force_attack:
        value = Interaction.main_attack(available_actions,hover_hit.id,attack_preference)
    if value.is_empty(): return
    hover_context = {"key":key}
    hover_request = session.request("preview",{"actor_uuid":available_actions.entity_uuid,"state_revision":action_revision,
        "discovery_generation":available_actions.discovery_generation,"correlation_id":Session.uuid(),"selection":value.selection})

func _unhandled_input(event: InputEvent) -> void:
    var focus = get_viewport().gui_get_focus_owner()
    if focus is LineEdit or focus is TextEdit: return
    if event is InputEventKey and hud.owns_keyboard_focus(): return
    if event is InputEventMouse and hud.pointer_over_controls(event.position): return
    if event is InputEventKey and event.physical_keycode == KEY_CTRL:
        force_attack = event.pressed
        cancel_selection()
        action_revision = ""
    if event is InputEventKey and event.pressed and not event.echo:
        match event.physical_keycode:
            KEY_Q: request_view((requested_quarter if rotation_pending() else quarter)-1)
            KEY_E: request_view((requested_quarter if rotation_pending() else quarter)+1)
            KEY_G: grid_visible = not grid_visible
            KEY_Z:
                wall_mode = WALL_MODES[(WALL_MODES.find(wall_mode)+1)%WALL_MODES.size()]
                update_wall_visibility()
                hover_key = []
            KEY_P: timeline.paused = not timeline.paused
            KEY_ESCAPE: cancel_selection()
            KEY_BACKSPACE:
                if not selected_action.is_empty() and action_request < 0:
                    if not target_selection.extra_target_positions.is_empty(): target_selection.extra_target_positions.pop_back()
                    elif not target_selection.target_indices.is_empty(): target_selection.target_indices.pop_back()
                    _request_selection(false)
            KEY_X: toggle_attack_preference()
            KEY_M: cancel_selection(); selected_mode = "action.move"
            KEY_J: select_behavior("action.jump")
            KEY_R:
                if pending_request.get("kind") == "unresolved":
                    pending_request.kind = "receipt"
                    receipt_due = 0
            KEY_ENTER: confirm_selection()
            KEY_SPACE: end_turn()
            KEY_F8:
                if profile.recording: notice_text = FrameProfile.save(profile,get_viewport(),"live_player"); profile.recording = false
                else: profile.recording = true; profile.recorded.clear()
            KEY_F9: notice_text = FrameProfile.save(profile,get_viewport(),"live_player_history",false)
            KEY_F:
                var id: Variant = timeline.state.get("current_actor_uuid")
                if visual_actors.has(id): camera_focus = Placement.contact(visual_actors[id].row); position_camera()
    if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
        var plane = Plane(Vector3.UP,camera_focus.y)
        var here: Variant = plane.intersects_ray(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
        var prior: Variant = plane.intersects_ray(camera.project_ray_origin(event.position-event.relative),camera.project_ray_normal(event.position-event.relative))
        if here != null and prior != null: camera_focus += prior-here; position_camera()
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera.size = maxf(4,camera.size*0.9)
        if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera.size = minf(80,camera.size/0.9)
        if event.button_index == MOUSE_BUTTON_LEFT:
            _world_click(pick_world(event.position))
        if event.button_index == MOUSE_BUTTON_RIGHT:
            if not selected_action.is_empty() or not pending_approach.is_empty(): cancel_selection()
            else: _world_click(pick_world(event.position),true)

func _input(event: InputEvent) -> void:
    # Key releases must survive GUI focus changes. Spending/shortcuts remain
    # in unhandled input, but a consumed Ctrl release must never arm attacks.
    if event is InputEventKey and event.physical_keycode == KEY_CTRL and not event.pressed and force_attack:
        force_attack = false
        cancel_selection()
        action_revision = ""

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT and force_attack:
        force_attack = false
        cancel_selection()
        action_revision = ""

func pick_actor(screen: Vector2) -> String:
    for i in range(draw_order.size()-1,-1,-1):
        var entry: Dictionary = draw_order[i]
        if entry.placement.kind != "actor" or entry.role == "shadow" or not entry.node.visible: continue
        var transform: Transform3D = entry.node.global_transform
        var normal = transform.basis.z.normalized()
        var hit: Variant = Plane(normal,normal.dot(transform.origin)).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
        if hit == null: continue
        var local: Vector3 = transform.affine_inverse()*hit
        var mesh: QuadMesh = entry.node.mesh
        var uv = Vector2((local.x-mesh.center_offset.x)/mesh.size.x+0.5,0.5-(local.y-mesh.center_offset.y)/mesh.size.y)
        if uv.x < 0 or uv.y < 0 or uv.x >= 1 or uv.y >= 1: continue
        var frame: Vector4 = entry.material.get_shader_parameter("frame_uv")
        var image: Image = source_images[entry.texture_path]
        var pixel = Vector2i((frame.x+uv.x*frame.z)*image.get_width(),(frame.y+uv.y*frame.w)*image.get_height())
        if image.get_pixelv(pixel).a > 0.05: return entry.placement.id
    return ""

func _exit_tree() -> void:
    generated_shadows.close()
    source_lighting.clear_pages()
    native_light_atlas.close()
    if pending_world!=null: pending_world.join()
    session.close()
    MediaWarmup.close(media_warmup)
    # Retired nodes remain scene children, so ordinary tree teardown owns them.
    retiring_views = []

func presentation_diagnostics() -> Dictionary:
    var actors = {}
    for id in visual_actors:
        var visual: Dictionary = visual_actors[id]
        var bodies: Array = visual.entries.filter(func(entry):return entry.node.visible and entry.role != "shadow")
        var body: Variant = bodies[0].node.position if not bodies.is_empty() else null
        actors[id] = {"rig":visual.row.rig,"position":visual.row.position.duplicate(),"height":visual.row.base_height_steps,
            "clip":playbacks[id].clip,"source_seconds":playbacks[id].sample_seconds,"facing":visual.row.facing,
            "visible_layers":visual.entries.filter(func(entry):return entry.node.visible).size(),
            "rendered_position":[body.x,body.z] if body != null else null,
            "rendered_height":body.y/Placement.HEIGHT_UNIT if body != null else null,
            "visible_slots":visual.entries.filter(func(entry):return entry.node.visible).map(func(entry):return entry.actor_layer.slot),
            "source_paths":bodies.map(func(entry):return entry.texture_path)}
    return {"timeline":timeline.diagnostics(),"media":MediaWarmup.diagnostics(media_warmup),"actors":actors,"quarter":quarter,"retiring_views":retiring_views.size(),"retiring_nodes":retiring_node_count,"unresolved":unresolved.duplicate(),
        "errors":presentation_errors.duplicate(),"received":session.latest_sequence,"static_draws":static_entries.size()}
