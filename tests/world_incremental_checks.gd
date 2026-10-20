extends SceneTree
# Real recorded Door scenario, original authored door/corner packets, and an independent
# full-rebuild/full-sort oracle. Presentation after-values exercise renderer
# changes here; this is not a claim that commands were sent to the backend.
const Player = preload("res://play.tscn")
const WorldRows = preload("res://presentation/world.gd")
const Order = preload("res://grid_order.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Cells=preload("res://sdk/fold_cells.gd")
const FixtureCompiler=preload("res://presentation/compiler.gd")
const ReferenceQuarter=preload("res://presentation/quarter_view.gd")
var checks := 0
var failures: Array = []
var comparisons: Array = []
var fixture_number:int=0
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
    var delta:Dictionary=FixtureCompiler.empty_delta();delta.objects[id]=changed
    enqueue_fixture(scene,delta)

func enqueue_fixture(scene:Node,delta:Dictionary)->void:
    # This has no gameplay fact or invented event identity. It is a named
    # renderer after-value, admitted through the same media/world barrier as
    # an ordinary received commit rather than editing an accepted boundary.
    fixture_number+=1
    scene.timeline.accept({"kind":"operation","groups":[{"id":"renderer-fixture-"+str(fixture_number),
        "operation_sequence":scene.timeline.sequence+1,"operation_end":true,"duration_ms":0.0,
        "actor_tracks":[],"components":[],"staged_tiles":{},"staged_actors":{},"events":[],
        "commits":[{"at_ms":0.0,"delta":delta}]}]})

func prepare_fixture(scene: Node) -> void:
    # Keep an explicitly pending camera unpublished while the world fixture
    # prepares. A changed source generation must retire that exact candidate.
    var requested:int=scene.requested_quarter
    scene.requested_quarter=scene.world_quarter
    var processing:bool=scene.is_processing()
    scene.timeline.paused=false;scene.set_process(true)
    var deadline := Time.get_ticks_msec()+60000
    while (scene.timeline.busy() or scene.pending_world!=null or scene.world_revision!=scene.timeline.world_revision or not scene._environment_media_ready()) and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
    scene.timeline.paused=true;scene.set_process(processing)
    scene.requested_quarter=requested
    check(not scene.timeline.busy() and scene.pending_world==null and scene.world_revision==scene.timeline.world_revision and scene._environment_media_ready() and scene.media_issue.is_empty(),"Exact renderer after-value publishes through prepared media/world ownership")

func sample_noop(scene:Node)->void:
    var processing:bool=scene.is_processing()
    scene.set_process(true);await scene.presentation_updated
    scene.set_process(processing)
func rotate(scene: Node, view: int) -> void:
    scene.request_view(view)
    var deadline = Time.get_ticks_msec()+60000
    while scene.rotation_pending() and Time.get_ticks_msec()<deadline:
        scene._prepare_rotation()
        await process_frame
    check(not scene.rotation_pending() and scene.quarter==view,"Complete target quarter publishes atomically")
    scene._sample_actors();scene._sample_fixtures();scene._sync_native_lighting();scene._sort_draws()

func full_order(scene: Node) -> Array:
    var rows: Array = (scene.static_entries+scene.actor_entries+scene.ground_overlay.ordered).filter(func(entry):return entry.node.visible)
    var keyed: Array = rows.map(func(entry):return {"entry":entry,"key":Order.key(entry.placement,entry.role,entry.layer,scene.quarter,scene.ground_is_background)})
    keyed.sort_custom(func(a,b):return Order.less(a.key,b.key) if a.key!=b.key else a.entry.id<b.entry.id)
    return keyed.map(func(item):return item.entry)
func assert_order(scene: Node, label: String) -> void:
    var expected := full_order(scene)
    check(scene.draw_order.map(func(entry):return entry.id)==expected.map(func(entry):return entry.id),"Complete painter order equals independent full sort: "+label)
    var correct := true
    var previous:float=-INF
    for entry in expected:
        # Current native order leaves fractional ranks between fixed statics;
        # the observable contract is the same strict painter order after
        # compensating each draw's actual physical camera depth.
        var rank:float=entry.node.sorting_offset-(-scene.camera.global_basis.z).dot(entry.node.global_position)
        if rank<=previous:correct=false
        previous=rank
    check(correct,"Native sorting offsets preserve strict physical-depth-compensated painter order: "+label)
func identities(scene: Node) -> Dictionary:
    var result := {}
    for id in scene.world_groups:
        result[id] = scene.world_groups[id].entries.map(func(entry):return [entry.node.get_instance_id(),entry.material.get_instance_id()])
    for key in scene.ground_groups:
        result["ground:"+key] = scene.ground_groups[key].entries.map(func(entry):return [entry.node.get_instance_id(),entry.material.get_instance_id()])
    return result
func capture_reference(scene:Node)->Image:
    # Build an independent exhaustive quarter without dismantling the accepted
    # production groups. The complete owner is restored after the framebuffer
    # comparison, including its native masks and consumer indices.
    var fresh=ReferenceQuarter.new();scene.add_child(fresh);fresh.configure(scene,scene.quarter)
    fresh.rows=WorldRows.rows(scene.timeline.presentation_state(),scene.catalog_cache).visual_rows
    var deadline:int=Time.get_ticks_msec()+60000
    while not fresh.is_prepared and fresh.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        fresh.step();await process_frame
    check(fresh.is_prepared and fresh.media_issue.is_empty(),"Independent original-source quarter prepares completely")
    if not fresh.is_prepared:
        fresh.queue_free();return await capture()
    scene._deactivate_static_view(true)
    var saved:Dictionary=scene.static_views[scene.quarter]
    scene.static_views[scene.quarter]=fresh.snapshot();scene._activate_static_view(scene.quarter)
    scene._sample_actors();scene._sample_fixtures();scene._sort_draws();scene._sync_native_lighting()
    var image:Image=await capture()
    scene._deactivate_static_view(false)
    scene.static_views[scene.quarter]=saved;scene._activate_static_view(scene.quarter)
    scene._sample_actors();scene._sample_fixtures();scene._sort_draws();scene._sync_native_lighting()
    return image
func run() -> void:
    if DisplayServer.get_name()=="headless": print("WORLD_INCREMENTAL_CHECKS requires native graphics"); quit(2); return
    root.unfocusable = true; root.position = Vector2i(-16000,-16000); root.size = Vector2i(960,640)
    var scene = Player.instantiate(); scene.timeline.paused = true; root.add_child(scene)
    if not open_fixture(scene):scene.queue_free();await process_frame;quit(1);return
    var deadline := Time.get_ticks_msec()+60000
    while (not scene.session.recording_ready or not scene._media_ready({}) or scene.world_revision<0 or scene.visual_actors.is_empty()) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    scene.session.close(); await scene.presentation_updated; scene.set_process(false); scene.hud.hide()
    check(scene.session.issue.is_empty() and not scene.timeline.state.is_empty() and scene.MediaWarmup.ready(scene.media_warmup,scene.media_plan.required),"Actual recorded Door scenario and exact visible actor sheets initialize")
    if not failures.is_empty() or scene.timeline.state.is_empty():scene.queue_free();await process_frame;quit(1);return
    scene.timeline.current={};scene.timeline.queue=[]
    scene.fire_light_flicker=false;scene.source_lighting.fire_light_flicker=false
    scene.grid_visible=false
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
            scene._sort_draws(); scene.update_wall_visibility(); scene._sample_fixtures()
            var after := identities(scene)
            check(before.keys().all(func(id):return id==door or before[id]==after.get(id)),"Door update retains every other node/material and floor batch")
            var snapshot := identities(scene)
            await sample_noop(scene)
            check(snapshot==identities(scene),"No-op world sync preserves original resources in rotated and Hidden views")
            assert_order(scene,"%s q%d" % [mode,quarter])
            var state_before: Dictionary = scene.timeline.state.duplicate(true)
            var actual := await capture()
            var reference := await capture_reference(scene)
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
    # The actor's ground key remains fixed while its actual jump height moves.
    # Cached static order must still compensate physical depth every frame.
    var actors:Array=scene.actor_entries.filter(func(entry):return entry.node.visible and entry.role!="shadow")
    check(not actors.is_empty(),"Real fixture retains an actual visible character for physical-depth compensation")
    if actors.is_empty():scene.queue_free();await process_frame;quit(1);return
    var actor: Dictionary = actors[0]
    var actor_offset:float=actor.node.sorting_offset
    actor.node.position.y += 1.25
    scene._sort_draws(); assert_order(scene,"Actor visual lift without changed ground key")
    check(absf(actor.node.sorting_offset-actor_offset-(-scene.camera.global_basis.z).dot(Vector3.UP*1.25))<=.0001,"Actor native offset changes by exactly its physical camera-depth displacement")
    actor.node.position.y -= 1.25
    # A retained source can move visually while retaining its logical painter
    # key. Physical depth compensation must still follow its native transform.
    var statics:Array=scene.static_entries.filter(func(entry):return entry.node.visible)
    check(not statics.is_empty(),"Prepared world retains visible original static source ownership")
    if statics.is_empty():scene.queue_free();await process_frame;quit(1);return
    var fixed: Dictionary = statics[0]
    var fixed_offset:float=fixed.node.sorting_offset
    fixed.node.position.y += 0.125
    # Static-source invalidation is separate from moving actor invalidation in
    # the prepared order API. Neither changes this source's logical key.
    scene.static_order_dirty = true; scene._sort_draws()
    assert_order(scene,"Retained static source transform with unchanged logical key")
    check(absf(fixed.node.sorting_offset-fixed_offset-(-scene.camera.global_basis.z).dot(Vector3.UP*.125))<=.0001,"Retained static native offset changes by exactly its physical camera-depth displacement")
    fixed.node.position.y -= 0.125
    scene.static_order_dirty = true; scene._sort_draws()
    scene.timeline.state = canonical
    check(scene.presentation_errors.is_empty(),"No source or renderer errors")
    var report := {"checks":checks,"failures":failures,"comparisons":comparisons,"renderer":RenderingServer.get_video_adapter_name()}
    var file := FileAccess.open("res://generated/world_incremental_checks.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
    print("WORLD_INCREMENTAL_CHECKS ",checks," checks; ",failures.size()," failures")
    scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
