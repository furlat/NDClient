extends SceneTree
const Media = preload("res://presentation/media_warmup.gd")
const EnvironmentMedia = preload("res://presentation/environment_media.gd")
const Protocol = preload("res://sdk/protocol.gd")
const Catalog = preload("res://source_catalog.gd")
var checks = 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("MEDIA_ROLE_RACE_FAIL ",label)

func _initialize() -> void: run.call_deferred()

func loaded(data: Dictionary) -> Dictionary:
    var deadline = Time.get_ticks_msec()+10000
    while Time.get_ticks_msec()<deadline:
        var result = Media.poll(data)
        if not result.is_empty(): return result
        await process_frame
    return {}

func run() -> void:
    var parsed = Protocol.parse_json(FileAccess.get_file_as_bytes("res://.runtime/player-runs/20261011T223103.996259Z/state.json"))
    check(parsed.ok,"Actual disclosed fixture source state parses")
    if not parsed.ok: quit(1); return
    var environment = EnvironmentMedia.plan(parsed.value,[],{})
    var path: String = environment.fixtures.keys()[0]
    var data = Media.create()
    Media.demand(data,{path:Catalog.media_path(path)},{path:true})
    check(Media.poll(data).is_empty() and data.task>=0 and data.inflight==path,"Original source decode is dispatched with the colour-only role")
    # The worker now owns its immutable request; even a fast completed worker
    # cannot retroactively acquire the role below before its result is polled.
    Media.demand(data,{path:Catalog.media_path(path)},{path:true},{path:true})
    check(data.pending.is_empty() and data.queued.has(path),"Promotion retains the existing in-flight source request")
    var first = await loaded(data)
    check(first.has("image") and not first.has("energy") and not first.has("emission_centroid"),"First real worker result retains its original role")
    if not first.has("image"): Media.close(data); quit(1); return
    Media.published(data,first)
    check(not Media.ready(data,{path:true}) and data.pending.size()==1 and data.pending[0].fixture,
        "Unsatisfied publication immediately queues exactly the required fixture preprocessing")
    check(Media.diagnostics(data,true).pending==1,"Replacement work is accounted once")
    # No further demand() call: a stable accepted scene plan must recover.
    var second = await loaded(data)
    check(second.has("image") and second.has("energy") and second.has("emission_centroid"),"Existing worker completes the upgraded role without a new scene plan")
    if second.has("image"):
        Media.published(data,second)
        check(second.image.get_data()==first.image.get_data(),"Role preprocessing preserves original source pixels")
        check(Media.ready(data,{path:true}) and data.pending.is_empty() and data.queued.is_empty(),"Newest mandatory role becomes ready with no repeat loop")
        check(data.decoded==2 and Media.diagnostics(data,true).pending==0 and Media.diagnostics(data,true).resident_sheets==1,
            "Two worker requests retain one original source residency and truthful queue accounting")
    Media.close(data)
    var report = {"checks":checks,"failures":failures,"source":path,"scope":"Actual worker dispatch→role promotion→publication race using original authored fixture PNG; no GPU allocation required."}
    FileAccess.open("res://generated/media_role_race_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
