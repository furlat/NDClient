extends SceneTree
# Actual saved journal -> original reducer/compiler -> body samples. No GPU,
# new gameplay outcomes, journal mutation or claims of live renderer validation.
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Characters=preload("res://presentation/characters.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Tracks=preload("res://presentation/tracks.gd")
const Graphs=preload("res://animation/graphs.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value: failures.append(label);print("LIFECYCLE_FAIL ",label)
func _initialize()->void:run.call_deferred()
func recorded(directory:String)->void:
    var journal=Journal.new()
    var opened=journal.open(directory,true,false)
    check(opened.ok,"Actual journal opens")
    if not opened.ok:return
    var files:Array=[]
    for name in DirAccess.get_files_at(directory):
        if name.ends_with(".json") and name.trim_suffix(".json").is_valid_int():files.append(name)
    files.sort()
    var cache={}
    var counts={"falls":0,"terminal_holds":0,"saves":0,"revivals":0,"operations":0}
    for index in files.size():
        var raw=FileAccess.get_file_as_bytes(directory.path_join(files[index]))
        var decoded=journal.protocol.decode("InitializationResponse" if index==0 else "PlayerOperation",raw)
        check(decoded.ok,"Actual packet decodes "+files[index])
        if not decoded.ok:return
        var before:Dictionary=journal.state
        var admitted=journal._consume_admitted(decoded.value,raw,true)
        check(admitted.ok,"Actual packet reduces "+files[index])
        if not admitted.ok:return
        if index==0:continue
        var compiled=Compiler.compile_recorded(before,admitted.normalized,cache,journal.state,admitted.transitions)
        check(compiled.ok,"Actual packet compiles "+files[index])
        if not compiled.ok:return
        counts.operations+=1
        var displayed=before.duplicate(true)
        for group in compiled.value.groups:
            for commit in group.commits:Compiler.apply_delta(displayed,commit.delta)
            for row in group.events:
                if row.kind not in ["life","death_save"]:continue
                var node={}
                for lineage in admitted.normalized.lineages:
                    for candidate in lineage.events:
                        if str(int(candidate.occurrence))==row.event_uuid:node=candidate;break
                if node.is_empty() or node.get("canceled",false):continue
                var fact:Dictionary=node.fact
                var bodies:Array=group.actor_tracks.filter(func(track):return track.source_event_uuid==str(int(node.occurrence)))
                if fact.kind=="death_save":
                    counts.saves+=1
                    check(bodies.is_empty(),"A death save never starts a body fall")
                    continue
                check(bodies.size()==1,"Each actual life transition has its sampled body owner")
                if bodies.is_empty():continue
                var body:Dictionary=bodies[0]
                if fact.new_state=="alive":
                    counts.revivals+=1
                    check(body.source_start_seconds>body.source_end_seconds and body.duration_ms>0,"Actual revival rises once in reverse")
                elif fact.previous_state=="alive":
                    counts.falls+=1
                    check(body.duration_ms>0 and body.source_start_seconds<body.source_end_seconds,"Actual upright downing falls once")
                else:
                    counts.terminal_holds+=1
                    check(body.duration_ms==0 and body.source_start_seconds==body.source_end_seconds,"Already downed life transition keeps final pose without refalling")
                    for elapsed in [0.0,17.0,1500.0,9000.0]:
                        var sample:Dictionary=Tracks.samples([body],body.start_ms+elapsed).get(body.actor_uuid,{})
                        check(sample.get("source_seconds")==body.source_end_seconds,"Later stable/dead samples stay at final frame")
                var first=Tracks.samples([body],body.start_ms+body.duration_ms*.5)
                Tracks.samples([body],body.start_ms+9000)
                check(Tracks.samples([body],body.start_ms+body.duration_ms*.5)==first,"Seek/loop resampling is deterministic")
                var actor:Dictionary=displayed.actors[fact.entity_uuid]
                var rig:Dictionary=Authoring.rigs(cache)[body.rig]
                var rest=Characters.rest_sample(actor,rig,cache)
                if actor.life_state in ["dead","dying","stable"]:
                    check(rest.ok and rest.value.source_seconds==float(rig.clips[rest.value.clip].frames)/rig.clips[rest.value.clip].fps,"Terminal idle holds source endpoint after body track retires")
                    var host=Graphs.build_character(root,rig,true)
                    for elapsed in [0.0,1.0,10.0]:
                        var sampled=Graphs.sample(host,rest.value.clip,rest.value.source_seconds,"terminal:"+actor.uuid)
                        check(sampled.ok and is_equal_approx(host.sample_seconds,rest.value.source_seconds),"Actual animation graph keeps terminal endpoint across idle samples")
                    host.free()
        check(displayed==journal.state,"Every original event after-value reaches canonical state without dropping commits")
    check(counts.falls>0,"Recording contains actual downing")
    evidence.append({"journal":directory,"counts":counts,"last_sequence":journal.cursor.sequence})
func run()->void:
    var directories:Array=[]
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--journal="):directories.append(argument.trim_prefix("--journal="))
    if directories.is_empty():printerr("Pass --journal=<real journal> (repeatable)");quit(2);return
    for directory in directories:recorded(directory)
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Original recorded reducer/compiler and native AnimationTree terminal sampling; no GPU/live visual claim."}
    FileAccess.open("res://generated/recorded_lifecycle_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("RECORDED_LIFECYCLE ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
    quit(0 if failures.is_empty() else 1)
