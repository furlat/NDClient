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
    # An explicit --recording may supply another original disclosed room.
    # Do not start a second reader over the source already opened by Play.
    var opened:Dictionary={"ok":true}
    if scene.session.replay_thread==null:opened=scene.session.open_recording(Fixtures.journal("door"))
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
    var flame:Dictionary=scene.fixture_clips[scene.fixture_entries[0].placement.lit_animation] if not scene.fixture_entries.is_empty() else {}
    check(not flame.is_empty() and flame.authored.frames.size()==16,"Original recorded fixtures have the actual sixteen-frame authored flame cycle")
    if flame.is_empty():await finish_local(scene);return
    var cycle_ms:float=1000.0*flame.authored.frames.size()/float(flame.authored.fps)
    visual_origin_ms=ceilf(visual_origin_ms/cycle_ms)*cycle_ms
    var frame_ms:float=1000.0/float(flame.authored.fps)
    # User settings may intentionally enable flicker. Pin only this test's
    # in-memory controls; never rewrite the saved profile to obtain a witness.
    scene.fire_light_flicker=false;scene.source_lighting.fire_light_flicker=false
    check(not scene.fire_light_flicker and not scene.source_lighting.fire_light_flicker,"Explicit test-only static fire profile is independent of saved preferences")
    # Choose a real disclosed contact inside competing actual source cookies.
    # No arbitrary tie/crossover is required at that contact.
    var actor_id:String=await select_recorded_caster(scene,deadline)
    check(not actor_id.is_empty(),"Original door journal has an actual geometry caster under competing disclosed sources")
    if actor_id.is_empty():await finish_local(scene);return
    scene.fire_light_flicker=false;scene.source_lighting.fire_light_flicker=false
    scene.camera_focus=scene.Placement.contact(scene.visual_actors[actor_id].row)
    scene.camera.size=6.0;scene.position_camera()
    DirAccess.make_dir_recursive_absolute("res://.captures/shadow-idle")
    var static_values=[]
    for frame in 16:
        scene.timeline.display_ms=visual_origin_ms+(frame+.25)*frame_ms
        await scene.presentation_updated
        static_values.append(scene.source_lighting.sampled.duplicate(true))
    check(static_values.all(func(value):return value==static_values[0]),"Authored mean keeps receiving light position/brightness static across all16 flame frames")
    scene.fire_light_flicker=true;scene.source_lighting.fire_light_flicker=true
    var energy_control_sensitive_quarters=0
    var all_rows=[]
    for quarter in 4:
        scene.request_view(quarter)
        while scene.rotation_pending() and Time.get_ticks_msec()<deadline:await scene.presentation_updated
        check(scene.quarter==quarter,"Quarter publishes before native shadow check")
        var stable={};var frames={};var energies={};var directions=[]
        var policy:Dictionary={};var control_scores:Dictionary={};var control_weights:Dictionary={};var live_weights:Dictionary={}
        var fixed:Dictionary={}
        for light in scene.source_lighting.sources:
            if light.actor_uuid.is_empty() and scene.fixture_shadow_heights.has(light.get("anchor_item_uuid",light.item_uuid)):fixed[light.item_uuid]=true
        var table_ready:bool=true;var mean_energy:bool=true;var support_cookie:bool=true;var invariant_policy:bool=true;var exact_control:bool=true
        for frame in 16:
            scene.timeline.display_ms=visual_origin_ms+(frame+.25)*frame_ms
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
            # Native range cookies already use the fixed support-plane center;
            # that migration retired optical-height-driven ranking movement.
            # Isolate the remaining energy sensitivity by removing only the
            # cycle-mean energy override, never the actual cookie/contact.
            var sources:Array=scene.source_lighting.canvas_sources()
            var instantaneous=sources.duplicate(true)
            for light in instantaneous:light.erase("shadow_rank_energy")
            var control=scene.GeneratedShadows.new()
            control._cookie_images=scene.generated_shadows._cookie_images.duplicate()
            var ready:bool=control._prepare_sources(instantaneous)
            table_ready=table_ready and ready
            var foot:Vector2=scene.camera.unproject_position(scene.Placement.contact(actor.row))
            var scores:Dictionary=source_scores(control,foot) if ready else {}
            observe_ranges(control_scores,scores)
            var frame_policy:Dictionary={}
            for light in sources:
                if not light.enabled or not fixed.has(light.id):continue
                var index:int=scene.generated_shadows._source_ids.find(light.id)
                var control_index:int=control._source_ids.find(light.id)
                table_ready=table_ready and index>=0 and control_index>=0
                if index<0 or control_index<0:continue
                var prepared:Dictionary=scene.generated_shadows._source_row(index)
                var control_row:Dictionary=control._source_row(control_index)
                var colour:Color=light.color.srgb_to_linear()
                var luminance:float=.2126*colour.r+.7152*colour.g+.0722*colour.b
                var expected_mean:float=scene.source_lighting.OPTICAL_ENERGY*scene.source_lighting.light_strength*luminance
                mean_energy=mean_energy and is_equal_approx(prepared.shadow_rank_strength,expected_mean)
                var support:Vector3=Vector3(light.world_position.x,light.base_height_steps*scene.Placement.HEIGHT_UNIT,light.world_position.z)
                var expected_cookie:Vector2=scene.camera.unproject_position(support)
                support_cookie=support_cookie and light.has("cookie_position") and prepared.shadow_cookie_position.is_equal_approx(expected_cookie) and prepared.shadow_cookie_position.is_equal_approx(light.cookie_position)
                exact_control=exact_control and is_equal_approx(control_row.shadow_rank_strength,prepared.strength) and control_row.shadow_cookie_position==prepared.shadow_cookie_position and control_row.span==prepared.span
                var ranking:Dictionary={"weight":prepared.shadow_rank_strength,"cookie":prepared.shadow_cookie_position,"span":prepared.span}
                if not policy.has(light.id):policy[light.id]=ranking
                invariant_policy=invariant_policy and policy[light.id]==ranking
                observe_ranges(live_weights,{light.id:prepared.strength})
                observe_ranges(control_weights,{light.id:control_row.shadow_rank_strength})
                frame_policy[light.id]={"rank_weight":prepared.shadow_rank_strength,"live_weight":prepared.strength,"cookie":str(prepared.shadow_cookie_position),"control_score":scores.get(light.id,0.0)}
            control.close()
            all_rows.append({"quarter":quarter,"frame":frame,"source_id":source,"native_direction":directions.back(),"fixed_source_policy":frame_policy})
            if quarter==1 and frame in [1,8]:
                root.get_texture().get_image().save_png("res://.captures/shadow-idle/q1-frame%d.png"%frame)
        check(stable.size()==1,"One casting direction across all16 actual idle/flame frames q"+str(quarter))
        check(frames.size()>1 and energies.size()>1,"Original idle body and receiving-light flicker keep animating q"+str(quarter))
        check(table_ready and not policy.is_empty(),"Production and energy-only control prepare the same actual fixed source rows q"+str(quarter))
        check(mean_energy and invariant_policy,"Production shadow ranking consumes invariant full-cycle mean energy across sixteen authored frames q"+str(quarter))
        check(support_cookie,"Production ranking uses each actual fixed source's support-plane cookie center q"+str(quarter))
        check(exact_control,"Energy-only control preserves actual cookie geometry and consumes instantaneous receiving weight q"+str(quarter))
        check(live_weights.values().any(func(value):return value.max-value.min>.000001),"Actual fixed flame receiving weights vary while production ranking stays invariant q"+str(quarter))
        var positive:int=0;var sensitive:bool=false
        for id in control_scores:
            var score:Dictionary=control_scores[id]
            if score.min>0.0:positive+=1
            if fixed.has(id) and score.min>0.0 and score.max-score.min>.000001 and control_weights.has(id) and control_weights[id].max-control_weights[id].min>.000001:sensitive=true
        if positive>1 and sensitive:energy_control_sensitive_quarters+=1
    check(energy_control_sensitive_quarters>0,"At an actually disclosed competing contact, instantaneous-energy control scores vary while production source selection remains stable")
    selection_evidence["energy_control_sensitive_quarters"]=energy_control_sensitive_quarters
    scene.fire_light_flicker=false;scene.source_lighting.fire_light_flicker=false
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
func select_recorded_caster(scene:Node,deadline:int)->String:
    var candidates:Dictionary={}
    var actual_sources:Array=[]
    var fixed_sources:Dictionary={}
    for source in scene.source_lighting.sources:
        actual_sources.append({"id":source.item_uuid,"actor":source.actor_uuid,"position":str(source.position)})
        if source.actor_uuid.is_empty() and scene.fixture_shadow_heights.has(source.get("anchor_item_uuid",source.item_uuid)):fixed_sources[source.item_uuid]=true
    check(not fixed_sources.is_empty() and actual_sources.size()>1,"Original door journal discloses actual fixed flames and competing optical sources")
    for quarter in 4:
        scene.request_view(quarter)
        while scene.rotation_pending() and Time.get_ticks_msec()<deadline:await scene.presentation_updated
        await scene.presentation_updated
        for id in scene.visual_actors:
            var actor:Dictionary=scene.visual_actors[id]
            if not scene.generated_shadows.actors.has(id) or scene.generated_shadows._snapshots(actor.entries,scene.camera).is_empty():continue
            if not candidates.has(id):candidates[id]={"position":actor.row.position.duplicate(),"quarters":{}}
            var scores:Dictionary=source_scores(scene.generated_shadows,scene.camera.unproject_position(scene.Placement.contact(actor.row)))
            var positive:Array=[];var fixed_positive:bool=false
            for source_id in scores:
                if scores[source_id]<=0.0:continue
                positive.append(source_id)
                if fixed_sources.has(source_id):fixed_positive=true
            candidates[id].quarters[quarter]={"positive_sources":positive,"competing_fixed":positive.size()>1 and fixed_positive}
    var actor_id:String=""
    var best:int=-1
    var ids:Array=candidates.keys();ids.sort()
    for id in ids:
        var competing:int=0
        for observed in candidates[id].quarters.values():
            if observed.competing_fixed:competing+=1
        candidates[id]["competing_quarters"]=competing
        if competing>best:best=competing;actor_id=id
    selection_evidence={"recording":scene.session.journal.directory,"sources":actual_sources,"candidates":candidates,"selected":actor_id,
        "competing_contact_available":best>0,"policy":"stable_support_cookie_and_cycle_mean_energy; control_changes_energy_only"}
    return actor_id if best>0 else ""

func source_scores(table:RefCounted,foot:Vector2)->Dictionary:
    var result:Dictionary={}
    for index in table._source_ids.size():
        var source:Dictionary=table._source_row(index)
        var uv:Vector2=(foot-source.shadow_cookie_position)/source.span+Vector2.ONE*.5
        var image:Image=table._cookie_images[source.texture.get_rid()]
        result[source.id]=source.shadow_rank_strength*table._cookie_at(image,uv)
    return result

func observe_ranges(ranges:Dictionary,values:Dictionary)->void:
    for id in values:
        var value:float=values[id]
        if not ranges.has(id):ranges[id]={"min":value,"max":value}
        else:
            ranges[id].min=minf(ranges[id].min,value)
            ranges[id].max=maxf(ranges[id].max,value)

func finish_local(scene:Node)->void:
    var report={"checks":checks,"failures":failures,"frames":receipts,"selection":selection_evidence,"scope":"Original schema16 door journal canonical drain, actual disclosed geometry caster under competing actual cookies, all4quarters/all16 authored flame frames; production cycle-mean ranking and support-plane cookie invariance plus instantaneous-energy score sensitivity control; native shadow clipping/visibility and canonical immutability remain checked."}
    FileAccess.open("res://generated/shadow_idle_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SHADOW_IDLE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
    scene.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
