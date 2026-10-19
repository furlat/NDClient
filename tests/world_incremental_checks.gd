extends SceneTree
# Real recorded Door scenario, original authored door/corner packets, and an independent
# full-rebuild/full-sort oracle. Presentation after-values exercise renderer
# changes here; this is not a claim that commands were sent to the backend.
const Player = preload("res://play.tscn")
const WorldRows = preload("res://presentation/world.gd")
const Order = preload("res://grid_order.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Cells=preload("res://sdk/fold_cells.gd")
var checks := 0
var failures: Array = []
var comparisons: Array = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("WORLD_INCREMENTAL_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func capture() -> Image:
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func open_fixture(scene:Node)->bool:
    # play.gd consumes an explicit --recording argument during _ready. Direct
    # execution uses the same durable original, without starting a second reader.
    if scene.session.replay_thread!=null:return true
    var opened:Dictionary=scene.session.open_recording(Fixtures.journal("door"))
    check(opened.ok,"Durable original schema16 Door recording opens")
    return opened.ok
func set_door_fixture(scene: Node, id: String, is_open: bool, swing: String) -> void:
    # Native commits replace immutable after-value records. Match that ownership
    # here instead of mutating a record retained by the preparation worker.
    var changed: Dictionary = scene.timeline.state.objects[id].duplicate(true)
    changed.item.is_open = is_open
    changed.item.door_swing = swing
    var state:Dictionary=scene.timeline.state.duplicate()
    state.objects=state.objects.duplicate();state.objects[id]=changed
    scene.timeline.state=state
    # This is an explicit renderer after-value, followed by prepare_fixture's
    # real media wait. A new world revision selects the supported complete
    # refresh fallback; it must not enqueue an unprepared gameplay occurrence.
    scene.timeline.world_revision += 1

func prepare_fixture(scene: Node) -> void:
    # Preparation uses the same production queue as gameplay. These tests freeze
    # a real admitted state and apply explicit renderer after-values, so pending
    # later recording groups must not determine their required source media.
    scene.timeline.current = {}
    scene.timeline.queue = []
    scene.timeline.revision += 1
    scene._prepare_media()
    var deadline := Time.get_ticks_msec()+60000
    while not scene._environment_media_ready() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        scene._warm_media(); scene._prepare_media()
        await process_frame
    check(scene._environment_media_ready() and scene.media_issue.is_empty(),"Exact authored fixture sources prepare before rendering")
func rotate(scene: Node, view: int) -> void:
    scene.request_view(view)
    var deadline = Time.get_ticks_msec()+60000
    while scene.rotation_pending() and Time.get_ticks_msec()<deadline:
        scene._prepare_rotation()
        await process_frame
    check(not scene.rotation_pending() and scene.quarter==view,"Complete target quarter publishes atomically")

func full_order(scene: Node) -> Array:
    var rows: Array = scene.entries.filter(func(entry):return entry.node.visible)
    var keyed: Array = rows.map(func(entry):return {"entry":entry,"key":Order.key(entry.placement,entry.role,entry.layer,scene.quarter)})
    keyed.sort_custom(func(a,b):return Order.less(a.key,b.key) if a.key!=b.key else a.entry.id<b.entry.id)
    return keyed.map(func(item):return item.entry)
func assert_order(scene: Node, label: String) -> void:
    var expected := full_order(scene)
    check(scene.draw_order.map(func(entry):return entry.id)==expected.map(func(entry):return entry.id),"Complete painter order equals independent full sort: "+label)
    var correct := true
    for i in range(expected.size()):
        var offset: float = i*8.0+(-scene.camera.global_basis.z).dot(expected[i].node.global_position)
        if absf(expected[i].node.sorting_offset-offset)>.0001: correct = false
    check(correct,"Native sorting offsets preserve exact projected order: "+label)
func identities(scene: Node) -> Dictionary:
    var result := {}
    for id in scene.world_groups:
        result[id] = scene.world_groups[id].entries.map(func(entry):return [entry.node.get_instance_id(),entry.material.get_instance_id()])
    for key in scene.ground_groups:
        result["ground:"+key] = scene.ground_groups[key].entries.map(func(entry):return [entry.node.get_instance_id(),entry.material.get_instance_id()])
    return result
func clear_world(scene: Node) -> void:
    scene._clear_static_view_cache()
    for entry in scene.static_entries: entry.node.queue_free()
    scene.entries = scene.entries.filter(func(entry):return entry.placement.kind=="actor")
    scene.static_entries = []; scene.fixture_entries = []
    scene.world_groups = {}; scene.ground_groups = {}
    # This independent oracle removes native owners outside the production
    # delta path. Its consumer indices must be reset with those owners.
    scene.scenery_index_dirty = true
    scene.static_order_dirty = true; scene.draw_order_dirty = true; scene.wall_mask_dirty = true
func reference_rebuild(scene: Node) -> void:
    clear_world(scene)
    var derived := WorldRows.rows(scene.timeline.presentation_state(),scene.catalog_cache)
    var ground := {}
    for original in derived.visual_rows:
        var row: Dictionary = original.duplicate(true)
        if row.kind=="terrain" and row.base_height_steps==0 and row.material!="water":
            if not ground.has(row.material): ground[row.material] = []
            ground[row.material].append(row)
        else: scene._environment_row(row)
    for rows in ground.values(): scene._ground_batch(rows)
    scene._sync_scenery(true); scene._sample_fixtures(); scene._sort_draws(); scene.update_wall_visibility()
    # Apply the original full-sort policy independently of cached merge state.
    scene.draw_order = full_order(scene)
    for i in range(scene.draw_order.size()):
        var entry: Dictionary = scene.draw_order[i]
        entry.node.sorting_offset = i*8.0+(-scene.camera.global_basis.z).dot(entry.node.global_position)
func run() -> void:
    if DisplayServer.get_name()=="headless": print("WORLD_INCREMENTAL_CHECKS requires native graphics"); quit(2); return
    root.unfocusable = true; root.position = Vector2i(-16000,-16000); root.size = Vector2i(960,640)
    var scene = Player.instantiate(); scene.timeline.paused = true; root.add_child(scene)
    if not open_fixture(scene):scene.queue_free();await process_frame;quit(1);return
    var deadline := Time.get_ticks_msec()+60000
    while (not scene.session.recording_ready or not scene.MediaWarmup.ready(scene.media_warmup,scene.media_plan.required) or not scene._environment_media_ready()) and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    scene.session.close(); await scene.presentation_updated; scene.set_process(false); scene.hud.hide()
    check(scene.session.issue.is_empty() and not scene.timeline.state.is_empty() and scene.MediaWarmup.ready(scene.media_warmup,scene.media_plan.required),"Actual recorded Door scenario and exact visible actor sheets initialize")
    if scene.timeline.state.is_empty(): quit(1); return
    var canonical: Dictionary = scene.timeline.state.duplicate(true)
    var door := ""
    for row in scene.placements:
        if row.kind=="door": door = row.id; break
    check(not door.is_empty(),"Actual source-backed door exists")
    if door.is_empty(): quit(1); return
    scene.camera_focus = Vector3(4,0,5); scene.camera.size = 10
    for quarter in range(4):
        await rotate(scene,quarter)
        for mode in ["solid","translucent","hidden"]:
            scene.wall_mode = mode
            var before := identities(scene)
            set_door_fixture(scene,door,mode!="solid","inward" if mode=="translucent" else "outward")
            await prepare_fixture(scene)
            scene._sync_world(); scene._sort_draws(); scene.update_wall_visibility(); scene._sample_fixtures()
            var after := identities(scene)
            check(before.keys().all(func(id):return id==door or before[id]==after.get(id)),"Door update retains every other node/material and floor batch")
            var snapshot := identities(scene)
            scene._sync_world()
            check(snapshot==identities(scene),"No-op world sync preserves original resources in rotated and Hidden views")
            assert_order(scene,"%s q%d" % [mode,quarter])
            var state_before: Dictionary = scene.timeline.state.duplicate(true)
            var actual := await capture()
            reference_rebuild(scene)
            var reference := await capture()
            var changed := 0; var maximum := 0.0
            for y in range(actual.get_height()):
                for x in range(actual.get_width()):
                    var a := actual.get_pixel(x,y); var b := reference.get_pixel(x,y)
                    var error := maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
                    maximum = maxf(maximum,error)
                    if error>1.0/255+0.00001: changed += 1
            check(changed==0,"Incremental native pixels equal independent full rebuild: %s q%d changed=%d" % [mode,quarter,changed])
            check(scene.timeline.state==state_before,"Rendering leaves canonical state intact")
            comparisons.append({"quarter":quarter,"mode":mode,"changed_pixels":changed,"maximum_error":maximum,"draws":scene.draw_order.size()})
            clear_world(scene); scene.world_quarter = -1; scene._sync_world(); scene._sort_draws(); scene.update_wall_visibility(); scene._sample_fixtures()
    # The actor's ground key remains fixed while its actual jump height moves.
    # Cached static order must still compensate physical depth every frame.
    var actor: Dictionary = scene.actor_entries.filter(func(entry):return entry.node.visible and entry.role!="shadow")[0]
    actor.node.position.y += 1.25
    scene._sort_draws(); assert_order(scene,"Actor visual lift without changed ground key")
    actor.node.position.y -= 1.25
    # A retained source can move visually while retaining its logical painter
    # key. Physical depth compensation must still follow its native transform.
    var fixed: Dictionary = scene.static_entries.filter(func(entry):return entry.node.visible)[0]
    fixed.node.position.y += 0.125
    scene.draw_order_dirty = true; scene._sort_draws()
    assert_order(scene,"Retained static source transform with unchanged logical key")
    fixed.node.position.y -= 0.125
    scene.draw_order_dirty = true; scene._sort_draws()
    scene.timeline.state = canonical
    check(scene.presentation_errors.is_empty(),"No source or renderer errors")
    var report := {"checks":checks,"failures":failures,"comparisons":comparisons,"renderer":RenderingServer.get_video_adapter_name()}
    var file := FileAccess.open("res://generated/world_incremental_checks.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
    print("WORLD_INCREMENTAL_CHECKS ",checks," checks; ",failures.size()," failures")
    scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
