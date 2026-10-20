extends "res://tests/native_vampiric_touch_render_checks.gd"
## Same native Play/Recording harness, with finite high-level support sources.
## No Studio-only renderer or synthetic source/recipient/outcome recordings.
const SOURCES={
    "aura-of-life":"high-level-22/aura-of-life/windup",
    "foresight":"high-level-22/foresight/windup",
    "power-word-heal":"high-level-22/power-word-heal/spoken_word"}
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute("res://.runtime/support-event-captures")
    for example in SOURCES:
        for seat in ["amber","blue"]:await case_seat(example,seat)
    finish()
func case_seat(example:String,seat:String)->void:
    var label:String=example+"/"+seat
    var index:Dictionary=Recording.read(Fixtures.journal(example,seat))
    check(index.ok,label+" unchanged original recording compiles")
    if not index.ok:return
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_cue",{}).get("staged_clip")==SOURCES[example])
    check(rows.size()==1,label+" the actual cast owns one finite preparation")
    if rows.size()!=1:return
    var row:Dictionary=rows[0];var component:Dictionary=row.component
    check(component.status=="available" and not component.get("persistent_owner",false),label+" finite source has actual event operands and no held ownership")
    var original:PackedByteArray=var_to_bytes(component)
    var phase:Resource=load(Effects.choice(component.native_clip).approaches[0].source_phase)
    var sealed:PackedByteArray=var_to_bytes(phase.to_clip())
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var start:float=float(row.start_ms);var end:float=float(row.end_ms)
    var during:float=start+minf(200.0,(end-start)*.35)
    var previous:WeakRef
    var pass_index:int=0
    # Rewind before and after the actual finite interval, then replay it. The
    # normal epoch teardown must not reuse a source's future sampled state.
    for at in [maxf(0.0,start-2.0),during,end+2.0,maxf(0.0,start-2.0),during]:
        world.install_playback(Recording.restore(index,at))
        if not await settle(world,component.id if at==during else ""):
            world.component_renderer.native_spells.close(world);view.queue_free();await frame();return
        if previous!=null:check(previous.get_ref()==null,label+" a replaced seek/loop epoch frees its previous source owner")
        var native=world.component_renderer.native_spells
        if at!=during:
            check(native.witnesses.all(func(witness):return witness.id!=component.id),label+" no finite draw witness before/after its source envelope")
            if native.handles.has(component.id):
                var inactive:Dictionary=native.handles[component.id]
                if at<start or at>end:
                    check(not inactive.root.is_visible_in_tree(),label+" prepared future/retired owner stays hidden")
                else:
                    # A cast beginning at t=0 has no negative recording cut.
                    # Its true initial source envelope must remain empty.
                    for early_program in inactive.occurrence.input_receivers.get("set_event_input",[]):
                        check(early_program.envelope==0.0 and early_program.pieces.all(func(piece):return not piece.is_visible_in_tree()),label+" initial zero-age boundary has no visible preparation geometry")
            previous=null
            continue
        check(native.handles.has(component.id),label+" actual preparation has a native owner after seek")
        if not native.handles.has(component.id):continue
        var handle:Dictionary=native.handles[component.id]
        var programs:Array=handle.occurrence.input_receivers.get("set_event_input",[])
        check(programs.size()==1,label+" one sealed native source receives the event")
        if programs.size()!=1:continue
        var program:Node3D=programs[0]
        check(program.event_input==component.native_inputs.event_input and program.event_admitted() and program.phase_admitted(),label+" native source admits the exact original cast, not a review event")
        check(program.lease.is_empty() and not program.owner_admitted(),label+" finite preparation fabricates no persistent lease")
        check(program.settings.event.is_empty() and program.settings.lease.is_empty() and program.settings.get("parent_owner_uuid","").is_empty(),label+" private construction clears unused review success/parent packets")
        check(program.settings.event_uuid==str(component.source_event_uuid) and program.settings.source_entity_uuid==component.actor_uuid \
            and program.settings.recipient_entity_uuid==component.target_uuid,label+" actual source, recipient and local occurrence reach the constructor")
        check(not program.event_input.has("heal_fact") and not program.event_input.has("actual_healing"),label+" cast source does not invent positive healing/restoration")
        check(program.settings.geometry_actor==component.actor_uuid and program.surface.get("actor")==component.actor_uuid \
            and program.surface.get("points",[]).size()>=8 and not program.frame.is_empty(),label+" native source receives measured geometry for the actual caster")
        check(world.playbacks.has(component.actor_uuid) and world.playbacks[component.actor_uuid].clip==component.cast_recipe.actionClip,label+" actual authored body casting clip is playing")
        var hands:Array=program.endpoints.filter(func(endpoint):return endpoint.socket=="cast_hand" and endpoint.actor_uuid==component.actor_uuid)
        var faces:Array=program.endpoints.filter(func(endpoint):return endpoint.socket=="face" and endpoint.actor_uuid==component.actor_uuid)
        check(hands.size()==1 and hands[0].point.is_equal_approx(handle.endpoints.hand),label+" exact measured current casting hand is bound")
        check(faces.size()==1 and program.endpoints.size()==3,label+" explicit measured head/face registration and all three authored endpoints are bound")
        if example=="power-word-heal":
            var recipients:Array=program.endpoints.filter(func(endpoint):return endpoint.socket=="body_center" and endpoint.actor_uuid==component.target_uuid)
            check(program.settings.voice_recipient_actor==component.target_uuid and component.target_uuid!=component.actor_uuid \
                and recipients.size()==1 and not recipients[0].point.is_equal_approx(faces[0].point),label+" source speech is directed from the actual face toward the actual patient's body")
        else:check(component.target_uuid==component.actor_uuid,label+" caster-only windup retains its authored recipient role")
        var bindings:Dictionary=native.diagnostics.get(component.id,{}).get("input_bindings",{})
        var requested:Array=component.native_clip.inputs
        var supplied:Array=bindings.get("supplied",[])
        check(bindings.get("unavailable",{}).is_empty() and "targets" in requested and "targets" in supplied \
            and requested.all(func(channel):return channel in supplied) and supplied.all(func(channel):return channel in requested),label+" exact declared inputs, including targets, are resolved without crediting unrequested channels")
        var observation:Dictionary=program.capture_observation().high_level_support
        check(observation.event_admitted and not observation.owner_admitted and observation.visible_pieces>0,label+" admitted native source submits finite geometry without a held owner")
        world.camera_focus=Play.Placement.contact({"position":component.from_position,"base_height_steps":float(component.get("from_elevation_feet",0.0))/5.0})
        world.camera.size=3.5;world.initial_focus=true;world.position_camera();world.grid_visible=false
        await frame();await frame();world.set_process(false)
        var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
        var present:Image=view.get_texture().get_image()
        var stem:String="res://.runtime/support-event-captures/"+example+"-"+seat+"-"+str(pass_index)
        check(present.save_png(stem+"-present.png")==OK,label+" actual finite native output capture saved")
        Effects.hide(handle);await frame();await frame()
        var absent:Image=view.get_texture().get_image()
        var pixels:int=changed(present,absent)
        check(pixels>0,label+" the actual finite support source changes framebuffer pixels")
        check(absent.save_png(stem+"-absent.png")==OK,label+" same-cut source-hidden comparison saved")
        check(var_to_bytes(world.timeline.state)==canonical and var_to_bytes(component)==original \
            and var_to_bytes(phase.to_clip())==sealed,label+" source drawing/hiding preserves canonical facts, shared component and immutable Factory preset")
        evidence.append({"case":example,"seat":seat,"at_ms":at,"changed_pixels":pixels,"capture":stem+"-present.png",
            "source_occurrence":component.source_event_uuid,"source_lineage":component.source_lineage,"event":program.event_input.duplicate(true),"observation":observation})
        previous=weakref(handle.root);handle.root.show();world.set_process(true);pass_index+=1
    var native=world.component_renderer.native_spells
    native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty(),label+" explicit teardown releases prepared source/geometry owners")
    check(previous==null or previous.get_ref()==null,label+" final finite source is freed on close")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+" real seeks/looping introduce no presentation/resource errors")
    view.queue_free();await frame();await frame()
func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Original independent two-seat finite Aura of Life/Foresight preparation and Power Word Heal speech, actual Play body/sockets/source admission/geometry/pixels and seek/loop/teardown. No held/recovery/positive-heal restoration, full-family, performance or user-art acceptance claim."}
    FileAccess.open("res://.runtime/native-support-spell-event-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SUPPORT_SPELL_EVENTS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
