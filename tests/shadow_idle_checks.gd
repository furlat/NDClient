extends "res://tests/native_2d_integration_checks.gd"
const Fixtures=preload("res://tests/recording_fixtures.gd")
var selection_evidence:Dictionary={}
# The user's recorded room and original idle/flame source frames, not a new
# gameplay scenario. Only the paused visual clock advances after canonical drain.
func run() -> void:
    if DisplayServer.get_name()=="headless":quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,800)
    ProjectSettings.set_setting("source_data/encounter_cache_mib",0)
    var scene=Player.instantiate();scene.timeline.paused=true;root.add_child(scene)
    var opened:Dictionary=scene.session.open_recording(Fixtures.journal("door"))
    check(opened.get("ok",false),"Original schema16 door journal opens through the production session: "+str(opened))
    if not opened.get("ok",false):await finish_local(scene);return
    var deadline=Time.get_ticks_msec()+240000
    while (not scene.session.recording_ready or not scene._media_ready({}) or scene.visual_actors.is_empty()) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
    check(scene.session.recording_ready and scene.media_initial_ready,"Actual user recording initializes through native media and world gates")
    while (scene.timeline.busy() or scene.timeline.sequence<scene.session.latest_sequence) and Time.get_ticks_msec()<deadline:
        scene.timeline.paused=false;scene.timeline.advance(1000);scene.timeline.paused=true;await scene.presentation_updated
    check(not scene.timeline.busy() and scene.timeline.sequence==scene.session.latest_sequence,"Actual user recording drains canonically before isolated idle clock checks")
    check(scene.timeline.state==scene.session.journal.state,"Actual displayed state equals SDK reduction")
    if not failures.is_empty():await finish_local(scene);return
    scene.session.close();scene.hud.hide();scene.grid_visible=false
    var canonical=scene.timeline.state.duplicate(true)
    var trace=scene.timeline.trace.duplicate(true)
    var visual_origin_ms:float=scene.timeline.display_ms
    check(not scene.fire_light_flicker and not scene.source_lighting.fire_light_flicker,"Static fire lighting is the current default")
    # Discover the witness from actual disclosed contacts and actual authored
    # flame samples. A retired screenshot coordinate is not a fixture identity.
    # The independent old-policy control never changes the production sources.
    var actor_id:String=await select_recorded_caster(scene,visual_origin_ms,deadline)
    check(not actor_id.is_empty(),"Original door journal has an actual geometry caster under competing disclosed sources")
    if actor_id.is_empty():await finish_local(scene);return
    scene.source_lighting.fire_light_flicker=false
    scene.camera_focus=scene.Placement.contact(scene.visual_actors[actor_id].row)
    scene.camera.size=6.0;scene.position_camera()
    DirAccess.make_dir_recursive_absolute("res://.captures/shadow-idle")
    var static_values=[]
    for frame in 16:
        scene.timeline.display_ms=visual_origin_ms+frame*100.0
        await scene.presentation_updated
        static_values.append(scene.source_lighting.sampled.duplicate(true))
    check(static_values.all(func(value):return value==static_values[0]),"Authored mean keeps receiving light position/brightness static across all16 flame frames")
    scene.source_lighting.fire_light_flicker=true
    var old_policy_changes=0
    var all_rows=[]
    for quarter in 4:
        scene.request_view(quarter)
        while scene.rotation_pending() and Time.get_ticks_msec()<deadline:await scene.presentation_updated
        check(scene.quarter==quarter,"Quarter publishes before native shadow check")
        var stable={};var old={};var frames={};var energies={};var directions=[]
        for frame in 16:
            scene.timeline.display_ms=visual_origin_ms+frame*100.0
            await scene.presentation_updated
            await RenderingServer.frame_post_draw
            var diagnostics=scene.generated_shadows.diagnostics()
            var source=diagnostics.selected_sources.get(actor_id,"")
            check(not source.is_empty(),"Native idle frame has selected caster source")
            stable[source]=true
            var actor:Dictionary=scene.visual_actors[actor_id]
            for entry in actor.entries:
                if entry.node.visible and entry.role!="shadow":
                    frames[str(entry.material.get_shader_parameter("frame_uv"))]=true
            energies[str(scene.fixture_energy.values())]=true
            var state:Dictionary=scene.generated_shadows.actors[actor_id]
            directions.append([state.light.position.x,state.light.position.z])
            # Retain the original failing selection as an independent control;
            # do not publish it into the live actor's actual caster or frame.
            var old_sources=scene.source_lighting.canvas_sources().duplicate(true)
            for light in old_sources:
                light.erase("shadow_rank_position");light.erase("shadow_rank_energy")
            var control=scene.GeneratedShadows.new()
            control._cookie_images=scene.generated_shadows._cookie_images.duplicate()
            control._prepare_sources(old_sources)
            var selected=control._dominant(scene.camera.unproject_position(scene.Placement.contact(actor.row)))
            old[control._source_ids[selected] if selected>=0 else ""]=true
            control.close()
            all_rows.append({"quarter":quarter,"frame":frame,"source_id":source,"native_direction":directions.back()})
            if quarter==1 and frame in [1,8]:
                root.get_texture().get_image().save_png("res://.captures/shadow-idle/q1-frame%d.png"%frame)
        check(stable.size()==1,"One casting direction across all16 actual idle/flame frames q"+str(quarter))
        check(frames.size()>1 and energies.size()>1,"Original idle body and receiving-light flicker keep animating q"+str(quarter))
        if old.size()>1:old_policy_changes+=1
    check(old_policy_changes>0,"Original instantaneous-ranking control reproduces source-switch defect in the actual room")
    scene.source_lighting.fire_light_flicker=false
    var actual:Dictionary=scene.generated_shadows.actors[actor_id]
    var visibility_image=actual.viewport.get_texture().get_image()
    var blocked=0;var fractional=0;var minimum=1.0
    for y in visibility_image.get_height():
        for x in visibility_image.get_width():
            var value=visibility_image.get_pixel(x,y).srgb_to_linear().r
            minimum=minf(minimum,value)
            if value<.99:blocked+=1
            if value>.02 and value<.98:fractional+=1
    print("ACTUAL_SHADOW_VISIBILITY ",JSON.stringify({"minimum":minimum,"blocked":blocked,"fractional":fractional}))
    check(blocked>0,"Actual native actor caster produces blocked visibility samples")
    var snapshots=scene.generated_shadows._snapshots(scene.visual_actors[actor_id].entries,scene.camera)
    var origin=scene.Placement.contact(scene.visual_actors[actor_id].row)
    var ppu=scene.camera.unproject_position(origin+scene.camera.global_basis.x).distance_to(scene.camera.unproject_position(origin))
    var ground=snapshots[0].ground_pixels*snapshots[0].component_units
    var selected=scene.generated_shadows._dominant(scene.camera.unproject_position(origin))
    var source=scene.generated_shadows._source_row(selected)
    var zoom=snapshots[0].component_units*ppu
    var projection=scene.generated_shadows._projection(scene.camera,origin,ground,snapshots[0].component_units,zoom,source.screen_position,source.height)
    var probe=scene.GeneratedShadows.new();probe.attach(scene)
    for dimensions in [Vector2(1,10),Vector2(10,1),Vector2(1,1)]:
        var rect=probe._sampling_rect(Rect2(Vector2.ZERO,dimensions),1.0)
        var size=Vector2i(rect.size)
        var helper=probe._create("narrow")
        probe.actors.narrow=helper
        probe._update_casters(helper,snapshots,scene.camera,origin,ground,false)
        probe._update_layout(helper,scene.camera,origin,ground,projection,rect,size,ppu);probe._render(helper)
        await RenderingServer.frame_post_draw
        var native_size=helper.viewport.get_texture().get_image().get_size()
        check(native_size==probe.TARGET and helper.footprint==size and size.x>=2 and size.y>=2,"Clipped shadow keeps the expanded sample dimensions in its fixed target")
        var projected_width=helper.camera.size*float(native_size.x)/native_size.y*ppu
        check(is_equal_approx(projected_width,rect.size.x/size.x*native_size.x) and helper.entry.node.mesh.size.is_equal_approx(rect.size/ppu),"Clipped shadow camera and output quad retain identical screen-space aspect")
        probe._remove("narrow")
    probe.close()
    check(scene.timeline.state==canonical and scene.timeline.trace==trace,"Idle visual sampling changes no canonical state, events or logs")
    check(scene.presentation_errors.is_empty() and scene.generated_shadows.issues.is_empty(),"No source/preparation/native shadow issues")
    receipts=all_rows
    await finish_local(scene)
func select_recorded_caster(scene:Node,origin_ms:float,deadline:int)->String:
    var candidates:Dictionary={}
    var actual_sources:Array=[]
    var fixed_sources:int=0
    for source in scene.source_lighting.sources:
        actual_sources.append({"id":source.item_uuid,"actor":source.actor_uuid,"position":str(source.position)})
        if source.actor_uuid.is_empty():fixed_sources+=1
    check(fixed_sources>0 and actual_sources.size()>1,"Original door journal discloses actual fixed flames and competing optical sources")
    scene.source_lighting.fire_light_flicker=true
    for quarter in 4:
        scene.request_view(quarter)
        while scene.rotation_pending() and Time.get_ticks_msec()<deadline:await scene.presentation_updated
        for frame in 16:
            scene.timeline.display_ms=origin_ms+frame*100.0
            await scene.presentation_updated
            var old_sources:Array=scene.source_lighting.canvas_sources().duplicate(true)
            for light in old_sources:
                light.erase("shadow_rank_position");light.erase("shadow_rank_energy")
            var control=scene.GeneratedShadows.new()
            control._cookie_images=scene.generated_shadows._cookie_images.duplicate()
            var ready:bool=control._prepare_sources(old_sources)
            for id in scene.visual_actors:
                var actor:Dictionary=scene.visual_actors[id]
                if not scene.generated_shadows.actors.has(id) or scene.generated_shadows._snapshots(actor.entries,scene.camera).is_empty():continue
                if not candidates.has(id):candidates[id]={"position":actor.row.position.duplicate(),"quarters":{}}
                if not candidates[id].quarters.has(quarter):candidates[id].quarters[quarter]={}
                var selected:int=control._dominant(scene.camera.unproject_position(scene.Placement.contact(actor.row))) if ready else -1
                var source:String=control._source_ids[selected] if selected>=0 else ""
                candidates[id].quarters[quarter][source]=true
            control.close()
    var actor_id:String=""
    var best:int=-1
    var ids:Array=candidates.keys();ids.sort()
    for id in ids:
        var switches:int=0
        for observed in candidates[id].quarters.values():
            if observed.size()>1 and not observed.has(""):switches+=1
        candidates[id]["switching_quarters"]=switches
        if switches>best:best=switches;actor_id=id
    selection_evidence={"recording":Fixtures.journal("door"),"sources":actual_sources,"candidates":candidates,"selected":actor_id}
    # An absent reproducer stays an honest failure of the unchanged policy
    # counterfactual below; never move an actor or manufacture a test light.
    return actor_id

func finish_local(scene:Node)->void:
    var report={"checks":checks,"failures":failures,"frames":receipts,"selection":selection_evidence,"scope":"Original schema16 door journal canonical drain, actual disclosed geometry caster selected by the independent source-switch control, all4quarters/all16 authored flame frames; native shadow helper/source identity plus original-policy selection control; current colour/brightness/body frames remain animated."}
    FileAccess.open("res://generated/shadow_idle_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SHADOW_IDLE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
    scene.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
