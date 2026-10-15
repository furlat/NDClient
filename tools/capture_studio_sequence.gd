extends SceneTree
## Observe the actual Studio. No backend, synthetic events or private VFX clock.
const Studio=preload("res://studio/studio.gd")
var studio:Control
var job:Dictionary
var results:Array=[]
var failures:Array=[]

func _initialize()->void:run.call_deferred()
func frame()->void:
    await process_frame
    await RenderingServer.frame_post_draw

func errors()->Array:
    var result:Array=[]
    for owner in [studio.world]:
        result.append_array(owner.presentation_errors)
        if not owner.media_issue.is_empty():result.append(owner.media_issue)
    return result

func settled()->bool:
    if studio.index.is_empty() or studio.loader!=null or studio.seeker!=null or studio.installing or studio.requested_seek>=0 or not studio.pending_directory.is_empty():return false
    for owner in [studio.world]:
        if owner.rotation_pending() or not owner.playback_prepared():return false
    return true

func wait_ready()->bool:
    var deadline:int=Time.get_ticks_msec()+120000
    while Time.get_ticks_msec()<deadline:
        if not errors().is_empty():failures.append(errors());return false
        if settled():
            studio.world.timeline.paused=true
            await frame()
            return true
        await process_frame
    failures.append("Studio did not publish: "+studio.status.text);return false

func advance(target:float)->bool:
    var deadline:int=Time.get_ticks_msec()+120000
    while studio.world.timeline.display_ms<target-.001 or not settled():
        if Time.get_ticks_msec()>=deadline or not errors().is_empty():
            failures.append({"requested_ms":target,"published_ms":studio.world.timeline.display_ms,"errors":errors()});return false
        # Keep native sampling at the normal display step, independently of the
        # screenshot cadence. The selected faction validates before publication.
        var next:float=minf(target,studio.world.timeline.display_ms+1000.0/60.0)
        studio.advance_review_to(next)
        await frame()
    return absf(studio.world.timeline.display_ms-target)<.001

func capture(folder:String,number:int,target:float,receipt:Dictionary)->bool:
    # Follow the published clock, exactly as the visible Studio does. A requested
    # sample can differ by floating-point roundoff at a component boundary.
    var displayed:float=studio.world.timeline.display_ms
    var selected:String=studio.tracks.follow_at(displayed)
    var deadline:int=Time.get_ticks_msec()+120000
    var previews:Dictionary=studio.tracks.prepare_visible(true)
    while not previews.settled and Time.get_ticks_msec()<deadline:
        await process_frame;previews=studio.tracks.prepare_visible(true)
    if not previews.settled or not previews.errors.is_empty():
        failures.append({"track":selected,"preview_errors":previews.errors,"pending":previews.pending});return false
    await frame()
    var selected_visible:bool=selected.is_empty() or studio.tracks.followed_visible()
    if not selected_visible:
        var diagnostics={"selected":selected,"time":target,"extent":[studio.tracks.size.x,studio.tracks.size.y],"requested_scroll":studio.tracks.scroll_y,"published_scroll":studio.tracks.published_layout.get("scroll_y",0),"rows":[]}
        for item in studio.tracks.published_layout.get("rows",[]):diagnostics.rows.append({"id":item.row.id,"height":studio.tracks._height(item.row)})
        FileAccess.open(folder.path_join("follow-error.json"),FileAccess.WRITE).store_string(JSON.stringify(diagnostics,"  "))
        failures.append("Followed track is outside the captured timeline: "+selected);return false
    var name:String="frame-%04d.png"%number
    var world_name:String="world-%04d.png"%number
    # Resolve the current viewport after every publication, never a cached pane.
    if root.get_texture().get_image().save_png(folder.path_join(name))!=OK:return false
    if studio.viewport.get_texture().get_image().save_png(folder.path_join(world_name))!=OK:return false
    var active:Array=[]
    for row in studio.index.rows:
        if row.start_ms<=displayed and displayed<row.end_ms and row.get("visible_here",true):active.append(row.id)
    var evidence={"file":name,"world_file":world_name,"seconds":studio.world.timeline.display_ms/1000.0,
        "requested_ms":target,"published_ms":studio.world.timeline.display_ms,"followed_row":selected,"active_rows":active,
        "followed_lane":studio.tracks.display_row_for.get(selected,selected),"track_context":studio.tracks.context_labels(studio.tracks.published_layout),
        "pane_size":[studio.viewport.size.x,studio.viewport.size.y],"replay":studio.replay_diagnostics(),
        "scroll_y":studio.tracks.published_layout.get("scroll_y",0),"origin_ms":studio.tracks.published_layout.get("origin_ms",0),"followed_row_visible":selected_visible}
    receipt.frames.append(evidence)
    return true

func inspect_case(spec:Dictionary)->void:
    print("STUDIO_SEQUENCE_BEGIN ",spec.id)
    studio=Studio.new()
    studio.follow_actor_id=str(spec.get("follow_actor",""))
    studio.initial_view_size=float(spec.get("view_size",12))
    root.add_child(studio)
    studio.loop_enabled=false;studio.follow_tracks=true
    studio.loop_button.set_pressed_no_signal(false)
    # PNG readback and fixed display stepping are visual review, not an FPS test.
    studio.fps_label.hide()
    studio._select_browser_path(spec.recording);studio._load(spec.recording)
    if not await wait_ready():return
    if spec.has("perspective") and studio.active_perspective!=spec.perspective:
        failures.append("Loaded audience differs from requested perspective: "+str(spec));return
    studio._rotate(int(spec.get("camera",0))-studio.world.quarter)
    if not await wait_ready():return
    var start:float=spec.get("start_ms",0)
    var end:float=spec.get("end_ms",studio.index.presentation_end_ms)
    if spec.has("row_id"):
        var found:Array=studio.index.rows.filter(func(row):return row.id==spec.row_id)
        if found.is_empty():failures.append("No recorded row: "+str(spec.row_id));return
        start=found[0].start_ms;end=found[0].end_ms
    if spec.has("at_ms"):start=float(spec.at_ms);end=start
    if start<0 or end<start or end>studio.index.presentation_end_ms+.001:
        failures.append("Requested range is outside the actual recording: "+str(spec));return
    studio._seek(start)
    if not await wait_ready():return
    if absf(studio.world.timeline.display_ms-start)>.001:failures.append("Seek did not publish requested start");return
    studio.world.external_clock=true
    var folder:String=job.output.path_join(spec.id);DirAccess.make_dir_recursive_absolute(folder)
    var receipt={"id":spec.id,"recording":studio.active_directory,"perspective":studio.active_perspective,
        "camera":studio.world.quarter,"start_ms":start,"end_ms":end,"seconds":end/1000.0,"fps":job.review_fps,
        "frames":[],"events":[],"rows":[],"errors":[],"preparation_begin":start/1000.0,"release":start/1000.0,"arrival":start/1000.0}
    var release:float=INF;var contact:float=INF
    for row in studio.index.rows:
        if row.end_ms<start or row.start_ms>end:continue
        receipt.rows.append({"id":row.id,"parent":row.get("parent",""),"label":row.label,"kind":row.kind,
            "start_ms":row.start_ms,"end_ms":row.end_ms,"status":row.get("status",""),"reason":row.get("reason",""),"source":row.get("source","")})
        var component:Dictionary=row.get("component",{})
        if component.get("native_spell",false) and row.kind=="native_effect":
            var cue:Dictionary=component.native_cue
            var origin:float=float(row.get("source_start_ms",row.start_ms))/1000.0
            receipt.events.append({"id":row.id,"role":cue.role,"begin":row.start_ms/1000.0,"end":row.end_ms/1000.0,"contact":origin+cue.contact})
            release=minf(release,origin+cue.launch)
            contact=minf(contact,origin+cue.contact)
    if is_finite(release):receipt.release=release
    if is_finite(contact):receipt.arrival=contact
    var count:int=int(ceil((end-start)/1000.0*float(job.review_fps)))+1
    for i in count:
        var at:float=minf(end,start+float(i)*1000.0/float(job.review_fps))
        if not await advance(at) or not await capture(folder,i,at,receipt):
            failures.append("Capture incomplete: "+spec.id);break
    receipt.errors=errors()
    receipt.complete=receipt.frames.size()==count and receipt.errors.is_empty()
    FileAccess.open(folder.path_join("sequence.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"  "))
    results.append(receipt)
    print("STUDIO_SEQUENCE_CASE ",spec.id," ",receipt.frames.size()," frames; complete=",receipt.complete)

func run()->void:
    var path:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--sequence-review="):path=argument.trim_prefix("--sequence-review=")
    if path.is_empty():printerr("Requires --sequence-review=res://job.json");quit(2);return
    job=JSON.parse_string(FileAccess.get_file_as_string(path))
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for spec in job.cases:
        await inspect_case(spec)
        if is_instance_valid(studio):studio.queue_free();await frame();await frame()
        if not failures.is_empty():break
    var result={"cases":results,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name()}
    FileAccess.open(job.output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("STUDIO_SEQUENCE_COMPLETE ",results.size()," cases; failures ",failures.size())
    quit(0 if failures.is_empty() else 1)
