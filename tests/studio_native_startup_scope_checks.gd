extends SceneTree
## Exact recording-source admission. Native draw completion is qualified by the
## integrated Studio checkpoint; this fixture proves requested closure/ownership.
const Startup=preload("res://presentation/native_source_startup.gd")
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Effects=preload("res://presentation/effect_package.gd")
var checks:int=0
var failures:Array=[]
var recordings:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func run()->void:
    Startup.reset()
    var empty=Startup.step(null,{}, {"plan":[],"required":[],"optional":false})
    check(empty.ready and empty.total==0 and Startup._state.is_empty(),"Empty Studio has no catalog warmup or native owner")
    for path in [Fixtures.journal("gallery"), Fixtures.journal("shield","blue"), Fixtures.journal("web")]:
        var index:Dictionary=Recording.read(path)
        check(index.ok,"Real recording admits: "+path)
        if not index.ok:continue
        var before=var_to_bytes(index.rows)
        var plan:Array=Startup.recording_plan(index.rows)
        check(not plan.is_empty(),"Actual native sources exist: "+path)
        var keys:Dictionary={};var earliest:float=INF
        for item in plan:
            check(not keys.has(item.key),"Only exact duplicate effective source specifications are reused")
            keys[item.key]=true
            for span in item.intervals:earliest=minf(earliest,span.x)
        var native_rows:int=0;var persistent:int=0;var hit:int=0
        for row in index.rows:
            var component:Dictionary=row.get("component",{})
            var clip:Dictionary={}
            if component.get("native_spell",false) and component.get("status")!="missing":
                clip=Effects.occurrence_clip(component);native_rows+=1
                if component.get("persistent_owner",false):persistent+=1
            elif component.get("kind")=="material_flash" and component.get("native_hit",{}).get("definition",{}).get("status")=="available":
                clip=component.native_hit.clip;hit+=1
            if clip.is_empty() or component.get("native_item",false) or (Effects.requires_construction(clip) and not clip.has("construction_inputs")) or row.end_ms<=row.start_ms:continue
            var at=lerpf(row.start_ms,row.end_ms,.5)
            check(Startup.requested(plan,at).any(func(item):return item.key==Startup._key(clip)),"Exact active phase/hit source is required at its own actual row time")
        check(var_to_bytes(index.rows)==before,"Source plan does not mutate original rows, clips or clocks")
        var required:Array=Startup.requested(plan,0.0)
        var cold=Startup.status({"plan":plan,"required":required})
        check(cold.ready==required.is_empty() and cold.pending==required.size(),"Unrelated future sources do not become first-frame requirements")
        var completed:Dictionary={}
        if not required.is_empty():
            for item in required:completed[item.key]=true
        Startup._state={"done":completed,"failures":{},"ready":true}
        check(Startup.status({"plan":plan,"required":required}).ready,"Exact warmed current set is sufficient despite unwarmed future set")
        var later=plan.filter(func(item):return not completed.has(item.key))
        if not later.is_empty():
            check(not Startup.status({"plan":plan,"required":[later[0]]}).ready,"Later seek/source cannot inherit a smaller plan ready flag")
            Startup._state.failures[later[0].key]="Explicit unavailable later source"
            check(Startup.status({"plan":plan,"required":required}).errors.is_empty(),"Unrelated failure does not poison current readiness")
            check(Startup.status({"plan":plan,"required":[later[0]]}).errors.size()==1,"Actual requested failed source remains explicit")
            check(Startup.status({"plan":plan,"required":required}).background_errors.size()==1,"Optional failures remain observable separately")
        recordings.append({"path":path,"sources":plan.size(),"native_rows":native_rows,"persistent_rows":persistent,"hit_rows":hit,
            "first_native_ms":earliest,"initial_required":required.size(),"sources_by_time":plan.map(func(item):return {"source":item.clip.id,"intervals":item.intervals})})
        Startup._state={}
    var clip={"id":"same source","components":[],"seconds":1.0}
    var rows=[{"start_ms":0.0,"end_ms":100.0,"component":{"native_spell":true,"native_clip":clip,"native_cue":{},"status":"available"}},
        {"start_ms":500.0,"end_ms":600.0,"component":{"native_spell":true,"native_clip":clip,"native_cue":{"opacity_uniform":"authored_alpha"},"status":"available"}}]
    var variants=Startup.recording_plan(rows)
    check(variants.size()==2,"Actual cue opacity adaptation has a distinct effective native source identity")
    check(Startup.requested(variants,150.0).is_empty() and Startup.requested(variants,150.0,4000.0).size()==1,"Upcoming source priority is separate from current readiness")
    check(not clip.has("opacity_uniform"),"Effective adaptation leaves authoring source unchanged")
    var done:Dictionary={}
    for item in variants:done[item.key]=true
    Startup._state={"plan":variants.duplicate(),"known":done.duplicate(),"done":done.duplicate(),"failures":{},
        "ready":true,"started":Time.get_ticks_usec(),"elapsed_ms":12.5,"memory_after":{"completed":true},"construction_ms":[]}
    var completed_before:Dictionary=Startup._state.duplicate(true)
    var completed_status=Startup.step(null,{}, {"plan":variants,"required":[variants[0]],"optional":true})
    check(completed_status.ready and completed_status.elapsed_ms==12.5 and Startup._state==completed_before,"Completed source polling retains its original receipt without diagnostics or native work")
    var another:Dictionary=variants[0].duplicate(true);another.clip.id="new source after completion";another.key=Startup._key(another.clip)
    var changed=Startup.step(null,{}, {"plan":[another],"required":[another],"optional":false},{"used_usec":2000,"limit_usec":2000})
    check(not changed.ready and changed.pending==1 and not Startup._state.ready,"A new source invalidates completion before the zero-allowance return")
    Startup._state={}
    var report={"checks":checks,"failures":failures,"recordings":recordings,"scope":"Recorded source/request closure only; no native draw readiness or timing claimed by a headless fixture."}
    FileAccess.open("res://.runtime/studio-native-startup-scope-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_NATIVE_STARTUP_SCOPE ",checks," failures=",failures," sources=",recordings.map(func(item):return item.sources))
    quit(0 if failures.is_empty() else 1)
