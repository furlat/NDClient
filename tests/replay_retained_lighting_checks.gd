extends SceneTree
## A real replay reset can retain its lighting geometry while replacing the
## authoritative prefix. It must not demand an unprepared full atlas replacement.
const Play=preload("res://play.gd")
const Recording=preload("res://studio/recording.gd")
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("REPLAY_RETAINED_LIGHTING_FAIL ",label)
func settled(world:Node)->bool:
    var deadline:int=Time.get_ticks_msec()+30000
    while not world.playback_prepared() and world.presentation_errors.is_empty() and world.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
    return world.playback_prepared() and world.presentation_errors.is_empty() and world.media_issue.is_empty()
func lighting(world:Node)->Dictionary:
    var atlas=world.native_light_atlas
    return {"source_serial":world.native_light_change_serial,"atlas_serial":atlas.delta_serial,
        "sources":atlas.entry_specs.size(),"receivers":atlas.receivers.size(),
        "nodes":atlas.receivers.map(func(receiver):return atlas.receiver_handle(receiver).get_instance_id()),
        "groups":atlas.groups.keys(),"errors":world.presentation_errors.duplicate()}
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1440,430)
    var index:Dictionary=Recording.read("res://.runtime/studio-cases/movement-oa/journal")
    check(index.ok,"Actual movement and opportunity-attack journal admitted")
    if not index.ok:finish();return
    var view=SubViewport.new();view.size=root.size;view.own_world_3d=true
    view.audio_listener_enable_3d=false;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    var world=Play.new();world.external_playback=true
    world.component_renderer.audio.set_enabled(false)
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache)
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows)
    world.native_startup_requested_ms=float(index.presentation_end_ms)*.1
    view.add_child(world)
    world.install_playback(Recording.restore(index,world.native_startup_requested_ms))
    var ready:bool=await settled(world)
    check(ready,"Real recorded prefix prepares its native lighting")
    if ready:
        var before:Dictionary=lighting(world);evidence.append({"prefix":"before reset","lighting":before})
        check(before.receivers>0 and before.sources>0,"Real initial prefix has native receiving surfaces")
        var restored:RefCounted=Recording.restore(index,0)
        check(world.try_reset_hidden_playback(restored),"Hidden inaudible renderer accepts the real earlier prefix")
        ready=await settled(world)
        check(ready,"Reset publishes without an unprepared full replacement")
        var after:Dictionary=lighting(world);evidence.append({"prefix":"reset to zero","lighting":after})
        check(world.timeline.display_ms==0 and world.timeline.state==Recording.restore(index,0).state,
            "Reset displays the exact authoritative zero-time prefix")
        check(after==before,"Unchanged lighting retains its actual source serial, receivers and groups")
        check(not world.publication_failed and not world.native_light_atlas.output_admission_failed,
            "Retained native lighting never pauses on an invalid publication")
        if ready:
            # This is a real prepared global replacement, unlike the state-only
            # reset above. Exercise its existing full receipt through Play.
            var canonical:Dictionary=world.timeline.state.duplicate(true)
            world.set_normals_visible(not world.normals_visible)
            var deadline:int=Time.get_ticks_msec()+30000
            while world.native_light_change_serial==after.source_serial and world.presentation_errors.is_empty() and Time.get_ticks_msec()<deadline:
                await process_frame
            check(world.native_light_change_serial>after.source_serial and world.native_light_changes.get("full",false),
                "Prepared global render-option replacement still publishes a full receipt")
            check(world.native_light_atlas.delta_serial==world.native_light_change_serial and world.presentation_errors.is_empty(),
                "Actual full replacement is accepted by the native atlas")
            check(world.timeline.state==canonical,"Render replacement preserves the authoritative event prefix")
            evidence.append({"prefix":"global replacement","lighting":lighting(world)})
    else:evidence.append({"errors":world.presentation_errors.duplicate(),"media_issue":world.media_issue})
    view.queue_free();await process_frame;await process_frame
    finish()
func finish()->void:
    var report={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual movement/OA recording hidden reset with retained native surfaces, exact authoritative prefix, and subsequent real prepared global replacement. No performance claim."}
    FileAccess.open("res://generated/replay_retained_lighting_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("REPLAY_RETAINED_LIGHTING ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
