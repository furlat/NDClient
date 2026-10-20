extends "res://tests/native_vampiric_touch_render_checks.gd"
## Real injured two-seat Power Word Heal through the ordinary replay renderer.
## The headless gate owns fact/control checks; this gate requires Forward+.
const POSITIVE="res://tests/fixtures/schema16/scenarios/power-word-heal-restoration"
const RESTORATION=["high-level-22/power-word-heal/full_restoration","high-level-22/power-word-heal/restoration_cross"]
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute("res://.runtime/positive-healing-captures")
    for seat in ["amber","blue"]:await healing_seat(seat)
    finish()
func healing_seat(seat:String)->void:
    var index:Dictionary=Recording.read(POSITIVE.path_join(seat))
    check(index.ok,seat+" original injured recording compiles")
    if not index.ok:return
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id") in RESTORATION)
    check(rows.size()==2,seat+" one actual positive heal owns two finite native sources")
    for row in rows:await source_interval(index,row,seat)
func source_interval(index:Dictionary,row:Dictionary,seat:String)->void:
    var component:Dictionary=row.component
    var label:String=seat+"/"+str(component.native_clip.id)
    check(component.status=="available" and not component.get("persistent_owner",false),label+" exact real heal is admitted without a persistent owner")
    var component_bytes:PackedByteArray=var_to_bytes(component)
    var phase:Resource=load(Effects.choice(component.native_clip).approaches[0].source_phase)
    var sealed:PackedByteArray=var_to_bytes(phase.to_clip())
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var start:float=float(row.start_ms);var end:float=float(row.end_ms)
    var during:float=start+minf(300.0,(end-start)*.4)
    var previous:WeakRef;var cycle:int=0
    for at in [maxf(0.0,start-2.0),during,end+2.0,maxf(0.0,start-2.0),during]:
        world.install_playback(Recording.restore(index,at))
        if not await settle(world,component.id if at==during else ""):
            world.component_renderer.native_spells.close(world);view.queue_free();await frame();return
        if previous!=null:check(previous.get_ref()==null,label+" seeking/looping frees the earlier finite native owner")
        var native=world.component_renderer.native_spells
        if at!=during:
            check(native.witnesses.all(func(witness):return witness.id!=component.id),label+" no restoration draw witness before/after the true finite interval")
            if native.handles.has(component.id):check(not native.handles[component.id].root.is_visible_in_tree(),label+" future/retired preparation stays hidden")
            previous=null;continue
        check(native.handles.has(component.id),label+" actual result has a prepared source owner")
        if not native.handles.has(component.id):continue
        var handle:Dictionary=native.handles[component.id]
        var programs:Array=handle.occurrence.input_receivers.get("set_event_input",[])
        check(programs.size()==1,label+" one sealed source receives the actual healing event")
        if programs.size()!=1:continue
        var program:Node3D=programs[0]
        var event:Dictionary=component.native_inputs.event_input
        check(program.event_input==event and program.event_admitted() and program.phase_admitted(),label+" the actual public positive heal admits the source")
        check(event.heal_fact.actual_healing>0 and not event.heal_fact.was_blocked \
            and event.heal_fact.source_entity_uuid==component.actor_uuid and event.heal_fact.target_entity_uuid==component.target_uuid,label+" exact positive/unblocked heal source and recipient reach the source")
        check(program.settings.event_uuid==str(component.source_event_uuid) \
            and program.settings.source_entity_uuid==component.actor_uuid and program.settings.recipient_entity_uuid==component.target_uuid,label+" constructor and setter name the same real result")
        check(program.settings.mode=="instant" and program.lease.is_empty() and not program.owner_admitted() \
            and program.settings.event.is_empty() and program.settings.lease.is_empty(),label+" finite healing retains no successful review packet or held lease")
        check(program.settings.geometry_actor==component.target_uuid and program.surface.get("actor")==component.target_uuid \
            and program.surface.get("points",[]).size()>=8 and not program.frame.is_empty(),label+" real measured patient geometry drives the receiver")
        var patients:Array=program.endpoints.filter(func(endpoint):return endpoint.actor_uuid==component.target_uuid and endpoint.socket=="body_center")
        var hands:Array=program.endpoints.filter(func(endpoint):return endpoint.actor_uuid==component.actor_uuid and endpoint.socket=="cast_hand")
        var faces:Array=program.endpoints.filter(func(endpoint):return endpoint.actor_uuid==component.actor_uuid and endpoint.socket=="face")
        check(patients.size()==1 and hands.size()==1 and faces.size()==1 \
            and hands[0].point.is_equal_approx(handle.endpoints.hand),label+" authored measured patient/caster sockets bind actual endpoints")
        var bindings:Dictionary=native.diagnostics.get(component.id,{}).get("input_bindings",{})
        var requested:Array=component.native_clip.inputs;var supplied:Array=bindings.get("supplied",[])
        check(bindings.get("unavailable",{}).is_empty() and requested.all(func(channel):return channel in supplied) \
            and supplied.all(func(channel):return channel in requested),label+" all exact declared input channels are supplied")
        var observation:Dictionary=program.capture_observation().high_level_support
        check(observation.event_admitted and not observation.owner_admitted and observation.visible_pieces>0,label+" actual admitted source submits finite geometry")
        world.camera_focus=Play.Placement.contact({"position":component.to_position,"base_height_steps":float(component.get("to_elevation_feet",0.0))/5.0})
        world.camera.size=3.5;world.initial_focus=true;world.position_camera();world.grid_visible=false
        world.set_process(false);await frame();await frame()
        var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
        var present:Image=view.get_texture().get_image()
        var stem:String="res://.runtime/positive-healing-captures/"+seat+"-"+str(component.native_clip.id).get_file()+"-"+str(cycle)
        check(present.save_png(stem+"-present.png")==OK,label+" actual native output capture saved")
        handle.root.hide();await frame();await frame()
        var absent:Image=view.get_texture().get_image();var pixels:int=changed(present,absent)
        check(pixels>0,label+" this actual restoration source independently changes framebuffer pixels")
        check(absent.save_png(stem+"-absent.png")==OK,label+" same-cut source-hidden control saved")
        check(var_to_bytes(world.timeline.state)==canonical and var_to_bytes(component)==component_bytes \
            and var_to_bytes(phase.to_clip())==sealed,label+" rendering preserves canonical state, shared cue and sealed Factory preset")
        evidence.append({"seat":seat,"clip":component.native_clip.id,"at_ms":at,"source_occurrence":component.source_event_uuid,"changed_pixels":pixels,"capture":stem+"-present.png","heal_fact":event.heal_fact,"observation":observation})
        handle.root.show();previous=weakref(handle.root);world.set_process(true);cycle+=1
    var native=world.component_renderer.native_spells;native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty(),label+" teardown releases all finite owners")
    check(previous==null or previous.get_ref()==null,label+" final native owner is released")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+" actual seeking and looping have no rendering/resource errors")
    view.queue_free();await frame();await frame()
func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Original independent two-seat positive Power Word Heal, actual receiver geometry, exact healing occurrence and declared input admission, finite framebuffer output, seeking/looping/teardown. Condition retirement probes, held effects, performance and user art acceptance remain separate."}
    FileAccess.open("res://.runtime/native-positive-healing-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_POSITIVE_HEALING ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
