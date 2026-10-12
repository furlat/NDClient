extends "res://tests/world_incremental_checks.gd"
# Exercise the production cache with a real recorded Crypt. Door after-values
# are explicit rendering fixtures; no fabricated backend commands are claimed.
var cached_comparisons: Array = []

func cache_isolated(scene: Node) -> bool:
    var active := {}
    for entry in scene.entries: active[entry.node.get_instance_id()] = true
    if scene.entries.size()!=scene.static_entries.size()+scene.actor_entries.size(): return false
    if scene.static_views.size()>3: return false
    for view in scene.static_views.values():
        for entry in view.entries:
            if entry.node.is_visible_in_tree() or active.has(entry.node.get_instance_id()): return false
    return scene.fixture_entries.all(func(entry):return active.has(entry.node.get_instance_id()))

func compare_pixels(actual: Image, expected: Image, label: String) -> void:
    var changed := 0
    var maximum := 0.0
    for y in range(actual.get_height()):
        for x in range(actual.get_width()):
            var a := actual.get_pixel(x,y)
            var b := expected.get_pixel(x,y)
            var error := maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
            maximum = maxf(maximum,error)
            if error>1.0/255+0.00001: changed += 1
    check(changed==0,"Cached native pixels equal independent fresh build: "+label)
    cached_comparisons.append({"case":label,"changed_pixels":changed,"maximum_error":maximum})

func run() -> void:
    if DisplayServer.get_name()=="headless": print("WORLD_VIEW_CACHE_CHECKS requires native graphics"); quit(2); return
    root.unfocusable = true; root.position = Vector2i(-16000,-16000); root.size = Vector2i(960,640)
    var scene = Player.instantiate(); scene.timeline.paused = true; root.add_child(scene)
    var deadline := Time.get_ticks_msec()+120000
    while (not scene.session.recording_ready or not scene.MediaWarmup.ready(scene.media_warmup,scene.media_plan.required) or not scene._environment_media_ready()) and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    scene.session.close(); await scene.presentation_updated; scene.set_process(false); scene.hud.hide()
    check(scene.session.issue.is_empty() and not scene.timeline.state.is_empty() and scene._environment_media_ready(),"Actual Crypt and exact four-view source media initialize")
    if scene.timeline.state.is_empty() or not scene._environment_media_ready(): quit(1); return
    var canonical: Dictionary = scene.timeline.state.duplicate(true)
    var door := ""
    for row in scene.placements:
        if row.kind=="door": door = row.id; break
    check(not door.is_empty(),"Recorded source-backed door exists")
    if door.is_empty(): quit(1); return
    scene.camera_focus = Vector3(4,0,5); scene.camera.size = 10
    for mode in ["solid","translucent","hidden"]:
        scene.wall_mode = mode
        var swing := "inward" if mode=="translucent" else "outward"
        set_door_fixture(scene,door,mode!="solid",swing)
        await prepare_fixture(scene)
        # The independent reference at the previous iteration has no retained
        # production owner groups. Explicitly start a fresh active view.
        clear_world(scene); scene.world_quarter = -1
        scene._sync_world(); scene.update_wall_visibility(); scene._sample_fixtures()
        var original_views := {}
        for q in range(4):
            await rotate(scene,q)
            original_views[q] = identities(scene)
        check(scene.static_views.size()==3,"Only three inactive quarters are retained")
        var snapshots := {}
        var state_before: Dictionary = scene.timeline.state.duplicate(true)
        for q in range(4):
            await rotate(scene,q)
            check(identities(scene)==original_views[q],"Repeated rotation reuses exact node/material/batch resources: %s q%d" % [mode,q])
            check(cache_isolated(scene),"Inactive views remain hidden and outside picking/fixtures: %s q%d" % [mode,q])
            assert_order(scene,"Cached %s q%d" % [mode,q])
            snapshots[q] = await capture()
        check(scene.timeline.state==state_before,"View cache leaves canonical state unchanged")
        # Returning to a cached quarter after a mode change must restore all
        # authored Hidden corner sources, not carry a prior rear substitution.
        var previous_ids := identities(scene)
        scene.wall_mode = "hidden" if mode!="hidden" else "solid"
        scene.update_wall_visibility()
        await rotate(scene,0); await rotate(scene,3)
        scene.wall_mode = mode; scene.update_wall_visibility()
        check(identities(scene)==previous_ids,"Wall-mode changes retain cached owner identities")
        compare_pixels(await capture(),snapshots[3],"Mode transition round trip "+mode)
        # A new displayed revision with unchanged authored rows retains every
        # inactive view. Actual door state change invalidates all inactive views.
        scene.timeline.revision += 1
        scene._sync_world()
        check(scene.static_views.size()==3 and identities(scene)==previous_ids,"Unchanged canonical rows preserve all quarters across a displayed revision")
        var stale: Array = []
        for view in scene.static_views.values():
            for entry in view.entries: stale.append(weakref(entry.node))
        set_door_fixture(scene,door,mode=="solid",swing)
        await prepare_fixture(scene)
        scene._sync_world(); scene.update_wall_visibility()
        check(scene.static_views.is_empty(),"Changed authored door rows invalidate inactive views")
        var retirement_deadline = Time.get_ticks_msec()+60000
        while scene.presentation_diagnostics().retiring_nodes>0 and Time.get_ticks_msec()<retirement_deadline:
            scene._dispose_views()
            await process_frame
        check(stale.all(func(ref):return ref.get_ref()==null),"Invalidated cached native nodes are released")
        set_door_fixture(scene,door,mode!="solid",swing)
        await prepare_fixture(scene)
        for q in range(4):
            scene.quarter = q; scene.position_camera()
            scene._sample_actors()
            reference_rebuild(scene)
            compare_pixels(snapshots[q],await capture(),"%s q%d" % [mode,q])
    check(scene.presentation_errors.is_empty(),"No presentation errors")
    scene.timeline.state = canonical
    var report := {"checks":checks,"failures":failures,"comparisons":cached_comparisons,"renderer":RenderingServer.get_video_adapter_name()}
    var file := FileAccess.open("res://generated/world_view_cache_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ")); file.close()
    print("WORLD_VIEW_CACHE_CHECKS ",checks," checks; ",failures.size()," failures")
    scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
