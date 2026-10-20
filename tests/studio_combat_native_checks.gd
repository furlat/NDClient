extends SceneTree
## Real Dying/death-save/Dead sequence in the production Studio renderer.
const Studio=preload("res://studio/studio.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("STUDIO_COMBAT_FAIL ",label)
func ready(studio:Control)->bool:
    return not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and not studio.world.rotation_pending() and studio.world.component_renderer.ready
func settle(studio:Control)->bool:
    var deadline=Time.get_ticks_msec()+90000
    while not ready(studio) and Time.get_ticks_msec()<deadline:await process_frame
    check(ready(studio),"Actual Studio sample publishes")
    if not ready(studio):return false
    await process_frame;await RenderingServer.frame_post_draw
    check(studio.world.presentation_errors.is_empty() and studio.world.media_issue.is_empty(),"Production presentation has no source/render errors")
    return true
func capture(studio:Control,label:String)->void:
    studio.viewport.get_texture().get_image().save_png("res://.captures/studio/combat/"+label+".png")
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    DisplayServer.window_set_size(Vector2i(1280,720));DirAccess.make_dir_recursive_absolute("res://.captures/studio/combat")
    var studio=Studio.new();root.add_child(studio)
    var original:Dictionary=Fixtures.public_case("death-save")
    studio.case_records=[original];studio.select_case(original,"amber")
    studio.loop_enabled=false;studio.loop_button.set_pressed_no_signal(false)
    if not await settle(studio):await finish(studio);return
    check(studio.active_directory==Fixtures.journal("death-save"),"Exact original Dying/death-save/Dead journal is selected, independent of library ordering")
    check(studio.index.rows.any(func(row):return row.kind=="event" and row.event.kind=="death_save"),"The original sequence includes authoritative death-save outcomes")
    var dying=studio.index.rows.filter(func(row):return row.kind=="body" and row.track.clip=="Die" and row.track.duration_ms>0)
    var dead=studio.index.rows.filter(func(row):return row.kind=="body" and row.track.clip=="Die" and row.track.duration_ms==0)
    check(dying.size()==1 and dead.size()==1,"Actual recording has one fall and one terminal-pose death")
    if dying.size()!=1 or dead.size()!=1:await finish(studio);return
    var actor:String=dying[0].track.actor_uuid
    check(dead[0].track.actor_uuid==actor,"One actual recipient owns both the fall and terminal death pose")
    for probe in [{"name":"alive","at":dying[0].start_ms-.01,"life":"alive"},{"name":"falling","at":lerpf(dying[0].start_ms,dying[0].end_ms,.5),"life":"dying"},{"name":"down","at":dying[0].end_ms+.01,"life":"dying"},{"name":"dead","at":dead[0].start_ms+.01,"life":"dead"}]:
        studio._seek(probe.at)
        if not await settle(studio):break
        var world=studio.world
        check(world.timeline.state.actors[actor].life_state==probe.life,"Actual committed life state: "+probe.name)
        check(world.visual_actors.has(actor),"Actual assembled actor remains present: "+probe.name)
        if world.visual_actors.has(actor):
            var entries:Array=world.visual_actors[actor].entries
            check(entries.any(func(entry):return entry.role=="body" and entry.node.visible),"Native body layers draw: "+probe.name)
        if probe.name!="alive":check(world.playbacks.get(actor,{}).get("clip")=="Die","Dying/dead uses actual Die source: "+probe.name)
        if probe.name in ["down","dead"] and world.playbacks.has(actor):
            var playback=world.playbacks[actor]
            var rig:Dictionary=world.rigs[world.visual_actors[actor].row.rig]
            check(is_equal_approx(playback.sample_seconds,float(rig.clips.Die.frames)/rig.clips.Die.fps),"Resting corpse holds terminal source time: "+probe.name)
        await capture(studio,probe.name)
        if probe.name=="dead":
            for component in world.displayed_components:
                if component.kind=="feedback_text":world.presentation_mutes[component.id]=true
            await process_frame;await RenderingServer.frame_post_draw
            await capture(studio,"dead-with-feedback-muted")
            world.presentation_mutes.clear()
        evidence.append({"sample":probe.name,"display_ms":world.timeline.display_ms,"state":world.timeline.state.actors[actor].life_state,"clip":world.playbacks.get(actor,{}).get("clip")})
    studio._seek(0)
    if await settle(studio):
        check(studio.world.timeline.state.actors[actor].life_state=="alive","Reverse seek restores real alive initialization")
        studio.world.timeline.paused=false
        var deadline=Time.get_ticks_msec()+45000
        var phases={};var frames=0;var backward=false;var last=0.0
        while studio.world.timeline.display_ms<dead[0].start_ms+100 and Time.get_ticks_msec()<deadline:
            await process_frame
            var at:float=studio.world.timeline.display_ms
            backward=backward or at<last;last=at;frames+=1
            phases[studio.world.timeline.state.actors[actor].life_state]=true
        studio.world.timeline.paused=true
        check(not backward and frames>10,"Actual continuous display clock advances without restarting")
        check(phases.has("alive") and phases.has("dying") and phases.has("dead"),"Continuous production playback reaches all actual life phases")
        check(studio.world.component_renderer.audio.errors.is_empty(),"Recorded sounds have no native playback errors")
        check(studio.world.presentation_errors.is_empty(),"Continuous production playback has no render errors")
        evidence.append({"continuous_frames":frames,"phases":phases.keys(),"audio_shots":studio.world.component_renderer.audio.counters.shots})
    await finish(studio)
func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame;await RenderingServer.frame_post_draw
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual server Dying/death saves/Dead recording through native production Studio; source poses, committed life state, reverse seek, continuous playback and captures. No manually assigned outcomes."}
    FileAccess.open("res://generated/studio_combat_native_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_COMBAT_NATIVE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
