extends SceneTree
## Three real batch families through the Studio Library and timeline controls.
## Whole-batch source pixels and canonical parity have their own finite tests.
const Studio=preload("res://studio/studio.gd")
const Thumbnails=preload("res://studio/thumbnail_cache.gd")
const Recording=preload("res://studio/recording.gd")
const CAPTURES="res://.captures/native-spell-library"
const CASES=[
    {"spell":"spell.fireball","case":"spell.fireball/baseline","role":"area","condition_phase":""},
    {"spell":"spell.mage_armor","case":"spell.mage_armor/studio_uuid_lifecycle","role":"attached","condition_phase":"condition"},
    {"spell":"spell.shield","case":"spell.shield/studio_uuid_lifecycle","role":"attached","condition_phase":"condition"}]
var studio:Control
var checks:int=0
var failures:Array=[]
var observations:Array=[]
var only:String=""
var preview_measurements:Dictionary={}
var selection_measurements:Dictionary={}
var pending_selection:Dictionary={}

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("SPELL_LIBRARY_FAIL ",label)

func frame()->void:
    await process_frame;await RenderingServer.frame_post_draw

func settle(label:String,case_id:String="")->bool:
    print("SPELL_LIBRARY_WAIT ",label)
    var deadline:int=Time.get_ticks_msec()+120000
    var diagnostic_at:int=Time.get_ticks_msec()+10000
    while Time.get_ticks_msec()<deadline:
        if not pending_selection.is_empty() and studio.candidate_world!=null:
            var elapsed:float=(Time.get_ticks_usec()-pending_selection.requested_usec)/1000.0
            if not pending_selection.has("candidate_observed_ms"):pending_selection.candidate_observed_ms=elapsed
            if not pending_selection.has("world_ready_observed_ms") and studio.candidate_world.playback_prepared() and not studio.candidate_world.rotation_pending():
                pending_selection.world_ready_observed_ms=elapsed
        var selected:bool=case_id.is_empty() or studio.active_case.get("id")==case_id
        if selected and not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and studio.pending_directory.is_empty() and studio.world.playback_prepared():
            studio.world.timeline.paused=true
            if not case_id.is_empty() and not pending_selection.is_empty():
                var timing:Dictionary=pending_selection.duplicate(true)
                timing.publication_observed_ms=(Time.get_ticks_usec()-timing.requested_usec)/1000.0
                for measure in studio.transport_measurements:
                    if int(measure.get("requested_usec",0))<int(timing.requested_usec):continue
                    timing.transport=measure.duplicate(true)
                    timing.publication_ms=(float(measure.requested_usec)+float(measure.publish_ms)*1000.0-timing.requested_usec)/1000.0
                    if measure.has("ready_ms"):
                        timing.all_sources_ready_ms=(float(measure.created_usec)+float(measure.ready_ms)*1000.0-timing.requested_usec)/1000.0
                    break
                timing.native_store_hits=studio.tracks.thumbnails.native_store.hits
                timing.native_store_misses=studio.tracks.thumbnails.native_store.misses
                timing.native_disk_loads=studio.tracks.thumbnails.native_store.disk_loads
                timing.native_descriptor_ms=studio.tracks.thumbnails.native_store.descriptor_usec/1000.0
                timing.native_resource_load_ms=studio.tracks.thumbnails.native_store.resource_load_usec/1000.0
                timing.native_jobs_at_publication=studio.tracks.thumbnails.native_composites.size()
                timing.initial_preview_samples=studio.tracks.preview_demand.size()
                timing.within_200ms=timing.get("publication_ms",timing.publication_observed_ms)<=200.0
                selection_measurements[case_id]=timing;pending_selection={}
            await frame()
            if not studio.world.playback_prepared() or studio.installing or studio.requested_seek>=0 or not studio.pending_directory.is_empty():continue
            if not case_id.is_empty() and studio.active_case.get("id")!=case_id:continue
            if selection_measurements.has(case_id):
                selection_measurements[case_id].first_draw_observed_ms=(Time.get_ticks_usec()-selection_measurements[case_id].requested_usec)/1000.0
            check(studio.world.presentation_errors.is_empty(),label+": active world has no presentation errors")
            check(studio.replay_diagnostics().panes.size()==1,"Studio renders only the selected recorded faction")
            return true
        await process_frame
        if Time.get_ticks_msec()>=diagnostic_at:
            diagnostic_at=Time.get_ticks_msec()+10000
            print("SPELL_LIBRARY_PENDING ",JSON.stringify({"stage":label,"case":studio.active_case.get("id",""),"loading":studio.loader!=null,"seeking":studio.seeker!=null,"installing":studio.installing,"requested_seek":studio.requested_seek,"media_issue":studio.world.media_issue,"world_errors":studio.world.presentation_errors,"pending_directory":studio.pending_directory}))
    check(false,label+": Studio publishes within the finite readiness budget; "+studio.status.text)
    return false

func find_item(item:TreeItem,id:String)->TreeItem:
    if item==null:return null
    var data=item.get_metadata(0)
    if data is Dictionary and data.get("case",{}).get("id","")==id:return item
    for child in item.get_children():
        var found=find_item(child,id)
        if found!=null:return found
    return null

func open_case(spec:Dictionary)->bool:
    var spell:String=spec.spell
    studio.loop_enabled=false;studio.loop_button.set_pressed_no_signal(false)
    studio._show_study_library()
    var panel:Window=studio.study_library
    # open() returns while its exact generation is still building. Native
    # pointer/preview controls consume only fully published current Tree rows.
    var catalog_deadline:int=Time.get_ticks_msec()+120000
    while not panel.is_prepared() and panel.error.is_empty() and Time.get_ticks_msec()<catalog_deadline:await process_frame
    check(panel.visible and panel.is_prepared() and not panel.report.get("entries",[]).is_empty(),spell+": actual capability Library has its current catalog; "+panel.error)
    if not panel.visible or not panel.is_prepared() or panel.report.get("entries",[]).is_empty():return false
    var id:String=spec.case
    var item:TreeItem=find_item(panel.tree.get_root(),id)
    check(item!=null,spell+": Library contains the exact recorded scenario")
    if item==null:return false
    var parent:TreeItem=item.get_parent()
    while parent!=null:parent.collapsed=false;parent=parent.get_parent()
    panel.tree.scroll_to_item(item,true);await process_frame
    var rect:Rect2=panel.tree.get_item_area_rect(item,0)
    var local:Vector2=rect.position+Vector2(minf(65,rect.size.x*.5),rect.size.y*.5)
    var geometry_deadline:int=Time.get_ticks_msec()+2000
    while panel.tree.get_item_at_position(local)!=item and Time.get_ticks_msec()<geometry_deadline:
        await process_frame;rect=panel.tree.get_item_area_rect(item,0)
        local=rect.position+Vector2(minf(65,rect.size.x*.5),rect.size.y*.5)
    check(panel.tree.get_item_at_position(local)==item,spell+": pointer geometry identifies this exact current Library original")
    var at:Vector2=panel.tree.global_position+local
    pending_selection={"case":id,"requested_usec":Time.get_ticks_usec(),"measurement":"Actual Library row pointer press to shared Studio publication in this fresh test process"}
    var delivered:Dictionary={"case":""}
    var observe:Callable=func(_capability:Dictionary,_scenario:Dictionary,record:Dictionary):delivered.case=str(record.get("id",""))
    panel.recording_selected.connect(observe)
    for pressed in [true,false]:
        var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=at;event.global_position=at
        panel.push_input(event,true)
    await process_frame
    panel.recording_selected.disconnect(observe)
    check(delivered.case==id,spell+": actual native Tree pointer emits the exact selected original recording")
    check(not panel.visible,spell+": selecting the actual recorded row closes Library")
    if not await settle(spell+" Library navigation",id):return false
    check(studio.study_capability.get("id")==spell and studio.study_scenario.get("id")==id,spell+": displayed study keeps its exact spell association")
    check(studio.active_directory==studio.active_case.perspectives[0].journal and studio.index.directory==studio.active_directory and studio.tracks.index.directory==studio.active_directory,spell+": world, timeline and original Amber journal publish together")
    return true

func prepare_previews(label:String)->bool:
    print("SPELL_LIBRARY_WAIT ",label," source previews")
    var started:int=Time.get_ticks_msec()
    var deadline:int=Time.get_ticks_msec()+120000
    var diagnostic_at:int=Time.get_ticks_msec()+10000
    var peak:int=0;var private_worlds:bool=true;var exact_steps:bool=true;var ages:Dictionary={}
    var state:Dictionary=studio.tracks.prepare_visible(true)
    var composed_contexts:int=0;var exact_context:bool=true
    while not state.ready and state.errors.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame;state=studio.tracks.prepare_visible(true)
        var worlds:Dictionary={}
        peak=maxi(peak,studio.tracks.thumbnails.native_composites.size())
        var cache:RefCounted=studio.tracks.thumbnails
        if not cache.composed_active.is_empty() and not cache.composed_pane.is_empty():
            var owner:Node3D=cache.composed_pane.world
            private_worlds=private_worlds and owner.get_world_3d()!=studio.world.get_world_3d() and cache.composed_pane.viewport.own_world_3d
            if owner.playback_prepared() and not owner.rotation_pending():
                var job:Dictionary=cache.composed_active.job
                composed_contexts+=1
                exact_context=(exact_context and is_same(job.recording,studio.index) and owner.timeline.display_ms==job.sample_ms
                    and owner.quarter==job.quarter and owner.timeline.paused and not owner.component_renderer.audio.enabled)
        for composite in studio.tracks.thumbnails.native_composites:
            var node= composite.node
            var source_world:World3D=node.camera.get_world_3d()
            private_worlds=private_worlds and source_world!=null
            if source_world!=null:
                var world_id:int=source_world.get_instance_id()
                private_worlds=private_worlds and not worlds.has(world_id);worlds[world_id]=true
            if not composite.job.component.get("persistent_owner",false) and ages.has(composite.job.key):
                exact_steps=exact_steps and node.sampled-ages[composite.job.key]<=1.0/60.0+.00001
            if node.sampled>=0:ages[composite.job.key]=node.sampled
        if Time.get_ticks_msec()>=diagnostic_at:
            diagnostic_at=Time.get_ticks_msec()+10000
            var active:Dictionary=studio.tracks.thumbnails.native_composites[0] if not studio.tracks.thumbnails.native_composites.is_empty() else studio.tracks.thumbnails.active
            var details:Dictionary={"stage":label,"pending":state.pending,"samples":state.samples,"errors":state.errors,"batch":studio.tracks.thumbnails.native_composites.size(),"active_kind":active.get("kind",""),"active_key":active.get("job",{}).get("key",""),"target_ms":active.get("job",{}).get("native_age_ms",0),"draws":active.get("draws",0),"suspended":studio.tracks.thumbnails.suspended}
            if active.get("kind")=="native_effect" and active.job.component.get("native_spell",false):
                details.sampled=active.node.sampled;details.drawn=active.node.drawn;details.source_age=active.node.handle.get("age",-1)
            details.composed_worker=studio.tracks.thumbnails.composed_worker!=null
            details.composed_job=studio.tracks.thumbnails.composed_active.get("job",{}).get("key","")
            print("SPELL_LIBRARY_PREVIEWS ",JSON.stringify(details))
    check(state.ready and state.pending==0 and state.errors.is_empty(),label+": visible timeline source previews complete: "+str(state.errors))
    check(peak<=Thumbnails.NATIVE_BATCH_LIMIT and private_worlds,label+": bounded native previews use independent world owners")
    check(exact_steps,label+": isolated source batching never skips a native60Hz history step")
    check(exact_context,label+": composed samples retain the exact recording/cut/quarter and muted private production owner")
    preview_measurements[label]={"elapsed_ms":Time.get_ticks_msec()-started,"samples":state.samples,"peak_native_previews":peak,
        "composed_context_observations":composed_contexts,"composed_scope":"Exact recorded full context, not isolated source pixels",
        "native_store_hits":studio.tracks.thumbnails.native_store.hits,"native_store_misses":studio.tracks.thumbnails.native_store.misses,
        "native_disk_loads":studio.tracks.thumbnails.native_store.disk_loads,
        "native_descriptor_ms":studio.tracks.thumbnails.native_store.descriptor_usec/1000.0,
        "native_resource_load_ms":studio.tracks.thumbnails.native_store.resource_load_usec/1000.0,
        "native_store_issues":studio.tracks.thumbnails.native_store.issues.duplicate(true)}
    await frame()
    return state.ready and state.pending==0 and state.errors.is_empty()

func row_y(row:Dictionary)->float:
    var y:float=studio.tracks.RULER-studio.tracks.published_layout.get("scroll_y",0.0)
    for item in studio.tracks.published_layout.get("rows",[]):
        var height:float=studio.tracks._height(item.row)
        if item.row.id==row.id:return y+height*.5
        y+=height
    return -1.0

func click_phase(row:Dictionary,at_ms:float,play_clip:bool=false)->void:
    var x:float=studio.tracks._x(at_ms,studio.tracks.published_layout)
    if play_clip:x=studio.tracks.published_layout.gutter-16.0
    var y:float=row_y(row)
    check(y>=studio.tracks.RULER and y<studio.tracks.size.y,"Native phase is visible before the timeline pointer selection")
    if y<studio.tracks.RULER or y>=studio.tracks.size.y:return
    var at:Vector2=studio.tracks.global_position+Vector2(x,y)
    for pressed in [true,false]:
        var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=at;event.global_position=at
        root.push_input(event,true)
    await process_frame

func source_pixels(row:Dictionary,spell:String)->Dictionary:
    var count:int=0;var coloured:int=0
    for cell_key in studio.tracks.preview_keys:
        if not str(cell_key).begins_with(str(row.id)+":"):continue
        var key:String=studio.tracks.preview_keys[cell_key]
        if not studio.tracks.thumbnails.textures.has(key):continue
        var image:Image=studio.tracks.thumbnails.textures[key].get_image()
        if image==null:continue
        image.convert(Image.FORMAT_RGBA8)
        var bytes:PackedByteArray=image.get_data()
        var pixels:int=0
        for i in range(0,bytes.size(),4):
            # The native additive source can carry RGB at zero alpha.
            if maxi(bytes[i],maxi(bytes[i+1],bytes[i+2]))>1:pixels+=1
        if pixels>0:
            if count==0:image.save_png(CAPTURES+"/"+spell+"-selected-source.png")
            count+=1;coloured+=pixels
    var composed:bool=Thumbnails._composed_row(row)
    check(count>0 and coloured>0,spell+": selected native row has actual nonblank "+("recorded-context" if composed else "isolated source")+" previews")
    return {"textures":count,"rgb_pixels":coloured,"scope":"recorded_composed_context" if composed else "isolated_source",
        "note":"Scene pixels are not isolated-effect evidence" if composed else "Exact source swatch"}

func active_phase(row:Dictionary,label:String)->void:
    var native=studio.world.component_renderer.native_spells
    var active:Array=studio.world.displayed_components.filter(func(sample):return sample.id==row.component.id and sample.get("native_spell",false))
    check(active.size()==1,label+": the selected event/condition occurrence is active")
    check(native.handles.has(row.component.id),label+": production owns the selected native source")
    if native.handles.has(row.component.id):
        var handle:Dictionary=native.handles[row.component.id]
        check(handle.root.is_visible_in_tree() and handle.rendered_once,label+": occurrence is submitted and has completed a native draw")

func inspect_case(spec:Dictionary)->void:
    var spell:String=spec.spell
    if not await open_case(spec):return
    var rows:Array=studio.index.rows.filter(func(row):return row.kind=="native_effect" and row.get("visible_here",true) and row.get("component",{}).get("native_spell",false) and row.component.get("spell_id")==spell.trim_prefix("spell.") and row.component.native_cue.role==spec.role and row.get("condition_phase","")==spec.condition_phase and row.end_ms>row.start_ms)
    check(not rows.is_empty(),spell+": actual index exposes the requested native family")
    if rows.is_empty():return
    var row:Dictionary=rows[0]
    var at:float=(float(row.start_ms)+float(row.end_ms))*.5
    studio.tracks.reveal(row.id)
    if not await prepare_previews(spell):return
    await click_phase(row,at)
    if not await settle(spell+" phase selection"):return
    check(studio.selected_row.get("id")==row.id,spell+": timeline pointer selects the actual native phase")
    active_phase(row,spell+" selected")
    var pixels:Dictionary=source_pixels(row,spell)
    await frame();root.get_texture().get_image().save_png(CAPTURES+"/"+spell+"-studio.png")
    studio._seek(0)
    if not await settle(spell+" reverse"):return
    check(studio.world.displayed_components.all(func(sample):return not sample.get("native_spell",false)),spell+": reverse seek to initialization publishes no later native source")
    studio._seek(at)
    if not await settle(spell+" reseek"):return
    active_phase(row,spell+" reseek")
    # The actual gutter click invokes Studio's selected-clip loop. A prepared
    # hidden replay must only replace the visible prefix at its Out boundary.
    await click_phase(row,at,true)
    var expected_in:float=maxf(0.0,float(row.start_ms)-Recording.PREVIEW_LEAD_IN_MS)
    var expected_out:float=minf(float(studio.index.presentation_end_ms),float(row.end_ms)+Recording.PREVIEW_OPERATION_GAP_MS)
    check(studio.loop_enabled and studio.loop_start==expected_in and studio.loop_end==expected_out,
        spell+": native clip control retains exact source timing plus ordinary admission/restoration context")
    var deadline:int=Time.get_ticks_msec()+120000
    var previous:float=studio.world.timeline.display_ms
    var entered:bool=false;var wrapped:bool=false;var maximum:float=-1.0
    while Time.get_ticks_msec()<deadline and not wrapped:
        await process_frame
        var now:float=studio.world.timeline.display_ms
        if now>float(row.start_ms)+minf(10.0,(row.end_ms-row.start_ms)*.1):entered=true;maximum=maxf(maximum,now)
        if entered and now+0.001<previous and previous>=expected_out-0.01:wrapped=true
        previous=now
    check(wrapped,spell+": shared display clock crosses the actual loop Out and returns to In")
    studio.loop_enabled=false;studio.loop_button.set_pressed_no_signal(false);studio.world.timeline.paused=true
    await process_frame
    studio._seek(at)
    if await settle(spell+" after loop"):active_phase(row,spell+" after loop")
    observations.append({"spell":spell,"case":studio.active_case.id,"journal":studio.active_directory,"row":row.id,"condition_phase":row.get("condition_phase",""),"source":row.component.native_clip.id,"at_ms":at,"source_start_ms":row.start_ms,"source_end_ms":row.end_ms,"loop_start_ms":expected_in,"loop_end_ms":expected_out,"loop_wrapped":wrapped,"maximum_observed_ms":maximum,"previews":pixels,"preview_preparation":preview_measurements.get(spell,{}),"library_selection":selection_measurements.get(studio.active_case.id,{}),"paired":false})
    print("SPELL_LIBRARY_CASE ",JSON.stringify(observations.back()))
    await cancel_previews(row,at)

func cancel_previews(row:Dictionary,at:float)->void:
    var cache=Thumbnails.new();cache.host=root;cache.cache=Thumbnails.Catalog.source_snapshot(studio.index.cache)
    cache.recording=studio.index;cache.reference_world=studio.world;cache.set_displayed_world(studio.world)
    var keys:Dictionary={}
    for quarter in 4:keys[cache.request(row,at,quarter,false)]=true
    cache.set_demand(keys);cache.poll();await frame();cache.poll()
    var composed:bool=Thumbnails._composed_row(row)
    check(keys.size()==4 and keys.keys().all(func(key):return cache.requested.has(key) or cache.textures.has(key) or cache.baked_requests.has(key)),
        "All four exact requested views retain their current queued, active or published ownership")
    if composed:
        check(cache.native_composites.is_empty() and cache.native_store.hits==0 and cache.errors.is_empty(),
            "Input-bearing recorded views use the production composed path, never isolated baked-source substitution")
        check(cache.pending.all(func(job):return job.composed and is_same(job.recording,studio.index) and job.component.id==row.component.id and job.sample_ms==at),
            "Queued composed views retain this actual recording, occurrence and sample")
    else:
        check(cache.native_composites.size()+cache.textures.size()+cache.baked_requests.size()+cache.pending.size()==4,
            "Source-only views retain exact baked Resources or bounded isolated jobs")
    var nodes:Array=cache.native_composites.map(func(value):return value.node)
    if not cache.composed_pane.is_empty():nodes.append(cache.composed_pane.viewport)
    var ages:Array=cache.native_composites.map(func(value):return value.node.sampled)
    var published:Array=cache.textures.keys()
    var recorded_at:float=cache.composed_pane.world.timeline.display_ms if not cache.composed_pane.is_empty() else -1.0
    cache.suspended=true
    for _i in 3:await frame();cache.poll()
    check(ages==cache.native_composites.map(func(value):return value.node.sampled) and (not composed or cache.textures.keys()==published),
        "Suspended previews neither advance isolated history nor publish a composed restore")
    if recorded_at>=0.0:check(cache.composed_pane.world.timeline.display_ms==recorded_at,"Suspension preserves the exact restored source clock")
    cache.reset();await frame()
    check(cache.native_composites.is_empty() and cache.composed_active.is_empty() and cache.composed_pane.is_empty()
        and cache.textures.is_empty() and cache.requested.is_empty() and nodes.all(func(node):return not is_instance_valid(node)),
        "Reset retires private source/pane owners and forbids old-generation publication")
    cache.close()

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.gui_embed_subwindows=true
    root.size=Vector2i(1280,720)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=60
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--only="):only=argument.trim_prefix("--only=")
    DirAccess.make_dir_recursive_absolute(CAPTURES)
    studio=Studio.new();root.add_child(studio);studio.loop_enabled=false
    if await settle("initial Studio"):
        for spec in CASES:
            if only.is_empty() or spec.spell==only or spec.spell.trim_prefix("spell.")==only:await inspect_case(spec)
    await finish()

func finish()->void:
    var requested:Array=CASES.filter(func(spec):return only.is_empty() or spec.spell==only or spec.spell.trim_prefix("spell.")==only)
    check(not requested.is_empty() and observations.size()==requested.size(),"Every requested case reaches its final native UI and loop assertions")
    studio.queue_free();await frame();await frame()
    var report={"checks":checks,"failures":failures,"cases":observations,"renderer":RenderingServer.get_current_rendering_method(),
        "scope":"Actual Library and timeline pointer controls for real Fireball, Mage Armor and Shield recordings; exact native phase association, submitted source-preview pixels, reverse/reseek and shared-clock row looping. Whole-batch scene pixels and canonical parity are separate tests."}
    FileAccess.open("res://.runtime/native-spell-library-checks"+("-"+only if not only.is_empty() else "")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPELL_LIBRARY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
