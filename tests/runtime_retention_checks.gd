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
    var first_player: AnimationPlayer = first.get_node("AnimationPlayer")
    var second_player: AnimationPlayer = second.get_node("AnimationPlayer")
    check(first_player.get_animation_library("")==second_player.get_animation_library(""),"Independent catalog reads share the immutable animation library within one scene")
    Graphs.sample(first,"Attack1",.6,"first")
    Graphs.sample(second,"Run",.2,"second")
    check(first.clip=="Attack1" and is_equal_approx(first.sample_seconds,.6),"Second actor cannot change first actor clip/clock")
    check(second.clip=="Run" and is_equal_approx(second.sample_seconds,.2),"Each native tree resolves its own animated properties")
    first.free()
    var recreated = Graphs.character(root,rig,true,templates)
    Graphs.sample(recreated,"Die",50,"death")
    check(recreated.clip=="Die" and is_equal_approx(recreated.sample_seconds,1.25),"Recreated host restores the causal held death frame")
    check(second.clip=="Run" and is_equal_approx(second.sample_seconds,.2),"Recreation leaves a sibling's animation clock intact")
    second.free(); recreated.free(); templates.clear()
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
