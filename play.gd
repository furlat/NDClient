extends "res://presentation/sprite_sources.gd"
# Godot scene specialization: reuse the tested sprite/material helpers. This
# scene owns no offline movement, editor handlers, collision or game rules.
const Session = preload("res://presentation/session.gd")
const Timeline = preload("res://presentation/timeline.gd")
const Characters = preload("res://presentation/characters.gd")
const ActorConstruction = preload("res://presentation/actor_construction.gd")
const WorldRows = preload("res://presentation/world.gd")
const PlayerHUD = preload("res://play_hud.gd")
const GroundOverlay = preload("res://presentation/ground_overlay.gd")
var ground_overlay = GroundOverlay.new()
const Interaction = preload("res://presentation/interaction.gd")
const Choices = preload("res://sdk/choices.gd")
const Lighting = preload("res://presentation/native_source_lights.gd")
const GeneratedShadows = preload("res://presentation/canvas_shadows.gd")
const LightTable = preload("res://presentation/light_table.gd")
# CanvasModulate of the former receiving canvas; blood and effect pages keep 0.18.
const LIGHT_AMBIENT := 0.30
const GroundReceiving = preload("res://presentation/ground_receiving.gd")
const BackgroundRelease = preload("res://presentation/background_release.gd")
const NativeStartup = preload("res://presentation/native_source_startup.gd")
const BakedEffects = preload("res://presentation/baked_effect.gd")
var native_startup:Dictionary={"ready":false,"completed":0,"total":0,"elapsed_ms":0.0}
# Sources are scoped to actual disclosed interests; Studio supplies recorded cues.
var native_startup_plan:Variant=[]
var native_live_plan:Array=[]
var native_live_owners:Array=[]
var draw_rank_updates:int=0
# Optional placement fields grid_order.key reads besides position and height.
const ORDER_FIELDS := ["sort_position","sort_height_steps","layer","boundaries"]
var native_startup_requested_ms:float=0.0
var native_startup_background:bool=true
var generated_shadows = GeneratedShadows.new()
# Sprites light themselves from this table of the frame's canvas lights.
var light_table = LightTable.new()
var receiving_globals: Array = []
# Shader globals are process-wide: only the displayed world publishes them
# (Studio prepares candidate worlds alongside the displayed one).
var publishes_receiving := true
var ground_supports_revision := -1
var ground_supports_texture: ImageTexture
var ground_supports_rect := Vector4(0, 0, 1, 1)
var generated_shadow_ids: Array = []
var generated_shadow_entries: Array = []
const RenderSettings = preload("res://presentation/render_settings.gd")
var character_light_profile = RenderSettings.DEFAULT_PROFILE
var requested_character_light_profile = ""
var character_profile_pending_paths: Dictionary = {}
var media_normal_sets: Dictionary = {}
var character_profile_notice = ""
var fire_light_flicker = RenderSettings.DEFAULT_FIRE_LIGHT_FLICKER
var light_strength = RenderSettings.DEFAULT_LIGHT_STRENGTH
var light_cap_enabled = RenderSettings.DEFAULT_LIGHT_CAP_ENABLED
const PLAYER_ENVIRONMENT = preload("res://presentation/player_environment.tres")
const MediaWarmup = preload("res://presentation/media_warmup.gd")
const SelectionMedia = preload("res://presentation/selection_media.gd")
const ChoiceResources = preload("res://live/choice_resources.gd")
const WallReveal = preload("res://presentation/wall_reveal.gd")
const WALL_COVERAGE_SHADER = preload("res://presentation/wall_coverage.gdshader")
const QuarterView = preload("res://presentation/quarter_view.gd")
const WorldPreparation = preload("res://presentation/world_preparation.gd")
const Palette = preload("res://presentation/palette.gd")
const ComponentRenderer = preload("res://presentation/component_renderer.gd")
const Conditions = preload("res://presentation/conditions.gd")
const Tracks = preload("res://presentation/tracks.gd")
var component_renderer = ComponentRenderer.new()
var displayed_components: Array = []
var pending_world: Variant
var static_forecast:Dictionary={}
# Changes whenever a path enters or leaves `textures` (upload or prune).
var texture_revision:int=0
var prepared_actor_owner: Variant
var world_prepare_epoch = -1
var world_prepare_worker_phases:Dictionary={}
var world_prepared_count = 0
var actor_prepared_layers = 0
var world_prepare_worker_ms = 0.0
var world_generation = 0
var publication_failed:bool=false
var world_visual_rows: Array = []
var world_row_cache: Dictionary = {}
var world_changes: Dictionary = {}
var sampled_supports: Dictionary = {}
var scenery_new_consumers: Dictionary = {}
var scenery_wall_sources: Dictionary = {}
var scenery_batches: Array = []
var scenery_consumers: Dictionary = {}
var scenery_visible_cells: Dictionary = {}
var prepared_scenery: Dictionary = {}
var wall_sources: Array = []
var wall_entries: Array = []
var scenery_index_dirty := true
var scenery_index_count := -1
var scenery_generation := -1
var requested_quarter = -1
var pending_view: Variant
var rotation_publication_frame = -1
signal presentation_updated
var session: RefCounted
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
const PREPARATION_USEC=2000
const PREPARATION_NEAR_MS:=300.0
const PREPARATION_NEAR_USEC:=3000
const PREPARATION_DUE_MS:=150.0
const PREPARATION_DUE_USEC:=4000
const PREPARATION_HELD_USEC:=8000
var preparation_admission:Dictionary={"frame":-1,"used_usec":0,"limit_usec":PREPARATION_USEC,"phase_usec":{},"optional_order":[],"minimum_cleanup":0}
# Optional preparation is skipped in a frame whose script work already passed
# this, at most OPTIONAL_MAX_SKIPS frames in a row.
const OPTIONAL_FRAME_LIMIT_USEC := 7000
const OPTIONAL_MAX_SKIPS := 3
const OPTIONAL_OWNER_PHASES := ["optional_owner_world","optional_owner_components","optional_owner_media","optional_owner_retirement"]
var optional_skips := 0
var preparation_turn:int=0
var static_order: Array = []
var static_complete_order: Array = []
var static_sort_nodes: Dictionary = {}
var static_order_dirty = true
var static_order_count = -1
var prepared_static_order: Dictionary = {}
# Painter order of the moving participants (see _order_moving): the polled
# participants by slot, the ground UI list, and the gaps between visible
# statics with the draws they hold.
var order_moving: Array = []
var order_positions: PackedVector3Array = []
var order_nodes: Array = []
var order_keyed: PackedInt64Array = []
var order_shown: PackedByteArray = []
var order_ground: Array = []
var order_ground_source: Variant = null
var order_gaps: Array = []
var order_dirty_gaps: Dictionary = {}
var order_resized_gaps: Dictionary = {}
var order_statics: Variant = null
var order_quarter: int = -1
var order_background: bool = true
var order_forward: Vector3 = Vector3.ZERO
var order_generation: int = 0
var order_member_generation: int = 0
var order_serial: int = 0
var order_shown_changed: bool = false
var initial_focus = false
var selected_mode = "action.move"
var action_request = -1
var pending_request: Dictionary = {}
var available_actions: Dictionary = {}
var choices_boundary: Dictionary = {}
var pending_choices: Dictionary = {}
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
var hover_requests: Dictionary = {}
var hover_intent: Dictionary = {}
var hover_cursor = Input.CURSOR_ARROW
var hover_key: Array = []
var hover_due = 0
var normals_visible = false
var requested_normals_visible = false
var source_lighting = Lighting.new()
var light_revision = -1
var light_source_epoch = -1
var light_source_inputs: Variant = null
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
var selection_media = SelectionMedia.create()
# Native resources of the disclosed choices, warmed from the shared account.
var choice_resources = ChoiceResources.new()
var selection_media_hold_cursor = -1
var selection_media_demand_paths: Dictionary = {}
var selection_media_preview: Dictionary = {}
var maximum_texture_size_2d=0
var media_plan: Dictionary = {"required":{},"upcoming":{},"errors":[],"upcoming_errors":[]}
var media_plan_key: Array = []
var media_promoted_ids: Array = []
var media_initial_ready = false
var media_gate: Dictionary = {}
var media_metadata_ready = false
var media_metadata_ms = 0.0
var media_source_issue:String=""
var media_group_plans: Dictionary = {}
var media_interest:Dictionary={}
var displayed_source_records:Array=[]
var replay_media_groups: Array = []
var media_received_owners: Dictionary = {}
var media_empty_key: Array = []
var media_empty_plan: Dictionary = {}
var media_terminal_plan: Dictionary = {}
var media_requested_key: Array = []
var media_plan_epoch = -1
var media_environment_required: Dictionary = {}
var media_condition_key: Array = []
var media_condition_paths: Dictionary = {}
var media_condition_record:Dictionary={}
var native_media_paths:Dictionary={}
var native_media_cpu_paths:Dictionary={}
var native_media_record:Dictionary={}
var media_profile_record:Dictionary={}
const EMPTY_PATHS:Dictionary={}
# Last composed due set and the exact part maps it was built from (§5.5).
var media_due_current_parts:Array=[]
var media_due_current:Dictionary={}
var media_due_parts:Array=[]
var media_due:Dictionary={}
var native_spell_hit_material:bool=true
var draw_order_dirty = true
var wall_pick_order: Array = []
var wall_support_candidates = 0
var wall_max_member_candidates = 0
var wall_geometry_views: Dictionary = {}
var ground_is_background := true
var pick_heights_revision = -1
var pick_heights: Array = []
## Studio hosts this exact renderer in its own viewport and owns only transport/input.
var external_playback = false
## Offline multi-view transport owns advance; this host still prepares and renders.
var external_clock = false
var presentation_mutes: Dictionary={}
var presentation_solo: Dictionary={}
var playback_speed = 1.0
var playback_end_ms = INF

func install_playback(value: RefCounted) -> void:
    publication_failed=false
    value.initialization_revision = timeline.initialization_revision + 1
    _release_replay_media()
    timeline = value
    timeline.profile = profile
    timeline.source_cut_boundaries = external_playback
    timeline.media_ready = _media_ready
    timeline.replay_media_ready = _replay_media_ready
    timeline.replay_media_release = _release_replay_media
    timeline.world_ready = _world_ready
    timeline.world_published=_publish_source_cut
    actor_revision = -1
    light_revision = -1
    wall_visibility_revision = -1
    announced_ready = false

func try_reset_hidden_playback(value:RefCounted)->bool:
    # A bounded Studio spare may reuse source handles across different prefixes
    # of the same immutable recording. It must already be hidden and inaudible.
    if not external_playback or not is_inside_tree() or value==null or not value.paused or value.state.is_empty():return false
    if not timeline.paused or get_viewport().audio_listener_enable_3d:return false
    if not media_issue.is_empty() or not presentation_errors.is_empty():return false
    install_playback(value)
    _reset_playback_presentation()
    # Keep old native membership until the existing full preparation can replace
    # it. An old worker remains owned until its normal epoch gate retires it.
    world_prepare_epoch=-1;world_revision=-1
    scenery_revision=-1;scenery_world_revision=-1;scenery_generation=-1
    pick_heights_revision=-1
    _clear_static_view_cache()
    requested_quarter=quarter
    wall_geometry_views={}
    return true

func _reset_playback_presentation()->void:
    prepared_scenery={};prepared_static_order={}
    # Fresh transient owners/clocks must never inherit a previous seek's audio,
    # particles or submitted-frame evidence, despite retaining static geometry.
    frame_evidence=[];displayed_samples={};displayed_components=[]
    component_renderer.ensure_epoch(self);component_renderer.ready=false
    media_initial_ready=false;media_metadata_ready=false
    _reset_media_epoch();media_plan_key=[]

func can_publish_replay_advance(plan:Dictionary)->bool:
    if not external_playback or not external_clock or not timeline.replay_can_publish(plan):return false
    if not plan.boundary:return true
    return pending_world!=null and pending_world.prepared and pending_world.epoch==timeline.initialization_revision and pending_world.quarter==quarter and not timeline.pending_world.is_empty() and pending_world.boundary.preparation_key==timeline.pending_world.preparation_key

func publish_replay_advance(plan:Dictionary)->bool:
    if not can_publish_replay_advance(plan):return false
    if plan.boundary:
        if not pending_world.can_publish_membership(int(pending_world.boundary.world_revision)):return false
        pending_world.admitted=true
    return timeline.replay_publish(plan)

func playback_prepared() -> bool:
    var group: Dictionary = timeline.current if not timeline.current.is_empty() else (timeline.queue[0] if not timeline.queue.is_empty() else {})
    return not timeline.state.is_empty() and world_prepare_epoch == timeline.initialization_revision and world_revision == timeline.world_revision and _media_ready(group) and not timeline.waiting_for_world and component_renderer.ready

func attach_media_sources() -> void:
    var owner:Dictionary=MediaWarmup.bind_host(media_warmup,self)
    textures=owner.textures;source_images=owner.source_images
    texture_last_use=owner.texture_last_use
    fixture_frame_energy=owner.fixture_frame_energy;fixture_frame_centroids=owner.fixture_frame_centroids
    if not owner.has("preparation_admission"):owner.preparation_admission=preparation_admission
    preparation_admission=owner.preparation_admission

func _ready() -> void:
    attach_media_sources()
    var owner:Dictionary=MediaWarmup.physical(media_warmup)
    var device=RenderingServer.get_rendering_device()
    if device!=null:maximum_texture_size_2d=device.limit_get(RenderingDevice.LIMIT_MAX_TEXTURE_SIZE_2D)
    owner.maximum_texture_size=maximum_texture_size_2d
    owner.worker_upload=device!=null and DisplayServer.get_name()!="headless"
    # Studio installs an already admitted Timeline. It has no live connection,
    # journal or protocol admission work to initialize for each hidden host.
    if not external_playback and session == null: session = Session.new()
    var settings = RenderSettings.read()
    character_light_profile = settings.profile
    media_warmup.light_profile = character_light_profile
    native_spell_hit_material = settings.native_spell_hit_material
    fire_light_flicker = settings.fire_light_flicker
    source_lighting.fire_light_flicker = fire_light_flicker
    light_strength = settings.light_strength
    source_lighting.light_strength = light_strength
    if settings.error != OK: presentation_errors.append("Cannot read local rendering settings: "+error_string(settings.error))
    # Shaders a reveal may meet first mid-play: a material compiles its shader.
    for shader in [ENVIRONMENT_SHADER,WATER_SHADER,FIXTURE_FLAME_SHADER,ActorConstruction.MODULAR_SHADER,GroundOverlay.SHADER,GroundOverlay.ROUTE]:
        var material:=ShaderMaterial.new();material.shader=shader
    light_cap_enabled = settings.light_cap_enabled
    generated_shadows.attach(self)
    timeline.profile = profile
    timeline.source_cut_boundaries = external_playback
    timeline.media_ready = _media_ready
    timeline.replay_media_ready = _replay_media_ready
    timeline.replay_media_release = _release_replay_media
    timeline.world_ready = _world_ready
    timeline.world_published=_publish_source_cut
    if not external_playback: timeline.retire_group = session.retire_group
    RenderingServer.frame_post_draw.connect(_record_frame_evidence)
    if not external_playback: DisplayServer.window_set_title("NDClient · Live player · Wall composition & frame profiling")
    RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
    var catalog = Catalog.read_file("catalog-index.json",catalog_cache)
    rig_config = Catalog.read_file(catalog.rig,catalog_cache)
    rigs = Characters.rigs(catalog_cache)
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
    # Every worker uses the host's admitted authoring revision. A Studio seek
    # reuses its indexed snapshot; Reload supplies a new source owner.
    # Seed before starting workers; never mutate their cache shells afterward.
    media_warmup.plan_cache = Catalog.source_snapshot(catalog_cache)
    if session != null: session.authoring_cache = Catalog.source_snapshot(catalog_cache)
    if not external_playback:
        hud = PlayerHUD.new()
        hud.world = self
        var canvas = CanvasLayer.new()
        add_child(canvas)
        canvas.add_child(hud)
    grid_visible = true
    if external_playback: return
    session.deliver_compiled_operations=true
    component_renderer.source_group_ready=_source_group_ready
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
    if notice_text==character_profile_notice:notice_text=""
    character_profile_notice=""
    requested_character_light_profile="" if profile_name==character_light_profile else profile_name
    character_profile_pending_paths=_requested_profile_normals(profile_name) if not requested_character_light_profile.is_empty() else {}
    media_plan_key=[]
    _poll_character_light_profile()
    if not requested_character_light_profile.is_empty():
        character_profile_notice="Preparing %s lighting; %s remains active." % [RenderSettings.PROFILES[profile_name],RenderSettings.PROFILES[character_light_profile]]
        if notice_text.is_empty():notice_text=character_profile_notice
    return true

func _requested_profile_normals(profile_name: String) -> Dictionary:
    var sets: Dictionary=media_normal_sets.duplicate()
    for entry in actor_entries:
        var path: String=entry.get("texture_path","")
        if path.is_empty() or entry.get("generated_shadow",false):continue
        var normals=CharacterGeometry.normal_paths(path,entry.actor_layer.slot,catalog_cache)
        if normals.ok and not normals.value.is_empty():sets[path]=normals.value
    var paths={}
    for profiles in sets.values():
        if profiles.has(profile_name):paths[profiles[profile_name]]=true
    return paths

func _save_character_light_profile(profile_name: String) -> Error:
    return RenderSettings.write(profile_name)

func _poll_character_light_profile() -> void:
    if requested_character_light_profile.is_empty():return
    for path in character_profile_pending_paths:
        if media_warmup.failed.has(path):
            notice_text="Cannot prepare lighting: "+str(media_warmup.failed[path])
            requested_character_light_profile="";character_profile_pending_paths={};character_profile_notice="";media_plan_key=[]
            return
    if not media_metadata_ready or not character_profile_pending_paths.keys().all(func(path):return textures.get(path)!=null):return
    var profile_name: String=requested_character_light_profile
    character_light_profile = profile_name
    requested_character_light_profile="";character_profile_pending_paths={};media_plan_key=[]
    # The optional library follows the profile in use.
    media_warmup.light_profile = profile_name
    if not media_warmup.optional_last.is_empty() and media_warmup.optional_pending.is_empty():
        media_warmup.optional_pending = media_warmup.optional_last.duplicate()
    var error = _save_character_light_profile(profile_name)
    if error != OK: notice_text = "Setting applied; cannot save it: "+error_string(error)
    elif notice_text==character_profile_notice:notice_text=""
    character_profile_notice=""

func set_native_spell_hit_material(enabled:bool)->void:
    native_spell_hit_material=enabled
    var error=RenderSettings.write_spell_hit_material(enabled)
    if error!=OK:notice_text="Setting applied; cannot save it: "+error_string(error)

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

func set_light_cap_enabled(enabled: bool) -> void:
    light_cap_enabled = enabled
    var error = RenderSettings.write_light_cap(enabled)
    if error != OK: notice_text = "Setting applied; cannot save it: "+error_string(error)

func _preparation_budget()->Dictionary:
    if preparation_admission.frame!=Engine.get_process_frames():
        preparation_admission.frame=Engine.get_process_frames()
        preparation_admission.limit_usec=_preparation_limit()
        preparation_admission.used_usec=0;preparation_admission.phase_usec={}
        preparation_admission.background_source_handoffs=0
        preparation_admission.optional_order=[];preparation_admission.minimum_cleanup=0
        preparation_admission.required_legacy_constructors=0
    return preparation_admission

## The allowance grows only for a world due soon: a few slower frames before
## its cue instead of a held clock at it (live play; Studio shares a fixed one).
func _preparation_limit()->int:
    if external_playback or pending_world==null or pending_world.prepared or pending_world.initial:return PREPARATION_USEC
    if timeline.waiting_for_world:return PREPARATION_HELD_USEC
    var until_ms:float=float(pending_world.boundary.get("display_ms",INF))-timeline.display_ms
    if until_ms<=PREPARATION_DUE_MS:return PREPARATION_DUE_USEC
    return PREPARATION_NEAR_USEC if until_ms<=PREPARATION_NEAR_MS else PREPARATION_USEC

func _charge_preparation(name:String,started:int,charged_before:int)->void:
    var budget:Dictionary=_preparation_budget()
    var elapsed:int=Time.get_ticks_usec()-started
    budget.used_usec+=maxi(0,elapsed-(budget.used_usec-charged_before))
    # Per-phase durations include nested calls; used_usec alone is exclusive.
    budget.phase_usec[name]=budget.phase_usec.get(name,0)+elapsed

func _native_startup_request(at_ms:float,optional:bool=false)->Dictionary:
    if external_playback:
        return {"plan":native_startup_plan,"required":NativeStartup.requested(native_startup_plan,at_ms),
            "priority":NativeStartup.requested(native_startup_plan,at_ms,ComponentRenderer.NATIVE_PREFETCH_MS),"optional":optional}
    var selected:Dictionary=selection_media.get("value",{}).get("native_selection",{})
    var owners:Array=[timeline.initialization_revision,timeline.current.get("id",""),timeline.queue.map(func(group):return group.id),selection_media.revision]
    if owners!=native_live_owners:
        native_live_owners=owners
        var clips:Array=NativeStartup.Authoring.effect_clips(selected)
        var groups:Array=timeline.queue.duplicate()
        if not timeline.current.is_empty():groups.push_front(timeline.current)
        for group in groups:
            for component in group.get("components",[])+group.get("native_requirements",[]):
                if component.get("native_spell",false) and component.get("status")!="missing":clips.append(component.native_clip)
                elif component.get("kind")=="material_flash" and component.get("native_hit",{}).get("definition",{}).get("status")=="available":clips.append(component.native_hit.clip)
        native_live_plan=NativeStartup.source_plan(clips,NativeStartup.Effects.lifecycle_clips())
    # Live occurrence readiness belongs to ComponentRenderer's exact cue. This
    # optional program interest cannot gate unrelated idle/movement or late cues.
    # Every condition lifecycle the package has warms with the load (any
    # condition can apply later; its first draw is too costly mid-play).
    return {"plan":native_live_plan,"required":native_live_plan.filter(func(item):return item.lifecycle),"priority":native_live_plan,"optional":optional}

func _step_native_startup(optional:bool=false)->void:
    if optional and not native_startup_background:return
    var at_ms:float=maxf(timeline.display_ms,native_startup_requested_ms)
    native_startup=NativeStartup.step(self,catalog_cache,_native_startup_request(at_ms,optional),_preparation_budget())

func _native_startup_ready(at_ms:float)->bool:
    native_startup_requested_ms=at_ms
    native_startup=NativeStartup.status(_native_startup_request(at_ms))
    return native_startup.ready

func _prepare_optional_work()->void:
    var budget:Dictionary=_preparation_budget()
    var section:int=Time.get_ticks_usec()
    # A producer may finish while this frame draws the retained display. Adopt
    # its passive handoff now so native preparation need not start a frame late.
    if _receive_prepared_operations():
        _prepare_future_world()
        _prepare_media()
        _warm_media(true,budget,timeline.media_target_ms)
    FrameProfile.end_phase(profile,"optional_received",section);section=Time.get_ticks_usec()
    var required_world:bool=timeline.waiting_for_world or _world_preparation_due(0.0)
    # Visible pending controls share the host allowance ahead of speculative
    # uploads. Otherwise a steady optional backlog can starve the bar forever.
    if hud!=null and hud.bar_pending():hud.prepare_bar()
    # The next received world cut is a real future consumer, not unrelated
    # speculative work. Current required effects and uploads ran above; spend
    # their remainder on this cut before optional later effects/retirement.
    _step_world_preparation()
    FrameProfile.end_phase(profile,"optional_world",section);section=Time.get_ticks_usec()
    # Rotate only the first existing owner. The queues and readiness contracts
    # stay where they were; empty owners leave their allowance to the next one.
    var first:int=preparation_turn;preparation_turn=(preparation_turn+1)%4
    for offset in 4:
        if budget.used_usec>=budget.limit_usec:break
        var owner:int=(first+offset)%4
        budget.optional_order.append(owner)
        var owner_started:int=Time.get_ticks_usec()
        match owner:
            0:continue # The existing world owner already used its remainder.
            1:
                # A due world owns this allowance ahead of future effect
                # constructors, including while its passive worker is running.
                if required_world and pending_world!=null and not pending_world.prepared:continue
                var started:int=Time.get_ticks_usec();var before:int=budget.used_usec
                if native_startup_plan!=null:_step_native_startup(true)
                component_renderer.prepare_optional(self,catalog_cache,budget)
                if not external_playback:choice_resources.prepare(catalog_cache,budget)
                # Spare shadow helpers, so a reveal's new actors construct none.
                if generated_shadows.spares_needed():generated_shadows.prepare_spares(budget.limit_usec-budget.used_usec-(Time.get_ticks_usec()-started))
                _charge_preparation("optional_components",started,before)
            2:_warm_media(false,budget)
            3:
                _prune_character_media(budget)
                _dispose_views(budget)
        FrameProfile.end_phase(profile,OPTIONAL_OWNER_PHASES[owner],owner_started)
    FrameProfile.end_phase(profile,"optional_owners",section);section=Time.get_ticks_usec()
    # A requested rotation cannot release its previous view without cleanup.
    # Permit one existing cleanup unit under that explicit memory blocker;
    # charge the overrun rather than pretending it fitted the allowance.
    if rotation_pending() and not retiring_views.is_empty():_dispose_views(budget,true)
    var stats:Dictionary=MediaWarmup._residency_stats(media_warmup)
    var bytes:int=stats[false].estimated_bytes+stats[true].estimated_bytes
    var pinned:int=stats[false].pinned_bytes+stats[true].pinned_bytes
    if bytes>maxi(pinned,MediaWarmup.physical(media_warmup).budget_bytes):_prune_character_media(budget,true)
    FrameProfile.end_phase(profile,"optional_residency",section)

func _receive_prepared_operations()->bool:
    if session==null:return false
    var messages:Array=session.take_prepared()
    for message in messages:
        if message.get("stage","")!="media":
            timeline.accept(message)
            if message.get("stage","")=="compiled":
                _reset_media_epoch()
                Catalog.adopt_snapshot(catalog_cache,message.source_files)
                for group in message.groups.slice(0,mini(2,message.groups.size())):media_received_owners[group.id]=group
                media_plan_key=[]
        _adopt_received_media(message)
    return not messages.is_empty()

func _advance_prepared(delta_ms:float)->void:
    var target:float=timeline.display_ms+maxf(0.0,delta_ms)
    timeline.advance(delta_ms)
    if not timeline.waiting_for_world and not timeline.waiting_for_media:return
    # A bounded second handoff drains work completed during the first readiness
    # call. Never join an unfinished worker or accrue waiting time as animation.
    var received:bool=_receive_prepared_operations()
    var media:Dictionary=MediaWarmup.poll_plan(media_warmup)
    if not media.is_empty():_adopt_media_plan(media)
    if received or not media.is_empty():
        _prepare_future_world()
        _prepare_media()
        _warm_media(true,_preparation_budget(),target)
    if timeline.waiting_for_world:_step_world_preparation()
    if received or not media.is_empty() or (pending_world!=null and pending_world.prepared):
        timeline.advance(maxf(0.0,target-timeline.display_ms))

func _process(delta: float) -> void:
    if publication_failed:return
    var budget:Dictionary=_preparation_budget()
    var advance_ms=delta*1000*playback_speed
    if external_playback:advance_ms=minf(advance_ms,maxf(0,playback_end_ms-timeline.display_ms))
    var started = Time.get_ticks_usec()
    var phase = Time.get_ticks_usec()
    var subphase = Time.get_ticks_usec()
    if external_playback:_step_native_startup()
    for issue in native_startup.get("errors",[]):
        if issue not in presentation_errors:presentation_errors.append(issue)
    FrameProfile.end_phase(profile,"native_startup",subphase)
    subphase = Time.get_ticks_usec()
    if not external_playback: session.poll()
    FrameProfile.end_phase(profile,"session_poll",subphase)
    subphase = Time.get_ticks_usec()
    _receive_prepared_operations()
    # Passive projection runs concurrently with source-role publication, not
    # behind it. It borrows the already accepted compiler/source references.
    _prepare_future_world()
    _adopt_media_plan(MediaWarmup.poll_plan(media_warmup))
    # Adopt finished projection and its exact pins before publishing demand.
    # Required uploads get first use of the shared allowance; hidden native
    # construction uses its remainder below, including source-decode waits.
    if _world_preparation_due(advance_ms):_step_world_preparation(true)
    _prepare_media()
    FrameProfile.end_phase(profile,"preparation_step",subphase)
    # Receive the new source interests before spending this frame's allowance.
    # An older optional/due set must not take priority over an arrived action.
    subphase = Time.get_ticks_usec()
    _warm_media(true,budget,timeline.display_ms+maxf(0,advance_ms))
    FrameProfile.end_phase(profile,"media_publication",subphase)
    subphase = Time.get_ticks_usec()
    _prepare_initial_world()
    _prepare_future_world()
    # Future received worlds share the rotating preparation allowance with
    # effects. Only an initial/due world gets priority before playback; taking
    # every frame for a later impact starves the earlier windup constructor.
    if _world_preparation_due(advance_ms) and (not timeline.waiting_for_media or media_gate.get("native",true)):_step_world_preparation()
    FrameProfile.end_phase(profile,"preparation_step",subphase)
    subphase = Time.get_ticks_usec()
    if not external_playback: _poll_actions()
    FrameProfile.end_phase(profile,"action_responses",subphase)
    subphase = Time.get_ticks_usec()
    if not external_clock:_advance_prepared(advance_ms)
    FrameProfile.end_phase(profile,"timeline_advance",subphase)
    if session != null: session.set_displayed_sequence(timeline.sequence)
    # Extra effect variants load only between actions, never into a cast.
    BakedEffects.background_allowed=timeline.current.is_empty() and timeline.queue.is_empty()
    FrameProfile.end_phase(profile,"session_timeline",phase)
    var world_available:bool=not timeline.state.is_empty() and world_prepare_epoch==timeline.initialization_revision and (world_revision>=0 or (pending_world!=null and pending_world.epoch==timeline.initialization_revision and pending_world.initial and pending_world.prepared))
    var can_publish_world:bool=world_available and _playback_environment_ready() and _world_can_publish()
    # A rejected initial candidate has no displayed actor owner yet. Keep
    # preparation and UI running, but do not sample its private world.
    if world_available and (world_revision>=0 or can_publish_world):
        var supports = timeline.staged_tiles().keys()
        if can_publish_world and (timeline.world_revision != world_revision or sampled_support_ids != supports or (pending_world!=null and pending_world.admitted)):
            phase = Time.get_ticks_usec()
            _sync_world()
            FrameProfile.end_phase(profile,"world_sync",phase)
            if publication_failed:return
            world_revision = timeline.world_revision
            sampled_support_ids = supports
        if light_revision != timeline.revision:
            phase = Time.get_ticks_usec()
            _sync_source_lighting()
            FrameProfile.end_phase(profile,"source_lighting_resolve",phase)
        subphase = Time.get_ticks_usec()
        displayed_samples = timeline.actor_samples()
        displayed_components=timeline.component_samples(catalog_cache).filter(func(component):return not presentation_mutes.has(component.id) and (presentation_solo.is_empty() or presentation_solo.has(component.id)))
        FrameProfile.end_phase(profile,"displayed_samples",subphase)
        phase = Time.get_ticks_usec()
        _sync_actors()
        if publication_failed:return
        FrameProfile.end_phase(profile,"actor_sync",phase)
        phase = Time.get_ticks_usec()
        component_renderer.pending_evidence.clear()
        subphase = Time.get_ticks_usec()
        component_renderer.decorate(self,displayed_components)
        FrameProfile.end_phase(profile,"actor_decorate",subphase)
        subphase = Time.get_ticks_usec()
        _sample_actors()
        FrameProfile.end_phase(profile,"actor_sprite_sample",subphase)
        subphase = Time.get_ticks_usec()
        component_renderer.sample(self,displayed_components,delta,budget)
        FrameProfile.end_phase(profile,"component_sample",subphase)
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
                update_wall_visibility(false,false)
            wall_visibility_revision = timeline.revision
        _prepare_rotation()
        phase = Time.get_ticks_usec()
        _sync_native_lighting()
        FrameProfile.end_phase(profile,"native_2d_lighting",phase)
        # Wall member selection precedes the final painter order and coverage mask.
        phase = Time.get_ticks_usec()
        subphase = Time.get_ticks_usec()
        _sort_draws()
        FrameProfile.end_phase(profile,"draw_sort",subphase)
        subphase = Time.get_ticks_usec()
        component_renderer.native_spells.sync(self)
        component_renderer.ready=component_renderer.ready and component_renderer.native_spells.ready
        _retain_displayed_sources()
        FrameProfile.end_phase(profile,"native_2d_output",subphase)
        FrameProfile.end_phase(profile,"draw_order",phase)
        phase = Time.get_ticks_usec()
        if not external_playback:
            _discover()
            _poll_storage()
            _update_hover()

        _capture_frame_evidence()
        FrameProfile.end_phase(profile,"interaction",phase)
        if not external_playback and not announced_ready and command_ready():
            announced_ready = true
            print("PLAYER_READY: initialized, acknowledged, and current choices available")
    phase = Time.get_ticks_usec()
    if external_playback:_prepare_optional_work.call_deferred()
    elif phase-started<OPTIONAL_FRAME_LIMIT_USEC or optional_skips>=OPTIONAL_MAX_SKIPS:
        optional_skips=0
        _prepare_optional_work()
    else:
        # This frame already did its heavy work (a world publication, a burst
        # of sampling); speculative work waits a frame instead of extending it.
        # The next received world cut is not speculative: keep preparing it.
        optional_skips+=1
        _step_world_preparation()
    FrameProfile.end_phase(profile,"optional_preparation",phase)
    if not media_issue.is_empty():
        var preparing: Dictionary = timeline.current if not timeline.current.is_empty() else (timeline.queue[0] if not timeline.queue.is_empty() else {})
        if not preparing.is_empty(): timeline.record_preparation_issue(preparing.id,media_issue)
    if not native_startup.ready and native_startup.errors.is_empty():
        notice_text = "Preparing spell and condition effects: %d / %d" % [native_startup.completed,native_startup.total]
    elif media_metadata_ready and not MediaWarmup.boot_ready(media_warmup):
        var progress = MediaWarmup.preload_progress(media_warmup)
        notice_text = "Preparing visible assets: %d / %d" % [progress.startup_ready,progress.startup_required]
    elif notice_text.begins_with("Preparing visible assets:") or notice_text.begins_with("Preparing spell and condition effects:"): notice_text = ""
    if session != null and not session.issue.is_empty(): notice_text = session.issue.message
    elif not media_issue.is_empty(): notice_text = media_issue
    elif session != null and not session.status_issue.is_empty(): notice_text = "Reconnecting to encounter status…"
    if session != null and not session.issue.is_empty() and str(session.issue) != reported_session_issue:
        reported_session_issue = str(session.issue)
        push_error("PLAYER_CONNECTION_FAILED: " + session.issue.message)
    FrameProfile.end_phase(profile,"player_process",started)
    var active_motion=false
    for sample in displayed_samples.values():
        if sample.get("from_position")!=null and sample.get("to_position")!=null and sample.get("position")!=sample.to_position:
            active_motion=true; break
    var frame_context = {"scene":"live_player","active_motion":active_motion,
        "motion_held":timeline.waiting_for_media or timeline.waiting_for_world or timeline.paused,
        "displayed_sequence":timeline.sequence,"profile_stage":profile.label}
    if profile.recording:
        var diagnostics_started = Time.get_ticks_usec()
        frame_context = _detailed_frame_context(active_motion)
        FrameProfile.end_phase(profile,"diagnostics",diagnostics_started)
    FrameProfile.frame(profile,get_viewport(),frame_context)
    if hud != null: hud.queue_redraw()
    presentation_updated.emit()

func _detailed_frame_context(active_motion: bool) -> Dictionary:
    return {"media_gate":media_gate,"active_motion":active_motion,"motion_held":timeline.waiting_for_media or timeline.waiting_for_world or timeline.paused,"light_cap_enabled":light_cap_enabled,"scene":"live_player","zoom":camera.size,"quarter":quarter,
        "static_forecast":({"task_pending":static_forecast.task>=0,"target_ms":static_forecast.boundary.display_ms,
            "worker_ms":static_forecast.output.get("worker_ms",0.0) if static_forecast.task<0 else 0.0} if not static_forecast.is_empty() else {}),
        "world_preparation":({"boundary_jobs":pending_world.boundary_jobs.size(),"upserts":pending_world.membership.get("upserts",[]).size(),"removals":pending_world.membership.get("removed",{}).size(),
            "environment_batches":pending_world.environment_output.get("batches",0),"environment_submitted":pending_world.environment_capture_cursor,
            "environment_ready_rows":pending_world.environment_output.get("rows",{}).size(),"environment_task_pending":pending_world.environment_task>=0,
            "actor_worker_profile":pending_world.result.get("actor_worker_profile",{}),
            "blocked_actor":pending_world.blocked_actor.duplicate(),"blocked_source":pending_world.blocked_source.duplicate(),
            "worker_phases":pending_world.result.get("worker_phases",{}).duplicate(),
            "object_work":pending_world.object_work_counts.duplicate(),
            "environment_paths":pending_world.result.get("environment_paths",{}).keys(),
            "native_phase_usec":pending_world.phase_usec.duplicate(),
            "actor_binding_cursor":pending_world.binding_cursor,"actor_binding_total":pending_world.actor_bindings.size(),
            "actor_binding_path":pending_world.actor_bindings[pending_world.binding_cursor].value.get("path","") if pending_world.binding_cursor<pending_world.actor_bindings.size() else "",
            "blood_rows":pending_world.result.get("blood_rows",{}).size(),"blood_handles":pending_world.blood_preparation.handles.size(),
            "retained_lights":pending_world.light_preparation.get("retained",false)} if pending_world!=null else {}),
        "native_startup":{"ready":native_startup.ready,"completed":native_startup.completed,"total":native_startup.total,"elapsed_ms":native_startup.elapsed_ms},
        "generated_shadows":generated_shadows.diagnostics(),"light_table":{"lights":light_table.count,"uploads":light_table.uploads},
        "native_spell_render_ms":component_renderer.native_spells.render_timings(),
        "native_support_sync":component_renderer.native_spells._support.last_sync_phases if component_renderer.native_spells._support!=null else {},
        "actor_sample_counts":profile.get("actor_sample_counts",{}),
        "media_settle":_media_settle_diagnostics(),
        "actor_membership_counts":profile.get("actor_membership_counts",{}),
        "scenery_sample_counts":profile.get("scenery_sample_counts",{}),
        "world_prepare_worker_phases":world_prepare_worker_phases,
        "rotation_pending":rotation_pending(),"requested_quarter":requested_quarter,"cached_quarters":static_views.size(),"retiring_views":retiring_views.size(),"retiring_nodes":retiring_node_count,"world_generation":world_generation,"world_preparing":pending_world!=null,"world_prepare_phase":pending_world.phase if pending_world!=null else "idle","world_prepared_count":world_prepared_count,"actor_prepared_layers":actor_prepared_layers,"world_prepare_worker_ms":world_prepare_worker_ms,"world_waiting":timeline.waiting_for_world,"preparation_admission":preparation_admission.duplicate(true),"session_execution":session.diagnostics() if session != null else {},"displayed_sequence":timeline.sequence,"consumed_sequence":session.latest_sequence if session != null else -1,"queued_groups":timeline.queue.size(),
        "profile_stage":profile.label,"wall_mode":wall_mode,"wall_support_candidates":wall_support_candidates,"wall_max_member_candidates":wall_max_member_candidates,
        "wall_mask_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(wall_mask_viewport.get_viewport_rid()) if wall_mask_viewport!=null and wall_mode=="translucent" else 0.0,
        "wall_mask_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(wall_mask_viewport.get_viewport_rid()) if wall_mask_viewport!=null and wall_mode=="translucent" else 0.0,"textures":textures.size(),"media_pending":media_warmup.pending.size(),"encounter_preload":MediaWarmup.preload_progress(media_warmup),"preload_ready":media_warmup.boot_complete,"character_media":MediaWarmup.diagnostics(media_warmup),"environment_media":MediaWarmup.diagnostics(media_warmup,true),"media_metadata_ms":media_metadata_ms,"media_metadata_pending":media_warmup.plan_task>=0,"media_waiting":timeline.waiting_for_media,"actors":actor_rows.size(),"placements":placements.size(),"draws":static_entries.size()+actor_entries.size()}

func _media_settle_diagnostics()->Dictionary:
    # Recording-only: why optional maintenance and due composition did or did
    # not settle this frame. Counters reset after each recorded frame.
    var owner:Dictionary=MediaWarmup.physical(media_warmup)
    var publication:Dictionary=owner.selection_publication
    var result:Dictionary={"changed_paths":owner.changed_paths.size(),"pending_paths":owner.pending_paths.size(),
        "selection_task":owner.selection_task,"publication":[publication.get("cursor",-1),publication.get("paths",[]).size()],
        "applied_revision":owner.selection_applied_revision,"selection_revision":owner.selection_revision,
        "families_pending":MediaWarmup._families_pending(owner),"families":owner.families.size(),
        "due_reused":profile.get("media_due_reused",0),"due_rebuilt":profile.get("media_due_rebuilt",0),
        "due_current_changes":profile.get("media_due_current_changes",[]),
        "unsettled_families":owner.families.filter(func(row):return row.cursor!=(row.paths.size() if row.users>0 else 0)).map(func(row):return [row.users,row.hint,row.cursor,row.paths.size()]),
        "changed_sample":owner.changed_paths.keys().slice(0,3)}
    profile.media_due_reused=0;profile.media_due_rebuilt=0;profile.media_due_current_changes=[]
    return result

func _prepare_initial_world() -> void:
    if timeline.state.is_empty(): return
    _poll_static_forecast()
    if world_prepare_epoch!=timeline.initialization_revision:
        if not static_forecast.is_empty() and static_forecast.task>=0:return
        if pending_world!=null:
            if not pending_world.worker_finished(): return
            _discard_world_preparation()
        world_prepare_epoch = timeline.initialization_revision
        world_revision = -1
    if world_revision>=0 or pending_world!=null or not _environment_sources_ready(): return
    var candidate = {"key":["initial",timeline.initialization_revision],"state":timeline.state,
        "presentation_state":timeline.presentation_state(),"world_revision":timeline.world_revision,
        "display_ms":timeline.display_ms,"staged_actors":timeline.staged_actors(),
        "actor_samples":timeline.actor_samples(),"actor_layers":timeline.actor_layer_samples(),
        "changes":{"full":true,"tiles":{},"objects":{},"senses":true}}
    pending_world = WorldPreparation.new(); add_child(pending_world)
    pending_world.configure(self,candidate,true)

func _prepare_future_world() -> void:
    _poll_static_forecast()
    if world_revision<0 or world_prepare_epoch!=timeline.initialization_revision: return
    if pending_world!=null and (pending_world.initial or pending_world.admitted): return
    var candidate: Dictionary = timeline.preview_world()
    if pending_world!=null:
        if not candidate.is_empty() and pending_world.epoch==timeline.initialization_revision and pending_world.quarter==quarter and pending_world.boundary.preparation_key==candidate.preparation_key:
            _forecast_static_world()
            return
        if not pending_world.worker_finished(): return
        _discard_world_preparation()
    if candidate.is_empty(): return
    # Compiler delivery admits immutable authoring for passive projection.
    # Exact media still gates native construction and visible publication.
    if not media_group_plans.has(candidate.source_group_id) and not is_same(
            media_received_owners.get(candidate.source_group_id),_media_group_owner(candidate.source_group_id)):return
    if not static_forecast.is_empty() and static_forecast.task>=0 and static_forecast.boundary.preparation_key==candidate.preparation_key:return
    pending_world = WorldPreparation.new(); add_child(pending_world)
    pending_world.configure(self,candidate,false,_take_static_forecast(candidate))

func _static_forecast_base_matches()->bool:
    if static_forecast.is_empty():return false
    var base:Dictionary=static_forecast.input.base
    return base.epoch==timeline.initialization_revision and base.world_revision==world_revision and base.quarter==quarter \
        and base.source_depth==source_depth and base.source_normals==source_normals \
        and base.world_generation==world_generation and is_same(base.row_owner,world_row_cache) \
        and is_same(base.groups,world_groups) and is_same(base.ground,ground_groups) and is_same(base.entries,static_entries) \
        and is_same(base.support_owner,ground_overlay.support_owner)

func _poll_static_forecast()->void:
    if static_forecast.is_empty():return
    if static_forecast.task>=0 and WorkerThreadPool.is_task_completed(static_forecast.task):
        WorkerThreadPool.wait_for_task_completion(static_forecast.task);static_forecast.task=-1
    if static_forecast.task<0 and not _static_forecast_base_matches():static_forecast={}

func _forecast_static_world()->void:
    if external_playback or not static_forecast.is_empty() or pending_world==null \
        or not pending_world.worker_finished() or not pending_world.result.get("source_only",false):return
    var candidate:Dictionary=timeline.preview_world(false)
    if candidate.is_empty() or candidate.preparation_key==pending_world.boundary.preparation_key:return
    if not media_group_plans.has(candidate.source_group_id) and not is_same(
            media_received_owners.get(candidate.source_group_id),_media_group_owner(candidate.source_group_id)):return
    var input:Dictionary=WorldPreparation.capture_static(self,candidate)
    var output:Dictionary={}
    var task:int=WorkerThreadPool.add_task(WorldPreparation.derive_static.bind(input,output),false,"Prepare received static world")
    static_forecast={"task":task,"input":input,"output":output,"boundary":candidate}

func _take_static_forecast(candidate:Dictionary)->Dictionary:
    _poll_static_forecast()
    if static_forecast.is_empty() or static_forecast.task>=0:return {}
    var output:Dictionary={}
    if _static_forecast_base_matches() and static_forecast.boundary.preparation_key==candidate.preparation_key:
        output=static_forecast.output
    static_forecast={}
    return output

func _prepared_world_sources_ready(candidate: Dictionary) -> bool:
    if candidate.get("replay",false):
        for group in candidate.replay_groups:
            var exact:Dictionary=media_group_plans.get(group.id,{})
            if exact.is_empty() or not exact.errors.is_empty() or not MediaWarmup.ready(media_warmup,exact.environment):return false
        return true
    var plan: Dictionary = media_group_plans.get(candidate.source_group_id,{})
    # Retained environment resources keep their displayed leases. The matching
    # prepared owner proves every new/changed current-view constructor, including
    # CPU images and fixture facts; other camera views are a later consumer.
    return not plan.is_empty() and plan.errors.is_empty() and pending_world!=null and pending_world.prepared \
        and pending_world.epoch==timeline.initialization_revision and pending_world.quarter==quarter \
        and pending_world.boundary.preparation_key==candidate.preparation_key \
        and MediaWarmup.ready(media_warmup,pending_world.result.get("environment_paths",{}))

func _world_preparation_due(advance_ms:float)->bool:
    return pending_world!=null and (pending_world.initial or float(pending_world.boundary.display_ms)<=timeline.display_ms+maxf(0,advance_ms))

func _step_world_preparation(poll_only:bool=false) -> void:
    if pending_world==null: return
    var invalid_initial:bool=false
    if pending_world.initial and pending_world.prepared:
        invalid_initial=not pending_world.can_publish_membership(timeline.world_revision) and pending_world.prepared
    if pending_world.epoch!=timeline.initialization_revision or pending_world.quarter!=quarter or pending_world.stale or invalid_initial:
        if pending_world.worker_finished(): _discard_world_preparation()
        return
    # Each hidden native phase waits for its own source operands. The exact
    # complete media/world gate still precedes any displayed state change.
    var budget:Dictionary=_preparation_budget()
    var started:int=Time.get_ticks_usec();var before:int=budget.used_usec
    pending_world.step(0 if poll_only else maxi(0,budget.limit_usec-budget.used_usec))
    _forecast_static_world()
    _charge_preparation("world",started,before)
    if not pending_world.media_issue.is_empty(): media_issue = pending_world.media_issue

func _world_ready(candidate: Dictionary) -> bool:
    if world_revision<0: return false
    _poll_static_forecast()
    if pending_world==null and not static_forecast.is_empty() and static_forecast.task>=0 \
        and static_forecast.boundary.preparation_key==candidate.preparation_key:return false
    # Required media preparation may have completed our worker since the early
    # poll. Reuse the remaining shared allowance before holding this boundary.
    if pending_world!=null and not pending_world.admitted and pending_world.boundary.preparation_key==candidate.preparation_key:
        _step_world_preparation()
    if pending_world!=null:
        if pending_world.admitted: return false # Publish before accepting another boundary.
        if pending_world.epoch!=timeline.initialization_revision or pending_world.quarter!=quarter or pending_world.boundary.preparation_key!=candidate.preparation_key:
            if not pending_world.worker_finished(): return false
            _discard_world_preparation()
        elif pending_world.prepared:
            if not _prepared_world_sources_ready(candidate):return false
            # Static preparation borrows the published row indexes. A different
            # publication cannot mutate them until this one finite task ends.
            if not pending_world.source_only() and not static_forecast.is_empty() and static_forecast.task>=0:return false
            # Validate the borrowed base before Timeline changes state, clocks,
            # trace or audio. A stale candidate owns nothing displayed.
            if pending_world.can_publish_membership(int(candidate.world_revision)):
                if not external_clock:
                    pending_world.admitted = true
                return true
            if not pending_world.prepared:return false
            _discard_world_preparation()
        else: return false
    pending_world = WorldPreparation.new(); add_child(pending_world)
    pending_world.configure(self,candidate,false,_take_static_forecast(candidate))
    _step_world_preparation()
    if pending_world.prepared and _prepared_world_sources_ready(candidate) and pending_world.can_publish_membership(int(candidate.world_revision)):
        if not pending_world.source_only() and not static_forecast.is_empty() and static_forecast.task>=0:return false
        if not external_clock:
            pending_world.admitted=true
        return true
    return false

func _publish_source_cut(_candidate:Dictionary)->bool:
    if pending_world==null or not pending_world.result.get("source_only",false):return false
    pending_world.publish_actor_bindings()
    world_prepare_worker_ms=pending_world.result.worker_ms
    world_prepare_worker_phases=pending_world.result.get("worker_phases",{})
    world_prepared_count+=1
    _discard_world_preparation()
    return true

func _world_can_publish() -> bool:
    if pending_world==null:return true
    if pending_world.epoch!=timeline.initialization_revision or not pending_world.prepared:return false
    if pending_world.initial:
        if not pending_world.can_publish_membership(timeline.world_revision):
            if pending_world.prepared:pending_world.stale=true
            return false
    return pending_world.admitted or pending_world.initial

func _discard_world_preparation() -> void:
    if pending_world==null: return
    _retire_view(pending_world,null,pending_world.entries)
    pending_world = null

func _finish_world_preparation() -> void:
    if pending_world==null or not (pending_world.admitted or pending_world.initial): return
    pending_world.publish_native_receivers()
    pending_world.publish_actor_bindings()
    component_renderer.invalidate_preparation()
    world_prepare_worker_ms = pending_world.result.worker_ms
    world_prepare_worker_phases=pending_world.result.get("worker_phases",{})
    world_prepared_count += 1
    # All adopted native nodes have moved to the stable displayed parent.
    pending_world.entries = []; pending_world.static_entries = []
    pending_world.native_groups = {}; pending_world.native_ground = {}
    if pending_world.result.has("actor_members"):
        # Static publication precedes actor synchronization. Keep the hidden
        # owner alive until exact current outfits can take their own nodes.
        _finish_actor_preparation()
        prepared_actor_owner=pending_world;pending_world=null
    else:_discard_world_preparation()

func _finish_actor_preparation() -> void:
    if prepared_actor_owner==null:return
    _retire_view(prepared_actor_owner,null,[])
    prepared_actor_owner=null

func _sync_world() -> void:
    prepared_scenery = {}; prepared_static_order = {}
    var prepared: Dictionary = pending_world.result if pending_world!=null and pending_world.epoch==timeline.initialization_revision and pending_world.prepared and (pending_world.admitted or pending_world.initial) else {}
    # Runtime cuts must already own their resources. Direct isolated renderer
    # fixtures may still use synchronous projection without installing the gate.
    if world_prepare_epoch==timeline.initialization_revision and prepared.is_empty():
        var detail:Dictionary={"display_revision":timeline.world_revision,"base_revision":world_revision,"pending":pending_world!=null}
        if pending_world!=null:
            detail.merge({"phase":pending_world.phase,"initial":pending_world.initial,"admitted":pending_world.admitted,
                "boundary_revision":pending_world.boundary.get("world_revision",-1),"lights_valid":source_lighting.preparation_valid(pending_world.light_preparation)})
        _publication_failure("Displayed world boundary has no valid prepared owner: "+JSON.stringify(detail))
        return
    if prepared.is_empty() and pending_world!=null: _discard_world_preparation()
    var phase = Time.get_ticks_usec()
    world_changes = timeline.take_world_changes(world_revision)
    world_changes.base_revision = world_revision
    if not prepared.is_empty() and world_changes.get("full",false) and not pending_world.initial:
        _publication_failure("Unexpected full replacement after prepared world admission.")
        return
    world_revision = timeline.world_revision
    var detail_started:int=Time.get_ticks_usec()
    if not prepared.is_empty():
        # The worker rebuilt the terrain supports only if terrain rows changed.
        if not prepared.get("ground_supports",{}).is_empty():_publish_ground_supports(prepared.ground_supports)
        ground_supports_revision=world_revision
        source_lighting.publish_prepared(pending_world.light_preparation)
        var senses:Variant=timeline.state.get("senses")
        var inputs:Variant=senses.get("light_sources") if senses!=null else null
        light_source_inputs=inputs
        light_source_epoch=timeline.initialization_revision
        light_revision=timeline.revision
    FrameProfile.end_phase(profile,"world_light_publication",detail_started)
    detail_started=Time.get_ticks_usec()
    var supports: Dictionary = timeline.staged_tiles()
    for key in supports:
        if not sampled_supports.has(key) or sampled_supports[key]!=supports[key]: world_changes.tiles[key] = true
    for key in sampled_supports:
        if not supports.has(key): world_changes.tiles[key] = true
    sampled_supports = supports
    FrameProfile.end_phase(profile,"world_support_changes",detail_started)
    detail_started=Time.get_ticks_usec()
    var derived: Dictionary
    if not prepared.is_empty():
        derived=WorldRows.apply_changes(world_row_cache,prepared.row_patch)
    else: derived = WorldRows.update_rows(timeline.presentation_state(),catalog_cache,world_row_cache,world_changes)
    FrameProfile.end_phase(profile,"world_row_adoption",detail_started)
    detail_started=Time.get_ticks_usec()
    _queue_wall_geometry_changes(world_changes)
    FrameProfile.end_phase(profile,"world_wall_geometry_changes",detail_started)
    FrameProfile.end_phase(profile,"world_rows",phase)
    unresolved = derived.unresolved
    var rotated = world_quarter != quarter
    var background: bool = world_row_cache.negative.is_empty()
    var changed: bool = world_row_cache.changed or ground_is_background != background
    ground_is_background = background
    world_visual_rows = derived.visual_rows
    if changed: world_generation += 1
    if prepared.has("ground_support"):
        detail_started=Time.get_ticks_usec()
        ground_overlay.publish_support(prepared.ground_support,
            [timeline.initialization_revision,timeline.world_revision,world_generation,timeline._support_signature()],
            world_row_cache,[timeline.initialization_revision],timeline.world_revision)
        FrameProfile.end_phase(profile,"world_ground_support_publish",detail_started)
    if not prepared.get("geometry",{}).is_empty():
        prepared.geometry.generation = world_generation
        wall_geometry_views[quarter] = prepared.geometry
    if not prepared.is_empty() and pending_world.quarter==quarter and pending_world.boundary.get("world_revision",-1)==timeline.world_revision:
        # The existing world gate has now admitted this exact epoch/boundary.
        # Merely finishing the private worker never publishes sight early.
        prepared_scenery = {"visibility":prepared.visibility,"visible_cells":prepared.visible_cells,
            "base":prepared.visibility_base,"changes":prepared.visibility_changes,
            "revision":timeline.world_revision,"generation":world_generation,
            "quarter":quarter,"epoch":timeline.initialization_revision}
        if pending_world.membership.scenery.has("writes"):
            prepared_scenery.writes = pending_world.membership.scenery.writes
    if prepared.has("blood_index"):
        detail_started=Time.get_ticks_usec()
        component_renderer.blood.publish_tile_index(timeline.state.tiles,timeline.world_revision,prepared.blood_index)
        FrameProfile.end_phase(profile,"world_blood_index_publish",detail_started)
    if not changed and not rotated:
        if not prepared.is_empty():
            pending_world.publish_membership()
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
    var light_upserts: Array = []
    var entries_changed = rotated
    var walls_changed = rotated
    if not prepared.is_empty() and (not rotated or pending_world.initial):
        var membership: Dictionary = pending_world.membership
        removed = membership.removed; light_upserts = membership.upserts
        entries_changed = membership.entries_changed; walls_changed = membership.walls_changed
        phase = Time.get_ticks_usec()
        for group in membership.retired_groups:
            for entry in group.entries: entry.node.queue_free()
        # Preserve the combined entries' historical insertion order.
        for group in membership.new_groups:
            for entry in group.entries: entry.node.reparent(sprite_parent,false)
            entries.append_array(group.entries)
        FrameProfile.end_phase(profile,"world_objects",phase)
        phase = Time.get_ticks_usec()
        for update in membership.ground_updates: _ground_publish(update.entry,update.packet)
        FrameProfile.end_phase(profile,"world_ground",phase)
        if not removed.is_empty():
            entries = entries.filter(func(entry):return not removed.has(entry.node.get_instance_id()))
        detail_started=Time.get_ticks_usec()
        _publish_scenery_membership(membership.scenery)
        FrameProfile.end_phase(profile,"world_scenery_membership",detail_started)
        detail_started=Time.get_ticks_usec()
        pending_world.publish_membership()
        if rotated:
            # An initial preparation can retain entries of the previous view
            # (ground batches updated in place). They leave its retiring root,
            # or its bounded retirement frees them while they are displayed.
            for entry in static_entries:
                if not sprite_parent.is_ancestor_of(entry.node):entry.node.reparent(sprite_parent,false)
        FrameProfile.end_phase(profile,"world_membership_publish",detail_started)
    else:
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
                light_upserts.append_array(fresh_groups[id].entries)
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
                    light_upserts.append(old.entries[0])
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
                light_upserts.append_array(fresh_ground[key].entries)
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
    # A rotated view rebuilds/adopts a different node membership. Its order
    # cannot reuse the pre-rotation preparation, even with the same row count.
    if not prepared.is_empty() and (not rotated or pending_world.initial):
        detail_started=Time.get_ticks_usec()
        pending_world.publish_order()
        FrameProfile.end_phase(profile,"world_order_publish",detail_started)
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
    # An authoritative replay reset replaces state, but may retain every native
    # lighting source. Only the physical view replacement is a full receipt;
    # prepared membership already supplies ordinary source additions/removals.
    detail_started=Time.get_ticks_usec()
    _finish_world_preparation()
    FrameProfile.end_phase(profile,"world_finish_publish",detail_started)

func _publication_failure(message:String)->void:
    # This signals an invariant fault after admission; it never fabricates a
    # rollback or rebuilds a second state while the accepted cut is advancing.
    publication_failed=true
    timeline.paused=true
    media_issue=message
    notice_text=message
    if message not in presentation_errors:presentation_errors.append(message)
    push_error(message)
    presentation_updated.emit()

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
    var pending: Array = [source]
    for entry in source.release_handles():
        if not is_instance_valid(entry.node): continue
        var id: int = entry.node.get_instance_id()
        if held.has(id): continue
        held[id] = entry
        # Nodes parented outside the candidate but owned by it retire with it,
        # within the existing per-frame budget.
        if entry.get("retire_external",false) and entry.node!=source and not source.is_ancestor_of(entry.node):
            pending.append(entry.node)
    for entry in source_entries:
        if is_instance_valid(entry.node): held[entry.node.get_instance_id()] = entry
    if mask != null and not source.is_ancestor_of(mask) and not pending.has(mask): pending.append(mask)
    # Descendant discovery belongs to the bounded retirement lane too.
    # Retaining roots avoids an unbounded prewalk at publication.
    retiring_views.append({"nodes":pending,"entries":held})
    retiring_node_count += pending.size()

func _dispose_views(budget:Dictionary={},minimum:bool=false) -> void:
    # Native destruction can execute after our callback. Bound count as well as
    # measured CPU work, and never run this slice twice in one native frame.
    if retiring_views.is_empty() or retirement_frame==Engine.get_process_frames(): return
    if not budget.is_empty() and budget.used_usec>=budget.limit_usec and not minimum:return
    retirement_frame = Engine.get_process_frames()
    var charged_before:int=budget.get("used_usec",0)
    var allowance:int=2000 if budget.is_empty() else maxi(0,budget.limit_usec-budget.used_usec)
    var started = Time.get_ticks_usec()
    var released = 0
    var metadata_steps = 0
    while not retiring_views.is_empty() and released<16 and metadata_steps<4096 and (Time.get_ticks_usec()-started<allowance or (minimum and released==0 and metadata_steps==0)):
        var view: Dictionary = retiring_views[0]
        if view.nodes.is_empty():retiring_views.pop_front();continue
        var node:Node=view.nodes.back()
        if is_instance_valid(node) and node.get_child_count()>0:
            view.nodes.append(node.get_child(node.get_child_count()-1))
            retiring_node_count+=1;metadata_steps+=1
            continue
        view.nodes.pop_back()
        if is_instance_valid(node):
            var id = node.get_instance_id()
            # A view root's tables are freed on a worker, not with the node.
            if node.get_script()!=null:BackgroundRelease.release(BackgroundRelease.detach_tables(node))
            node.free()
            view.entries.erase(id)
        retiring_node_count -= 1
        released += 1
        if view.nodes.is_empty(): retiring_views.pop_front()
    if not budget.is_empty():
        if minimum and allowance==0:budget.minimum_cleanup+=released+metadata_steps
        _charge_preparation("retirement",started,charged_before)
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

func _activate_static_view(view_quarter: int, publish_lighting: bool = true) -> void:
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
            SourceMaterial.set_parameter(entry,"frame_index",clip.index)

func _scenery_remove(group_entries: Array) -> void:
    for entry in group_entries:
        var ids:Array=[] if entry.has("batch_rows") else [entry.placement.id]
        for id in ids:
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
            continue
        var id: String = entry.placement.id
        if not scenery_consumers.has(id): scenery_consumers[id] = []
        scenery_consumers[id].append({"entry":entry,"index":-1})
        scenery_new_consumers[id] = true
    wall_sources = scenery_wall_sources.values()

func _publish_scenery_membership(delta:Dictionary)->void:
    # The candidate enumerated only its added/retired targets before admission.
    # Ground consumers resolve their current packed index directly by ID; a
    # changed sight cell never searches every floor batch again.
    for id in delta.remove:
        if not scenery_consumers.has(id):continue
        var removed:Dictionary=delta.remove[id]
        scenery_consumers[id]=scenery_consumers[id].filter(func(value):return not removed.has(value.entry.node.get_instance_id()))
        if scenery_consumers[id].is_empty():scenery_consumers.erase(id)
    for id in delta.add:
        if not scenery_consumers.has(id):scenery_consumers[id]=[]
        scenery_consumers[id].append_array(delta.add[id])
    var walls_changed:bool=false
    for entry in delta.entry_remove:
        water_entries.erase(entry);scenery_batches.erase(entry)
        if entry.has("wall_source"):
            wall_entries.erase(entry);scenery_wall_sources.erase(entry.wall_source.id);walls_changed=true
    for entry in delta.entry_add:
        if entry.has("wall_source"):
            wall_entries.append(entry);scenery_wall_sources[entry.wall_source.id]=entry.wall_source;walls_changed=true
        if entry.material.shader==WATER_SHADER:water_entries.append(entry)
        if entry.has("batch_rows"):scenery_batches.append(entry)
    if walls_changed:wall_sources=scenery_wall_sources.values()
    scenery_new_consumers.merge(delta.new_consumers)
    scenery_index_dirty=false

func _scenery_ground_entry(id:String)->Dictionary:
    var slot:int=world_row_cache.get("visual_slots",{}).get(id,-1)
    if slot>=0:
        var row:Dictionary=world_visual_rows[slot]
        if row.kind=="terrain" and ground_groups.has(row.material):
            var entry:Dictionary=ground_groups[row.material].entries[0]
            if entry.ground_indices.has(id):return entry
        return {}
    # Standalone source/pixel fixtures omit the prepared canonical row owner.
    # Runtime uses its admitted row/material/batch references above.
    if world_prepare_epoch!=timeline.initialization_revision:
        for entry in scenery_batches:
            if entry.ground_indices.has(id):return entry
    return {}

func _sync_scenery(force: bool = false, refresh_sight: bool = false) -> void:
    var counts:Dictionary={"resolved_ids":0,"prepared_writes":0,"native_writes":0}
    profile.scenery_sample_counts=counts
    var rebuild = force or scenery_index_dirty or scenery_index_count!=static_entries.size() or scenery_quarter!=world_quarter
    if rebuild:
        scenery_consumers = {}; water_entries = []; wall_sources = []; wall_entries = []; scenery_wall_sources = {}; scenery_batches = []
        _scenery_add(static_entries)
        # A fresh quarter's packed instances already carry its prepared style.
        # Full fixtures/initialization also need explicit current support grants.
        for group in ground_groups.values():
            for row in group.rows: scenery_new_consumers[row.id] = true
        scenery_index_count = static_entries.size(); scenery_index_dirty = false
    if rebuild or refresh_sight or scenery_revision!=timeline.world_revision or scenery_generation!=world_generation or not scenery_new_consumers.is_empty() or not prepared_scenery.is_empty():
        var reuse: bool = not force and not refresh_sight and not prepared_scenery.is_empty() and prepared_scenery.epoch==timeline.initialization_revision and prepared_scenery.revision==timeline.world_revision and prepared_scenery.generation==world_generation and prepared_scenery.quarter==world_quarter and is_same(prepared_scenery.base,scenery_visibility)
        var current: Dictionary
        var changed: Dictionary
        var writes:Array=[]
        var prepared_writes:bool=reuse and prepared_scenery.has("writes")
        if reuse:
            current = prepared_scenery.visibility
            scenery_visible_cells = prepared_scenery.visible_cells
            changed = prepared_scenery.changes
            if prepared_writes:writes=prepared_scenery.writes
        else:
            var state: Dictionary = timeline.presentation_state()
            var boundaries: Dictionary = WorldRows.boundary_index(state) if force or world_row_cache.is_empty() else world_row_cache.boundaries
            current = WorldRows.current_ids(state,boundaries,scenery_visible_cells)
            changed = {}
            for id in current:
                if not scenery_visibility.has(id): changed[id] = true
            for id in scenery_visibility:
                if not current.has(id): changed[id] = false
        prepared_scenery = {}
        var sight_changed: bool = not changed.is_empty()
        if not prepared_writes:
            changed=changed.duplicate()
            for id in scenery_new_consumers: changed[id] = current.has(id)
        scenery_new_consumers = {}
        if sight_changed: wall_visibility_revision = -1
        scenery_visibility = current
        if not prepared_writes:
            for id in changed:
                counts.resolved_ids+=1
                var value:float = 1.0 if changed[id] else 0.0
                var ground_entry:Dictionary=_scenery_ground_entry(str(id))
                if not ground_entry.is_empty():
                    var index:int=ground_entry.ground_indices[id]
                    if ground_entry.scenery_values[index]!=value:
                        writes.append({"entry":ground_entry,"index":index,"id":str(id),"value":value})
                for consumer in scenery_consumers.get(id,[]):
                    var entry: Dictionary = consumer.entry
                    var index:int=entry.ground_indices.get(id,-1) if consumer.index>=0 else -1
                    if consumer.index>=0:
                        if index>=0 and entry.scenery_values[index]!=value:
                            writes.append({"entry":entry,"index":index,"id":str(id),"value":value})
                    elif entry.get("scenery_value",-1.0)!=value:
                        writes.append({"entry":entry,"index":-1,"id":str(id),"value":value})
        if prepared_writes:counts.prepared_writes=writes.size()
        counts.native_writes=writes.size()
        _publish_scenery_writes(writes)
        scenery_revision = timeline.world_revision
        scenery_world_revision = world_revision
        scenery_generation = world_generation
        scenery_quarter = world_quarter
    var seconds: float = timeline.display_ms / 1000.0
    if water_display_seconds != seconds:
        for entry in water_entries:
            SourceMaterial.set_parameter(entry,"displayed_time_seconds",seconds)
        water_display_seconds = seconds

func _publish_scenery_writes(writes:Array)->void:
    var batches:Dictionary={}
    for write in writes:
        var entry:Dictionary=write.entry
        if write.index>=0:
            _ground_visibility(entry,write.index,write.value)
            var key:int=entry.node.get_instance_id()
            if not batches.has(key):batches[key]={"entry":entry,"indices":[]}
            batches[key].indices.append(write.index)
        else:
            SourceMaterial.set_parameter(entry,"current_visibility",write.value)
            entry.scenery_value=write.value
    for batch in batches.values():_ground_flush_visibility(batch.entry,batch.indices)

func _light_entry(entry: Dictionary) -> void:
    SourceMaterial.apply(entry,SourceMaterial.environment_policy(entry.placement.kind,entry.role))

func _sync_actors() -> void:
    _sync_actor_membership()
    _finish_actor_preparation()

func _sync_source_lighting() -> void:
    var senses:Variant=timeline.state.get("senses")
    var sources:Variant=senses.get("light_sources") if senses!=null else null
    # New-schema emitters fully describe source membership and optical values.
    # Legacy inventory-derived sources retain their existing revision refresh.
    if light_revision<0 or light_source_epoch!=timeline.initialization_revision or sources==null or sources!=light_source_inputs:
        source_lighting.sync(timeline.state)
        light_source_inputs=sources
        light_source_epoch=timeline.initialization_revision
    light_revision=timeline.revision

func _reconcile_actor_layers(id:String,row:Dictionary)->bool:
    var old:Dictionary=visual_actors[id]
    if row.rig!=old.row.rig or row.appearance!=old.row.appearance:return false
    var prior_base:Array=[];var current_base:Array=[];var selectors:Dictionary={}
    for layer in old.row.equipment_layers:
        selectors[layer.slot]=layer
        if layer.get("effect",{}).is_empty():prior_base.append(layer)
    for layer in row.equipment_layers:
        if layer.get("effect",{}).is_empty():current_base.append(layer)
    if prior_base!=current_base:return false
    var by_slot:Dictionary={}
    for entry in old.entries:by_slot[entry.actor_layer.slot]=entry
    var changed:Array=[]
    for layer in row.equipment_layers:
        if selectors.get(layer.slot)!=layer:changed.append(layer)
    var selected:Dictionary=row.duplicate()
    selected.equipment_layers=changed
    var resolved:Dictionary={}
    var started:int=Time.get_ticks_usec()
    for layer in Characters.layers(selected,rigs[row.rig],catalog_cache):resolved[layer.slot]=layer
    FrameProfile.end_phase(profile,"actor_layers_resolve",started)
    old.row.merge(row,true)
    var retained:Array=[]
    started=Time.get_ticks_usec()
    for index in row.equipment_layers.size():
        var layer:Dictionary=row.equipment_layers[index]
        var entry:Dictionary
        if selectors.get(layer.slot)==layer:entry=by_slot[layer.slot]
        else:entry=ActorConstruction.layer(self,old.row,rigs[row.rig],resolved[layer.slot],index)
        entry.layer=index
        entry.id=id+":"+str(index)+":"+entry.role
        retained.append(entry)
    for entry in old.entries:
        if entry in retained:continue
        entry.node.visible=false;entry.node.queue_free()
        entries.erase(entry);actor_entries.erase(entry)
    old.entries=retained;old.valid=true
    draw_order_dirty=true
    FrameProfile.end_phase(profile,"actor_layers_reconcile",started)
    return true

func _sync_actor_membership() -> void:
    var counts:Dictionary={"prepared_rows":0,"resolved_rows":0}
    profile.actor_membership_counts=counts
    # Initial raw state can arrive before its worker-prepared source catalog.
    # Do not fall back to synchronous JSON parsing while that job is running.
    if not media_metadata_ready: return
    var group: String = timeline.current.get("id","")
    var staged: Dictionary = timeline.staged_actors()
    var rendered_state: Dictionary = timeline.presentation_state()
    var loadouts:Dictionary=ActorConstruction.loadouts(displayed_samples,displayed_components)
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
        actor=ActorConstruction.actor_with_loadout(actor,loadouts)
        if not WorldRows.visible_actor(actor,timeline.state,staged.has(id)):
            _retire_actor(id)
            continue
        var actor_stage:int=Time.get_ticks_usec()
        var resolved:Dictionary
        if prepared_actor_owner!=null:
            var prepared_row:Variant=prepared_actor_owner.result.actor_members.get(id)
            resolved={"ok":true,"value":prepared_row.duplicate() if prepared_row!=null else null}
            counts.prepared_rows+=1
        else:
            resolved=Characters.resolve(actor,rendered_state,catalog_cache)
            counts.resolved_rows+=1
        FrameProfile.end_phase(profile,"actor_resolve",actor_stage)
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
            if ActorConstruction.matches(row,old.row):
                old.row.merge(row,true)
                old.valid = true
                continue
            # Effect-layer changes are not world boundaries in live play.
            if (world_prepare_epoch!=timeline.initialization_revision or not timeline.source_cut_boundaries) and _reconcile_actor_layers(id,row):continue
            # Exact replacement comes from the admitted structural boundary.
            # Keep old ownership until its complete replacement is available.
        draw_order_dirty = true
        var rig: Dictionary = rigs[row.rig]
        var prepared:Dictionary=prepared_actor_owner.take_actor(id,row,rig) if prepared_actor_owner!=null else {}
        if prepared.is_empty() and world_prepare_epoch==timeline.initialization_revision:
            var detail:Dictionary={"actor":id,"prepared_owner":prepared_actor_owner!=null}
            if prepared_actor_owner!=null:
                var candidate:Dictionary=prepared_actor_owner.native_actors.get(id,{})
                detail.merge({"candidate":not candidate.is_empty(),"epoch":prepared_actor_owner.epoch,
                    "display_epoch":timeline.initialization_revision,"quarter":prepared_actor_owner.quarter,
                    "catalog_owner_matches":is_same(prepared_actor_owner.actor_catalog_owner,catalog_cache)})
                if not candidate.is_empty():detail.merge({"rig_matches":is_same(candidate.rig,rig),
                    "structure_matches":ActorConstruction.matches(row,candidate.row),
                    "layers":candidate.layers.size(),"entries":candidate.entries.size(),"graph_ready":candidate.playback!=null})
            _publication_failure("Actor structure was not prepared before display: "+JSON.stringify(detail))
            return
        var retain_actor:bool=not prepared.is_empty() and prepared.get("reuse_actor",false)
        if visual_actors.has(id) and not retain_actor:_retire_actor(id)
        var created:Array=[]
        if not prepared.is_empty():
            actor_stage=Time.get_ticks_usec()
            if retain_actor:
                var old:Dictionary=visual_actors[id]
                old.row.merge(row,true);row=old.row;prepared.row=row
                for entry in old.entries:
                    if entry in prepared.entries:continue
                    entry.node.hide();entry.node.queue_free()
                    entries.erase(entry);actor_entries.erase(entry)
            else:prepared.row.merge(row,true);row=prepared.row
            playbacks[id]=prepared.playback
            if playbacks[id].get_parent()!=self:playbacks[id].reparent(self,false)
            created=prepared.entries
            for index in created.size():
                var entry:Dictionary=created[index]
                entry.layer=index;entry.id=id+":"+str(index)+":"+entry.role;entry.placement=row
                if entry.node.get_parent()==self:continue
                entry.node.visible=false;entry.node.reparent(self,false);_light_entry(entry)
                entries.append(entry);actor_entries.append(entry)
            var retired_shadows:Array=generated_shadows.adopt_actor(prepared)
            if not retired_shadows.is_empty():
                retiring_views.append({"nodes":retired_shadows,"entries":{}})
                retiring_node_count+=retired_shadows.size()
            FrameProfile.end_phase(profile,"actor_prepared_adopt",actor_stage)
            actor_prepared_layers+=prepared.new_entries.size()
        else:
            actor_stage=Time.get_ticks_usec()
            playbacks[id] = ActorConstruction.graph(self,rig,animation_templates)
            FrameProfile.end_phase(profile,"actor_graph_create",actor_stage)
            actor_stage=Time.get_ticks_usec()
            var layers: Array = Characters.layers(row,rig,catalog_cache)
            FrameProfile.end_phase(profile,"actor_layers_resolve",actor_stage)
            actor_stage=Time.get_ticks_usec()
            for i in range(layers.size()):created.append(ActorConstruction.layer(self,row,rig,layers[i],i))
            FrameProfile.end_phase(profile,"actor_layers_create",actor_stage)
        if not retain_actor:actor_rows.append(row)
        var visual:Dictionary={"row":row,"entries":created,"valid":true}
        if prepared.has("condition_parameters"):visual.condition_parameters=prepared.condition_parameters
        if prepared.get("outfit_profile","")==character_light_profile and prepared.has("outfit_clip"):
            visual.outfit_binding=[prepared.outfit_clip,character_light_profile,MediaWarmup.physical(media_warmup).source_revision]
        visual_actors[id] = visual
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

func _reset_media_epoch() -> void:
    if media_plan_epoch == timeline.initialization_revision: return
    media_plan_epoch = timeline.initialization_revision
    SelectionMedia.cancel(selection_media)
    selection_media_hold_cursor=-1
    selection_media_demand_paths={}
    selection_media_preview={}
    media_normal_sets={}
    media_group_plans.clear();media_interest={}
    _release_replay_media()
    media_received_owners.clear()
    media_empty_key = []
    media_empty_plan = {}
    media_terminal_plan = {}
    media_condition_key = []
    media_condition_paths = {}
    media_condition_record={};native_media_record={};media_profile_record={}
    media_due_current_parts=[];media_due_parts=[]
    media_source_issue=""

func _retained_condition_media() -> bool:
    # Removal banks outlive the canonical condition. Seek can start directly in
    # that interval, so its current presentation owners also own required bytes.
    # Retain each active owner's authored closure, not all historical conditions.
    var key:Array=[]
    var conditions:Array=[]
    for owner in timeline.condition_owners.values():
        if timeline.display_ms>=owner.end_ms+Conditions.fade_ms(owner.condition,catalog_cache):continue
        key.append([owner.id,owner.condition.behavior_id])
        conditions.append(owner.condition)
    if key==media_condition_key:return false
    media_condition_key=key
    media_condition_paths=Conditions.paths({"conditions":conditions},catalog_cache) if not conditions.is_empty() else {}
    media_condition_record=MediaWarmup.source_record(media_condition_paths) if not media_condition_paths.is_empty() else {}
    return true

func _media_group_owner(id: String) -> Dictionary:
    if timeline.current.get("id","") == id: return timeline.current
    for group in timeline.queue:
        if group.id == id: return group
    return {}

func _adopt_received_media(message: Dictionary) -> void:
    _reset_media_epoch()
    var received: Dictionary = message.get("media",{})
    if received.is_empty() or timeline.state.is_empty(): return
    if received.generation != timeline.state.generation or received.observer_uuid != timeline.state.observer_uuid: return
    var ids: Array = []
    for group in received.groups:
        if not is_same(_media_group_owner(group.id),group): return
        var belongs = false
        for supplied in message.groups:
            if is_same(supplied,group): belongs = true; break
        if not belongs: return
        ids.append(group.id)
    if ids.is_empty(): return
    var key: Array = [timeline.initialization_revision,ids,0]
    media_requested_key = key
    var completed = MediaWarmup.receive_handoff(media_warmup,received,key)
    _adopt_media_plan(completed,false)
    for group in received.groups: media_received_owners[group.id] = group
    # Pins/readiness are still selected by _prepare_media's displayed window.
    media_plan_key = []

func _selection_media_budget() -> int:
    var started=Time.get_ticks_usec()
    var reserved=0
    var exact: Dictionary=media_plan.get("required",{}).duplicate()
    exact.merge(media_environment_required)
    for path in media_warmup.wanted:
        if not selection_media_demand_paths.has(path) or exact.has(path):
            reserved+=maxi(0,MediaWarmup._estimate(media_warmup,path))
    FrameProfile.end_phase(profile,"selection_media_budget",started)
    return maxi(0,int(MediaWarmup.physical(media_warmup).budget_bytes)-reserved)

func _body_action_choices() -> Dictionary:
    if external_playback or session==null:return {}
    # Choices may already describe the accepted post-action boundary while its
    # preceding animation is still displayed. Only source hints consume them.
    if not pending_choices.is_empty() and pending_choices.force_attack==force_attack \
            and session.matches_choice_boundary(pending_choices.boundary):return pending_choices.value.choices
    if action_revision==session.status.get("boundary",{}).get("state_revision") \
            and session.matches_choice_boundary(choices_boundary):return available_actions
    return {}

func _refresh_selection_media() -> void:
    var started=Time.get_ticks_usec()
    var revision: int=selection_media.revision
    var boundary: Dictionary=session.status.get("boundary",{}) if session!=null else {}
    var body_choices: Dictionary=_body_action_choices()
    if selection_media_hold_cursor!=-1:
        if selection_media.key.is_empty() or selection_media.key[0]!=timeline.initialization_revision:
            SelectionMedia.cancel(selection_media);selection_media_hold_cursor=-1
    elif not selected_action.is_empty() and Interaction.owns_action(available_actions,selected_action) \
            and action_revision==boundary.get("state_revision") \
            and available_actions.get("entity_uuid")==boundary.get("input_actor_uuid") \
            and available_actions.get("entity_uuid")==timeline.state.get("current_actor_uuid") \
            and timeline.state.get("actors",{}).has(available_actions.get("entity_uuid")):
        var pending_preview=action_request>=0 and pending_request.get("kind")=="preview"
        var preview: Dictionary=hover_preview if not hover_preview.is_empty() else selection_preview if not selection_preview.is_empty() else selection_media_preview if pending_preview else {}
        selection_media_preview=preview
        var owners_started=Time.get_ticks_usec()
        var owners: Dictionary=SelectionMedia.owners(selection_media,timeline.state,preview)
        FrameProfile.end_phase(profile,"selection_media_owners",owners_started)
        var key=[timeline.initialization_revision,timeline.revision,action_revision,
            available_actions.entity_uuid,available_actions.discovery_generation,selected_action,character_light_profile,
            owners.object_resources,owners.response_resources,owners.exact]
        if key!=selection_media.key:
            # Only an area/recipient refinement may retain the accepted base.
            # A new source epoch, outfit revision or action owns fresh candidates.
            if selection_media.key.slice(0,7)!=key.slice(0,7):SelectionMedia.cancel(selection_media)
            var budget_bytes=_selection_media_budget()
            var snapshot_started=Time.get_ticks_usec()
            var eligible=[]
            for option in Choices.action_options(available_actions,selected_action):
                var subject=Choices.binding_subject(available_actions,option)
                if subject!=null and subject.get("kind")=="creature" and subject.uuid not in eligible:eligible.append(subject.uuid)
            var sources: Dictionary=Catalog.source_snapshot(catalog_cache)
            FrameProfile.end_phase(profile,"selection_media_snapshot",snapshot_started)
            var request_started=Time.get_ticks_usec()
            SelectionMedia.request(selection_media,key,available_actions.entity_uuid,selected_action.behavior_id,
                timeline.state,budget_bytes,sources,preview,eligible,owners,character_light_profile)
            FrameProfile.end_phase(profile,"selection_media_request",request_started)
    elif selected_action.is_empty() and not body_choices.is_empty() \
            and timeline.state.get("actors",{}).has(body_choices.get("entity_uuid")):
        # Current disclosed outfit is an optional hint even if later accepted
        # events will replace it; exact received sources still own every gate.
        var actor_uuid: String=body_choices.entity_uuid
        var actor: Dictionary=timeline.state.actors[actor_uuid]
        var key=[timeline.initialization_revision,SelectionMedia._outfit(actor),boundary.get("state_revision"),
            actor_uuid,body_choices.discovery_generation,"available_body_actions",character_light_profile]
        if key!=selection_media.key:
            SelectionMedia.cancel(selection_media)
            var behaviors={}
            for action in Choices.all_actions(body_choices):behaviors[action.behavior_id]=true
            var state={"actors":{actor_uuid:actor},"objects":{},
                "senses":timeline.state.senses,"audience":timeline.state.audience}
            var owners={"objects":[],"recipients":[],"object_resources":[],"response_resources":[],"exact":false}
            SelectionMedia.request(selection_media,key,actor_uuid,"",state,_selection_media_budget(),
                Catalog.source_snapshot(catalog_cache),{},[],owners,character_light_profile,behaviors.keys())
    else: SelectionMedia.cancel(selection_media)
    var adoption_started=Time.get_ticks_usec()
    if SelectionMedia.poll(selection_media) and not selection_media.value.is_empty():
        var accepted: Dictionary=selection_media.value
        Catalog.adopt_snapshot(catalog_cache,accepted.get("source_files",{}))
        if session!=null:session.offer_prepared_sources(accepted.get("source_files",{}),accepted.get("source_headers",{}))
        MediaWarmup.adopt_source_sizes(media_warmup,accepted.get("source_sizes",{}),timeline.initialization_revision)
        if selection_media_hold_cursor==-1 and not selected_action.is_empty():
            var shown: Dictionary=hover_preview if not hover_preview.is_empty() else selection_preview if not selection_preview.is_empty() else selection_media_preview if action_request>=0 and pending_request.get("kind")=="preview" else {}
            var resolved: Dictionary=SelectionMedia.owners(selection_media,timeline.state,shown)
            selection_media.key=selection_media.key.slice(0,7)+[resolved.object_resources,resolved.response_resources,resolved.exact]
    FrameProfile.end_phase(profile,"selection_media_adoption",adoption_started)
    if revision!=selection_media.revision:media_plan_key=[]
    FrameProfile.end_phase(profile,"selection_media",started)

func _prepare_media(first: Dictionary = {}) -> void:
    if timeline.state.is_empty(): return
    _reset_media_epoch()
    _refresh_selection_media()
    var condition_changed=_retained_condition_media()
    var native_paths:Dictionary=component_renderer.native_spells.required_images
    var native_cpu:Dictionary=component_renderer.native_spells.required_cpu_images
    var native_changed:bool=native_paths!=native_media_paths or native_cpu!=native_media_cpu_paths
    if native_changed:
        native_media_paths=native_paths.duplicate()
        native_media_cpu_paths=native_cpu.duplicate()
        native_media_record=MediaWarmup.source_record(native_media_paths,{},{},native_media_paths,native_media_cpu_paths) if not native_media_paths.is_empty() else {}
    var groups: Array = []
    if not timeline.current.is_empty(): groups.append(timeline.current)
    elif not first.is_empty(): groups.append(first)
    for group in timeline.queue:
        if groups.size() >= 2: break
        if groups.is_empty() or group.id != groups[0].id: groups.append(group)
    for group in replay_media_groups:
        if not groups.any(func(existing):return existing.id==group.id):groups.append(group)
    var ids: Array = groups.map(func(group):return group.id)
    # A group union includes every staged/committed outfit and world after-value.
    # Position/HP commits inside that same group cannot add a new media demand.
    # Repeated replay preparation of the current group has the same mandatory
    # closure as normal playback. Only additional crossed groups promote new
    # bytes from optional to required; include that distinction in the identity.
    var promoted_ids: Array = []
    for group in replay_media_groups:
        if ids.is_empty() or group.id != ids[0]: promoted_ids.append(group.id)
    var key: Array = [timeline.initialization_revision,ids,timeline.revision if ids.is_empty() else 0]
    if key == media_plan_key and promoted_ids == media_promoted_ids and not condition_changed and not native_changed:
        _publish_media_interest(maxf(timeline.display_ms,timeline.media_target_ms))
        _refresh_due_media_errors()
        # A completed older task may leave newer optional intent queued. The
        # displayed demand is already stable here; it must not wait for another
        # gameplay action merely because its media key did not change.
        if not media_warmup.optional_pending.is_empty():
            var dispatch_started:int=Time.get_ticks_usec()
            MediaWarmup._start_plan(media_warmup,true)
            FrameProfile.end_phase(profile,"media_optional_dispatch",dispatch_started)
        return
    var started = Time.get_ticks_usec()
    media_plan_key = key
    media_promoted_ids = promoted_ids
    _reset_media_epoch()
    if ids.is_empty():_adopt_terminal_media()
    if external_playback:
        var recorded:Dictionary=media_warmup.encounter_override.get("group_plans",{})
        for id in ids:
            if recorded.has(id):media_group_plans[id]=recorded[id]
    for id in media_group_plans.keys():
        var received: Dictionary = media_received_owners.get(id,{})
        if not received.is_empty() and is_same(_media_group_owner(id),received): continue
        media_received_owners.erase(id)
        if id not in ids: media_group_plans.erase(id)
    var ready: Dictionary = media_empty_plan if ids.is_empty() and media_empty_key==key else media_group_plans.get(ids[0],{}) if not ids.is_empty() else {}
    var upcoming: Dictionary = media_group_plans.get(ids[1],{}) if ids.size()>1 else {}
    # Promote the crossed prefix until publication or cancellation. Including
    # the current group again would only rebuild its existing closure.
    if not promoted_ids.is_empty():
        var crossed:Array=[]
        for id in promoted_ids:
            if not media_group_plans.has(id):
                media_metadata_ready=false
                media_issue="Recording has no exact media closure for replay group: "+id
                if media_issue not in presentation_errors:presentation_errors.append(media_issue)
                FrameProfile.end_phase(profile,"media_plan",started)
                return
            crossed.append(media_group_plans[id])
        if not ready.is_empty():crossed.push_front(ready)
        ready=_combined_media_plan(crossed)
    var needs_plan = ready.is_empty() or (ids.size()>1 and upcoming.is_empty())
    var session_owns_missing:bool=not ids.is_empty()
    for group in groups.slice(0,mini(2,groups.size())):
        if not media_group_plans.has(group.id) and not is_same(media_received_owners.get(group.id),group):
            session_owns_missing=false;break
    if needs_plan and not session_owns_missing and media_requested_key != key:
        var request_started = Time.get_ticks_usec()
        media_requested_key = key
        MediaWarmup.request_plan(media_warmup,key,timeline.state,groups)
        FrameProfile.end_phase(profile,"media_plan_request",request_started)
    media_metadata_ready = not ready.is_empty()
    if not media_metadata_ready:
        FrameProfile.end_phase(profile,"media_plan",started)
        return
    if external_playback:MediaWarmup.adopt_required(media_warmup,timeline.initialization_revision)
    var sets_started = Time.get_ticks_usec()
    # Accepted group metadata owns this one immutable projected window. Changes
    # in selection hints or current optical samples do not rebuild its source
    # paths, normal-profile projection, or environment/fixture role unions.
    var projection:Dictionary=media_plan.get("projection",{})
    if projection.is_empty() or projection.epoch!=timeline.initialization_revision or projection.profile!=character_light_profile \
            or not is_same(projection.ready,ready) or (not upcoming.is_empty() and not is_same(projection.upcoming,upcoming)) \
            or projection.upcoming.is_empty()!=upcoming.is_empty():
        var required_normal_sets:Dictionary=ready.get("normal_sets",{})
        var next_normal_sets:Dictionary=upcoming.get("normal_sets",{})
        media_normal_sets=required_normal_sets
        if not next_normal_sets.is_empty() and not is_same(required_normal_sets,next_normal_sets):
            media_normal_sets=required_normal_sets.duplicate();media_normal_sets.merge(next_normal_sets);media_normal_sets.make_read_only()
        var required_paths:Dictionary=CharacterGeometry.for_profile(ready.character,media_normal_sets,character_light_profile,catalog_cache,"required")
        var next_paths:Dictionary=CharacterGeometry.for_profile(upcoming.get("character",{}),media_normal_sets,character_light_profile,catalog_cache,"upcoming")
        projection={"epoch":timeline.initialization_revision,"profile":character_light_profile,"ready":ready,"upcoming":upcoming,
            "required":required_paths,"next":next_paths}
    var character_required:Dictionary=projection.required.duplicate()
    character_required.merge(media_condition_paths)
    character_required.merge(native_media_paths)
    var error_start:float=timeline.group_start_ms if not timeline.current.is_empty() and not ids.is_empty() and ids[0]==timeline.current.id else timeline.display_ms
    var due_errors:Array=MediaWarmup.errors_at(ready,maxf(timeline.display_ms,timeline.media_target_ms)-error_start)
    media_plan = {"projection":projection,"required":character_required,"upcoming":projection.next,
        "errors":due_errors,"upcoming_errors":upcoming.get("errors",[])}
    media_environment_required = ready.environment
    if not requested_character_light_profile.is_empty():
        character_profile_pending_paths=_requested_profile_normals(requested_character_light_profile)
        var pending_key:Array=[requested_character_light_profile,projection.ready,projection.upcoming]
        if media_profile_record.get("key",[])!=pending_key:
            media_profile_record={"key":pending_key,"value":MediaWarmup.source_record(character_profile_pending_paths,{},{},character_profile_pending_paths)}
    else:media_profile_record={}
    # Selection candidates use the same bounded source owner, after all received
    # authoritative paths. They never enter media_plan.required/readiness gates.
    if selection_media_hold_cursor>=0 and groups.any(func(group):return group.get("operation_sequence",-1)>=selection_media_hold_cursor and media_group_plans.has(group.id)):
        SelectionMedia.cancel(selection_media);selection_media_hold_cursor=-1
    var hints: Dictionary=selection_media.value
    selection_media_demand_paths=hints.get("paths",{})
    FrameProfile.end_phase(profile,"media_plan_sets",sets_started)
    _publish_media_interest(maxf(timeline.display_ms,timeline.media_target_ms))
    _prioritize_media(maxf(timeline.display_ms,timeline.media_target_ms))
    for message in media_plan.errors+media_plan.upcoming_errors:
        if not message in presentation_errors: presentation_errors.append(message)
    _refresh_due_media_errors()
    # The existing end-of-frame retirement lane owns eviction and CPU-image
    # release, including its explicit over-budget cleanup. Doing that here as
    # well bypasses the shared allowance before required effect preparation.
    FrameProfile.end_phase(profile,"media_plan",started)

static func _same_source_refs(a:Array,b:Array)->bool:
    if a.size()!=b.size():return false
    for i in a.size():
        if not is_same(a[i],b[i]):return false
    return true

func _publish_media_interest(at_ms:float)->void:
    if not media_metadata_ready:return
    var record_sets:Array=[];var families:Array=[]
    var group:Dictionary=timeline.current if not timeline.current.is_empty() else timeline.queue[0] if not timeline.queue.is_empty() else {}
    var current_plan:Dictionary=media_group_plans.get(group.get("id",""),media_empty_plan)
    if group.is_empty():
        # The terminal plan describes the previous operation's final sources;
        # its initial cut is not the outfit currently on screen.
        record_sets.append(current_plan.get("source_records",{}).get(character_light_profile,[]))
    elif external_playback:
        # Explicit seeks own their complete crossed prefix. The metadata loader
        # already constructed these immutable contributions off the scene thread.
        current_plan=media_plan.get("projection",{}).get("ready",current_plan)
        record_sets.append(current_plan.get("source_records",{}).get(character_light_profile,[]))
    else:
        var start:float=timeline.group_start_ms if is_same(group,timeline.current) else timeline.display_ms
        start=maxf(start,float(group.get("preview_start_ms",start)))
        var local:float=maxf(0.0,at_ms-start)
        var schedule:Dictionary=current_plan.get("source_cuts",{}).get(character_light_profile,{})
        var group_records:Array=current_plan.get("source_records",{}).get(character_light_profile,[])
        record_sets.append(MediaWarmup.records_at(schedule,local,group_records))
        # Clip and effect changes bind in sampling, not behind a preparation
        # that pinned their media early: load the group's later cuts now too.
        if not timeline.source_cut_boundaries:record_sets.append(MediaWarmup.records_at(schedule,INF,group_records))
    # A private candidate owns real resources too. Keep its exact cut pinned
    # while it is prepared, even when that cut is later than displayed time.
    for prepared_owner in [pending_world,prepared_actor_owner]:
        if prepared_owner==null or prepared_owner.initial or prepared_owner.stale or prepared_owner.epoch!=timeline.initialization_revision:continue
        var boundary:Dictionary=prepared_owner.boundary
        if not boundary.get("replay",false):
            var future:Dictionary=media_group_plans.get(boundary.source_group_id,{})
            if not future.is_empty():record_sets.append(MediaWarmup.records_at(future.get("source_cuts",{}).get(character_light_profile,{}),boundary.source_local_ms,
                future.get("source_records",{}).get(character_light_profile,[])))
    if _static_forecast_base_matches():
        var boundary:Dictionary=static_forecast.boundary
        var future:Dictionary=media_group_plans.get(boundary.source_group_id,{})
        if not future.is_empty():record_sets.append(MediaWarmup.records_at(future.get("source_cuts",{}).get(character_light_profile,{}),boundary.source_local_ms,
            future.get("source_records",{}).get(character_light_profile,[])))
    if not displayed_source_records.is_empty():record_sets.append(displayed_source_records)
    # Current, displayed and pending owners can borrow the same immutable cut.
    # Keep all their leases above, but flatten each exact source set only once.
    var unique_sets:Array=[]
    for selected in record_sets:
        if not unique_sets.any(func(previous):return is_same(previous,selected)):unique_sets.append(selected)
    record_sets=unique_sets
    for id in media_plan_key[1] if media_plan_key.size()>1 else []:
        var family:Dictionary=media_group_plans.get(id,{}).get("source_families",{}).get(character_light_profile,{})
        if not family.is_empty() and not families.any(func(value):return is_same(value,family)):families.append(family)
    var extras:Array=[]
    for record in [media_condition_record,native_media_record,media_profile_record.get("value",{})]:
        if not record.is_empty():extras.append(record)
    for prepared_owner in [pending_world,prepared_actor_owner]:
        if prepared_owner!=null and not prepared_owner.stale and prepared_owner.epoch==timeline.initialization_revision \
                and not prepared_owner.environment_source_record.is_empty():extras.append(prepared_owner.environment_source_record)
    if _static_forecast_base_matches() and static_forecast.task<0 and static_forecast.output.get("complete",false):
        var record:Dictionary=static_forecast.output.static_result.environment_source_record
        if not record.is_empty():extras.append(record)
    if component_renderer.native_spells.actor_bindings_needed():
        for prepared_owner in [pending_world,prepared_actor_owner]:
            if prepared_owner!=null and not prepared_owner.stale and prepared_owner.epoch==timeline.initialization_revision \
                    and not prepared_owner.required_source_record.is_empty():extras.append(prepared_owner.required_source_record)
    var hints:Dictionary=selection_media.value
    var same_records:bool=not media_interest.is_empty() and _same_source_refs(media_interest.sets,record_sets) and _same_source_refs(media_interest.extras,extras)
    if same_records and _same_source_refs(media_interest.families,families) and is_same(media_interest.hints,hints):return
    var started:int=Time.get_ticks_usec();var budget:Dictionary=_preparation_budget();var before:int=budget.used_usec
    var records:Array=media_interest.records if same_records else []
    if not same_records:
        var seen:Dictionary={}
        for selected in record_sets:MediaWarmup.append_source_records(records,seen,selected)
        MediaWarmup.append_source_records(records,seen,extras)
        records.make_read_only()
    MediaWarmup.demand_records(media_warmup,records,hints,families)
    media_interest={"sets":record_sets,"extras":extras,"families":families,"hints":hints,"records":records}
    for name in media_warmup.get("demand_phases",{}):
        if name!="total":
            var phase_name:String="media_demand_"+name
            profile.phases[phase_name]=profile.phases.get(phase_name,0.0)+media_warmup.demand_phases[name]
    _charge_preparation("source_publication",started,before)
    FrameProfile.end_phase(profile,"media_plan_demand",started)

func _adopt_terminal_media()->void:
    if media_terminal_plan.is_empty():return
    # The completed group's latest plan owns its terminal sources, including a
    # continuation that replaced the early opening plan. Transfer that lease
    # before the same-frame optional lane can withdraw its old requirements.
    var terminal:Dictionary=media_terminal_plan
    if terminal.epoch==timeline.initialization_revision and is_same(terminal.state,timeline.state) \
            and terminal.revision==timeline.revision and terminal.completed==timeline.completed_group_count \
            and not timeline.completed_groups.is_empty() and timeline.completed_groups.back().id==terminal.id:
        media_empty_key=[timeline.initialization_revision,[],timeline.revision]
        media_empty_plan=media_group_plans[terminal.id]
    media_terminal_plan={}

func _retain_displayed_sources()->void:
    var group:Dictionary=timeline.current if not timeline.current.is_empty() else timeline.queue[0] if not timeline.queue.is_empty() else {}
    if group.is_empty():_adopt_terminal_media()
    var selected:Dictionary=media_group_plans.get(group.get("id",""),media_empty_plan)
    if group.is_empty() or external_playback:
        displayed_source_records=selected.get("source_records",{}).get(character_light_profile,[])
    else:
        var local:float=timeline.display_ms-(timeline.group_start_ms if is_same(group,timeline.current) else timeline.display_ms)
        displayed_source_records=MediaWarmup.records_at(selected.get("source_cuts",{}).get(character_light_profile,{}),local,
            selected.get("source_records",{}).get(character_light_profile,[]))

func _refresh_due_media_errors()->void:
    if media_issue==media_source_issue:media_issue=""
    media_source_issue=""
    var group:Dictionary=timeline.current if not timeline.current.is_empty() else timeline.queue[0] if not timeline.queue.is_empty() else {}
    var plan:Dictionary=media_group_plans.get(group.get("id",""),media_empty_plan)
    var start:float=timeline.group_start_ms if is_same(group,timeline.current) else timeline.display_ms
    var at:float=maxf(timeline.display_ms,timeline.media_target_ms)
    if not external_playback:media_plan.errors=MediaWarmup.errors_at(plan,at-start)
    if not media_plan.errors.is_empty():media_source_issue=media_plan.errors[0]
    if not media_warmup.failed.is_empty():
        var characters:Dictionary=_character_source_paths(group,at)
        var environment:Dictionary=_environment_source_paths(group,at)
        for path in media_warmup.failed:
            if characters.has(path) or environment.has(path) or media_condition_paths.has(path) or native_media_paths.has(path):
                media_source_issue=media_warmup.failed[path];break
    if not media_source_issue.is_empty():media_issue=media_source_issue

func _release_replay_media() -> void:
    if replay_media_groups.is_empty():return
    replay_media_groups=[]

func _combined_media_plan(plans:Array)->Dictionary:
    var result={"character":{},"environment":{},"fixtures":{},"gpu_only":{},"cpu_required":{},"normal_sets":{},"errors":[],"source_records":{}}
    var seen_records:Dictionary={}
    for plan in plans:
        for field in ["character","environment","fixtures","gpu_only","cpu_required","normal_sets"]:result[field].merge(plan.get(field,{}))
        for issue in plan.get("errors",[]):
            if issue not in result.errors:result.errors.append(issue)
        for profile in plan.get("source_records",{}):
            if not result.source_records.has(profile):
                result.source_records[profile]=[];seen_records[profile]={}
            MediaWarmup.append_source_records(result.source_records[profile],seen_records[profile],plan.source_records[profile])
    for path in result.cpu_required:result.gpu_only.erase(path)
    return result

func _replay_media_ready(plan:Dictionary)->bool:
    if not external_playback or not timeline.replay_plan_current(plan):return false
    _reset_media_epoch()
    var groups:Array=plan.groups
    if replay_media_groups!=groups:
        replay_media_groups=groups
    component_renderer.ensure_epoch(self)
    var budget:Dictionary=_preparation_budget()
    var started:int=Time.get_ticks_usec();var before:int=budget.used_usec
    var native=component_renderer.prepare(groups,catalog_cache,self,budget,false)
    _charge_preparation("required_components",started,before)
    # Native sources discover their optical image demand during preparation.
    # Include it before declaring the replay's media closure ready.
    _prepare_media()
    for issue in native.errors:
        if issue not in presentation_errors:presentation_errors.append(issue)
    return _native_startup_ready(float(plan.display_ms)) and media_metadata_ready and media_issue.is_empty() and media_plan.errors.is_empty() \
        and MediaWarmup.ready(media_warmup,media_plan.required) and _environment_sources_ready() \
        and MediaWarmup.boot_ready(media_warmup) and native.ready and world_revision>=0 \
        and not (pending_world!=null and pending_world.admitted)

func _source_group_ready(group:Dictionary)->bool:
    if group.is_empty() or not is_same(media_received_owners.get(group.id),group):return true
    var plan:Dictionary=media_group_plans.get(group.id,{})
    if plan.is_empty():return false
    if not plan.has("coverage_until_ms"):return true
    var start:float=timeline.group_start_ms if is_same(group,timeline.current) else timeline.display_ms
    var local:float=maxf(timeline.display_ms,timeline.media_target_ms)-start
    return local<float(plan.coverage_until_ms)-0.000001

func _media_ready(group: Dictionary) -> bool:
    # Early compiler delivery grants only passive projection. Native resources
    # consume the complete source catalog and exact media plan, never a prefix.
    if not _source_group_ready(group):
        media_gate={"metadata":false,"native":false,"sources":false,"environment":false,
            "boot":MediaWarmup.boot_ready(media_warmup),"admitted_world_pending":false}
        media_initial_ready=false
        return false
    component_renderer.ensure_epoch(self)
    var budget:Dictionary=_preparation_budget()
    var started:int=Time.get_ticks_usec();var before:int=budget.used_usec
    var native=component_renderer.prepare([group],catalog_cache,self,budget,false,maxf(timeline.display_ms,timeline.media_target_ms))
    _charge_preparation("required_components",started,before)
    _prepare_media(group)
    for issue in native.errors:
        if issue not in presentation_errors:presentation_errors.append(issue)
    media_gate={"native":native.ready,"components":component_renderer.readiness.duplicate(),
        "sources":_character_sources_ready(group,timeline.media_target_ms),"environment":_playback_environment_ready(group,timeline.media_target_ms),
        "metadata":media_metadata_ready,"boot":MediaWarmup.boot_ready(media_warmup),
        "admitted_world_pending":pending_world!=null and pending_world.admitted}
    media_initial_ready = _native_startup_ready(timeline.display_ms) and media_gate.metadata and not timeline.state.is_empty() and media_issue.is_empty() and media_plan.errors.is_empty() and media_gate.sources and media_gate.environment and media_gate.boot
    var ready: bool = media_initial_ready and native.ready and world_revision>=0 and not (pending_world!=null and pending_world.admitted)
    if ready and not group.is_empty() and media_group_plans.has(group.id) \
        and not media_plan_key[1].is_empty() and media_plan_key[1][0] == group.id:
        if media_terminal_plan.is_empty() or media_terminal_plan.id != group.id:
            var committed: int = timeline.commit_index if is_same(timeline.current,group) else 0
            media_terminal_plan = {"id":group.id,"epoch":timeline.initialization_revision,"state":timeline.state,
                "revision":timeline.revision+group.commits.size()-committed,
                "completed":timeline.completed_group_count+1}
    return ready

func _environment_media_ready() -> bool:
    return world_revision>=0 and _environment_sources_ready()

func _character_source_paths(group:Dictionary={},at_ms:float=-1.0)->Dictionary:
    var paths:Dictionary=media_plan.required
    if not external_playback:
        if group.is_empty():group=timeline.current
        if group.is_empty() and not timeline.queue.is_empty():group=timeline.queue[0]
        if not group.is_empty():
            var plan:Dictionary=media_group_plans.get(group.id,{})
            var start_ms:float=timeline.group_start_ms if is_same(group,timeline.current) else timeline.display_ms
            start_ms=maxf(start_ms,float(group.get("preview_start_ms",start_ms)))
            var local_ms:float=(timeline.display_ms if at_ms<0 else at_ms)-start_ms
            var due:Dictionary=MediaWarmup.required_at(plan.get("character_timeline",{}),local_ms,plan.get("character",paths))
            paths=CharacterGeometry.for_profile(due,media_normal_sets,character_light_profile,catalog_cache,"character_due")
    return paths

func _character_sources_ready(group:Dictionary={},at_ms:float=-1.0)->bool:
    return MediaWarmup.ready(media_warmup,_character_source_paths(group,at_ms)) and MediaWarmup.ready(media_warmup,media_condition_paths) and MediaWarmup.ready(media_warmup,native_media_paths)

func _environment_source_paths(group:Dictionary={},at_ms:float=-1.0)->Dictionary:
    var paths:Dictionary=media_environment_required
    if not external_playback:
        if group.is_empty():group=timeline.current
        if group.is_empty() and not timeline.queue.is_empty():group=timeline.queue[0]
        if not group.is_empty():
            var plan:Dictionary=media_group_plans.get(group.id,{})
            var start_ms:float=timeline.group_start_ms if is_same(group,timeline.current) else timeline.display_ms
            start_ms=maxf(start_ms,float(group.get("preview_start_ms",start_ms)))
            var local_ms:float=(timeline.display_ms if at_ms<0 else at_ms)-start_ms
            paths=EnvironmentMedia.required_at(plan.get("environment_timeline",{}),local_ms,paths)
    return paths

func _environment_sources_ready(group:Dictionary={},at_ms:float=-1.0) -> bool:
    return media_metadata_ready and media_plan.errors.is_empty() and MediaWarmup.ready(media_warmup,_environment_source_paths(group,at_ms))

func _playback_environment_ready(group:Dictionary={},at_ms:float=-1.0)->bool:
    # Initial loading and replay keep their exhaustive source contracts. In a
    # live displayed world, selectors change only at world cuts; _world_ready
    # owns their complete constructor/CPU/fixture proof before clock/state can
    # cross them. Do not make that same cut wait for unused camera views here.
    if external_playback or world_revision<0:return _environment_sources_ready(group,at_ms)
    return world_prepare_epoch==timeline.initialization_revision and media_metadata_ready and media_plan.errors.is_empty()

func _prioritize_media(at_ms:float)->Dictionary:
    var prioritize_started:int=Time.get_ticks_usec()
    var due:Dictionary=_prioritized_media(at_ms)
    FrameProfile.end_phase(profile,"media_prioritize",prioritize_started)
    return due

func _prioritized_media(at_ms:float)->Dictionary:
    var interest_started:int=Time.get_ticks_usec()
    _publish_media_interest(at_ms)
    FrameProfile.end_phase(profile,"media_prioritize_interest",interest_started)
    # Readiness and preparation use the same authored cut. Keeping a later cue
    # pinned does not let it displace the sources needed to start this one.
    # Every part below is an immutable or replaced-on-change path map, so the
    # composed set is rebuilt only when one of them is a different object.
    var current_parts:Array=[_character_source_paths({},at_ms)]
    if external_playback or world_revision<0:current_parts.append(_environment_source_paths({},at_ms))
    current_parts.append(media_condition_paths)
    current_parts.append(native_media_paths)
    if not external_playback and timeline.current.is_empty() and timeline.queue.is_empty():current_parts.append(selection_media.value.get("onset_paths",EMPTY_PATHS))
    if not _same_source_refs(current_parts,media_due_current_parts):
        var differing:Array=[]
        for index in current_parts.size():
            if index>=media_due_current_parts.size() or not is_same(current_parts[index],media_due_current_parts[index]):differing.append(index)
        profile.media_due_current_changes=differing
        var composed:Dictionary={}
        for part in current_parts:composed.merge(part)
        composed.make_read_only()
        media_due_current_parts=current_parts;media_due_current=composed
    # Current source/CPU/fixture requirements have strict priority. Future
    # resources keep their existing pins, but cannot fill urgent decode slots
    # while a newly selected animation still lacks one of its own operands.
    # Readiness of the current set only decides whether future cuts may join.
    # Without a prepared candidate or forecast there is nothing to join.
    var future_world:bool=pending_world!=null and not pending_world.stale and pending_world.epoch==timeline.initialization_revision and pending_world.quarter==quarter
    var future_forecast:bool=_static_forecast_base_matches()
    var prepare_future:bool=false
    if (future_world or future_forecast) and not external_playback and world_revision>=0:
        var ready_started:int=Time.get_ticks_usec()
        prepare_future=MediaWarmup.ready(media_warmup,media_due_current)
        FrameProfile.end_phase(profile,"media_prioritize_ready",ready_started)
    var future_characters:Array=[];var future_environment:Array=[]
    if prepare_future and future_world:
        future_environment.append(pending_world.result.get("environment_paths",EMPTY_PATHS))
        # These actors are already in the received cut being prepared. Their
        # exact selected sheets must publish ahead of constructors that depend
        # on them, rather than wait until the displayed clock hits the reveal.
        var boundary:Dictionary=pending_world.boundary
        var future:Dictionary=media_group_plans.get(boundary.get("source_group_id",""),EMPTY_PATHS)
        if not future.is_empty():
            var paths:Dictionary=MediaWarmup.required_at(future.get("character_timeline",EMPTY_PATHS),float(boundary.get("source_local_ms",0)),future.get("character",EMPTY_PATHS))
            future_characters.append(CharacterGeometry.for_profile(paths,media_normal_sets,character_light_profile,catalog_cache,"prepared_character_due"))
    if prepare_future and future_forecast:
        var boundary:Dictionary=static_forecast.boundary
        if static_forecast.task<0 and static_forecast.output.get("complete",false):future_environment.append(static_forecast.output.static_result.environment_paths)
        var future:Dictionary=media_group_plans.get(boundary.source_group_id,EMPTY_PATHS)
        if not future.is_empty():
            var paths:Dictionary=MediaWarmup.required_at(future.get("character_timeline",EMPTY_PATHS),float(boundary.source_local_ms),future.get("character",EMPTY_PATHS))
            future_characters.append(CharacterGeometry.for_profile(paths,media_normal_sets,character_light_profile,catalog_cache,"forecast_character_due"))
    # The displayed/onset cut above keeps strict priority. Once it is ready,
    # the next cut's actor and environment producers are independent: missing
    # future actor pixels must not hold unrelated room resources behind them.
    var parts:Array=[media_due_current]+future_characters+future_environment
    if _same_source_refs(parts,media_due_parts):
        profile.media_due_reused=int(profile.get("media_due_reused",0))+1
        return media_due
    profile.media_due_rebuilt=int(profile.get("media_due_rebuilt",0))+1
    var due:Dictionary=media_due_current
    if parts.size()>1:
        due={}
        for part in parts:due.merge(part)
        due.make_read_only()
    media_due_parts=parts;media_due=due
    MediaWarmup.prioritize(media_warmup,due)
    return due

func _adopt_media_plan(completed: Dictionary, offer_to_session:bool=true) -> void:
    if completed.is_empty() or completed.key[0] != timeline.initialization_revision: return
    if completed.get("stage","")=="optional":
        # Optional families may finish after the requested group/window changed.
        # They never replace required plans or re-open their readiness boundary.
        if completed.key != media_requested_key: return
        if completed.has("error"):
            if completed.error not in presentation_errors: presentation_errors.append(completed.error)
            return
        Catalog.adopt_snapshot(catalog_cache,completed.get("source_files",{}))
        if offer_to_session and session!=null:session.offer_prepared_sources(completed.get("source_files",{}),completed.get("source_headers",{}))
        MediaWarmup.adopt_encounter(media_warmup,completed.value.encounter,timeline.initialization_revision)
        media_plan_key = []
        return
    # Worker-published raw authoring is immutable; avoid synchronous JSON loads
    # when this exact prepared outfit/world first binds on the scene thread.
    Catalog.adopt_snapshot(catalog_cache,completed.get("source_files",{}))
    # A handoff from the session already belongs to its source cache. Return
    # only locally prepared metadata, not the session's entire cache each cast.
    if offer_to_session and session!=null:session.offer_prepared_sources(completed.get("source_files",{}),completed.get("source_headers",{}))
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
    MediaWarmup.adopt_required(media_warmup,timeline.initialization_revision)
    MediaWarmup.adopt_source_sizes(media_warmup,value.get("source_sizes",{}),timeline.initialization_revision)
    if value.has("encounter"): MediaWarmup.adopt_encounter(media_warmup,value.encounter,timeline.initialization_revision)
    var ids: Array = completed.key[1]
    var first_fixtures = {}
    var next_fixtures = {}
    for path in value.fixtures:
        if value.environment_required.has(path): first_fixtures[path] = true
        if value.environment_upcoming.has(path): next_fixtures[path] = true
    var first = {"character":value.required,"environment":value.environment_required,"errors":value.errors,"fixtures":first_fixtures,
        "source_records":value.get("source_records",{}).get(ids[0] if not ids.is_empty() else "",{}),
        "source_cuts":value.get("source_cuts",{}).get(ids[0] if not ids.is_empty() else "",{}),
        "source_families":value.get("source_families",{}).get(ids[0] if not ids.is_empty() else "",{})}
    if completed.has("coverage_until_ms"):first.coverage_until_ms=completed.coverage_until_ms
    if not ids.is_empty():first.error_timeline=value.get("character_error_timeline",{}).get(ids[0],[])
    first.merge(MediaWarmup.roles_for(value,value.required))
    if ids.is_empty():
        media_empty_key = completed.key
        media_empty_plan = first
    else:
        first.environment_timeline=value.get("environment_timeline",{}).get(ids[0],{})
        first.character_timeline=value.get("character_timeline",{}).get(ids[0],{})
        if not media_group_plans.has(ids[0]) or (media_group_plans[ids[0]].has("coverage_until_ms") and not first.has("coverage_until_ms")):media_group_plans[ids[0]]=first
        if ids.size()>1 and not media_group_plans.has(ids[1]):
            media_group_plans[ids[1]] = {"character":value.upcoming,"environment":value.environment_upcoming,"errors":value.upcoming_errors,"fixtures":next_fixtures,
                "source_records":value.get("source_records",{}).get(ids[1],{}),
                "source_cuts":value.get("source_cuts",{}).get(ids[1],{}),
                "source_families":value.get("source_families",{}).get(ids[1],{})}
            media_group_plans[ids[1]].environment_timeline=value.get("environment_timeline",{}).get(ids[1],{})
            media_group_plans[ids[1]].character_timeline=value.get("character_timeline",{}).get(ids[1],{})
            media_group_plans[ids[1]].error_timeline=value.get("character_error_timeline",{}).get(ids[1],[])
            media_group_plans[ids[1]].merge(MediaWarmup.roles_for(value,value.upcoming))
    media_plan_key = []

func set_normals_visible(value: bool) -> void:
    requested_normals_visible = value
    _publish_normals(value)

func _publish_normals(value: bool) -> void:
    if normals_visible == value: return
    normals_visible = value
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

func _release_actor_source(path:String) -> void:
    for visual in visual_actors.values():
        for entry in visual.entries:
            if entry.get("texture_path","")==path:
                SourceMaterial.set_parameter(entry,"sheet",null)
                entry.erase("bound_frame_key");entry.erase("texture_path")
                entry.node.visible=false
            if entry.get("geometry_paths",{}).has(path):CharacterGeometry.clear(entry)

func _prune_character_media(budget:Dictionary={},minimum:bool=false) -> void:
    if not budget.is_empty() and budget.used_usec>=budget.limit_usec and not minimum:return
    var charged_before:int=budget.get("used_usec",0)
    var admission_started:int=Time.get_ticks_usec()
    var started=Time.get_ticks_usec()
    var released_images:Array=[]
    for path in MediaWarmup.release_cold_images(media_warmup):
        released_images.append(source_images.get(path));source_images.erase(path)
    BackgroundRelease.release(released_images)
    FrameProfile.end_phase(profile,"media_release_cpu",started)
    started=Time.get_ticks_usec()
    var retired_paths:Array=MediaWarmup.prune(media_warmup)
    FrameProfile.end_phase(profile,"media_prune_select",started)
    started=Time.get_ticks_usec()
    for path in retired_paths:
        for owner in MediaWarmup.hosts(media_warmup):owner._release_actor_source(path)
        if textures.erase(path):texture_revision+=1
        source_images.erase(path)
        texture_last_use.erase(path)
    FrameProfile.end_phase(profile,"media_prune_retire",started)
    if not budget.is_empty():
        if minimum and charged_before>=budget.limit_usec:budget.minimum_cleanup+=retired_paths.size()
        _charge_preparation("media_retirement",admission_started,charged_before)

func _warm_media(required_only:bool=false,budget:Dictionary={},through_ms:float=-1.0) -> void:
    var completed:Dictionary=MediaWarmup.poll_plan(media_warmup)
    if not completed.is_empty():
        _adopt_media_plan(completed)
        # A worker may finish after the early poll. Its demand projection must
        # precede prioritization/publication, including in the optional lane.
        _prepare_media()
    # Full received closures stay pinned, but future textures are not urgent
    # merely because they are in that closure. When the displayed sources are
    # ready, leave publication to the rotating optional lane so a received world
    # boundary can be prepared during its preceding animation.
    var required_at:float=maxf(timeline.display_ms,timeline.media_target_ms) if through_ms<0 else through_ms
    var due:Dictionary=_prioritize_media(required_at)
    var background_handoff:bool=false
    if required_only and media_metadata_ready and MediaWarmup.ready(media_warmup,due):
        # Completed private textures release finite decode slots independently
        # of optional library selection. Receipts use the existing per-frame
        # image/time limits; a ready future source is not a reason to run the
        # optional family planner before mandatory native construction.
        background_handoff=MediaWarmup.physical(media_warmup).worker_upload and pending_world!=null and not pending_world.prepared \
            and budget.get("background_source_handoffs",0)<MediaWarmup.PUBLICATIONS_PER_FRAME
        if not background_handoff:
            _poll_character_light_profile()
            return
    if not required_only:
        var maintenance_started:int=Time.get_ticks_usec();var maintenance_before:int=budget.get("used_usec",0)
        var physical_media:Dictionary=MediaWarmup.physical(media_warmup)
        physical_media.optional_phases={}
        MediaWarmup.prepare_optional(media_warmup)
        if not budget.is_empty():_charge_preparation("media_optional_maintenance",maintenance_started,maintenance_before)
        FrameProfile.end_phase(profile,"media_optional_maintenance",maintenance_started)
        for part in ["family","selection","pending"]:
            var phase_name:String="media_optional_"+part
            profile.phases[phase_name]=profile.phases.get(phase_name,0.0)+float(physical_media.optional_phases.get(part,0.0))
    var tick = Time.get_ticks_usec()
    var charged_before:int=budget.get("used_usec",0)
    var owner:Dictionary=MediaWarmup.physical(media_warmup)
    var previous:Dictionary=owner.publication if owner.publication.get("frame",-1)==Engine.get_process_frames() else {}
    var count:int=previous.get("count",0)
    var required:int=previous.get("required",0)
    var uploads:Array=previous.get("uploads",[]).duplicate()
    # At least one complete image may publish even if it alone exceeds budget.
    # Continue cheap required uploads in this frame; optional warming gets at
    # most one publication and never consumes a required backlog's turn.
    while count < MediaWarmup.PUBLICATIONS_PER_FRAME:
        if not budget.is_empty() and budget.used_usec>=budget.limit_usec:
            MediaWarmup.poll_sources(media_warmup,true,false) # Dispatch without optional maintenance or receipt.
            break
        if count>0 and previous.get("elapsed_ms",0.0)*1000.0+Time.get_ticks_usec()-tick>=MediaWarmup.PUBLICATION_BUDGET_USEC: break
        var loaded = MediaWarmup.poll_sources(media_warmup,required_only or count>0)
        if loaded.is_empty(): break
        count += 1
        if background_handoff:budget.background_source_handoffs=int(budget.get("background_source_handoffs",0))+1
        if media_warmup.wanted.has(loaded.path): required += 1
        MediaWarmup.validate_upload_dimensions(media_warmup,loaded,maximum_texture_size_2d)
        if loaded.has("error"):
            var message: String = loaded.error
            if not message in presentation_errors: presentation_errors.append(message)
            # The failed source remains recorded by its owner. Only its actual
            # authored cue may block display; optional/late failures cannot
            # prevent an already prepared opening from starting.
            continue
        var started = Time.get_ticks_usec()
        source_images[loaded.path] = loaded.image
        if loaded.has("energy"): fixture_frame_energy[loaded.path] = loaded.energy
        if loaded.has("emission_centroid"): fixture_frame_centroids[loaded.path] = loaded.emission_centroid
        var phase=Time.get_ticks_usec()
        var created:bool=not textures.has(loaded.path)
        if created:
            textures[loaded.path] = loaded.texture if loaded.has("texture") else ImageTexture.create_from_image(loaded.image)
            texture_revision+=1
        var creation_ms:float=(Time.get_ticks_usec()-phase)/1000.0
        FrameProfile.end_phase(profile,"media_texture_create",phase)
        uploads.append({"path":loaded.path,"created":created,"create_ms":creation_ms,"worker_upload_ms":loaded.get("worker_upload_ms",0.0),"decode_ms":loaded.get("elapsed_ms",0.0),"decode_phases_ms":loaded.get("phases_ms",{}),"worker_clock_us":loaded.get("worker_clock_us",{}),"width":loaded.image.get_width(),"height":loaded.image.get_height(),"gpu_estimated_bytes":loaded.gpu_bytes})
        texture_last_use[loaded.path] = Time.get_ticks_msec()
        phase=Time.get_ticks_usec()
        MediaWarmup.published(media_warmup,loaded)
        FrameProfile.end_phase(profile,"media_publish_accounting",phase)
        if not budget.is_empty():budget.used_usec+=maxi(0,Time.get_ticks_usec()-tick-(budget.used_usec-charged_before))
        # Retirement has its own bounded lane below. Doing it after every image
        # let speculative uploads spend the world's preparation allowance on
        # unrelated eviction. The end-of-frame over-budget cleanup still runs.
        FrameProfile.end_phase(profile,"media_upload",started)
        if not budget.is_empty():budget.used_usec+=maxi(0,Time.get_ticks_usec()-tick-(budget.used_usec-charged_before))
    if not budget.is_empty():_charge_preparation("media_upload",tick,charged_before)
    owner.publication = {"frame":Engine.get_process_frames(),"count":count,"required":required,"optional":count-required,"uploads":uploads,
        "elapsed_ms":previous.get("elapsed_ms",0.0)+(Time.get_ticks_usec()-tick)/1000.0,"budget_ms":MediaWarmup.PUBLICATION_BUDGET_USEC/1000.0}
    _poll_character_light_profile()

func _sample_actors() -> void:
    var inputs_started:int=Time.get_ticks_usec()
    var sampling_counts:Dictionary={"actors":0,"visible_layers":0,"source_changes":0,"uv_only_changes":0,"full_source_changes":0,"retained_poses":0,"validated_outfits":0}
    profile.actor_sample_counts=sampling_counts
    var rendered_state = timeline.presentation_state()
    var staged: Dictionary = timeline.staged_actors()
    var directions: Dictionary = timeline.actor_directions()
    var layer_samples={}
    var layer_sample_actors:Dictionary={}
    var condition_ages={}
    var material_samples:Dictionary={}
    for component in displayed_components:
        if component.kind=="sprite_layer":
            layer_samples[component.id]=component;layer_sample_actors[component.actor_uuid]=true
        elif component.kind=="condition": condition_ages[component.condition_uuid]=component.age_ms
        if component.kind in ["condition","material_flash","body_surface"]:
            var actor_id:String=component.actor_uuid
            if not material_samples.has(actor_id):material_samples[actor_id]=[]
            material_samples[actor_id].append(component)
    FrameProfile.end_phase(profile,"actor_sprite_inputs",inputs_started)
    for id in visual_actors:
        var actor_setup_started:int=Time.get_ticks_usec()
        var visual: Dictionary = visual_actors[id]
        var row: Dictionary = visual.row
        if directions.has(id):
            var points: Array=directions[id]
            row.facing=_facing(Vector2(points[1][0]-points[0][0],points[1][1]-points[0][1]))
        elif external_playback: row.facing="SW"
        var actor: Dictionary = timeline.state.actors.get(id,staged.get(id,{}))
        if actor.is_empty() or not visual.valid or actor.get("last_visual_position") == null:
            visual.erase("sampled_pose")
            for entry in visual.entries: entry.node.visible = false
            FrameProfile.end_phase(profile,"actor_sprite_setup",actor_setup_started)
            continue
        var show = WorldRows.visible_actor(actor,timeline.state,staged.has(id))
        show = show and actor.get("spatial_disposition","present") == "present" and actor.get("remains_disposition","intact") != "disintegrated"
        if not show:
            visual.erase("sampled_pose")
            for entry in visual.entries: entry.node.visible = false
            FrameProfile.end_phase(profile,"actor_sprite_setup",actor_setup_started)
            continue
        var sample: Dictionary = displayed_samples.get(id,{})
        row.visual_height = float(sample.get("lift_pixels",0))*(128.0/rig_config.TILE_W)/64.0
        var rig: Dictionary = rigs[row.rig]
        var resting = Characters.rest_sample(actor,rig,catalog_cache)
        var condition_pose=Conditions.pose(actor,row.rig,catalog_cache)
        var material_state=Conditions.material(id,material_samples.get(id,[]))
        # Material values are independently clocked from the sprite frame. In
        # particular, damage/body surfaces must keep sampling between frames,
        # while an unchanged resting body need not resend every shader uniform.
        var projected:Dictionary=Conditions.parameters(material_state,textures,resources)
        # Each actor owns one immutable set of actual shader operands. All its
        # layers consume that same value; clocks still change it when sampled.
        if visual.get("condition_parameters",{})!=projected:
            visual.condition_parameters=projected.duplicate(true)
            visual.condition_parameters.make_read_only()
        var material_parameters:Dictionary=visual.condition_parameters
        if not resting.ok:
            if not resting.error.message in presentation_errors: presentation_errors.append(resting.error.message)
            visual.erase("sampled_pose")
            for entry in visual.entries: entry.node.visible = false
            FrameProfile.end_phase(profile,"actor_sprite_setup",actor_setup_started)
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
        elif not condition_pose.is_empty() and rig.clips.has(condition_pose.clip):
            idle=condition_pose.clip
            seconds=Conditions.ConditionPose.source_seconds(condition_pose,rig.clips[idle],condition_ages.get(condition_pose.condition_uuid,0.0))
            occurrence="condition_pose:"+condition_pose.condition_uuid+":"+idle
        FrameProfile.end_phase(profile,"actor_sprite_setup",actor_setup_started)
        var graph_started:int=Time.get_ticks_usec()
        var sampled = Graphs.sample(playbacks[id],idle,seconds,occurrence)
        FrameProfile.end_phase(profile,"actor_sprite_graph",graph_started)
        if not sampled.ok:
            if not sampled.error.message in presentation_errors: presentation_errors.append(sampled.error.message)
            visual.erase("sampled_pose")
            for entry in visual.entries: entry.node.visible = false
            continue
        sampling_counts.actors+=1
        var outfit_started:int=Time.get_ticks_usec()
        var playback: Node = playbacks[id]
        var clip: Dictionary = rig.clips[playback.clip]
        var cycle: Array = rig_config.FACING_CYCLE
        var facing: String = cycle[posmod(cycle.find(row.facing)+quarter*2,8)]
        var frame = mini(int(playback.sample_seconds*clip.fps),int(clip.frames)-1)
        var pose_key:Array=[playback.clip,frame,facing,row.position,row.base_height_steps,row.visual_height,
            row.get("scale_x",1.0),row.scale,camera.basis,quarter,source_depth,source_normals,character_light_profile,
            sample.get("hidden_slots",[]),sample.get("passage_weight",0.0),
            sample.get("passage",{}).get("passageSocket"),sample.get("passage",{}).get("passageBodyHeightPx"),
            sample.get("passage",{}).get("passageScale"),world_generation,MediaWarmup.physical(media_warmup).source_revision]
        # The published outfit already owns these resources. Identical physical
        # poses and immutable material operands do not resample every layer.
        var last_pose:Dictionary=visual.get("sampled_pose",{})
        if not layer_sample_actors.has(id) and not last_pose.is_empty() and last_pose.key==pose_key and is_same(last_pose.parameters,material_parameters):
            sampling_counts.retained_poses+=1
            FrameProfile.end_phase(profile,"actor_sprite_outfit",outfit_started)
            continue
        visual.sampled_pose={"key":pose_key,"parameters":material_parameters}
        var binding_key:Array=[playback.clip,character_light_profile,MediaWarmup.physical(media_warmup).source_revision]
        var check_outfit:bool=layer_sample_actors.has(id) or visual.get("outfit_binding",[])!=binding_key
        var complete_outfit = true
        if check_outfit:sampling_counts.validated_outfits+=1
        if check_outfit:
            for entry in visual.entries:
                var layer: Dictionary = entry.actor_layer
                var effect: Dictionary=layer_samples.get(layer.get("effect",{}).get("component_id"),{})
                var layer_clip: String=effect.get("clip",playback.clip)
                if not layer.paths.has(layer_clip) or layer.slot in sample.get("hidden_slots",[]): continue
                var path: String = layer.paths[layer_clip]
                if not textures.has(path) or not source_images.has(path): complete_outfit = false; break
                for companion in CharacterGeometry.paths(path,layer.slot,catalog_cache,character_light_profile):
                    if not textures.has(companion): complete_outfit = false; break
            if complete_outfit:visual.outfit_binding=binding_key
        FrameProfile.end_phase(profile,"actor_sprite_outfit",outfit_started)
        if not complete_outfit:
            visual.erase("sampled_pose")
            for entry in visual.entries: entry.node.visible = false
            if media_initial_ready:
                var message = "Character media preparation missed displayed outfit: " + id + "/" + playback.clip
                if not message in presentation_errors: presentation_errors.append(message)
                media_issue = message
            continue
        for entry in visual.entries:
            var selection_started:int=Time.get_ticks_usec()
            var layer: Dictionary = entry.actor_layer
            var effect: Dictionary=layer_samples.get(layer.get("effect",{}).get("component_id"),{})
            var layer_clip: String=effect.get("clip",playback.clip)
            var layer_frame=frame
            var layer_facing=facing
            if not effect.is_empty():
                var pose: Dictionary=Tracks.samples([effect.source_track],effect.source_track.start_ms+effect.age_ms).get(id,{})
                layer_frame=clampi(int(pose.get("source_seconds",0)*rig.clips[layer_clip].fps),0,int(rig.clips[layer_clip].frames)-1)
                var from: Variant=effect.source_track.get("from_position")
                var to: Variant=effect.source_track.get("target_position",effect.source_track.get("to_position"))
                if from!=null and to!=null:
                    var direction=Vector2(to[0]-from[0],to[1]-from[1])
                    if not direction.is_zero_approx():layer_facing=cycle[posmod(cycle.find(_facing(direction))+quarter*2,8)]
            entry.node.visible = show and layer.paths.has(layer_clip) and not layer.slot in sample.get("hidden_slots",[])
            if not entry.node.visible:
                FrameProfile.end_phase(profile,"actor_sprite_layer_selection",selection_started)
                continue
            var path: String = layer.paths[layer_clip]
            # Current sampling never falls back to synchronous disk/decode.
            # A missing initial sheet remains hidden until preparation finishes;
            # an active group's full exact demand was gated before its commits.
            if not textures.has(path) or not source_images.has(path):
                entry.node.visible = false
                FrameProfile.end_phase(profile,"actor_sprite_layer_selection",selection_started)
                continue
            MediaWarmup.touch(media_warmup,path)
            FrameProfile.end_phase(profile,"actor_sprite_layer_selection",selection_started)
            sampling_counts.visible_layers+=1
            var source_version_before:int=entry.get("source_version",0)
            var bind_started:int=Time.get_ticks_usec()
            ActorConstruction.bind_source(self,entry,rig,path,layer_frame,layer_facing,material_parameters)
            FrameProfile.end_phase(profile,"actor_sprite_binding",bind_started)
            if source_version_before!=int(entry.get("source_version",0)):
                sampling_counts.source_changes+=1
                var changes:Variant=SourceMaterial.changes_since(entry,source_version_before)
                if changes!=null and changes.size()==1 and changes.has(&"frame_uv"):sampling_counts.uv_only_changes+=1
                else:sampling_counts.full_source_changes+=1
            var transform_started:int=Time.get_ticks_usec()
            entry.node.basis = camera.basis.scaled_local(Vector3(row.get("scale_x",1.0),1,1))
            entry.node.position = Placement.contact(row)
            if sample.has("passage") and entry.role!="shadow":
                var weight: float=sample.passage_weight
                var passage: Dictionary=sample.passage
                var sx=lerpf(1,passage.passageScale[0],weight)
                var sy=lerpf(1,passage.passageScale[1],weight)
                entry.node.basis=camera.basis.scaled_local(Vector3(row.get("scale_x",1.0)*sx,sy,1))
                var points: Array=rig.get("pose_sockets",{}).get(passage.passageSocket,{}).get(playback.clip,{}).get(facing,[])
                var socket: Variant=points[mini(frame,points.size()-1)] if not points.is_empty() else null
                var unit=128.0/float(rig_config.TILE_W)*row.scale/Placement.PIXELS_PER_UNIT
                entry.node.position+=camera.basis.y*float(passage.passageBodyHeightPx)*(1-sy)*unit
                if socket!=null:
                    entry.node.position+=camera.basis.x*(rig.cell_width*.5-socket.x)*row.get("scale_x",1.0)*sx*weight*unit
                    entry.node.position-=camera.basis.y*(rig.cell_height-rig.origin_y_from_ground-passage.passageBodyHeightPx-socket.y)*sy*weight*unit
            if entry.role != "shadow": entry.node.position.y += float(sample.get("lift_pixels",0))*(128.0/rig_config.TILE_W)/64.0*Placement.HEIGHT_UNIT
            update_bounds(entry)
            FrameProfile.end_phase(profile,"actor_sprite_transform",transform_started)
            if not effect.is_empty() and component_renderer._entry_visible(self,entry):component_renderer.pending_evidence.append({"trace_track_id":effect.id,"display_ms":timeline.display_ms,"visible":true})

# Room-wide receiving inputs of the lit sprite shaders: the light table, the
# cap/Normals storage and ambient, and the terrain supports.
func _publish_receiving() -> void:
    if not publishes_receiving: return
    light_table.publish(source_lighting.canvas_sources(),generated_shadows.cookie_image)
    var cap:float=1.0 if light_cap_enabled else 0.0
    var receiving:Array=[cap,normals_visible]
    if receiving!=receiving_globals:
        receiving_globals=receiving
        var hdr:bool=cap>0.0 and not normals_visible
        var ambient:=Color(LIGHT_AMBIENT,LIGHT_AMBIENT,LIGHT_AMBIENT)
        # The receiving canvas sees CanvasModulate after Godot's HDR conversion.
        RenderingServer.global_shader_parameter_set(&"light_ambient",ambient.linear_to_srgb().srgb_to_linear().r if hdr else ambient.r)
        RenderingServer.global_shader_parameter_set(&"light_cap",cap)
        RenderingServer.global_shader_parameter_set(&"light_normals",normals_visible)
    # Worlds published without a preparation (isolated fixtures) build them here.
    if ground_supports_revision!=world_revision:
        ground_supports_revision=world_revision
        _publish_ground_supports(GroundReceiving.support_image(entries))

func _publish_ground_supports(supports:Dictionary)->void:
    # One texture while it is large enough: replacing a global texture re-queues
    # every material that reads it. The rect bounds what the shader reads.
    var image:Image=supports.image
    var capacity:=Vector2i(ground_supports_texture.get_size()) if ground_supports_texture!=null else Vector2i.ZERO
    var grown:bool=image.get_width()>capacity.x or image.get_height()>capacity.y
    if grown:capacity=capacity.max(Vector2i(maxi(64,nearest_po2(image.get_width())),maxi(64,nearest_po2(image.get_height()))))
    if image.get_size()!=capacity:
        var padded:=Image.create_empty(capacity.x,capacity.y,false,image.get_format())
        padded.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i.ZERO)
        image=padded
    ground_supports_rect=supports.rect
    if grown:
        ground_supports_texture=ImageTexture.create_from_image(image)
        _publish_ground_supports_texture()
        return
    ground_supports_texture.update(image)
    if publishes_receiving:RenderingServer.global_shader_parameter_set(&"ground_supports_rect",ground_supports_rect)

func _publish_ground_supports_texture()->void:
    if not publishes_receiving: return
    RenderingServer.global_shader_parameter_set(&"ground_supports",ground_supports_texture)
    RenderingServer.global_shader_parameter_set(&"ground_supports_rect",ground_supports_rect)

## Make this world the publisher of the receiving globals and republish them all.
func claim_receiving() -> void:
    publishes_receiving = true
    light_table.invalidate()
    receiving_globals = []
    if ground_supports_texture != null: _publish_ground_supports_texture()
    else: ground_supports_revision = -1

func _facing(direction: Vector2) -> String:
    var cycle: Array = rig_config.FACING_CYCLE
    return cycle[posmod(roundi((atan2(direction.y,direction.x)+PI/4)/(TAU/8))+cycle.find("E"),8)]

func _sync_native_lighting() -> void:
    var phase = Time.get_ticks_usec()
    source_lighting.project(camera)
    FrameProfile.end_phase(profile,"native_2d_projection",phase)
    phase = Time.get_ticks_usec()
    _publish_receiving()
    FrameProfile.end_phase(profile,"light_table",phase)
    phase = Time.get_ticks_usec()
    # The light table's upload count changes whenever the canvas sources do.
    var shadows: Array = generated_shadows.sync(visual_actors.values(),camera,source_lighting.canvas_sources(),light_table.uploads if publishes_receiving else -1)
    if normals_visible:
        for entry in shadows: entry.node.visible = false
    # A new array only when the shown helpers changed. Source components and
    # picking continue to use the original visual.entries list.
    if not is_same(shadows,generated_shadow_entries):
        generated_shadow_entries = shadows
        actor_entries = actor_entries.filter(func(entry):return not entry.get("generated_shadow",false))
        actor_entries.append_array(shadows)
        var ids = shadows.map(func(entry):return entry.node.get_instance_id())
        if ids != generated_shadow_ids:
            generated_shadow_ids = ids
            draw_order_dirty = true
    FrameProfile.end_phase(profile,"modular_shadows",phase)
    for issue in source_lighting.issues+generated_shadows.issues:
        if issue not in presentation_errors: presentation_errors.append(issue)

func _sort_draws() -> void:
    # Ground UI joins only painter order, never actor/media/light/picking owners.
    var phase = Time.get_ticks_usec()
    _sync_ground_overlay()
    FrameProfile.end_phase(profile,"ground_overlay_sync",phase)
    var fixed_changed = false
    # Source geometry establishes one total order. Changing which wall variants
    # are visible selects a subsequence; it does not change those ordering keys.
    var proof: Dictionary = prepared_static_order
    prepared_static_order = {}
    if static_order_dirty or static_order_count != static_entries.size():
        fixed_changed = true
        var ordering_started = Time.get_ticks_usec()
        var changed = static_complete_order.size()!=static_entries.size()
        var trusted: bool = not proof.is_empty() and proof.epoch==timeline.initialization_revision and proof.generation==world_generation and proof.quarter==quarter and proof.background==ground_is_background and is_same(proof.entries,static_entries) and is_same(proof.order,static_complete_order)
        if not trusted:
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
        FrameProfile.end_phase(profile,"static_order",ordering_started)
    # Visible statics take the dense ranks 0..n-1 of their order. Moving draws
    # take fractions between them, so a moving draw never renumbers a static.
    var forward: Vector3 = -camera.global_basis.z
    var statics_changed: bool = fixed_changed or not is_same(static_order,order_statics) or forward!=order_forward
    if statics_changed:
        phase = Time.get_ticks_usec()
        for i in range(static_order.size()):_apply_draw_rank(static_order[i],float(i),forward)
        order_statics = static_order
        FrameProfile.end_phase(profile,"draw_rank_apply",phase)
    phase = Time.get_ticks_usec()
    _order_moving(statics_changed,forward)
    FrameProfile.end_phase(profile,"actor_order",phase)
    _sync_wall_mask()

func _sync_ground_overlay() -> void:
    # Disclosed supports, the preview, the grid toggle and the view are the
    # overlay's inputs; while none changes it is not visited at all.
    var support: Array = [] if timeline.current.get("staged_tiles",{}).is_empty() else timeline._support_signature()
    var revision: Array = [timeline.initialization_revision,timeline.world_revision,world_generation,support]
    if ground_overlay.current(revision,grid_visible,quarter,ground_is_background,world_row_cache,timeline.initialization_revision): return
    ground_overlay.sync(self,timeline.presentation_state().get("tiles",{}),revision,grid_visible,quarter,ground_is_background,
        {"changes":world_changes,"revision":timeline.world_revision,"scope":[timeline.initialization_revision],"owner":world_row_cache})
    profile.phases.ground_overlay_support_check = profile.phases.get("ground_overlay_support_check",0.0)+ground_overlay.support_check_us/1000.0
    profile.phases.ground_overlay_mark_update = profile.phases.get("ground_overlay_mark_update",0.0)+ground_overlay.mark_update_us/1000.0

# Moving participants: actor layers, generated shadows, blood stains, droplet
# halves and effect draws (actor_entries), and ground UI. A draw sits in the gap
# of the visible static order where its key+id lower bound falls, and the j-th
# of the m draws in gap g takes rank g-1+(j+1)/(m+1). Keys follow placements,
# ranks follow a gap's members and their order, offsets follow ranks and node
# origins: an unchanged participant costs one poll per frame.
func _order_moving(statics_changed: bool, forward: Vector3) -> void:
    var rekey: bool = quarter!=order_quarter or ground_is_background!=order_background
    var replace: bool = statics_changed or rekey
    order_quarter = quarter; order_background = ground_is_background; order_forward = forward
    if replace:
        # Static indices moved: every participant takes its gap again.
        for entry in order_moving+order_ground+actor_entries+ground_overlay.ordered: entry.order_gap = -1
        order_gaps = []; order_gaps.resize(static_order.size()+1)
        order_dirty_gaps.clear(); order_resized_gaps.clear()
    var structure: bool = replace
    var moved: Array = []
    if replace or not is_same(ground_overlay.ordered,order_ground_source):
        structure = true
        _order_ground(moved)
    if rekey or draw_order_dirty or actor_entries.size()!=order_moving.size():
        structure = true
        _order_members(rekey)
    else:
        if order_shown_changed:
            structure = true
            _order_shown()
        if replace:
            var previous: int = -1
            for s in order_moving.size():
                if order_shown[s]==0: continue
                _order_place(order_moving[s],previous)
                previous = order_moving[s].order_gap
    draw_order_dirty = false
    order_shown_changed = false
    if not _order_poll(moved):
        # A participant joined or left without notice.
        structure = true
        _order_members(false)
        _order_poll(moved)
    for gap in order_dirty_gaps:
        var gap_members: Array = order_gaps[gap]
        var in_order: bool = true
        for j in range(1,gap_members.size()):
            if _entry_before(gap_members[j],gap_members[j-1]): in_order = false; break
        if in_order and not order_resized_gaps.has(gap): continue
        if not in_order: gap_members.sort_custom(_entry_before)
        structure = true
        var m: int = gap_members.size()
        for j in m: _order_rank(gap_members[j],float(gap-1)+float(j+1)/float(m+1),forward)
    order_dirty_gaps.clear(); order_resized_gaps.clear()
    for entry in moved: _order_rank(entry,entry.draw_rank,forward)
    if structure: _order_merge()

func _order_poll(moved: Array) -> bool:
    # Once per frame per displayed participant: its placement (key) and node
    # origin. Visibility arrives by signal. False when actor_entries no longer
    # holds the polled slots.
    var head: Variant = null
    var serial: int = -1
    for s in actor_entries.size():
        var entry: Dictionary = actor_entries[s]
        if not is_same(entry,order_moving[s]): return false
        if order_shown[s]==0: continue
        var row: Dictionary = entry.placement
        if not is_same(row,head):
            # The placement values grid_order.key reads, compared once per run
            # of draws sharing a row. Samplers assign equal values in new
            # arrays and some producers edit arrays in place, so the values are
            # copied; scalar types count, as they do in the comparator. A new
            # serial re-keys every draw of the run, and any draw keyed under
            # another serial (other row, other run head) re-keys too.
            head = row
            var stamp: Variant = entry.get("order_stamp")
            var same: bool = stamp!=null and stamp[1]==row.position and is_same(stamp[2],row.base_height_steps) and stamp[3]==row.size()
            if same:
                # The optional key fields this row had when stamped; any field
                # added or removed changes the row's size.
                var optional: Array = stamp[4]
                for i in range(0,optional.size(),2):
                    var value: Variant = row.get(optional[i])
                    if not is_same(value,optional[i+1]) and not (value is Array and value==optional[i+1]): same = false; break
            if not same:
                order_serial += 1
                var optional: Array = []
                for field in ORDER_FIELDS:
                    if row.has(field):
                        var value: Variant = row[field]
                        optional.append_array([field,value.duplicate() if value is Array else value])
                stamp = [order_serial,row.position.duplicate(),row.base_height_steps,row.size(),optional]
                entry.order_stamp = stamp
            serial = stamp[0]
        if order_keyed[s]!=serial:
            order_keyed[s] = serial; entry.order_keyed = serial
            var key: Array = Order.key(row,entry.role,entry.layer,quarter,ground_is_background)
            if entry.order_gap<0 or key!=entry.order_key or entry.id!=entry.order_gap_id:
                entry.order_key = key
                _order_place(entry,order_moving[s-1].order_gap if s>0 else -1)
        var position: Vector3 = order_nodes[s].global_position
        if position!=order_positions[s]:
            order_positions[s] = position; moved.append(entry)
    return true

func _order_members(rekey: bool) -> void:
    # A participant joined, left or moved within actor_entries. Joiners, and
    # members renamed or re-layered, are keyed by the poll; members whose gap
    # was reset by new statics take a gap with their current key.
    var kept: int = order_member_generation
    order_member_generation += 1
    var previous: int = -1
    var count: int = actor_entries.size()
    order_positions.resize(count); order_nodes.resize(count); order_keyed.resize(count); order_shown.resize(count)
    for s in count:
        var entry: Dictionary = actor_entries[s]
        var member: bool = entry.get("order_member",-1)==kept
        entry.order_member = order_member_generation
        order_positions[s] = entry.get("draw_position",Vector3.INF)
        order_nodes[s] = entry.node
        if not member:
            entry.order_gap = -1; entry.order_key = []; entry.order_gap_id = ""
            if not entry.node.visibility_changed.is_connected(_order_visibility_changed): entry.node.visibility_changed.connect(_order_visibility_changed)
        var shown: bool = entry.node.visible
        order_shown[s] = 1 if shown else 0
        if not shown:
            # A hidden draw holds no rank: it is keyed and placed when shown.
            if entry.order_gap>=0: _order_detach(entry)
            entry.order_keyed = -1
        elif not member or rekey or entry.id!=entry.order_gap_id or entry.layer!=entry.get("order_gap_layer"):
            entry.order_keyed = -1
        elif entry.order_gap<0: _order_place(entry,previous)
        order_keyed[s] = entry.order_keyed
        if shown: previous = entry.order_gap
    for entry in order_moving:
        if entry.get("order_member")==order_member_generation: continue
        if entry.get("order_gap",-1)>=0: _order_detach(entry)
        var node: Variant = entry.node
        if is_instance_valid(node) and node.visibility_changed.is_connected(_order_visibility_changed): node.visibility_changed.disconnect(_order_visibility_changed)
    order_moving = actor_entries.duplicate()

func _order_visibility_changed() -> void:
    # A moving draw was shown or hidden; _order_shown finds which.
    order_shown_changed = true

func _order_shown() -> void:
    # Only displayed moving draws hold ranks, as in the full sort they replace:
    # a hidden draw leaves its gap, a shown one is keyed, placed and ranked.
    for s in order_moving.size():
        var shown: int = 1 if order_nodes[s].visible else 0
        if shown==order_shown[s]: continue
        order_shown[s] = shown
        var entry: Dictionary = order_moving[s]
        if shown==0 and entry.order_gap>=0: _order_detach(entry)
        entry.order_keyed = -1; order_keyed[s] = -1; order_positions[s] = Vector3.INF

func _order_ground(moved: Array) -> void:
    # The overlay keys its entries and replaces its ordered list whenever any
    # of them changes; an unchanged list is never visited.
    order_generation += 1
    var ground: Array = ground_overlay.ordered
    for entry in ground: entry.order_ground_member = order_generation
    for entry in order_ground:
        if entry.get("order_ground_member")!=order_generation and entry.get("order_gap",-1)>=0: _order_detach(entry)
    var previous: int = -1
    for entry in ground:
        if entry.get("order_gap",-1)<0 or entry.order_key!=entry.get("order_gap_key") or entry.id!=entry.get("order_gap_id"):
            _order_place(entry,previous,maxi(previous,0))
        if entry.node.global_position!=entry.get("draw_position"): moved.append(entry)
        previous = entry.order_gap
    order_ground = ground; order_ground_source = ground

func _order_fits(entry: Dictionary, gap: int) -> bool:
    return gap>=0 and gap<=static_order.size() and (gap==0 or _entry_before(static_order[gap-1],entry)) \
        and (gap==static_order.size() or not _entry_before(static_order[gap],entry))

func _order_place(entry: Dictionary, hint: int, low: int = 0) -> void:
    # The gap is the draw's lower bound among the visible statics by key, then
    # id. A draw usually keeps its gap, and an actor's layers share one unless
    # a static key falls between them, so both are tried before a search.
    # Callers placing draws in key order pass the previous gap as the floor.
    var gap: int = entry.get("order_gap",-1)
    var target: int = gap
    if not _order_fits(entry,gap):
        if _order_fits(entry,hint): target = hint
        else:
            var high: int = static_order.size()
            while low < high:
                var middle: int = (low+high)/2
                if _entry_before(static_order[middle],entry): low = middle+1
                else: high = middle
            target = low
    entry.order_gap_key = entry.order_key; entry.order_gap_id = entry.id; entry.order_gap_layer = entry.layer
    if target==gap:
        if order_gaps[gap].size()>1: order_dirty_gaps[gap] = true
        return
    if gap>=0: _order_detach(entry)
    if order_gaps[target]==null: order_gaps[target] = []
    order_gaps[target].append(entry)
    entry.order_gap = target
    order_dirty_gaps[target] = true; order_resized_gaps[target] = true

func _order_detach(entry: Dictionary) -> void:
    var gap: int = entry.order_gap
    var members: Array = order_gaps[gap]
    for j in members.size():
        if is_same(members[j],entry):
            members.remove_at(j)
            break
    entry.order_gap = -1
    order_dirty_gaps[gap] = true; order_resized_gaps[gap] = true

func _order_rank(entry: Dictionary, rank: float, forward: Vector3) -> void:
    draw_rank_updates+=1
    var position: Vector3 = entry.node.global_position
    var offset: float = rank*8.0+forward.dot(position)
    if entry.get("draw_offset") != offset:
        entry.node.sorting_offset = offset
        entry.draw_offset = offset
    entry.draw_rank = rank
    entry.draw_position = position

func _order_merge() -> void:
    # The merged painter sequence for picking and the wall mask: displayed
    # moving draws in their gaps between the visible statics.
    var merged: Array = []
    var start: int = 0
    for gap in order_gaps.size():
        var members: Variant = order_gaps[gap]
        if members==null or members.is_empty(): continue
        if gap>start: merged.append_array(static_order.slice(start,gap))
        start = gap
        for entry in members:
            if entry.node.visible: merged.append(entry)
    if start<static_order.size(): merged.append_array(static_order.slice(start))
    draw_order = merged

func _entry_before(a: Dictionary, b: Dictionary) -> bool:
    return Order.less(a.order_key,b.order_key) if a.order_key != b.order_key else a.id < b.id

func _apply_draw_rank(entry: Dictionary, rank: float, forward: Vector3) -> void:
    draw_rank_updates+=1
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
    # Coverage is sampled only in translucent mode. Retain pending membership
    # and camera changes until the first frame that actually needs this mask.
    if wall_mode != "translucent":
        if wall_mask_viewport != null: wall_mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
        FrameProfile.end_phase(profile,"mask_sync",started)
        return
    if wall_mask_viewport == null:
        wall_mask_viewport = SubViewport.new()
        wall_mask_viewport.size = Vector2i(get_viewport().get_visible_rect().size)
        wall_mask_viewport.disable_3d = true
        wall_mask_viewport.transparent_bg = true
        wall_mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
        add_child(wall_mask_viewport)
        RenderingServer.viewport_set_measure_render_time(wall_mask_viewport.get_viewport_rid(),true)
        wall_mask_dirty = true
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
            # This receiver can be assigned a different source after wall
            # selection/reordering. Cache at the receiving material, never only
            # on the source entry that previously occupied this draw index.
            var source_key = [entry.node.get_instance_id(),entry.material.get_instance_id(),entry.get("source_version",0)]
            if material.get_meta("coverage_source",[]) != source_key:
                for parameter in ["colour_texture","colour_size","colour_rect","use_selection","invert_selection","selection_kind",
                        "rgba_min","rgba_max","selection_mask","selection_rect","selection_scale","selection_offset","selection_values"]:
                    material.set_shader_parameter(parameter,SourceMaterial.value(entry,parameter))
                material.set_meta("coverage_source",source_key)
            material.set_shader_parameter("wall_mask_id",index)
            wall_mask_sources.append(entry)
            SourceMaterial.set_parameter(entry,"wall_mask_id",index)
            SourceMaterial.set_parameter(entry,"wall_mask_texture",wall_mask_viewport.get_texture())
            SourceMaterial.set_parameter(entry,"wall_mask_enabled",wall_mode=="translucent")
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
    var budget:Dictionary=_preparation_budget()
    if rotation_pending():_dispose_views(budget,true)
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
        if budget.used_usec>=budget.limit_usec:return
        var started:int=Time.get_ticks_usec();var before:int=budget.used_usec
        pending_view.step(maxi(0,budget.limit_usec-budget.used_usec))
        _charge_preparation("rotation",started,before)
        return
    if not pending_view.style_is_current():
        pending_view.is_prepared = false; pending_view.begin_style(); rotation_publication_frame = -1; return
    if not pending_view.projection_is_current():
        pending_view.refresh_projection(); rotation_publication_frame = -1; return
    # Native spells receive on the target quarter's floors from its first frame.
    var receivers_started:int=Time.get_ticks_usec();var receivers_before:int=budget.used_usec
    var receivers_ready:bool=component_renderer.native_spells.prepare_receivers(pending_view.static_entries,budget)
    _charge_preparation("rotation_receivers",receivers_started,receivers_before)
    if not receivers_ready: return
    # Let prepared mask textures complete a native frame before publication.
    if rotation_publication_frame < 0:
        rotation_publication_frame = Engine.get_process_frames(); return
    if Engine.get_process_frames() <= rotation_publication_frame: return
    _poll_static_forecast()
    if not static_forecast.is_empty() and static_forecast.task>=0:return
    # The target view owns its exact static sources. Existing actors keep their
    # published occurrence/clock while receiving target-basis bindings.
    var started = Time.get_ticks_usec()
    var target: int = pending_view.quarter
    var prepared: Dictionary = pending_view.snapshot()
    pending_view = null; rotation_publication_frame = -1
    _deactivate_static_view(true)
    static_views[target] = prepared
    quarter = target; position_camera(); _activate_static_view(target,false)
    _sample_actors(); _sample_fixtures(); _sync_scenery()
    _sort_draws()
    hover_key = []; hover_hit = {}; hover_preview = {}
    FrameProfile.end_phase(profile,"rotation_publish",started)

func _discover() -> void:
    if not pending_choices.is_empty() and (pending_choices.force_attack != force_attack or not session.matches_choice_boundary(pending_choices.boundary)):
        session.retire_record(pending_choices)
        pending_choices = {}
    if command_busy or action_request >= 0: return
    var boundary = session.ready_choice_boundary()
    if boundary.is_empty() or session.latest_sequence < await_command_cursor: return
    if not pending_choices.is_empty():
        # Neither source targets nor a future actor's buttons enter the HUD
        # until the exact native boundary has also reached displayed state.
        if timeline.busy() or timeline.paused or timeline.sequence < await_command_cursor \
                or not session.ready_for_input(timeline.sequence) \
                or timeline.state.get("current_actor_uuid") != boundary.actor_uuid: return
        var value: Dictionary = pending_choices.value
        session.retire_record(available_actions)
        # A selected action's key holds the action itself at index 5.
        var body_hint_current:bool=selection_media.key.size()>=7 and typeof(selection_media.key[5])==TYPE_STRING \
            and selection_media.key[5]=="available_body_actions" \
            and selection_media.key[4]==value.choices.discovery_generation
        cancel_selection(false,body_hint_current)
        available_actions = value.choices
        choices_boundary = pending_choices.boundary
        action_revision = boundary.state_revision
        choices_force_attack = value.force_attack
        attack_preference = attack_preferences.get(available_actions.entity_uuid,"MELEE_MAIN")
        pending_choices = {}
        hover_key = []
        notice_text = ""
        _continue_approach()
        return
    if action_revision == boundary.state_revision and choices_force_attack == force_attack and session.matches_choice_boundary(choices_boundary): return
    pending_request = {"kind":"choices","force_attack":force_attack,"revision":boundary.state_revision,"boundary":boundary}
    action_request = session.request("choices",{"actor_uuid":boundary.actor_uuid,"state_revision":boundary.state_revision,"force_attack":force_attack,"correlation_id":Session.uuid()})

func command_ready() -> bool:
    return not external_playback and session != null and native_startup.ready and media_initial_ready and media_issue.is_empty() and not command_busy and action_request < 0 and not available_actions.is_empty() and not timeline.busy() \
        and not timeline.paused and timeline.sequence >= await_command_cursor and session.ready_for_input(timeline.sequence) \
        and action_revision == session.status.boundary.state_revision and choices_force_attack == force_attack \
        and session.matches_choice_boundary(choices_boundary) \
        and available_actions.entity_uuid == timeline.state.current_actor_uuid

func cancel_selection(clear_approach: bool = true, preserve_selection_media: bool = false) -> void:
    if not preserve_selection_media:
        SelectionMedia.cancel(selection_media);selection_media_hold_cursor=-1
        media_plan_key=[]
    selection_serial += 1
    selected_action = {}
    selection_media_preview={}
    target_selection = {}
    selection_preview = {}
    preview_positions = []
    hover_preview = {}
    hover_key = []
    hover_intent = {}
    if clear_approach:
        pending_approach = {}
        pending_loot_open = {}
    if pending_request.get("kind") == "preview": command_busy = false
    selected_mode = "action.move"
    context_menu.hide()

func select_action(row: Dictionary) -> void:
    if not command_ready() or not Interaction.owns_action(available_actions,row): return
    if row.get("discovery_generation",0) != available_actions.discovery_generation: return
    if row.get("discovery_actor_uuid") != null and row.discovery_actor_uuid != available_actions.entity_uuid: return
    if row.availability_status != "available": notice_text = row.availability_status.replace("_"," ").capitalize(); return
    cancel_selection()
    selected_action = row
    if row.get("weapon_slot") in ["MELEE_MAIN","RANGED_MAIN"]:
        attack_preference = row.weapon_slot
        attack_preferences[available_actions.entity_uuid] = attack_preference
    selected_mode = row.behavior_id
    target_selection = Interaction.selection(row,[])
    notice_text = ""
    if row.target_type == "self":
        target_selection.target_indices = [Choices.action_options(available_actions,row)[0].index]
        _request_selection(true)
    else: _request_selection(false)

func _request_selection(auto_confirm: bool) -> void:
    if action_request >= 0 or selected_action.is_empty(): return
    if not hover_preview.is_empty():selection_media_preview=hover_preview
    elif not selection_preview.is_empty():selection_media_preview=selection_preview
    selection_serial += 1
    hover_key = []; hover_preview = {}; hover_intent = {}
    preview_selection = target_selection.duplicate(true)
    selection_preview = {}
    command_busy = auto_confirm
    pending_request = {"kind":"preview","serial":selection_serial,"auto_confirm":auto_confirm,
        "revision":action_revision,"generation":available_actions.discovery_generation,
        "actor_uuid":available_actions.entity_uuid,"selection":preview_selection}
    action_request = session.request("preview",{"actor_uuid":available_actions.entity_uuid,"state_revision":action_revision,
        "discovery_generation":available_actions.discovery_generation,"correlation_id":Session.uuid(),"selection":preview_selection})
    _refresh_selection_media()

func _execute_admitted(value: Dictionary, keep_approach: bool = false) -> void:
    if not command_ready() or not Interaction.owns_action(available_actions,value.action): return
    cancel_selection(not keep_approach)
    selected_action = value.action
    selected_mode = selected_action.behavior_id
    target_selection = value.selection.duplicate(true)
    if _submit_ready_move(): return
    _request_selection(true)

func _submit_ready_move() -> bool:
    # Choices already admits this complete native destination/path selection.
    # Preview is optional on the protocol; hover can still show its route while
    # a click submits directly. Compound and extra-position actions keep Preview.
    if not command_ready() or not Interaction.owns_action(available_actions,selected_action): return false
    if selected_action.behavior_id != "action.move" or not selected_action.can_afford: return false
    if selected_action.target_type not in ["position","position_path"] or selected_action.get("position_selection") != null: return false
    if target_selection.target_indices.size() != 1 or not target_selection.extra_target_positions.is_empty(): return false
    _submit({"kind":"execute_selection","discovery_generation":available_actions.discovery_generation,"selection":target_selection.duplicate(true)})
    return true

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
        var options = Choices.action_options(available_actions,row)
        if options.size() == 1:
            return {"action":row,"selection":Choices.selection_for(row,options)}
    return {}

func loot_storage(item_uuid: String = "") -> void:
    var admitted = storage_action(item_uuid)
    if admitted.is_empty(): return
    _execute_admitted(admitted)
    hud.loot_panel.refresh()

func _capture_frame_evidence() -> void:
    frame_evidence.clear()
    if DisplayServer.get_name() == "headless": return
    component_renderer.capture_native_channels(self)
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
    frame_evidence.append_array(component_renderer.pending_evidence)

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
        var appended = Interaction.extend_selection(available_actions,selected_action,target_selection,selection_preview,
            position,actor_id,not Input.is_physical_key_pressed(KEY_SHIFT))
        if appended.is_empty(): notice_text = selection_preview.get("reason") if selection_preview.get("reason") != null else "Choose a highlighted legal target."; return
        var extra = appended.selection.extra_target_positions.size()>target_selection.extra_target_positions.size()
        target_selection = appended.selection
        var position_spec: Variant = selected_action.get("position_selection")
        var explicit = extra or selected_action.target_type == "multi_entity" or (position_spec != null and position_spec.kind in ["path","entity_destination"])
        if not explicit and _submit_ready_move(): return
        _request_selection(not explicit)
        return
    var selected: Dictionary = {}
    var target: Dictionary = {}
    var behavior = "action.attack" if not actor_id.is_empty() and selected_mode == "action.move" else selected_mode
    for action in Choices.all_actions(available_actions):
        if action.behavior_id != behavior or not action.can_afford: continue
        for candidate in Choices.action_options(available_actions,action):
            var subject: Variant = Choices.binding_subject(available_actions,candidate)
            if (not actor_id.is_empty() and subject != null and subject.uuid == actor_id) or (actor_id.is_empty() and Interaction.same_position(Choices.binding_position(available_actions,candidate),position)):
                selected = action
                target = candidate
                break
        if not target.is_empty(): break
    if target.is_empty(): notice_text = "No disclosed legal target for this action."; return
    _execute_admitted({"action":selected,"selection":Interaction.selection(selected,[target.index],not Input.is_physical_key_pressed(KEY_SHIFT))})

func end_turn() -> void:
    if not command_ready(): return
    cancel_selection()
    _submit({"kind":"end_turn"})

func _submit(intent: Dictionary) -> void:
    if not selection_media.key.is_empty():selection_media_hold_cursor=-2
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
    if pending_request.get("kind")=="preview" and not _selection_reply_current(pending_request):
        command_busy = false
        return
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
            if pending_request.force_attack != force_attack or not session.matches_choice_boundary(pending_request.boundary): return
            pending_choices = {"boundary":pending_request.boundary,"force_attack":pending_request.force_attack,"value":response.value}
            choice_resources.request(response.value.choices,catalog_cache)
        "preview":
            var preview: Dictionary = response.value.preview
            selection_preview = preview
            preview_positions = Choices.preview_positions(preview,true)
            command_busy = false
            _refresh_selection_media()
            if pending_request.auto_confirm and preview.can_confirm: confirm_selection()
            else: notice_text = preview.reason if preview.get("reason") != null else ""
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
                if receipt.kind=="committed" and selection_media_hold_cursor==-2:selection_media_hold_cursor=int(receipt.cursor.sequence)
                cancel_selection(false,receipt.kind=="committed" and selection_media_hold_cursor>=0)
                action_revision = ""
                notice_text = "" if receipt.kind == "committed" else "Command "+receipt.kind

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
    hud.clear_hover_feedback()
    if not selected_action.is_empty():
        choose_target(hit.get("position",[]),hit.get("id","")); return
    if hit.is_empty(): return
    var id: String = hit.get("id","")
    if alternative and hit.kind == "actor":
        context_options = [{"inspect":hit}]
        _show_context([hit.label]); return
    if not alternative:
        var intent = Interaction.idle_intent(available_actions,timeline.state,hit,force_attack,attack_preference,
            selected_mode,not Input.is_physical_key_pressed(KEY_SHIFT))
        match intent.get("kind",""):
            "move","attack": _execute_admitted(intent.value); return
            "storage": open_storage(id); return
            "interaction","approach": _choose_world_option(intent.option); return
            "context": pass
            _:
                notice_text = hit.get("label","") + (": no legal attack." if hit.get("kind")=="actor" or force_attack else "")
                return
    if id.is_empty(): return
    var options = Interaction.world_options(available_actions,id)
    if options.is_empty(): notice_text = hit.label; return
    var defaults: Array = options.filter(func(option):return option.get("default_priority",100) == options[0].get("default_priority",100))
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

func update_wall_visibility(refresh_sight: bool = true, finish_draw_order: bool = true) -> void:
    _sync_scenery(false,refresh_sight)
    var started = Time.get_ticks_usec()
    var senses: Variant = timeline.state.get("senses")
    var geometry = _wall_geometry() if wall_mode != "solid" else {}
    var visible: Dictionary = scenery_visible_cells
    geometry.visible = visible
    FrameProfile.end_phase(profile,"wall_targets",started)
    var candidates_started = Time.get_ticks_usec()
    var faded = {}
    var choices = {}
    wall_support_candidates = 0
    wall_max_member_candidates = 0
    for source in wall_sources:
        if wall_mode != "solid":
            for member in source.get("wall_members",[source]):
                var targets = _wall_member_targets(member,geometry)
                wall_support_candidates += targets.size()
                wall_max_member_candidates = maxi(wall_max_member_candidates,targets.size())
                if targets.any(func(target):return visible.has(target.cell)):
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
            SourceMaterial.set_parameter(entry,"wall_opacity",alpha)
        var masked = wall_mode=="translucent" and entry.role!="shadow"
        if entry.get("wall_mask_enabled") != masked:
            entry.wall_mask_enabled = masked
            SourceMaterial.set_parameter(entry,"wall_mask_enabled",masked)
    FrameProfile.end_phase(profile,"wall_candidates",candidates_started)
    wall_visibility_revision = timeline.revision
    wall_visible_cells = senses.get("visible",[]).duplicate(true) if senses != null else []
    # Production finalizes painter order once, after sampling native shadows.
    # Direct input/inspection callers retain immediate order and mask updates.
    if finish_draw_order: _sort_draws()
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
    # Deposited blood uses a horizontal PlaneMesh; airborne/native effects can
    # use other geometry or borrow an actor's placement. They are presentation
    # layers, never selectable world subjects or blockers for the artwork below.
    if entry.get("ground_overlay",false) or entry.placement.kind=="effect" or entry.role=="native_effect":return false
    var transform: Transform3D = entry.node.global_transform
    var normal = transform.basis.z.normalized()
    var intersection: Variant = Plane(normal,normal.dot(transform.origin)).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
    if intersection == null: return false
    var local: Vector3 = transform.affine_inverse()*intersection
    var mesh: QuadMesh = entry.node.mesh
    var uv = Vector2((local.x-mesh.center_offset.x)/mesh.size.x+0.5,0.5-(local.y-mesh.center_offset.y)/mesh.size.y)
    if uv.x < 0 or uv.y < 0 or uv.x >= 1 or uv.y >= 1: return false
    if entry.placement.kind == "actor":
        var frame: Vector4 = SourceMaterial.value(entry,"frame_uv")
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

func _selection_reply_current(context: Dictionary) -> bool:
    return not selected_action.is_empty() and context.serial==selection_serial \
        and Interaction.owns_action(available_actions,selected_action) \
        and context.revision==action_revision and context.revision==session.status.boundary.state_revision \
        and context.generation==available_actions.get("discovery_generation") \
        and context.actor_uuid==available_actions.get("entity_uuid") \
        and context.actor_uuid==timeline.state.get("current_actor_uuid") \
        and context.actor_uuid==session.status.boundary.input_actor_uuid \
        and context.selection==target_selection

func _set_world_cursor(shape: int) -> void:
    if shape == hover_cursor: return
    hover_cursor = shape
    Input.set_default_cursor_shape(shape)

func _hover_choice(hit: Dictionary, safe: bool) -> Dictionary:
    if not selected_action.is_empty():
        var appended = Interaction.extend_selection(available_actions,selected_action,target_selection,selection_preview,
            hit.get("position",[]),hit.get("id",""),safe)
        return {"kind":"target","label":selected_action.display_name,"value":appended} if not appended.is_empty() else {}
    return Interaction.idle_intent(available_actions,timeline.state,hit,force_attack,attack_preference,selected_mode,safe)

func _update_hover() -> void:
    # Re-evaluate the current pointer before publishing a reply. Earlier requests
    # are retired independently; neither pointer motion nor undo can repaint an
    # older prospective prefix over the new gesture.
    var completed: Array = []
    for request in hover_requests:
        if session.responses.has(request): completed.append(request)
    var now = Time.get_ticks_msec()
    if now < hover_due and completed.is_empty(): return
    hover_due = now+100
    var ready = command_ready()
    if not selected_action.is_empty() and not Interaction.owns_action(available_actions,selected_action): ready = false
    var over_ui = hud == null or hud.pointer_over_controls() or context_menu.visible
    var key: Array = []
    var intent: Dictionary = {}
    if ready and not over_ui:
        hover_hit = pick_world(get_viewport().get_mouse_position())
        var safe = not Input.is_physical_key_pressed(KEY_SHIFT)
        key = [hover_hit.get("id"),hover_hit.get("position"),safe,action_revision,
            available_actions.entity_uuid,available_actions.discovery_generation,force_attack,
            attack_preference,selection_serial,target_selection.duplicate(true),selected_mode,
            session.status.boundary.state_revision,session.status.boundary.input_actor_uuid,
            timeline.state.get("current_actor_uuid")]
        intent = _hover_choice(hover_hit,safe)
    else: hover_hit = {}
    var changed = key != hover_key
    # Moving between admitted targets of the same prefix keeps the last complete
    # SDK footprint until its replacement arrives. Eligibility belongs to the
    # selected prefix, not to this prospective reply's continuation domain.
    var same_prefix = not selected_action.is_empty() and not key.is_empty() and not hover_key.is_empty() \
        and key.slice(2)==hover_key.slice(2)
    if intent.is_empty() or (changed and not same_prefix): hover_preview = {}
    hover_key = key
    hover_intent = intent
    var cursor = Input.CURSOR_ARROW
    if ready and not over_ui:
        if intent.is_empty(): cursor = Input.CURSOR_FORBIDDEN
        elif intent.kind in ["target","attack"]: cursor = Input.CURSOR_CROSS
        elif intent.kind != "move": cursor = Input.CURSOR_POINTING_HAND
    _set_world_cursor(cursor)
    for request in completed:
        var response: Dictionary = session.responses[request]
        session.responses.erase(request)
        session.retire_record(response)
        var context: Dictionary = hover_requests[request]
        hover_requests.erase(request)
        if request == hover_request: hover_request = -1
        if response.ok and ready and not intent.is_empty() and not key.is_empty() and context.key == key:
            hover_preview = response.value.preview
        elif not response.ok and context.key == key:
            hover_preview = {}
    if not changed or key.is_empty() or intent.get("value",{}).is_empty(): return
    hover_context = {"key":key.duplicate(true),"selection":intent.value.selection.duplicate(true)}
    hover_request = session.request("preview",{"actor_uuid":available_actions.entity_uuid,"state_revision":action_revision,
        "discovery_generation":available_actions.discovery_generation,"correlation_id":Session.uuid(),"selection":intent.value.selection})
    hover_requests[hover_request] = hover_context

func _unhandled_input(event: InputEvent) -> void:
    if external_playback: return
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
    if external_playback: return
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
        if _entry_contains(entry,screen):return entry.placement.id
    return ""

func _exit_tree() -> void:
    # Shutdown joins workers before destroying the native owners they borrowed.
    # During playback cancellation stays incremental in _dispose_views.
    if pending_world!=null: pending_world.join()
    if not static_forecast.is_empty() and static_forecast.task>=0:WorkerThreadPool.wait_for_task_completion(static_forecast.task)
    static_forecast={}
    ground_overlay.close()
    component_renderer.close(self)
    generated_shadows.close()
    source_lighting.clear_pages()
    if session != null: session.close()
    SelectionMedia.close(selection_media)
    MediaWarmup.close(media_warmup)
    # Retired nodes remain scene children, so ordinary tree teardown owns them.
    retiring_views = []
    BackgroundRelease.join()

func error_report(displayed_message: String) -> Dictionary:
    # Copy only diagnostic state; connection tokens, requests and private config
    # never enter the report. Keep the exact visible message even if state moves.
    return {"kind":"ndclient_error","message":displayed_message,
        "displayed_sequence":timeline.sequence,"consumed_sequence":session.latest_sequence if session!=null else -1,
        "display_ms":timeline.display_ms,"active_group":timeline.current.get("id",""),
        "queued_groups":timeline.queue.size(),"paused":timeline.paused,
        "waiting_for_media":timeline.waiting_for_media,"waiting_for_world":timeline.waiting_for_world,
        "media_issue":media_issue,"presentation_errors":presentation_errors.slice(-8),
        "renderer":RenderingServer.get_current_rendering_method()}

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
        "errors":presentation_errors.duplicate(),"received":session.latest_sequence if session != null else -1,"static_draws":static_entries.size()}
