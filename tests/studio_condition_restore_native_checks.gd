extends SceneTree
## Native before/after removal with the same actual Studio actor and tracks.
const Studio=preload("res://studio/studio.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
const CAPTURES="res://.captures/studio/condition-restoration"
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_RESTORE_NATIVE_FAIL ",label)
func settle(studio:Control)->bool:
    var deadline=Time.get_ticks_msec()+90000
    while Time.get_ticks_msec()<deadline:
        if not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and not studio.world.rotation_pending():
            await process_frame;await RenderingServer.frame_post_draw
            return true
        await process_frame
    check(false,"Actual Studio prefix publishes: "+studio.status.text)
    return false
func capture(studio:Control,name:String)->void:
    await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(CAPTURES.path_join(name+".png"))
    studio.viewport.get_texture().get_image().save_png(CAPTURES.path_join(name+"-world.png"))
func run()->void:
    if not Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--recording=")):
        printerr("Requires --recording=<actual hide-light-schema9 journal>");quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    DisplayServer.window_set_size(Vector2i(1280,720));DirAccess.make_dir_recursive_absolute(CAPTURES)
    var studio=Studio.new();root.add_child(studio);studio.loop_enabled=false
    if not await settle(studio):await finish(studio);return
    var rows=studio.index.rows.filter(func(row):return row.kind=="condition_restore" and row.owner.condition.behavior_id=="condition.hidden")
    check(rows.size()==2,"Actual Hidden removal has separate body-pose and opacity restoration lanes")
    if rows.size()!=2:await finish(studio);return
    check(rows.all(func(row):return studio.tracks.rows.any(func(entry):return entry.row.id==row.id)),"Removal ancestry is open in the default timeline")
    studio.tracks.filter="condition_restore";studio.tracks.rebuild_rows();studio.tracks.fit()
    var actor:String=rows[0].actor_uuid
    var removed:float=rows[0].transition.condition_removed_ms
    for point in [{"name":"before-removal","time":removed-.001,"clip":"CrouchIdle","alpha":.55},{"name":"after-removal","time":removed+1,"clip":"Idle","alpha":1.0}]:
        studio._seek(point.time)
        if not await settle(studio):await finish(studio);return
        check(is_equal_approx(studio.world.timeline.display_ms,point.time),"Displayed clock is the requested real boundary: "+point.name)
        check(studio.world.playbacks.get(actor,{}).get("clip")==point.clip,"Native body uses the correct source: "+point.name)
        var layers=0
        for entry in studio.world.visual_actors.get(actor,{}).get("entries",[]):
            if not entry.node.visible or entry.role=="shadow":continue
            layers+=1
            check(is_equal_approx(float(entry.material.get_shader_parameter("condition_alpha")),point.alpha),"Real body/gear receives the composed opacity: "+point.name+" "+entry.actor_layer.slot)
        check(layers>1,"Assembled original body and equipment remain present")
        var preview=studio.tracks.prepare_visible()
        check(preview.ready and preview.errors.is_empty(),"Visible restoration swatches are prepared before publication: "+point.name)
        check(studio.world.presentation_errors.is_empty() and studio.world.media_issue.is_empty(),"Native source/presentation pipeline has no error: "+point.name)
        await capture(studio,point.name)
        evidence.append({"phase":point.name,"time_ms":studio.world.timeline.display_ms,"clip":point.clip,"alpha":point.alpha,"preview":preview})
    for row in rows:
        var cells=studio.tracks._sample_cells(row)
        check(not cells.is_empty(),"Each restored method has an actual after-state source swatch")
        if cells.is_empty():continue
        var key=studio.tracks.thumbnails.request(row,cells[0].sample_ms,studio.world.quarter,false)
        check(studio.tracks.thumbnails.textures.has(key),"Inspected restored-source image is already prepared")
        if studio.tracks.thumbnails.textures.has(key):studio.tracks.thumbnails.textures[key].get_image().save_png(CAPTURES.path_join(row.mechanism+"-source.png"))
    studio.selected_row=rows[0]
    check(studio._diagnostic_id().is_empty(),"Restoration is state inspection and creates no muteable extra effect")
    await finish(studio)
func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame;await RenderingServer.frame_post_draw
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual Hide/light removal through native Studio; default ancestry, prepared source swatches, CrouchIdle→Idle and original body/gear opacity .55→1 at the recorded removal. No synthetic events or fades."}
    FileAccess.open("res://generated/studio_condition_restore_native_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_RESTORE_NATIVE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
