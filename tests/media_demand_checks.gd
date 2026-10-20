extends SceneTree
## Current physical-source contracts against the complete frozen source owner.
## Passive residency receipts do not claim native texture pixels.
const Media=preload("res://presentation/media_warmup.gd")
const Reference=preload("res://tests/oracles/media_before_source_delta.gd")
var checks:int=0
var failures:Array=[]
var current:Dictionary={}
var original:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("MEDIA_DEMAND_FAIL ",label)
func physical(data:Dictionary)->Dictionary:return Media.physical(data)
func family(amounts:Array=[16,16,16])->Dictionary:
    var result:Dictionary={"paths":{},"source_sizes":{},"gpu_only":{}}
    for i in amounts.size():
        var path:String="source/"+str(i)
        result.paths[path]="/test/"+str(i)+".png";result.source_sizes[path]=amounts[i];result.gpu_only[path]=true
    result.ordered_paths=result.paths.keys()
    return result
func reset(plan:Dictionary,budget:int=48)->void:
    if not current.is_empty():Media.close(current);Reference.close(original)
    current=Media.create();original=Reference.create()
    for pair in [[Media,current],[Reference,original]]:
        pair[1].budget_bytes=budget;pair[0].adopt_required(pair[1],1);pair[0].adopt_source_sizes(pair[1],plan.source_sizes,1)
        pair[0].adopt_encounter(pair[1],plan,1)
func settled(script:Script,data:Dictionary)->bool:
    var owner:Dictionary=script.physical(data)
    return not script._families_pending(owner) and owner.changed_paths.is_empty() and owner.selection_task<0 \
        and (owner.selection_publication.is_empty() or owner.selection_publication.cursor==owner.selection_publication.paths.size()) \
        and owner.selection_applied_revision==owner.selection_revision
func settle()->void:
    var deadline:int=Time.get_ticks_msec()+10000
    while Time.get_ticks_msec()<deadline:
        Media.prepare_optional(current);Reference.prepare_optional(original)
        if settled(Media,current) and settled(Reference,original):return
        await process_frame
    check(false,"Both complete physical owners finish their bounded metadata admission")
func observable(script:Script,data:Dictionary)->Dictionary:
    var owner:Dictionary=script.physical(data)
    var result:Dictionary={}
    for field in ["wanted","environment","fixtures","gpu_only","cpu_required","boot_paths","boot_waiting","boot_started","boot_complete"]:result[field]=data[field]
    for field in ["interests","wanted","pending","queued","required_estimated_bytes","optional_estimated_bytes","unknown_required","unknown_optional","cpu_release","due_paths","preload_selected","preload_estimated_bytes"]:result["physical:"+field]=owner[field]
    # Queue timestamps and selection-revision numbers were added/changed by
    # later scheduling instrumentation; source/role/order are the public work.
    result["physical:pending"]=owner.pending.map(func(job):var copy=job.duplicate();copy.erase("queued_us");return copy)
    var queued:Dictionary={}
    for path in owner.queued:
        var job:Dictionary=owner.queued[path].duplicate();job.erase("queued_us");queued[path]=job
    result["physical:queued"]=queued
    result.optional_paths=owner.encounter.paths
    for category in [false,true]:
        var stats:Dictionary=script.diagnostics(data,category)
        for field in ["demand_runs","demand_noops","demand_counts","demand_phases","metadata_ms","decode_ms","decode_worker_limit","selection_jobs"]:stats.erase(field)
        result[str(category)]=stats
    return result
func original_demand(data:Dictionary,records:Array,hint:Dictionary)->void:
    # The independent pre-change source accepted flat path/role maps. This is
    # only its public caller projection, not the optimized delta implementation.
    var paths:Dictionary={};var environment:Dictionary={};var fixtures:Dictionary={};var cpu:Dictionary={};var gpu:Dictionary={}
    for source in records:
        for path in source.roles:
            var role:Array=source.roles[path]
            paths[path]=role[0]
            if role[1]:cpu[path]=true
            if role[2]:fixtures[path]=true
            if role[3]:environment[path]=true
    for path in paths:
        if not cpu.has(path):gpu[path]=true
    Reference.demand(data,paths,environment,fixtures,gpu,cpu,hint)
func compare(label:String)->void:
    var actual:Dictionary=observable(Media,current)
    var expected:Dictionary=observable(Reference,original)
    if actual!=expected:
        for key in actual:
            if actual[key]!=expected.get(key):printerr("MEDIA_DEMAND_DIFF ",label," ",key,": ",actual[key]," != ",expected.get(key))
    check(actual==expected,label+": exact source pins/roles/order/estimates/readiness/boot/queue/failures")
func demand(label:String,paths:Dictionary,roles:Array=[{},{},{},{}])->void:
    var record:Dictionary=Media.source_record(paths,roles[0],roles[1],roles[2],roles[3])
    var records:Array=[] if paths.is_empty() else [record]
    Media.demand_records(current,records)
    # Flatten only this unchanged caller packet for the independent old owner.
    original_demand(original,records,{})
    await settle();compare(label)
func publish(path:String,gpu:int=8,fixture:bool=false)->void:
    var receipt:Dictionary={"path":path,"cpu_bytes":8,"gpu_bytes":gpu}
    if fixture:receipt.merge({"energy":.2,"emission_centroid":Vector2(2,3)})
    Media.published(current,receipt);Reference.published(original,receipt)
    await settle();compare("Actual source publication "+path)
func run()->void:
    var plan:Dictionary=family()
    var a:String="source/0";var b:String="source/1";var c:String="source/2"
    reset(plan)
    await source_replacement_control()
    await demand("Initial exact sources",{a:plan.paths[a],b:plan.paths[b]},[{},{},{a:true,b:true},{}])
    check(physical(current).pending.slice(0,2).map(func(job):return job.path)==[a,b],"Initial actual source order is authored FIFO")
    var retained:Array=physical(current).pending.map(func(job):return job.path)
    await demand("Fresh equal source contributions",{a:plan.paths[a],b:plan.paths[b]},[{},{},{a:true,b:true},{}])
    check(physical(current).pending.map(func(job):return job.path)==retained,"Equal immutable source values do not reorder retained work")
    Media.prioritize(current,{b:true});Reference.prioritize(original,{b:true})
    compare("Explicit current display cut")
    check(physical(current).pending[0].path==b,"Due-cut priority moves the selected source ahead of retained work")
    Media.prioritize(current,{});Reference.prioritize(original,{})
    await demand("Environment role promotion",{a:plan.paths[a],b:plan.paths[b]},[{a:true},{},{a:true,b:true},{}])
    check(physical(current).queued[a].required,"Required source remains strongly pinned during role changes")
    await demand("Exact fixture promotion",{a:plan.paths[a],b:plan.paths[b]},[{a:true},{a:true},{a:true,b:true},{}])
    check(physical(current).queued[a].fixture and not Media.ready(current,{a:true}),"New preprocessing role gates the exact source")
    await publish(a)
    check(not Media.ready(current,{a:true}),"Colour publication cannot satisfy missing fixture facts")
    await publish(a,8,true)
    check(Media.ready(current,{a:true}) and not physical(current).queued.has(a),"Actual fixture receipt cancels only its duplicate queued work")
    await publish(b)
    check(Media.ready(current,{a:true,b:true}),"Both required sources become ready from their exact receipts")
    var boot:Array=[Media.boot_ready(current),Reference.boot_ready(original)]
    check(boot==[true,true],"Startup completes from required receipts rather than optional family completion")
    await demand("Fixture role withdrawal",{a:plan.paths[a],b:plan.paths[b]},[{},{},{a:true,b:true},{}])
    for data in [current,original]:data.budget_bytes=0
    await demand("Pressure retains required GPU roles",{a:plan.paths[a],b:plan.paths[b]},[{},{},{a:true,b:true},{}])
    Media.release_cold_images(current,-1);Reference.release_cold_images(original,-1)
    compare("GPU-only CPU retirement")
    check(Media.ready(current,{a:true}) and current.resident[a].cpu_bytes==0,"GPU-only source stays ready after its CPU bytes retire")
    await demand("CPU role recovery",{a:plan.paths[a],b:plan.paths[b]},[{},{},{a:true,b:true},{a:true}])
    check(not Media.ready(current,{a:true}) and physical(current).pending[0].path==a,"CPU promotion queues the exact missing original before optional work")
    await publish(a)
    await publish(a,0)
    check(not Media.ready(current,{a:true}),"A receipt without a GPU allocation cannot fabricate render readiness")
    await publish(a)
    check(Media.ready(current,{a:true}),"Replacing the missing allocation restores only actual source readiness")
    var source_bytes:Dictionary={"outside":5}
    Media.adopt_source_sizes(current,source_bytes,1);Reference.adopt_source_sizes(original,source_bytes,1)
    await demand("Known required source outside optional family",{"outside":"/test/outside.png"},[{},{},{"outside":true},{}])
    check(physical(current).unknown_required==0 and physical(current).required_estimated_bytes==5,"Required metadata arrives before family discovery without granting bytes")
    for pair in [[Media,current],[Reference,original]]:pair[0].adopt_required(pair[1],2)
    check(current.source_sizes.is_empty() and original.source_sizes.is_empty(),"Initialization epoch releases prior metadata ownership")
    await demand("New initialization epoch",{c:plan.paths[c]},[{},{},{c:true},{}])
    check(current.boot_paths.keys()==[c] and not Media.boot_ready(current),"Fresh epoch owns its own unpublished startup gate")
    var unknown:Dictionary=family();unknown.source_sizes.erase(a)
    reset(unknown)
    await demand("Unknown required byte estimate",{a:unknown.paths[a]},[{},{},{a:true},{}])
    check(physical(current).unknown_required==1 and physical(current).preload_selected.keys()==[a],"Unknown required bytes cannot authorize optional budget spending")
    await publish(a)
    check(physical(current).unknown_required==0 and physical(current).required_estimated_bytes==8 and Media.ready(current,{a:true}),"Actual receipt resolves the unknown estimate without inventing readiness")
    await budget_matrix()
    await failure_controls()
    Media.close(current);Reference.close(original)
    print("MEDIA_DEMAND ",JSON.stringify({"checks":checks,"failures":failures,"budget_limits":8,"required_sets":7,
        "scope":"Complete independent frozen physical source owner; exact role/publication/readiness/queue/epoch/failure contracts and 112 budget transitions. No obsolete flat-owner counters or native pixel claim."}))
    quit(0 if failures.is_empty() else 1)
func budget_matrix()->void:
    var amounts:Array=[0,5,7,32,1,16,4,9]
    var source:Dictionary=family(amounts)
    for limit in [0,1,7,17,31,48,64,96]:
        for ids in [[],[0],[3],[0,2],[1,4,7],[3,5,6],[0,1,2,3,4,5,6,7]]:
            reset(source,limit)
            var paths:Dictionary={};var gpu:Dictionary={};var required:Dictionary={}
            for i in ids:
                var path:String="source/"+str(i);paths[path]=source.paths[path];gpu[path]=true;required[path]=amounts[i]
            await demand("Independent greedy budget %d/%s"%[limit,str(ids)],paths,[{},{},gpu,{}])
            var expected:Dictionary=greedy(source,required,limit)
            check(physical(current).preload_selected==expected,"Exact independent authored greedy selection %d/%s"%[limit,str(ids)])
            check(paths.keys().all(func(path):return physical(current).wanted.has(path)),"Required paths remain admitted even above zero/capped optional budget")
            for pair in [[Media,current],[Reference,original]]:pair[0].adopt_source_sizes(pair[1],{"outside-index":5},1)
            await demand("Changed required source outside index %d/%s"%[limit,str(ids)],{"source/7":source.paths["source/7"],"outside-index":"/test/outside-index.png"},[{},{},{"source/7":true,"outside-index":true},{}])
            expected=greedy(source,{"source/7":9,"outside-index":5},limit)
            check(physical(current).preload_selected==expected,"Exact independent changed-demand greedy selection %d/%s"%[limit,str(ids)])
func greedy(source:Dictionary,required:Dictionary,budget:int)->Dictionary:
    # Independent direct policy, no production selector/summary/index call.
    var used:int=0
    for size in required.values():used+=int(size)
    var selected:Dictionary={}
    for path in source.paths:
        var size:int=int(source.source_sizes[path])
        if required.has(path):selected[path]=source.paths[path]
        elif used+size<=budget:selected[path]=source.paths[path];used+=size
    return selected
func failure_controls()->void:
    var missing:String="res://tests/no-such-demand-fixture.png"
    var plan:Dictionary={"paths":{missing:missing},"source_sizes":{missing:8},"gpu_only":{missing:true}}
    reset(plan,8)
    await demand("Missing original source",{missing:missing},[{},{},{missing:true},{}])
    for pair in [[Media,current],[Reference,original]]:
        var deadline:int=Time.get_ticks_msec()+10000
        while not pair[1].failed.has(missing) and Time.get_ticks_msec()<deadline:
            pair[0].poll(pair[1]);await process_frame
    await demand("Actual missing-source failure persists",{missing:missing},[{},{},{missing:true},{}])
    check(current.failed.has(missing) and not Media.ready(current,{missing:true}) and not physical(current).queued.has(missing),"Actual worker failure is explicit, unavailable and never endlessly requeued")
    var message:String=current.failed.get(missing,"")
    await demand("Failure withdrawal",{})
    await demand("Failure re-admission",{missing:missing},[{},{},{missing:true},{}])
    check(current.failed.get(missing)==message and not Media.ready(current,{missing:true}) and not physical(current).queued.has(missing),"Readmitting the same failed source cannot grant readiness or launch duplicate work")

func source_replacement_control()->void:
    # Same-owner mutable927 path relocation is retired: admitted physical
    # source/index values are immutable. A real replacement owns a fresh
    # physical source revision and cannot mutate holders of the old one.
    var path:String="same-source"
    var old:Dictionary=Media.create();var fresh:Dictionary=Media.create()
    Media.adopt_required(old,1);Media.adopt_required(fresh,1)
    Media.demand_records(old,[Media.source_record({path:"/original/source.png"})])
    Media.demand_records(fresh,[Media.source_record({path:"/replacement/source.png"})])
    check(not is_same(Media.physical(old),Media.physical(fresh)),"Explicit source replacement owns a fresh physical admission")
    check(Media.physical(old).queued[path].absolute=="/original/source.png" and Media.physical(fresh).queued[path].absolute=="/replacement/source.png","Actual queued absolute paths retain exact independent revision ownership")
    check(not Media.ready(old,{path:true}) and not Media.ready(fresh,{path:true}),"A source replacement cannot inherit unpublished readiness")
    Media.close(fresh)
    check(Media.physical(old).queued[path].absolute=="/original/source.png","Retiring the new source owner never rewrites the original holder")
    Media.close(old)
