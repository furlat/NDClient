extends "res://tests/native_vampiric_touch_render_checks.gd"
## Original result-owned sources through Play, with isolated framebuffer proof.
const RecordingMedia=preload("res://studio/recording_media.gd")
const FINITE_ROOT="res://tests/fixtures/schema16/finite-observed"
## Exact newer original supplies the public blast footprint; older original
## bytes remain an explicit unavailable-input control below, never normalized.
const FINITE_JOURNALS={"vitriolic-sphere":"res://tests/fixtures/schema16/finite-observed-current/vitriolic-sphere-0c",
    "divine-word":FINITE_ROOT+"/divine-word"}
const FINITE_CASES={"vitriolic-sphere":"high-level-22/vitriolic-sphere/native_target_initial","divine-word":"review/divine_word/back/proclamation"}
const FINITE_CAPTURES="res://.runtime/finite-observed-captures"
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_FINITE_OBSERVED_FAIL ",label)
func settle(world:Node,component_id:String="")->bool:
    var began:int=Time.get_ticks_msec();var reported:bool=false
    var before_draw:Dictionary={}
    while Time.get_ticks_msec()-began<10000 and not world.publication_failed and world.presentation_errors.is_empty() and world.media_issue.is_empty():
        # SceneTree.process_frame resumes the parent replay controller before
        # Play spends its shared preparation allowance in the child _process.
        # The post-draw check still requires the actual published picture.
        await process_frame
        var prepared:bool=world.playback_prepared()
        before_draw={"prepared":prepared,"components_ready":world.component_renderer.ready,
            "media_gate":world.media_gate.duplicate(true),"budget":world.preparation_admission.duplicate(true)}
        await RenderingServer.frame_post_draw
        var drawn:bool=world.playback_prepared()
        var bindings:Dictionary=world.component_renderer.native_spells.diagnostics.get(component_id,{}).get("input_bindings",{})
        var inputs_ready:bool=component_id.is_empty() or (not bindings.is_empty() and bindings.unavailable.is_empty())
        if prepared and drawn and inputs_ready and not world.rotation_pending():return true
        if not reported and Time.get_ticks_msec()-began>=2000:
            var pending:Dictionary=settle_diagnostic(world,component_id,before_draw)
            evidence.append({"kind":"native_settle_pending","elapsed_ms":Time.get_ticks_msec()-began,"diagnostic":pending})
            print("FINITE_OBSERVED_PENDING ",JSON.stringify(settle_summary(pending)));reported=true
    var timeout:Dictionary=settle_diagnostic(world,component_id,before_draw)
    evidence.append({"kind":"native_settle_failed","elapsed_ms":Time.get_ticks_msec()-began,"diagnostic":timeout})
    check(false,"Native preparation failed: "+JSON.stringify(settle_summary(timeout)));return false
func settle_summary(diagnostic:Dictionary)->Dictionary:
    var summary:Dictionary=diagnostic.duplicate()
    # Keep the complete witness in the saved evidence. Console failures need
    # counts and a bounded sample, including stale boot-only CPU interests.
    for field in ["required_components","missing_sources","boot_waiting","boot_sources"]:
        var rows:Array=diagnostic.get(field,[])
        summary[field]={"count":rows.size(),"examples":rows.slice(0,4)}
    var preparation:Dictionary=diagnostic.get("native_preparation",{}).duplicate()
    var wanted:Array=preparation.get("wanted_ids",[])
    preparation.wanted_ids={"count":wanted.size(),"examples":wanted.slice(0,3)}
    summary.native_preparation=preparation
    var measured:Dictionary=diagnostic.get("preparation_profile",{})
    summary.preparation_profile={"last_completed_frame":_preparation_frame_summary(measured.get("last_completed_frame",{})),
        "slowest_native_preparation_frames":measured.get("slowest_native_preparation_frames",[]).map(func(row):return _preparation_frame_summary(row)),
        "open_cpu_ms":measured.get("open_cpu_ms",{}),"surface_counters":measured.get("surface_counters",{}),
        "source_constructions":measured.get("source_constructions",[])}
    return summary

static func _preparation_frame_summary(sample:Dictionary)->Dictionary:
    if sample.is_empty():return {}
    var phases:Dictionary={}
    for name in sample.get("cpu_ms",{}):
        if str(name).begins_with("native_prepare_") or str(name).begins_with("native_construct_") or name in ["player_process","preparation_step"]:phases[name]=sample.cpu_ms[name]
    return {"frame":sample.frame,"frame_ms":sample.frame_ms,"cpu_ms":phases,"view":sample.get("view",{}),
        "largest_native_phase":sample.get("largest_native_phase",""),"largest_native_phase_ms":sample.get("largest_native_phase_ms",0.0)}

func preparation_profile(world:Node)->Dictionary:
    # Copy existing completed records only at pending/timeout or case teardown.
    # Phase durations are inclusive: rank by one measured phase, never their sum.
    var profile:Dictionary=world.profile;var frames:Array=profile.frames
    var latest:Dictionary=frames[posmod(int(profile.cursor)-1,frames.size())] if not frames.is_empty() else {}
    var slowest:Array=[]
    for sample in frames:
        var largest:String="";var elapsed:float=0.0
        for name in sample.get("cpu_ms",{}):
            if not (str(name).begins_with("native_prepare_") or str(name).begins_with("native_construct_")):continue
            if float(sample.cpu_ms[name])>elapsed:largest=str(name);elapsed=float(sample.cpu_ms[name])
        if elapsed<=0.0:continue
        if slowest.size()==3 and elapsed<=float(slowest[-1].largest_native_phase_ms):continue
        var row:Dictionary=sample.duplicate()
        row.largest_native_phase=largest;row.largest_native_phase_ms=elapsed
        slowest.append(row);slowest.sort_custom(func(a,b):return a.largest_native_phase_ms>b.largest_native_phase_ms)
        if slowest.size()>3:slowest.resize(3)
    var surface=world.component_renderer.native_spells.inputs.surfaces
    var sources:Array=[]
    for handle in world.component_renderer.native_spells.handles.values():
        var phases:Dictionary=handle.get("construction_phases",{})
        if phases.is_empty():continue
        sources.append({"component_id":handle.component.id,"source_occurrence":handle.component.get("source_event_uuid",""),
            "clip_id":handle.clip.id,"approach_id":handle.get("effect_approach_id",""),
            "constructor":handle.get("effect_approach_path",""),"source_phase":handle.get("effect_source_phase",""),
            "cpu_ms":phases.duplicate()})
    sources.sort_custom(func(a,b):return float(a.cpu_ms.get("ready",0.0))>float(b.cpu_ms.get("ready",0.0)))
    if sources.size()>4:sources.resize(4)
    return {"last_completed_frame":latest.duplicate(true),"slowest_native_preparation_frames":slowest.duplicate(true),
        "open_cpu_ms":profile.phases.duplicate(),"source_constructions":sources,
        "surface_counters":{"source_builds":surface.source_builds,"source_worker_usec":surface.source_usec,
            "packet_builds":surface.packet_builds,"source_entries":surface.sources.size(),"packet_entries":surface.packets.size(),
            "worker_jobs":surface.jobs.size(),"pending_sources":surface.pending.size(),"discarded":surface.discarded,
            "received_scans":surface.received_scans,"received_poses":surface.received_poses.size()},
        "scope":"Existing completed frame ring and current uncompleted phase accumulator; CPU phases are inclusive and must not be summed. Worker counters are cumulative. Renderer CPU/GPU samples may lag. No leaf attribution inferred from the required_components envelope."}
func history_pending(world:Node)->Array:
    var native=world.component_renderer.native_spells;var rows:Array=[]
    var displayed:Dictionary={}
    for component in world.displayed_components:displayed[component.id]=true
    for id in native.handles:
        if rows.size()>=6:break
        var handle:Dictionary=native.handles[id]
        if "actor_context" not in handle.clip.get("inputs",[]):continue
        var helper:RefCounted=handle.occurrence.actor_history
        if helper==null:
            rows.append({"id":id,"reason":"history_capture_owner_unavailable"});continue
        var diagnostic:Dictionary=native.diagnostics.get(id,{})
        var records:Array=[];var suspended:int=0;var complete:int=0;var closed:int=0
        for poses in helper.history.values():
            for pose in poses:
                if not pose.has("capture"):continue
                var record:Dictionary=pose.capture
                if record.get("suspended",false):suspended+=1
                if record.get("ready",false):complete+=1
                if record.get("closed",false):closed+=1
                if records.size()<2 and not record.get("ready",false):
                    records.append({"requested_identity":record.get("requested_identity",{}),"drawn_identity":record.get("drawn_identity",{}),
                        "drawn_frame":record.get("drawn_frame",-1),"attempt":record.get("attempt",0),"suspended":record.get("suspended",false),
                        "closed":record.get("closed",false),"error":record.get("error","")})
        rows.append({"id":id,"displayed":displayed.has(id),"required":native._required_ids.has(id),
            "wanted":id in native.preparation_state.get("wanted_ids",[]),"allocated":handle.get("history_allocated",false),
            "actor_context_bound":handle.get("actor_context_bound",false),"admitted":helper.admitted,
            "history_requested_key":handle.get("history_requested_key",[]),"history_seeded_key":handle.get("history_seeded_key",[]),
            "departure_seeded_key":handle.get("departure_seeded_key",[]),"sample_time":handle.sample_time,
            "requested_time":handle.requested_time,"drawn_time":handle.drawn_time,
            "native_diagnostic":{"status":diagnostic.get("status",""),"reason":diagnostic.get("reason",""),
                "input_bindings":diagnostic.get("input_bindings",{})},
            "capture_complete":complete,"capture_suspended":suspended,"capture_closed":closed,"pending_examples":records})
        if rows.size()==6:break
    return rows
func settle_diagnostic(world:Node,component_id:String,before_draw:Dictionary)->Dictionary:
    var media:Dictionary=world.media_warmup
    var owner:Dictionary=Play.MediaWarmup.physical(media)
    var consumer:Dictionary=owner.consumers[media.consumer_id]
    var requirements:Dictionary=world.media_plan.get("required",{})
    var missing:Array=[]
    for path in requirements:
        var requested:Dictionary={};requested[path]=requirements[path]
        if Play.MediaWarmup.ready(media,requested):continue
        missing.append({"path":path,"admitted":consumer.paths.has(path),"ready_member":media.ready_paths.has(path),
            "roles":owner.interests.get(path,[]),"queued":owner.queued.has(path),"resident":owner.resident.has(path),
            "cpu_image":owner.source_images.has(path),"gpu_texture":owner.textures.has(path)})
    var native=world.component_renderer.native_spells
    var boot_sources:Array=[]
    for path in media.boot_waiting.keys().slice(0,4):
        var resident:Dictionary=owner.resident.get(path,{})
        boot_sources.append({"path":path,"current_required":consumer.paths.has(path),
            "role_counts":owner.interests.get(path,[]),"queued":owner.queued.has(path),
            "cpu_bytes":resident.get("cpu_bytes",0),"gpu_bytes":resident.get("gpu_bytes",0),
            "cpu_image":owner.source_images.has(path),"gpu_texture":owner.textures.has(path)})
    var startup:Dictionary=Play.NativeStartup.status(world._native_startup_request(world.timeline.display_ms))
    var pending:Dictionary={}
    if world.pending_world!=null:
        pending={"prepared":world.pending_world.prepared,"admitted":world.pending_world.admitted,"phase":world.pending_world.phase,
            "epoch":world.pending_world.epoch,"quarter":world.pending_world.quarter,"key":world.pending_world.boundary.get("preparation_key",[])}
        # Failure-only breadcrumbs from existing preparation owners. Reading
        # these does not realize a binding, request a draw or advance a clock.
        var prepared_world=world.pending_world
        # Same existing _detailed_frame_context fields, copied directly so this
        # read does not reset that function's profiling counters.
        pending.work={"actor_binding_cursor":prepared_world.binding_cursor,"actor_binding_total":prepared_world.actor_bindings.size(),
            "actor_binding_path":prepared_world.actor_bindings[prepared_world.binding_cursor].value.get("path","") if prepared_world.binding_cursor<prepared_world.actor_bindings.size() else "",
            "blood_rows":prepared_world.result.get("blood_rows",{}).size(),"blood_handles":prepared_world.blood_preparation.handles.size(),
            "blocked_actor":prepared_world.blocked_actor.duplicate(true),"blocked_source":prepared_world.blocked_source.duplicate(true),
            "native_phase_usec":prepared_world.phase_usec.duplicate()}
        if prepared_world.binding_cursor<prepared_world.actor_bindings.size():
            var binding:Dictionary=prepared_world.actor_bindings[prepared_world.binding_cursor]
            var value:Dictionary=binding.value
            var missing_binding:Array=[]
            if not world.textures.has(value.path):missing_binding.append(value.path)
            for path in value.get("geometry",{}).get("textures",{}).values():
                if not world.textures.has(path) and path not in missing_binding:missing_binding.append(path)
            var optical:Dictionary=binding.get("optical",{})
            pending.binding={"prepared":not binding.get("prepared",{}).is_empty(),"missing_textures":missing_binding,
                "optical":{"ready":optical.get("ready"),"mask_path":optical.get("mask_path",""),"has_mask":optical.has("mask")}}
        var blood=world.component_renderer.blood
        var waiting:Array=[];var ready_count:int=0;var removed_count:int=0;var waiting_count:int=0
        for key in prepared_world.blood_preparation.handles:
            var record:Dictionary=prepared_world.blood_preparation.handles[key]
            if record.get("removed",false):removed_count+=1;continue
            var held:Dictionary=record.get("handle",{})
            if held.get("ready",false):ready_count+=1;continue
            waiting_count+=1
            if waiting.size()==4:continue
            var callback:Callable=held.get("draw_callback",Callable())
            waiting.append({"key":key,"ready":held.get("ready",false),"slot":held.get("slot",-1),
                "generation":held.get("generation",-1),"borrowed":record.get("borrowed",false),
                "draw_wait":held.get("draw_wait",-1),"draw_wait_owned":blood._draw_waits.has(held.get("draw_wait",-1)),
                "callback_connected":callback.is_valid() and RenderingServer.frame_post_draw.is_connected(callback)})
        pending.blood={"ready":blood.ready,"resources_ready":blood.resources_ready,"generation":blood._generation,
            "ready_handles":ready_count,"removed_handles":removed_count,"pending_handles":waiting_count,
            "draw_waits":blood._draw_waits.size(),"pending_examples":waiting}
        # Inspect the existing exclusion owner without polling/joining a job,
        # requesting resources or acquiring source mutation from a diagnostic.
        var admission=world.component_renderer.BloodRenderer.Admission
        var loading_progress:Array=[]
        var loading_status:int=ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
        if not admission.loading_path.is_empty():
            loading_status=ResourceLoader.load_threaded_get_status(admission.loading_path,loading_progress)
        var material_job:Dictionary=admission._material_job
        var receiver_cache:Dictionary=world.component_renderer.native_spells._resource_cache
        var blood_pool:Variant=world.component_renderer.blood._pool_world
        pending.blood.admission={"loading_path":admission.loading_path,"settling":admission.settling,
            "loading_status":loading_status,"loading_progress":loading_progress,
            "loading_owner_has_path":admission.loading_owner.has(admission.loading_path),
            "loading_resource_cached":not admission.loading_path.is_empty() and ResourceLoader.has_cached(admission.loading_path),
            "loading_revision":admission.loading_revision,"loading_owner_revision":admission.loading_owner.get("native_source_revision",0),
            "loading_owner_is_receiver_cache":is_same(admission.loading_owner,receiver_cache),
            "mutation_frame":admission.mutation_frame,"current_frame":Engine.get_process_frames(),
            "material_job":not material_job.is_empty(),"material_task":material_job.get("task",-1),
            "material_task_complete":not material_job.is_empty() and WorkerThreadPool.is_task_completed(material_job.task),
            "material_revision":material_job.get("revision",0),"material_owner_revision":material_job.get("owner",{}).get("native_source_revision",0),
            "material_owner_is_receiver_cache":is_same(material_job.get("owner",{}),receiver_cache),
            "receiver_cache_revision":receiver_cache.get("native_source_revision",0),
            "receiver_preparation_revision":world.component_renderer.native_spells.preparation_revision,
            "pool_world_valid":is_instance_valid(blood_pool),"pool_is_current_world":is_same(blood_pool,world),
            "initial_world":prepared_world.initial,"frame_budget_used_usec":world.preparation_admission.used_usec,
            "frame_budget_limit_usec":world.preparation_admission.limit_usec}
    return {"display_ms":world.timeline.display_ms,"component_id":component_id,"sequence":world.timeline.sequence,
        "revisions":{"world":world.world_revision,"timeline_world":world.timeline.world_revision,
            "world_epoch":world.world_prepare_epoch,"timeline_epoch":world.timeline.initialization_revision,"resources":world.timeline.resource_revision},
        "before_draw":before_draw,"media_gate":world.media_gate.duplicate(true),"component_ready":world.component_renderer.ready,
        "component_leaves":world.component_renderer.readiness.duplicate(true),"native_ready":native.ready,
        "native_preparation":native.preparation_state.duplicate(true),"native_failures":native._prepare_failures.duplicate(),
        "history_owners":history_pending(world),"native_issues":native.issues.duplicate(true),
        "native_support_ready":native._support.ready if native._support!=null else true,
        "required_components":world.component_renderer._native_prepare_components.map(func(component):return {"id":component.id,"kind":component.kind,
            "status":component.get("status"),"clip":component.get("native_clip",{}).get("id"),"handle":native.handles.has(component.id)}),
        "required_sources":requirements.size(),"missing_sources":missing,"decode_jobs":owner.decode_jobs.size(),"pending_decode":owner.pending.size(),
        "failed_sources":owner.failed.duplicate(),"boot_waiting":media.boot_waiting.keys(),"boot_sources":boot_sources,"metadata_pending":media.plan_thread!=null,
        "native_startup":{"ready":startup.ready,"pending":startup.pending,"errors":startup.errors},"pending_world":pending,
        "quarter":world.quarter,"published_quarter":world.world_quarter,"rotation_pending":world.rotation_pending(),
        "frame_budget":world.preparation_admission.duplicate(true),"preparation_profile":preparation_profile(world),
        "errors":world.presentation_errors,"media_issue":world.media_issue}
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(FINITE_CAPTURES)
    for name in FINITE_CASES:
        for seat in ["amber","blue"]:
            if name=="vitriolic-sphere":historical_blast_refusal(seat)
            await finite_seat(name,seat)
    finish()
func historical_blast_refusal(seat:String)->void:
    var directory:String=FINITE_ROOT.path_join("vitriolic-sphere").path_join(seat)
    var packet:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("0000000000000008.json")))
    var casts:Array=[]
    for lineage in packet.lineages:
        for node in lineage.events:
            var fact:Variant=node.get("fact")
            if fact!=null and fact.get("behavior_id")=="spell.vitriolic_sphere":casts.append(fact)
    check(casts.size()==1 and casts[0].get("resolved_area_positions",[]).is_empty(),seat+" historical original genuinely omits the blast footprint")
    var index:Dictionary=Recording.read(directory)
    check(index.ok,seat+" historical original remains inspectable without adding missing public cells")
    if not index.ok:return
    var blasts:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")=="high-level-22/vitriolic-sphere/native_initial_blast")
    check(blasts.size()==1 and blasts[0].component.status=="missing" \
        and blasts[0].component.reason=="native_observed_event_recipient_not_disclosed",seat+" old blast stays explicitly unavailable instead of deriving a footprint from rules or recipients")
    var contacts:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")==FINITE_CASES["vitriolic-sphere"])
    check(contacts.size()==4 and contacts.all(func(row):return row.component.status=="available"),seat+" historical actual recipient contacts remain independently supported")

func original_results(name:String,seat:String)->Dictionary:
    var packet:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FINITE_JOURNALS[name].path_join(seat).path_join("0000000000000008.json")))
    var result:Dictionary={"cast":{},"results":{},"residues":{}}
    for lineage in packet.lineages:
        for node in lineage.events:
            var fact:Variant=node.get("fact")
            if fact==null:continue
            if fact.get("behavior_id")==("spell.vitriolic_sphere" if name=="vitriolic-sphere" else "spell.divine_word"):
                result.cast={"occurrence":str(int(node.occurrence)),"fact":fact,"phase":node.phase}
                if name=="divine-word":result.results[str(int(node.occurrence))]=fact
            if name=="vitriolic-sphere" and fact.kind=="damage" and fact.get("stage")=="applied":result.results[str(int(node.occurrence))]=fact
            if fact.kind=="actor_change":
                for actor in fact.actors:
                    for row in actor.rows:
                        if row.field=="condition" and row.get("member")!=null and row.member.behavior_id=="condition.spell.vitriolic_sphere.residue":result.residues[actor.actor_uuid]=row.condition_uuid
    return result
func finite_seat(name:String,seat:String)->void:
    var label:String=name+"/"+seat
    var original:Dictionary=original_results(name,seat)
    var index:Dictionary=Recording.read(FINITE_JOURNALS[name].path_join(seat))
    check(index.ok,label+" original complete recording compiles")
    if not index.ok:return
    if name=="vitriolic-sphere":
        var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FINITE_JOURNALS[name].path_join("recording.json")))
        check(metadata.ok and metadata.engine.commit=="0c2e5a0d74919402c6e528f40c580b7ca3c22e93",label+" newer original retains its actual captured producer identity")
        check(original.cast.fact.get("resolved_area_positions",[]).size()==49,label+" newer original discloses the blast's complete actual49-cell footprint")
        var blasts:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")=="high-level-22/vitriolic-sphere/native_initial_blast")
        check(blasts.size()==1 and blasts[0].component.status=="available" and not blasts[0].component.get("native_constructor_inputs",[]).is_empty(),label+" real completed blast admits through its public footprint and exact constructor")
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")==FINITE_CASES[name])
    check(rows.size()==(4 if name=="vitriolic-sphere" else 1) and rows.size()==original.results.size(),label+" real applied contacts/proclamation own exactly the original finite source count")
    check(rows.all(func(row):return row.component.status=="available" and not row.component.get("persistent_owner",false)),label+" every finite source has actual inputs without a forged held owner")
    if rows.size()!=original.results.size() or not rows.all(func(row):return row.component.status=="available"):return
    var media:Dictionary=RecordingMedia.plan(index)
    check(media.errors.is_empty(),label+" whole original recording media closure resolves")
    if not media.errors.is_empty():return
    Play.Catalog.adopt_snapshot(index.cache,media.source_files)
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.media_warmup.budget_bytes=0;world.media_warmup.encounter_override=media
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows)
    world.native_startup_requested_ms=maxf(0.0,float(rows[0].start_ms)-2.0)
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var seen:Dictionary={}
    for row_index in rows.size():
        var row:Dictionary=rows[row_index];var component:Dictionary=row.component
        var occurrence:String=str(component.source_event_uuid)
        check(original.results.has(occurrence) and not seen.has(occurrence),label+" component belongs to one unique original result occurrence")
        if not original.results.has(occurrence):continue
        seen[occurrence]=true
        var fact:Dictionary=original.results[occurrence]
        var start:float=float(row.start_ms);var end:float=float(row.end_ms)
        var during:float=start+minf(120.0 if name=="vitriolic-sphere" else 350.0,(end-start)*.35)
        var cuts:Array=[maxf(0.0,start-2.0),during,minf(index.presentation_end_ms,end+2.0)]
        if row_index==0:cuts.append_array([maxf(0.0,start-2.0),during])
        var previous:WeakRef;var pass_number:int=0
        for at in cuts:
            world.install_playback(Recording.restore(index,at))
            if not await settle(world,component.id if at==during else ""):world.component_renderer.native_spells.close(world);view.queue_free();await frame();return
            if previous!=null:check(previous.get_ref()==null,label+" seek/loop releases the earlier private finite source owner")
            var native=world.component_renderer.native_spells
            if at!=during:
                check(native.witnesses.all(func(witness):return witness.id!=component.id),label+" this finite result never draws before/after its actual source interval")
                if native.handles.has(component.id):check(not native.handles[component.id].root.is_visible_in_tree(),label+" future/retired source preparation stays hidden")
                previous=null;continue
            # A view request is qualified only after both requested and actual
            # published quarter agree; playback_prepared alone is insufficient.
            var quarter:int=1 if pass_number==0 else 3
            world.request_view(quarter)
            var deadline:int=Time.get_ticks_msec()+15000
            while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
            check(not world.rotation_pending() and world.quarter==quarter and world.world_quarter==quarter,label+" actual requested camera quarter publishes: "+str(quarter))
            if not await settle(world,component.id):break
            check(native.handles.has(component.id),label+" finite real result has a native owner at its exact interval")
            if not native.handles.has(component.id):continue
            var handle:Dictionary=native.handles[component.id]
            var channel:String="native_state" if name=="vitriolic-sphere" else "observation"
            var programs:Array=handle.occurrence.input_receivers.get("set_"+channel,[])
            check(programs.size()==1,label+" exactly one delivered source receives the actual "+channel)
            if programs.size()!=1:continue
            var program:Node3D=programs[0]
            var observation:Dictionary=program.capture_observation()
            if name=="vitriolic-sphere":contact_source(program,component,fact,original,observation,label)
            else:proclamation_source(program,component,fact,original,observation,label)
            var bindings:Dictionary=native.diagnostics.get(component.id,{}).get("input_bindings",{})
            var requested:Array=component.native_clip.inputs;var supplied:Array=bindings.get("supplied",[])
            check(bindings.get("unavailable",{}).is_empty() and requested.all(func(input):return input in supplied) \
                and supplied.all(func(input):return input in requested),label+" every declared input has real supplied evidence, no setter-only readiness claim")
            check(native.witnesses.any(func(witness):return witness.id==component.id),label+" actual source has a post-draw witness")
            var target_position:Variant=component.to_position if name=="vitriolic-sphere" else component.from_position
            var elevation:float=float(component.get("to_elevation_feet" if name=="vitriolic-sphere" else "from_elevation_feet",0.0))
            world.camera_focus=Play.Placement.contact({"position":target_position,"base_height_steps":elevation/5.0})
            world.camera.size=4;world.initial_focus=true;world.position_camera();world.grid_visible=false
            await frame();await frame();world.set_process(false)
            var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
            var component_bytes:PackedByteArray=var_to_bytes(component)
            var present:Image=view.get_texture().get_image()
            var stem:String=FINITE_CAPTURES.path_join(name+"-"+seat+"-"+occurrence+"-q"+str(quarter))
            check(present.save_png(stem+"-present.png")==OK,label+" actual source capture saved")
            handle.root.hide();await frame();await frame()
            var hidden:Image=view.get_texture().get_image();var pixels:int=changed(present,hidden)
            check(pixels>0,label+" hiding only this real finite source changes framebuffer pixels")
            check(hidden.save_png(stem+"-hidden.png")==OK,label+" same-cut isolated-source hidden control saved")
            check(var_to_bytes(world.timeline.state)==canonical and var_to_bytes(component)==component_bytes,label+" source visibility probe leaves native facts, owner packet and compiled timing unchanged")
            handle.root.show();await frame()
            check(handle.root.is_visible_in_tree(),label+" same real native owner restores without a duplicate probe source")
            evidence.append({"case":name,"seat":seat,"event_occurrence":occurrence,"cast_occurrence":original.cast.occurrence,"target_uuid":component.target_uuid,
                "at_ms":at,"quarter":quarter,"published_quarter":world.world_quarter,"changed_pixels":pixels,"capture":stem+"-present.png","observation":observation})
            previous=weakref(handle.root);world.set_process(true);pass_number+=1
    var native=world.component_renderer.native_spells;native.close(world)
    check(seen.size()==original.results.size(),label+" every original finite recipient/result has native output evidence")
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty(),label+" teardown releases all private finite owners")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+" original seeking/looping/view switching has no presentation/resource errors")
    view.queue_free();await frame();await frame()
func contact_source(program:Node3D,component:Dictionary,fact:Dictionary,original:Dictionary,observation:Dictionary,label:String)->void:
    var state:Dictionary=component.native_inputs.native_state
    check(fact.applied_damage==29 and fact.damage_type=="Acid" and fact.stage=="applied",label+" original result is exactly 29 applied Acid")
    check(program.specification.phase=="initial_contact" and program.state==state and program.rejection.is_empty(),label+" sealed source admits the exact initial-contact state")
    check(state.source_owner_uuid==original.cast.occurrence and state.original_caster_uuid==fact.source_entity_uuid \
        and state.recipient_uuid==fact.target_entity_uuid and state.event_uuid==str(component.source_event_uuid) and state.damage_applied,label+" actual cast/result/source/recipient identities reach native state")
    check(program.specification.get("condition_uuid","").is_empty() and state.get("condition_uuid","").is_empty() \
        and not component.get("persistent_owner",false),label+" initial source retains no fake held-condition identity")
    check(program.geometry.get("actor")==fact.target_entity_uuid and program.geometry.get("points",[]).size()>=8 \
        and program.endpoints.size()==1 and program.endpoints[0].actor_uuid==fact.target_entity_uuid and program.endpoints[0].socket=="body_center",label+" measured actual recipient surface and body endpoint drive the contact")
    check(program.draws.any(func(draw):return draw.is_visible_in_tree()) and observation.actual_recipient_points>=8 \
        and observation.phase=="initial_contact" and not observation.fixed_five_d4_computed \
        and not observation.recipient_end_or_condition_duration_counted,label+" source submits real contact geometry without computing a delayed tick or damage")
func proclamation_source(program:Node3D,component:Dictionary,fact:Dictionary,original:Dictionary,observation:Dictionary,label:String)->void:
    var actual:Dictionary=component.native_inputs.observation
    check(program.observation==actual and program.admitted() and program.settings.role=="proclamation",label+" actual completed cast admits only the proclamation source")
    check(actual.event_uuid==original.cast.occurrence and actual.cast_uuid==original.cast.occurrence \
        and actual.source_entity_uuid==fact.source_entity_uuid and actual.target_entity_uuid==fact.target_entity_uuid \
        and actual.phase=="completion" and actual.admitted and not actual.canceled,label+" exact actual completed cast identities reach the source")
    check(program.endpoints.size()==1 and program.endpoints[0].actor_uuid==fact.source_entity_uuid \
        and program.endpoints[0].socket=="ground",label+" proclamation anchors at actual caster without changing actual target identity")
    check(observation.source_visible and observation.source_materials>0 and observation.outcome.is_empty() \
        and observation.condition_id.is_empty() and not observation.HP_or_save_solver,label+" actual preserved proclamation draws without a guessed HP tier or condition owner")
func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Original independent two-seat four actual Vitriolic initial contacts and completed Divine proclamation; exact native source/setter/recipient geometry, isolated framebuffer output, real published views, seeking/looping/teardown. Residue ticks, recipient tiers, performance and human acceptance remain separate."}
    FileAccess.open("res://.runtime/native-finite-observed-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_FINITE_OBSERVED ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
