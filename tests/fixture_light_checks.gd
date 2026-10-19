extends SceneTree
# Actual recorded fixture and original flame frames. Activation/visibility
# after-values below are named presentation fixtures, not gameplay commands.
const Player = preload("res://play.tscn")
var checks = 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("FIXTURE_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func capture() -> Image:
    await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func differences(a: Image,b: Image) -> int:
    var count = 0
    for y in range(a.get_height()):
        for x in range(a.get_width()):
            var first = a.get_pixel(x,y); var second = b.get_pixel(x,y)
            if absf(first.r-second.r)+absf(first.g-second.g)+absf(first.b-second.b) > .02: count += 1
    return count
func run() -> void:
    var scene = Player.instantiate()
    scene.timeline.paused = true
    root.add_child(scene)
    var deadline = Time.get_ticks_msec()+60000
    while not scene.session.recording_ready and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    scene.session.close()
    while (not scene._environment_media_ready() or not scene.MediaWarmup.ready(scene.media_warmup,scene.media_plan.required)) and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline: await scene.presentation_updated
    await scene.presentation_updated
    scene.hud.hide()
    scene.set_process(false)
    check(scene.session.issue.is_empty() and not scene.timeline.state.is_empty(),"Real fixture recording admits")
    if scene.timeline.state.is_empty(): quit(1); return
    var original: Dictionary = scene.timeline.state.duplicate(true)
    check(scene.fixture_entries.size()==2,"Both disclosed lit wall torches display their authored flame")
    var assets = scene.Catalog.environment_resources(scene.catalog_cache)
    var reference: Dictionary = assets.animations["torch.flame"]
    var strengths: Array = []
    var first: Image
    for i in range(reference.frames.size()):
        scene.timeline.display_ms = (float(i)+.25)/float(reference.fps)*1000.0
        scene._sample_fixtures()
        for entry in scene.fixture_entries:
            check(entry.record.path==assets.resources[reference.frames[i]].path,"Native clock selects the original authored flame frame")
            check(entry.pivot==Vector2(128,209.92) and is_equal_approx(entry.scale,128.0/127.0),"Flame preserves original registration")
            check(entry.node.position==scene.Placement.contact(entry.placement),"Flame stays at its fixture's authoritative support")
        strengths.append(scene.fixture_energy.values()[0])
        if i == 0:
            first = await capture()
            for entry in scene.fixture_entries: entry.node.visible = false
            var absent = await capture()
            check(differences(first,absent)>10,"Original flame changes actual native viewport pixels")
            for entry in scene.fixture_entries: entry.node.visible = true
        if i == reference.frames.size()/2:
            var later = await capture()
            check(differences(first,later)>10,"Authored animation visibly changes flame pixels")
    check(strengths.max()-strengths.min()>.005,"Light energy fluctuates with the original flame sequence")
    check(strengths.min()>=.85 and strengths.max()<=1.15,"Light fluctuation remains gentle and bounded")
    var held: Dictionary = scene.fixture_energy.duplicate()
    var held_heights: Dictionary = scene.fixture_heights.duplicate()
    await process_frame
    scene._sample_fixtures()
    check(scene.fixture_energy==held,"Paused displayed time freezes both flame and light")
    check(scene.fixture_heights==held_heights,"Paused displayed time freezes original flame optical elevation")
    for object in scene.timeline.state.objects.values():
        if object.item.item_id=="environment.wall_torch": object.item.is_lit = false
    scene._sync_world(); scene._sample_fixtures(); scene._sort_draws()
    check(scene.fixture_entries.is_empty() and scene.fixture_energy.is_empty(),"Displayed extinguishing removes flame and animated energy")
    check(scene.fixture_heights.is_empty(),"Extinguishing removes stale optical fixture elevations")
    scene.timeline.state = original.duplicate(true)
    scene.timeline.state.senses.objects.clear()
    scene._sync_world(); scene._sample_fixtures(); scene._sort_draws()
    check(scene.fixture_entries.is_empty(),"Remembered torch has no active flame without visual contact")
    scene.timeline.state = original
    scene._sync_world(); scene._sample_fixtures(); scene._sort_draws(); scene.update_wall_visibility()
    check(scene.fixture_entries.size()==2,"Restoring disclosed lit fixtures restores both flame layers")
    var restored = await capture()
    restored.save_png("res://.captures/player/fixture-lights.png")
    var report = {"checks":checks,"failures":failures,"frame_energy":strengths}
    var file = FileAccess.open("res://generated/fixture_light_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ")); file.close()
    print(JSON.stringify(report))
    scene.queue_free(); await process_frame
    quit(0 if failures.is_empty() else 1)
