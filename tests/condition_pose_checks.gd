extends SceneTree
# Actual Hide records and installed source registration -> shared pose operands,
# unchanged causal movement schedule, and native AnimationTree source frames.
# Headless: no pixel, lighting, or assembled-character appearance claim.
const Catalog=preload("res://source_catalog.gd")
const Pose=preload("res://presentation/condition_pose.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Characters=preload("res://presentation/characters.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Graphs=preload("res://animation/graphs.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("CONDITION_POSE_FAIL ",label)
func run()->void:
    var directory=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directory=arg.trim_prefix("--recording=")
    if directory.is_empty():push_error("Use --recording=<actual Hide journal>");quit(2);return
    var cache={}
    var rigs=Catalog.read_file("catalog/rigs.json",cache)
    var rig:Dictionary=rigs["neuroclient.modular"]
    for name in ["CrouchIdle","CrouchRun"]:
        check(rig.clips.has(name),"Resource adopts actual "+name)
        if not rig.clips.has(name):finish({});return
        var clip:Dictionary=rig.clips[name]
        check(clip.frames==15 and clip.fps==12,"Explicit new 12 FPS source clock "+name)
        check(clip.sheets.size()==rig.clips.Idle.sheets.size(),"All current modular categories registered "+name)
        for category in clip.sheets:
            var path:String=clip.sheets[category]
            check(path=="/media/smallscale/modular/"+category+"/"+name+".png" and FileAccess.file_exists(Catalog.media_path(path)),"Installed original source "+category+"/"+name)
    var recipes=Catalog.read_file("catalog/condition_recipes.json",cache)
    var held_recipes=recipes.duplicate(true)
    var baseline_cache=cache.duplicate()
    baseline_cache["catalog/condition_recipes.json"]=recipes.duplicate(true)
    baseline_cache["catalog/condition_recipes.json"]["condition.hidden"].persistent.erase("activityPoses")
    var journal=Journal.new()
    var opened=journal.open(directory,false,false)
    check(opened.ok,"Recording journal opens without writes")
    if not opened.ok:finish({"recording":directory});return
    var files:Array[String]=[]
    for name in DirAccess.get_files_at(directory):
        if name.ends_with(".json") and name.get_basename().is_valid_int():files.append(name)
    files.sort()
    var actor={};var hidden_moves=0;var other_tracks=0;var operations=0
    for name in files:
        var raw=FileAccess.get_file_as_bytes(directory.path_join(name))
        var decoded=journal.protocol.decode("InitializationResponse" if operations==0 else "PlayerOperation",raw)
        check(decoded.ok,"Actual packet decodes "+name)
        if not decoded.ok:break
        var before:Dictionary=journal.state
        var admitted=journal._consume_admitted(decoded.value,raw,true)
        check(admitted.ok,"Actual packet reduces "+name)
        if not admitted.ok:break
        for value in journal.state.actors.values():
            if value.get("conditions",[]).any(func(c):return c.behavior_id=="condition.hidden"):actor=value
        if operations>0:
            var compiled=Compiler.compile_recorded(before,admitted.normalized,cache,journal.state,admitted.transitions)
            var original=Compiler.compile_recorded(before,admitted.normalized,baseline_cache,journal.state,admitted.transitions)
            check(compiled.ok and original.ok,"Both authored pose selections compile "+name)
            if not compiled.ok or not original.ok:break
            check(compiled.value.groups.size()==original.value.groups.size(),"No new schedule groups "+name)
            for i in compiled.value.groups.size():
                var a:Dictionary=compiled.value.groups[i];var b:Dictionary=original.value.groups[i]
                check(a.commits==b.commits and a.duration_ms==b.duration_ms,"Every state commit and group duration unchanged "+a.id)
                check(a.actor_tracks.size()==b.actor_tracks.size(),"Existing body-track cardinality unchanged "+a.id)
                for j in a.actor_tracks.size():
                    var track:Dictionary=a.actor_tracks[j];var prior:Dictionary=b.actor_tracks[j]
                    if track.clip=="CrouchRun":
                        hidden_moves+=1
                        check(prior.clip=="Run" and track.activity=="move" and track.trajectory=="path","Only actual ground locomotion selects crouch")
                        var compare=track.duplicate();compare.clip=prior.clip;compare.erase("condition_pose")
                        check(compare==prior,"Crouch changes only source clip, not positions/source clock/markers")
                    else:
                        other_tracks+=1;check(track==prior,"Attack/hit/jump/other track remains exact")
        operations+=1
    check(not actor.is_empty() and hidden_moves>0,"Actual recording includes admitted Hidden and crouched movement")
    if actor.is_empty():finish({"recording":directory});return
    var held_actor=actor.duplicate(true)
    var idle=Pose.select(actor,"neuroclient.modular","idle",cache)
    var move=Pose.select(actor,"neuroclient.modular","move",cache)
    check(idle.clip=="CrouchIdle" and move.clip=="CrouchRun","Shared activity selectors resolve original clips")
    check(idle.source.ends_with("hidden.tres::activity_poses/0") and move.source.ends_with("hidden.tres::activity_poses/1"),"Selected Resource property provenance is precise")
    check(Pose.select(actor,"uncovered.rig","idle",cache).is_empty(),"No invented crouch for other rigs")
    var host=Graphs.build_character(root,rig,true)
    for age in [0.0,250.0,1250.0,1500.0,3750.0]:
        var seconds=Pose.source_seconds(idle,rig.clips.CrouchIdle,age)
        var sampled=Graphs.sample(host,idle.clip,seconds,idle.condition_uuid)
        check(sampled.ok and is_equal_approx(host.sample_seconds,fposmod(age/1000.0,1.25)),"Native idle frame follows owner age through loops: "+str(age))
    for name in ["CrouchIdle","CrouchRun"]:
        check(Graphs.character_loops(rig,name),"Adopted descriptor declares shared looping: "+name)
        var sampled=Graphs.sample(host,name,2.75,"direct-loop:"+name)
        check(sampled.ok and is_equal_approx(host.sample_seconds,.25),"Native sampler loops source beyond one cycle: "+name)
    host.free()
    var frozen={"clip":"CrouchIdle","sampling":"hold","frame":7}
    check(is_equal_approx(Pose.source_seconds(frozen,rig.clips.CrouchIdle,9999),7.0/12),"Hold sampling stays on authored frame")
    var changed=actor.duplicate(true);changed.life_state="dead"
    check(Pose.select(changed,"neuroclient.modular","idle",cache).is_empty(),"Death retains original resting authority")
    changed=actor.duplicate(true)
    for c in changed.conditions:
        if c.condition_uuid==idle.condition_uuid:c.state={"suppression_provider_uuids":["actual-provider"]}
    check(Pose.select(changed,"neuroclient.modular","idle",cache).is_empty(),"Suppressed Hidden does not select crouch")
    changed=actor.duplicate(true)
    changed.conditions.append({"behavior_id":"condition.paralyzed","condition_uuid":"held-paralysis","state":null})
    var held_pose=Pose.select(changed,"neuroclient.modular","idle",cache)
    check(held_pose.clip=="Idle" and held_pose.frame==3 and held_pose.condition_uuid=="held-paralysis","Higher-priority authored frozen pose still wins over crouch")
    changed.conditions=[{"behavior_id":"condition.prone","condition_uuid":"prone","state":null}]
    var prone=Pose.select(changed,"neuroclient.modular","idle",cache)
    check(prone.clip=="Die" and prone.terminal and is_equal_approx(Pose.source_seconds(prone,rig.clips.Die,9000),float(rig.clips.Die.frames)/rig.clips.Die.fps),"Legacy terminal resting pose remains exact")
    var fact={"trajectory":"path","movement_mode":"walking"}
    check(Authoring.body("movement",actor,fact,cache).actor.clip=="CrouchRun","Ground body selection uses native pose")
    for excluded in [{"trajectory":"direct_arc","movement_mode":"jumping"},{"trajectory":"connector_transfer","movement_mode":"walking","connector_presentation_key":"window"},{"trajectory":"path","movement_mode":"flying"}]:
        check(Authoring.body("movement",actor,excluded,cache)==Authoring.body("movement",actor,excluded,baseline_cache),"Other movement arbitration remains exact: "+excluded.trajectory+"/"+excluded.movement_mode)
    for role in ["damage","death"]:
        check(Authoring.body(role,actor,{},cache)==Authoring.body(role,actor,{},baseline_cache),role+" source unchanged")
    var state={"actors":{actor.uuid:actor},"tiles":{},"objects":{},"senses":null,"audience":{"controlled":[actor.uuid]}}
    var demand=Media.plan(state,[],cache)
    var expected=Characters.sheet_paths(actor,["CrouchIdle","CrouchRun"],cache)
    check(expected.ok and demand.errors.is_empty(),"Actual outfit resolves both pose source closures")
    if expected.ok:
        check(expected.value.keys().all(func(path):return demand.required.has(path)),"Hidden admission requires complete idle and move colour/normal/depth closure")
        check(expected.cpu_required.keys().all(func(path):return demand.cpu_required.has(path)),"Original source CPU roles retained for crouch")
    check(actor==held_actor and recipes==held_recipes,"All pose/compiler/demand reads preserve actor and authored data")
    finish({"recording":directory,"operations":operations,"hidden_moves":hidden_moves,"unchanged_other_tracks":other_tracks,"outfit_pose_paths":expected.get("value",{}).size()})
func finish(evidence:Dictionary)->void:
    evidence.checks=checks;evidence.failures=failures
    evidence.scope="Actual recorded Hide compilation, source resource registration, body-clock and mandatory media operands; headless AnimationTree sampling, no pixel qualification."
    FileAccess.open("res://generated/condition_pose_checks.json",FileAccess.WRITE).store_string(JSON.stringify(evidence,"  "))
    print("CONDITION_POSE_CHECKS ",JSON.stringify(evidence));quit(0 if failures.is_empty() else 1)
