extends SceneTree
# Real PNG -> background texture -> explicit publication; pixels and readiness
# must be identical to the original image through cancellation and limits.
const Media=preload("res://presentation/media_warmup.gd")
var failures:Array=[]
var checks=0
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr(label)
func _initialize()->void:run.call_deferred()
func next(data:Dictionary)->Dictionary:
    var deadline:int=Time.get_ticks_msec()+15000
    while Time.get_ticks_msec()<deadline:
        var result:Dictionary=Media.poll(data)
        if not result.is_empty():return result
        await process_frame
    return {}
func run()->void:
    var device=RenderingServer.get_rendering_device()
    if device==null:printerr("Native RenderingDevice required");quit(2);return
    var part:Resource=load("res://authoring/characters/parts/Melee2.tres")
    var normal:String="res://assets/"+part.actions.Attack1.surface.normals.reference
    var source:Image=Image.load_from_file(normal)
    check(source!=null,"Actual spike normal sheet loads")
    if source==null:quit(1);return
    var data=Media.create();var owner:Dictionary=Media.physical(data)
    owner.worker_upload=true
    owner.maximum_texture_size=device.limit_get(RenderingDevice.LIMIT_MAX_TEXTURE_SIZE_2D)
    Media.demand(data,{normal:normal})
    var loaded:Dictionary=await next(data)
    check(loaded.has("texture") and not loaded.has("error"),"Native prepared sheet has a completed texture")
    check(loaded.get("complete",false) and loaded.get("worker_clock_us",{}).has("upload_finished"),"Physical owner completes the actual worker upload before handing off its immutable result")
    check(not Media.ready(data,{normal:true}),"Prepared GPU resource cannot publish readiness early")
    if loaded.has("texture"):
        var pixels:Image=loaded.texture.get_image()
        pixels.convert(source.get_format())
        check(pixels.get_size()==source.get_size() and pixels.get_data()==source.get_data(),"GPU normal texture exactly preserves original dimensions and bytes")
        check(loaded.image.get_data()==source.get_data(),"CPU picking image remains unchanged")
        Media.published(data,loaded)
        check(Media.ready(data,{normal:true}),"Only explicit publication makes the source ready")
        check(owner.resident.has(normal) and is_same(data.resident,owner.resident),"The consumer borrows its physical residency directory after publication")
    Media.close(data)
    var rejected=Media.create();var rejected_owner:Dictionary=Media.physical(rejected)
    rejected_owner.worker_upload=true;rejected_owner.maximum_texture_size=1
    Media.demand(rejected,{normal:normal})
    var oversized:Dictionary=await next(rejected)
    check(oversized.has("error") and not oversized.has("texture"),"Oversized sheet fails before GPU allocation")
    check(rejected_owner.failed.has(normal) and not Media.ready(rejected,{normal:true}),"Oversized sheet cannot satisfy readiness")
    check(rejected_owner.resident.is_empty() and rejected_owner.textures.is_empty(),"Rejected dimension limit never publishes physical residency or GPU texture ownership")
    Media.close(rejected)
    var stale=Media.create();Media.physical(stale).worker_upload=true
    Media.demand(stale,{normal:normal});Media.poll(stale,false,false)
    Media.demand(stale,{})
    while not stale.decode_jobs.all(func(job):return WorkerThreadPool.is_task_completed(job.task)):await process_frame
    check(Media.poll(stale).is_empty() and Media.physical(stale).resident.is_empty() \
        and Media.physical(stale).textures.is_empty() and stale.ready_paths.is_empty(),"Superseded worker result never publishes a stale texture or consumer readiness")
    Media.close(stale)
    var closing=Media.create();Media.physical(closing).worker_upload=true
    Media.demand(closing,{normal:normal});Media.poll(closing,false,false);Media.close(closing)
    check(closing.decode_jobs.is_empty() and closing.resident.is_empty(),"Closing joins workers without publishing private resources")
    var f=FileAccess.open("res://.runtime/media-texture-native-checks.json",FileAccess.WRITE)
    f.store_string(JSON.stringify({"checks":checks,"failures":failures,"worker_upload_ms":loaded.get("worker_upload_ms",0)},"  "));f.close()
    print("MEDIA_TEXTURE_NATIVE ",checks," checks; failures ",failures)
    quit(0 if failures.is_empty() else 1)
