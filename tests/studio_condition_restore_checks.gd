extends SceneTree
## Actual condition-removal facts -> explicit pose/material restoration inspection.
const Recording=preload("res://studio/recording.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Pose=preload("res://presentation/condition_pose.gd")
const Characters=preload("res://presentation/characters.gd")
const Thumbnails=preload("res://studio/thumbnail_cache.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_CONDITION_RESTORE_FAIL ",label)
func property(material:Dictionary,field:String)->Variant:
    match field:
        "alphaMultiplier":return material.alpha
        "bodyColor":return {"tint":material.tint,"saturation":material.saturation,"brightness":material.brightness}
        "bodyRamp":return material.ramp
        "bodyOutline":return material.outline
    return null
func actual_pose(timeline:RefCounted,id:String,cache:Dictionary)->String:
    var sample:Dictionary=timeline.actor_samples().get(id,{})
    if not sample.is_empty():return sample.clip
    var actor:Dictionary=timeline.state.actors[id]
    var rig_id=Characters.rig_id(actor,cache)
    var selected=Pose.select(actor,rig_id,"idle",cache)
    if not selected.is_empty():return selected.clip
    return Characters.rest_sample(actor,cache["catalog/rigs.json"][rig_id],cache).value.clip
func run()->void:
    for name in ["hide-seed3-v3","hide-light-schema9-seed3","dodge-seed3","invisibility-seed3-v2","rage-seed3-v3","condition_owners-seed4","condition_suppression-seed3-v2"]:
        var index=Recording.read("res://.runtime/studio-cases/"+name+"/amber/journal")
        check(index.ok,name+" actual journal admits")
        if not index.ok:continue
        var by_id={}
        for row in index.rows:by_id[row.id]=row
        var restores=index.rows.filter(func(row):return row.kind=="condition_restore")
        var cache=Thumbnails.new();cache.cache=index.cache
        for row in restores:
            var label=name+" "+row.mechanism
            var removed:float=row.transition.condition_removed_ms
            var before=Recording.restore(index,maxf(0,removed-.001))
            var after=Recording.restore(index,row.start_ms)
            check(by_id.has(row.parent) and by_id[row.parent].kind=="event" and by_id[row.parent].event.kind=="condition",label+" belongs to an actual condition occurrence")
            check(by_id[row.parent].markers.any(func(marker):return marker.kind=="commit" and is_equal_approx(marker.at_ms,removed)),label+" transition uses the actual removal commit")
            check(before.state.actors[row.actor_uuid].conditions.any(func(condition):return condition.condition_uuid==row.owner.id),label+" original owner exists before actual removal")
            check(not after.state.actors[row.actor_uuid].conditions.any(func(condition):return condition.condition_uuid==row.owner.id),label+" original owner is absent in authoritative after-state")
            check(row.actor_uuid==row.owner.actor_uuid and row.recipient_uuid==row.actor_uuid and not row.actor_name.is_empty(),label+" exact disclosed recipient is retained")
            check(row.coverage.rendered=="not_witnessed" and row.diagnostic_scope=="state_inspection",label+" no new runtime component or render witness is invented")
            check(is_equal_approx(row.start_ms,removed+row.transition.fade_ms) and row.end_ms>=row.start_ms,label+" starts after only the existing declared removal fade")
            var boundary=row.end_ms==index.presentation_end_ms
            for state in row.preview_states:boundary=boundary or row.end_ms==state.at_ms
            for track in row.preview_tracks:boundary=boundary or row.end_ms in [track.start_ms,track.start_ms+track.duration_ms,track.group_end_ms]
            check(boundary or row.end_ms==row.start_ms,label+" interval ends at a real presentation boundary")
            if row.mechanism=="pose":
                check(row.transition.from.clip==actual_pose(before,row.actor_uuid,index.cache) and row.transition.to.clip==actual_pose(after,row.actor_uuid,index.cache),label+" before/after clips are the production selection")
            else:
                var previous=Conditions.material(row.actor_uuid,before.component_samples(index.cache))
                var current=Conditions.material(row.actor_uuid,after.component_samples(index.cache))
                check(row.transition.from==property(previous,row.mechanism) and row.transition.to==property(current,row.mechanism),label+" before/after values match the production composed material")
            var at:float=(row.start_ms+row.end_ms)*.5
            var key=cache.request(row,at,0,false)
            var jobs=cache.pending.filter(func(job):return job.key==key)
            check(jobs.size()==1 and not cache.errors.has(key),label+" real after-state queues a composed actor preview")
            if not jobs.is_empty():
                var sampled=Recording.restore(index,at)
                check(jobs[0].clip==actual_pose(sampled,row.actor_uuid,index.cache),label+" preview returns to the actual body pose")
                check(is_equal_approx(jobs[0].material.alpha,Conditions.material(row.actor_uuid,sampled.component_samples(index.cache)).alpha),label+" preview uses restored composed opacity")
            evidence.append({"case":name,"mechanism":row.mechanism,"actor":row.actor_name,"removed_ms":removed,"start_ms":row.start_ms,"end_ms":row.end_ms,"from":row.transition.from,"to":row.transition.to})
        if name.begins_with("hide"):
            var hidden=restores.filter(func(row):return row.owner.condition.behavior_id=="condition.hidden")
            check(hidden.size()==2,name+" exposes both Hidden opacity and pose restoration")
            check(hidden.any(func(row):return row.mechanism=="alphaMultiplier" and row.transition.from==.55 and row.transition.to==1.0 and row.transition.curve=="step"),name+" opacity restores instantly from .55 to 1")
            check(hidden.any(func(row):return row.mechanism=="pose" and row.transition.from.clip=="CrouchIdle" and row.transition.to.clip=="Idle"),name+" crouch returns to normal Idle")
            if not hidden.is_empty():
                var original:Dictionary=hidden[0]
                var cropped={"rows":[by_id[original.parent]],"cache":index.cache,"presentation_end_ms":original.transition.condition_removed_ms}
                Recording._condition_restoration_rows(cropped,original.owner,{"event_id":original.parent,"event_uuid":original.source_event_uuid,"actor_uuid":original.actor_uuid},original.preview_states,original.preview_tracks)
                check(cropped.rows.filter(func(row):return row.kind=="condition_restore").all(func(row):return row.start_ms==row.end_ms),name+" terminal inspection boundary invents no tail or fade")
        for owner_row in index.rows:
            if owner_row.kind!="condition":continue
            if is_inf(owner_row.owner.end_ms):
                check(not restores.any(func(row):return row.owner.id==owner_row.owner.id),name+" active condition does not invent a future removal")
            else:
                var owner:Dictionary=owner_row.owner
                var before=Recording.restore(index,maxf(0,owner.end_ms-.001))
                var after=Recording.restore(index,owner.end_ms+Conditions.fade_ms(owner.condition,index.cache))
                var previous=Conditions.material(owner.actor_uuid,before.component_samples(index.cache))
                var current=Conditions.material(owner.actor_uuid,after.component_samples(index.cache))
                for field in ["alphaMultiplier","bodyColor","bodyRamp","bodyOutline"]:
                    if property(previous,field)==property(current,field):
                        check(not restores.any(func(row):return row.owner.id==owner.id and row.mechanism==field),name+" unchanged effective "+field+" does not invent a reset under overlapping/suppressed owners")
        cache.close()
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual SDK Hide, optical reveal, Dodge, Invisibility, Rage, overlapping owner and suppression journals; source-owned removal commits, shared composed pose/material restoration, real after-state intervals and thumbnail requests. No native framebuffer claim."}
    FileAccess.open("res://generated/studio_condition_restore_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_CONDITION_RESTORE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
