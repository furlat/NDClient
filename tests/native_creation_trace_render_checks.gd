extends "res://tests/native_vampiric_touch_render_checks.gd"
## The existing finite optical preparation sources, on real public admissions.
## No armed Glyph, Flaming body/trail/contact, new arrival source or art approval.
const Facts=preload("res://tests/creation_trace_input_checks.gd")

func settle(world:Node,component_id:String="")->bool:
    var deadline:int=Time.get_ticks_msec()+45000
    while Time.get_ticks_msec()<deadline and not world.publication_failed and world.presentation_errors.is_empty() and world.media_issue.is_empty():
        await process_frame
        var inputs:Dictionary=world.component_renderer.native_spells.diagnostics.get(component_id,{}).get("input_bindings",{})
        if world.playback_prepared() and (component_id.is_empty() or not inputs.is_empty() and inputs.get("unavailable",{}).is_empty()):
            await RenderingServer.frame_post_draw
            inputs=world.component_renderer.native_spells.diagnostics.get(component_id,{}).get("input_bindings",{})
            if world.playback_prepared() and (component_id.is_empty() or not inputs.is_empty() and inputs.get("unavailable",{}).is_empty() and "targets" in inputs.get("supplied",[]) and "delivery_timing" in inputs.get("supplied",[])):return true
        else:await RenderingServer.frame_post_draw
    check(false,"Actual finite trace preparation: "+str({"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics}))
    return false

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    check(DisplayServer.get_name()!="headless","Finite optical trace qualification requires actual native output")
    if DisplayServer.get_name()=="headless":finish();return
    DirAccess.make_dir_recursive_absolute("res://.runtime/creation-trace-captures")
    for name in Facts.CASES:
        for seat in ["amber","blue"]:await trace_seat(name,seat)
    finish()

func trace_seat(name:String,seat:String)->void:
    var spec:Dictionary=Facts.CASES[name];var label:String=name+"/"+seat
    var directory:String="res://tests/fixtures/schema16/"+spec.folder+"/"+seat
    var index:Dictionary=Recording.read(directory)
    check(index.ok,label+" independently recorded original compiles through production")
    if not index.ok:return
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")==spec.clip)
    check(rows.size()==1,label+" exactly one original public admission owns the finite trace")
    if rows.size()!=1:return
    var row:Dictionary=rows[0];var component:Dictionary=row.component
    var destination:Dictionary=component.get("native_destination",{})
    check(component.status=="available" and destination.get("kind")==spec.kind,label+" actual admission supplies the existing source")
    if component.status!="available" or destination.is_empty():return
    check(component.source_event_uuid==spec.publication and component.native_cast_id==spec.source,label+" publication and original rule declaration remain separate")
    var original:PackedByteArray=var_to_bytes(component)
    var phase:Resource=load(Effects.choice(component.native_clip).approaches[0].source_phase)
    var sealed:PackedByteArray=var_to_bytes(phase.to_clip())
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var previous:WeakRef
    var canonical:PackedByteArray=PackedByteArray()
    for pass_index in 2:
        world.install_playback(Recording.restore(index,maxf(0.0,float(row.start_ms)-2.0)))
        if not await settle(world):await close_trace(world,view,label);return
        if previous!=null:check(previous.get_ref()==null,label+" reverse seek releases the previous source occurrence")
        var native=world.component_renderer.native_spells
        check(native.witnesses.all(func(witness):return witness.id!=component.id),label+" source draws nothing before its exact original publication")
        if native.handles.has(component.id):check(not native.handles[component.id].root.is_visible_in_tree(),label+" future prepared source remains hidden")
        var at:float=float(row.start_ms)+600.0
        world.install_playback(Recording.restore(index,at))
        if not await settle(world,component.id):await close_trace(world,view,label);return
        if pass_index==0:canonical=var_to_bytes(world.timeline.state)
        else:check(var_to_bytes(world.timeline.state)==canonical,label+" looping restores the identical original canonical prefix")
        native=world.component_renderer.native_spells
        check(native.handles.has(component.id),label+" ordinary native preparation constructs the actual finite source")
        if not native.handles.has(component.id):await close_trace(world,view,label);return
        var handle:Dictionary=native.handles[component.id]
        var programs:Array=handle.occurrence.input_receivers.get("set_live_endpoints",[])
        check(programs.size()==1,label+" exactly one original source receives actual endpoints")
        if programs.size()!=1:await close_trace(world,view,label);return
        var program:Node3D=programs[0]
        check(program.specification.is_empty(),label+" no review lifecycle or fabricated constructor fields replace the sealed source")
        check(is_equal_approx(program.launch_seconds,.3) and is_equal_approx(program.travel_seconds,.45),label+" source retains its exact authored finite internal travel")
        check(is_equal_approx(handle.age,.6),label+" actual publication owns source age zero")
        var quarters:Array=[0,1,2,3] if pass_index==0 else [0]
        for quarter in quarters:
            world.request_view(quarter)
            var deadline:int=Time.get_ticks_msec()+45000
            while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
            check(world.quarter==quarter and world.world_quarter==quarter and not world.rotation_pending(),label+" actual view publishes quarter "+str(quarter))
            if not await settle(world,component.id):await close_trace(world,view,label);return
            native=world.component_renderer.native_spells
            check(native.handles.has(component.id),label+" published view retains an actual finite trace owner")
            if not native.handles.has(component.id):continue
            handle=native.handles[component.id]
            programs=handle.occurrence.input_receivers.get("set_live_endpoints",[])
            check(programs.size()==1,label+" published view has one current source endpoint receiver")
            if programs.size()!=1:continue
            program=programs[0]
            var bound:Dictionary=native.diagnostics.get(component.id,{}).get("input_bindings",{})
            check(bound.get("unavailable",{}).is_empty() and bound.get("supplied",[]).has("targets") and bound.get("supplied",[]).has("delivery_timing"),label+" both exact source inputs are supplied")
            check(program.endpoints.size()==3,label+" complete actual hand/ground/release tuple reaches the source")
            if program.endpoints.size()!=3:continue
            var ground:Vector3=Play.Placement.contact({"position":component.to_position,"base_height_steps":component.to_elevation_feet/5.0})
            check(program.endpoints[0].actor_uuid==component.actor_uuid and program.endpoints[0].socket=="cast_hand" and program.endpoints[0].point.is_equal_approx(handle.endpoints.hand),label+" hand endpoint follows the actual caster registration")
            check(program.endpoints[1].cue_point=="target" and program.endpoints[1].point.is_equal_approx(ground),label+" destination is the exact recorded world ground, in every view")
            check(program.endpoints[2].cue_point=="source" and program.endpoints[2].point.is_equal_approx(handle.endpoints.from),label+" launch uses the actual authored casting release socket")
            var expected:Vector3=(program.endpoints[2].point as Vector3).lerp(ground,2.0/3.0)
            var trajectory_ready:bool=program.draw!=null and program.draw.is_visible_in_tree() and program.draw.global_position.is_equal_approx(expected)
            var trajectory:Dictionary={"quarter":quarter,"pass":pass_index,"expected_world":expected,
                "actual_world":program.draw.global_position if program.draw!=null else null,
                "source_transform":program.global_transform,"root_transform":handle.root.global_transform,
                "source_age":handle.age,"endpoints":program.endpoints}
            check(trajectory_ready,label+" original source actually travels between those world endpoints without a double transform"+("" if trajectory_ready else ": "+JSON.stringify(trajectory)))
            if name=="flaming_sphere":
                check(world.timeline.state.actors.has(spec.identity) and world.timeline.state.actors[spec.identity].present,label+" actual born actor is already published; the optical seed is not its body")
                check(program.capture_observation().optical_seed_only and not program.capture_observation().summoned_body_in_flight,label+" source retains its explicit optical-only contract")
            else:check(program.capture_observation().observed_ground_destination_required,label+" Glyph trace retains its observed-ground contract")
            world.camera_focus=expected;world.camera.size=4;world.initial_focus=true;world.position_camera();world.grid_visible=false
            if not await settle(world,component.id):await close_trace(world,view,label);return
            native=world.component_renderer.native_spells
            handle=native.handles[component.id]
            programs=handle.occurrence.input_receivers.get("set_live_endpoints",[])
            check(programs.size()==1,label+" final capture camera retains the actual endpoint receiver")
            if programs.size()!=1:await close_trace(world,view,label);return
            program=programs[0]
            var capture_bindings:Dictionary=native.diagnostics.get(component.id,{}).get("input_bindings",{})
            check(not capture_bindings.is_empty() and capture_bindings.get("unavailable",{}).is_empty(),label+" final capture camera has every actual phase input ready")
            check(world.timeline.display_ms==at and is_equal_approx(handle.age,.6),label+" final camera readiness preserves original publication and source clocks")
            await frame();await frame();world.set_process(false)
            var present:Image=view.get_texture().get_image();Effects.hide(handle);await frame();await frame()
            var absent:Image=view.get_texture().get_image();var pixels:int=changed(present,absent)
            check(pixels>0,label+" real finite source contributes framebuffer pixels, quarter "+str(quarter))
            var stem:String="res://.runtime/creation-trace-captures/"+name+"-"+seat+"-"+str(pass_index)+"-q"+str(quarter)
            check(present.save_png(stem+"-present.png")==OK and absent.save_png(stem+"-absent.png")==OK,label+" exact source present/hidden captures save")
            check(var_to_bytes(world.timeline.state)==canonical and var_to_bytes(component)==original and var_to_bytes(phase.to_clip())==sealed,label+" drawing, view and source hiding preserve canonical facts and immutable art")
            evidence.append({"case":spec.case,"seat":seat,"pass":pass_index,"quarter":quarter,"at_ms":at,"clip":spec.clip,"changed_pixels":pixels,"binding":destination,"capture":stem+"-present.png","capture_bindings":capture_bindings,"trajectory":trajectory})
            handle.root.show();world.set_process(true)
        previous=weakref(handle.root)
        world.install_playback(Recording.restore(index,minf(index.presentation_end_ms,float(row.end_ms)+2.0)))
        if not await settle(world):await close_trace(world,view,label);return
        check(native.witnesses.all(func(witness):return witness.id!=component.id),label+" full original finite source stops after its authored tail")
    await close_trace(world,view,label)
    check(previous==null or previous.get_ref()==null,label+" final source occurrence releases on teardown")

func close_trace(world:Node,view:SubViewport,label:String)->void:
    var native=world.component_renderer.native_spells;native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty(),label+" ordinary teardown releases native source and layer owners")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+" actual finite phase replay has no presentation/resource errors")
    view.queue_free();await frame();await frame()

func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"factory_version":JSON.parse_string(FileAccess.get_file_as_string(Effects.INDEX)).version,
        "scope":"Existing Glyph ground trace and Flaming optical preparation, actual creation/birth admission, both original seats, ordinary Play source inputs/timing/world registration/native pixels, four published views and reverse seek/loop/teardown. Glyph armed/payload and Flaming body/trail/contact, performance and human art approval remain separate."}
    FileAccess.open("res://.runtime/native-creation-trace-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_CREATION_TRACE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
