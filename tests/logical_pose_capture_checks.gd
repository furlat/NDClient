extends SceneTree
## Real ordered admission and replay restoration; pure clock edge below is a
## contract test, not a fabricated trap/reaction recording.
const Recording=preload("res://studio/recording.gd")
const Pose=preload("res://presentation/condition_pose.gd")
const Catalog=preload("res://source_catalog.gd")
const Characters=preload("res://presentation/characters.gd")
const Graphs=preload("res://animation/graphs.gd")
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("LOGICAL_POSE_FAIL "+label)
func run()->void:
    for faction in ["amber","blue"]:
        var index:Dictionary=Recording.read("res://tests/fixtures/schema16/petrification/"+faction)
        check(index.ok,"Original "+faction+" completed-petrification recording opens: "+str(index.get("error","")))
        if not index.ok:continue
        var spans:Array=index.rows.filter(func(row):return row.kind=="condition" and row.owner.condition.behavior_id=="condition.spell.flesh_to_stone.petrified")
        check(spans.size()==1,"One real completed petrification lifetime, "+faction)
        if spans.size()!=1:continue
        var span:Dictionary=spans[0];var identity:String=span.owner.id;var actor_id:String=span.owner.actor_uuid
        var before:RefCounted=Recording.restore(index,span.start_ms-.001)
        var admitted:RefCounted=Recording.restore(index,span.start_ms+.001)
        check(not before.condition_owners.has(identity),"No future capture before actual application, "+faction)
        check(admitted.condition_owners.has(identity) and admitted.condition_owners[identity].has("logical_pose"),"Actual condition application records its original logical pose, "+faction)
        if not admitted.condition_owners.get(identity,{}).has("logical_pose"):
            print("CAPTURE_ADMISSION_DIAGNOSTIC "+JSON.stringify({"requested":Pose.capture_requested(span.owner.condition,index.cache),"recipe":admitted.Conditions.recipe(span.owner.condition,index.cache).get("persistent",{}),"owner":admitted.condition_owners.get(identity,{}),"before_sequence":before.sequence,"after_sequence":admitted.sequence}))
            continue
        var planned:Dictionary=before._world_candidate(before.replay_plan(span.start_ms+.001))
        check(planned.actor_samples.get(actor_id,{}).get("captured",false) and not before.condition_owners.has(identity),"Future preparation receives the capture without publishing its owner, "+faction)
        var capture:Dictionary=admitted.condition_owners[identity].logical_pose
        var pose_rows:Array=index.rows.filter(func(row):return row.kind=="condition_pose" and row.owner.id==identity)
        check(not pose_rows.is_empty() and pose_rows.all(func(row):return row.selected_pose.get("captured",false) and row.selected_pose.clip==capture.clip and row.selected_pose.frame==capture.frame),"Studio indexes the actual captured clip/frame, "+faction)
        check(capture.clip=="Idle" and capture.actor_uuid==actor_id and capture.condition_uuid==identity,"Ordinary real cast captures the actual idle target and owner, "+faction)
        check(is_equal_approx(capture.source_seconds,span.start_ms/1000.0) and is_equal_approx(capture.admitted_at_ms,span.start_ms),"Capture time belongs to the admission cut, "+faction)
        var held:RefCounted=Recording.restore(index,lerpf(span.start_ms,span.end_ms,.8))
        check(held.condition_owners[identity].logical_pose==capture,"Seeking into hold reconstructs original admission instead of current pose, "+faction)
        var sample:Dictionary=held.actor_samples().get(actor_id,{})
        check(sample.get("captured",false) and sample.source_seconds==capture.source_seconds and sample.world_facing==capture.world_facing,"Held body sampling consumes the exact original time and world-facing, "+faction)
        var restored:RefCounted=Recording.restore(index,span.end_ms+.001)
        check(not restored.actor_samples().get(actor_id,{}).get("captured",false),"Actual Greater Restoration releases body arbitration, "+faction)
        var original:Dictionary=admitted.state.actors[actor_id]
        var rig_id:String=Characters.rig_id(original,index.cache)
        var rig:Dictionary=Characters.rigs(index.cache)[rig_id]
        var clock:Node=Graphs.clock(root,rig)
        Graphs.sample(clock,capture.clip,capture.source_seconds,"captured")
        check(mini(int(clock.sample_seconds*rig.clips[capture.clip].fps),int(rig.clips[capture.clip].frames)-1)==capture.frame,"Capture frame equals native production clock frame, "+faction)
        clock.free()
        # A genuine pre-new-condition value is the input to this explicit pure
        # arbitration test. It does not assert a server-supported moving trap.
        var actor:Dictionary=before.state.actors[actor_id].duplicate()
        actor.presentation_rig=rig_id;actor.presentation_rest=Characters.rest_sample(actor,rig,index.cache).value
        var duration:float=float(rig.clips.Run.frames)/float(rig.clips.Run.fps)
        var active:Dictionary={"actor_uuid":actor_id,"clip":"Run","start_ms":0.0,"duration_ms":1000.0,"source_start_seconds":duration*2.1,"source_end_seconds":duration*3.1,"priority":1,"hidden_slots":["weapon"],"from_position":[1,1],"to_position":[2,1]}
        var member:Dictionary=span.owner.condition
        var rows:Array=[{"actor_uuid":actor_id,"before":null,"after":member,"row":{"field":"condition","condition_uuid":identity}}]
        var captures:Dictionary=Pose.admissions(rows,{actor_id:actor},{},{"actor_tracks":[active]},1000,.25,{},index.cache)
        check(captures.has(identity) and captures[identity].clip=="Run" and captures[identity].hidden_slots==["weapon"],"Contract: interrupted authored body retains current clip and hidden slots, "+faction)
        var projected:Dictionary=Pose.project({actor_id:{"clip":"Run","source_seconds":9.0,"position":[8,9],"base_height_steps":2.0}},admitted.state.actors,{identity:admitted.condition_owners[identity]},index.cache,{actor_id:rig_id})
        check(projected[actor_id].captured and projected[actor_id].position==[8,9] and projected[actor_id].base_height_steps==2.0,"Captured body preserves actual forced displacement/elevation, "+faction)
        var initial:Dictionary=admitted.condition_owners[identity].duplicate();initial.erase("logical_pose");initial.initial=true
        check(Pose.select(admitted.state.actors[actor_id],rig_id,"idle",index.cache,{identity:initial}).is_empty(),"Already-held owner with no original capture remains unavailable, "+faction)
        evidence.append({"faction":faction,"application_ms":span.start_ms,"removal_ms":span.end_ms,"capture":capture})
    var result={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Real original idle-target application, hold/seek and cure; non-idle capture is explicitly a pure clock/arbitration contract test."}
    FileAccess.open("res://.runtime/logical-pose-capture-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
