extends SceneTree
## The real Studio must finish its authored tails, then stop or loop.
const Studio=preload("res://studio/studio.gd")
var checks=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("STUDIO_CLIP_END_FAIL ",label)
func _initialize()->void:run.call_deferred()
func ready(studio:Control)->bool:
    return not studio.index.is_empty() and studio.loader==null and (studio.seeker==null or studio.preparing_loop) and (not studio.installing or studio.preparing_loop) and studio.requested_seek<0 and not studio.world.rotation_pending()
func settle(studio:Control)->bool:
    var deadline=Time.get_ticks_msec()+90000
    while not ready(studio) and Time.get_ticks_msec()<deadline:await process_frame
    check(ready(studio),"Actual recorded scene publishes")
    return ready(studio)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var studio=Studio.new();root.add_child(studio)
    if not await settle(studio):await finish(studio);return
    studio.loop_enabled=false
    var end:float=studio.index.presentation_end_ms
    check(end>=studio.index.duration_ms,"All authoritative operations fit before the presentation end")
    for row in studio.index.rows:
        if row.has("component") and row.get("status")=="available":check(row.end_ms<=end+.001,"Presentation end includes actual "+row.kind+" tail")
    studio._seek(maxf(0,end-200),true)
    if not await settle(studio):await finish(studio);return
    var deadline=Time.get_ticks_msec()+15000
    while not studio.world.timeline.paused and Time.get_ticks_msec()<deadline:await process_frame
    check(studio.world.timeline.paused and is_equal_approx(studio.world.timeline.display_ms,end),"Play stops exactly at the actual presentation end")
    check(not studio.world.timeline.busy(),"End pause does not leave authoritative groups unprocessed")
    var clock=studio.world.timeline.display_ms
    for n in 8:await process_frame
    check(studio.world.timeline.display_ms==clock,"End has no advancing empty idle tail")
    studio._toggle_play()
    if not await settle(studio):await finish(studio);return
    check(studio.world.timeline.display_ms<end and not studio.world.timeline.paused,"Play at end restarts the study")
    studio.loop_start=maxf(0,end-300);studio.loop_end=end;studio.loop_enabled=true
    studio._seek(end-100,true)
    if not await settle(studio):await finish(studio);return
    var looped=false;deadline=Time.get_ticks_msec()+20000
    while not looped and Time.get_ticks_msec()<deadline:
        await process_frame
        looped=ready(studio) and studio.world.timeline.display_ms<end-150 and not studio.world.timeline.paused
    check(looped,"Loop returns to its selected start after the final tail")
    check(studio.world.presentation_errors.is_empty(),"No presentation errors during end, replay or loop")
    await finish(studio)
func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"scope":"Actual Studio clip end, retained tails, end replay and loop; no gameplay or renderer changes."}
    FileAccess.open("res://generated/studio_clip_end_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_CLIP_END ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
