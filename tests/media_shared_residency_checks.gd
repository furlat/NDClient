extends SceneTree
## Source-owner boundary: real PNG workers/publication, private consumer gates,
## and aggregate budgets. Headless does not qualify native texture pixels.
const Media=preload("res://presentation/media_warmup.gd")
const Player=preload("res://play.gd")
var checks=0
var failures=[]
var deadline:int
var original:Image
var source_path="res://.runtime/shared-media-source.png"

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("MEDIA_SHARED_FAIL ",label)

func host(reference:Node3D=null)->Node3D:
    var value=Player.new()
    if reference!=null:Media.share(value.media_warmup,reference.media_warmup)
    value.attach_media_sources()
    return value

func dispose(value:Node3D)->void:
    Media.close(value.media_warmup);value.context_menu.free();value.free()

func prepared(hosts:Array,consumer:Dictionary,paths:Dictionary)->bool:
    while Time.get_ticks_msec()<deadline:
        for value in hosts:value._warm_media(false,{})
        if Media.ready(consumer,paths):return true
        await process_frame
    return false

func settle_selection(data:Dictionary)->void:
    var owner=Media.physical(data)
    while Time.get_ticks_msec()<deadline:
        Media.prepare_optional(data)
        if not Media.diagnostics(data).selection_pending:return
        await process_frame

func shared_source()->void:
    var a=host();var b=host(a)
    var path="shared";var paths={path:ProjectSettings.globalize_path(source_path)}
    for value in [a,b]:
        Media.adopt_required(value.media_warmup,1)
        Media.adopt_source_sizes(value.media_warmup,{path:64},1)
        Media.demand(value.media_warmup,paths,{},{},{path:true})
    var owner=Media.physical(a.media_warmup)
    check(await prepared([a,b],b.media_warmup,paths),"Two panes become ready from the same real PNG worker")
    check(Media.ready(a.media_warmup,paths) and Media.boot_ready(a.media_warmup) and Media.boot_ready(b.media_warmup),"Each pane independently admits its exact boot paths")
    check(Media.diagnostics(a.media_warmup).decoded==1 and a.textures.size()==1 and is_same(a.textures[path],b.textures[path]),"One decode and one texture serve both consumers")
    check(a.source_images[path].get_data()==original.get_data(),"Source publication preserves the original PNG bytes")
    if DisplayServer.get_name()!="headless":
        await RenderingServer.frame_post_draw
        check(a.textures[path].get_image().get_data()==original.get_data(),"Native uploaded source preserves exact original pixels")
    check(Media.diagnostics(a.media_warmup).combined_estimated_bytes==128 and Media.diagnostics(b.media_warmup).combined_estimated_bytes==128,"Both panes report one physical CPU/GPU allocation")
    var texture=a.textures[path]
    for released in Media.release_cold_images(a.media_warmup,-1):a.source_images.erase(released)
    check(a.source_images.is_empty() and b.source_images.is_empty() and Media.ready(a.media_warmup,paths),"GPU-only CPU retirement updates both aliases without losing GPU readiness")
    Media.demand(b.media_warmup,paths,{},{path:true})
    check(Media.ready(a.media_warmup,paths) and not Media.ready(b.media_warmup,paths),"Fixture promotion gates only the consumer requiring CPU pixels and emission metrics")
    check(await prepared([a,b],b.media_warmup,paths),"Shared original is recovered with fixture metrics")
    check(Media.diagnostics(a.media_warmup).decoded==2 and is_same(a.textures[path],texture) and b.fixture_frame_energy.has(path) and b.fixture_frame_centroids.has(path),"Role promotion retains its GPU allocation and publishes metrics once")
    check(Media.diagnostics(a.media_warmup,true).resident_sheets==0 and Media.diagnostics(a.media_warmup).resident_sheets==1,"A fixture role alone does not fabricate an environment category")
    Media.demand(a.media_warmup,{})
    check(Media.prune(a.media_warmup,0).is_empty() and Media.ready(b.media_warmup,paths),"One consumer cancelling cannot evict another consumer's required source")
    dispose(a)
    check(Media.ready(b.media_warmup,paths) and b.textures.has(path) and Media.diagnostics(b.media_warmup).consumers==1,"Closing a pane leaves the surviving pane's source and account intact")
    var next="pending";var both=paths.duplicate();both[next]=paths[path]
    var c=host(b)
    Media.demand(b.media_warmup,both,{},{path:true})
    Media.demand(c.media_warmup,{next:paths[path]})
    Media.poll(c.media_warmup,false,false)
    dispose(c)
    check(await prepared([b],b.media_warmup,both),"Closing a consumer during decode preserves another consumer's pending source")
    check(Media.diagnostics(b.media_warmup).decoded==3,"Shared cancellation causes no duplicate decode")
    var fresh=host()
    Media.physical(fresh.media_warmup).source_revision=owner.source_revision+1
    check(fresh.textures.is_empty() and not is_same(Media.physical(fresh.media_warmup),owner),"A new source revision starts with a separate physical owner")
    Media.demand(fresh.media_warmup,paths)
    check(await prepared([fresh],fresh.media_warmup,paths),"The new revision prepares independently")
    check(not is_same(fresh.textures[path],b.textures[path]) and is_same(b.textures[path],texture),"New-revision publication never changes an older pinned texture")
    dispose(fresh);dispose(b)

func cpu_cache_roles()->void:
    var a=host();var b=host(a)
    var path="cpu-cache";var paths={path:ProjectSettings.globalize_path(source_path)}
    for value in [a,b]:
        Media.adopt_required(value.media_warmup,1)
        Media.adopt_source_sizes(value.media_warmup,{path:64},1)
    Media.demand(a.media_warmup,paths,{},{},{},{path:true})
    Media.demand(b.media_warmup,paths,{},{},{path:true})
    check(await prepared([a,b],a.media_warmup,paths),"CPU and GPU consumers share one prepared original")
    var owner=Media.physical(a.media_warmup)
    var texture=a.textures[path]
    Media.demand(a.media_warmup,paths,{},{},{path:true})
    await process_frame
    check(Media.release_cold_images(a.media_warmup).is_empty() and a.source_images[path].get_data()==original.get_data(),"Withdrawing CPU interest preserves exact reusable pixels under budget")
    var stats=Media.diagnostics(a.media_warmup)
    check(stats.combined_estimated_bytes==128 and stats.pinned_bytes==64,"Cached CPU bytes remain counted but are not pinned by GPU-only consumers")
    Media.demand(a.media_warmup,paths,{},{},{},{path:true})
    check(Media.ready(a.media_warmup,paths) and owner.decoded==1 and owner.queued.is_empty(),"Reacquiring CPU interest is immediately ready without another decode")
    Media.demand(a.media_warmup,paths,{},{},{path:true})
    owner.budget_bytes=64
    await process_frame
    var released=Media.release_cold_images(b.media_warmup)
    for item in released:b.source_images.erase(item)
    check(released==[path] and a.source_images.is_empty() and is_same(a.textures[path],texture),"Budget pressure retires unpinned CPU pixels before the required GPU texture")
    check(Media.ready(a.media_warmup,paths) and Media.ready(b.media_warmup,paths) and Media.prune(a.media_warmup).is_empty(),"CPU pressure retirement preserves both GPU consumers and needs no whole-source eviction")
    Media.demand(a.media_warmup,paths,{},{},{},{path:true})
    check(not Media.ready(a.media_warmup,paths) and Media.ready(b.media_warmup,paths),"Only a CPU consumer waits when previously cached pixels were retired under pressure")
    check(await prepared([a,b],a.media_warmup,paths),"CPU pixels can be recovered after actual budget retirement")
    check(owner.decoded==2 and is_same(a.textures[path],texture),"Budget recovery decodes once without replacing the surviving GPU allocation")
    check(Media.release_cold_images(a.media_warmup).is_empty() and Media.diagnostics(a.media_warmup).pinned_over_budget_bytes==64,"Current CPU demand remains pinned even when required residency exceeds the optional budget")
    dispose(a);dispose(b)

func optional_and_budgets()->void:
    var a=Media.create();var b=Media.create();Media.share(b,a)
    var owner=Media.physical(a)
    var absolute=ProjectSettings.globalize_path(source_path)
    owner.budget_bytes=0;a.budget_bytes=0;b.budget_bytes=0
    Media.adopt_required(a,1)
    Media.adopt_source_sizes(a,{"required":64,"hint":64},1)
    var hint={"paths":{"hint":absolute},"gpu_only":{"hint":true},"source_sizes":{"hint":64}}
    Media.demand(a,{"required":absolute},{},{},{"required":true},{},hint)
    Media.published(a,{"path":"required","cpu_bytes":0,"gpu_bytes":64})
    check(Media.boot_ready(a) and Media.ready(a,{"required":true}) and not owner.wanted.has("hint"),"Preview hints cannot become required or hold boot readiness")
    await settle_selection(a)
    check(not owner.preload_selected.has("hint") and not owner.queued.has("hint"),"A zero optional budget rejects preview residency without blocking required media")
    check(Media.diagnostics(a).pinned_over_budget_bytes==64 and Media.prune(b,0).is_empty(),"Required bytes over budget remain pinned in the shared physical account")
    Media.demand(a,{})
    Media.demand(b,{})
    for i in 5:Media.published(a,{"path":"cold"+str(i),"cpu_bytes":64,"gpu_bytes":64})
    var removed=Media.prune(a,0)
    removed.append_array(Media.prune(b,0))
    check(removed.size()==Media.EVICTIONS_PER_FRAME,"Two consumers share one per-frame eviction allowance")
    await process_frame
    var next=Media.prune(b,0)
    check(next.size()==Media.EVICTIONS_PER_FRAME,"Remaining shared retirement progresses on the next frame")
    Media.close(a);Media.close(b)

func optional_consumers()->void:
    var a=Media.create();var b=Media.create();Media.share(b,a)
    var absolute=ProjectSettings.globalize_path(source_path)
    var family={"paths":{"optional":absolute},"source_sizes":{"optional":64},"gpu_only":{"optional":true}}
    Media.demand(a,{},{},{},{},{},family)
    Media.demand(b,{},{},{},{},{},family)
    var owner=Media.physical(a)
    await settle_selection(a)
    check(owner.preload_selected.size()==1 and owner.pending.size()==1 and Media.diagnostics(a).pending==1,"Shared optional interest selects and queues one original")
    Media.demand(a,{})
    check(owner.preload_selected.has("optional") and owner.queued.has("optional"),"Cancelling one preview preserves another preview's optional pin")
    Media.demand(b,{})
    await settle_selection(b)
    check(owner.preload_selected.is_empty() and owner.pending.is_empty() and Media.diagnostics(a).pending==0,"The last optional consumer cancels unpublished work and its accounting")
    var paths={"required":absolute}
    Media.demand(a,paths)
    Media.published(a,{"path":"required","cpu_bytes":64,"gpu_bytes":64})
    Media.demand(b,paths,paths)
    check(Media.diagnostics(a,true).resident_sheets==1 and Media.diagnostics(a).resident_sheets==0,"An environment consumer promotes the one shared resident category")
    Media.demand(b,{})
    check(Media.diagnostics(a,true).resident_sheets==0 and Media.diagnostics(a).resident_sheets==1 and Media.ready(a,paths),"Removing environment interest restores classification without withdrawing another pin")
    Media.close(a);Media.close(b)

func cancelled_optional_backlog()->void:
    var data=Media.create();var paths={};var sizes={};var gpu={}
    for i in 80:
        var path="cancelled"+str(i)
        paths[path]=ProjectSettings.globalize_path(source_path);sizes[path]=64;gpu[path]=true
    var family={"paths":paths,"source_sizes":sizes,"gpu_only":gpu}
    Media.demand(data,{},{},{},{},{},family)
    await settle_selection(data)
    var owner=Media.physical(data)
    check(owner.pending.size()==80 and owner.optional_updates<=Media.OPTIONAL_UPDATES_PER_FRAME,"Large optional admission advances through the shared bounded allowance")
    Media.demand(data,{})
    Media.poll(data,false,false)
    check(owner.decode_jobs.is_empty(),"Withdrawn optional intent starts no decode while its references retire")
    await settle_selection(data)
    check(owner.pending.is_empty() and owner.preload_selected.is_empty(),"Bounded cancellation retires the remaining optional queue and pins")
    Media.close(data)

func publication_budget()->void:
    var a=host();var b=host(a)
    var owner=Media.physical(a.media_warmup)
    var paths={}
    for i in 12:paths["publication"+str(i)]=ProjectSettings.globalize_path(source_path)
    Media.demand(a.media_warmup,paths)
    Media.demand(b.media_warmup,paths)
    # Completed private workers are ready for publication; the original image
    # is real, and publication still uses the ordinary host upload/account path.
    owner.pending.clear();owner.queued.clear()
    for path in paths:
        owner.queued[path]={"pending":false}
        owner.decode_jobs.append({"joined":true,"path":path,"paths":[path],"result":{"path":path,"image":original,"cpu_bytes":64,"gpu_bytes":64}})
    owner.stats.clear()
    a._warm_media(false,{})
    var first=owner.publication.count
    b._warm_media(false,{})
    check(first>0 and owner.publication.count<=Media.PUBLICATIONS_PER_FRAME,"Two panes share the per-frame publication limit")
    check(is_same(a._preparation_budget(),b._preparation_budget()),"World/native/source preparation uses the same allowance in both panes")
    check(owner.resident.size()==owner.publication.count,"Every published allocation is charged exactly once")
    dispose(a);dispose(b)

func due_priority()->void:
    var data=Media.create();var other=Media.create();Media.share(other,data)
    var absolute=ProjectSettings.globalize_path(source_path)
    var paths={"late-a":absolute,"onset-a":absolute,"late-b":absolute,"onset-b":absolute}
    Media.demand(data,paths)
    var owner=Media.physical(data)
    check(owner.pending.map(func(row):return row.path)==paths.keys(),"New equal-priority sources preserve authored FIFO order")
    Media.prioritize(data,{"onset-a":true,"onset-b":true})
    check(owner.pending.map(func(row):return row.path)==["onset-a","onset-b","late-a","late-b"],"Due sources dispatch before later received sources without reversing ties")
    Media.prioritize(other,{"onset-a":true});Media.prioritize(data,{"onset-b":true})
    check(owner.due_paths.has("onset-a") and owner.due_paths.has("onset-b"),"One consumer's cut change retains another consumer's due priority")
    Media.close(other)
    Media.prioritize(data,{"onset-a":true,"onset-b":true})
    Media.poll(data,true,false)
    check(owner.decode_jobs.slice(0,2).map(func(job):return job.path)==["onset-b","onset-a"],"Real PNG dispatch starts both onset sources before later sources")
    for job in owner.decode_jobs:WorkerThreadPool.wait_for_task_completion(job.task);job.joined=true
    Media.prioritize(data,{"late-b":true})
    var first:Dictionary=Media.poll(data,true)
    check(first.path=="late-b" and first.image.get_data()==original.get_data(),"A newly due completed source is harvested ahead of earlier later-cue jobs with original bytes")
    check(owner.wanted.size()==4 and not Media.ready(data,paths),"Priority preserves the full operation pins and cannot grant unpublished readiness")
    Media.close(data)
    data=Media.create();owner=Media.physical(data)
    var encounter={"paths":{},"gpu_only":{},"source_sizes":{}}
    for index in 40:
        var path="encounter"+str(index);encounter.paths[path]=absolute;encounter.gpu_only[path]=true;encounter.source_sizes[path]=64
    Media.adopt_encounter(data,encounter,1)
    var hints={"paths":{"hint-onset":absolute},"gpu_only":{"hint-onset":true},"source_sizes":{"hint-onset":64}}
    Media.demand(data,{},{},{},{},{},hints);Media.prioritize(data,{"hint-onset":true})
    Media.poll(data,true,false)
    check(owner.preload_selected.has("hint-onset") and owner.decode_jobs.size()==1 and owner.decode_jobs[0].path=="hint-onset" and owner.wanted.is_empty(),
        "Urgent hint accounting bypasses encounter backlog without converting optional interest into a required pin")
    for job in owner.decode_jobs:WorkerThreadPool.wait_for_task_completion(job.task);job.joined=true
    var hint:Dictionary=Media.poll(data,true)
    check(hint.get("path")=="hint-onset" and hint.image.get_data()==original.get_data(),"Required-only publication also harvests selected due optional sources")
    Media.close(data)

func run()->void:
    deadline=Time.get_ticks_msec()+20000
    original=Image.create(4,4,false,Image.FORMAT_RGBA8);original.fill(Color(0.8,0.25,0.1,0.5))
    original.set_pixel(1,2,Color.WHITE)
    check(original.save_png(source_path)==OK,"Controlled original source is saved")
    if "--priority-only" in OS.get_cmdline_user_args():
        due_priority()
        var report={"checks":checks,"failures":failures,"scope":"Focused exact due queue ordering, real PNG dispatch/harvest, shared priority cancellation and optional onset accounting; no gameplay latency claim."}
        FileAccess.open("res://.runtime/media-due-priority-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
        print("MEDIA_DUE_PRIORITY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1);return
    await shared_source()
    await cpu_cache_roles()
    await optional_and_budgets()
    await optional_consumers()
    await cancelled_optional_backlog()
    await publication_budget()
    var report={"checks":checks,"failures":failures,"native":DisplayServer.get_name()!="headless",
        "scope":"Physical source ownership, decode/publication bytes, independent required roles, cancellation, revision isolation and shared frame budgets; no gameplay latency claim."}
    FileAccess.open("res://.runtime/media-shared-residency-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("MEDIA_SHARED_RESIDENCY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
