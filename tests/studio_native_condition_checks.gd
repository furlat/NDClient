extends SceneTree
## Actual Hide recording through the immutable Studio index and shared selectors.
const Recording=preload("res://studio/recording.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Pose=preload("res://presentation/condition_pose.gd")
const Thumbnails=preload("res://studio/thumbnail_cache.gd")
const Coverage=preload("res://presentation/condition_coverage.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_NATIVE_CONDITION_FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var directory=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directory=arg.trim_prefix("--recording=")
    if directory.is_empty():print("Usage: --recording=<actual Hide amber journal>");quit(2);return
    var index=Recording.read(directory)
    check(index.ok,"Real current-SDK journal compiles with selected native authoring")
    if not index.ok:finish(directory);return
    var original=index.rows.duplicate(true)
    var poses=index.rows.filter(func(row):return row.kind=="condition_pose" and row.owner.condition.behavior_id=="condition.hidden")
    check(not poses.is_empty(),"Actual Hidden owner has first-class authored pose spans")
    var observed={};var thumbnails=Thumbnails.new();thumbnails.cache=index.cache
    for row in poses:
        observed[row.activity]=true
        var at:float=(row.start_ms+row.end_ms)*.5
        var timeline=Recording.restore(index,at)
        var actor:Dictionary=timeline.state.actors[row.owner.actor_uuid]
        var selected=Pose.select(actor,row.actor.rig,row.activity,index.cache)
        check(selected==row.selected_pose,"Indexed pose uses the shared live selection "+row.activity)
        check(row.source==selected.source and row.legacy_source==selected.legacy_source and ".tres::" in row.source,"Exact effective native pose field and legacy ownership remain inspectable")
        var samples=timeline.actor_samples()
        var expected:float=Pose.source_seconds(selected,Recording.Compiler.Authoring.clip(actor,selected.clip,index.cache),at-row.owner.start_ms)
        if row.activity=="move":
            check(samples.has(row.owner.actor_uuid) and samples[row.owner.actor_uuid].clip==selected.clip,"Movement row is an actual compiled crouch track")
            expected=samples[row.owner.actor_uuid].source_seconds
        else:check(not samples.has(row.owner.actor_uuid),"Resting crouch row does not overwrite an authored action track")
        var key=thumbnails.request(row,at,0)
        var jobs=thumbnails.pending.filter(func(job):return job.key==key)
        check(jobs.size()==1 and not thumbnails.errors.has(key),"Actual pose thumbnail request resolves its body source")
        if not jobs.is_empty():
            var clip=Recording.Compiler.Authoring.clip(actor,selected.clip,index.cache)
            var frame=clampi(int(fposmod(expected,float(clip.frames)/clip.fps)*clip.fps),0,int(clip.frames)-1)
            check(jobs[0].clip==selected.clip and jobs[0].frame==frame,"Thumbnail frame follows the same owner/track source clock")
            if row.activity=="idle":
                # Same admitted pose/age at a shifted occurrence origin. This
                # transport contract must not accidentally use the global clock.
                var shifted=row.duplicate(true);shifted.id+="/shifted";shifted.preview_tracks=[]
                shifted.start_ms+=137;shifted.end_ms+=137;shifted.source_start_ms+=137
                for state in shifted.preview_states:
                    state.at_ms+=137
                    if state.sampled_pose.get("clock")=="condition":state.sampled_pose.owner_start_ms+=137
                    for held_owner in state.condition_owners.values():
                        held_owner.start_ms+=137
                        if not is_inf(held_owner.end_ms):held_owner.end_ms+=137
                var shifted_key=thumbnails.request(shifted,at+137,0)
                var shifted_jobs=thumbnails.pending.filter(func(job):return job.key==shifted_key)
                check(shifted_jobs.size()==1 and shifted_jobs[0].frame==jobs[0].frame,"Owner-relative crouch thumbnail is invariant to occurrence clock origin")
            evidence.append({"activity":row.activity,"source":row.source,"clip":jobs[0].clip,"frame":jobs[0].frame,"at_ms":at,"owner_start_ms":row.owner.start_ms})
    check(observed.has("idle") and observed.has("move"),"Actual recording exercises idle and movement crouch")
    var materials=index.rows.filter(func(row):return row.kind=="condition_material" and row.owner.condition.behavior_id=="condition.hidden")
    check(not materials.is_empty() and materials.all(func(row):return row.operations.get("alphaMultiplier")==.55 and row.source_fields.alphaMultiplier.ends_with("condition.hidden.tres::look/steps/0/alpha")),"Partial opacity is an exact native body filter, not magical invisibility")
    var badges=index.rows.filter(func(row):return row.kind=="feedback_text" and row.component.get("legacy_source","").begins_with("catalog/condition_recipes.json:/condition.hidden/"))
    check(not badges.is_empty(),"Recorded condition transition emits actual feedback-text badge rows")
    for row in badges:
        check(row.source.ends_with("_text/enabled") and row.component.text.contains("Hidden") and row.label==row.component.text,"Badge retains its Resource field and authored text")
        var key=thumbnails.request(row,(row.start_ms+row.end_ms)*.5,0)
        check(thumbnails.pending.any(func(job):return job.key==key and job.component.kind=="feedback_text"),"Badge queues the existing native text preview, never an empty material pose")
    var report=Coverage.build(index.cache,index.rows,{"condition.hidden":true})
    check(report.entries[0].requirements.all(func(row):return row.get("gap_kind")!="authoring_assignment"),"Selected Hidden Resource does not leave a false missing JSON assignment")
    var requirements=report.entries[0].requirements.filter(func(row):return row.mechanism.begins_with("activityPoses:") or row.mechanism=="feedback_text")
    check(requirements.all(func(row):return not row.evidence.is_empty() and not row.rendered),"Recording evidence matches exact pose/badge fields without claiming native rendering")
    check(index.rows==original,"Thumbnail requests and coverage leave historical rows immutable")
    thumbnails.close()
    finish(directory)
func finish(directory:String)->void:
    var report={"checks":checks,"failures":failures,"evidence":evidence,"command":"--headless --script res://tests/studio_native_condition_checks.gd -- --recording="+directory,"scope":"Actual journal, effective native field provenance, shared pose clocks, thumbnail preparation and feedback text family. No GPU pixel claim."}
    FileAccess.open("res://generated/studio_native_condition_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_NATIVE_CONDITION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
