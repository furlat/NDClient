extends SceneTree
# Real Gallery demand changes, compared with the original exhaustive contract.
# Passive exact publication receipts test readiness/accounting, not GPU pixels.
const Media=preload("res://presentation/media_warmup.gd")
const Reference=preload("res://tests/media_demand_reference.gd")
const Recording=preload("res://studio/recording.gd")
const RecordingMedia=preload("res://studio/recording_media.gd")
const Catalog=preload("res://source_catalog.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func observable(data:Dictionary)->Dictionary:
    var result:Dictionary={}
    for key in ["pending","queued","wanted","environment","fixtures","gpu_only","cpu_required","failed",
        "preload_selected","preload_skipped","preload_estimated_bytes","required_estimated_bytes","unknown_required",
        "boot_paths","boot_started","boot_complete","ready_paths","boot_waiting","selected_ready","selected_failed","cpu_release"]:
        result[key]=data[key]
    for category in [false,true]:
        var stats:Dictionary=Media.diagnostics(data,category)
        for key in ["demand_runs","demand_noops","demand_phases","demand_counts","metadata_ms","decode_ms"]:stats.erase(key)
        result[str(category)]=stats
    return result
func summary(values:Array)->Dictionary:
    var ordered:Array=values.duplicate();ordered.sort()
    return {"count":ordered.size(),"median_ms":ordered[ordered.size()/2],"p95_ms":ordered[mini(ordered.size()-1,int(ceil(ordered.size()*.95))-1)],"max_ms":ordered.back()}
func run()->void:
    var descriptor:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://generated/studio_gallery_spell_case.json"))
    var bundle:Dictionary=Recording.compare_case(Recording.read_case(descriptor))
    check(bundle.get("ok",false),"Actual Gallery recording admits")
    if not bundle.get("ok",false):quit(1);return
    var index:Dictionary=Recording.view_index(bundle,"amber")
    var original:PackedByteArray=var_to_bytes([index.initialization,index.groups])
    var plan:Dictionary=RecordingMedia.plan(index)
    check(plan.errors.is_empty(),"Exact recording source closure resolves")
    var groups:Array=index.groups.map(func(row):return row.group)
    var demands:Array=[]
    for at in groups.size():
        var first:Dictionary=plan.group_plans[groups[at].id]
        var next:Dictionary=plan.group_plans[groups[at+1].id] if at+1<groups.size() else {}
        var wanted:Dictionary=first.character.duplicate();wanted.merge(first.environment)
        var environment:Dictionary=first.environment.duplicate();var fixtures:Dictionary=first.fixtures.duplicate()
        var cpu:Dictionary=first.cpu_required.duplicate();var gpu:Dictionary=first.gpu_only.duplicate()
        for field in ["character","environment"]:wanted.merge(next.get(field,{}))
        environment.merge(next.get("environment",{}));fixtures.merge(next.get("fixtures",{}))
        cpu.merge(next.get("cpu_required",{}));gpu.merge(next.get("gpu_only",{}))
        for path in cpu:gpu.erase(path)
        for path in wanted:wanted[path]=Catalog.media_path(path)
        demands.append([wanted,environment,fixtures,gpu,cpu])
    var live:Dictionary=Media.create();var reference:Dictionary=Media.create()
    for data in [live,reference]:
        data.encounter_override=plan;Media.adopt_required(data,1);Media.demand(data,plan.priority)
        for path in plan.paths:
            var estimate:Dictionary=plan.estimates[path]
            Media.published(data,{"path":path,"cpu_bytes":estimate.cpu_bytes,"gpu_bytes":estimate.gpu_bytes,"energy":1.0,"emission_centroid":Vector2.ZERO})
        Media.demand(data,plan.priority);Media.release_cold_images(data,-1);Media.boot_ready(data)
    var initial_decodes:Array=[live.decoded,reference.decoded]
    var samples:Array=[[],[]];var refresh_samples:Array=[[],[]];var refreshed:Array=[0,0]
    for repeat in 4:
        for at in demands.size():
            var demand:Array=demands[at]
            # Alternate execution order to avoid always giving one version the
            # warmed CPU/cache state. Only demand itself is inside each timer.
            for variant in ([0,1] if (at+repeat)%2==0 else [1,0]):
                var data:Dictionary=live if variant==0 else reference
                var source:Script=Media if variant==0 else Reference
                data.demand_phases={}
                data.demand_counts={}
                var started:int=Time.get_ticks_usec()
                source.demand(data,demand[0],demand[1],demand[2],demand[3],demand[4])
                samples[variant].append((Time.get_ticks_usec()-started)/1000.0)
                if data.has("demand_phases") and data.demand_phases.has("resident_refresh"):
                    refresh_samples[variant].append(data.demand_phases.resident_refresh)
                    refreshed[variant]+=data.demand_counts.get("resident_refreshed",0)
                Media.release_cold_images(data,-1)
            if repeat==0:
                check(observable(live)==observable(reference),"Exact queue/readiness/pins/errors/accounting at actual group "+str(at))
                check(live.pending.is_empty() and Media.ready(live,demand[0]),"No new decode or readiness hold at actual group "+str(at))
    check([live.decoded,reference.decoded]==initial_decodes and live.resident.size()==plan.paths.size() and reference.resident.size()==plan.paths.size(),"All recording roles reuse the originally admitted images")
    check(var_to_bytes([index.initialization,index.groups])==original,"Canonical recording and compiled event groups remain untouched")
    var report:Dictionary={"checks":checks,"failures":failures,"groups":groups.size(),"sources":plan.paths.size(),
        "current_demand":summary(samples[0]),"reference_demand":summary(samples[1]),"refreshed":refreshed,
        "comparison":"Original exhaustive reference; timings are CPU demand only, not game frame times."}
    if not refresh_samples[0].is_empty():report.current_resident_refresh=summary(refresh_samples[0])
    if not refresh_samples[1].is_empty():report.reference_resident_refresh=summary(refresh_samples[1])
    Media.close(live);Media.close(reference)
    FileAccess.open("res://.runtime/media-recording-demand-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("MEDIA_RECORDING_DEMAND ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
