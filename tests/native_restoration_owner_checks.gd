extends "res://tests/native_vampiric_touch_render_checks.gd"
## Existing condition UUID owners retire once; PWH never creates probe copies.
const SOURCE="res://tests/fixtures/schema16/scenarios/power-word-heal-restoration"
const PARALYSIS=["condition.paralyzed","condition.spell.hold_person"]
const PROBES=["high-level-22/power-word-heal/paralyzed_existing","high-level-22/power-word-heal/paralyzed_retire"]
const HEALING=["high-level-22/power-word-heal/full_restoration","high-level-22/power-word-heal/restoration_cross"]
const LIFECYCLE="condition_paralyzed_native"
const CAPTURES="res://.runtime/restoration-owner-captures"
const RecordingMedia=preload("res://studio/recording_media.gd")
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_RESTORATION_OWNER_FAIL ",label)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(CAPTURES)
    var entry:Resource=load("res://authoring/abilities/spells/spell.power_word_heal.tres")
    check(entry.excluded_cues==PackedInt32Array([3,4]),"Only existing/retiring Paralyzed demonstration copies are excluded")
    check(entry.effects[3].clip==PROBES[0] and entry.effects[4].clip==PROBES[1],"Exclusions name the exact delivered duplicate probes")
    check(entry.effects[5].clip.ends_with("/poisoned_existing") and entry.effects[6].clip.ends_with("/poisoned_retire") \
        and 5 not in entry.excluded_cues and 6 not in entry.excluded_cues and entry.status=="partial","Poison and other incomplete input requirements remain explicit")
    for seat in ["amber","blue"]:await owner_seat(seat)
    finish()
func packet(seat:String,sequence:int)->Dictionary:
    return JSON.parse_string(FileAccess.get_file_as_string(SOURCE.path_join(seat).path_join("%016d.json"%sequence)))
func memberships(record:Dictionary,present:bool)->Array:
    var result:Array=[]
    for lineage in record.lineages:
        for node in lineage.events:
            var fact:Variant=node.get("fact")
            if fact==null or fact.get("kind")!="actor_change":continue
            for actor in fact.actors:
                for row in actor.rows:
                    if row.field!="condition" or (row.get("member")!=null)!=present:continue
                    result.append({"actor_uuid":actor.actor_uuid,"condition_uuid":row.condition_uuid,
                        "member":row.get("member"),"occurrence":str(int(node.occurrence))})
    return result
func marker_id(owner_uuid:String)->String:
    return "condition:"+owner_uuid+":lifecycle:"+LIFECYCLE
func emitting(world:Node,owner_uuids:Array)->Array:
    var result:Array=[]
    var native=world.component_renderer.native_spells
    for uuid in owner_uuids:
        var id:String=marker_id(uuid)
        if native.handles.has(id) and native.handles[id].root.is_visible_in_tree():result.append(id)
    return result
func pose(world:Node,actor:String)->Dictionary:
    var visual:Dictionary=world.visual_actors.get(actor,{})
    if visual.is_empty():return {}
    return Play.Conditions.pose(world.timeline.state.actors[actor],visual.row.rig,world.catalog_cache,world.timeline.condition_owners)
func advance(world:Node,at:float,id:String="")->bool:
    var plan:Dictionary={}
    var publications:int=0;var retries:int=0;var last:Dictionary={}
    var began:int=Time.get_ticks_msec();var reported:bool=false
    var deadline:int=began+45000
    while world.timeline.display_ms<at-.000001 and Time.get_ticks_msec()<deadline:
        # Studio's parent _process requests replay preparation before Play's
        # child _process spends the shared frame allowance. A post-draw retry
        # instead arrives after that same allowance has already been spent.
        await process_frame
        if plan.is_empty():plan=world.timeline.replay_plan(at)
        var prepared:bool=world.timeline.replay_prepare(plan)
        if prepared:
            if not world.can_publish_replay_advance(plan):
                # Studio uses this exact retry protocol. A scene preparation
                # can replace its candidate while the immutable plan waits;
                # retaining that rejected plan cannot make it publishable.
                last=advance_diagnostic(world,plan,at,prepared)
                world.timeline.replay_cancel_preparation();plan={};retries+=1
            else:
                if not world.publish_replay_advance(plan):
                    check(false,"Prepared replay publication rejected "+str(advance_diagnostic(world,plan,at,prepared)))
                    return false
                plan={};publications+=1
        else:last=advance_diagnostic(world,plan,at,prepared)
        if not world.presentation_errors.is_empty() or not world.media_issue.is_empty():
            var blocked:Dictionary=last.merged(readiness_diagnostic(world,at),true)
            check(false,"Ordinary replay has an explicit preparation error "+str(blocked))
            evidence.append({"kind":"replay_preparation_error","target_ms":at,"diagnostic":blocked})
            return false
        if not reported and world.timeline.display_ms<at-.000001 and Time.get_ticks_msec()-began>=500:
            var diagnostic:Dictionary=last.merged(readiness_diagnostic(world,at),true)
            evidence.append({"kind":"replay_pending_leaves","at_ms":at,"elapsed_ms":Time.get_ticks_msec()-began,"diagnostic":diagnostic})
            print("NATIVE_RESTORATION_PENDING ",JSON.stringify(diagnostic));reported=true
        await RenderingServer.frame_post_draw
    if not is_equal_approx(world.timeline.display_ms,at):
        check(false,"Ordinary replay publication timeout "+str(last))
        evidence.append({"kind":"replay_publication_timeout","target_ms":at,"publications":publications,"retries":retries,"last":last})
        return false
    check(true,"Ordinary replay publications reach the exact requested cut "+str(at))
    evidence.append({"kind":"replay_publication","target_ms":at,"publications":publications,"retries":retries})
    return await settle(world,id)
func advance_diagnostic(world:Node,plan:Dictionary,target:float,prepared:bool)->Dictionary:
    var pending:Dictionary={}
    if world.pending_world!=null:
        pending={"prepared":world.pending_world.prepared,"phase":world.pending_world.phase,
            "key":world.pending_world.boundary.get("preparation_key",[]),"stale":world.pending_world.stale,
            "admitted":world.pending_world.admitted,"epoch":world.pending_world.epoch,"quarter":world.pending_world.quarter}
    return {"target_ms":target,"display_ms":world.timeline.display_ms,"prepared":prepared,
        "plan_current":world.timeline.replay_plan_current(plan),"plan_ms":plan.get("display_ms"),"plan_base":plan.get("base",[]),
        "current_group":world.timeline.current.get("id",""),"sequence":world.timeline.sequence,
        "waiting_for_media":world.timeline.waiting_for_media,"waiting_for_world":world.timeline.waiting_for_world,
        "timeline_pending":world.timeline.pending_world.get("preparation_key",[]),"scene_pending":pending,
        "errors":world.presentation_errors,"media":world.media_issue}
func readiness_diagnostic(world:Node,target:float)->Dictionary:
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
    var startup:Dictionary=Play.NativeStartup.status(world._native_startup_request(target))
    return {"gates":{"startup":startup.ready,"metadata":world.media_metadata_ready,
        "required_sources":Play.MediaWarmup.ready(media,requirements),"environment":world._environment_sources_ready(),
        "boot":media.boot_complete or (media.boot_started and media.boot_waiting.is_empty()),
        "world_published":world.world_revision>=0,"scene_admitted":world.pending_world!=null and world.pending_world.admitted},
        "components":world.component_renderer.readiness.duplicate(true),"native_preparation":native.preparation_state.duplicate(true),
        "native_failures":native._prepare_failures.duplicate(),"native_required_components":world.component_renderer._native_prepare_components.map(func(component):
            return {"id":component.id,"kind":component.kind,"status":component.get("status"),"clip":component.get("native_clip",{}).get("id"),"handle":native.handles.has(component.id)}),
        "required_count":requirements.size(),"required_missing":missing,
        "decode_jobs":owner.decode_jobs.size(),"pending_decode":owner.pending.size(),"failed_sources":owner.failed.duplicate(),
        "boot_waiting":media.boot_waiting.keys(),"metadata_pending":media.plan_thread!=null,
        "native_startup":{"ready":startup.ready,"pending":startup.pending,"errors":startup.errors},
        "source_lighting_ready":world.source_lighting.native_preparation_ready,
        "frame_budget":world.preparation_admission.duplicate(true)}
func native_owner(world:Node,owner:Dictionary,at:float,phase:String,label:String)->Dictionary:
    var id:String=marker_id(owner.id)
    var native=world.component_renderer.native_spells
    check(native.handles.has(id),label+" original condition UUID owns the prepared native lifecycle")
    if not native.handles.has(id):return {}
    var handle:Dictionary=native.handles[id]
    var state:Dictionary=handle.get("owner_state",{})
    check(state.get("phase")==phase and handle.get("lifecycle_phase")==phase,label+" exact native lifecycle phase is supplied")
    check(is_equal_approx(float(state.get("owner_age_seconds",-1.0)),(at-float(owner.start_ms))/1000.0),label+" private source clock stays on the original condition age")
    if phase=="removal":
        check(is_equal_approx(float(state.get("phase_age_seconds",-1.0)),(at-float(owner.end_ms))/1000.0) \
            and is_equal_approx(float(state.get("removal_started_at_owner_age_seconds",-1.0)),(float(owner.end_ms)-float(owner.start_ms))/1000.0),label+" native fade begins at the actual removal, without a new owner")
    var bindings:Dictionary=native.diagnostics.get(id,{}).get("input_bindings",{})
    check(bindings.get("unavailable",{}).is_empty() and "owner_state" in bindings.get("supplied",[]) \
        and "targets" in bindings.get("supplied",[]),label+" real lifecycle owner and target inputs are supplied")
    check(native.witnesses.any(func(witness):return witness.id==id),label+" actual owner has a native draw-frame witness")
    check(handle.clip.get("inputs",[]).all(func(channel):return channel not in ["lease_input","event_input"]),label+" lifecycle needs no fabricated restoration probe lease/event")
    return handle
func pixels(world:Node,view:SubViewport,handle:Dictionary,label:String)->int:
    world.set_process(false);await frame();await frame()
    var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
    var present:Image=view.get_texture().get_image()
    handle.root.hide();await frame();await frame()
    var hidden:Image=view.get_texture().get_image()
    var count:int=changed(present,hidden)
    check(count>0,label+" hiding only the selected real marker changes framebuffer pixels")
    handle.root.show();await frame();await frame()
    var restored:Image=view.get_texture().get_image()
    check(changed(present,restored)==0,label+" restoring only that owner restores the exact frame")
    check(var_to_bytes(world.timeline.state)==canonical,label+" optical control never changes canonical state")
    check(present.save_png(CAPTURES.path_join(label+"-present.png"))==OK \
        and hidden.save_png(CAPTURES.path_join(label+"-hidden.png"))==OK,label+" paired native owner captures saved")
    world.set_process(true)
    return count
func owner_seat(seat:String)->void:
    var originals:PackedByteArray=FileAccess.get_file_as_bytes(SOURCE.path_join(seat).path_join("0000000000000010.json"))
    var application:Dictionary=packet(seat,6);var removal:Dictionary=packet(seat,10)
    var applied:Array=memberships(application,true).filter(func(row):return row.member.behavior_id in PARALYSIS)
    var removed:Array=memberships(removal,false)
    check(applied.size()==2,seat+" original sequence6 actually applies Paralyzed and Hold Person")
    if applied.size()!=2:return
    var patient:String=str(applied[0].actor_uuid)
    var ids:Array=applied.map(func(row):return str(row.condition_uuid));ids.sort()
    check(applied.all(func(row):return row.actor_uuid==patient) and ids.all(func(uuid):return removed.any(func(row):return row.condition_uuid==uuid and row.actor_uuid==patient)),seat+" original sequence10 removes both exact patient UUIDs")
    var index:Dictionary=Recording.read(SOURCE.path_join(seat))
    check(index.ok,seat+" unchanged original recording compiles")
    if not index.ok:return
    # Studio's loader computes each actual group's closure against its own
    # admitted prefix. A later multi-group replay cut must borrow these exact
    # plans, not ask the ordinary two-group live window to invent them.
    var media_preload:Dictionary=RecordingMedia.plan(index)
    check(media_preload.errors.is_empty(),seat+" ordinary Studio loader prepares exact source metadata for every recorded group")
    if not media_preload.errors.is_empty():return
    Play.Catalog.adopt_snapshot(index.cache,media_preload.source_files)
    check(index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id") in PROBES).is_empty(),seat+" no duplicate existing/retiring demonstration component is compiled")
    var healing:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id") in HEALING)
    check(healing.size()==2 and healing.all(func(row):return row.component.status=="available"),seat+" both real positive-healing sources remain bound")
    var heal_total:int=0
    for lineage in removal.lineages:
        for node in lineage.events:
            var fact:Variant=node.get("fact")
            if fact!=null and fact.get("kind")=="heal":heal_total+=int(fact.actual_healing)
    check(heal_total==38,seat+" original 38HP healing remains exact")
    var lives:Array=index.rows.filter(func(row):return row.kind=="condition" and row.owner.id in ids)
    check(lives.size()==2,seat+" Studio retains both actual semantic condition lifetimes")
    if lives.size()!=2:return
    var owner:Dictionary=lives.filter(func(row):return row.owner.id==ids[0])[0].owner
    check(lives.all(func(row):return not row.owner.initial and is_finite(float(row.owner.end_ms))),seat+" no held condition is manufactured from an initial snapshot")
    var first_start:float=minf(float(lives[0].owner.start_ms),float(lives[1].owner.start_ms))
    var last_start:float=maxf(float(lives[0].owner.start_ms),float(lives[1].owner.start_ms))
    var cut:float=float(owner.end_ms)
    check(lives.all(func(row):return is_equal_approx(float(row.owner.end_ms),cut)),seat+" actual linked removals share their native presentation cut")
    var at_application:float=last_start+60.0
    var held:float=minf(cut-1.0,last_start+400.0)
    var fade:float=cut+100.0
    var ended:float=cut+251.0
    check(at_application<held and held<cut,seat+" real recording contains application, held and removal intervals")
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.media_warmup.encounter_override=media_preload
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows)
    world.native_startup_requested_ms=maxf(0.0,first_start-2.0)
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    world.install_playback(Recording.restore(index,maxf(0.0,first_start-2.0)))
    if not await settle(world):view.queue_free();await frame();return
    check(emitting(world,ids).is_empty() and pose(world,patient).is_empty(),seat+" before actual application there is no marker or paralysis pose")
    if not await advance(world,at_application,marker_id(owner.id)):view.queue_free();await frame();return
    check(emitting(world,ids)==[marker_id(owner.id)],seat+" actual application selects one glyph for the two semantic owners")
    var handle:Dictionary=native_owner(world,owner,at_application,"application",seat+" application")
    if handle.is_empty():view.queue_free();await frame();return
    var source_root:WeakRef=weakref(handle.root)
    check(is_equal_approx(float(Effects.clip("conditions/native_v1/"+LIFECYCLE+"/default/removal").seconds),.25),seat+" original package removal lasts exactly0.25seconds")
    if not await advance(world,held,marker_id(owner.id)):view.queue_free();await frame();return
    handle=native_owner(world,owner,held,"sustain",seat+" sustain")
    check(not handle.is_empty() and source_root.get_ref()==handle.root,seat+" application and held phase share the original private owner")
    check(not pose(world,patient).is_empty(),seat+" actual paralysis owns the held body pose")
    world.camera_focus=Play.Placement.contact(world.visual_actors[patient].row);world.camera.size=3.5;world.initial_focus=true;world.position_camera();world.grid_visible=false
    for quarter in 4:
        if quarter!=world.quarter:world.request_view(quarter)
        var rotation_deadline:int=Time.get_ticks_msec()+15000
        while world.rotation_pending() and Time.get_ticks_msec()<rotation_deadline:await frame()
        check(world.quarter==quarter and world.world_quarter==quarter and not world.rotation_pending(),seat+" actual prepared camera quarter publishes: "+str(quarter))
        if world.quarter!=quarter or world.world_quarter!=quarter or world.rotation_pending():break
        if not await settle(world,marker_id(owner.id)):break
        handle=native_owner(world,owner,held,"sustain",seat+" view"+str(quarter))
        if handle.is_empty():continue
        check(emitting(world,ids)==[marker_id(owner.id)],seat+" view"+str(quarter)+" retains one selected actual UUID")
        evidence.append({"seat":seat,"phase":"sustain","quarter":quarter,"published_quarter":world.quarter,"world_quarter":world.world_quarter,"condition_uuid":owner.id,"at_ms":held,
            "changed_pixels":await pixels(world,view,handle,seat+"-q"+str(quarter)+"-held")})
    # Reuse the last prepared view's handle through the real removal boundary.
    handle=world.component_renderer.native_spells.handles.get(marker_id(owner.id),{})
    source_root=weakref(handle.root) if not handle.is_empty() else null
    if not await advance(world,fade,marker_id(owner.id)):view.queue_free();await frame();return
    handle=native_owner(world,owner,fade,"removal",seat+" removal")
    check(not handle.is_empty() and source_root!=null and source_root.get_ref()==handle.root,seat+" same original UUID/private instance continues into native removal")
    check(emitting(world,ids)==[marker_id(owner.id)],seat+" removal does not create a second glyph")
    check(pose(world,patient).is_empty(),seat+" actual removal immediately restores the ordinary body pose")
    if not handle.is_empty():
        evidence.append({"seat":seat,"phase":"removal","condition_uuid":owner.id,"at_ms":fade,"removal_start_ms":cut,
            "owner_state":handle.owner_state.duplicate(true),"changed_pixels":await pixels(world,view,handle,seat+"-removal")})
    if not await advance(world,ended):view.queue_free();await frame();return
    check(emitting(world,ids).is_empty() and pose(world,patient).is_empty(),seat+" after the actual0.25second fade no marker or paralysis pose remains")
    check(ids.all(func(uuid):return not world.timeline.condition_owners.has(uuid)),seat+" finished real condition owners retire")
    var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
    var previous:WeakRef=source_root
    for at in [held,fade,ended]:
        world.install_playback(Recording.restore(index,at))
        if not await settle(world,marker_id(owner.id) if at!=ended else ""):break
        if previous!=null:check(previous.get_ref()==null,seat+" seeking/looping releases the earlier private native instance")
        if at==ended:
            check(emitting(world,ids).is_empty() and var_to_bytes(world.timeline.state)==canonical,seat+" replay loop restores the exact final independent canonical state")
            previous=null
        else:
            handle=native_owner(world,owner,at,"removal" if at==fade else "sustain",seat+" seek"+str(at))
            check(emitting(world,ids)==[marker_id(owner.id)],seat+" seeking reconstructs one real owner without any probe copy")
            previous=weakref(handle.root) if not handle.is_empty() else null
    var native=world.component_renderer.native_spells;native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty(),seat+" teardown releases private lifecycle and rendering owners")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+" real application/removal/seek/loop has no renderer errors")
    check(FileAccess.get_file_as_bytes(SOURCE.path_join(seat).path_join("0000000000000010.json"))==originals,seat+" original removal packets remain unchanged")
    view.queue_free();await frame();await frame()
func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Both original PWH restoration journals: existing same-UUID Paralyzed/Hold Person lifecycle application, selection,0.25second native removal, marker pixels/restoration, four views and seek/loop/teardown. Duplicate probes are excluded; poison, source preparation performance and visual approval remain unqualified."}
    FileAccess.open("res://.runtime/native-restoration-owner-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_RESTORATION_OWNER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
