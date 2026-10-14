extends SceneTree
## Actual recorded condition owners through the complete production Studio renderer.
const Studio=preload("res://studio/studio.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
const CAPTURES="res://.captures/studio/basic-conditions"
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("BASIC_CONDITION_RENDER_FAIL ",label)
func ready(studio:Control)->bool:
    return not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and not studio.world.rotation_pending() and studio.world.component_renderer.ready
func settle(studio:Control)->bool:
    var end=Time.get_ticks_msec()+120000
    while not ready(studio) and Time.get_ticks_msec()<end:await process_frame
    check(ready(studio),"Requested recorded scene publishes: "+studio.status.text)
    if not ready(studio):return false
    await process_frame;await RenderingServer.frame_post_draw
    check(studio.world.presentation_errors.is_empty() and studio.world.media_issue.is_empty(),"Native scene has no source/preparation errors")
    return true
func seek(studio:Control,at:float)->bool:
    studio._seek(at)
    if not await settle(studio):return false
    check(is_equal_approx(studio.world.timeline.display_ms,at),"Requested exact owner time publishes: "+str(at))
    return is_equal_approx(studio.world.timeline.display_ms,at)
func capture(studio:Control,label:String)->PackedByteArray:
    await process_frame;await RenderingServer.frame_post_draw
    var image=studio.viewport.get_texture().get_image()
    image.save_png(CAPTURES.path_join(label+".png"))
    return image.get_data()
func difference(a:PackedByteArray,b:PackedByteArray)->int:
    if a.size()!=b.size():return -1
    var changed=0
    for i in range(0,a.size(),4):
        if a[i]!=b[i] or a[i+1]!=b[i+1] or a[i+2]!=b[i+2] or a[i+3]!=b[i+3]:changed+=1
    return changed
func run()->void:
    var directory=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--cases="):directory=arg.trim_prefix("--cases=")
    if directory.is_empty():print("Use --cases=<actual case root> --recording=<dash amber journal>");quit(2);return
    DirAccess.make_dir_recursive_absolute(CAPTURES)
    DisplayServer.window_set_size(Vector2i(1280,720))
    var studio=Studio.new();root.add_child(studio)
    if not await settle(studio):await finish(studio);return
    for item in [["dash","dashing"],["dodge","dodging"],["disengage","disengaging"]]:
        var action:String=item[0];var id="condition."+item[1]
        if action!="dash":
            studio._load(directory.path_join(action+"-seed3/amber/journal"))
            if not await settle(studio):break
        var rows=studio.index.rows.filter(func(row):return row.kind=="condition_material" and row.owner.condition.behavior_id==id)
        check(not rows.is_empty(),"Actual recorded "+action+" owns a contour row")
        if rows.is_empty():continue
        var row:Dictionary=rows[0];var owner:Dictionary=row.owner
        var at:float=minf(row.end_ms-.01,row.start_ms+150)
        if not await seek(studio,at):break
        studio.selected_row=row
        check(studio.world.component_renderer.outlines.owners.has(owner.actor_uuid),"Actual native assembled contour exists: "+action)
        var held_state=studio.world.timeline.state.duplicate(true)
        for quarter in 4:
            if quarter!=studio.world.quarter:studio.world.request_view(quarter)
            if not await settle(studio):break
            var label=action+"-q"+str(quarter)
            var coloured=await capture(studio,label+"-active")
            studio._menu_selected(7)
            await process_frame
            var plain=await capture(studio,label+"-muted")
            var changed=difference(coloured,plain)
            check(changed>0,"Indicator changes actual displayed pixels "+label)
            check(not studio.world.component_renderer.outlines.owners.has(owner.actor_uuid),"Mute disables this owner contour "+label)
            studio._menu_selected(7)
            if not await settle(studio):break
            check(difference(coloured,await capture(studio,label+"-restored"))==0,"Unmute restores exact source pixels "+label)
            check(studio.world.timeline.state==held_state and is_equal_approx(studio.world.timeline.display_ms,at),"Diagnostics leave exact state and time unchanged "+label)
            evidence.append({"action":action,"condition_uuid":owner.id,"quarter":quarter,"at_ms":at,"changed_pixels":changed,"source":row.source_fields.bodyOutline})
        if not await seek(studio,maxf(0,owner.start_ms-.01)):break
        check(not studio.world.component_renderer.outlines.owners.has(owner.actor_uuid),"No contour before real application: "+action)
        if not await seek(studio,owner.end_ms+.01):break
        check(not studio.world.component_renderer.outlines.owners.has(owner.actor_uuid),"No contour after real removal: "+action)
        if not await seek(studio,at):break
        check(studio.world.component_renderer.outlines.owners.has(owner.actor_uuid),"Reverse seek restores actual condition contour: "+action)
    await finish(studio)
func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Native production Studio, three real action recordings, four views, visible shared contour and exact mute restoration, actual application/removal/reverse seek. These are new explicit Resource indicator choices, not recovered per-action source artwork."}
    FileAccess.open("res://generated/basic_condition_render_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BASIC_CONDITION_RENDER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
