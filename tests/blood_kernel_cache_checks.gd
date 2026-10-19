extends SceneTree
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var original:Script
var candidate:Script
const Profile=preload("res://frame_profile.gd")
var checks:int=0
var failures:Array=[]
var timings:Dictionary={"original":[],"cached":[]}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func run()->void:
    var oracle:String="";var selected:String="res://presentation/blood.gd"
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--oracle="):oracle=argument.trim_prefix("--oracle=")
        elif argument.begins_with("--candidate="):selected=argument.trim_prefix("--candidate=")
    if oracle.is_empty():printerr("Provide saved pre-edit blood source with --oracle");quit(2);return
    original=load(oracle);candidate=load(selected)
    var index=Fixtures.read("gallery")
    check(index.ok,"Actual Gallery recording admits")
    if not index.ok:quit(1);return
    var source:Dictionary=original.asset(index.cache)
    var occurrences:int=0
    for item in index.groups:
        for component in item.group.components:
            if component.kind!="residue_deposit":continue
            occurrences+=1
            for reveal in component.reveals:
                var cache:Dictionary={}
                var active:Dictionary=reveal.duplicate()
                active.pattern=component.body_release.pattern
                var ages:Array=[-.01]
                for frame in 31:ages.append(frame*component.duration_ms/30000.)
                ages.append_array([0.3,0.8,0.3,component.duration_ms/1000.+.01])
                for age in ages:
                    active.age_seconds=age
                    var began:int=Time.get_ticks_usec()
                    var expected:Array=original.kernels(reveal.after,reveal.position,[active],source)
                    timings.original.append((Time.get_ticks_usec()-began)/1000.)
                    began=Time.get_ticks_usec()
                    var actual:Array=candidate.kernels(reveal.after,reveal.position,[active],source,cache)
                    timings.cached.append((Time.get_ticks_usec()-began)/1000.)
                    check(actual==expected,"Exact recorded field kernels "+str([component.id,reveal.position,age]))
                check(candidate.kernels(reveal.after,reveal.position,[],source,cache)==original.kernels(reveal.after,reveal.position,[],source),"Actual settled field after active release ends")
                check(candidate.kernels(reveal.before,reveal.position,[],source,cache)==original.kernels(reveal.before,reveal.position,[],source),"Reverse state replaces cached value")
                check(is_same(cache.value,reveal.before),"Only current after-value remains cached")
    check(occurrences>5,"Multiple actual Gallery injuries exercised")
    var report:Dictionary={"checks":checks,"failures":failures,"occurrences":occurrences,"timing_ms":{"original":Profile.distribution(timings.original),"cached":Profile.distribution(timings.cached)},"scope":"All actual Gallery blood contributions, before/landing/settled/reverse ages. Exact ordered kernel dictionaries versus saved pre-edit implementation; isolated CPU costs only."}
    FileAccess.open("res://.runtime/blood-kernel-cache-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BLOOD_KERNEL_CACHE_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
