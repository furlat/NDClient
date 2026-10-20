extends "res://tests/native_finite_observed_render_checks.gd"
## Exact accepted operation inputs and original source output, independent of
## actual resource/book mutation. No decorative item becomes a world item.
const OPERATIONS_ROOT="res://tests/fixtures/schema16/accepted-operations"
const OPERATIONS={"arcane-recovery":"wizard-class-study/wizard_arcane_recovery_accepted_study",
    "scroll-learning":"wizard-class-study/wizard_scroll_learning_accepted_study"}
const OPERATION_CAPTURES="res://.runtime/accepted-operation-captures"
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_ACCEPTED_OPERATION_FAIL ",label)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(OPERATION_CAPTURES)
    for case_id in OPERATIONS:
        for seat in ["amber","blue"]:await operation_seat(case_id,seat)
    finish()

func operation_seat(case_id:String,seat:String)->void:
    var label:String=case_id+"/"+seat
    var index:Dictionary=Recording.read(OPERATIONS_ROOT.path_join(case_id).path_join(seat))
    check(index.ok,label+" unchanged original recording compiles")
    if not index.ok:return
    var original:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")==OPERATIONS[case_id])
    if seat=="blue":
        if case_id=="arcane-recovery":check(rows.is_empty(),label+" no post-victory action disclosure means no invented source")
        else:
            check(rows.size()==1 and rows[0].component.status=="missing" and not rows[0].component.has("native_constructor_inputs"),label+" missing source-item/book witness remains unconstructed")
        return
    check(rows.size()==1 and rows[0].component.status=="available",label+" one actual accepted action owns one available source")
    if rows.size()!=1 or rows[0].component.status!="available":return
    var row:Dictionary=rows[0];var component:Dictionary=row.component
    var media:Dictionary=RecordingMedia.plan(index)
    check(media.errors.is_empty(),label+" real whole-recording media closure resolves")
    if not media.errors.is_empty():return
    Play.Catalog.adopt_snapshot(index.cache,media.source_files)
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.media_warmup.budget_bytes=0;world.media_warmup.encounter_override=media
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows)
    world.native_startup_requested_ms=maxf(0.0,float(row.start_ms)-2.0)
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var phase:Resource=load(Effects.choice(component.native_clip).approaches[0].source_phase)
    var sealed:PackedByteArray=var_to_bytes(phase.to_clip())
    var start:float=float(row.start_ms);var end:float=float(row.end_ms)
    var during:float=start+minf(650.0,(end-start)*.4)
    var previous:WeakRef
    var passes:int=0
    for at in [maxf(0.0,start-2.0),during,minf(index.presentation_end_ms,end+2.0),maxf(0.0,start-2.0),during]:
        world.install_playback(Recording.restore(index,at))
        if not await settle(world,component.id if at==during else ""):
            world.component_renderer.native_spells.close(world);view.queue_free();await frame();return
        if previous!=null:check(previous.get_ref()==null,label+" rewind/loop releases the prior private finite occurrence")
        var native=world.component_renderer.native_spells
        if at!=during:
            check(native.witnesses.all(func(witness):return witness.id!=component.id),label+" no operation draws before/after its actual finite interval")
            if native.handles.has(component.id):check(not native.handles[component.id].root.is_visible_in_tree(),label+" prepared finite source remains hidden outside its interval")
            previous=null;continue
        check(native.handles.has(component.id),label+" actual operation owns its native source")
        if not native.handles.has(component.id):continue
        var handle:Dictionary=native.handles[component.id]
        for quarter in [0,1,2,3]:
            if world.quarter!=quarter:world.request_view(quarter)
            var deadline:int=Time.get_ticks_msec()+15000
            while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
            check(not world.rotation_pending() and world.quarter==quarter and world.world_quarter==quarter,label+" requested and actual published quarter are "+str(quarter))
            if not await settle(world,component.id):break
            var programs:Array=handle.occurrence.input_receivers.get("set_operation_state",[])
            check(programs.size()==1,label+" exactly one sealed operation source consumes the factual packet")
            if programs.size()!=1:continue
            var program:Node3D=programs[0]
            var input:Dictionary=component.native_inputs.operation_state
            check(program.live_state==input and program.settings.operation_uuid==str(component.source_event_uuid) \
                and program.settings.actor_uuid==component.actor_uuid,label+" actual operation/actor identities reach constructor and public setter")
            check(program.settings.state.is_empty() and program.settings.get("review_states",[]).is_empty() \
                and not program.live_state.has("restored_slot_ranks"),label+" review outcomes and slot results are not used")
            check(program.endpoints.size()==1 and program.endpoints[0].actor_uuid==component.actor_uuid \
                and program.endpoints[0].socket=="cast_hand",label+" real current source hand drives the operation")
            if case_id=="scroll-learning":
                check(program.settings.item_uuid==input.item_uuid and program.settings.learned_spell_id=="spell.hold_person",label+" original consumed scroll and actual own book result reach native source")
            var bindings:Dictionary=native.diagnostics.get(component.id,{}).get("input_bindings",{})
            check(bindings.get("unavailable",{}).is_empty() and component.native_clip.inputs.all(func(channel):return channel in bindings.get("supplied",[])),label+" every declared input is actually supplied")
            check(native.witnesses.any(func(witness):return witness.id==component.id),label+" source has an actual draw-frame witness")
            world.camera_focus=Play.Placement.contact({"position":component.from_position,"base_height_steps":float(component.get("from_elevation_feet",0.0))/5.0})
            world.camera.size=4;world.initial_focus=true;world.position_camera();world.grid_visible=false
            await frame();await frame();world.set_process(false)
            var state:PackedByteArray=var_to_bytes(world.timeline.state)
            var present:Image=view.get_texture().get_image()
            handle.root.hide();await frame();await frame()
            var hidden:Image=view.get_texture().get_image();var pixels:int=changed(present,hidden)
            check(pixels>0,label+" hiding this exact native source changes actual framebuffer pixels")
            var stem:String=OPERATION_CAPTURES.path_join(case_id+"-"+seat+"-"+str(passes)+"-q"+str(quarter))
            check(present.save_png(stem+"-present.png")==OK and hidden.save_png(stem+"-hidden.png")==OK,label+" actual source visibility controls saved")
            check(var_to_bytes(world.timeline.state)==state and var_to_bytes(phase.to_clip())==sealed,label+" source probe preserves canonical state and shared sealed program")
            handle.root.show();world.set_process(true)
            evidence.append({"case":case_id,"seat":seat,"operation":component.source_event_uuid,"at_ms":at,
                "quarter":quarter,"published_quarter":world.world_quarter,"changed_pixels":pixels,
                "observation":program.capture_observation(),"capture":stem+"-present.png"})
        previous=weakref(handle.root);passes+=1
    world.component_renderer.native_spells.close(world)
    check(world.component_renderer.native_spells.handles.is_empty() and (previous==null or previous.get_ref()==null),label+" private finite sources release on teardown")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==original and world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+" actual seek/loop/views preserve original inputs without presentation errors")
    view.queue_free();await frame();await frame()

func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual original accepted action identities, consumed scroll/own book witness, exact delivered sources and source-hidden framebuffer output through four published quarters, finite seeking/loop/teardown. Blue missing disclosure, performance and visual acceptance remain distinct."}
    FileAccess.open("res://.runtime/native-accepted-operation-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_ACCEPTED_OPERATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
