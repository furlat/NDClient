extends "res://tests/native_vampiric_touch_render_checks.gd"
## Actual native AI motion and dismissal; contact/trail source gaps stay gaps.
const MEDIA=preload("res://studio/recording_media.gd")
const PREPARED=preload("res://tests/dynamic_weapon_support.gd")
const JOURNAL=preload("res://sdk/journal.gd")
const MOTION=preload("res://tests/effect_owned_actor_motion_checks.gd")
const ROOT_PATH="res://tests/fixtures/schema16/scenarios/flaming-sphere-lifecycle"
const OUTPUT_PATH="res://.runtime/native-effect-owned-motion"
const SPHERE="9a7daae4-573e-4248-82ca-19eb9430cf2c"
const OWNER="3e1d4d91-5553-4266-951d-0754ac3953c5"
const SPATIAL="b1bfa454-b66a-4dab-8c77-1ce50c5171e8"
const STEPS=["102","139","201","238","275","312"]
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(OUTPUT_PATH)
    for seat in ["amber","blue"]:await actual_motion(seat)
    var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Both original six-Step FlamingSphere lifecycles through ordinary Play: actual source transform and Step draw witnesses, one unchanged private native clock/body, strict native pixels during motion, actual dismissed retirement, independent canonical seek/loop and cleanup. Ram/contact/trail, performance and visual approval remain separate gaps."}
    FileAccess.open(OUTPUT_PATH+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_EFFECT_OWNED_MOTION ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func next_cut(timeline:RefCounted,at:float)->float:
    var group:Dictionary=timeline.current
    var start:float=timeline.group_start_ms
    if group.is_empty() and not timeline.queue.is_empty():group=timeline.queue[0];start=maxf(timeline.display_ms,float(group.preview_start_ms))
    return minf(at,start+float(group.duration_ms)) if not group.is_empty() else at
func advance(world:Node,at:float,ids:Array=[])->bool:
    if not is_finite(at):check(false,"Native proof rejects nonfinite replay cut "+str(at));return false
    var plan:Dictionary={};var deadline:int=Time.get_ticks_msec()+45000
    while world.timeline.display_ms<at-.000001 and Time.get_ticks_msec()<deadline:
        await process_frame
        if not plan.is_empty() and not world.timeline.replay_plan_current(plan):world.timeline.replay_cancel_preparation();plan={}
        if plan.is_empty():plan=world.timeline.replay_plan(next_cut(world.timeline,at))
        if world.timeline.replay_prepare(plan):
            if world.can_publish_replay_advance(plan):check(world.publish_replay_advance(plan),"Actual motion cut publishes in order");plan={}
            else:world.timeline.replay_cancel_preparation();plan={}
        await RenderingServer.frame_post_draw
        if not world.presentation_errors.is_empty() or not world.media_issue.is_empty():break
    var arrived:bool=is_equal_approx(world.timeline.display_ms,at)
    check(arrived,"Actual motion clock reaches "+str(at)+str({"display_ms":world.timeline.display_ms,"errors":world.presentation_errors,"media":world.media_issue} if not arrived else ""))
    if not arrived:return false
    var prepared:bool=await PREPARED.settle(self,world,ids)
    check(prepared,"Actual displayed source prepares at finite motion cut "+str(at))
    return prepared
func pixels(world:Node,view:SubViewport,handle:Dictionary,label:String)->int:
    world.set_process(false);await frame();await frame()
    var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
    var at:float=world.timeline.display_ms
    var shown:Image=view.get_texture().get_image();handle.root.hide();await frame();await frame()
    var hidden:Image=view.get_texture().get_image();var count:int=changed(shown,hidden)
    check(count>0,label+": actual moving native body contributes framebuffer pixels")
    check(var_to_bytes(world.timeline.state)==canonical and world.timeline.display_ms==at,label+": optical control leaves real canonical/clock unchanged")
    shown.save_png(OUTPUT_PATH+"/"+label+"-present.png");hidden.save_png(OUTPUT_PATH+"/"+label+"-hidden.png")
    handle.root.show();world.set_process(true)
    return count
func actual_motion(seat:String)->void:
    var directory:String=ROOT_PATH.path_join(seat)
    var journal:RefCounted=JOURNAL.new();var opened:Dictionary=journal.open(directory,true,true)
    var index:Dictionary=Recording.read(directory)
    check(opened.ok and index.ok,seat+": independent original and ordinary Studio index open")
    if not opened.ok or not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var lives:Array=index.rows.filter(func(row):return row.kind=="condition" and row.owner.id==OWNER)
    var edges:Dictionary={}
    for item in index.groups:
        for track in item.group.actor_tracks:
            if track.actor_uuid==SPHERE and track.get("spatial_only",false) and track.get("motion",false):edges[str(track.source_event_uuid)]={"item":item,"track":track}
    check(lives.size()==1 and edges.size()==6 and STEPS.all(func(id):return edges.has(id)),seat+": exact real owner and all six position-only Steps are compiled")
    if lives.size()!=1 or edges.size()!=6:return
    var owner:Dictionary=lives[0].owner
    var first:Dictionary=edges[STEPS[0]]
    var before:float=float(first.item.start_ms)+float(first.track.start_ms)-.01
    check(is_finite(before),seat+": initial motion proof cut is finite")
    if not is_finite(before):return
    var id:String="condition:"+OWNER+":lifecycle:condition_flaming_sphere_persistent"
    index.media_preload=MEDIA.plan(index)
    check(index.media_preload.errors.is_empty(),seat+": original full source closure prepares without nonexistent sprite clips")
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.encounter_override=index.media_preload
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows);world.native_startup_requested_ms=before
    world.playback_end_ms=index.presentation_end_ms;world.component_renderer.audio.set_enabled(false);view.add_child(world)
    world.install_playback(Recording.restore(index,before))
    if not await PREPARED.settle(self,world,[id]):check(false,seat+": actual pre-motion native body prepares");view.queue_free();await frame();return
    world.camera_focus=Vector3(8,0,7);world.initial_focus=true;world.camera.size=7;world.position_camera()
    world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility()
    var native:RefCounted=world.component_renderer.native_spells
    var handle:Dictionary=native.handles[id];var original_root:WeakRef=weakref(handle.root)
    check(not world.visual_actors.has(SPHERE) and handle.component.condition_uuid==OWNER \
        and handle.occurrence.handle.geometry.size()==13,seat+": unchanged actual thirteen-layer native body owns the real actor with no2Dproxy")
    for step_index in STEPS.size():
        var edge:Dictionary=edges[STEPS[step_index]];var track:Dictionary=edge.track
        for fraction in [.25,.75]:
            var at:float=float(edge.item.start_ms)+float(track.start_ms)+float(track.duration_ms)*fraction
            if not await advance(world,at,[id]):view.queue_free();await frame();return
            handle=native.handles[id]
            var point:=Vector3(lerpf(track.from_position[0],track.to_position[0],fraction), \
                lerpf(track.from_elevation_feet,track.to_elevation_feet,fraction)/5.0*Play.Placement.HEIGHT_UNIT, \
                lerpf(track.from_position[1],track.to_position[1],fraction))
            var actual:Dictionary=handle.endpoints.effect_owned_ground
            check(original_root.get_ref()==handle.root and not world.visual_actors.has(SPHERE) \
                and handle.endpoints.ground.is_equal_approx(point) and handle.root.global_position.is_equal_approx(point),seat+": Step "+STEPS[step_index]+" consumes the actual interpolated ground on the same private native body")
            check(actual.get("motion_track_id")==track.trace_track_id \
                and native.witnesses.any(func(witness):return witness.id==track.trace_track_id and witness.get("native_body_owner_id")==id \
                    and witness.get("ground",Vector3.INF).is_equal_approx(point) and is_equal_approx(float(witness.age_ms),at-float(owner.start_ms))),seat+": Step "+STEPS[step_index]+" has an exact same-draw-frame witness, not merely a held body")
            check(world.timeline.event_trace(2000).events.any(func(event):return event.components.any(func(component):return component.get("trace_track_id")==track.trace_track_id \
                and component.kind=="motion" and component.status=="presented" and component.sample_count>0)),seat+": actual Step draw reaches the existing public EventTrace/Studio coverage")
            check(is_equal_approx(handle.owner_state.owner_age_seconds,(at-float(owner.start_ms))/1000.0) \
                and handle.component.actor_uuid==SPHERE and handle.component.condition_uuid==OWNER \
                and world.timeline.state.senses.spatial_effects.has(SPATIAL),seat+": movement preserves owner clock/identity and independent spatial aura")
            if fraction==.75 and step_index in [0,5]:
                evidence.append({"seat":seat,"step_occurrence":STEPS[step_index],"track_id":track.trace_track_id,"at_ms":at,
                    "point":[point.x,point.y,point.z],"changed_pixels":await pixels(world,view,handle,seat+"-step"+STEPS[step_index])})
    var terminal:Dictionary=MOTION.terminal_cut(index,seat)
    check(terminal.get("found",false) and is_finite(float(terminal.get("at_ms",INF))),seat+": actual dismissed SpatialFact has one finite publication cut")
    if not terminal.get("found",false) or not is_finite(float(terminal.at_ms)):view.queue_free();await frame();return
    var retired:float=float(terminal.at_ms)+351.0
    if not await advance(world,retired):view.queue_free();await frame();return
    check(not world.timeline.state.actors[SPHERE].present and world.timeline.state.actors[SPHERE].last_visual_position==null \
        and world.timeline.state.actors[SPHERE].conditions.any(func(member):return member.condition_uuid==OWNER) \
        and not world.timeline.state.senses.spatial_effects.has(SPATIAL),seat+": real finite dismissal withdraws the actor/spatial aura while retaining the exact remembered condition member")
    var prepared:Dictionary=native.handles.get(id,{})
    var root_valid:bool=not prepared.is_empty() and is_instance_valid(prepared.get("root"))
    var root_visible:bool=root_valid and prepared.root.is_visible_in_tree()
    var retirement_witnesses:Array=native.witnesses.filter(func(witness):return witness.id==id or witness.get("native_body_owner_id")==id)
    var retirement:Dictionary={"seat":seat,"phase":"actual_dismissed_retirement","terminal_occurrence":terminal.occurrence,
        "terminal_cut_ms":terminal.at_ms,"requested_ms":retired,"display_ms":world.timeline.display_ms,
        "process_frame":Engine.get_process_frames(),"root_valid":root_valid,"root_visible":root_visible,
        "drawn_time":prepared.get("drawn_time"),"drawn_frame":prepared.get("drawn_frame"),
        "component_ids":world.displayed_components.map(func(component):return component.id),"witnesses":retirement_witnesses.duplicate(true),
        "diagnostic":native.diagnostics.get(id,{}).duplicate(true),"epoch":world.world_prepare_epoch,
        "published_world_revision":world.world_revision,"timeline_world_revision":world.timeline.world_revision,
        "published_actor_revision":world.actor_revision,"timeline_revision":world.timeline.revision}
    evidence.append(retirement)
    check(not root_visible and not retirement_witnesses.any(func(witness):return witness.status=="rendered"),seat+": no retired body is visible or drawn; hidden retained preparation is permitted "+str(retirement))
    check(retirement_witnesses.all(func(witness):return witness.status=="missing" and witness.get("reason")=="effect_owned_actor_not_visible"),seat+": any retained-owner witness is the exact canonical-visibility refusal, never a draw")
    var midpoint:float=float(first.item.start_ms)+float(first.track.start_ms)+float(first.track.duration_ms)*.5
    check(is_finite(midpoint),seat+": reverse-seek motion cut is finite")
    if not is_finite(midpoint):view.queue_free();await frame();return
    world.install_playback(Recording.restore(index,midpoint))
    var loop_ready:bool=await PREPARED.settle(self,world,[id])
    check(loop_ready,seat+": reverse seek/loop source prepares")
    if loop_ready:check(original_root.get_ref()==null and native.handles[id].component.condition_uuid==OWNER \
        and native.handles[id].endpoints.effect_owned_ground.motion_track_id==first.track.trace_track_id,seat+": reverse seek/loop releases old private state and reconstructs the same actual motion owner")
    check(is_finite(float(index.presentation_end_ms)),seat+": original final canonical cut is finite")
    if not is_finite(float(index.presentation_end_ms)):view.queue_free();await frame();return
    world.install_playback(Recording.restore(index,index.presentation_end_ms+1000.0))
    var final_ready:bool=await PREPARED.settle(self,world)
    check(final_ready,seat+": actual final canonical cut prepares")
    if final_ready:check(world.timeline.state==journal.state and not world.timeline.state.senses.spatial_effects.is_empty(),seat+": final independent canonical state preserves separately owned FireSurfaces")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty() and var_to_bytes([index.initialization,index.groups,index.rows])==immutable,seat+": motion/retirement source path has no errors or immutable-record mutation")
    native.close(world);check(native.handles.is_empty() and native.groups.is_empty(),seat+": actual private source owners close")
    view.queue_free();await frame();await frame()
