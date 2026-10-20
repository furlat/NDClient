extends "res://tests/native_observed_damage_render_checks.gd"
## Actual ordinary item/object admission with sealed receiving accents.
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for name in ["divine-arm","divine-generosity"]:
        var index:Dictionary=Fixtures.read(name,"party")
        check(index.ok,name+" original party recording compiles")
        if not index.ok:continue
        var rows:Array=index.rows.filter(func(row):return row.get("component",{}).has("native_creation"))
        check(rows.size()==1 and rows[0].component.status=="available",name+" owns one actual admitted-item receiving cue")
        if rows.size()!=1:continue
        var component:Dictionary=rows[0].component
        var at:float=float(rows[0].start_ms)+180.0
        var view:SubViewport=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
        view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
        var world=Play.new();world.external_playback=true;world.external_clock=true
        world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
        world.playback_end_ms=index.presentation_end_ms;world.component_renderer.audio.set_enabled(false)
        view.add_child(world);world.install_playback(Recording.restore(index,at))
        if not await settle(world):view.queue_free();await frame();continue
        world.camera_focus=Play.Placement.contact({"position":component.to_position,"base_height_steps":float(component.to_elevation_feet)/5.0})
        world.camera.size=7;world.initial_focus=true;world.position_camera();world.grid_visible=false
        var native=world.component_renderer.native_spells
        check(native.handles.has(component.id),name+" actual admission source is prepared")
        if not native.handles.has(component.id):view.queue_free();await frame();continue
        var handle:Dictionary=native.handles[component.id]
        var programs:Array=handle.occurrence.input_receivers.get("set_event_input",[])
        check(programs.size()==1,name+" receiving setter binds exactly one source program")
        for program in programs:
            check(program.event_input.ordinary_item_admitted and program.event_input.item_uuid==component.native_creation.item_uuid,name+" actual original item UUID is admitted, never a fixture object")
            check(program.settings.recipient_entity_uuid==component.actor_uuid and program.settings.geometry_actor==component.actor_uuid,name+" actual invoking actor supplies receiving geometry; created object is not a character")
            check(program.capture_observation().divine_study.phase_admitted,name+" source admits the real creation result")
            var point:Array=program.event_input.creation_position_cells
            check(point.size()==3,name+" exact placement or real holder socket supplies source position")
            if component.native_creation.kind=="placed_object":
                check(point==component.native_inputs.event_input.creation_position_cells,name+" native source preserves canonical object base placement")
            else:
                check(not component.native_inputs.event_input.has("creation_position_cells"),name+" authored holder socket does not invent a server item position")
            evidence.append({"case":name,"item_uuid":program.event_input.item_uuid,"position":point,"provenance":component.native_input_evidence.position_source})
        await frame();await frame();world.set_process(false)
        var present:Image=view.get_texture().get_image()
        Effects.hide(handle);await frame();await frame()
        var pixels:int=changed(present,view.get_texture().get_image())
        check(pixels>0,name+" actual receiving accent contributes native framebuffer pixels")
        present.save_png("res://.runtime/native-"+name+".png")
        evidence.append({"case":name,"changed_pixels":pixels})
        var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
        world.set_process(true);world.install_playback(Recording.restore(index,0.0))
        if await settle(world):check(not world.timeline.state.items.has(component.native_creation.item_uuid),name+" reverse seek cannot publish a future created item")
        world.install_playback(Recording.restore(index,at))
        if await settle(world):check(var_to_bytes(world.timeline.state)==canonical,name+" replay restores the identical canonical creation prefix")
        check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),name+" native admission has no presentation/resource errors")
        view.queue_free();await frame();await frame()
    finish()

func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual lawful party creation prefixes, source setter/admission/native output and backward replay. No second faction, later Healing Incense or visual approval claim."}
    FileAccess.open("res://.runtime/native-creation-owner-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_CREATION_OWNER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
