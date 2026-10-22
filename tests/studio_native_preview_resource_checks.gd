extends SceneTree
## Actual composed previews and eligible source-only disk Resources at the
## Recording -> TimelineView boundary, separate from full Library navigation.
const Library=preload("res://studio/case_library.gd")
const Play=preload("res://play.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Recording=preload("res://studio/recording.gd")
const ReplayPanes=preload("res://studio/replay_panes.gd")
const TimelineView=preload("res://studio/timeline_view.gd")
const Thumbnails=preload("res://studio/thumbnail_cache.gd")
const Store=preload("res://studio/native_preview_store.gd")
const Packet=preload("res://studio/native_preview_resource.gd")
const Baker=preload("res://tools/bake_studio_spell_previews.gd")
const REPORT="res://.runtime/studio-native-preview-resource-checks.json"
var checks:int=0
var failures:Array=[]
var measurements:Array=[]
var observed_sources:Array=[]
var replay_controls:Array=[]
var tracks:Control
var finished:bool=false
var reference:Node3D
var reference_view:SubViewport
var profile_composed:bool=false

class ProfiledThumbnails extends "res://studio/thumbnail_cache.gd":
    # Optional measurement of the real owner. Nested CPU counters are inclusive;
    # timestamps separate worker/readiness/draw waits without another readback.
    var timings:Array=[]
    var measured_job:Dictionary={}
    func _start_composed(job:Dictionary)->void:
        measured_job={"key":job.key,"row":job.row.id,"sample_ms":job.sample_ms,"quarter":job.quarter,
            "start_us":Time.get_ticks_usec(),"start_frame":Engine.get_process_frames(),"cpu_usec":{},"polls":[]}
        timings.append(measured_job)
        super._start_composed(job)
        measured_job.start_return_us=Time.get_ticks_usec()
        measured_job.cpu_usec.start=measured_job.start_return_us-measured_job.start_us
    func _prepare_composed(job:Dictionary,restored:RefCounted)->void:
        var started:int=Time.get_ticks_usec()
        super._prepare_composed(job,restored)
        measured_job.prepared_us=Time.get_ticks_usec()
        measured_job.cpu_usec.prepare=measured_job.prepared_us-started
        measured_job.reused=composed_pane.reused
        measured_job.from_ms=restored.display_ms
    func _advance_composed(owner:Node3D,target_ms:float)->bool:
        var started:int=Time.get_ticks_usec()
        var result:bool=super._advance_composed(owner,target_ms)
        measured_job.cpu_usec.advance=measured_job.cpu_usec.get("advance",0)+Time.get_ticks_usec()-started
        if result and not measured_job.has("cut_ready_us"):
            measured_job.cut_ready_us=Time.get_ticks_usec()
            measured_job.cut_ready_frame=Engine.get_process_frames()
        return result
    func _poll_composed()->bool:
        if measured_job.is_empty() or (composed_active.is_empty() and composed_worker==null):return super._poll_composed()
        var started:int=Time.get_ticks_usec()
        var drawn:bool=composed_active.get("drawn",false)
        var result:bool=super._poll_composed()
        var ended:int=Time.get_ticks_usec()
        measured_job.cpu_usec.poll=measured_job.cpu_usec.get("poll",0)+ended-started
        if composed_active.has("draw_signature") and not measured_job.has("fence_armed_us"):
            measured_job.fence_armed_us=ended
            measured_job.fence_armed_frame=Engine.get_process_frames()
        measured_job.polls.append({"frame":Engine.get_process_frames(),"start_us":started,"end_us":ended,
            "drawn_before":drawn,"drawn_after":composed_active.get("drawn",false),
            "fence_after":composed_active.has("draw_signature")})
        return result
    func _publish(job:Dictionary,output:Image)->void:
        if not job.get("composed",false):
            super._publish(job,output)
            return
        var started:int=Time.get_ticks_usec()
        measured_job.readback_complete_us=started
        measured_job.readback_size=[output.get_width(),output.get_height()]
        super._publish(job,output)
        measured_job.published_us=Time.get_ticks_usec()
        measured_job.published_frame=Engine.get_process_frames()
        measured_job.cpu_usec.publish=measured_job.published_us-started
    func _finish_composed()->void:
        var started:int=Time.get_ticks_usec()
        super._finish_composed()
        if not measured_job.is_empty():
            measured_job.finished_us=Time.get_ticks_usec()
            measured_job.cpu_usec.finish=measured_job.finished_us-started

func _initialize()->void:
    DisplayServer.window_set_title("NDClient · Fireball thumbnail control · Timeline only")
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,800)
    run.call_deferred()

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_PREVIEW_RESOURCE_FAIL ",label)

func bounded_sources(label:String)->void:
    var cache:RefCounted=tracks.thumbnails
    check(cache.errors.is_empty() and cache.native_store.issues.is_empty(),label+": source and Resource preparation have no errors")
    check(cache.texture_bytes<=cache.texture_limit and cache.native_store.retained_bytes<=Store.MEMORY_LIMIT,
        label+": resident preview caches retain their existing byte budgets")
    check(cache.native_composites.size()<=Thumbnails.NATIVE_BATCH_LIMIT,label+": source-only preparation keeps its existing bounded batch")
    if not cache.composed_pane.is_empty():
        check(cache.composed_pane.viewport.own_world_3d and cache.composed_pane.world.get_world_3d()!=reference.get_world_3d(),
            label+": the single reused composed pane owns its private production world")
        check(cache.composed_pane.world.timeline.paused and not cache.composed_pane.world.component_renderer.audio.enabled,
            label+": composed context uses the recorded sample clock and muted audio")

func bind_recording(index:Dictionary)->void:
    tracks.thumbnails.recording=index;tracks.thumbnails.reference_world=reference
    tracks.thumbnails.set_displayed_world(reference)

func measure(label:String)->Dictionary:
    var cache:RefCounted=tracks.thumbnails
    var first_profile:int=cache.timings.size() if profile_composed else 0
    var before_hits:int=cache.native_store.hits;var before_misses:int=cache.native_store.misses
    var before_loads:int=cache.native_store.disk_loads
    var begin:int=Time.get_ticks_usec()
    var first_frame:int=Engine.get_process_frames()
    # This measurement owns four-view demand. The automatic one-view process
    # would replace its signature and reorder the same pending queue each frame.
    var was_processing:bool=tracks.is_processing()
    tracks.set_process(false)
    var state:Dictionary=tracks.prepare_visible(true)
    var request_cpu_ms:float=float(Time.get_ticks_usec()-begin)/1000.0
    var deadline:int=Time.get_ticks_msec()+120000
    while not state.ready and state.errors.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame;await RenderingServer.frame_post_draw
        # Play/child preparation and the native draw have kept their ordinary
        # callbacks. Use only the existing remainder for this same cache owner.
        if tracks._preparation_available():
            var optional_started:int=Time.get_ticks_usec()
            tracks._prepare_other_rows()
            tracks._charge_preparation(optional_started)
        if tracks._preparation_available():
            var poll_started:int=Time.get_ticks_usec()
            var charged_before:int=tracks.preparation_admission.get("used_usec",0)
            cache.poll()
            tracks._charge_preparation(poll_started,charged_before)
        state=tracks.prepare_visible(true)
    check(state.ready and state.pending==0 and state.errors.is_empty(),label+": actual visible four-view samples complete through their eligible production path")
    bounded_sources(label)
    await process_frame;await RenderingServer.frame_post_draw
    var available_ms:float=float(Time.get_ticks_usec()-begin)/1000.0
    tracks.set_process(was_processing)
    var record={"label":label,"request_cpu_ms":request_cpu_ms,"through_post_draw_ms":available_ms,"samples":state.samples,
        "disk_hits":cache.native_store.hits-before_hits,"disk_misses":cache.native_store.misses-before_misses,
        "disk_loads":cache.native_store.disk_loads-before_loads,"available":state.ready,"target_ms":200.0,
        "within_target":state.ready and available_ms<=200.0,"errors":state.errors,
        "scope":"Stable explicit four-view demand owner with ordinary Play callbacks and shared remaining preparation budget. Input-bearing rows use exact recorded full context; source-only rows retain normal bounded rendering. This is not an ordinary one-view UI timing. Actual disk identity/dependency proof is separate below."}
    if profile_composed:
        record.composed_jobs=cache.timings.slice(first_profile).duplicate(true)
        # Existing passive rings, copied after the measured window. No extra
        # detailed diagnostics, callbacks, or work before cache polling.
        record.frame_range=[first_frame,Engine.get_process_frames()]
        record.reference_frames=reference.profile.frames.filter(func(sample):return sample.frame>=first_frame).duplicate(true)
        record.composed_frames=cache.composed_pane.world.profile.frames.filter(func(sample):return sample.frame>=first_frame).duplicate(true) if not cache.composed_pane.is_empty() else []
    measurements.append(record);print("NATIVE_PREVIEW_RESOURCE_TIME ",JSON.stringify(record))
    check(state.samples>0,label+": the measured timeline actually requests source thumbnails")
    return record

func source_texture(cache:RefCounted,key:String,label:String,row:Dictionary={},sample_ms:float=-1.0,quarter:int=-1)->Texture2D:
    var already_published:bool=cache.textures.has(key)
    var deadline:int=Time.get_ticks_msec()+20000
    while not cache.textures.has(key) and not cache.errors.has(key) and not cache.inactive.has(key) and Time.get_ticks_msec()<deadline:
        await process_frame;cache.poll();await RenderingServer.frame_post_draw
    check(not key.is_empty() and cache.textures.has(key) and not cache.errors.has(key),label+": exact requested source completes: "+str(cache.errors.get(key,cache.inactive.get(key,""))))
    if not already_published and cache.textures.has(key) and not row.is_empty() and Thumbnails._composed_row(row):
        check(not cache.composed_pane.is_empty() and is_same(cache.composed_pane.index,cache.recording),label+": composed source belongs to this exact recorded index")
        if not cache.composed_pane.is_empty():
            var owner:Node3D=cache.composed_pane.world
            var current:Array=owner.displayed_components.filter(func(component):return component.id==row.component.id)
            var status:Dictionary=owner.component_renderer.native_spells.diagnostics.get(row.component.id,{})
            check(current.size()==1 and owner.timeline.display_ms==sample_ms and owner.quarter==quarter and not owner.rotation_pending(),
                label+": full-context image retains the actual source occurrence, sample and published quarter")
            check(status.get("status")=="rendered" and status.get("input_bindings",{}).get("unavailable",{}).is_empty(),
                label+": the actual input-bearing source completes its native draw before context capture")
    return cache.textures.get(key)

func phase_samples(rows:Array)->Dictionary:
    var samples:Dictionary={};var fresh_multi_view_cuts:int=0
    for row in rows:
        for fraction in [.1,.5,.9,1.0]:
            var at:float=row.end_ms-.001 if fraction==1.0 else lerpf(row.start_ms,row.end_ms,fraction)
            var cut:RefCounted;var epoch:int=-1;var canonical:Dictionary={};var fresh_views:int=0
            for quarter in 4:
                var published:Array=tracks.thumbnails.textures.keys()
                var key:String=tracks.thumbnails.request(row,at,quarter,false)
                var texture:Texture2D=await source_texture(tracks.thumbnails,key,str(row.component.native_cue.role)+" actual phase/tail "+str(fraction)+" q"+str(quarter),row,at,quarter)
                if texture!=null:
                    if Thumbnails._composed_row(row) and key not in published:
                        fresh_views+=1
                        var current:RefCounted=tracks.thumbnails.composed_pane.world.timeline
                        if cut==null:
                            cut=current;epoch=current.initialization_revision;canonical=current.state.duplicate(true)
                        else:
                            check(is_same(current,cut) and current.initialization_revision==epoch and current.state==canonical,
                                "Another actual view retains the identical canonical cut and admitted Timeline epoch")
                    samples[key]=texture
                    var pending:int=tracks.thumbnails.pending.size()
                    check(tracks.thumbnails.request(row,at,quarter,false)==key and tracks.thumbnails.pending.size()==pending,
                        "Repeated exact recorded source/sample/view reuses its published image without another job")
            if fresh_views>1:fresh_multi_view_cuts+=1
    check(fresh_multi_view_cuts>0,"At least one exact composed cut publishes multiple fresh view images from its retained Timeline")
    bounded_sources("actual phase/retained-tail coverage")
    return samples

func same_recorded_cut(actual:RefCounted,index:Dictionary,at:float,label:String)->void:
    var fresh:RefCounted=Recording.restore(index,at)
    check(actual.display_ms==fresh.display_ms and actual.sequence==fresh.sequence and actual.state==fresh.state,
        label+": retained replay agrees with fresh canonical state, sequence and absolute clock")
    check(actual.condition_owners==fresh.condition_owners and actual.temporary_hp_owners==fresh.temporary_hp_owners \
        and actual.item_effect_owners==fresh.item_effect_owners and actual.spatial_effect_owners==fresh.spatial_effect_owners \
        and actual.actor_history_cuts==fresh.actor_history_cuts and actual.retained_components==fresh.retained_components \
        and actual.retained_directions==fresh.retained_directions and actual.resolved_impacts==fresh.resolved_impacts,
        label+": actual owner lifetimes, history cuts and retained presentation agree with fresh restore")

func retained_prefix_and_optics(rows:Array,index:Dictionary)->void:
    var composed:Array=rows.filter(func(row):return Thumbnails._composed_row(row))
    check(not composed.is_empty(),"Recorded prefix controls use an actual input-bearing composed row")
    if composed.is_empty():return
    composed.sort_custom(func(a,b):return a.end_ms-a.start_ms>b.end_ms-b.start_ms)
    var row:Dictionary=composed[0]
    var first:float=lerpf(row.start_ms,row.end_ms,.2)
    var later:float=lerpf(row.start_ms,row.end_ms,.7)
    var backward:float=lerpf(row.start_ms,row.end_ms,.4)
    var was_processing:bool=tracks.is_processing()
    tracks.set_process(false);tracks.set_index(index);bind_recording(index)
    var cache:RefCounted=tracks.thumbnails
    var first_key:String=cache.request(row,first,0,false)
    var first_image:Texture2D=await source_texture(cache,first_key,"Retained prefix initial cut",row,first,0)
    if first_image==null:tracks.set_process(was_processing);return
    var initial:RefCounted=cache.composed_pane.world.timeline
    var epoch:int=initial.initialization_revision
    var later_key:String=cache.request(row,later,0,false)
    check(later_key!=first_key,"Later prefix control requests a distinct actual sample bin")
    var later_image:Texture2D=await source_texture(cache,later_key,"Retained prefix later cut",row,later,0)
    if later_image==null:tracks.set_process(was_processing);return
    var advanced:RefCounted=cache.composed_pane.world.timeline
    check(is_same(initial,advanced) and advanced.initialization_revision==epoch,
        "A later cut keeps the same private Timeline and admitted epoch")
    same_recorded_cut(advanced,index,later,"Later composed cut")
    # This independent cache has no parked prefix. Its ordinary cold restore
    # and production draw remain the output oracle for the retained path.
    var cold=Thumbnails.new();cold.host=root;cold.cache=Thumbnails.Catalog.source_snapshot(index.cache)
    cold.recording=index;cold.reference_world=reference;cold.set_displayed_world(reference)
    var cold_key:String=cold.request(row,later,0,false)
    var cold_image:Texture2D=await source_texture(cold,cold_key,"Independent cold later cut",row,later,0)
    if cold_image!=null:
        check(cold_image.get_image().get_data()==later_image.get_image().get_data(),
            "Cold and retained paths draw identical full-context pixels at the same actual cut and view")
    cold.close()
    var back_key:String=cache.request(row,backward,0,false)
    check(back_key not in [first_key,later_key],"Backward prefix control requests an uncached actual cut")
    var back_image:Texture2D=await source_texture(cache,back_key,"Backward composed cut",row,backward,0)
    if back_image==null:tracks.set_process(was_processing);return
    var restored:RefCounted=cache.composed_pane.world.timeline
    check(not is_same(restored,advanced),"An earlier cut uses ordinary fresh restoration instead of rewinding mutable history")
    same_recorded_cut(restored,index,backward,"Backward composed cut")
    replay_controls.append({"row":row.id,"first_ms":first,"later_ms":later,"backward_ms":backward,
        "scope":"Actual same-recording private forward replay, independent cold output and backward restore; no source-only substitution."})
    var extent:Vector2i=reference_view.size
    var camera_size:float=reference.camera.size
    var hit_material:bool=reference.native_spell_hit_material
    var depth:bool=reference.source_depth;var normals:bool=reference.source_normals
    # Exercise the pane API too: output invalidation below deliberately retires
    # a pane, so it alone cannot establish reused-target extent synchronization.
    reference_view.size=extent+Vector2i(32,16)
    var pane:Dictionary=ReplayPanes.prepare(root,restored,index,reference,cache.composed_pane,0,true,true,0)
    check(is_same(pane.world.timeline,restored) and pane.viewport.size==reference_view.size,
        "Existing same-cut replay pane explicitly adopts the actual resized extent")
    pane.world.external_clock=true;ReplayPanes.freeze(pane,true)
    for setting in ["extent","camera","material","depth","normals"]:
        var previous:int=cache.generation
        var old_key:String=back_key
        if setting=="camera":reference.camera.size=camera_size*1.125
        elif setting=="material":reference.native_spell_hit_material=not hit_material
        elif setting=="depth":reference.source_depth=not depth
        elif setting=="normals":reference.source_normals=not normals
        # The Timeline's pre-signature path must invalidate resident images
        # even when no direct thumbnail request/poll has run since the change.
        tracks.prepare_visible(false)
        check(cache.generation==previous+1 and not cache.textures.has(old_key),
            "Same-cut "+setting+" change invalidates old composed output before a cache hit")
        back_key=cache.request(row,backward,0,false);cache.set_demand({back_key:true})
        check(back_key!=old_key,"Changed "+setting+" output has a new existing generation key")
        var image:Texture2D=await source_texture(cache,back_key,"Same-cut changed "+setting,row,backward,0)
        if image==null:break
        var stored_extent:=Vector2(128,roundi(128.0*reference_view.size.y/reference_view.size.x))
        check(image.get_size()==stored_extent and cache.composed_pane.viewport.size==reference_view.size \
            and cache.composed_pane.world.camera.size==reference.camera.size \
            and cache.composed_pane.world.native_spell_hit_material==reference.native_spell_hit_material \
            and cache.composed_pane.world.source_depth==reference.source_depth and cache.composed_pane.world.source_normals==reference.source_normals,
            "Changed "+setting+" output uses the actual target extent, camera size and render setting")
        same_recorded_cut(cache.composed_pane.world.timeline,index,backward,"Changed "+setting+" cut")
    reference_view.size=extent;reference.camera.size=camera_size;reference.native_spell_hit_material=hit_material
    reference.source_depth=depth;reference.source_normals=normals
    reference.position_camera()
    tracks.set_process(was_processing)

func identity_and_authoring(row:Dictionary,index:Dictionary)->void:
    check(not Thumbnails._composed_row(row),"Persisted-source identity reuse uses an actual source-only recorded phase, without clearing operands")
    if Thumbnails._composed_row(row):return
    var cache=Thumbnails.new();cache.host=root;cache.cache=Thumbnails.Catalog.source_snapshot(index.cache)
    var at:float=lerpf(row.start_ms,row.end_ms,.5)
    var original:String=cache.request(row,at,0,false)
    var texture:Texture2D=await source_texture(cache,original,"Actual standalone source for disk controls")
    if texture==null:cache.close();return
    var copy:Dictionary=row.duplicate(true);copy.id+="/unrelated-occurrence";copy.component.id+="/unrelated-occurrence"
    copy.component.actor_uuid="unrelated-actor";copy.component.target_uuid="unrelated-recipient";copy.component.source_event_uuid="unrelated-event"
    var store=Store.new()
    var hz:float=maxf(1,float(row.get("source_fps",row.component.get("sample_hz",32))))
    var baseline:Dictionary=store.visual_specification(row.component,hz)
    check(store.visual_specification(copy.component,hz)==baseline,"Only eligible source-only artwork excludes unrelated occurrence/actor identity")
    var bookkeeping:Dictionary=row.duplicate(true)
    var names:Dictionary={}
    for field in bookkeeping.component.native_cue:names[StringName(str(field))]=bookkeeping.component.native_cue[field]
    names[&"clip"]="different-intake-order";names[&"source_index"]=98765;names[&"role"]=StringName(str(names[&"role"]))
    bookkeeping.component.native_cue=names
    check(store.visual_specification(bookkeeping.component,hz)==baseline,"Bookkeeping phase order and StringName keys preserve the exact canonical source specification")
    var edited:Dictionary=row.duplicate(true)
    edited.component.native_cue.scale=float(edited.component.native_cue.get("scale",1.0))*.731
    check(store.visual_specification(edited.component,hz)!=baseline,"A changed visual cue cannot alias the prior persisted source specification")
    var invalidated:String=cache.request(edited.merged({"id":row.id+"/changed-scale"},true),at,0,false)
    check(not cache.textures.has(invalidated) and cache.pending.any(func(job):return job.key==invalidated),
        "An unbaked changed visual cue enters the existing explicit source render fallback")
    cache.close()
    await dependency_revision(row,texture)

func dependency_revision(row:Dictionary,texture:Texture2D)->void:
    var root_path:String="res://.runtime/native-preview-resource-probe-"+str(OS.get_process_id())
    DirAccess.make_dir_recursive_absolute(root_path)
    var component:Dictionary=row.component.duplicate(true)
    component.native_clip=Effects.occurrence_clip(component).duplicate(true)
    var selected:Dictionary=Effects.choice(component.native_clip)
    var actual:Dictionary=selected.approaches[0] if not selected.approaches.is_empty() else {}
    var field:String="source_phase" if str(actual.get("source_phase","")).get_extension() in ["tres","tscn","gd"] else "path"
    var source:String=str(actual.get(field,""))
    check(source.get_extension() in ["tres","tscn","gd","res"] and FileAccess.file_exists(source),"Dependency qualification uses this selected source's actual Resource or program")
    if source.get_extension() not in ["tres","tscn","gd","res"] or not FileAccess.file_exists(source):
        DirAccess.remove_absolute(root_path);return
    var fixture:String=root_path.path_join("source."+source.get_extension())
    var original:PackedByteArray=FileAccess.get_file_as_bytes(source)
    FileAccess.open(fixture,FileAccess.WRITE).store_buffer(original)
    actual[field]=fixture
    var store=Store.new()
    var hz:float=maxf(1,float(row.get("source_fps",component.get("sample_hz",32))))
    var descriptor:Dictionary=store.descriptor(component,hz)
    check(descriptor.dependencies.has(fixture),"Actual selected source phase participates in source invalidation")
    var packet=Packet.new()
    packet.signature=descriptor.signature;packet.specification=descriptor.specification;packet.dependencies=descriptor.dependencies
    packet.quarter=0;packet.hz=hz;packet.ticks.append(0);packet.textures.append(texture)
    var bytes:int=texture.get_image().get_data_size();packet.sizes.append(bytes);packet.texture_bytes=bytes
    var path:String=Store.resource_path(descriptor.signature,0,0)
    check(not FileAccess.file_exists(path),"Dependency probe has its own new derived Resource")
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(fixture);DirAccess.remove_absolute(root_path);return
    DirAccess.make_dir_recursive_absolute(Store.DIRECTORY)
    check(ResourceSaver.save(packet,path,ResourceSaver.FLAG_COMPRESS)==OK,"Owned dependency probe saves through Godot ResourceSaver")
    var loaded:Texture2D=store.lookup(descriptor,0,0)
    var deadline:int=Time.get_ticks_msec()+15000
    while loaded==null and store.pending(descriptor,0,0) and Time.get_ticks_msec()<deadline:
        await process_frame;loaded=store.lookup(descriptor,0,0)
    check(loaded!=null and store.disk_loads==1 and store.issues.is_empty(),"Actual completed disk Resource serves the unchanged selected source")
    if loaded!=null:
        check(loaded.get_image().get_data()==texture.get_image().get_data(),"Persisted source Resource preserves exact native source pixels")
        var unrelated:Dictionary=component.duplicate(true)
        unrelated.actor_uuid="unrelated-actor";unrelated.target_uuid="unrelated-recipient";unrelated.source_event_uuid="unrelated-event"
        var same_source:Dictionary=store.descriptor(unrelated,hz)
        var reused:Texture2D=store.lookup(same_source,0,0)
        check(same_source.signature==descriptor.signature and reused!=null and store.disk_loads==1,
            "A distinct eligible source-only occurrence reuses the actual persisted Resource without a second load")
        if reused!=null:check(reused.get_image().get_data()==loaded.get_image().get_data(),"Source-only occurrence reuse preserves exact disk pixels")
    if source.get_extension()=="res":
        var queued:Error=ResourceLoader.load_threaded_request(fixture,"",false,ResourceLoader.CACHE_MODE_IGNORE)
        check(queued==OK,"Owned byte-identical recording copy requests its own actual Resource token")
        var loaded_source:Resource
        deadline=Time.get_ticks_msec()+15000
        while queued==OK and ResourceLoader.load_threaded_get_status(fixture)==ResourceLoader.THREAD_LOAD_IN_PROGRESS and Time.get_ticks_msec()<deadline:await process_frame
        if queued==OK and ResourceLoader.load_threaded_get_status(fixture)==ResourceLoader.THREAD_LOAD_LOADED:
            loaded_source=ResourceLoader.load_threaded_get(fixture)
        check(loaded_source!=null,"Owned recording copy reaches actual ResourceLoader completion before revision")
        if loaded_source!=null:
            loaded_source.resource_name+=" owned metadata revision"
            check(ResourceSaver.save(loaded_source,fixture,ResourceSaver.FLAG_COMPRESS)==OK,"A valid recording metadata revision preserves the original rendering fields")
    else:
        var comment:String="#" if source.get_extension()=="gd" else ";"
        FileAccess.open(fixture,FileAccess.WRITE).store_string(original.get_string_from_utf8()+"\n"+comment+" source revision for owned invalidation qualification\n")
    store.reset()
    var revised:Dictionary=store.descriptor(component,hz)
    check(revised.signature!=descriptor.signature,"An actual source file revision invalidates the prior visual signature")
    check(store.lookup(revised,0,0)==null,"A revised source cannot load the previous saved image")
    store.reset();packet=null
    DirAccess.remove_absolute(path);DirAccess.remove_absolute(fixture);DirAccess.remove_absolute(root_path)
    check(FileAccess.get_file_as_bytes(source)==original,"Dependency qualification never edits the original packaged source")

func incremental_pages(textures:Array)->void:
    if textures.size()<2:check(false,"Incremental page qualification has two actual native images");return
    var previous=Packet.new();var current=Packet.new()
    for packet in [previous,current]:packet.signature="owned-page-union";packet.quarter=2;packet.hz=60
    previous.ticks=PackedInt32Array([0,1]);previous.textures.assign([textures[0],textures[0]])
    current.ticks=PackedInt32Array([1,2]);current.textures.assign([textures[1],textures[1]])
    for packet in [previous,current]:
        for texture in packet.textures:packet.sizes.append(texture.get_image().get_data_size())
    check(Baker.merge_page(previous,current),"A later same-source partial bake can merge the existing native Resource page")
    check(current.ticks==PackedInt32Array([0,1,2]) and current.textures.size()==3,"Partial-page extension preserves earlier qualified source ticks")
    check(is_same(current.textures[0],textures[0]) and is_same(current.textures[1],textures[1]) and is_same(current.textures[2],textures[1]),"Only newly baked overlapping ticks replace prior source images")
    check(current.texture_bytes==current.sizes[0]+current.sizes[1]+current.sizes[2],"Merged resource accounts for all retained texture bytes")
    var another=Packet.new();another.signature=current.signature;another.quarter=current.quarter;another.hz=current.hz
    another.ticks=PackedInt32Array([64]);another.textures.assign([textures[1]]);another.sizes.append(textures[1].get_image().get_data_size())
    check(not Baker.merge_page(current,another) and another.ticks==PackedInt32Array([64]),"A different bounded source page cannot consume or rewrite this page")

func run()->void:
    check(DisplayServer.get_name()!="headless","Recorded preview qualification uses a native renderer and completed draw")
    if DisplayServer.get_name()=="headless":finish();return
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var originals:Array=Library.read().filter(func(record):return record.id=="spell.fireball/baseline")
    check(originals.size()==1 and originals[0].ready,"The exact current Library Fireball original is available")
    if originals.size()!=1 or not originals[0].ready:finish();return
    var begin:int=Time.get_ticks_usec()
    var index:Dictionary=Recording.read(originals[0].perspectives[0].journal)
    var indexing_ms:float=float(Time.get_ticks_usec()-begin)/1000.0
    check(index.ok,"Original Fireball journal compiles with ordinary Studio Recording")
    if not index.ok:finish();return
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("native_spell",false) and row.component.get("spell_id")=="fireball")
    check(rows.size()==3,"Real recording retains cast, flight and area source rows")
    if rows.size()!=3:finish();return
    var immutable:PackedByteArray=var_to_bytes(rows)
    for row in rows:
        check(not str(row.get("source","")).is_empty() and row.source==row.component.get("source"),"The actual source preview retains its exact authored row/component pointer")
        observed_sources.append({"row":row.id,"source":row.source,"event":row.source_event_uuid,"clip":row.component.native_clip.id,
            "inputs":row.component.native_clip.get("inputs",[]),"scope":"recorded_composed_context" if Thumbnails._composed_row(row) else "isolated_source"})
    reference_view=SubViewport.new();reference_view.size=Vector2i(640,480);reference_view.own_world_3d=true
    reference_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(reference_view)
    reference=Play.new();reference.external_playback=true;reference.external_clock=true
    reference.catalog_cache=Play.Catalog.source_snapshot(index.cache);reference.media_warmup.budget_bytes=0
    reference.component_renderer.audio.set_enabled(false);reference.native_startup_background=false
    reference.playback_end_ms=index.presentation_end_ms;reference_view.add_child(reference)
    reference.install_playback(Recording.restore(index,0.0));reference.timeline.paused=true
    var deadline:int=Time.get_ticks_msec()+20000
    while not reference.playback_prepared() and Time.get_ticks_msec()<deadline:await process_frame
    check(reference.playback_prepared(),"The actual recorded production reference prepares before source requests")
    if not reference.playback_prepared():reference_view.queue_free();finish();return
    reference.claim_receiving();reference._publish_receiving()
    profile_composed="--profile-composed-stages" in OS.get_cmdline_user_args()
    tracks=TimelineView.new()
    if profile_composed:tracks.thumbnails=ProfiledThumbnails.new()
    root.add_child(tracks);tracks.size=Vector2(1280,800);tracks.filter="native_effect"
    tracks.preparation_admission=reference.preparation_admission
    tracks.set_index(index);bind_recording(index);tracks.rebuild_rows();tracks.fit()
    check(tracks.thumbnails.textures.is_empty(),"Fresh process begins without resident thumbnail images")
    var fresh:Dictionary=await measure("fresh-process Fireball exact four-view context");fresh.recording_index_ms=indexing_ms
    # Sequential actual-cut witnesses start with no earlier cached image whose
    # reusable pane may already belong to another sample. Cache hits thereafter
    # retain their keyed image without claiming the pane is still its origin.
    tracks.set_process(false);tracks.set_index(index);bind_recording(index)
    var snapshots:Dictionary=await phase_samples(rows)
    tracks.set_process(true)
    var coloured:int=0
    for texture in snapshots.values():
        var image:Image=texture.get_image()
        for y in image.get_height():
            for x in image.get_width():
                var pixel:Color=image.get_pixel(x,y)
                if maxf(pixel.r,maxf(pixel.g,pixel.b))>1.0/255.0:coloured+=1
    check(coloured>0,"Actual native preview samples contain rendered pixels; composed scene pixels are not isolated-effect evidence")
    tracks.pixels_per_second*=1.75;tracks.origin_ms=index.presentation_end_ms*.45
    await measure("changed zoom and actual late-source bins")
    tracks.set_index(index);bind_recording(index);tracks.filter="native_effect";tracks.rebuild_rows();tracks.fit()
    await measure("reset/reload exact recording context")
    await retained_prefix_and_optics(rows,index)
    incremental_pages(snapshots.values())
    # Disk identity remains a source-only contract. Select a genuine eligible
    # phase from these exact existing originals; never strip required inputs.
    var source_index:Dictionary=index
    var eligible:Array=source_index.rows.filter(func(row):return row.kind=="native_effect" and row.get("status")!="missing" and row.get("component",{}).get("native_spell",false) and not Thumbnails._composed_row(row))
    if eligible.is_empty():
        var missile:Array=Library.read().filter(func(record):return record.id=="spell.magic_missile/baseline" and record.ready)
        if missile.size()==1:
            source_index=Recording.read(missile[0].perspectives[0].journal)
            if source_index.get("ok",false):eligible=source_index.rows.filter(func(row):return row.kind=="native_effect" and row.get("status")!="missing" and row.get("component",{}).get("native_spell",false) and not Thumbnails._composed_row(row))
    check(not eligible.is_empty(),"Existing Fireball/MagicMissile originals contain an actual source-only phase for separate disk Resource controls")
    if not eligible.is_empty():await identity_and_authoring(eligible[0],source_index)
    check(var_to_bytes(rows)==immutable,"Requests and invalidation preserve real recording rows and authored cues")
    tracks.queue_free();reference_view.queue_free();await process_frame;await RenderingServer.frame_post_draw
    finish()

func finish()->void:
    if finished:return
    finished=true
    var report={"checks":checks,"failed":failures.size(),"failures":failures,"measurements":measurements,"sources":observed_sources,"replay_controls":replay_controls,
        "scope":"Actual current Fireball Recording/Timeline previews, exact composed context where inputs require it, four views/tails/zoom/reset and existing budgets; separately eligible actual source-only identity, persisted Resource/dependency revision and bounded-page controls. Full-context pixels are not isolated-effect evidence. No full Library timing, current-engine qualification or artwork approval is inferred."}
    FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_PREVIEW_RESOURCE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
