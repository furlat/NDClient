extends SceneTree
# Actual recorded damage and resumed target movement, through the shared Studio.
const Studio=preload("res://studio/studio.gd")
const Placement=preload("res://placement.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("STUDIO_BLOOD_FAIL ",label)
func _initialize()->void:run.call_deferred()
func ready(studio:Control)->bool:
    return not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and not studio.world.rotation_pending() and studio.world.component_renderer.ready
func settle(studio:Control)->bool:
    var end=Time.get_ticks_msec()+120000
    while not ready(studio) and Time.get_ticks_msec()<end:await process_frame
    check(ready(studio),"Recorded requested view publishes: "+studio.status.text)
    return ready(studio)
func check_placement(studio:Control,id:String,anchor:Vector3)->void:
    var renderer=studio.world.component_renderer
    check(renderer.handles.has(id),"Recorded blood occurrence owns a native presenter")
    if not renderer.handles.has(id):return
    var handle:Dictionary=renderer.handles[id]
    var actor:Dictionary=studio.world.visual_actors[handle.component.actor_uuid]
    check(handle.node.position==anchor,"Native cloud retains admitted impact anchor")
    check(handle.placement.position==actor.row.position and handle.placement.base_height_steps==actor.row.base_height_steps,"Both blood parts use current recipient painter contact")
    check(handle.draws.size()==2 and handle.draws[0].half=="back" and handle.draws[1].half=="front","One occurrence supplies complementary native back/front parts")
    var front=-1;var back=-1
    for draw in handle.draws:
        if draw.half=="back":back=draw.get("draw_rank",-1)
        else:front=draw.get("draw_rank",-1)
    var parts=0;var surrounded=true
    for entry in actor.entries:
        if entry.role=="body" and entry.node.visible:
            parts+=1;surrounded=surrounded and entry.get("draw_rank",-1)>back and entry.get("draw_rank",-1)<front
    check(parts>0 and back>=0 and front>back and surrounded,"Native parts surround all visible assembled recipient body layers")
    var expected_origin=(Placement.contact(actor.row)-anchor)/float(handle.component.scale)
    check(handle.node._actor_partition_key[0].is_equal_approx(expected_origin),"Native fragment plane follows current foot in fixed-anchor source coordinates")
func capture(studio:Control,label:String)->void:
    await process_frame;await RenderingServer.frame_post_draw
    studio.viewport.get_texture().get_image().save_png("res://.captures/studio/blood/"+label+".png")
func run()->void:
    if not Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--recording=")):
        print("Usage: --recording=<real OA recording with blood and resumed recipient movement>");quit(2);return
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/blood")
    DisplayServer.window_set_size(Vector2i(1280,720))
    var studio=Studio.new();root.add_child(studio)
    if not await settle(studio):await finish(studio);return
    var rows=studio.index.rows.filter(func(row):return row.kind=="native_effect" and row.component.get("source_id","") in ["blood.hit_a1","blood.hit_a2"])
    check(not rows.is_empty(),"Real recording contains native damage blood")
    if rows.is_empty():await finish(studio);return
    var row:Dictionary=rows[0];var component:Dictionary=row.component
    var id:String=component.id
    studio._seek(row.start_ms+200.)
    if not await settle(studio):await finish(studio);return
    var resolved=studio.world.timeline.component_samples(studio.world.catalog_cache).filter(func(item):return item.id==id)
    check(resolved.size()==1 and resolved[0].get("attachment")=="impact" and resolved[0].get("impact",{}).get("status")=="available","Shared Timeline resolves authored impact anchor using exact retained event-time direction")
    if resolved.is_empty() or resolved[0].get("impact",{}).get("status")!="available":await finish(studio);return
    component=resolved[0]
    var anchor:Vector3=component.impact.world_anchor
    studio.world.camera_focus=Vector3(anchor.x,0,anchor.z);studio.world.camera.size=4.5;studio.world.position_camera()
    var first_position:Array=studio.world.visual_actors[component.actor_uuid].row.position.duplicate()
    for quarter in 4:
        if quarter!=studio.world.quarter:studio.world.request_view(quarter)
        if not await settle(studio):break
        await process_frame;await RenderingServer.frame_post_draw
        check_placement(studio,id,anchor)
        await capture(studio,"q%d-held"%quarter)
        evidence.append({"quarter":quarter,"display_ms":studio.world.timeline.display_ms,"anchor":anchor,"actor_position":studio.world.visual_actors[component.actor_uuid].row.position.duplicate(),"capture":"q%d-held"%quarter})
    # Actual shared clock resumes; no source transforms or canonical data are
    # edited by the fixture. The real recorded recipient resumes its movement.
    studio.world.timeline.paused=false
    var end=Time.get_ticks_msec()+15000
    var fixed=true;var moving=false;var sampled=0
    while studio.world.timeline.display_ms<row.start_ms+1350. and Time.get_ticks_msec()<end:
        await process_frame
        var renderer=studio.world.component_renderer
        if renderer.handles.has(id):
            fixed=fixed and renderer.handles[id].node.position==anchor
            moving=moving or studio.world.visual_actors[component.actor_uuid].row.position!=first_position
            sampled+=1
    studio.world.timeline.paused=true
    check(sampled>5 and fixed,"Advancing native blood stays detached throughout real display playback")
    check(moving,"Recorded recipient moves while the original blood occurrence remains active")
    if await settle(studio):
        check_placement(studio,id,anchor)
        await capture(studio,"recipient-moved")
        evidence.append({"display_ms":studio.world.timeline.display_ms,"anchor":anchor,"actor_position":studio.world.visual_actors[component.actor_uuid].row.position.duplicate(),"continuous_frames":sampled,"capture":"recipient-moved"})
    check(studio.world.presentation_errors.is_empty(),"Shared production renderer reports no source or preparation errors")
    await finish(studio)
func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Real recorded damage: one native blood simulation, immutable authored impact anchor, current recipient presentation-plane split and assembled-body painter interleave across four views and resumed target movement. Scenery crossings remain outside this bounded actor qualification."}
    FileAccess.open("res://generated/studio_blood_partition_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_BLOOD ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
