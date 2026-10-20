extends "res://tests/native_observed_damage_render_checks.gd"
## Original two-seat Orb recording, actual persistent owner and native source.
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for seat in ["amber","blue"]:
        var index:Dictionary=Fixtures.read("chromatic-orb",seat)
        check(index.ok,seat+" actual Orb journal compiles")
        if not index.ok:continue
        var at:float=float(index.presentation_end_ms)+4100.0
        var view:SubViewport=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
        view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
        var world=Play.new();world.external_playback=true;world.external_clock=true
        world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
        world.playback_end_ms=at+2000.0;world.component_renderer.audio.set_enabled(false)
        view.add_child(world);world.install_playback(Recording.restore(index,at))
        if not await settle(world):view.queue_free();await frame();continue
        var native=world.component_renderer.native_spells
        var handles:Array=native.handles.values().filter(func(handle):return handle.component.get("spatial_owner",false) and handle.component.get("spatial_content_id")=="spatial_effect.spell.acid_surface")
        check(handles.size()==1,seat+" one disclosed Acid UUID owns one actual native surface")
        if handles.size()!=1:view.queue_free();await frame();continue
        var handle:Dictionary=handles[0]
        var component:Dictionary=handle.component
        var effect:Dictionary=world.timeline.state.senses.spatial_effects[component.spatial_effect_uuid]
        var programs:Array=handle.occurrence.input_receivers.get("set_surface_presence",[])
        check(programs.size()==1,seat+" exact public presence setter reaches the original source")
        for program in programs:
            var observed:Dictionary=program.capture_observation()
            check(observed.surface_admitted and observed.admitted_cells.size()==effect.positions.size(),seat+" actual source admits only the independently disclosed cells")
            check(is_inf(float(program.specification.retire_at_seconds)),seat+" review expiry cannot retire a still-disclosed surface")
            check(program.plane!=null and program.plane.visible,seat+" real source geometry draws after actual setters, not neutral warm-up")
        world.camera_focus=Play.Placement.contact({"position":component.position,"base_height_steps":float(component.elevation_feet)/5.0})
        world.camera.size=7;world.initial_focus=true;world.position_camera();world.grid_visible=false
        await frame();await frame();world.set_process(false)
        var present:Image=view.get_texture().get_image()
        Effects.hide(handle);await frame();await frame()
        var pixels:int=changed(present,view.get_texture().get_image())
        check(pixels>0,seat+" actual surface contributes native framebuffer pixels")
        present.save_png("res://.runtime/native-spatial-"+seat+".png")
        evidence.append({"seat":seat,"spatial_effect_uuid":component.spatial_effect_uuid,"cells":effect.positions,"changed_pixels":pixels})
        var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
        world.set_process(true)
        world.install_playback(Recording.restore(index,0.0))
        if await settle(world):
            check(not world.timeline.state.senses.spatial_effects.has(component.spatial_effect_uuid),seat+" backward seek does not publish a future surface")
        world.install_playback(Recording.restore(index,at))
        if await settle(world):
            check(var_to_bytes(world.timeline.state)==canonical,seat+" repeated loop restores the identical canonical owner state")
            var active:Array=world.component_renderer.native_spells.handles.values().filter(func(item):return item.component.get("spatial_effect_uuid")==component.spatial_effect_uuid)
            check(active.size()==1,seat+" repeated seek owns one fresh prepared surface, without duplicate lifetime")
        check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+" owner replay has no resource/presentation errors")
        view.queue_free();await frame();await frame()
    finish()

func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Original independent Acid surface journals, sealed source setters/native output, exact lifetime, backward seek/replay and teardown. Other material variants/removal scenarios/art approval remain unqualified."}
    FileAccess.open("res://.runtime/native-spatial-owner-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPATIAL_OWNER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
