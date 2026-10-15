extends SceneTree
## Residency pressure mirrors the live Gallery scale. No textures are changed;
## this measures selection separately from native resource destruction.
const Media=preload("res://presentation/media_warmup.gd")
const Profile=preload("res://frame_profile.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func resident(count:int,pins:int)->Dictionary:
    var data=Media.create()
    for i in count:
        var path="pressure/source-%04d.png"%i
        var bytes:int=(4+(i%3))*1024*1024
        data.resident[path]={"bytes":bytes,"cpu_bytes":bytes/2,"gpu_bytes":bytes/2,"used":(i*1297)%count,"environment":false,"cpu_required":true}
        if i<pins:data.wanted[path]=path
    return data
func oldest(data:Dictionary,count:int)->Array:
    # Whole sorted oracle defines the existing LRU policy independently of the
    # bounded production selection. Unique timestamps remove arbitrary ties.
    var ordered:Array=[]
    for path in data.resident:
        if not data.wanted.has(path) and not data.preload_selected.has(path):ordered.append([int(data.resident[path].used),path])
    ordered.sort_custom(func(a,b):return a[0]<b[0])
    return ordered.slice(0,count).map(func(item):return item[1])

func cpu_release_checks()->void:
    var data=Media.create()
    var images:Dictionary={}
    var original_bytes:int=0
    for i in 5:
        var path="pressure/companion-%d.png"%i
        images[path]=Image.create(32+i,32,false,Image.FORMAT_RGBA8)
        var bytes:int=images[path].get_data().size()
        original_bytes+=bytes
        data.gpu_only[path]=true;data.wanted[path]=path
        Media.published(data,{"path":path,"cpu_bytes":bytes,"gpu_bytes":bytes})
    var initial=Media.diagnostics(data)
    var released=Media.release_cold_images(data)
    for path in released:images.erase(path)
    check(released.size()==2 and images.size()==3 and data.cpu_release.size()==3,
        "CPU retirement drains two actual Image owners and leaves the remaining queue intact")
    var remaining_bytes:int=0
    for image in images.values():remaining_bytes+=image.get_data().size()
    check(Media.diagnostics(data).cpu_bytes==remaining_bytes and data.cpu_released_bytes_this_frame==original_bytes-remaining_bytes,
        "Pending CPU images remain counted until their own release")
    check(Media.ready(data,data.wanted) and Media.diagnostics(data).gpu_estimated_bytes==initial.gpu_estimated_bytes,
        "Bounded CPU retirement never changes GPU residency or mandatory readiness")
    check(Media.release_cold_images(data).is_empty() and images.size()==3,
        "Repeated maintenance in the same native frame cannot drain another CPU batch")
    var retained:String=images.keys()[0]
    data.cpu_required[retained]=true
    var prior_frame:int=Engine.get_process_frames()
    while Engine.get_process_frames()==prior_frame:await process_frame
    released=Media.release_cold_images(data)
    for path in released:images.erase(path)
    check(released.size()==2 and images.keys()==[retained] and data.cpu_release.is_empty(),
        "Later CPU-role promotion cancels that queued release while other eligible images progress")
    check(Media.ready(data,data.wanted) and data.resident[retained].cpu_bytes==images[retained].get_data().size(),
        "Newly required picking/geometry image remains resident without a decode")
    check(Media.diagnostics(data).cpu_bytes==images[retained].get_data().size(),
        "Final residency accounting matches the one retained Image owner")
    data.cpu_required.clear();Media._refresh_resident_role(data,retained)
    check(Media.release_cold_images(data).is_empty(),"A second role change cannot bypass this frame's CPU release cap")
    prior_frame=Engine.get_process_frames()
    while Engine.get_process_frames()==prior_frame:await process_frame
    released=Media.release_cold_images(data)
    for path in released:images.erase(path)
    check(released==[retained] and images.is_empty() and Media.diagnostics(data).cpu_bytes==0,
        "The final no-longer-required image releases exactly once on the next frame")

func run()->void:
    var elapsed:Array=[]
    for repeat in 24:
        var data=resident(1996,471)
        var expected=oldest(data,2)
        var before=Media.diagnostics(data)
        var pinned:Dictionary=data.wanted.duplicate()
        var removed_bytes:int=0
        for path in expected:removed_bytes+=int(data.resident[path].bytes)
        var started=Time.get_ticks_usec()
        var actual=Media.prune(data,0)
        elapsed.append((Time.get_ticks_usec()-started)/1000.0)
        check(actual==expected,"Pressure selects the oldest two unpinned sheets "+str(repeat))
        check(pinned.keys().all(func(path):return data.resident.has(path)),"Pressure never evicts required sheet "+str(repeat))
        check(Media.prune(data,0).is_empty(),"Repeated same-frame maintenance cannot double native release allowance "+str(repeat))
        var after=Media.diagnostics(data)
        check(after.combined_estimated_bytes==before.combined_estimated_bytes-removed_bytes and after.evicted==2,"Pressure accounting matches exact removals "+str(repeat))
    var one=resident(19,4)
    var total:int=Media.diagnostics(one).combined_estimated_bytes
    check(Media.prune(one,total-1)==oldest(resident(19,4),1),"A one-byte deficit removes only the oldest eligible sheet")
    var pinned=resident(37,37)
    check(Media.prune(pinned,0).is_empty() and pinned.resident.size()==37,"Required residency over budget stays admitted")
    var optional=resident(23,2)
    optional.preload_selected[oldest(optional,1)[0]]=true
    var expected=oldest(optional,2)
    check(Media.prune(optional,0)==expected,"Selected optional preload sources remain pinned alongside current demand")
    var all_before=optional.resident.size()
    var prior_frame:int=Engine.get_process_frames()
    while Engine.get_process_frames()==prior_frame:await process_frame
    check(Media.prune(optional,0).size()==2 and optional.resident.size()==all_before-2,"Remaining pressure progresses on the next native frame")
    await cpu_release_checks()
    var report={"checks":checks,"failures":failures,"selection_ms":Profile.distribution(elapsed),"resident_sheets":1996,"required_pins":471,
        "cpu_images_per_frame":Media.CPU_RELEASES_PER_FRAME,
        "scope":"Selection/accounting under Gallery-size pressure plus bounded actual Image-owner retirement, current-role promotion and readiness. Timings cover selection only, not Image/ImageTexture destruction or GPU work."}
    FileAccess.open("res://.runtime/media-prune-pressure-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("MEDIA_PRUNE_PRESSURE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
