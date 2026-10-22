extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
## Real single-preview replay controls and independently selected faction journals.
const Studio=preload("res://studio/studio.gd")
const Recording=preload("res://studio/recording.gd")
const BodyGeometryProof=preload("res://presentation/character_geometry.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
var prefix_ordinals:Dictionary={}
var report_path="res://generated/studio_replay_native_checks.json"
var require_body_geometry:bool=false
var require_authored_action_bodies:bool=false
var required_action_bodies:Array=[]
## Optional requirements from this exact original scenario; ordinary callers stay unchanged.
var required_grant_sources:Array=[]
var required_native_results:Array=[]
var body_geometry_rows:Dictionary={}
func _initialize()->void:run.call_deferred()
func register_case(studio:Control,record:Dictionary)->void:
    # A durable original can share its scenario ID with the Library's later
    # recording. Studio selection owns actual journal paths, not that label.
    for perspective in record.perspectives:
        var path=ProjectSettings.globalize_path(perspective.journal).replace("\\","/")
        if not studio.case_records.any(func(existing):return existing.perspectives.any(func(view):return ProjectSettings.globalize_path(view.journal).replace("\\","/")==path)):
            studio.case_records.append(record)
            return
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("REPLAY_NATIVE_FAIL ",label)
func readiness_leaves(world:Node)->Dictionary:
    var renderer=world.component_renderer
    var blood_pending:Array=[]
    for cell in renderer.blood.tiles:
        if not renderer.blood.deposits.has(cell):
            if blood_pending.size()<4:blood_pending.append(cell)
    var spells:Array=[]
    for row in renderer.native_spells.diagnostics.values():
        if spells.size()>=6:break
        spells.append({"id":row.get("id"),"status":row.get("status"),"reason":row.get("reason"),
            "age_ms":row.get("age_ms"),"requested_age_ms":row.get("requested_age_ms")})
    var support=renderer.native_spells._support
    var pending:Dictionary={}
    if world.pending_world!=null:
        var prepared_world=world.pending_world
        pending={"phase":prepared_world.phase,"prepared":prepared_world.prepared,"admitted":prepared_world.admitted,
            "epoch":prepared_world.epoch,"quarter":prepared_world.quarter,"key":prepared_world.boundary.get("preparation_key",[]),
            "actor_binding_cursor":prepared_world.binding_cursor,"actor_binding_total":prepared_world.actor_bindings.size(),
            "actor_binding_path":prepared_world.actor_bindings[prepared_world.binding_cursor].value.get("path","") if prepared_world.binding_cursor<prepared_world.actor_bindings.size() else "",
            "blood_rows":prepared_world.result.get("blood_rows",{}).size(),"blood_handles":prepared_world.blood_preparation.handles.size(),
            "blocked_actor":prepared_world.blocked_actor.duplicate(true),"blocked_source":prepared_world.blocked_source.duplicate(true),
            "native_phase_usec":prepared_world.phase_usec.duplicate()}
        if prepared_world.binding_cursor<prepared_world.actor_bindings.size():
            var binding:Dictionary=prepared_world.actor_bindings[prepared_world.binding_cursor];var value:Dictionary=binding.value
            var missing:Array=[]
            if not world.textures.has(value.path):missing.append(value.path)
            for path in value.get("geometry",{}).get("textures",{}).values():
                if not world.textures.has(path) and path not in missing:missing.append(path)
            var optical:Dictionary=binding.get("optical",{})
            pending.binding={"actor":binding.get("actor",""),"prepared":not binding.get("prepared",{}).is_empty(),"missing_textures":missing,
                "optical":{"ready":optical.get("ready"),"mask_path":optical.get("mask_path",""),"has_mask":optical.has("mask")}}
        var waiting:Array=[];var ready_count:int=0;var removed_count:int=0;var waiting_count:int=0
        for key in prepared_world.blood_preparation.handles:
            var record:Dictionary=prepared_world.blood_preparation.handles[key]
            if record.get("removed",false):removed_count+=1;continue
            var held:Dictionary=record.get("handle",{})
            if held.get("ready",false):ready_count+=1;continue
            waiting_count+=1
            if waiting.size()==4:continue
            var callback:Callable=held.get("draw_callback",Callable())
            waiting.append({"key":key,"ready":held.get("ready",false),"slot":held.get("slot",-1),"generation":held.get("generation",-1),
                "borrowed":record.get("borrowed",false),"draw_wait":held.get("draw_wait",-1),
                "draw_wait_owned":renderer.blood._draw_waits.has(held.get("draw_wait",-1)),
                "callback_connected":callback.is_valid() and RenderingServer.frame_post_draw.is_connected(callback)})
        pending.blood={"ready":renderer.blood.ready,"resources_ready":renderer.blood.resources_ready,
            "ready_handles":ready_count,"removed_handles":removed_count,"pending_handles":waiting_count,
            "draw_waits":renderer.blood._draw_waits.size(),"pending_examples":waiting}
        # Inspect the existing exclusion owner without polling/joining a job,
        # requesting resources or acquiring source mutation from a diagnostic.
        var admission=renderer.BloodRenderer.Admission
        var loading_progress:Array=[]
        var loading_status:int=ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
        if not admission.loading_path.is_empty():
            loading_status=ResourceLoader.load_threaded_get_status(admission.loading_path,loading_progress)
        var material_job:Dictionary=admission._material_job
        var receiver_cache:Dictionary=renderer.native_spells._resource_cache
        var blood_pool:Variant=renderer.blood._pool_world
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
            "receiver_preparation_revision":renderer.native_spells.preparation_revision,
            "pool_world_valid":is_instance_valid(blood_pool),"pool_is_current_world":is_same(blood_pool,world),
            "initial_world":prepared_world.initial,"frame_budget_used_usec":world.preparation_admission.used_usec,
            "frame_budget_limit_usec":world.preparation_admission.limit_usec}
    var required_missing:Array=[];var missing_count:int=0
    for path in world.media_plan.get("required",{}):
        var requested:Dictionary={};requested[path]=world.media_plan.required[path]
        if world.MediaWarmup.ready(world.media_warmup,requested):continue
        missing_count+=1
        if required_missing.size()<8:required_missing.append({"path":path,"texture_present":world.textures.has(path),"image_present":world.source_images.has(path)})
    return {"pending_world":pending,"required_missing":{"count":missing_count,"examples":required_missing},
        "display_ms":world.timeline.display_ms,"state":not world.timeline.state.is_empty(),
        "world_epoch":world.world_prepare_epoch,"timeline_epoch":world.timeline.initialization_revision,
        "world_revision":world.world_revision,"timeline_world_revision":world.timeline.world_revision,
        "waiting_world":world.timeline.waiting_for_world,"component_ready":renderer.ready,
        "blood_ready":renderer.blood.ready,"blood_unprepared_tiles":blood_pending,
        "native_ready":renderer.native_spells.ready,"native_samples":spells,"native_preparation":renderer.native_spells.preparation_state,
        "native_support_ready":support.ready if support!=null else true,
        "native_support_issues":support.issues.slice(0,3) if support!=null else [],
        "hits_ready":renderer.native_hits.ready,"hit_pending":renderer.native_hits.pending_occurrences.slice(0,3),
        "media":world.media_gate,"errors":world.presentation_errors.slice(0,3)}
## Progress/failure reads of the existing owners. Never call a preparation or
## readiness method here: playback_prepared/_media_ready advance admission.
func installation_diagnostics(studio:Control)->Dictionary:
    var result:Dictionary={"process_frame":Engine.get_process_frames(),"studio_processing":studio.is_processing(),
        "installing":studio.installing,"seek_generation":studio.seek_generation,
        "restore_generation":studio.worker_generation,"installation_generation":studio.installation_generation,
        "generation_matches":studio.installation_generation==studio.seek_generation,
        "last_evaluated_gate":studio.preparation_measurement.get("candidate_gate","not_evaluated"),
        "last_gate_frame":studio.preparation_measurement.get("candidate_gate_frame",-1),
        "preparing_loop":studio.preparing_loop,"loop_enabled":studio.loop_enabled,
        "loop_start":studio.loop_start,"loop_end":studio.loop_end,"requested_seek":studio.requested_seek,
        "displayed_clock_ms":studio.world.timeline.display_ms,"displayed_paused":studio.world.timeline.paused}
    if studio.candidate_world==null:return result
    var owner:Node3D=studio.candidate_world
    var startup:Dictionary=owner.native_startup
    var cached:Dictionary={}
    for key in ["ready","pending","required_total","completed","total","background_pending"]:
        if startup.has(key):cached[key]=startup[key]
    cached.errors=startup.get("errors",[]).slice(0,3)
    cached.background_errors=startup.get("background_errors",[]).slice(0,3)
    result.native_startup_cached=cached
    result.native_startup_owner=owner.NativeStartup.profile_state()
    result.native_startup_requested_ms=owner.native_startup_requested_ms
    result.native_startup_background=owner.native_startup_background
    result.native_startup_plan_size=owner.native_startup_plan.size() if owner.native_startup_plan!=null else -1
    result.candidate={"process_mode":owner.process_mode,"processing":owner.is_processing(),
        "publication_failed":owner.publication_failed,"publishes_receiving":owner.publishes_receiving,
        "media_initial_ready":owner.media_initial_ready,"media_metadata_ready":owner.media_metadata_ready,
        "media_issue":owner.media_issue,"media_plan_errors":owner.media_plan.get("errors",[]).slice(0,3),
        "quarter":owner.quarter,"world_quarter":owner.world_quarter,"requested_quarter":owner.requested_quarter,
        "viewport_size":[studio.candidate_viewport.size.x,studio.candidate_viewport.size.y],
        "viewport_update_mode":studio.candidate_viewport.render_target_update_mode,
        "camera_size":owner.camera.size,"camera_keep_aspect":owner.camera.keep_aspect,
        "camera_focus":[owner.camera_focus.x,owner.camera_focus.y,owner.camera_focus.z],
        "native_hit_material":owner.native_spell_hit_material,"playback_speed":owner.playback_speed,
        "wall_mode":owner.wall_mode,"grid_visible":owner.grid_visible,
        "budget_used_usec":owner.preparation_admission.used_usec,"budget_limit_usec":owner.preparation_admission.limit_usec}
    var reference:Node3D=studio.world
    result.reference={"quarter":reference.quarter,"world_quarter":reference.world_quarter,"requested_quarter":reference.requested_quarter,
        "viewport_size":[studio.viewport.size.x,studio.viewport.size.y],
        "preview_row_size":[studio.preview_row.size.x,studio.preview_row.size.y],
        "camera_size":reference.camera.size,"camera_keep_aspect":reference.camera.keep_aspect,
        "camera_focus":[reference.camera_focus.x,reference.camera_focus.y,reference.camera_focus.z],
        "native_hit_material":reference.native_spell_hit_material,"playback_speed":reference.playback_speed,
        "wall_mode":reference.wall_mode,"grid_visible":reference.grid_visible,
        "same_directory":studio.candidate_index.directory==studio.active_directory,
        "same_mutes":owner.presentation_mutes==reference.presentation_mutes,
        "same_solo":owner.presentation_solo==reference.presentation_solo,
        "follow_actor_id":studio.follow_actor_id}
    return result

func settle(studio:Control,requested_time:float=-1.0,requested_directory:String="")->bool:
    var diagnostic_at:int=Time.get_ticks_msec()+3000
    var diagnostic_emitted:bool=false
    var deadline=Time.get_ticks_msec()+90000
    while (studio.index.is_empty() or studio.loader!=null or (not studio.preparing_loop and (studio.seeker!=null or studio.installing or studio.requested_seek>=0))) and Time.get_ticks_msec()<deadline:
        if not diagnostic_emitted and Time.get_ticks_msec()>=diagnostic_at:
            diagnostic_emitted=true
            if studio.candidate_world!=null:print("STUDIO_WAIT_DIAGNOSTIC ",JSON.stringify({"requested_ms":requested_time,"candidate":readiness_leaves(studio.candidate_world),"installation":installation_diagnostics(studio)}))
        await process_frame
    var ready=not studio.index.is_empty() and studio.loader==null and (studio.preparing_loop or (studio.seeker==null and not studio.installing and studio.requested_seek<0))
    ready=ready and not studio.status.text.begins_with("Candidate rejected") and not studio.status.text.begins_with("Recording rejected")
    ready=ready and studio.world.presentation_errors.is_empty() and studio.world.media_issue.is_empty()
    if ready and requested_time>=0:ready=is_equal_approx(studio.world.timeline.display_ms,requested_time)
    if ready and not requested_directory.is_empty():ready=studio.active_directory==requested_directory
    if not ready:
        var details:Dictionary={"requested_ms":requested_time,"status":studio.status.text,"replay":studio.replay_diagnostics(),"installation":installation_diagnostics(studio)}
        if studio.candidate_world!=null:
            details.candidate=readiness_leaves(studio.candidate_world)
        evidence.append({"installation_failure":details})
        print("STUDIO_INSTALLATION_DIAGNOSTIC ",JSON.stringify(details))
    check(ready,"Single preview installation ready: "+studio.status.text)
    return ready
func prefix_shape(timeline)->Dictionary:
    var commits:Array=[]
    for commit in timeline.current.get("commits",[]):
        commits.append({"at_ms":commit.at_ms,"absolute_ms":timeline.group_start_ms+commit.at_ms,
            "fields":commit.delta.keys(),"event":commit.get("event_uuid","")})
    return {"display_ms":timeline.display_ms,"group_start_ms":timeline.group_start_ms,"sequence":timeline.sequence,
        "completed":timeline.completed_group_count,"commit_index":timeline.commit_index,"world_revision":timeline.world_revision,
        "current":timeline.current.get("id",""),"duration_ms":timeline.current.get("duration_ms",0.0),"commits":commits,
        "queued":timeline.queue.size(),"cursor":timeline.state.get("reducer_cursor")}
func prefix_diff(actual:Variant,expected:Variant,path:String,output:Array)->void:
    if actual==expected or output.size()>=32:return
    if actual is Dictionary and expected is Dictionary:
        var keys:Array=actual.keys()
        for key in expected:
            if not actual.has(key):keys.append(key)
        for key in keys:prefix_diff(actual.get(key),expected.get(key),path+"/"+str(key),output)
    elif actual is Array and expected is Array and actual.size()==expected.size():
        for i in actual.size():prefix_diff(actual[i],expected[i],path+"/"+str(i),output)
    else:output.append({"path":path,"actual":actual,"expected":expected})
func yielded_recorded_prefix(index:Dictionary,timeline)->RefCounted:
    # Live publication intentionally yields after one world cut. A clock at a
    # group endpoint can therefore name several different ordered prefixes.
    var count:int=timeline.completed_group_count
    if not timeline.current.is_empty() or count<=0 or count>=index.groups.size():return null
    var item:Dictionary=index.groups[count-1]
    if timeline.display_ms!=item.start_ms+float(item.group.duration_ms):return null
    var next:Dictionary=index.groups[count]
    if float(next.start_ms)>timeline.display_ms or timeline.queue.is_empty() or timeline.queue[0].id!=next.group.id:return null
    var world_cut:bool=item.group.commits.any(func(commit):return float(commit.at_ms)==float(item.group.duration_ms) and timeline._world_delta(commit.delta))
    world_cut=world_cut or float(item.group.duration_ms) in item.group.get("actor_structure_times",[])+item.group.get("actor_effect_times",[]) or not item.group.get("staged_tiles",{}).is_empty()
    if not world_cut and not timeline.waiting_for_media and not timeline.waiting_for_world:return null
    return Recording.restore_boundary(index,count-1,item.group.commits.size())
func verify_prefix(studio:Control,label:String,allow_atomic_yield:bool=false)->void:
    for pane in [{"world":studio.world,"perspective_id":studio.active_perspective}]:
        var actual=pane.world.timeline
        var index:Dictionary=studio.case_bundle.views[pane.perspective_id]
        var expected=Recording.restore(index,actual.display_ms)
        var exact_yield:RefCounted=yielded_recorded_prefix(index,actual) if allow_atomic_yield else null
        if exact_yield!=null:expected=exact_yield
        var prior:Dictionary=prefix_ordinals.get(actual.get_instance_id(),{})
        if not prior.is_empty():check(actual.completed_group_count>=prior.ordinal,label+": published source ordinals never regress")
        prefix_ordinals[actual.get_instance_id()]={"ordinal":actual.completed_group_count}
        for i in actual.completed_groups.size():
            var ordinal:int=actual.completed_group_count-actual.completed_groups.size()+i
            check(ordinal>=0 and ordinal<index.groups.size() and actual.completed_groups[i].id==index.groups[ordinal].group.id,
                label+": completed source groups preserve every recorded ID in order")
        if actual.state!=expected.state or actual.completed_group_count!=expected.completed_group_count or actual.commit_index!=expected.commit_index or actual.current.get("id","")!=expected.current.get("id",""):
            var difference:Array=[];prefix_diff(actual.state,expected.state,"",difference)
            var failure:Dictionary={"failure":"prefix","label":label,"directory":studio.active_directory,"perspective":pane.perspective_id,
                "actual":prefix_shape(actual),"expected":prefix_shape(expected),"difference":difference}
            evidence.append(failure)
            FileAccess.open("res://.runtime/studio-prefix-failure.json",FileAccess.WRITE).store_string(JSON.stringify(failure,"  "))
        check(actual.state==expected.state,label+": "+pane.perspective_id+" owns exact admitted prefix")
        check(actual.completed_group_count==expected.completed_group_count and actual.commit_index==expected.commit_index and actual.current.get("id","")==expected.current.get("id",""),label+": "+pane.perspective_id+" owns the exact ordered source cut")
        check(pane.world.session==null,label+": no live Session")
        for id in actual.state.actors:
            var disclosed=Studio.Play.WorldRows.visible_actor(actual.state.actors[id],actual.state,actual.staged_actors().has(id))
            check(disclosed or not pane.world.visual_actors.has(id),label+": undisclosed actor absent from native pane")
    check(studio.world.component_renderer.audio.enabled,label+": selected faction is audible")
    check(studio.world.presentation_errors.is_empty() and not studio.world.publication_failed,label+": displayed native owner has no publication errors")
    for owner in [studio.world]:
        var members={}
        for entry in owner.static_entries:members[entry.node.get_instance_id()]=true
        check(owner.static_complete_order.all(func(entry):return is_instance_valid(entry.node) and members.has(entry.node.get_instance_id())),label+": cached order owns only current live members")
    for owner in [studio.candidate_world,studio.spare_world]:
        if owner!=null:check(not owner.component_renderer.audio.enabled,label+": private primary silent")
    if require_body_geometry:verify_body_geometry(studio,label)

func verify_body_geometry(studio:Control,label:String)->void:
    var world=studio.world
    var admission:Dictionary=world.catalog_cache.get(BodyGeometryProof.BodySources.KEY,{})
    var index:Resource=admission.get("index")
    check(index!=null,label+": body proof uses the actually admitted source index")
    if index==null:return
    check(world.character_light_profile==Studio.Play.RenderSettings.DEFAULT_PROFILE,
        label+": source geometry remains active under the ordinary default normal profile")
    var staged:Dictionary=world.timeline.staged_actors()
    for actor_id in world.visual_actors:
        var visual:Dictionary=world.visual_actors[actor_id]
        var rig_id:String=str(visual.row.rig)
        if rig_id==index.root_rig:continue
        for entry in visual.entries:
            if entry.role=="shadow" or entry.actor_layer.slot!="body" \
                or not entry.actor_layer.get("effect",{}).is_empty() \
                or not world.component_renderer._entry_visible(world,entry):continue
            var material:ShaderMaterial=entry.material
            if float(material.get_shader_parameter("condition_alpha"))<=0.0 or float(material.get_shader_parameter("layer_alpha"))<=0.0:continue
            var path:String=str(entry.get("texture_path",""))
            var descriptor:Dictionary=BodyGeometryProof.BodySources.descriptor(path,"body",world.catalog_cache)
            var source:Dictionary=descriptor.get("geometry",{})
            # Whole-body source packets declare their own profile table. A
            # color-only rig or modular part does not acquire invented optics.
            if source.is_empty() or not source.has("normal_profiles"):continue
            var owner:Array=index.source_owners.get(path,[])
            var layer:Resource=BodyGeometryProof.BodySources.prepared_layer(str(owner[0]),world.catalog_cache) if not owner.is_empty() else null
            var clip:String=str(world.playbacks[actor_id].clip)
            var frame_key:Array=entry.get("bound_frame_key",[])
            check((world.timeline.state.actors.has(actor_id) or staged.has(actor_id))
                and layer!=null and layer.rig_id==rig_id and frame_key.size()>=3
                and Recording.Characters.source_path(entry.actor_layer,clip,str(frame_key[2]))==path,
                label+": actual visible actor/rig/clip owns this exact whole-body source: "+str(actor_id)+" "+rig_id+" "+clip)
            check(not str(source.get("status","")).is_empty() and entry.get("geometry_status")==source.status
                and material.get_shader_parameter("has_component_geometry")==true
                and material.get_shader_parameter("use_component_depth")==true
                and material.get_shader_parameter("use_component_normals")==true,
                label+": declared body depth and normals remain enabled: "+rig_id+" "+clip)
            var profile:String=str(source.get("normal_profile",""))
            if profile.is_empty():profile=world.character_light_profile
            var paths:Dictionary={}
            for field in BodyGeometryProof.PARAMETERS:
                var texture_path:String=str(descriptor.get("normal_paths",{}).get(profile,"")) if field=="normal" \
                    else str(source.get("_source_root","res://assets")).path_join(str(source.get("files",{}).get(field,"")))
                var parameter:String=BodyGeometryProof.PARAMETERS[field]
                paths[parameter]=texture_path
                check(not texture_path.is_empty() and world.textures.has(texture_path)
                    and entry.get("geometry_paths",{}).has(texture_path)
                    and is_same(material.get_shader_parameter(parameter),world.textures[texture_path]),
                    label+": actual body material binds its exact admitted "+field+" texture: "+rig_id+" "+clip)
            var ground:Variant=source.get("optical_ground_pixels")
            if ground!=null:
                check(entry.has("geometry_ground_pixels") and is_equal_approx(float(entry.geometry_ground_pixels),float(ground)),
                    label+": declared optical ground, including zero, survives binding: "+rig_id+" "+clip)
            var key:String=JSON.stringify([studio.active_perspective,actor_id,rig_id,clip,path,profile])
            body_geometry_rows[key]={"perspective":studio.active_perspective,"actor_uuid":actor_id,"rig":rig_id,"clip":clip,
                "path":path,"geometry_status":entry.get("geometry_status"),"global_normal_profile":world.character_light_profile,
                "source_normal_profile":source.get("normal_profile",""),"effective_normal_profile":profile,
                "declared_optical_ground_pixels":ground,"bound_optical_ground_pixels":entry.get("geometry_ground_pixels"),
                "texture_paths":paths,"scope":"Actual visible source-declared whole-body material/companion preservation; not lighting parity, pixel-difference evidence or human artwork approval."}

## Optional companion to the Action gesture proof: the catalog identity may
## actually publish AttackFact. Read its real original; never manufacture an
## Action or use one recorded roll as an outcome requirement for another run.
func authored_attack_bodies(index:Dictionary,scenario:Dictionary,label:String)->Array:
    var result:Array=[]
    var root_source:Resource=load("res://authoring/abilities.tres")
    var selected:Array=[]
    var declared_creatures:Array=scenario.get("subjects",{}).get("creature",[])
    for behavior in scenario.get("required_behaviors",[]):
        var path:String=str(root_source.sections.get("attacks",{}).get(behavior,""))
        if path.is_empty():continue
        var entry:Resource=load(path)
        # Only an explicit creature/own-rig assignment belongs to this control;
        # generic attack templates and effect-bodied finite strikes keep theirs.
        if entry.variants.any(func(variant):return variant.body!=null and variant.body.enabled \
                and not variant.body.rig.is_empty() \
                and variant.match.get("creatureIds",[]).any(func(creature):return creature in declared_creatures)):
            selected.append({"behavior":behavior,"path":path,"entry":entry})
    if selected.is_empty():return result
    var journal=Recording.Journal.new()
    var opened:Dictionary=journal.open(index.directory,true,false)
    check(opened.ok,label+": actual Attack-body original selects its recorded producer contract")
    if not opened.ok:return result
    var packets:Dictionary={}
    for chosen in selected:
        var events:Array=[];var tracks:Dictionary={};var witness:Dictionary={}
        var rig_id:String="";var clip_name:String="";var assignment:String="";var component_source:String=""
        for item in index.groups:
            for event in item.group.events:
                if event.kind!="attack" or event.behavior_id!=chosen.behavior or event.phase!="completion" or "canceled" in event.reasons:continue
                var sequence:int=int(event.sequence)
                if not packets.has(sequence):
                    packets[sequence]=journal.decode_record(sequence,FileAccess.get_file_as_bytes(index.directory.path_join("%016d.json"%sequence)))
                var packet:Dictionary=packets[sequence]
                check(packet.ok,label+": actual completed Attack bytes pass the existing strict recorded decoder")
                if not packet.ok:continue
                var same_identity:bool=packet.value.cursor.sequence==sequence
                for field in ["game_id","game_epoch","audience_id"]:
                    same_identity=same_identity and packet.value.cursor[field]==index.identity[field]
                check(same_identity,label+": Attack operands belong to this exact recorded audience/cursor")
                if not same_identity:continue
                var nodes:Array=[]
                for lineage in packet.value.lineages:
                    for node in lineage.events:
                        if str(node.occurrence)==str(event.event_uuid):nodes.append(node)
                check(nodes.size()==1,label+": compiled Attack occurrence has exactly one original public node")
                if nodes.size()!=1:continue
                var node:Dictionary=nodes[0];var fact:Dictionary=node.get("fact",{})
                var actual:bool=node.phase=="completion" and not node.get("canceled",false) and fact.get("kind")=="attack" \
                    and fact.get("behavior_id")==chosen.behavior and fact.get("source_entity_uuid")==event.actor_uuid
                check(actual,label+": native Attack kind/source/behavior remain actual public operands")
                if not actual:continue
                var matching:Array=item.group.actor_tracks.filter(func(track):return track.source_event_uuid==event.event_uuid \
                    and track.actor_uuid==fact.source_entity_uuid and track.activity=="attack" and float(track.duration_ms)>0.0)
                check(not matching.is_empty(),label+": completed actual Attack has its compiled body track")
                if matching.is_empty():continue
                var actor:Dictionary=matching[0].presentation_actor
                var recipe:Dictionary=Recording.Compiler.Authoring.attack(fact,actor,index.cache)
                var variants:Array=chosen.entry.variants.filter(func(variant):return variant.id==recipe.get("selected_variant",""))
                check(variants.size()==1,label+": exact original Attack and captured actor select one typed variant")
                if variants.size()!=1:continue
                var variant:Resource=variants[0]
                var actual_rig:String=Recording.Compiler.Authoring.rig_id(actor,index.cache)
                check(actor.uuid==fact.source_entity_uuid and variant.body!=null and variant.body.enabled \
                    and not variant.body.rig.is_empty() and variant.body.rig==actual_rig \
                    and Recording.Characters.content_id(actor.get("creature_content_ref")) in variant.match.get("creatureIds",[]) \
                    and fact.attack_source_kind in variant.match.get("sourceKinds",[]) \
                    and fact.source_item_id in variant.match.get("sourceItemIds",[]) \
                    and fact.weapon_slot in variant.match.get("weaponSlots",[]) \
                    and recipe.get("actor",{}).get("enabled",false) and recipe.actor.clip==variant.body.clip,
                    label+": actual captured creature/rig/item/source-kind/slot owns the selected Attack body")
                if variant.body==null or variant.body.rig!=actual_rig or not recipe.get("actor",{}).get("enabled",false):continue
                var source:String=chosen.path+"::variants/"+str(chosen.entry.variants.find(variant))+"/body/clip"
                var declared_source:String="catalog/rigs.json:"+actual_rig+".clips."+str(recipe.actor.clip)
                if assignment.is_empty():
                    assignment=source;component_source=declared_source;rig_id=actual_rig;clip_name=recipe.actor.clip
                check(assignment==source and component_source==declared_source,label+": one exact typed body assignment owns this original's required Attack")
                events.append(event.event_uuid)
                for track in matching:
                    var body:Array=event.components.filter(func(component):return component.kind=="body" \
                        and component.trace_track_id==track.trace_track_id and component.source==declared_source)
                    check(track.rig==actual_rig and track.clip==recipe.actor.clip and not body.is_empty(),
                        label+": compiled Attack track retains its actual body-component rig/clip source")
                    if track.rig!=actual_rig or track.clip!=recipe.actor.clip or body.is_empty():continue
                    tracks[track.trace_track_id]={"source_event_uuid":event.event_uuid,"actor_uuid":event.actor_uuid,
                        "start_ms":float(item.start_ms)+float(track.start_ms),"duration_ms":track.duration_ms}
                witness[event.event_uuid]={"sequence":sequence,"fact_kind":fact.kind,"source_entity_uuid":fact.source_entity_uuid,
                    "target_entity_uuid":fact.target_entity_uuid,"source_item_id":fact.source_item_id,"source_item_uuid":fact.source_item_uuid,
                    "attack_source_kind":fact.attack_source_kind,"weapon_slot":fact.weapon_slot,"attack_outcome":fact.attack_outcome,
                    "captured_creature_ref":actor.get("creature_content_ref"),"captured_rig":actual_rig,"selected_variant":recipe.selected_variant}
        check(not events.is_empty() and not tracks.is_empty(),label+": optional Attack proof has real completed original/body occurrences: "+str(chosen.behavior))
        result.append({"behavior_id":chosen.behavior,"fact_kind":"attack","rig":rig_id,"clip":clip_name,"source":assignment,
            "body_component_source":component_source,"original_events":events,"compiled_tracks":tracks,"actual_attack_operands":witness,
            "scope":"Actual decoded Attack and captured source select the indexed typed body variant. Typed assignment and actual trace rig clip are distinct source carriers; visible postdraw binding is checked separately."})
    return result

func observed_attack_body(world:Node,requirement:Dictionary,observed:Dictionary)->void:
    if observed.has(requirement.behavior_id):return
    for actor_id in world.displayed_samples:
        var sample:Dictionary=world.displayed_samples[actor_id]
        var track_id:String=str(sample.get("trace_track_id",""))
        if not requirement.compiled_tracks.has(track_id) or sample.clip!=requirement.clip:continue
        var binding:Dictionary=requirement.compiled_tracks[track_id]
        if str(binding.actor_uuid)!=str(actor_id) or sample.source_event_uuid!=binding.source_event_uuid or not world.playbacks.has(actor_id):continue
        var submitted:Array=world.timeline.trace.tracks.get(track_id,[]).filter(func(row):return row.row.kind=="attack" \
            and row.component.kind=="body" and row.component.source==requirement.body_component_source \
            and row.component.status=="presented" and row.component.sample_count>0)
        if submitted.is_empty():continue
        var visual:Dictionary=world.visual_actors.get(actor_id,{})
        if visual.is_empty() or not visual.valid or visual.row.rig!=requirement.rig or world.playbacks[actor_id].clip!=requirement.clip:continue
        var clip:Dictionary=world.rigs[requirement.rig].clips[requirement.clip]
        var frame:int=mini(int(world.playbacks[actor_id].sample_seconds*clip.fps),int(clip.frames)-1)
        for entry in visual.entries:
            if entry.role=="shadow" or entry.actor_layer.slot!="body" or not entry.actor_layer.get("effect",{}).is_empty() or not world.component_renderer._entry_visible(world,entry):continue
            var material:ShaderMaterial=entry.material
            var path:String=str(entry.get("texture_path",""));var frame_key:Array=entry.get("bound_frame_key",[])
            if path.is_empty() or not world.textures.has(path) or not world.source_images.has(path) or frame_key.size()<3:continue
            if Recording.Characters.source_path(entry.actor_layer,requirement.clip,str(frame_key[2]))!=path:continue
            if int(frame_key[1])!=frame or not is_same(frame_key[0],world.textures[path]) or not is_same(material.get_shader_parameter("sheet"),world.textures[path]):continue
            if float(material.get_shader_parameter("condition_alpha"))<=0.0 or float(material.get_shader_parameter("layer_alpha"))<=0.0:continue
            var rig:Dictionary=world.rigs[requirement.rig];var image:Image=world.source_images[path]
            var uv:Vector4=material.get_shader_parameter("frame_uv")
            var expected:=Vector4(float(frame)*rig.cell_width/image.get_width(),float(rig.facing_rows[frame_key[2]])*rig.cell_height/image.get_height(),float(rig.cell_width)/image.get_width(),float(rig.cell_height)/image.get_height())
            var frame_rect:=Rect2i(frame*int(rig.cell_width),int(rig.facing_rows[frame_key[2]])*int(rig.cell_height),int(rig.cell_width),int(rig.cell_height))
            var layout:Dictionary=entry.get("source_layout",{})
            if not layout.is_empty():
                var admitted:Dictionary=BodyGeometryProof.BodySources.descriptor(path,"body",world.catalog_cache)
                if admitted.get("source_layout",{})!=layout or frame>=layout.frame_rects.size() \
                        or image.get_size()!=Vector2i(layout.sheet_size[0],layout.sheet_size[1]):continue
                var rect:Array=layout.frame_rects[frame]
                frame_rect=Rect2i(rect[0],rect[1],rect[2],rect[3])
                expected=Vector4(float(rect[0])/image.get_width(),float(rect[1])/image.get_height(),float(rect[2])/image.get_width(),float(rect[3])/image.get_height())
                if material.get_shader_parameter("material_cell_size")!=Vector2(layout.cell[0],layout.cell[1]):continue
            if not uv.is_equal_approx(expected):continue
            var original:Image=image.get_region(frame_rect)
            original.convert(Image.FORMAT_RGBA8)
            var pixels:int=0;var bytes:PackedByteArray=original.get_data()
            for at in range(3,bytes.size(),4):
                if bytes[at]>0:pixels+=1
            if pixels==0:continue
            observed[requirement.behavior_id]={"behavior_id":requirement.behavior_id,"fact_kind":"attack","actor_uuid":actor_id,
                "rig":requirement.rig,"clip":requirement.clip,"source":requirement.source,"body_component_source":requirement.body_component_source,
                "source_event_uuid":sample.source_event_uuid,"trace_track_id":track_id,"display_ms":world.timeline.display_ms,
                "bound_frame":frame,"bound_facing":frame_key[2],"source_texture":path,"frame_uv":[uv.x,uv.y,uv.z,uv.w],
                "source_opaque_pixels":pixels,"acknowledged_samples":submitted.map(func(row):return row.component.sample_count).max(),
                "last_acknowledged_display_ms":submitted.map(func(row):return row.component.last_sample_ms).max(),
                "scope":"Actual submitted Attack body and current visible original texture/frame binding; distinct typed assignment/trace sources. Not isolated Hit/Dazed pixels, every occurrence/seat output or artwork approval."}
            break

## Optional proof of the selected rig-specific body assignments in this
## actual original. Compiled tracks and submitted visible bindings stay distinct.
func authored_action_bodies(index:Dictionary,scenario:Dictionary,label:String)->Array:
    var result:Array=[]
    for behavior in scenario.get("required_behaviors",[]):
        var recipe:Dictionary=Recording.Compiler.Authoring.action({"kind":"action","behavior_id":behavior},index.cache)
        if not recipe.get("actor",{}).get("enabled",false) or str(recipe.get("rigId","")).is_empty():continue
        var source:String=Recording.Compiler.Authoring.recipe_source(recipe,"actor/clip",index.cache)
        var tracks:Dictionary={};var events:Array=[]
        for item in index.groups:
            for event in item.group.events:
                if event.kind!="action" or event.behavior_id!=behavior or event.phase!="completion" or "canceled" in event.reasons:continue
                events.append(event.event_uuid)
                var matching:Array=item.group.actor_tracks.filter(func(track):return track.source_event_uuid==event.event_uuid and track.actor_uuid==event.actor_uuid \
                    and track.rig==recipe.rigId and track.clip==recipe.actor.clip and track.get("source","")==source and float(track.duration_ms)>0.0)
                check(not matching.is_empty(),label+": actual intrinsic occurrence compiles its selected own-rig body: "+str(behavior))
                for track in matching:
                    tracks[track.trace_track_id]={"source_event_uuid":event.event_uuid,"actor_uuid":event.actor_uuid,
                        "start_ms":float(item.start_ms)+float(track.start_ms),"duration_ms":track.duration_ms}
        check(not events.is_empty(),label+": selected authored action has real completed original occurrences: "+str(behavior))
        result.append({"behavior_id":behavior,"rig":recipe.rigId,"clip":recipe.actor.clip,"source":source,
            "original_events":events,"compiled_tracks":tracks,"scope":"Compiled original action body selection; native binding is checked separately."})
    result.append_array(authored_attack_bodies(index,scenario,label))
    check(not result.is_empty(),label+": optional action-body proof has actual rig-specific selected assignments")
    return result

func observed_action_bodies(world:Node,required:Array,observed:Dictionary)->void:
    for requirement in required:
        if requirement.get("fact_kind")=="attack":
            observed_attack_body(world,requirement,observed);continue
        if observed.has(requirement.behavior_id):continue
        for actor_id in world.displayed_samples:
            var sample:Dictionary=world.displayed_samples[actor_id]
            var track_id:String=str(sample.get("trace_track_id",""))
            if not requirement.compiled_tracks.has(track_id) or sample.clip!=requirement.clip or sample.get("source","")!=requirement.source:continue
            var binding:Dictionary=requirement.compiled_tracks[track_id]
            if str(binding.actor_uuid)!=str(actor_id) or sample.source_event_uuid!=binding.source_event_uuid or not world.playbacks.has(actor_id):continue
            var submitted:Array=world.timeline.trace.tracks.get(track_id,[]).filter(func(row):return row.component.kind=="body" and row.component.status=="presented" and row.component.sample_count>0)
            if submitted.is_empty():continue
            var visual:Dictionary=world.visual_actors.get(actor_id,{})
            if visual.is_empty() or not visual.valid or visual.row.rig!=requirement.rig or world.playbacks[actor_id].clip!=requirement.clip:continue
            var clip:Dictionary=world.rigs[requirement.rig].clips[requirement.clip]
            var frame:int=mini(int(world.playbacks[actor_id].sample_seconds*clip.fps),int(clip.frames)-1)
            for entry in visual.entries:
                if entry.role=="shadow" or entry.actor_layer.slot!="body" or not entry.actor_layer.get("effect",{}).is_empty() or not world.component_renderer._entry_visible(world,entry):continue
                var material:ShaderMaterial=entry.material
                var path:String=str(entry.get("texture_path",""));var frame_key:Array=entry.get("bound_frame_key",[])
                if path.is_empty() or not world.textures.has(path) or not world.source_images.has(path) or frame_key.size()<3:continue
                if Recording.Characters.source_path(entry.actor_layer,requirement.clip,str(frame_key[2]))!=path:continue
                if int(frame_key[1])!=frame or not is_same(frame_key[0],world.textures[path]) or not is_same(material.get_shader_parameter("sheet"),world.textures[path]):continue
                if float(material.get_shader_parameter("condition_alpha"))<=0.0 or float(material.get_shader_parameter("layer_alpha"))<=0.0:continue
                var rig:Dictionary=world.rigs[requirement.rig];var image:Image=world.source_images[path]
                var uv:Vector4=material.get_shader_parameter("frame_uv")
                var expected:=Vector4(float(frame)*rig.cell_width/image.get_width(),float(rig.facing_rows[frame_key[2]])*rig.cell_height/image.get_height(),float(rig.cell_width)/image.get_width(),float(rig.cell_height)/image.get_height())
                var frame_rect:=Rect2i(frame*int(rig.cell_width),int(rig.facing_rows[frame_key[2]])*int(rig.cell_height),int(rig.cell_width),int(rig.cell_height))
                var layout:Dictionary=entry.get("source_layout",{})
                if not layout.is_empty():
                    var admitted:Dictionary=BodyGeometryProof.BodySources.descriptor(path,"body",world.catalog_cache)
                    if admitted.get("source_layout",{})!=layout or frame>=layout.frame_rects.size() \
                            or image.get_size()!=Vector2i(layout.sheet_size[0],layout.sheet_size[1]):continue
                    var rect:Array=layout.frame_rects[frame]
                    frame_rect=Rect2i(rect[0],rect[1],rect[2],rect[3])
                    expected=Vector4(float(rect[0])/image.get_width(),float(rect[1])/image.get_height(),float(rect[2])/image.get_width(),float(rect[3])/image.get_height())
                    if material.get_shader_parameter("material_cell_size")!=Vector2(layout.cell[0],layout.cell[1]):continue
                if not uv.is_equal_approx(expected):continue
                var original:Image=image.get_region(frame_rect)
                original.convert(Image.FORMAT_RGBA8)
                var pixels:int=0;var bytes:PackedByteArray=original.get_data()
                for at in range(3,bytes.size(),4):
                    if bytes[at]>0:pixels+=1
                if pixels==0:continue
                observed[requirement.behavior_id]={"behavior_id":requirement.behavior_id,"actor_uuid":actor_id,"rig":requirement.rig,
                    "clip":requirement.clip,"source":requirement.source,"source_event_uuid":sample.source_event_uuid,"trace_track_id":track_id,
                    "display_ms":world.timeline.display_ms,"bound_frame":frame,"bound_facing":frame_key[2],"source_texture":path,
                    "frame_uv":[uv.x,uv.y,uv.z,uv.w],"source_opaque_pixels":pixels,
                    "acknowledged_samples":submitted.map(func(row):return row.component.sample_count).max(),
                    "last_acknowledged_display_ms":submitted.map(func(row):return row.component.last_sample_ms).max(),
                    "scope":"Actual selected body track with submitted postdraw acknowledgement and current visible original texture/frame binding. Acknowledged time is separate from current binding time; not isolated scene pixels or artwork approval."}
                break

func save_capture(studio:Control,label:String)->void:
    await RenderingServer.frame_post_draw
    var path="res://.captures/studio/replay-comparison/"+label
    studio.viewport.get_texture().get_image().save_png(path+"-primary.png")
    root.get_texture().get_image().save_png(path+"-studio.png")
## Failure-only actual pose operands. Null current markers are reported as
## null; no neighbouring frame, primary hand or idle actor is substituted.
func socket_operands(world:Node)->Array:
    var rows:Array=[]
    for component in world.displayed_components:
        if not component.get("native_spell",false) and not component.get("requires_pose_socket",false):continue
        var visual:Dictionary=world.visual_actors.get(component.get("actor_uuid"),{})
        if visual.is_empty():continue
        var row:Dictionary=visual.row;var playback:Node=world.playbacks.get(row.id)
        if playback==null:continue
        var rig:Dictionary=world.rigs[row.rig];var clip:Dictionary=rig.clips[playback.clip]
        var frame:int=mini(int(playback.sample_seconds*float(clip.fps)),int(clip.frames)-1)
        var facing:String=world.component_renderer.SpellPlacement.facing(world,row)
        var names:Array=[]
        if component.get("requires_pose_socket",false):names.append(str(component.get("attachment","")))
        var cue:Dictionary=component.get("native_cue",{})
        for endpoint in cue.get("live_endpoints",[]):
            if endpoint.get("actor")=="caster" and endpoint.get("socket") in ["hand","cast_hand"] and "hand" not in names:names.append("hand")
        if names.is_empty():continue
        var sockets:Dictionary={}
        for name in names:
            var points:Array=rig.get("pose_sockets",{}).get(name,{}).get(playback.clip,{}).get(facing,[])
            sockets[name]={"channel_present":rig.get("pose_sockets",{}).has(name),"pose_present":rig.get("pose_sockets",{}).get(name,{}).has(playback.clip),
                "row_count":points.size(),"point":points[mini(frame,points.size()-1)] if not points.is_empty() else null}
        rows.append({"component":component.id,"source_id":component.get("source_id",""),"assignment_source":component.get("assignment_source",component.get("source","")),
            "actor":row.id,"rig":row.rig,"world_facing":row.facing,"quarter":world.quarter,"display_facing":facing,
            "clip":playback.clip,"source_seconds":playback.sample_seconds,"source_frame":frame,"sockets":sockets,
            "component_age_ms":component.age_ms,"cast_recipe":component.get("cast_recipe",{}),"active_body":world.displayed_samples.get(row.id,{})})
    return rows

## Inspect only an already acknowledged item receiver. Public member and
## equipment rows independently anchor the source packet; no provider is called.
func item_surface_witness(world:Node,handle:Dictionary)->Dictionary:
    var component:Dictionary=handle.component
    if not component.get("native_item",false) or not component.get("dynamic_item_effect",false):return {}
    var native=world.component_renderer.native_spells
    if not native.witnesses.any(func(row):return row.id==component.id+":weapon_surface" and row.status=="rendered"):return {}
    var keys:Array=handle.get("weapon_input_key",[])
    if keys.is_empty():return {}
    var binding:Dictionary=keys[0]
    var item:String=str(component.get("item_owner_uuid",""));var effect:String=str(component.get("item_effect_uuid",""))
    var actor:String=str(component.get("actor_uuid",""));var behavior:String=str(component.get("item_effect_member",{}).get("behavior_id",""))
    var members:Array=world.timeline.state.get("items",{}).get(item,{}).get("effects",[]).filter(func(member):return member.get("effect_uuid")==effect and member.get("behavior_id")==behavior)
    var layers:Array=world.timeline.state.get("actors",{}).get(actor,{}).get("visual_loadout",{}).get("layers",[]).filter(func(layer):return layer.get("item_uuid")==item)
    if members.size()!=1 or layers.size()!=1:return {}
    var slot:String=str(layers[0].slot);var render_slot:String="offhand" if slot.ends_with("OFF") else "weapon"
    if slot not in ["MELEE_MAIN","MELEE_OFF","RANGED_MAIN","RANGED_OFF"] \
        or binding.get("item_uuid")!=item or binding.get("effect_uuid")!=effect or binding.get("holder_uuid")!=actor \
        or binding.get("behavior_id")!=behavior or binding.get("equipment_slot")!=slot or binding.get("render_slot")!=render_slot \
        or not binding.get("present",false) or not binding.get("observed",false) or not binding.get("equipped",false) or binding.get("suppressed",true):return {}
    var geometry:Dictionary=handle.get("geometry_input_keys",{})
    if not ["entity_geometry","recipient_geometry"].any(func(channel):return not geometry.get(channel,[]).is_empty()):return {}
    var measured:bool=native.Inputs.measured_weapon_source(handle)
    var points:int=0
    if measured:
        var receiver:RefCounted=handle.occurrence.receiving
        var surface:Dictionary=receiver.current_surface
        if not receiver.admitted_geometry or not surface.get("ready",false) or surface.get("actor")!=actor or surface.get("item_uuid")!=item \
            or surface.get("points",[]).is_empty() or not surface.points.all(func(point):return point.get("slot")==render_slot):return {}
        points=surface.points.size()
    return {"behavior_id":behavior,"item_uuid":item,"effect_uuid":effect,"holder_uuid":actor,
        "equipment_slot":slot,"render_slot":render_slot,"clip":component.native_clip.id,"source":component.source,
        "measured_geometry":measured,"measured_points":points,"draw_witness":component.id+":weapon_surface",
        "scope":"Acknowledged native item draw with exact current public membership/equipment and supplied geometry; not a final-scene pixel difference or art approval."}

## Only the existing native post-draw acknowledgement may qualify this actual
## grant. Canonical UUID/source/recipient and retained lifecycle are independent
## evidence; no ConditionRow, receiver/provider call or source sample is made.
func grant_source_witness(world:Node,index:Dictionary,handle:Dictionary,witness:Dictionary)->Dictionary:
    var component:Dictionary=handle.component
    if not component.get("native_grant",false) or not component.has("lifecycle_phases") \
        or witness.get("status")!="rendered" or witness.get("id")!=component.id: return {}
    var uuid:String=str(component.get("grant_uuid",""));var source:String=str(component.get("grant_source_id",""))
    var actor:String=str(component.get("actor_uuid",""))
    var owner:Dictionary=world.timeline.temporary_hp_owners.get(uuid,{})
    var recipient:Dictionary=world.timeline.state.actors.get(actor,{})
    if uuid.is_empty() or source.is_empty() or owner.is_empty() or recipient.is_empty() \
        or owner.actor_uuid!=actor or component.get("target_uuid")!=actor \
        or owner.grant.get("instance_uuid")!=uuid or owner.grant.get("source_id")!=source \
        or component.get("temporary_hp_grant")!=owner.grant: return {}
    var native=world.component_renderer.native_spells
    var state:Dictionary=native.Persistent.lifecycle_state(component,float(witness.age_ms)/1000.0)
    var phase:String=str(state.phase)
    if not handle.get("rendered_once",false) or int(witness.get("frame",-1))<0 \
        or handle.get("lifecycle_phase")!=phase or handle.get("owner_state",{}).get("phase")!=phase: return {}
    var diagnostic:Dictionary=native.diagnostics.get(component.id,{})
    if diagnostic.get("status")!="rendered" or not diagnostic.get("submitted_bounds",false) \
        or not handle.root.is_visible_in_tree(): return {}
    var supplied:Array=diagnostic.get("input_bindings",{}).get("supplied",[])
    if "owner_state" not in supplied or not supplied.any(func(channel):return channel in ["targets","root_path"]):return {}
    var current:Variant=recipient.get("temporary_hp_grant")
    if phase=="removal":
        if is_inf(float(owner.end_ms)) or component.get("removal_age_ms")==null \
            or current!=null and current.get("instance_uuid")==uuid: return {}
    elif not is_inf(float(owner.end_ms)) or current!=owner.grant or float(recipient.temporary_hp)<=0.0:return {}
    var onset:String=str(owner.source_event_uuid)
    if not owner.initial:
        var matches:Array=[]
        for item in index.groups:
            for commit in item.group.get("commits",[]):
                var fact:Dictionary=commit.get("grant_fact",{})
                if commit.get("event_uuid")==onset and fact.get("kind")=="temporary_hit_points" \
                    and fact.get("entity_uuid")==actor and fact.get("grant")==owner.grant:matches.append(commit)
        if matches.size()!=1:return {}
    return {"grant_uuid":uuid,"grant_source_id":source,"recipient_uuid":actor,"grant":owner.grant,
        "source_event_uuid":onset,"owner_start_ms":owner.start_ms,"owner_end_ms":null if is_inf(float(owner.end_ms)) else owner.end_ms,
        "canonical_temporary_hp":recipient.temporary_hp,"canonical_grant":current,"initial":owner.initial,
        "lifecycle_phase":phase,"source_owner_state":state,"drawn_age_ms":witness.age_ms,"draw_frame":witness.frame,
        "component_id":component.id,"observer_uuid":world.timeline.state.observer_uuid,"source":component.source,"lifecycle_source":component.get("lifecycle_source",""),
        "effect_clip":component.lifecycle_phases[phase].id,
        "scope":"Actual acknowledged bounded native draw with exact canonical grant/recipient and lifecycle phase; not a final-scene pixel difference or artwork approval."}

## Optional exact originals for this invocation; no source/owner is synthesized.
func _native_result_fields(actual:Dictionary,expected:Dictionary)->bool:
    for field in expected:
        if not actual.has(field) or actual[field]!=expected[field]:return false
    return true

## The literal oracle was independently saved from the unchanged public
## result/owner nodes; do not derive it from the components being observed.
func recorded_native_results(index:Dictionary,record:Dictionary,requirements:Array)->Array:
    var result:Array=[]
    for requirement in requirements:
        var same:bool=ProjectSettings.globalize_path(requirement.journal).replace("\\","/")==ProjectSettings.globalize_path(index.directory).replace("\\","/")
        for field in ["commit","protocol_version","player_schema_version","schema_digest"]:
            same=same and record.capture_engine.get(field)==requirement.capture_engine.get(field)
        check(same,record.id+": result requirement preserves exact original journal and captured producer")
        if same:result.append(requirement.duplicate(true))
    return result

func native_result_witness(world:Node,handle:Dictionary,witness:Dictionary)->Dictionary:
    var component:Dictionary=handle.component
    var diagnostic:Dictionary=world.component_renderer.native_spells.diagnostics.get(component.id,{})
    var bindings:Dictionary=diagnostic.get("input_bindings",{})
    if witness.get("id")!=component.id or witness.get("status")!="rendered" or int(witness.get("frame",-1))<0 \
        or float(witness.get("age_ms",-1.0))<0.0 or not handle.get("rendered_once",false) \
        or float(handle.get("drawn_time",-1.0))!=float(handle.get("sample_time",-2.0)) \
        or float(handle.get("sample_time",-1.0))!=float(handle.get("requested_time",-2.0)) \
        or int(handle.get("drawn_frame",-1))<0 \
        or not handle.root.is_visible_in_tree() or diagnostic.get("status")!="rendered" \
        or not diagnostic.get("submitted_bounds",false) or not bindings.get("unavailable",{}).is_empty():return {}
    var operands:Array=[]
    if not component.get("native_constructor_inputs",[]).is_empty():
        # Actual current Constructed occurrence parameters, already passed to
        # its constructor; no getter/sample/setter/provider is invoked here.
        operands=handle.occurrence.parameters.get("operands",[]).duplicate(true)
    return {"clip":component.native_clip.id,"evidence":component.get("native_constructor_evidence",component.get("native_input_evidence",{})).duplicate(true),
        "component_id":component.id,"source_id":component.get("source_id",""),"source_event_uuid":component.get("source_event_uuid",""),
        "source_lineage":component.get("source_lineage",""),"actor_uuid":component.get("actor_uuid",""),"target_uuid":component.get("target_uuid",""),
        "condition_uuid":component.get("condition_uuid"),"spatial_effect_uuid":component.get("spatial_effect_uuid"),
        "condition_response":component.get("condition_response",{}).duplicate(true),"witness_trigger":witness.duplicate(true),
        "acknowledged_age_ms":float(handle.drawn_time)*1000.0,"acknowledged_frame":int(handle.drawn_frame),
        "declared_inputs":Array(handle.clip.get("inputs",[])),"input_bindings":bindings.duplicate(true),
        "input_packets":handle.get("native_input_packets",{}).duplicate(true),"constructor_operands":operands,
        "component_constructor_inputs":component.get("native_constructor_inputs",[]).duplicate(true),
        "submitted_bounds":true,"result_witness":true,
        "scope":"Actual existing postdraw acknowledgement/declared operands; no isolated framebuffer pixels or human artwork approval."}

func verify_native_results(label:String,observed:Dictionary)->void:
    for requirement in required_native_results:
        var matches:Array=observed.values().filter(func(row):return row.get("result_witness",false) and row.clip==requirement.clip \
            and _native_result_fields(row.evidence,requirement.evidence))
        check(matches.size()==1,label+": exact positive original result has one submitted native source witness: "+str(requirement.result_occurrence))
        if matches.size()!=1:continue
        var row:Dictionary=matches[0]
        check(row.source_id==requirement.source_id and str(row.source_event_uuid)==str(requirement.result_occurrence) \
            and str(row.source_lineage)==str(requirement.result_lineage) and row.actor_uuid==requirement.actor_uuid \
            and row.target_uuid==requirement.target_uuid,label+": native source keeps the exact result/lineage/receiving actor")
        check(row.declared_inputs==requirement.declared_inputs,label+": witness uses the selected source's actual declared input contract")
        if requirement.owner_kind=="effective_handler":
            check(Recording.Journal.Protocol._equal(row.evidence.get("attribution",{}),requirement.attribution),label+": drawn passive keeps its exact real effective-handler/emitted-result attribution")
        else:
            var key:String="condition_uuid" if requirement.owner_kind=="condition" else "spatial_effect_uuid"
            check(row.get(key)==requirement.owner_uuid and _native_result_fields(row.condition_response,requirement.response_evidence),
                label+": drawn response retains the exact captured public owner and positive result")
        if requirement.has("constructor_values"):
            var operands:Array=row.constructor_operands.filter(func(operand):return operand.component_path==requirement.constructor_component_path and operand.get("input_field","").is_empty())
            check(row.constructor_operands==row.component_constructor_inputs and operands.size()==1 \
                and _native_result_fields(operands[0].values,requirement.constructor_values),label+": actual constructed source operands preserve original identities")
            check(_native_result_fields(row.input_packets.get("event_input",{}),requirement.event_input) \
                and ["lease_input","event_input","recipient_geometry","targets","owner_visibility"].all(func(channel):return channel in row.input_bindings.get("supplied",[])),
                label+": actual declared setters received the exact positive event and required receiving inputs")
        else:
            check(row.constructor_operands.is_empty() and row.component_constructor_inputs.is_empty() and row.input_packets.is_empty(),
                label+": inputless Incense receiving source has no invented constructor/event/lease input")

func play_once(studio:Control,label:String,source_uses:Array=[],item_effects:Array=[])->void:
    var failures_before:int=failures.size()
    studio.loop_enabled=false;studio._play_study()
    if not await settle(studio):return
    # The fixed allowance bounds preparation overhead, not the recording's
    # natural duration. Long legal originals must reach their actual witness.
    var expected_play_ms:int=ceili(maxf(0.0,studio.index.presentation_end_ms-studio.world.timeline.display_ms)/studio.world.playback_speed)
    var deadline=Time.get_ticks_msec()+expected_play_ms+45000
    var next_sample=0.0;var frames=0;var longest=0.0;var last=Time.get_ticks_usec()
    var observed_native:Dictionary={};var observed_sources:Dictionary={}
    var native_result_diagnostics:Dictionary={}
    var observed_items:Dictionary={}
    var observed_grants:Dictionary={}
    var observed_action_draws:Dictionary={}
    var atomic_targets:Dictionary={};var atomic_seen:Dictionary={}
    if label=="hide-light":
        for i in range(studio.index.groups.size()-1):
            var item:Dictionary=studio.index.groups[i];var next:Dictionary=studio.index.groups[i+1]
            var end:float=item.start_ms+float(item.group.duration_ms)
            if item.group.duration_ms>0 and next.group.duration_ms==0 and next.start_ms==end:
                atomic_targets[i+1]={"at_ms":end,"group":item.group.id}
        check(atomic_targets.size()>=2,label+": real recording includes both positive-duration cuts followed by zero-time tails")
    while not studio.world.timeline.paused and Time.get_ticks_msec()<deadline:
        await process_frame
        var now=Time.get_ticks_usec();longest=maxf(longest,(now-last)/1000.0);last=now;frames+=1
        var timeline=studio.world.timeline
        var native=studio.world.component_renderer.native_spells
        if not required_action_bodies.is_empty():observed_action_bodies(studio.world,required_action_bodies,observed_action_draws)
        if not required_native_results.is_empty():
            for handle in native.handles.values():
                var component:Dictionary=handle.component
                if not required_native_results.any(func(requirement):return requirement.clip==component.native_clip.id):continue
                var id:String=str(component.id)
                var visible:bool=is_instance_valid(handle.get("root")) and handle.root.is_visible_in_tree()
                # Keep actual later hidden refusals as well as visible cuts;
                # unchanged inactive diagnostics must not overwrite that cut.
                var diagnostic:Dictionary=native.diagnostics.get(id,{})
                if native_result_diagnostics.has(id) and not visible and (diagnostic.is_empty() or diagnostic==native_result_diagnostics[id].diagnostic):continue
                if native_result_diagnostics.size()>=4 and not native_result_diagnostics.has(id):continue
                native_result_diagnostics[id]={"component_id":id,"clip":component.native_clip.id,
                    "source_event_uuid":component.get("source_event_uuid",""),"source_lineage":component.get("source_lineage",""),
                    "evidence":component.get("native_constructor_evidence",component.get("native_input_evidence",{})).duplicate(true),
                    "display_ms":timeline.display_ms,"root_visible":visible,"baked":handle.get("baked",false),
                    "effect_kind":handle.get("effect_kind",""),"effect_approach_id":handle.get("effect_approach_id",""),
                    "sample_time":handle.get("sample_time",-1.0),"requested_time":handle.get("requested_time",-1.0),
                    "drawn_time":handle.get("drawn_time",-1.0),"drawn_frame":handle.get("drawn_frame",-1),
                    "rendered_once":handle.get("rendered_once",false),"error":handle.get("error",""),
                    "has_rendered_witness":native.witnesses.any(func(witness):return witness.id==id and witness.status=="rendered"),
                    "diagnostic":diagnostic.duplicate(true),
                    "snapshot_policy":"Latest visible or changed nonempty diagnostic cut, otherwise first sighting; at most four exact required-source candidates."}
        for witness in native.witnesses:
            if witness.status!="rendered" or observed_native.has(witness.id) or not native.handles.has(witness.id):continue
            var component:Dictionary=native.handles[witness.id].component
            var actual:Dictionary=component.get("native_constructor_evidence",component.get("native_input_evidence",{}))
            if actual.is_empty():continue
            if required_native_results.any(func(requirement):return requirement.clip==component.native_clip.id):
                var captured:Dictionary=native_result_witness(studio.world,native.handles[witness.id],witness)
                if captured.is_empty():continue
                observed_native[witness.id]=captured
            else:observed_native[witness.id]={"clip":component.native_clip.id,"evidence":actual}
        if not required_grant_sources.is_empty():
            for witness in native.witnesses:
                if not native.handles.has(witness.id):continue
                var handle:Dictionary=native.handles[witness.id]
                if not required_grant_sources.any(func(requirement):return requirement.source_id==handle.component.get("grant_source_id")):continue
                var observed:Dictionary=grant_source_witness(studio.world,studio.index,handle,witness)
                if not observed.is_empty():observed_grants[str(observed.component_id)+":"+str(observed.lifecycle_phase)]=observed
        if not item_effects.is_empty():
            for handle in native.handles.values():
                var component:Dictionary=handle.component
                var behavior:String=str(component.get("item_effect_member",{}).get("behavior_id",""))
                if behavior not in item_effects or observed_items.has(component.id):continue
                var observed:Dictionary=item_surface_witness(studio.world,handle)
                if not observed.is_empty():observed_items[component.id]=observed
        # Use the existing post-draw acknowledgement and exact native output.
        # Only the requested capability's explicit authored uses are required;
        # an incidental out-of-view native component is not a failed witness.
        var renderer=studio.world.component_renderer
        for id in renderer.handles:
            if observed_sources.has(id):continue
            var handle:Dictionary=renderer.handles[id];var component:Dictionary=handle.component
            if not source_uses.any(func(use):return use.source_id==component.get("source_id") and use.attachment==component.get("attachment") \
                and use.assignment_source==component.get("assignment_source")):continue
            var presenter=handle.node
            if not handle.published or not presenter.error.is_empty() or not presenter.sample_ready \
                or presenter.sampled_age<0.0 or not is_equal_approx(presenter.sampled_age,presenter.requested_age) \
                or presenter._rendered_key!=presenter._requested_render_key:continue
            var submitted:Array=timeline.trace.tracks.get(id,[]).filter(func(binding):return binding.component.sample_count>0 and binding.component.status=="presented")
            if submitted.is_empty():continue
            var pixels:int=0;var captures:Array=[]
            for source_view in presenter.views:
                var shown:bool=handle.draws.any(func(draw):return draw.half==source_view.half \
                    and float(draw.material.get_shader_parameter("opacity"))>0.0 and renderer._entry_visible(studio.world,draw))
                if not shown:continue
                var image:Image=source_view.output.get_texture().get_image()
                image.convert(Image.FORMAT_RGBA8)
                var bytes:PackedByteArray=image.get_data();var count:int=0
                for at in range(3,bytes.size(),4):
                    if bytes[at]>0:count+=1
                pixels+=count
                if count==0:continue
                var path:String="res://.captures/studio/replay-comparison/"+label.replace("/","-")+"-native-"+str(observed_sources.size())+"-"+str(source_view.half)+".png"
                image.save_png(path);captures.append({"half":source_view.half,"pixels":count,"path":path})
            if pixels==0:continue
            observed_sources[id]={"source_id":component.source_id,"attachment":component.get("attachment",""),
                "assignment_source":component.get("assignment_source",""),"authored_use_id":component.get("authored_use_id",""),
                "source_time_window":component.get("source_time_window",{}).duplicate(true),
                "observed_fact":component.get("observed_fact",{}).duplicate(true),"observed_condition":component.get("observed_condition",{}).duplicate(true),
                "generation":presenter._generation,"source_sample_seconds":presenter.sampled_age,"requested_source_seconds":presenter.requested_age,
                "render_key_current":true,"presented_samples":submitted.map(func(binding):return binding.component.sample_count).max(),
                "native_source_pixels":pixels,"captures":captures,
                "scope":"Actual submitted source textures and visible production draw entries, not a final-scene difference or human artwork approval."}
        # A cut is observed on a frame displaying its exact clock with nothing
        # playing. Zero-time groups at that same instant may already have been
        # applied in that frame (nothing to prepare means no frame between).
        for index in atomic_targets:
            if atomic_seen.has(index) or not timeline.current.is_empty() or timeline.completed_group_count<index:continue
            var cut:Dictionary=atomic_targets[index]
            if timeline.completed_group_count>index and timeline.display_ms!=cut.at_ms:continue
            check(timeline.display_ms==cut.at_ms,label+": native atomic cut uses the exact recorded absolute clock")
            verify_prefix(studio,label+" atomic cut "+str(index),true)
            atomic_seen[index]=true
        if studio.world.timeline.display_ms>=next_sample:
            verify_prefix(studio,label+" playback "+str(studio.world.timeline.display_ms),true);next_sample=studio.world.timeline.display_ms+150.0
        if failures.size()>failures_before:break
    if not studio.world.timeline.paused:
        var w=studio.world;var pw=w.pending_world
        print("PLAYBACK_STALL ",JSON.stringify({"display_ms":w.timeline.display_ms,"waiting_media":w.timeline.waiting_for_media,"busy":w.timeline.busy(),
            "world_revision":w.world_revision,"pending":pw!=null,"phase":pw.phase if pw!=null else "",
            "prepared":pw.prepared if pw!=null else false,"media_issue":w.media_issue,"errors":w.presentation_errors.slice(0,3),
            "media_gate":w.media_gate,"rotation":w.rotation_pending(),"socket_operands":socket_operands(w),"readiness":readiness_leaves(w)}))
    check(studio.world.timeline.paused,label+": reaches stop")
    check(atomic_seen.size()==atomic_targets.size(),label+": every requested native atomic cut was observed before ordered zero-time tails drained")
    check(is_equal_approx(studio.world.timeline.display_ms,studio.index.presentation_end_ms),label+": reaches actual recorded endpoint")
    verify_prefix(studio,label+" terminal")
    check(not studio.world.timeline.busy(),label+": selected terminal prefix drained")
    for use in source_uses:
        check(observed_sources.values().any(func(row):return row.source_id==use.source_id and row.attachment==use.attachment \
            and row.assignment_source==use.assignment_source and row.native_source_pixels>0),
            label+": actual submitted positive native source at authored "+str(use.attachment)+": "+str(use.source_id)+" from "+str(use.assignment_source))
    for behavior in item_effects:
        check(observed_items.values().any(func(row):return row.behavior_id==behavior),
            label+": actual item-effect receiver has acknowledged exact membership/holder/slot geometry: "+str(behavior))
    for requirement in required_grant_sources:
        var observed:Array=observed_grants.values().filter(func(row):return row.grant_source_id==requirement.source_id)
        check(not observed.is_empty(),label+": actual grant source has a postdraw UUID/source/recipient witness: "+str(requirement.source_id))
        for phase in requirement.get("phases",[]):
            check(observed.any(func(row):return row.lifecycle_phase==phase),label+": actual grant source has acknowledged "+str(phase)+": "+str(requirement.source_id))
        if requirement.get("retired",false) and not observed.is_empty():
            var ids:Array=observed.map(func(row):return row.grant_uuid)
            check(not studio.world.timeline.state.actors.values().any(func(actor):return actor.get("temporary_hp_grant")!=null and actor.temporary_hp_grant.instance_uuid in ids) \
                and not ids.any(func(uuid):return studio.world.timeline.temporary_hp_owners.has(uuid)) \
                and not studio.world.component_renderer.native_spells.handles.values().any(func(handle):return handle.component.get("native_grant",false) and handle.component.get("grant_uuid") in ids),
                label+": depleted grant has no canonical pool owner, retained lifecycle or native handle after its actual source return")
    for requirement in required_action_bodies:
        check(observed_action_draws.has(requirement.behavior_id),label+": actual selected intrinsic body reaches a submitted visible original binding: "+str(requirement.behavior_id)+" "+str(requirement.clip))
    verify_native_results(label,observed_native)
    if require_body_geometry:check(not body_geometry_rows.is_empty(),label+": at least one actual visible source-declared body has geometry preservation proof")
    evidence.append({"case":label,"frames":frames,"functional_max_frame_ms_including_oracle":longest,"diagnostics":studio.replay_diagnostics(),"audio_primary":studio.world.component_renderer.audio.diagnostics(),"observed_native":observed_native,"required_native_results":required_native_results,"native_result_diagnostics":native_result_diagnostics,
        "required_body_geometry":require_body_geometry,"observed_body_geometry":body_geometry_rows.values() if require_body_geometry else [],
        "required_action_bodies":required_action_bodies,"observed_action_bodies":observed_action_draws,
        "required_native_sources":source_uses,"observed_native_sources":observed_sources,"required_item_effects":item_effects,"observed_item_surfaces":observed_items,"required_grant_sources":required_grant_sources,"observed_grant_sources":observed_grants,"expected_playback_ms":expected_play_ms,"preparation_allowance_ms":45000})
func measure_single(studio:Control)->void:
    studio.loop_enabled=false;studio._play_study()
    if not await settle(studio):return
    var durations:Array=[];var last=Time.get_ticks_usec();var deadline=Time.get_ticks_msec()+30000
    var max_hosts=0;var max_texture_bytes=0;var max_buffer_bytes=0
    # No restore/oracle or pixel readback runs in this measured playback window.
    while not studio.world.timeline.paused and Time.get_ticks_msec()<deadline:
        await process_frame
        var now=Time.get_ticks_usec();durations.append((now-last)/1000.0);last=now
        max_hosts=maxi(max_hosts,studio.get_children().filter(func(child):return child is SubViewport and not child.is_queued_for_deletion()).size())
        max_texture_bytes=maxi(max_texture_bytes,RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED))
        max_buffer_bytes=maxi(max_buffer_bytes,RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED))
    check(studio.world.timeline.paused,"Measured single preview completes without oracle work")
    check(is_equal_approx(studio.world.timeline.display_ms,studio.index.presentation_end_ms),"Measured single preview reaches actual endpoint")
    check(not studio.world.timeline.busy(),"Measured single preview drains every due recorded group")
    check(max_hosts<=2,"Single preview plus prepared/spare host stays bounded at two")
    check(not durations.is_empty(),"Measured replay renders actual playback frames")
    if durations.is_empty():return
    durations.sort()
    evidence.append({"measurement":"native_single_no_oracle","case":studio.active_directory,"frames":durations.size(),"median_frame_ms":durations[durations.size()/2],"p95_frame_ms":durations[int(durations.size()*.95)],"max_frame_ms":durations.back(),"max_texture_bytes":max_texture_bytes,"max_buffer_bytes":max_buffer_bytes,"max_play_hosts":max_hosts,"note":"Whole native process frame interval; includes ordinary replay preparation, excludes test restore oracles and captures."})
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1600,900)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures/studio/replay-comparison"))
    var studio=Studio.new();root.add_child(studio);studio.loop_enabled=false
    if not await settle(studio):await finish(studio);return
    var movement_directory=Fixtures.journal("oa-walk")
    var movement_record:Dictionary=Fixtures.public_case("oa-walk")
    register_case(studio,movement_record)
    if studio.active_directory!=movement_directory or studio.case_bundle.is_empty():
        studio._load(movement_directory)
        if not await settle(studio,0,movement_directory):await finish(studio);return
    check(studio.active_case.get("id")==movement_record.id and studio.case_bundle.get("views",{}).has("amber"),"Movement/OA is an actual registered two-seat Library selection")
    check(studio.replay_diagnostics().panes.size()==1,"Real movement/OA recording opens one rendered audience")
    verify_prefix(studio,"initial movement/OA")
    var duration=float(studio.index.presentation_end_ms)
    for fraction in [.45,.9,.1,.45]:
        studio._seek(duration*fraction)
        if not await settle(studio,duration*fraction):break
        verify_prefix(studio,"Movement/OA seek "+str(fraction))
        check(str(studio.perspective_picker.get_item_metadata(studio.perspective_picker.selected))==studio.active_perspective,"Faction picker survives seek")
        if fraction==.45:await save_capture(studio,"hide-mid")
    studio.select_perspective(studio.active_perspective)
    if failures.is_empty():await play_once(studio,"movement-oa")
    if not failures.is_empty():await finish(studio);return
    # Newest request wins even if an older restore is already running.
    studio._seek(duration*.2);await process_frame;studio._seek(duration*.8)
    if await settle(studio,duration*.8):
        check(is_equal_approx(studio.world.timeline.display_ms,duration*.8),"Superseded seek cannot publish old preview")
        verify_prefix(studio,"newest seek")
    var old_size=studio.world.camera.size;var old_height=studio.viewport.size.y
    studio.split.split_offset+=70
    for frame in 5:await process_frame
    check(is_equal_approx(studio.world.camera.size/float(studio.viewport.size.y),old_size/float(old_height)),"Divider preserves world units per pixel")
    # Use the actual complete study loop; verify the selected reducer on each new pass.
    studio.loop_enabled=true;studio._play_study();await settle(studio)
    var wraps=0;var prior=studio.world.timeline.display_ms;var deadline=Time.get_ticks_msec()+45000
    while wraps<2 and Time.get_ticks_msec()<deadline:
        await process_frame
        var current=studio.world.timeline.display_ms
        check(current<=studio.loop_end+.001,"Loop never advances beyond Out")
        if current<prior-.1:wraps+=1;verify_prefix(studio,"loop pass "+str(wraps))
        prior=current
    check(wraps==2,"Real movement/OA loops twice with independent restores")
    studio._toggle_play();studio.loop_enabled=false
    await measure_single(studio)
    for name in ["hide","hide-light","invisibility","oa-jump-lethal"]:
        var directory=Fixtures.journal(name)
        var record:Dictionary=Fixtures.public_case(name)
        register_case(studio,record)
        studio._load(directory)
        if not await settle(studio,0,directory):break
        check(studio.active_case.get("id")==record.id and studio.case_bundle.get("views",{}).has("amber"),name+": exact original journal is a registered independent audience")
        if not studio.case_bundle.get("views",{}).has("amber"):break
        check(studio.replay_diagnostics().panes.size()==1,name+": one selected renderer")
        if name=="hide":
            verify_prefix(studio,"Hide amber audience")
            studio.select_perspective("blue")
            if not await settle(studio,0,Fixtures.journal(name,"blue")):break
            check(studio.active_perspective=="blue","Hide faction switch installs actual Blue journal")
            verify_prefix(studio,"Hide blue audience")
        if name=="invisibility":
            var cast:Dictionary={}
            var declarations:Array=Fixtures.fact_rows("invisibility","spell").filter(func(row):return row.fact.get("behavior_id")=="spell.see_invisibility")
            for declared in declarations:
                var occurrence:String=str(int(declared.node.occurrence))
                for item in studio.index.groups:
                    if int(item.group.operation_sequence)==int(declared.sequence) and item.group.actor_tracks.any(func(track):return track.source_event_uuid==occurrence) and item.group.components.any(func(component):return component.kind=="sprite_layer" and component.source_event_uuid==occurrence):cast=item;break
                if not cast.is_empty():break
            check(not cast.is_empty(),"Real See Invisibility cast is available for mid-cast seek")
            if not cast.is_empty():
                var middle:float=cast.start_ms+cast.group.duration_ms*.5
                studio._seek(middle)
                if not await settle(studio,middle):break
                verify_prefix(studio,"Invisibility active-cast seek")
                studio._seek(0)
                if not await settle(studio,0):break
        if name=="hide-light":
            var restores=studio.index.rows.filter(func(row):return row.kind=="condition_restore" and row.owner.condition.behavior_id=="condition.hidden" and row.get("source_perspective",studio.active_perspective)==studio.active_perspective)
            check(not restores.is_empty(),"Actual bright-light Hidden removal has a restoration track")
            if not restores.is_empty():
                var row=restores[0]
                for point in [{"offset":-.001,"clip":"CrouchIdle","alpha":.55},{"offset":1.0,"clip":"Idle","alpha":1.0}]:
                    studio._seek(row.transition.condition_removed_ms+point.offset)
                    if not await settle(studio,row.transition.condition_removed_ms+point.offset):break
                    verify_prefix(studio,"light reveal "+str(point.offset))
                    check(studio.world.playbacks.get(row.actor_uuid,{}).get("clip")==point.clip,"Real light reveal chooses "+point.clip)
                    var layers=0
                    for entry in studio.world.visual_actors.get(row.actor_uuid,{}).get("entries",[]):
                        if not entry.node.visible or entry.role=="shadow":continue
                        layers+=1
                        check(is_equal_approx(float(entry.material.get_shader_parameter("condition_alpha")),point.alpha),"Real light reveal applies authored opacity to "+entry.actor_layer.slot)
                    check(layers>1,"Light reveal renders body and equipped layers")
                    await save_capture(studio,"light-reveal-"+("before" if point.offset<0 else "after"))
        await play_once(studio,name)
        await save_capture(studio,name+"-end")
        if name=="invisibility" and failures.is_empty():
            studio.loop_enabled=true;studio._play_study()
            if not await settle(studio):break
            var wrapped:bool=false
            var previous:float=studio.world.timeline.display_ms
            var limit:int=Time.get_ticks_msec()+30000
            while not wrapped and Time.get_ticks_msec()<limit:
                await process_frame
                var now:float=studio.world.timeline.display_ms
                check(now<=studio.loop_end+.001,"Invisibility loop never advances beyond actual Out")
                if now<previous-.1:
                    wrapped=true;verify_prefix(studio,"Invisibility automatic loop restore")
                previous=now
            check(wrapped,"Real Invisibility automatically loops through a fresh exact reducer restore")
            if not studio.world.timeline.paused:studio._toggle_play()
            studio.loop_enabled=false
        if not failures.is_empty():break
    await finish(studio)
func finish(studio:Control)->void:
    evidence.append({"transport":studio.transport_measurements})
    studio.queue_free();await process_frame;await process_frame
    FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence},"  "))
    print("STUDIO_REPLAY_NATIVE ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
