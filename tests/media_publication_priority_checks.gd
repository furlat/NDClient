extends SceneTree
## A ready displayed outfit leaves future decoded images to the optional lane.
const Player=preload("res://play.gd")
const Media=preload("res://presentation/media_warmup.gd")
var checks:int=0
var failures:Array=[]

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("MEDIA_PUBLICATION_PRIORITY_FAIL ",label)

func completed(path:String)->Dictionary:
    var original=Image.create(2,2,false,Image.FORMAT_RGBA8)
    original.fill(Color.CORAL)
    return {"task":-1,"joined":true,"path":path,"paths":[path],
        "result":{"path":path,"image":original,"cpu_bytes":16,"gpu_bytes":16,"complete":true}}

func run()->void:
    var host=Player.new()
    host.media_metadata_ready=true
    host.media_plan={"required":{"current":true},"errors":[]}
    host.media_environment_required={"floor":true}
    var data:Dictionary=host.media_warmup
    data.wanted={"current":"current","floor":"floor","future":"future"}
    data.ready_paths={"current":true,"floor":true}
    data.queued={"future":true};data.decode_jobs=[completed("future")]
    var budget:Dictionary=host._preparation_budget()
    host._warm_media(true,budget)
    check(not host.textures.has("future") and data.decode_jobs.size()==1,
        "Ready displayed sources do not publish a future decoded image in the urgent lane")
    check(budget.used_usec==0 and data.wanted.has("future") and data.queued.has("future"),
        "Deferring publication preserves the full future owner and leaves world preparation its allowance")
    host._warm_media(false,budget)
    check(host.textures.has("future") and host.source_images.future.get_pixel(0,0).is_equal_approx(Color.CORAL),
        "Optional lane publishes the unchanged original image")
    check(data.ready_paths.has("future") and data.decode_jobs.is_empty() and not data.queued.has("future"),
        "Optional publication completes the same exact residency and queue contract")
    # A missing current source must still get urgent publication; neither this
    # scheduling decision nor a prior optional result grants its readiness.
    data.ready_paths.erase("current")
    data.queued.current=true;data.decode_jobs=[completed("current")]
    budget.used_usec=0;data.publication={}
    host._warm_media(true,budget)
    check(host.textures.has("current") and data.ready_paths.has("current"),
        "Missing displayed source is published before optional preparation")
    host.timeline.current={"id":"next-floor","duration_ms":100.0}
    host.media_group_plans={"next-floor":{"environment_timeline":{"initial":{"floor":true},
        "changes":[{"at_ms":10.0,"paths":{"floor":true,"new_floor":true}}]}}}
    data.wanted.new_floor="new_floor"
    data.queued.new_floor=true;data.decode_jobs=[completed("new_floor")]
    budget.used_usec=0;data.publication={}
    host._warm_media(true,budget,9.0)
    check(not data.ready_paths.has("new_floor") and data.decode_jobs.size()==1,
        "A later environment boundary retains its future image without urgent publication")
    host._warm_media(true,budget,10.0)
    check(data.ready_paths.has("new_floor") and host.textures.has("new_floor"),
        "Environment required by the proposed step publishes urgently even while current display is before that boundary")
    check(host.timeline.state.is_empty() and host.timeline.queue.is_empty() and host.timeline.display_ms==0.0,
        "Scheduling changes publish no canonical state, events or animation time")
    Media.close(data);host.context_menu.free();host.free()
    var report={"checks":checks,"failures":failures,"scope":"Original image publication, required readiness, future ownership and preparation allowance; headless, no live timing claim."}
    FileAccess.open("res://.runtime/media-publication-priority-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("MEDIA_PUBLICATION_PRIORITY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
