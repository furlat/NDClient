extends SceneTree
const Catalog=preload("res://source_catalog.gd")
const Media=preload("res://presentation/media_warmup.gd")
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr(label)
func _initialize()->void:run.call_deferred()
func loaded(data:Dictionary)->Dictionary:
    var deadline:int=Time.get_ticks_msec()+10000
    while Time.get_ticks_msec()<deadline:
        var result:Dictionary=Media.poll(data)
        if not result.is_empty():return result
        await process_frame
    return {}
func held_batch(requests:Array,result:Dictionary,release:Semaphore)->void:
    for i in requests.size():
        if i==1:release.wait()
        var image:Dictionary={}
        Media._decode(requests[i],image)
        result.mutex.lock();result.images.append(image);result.mutex.unlock()

func streaming_batch(environment:Dictionary,cancel:bool=false)->void:
    var source:String=environment.required.keys()[0]
    var absolute:String=Catalog.media_path(source)
    var wanted:Dictionary={"stream-first":absolute,"stream-held":absolute}
    var data:Dictionary=Media.create()
    Media.demand(data,wanted,wanted)
    var requests:Array=data.pending.duplicate();data.pending.clear()
    var result:Dictionary={"images":[],"mutex":Mutex.new()}
    var release:Semaphore=Semaphore.new()
    var task:int=WorkerThreadPool.add_task(held_batch.bind(requests,result,release))
    data.decode_jobs.append({"task":task,"path":requests[0].path,"paths":wanted.keys(),"result":result})
    var deadline:int=Time.get_ticks_msec()+10000
    var available:bool=false
    while not available and Time.get_ticks_msec()<deadline:
        result.mutex.lock();available=not result.images.is_empty();result.mutex.unlock()
        if not available:await process_frame
    check(available and not WorkerThreadPool.is_task_completed(task),"Streaming batch has a real completed PNG while its second member remains held")
    check(Media.poll(data,true,false).is_empty() and not Media.ready(data,wanted),"Unfunded poll cannot consume a completed member or publish readiness")
    var first:Dictionary=Media.poll(data,true)
    check(first.get("path")=="stream-first" and first.has("image") and not WorkerThreadPool.is_task_completed(task),
        "Completed first member is returned without joining its unfinished batch")
    check(data.decode_jobs.size()==1 and data.decode_jobs[0].paths==["stream-held"] and data.queued.has("stream-held"),
        "Partly consumed batch retains its worker slot and exact remaining request")
    check(not Media.ready(data,{"stream-first":true}),"Stream handoff alone does not make decoded bytes render-ready")
    if first.has("image"):Media.published(data,first)
    check(Media.ready(data,{"stream-first":true}) and not Media.ready(data,{"stream-held":true}),
        "Caller publication admits only the complete member")
    check(Media.poll(data).is_empty() and data.decode_jobs.size()==1,"Empty in-flight mailbox neither blocks polling nor releases the worker slot")
    if cancel:Media.demand(data,{"stream-first":absolute},{"stream-first":absolute})
    release.post()
    if not cancel:
        var second:Dictionary=await loaded(data)
        check(second.get("path")=="stream-held" and second.has("image") and first.has("image") and second.image.get_data()==first.image.get_data(),
            "Later batch member preserves original bytes and publishes exactly once")
        if second.has("image"):Media.published(data,second)
    deadline=Time.get_ticks_msec()+10000
    while not data.decode_jobs.is_empty() and Time.get_ticks_msec()<deadline:
        check(Media.poll(data).is_empty(),"Retirement never exposes a cancelled or already consumed batch member")
        await process_frame
    var expected:Dictionary={"stream-first":absolute} if cancel else wanted
    check(data.decode_jobs.is_empty() and data.queued.is_empty() and Media.physical(data).decoded==2 and Media.ready(data,expected),
        "Completed empty batch is joined and released with exact readiness and accounting")
    if cancel:check(not data.resident.has("stream-held") and not Media.ready(data,{"stream-held":true}),"Cancelled held member never creates residency or readiness")
    Media.close(data)

func required_slot_priority(mode:String)->void:
    var image:Image=Image.create(3,3,false,Image.FORMAT_RGBA8);image.fill(Color(.2,.4,.6,1))
    var file:String="user://media-stream-priority-"+mode+".png"
    check(image.save_png(file)==OK,mode+" saves a real source PNG")
    var paths:Dictionary={};var estimates:Dictionary={}
    for index in Media.OPTIONAL_DECODE_WORKERS+3:
        var path:String=mode+"-optional-"+str(index)
        paths[path]=file;estimates[path]={"bytes":image.get_data_size()*2}
    var data:Dictionary=Media.create();var owner:Dictionary=Media.physical(data)
    Media.adopt_encounter(data,{"revision":1,"paths":paths,"estimates":estimates,"errors":[]},1)
    Media.demand(data,{})
    Media.prepare_optional(data)
    Media.poll_sources(data,true,false)
    var deadline:int=Time.get_ticks_msec()+10000
    while not owner.decode_jobs.all(func(job):return WorkerThreadPool.is_task_completed(job.task)) and Time.get_ticks_msec()<deadline:
        await process_frame
    check(owner.decode_jobs.size()==Media.OPTIONAL_DECODE_WORKERS and owner.pending.size()==3,
        mode+" owns four actual completed PNG jobs with additional optional sources pending")
    var decoded:int=owner.decoded
    check(Media.poll_sources(data,true).is_empty() and owner.decoded==decoded,
        mode+" required-only receipt preserves completed optional slots when no required work is waiting")
    if mode=="withdrawn":
        var withdrawn:String=owner.pending.back().path
        Media.prioritize(data,{withdrawn:true})
        Media.adopt_encounter(data,{"revision":2,"paths":{},"estimates":{},"errors":[]},1)
        Media.demand(data,{})
        check(owner.preload_selected.has(withdrawn) and owner.pending.front().path==withdrawn,
            "Withdrawn family leaves its real bounded accounting lease behind an urgent scheduling intent")
        check(Media.poll_sources(data,true).is_empty() and owner.decoded==decoded and not owner.queued.has(withdrawn)
            and owner.decode_jobs.size()==Media.OPTIONAL_DECODE_WORKERS,
            "Withdrawn optional intent cannot reclaim a completed worker slot or publish a cancelled source")
    else:
        var first:String=mode+"-required-first";var second:String=mode+"-required-second"
        var required_paths:Dictionary={first:file,second:file}
        for index in 6:required_paths[mode+"-required-later-"+str(index)]=file
        Media.demand(data,required_paths)
        Media.prioritize(data,{second:true})
        var expected:String=second
        if mode=="cancelled":
            required_paths.erase(second);Media.demand(data,required_paths);expected=first
            check(not owner.queued.has(second),"Cancelling the reprioritized source withdraws its actual pending request")
        check(Media.poll_sources(data,true,false).is_empty() and owner.decode_jobs.size()<=Media.DECODE_WORKERS
            and owner.decode_jobs[Media.OPTIONAL_DECODE_WORKERS].path==expected and owner.decoded==decoded
            and not Media.ready(data,{expected:true}),mode+" dispatches urgent work in required slots without reclaiming optional bytes or fabricating readiness")
        check(owner.decode_jobs.slice(0,Media.OPTIONAL_DECODE_WORKERS).all(func(job):return paths.has(job.path) and job.paths.size()==1),
            mode+" existing optional jobs keep their exact single-image ownership under the expanded required window")
        var private_paths:int=0
        for job in owner.decode_jobs:private_paths+=job.paths.size()
        check(owner.decode_jobs.size()==8 and private_paths<=16,
            mode+" mixed optional and required saturation still owns at most eight workers and sixteen private images")
        deadline=Time.get_ticks_msec()+10000
        while owner.decode_jobs.any(func(job):return expected in job.paths and not WorkerThreadPool.is_task_completed(job.task)) and Time.get_ticks_msec()<deadline:
            await process_frame
        var required:Dictionary=Media.poll_sources(data,true)
        check(required.get("path")==expected and required.has("image") and required.image.get_data()==image.get_data() and not Media.ready(data,{expected:true}),
            mode+" returns the required source ahead of completed optional work without early publication")
        if required.has("image"):Media.published(data,required)
        check(Media.ready(data,{expected:true}) and paths.keys().all(func(path):return not owner.resident.has(path)),
            mode+" only caller publication admits required readiness; optional bytes stay unpublished")
    Media.close(data)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(file))

func required_window()->void:
    var image:Image=Image.create(3,3,false,Image.FORMAT_RGBA8);image.fill(Color(.2,.4,.6,1))
    var file:String="user://media-required-window.png"
    check(image.save_png(file)==OK,"Required window saves actual source pixels")
    var paths:Dictionary={}
    for index in Media.DECODE_WORKERS*Media.DECODE_BATCH_IMAGES+4:paths["window-"+str(index)]=file
    var first:String=paths.keys()[0]
    var data:Dictionary=Media.create();var owner:Dictionary=Media.physical(data)
    Media.demand(data,paths,{first:true},{first:true})
    Media.poll_sources(data,true,false)
    check(owner.decode_jobs.size()==8 and owner.decode_jobs.all(func(job):return job.paths.size()==2)
        and owner.pending.size()==4,"Required sources dispatch eight finite two-image jobs while later requests stay pending")
    var deadline:int=Time.get_ticks_msec()+10000
    while not owner.decode_jobs.all(func(job):return WorkerThreadPool.is_task_completed(job.task)) and Time.get_ticks_msec()<deadline:await process_frame
    var images:int=0
    for job in owner.decode_jobs:images+=job.result.images.size()
    check(images==16 and owner.resident.is_empty() and not Media.ready(data,paths),
        "The saturated producer owns exactly sixteen original private images and publishes no readiness")
    var loaded:Dictionary=Media.poll_sources(data,true)
    check(loaded.get("path")==first and loaded.image.get_data()==image.get_data() and loaded.has("energy") and loaded.has("emission_centroid"),
        "The first required receipt preserves original pixels and real fixture optical facts")
    check(owner.decode_jobs.size()==8 and owner.pending.size()==4 and owner.decode_jobs[0].paths.size()==1,
        "Partial receipt preserves its unfinished two-image worker slot and cannot expand the private image window")
    Media.published(data,loaded)
    check(Media.ready(data,{first:true}) and not Media.ready(data,paths),"Actual fixture publication admits only that exact source")
    var second:Dictionary=Media.poll_sources(data,true)
    check(second.has("image") and second.image.get_data()==image.get_data() and owner.decode_jobs.size()==8 and owner.pending.size()==2,
        "Completing one finite slot refills with at most two required originals without exceeding eight workers")
    var owned:int=0
    for job in owner.decode_jobs:owned+=job.paths.size()
    check(owned==16,"Mixed completed and newly running jobs retain the same sixteen-image ownership bound")
    Media.close(data);DirAccess.remove_absolute(ProjectSettings.globalize_path(file))

func run()->void:
    var source:String="/media/environment/terrain/ground-d1-e.png"
    await streaming_batch({"required":{source:true}})
    await streaming_batch({"required":{source:true}},true)
    for mode in ["reprioritized","cancelled","withdrawn"]:await required_slot_priority(mode)
    await required_window()
    var report:Dictionary={"checks":checks,"failures":failures}
    FileAccess.open("res://generated/media_streaming_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
