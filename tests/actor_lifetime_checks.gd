extends "res://tests/world_incremental_checks.gd"
# Authentic initial actor appearance; explicit visibility fixture tests node
# lifetime, not a claimed backend encounter command.
func run() -> void:
    root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    var scene = Player.instantiate(); scene.timeline.paused = true; root.add_child(scene)
    var deadline = Time.get_ticks_msec()+90000
    while not scene.session.recording_ready and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    scene.session.close()
    while not scene._media_ready({}) and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline: await scene.presentation_updated
    check(scene._media_ready({}),"Authentic actor original media prepare")
    if not scene._media_ready({}): quit(1); return
    scene.set_process(false); scene.timeline.current = {}; scene.timeline.queue = []; scene.displayed_samples = {}
    var canonical: Dictionary = scene.timeline.state.duplicate(true)
    var id: String = scene.timeline.state.audience.controlled[0]
    scene.visual_actors[id].row.facing = "NE"
    scene.timeline.display_ms = 350.0
    scene._sample_actors()
    var before: Dictionary = scene.presentation_diagnostics().actors[id].duplicate(true)
    var old_nodes: Array = scene.visual_actors[id].entries.map(func(entry):return weakref(entry.node))
    var old_host = weakref(scene.playbacks[id])
    scene.timeline.state.audience.controlled.erase(id)
    scene.timeline.state.senses.entities[id] = {"visual":false}
    scene.timeline.revision += 1
    scene._sync_actors(); scene._sample_actors()
    check(not scene.visual_actors.has(id) and not scene.playbacks.has(id),"Lost sight retires all render hosts while canonical actor data remains")
    check(scene.timeline.state.actors.has(id),"Renderer lifecycle cannot remove canonical remembered actors")
    await process_frame
    check(old_host.get_ref()==null and old_nodes.all(func(ref):return ref.get_ref()==null),"Retired native meshes and animation host actually free")
    scene.timeline.state = canonical.duplicate(true); scene.timeline.revision += 1
    scene._sync_actors(); scene._sample_actors()
    var after: Dictionary = scene.presentation_diagnostics().actors[id]
    check(scene.visual_actors[id].row.facing=="NE","Idle redisclosure restores last displayed world facing")
    check(after.source_seconds==before.source_seconds and after.clip==before.clip,"Redisclosed native tree restores exact causal source time")
    check(scene.timeline.state==canonical and scene.presentation_errors.is_empty(),"Retirement/recreation leaves canonical data intact and no presentation errors")
    var summary = {"checks":checks,"failures":failures}
    var file = FileAccess.open("res://generated/actor_lifetime_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(summary,"  "));file.close()
    print("ACTOR_LIFETIME_CHECKS ",JSON.stringify(summary))
    scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
