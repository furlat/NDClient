extends SceneTree
## Real SDK prefix -> shared display clock. No renderer or invented game facts.
const Recording=preload("res://studio/recording.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Conditions=preload("res://presentation/conditions.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]

func _initialize()->void: run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_TIMING_FAIL ",label)

func _timeline(index:Dictionary)->RefCounted:
    var value=Timeline.new()
    var initial=index.initialization.duplicate()
    initial.state=index.initialization.state.duplicate(true)
    value.accept(initial)
    value.accept({"kind":"operation","groups":index.groups.map(func(item):return item.group)})
    return value

func _hidden(value:RefCounted,actor:String)->bool:
    return value.state.actors[actor].get("conditions",[]).any(func(condition):return condition.behavior_id=="condition.hidden")

func _same_at(a:RefCounted,b:RefCounted)->bool:
    return a.state==b.state and a.sequence==b.sequence and a.actor_samples()==b.actor_samples() and a.condition_owners==b.condition_owners

func _raw_groups(directory:String,cache:Dictionary)->Dictionary:
    var journal=Journal.new()
    var opened=journal.open(directory,false,false)
    if not opened.ok:return opened
    var result:Array=[]
    var paths=DirAccess.get_files_at(directory)
    var packet_paths:Array=[]
    var regex=RegEx.new();regex.compile("^[0-9]{16}\\.json$")
    for name in paths:
        if regex.search(name)!=null:packet_paths.append(name)
    packet_paths.sort()
    for n in packet_paths.size():
        var raw=FileAccess.get_file_as_bytes(directory.path_join(packet_paths[n]))
        var decoded=journal.protocol.decode("InitializationResponse" if n==0 else "PlayerOperation",raw)
        if not decoded.ok:return decoded
        var before=journal.state
        var admitted=journal._consume_admitted(decoded.value,raw,true)
        if not admitted.ok:return admitted
        if n==0:continue
        var compiled=Compiler.compile_recorded(before,admitted.normalized,cache,journal.state,admitted.transitions)
        if not compiled.ok:return compiled
        result.append_array(compiled.value.groups)
    return {"ok":true,"groups":result,"final_state":journal.state}

func _advance_to(value:RefCounted,target:float)->bool:
    # World publication yields at each real boundary. Wait on observable clock /
    # cursor progress, never a wall-time sleep or assumed number of frames.
    for n in 512:
        var before=[value.display_ms,value.completed_group_count,value.commit_index,value.current.get("id","")]
        value.advance(maxf(0,target-value.display_ms))
        if is_equal_approx(value.display_ms,target):
            # Several real zero-duration publication boundaries can share this
            # instant. Settle those through the same readiness path as Play.
            if not value.current.is_empty() or value.queue.is_empty() or float(value.queue[0].get("preview_start_ms",target))>target:return true
        if before==[value.display_ms,value.completed_group_count,value.commit_index,value.current.get("id","")]:return false
    return false

func _recording(directory:String)->Dictionary:
    var index=Recording.read(directory)
    check(index.ok,directory+" admits complete real recording")
    if not index.ok:return {}
    var raw=_raw_groups(directory,index.cache)
    check(raw.ok,directory+" independently compiles original ordered prefix")
    if not raw.ok:return {}
    check(index.groups.size()==raw.groups.size(),"Inspection spacing adds no fake group or event")
    var previous_end=500.0
    var previous_operation=-1
    var gaps=0
    for n in index.groups.size():
        var item:Dictionary=index.groups[n]
        var group=item.group.duplicate();group.erase("preview_start_ms")
        check(group==raw.groups[n],"Original complete compiler group remains exact: "+str(group.id))
        var gap:float=item.start_ms-previous_end
        check(is_zero_approx(gap) or is_equal_approx(gap,350),"Only bounded inspection spacing precedes "+str(group.id))
        if group.operation_sequence==previous_operation:check(is_zero_approx(gap),"No delay between lineages of one operation")
        if gap>0:gaps+=1
        previous_operation=group.operation_sequence;previous_end=item.start_ms+group.duration_ms
    check(is_equal_approx(index.groups[0].start_ms,500),"First operation starts after500ms real-state lead-in")
    for at in [0.0,250.0,499.0]:
        var value=Recording.restore(index,at)
        check(value.state==index.initialization.state and value.sequence==0,"Lead-in retains exact initialization at "+str(at))
        check(value.actor_samples().is_empty() and value.current.is_empty(),"Lead-in has no early body/event at "+str(at))
    var restored=Recording.restore(index,index.presentation_end_ms)
    check(restored.state==raw.final_state,"Final real state includes every operation despite inspection intervals")
    check(restored.sequence==index.groups[-1].group.operation_sequence,"Final native operation cursor is retained")
    var longest=index.duration_ms
    for row in index.rows:
        if row.has("component"):longest=maxf(longest,row.end_ms)
    check(index.presentation_end_ms>=longest,"Presentation extent retains all actual component/audio tails")

    var hides=index.rows.filter(func(row):return row.kind=="event" and row.event.get("behavior_id")=="action.hide")
    for hide in hides:
        var bodies=index.rows.filter(func(row):return row.kind=="body" and row.track.source_event_uuid==hide.event.event_uuid)
        check(bodies.size()==1 and bodies[0].end_ms>bodies[0].start_ms,"Hide owns its positive-duration action body")
        if bodies.is_empty():continue
        var body:Dictionary=bodies[0]
        check(body.track.source=="res://authoring/presentation/actions/hide.tres::clip","Actual Hide body retains selected native clip provenance")
        var cues:Array=[]
        for item in index.groups:
            for component in item.group.get("components",[]):
                if component.get("source_event_uuid")==hide.event.event_uuid and component.get("cue_id")=="hide_transition":cues.append(component)
        check(cues.size()==1 and cues[0].get("assignment_source")=="res://authoring/presentation/actions/hide.tres::effect_audio_cue" and str(cues[0].source).begins_with("audio/cues.json:"),"Actual action audio retains both assignment and selected cue provenance")
        var actor:String=body.track.actor_uuid
        var owner_rows=index.rows.filter(func(row):return row.kind=="condition" and row.owner.condition.behavior_id=="condition.hidden" and not row.owner.initial)
        check(owner_rows.size()==1,"Real Hidden application has one retained owner")
        if owner_rows.is_empty():continue
        var applied:float=owner_rows[0].start_ms
        check(is_equal_approx(applied,body.group_start_ms+body.track.contact_ms),"Hidden begins at actual authored effect anchor")
        var next_moves=index.rows.filter(func(row):return row.kind=="body" and row.track.actor_uuid==actor and row.track.get("motion",false) and row.start_ms>=body.end_ms)
        check(not next_moves.is_empty(),"Actual Hide recording includes subsequent crouched movement")
        if next_moves.is_empty():continue
        var movement:Dictionary=next_moves[0]
        check(is_equal_approx(movement.start_ms-body.end_ms,350),"Hidden has350ms inspectable idle before the next movement")
        for at in [body.start_ms,lerpf(body.start_ms,applied,.5),applied-1]:
            var value=Recording.restore(index,at)
            check(not _hidden(value,actor),"No early Hidden state during the action at "+str(at))
            check(value.actor_samples().get(actor,{}).get("trace_track_id")==body.track.trace_track_id,"Actual Hide body owns action sample")
        var idle_at=lerpf(body.end_ms,movement.start_ms,.5)
        var idle=Recording.restore(index,idle_at)
        check(_hidden(idle,actor) and not idle.actor_samples().has(actor),"Post-action pause presents authoritative Hidden idle")
        var pose=Conditions.pose(idle.state.actors[actor],body.track.rig,index.cache)
        check(pose.get("clip")=="CrouchIdle","Shared condition selection owns paused crouch pose")
        var components=idle.component_samples(index.cache)
        check(is_equal_approx(Conditions.material(actor,components).alpha,.55),"Post-action idle carries authored partial transparency")
        var moving=Recording.restore(index,lerpf(movement.start_ms,movement.end_ms,.5))
        check(moving.actor_samples().get(actor,{}).get("clip")=="CrouchRun","Next actual movement uses crouched source")
        var forward=_timeline(index)
        var targets=[250.0,body.start_ms,applied-1,applied,idle_at,movement.start_ms,lerpf(movement.start_ms,movement.end_ms,.5)]
        for at in targets:
            forward.advance(at-forward.display_ms)
            check(_same_at(forward,Recording.restore(index,at)),"Continuous playback equals exact seek at "+str(at))
        var prepared=_timeline(index)
        prepared.world_ready=func(_candidate):return true
        for at in targets:
            check(_advance_to(prepared,at),"Prepared world boundary reaches target "+str(at))
            check(_same_at(prepared,Recording.restore(index,at)),"Prepared production clock agrees with seek at "+str(at))
        var gate={"ready":false}
        var held=Recording.restore(index,applied-1);held.paused=false
        held.world_ready=func(_candidate):return gate.ready
        held.advance(2)
        check(held.waiting_for_world and not _hidden(held,actor) and is_equal_approx(held.display_ms,applied-1),"Unprepared effect boundary exposes no future Hidden state")
        gate.ready=true;held.advance(2)
        check(_hidden(held,actor),"Prepared effect publishes the original Hidden after-value")
        var rewind=Recording.restore(index,250)
        check(not _hidden(rewind,actor) and rewind.state==index.initialization.state,"Reverse seek returns to normal pre-action state")
        evidence.append({"directory":directory,"hide_start_ms":body.start_ms,"effect_ms":applied,"idle_sample_ms":idle_at,"movement_start_ms":movement.start_ms,"duration_ms":index.duration_ms,"presentation_end_ms":index.presentation_end_ms,"tail_ms":index.presentation_end_ms-index.duration_ms,"operation_gaps":gaps})
    return index

func run()->void:
    var paths:Array=[]
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):paths.append(argument.trim_prefix("--recording="))
    if paths.is_empty():printerr("Requires explicit --recording=<real journal>");quit(2);return
    var indexes:Array=[]
    for directory in paths:
        var index=_recording(directory)
        if not index.is_empty():indexes.append(index)
    if indexes.size()>=2:
        var bundle={"views":{"first":indexes[0],"second":indexes[1]},"perspectives":[{"id":"first","label":"First"},{"id":"second","label":"Second"}]}
        for id in ["first","second"]:
            var view=Recording.view_index(bundle,id)
            check(view.presentation_end_ms==bundle.views[id].presentation_end_ms,"Foreign faction inspection adds no loop padding: "+id)
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Real SDK state, authored action/condition boundaries, normal lead-in, inter-operation idle, complete unchanged groups and shared immediate/prepared clocks; no native image/audio claim."}
    FileAccess.open("res://generated/studio_timing_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_TIMING ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
