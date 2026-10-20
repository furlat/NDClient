extends "res://tests/world_incremental_checks.gd"
# Native integration of the prospective Timeline barrier and hidden world builder.
# Door changes below are named immutable renderer after-values, not sent commands.
const Compiler = preload("res://presentation/compiler.gd")
const Quarter = preload("res://presentation/quarter_view.gd")
var gate={"allow":false}
var number=0
var evidence=[]
func enqueue_door(scene:Node,id:String,delay:float=0.0)->Dictionary:
    number+=1
    var after:Dictionary=scene.timeline.state.objects[id].duplicate(true)
    after.item.is_open=not after.item.get("is_open",false)
    after.item.door_swing="inward"
    var delta=Compiler.empty_delta();delta.objects[id]=after
    scene.timeline.accept({"kind":"operation","groups":[{"id":"prepared-door-%d"%number,"operation_sequence":scene.timeline.sequence+1,
        "operation_end":true,"duration_ms":delay,"actor_tracks":[],"staged_tiles":{},"staged_actors":{},"events":[],
        "commits":[{"at_ms":delay,"delta":delta}]}]})
    return after
func enqueue_floor_representative(scene:Node)->Dictionary:
    # Named renderer after-value: raising this actual first tile removes it
    # from the retained flat batch and changes that draw's representative ID.
    number+=1
    var material:String=scene.ground_groups.keys()[0]
    var batch:Dictionary=scene.ground_groups[material].entries[0]
    var row:Dictionary=batch.batch_rows[0]
    var cell:String=WorldRows.cell_key(row.position)
    var after:Dictionary=scene.timeline.state.tiles[cell].duplicate(true)
    after.elevation_steps=1
    var delta=Compiler.empty_delta();delta.tiles[cell]=after
    scene.timeline.accept({"kind":"operation","groups":[{"id":"prepared-floor-%d"%number,"operation_sequence":scene.timeline.sequence+1,
        "operation_end":true,"duration_ms":0.0,"actor_tracks":[],"staged_tiles":{},"staged_actors":{},"events":[],
        "commits":[{"at_ms":0.0,"delta":delta}]}]})
    return {"id":row.id,"cell":cell,"after":after,"material":material,"node_id":batch.node.get_instance_id()}
func assert_complete_order(scene:Node,label:String)->void:
    var expected:Array=scene.static_entries.map(func(entry):return {"entry":entry,"key":Order.key(entry.placement,entry.role,entry.layer,scene.quarter,scene.ground_is_background)})
    expected.sort_custom(func(a,b):return Order.less(a.key,b.key) if a.key!=b.key else a.entry.id<b.entry.id)
    check(scene.static_complete_order.map(func(entry):return entry.id)==expected.map(func(value):return value.entry.id),label+" original total order includes every hidden and shown static entry")
    check(scene.static_complete_order.size()==scene.static_entries.size() and scene.static_entries.any(func(entry):return not entry.node.visible),label+" total-order fixture includes hidden variants")
    assert_order(scene,label)
func picks(scene:Node,id:String)->Dictionary:
    var result={}
    var row:Dictionary=scene.world_groups[id].entries[0]
    var quad:QuadMesh=row.node.mesh
    var left=scene.camera.unproject_position(row.node.to_global(quad.center_offset+Vector3(-quad.size.x*.5,quad.size.y*.5,0)))
    var right=scene.camera.unproject_position(row.node.to_global(quad.center_offset+Vector3(quad.size.x*.5,-quad.size.y*.5,0)))
    for y in range(1,6):
        for x in range(1,6):
            var point=left.lerp(right,0)+Vector2((right.x-left.x)*x/6.0,(right.y-left.y)*y/6.0)
            result[point]=scene.pick_world(point)
    return result
func same_picks(scene:Node,values:Dictionary)->bool:
    for point in values:
        if scene.pick_world(point)!=values[point]:return false
    return true
func pending_ready(scene:Node)->void:
    var deadline=Time.get_ticks_msec()+60000
    while (scene.pending_world==null or not scene.pending_world.prepared) and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
    check(scene.pending_world!=null and scene.pending_world.prepared and scene.timeline.waiting_for_world,"Native target finishes hidden while Timeline gate remains held")
func published(scene:Node,previous:int)->void:
    var deadline=Time.get_ticks_msec()+60000
    while (scene.world_prepared_count==previous or scene.pending_world!=null or scene.timeline.busy()) and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
    scene.timeline.paused=true
    check(scene.world_prepared_count==previous+1 and scene.pending_world==null and not scene.timeline.busy(),"One complete prepared world publishes per accepted boundary")
func compare_reference(scene:Node,label:String,pick_id:String="")->void:
    scene.set_process(false)
    var actual=await capture()
    var expected_picks=picks(scene,pick_id) if not pick_id.is_empty() else {}
    var fresh=Quarter.new();scene.add_child(fresh);fresh.configure(scene,scene.quarter)
    # Independent exhaustive rows, original native builder, no retained view.
    fresh.rows=WorldRows.rows(scene.timeline.presentation_state(),scene.catalog_cache).visual_rows
    var deadline=Time.get_ticks_msec()+60000
    while not fresh.is_prepared and fresh.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        fresh.step();await process_frame
    check(fresh.is_prepared and fresh.media_issue.is_empty(),label+" independent original-source quarter prepares")
    if not fresh.is_prepared:fresh.queue_free();scene.set_process(true);return
    scene._deactivate_static_view(true)
    var saved:Dictionary=scene.static_views[scene.quarter]
    scene.static_views[scene.quarter]=fresh.snapshot();scene._activate_static_view(scene.quarter)
    scene._sample_actors();scene._sample_fixtures();scene._sort_draws()
    var expected=await capture()
    if not pick_id.is_empty():check(same_picks(scene,expected_picks),label+" picking equals independent full original-source construction")
    var same=actual.get_data()==expected.get_data()
    check(same,label+" exact native pixels equal independent full original-source construction")
    evidence.append({"case":label,"quarter":scene.quarter,"byte_exact":same})
    if not same:
        actual.save_png("res://.captures/world-prepared-"+label+".png")
        expected.save_png("res://.captures/world-reference-"+label+".png")
    scene._deactivate_static_view(false)
    scene.static_views[scene.quarter]=saved;scene._activate_static_view(scene.quarter)
    scene._sample_actors();scene._sample_fixtures();scene._sort_draws()
    scene.set_process(true)
func run()->void:
    if DisplayServer.get_name()=="headless":quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(960,640)
    var scene=Player.instantiate();scene.timeline.paused=true;scene.MediaWarmup.physical(scene.media_warmup).budget_bytes=0;root.add_child(scene)
    var deadline=Time.get_ticks_msec()+120000
    while (not scene.session.recording_ready or not scene._media_ready({}) or scene.world_revision<0) and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
    check(scene.session.issue.is_empty() and scene.media_issue.is_empty() and scene.world_revision>=0,"Actual Crypt initialization publishes only after original media and native world preparation")
    if not failures.is_empty():scene.queue_free();await process_frame;quit(1);return
    scene.session.close();scene.timeline.current={};scene.timeline.queue=[];scene.hud.hide()
    if "--fixed-direct" in OS.get_cmdline_user_args():
        for light in scene.source_lighting.nodes.values():light.visible=false
    scene.wall_mode="solid";scene.camera_focus=Vector3(4,0,5);scene.camera.size=10;scene.position_camera();scene.update_wall_visibility()
    var door=""
    for row in scene.placements:
        if row.kind=="door":door=row.id;break
    check(not door.is_empty(),"Native source-backed door available")
    if door.is_empty():scene.queue_free();await process_frame;quit(1);return
    # Hold approval after the real hidden builder is ready; never mark its job
    # admitted until this explicit acceptance gate permits publication.
    scene.timeline.world_ready=func(candidate):
        if gate.allow:return scene._world_ready(candidate)
        if scene.pending_world==null:scene._world_ready(candidate)
        return false
    for q in range(4):
        await rotate(scene,q)
        scene.timeline.paused=true;await capture()
        var before:Dictionary=scene.timeline.state.duplicate(true)
        var rows: Array=scene.placements.duplicate(true)
        var time:float=scene.timeline.display_ms
        var trace:Dictionary=scene.timeline.trace.rows.duplicate(true)
        var logs:Array=scene.timeline.trace.logs.duplicate(true)
        var original_picks=picks(scene,door)
        var image_before=await capture()
        var after=enqueue_door(scene,door);gate.allow=false;scene.timeline.paused=false
        await pending_ready(scene)
        check(scene.timeline.state==before and scene.timeline.display_ms==time,"q%d pending source never changes canonical state or time"%q)
        check(scene.timeline.trace.rows==trace and scene.timeline.trace.logs==logs,"q%d pending source never publishes trace or logs"%q)
        check(scene.placements==rows and same_picks(scene,original_picks),"q%d pending source preserves displayed rows and picking"%q)
        check(not scene.pending_world.visible and scene.sprite_parent.is_visible_in_tree(),"q%d native target remains hidden beside the live original view"%q)
        var image_held=await capture()
        check(image_before.get_data()==image_held.get_data(),"q%d held builder leaves original native pixels unchanged"%q)
        var count:int=scene.world_prepared_count;gate.allow=true
        await published(scene,count)
        check(scene.timeline.state.objects[door]==after,"q%d exact prepared door after-value publishes"%q)
        assert_complete_order(scene,"door-q%d"%q)
        await compare_reference(scene,"door-q%d"%q)
        # A retained material batch changes its representative, while one exact
        # original tile becomes an individual raised draw in the same boundary.
        gate.allow=false;scene.timeline.paused=false
        var floor_case=enqueue_floor_representative(scene)
        await pending_ready(scene)
        count=scene.world_prepared_count;gate.allow=true
        await published(scene,count)
        var batch:Dictionary=scene.ground_groups[floor_case.material].entries[0]
        check(batch.node.get_instance_id()==floor_case.node_id and batch.placement.id!=floor_case.id and batch.placement.id==batch.batch_rows[0].id,"q%d async floor publication preserves native batch and updates its representative"%q)
        check(scene.timeline.state.tiles[floor_case.cell]==floor_case.after and scene.world_groups.has(floor_case.id),"q%d exact raised floor after-value and original individual draw publish together"%q)
        assert_complete_order(scene,"floor-representative-q%d"%q)
        await compare_reference(scene,"floor-representative-q%d"%q,floor_case.id)
    # Rotate while a fully prepared old-quarter target is still unadmitted.
    gate.allow=false;scene.timeline.paused=false
    var before:Dictionary=scene.timeline.state.duplicate(true)
    var after=enqueue_door(scene,door);await pending_ready(scene)
    var stale=weakref(scene.pending_world)
    var target=(scene.quarter+1)%4
    scene.request_view(target);await rotate(scene,target);await pending_ready(scene)
    check(scene.timeline.state==before and scene.pending_world.quarter==target,"Rotation replaces pending native target without admitting its old-quarter state")
    var count:int=scene.world_prepared_count;gate.allow=true;await published(scene,count)
    check(scene.timeline.state.objects[door]==after,"Rotated target admits the same exact boundary")
    await compare_reference(scene,"rotated-target")
    var retired_deadline=Time.get_ticks_msec()+60000
    while stale.get_ref()!=null and Time.get_ticks_msec()<retired_deadline:await process_frame
    check(stale.get_ref()==null,"Old-quarter prepared world releases its native ownership")
    # Received future data prepares while the displayed clock still progresses.
    gate.allow=false;scene.timeline.paused=false
    before=scene.timeline.state.duplicate(true)
    var clock_before:float=scene.timeline.display_ms
    after=enqueue_door(scene,door,10000.0)
    var ready_deadline=Time.get_ticks_msec()+60000
    while (scene.pending_world==null or not scene.pending_world.prepared) and scene.media_issue.is_empty() and Time.get_ticks_msec()<ready_deadline:await process_frame
    check(scene.pending_world!=null and scene.pending_world.prepared and scene.timeline.display_ms>clock_before and scene.timeline.display_ms<clock_before+10000.0,"Received world prepares before arrival while ordinary displayed time continues")
    check(scene.timeline.state==before and not scene.timeline.waiting_for_world,"Prepared future world remains undisplayed before its causal boundary")
    count=scene.world_prepared_count;gate.allow=true
    scene.timeline.advance(10000.0)
    await published(scene,count)
    check(scene.timeline.state.objects[door]==after and scene.timeline.display_ms==clock_before+10000.0,"Early prepared world publishes exactly at its later authored boundary")
    # A new admitted initialization discards old pending world and queued events.
    gate.allow=false;scene.timeline.paused=false;enqueue_door(scene,door);await pending_ready(scene)
    var old_epoch=weakref(scene.pending_world)
    var reset_state:Dictionary=scene.timeline.state.duplicate(true)
    scene.timeline.accept({"kind":"initialization","state":reset_state,"sequence":scene.timeline.sequence})
    scene.timeline.paused=true
    ready_deadline=Time.get_ticks_msec()+60000
    while (scene.world_prepare_epoch!=scene.timeline.initialization_revision or scene.world_revision<0 or scene.pending_world!=null) and scene.media_issue.is_empty() and Time.get_ticks_msec()<ready_deadline:await process_frame
    check(scene.timeline.state==reset_state and not scene.timeline.busy() and scene.world_revision>=0,"Initialization reset republishes its own state and never applies stale queued door")
    while old_epoch.get_ref()!=null and Time.get_ticks_msec()<ready_deadline:await process_frame
    check(old_epoch.get_ref()==null,"Stale preparation epoch releases its native target")
    # Fault injection tests the documented incomplete-worker-result boundary;
    # no artwork is changed and this is not claimed as a missing-file encounter.
    scene.set_process(false);gate.allow=false;scene.timeline.paused=false;enqueue_door(scene,door)
    var candidate:Dictionary=scene.timeline.preview_world()
    ready_deadline=Time.get_ticks_msec()+60000
    while not scene._prepared_world_sources_ready(candidate) and scene.media_issue.is_empty() and Time.get_ticks_msec()<ready_deadline:
        scene._prepare_media();scene._warm_media();await process_frame
    scene._world_ready(candidate)
    while not scene.pending_world.worker_finished():await process_frame
    scene.pending_world.result={}
    await process_frame
    scene._step_world_preparation()
    check(not scene.media_issue.is_empty() and not scene.pending_world.prepared,"Incomplete worker receipt fails explicitly before native publication")
    var unchanged:Dictionary=scene.timeline.state.duplicate(true);var clock:float=scene.timeline.display_ms
    scene.timeline.advance(5000)
    check(scene.timeline.state==unchanged and scene.timeline.display_ms==clock,"Preparation failure cannot advance canonical state or clock")
    var closing=weakref(scene.pending_world)
    scene.timeline.world_ready=Callable() # Test callback captures scene; release that reference before teardown.
    scene.queue_free();await process_frame;await process_frame
    check(closing.get_ref()==null,"Closing failed/pending preparation joins worker and frees native target")
    var report={"checks":checks,"failures":failures,"comparisons":evidence,"direct_lights_enabled":"--fixed-direct" not in OS.get_cmdline_user_args(),"scope":"Actual Crypt originals with named door and floor-representative elevation after-values; original total painter order including hidden variants; held native preparation, source-state/picking/trace/time isolation, four solid quarters and independent full native construction, pending rotation replacement, received future preparation, initialization epoch replacement, explicit worker-receipt failure and close cleanup. Optional whole-encounter preload budget0 for this correctness fixture."}
    FileAccess.open("res://generated/world_preparation_render_"+("fixed" if "--fixed-direct" in OS.get_cmdline_user_args() else "native")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("WORLD_PREPARATION_RENDER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
