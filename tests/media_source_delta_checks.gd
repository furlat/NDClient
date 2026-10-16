extends SceneTree
## Changed contribution publication against the frozen pre-change source owner.
## Optional readiness is compared through its public query, not a stale hint cache.
const Media=preload("res://presentation/media_warmup.gd")
var baseline:Script
var checks:int=0
var failures:Array=[]
var times:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("MEDIA_SOURCE_DELTA_FAIL ",label)
func _initialize()->void:run.call_deferred()
func entry(id:String,path:String,cpu:bool=false,fixture:bool=false,environment:bool=false)->Dictionary:
    var raw:Dictionary=Media.source_record({path:"/unused/"+path},{path:true} if environment else {},{path:true} if fixture else {},{} if cpu else {path:true},{path:true} if cpu else {})
    var result:Dictionary={"source_id":id,"roles":raw.roles};result.make_read_only();return result
func observable(script:Script,data:Dictionary)->Dictionary:
    var owner:Dictionary=script.physical(data)
    var result:Dictionary={}
    for field in ["wanted","environment","fixtures","gpu_only","cpu_required","boot_paths","boot_waiting","boot_started"]:result[field]=data[field]
    for field in ["interests","wanted","pending","queued","required_estimated_bytes","optional_estimated_bytes","unknown_required","unknown_optional","selection_revision","cpu_release","due_paths"]:result["physical:"+field]=owner[field]
    result.optional_paths=owner.encounter.paths
    for category in [false,true]:
        var stats:Dictionary=script.diagnostics(data,category)
        for field in ["demand_runs","demand_noops","demand_counts","demand_phases","metadata_ms","decode_ms"]:stats.erase(field)
        result[str(category)]=stats
    return result
func compare(a:Dictionary,b:Dictionary,paths:Dictionary,label:String)->void:
    check(observable(Media,a)==observable(baseline,b),label+" exact required/optional pins, queue, role counts, estimates, budget and startup gates")
    for path in paths:
        check(Media.ready(a,{path:true})==baseline.ready(b,{path:true}),label+" exact current readiness "+path)
        if a.wanted.has(path) or a.boot_paths.has(path):check(a.ready_paths.has(path)==b.ready_paths.has(path),label+" eager required/startup cache "+path)
func demand(a:Dictionary,b:Dictionary,records:Array,hint:Dictionary,paths:Dictionary,label:String)->void:
    var began:int=Time.get_ticks_usec();Media.demand_records(a,records,hint);var current_ms:float=(Time.get_ticks_usec()-began)/1000.0
    began=Time.get_ticks_usec();baseline.demand_records(b,records,hint);var prior_ms:float=(Time.get_ticks_usec()-began)/1000.0
    compare(a,b,paths,label)
    times.append({"case":label,"current_ms":current_ms,"previous_ms":prior_ms,"current_phases":a.demand_phases.duplicate(),"previous_phases":b.demand_phases.duplicate()})
func run()->void:
    var oracle_path:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--oracle="):oracle_path=argument.trim_prefix("--oracle=")
    if oracle_path.is_empty():printerr("Requires --oracle=<frozen pre-change media owner>");quit(2);return
    baseline=load(oracle_path)
    var a:Dictionary=Media.create();var b:Dictionary=baseline.create()
    Media.adopt_required(a,1);baseline.adopt_required(b,1)
    var paths:Dictionary={};var records:Array=[]
    for i in 242:
        var path:String="required/%d"%i;paths[path]=true;records.append(entry("record/%d"%i,path))
    records.make_read_only()
    var hinted:Dictionary={};var hinted_gpu:Dictionary={}
    for i in 4000:
        var path:String="hint/%d"%i;hinted[path]="/unused/"+path;hinted_gpu[path]=true
        for script_data in [[Media,a],[baseline,b]]:script_data[0].published(script_data[1],{"path":path,"gpu_bytes":64,"cpu_bytes":0})
    var gpu_hint:Dictionary={"paths":hinted,"gpu_only":hinted_gpu}
    paths["hint/0"]=true;paths["hint/3999"]=true
    demand(a,b,records,gpu_hint,paths,"Initial exact242 and4000 optional hints")
    var extended:Array=records.duplicate()
    for i in 27:extended.append(entry("overlap/%d"%i,"required/%d"%i))
    extended.make_read_only()
    demand(a,b,extended,{},paths,"Complete handoff adds27 contributions with unchanged physical roles and withdraws4000 hints")
    check(a.demand_counts.affected==0,"Overlapping contributions update leases without re-publishing unchanged roles")
    var consumer:Dictionary=Media.physical(a).consumers[a.consumer_id]
    check(consumer.record_roles["required/0"][0]==2,"Unchanged Boolean contract still retains both contribution counts")
    demand(a,b,records,gpu_hint,paths,"Retire redundant contributions and restore exact optional GPU contract")
    var cpu_hint:Dictionary={"paths":hinted,"cpu_required":hinted}
    demand(a,b,records,cpu_hint,paths,"Optional CPU promotion is immediately queried from current descriptor")
    check(not Media.ready(a,{"hint/0":true}),"Cached positive optional GPU readiness cannot survive CPU promotion")
    var fixture_hint:Dictionary={"paths":hinted,"fixtures":{"hint/0":true},"gpu_only":hinted_gpu}
    demand(a,b,records,fixture_hint,paths,"Fixture hint with the same path owner still changes its exact query gate")
    for script_data in [[Media,a],[baseline,b]]:script_data[0].published(script_data[1],{"path":"hint/0","gpu_bytes":64,"cpu_bytes":64,"energy":1.0,"emission_centroid":Vector2.ZERO})
    compare(a,b,paths,"Actual CPU/fixture source publication")
    demand(a,b,records,{},paths,"Hint withdrawal uses actual retained residency contract")
    var unkeyed:Dictionary=Media.source_record({"partition":"/unused/partition"},{},{},{"partition":true})
    var unkeyed_sources:Array=records.duplicate();unkeyed_sources.append(unkeyed)
    var union:Array=[];var previous_union:Array=[];var seen:Dictionary={};var previous_seen:Dictionary={}
    for selected in [records,unkeyed_sources,records,unkeyed_sources]:
        Media.append_source_records(union,seen,selected)
        baseline.append_source_records(previous_union,previous_seen,selected)
    check(union==previous_union and union.size()==records.size()+1,"Keyed/unkeyed union keeps exact first-seen membership and order")
    check(seen[null].size()==1 and is_same(seen[null][0],unkeyed),"Unkeyed union compares only its own identity class")
    demand(a,b,unkeyed_sources,{},paths,"Unkeyed authored partition joins keyed retained sources")
    demand(a,b,unkeyed_sources.duplicate(),{},paths,"New array shell keeps the exact unkeyed partition ref")
    demand(a,b,records,{},paths,"Unkeyed partition retires without touching retained keyed roles")
    var upgrade:Array=records.duplicate();upgrade.append(entry("cpu upgrade","required/0",true,true))
    demand(a,b,upgrade,{},paths,"Exact required fixture promotion remains eager")
    check(not a.ready_paths.has("required/0"),"Required fixture gate updates its eager ready map")
    demand(a,b,records,{},paths,"Only last fixture owner releases exact extra roles")
    for script_data in [[Media,a],[baseline,b]]:script_data[0].close(script_data[1])
    var report={"checks":checks,"failures":failures,"timing":times,"scope":"Frozen source-owner parity;242retained refs,27overlapping leases,4000optional hints, current role queries, actual publication, unkeyed partitions and exact required promotion. Isolated timings, no live frame claim."}
    FileAccess.open("res://.runtime/media-source-delta-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("MEDIA_SOURCE_DELTA ",JSON.stringify({"checks":checks,"failures":failures,"timing":times}));quit(0 if failures.is_empty() else 1)
