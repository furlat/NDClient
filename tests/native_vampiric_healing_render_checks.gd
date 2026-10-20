extends "res://tests/native_finite_observed_render_checks.gd"
## Actual healing returns plus one existing UUID hand source through removal.
const POSITIVE="res://tests/fixtures/schema16/vampiric-positive"
const HEALING="bg3-36/vampiric-touch/vampiric_touch_native/healing"
const HAND="condition_vampiric_touch_hand_persistent"
const CAPTURES="res://.runtime/vampiric-healing-captures"
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_VAMPIRIC_HEALING_FAIL ",label)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(CAPTURES)
    for seat in ["amber","blue"]:await healing_seat(seat)
    finish()
func advance(world:Node,at:float,id:String="")->bool:
    var plan:Dictionary={};var began:int=Time.get_ticks_msec()
    while world.timeline.display_ms<at-.000001 and Time.get_ticks_msec()-began<15000:
        await process_frame
        if plan.is_empty():plan=world.timeline.replay_plan(at)
        if world.timeline.replay_prepare(plan):
            if world.can_publish_replay_advance(plan):
                check(world.publish_replay_advance(plan),"Actual replay boundary publishes before advancing the shared clock")
                plan={}
            else:
                world.timeline.replay_cancel_preparation();plan={}
        await RenderingServer.frame_post_draw
        if not world.presentation_errors.is_empty() or not world.media_issue.is_empty():break
    check(is_equal_approx(world.timeline.display_ms,at),"Ordinary received boundary reaches requested cut "+str(at)+": "+str(settle_diagnostic(world,id,{})))
    if not is_equal_approx(world.timeline.display_ms,at):return false
    return await settle(world,id)
func source_pixels(world:Node,view:SubViewport,handle:Dictionary,label:String)->int:
    world.set_process(false);await frame();await frame()
    var state:PackedByteArray=var_to_bytes(world.timeline.state)
    var present:Image=view.get_texture().get_image()
    handle.root.hide();await frame();await frame()
    var hidden:Image=view.get_texture().get_image();var count:int=changed(present,hidden)
    check(count>0,label+" isolated native source changes actual framebuffer pixels")
    check(present.save_png(CAPTURES.path_join(label+"-present.png"))==OK and hidden.save_png(CAPTURES.path_join(label+"-hidden.png"))==OK,label+" native present/hidden controls saved")
    check(var_to_bytes(world.timeline.state)==state,label+" optical source control preserves canonical state")
    handle.root.show();world.set_process(true)
    return count
func actual_quarter(world:Node,quarter:int,id:String,label:String)->bool:
    if quarter!=world.quarter:world.request_view(quarter)
    var until:int=Time.get_ticks_msec()+15000
    while world.rotation_pending() and Time.get_ticks_msec()<until:await frame()
    var ready:bool=not world.rotation_pending() and world.quarter==quarter and world.world_quarter==quarter
    check(ready,label+" actual requested/published quarter is "+str(quarter))
    return ready and await settle(world,id)
func hand_at(world:Node,owner:Dictionary,at:float,phase:String,label:String)->Dictionary:
    var native=world.component_renderer.native_spells
    var id:String="condition:"+str(owner.id)+":lifecycle:"+HAND
    check(native.handles.has(id),label+" exact original condition UUID has one native hand owner")
    if not native.handles.has(id):return {}
    var handle:Dictionary=native.handles[id];var state:Dictionary=handle.get("owner_state",{})
    check(handle.get("lifecycle_phase")==phase and state.get("phase")==phase,label+" actual lifecycle phase is supplied")
    check(is_equal_approx(float(state.get("owner_age_seconds",-1.0)),(at-float(owner.start_ms))/1000.0),label+" same actual UUID start owns the source age")
    if phase=="removal":
        check(is_equal_approx(float(state.get("phase_age_seconds",-1.0)),(at-float(owner.end_ms))/1000.0),label+" removal uses actual owner end rather than a new source clock")
    var peers:Array=native.handles.values().filter(func(candidate):return candidate.component.get("lifecycle_key")==HAND and candidate.root.is_visible_in_tree())
    check(peers.size()==1 and peers[0].root==handle.root,label+" no duplicate held/retiring probe or hand is drawn")
    check(native.witnesses.any(func(witness):return witness.id==id),label+" selected owner has a real draw witness")
    return handle
func healing_seat(seat:String)->void:
    var index:Dictionary=Recording.read(POSITIVE.path_join(seat));check(index.ok,seat+" original positive lifecycle compiles")
    if not index.ok:return
    var original:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")==HEALING)
    check(rows.size()==2,seat+" actual first and repeat positive HealFacts each own one finite return")
    if rows.size()!=2:return
    var zero:Dictionary=Recording.read(Fixtures.journal("vampiric-touch",seat));check(zero.ok,seat+" unchanged zero-heal original compiles")
    if zero.ok:check(zero.rows.all(func(row):return row.get("component",{}).get("native_clip",{}).get("id")!=HEALING),seat+" actual zero-heal recording constructs no successful healing return")
    var held:Array=index.rows.filter(func(row):return row.get("component",{}).get("lifecycle_key")==HAND)
    check(not held.is_empty(),seat+" actual UUID hand lifecycle is indexed")
    if held.is_empty():return
    var owner:Dictionary=held[0].owner;var id:String="condition:"+str(owner.id)+":lifecycle:"+HAND
    check(not owner.initial and is_finite(float(owner.end_ms)),seat+" held source starts at actual application and ends at actual removal")
    check(index.rows.all(func(row):return row.get("component",{}).get("native_cue",{}).get("source_index",-1) not in [3,4] \
        or row.get("component",{}).get("spell_id")!="vampiric_touch"),seat+" original held/retire probes are delegated rather than duplicated")
    var media:Dictionary=RecordingMedia.plan(index);check(media.errors.is_empty(),seat+" immutable recorded media closure is available")
    if not media.errors.is_empty():return
    Play.Catalog.adopt_snapshot(index.cache,media.source_files)
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.media_warmup.encounter_override=media
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows)
    world.native_startup_requested_ms=maxf(0.0,float(owner.start_ms)-2.0)
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    for row in rows:
        var component:Dictionary=row.component;var phase:Resource=load(Effects.choice(component.native_clip).approaches[0].source_phase)
        var sealed:PackedByteArray=var_to_bytes(phase.to_clip());var component_bytes:PackedByteArray=var_to_bytes(component)
        var during:float=float(row.start_ms)+minf(180.0,(float(row.end_ms)-float(row.start_ms))*.4)
        var previous:WeakRef;var cycle:int=0
        for at in [maxf(0.0,float(row.start_ms)-2.0),during,float(row.end_ms)+2.0,maxf(0.0,float(row.start_ms)-2.0),during]:
            world.install_playback(Recording.restore(index,at))
            if not await settle(world,component.id if at==during else ""):world.component_renderer.native_spells.close(world);view.queue_free();await frame();return
            if previous!=null:check(previous.get_ref()==null,seat+" seeking/looping frees previous finite private source")
            var native=world.component_renderer.native_spells
            if at!=during:
                check(native.witnesses.all(func(witness):return witness.id!=component.id),seat+" no return witness before/after actual healing interval")
                if native.handles.has(component.id):check(not native.handles[component.id].root.is_visible_in_tree(),seat+" prepared return stays hidden outside its finite interval")
                previous=null;continue
            if not await actual_quarter(world,1 if cycle==0 else 3,component.id,seat):break
            check(native.handles.has(component.id),seat+" original HealFact has a native source owner")
            if not native.handles.has(component.id):continue
            var handle:Dictionary=native.handles[component.id]
            var programs:Array=handle.occurrence.input_receivers.get("set_healing_input",[])
            check(programs.size()==1,seat+" one sealed source receives the original healing packet")
            if programs.size()!=1:continue
            var program:Node3D=programs[0];var actual:Dictionary=component.native_inputs.healing_input
            check(program.healing==actual and program.healing_admitted() and not program.owner_admitted() \
                and not program.payload_admitted(),seat+" exact positive HealFact admits only its independent healing branch")
            check(program.settings.source_actor_uuid==actual.source_actor_uuid and program.settings.recipient_uuid==component.target_uuid \
                and actual.recipient_uuid==component.actor_uuid and component.target_uuid!=component.actor_uuid,seat+" enemy optical donor stays separate from the actually healed caster")
            check(program.settings.activation_event_uuid==actual.parent_event_uuid and actual.healing_fact_uuid==str(component.source_event_uuid),seat+" actual heal parent and result identities reach the sealed constructor/setter")
            check(program.endpoints.size()==2 and program.endpoints[0].actor_uuid==component.actor_uuid \
                and program.endpoints[1].actor_uuid==component.target_uuid and not program.contact().is_empty(),seat+" measured caster hand and real enemy surface drive the return path")
            var bindings:Dictionary=native.diagnostics.get(component.id,{}).get("input_bindings",{})
            check("healing_input" in bindings.get("supplied",[]) and bindings.get("unavailable",{}).is_empty() \
                and bindings.get("not_applicable",{}).size()==4,seat+" supplied healing is distinct from four exact unconsumed N/A channels")
            world.camera_focus=Play.Placement.contact({"position":component.to_position,"base_height_steps":float(component.get("to_elevation_feet",0.0))/5.0})
            world.camera.size=4;world.initial_focus=true;world.position_camera();world.grid_visible=false
            var pixels:int=await source_pixels(world,view,handle,seat+"-heal-"+str(component.source_event_uuid)+"-"+str(cycle))
            evidence.append({"seat":seat,"source":component.source_event_uuid,"quarter":world.world_quarter,
                "actual_healing":actual.actual_healing,"actual_parent":actual.parent_event_uuid,"changed_pixels":pixels})
            if pixels==0:
                var diagnostic:Dictionary={"seat":seat,"source":component.source_event_uuid,"quarter":world.world_quarter,
                    "clock":program.local_clock,"envelope":program.envelope,"healing_admitted":program.healing_admitted(),
                    "handle_age":handle.age,"sample_time":handle.sample_time,"requested_time":handle.requested_time,
                    "source_input_revision":handle.occurrence.source_input_revision,
                    "sampled_input_revision":handle.occurrence.sampled_input_revision,
                    "tendons":program.tendons.map(func(piece):return {"visible":piece.is_visible_in_tree(),
                        "envelope":piece.material_override.get_shader_parameter("owned_envelope"),
                        "path_count":piece.get_meta("gpu_path_count",0)}),
                    "render":native.diagnostics.get(component.id,{})}
                evidence.append({"kind":"healing_geometry_diagnostic","details":diagnostic})
                print("VAMPIRIC_HEALING_GEOMETRY ",JSON.stringify(diagnostic))
            check(var_to_bytes(phase.to_clip())==sealed and var_to_bytes(component)==component_bytes,seat+" rendering preserves shared source material and actual cue operands")
            previous=weakref(handle.root);cycle+=1
    # One continuous replay epoch proves retained identity through the actual
    # application, intervening movement/repeat and authoritative removal.
    var before:float=maxf(0.0,float(owner.start_ms)-2.0)
    world.install_playback(Recording.restore(index,before));if not await settle(world):view.queue_free();await frame();return
    check(world.component_renderer.native_spells.witnesses.all(func(witness):return witness.id!=id),seat+" no hand appears before the actual application")
    var apply:float=float(owner.start_ms)+80.0;var sustain:float=float(owner.start_ms)+400.0
    if not await advance(world,apply,id):view.queue_free();await frame();return
    var active:Dictionary=hand_at(world,owner,apply,"application",seat)
    var retained:WeakRef=weakref(active.root) if not active.is_empty() else null
    for at in [sustain,float(rows[1].start_ms)+180.0,float(owner.end_ms)+100.0]:
        if not await advance(world,at,id):view.queue_free();await frame();return
        var phase:String="removal" if at>=float(owner.end_ms) else "sustain"
        active=hand_at(world,owner,at,phase,seat)
        check(not active.is_empty() and retained!=null and retained.get_ref()==active.root,seat+" same private UUID hand survives movement, repeat and removal")
        if not active.is_empty():
            var pixels:int=await source_pixels(world,view,active,seat+"-hand-"+str(roundi(at)))
            evidence.append({"seat":seat,"phase":phase,"owner_uuid":owner.id,"at_ms":at,"changed_pixels":pixels})
    check(is_equal_approx(float(held[0].component.lifecycle_phases.removal.seconds),.35),seat+" original native hand fade remains .35 seconds")
    if await advance(world,float(owner.end_ms)+351.0):
        check(world.component_renderer.native_spells.witnesses.all(func(witness):return witness.id!=id),seat+" after authoritative removal/fade no hand witness remains")
    world.component_renderer.native_spells.close(world)
    check(world.component_renderer.native_spells.handles.is_empty() and (retained==null or retained.get_ref()==null),seat+" explicit teardown releases the finite returns and retained hand")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==original and world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+" native seek/loop/cleanup preserves immutable originals and has no presentation errors")
    view.queue_free();await frame();await frame()
func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Both original positive first/repeat heals, exact caster/enemy geometry and actual-parent inputs, finite source-hidden pixels, original zero negative, selected published quarters1/3, one actual UUID hand lifecycle through movement/repeat/.35s removal and seek/loop/cleanup. Windup/repeat impact, full performance and user artistic approval remain unqualified."}
    FileAccess.open("res://.runtime/native-vampiric-healing-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_VAMPIRIC_HEALING ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
