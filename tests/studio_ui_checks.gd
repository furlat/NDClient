extends SceneTree
const Studio=preload("res://studio/studio.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_UI_FAIL ",label)
func _initialize()->void:run.call_deferred()
func settled(studio:Control)->bool:
    return not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0
func wait_ready(studio:Control)->bool:
    var deadline=Time.get_ticks_msec()+180000
    while not settled(studio) and Time.get_ticks_msec()<deadline:await process_frame
    check(settled(studio),"Requested production scene publishes within bounded acceptance time: "+studio.status.text)
    return settled(studio)
func capture(studio:Control,name:String)->void:
    var cache=studio.tracks.thumbnails
    var deadline=Time.get_ticks_msec()+30000
    # Let visible source requests enter the finite thumbnail queue, then wait
    # on its actual owners rather than a guessed number of render frames.
    await process_frame
    while (cache.worker!=null or not cache.pending.is_empty() or not cache.active.is_empty()) and Time.get_ticks_msec()<deadline:
        await process_frame
    await RenderingServer.frame_post_draw
    check(studio.world.native_light_atlas.viewport!=null and studio.world.entries.size()>0,"Published renderer retains its native atlas and original draw entries "+name)
    var image=studio.viewport.get_texture().get_image()
    check(image!=null and not image.is_empty() and image.get_used_rect().has_area(),"Published native viewport contains pixels "+name)
    if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png("res://.captures/studio/"+name+".png")
    evidence.append({"capture":name,"window":root.size,"preview":studio.preview.size,"timeline":studio.tracks.size,
        "display_ms":studio.world.timeline.display_ms,"sequence":studio.world.timeline.sequence,"rows":studio.index.rows.size(),"quarter":studio.world.quarter,"source_errors":cache.errors.duplicate()})
func run()->void:
    var has_recording=false
    for arg in OS.get_cmdline_user_args():has_recording=has_recording or arg.begins_with("--recording=")
    if not has_recording:print("Usage: --recording=<actual SDK journal>");quit(2);return
    DirAccess.make_dir_recursive_absolute("res://.captures/studio")
    DisplayServer.window_set_size(Vector2i(1280,720))
    var studio=Studio.new();root.add_child(studio)
    if not await wait_ready(studio):await finish(studio);return
    check(studio.case_paths.any(func(path):return "/blue/journal" in path),"Case picker includes actual blue observer recordings")
    check(studio.index.rows.any(func(row):return row.kind=="audio"),"Timeline exposes actual compiled audio rows")
    check(studio.index.rows.any(func(row):return row.kind=="native_effect"),"Timeline exposes actual compiled native source rows")
    check(studio.preview.size.y>=200 and studio.tracks.size.y>100,"1280 layout retains usable preview and tracks")
    check(studio.size.x<=1280 and studio.clock_label.get_global_rect().end.x<=1280,"1280 transport and clock fit viewport")
    check(not studio.tracks.show_metadata and studio.tracks.rows.size()<studio.index.rows.size(),"Default workspace hides metadata rows while retaining the complete index")
    check(studio.tracks.rows.any(func(item):return item.row.kind=="body"),"First meaningful occurrence opens its actual Body lane")
    var rows=studio.tracks.rows.size()
    studio._menu_selected(6)
    check(studio.tracks.show_metadata and studio.tracks.rows.size()>=rows,"Metadata remains explicitly inspectable")
    studio._menu_selected(6)
    studio._show_coverage()
    check("Condition catalog" in studio.inspector_text.text and "implementation" in studio.inspector_text.text and "native qualification separate" in studio.inspector_text.text,"On-demand coverage distinguishes mechanism, source and recorded evidence")
    studio.inspector.hide()
    await capture(studio,"1280-initial")
    check(studio.tracks.thumbnails.textures.values().any(func(texture):return texture.get_image().get_used_rect().has_area()),"Visible body/source thumbnails contain real sampled pixels")
    var layer=studio.index.rows.filter(func(row):return row.kind=="sprite_layer")[0]
    var layer_key=studio.tracks.thumbnails.request(layer,(layer.start_ms+layer.end_ms)*.5,studio.world.quarter)
    var layer_deadline=Time.get_ticks_msec()+10000
    while not studio.tracks.thumbnails.textures.has(layer_key) and Time.get_ticks_msec()<layer_deadline:await process_frame
    check(studio.tracks.thumbnails.textures.has(layer_key) and studio.tracks.thumbnails.textures[layer_key].get_image().get_used_rect().has_area(),"Short actual slash clip has a visible source midpoint thumbnail")
    check(studio.world.camera.size==6,"Small recording initial view resolves actor silhouettes at useful scale")
    check(studio.world.camera.get_node("StudioAudioListener").is_current() and studio.viewport.audio_listener_enable_3d,"Displayed native viewport owns the actual3D audio listener")
    check(studio.index.rows.any(func(row):return row.get("markers",[]).any(func(marker):return marker.kind=="commit")),"Timeline exposes original commit markers")
    check(studio.index.rows.any(func(row):return row.get("markers",[]).any(func(marker):return marker.kind=="contact")),"Timeline exposes original authored contact markers")
    DisplayServer.window_set_size(Vector2i(1920,1080));await process_frame;await process_frame
    check(studio.size.x==1920 and studio.preview.size.x<=1920,"1920 layout follows native viewport resize")
    await capture(studio,"1920-initial")
    var prior_height=studio.preview.size.y
    studio._maximize();await process_frame;await process_frame
    check(not studio.bottom.visible and studio.preview.size.y>prior_height,"Maximize preview hides tracks without replacing world")
    studio._maximize();await process_frame;await process_frame
    check(studio.bottom.visible,"Restore preview returns timeline")
    var old_world=studio.world
    var old_index=studio.index
    var old_time=old_world.timeline.display_ms
    var target=studio.index.duration_ms*.45
    studio._seek(target)
    check(studio.world==old_world and studio.world.timeline.display_ms==old_time and is_same(studio.index,old_index),"Seek keeps displayed world/index/clock until candidate ready")
    var deadline=Time.get_ticks_msec()+30000
    while studio.candidate_world==null and Time.get_ticks_msec()<deadline:await process_frame
    check(studio.candidate_world!=null,"Seek builds a separate production renderer owner")
    if studio.candidate_world!=null:
        var common=0
        for path in studio.candidate_world.textures:
            if old_world.textures.has(path) and studio.candidate_world.textures[path]==old_world.textures[path]:common+=1
        check(common>0,"Seek shares immutable already uploaded textures")
        check(not is_same(studio.candidate_world.media_warmup.resident,old_world.media_warmup.resident) and studio.candidate_world.media_warmup.budget_bytes==0,"Candidate owns independent residency and no optional preload budget")
        studio.world.camera.size=14;studio.world.camera_focus+=Vector3(.1,0,.1);studio.world.position_camera()
        studio.world.grid_visible=false;studio.world.wall_mode="hidden";studio.world.update_wall_visibility()
    if not await wait_ready(studio):await finish(studio);return
    check(studio.world!=old_world and is_equal_approx(studio.world.timeline.display_ms,target),"Prepared target clock and host publish together")
    check(studio.world.camera.size==14 and not studio.world.grid_visible and studio.world.wall_mode=="hidden","Pending camera/grid/wall input survives candidate publication")
    check(studio.world.media_warmup.budget_bytes>0,"Published owner restores configured optional budget")
    await capture(studio,"1920-seek")
    # Restore a useful inspection zoom after proving pending user view changes.
    studio.world.camera.size=6;studio.world.position_camera()
    var committed=studio.world
    studio._seek(studio.index.duration_ms*.7);studio._seek(studio.index.duration_ms*.2)
    if not await wait_ready(studio):await finish(studio);return
    check(studio.world!=committed and is_equal_approx(studio.world.timeline.display_ms,studio.index.duration_ms*.2),"Rapid seeks publish only the latest requested target")
    var stable=studio.world
    var stable_index=studio.index
    studio._load("res://.runtime/studio-cases/not-a-recording")
    var until=Time.get_ticks_msec()+10000
    while studio.loader!=null and Time.get_ticks_msec()<until:await process_frame
    check(studio.world==stable and is_same(studio.index,stable_index) and "rejected" in studio.status.text.to_lower(),"Failed recording retains prior complete scene and index")
    var previous_cache=studio.world.catalog_cache
    studio._load(studio.active_directory)
    if not await wait_ready(studio):await finish(studio);return
    check(studio.world!=stable and not is_same(studio.world.catalog_cache,previous_cache) and not is_same(studio.index,stable_index),"Authoring reload publishes fresh renderer/cache/index generation")
    check(studio.world.presentation_errors.is_empty(),"Actual production preview has no presentation errors")
    DisplayServer.window_set_size(Vector2i(1280,720));await process_frame;await process_frame
    await capture(studio,"1280-reloaded")
    var effects=studio.index.rows.filter(func(row):return row.kind=="native_effect" and "surge" in row.label.to_lower())
    check(not effects.is_empty(),"Actual Action Surge native source is available for timeline inspection")
    if not effects.is_empty():
        var effect: Dictionary=effects[0]
        studio.tracks.filter="surge";studio.tracks.rebuild_rows()
        studio.tracks.pixels_per_second=200
        studio.tracks.origin_ms=maxf(0,effect.start_ms-300)
        studio._seek(effect.start_ms+minf(350,(effect.end_ms-effect.start_ms)*.4))
        if await wait_ready(studio):
            await capture(studio,"1280-action-surge-components")
            await diagnostic_controls(studio,effect)
            var audio=studio.tracks.rows.filter(func(item):return item.row.kind=="audio")
            check(not audio.is_empty(),"Action Surge inspection exposes the real decoded audio cue")
            if not audio.is_empty():
                var row:Dictionary=audio[0].row
                var key=studio.tracks.thumbnails.request(row,(row.start_ms+row.end_ms)*.5,studio.world.quarter)
                var waveform_deadline=Time.get_ticks_msec()+10000
                while not studio.tracks.thumbnails.textures.has(key) and Time.get_ticks_msec()<waveform_deadline:await process_frame
                check(studio.tracks.thumbnails.textures.has(key),"Actual decoded waveform publishes as a timeline texture")
                await audio_output(studio,row)
    await finish(studio)
func diagnostic_controls(studio:Control,effect:Dictionary)->void:
    var state=studio.world.timeline.state.duplicate(true)
    var clock=studio.world.timeline.display_ms
    var event_log=studio.world.timeline.event_log().duplicate(true)
    var id:String=effect.component.id
    studio.selected_row=studio.index.rows.filter(func(row):return row.kind=="body")[0]
    studio._menu_selected(7)
    check(studio.world.presentation_mutes.is_empty(),"Body and semantic rows cannot mute authoritative pose or state")
    studio.selected_row=effect;studio._diagnostic_menu_state()
    check(not studio.diagnostic_menu.is_item_disabled(7),"Selected effect exposes presentation-only mute")
    check(studio.world.component_renderer.handles.has(id),"Selected native occurrence exists before diagnostic mute")
    studio._menu_selected(7);await process_frame;await process_frame
    check(not studio.world.component_renderer.handles.has(id),"Mute removes only selected native presentation handle")
    studio._menu_selected(8);studio._menu_selected(7)
    var solo_deadline=Time.get_ticks_msec()+15000
    while (not studio.world.component_renderer.handles.has(id) or not studio.world.component_renderer.ready) and Time.get_ticks_msec()<solo_deadline:await process_frame
    check(studio.world.presentation_solo.has(id) and studio.world.component_renderer.handles.keys()==[id],"Solo shows the exact native occurrence while preserving body/world context")
    studio._menu_selected(9)
    var deadline=Time.get_ticks_msec()+15000
    while (not studio.world.component_renderer.handles.has(id) or not studio.world.component_renderer.ready) and Time.get_ticks_msec()<deadline:await process_frame
    check(studio.world.component_renderer.handles.has(id) and studio.world.component_renderer.ready,"Clearing diagnostics restores the native occurrence at held display time")
    check(studio.world.timeline.state==state and studio.world.timeline.display_ms==clock and studio.world.timeline.event_log()==event_log,"Mute and solo never change canonical state, event log or clock")

func audio_output(studio:Control,row:Dictionary)->void:
    var bus=AudioServer.get_bus_index(row.component.bus)
    check(bus>=0,"Actual selected cue uses an existing native audio bus")
    if bus<0:return
    var probe=AudioEffectCapture.new();probe.buffer_length=8.0
    var record=AudioEffectRecord.new()
    var first=AudioServer.get_bus_effect_count(bus)
    AudioServer.add_bus_effect(bus,probe);AudioServer.add_bus_effect(bus,record)
    studio._seek(maxf(0,row.start_ms-100))
    if not await wait_ready(studio):
        AudioServer.remove_bus_effect(bus,first+1);AudioServer.remove_bus_effect(bus,first);return
    # The previous host is already retired; capture actual mixed bus samples.
    # A paused scrub must remain silent, independent of voice-counter values.
    probe.clear_buffer();record.set_recording_active(true)
    var until=Time.get_ticks_msec()+350
    while Time.get_ticks_msec()<until:await process_frame
    record.set_recording_active(false)
    var quiet=probe.get_buffer(probe.get_frames_available())
    var quiet_peak=0.0
    for frame in quiet:quiet_peak=maxf(quiet_peak,maxf(absf(frame.x),absf(frame.y)))
    check(quiet.size()>0 and quiet_peak==0.0,"Paused native seek produces exact silent bus output")
    var silent=record.get_recording()
    if silent!=null:silent.save_to_wav("res://.captures/studio/silent-scrub.wav")
    probe.clear_buffer();record.set_recording_active(true)
    studio._toggle_play()
    var deadline=Time.get_ticks_msec()+15000
    var end=minf(row.end_ms,row.start_ms+900)
    while studio.world.timeline.display_ms<end and Time.get_ticks_msec()<deadline:await process_frame
    studio.world.timeline.paused=true
    record.set_recording_active(false)
    var mixed=probe.get_buffer(probe.get_frames_available())
    var peak=0.0;var squares=0.0
    for frame in mixed:
        peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)));squares+=frame.x*frame.x+frame.y*frame.y
    var rms=sqrt(squares/maxi(1,mixed.size()*2))
    check(studio.world.timeline.display_ms>=end,"Actual forward playback crosses the selected cue interval")
    check(mixed.size()>0 and peak>0.000001,"Actual native3D cue produces nonzero mixed output through Studio listener")
    var output=record.get_recording()
    if output!=null:output.save_to_wav("res://.captures/studio/action-surge-output.wav")
    evidence.append({"audio_clip":row.component.clip,"output":".captures/studio/action-surge-output.wav","frames":mixed.size(),"peak":peak,"rms":rms,"silent_frames":quiet.size(),"silent_peak":quiet_peak,"display_ms":studio.world.timeline.display_ms})
    AudioServer.remove_bus_effect(bus,first+1);AudioServer.remove_bus_effect(bus,first)

func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual SDK Studio production preview, atomic seek/reload/view settings and native layout; actual mixed audio/silent scrub output; complete component appearance separately qualified"}
    FileAccess.open("res://generated/studio_ui_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_UI ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
