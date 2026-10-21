extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
# Real received Gallery residue versions through the worker/adoption boundary.
const Renderer=preload("res://presentation/blood_renderer.gd")
const Blood=preload("res://presentation/blood.gd")
const Recording=preload("res://studio/recording.gd")
class Owner extends Node:
    var catalog_cache:Dictionary={}
    var timeline:Dictionary={"current":{},"queue":[]}
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("BLOOD_PREPARE_FAIL ",label)
func run()->void:
    var index=Fixtures.read("gallery")
    check(index.ok,"Actual Gallery recording admits")
    if not index.ok:quit(1);return
    var original=load("res://tests/oracles/blood_before_shape_cache.gd")
    var owner=Owner.new();owner.catalog_cache=index.cache;root.add_child(owner)
    var renderer=Renderer.new();renderer.resources_ready=true;renderer.source=Blood.asset(index.cache)
    var versions:int=0
    var peak_workers:int=0
    var retained_versions:int=0
    var first_groups:Array=[]
    var eighteen_cell_witness:bool=false
    for item in index.groups:
        var group:Dictionary=item.group
        var components=group.components.filter(func(component):return component.kind=="residue_deposit")
        if components.is_empty():continue
        owner.timeline.current=group
        renderer._prune_pending(owner)
        for component in components:
            for reveal in component.reveals:
                var key=Blood.key(reveal.position)
                if not renderer.deposits.has(key):renderer.deposits[key]={"kernel_cache":{},"value":reveal.before}
        var complete:bool=false
        for attempt in 1200:
            var budget={"used_usec":0,"limit_usec":1000}
            complete=renderer.prepare(owner,[group],budget)
            var workers=renderer.kernel_jobs.size()
            peak_workers=maxi(peak_workers,workers)
            if workers>2:check(false,"Received shapes exceeded two worker jobs")
            if attempt==0:
                var cells:Dictionary={}
                for component in components:
                    for reveal in component.reveals:cells[Blood.key(reveal.position)]=true
                if cells.size()==18:
                    eighteen_cell_witness=true
                    check(not complete and renderer.kernel_preparations.filter(func(prepared):return prepared.task==-2).is_empty(),"All eighteen actual receiving cells enter bounded workers on one preparation turn; readiness still waits for completion")
                    for wait_turn in 1200:
                        if renderer.kernel_jobs.all(func(job):return WorkerThreadPool.is_task_completed(job.task)):break
                        await process_frame
                    complete=renderer.prepare(owner,[group],{"used_usec":0,"limit_usec":1000})
                    check(complete,"One completed worker batch makes all eighteen existing receiving fields ready on the next preparation turn, without nine frame admissions")
            if complete:break
            await process_frame
        check(complete,"All received exact field versions prepare")
        check(renderer.prepare_allocations==0 and renderer.pending_deposits.is_empty(),"Existing fields warm without allocating or publishing native fields")
        retained_versions=maxi(retained_versions,renderer.kernel_preparations.size())
        for component in components:
            var asset:Dictionary=component.asset_metadata
            for reveal in component.reveals:
                versions+=1
                var key=Blood.key(reveal.position)
                var value:Dictionary=reveal.after.duplicate(true)
                var handle:Dictionary=renderer.deposits[key]
                renderer._adopt_kernel_cache(handle,key,value,false,asset)
                check(is_same(handle.kernel_cache.get("value"),value) and is_same(handle.kernel_cache.get("source"),asset) and not handle.kernel_cache.get("particles",{}).is_empty(),"Prepared equivalent after-value copy adopts exact particle cache")
                var prepared=renderer.kernel_preparations.filter(func(entry):return entry.key==key and is_same(entry.source,asset) and entry.value==value)[0]
                check(is_same(handle.kernel_cache,prepared.output.cache),"Impact adopts completed worker cache without copying particle shapes")
                var active:Dictionary=reveal.duplicate();active.pattern=component.body_release.pattern
                check(not handle.kernel_cache.get("landing",{}).is_empty(),"Worker prepares exact single-reveal landing rows")
                var ages:Dictionary={-.01:true,0.:true,.3:true,.8:true,component.duration_ms/1000.+.01:true}
                var family:Dictionary=renderer.source.region.families[component.body_release.pattern]
                for template in renderer.source.region.templates:
                    for particle in template.particles:
                        var time=Blood.schedule(particle,family)
                        for age in [time.x+time.y-.000001,time.x+time.y,time.x+time.y+.000001]:ages[age]=true
                for age in ages:
                    active.age_seconds=age
                    check(Blood.kernels(value,reveal.position,[active],renderer.source,handle.kernel_cache)==original.kernels(value,reveal.position,[active],renderer.source),"Exact recorded pre-impact/landing/settled kernels "+str([component.id,key,age]))
                active.age_seconds=.3
                var second:Dictionary=active.duplicate();second.age_seconds=.8
                check(Blood.kernels(value,reveal.position,[active,second],renderer.source,handle.kernel_cache)==original.kernels(value,reveal.position,[active,second],renderer.source),"Overlapping reveals use the general amount evaluator exactly")
                var copied:Dictionary=active.duplicate(true)
                check(Blood.kernels(value,reveal.position,[copied],renderer.source,handle.kernel_cache)==original.kernels(value,reveal.position,[copied],renderer.source),"Copied equal reveal retains exact landing output")
                check(Blood.kernels(reveal.before,reveal.position,[],renderer.source,handle.kernel_cache)==original.kernels(reveal.before,reveal.position,[],renderer.source),"Reverse version cannot retain future residue shapes")
                renderer._adopt_kernel_cache(handle,key,value,false,asset)
                check(Blood.kernels(value,reveal.position,[],renderer.source,handle.kernel_cache)==original.kernels(value,reveal.position,[],renderer.source),"Reverse then forward cannot reuse a cache for another residue version")
                check(reveal.after==value,"Worker/adoption never mutates received residue")
        if first_groups.is_empty():first_groups=[group]
    # Preparation must cover finite schedules earlier than the ordinary clip,
    # and never interpret an absent cached amount as a clipped empty shape.
    var witness:Dictionary=first_groups[0].components.filter(func(component):return component.kind=="residue_deposit")[0]
    var reveal:Dictionary=witness.reveals[0]
    var altered:Dictionary=renderer.source.duplicate(true)
    altered.region.families[witness.body_release.pattern].delayScale=-1000.
    altered.region.families[witness.body_release.pattern].durationScale=-1000.
    var output:Dictionary={}
    Renderer._warm_kernels({"value":reveal.after,"position":reveal.position,"source":altered,"reveal":reveal,"pattern":witness.body_release.pattern},output)
    check(output.cache.has("landing"),"Finite negative schedule prepares both endpoint amounts")
    var active:Dictionary=reveal.duplicate();active.pattern=witness.body_release.pattern
    for age in [-INF,-100000.,-1.,0.]:
        active.age_seconds=age
        check(Blood.kernels(reveal.after,reveal.position,[active],altered,output.cache)==original.kernels(reveal.after,reveal.position,[active],altered),"Finite negative schedule retains exact pre/post landing "+str(age))
    output.cache.particles.clear()
    Blood.prepare_landing(output.cache,reveal,active.pattern)
    check(not output.cache.has("landing"),"Missing positive fraction preparation declines fast path")
    check(Blood.kernels(reveal.after,reveal.position,[active],altered,output.cache)==original.kernels(reveal.after,reveal.position,[active],altered),"Declined preparation uses unchanged general evaluator")
    owner.timeline.current={};owner.timeline.queue=[]
    renderer._prune_pending(owner)
    check(peak_workers<=2,"Received shapes stay within two worker jobs")
    check(eighteen_cell_witness,"Actual Gallery exercises the eighteen-cell preparation regression")
    check(renderer.kernel_preparations.is_empty(),"Completed results retire when their actual groups retire")
    # Closing while real received work is in flight must join its private job.
    owner.timeline.current=first_groups[0]
    renderer.prepare(owner,first_groups)
    check(renderer.kernel_jobs.size()<=2,"Restarted preparation remains bounded")
    owner.timeline.current={}
    renderer._prune_pending(owner)
    for wait_turn in 1200:
        if renderer.kernel_jobs.all(func(job):return WorkerThreadPool.is_task_completed(job.task)):break
        await process_frame
    renderer._prune_pending(owner)
    var retired_handle={"kernel_cache":{}}
    var retired_component:Dictionary=first_groups[0].components.filter(func(component):return component.kind=="residue_deposit")[0]
    var retired_reveal:Dictionary=retired_component.reveals[0]
    renderer._adopt_kernel_cache(retired_handle,Blood.key(retired_reveal.position),retired_reveal.after,false,retired_component.asset_metadata)
    check(renderer.kernel_jobs.is_empty() and renderer.kernel_preparations.is_empty() and retired_handle.kernel_cache.is_empty(),"Canceled received groups cannot publish completed or partial worker caches")
    owner.timeline.current=first_groups[0]
    renderer.prepare(owner,first_groups)
    renderer.deposits.clear();renderer.close(owner)
    check(renderer.kernel_preparations.is_empty(),"Close retires all private worker owners/results")
    owner.free()
    var report={"checks":checks,"failures":failures,"versions":versions,"peak_workers":peak_workers,"peak_received_versions":retained_versions,"scope":"Actual Gallery residue versions, existing-field preparation, exact before/landing/settled/reverse kernels; no GPU/live-performance claim"}
    FileAccess.open("res://.runtime/blood-shape-preparation-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BLOOD_SHAPE_PREPARATION_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
