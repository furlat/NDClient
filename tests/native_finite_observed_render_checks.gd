extends "res://tests/native_vampiric_touch_render_checks.gd"
## Original result-owned sources through Play, with isolated framebuffer proof.
const RecordingMedia=preload("res://studio/recording_media.gd")
const FINITE_ROOT="res://tests/fixtures/schema16/finite-observed"
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
            print("FINITE_OBSERVED_PENDING ",JSON.stringify(pending));reported=true
    var timeout:Dictionary=settle_diagnostic(world,component_id,before_draw)
    evidence.append({"kind":"native_settle_failed","elapsed_ms":Time.get_ticks_msec()-began,"diagnostic":timeout})
    check(false,"Native preparation failed: "+str(timeout));return false
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
    var startup:Dictionary=Play.NativeStartup.status(world._native_startup_request(world.timeline.display_ms))
    var pending:Dictionary={}
    if world.pending_world!=null:
        pending={"prepared":world.pending_world.prepared,"admitted":world.pending_world.admitted,"phase":world.pending_world.phase,
            "epoch":world.pending_world.epoch,"quarter":world.pending_world.quarter,"key":world.pending_world.boundary.get("preparation_key",[])}
    return {"display_ms":world.timeline.display_ms,"component_id":component_id,"sequence":world.timeline.sequence,
        "revisions":{"world":world.world_revision,"timeline_world":world.timeline.world_revision,
            "world_epoch":world.world_prepare_epoch,"timeline_epoch":world.timeline.initialization_revision,"resources":world.timeline.resource_revision},
        "before_draw":before_draw,"media_gate":world.media_gate.duplicate(true),"component_ready":world.component_renderer.ready,
        "component_leaves":world.component_renderer.readiness.duplicate(true),"native_ready":native.ready,
        "native_preparation":native.preparation_state.duplicate(true),"native_failures":native._prepare_failures.duplicate(),
        "required_components":world.component_renderer._native_prepare_components.map(func(component):return {"id":component.id,"kind":component.kind,
            "status":component.get("status"),"clip":component.get("native_clip",{}).get("id"),"handle":native.handles.has(component.id)}),
        "required_sources":requirements.size(),"missing_sources":missing,"decode_jobs":owner.decode_jobs.size(),"pending_decode":owner.pending.size(),
        "failed_sources":owner.failed.duplicate(),"boot_waiting":media.boot_waiting.keys(),"metadata_pending":media.plan_thread!=null,
        "native_startup":{"ready":startup.ready,"pending":startup.pending,"errors":startup.errors},"pending_world":pending,
        "quarter":world.quarter,"published_quarter":world.world_quarter,"rotation_pending":world.rotation_pending(),
        "frame_budget":world.preparation_admission.duplicate(true),"errors":world.presentation_errors,"media_issue":world.media_issue}
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(FINITE_CAPTURES)
    for name in FINITE_CASES:
        for seat in ["amber","blue"]:await finite_seat(name,seat)
    finish()
func original_results(name:String,seat:String)->Dictionary:
    var packet:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FINITE_ROOT.path_join(name).path_join(seat).path_join("0000000000000008.json")))
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
    var index:Dictionary=Recording.read(FINITE_ROOT.path_join(name).path_join(seat))
    check(index.ok,label+" original complete recording compiles")
    if not index.ok:return
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
