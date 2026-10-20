extends SceneTree
## Original schema16 Gallery groups exercise the physical source-owner route.
## Passive publication receipts qualify source readiness/accounting, not pixels.
const Media=preload("res://presentation/media_warmup.gd")
const Reference=preload("res://tests/oracles/media_before_source_delta.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const RecordingMedia=preload("res://studio/recording_media.gd")
var checks:int=0
var failures:Array=[]
var current:Dictionary={}
var original:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("MEDIA_RECORDING_DEMAND_FAIL ",label)
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
func run()->void:
    var index:Dictionary=Fixtures.read("gallery","amber")
    check(index.ok,"Durable original schema16 Gallery journal admits")
    if not index.ok:quit(1);return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups])
    var plan:Dictionary=RecordingMedia.plan(index)
    check(plan.errors.is_empty(),"Actual recording source closure resolves")
    if not plan.errors.is_empty():quit(1);return
    current=Media.create();original=Reference.create()
    var bytes:int=0
    for estimate in plan.estimates.values():bytes+=int(estimate.bytes)
    for pair in [[Media,current],[Reference,original]]:
        pair[1].budget_bytes=maxi(bytes*2,Media.BUDGET_BYTES)
        pair[0].adopt_required(pair[1],1);pair[0].adopt_encounter(pair[1],plan,1)
        pair[0].demand(pair[1],{})
    await settle()
    for pair in [[Media,current],[Reference,original]]:
        for path in plan.paths:
            var estimate:Dictionary=plan.estimates[path]
            pair[0].published(pair[1],{"path":path,"cpu_bytes":estimate.cpu_bytes,"gpu_bytes":estimate.gpu_bytes,
                "energy":1.0,"emission_centroid":Vector2.ZERO})
    await settle()
    compare("All exact original source receipts admitted")
    var decodes:Array=[Media.physical(current).decoded,Reference.physical(original).decoded]
    var samples:Array=[[],[]]
    var group_count:int=0;var cut_count:int=0
    for repeat in 4:
        for index_at in index.groups.size():
            var group:Dictionary=index.groups[index_at].group
            var first:Dictionary=plan.group_plans[group.id]
            var next:Dictionary=plan.group_plans[index.groups[index_at+1].group.id] if index_at+1<index.groups.size() else {}
            var records:Array=[]
            for record in first.source_records.reference+next.get("source_records",{}).get("reference",[]):
                if not records.any(func(prior):return is_same(prior,record)):records.append(record)
            var required:Dictionary={}
            for record in records:
                for path in record.roles:required[path]=true
            for variant in ([0,1] if (index_at+repeat)%2==0 else [1,0]):
                var began:int=Time.get_ticks_usec()
                if variant==0:Media.demand_records(current,records)
                else:original_demand(original,records,{})
                samples[variant].append((Time.get_ticks_usec()-began)/1000.0)
            await settle()
            if repeat==0:
                group_count+=1;compare("Actual Gallery group "+str(index_at))
                check(Media.ready(current,required) and Reference.ready(original,required),"Prepared original current/next source roles need no new receipt at actual group "+str(index_at))
                for cut_ms in [0.0]+first.source_cuts.reference.changes.map(func(change):return float(change.at_ms)):
                    cut_count+=1
                    var due:Array=Media.records_at(first.source_cuts.reference,float(cut_ms))
                    var due_paths:Dictionary={}
                    for record in due:
                        for path in record.roles:due_paths[path]=true
                    Media.prioritize(current,due_paths);Reference.prioritize(original,due_paths)
                    check(Media.ready(current,due_paths) and Reference.ready(original,due_paths),"Each actual source-publication cut is ready from the original admitted bytes")
                compare("Actual Gallery source cuts "+str(index_at))
    check(group_count==index.groups.size() and cut_count>=group_count,"Every original Gallery group and its source publication cuts are exercised")
    check([Media.physical(current).decoded,Reference.physical(original).decoded]==decodes,"Changing actual event demand never decodes an already admitted physical source")
    check(current.resident.size()==plan.paths.size() and original.resident.size()==plan.paths.size(),"Actual recording roles share their original admitted source residency")
    check(var_to_bytes([index.initialization,index.groups])==immutable,"Recording and ordered event groups remain byte-identical")
    var result:Dictionary={"checks":checks,"failures":failures,"groups":group_count,"source_cuts":cut_count,
        "sources":plan.paths.size(),"current_demand":summary(samples[0]),"reference_demand":summary(samples[1]),
        "scope":"Original Gallery current/next immutable source contributions, physical roles/readiness/accounting/publication cuts and complete frozen-owner comparison. CPU demand timings only, no native allocation/FPS claim."}
    Media.close(current);Reference.close(original)
    FileAccess.open("res://.runtime/media-recording-demand-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("MEDIA_RECORDING_DEMAND ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func summary(values:Array)->Dictionary:
    if values.is_empty():return {"count":0}
    var ordered:Array=values.duplicate();ordered.sort()
    return {"count":ordered.size(),"median_ms":ordered[ordered.size()/2],"p95_ms":ordered[mini(ordered.size()-1,int(ceil(ordered.size()*.95))-1)],"max_ms":ordered.back()}
