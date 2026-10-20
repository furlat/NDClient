extends "res://tests/native_vampiric_touch_render_checks.gd"
## One shared provider: current copies, original departure and rolling history.
## Every input below comes from the two untouched subjective recordings.
const HISTORY_CASES=[{"id":"blur","path":"res://tests/fixtures/schema16/scenarios/blur","condition":"condition.spell.blur"},
    {"id":"mirror","path":"res://tests/fixtures/schema16/mirror-image","condition":"condition.spell.mirror_image"},
    {"id":"departure","path":"res://tests/fixtures/schema16/banishment-departure","condition":"condition.spell.banishment"}]
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for source in HISTORY_CASES:
        var selected:Array=Array(OS.get_cmdline_user_args()).filter(func(arg):return str(arg).begins_with("--case="))
        if not selected.is_empty() and str(selected[0]).trim_prefix("--case=")!=source.id:continue
        for seat in ["amber","blue"]:await history_case(source,seat)
    finish()
func history_case(source:Dictionary,seat:String)->void:
    var path:String=Fixtures.journal("blur",seat) if source.id=="blur" else source.path.path_join(seat)
    var index:Dictionary=Recording.read(path)
    var label:String=source.id+"/"+seat
    check(index.ok,label+": unchanged original stream admits")
    if not index.ok:return
    var spans:Array=index.rows.filter(func(row):return row.kind=="condition" and row.get("owner",{}).get("condition",{}).get("behavior_id")==source.condition)
    check(spans.size()==1,label+": one genuine condition lifetime")
    if spans.size()!=1:return
    var span:Dictionary=spans[0];var owner:String=span.owner.id;var actor:String=span.owner.actor_uuid
    var at:float=minf(float(index.presentation_end_ms)-1.0,float(span.start_ms)+650.0)
    if is_finite(float(span.end_ms)):at=minf(at,float(span.end_ms)-100.0)
    # The rolling provider must demonstrate actual old displacement.
    if source.id=="blur":
        for wrapped in index.groups:
            for track in wrapped.group.actor_tracks:
                var start:float=float(wrapped.start_ms)+float(track.start_ms)
                if track.actor_uuid==actor and track.get("motion",false) and start>=float(span.start_ms) and start<float(span.end_ms):
                    at=start+float(track.duration_ms)*.8;break
    var view:=SubViewport.new();view.size=Vector2i(640,480);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms;world.component_renderer.audio.set_enabled(false)
    view.add_child(world)
    var position:Variant=Recording.restore(index,at).state.actors[actor].get("last_visual_position",[4,7])
    if position==null:position=[4,7]
    world.camera_focus=Vector3(position[0],0,position[1]);world.initial_focus=true;world.camera.size=4.0;world.position_camera();world.grid_visible=false
    var original:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var last:WeakRef
    for quarter in [0,1,2,3,0]:
        world.install_playback(Recording.restore(index,at));world.request_view(quarter)
        var deadline:int=Time.get_ticks_msec()+45000
        while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
        check(not world.rotation_pending() and world.quarter==quarter,label+": current view publishes "+str(quarter))
        if last!=null:check(last.get_ref()==null,label+": replay epoch frees its previous occurrence and private layers")
        if not await settle(world):break
        var native:RefCounted=world.component_renderer.native_spells
        var ids:Array=native.handles.keys().filter(func(id):return native.handles[id].component.get("condition_uuid")==owner and "actor_context" in native.handles[id].clip.get("inputs",[]))
        check(ids.size()==1,label+": actual UUID selects one complete history occurrence")
        if ids.size()!=1:break
        var handle:Dictionary=native.handles[ids[0]]
        var binding:Dictionary=native.diagnostics.get(ids[0],{}).get("input_bindings",{})
        if not binding.get("unavailable",{}).is_empty():
            print("HISTORY_PREPARATION_DIAGNOSTIC ",JSON.stringify({"case":source.id,"seat":seat,"quarter":quarter,
                "handle_fields":handle.keys(),"logical_capture":handle.component.has("logical_pose"),
                "departure":{ "entries":handle.get("departure_entries",[]).size(), "metadata_layers":handle.get("departure_metadata",{}).get("inputs",{}).values().map(func(row):return row.layers.size()), "output_rows":handle.get("departure_output",{}).get("rows",{}).values().map(func(row):return row.size()), "equipment":handle.component.get("logical_pose",{}).get("departure",{}).get("row",{}).get("equipment_layers",[]), "hidden":handle.component.get("logical_pose",{}).get("hidden_slots",[])},
                "preparation":native.preparation_state,"required":world.component_renderer._native_prepare_components.filter(func(row):return row.id==ids[0]).map(func(row):return {"id":row.id,"capture":row.has("logical_pose"),"owner":row.get("condition_uuid"),"preparation":row.get("preparation_key")}),"budget":world.component_renderer._native_budget}))
        check(binding.unavailable.is_empty() and "actor_context" in binding.supplied,label+": exact current/history input is supplied without fabricated public state")
        var helper:RefCounted=handle.occurrence.actor_history
        check(helper.admitted and not helper.history.is_empty(),label+": native compositor retains actual captured poses")
        if source.id=="blur":
            check(handle.has("history_seeded_key") and handle.get("history_capture_range",{}).get("complete_window",false),label+": seek seeds the complete real bounded prefix")
            check(binding.get("not_applicable",{}).get("history_state")=="non_mirror_history_does_not_consume_duplicate_count",label+": rolling history never invents Mirror duplicate counts")
            var snapshots:Array=helper.history.get("recipient",[])
            if snapshots.size()<=4 or snapshots.front().origin==snapshots.back().origin:
                print("HISTORY_MOTION_DIAGNOSTIC ",JSON.stringify({"seat":seat,"quarter":quarter,"seconds":helper.last_seconds,"owner":handle.get("owner_state",{}),"ages":[handle.sample_time,handle.component.age_ms],"origins":snapshots.map(func(row):return [row.seconds,row.origin])}))
            check(snapshots.size()>4 and snapshots.front().origin!=snapshots.back().origin,label+": historical motion differs from the present body")
        elif source.id=="mirror":
            var count:int=int(handle.component.condition.state.duplicate_count)
            check(helper.copies.size()==count,label+": copy allocation uses the real disclosed duplicate count")
        else:
            check(not helper.captured_packet.is_empty() and not world.visual_actors.has(actor),label+": departure uses retained original layers while the canonical actor remains absent")
        await frame();await frame();world.set_process(false)
        var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
        var shown:Image=view.get_texture().get_image();Effects.hide(handle);await frame();await frame()
        var delta:int=changed(shown,view.get_texture().get_image())
        if delta==0:
            var passes:Array=[]
            for group in helper.copies.values():
                var pixels:Image=group.colour.viewport.get_texture().get_image()
                passes.append({"visible":group.output.visible,"alpha_rect":pixels.get_used_rect(),"source_texture":pixels.get_size(),"layer":group.output.layers})
            print("HISTORY_OUTPUT_DIAGNOSTIC ",JSON.stringify({"case":source.id,"seat":seat,"quarter":quarter,"geometry":handle.geometry.size(),"settings":handle.occurrence.parameters.get("actor_history",{}),"owner_state":handle.get("owner_state",{}),"poses":helper.history.get("recipient",[]).map(func(row):return {"layers":row.layers.size(),"origin":row.origin,"seconds":row.seconds}),"copies":passes}))
        check(delta>0,label+": actual history output contributes native pixels in quarter"+str(quarter))
        check(var_to_bytes(world.timeline.state)==canonical,label+": native capture and visibility controls preserve exact canonical state")
        evidence.append({"case":source.id,"seat":seat,"quarter":quarter,"pixels":delta,"at_ms":at,"binding":binding,"history_range":handle.get("history_capture_range",{}),"private_source_sets":handle.get("history_sources",{}).size()})
        last=weakref(handle.root);world.set_process(true)
    world.install_playback(Recording.restore(index,maxf(0,float(span.start_ms)-1.0)))
    await settle(world)
    check(world.component_renderer.native_spells.handles.values().all(func(handle):return handle.component.get("condition_uuid")!=owner or not handle.root.is_visible_in_tree()),label+": reverse seek cannot expose future history")
    if is_finite(float(span.end_ms)):
        world.install_playback(Recording.restore(index,minf(index.presentation_end_ms,float(span.end_ms)+1000.0)));await settle(world)
        var still_present:bool=world.timeline.state.actors[actor].conditions.any(func(condition):return condition.condition_uuid==owner)
        if not still_present:
            check(world.component_renderer.native_spells.handles.values().all(func(handle):return handle.component.get("condition_uuid")!=owner or not handle.root.is_visible_in_tree()),label+": real removal retires history output")
        else:evidence.append({"case":source.id,"seat":seat,"gap":"recording_does_not_include_authoritative_removal","owner":owner})
    var native:RefCounted=world.component_renderer.native_spells;native.close(world)
    check(native.handles.is_empty() and (last==null or last.get_ref()==null),label+": teardown frees occurrence/capture ownership")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+": full shared path has no presentation/resource error")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==original,label+": all original rows and operands remain immutable")
    view.queue_free();await frame();await frame()
func finish()->void:
    var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Shared actual-current, rolling and original-departure compositor paths on original two-seat streams, true movement prefix, all camera quarters, seek/loop/removal and native output. No art approval or live frame-cost claim."}
    FileAccess.open("res://.runtime/native-actor-history-modes.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_HISTORY_MODES ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
