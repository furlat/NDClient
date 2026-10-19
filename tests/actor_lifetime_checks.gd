extends "res://tests/world_incremental_checks.gd"
# Authentic initial actor appearance; explicit visibility fixture tests node
# lifetime, not a claimed backend encounter command.
const Compiler=preload("res://presentation/compiler.gd")
func publish_visibility(scene:Node,after:Dictionary,label:String)->bool:
    # Explicit renderer after-values still require the production preparation
    # boundary. Redisclosure cannot construct a native actor synchronously.
    var delta:Dictionary=Compiler.empty_delta()
    delta.set.audience=after.audience;delta.set.senses=after.senses
    scene.timeline.accept({"kind":"operation","groups":[{"id":"actor-lifetime-"+label,
        "operation_sequence":scene.timeline.sequence+1,"operation_end":true,"duration_ms":0.0,
        "actor_tracks":[],"staged_tiles":{},"staged_actors":{},"events":[],"commits":[{"at_ms":0.0,"delta":delta}]}]})
    scene.timeline.paused=false
    var deadline:int=Time.get_ticks_msec()+60000
    while (scene.timeline.busy() or scene.pending_world!=null) and scene.media_issue.is_empty() and not scene.publication_failed and Time.get_ticks_msec()<deadline:
        # This fixture owns a fixed sampling clock. Native preparation and
        # drawing progress on real frames; the named after-value has no duration.
        scene._process(0.0)
        await process_frame
    scene.timeline.paused=true
    var complete:bool=scene.timeline.state==after and not scene.timeline.busy() and scene.pending_world==null and not scene.publication_failed
    check(complete,label+" exact after-value publishes through complete native preparation")
    return complete
func run() -> void:
    if DisplayServer.get_name()=="headless":print("ACTOR_LIFETIME_CHECKS requires native graphics");quit(2);return
    root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    var scene = Player.instantiate(); scene.timeline.paused = true; root.add_child(scene)
    if not open_fixture(scene):scene.queue_free();await process_frame;quit(1);return
    var deadline = Time.get_ticks_msec()+90000
    while (not scene.session.recording_ready or not scene._media_ready({}) or scene.world_revision<0) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
    check(scene.session.issue.is_empty() and scene.media_issue.is_empty() and scene._media_ready({}) and scene.world_revision>=0,"Authentic actor original media and complete native world prepare")
    if not failures.is_empty():scene.queue_free();await process_frame;quit(1);return
    scene.session.close()
    scene.session.take_prepared() # The fixture retains initialization, not received future commands.
    scene.set_process(false); scene.timeline.current = {}; scene.timeline.queue = []; scene.displayed_samples = {}
    var canonical: Dictionary = scene.timeline.state.duplicate(true)
    var id: String = scene.timeline.state.audience.controlled[0]
    scene.visual_actors[id].row.facing = "NE"
    scene.timeline.display_ms = 350.0
    scene._sample_actors()
    var before: Dictionary = scene.presentation_diagnostics().actors[id].duplicate(true)
    var old_nodes: Array = scene.visual_actors[id].entries.map(func(entry):return weakref(entry.node))
    var old_host = weakref(scene.playbacks[id])
    var hidden:Dictionary=canonical.duplicate(true)
    hidden.audience.controlled.erase(id)
    hidden.senses.entities[id].visual=false
    if not await publish_visibility(scene,hidden,"lost-sight"):scene.queue_free();await process_frame;quit(1);return
    check(not scene.visual_actors.has(id) and not scene.playbacks.has(id),"Lost sight retires all render hosts while canonical actor data remains")
    check(scene.timeline.state.actors.has(id),"Renderer lifecycle cannot remove canonical remembered actors")
    await process_frame
    check(old_host.get_ref()==null and old_nodes.all(func(ref):return ref.get_ref()==null),"Retired native meshes and animation host actually free")
    if not await publish_visibility(scene,canonical.duplicate(true),"redisclosed"):scene.queue_free();await process_frame;quit(1);return
    var after: Dictionary = scene.presentation_diagnostics().actors[id]
    check(scene.visual_actors[id].row.facing=="NE","Idle redisclosure restores last displayed world facing")
    check(after.source_seconds==before.source_seconds and after.clip==before.clip,"Redisclosed native tree restores exact causal source time")
    check(scene.timeline.state==canonical and scene.presentation_errors.is_empty(),"Retirement/recreation leaves canonical data intact and no presentation errors")
    var summary = {"checks":checks,"failures":failures}
    var file = FileAccess.open("res://generated/actor_lifetime_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(summary,"  "));file.close()
    print("ACTOR_LIFETIME_CHECKS ",JSON.stringify(summary))
    scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
