extends SceneTree
# Real packet -> production compiler/timeline -> displayed log boundaries.
# Replay intake writes only a separate test journal, never the source recording.
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
var contact_actions=0
var early_logs=0
var lethal_chains=0
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("LOG_TIMING_FAIL ",label)
func timeline_for(state:Dictionary,group:Dictionary)->RefCounted:
    var result=Timeline.new()
    result.accept({"kind":"initialization","state":state.duplicate(true),"sequence":-1})
    result.accept({"kind":"operation","groups":[group]})
    return result
func inspect_group(state:Dictionary,group:Dictionary)->void:
    var gates={}
    var logged={}
    for row in group.events:
        if row._log==null:continue
        logged[row.id]=row
        gates[row.id]=float(row._commit_ms)
    for id in gates:
        var parent:String=logged[id].get("_log_parent_id","")
        var seen={id:true}
        while logged.has(parent) and not seen.has(parent):
            seen[parent]=true
            gates[id]=maxf(gates[id],float(logged[parent]._commit_ms))
            parent=logged[parent].get("_log_parent_id","")
    var times:Array=gates.values()
    times.sort()
    var prior=-1.0
    for at in times:
        if is_equal_approx(at,prior):continue
        prior=at
        var view=timeline_for(state,group)
        if at>0:
            view.advance(maxf(0,at-0.01))
            var before=view.event_log(2000).entries
            for id in gates:
                if gates[id]>=at:check(not before.any(func(row):return row.id==id),"No result text leaks before its effect/ancestor boundary")
            view.advance(0.01)
        else:view.advance(0)
        var after=view.event_log(2000).entries
        var indices={}
        for index in after.size():indices[after[index].id]=index
        for id in gates:
            if gates[id]<=at+0.000001:
                check(indices.has(id),"Exact log appears at its safe effect boundary, without waiting for recovery")
                if not indices.has(id):continue
                var row:Dictionary=after[indices[id]]
                check(row.entry.compact==logged[id]._log.compact,"Recorded compact text remains exact")
                if not row.parent_id.is_empty():check(indices.has(row.parent_id) and indices[row.parent_id]<indices[id],"Attack/action parent precedes damage/life descendant")
                if row.entry.entry_type=="death" and not row.parent_id.is_empty():lethal_chains+=1
        if at<group.duration_ms and not after.is_empty():early_logs+=1
    for track in group.actor_tracks:
        if track.priority!=20 or not track.has("contact_ms") or track.get("duration_ms",0)<=0:continue
        var id="%s:%s"%[group.operation_sequence,track.source_event_uuid]
        if not logged.has(id) or logged[id].kind!="action":continue
        var contact:float=track.contact_ms
        # The action may own later real effects. For the ordinary native
        # potion/door cases here, every non-root event commits by contact.
        var child_after_contact=group.commits.any(func(commit):return commit.has("event_uuid") and commit.event_uuid!=track.source_event_uuid and commit.at_ms>contact+0.000001)
        if child_after_contact:continue
        var view=timeline_for(state,group)
        if contact>0:
            view.advance(contact-0.01)
            check(not view.event_log(2000).entries.any(func(row):return row.id==id),"Action outcome stays hidden before authored contact")
            view.advance(0.01)
        else:view.advance(0)
        check(view.event_log(2000).entries.any(func(row):return row.id==id),"Authored action log publishes at contact rather than animation recovery end")
        check(contact<track.start_ms+track.duration_ms,"Recording exercises contact before body recovery")
        contact_actions+=1
        evidence.append({"sequence":group.operation_sequence,"event":id,"contact_ms":contact,"log_ms":gates[id],"body_end_ms":track.start_ms+track.duration_ms})
func recording(source:String,index:int)->void:
    var journal=Journal.new()
    var target="res://.runtime/log-publication-checks/"+str(Time.get_ticks_usec())+"-"+str(index)
    DirAccess.make_dir_recursive_absolute(target)
    # Historical schema selection reads the exact initialization bytes.
    FileAccess.open(target.path_join("0000000000000000.json"),FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes(source.path_join("0000000000000000.json")))
    var opened=journal.open(target,true,false)
    check(opened.ok,"Exact historical initialization chooses its own SDK schema")
    if not opened.ok:return
    var names=DirAccess.get_files_at(source);names.sort()
    var cache={}
    for name in names:
        if not name.ends_with(".json"):continue
        var raw=FileAccess.get_file_as_bytes(source.path_join(name))
        var decoded=journal.protocol.decode("InitializationResponse" if journal.state.is_empty() else "PlayerOperation",raw)
        check(decoded.ok,"Real journal packet admitted: "+name)
        if not decoded.ok:return
        var before=journal.state
        var admitted=journal._consume_admitted(decoded.value,raw,true)
        check(admitted.ok,"Real journal replay keeps native identities")
        if not admitted.ok:return
        if before.is_empty():continue
        var compiled=Compiler.compile_recorded(before,admitted.normalized,cache,journal.state,admitted.transitions)
        check(compiled.ok,"Production timing compile succeeds")
        if not compiled.ok:return
        var displayed=before.duplicate(true)
        for group in compiled.value.groups:
            inspect_group(displayed,group)
            for commit in group.commits:Compiler.apply_delta(displayed,commit.delta)
        check(displayed==journal.state,"Timing leaves all canonical final after-values intact")
func _initialize()->void:
    var arguments=OS.get_cmdline_user_args()
    if arguments.is_empty():printerr("Pass real journal directories");quit(2);return
    for index in arguments.size():recording(arguments[index],index)
    check(contact_actions>0,"Real action recordings exercise contact before recovery")
    check(early_logs>0,"Real logs appear during playback rather than only after animation")
    var report={"checks":checks,"failures":failures,"contact_actions":contact_actions,"early_log_boundaries":early_logs,"lethal_links":lethal_chains,"contact_evidence":evidence}
    FileAccess.open("res://generated/log_publication_timing_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
