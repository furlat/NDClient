extends SceneTree
const Studio=preload("res://studio/studio.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Media=preload("res://presentation/media_warmup.gd")
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
    # Current visible demand owns usable cells. Unrelated background prewarm
    # and parked batches are neither completion nor failure of that demand.
    await process_frame
    var previews:Dictionary=studio.tracks.prepare_visible()
    while not previews.settled and Time.get_ticks_msec()<deadline:
        await process_frame
        previews=studio.tracks.prepare_visible()
    check(previews.settled and previews.errors.is_empty(),"Actual visible source previews complete without source errors "+name+": "+str(previews.errors))
    await RenderingServer.frame_post_draw
    check(studio.world.light_table!=null and studio.world.entries.size()>0,"Published renderer retains its light table and original draw entries "+name)
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
    var record:Dictionary=Fixtures.public_case("action-surge")
    var requested:String=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):requested=arg.trim_prefix("--recording=")
    check(record.journals.values().has(requested),"Native UI input is one exact independent original in the declared Action Surge case")
    if not record.journals.values().has(requested):await finish(studio);return
    studio.case_records.append(record);studio._load(requested)
    if not await wait_ready(studio):await finish(studio);return
    check(studio.case_bundle.perspectives.any(func(view):return view.id=="blue"),"Actual selected case retains its independent Blue observer recording")
    check(studio.index.rows.any(func(row):return row.kind=="audio"),"Timeline exposes actual compiled audio rows")
    check(studio.index.rows.any(func(row):return row.kind=="native_effect"),"Timeline exposes actual compiled native source rows")
    check(studio.preview.size.y>=200 and studio.tracks.size.y>100,"1280 layout retains usable preview and tracks")
    check(studio.size.x<=1280 and studio.clock_label.get_global_rect().end.x<=1280,"1280 transport and clock fit viewport")
    check(not studio.tracks.show_metadata and studio.tracks.rows.size()<studio.index.rows.size(),"Default workspace hides metadata rows while retaining the complete index")
    check(studio.tracks.rows.any(func(item):return item.row.kind=="body"),"First meaningful occurrence opens its actual Body lane")
    var displayed:Dictionary={}
    for item in studio.tracks.rows:displayed[item.row.id]=true
    var metadata:Array=studio.index.rows.filter(func(row):return row.kind=="event" \
        and row.event.kind in ["turn","sensory","spatial","damage","actor_change"] and not displayed.has(row.id))
    check(not metadata.is_empty(),"Actual original retains an accounting/event row outside the compact projection")
    var full_index:Dictionary=studio.index
    studio._menu_selected(6)
    if not metadata.is_empty():studio.tracks.reveal(metadata[0].id)
    check(studio.tracks.show_metadata and not metadata.is_empty() \
        and studio.tracks.rows.any(func(item):return item.row.id==metadata[0].id) and is_same(studio.index,full_index),
        "Metadata reveals the exact original row while preserving the complete index")
    studio._menu_selected(6)
    var body_rows:Array=studio.index.rows.filter(func(row):return row.kind=="body")
    if not body_rows.is_empty():studio.tracks.reveal(body_rows[0].id)
    studio._show_coverage()
    check("Condition catalog" in studio.inspector_text.text and "implementation" in studio.inspector_text.text and "native qualification separate" in studio.inspector_text.text,"On-demand coverage distinguishes mechanism, source and recorded evidence")
    studio.inspector.hide()
    await capture(studio,"1280-initial")
    check(studio.tracks.thumbnails.textures.values().any(func(texture):return texture.get_image().get_used_rect().has_area()),"Visible body/source thumbnails contain real sampled pixels")
    var layers:Array=studio.index.rows.filter(func(row):return row.kind=="sprite_layer")
    check(not layers.is_empty(),"Actual original retains its authored slash source")
    if layers.is_empty():await finish(studio);return
    var layer:Dictionary=layers[0]
    var layer_key=studio.tracks.thumbnails.request(layer,(layer.start_ms+layer.end_ms)*.5,studio.world.quarter)
    var layer_deadline=Time.get_ticks_msec()+10000
    while not studio.tracks.thumbnails.textures.has(layer_key) and Time.get_ticks_msec()<layer_deadline:await process_frame
    check(studio.tracks.thumbnails.textures.has(layer_key) and studio.tracks.thumbnails.textures[layer_key].get_image().get_used_rect().has_area(),"Short actual slash clip has a visible source midpoint thumbnail")
    check(studio.world.camera.size==6,"Small recording initial view resolves actor silhouettes at useful scale")
    var listener:AudioListener3D=studio.world.get_node_or_null("StudioAudioListener")
    check(listener!=null and listener.is_current() and listener.get_parent()==studio.world \
        and listener.position==studio.world.camera_focus+Vector3.UP and studio.viewport.audio_listener_enable_3d,
        "Displayed Play host owns the active native3D listener at its actual independent listening position")
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
        var candidate:Dictionary=studio.candidate_world.media_warmup
        var previous:Dictionary=old_world.media_warmup
        check(is_same(Media.physical(candidate),Media.physical(previous)) \
            and candidate.consumer_id!=previous.consumer_id and not is_same(candidate.ready_paths,previous.ready_paths) \
            and not is_same(candidate.boot_paths,previous.boot_paths) and not is_same(candidate.wanted,previous.wanted),
            "Same-source seek shares immutable residency while retaining private readiness, boot and demand ownership")
        check(candidate.budget_bytes==studio.candidate_budget \
            and is_same(studio.candidate_world.preparation_admission,old_world.preparation_admission),
            "Pending host preserves the configured source budget and the shared frame preparation allowance")
        studio.world.camera.size=14/.9
        var zoom=InputEventMouseButton.new();zoom.button_index=MOUSE_BUTTON_WHEEL_UP;zoom.pressed=true
        studio._preview_input(zoom)
        check(not studio.automatic_view and not studio.candidate_automatic_view,"Actual wheel input latches manual framing for displayed and pending owners")
        var focus:Vector3=studio.world.camera_focus
        var pan=InputEventMouseMotion.new();pan.button_mask=MOUSE_BUTTON_MASK_MIDDLE;pan.relative=Vector2(8,-3)
        studio._preview_input(pan)
        check(studio.world.camera_focus!=focus and not studio.automatic_view and not studio.candidate_automatic_view,
            "Actual middle-pan changes the chosen frame and keeps both pending/current owners manual")
        studio.world.grid_visible=false;studio.world.wall_mode="hidden";studio.world.update_wall_visibility()
    var chosen_focus:Vector3=studio.world.camera_focus
    if not await wait_ready(studio):await finish(studio);return
    check(studio.world!=old_world and is_equal_approx(studio.world.timeline.display_ms,target),"Prepared target clock and host publish together")
    check(is_equal_approx(studio.world.camera.size,14) and not studio.world.grid_visible and studio.world.wall_mode=="hidden","Pending camera/grid/wall input survives candidate publication")
    check(not studio.automatic_view and studio.world.camera_focus.is_equal_approx(chosen_focus),"Same-index seek publication preserves the exact explicit manual pan")
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
    studio._reload_authoring()
    if not await wait_ready(studio):await finish(studio);return
    check(studio.world!=stable and not is_same(studio.world.catalog_cache,previous_cache) and not is_same(studio.index,stable_index),"Authoring reload publishes fresh renderer/cache/index generation")
    check(studio.world.presentation_errors.is_empty(),"Actual production preview has no presentation errors")
    DisplayServer.window_set_size(Vector2i(1280,720));await process_frame;await process_frame
    await capture(studio,"1280-reloaded")
    var effects=studio.index.rows.filter(func(row):return row.kind=="native_effect" \
        and row.get("component",{}).get("source_id","")=="action.class.fighter.action_surge.native.attached")
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
func visible_effect_ids(studio:Control)->Array:
    var result:Array=[]
    var renderer=studio.world.component_renderer
    for id in renderer.native_spells.handles:
        if renderer.native_spells.handles[id].root.is_visible_in_tree():result.append(id)
    for id in renderer.handles:
        var handle:Dictionary=renderer.handles[id]
        if handle.published and handle.node.is_visible_in_tree():result.append(id)
    return result

func diagnostic_controls(studio:Control,effect:Dictionary)->void:
    var state=studio.world.timeline.state.duplicate(true)
    var clock=studio.world.timeline.display_ms
    var event_log=studio.world.timeline.event_log().duplicate(true)
    var id:String=effect.component.id
    var bodies:Array=studio.index.rows.filter(func(row):return row.kind=="body")
    check(not bodies.is_empty(),"Actual original exposes a body row for the immutable-state diagnostic guard")
    if bodies.is_empty():return
    studio.selected_row=bodies[0]
    studio._menu_selected(7)
    check(studio.world.presentation_mutes.is_empty(),"Body and semantic rows cannot mute authoritative pose or state")
    studio.selected_row=effect;studio._diagnostic_menu_state()
    check(not studio.diagnostic_menu.is_item_disabled(7),"Selected effect exposes presentation-only mute")
    check(effect.component.get("native_spell",false) and studio.world.component_renderer.native_spells.handles.has(id) \
        and id in visible_effect_ids(studio),"Selected Factory occurrence exists in its actual native renderer before diagnostic mute")
    studio._menu_selected(7)
    var mute_deadline=Time.get_ticks_msec()+15000
    while id in visible_effect_ids(studio) and Time.get_ticks_msec()<mute_deadline:await process_frame
    check(not id in visible_effect_ids(studio) and not studio.world.displayed_components.any(func(component):return component.id==id),
        "Mute withdraws the selected visible native occurrence without requiring destruction of parked resources")
    studio._menu_selected(8);studio._menu_selected(7)
    var solo_deadline=Time.get_ticks_msec()+15000
    while (visible_effect_ids(studio)!=[id] or not studio.world.component_renderer.ready) and Time.get_ticks_msec()<solo_deadline:await process_frame
    check(studio.world.presentation_solo.has(id) and visible_effect_ids(studio)==[id],"Solo shows the exact native occurrence while preserving body/world context")
    studio._menu_selected(9)
    var deadline=Time.get_ticks_msec()+15000
    while (not id in visible_effect_ids(studio) or not studio.world.component_renderer.ready) and Time.get_ticks_msec()<deadline:await process_frame
    check(id in visible_effect_ids(studio) and studio.world.component_renderer.ready,"Clearing diagnostics restores the native occurrence at held display time")
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
