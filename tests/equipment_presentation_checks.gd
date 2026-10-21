extends SceneTree
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Authoring=preload("res://presentation/authoring.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
var changed_equipment=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("EQUIPMENT_PRESENTATION_FAIL ",label)
func run()->void:
    var directories:Array=[]
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directories.append(arg.trim_prefix("--recording="))
    if directories.is_empty():print("Use repeated --recording=<actual Hide/torch journal>");quit(2);return
    for directory in directories:examine(directory)
    check(changed_equipment>0,"Real recordings include observable equipment before/after changes")
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual recorded equipment events; original Taunt3x frame4 commit, source-order canonical equivalence, forward/reverse seek and no early loadout. No native pixel claim."}
    FileAccess.open("res://generated/equipment_presentation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("EQUIPMENT_PRESENTATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func examine(directory:String)->void:
    var index=Recording.read(directory)
    check(index.ok,"Actual recording compiles "+directory)
    if not index.ok:return
    var context:Dictionary=Authoring.load_data("catalog/equipment_context.json",index.cache)
    var count=0
    var held=index.groups.duplicate(true)
    for item in index.groups:
        var previous_cursor=-1;var previous_time=-1.0
        for commit in item.group.commits:
            check(commit.source_index>=previous_cursor and commit.at_ms>=previous_time,"Original event commit order remains monotonic")
            previous_cursor=commit.source_index;previous_time=commit.at_ms
        for event in item.group.events:
            var tracks:Array=item.group.actor_tracks.filter(func(track):return track.source_event_uuid==event.event_uuid and (event.kind=="equipment" or track.get("equipment_change",false)))
            if event.kind!="equipment" and tracks.is_empty():continue
            count+=1
            check(tracks.size()==1,"One actual equipment occurrence owns one selected body")
            if tracks.is_empty():continue
            var track:Dictionary=tracks[0]
            var clip:Dictionary=Authoring.clip(track.presentation_actor,context.bodyClip,index.cache)
            var expected_duration:float=clip.frames*1000.0/clip.fps/context.bodyPlaybackSpeed
            var expected_commit:float=track.start_ms+minf(expected_duration,context.commitFrame*1000.0/clip.fps/context.bodyPlaybackSpeed)
            check(track.clip=="Taunt" and track.activity=="act" and is_equal_approx(track.duration_ms,expected_duration),"Original modular equipment body/rate/duration")
            check(is_equal_approx(track.commit_ms,expected_commit),"Original equipment frame4 commits before body completion")
            var commits=item.group.commits.filter(func(commit):return commit.get("event_uuid")==event.event_uuid)
            check(commits.size()==1 and is_equal_approx(commits[0].at_ms,expected_commit),"Real equipment after-value publishes exactly at authored commit")
            check(not event.components.any(func(component):return component.status=="missing" and component.kind=="body"),"Actual owned track satisfies only equipment body requirement")
            var at:float=item.start_ms+expected_commit
            var before=Recording.restore(index,at-.001)
            var after=Recording.restore(index,at+.001)
            var actor_id:String=track.actor_uuid
            var expected:Dictionary=commits[0].delta.actors[actor_id]
            var prior_state:Dictionary=index.initialization.state.duplicate(true)
            for prior_item in index.groups:
                for prior_commit in prior_item.group.commits:
                    if prior_item.start_ms+prior_commit.at_ms<at-.0001:
                        Recording.Compiler.apply_delta(prior_state,prior_commit.delta)
            check(before.state.actors[actor_id]==prior_state.actors[actor_id],"Actual prior committed actor remains before the authored equipment commit")
            if before.state.actors[actor_id].visual_loadout!=expected.visual_loadout or before.state.actors[actor_id].controlled_items!=expected.controlled_items:changed_equipment+=1
            check(after.state.actors[actor_id].visual_loadout==expected.visual_loadout and after.state.actors[actor_id].controlled_items==expected.controlled_items,"Actual loadout and carried-item after-values appear at commit")
            var body:Dictionary=after.actor_samples().get(actor_id,{})
            check(not body.is_empty() and body.clip==context.bodyClip and absf(body.source_seconds*clip.fps-context.commitFrame)<.001,"Shared body sampler reaches actual commit frame")
            var again=Recording.restore(index,at-.001)
            check(again.state==before.state and again.actor_samples()==before.actor_samples(),"Reverse restore gives identical canonical prefix and source frame")
            evidence.append({"recording":directory,"event_uuid":event.event_uuid,"source_index":commits[0].source_index,"start_ms":item.start_ms+track.start_ms,"commit_ms":at,"duration_ms":track.duration_ms,"clip":track.clip})
    check(count>0,"Real recording contains equipment facts")
    var journal=Journal.new();var opened=journal.open(directory,true,true)
    check(opened.ok,"Independent historical SDK replay accepts all packets")
    var complete=Recording.restore(index,index.presentation_end_ms+1)
    check(complete.state==journal.state,"Entire displayed final state equals independent canonical replay")
    check(index.groups==held,"Forward/reverse sampling leaves compiled groups immutable")
    var rig:Dictionary=Authoring.rigs(index.cache)["smallscale.goblin01"]
    check(rig.body_contexts.any(func(row):return row.role=="equipment" and not row.body.actor.enabled),"Disabled rig override remains in its authored source")
