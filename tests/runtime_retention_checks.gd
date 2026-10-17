extends SceneTree
const Graphs = preload("res://animation/graphs.gd")
const Catalog = preload("res://source_catalog.gd")
const Profile = preload("res://frame_profile.gd")
var checks := 0
var failures: Array = []
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var cache := {}
    var rig: Dictionary = Catalog.read_file("catalog/rigs.json",cache)["neuroclient.modular"]
    var templates: Array = []
    var first = Graphs.character(root,rig,true,templates)
    var second = Graphs.character(root,rig.duplicate(true),true,templates)
    check(first.find_children("*","AnimationMixer",true,false).is_empty(),"A sampled actor builds no AnimationPlayer/AnimationTree")
    Graphs.sample(first,"Attack1",.6,"first")
    Graphs.sample(second,"Run",.2,"second")
    check(first.clip=="Attack1" and is_equal_approx(first.sample_seconds,.6),"Second actor cannot change first actor clip/clock")
    check(second.clip=="Run" and is_equal_approx(second.sample_seconds,.2),"Each actor clock resolves its own clip time")
    first.free()
    var recreated = Graphs.character(root,rig,true,templates)
    Graphs.sample(recreated,"Die",50,"death")
    check(recreated.clip=="Die" and is_equal_approx(recreated.sample_seconds,1.25),"Recreated host restores the causal held death frame")
    check(second.clip=="Run" and is_equal_approx(second.sample_seconds,.2),"Recreation leaves a sibling's animation clock intact")
    second.free(); recreated.free(); templates.clear()
    # Oracle: the arithmetic clock equals the seek tree it replaced, bit for
    # bit, for every clip of every rig at times inside, at and past the clip.
    var differing: Array = []
    var compared := 0
    for rig_id in Catalog.read_file("catalog/rigs.json",cache):
        var any_rig: Dictionary = Catalog.read_file("catalog/rigs.json",cache)[rig_id]
        var tree = Graphs.character(root,any_rig)
        var clock = Graphs.character(root,any_rig,true)
        for clip in any_rig.clips:
            var length: float = float(any_rig.clips[clip].frames)/float(any_rig.clips[clip].fps)
            for time in [0.0,.001,length*.37,length*.5,length-.0001,length,length+.013,length*2.71,37.3]:
                var a: Dictionary = Graphs.sample(tree,clip,time,"oracle")
                var b: Dictionary = Graphs.sample(clock,clip,time,"oracle")
                compared += 1
                if a.ok!=b.ok or tree.clip!=clock.clip or tree.sample_seconds!=clock.sample_seconds or tree.phase!=clock.phase:
                    differing.append([rig_id,clip,time,tree.sample_seconds,clock.sample_seconds])
        tree.free(); clock.free()
    check(differing.is_empty(),"Arithmetic clock equals the sampled AnimationTree: "+str(differing.slice(0,5)))
    check(compared>100,"Clock oracle compares every rig clip ("+str(compared)+")")
    var profile = Profile.create()
    profile.recording = true
    profile.last_usec = Time.get_ticks_usec()
    for i in range(Profile.RECORDING_HISTORY+7): Profile.frame(profile,root,{"sample_id":i})
    check(profile.frames.size()==Profile.HISTORY,"Default diagnostics retain only their bounded frame window")
    check(profile.recorded.size()==Profile.RECORDING_HISTORY,"Explicit profiling stays bounded during long sessions")
    check(profile.recorded_total==Profile.RECORDING_HISTORY+7,"Profile lifetime total records evicted samples honestly")
    var ids = profile.recorded.map(func(value):return value.view.sample_id)
    ids.sort()
    check(ids[0]==7 and ids.back()==Profile.RECORDING_HISTORY+6,"Ring retains every recent frame, not an arbitrary subset")
    profile.recorded.clear()
    Profile.frame(profile,root,{"sample_id":0})
    check(profile.recorded_total==1 and profile.recorded.size()==1,"A fresh explicit recording resets its lifetime counters")
    print("RUNTIME_RETENTION_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
