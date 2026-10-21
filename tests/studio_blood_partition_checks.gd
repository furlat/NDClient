extends SceneTree
## Actual BodyRelease flight and canonical deposits during resumed target movement.
const Studio=preload("res://studio/studio.gd")
const Placement=preload("res://placement.gd")
const GridOrder=preload("res://grid_order.gd")
const Blood=preload("res://presentation/blood.gd")
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
    if not ready(studio):return false
    await process_frame;await RenderingServer.frame_post_draw
    return true
func flight_entries(studio:Control,id:String)->Array:
    var result:Array=[]
    for key in studio.world.component_renderer.blood.flights:
        if str(key).begins_with(id+":"):
            var entry:Dictionary=studio.world.component_renderer.blood.flights[key]
            if entry.node.visible and entry.node.multimesh.instance_count>0:result.append(entry)
    return result
func fixed_release(studio:Control,component:Dictionary)->bool:
    var plan:Array=studio.world.component_renderer.blood._flight_plans.get(component.id,[])
    return not plan.is_empty() and plan[0]==component.body_release and plan[1]==component.body_release.position \
        and plan[2]==component.elevation_steps
func partition_state(studio:Control,component:Dictionary,compare_buffers:bool=false)->Dictionary:
    var entries:Array=flight_entries(studio,component.id)
    var actor:Dictionary=studio.world.visual_actors.get(component.actor_uuid,{})
    if actor.is_empty():return {"pairs":0,"contact_pairs":0,"valid":false,"surrounded":false}
    var foot:Vector3=Placement.contact(actor.row)
    var normal:Vector3=Vector3(studio.world.camera.basis.z.x,0,studio.world.camera.basis.z.z).normalized()
    var actor_key:Array=GridOrder.key(actor.row,"body",0,0).slice(0,5)
    var pairs:Dictionary={};var valid:bool=not entries.is_empty();var surrounded:bool=true;var contacts:int=0
    for entry in entries:
        var half:String="back" if entry.written_back else "front"
        var key:String=str(entry.id).trim_suffix(":"+half)
        if not pairs.has(key):pairs[key]={}
        pairs[key][half]=entry
        valid=valid and entry.node.get_instance_shader_parameter("partition")==true \
            and entry.node.get_instance_shader_parameter("back")==entry.written_back \
            and entry.node.get_instance_shader_parameter("plane_origin").is_equal_approx(foot) \
            and entry.node.get_instance_shader_parameter("plane_normal").is_equal_approx(normal)
    for pair in pairs.values():
        if not pair.has("back") or not pair.has("front"):valid=false;continue
        var back:Dictionary=pair.back;var front:Dictionary=pair.front
        valid=valid and back.node.multimesh.instance_count==front.node.multimesh.instance_count \
            and back.placement.position==front.placement.position \
            and back.placement.base_height_steps==front.placement.base_height_steps
        if compare_buffers:valid=valid and back.node.multimesh.buffer==front.node.multimesh.buffer
        if GridOrder.key(back.placement,"native_effect",back.layer,0).slice(0,5)!=actor_key:continue
        contacts+=1
        var parts:int=0
        for entry in actor.entries:
            if entry.role=="body" and entry.node.visible:
                parts+=1;surrounded=surrounded and entry.get("draw_rank",-1)>back.get("draw_rank",-1) and entry.get("draw_rank",-1)<front.get("draw_rank",-1)
        surrounded=surrounded and parts>0 and back.get("draw_rank",-1)>=0 and front.get("draw_rank",-1)>back.get("draw_rank",-1)
    return {"pairs":pairs.size(),"contact_pairs":contacts,"valid":valid,"surrounded":surrounded}
func capture(studio:Control,label:String)->PackedByteArray:
    await process_frame;await RenderingServer.frame_post_draw
    var image:Image=studio.viewport.get_texture().get_image()
    image.save_png("res://.captures/studio/blood/"+label+".png")
    return image.get_data()
func difference(a:PackedByteArray,b:PackedByteArray)->int:
    if a.size()!=b.size():return -1
    var changed:int=0
    for i in range(0,a.size(),4):
        if a[i]!=b[i] or a[i+1]!=b[i+1] or a[i+2]!=b[i+2] or a[i+3]!=b[i+3]:changed+=1
    return changed
func run()->void:
    if not Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--recording=")):
        print("Usage: --recording=<real OA journal with BodyRelease and resumed recipient movement>");quit(2);return
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/blood")
    DisplayServer.window_set_size(Vector2i(1280,720))
    var studio=Studio.new();root.add_child(studio)
    if not await settle(studio):await finish(studio);return
    var rows:Array=studio.index.rows.filter(func(row):return row.kind=="residue_deposit" and row.status=="available" \
        and row.component.get("body_release",{}).get("release_id")=="body.blood" and row.component.get("flight_enabled",false))
    var selected:Dictionary={};var moves:Array=[]
    for row in rows:
        var movement:Array=studio.index.rows.filter(func(candidate):return candidate.kind in ["body","motion"] \
            and candidate.get("track",{}).get("actor_uuid")==row.component.actor_uuid and candidate.track.get("motion",false) \
            and candidate.start_ms<row.end_ms and candidate.end_ms>row.start_ms)
        if not movement.is_empty():selected=row;moves=movement;break
    check(not selected.is_empty(),"Actual recorded BodyRelease overlaps genuine resumed recipient movement")
    if selected.is_empty():await finish(studio);return
    var row:Dictionary=selected;var component:Dictionary=row.component
    var source:Dictionary=component.asset_metadata
    var plan:Array=Blood.flight_plan(component,source)
    check(not plan.is_empty() and component.position==component.body_release.position,"Flight starts from the actual disclosed release, with source-owned particle timings")
    if plan.is_empty():await finish(studio);return
    var first:Array=plan[0]
    for flight in plan:
        if float(flight[0])+float(flight[1])*.5<float(first[0])+float(first[1])*.5:first=flight
    var at:float=float(row.start_ms)+(float(first[0])+float(first[1])*.5)*1000.0
    check(at<float(row.end_ms) and moves.any(func(move):return move.end_ms>at),"Source-derived first flight sample precedes real remaining movement")
    studio._seek(at)
    if not await settle(studio):await finish(studio);return
    var anchor:Vector3=Vector3(component.position[0],float(component.elevation_steps)*Placement.HEIGHT_UNIT,component.position[1])
    studio.world.camera_focus=Vector3(anchor.x,0,anchor.z);studio.world.camera.size=4.5;studio.world.position_camera()
    if not await settle(studio):await finish(studio);return
    var first_position:Array=studio.world.visual_actors[component.actor_uuid].row.position.duplicate()
    var original:Dictionary=studio.world.timeline.state.duplicate(true)
    for quarter in 4:
        if quarter!=studio.world.quarter:studio.world.request_view(quarter)
        if not await settle(studio):break
        var state:Dictionary=partition_state(studio,component,true)
        check(fixed_release(studio,component),"Actual source plan retains immutable release origin/support q"+str(quarter))
        check(state.pairs>0 and state.valid,"Actual per-cell flight halves share source geometry and current recipient partition q"+str(quarter))
        check(state.contact_pairs>0 and state.surrounded,"Recipient-cell flight halves surround every visible assembled body layer q"+str(quarter))
        var shown:PackedByteArray=await capture(studio,"q%d-held"%quarter)
        studio.world.presentation_mutes[component.id]=true
        if not await settle(studio):break
        var muted:PackedByteArray=await capture(studio,"q%d-muted"%quarter)
        check(flight_entries(studio,component.id).is_empty(),"Exact occurrence mute withdraws its finite flight q"+str(quarter))
        check(difference(shown,muted)>0,"Actual selected blood source changes visible scene pixels q"+str(quarter))
        studio.world.presentation_mutes.erase(component.id)
        if not await settle(studio):break
        check(difference(shown,await capture(studio,"q%d-restored"%quarter))==0,"Same-clock unmute restores exact source pixels q"+str(quarter))
        check(studio.world.timeline.state==original and is_equal_approx(studio.world.timeline.display_ms,at),"Diagnostics preserve canonical after-values and display clock q"+str(quarter))
        evidence.append({"quarter":quarter,"display_ms":at,"release_event":component.source_event_uuid,"release":component.body_release,
            "component_id":component.id,"source":component.source,"partition":state,"anchor":anchor})
    # Continue the actual recorded clock. No source node, canonical actor,
    # release geometry or movement track is changed by this control.
    studio.world.timeline.paused=false
    var end:int=Time.get_ticks_msec()+15000
    var fixed:bool=true;var partitioned:bool=true;var moving:bool=false;var sampled:int=0;var moving_samples:int=0
    while studio.world.timeline.display_ms<float(row.end_ms)-.01 and Time.get_ticks_msec()<end:
        await process_frame
        if flight_entries(studio,component.id).is_empty():continue
        fixed=fixed and fixed_release(studio,component)
        partitioned=partitioned and partition_state(studio,component).valid
        var moved:bool=studio.world.visual_actors[component.actor_uuid].row.position!=first_position
        moving=moving or moved
        if moved:moving_samples+=1
        sampled+=1
    studio.world.timeline.paused=true
    check(sampled>5 and fixed,"Real playback keeps airborne geometry on its exact released source plan")
    check(moving and moving_samples>0 and partitioned,"Actual recipient moves while flight planes follow its current contact")
    if await settle(studio):await capture(studio,"recipient-moved")
    studio._seek(float(row.end_ms)+.01)
    if await settle(studio):
        check(flight_entries(studio,component.id).is_empty(),"Source-timed finite flight retires without deleting canonical residues")
        var received:int=0;var owned:bool=true
        var renderer=studio.world.component_renderer.blood
        for reveal in component.reveals:
            var key:String=Blood.field_key(reveal.position,str(component.residue_id))
            if not renderer.deposits.has(key):continue
            var tile:Dictionary=studio.world.timeline.state.tiles.get(Blood.key(reveal.position),{})
            if tile.is_empty():continue
            received+=1;owned=owned and renderer.deposits[key].value==Blood.residue(tile,str(component.residue_id))
        check(received>0 and owned,"Retained deposits remain owned by exact current canonical tile after-values")
    check(studio.world.presentation_errors.is_empty(),"Shared renderer reports no source/preparation error")
    evidence.append({"continuous_frames":sampled,"moving_flight_frames":moving_samples,"movement_tracks":moves.map(func(move):return move.id),
        "flight_end_ms":row.end_ms,"partition_foot":"actual current recipient contact","release_anchor":anchor})
    await finish(studio)
func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Real BodyRelease source/geometry/timing and canonical tile residue ownership, four-view actual per-cell back/front flight pairing and recipient painter interleave, positive pixels/exact renderer mute restoration and resumed recorded movement. No retired blood.hit_a presenter, synthetic release or scenery-crossing qualification."}
    FileAccess.open("res://generated/studio_blood_partition_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_BLOOD ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
