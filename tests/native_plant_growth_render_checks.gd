extends "res://tests/native_observed_damage_render_checks.gd"
## Production Play/Recording path, exact original two-seat spatial owner.
const Spatial=preload("res://presentation/spatial_inputs.gd")
const OWNER="spatial_effect.spell.plant_growth"
const CLIP="bg3-36/plant-growth/plant_growth_native"
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for seat in ["amber","blue"]:
        var index:Dictionary=Fixtures.read("plant-growth",seat)
        check(index.ok,seat+" unchanged original journal compiles")
        if not index.ok:continue
        var at:float=float(index.presentation_end_ms)+1800.0
        var view:SubViewport=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
        view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
        var world=Play.new();world.external_playback=true;world.external_clock=true
        world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
        world.playback_end_ms=at+10000.0;world.component_renderer.audio.set_enabled(false)
        view.add_child(world);world.install_playback(Recording.restore(index,at))
        if not await settle(world):view.queue_free();await frame();continue
        var native=world.component_renderer.native_spells
        var handles:Array=native.handles.values().filter(func(handle):return handle.component.get("spatial_content_id")==OWNER)
        check(handles.size()==1,seat+" one real spatial UUID owns one vegetation occurrence")
        if handles.size()!=1:view.queue_free();await frame();continue
        var handle:Dictionary=handles[0];var component:Dictionary=handle.component
        var effect:Dictionary=world.timeline.state.senses.spatial_effects[component.spatial_effect_uuid]
        check(component.actor_uuid==null and component.target_uuid==null,seat+" independent spatial source fabricates no actor endpoint")
        check(component.native_clip.id==CLIP and component.resolved_area_positions==effect.positions,seat+" actual content and disclosed footprint choose the original source")
        var programs:Array=handle.occurrence.input_receivers.get("set_removed_cells",[])
        check(programs.size()==1,seat+" prepared receiver index resolves the original two-argument setter")
        for program in programs:
            var expected:Array=effect.positions.map(func(point):return [point[0]-component.position[0],point[1]-component.position[1]])
            var observation:Dictionary=program.capture_observation()
            check(program.specification.cells==expected and program.groups.size()==49,seat+" original program constructs all 49 actual cells in the correct source frame")
            check(program.specification.observed_removals.is_empty() and program.removal_times.is_empty(),seat+" neither review burn nor subjective visibility fabricates permanent removal")
            check(observation.supplied_cells==49 and observation.removed_cells==0 and not observation.auto_regrowth,seat+" native observation agrees with the actual baseline")
            var mapped:Array=program.groups.map(func(group):return [group.cell[0]+component.position[0],group.cell[1]+component.position[1]])
            check(mapped==effect.positions,seat+" every native vegetation group maps back to its exact recorded world cell")
        var inputs:Dictionary=native.diagnostics[component.id].get("input_bindings",{})
        check(inputs.get("unavailable",{}).is_empty() and "removed_cells" in inputs.get("supplied",[]),seat+" all original required input channels resolve")
        world.camera_focus=Play.Placement.contact({"position":[6,7],"base_height_steps":float(component.elevation_feet)/5.0})
        world.camera.size=11;world.initial_focus=true;world.position_camera();world.grid_visible=false
        await frame();await frame();world.set_process(false)
        var present:Image=view.get_texture().get_image()
        Effects.hide(handle);await frame();await frame()
        var pixels:int=changed(present,view.get_texture().get_image())
        check(pixels>0,seat+" real constructed vegetation contributes native framebuffer pixels")
        present.save_png("res://.runtime/native-plant-growth-"+seat+".png")
        var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
        evidence.append({"seat":seat,"spatial_effect_uuid":component.spatial_effect_uuid,"cells":effect.positions,
            "constructor_cells":programs[0].specification.cells if not programs.is_empty() else [],"changed_pixels":pixels,"observed_removals":[]})
        world.set_process(true);world.install_playback(Recording.restore(index,0.0))
        if await settle(world):
            check(not world.timeline.state.senses.spatial_effects.has(component.spatial_effect_uuid),seat+" backward seek does not publish future membership")
            check(not world.component_renderer.native_spells.handles.values().any(func(value):return value.component.get("spatial_effect_uuid")==component.spatial_effect_uuid and value.root.is_visible_in_tree()),seat+" earlier epoch displays no future constructed vegetation, including privately prepared lookahead")
        world.install_playback(Recording.restore(index,at+5000.0))
        if await settle(world):
            check(var_to_bytes(world.timeline.state)==canonical,seat+" seek/loop preserves exact canonical field state")
            var active:Array=world.component_renderer.native_spells.handles.values().filter(func(value):return value.component.get("spatial_effect_uuid")==component.spatial_effect_uuid)
            check(active.size()==1 and is_inf(float(active[0].component.duration_ms)),seat+" fresh epoch owns one source beyond its finite review clip length")
            if active.size()==1:
                var fresh:Array=active[0].occurrence.input_receivers.get("set_removed_cells",[])
                check(fresh.size()==1 and fresh[0].groups.size()==49 and fresh[0].removal_times.is_empty(),seat+" looping retains actual topology without stale burn history")
        check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+" native production playback has no presentation/media errors")
        view.queue_free();await frame();await frame()
    finish()
func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual two-seat Plant Growth baseline, original source cells/timed-input admission, native pixels, independent epochs/seek/loop. No partial burn, undisclosed extension, performance or user art approval claim."}
    FileAccess.open("res://.runtime/native-plant-growth-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_PLANT_GROWTH ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
