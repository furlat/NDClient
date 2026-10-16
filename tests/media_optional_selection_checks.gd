extends SceneTree
## Complete immutable families own the optional decision. Their bounded physical
## accounting cursor must not repeatedly invalidate that same decision.
const Media=preload("res://presentation/media_warmup.gd")
const Bodies=preload("res://presentation/body_sources.gd")
const Catalog=preload("res://source_catalog.gd")
var checks:int=0
var failures:Array=[]
var baseline:Script
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("OPTIONAL_SELECTION_FAIL ",label)

func family()->Dictionary:
    var cache:Dictionary={};var index=Bodies.index(cache)
    var paths:Dictionary={};var sizes:Dictionary={};var gpu:Dictionary={}
    for path in index.source_owners:
        var header:Dictionary=Bodies.header(path,cache)
        if not header.has("width") or not header.has("height"):continue
        paths[path]=Catalog.media_path(path);sizes[path]=int(header.width)*int(header.height)*4;gpu[path]=true
        if paths.size()==1024:break
    var order:Array=paths.keys()
    for value in [paths,sizes,gpu,order]:value.make_read_only()
    var result={"paths":paths,"ordered_paths":order,"source_sizes":sizes,"gpu_only":gpu};result.make_read_only()
    return result

func create_owner(script:Script,source:Dictionary)->Dictionary:
    var data:Dictionary=script.create()
    var first:String=source.ordered_paths[0]
    data.budget_bytes=int(source.source_sizes[first])*8
    script.adopt_required(data,1);script.adopt_source_sizes(data,source.source_sizes,1);script.adopt_encounter(data,source,1)
    script.demand(data,{first:source.paths[first]},{},{},{first:true})
    return data

func observed(script:Script,data:Dictionary)->Dictionary:
    var owner:Dictionary=script.physical(data)
    var pending:Array=[]
    for request in owner.pending:pending.append([request.path,request.absolute,request.required,request.fixture])
    return {"selected":owner.preload_selected,"selected_bytes":owner.preload_estimated_bytes,"optional_paths":owner.encounter.paths,
        "interests":owner.interests,"required":owner.wanted,"required_bytes":owner.required_estimated_bytes,
        "optional_bytes":owner.optional_estimated_bytes,"unknown_required":owner.unknown_required,"unknown_optional":owner.unknown_optional,
        "pending":pending,"ready":data.ready_paths,"boot_waiting":data.boot_waiting,"failed":owner.failed}

func settled(owner:Dictionary)->bool:
    return not Media._families_pending(owner) and owner.changed_paths.is_empty() and owner.selection_task<0 \
        and (owner.selection_publication.is_empty() or owner.selection_publication.cursor==owner.selection_publication.paths.size()) \
        and owner.selection_applied_revision==owner.selection_revision

func required_accounting(source:Dictionary)->void:
    var first:String=source.ordered_paths[0]
    var cpu:Dictionary={"paths":{first:source.paths[first]},"source_sizes":{first:source.source_sizes[first]},"cpu_required":{first:true}}
    var data:Dictionary=Media.create();data.budget_bytes=int(source.source_sizes[first])*4
    Media.adopt_required(data,1);Media.adopt_source_sizes(data,source.source_sizes,1)
    Media.demand(data,{first:source.paths[first]},{},{},{first:true})
    var owner:Dictionary=Media.physical(data)
    var before:int=owner.selection_revision
    Media._family_interest(owner,cpu,1)
    check(owner.selection_revision==before+1,"Actual new family membership invalidates the decision once")
    before=owner.selection_revision
    Media._step_families(owner,1)
    check(owner.selection_revision==before+1 and owner.required_estimated_bytes==int(source.source_sizes[first])*2,
        "Family CPU promotion of a required path preserves the genuine required-byte invalidation")
    before=owner.selection_revision;Media._family_interest(owner,cpu,-1);Media._step_families(owner,1)
    check(owner.selection_revision==before+2 and owner.required_estimated_bytes==int(source.source_sizes[first]),
        "Family withdrawal plus required CPU-byte contraction both retain their real invalidation")
    before=owner.selection_revision
    Media.adopt_source_sizes(data,{first:int(source.source_sizes[first])*2},1)
    check(owner.selection_revision==before+1,"Changed actual required source size invalidates the budget decision")
    Media.close(data)

func run()->void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--oracle="):baseline=load(argument.trim_prefix("--oracle="))
    var source:Dictionary=family()
    check(source.paths.size()==1024,"Actual admitted native headers supply the 1024-source family without loading artwork")
    var data:Dictionary=create_owner(Media,source);var owner:Dictionary=Media.physical(data)
    var old:Dictionary={} if baseline==null else create_owner(baseline,source)
    var old_owner:Dictionary={} if baseline==null else baseline.physical(old)
    var revision_after_membership:int=owner.selection_revision
    var trace:Array=[];var completed:bool=false
    for frame in 400:
        Media.prepare_optional(data)
        if baseline!=null:baseline.prepare_optional(old)
        trace.append({"frame":frame,"jobs":owner.selection_jobs,"revision":owner.selection_revision,
            "accounted":owner.encounter.paths.size(),"selected":owner.preload_selected.size(),
            "before_jobs":old_owner.get("selection_jobs",0)})
        if settled(owner) and (baseline==null or settled(old_owner)):completed=true;break
        await process_frame
    check(completed,"Both physical owners settle their complete selected-budget/accounting state")
    check(owner.selection_revision==revision_after_membership,"Optional-only family accounting never changes the complete-family decision revision")
    check(owner.selection_jobs<=2,"Complete immutable family requires at most one current worker decision plus one real input refresh")
    var expected:Dictionary={};var required:Dictionary={}
    for path in owner.wanted:required[path]={"bytes":owner.interests[path][5]}
    Media._select_optional([source],required,owner.budget_bytes,{},owner.selection_revision,expected)
    check(owner.preload_selected==expected.selected and owner.preload_estimated_bytes==expected.bytes,
        "Final selected order and byte total equal the complete original budget algorithm")
    if baseline!=null:
        check(observed(Media,data)==observed(baseline,old),"Frozen-before and current physical owners preserve exact selections, roles, pending order, estimates and boot gates")
        check(old_owner.selection_jobs>owner.selection_jobs+10,"Counted original reproduces repeated invalidated workers during unchanged-family bookkeeping")
    var jobs_before:int=owner.selection_jobs
    var selection:Dictionary=owner.preload_selected.duplicate()
    for frame in 32:
        await process_frame;Media.prepare_optional(data)
    check(owner.selection_jobs==jobs_before and settled(owner) and owner.preload_selected==selection,
        "32 true idle frames launch no new selector work and retain the exact selected source set")
    var peer:Dictionary=Media.create();Media.share(peer,data);Media.adopt_required(peer,1)
    Media.adopt_encounter(peer,source,1)
    var before:int=owner.selection_revision
    Media.demand(peer,{})
    check(owner.selection_revision==before,"A second consumer of the same active physical family does not create another selection input")
    Media.close(peer)
    check(owner.selection_revision==before,"One shared consumer retiring preserves the other family's selected decision")
    required_accounting(source)
    var report={"checks":checks,"failures":failures,"source_count":source.paths.size(),"jobs":owner.selection_jobs,
        "before_jobs":old_owner.get("selection_jobs",0),"revision":owner.selection_revision,"frames":trace.size(),"trace":trace,
        "scope":"Actual Media physical owner, admitted source paths/header sizes and constrained optional budget; exact frozen selection/role/queue/boot parity, required-byte invalidation and steady-state worker counts. No PNG decode/GPU/live FPS claim."}
    Media.close(data)
    if baseline!=null:baseline.close(old)
    FileAccess.open("res://generated/media_optional_selection_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    var summary:Dictionary=report.duplicate();summary.erase("trace")
    print("MEDIA_OPTIONAL_SELECTION ",JSON.stringify(summary));quit(0 if failures.is_empty() else 1)
