extends SceneTree
## Native Studio inspection of the actual current-schema Hide/torch journal.
const Studio=preload("res://studio/studio.gd")
const LightTracks=preload("res://studio/light_tracks.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_LIGHT_UI_FAIL ",label)
func settle(studio:Control)->bool:
    var deadline=Time.get_ticks_msec()+90000
    while Time.get_ticks_msec()<deadline:
        if not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and not studio.world.rotation_pending():
            await process_frame;await RenderingServer.frame_post_draw
            return true
        await process_frame
    check(false,"Actual Studio scene publishes within bounded wait: "+studio.status.text)
    return false
func shown_sample(studio:Control)->Dictionary:
    var text:String=studio.inspector_text.text
    var start=text.find("\n")+1
    var end=text.find("\n\nOrigin:")
    if not text.begins_with("At playhead ") or end<start:return {}
    var value:Variant=JSON.parse_string(text.substr(start,end-start))
    return value if value is Dictionary else {}
func capture(name:String)->void:
    await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.captures/studio/lights/"+name+".png")
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    DisplayServer.window_set_size(Vector2i(1280,720))
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/lights")
    var requested:String=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):requested=arg.trim_prefix("--recording=")
    if requested.is_empty():printerr("Requires --recording=<actual Hide/light journal>");quit(2);return
    var studio=Studio.new();root.add_child(studio);studio.inspector.unfocusable=true
    studio.loop_enabled=false
    if not await settle(studio):await finish(studio);return
    check(studio.active_directory==requested,"UI is bound to the exact requested optical-source original")
    studio.tracks.filter="light";studio.tracks.rebuild_rows();studio.tracks.fit()
    await process_frame;await RenderingServer.frame_post_draw
    var lights=studio.index.rows.filter(func(row):return row.kind=="light")
    check(lights.size()==3,"Actual three emitters have independent native light lanes")
    check(studio.tracks.rows.size()==lights.size(),"Light filter shows exact source lanes without unrelated rows")
    for row in lights:
        check(studio.tracks.light_plots.has(row.id),"Each visible actual source draws a cached energy curve")
        if not studio.tracks.light_plots.has(row.id):continue
        var plot:Dictionary=studio.tracks.light_plots[row.id]
        var original=plot.samples
        studio.tracks.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
        check(is_same(original,studio.tracks.light_plots[row.id].samples),"Unchanged view redraw reuses its source samples")
        for key in row.light_keys:
            var x:float=studio.tracks._x(key.at_ms)
            if x<maxf(studio.tracks.gutter+2,studio.tracks._x(row.start_ms)) or x>minf(studio.tracks.size.x,studio.tracks._x(row.end_ms)):continue
            check(plot.samples.any(func(sample):return is_equal_approx(sample.time,key.at_ms)),"Curve contains the exact authoritative switch/property time")
        check(studio.tracks._participants(row)==row.actor_name,"Track recipient is the disclosed source owner only")
    await capture("native-light-lanes")
    var switchable=lights.filter(func(row):return row.light_keys.any(func(key):return not key.enabled))
    check(not switchable.is_empty(),"Actual torch source has a recorded off transition")
    if switchable.is_empty():await finish(studio);return
    var selected:Dictionary=switchable[0]
    var off:Dictionary=selected.light_keys.filter(func(key):return not key.enabled)[0]
    studio.selected_row=selected;studio.tracks.reveal(selected.id)
    studio._seek(maxf(selected.start_ms,off.at_ms-120))
    if not await settle(studio):await finish(studio);return
    studio._show_inspector(selected)
    var sample=shown_sample(studio)
    var expected=LightTracks.sample(selected,studio.world.timeline.display_ms,{"light_strength":studio.world.light_strength,"fire_light_flicker":studio.world.fire_light_flicker},studio.world.fixture_clips)
    check(not sample.is_empty() and sample.energy==expected.energy,"Inspector includes the current native source energy")
    check(sample.get("bright_radius_feet")==expected.get("bright_radius_feet") and sample.get("normal_height_source_pixels")==expected.get("normal_height_source_pixels"),"Inspector exposes native radius and normal-light height")
    check(studio.inspector_text.text.contains("No added fade") and studio.inspector_text.text.contains("PointLight2D"),"Inspector describes actual native mechanism and honest step transitions")
    check(studio.inspector_text.text.contains("source_fields") and studio.inspector_text.text.contains("PlayerState.senses.light_sources"),"Inspectable parameters retain exact property provenance")
    var was=studio.world.timeline.display_ms
    studio.world.timeline.paused=false
    var until=Time.get_ticks_msec()+1200
    while studio.world.timeline.display_ms<was+180 and Time.get_ticks_msec()<until:await process_frame
    studio.world.timeline.paused=true
    await create_timer(.2).timeout
    sample=shown_sample(studio)
    check(not sample.is_empty() and absf(float(sample.get("at_ms",-1))-studio.world.timeline.display_ms)<1,"Open light inspector follows the actual displayed clock")
    studio._seek(minf(studio.index.presentation_end_ms,off.at_ms+1))
    if not await settle(studio):await finish(studio);return
    await create_timer(.2).timeout
    sample=shown_sample(studio)
    check(studio.inspector_text.text.contains("Origin:") and not sample.is_empty(),"Seek publication retains light provenance and sampled parameters")
    check(not sample.get("enabled",true) and sample.get("energy",-1)==0,"Recorded torch-off inspection shows zero energy without a fade")
    evidence.append({"source":selected.optical_source_id,"actor":selected.actor_name,"switch_ms":off.at_ms,"display_ms":studio.world.timeline.display_ms,"inspector_sample":sample,"native_rows":lights.size()})
    await RenderingServer.frame_post_draw
    studio.inspector.get_texture().get_image().save_png("res://.captures/studio/lights/recorded-torch-off-inspector.png")
    studio.inspector.hide();await capture("recorded-torch-off")
    check(studio.world.presentation_errors.is_empty() and studio.world.media_issue.is_empty(),"Native production rendering has no reported source/presentation errors")
    await finish(studio)
func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame;await RenderingServer.frame_post_draw
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Native UI using actual Hide/light recording: optical-source curve draw, exact keys, cached redraw, parameter provenance and inspector continuity. No new lighting or gameplay model."}
    FileAccess.open("res://generated/studio_light_ui_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_LIGHT_UI ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
