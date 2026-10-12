extends SceneTree
# CPU-only demand scheduling measurement. Residency records model already
# uploaded original sources; this is not a GPU readiness or VRAM measurement.
const Media = preload("res://presentation/media_warmup.gd")
const Encounter = preload("res://presentation/encounter_media.gd")
const EnvironmentMedia = preload("res://presentation/environment_media.gd")
const Characters = preload("res://presentation/characters.gd")
const Protocol = preload("res://sdk/protocol.gd")
const Catalog = preload("res://source_catalog.gd")

func _initialize() -> void:
    var state: Dictionary = Protocol.parse_json(FileAccess.get_file_as_bytes("res://.runtime/player-runs/20261011T223103.996259Z/state.json")).value
    var cache = {}
    var environment = EnvironmentMedia.plan(state,[],cache)
    var encounter = Encounter.plan(state,environment.required,environment.fixtures,cache)
    encounter.estimates = Encounter.estimates(encounter.paths,encounter.cpu_required,encounter.gpu_only,cache)
    var data = Media.create()
    Media.adopt_encounter(data,encounter,1)
    Media.demand(data,{},environment.required,environment.fixtures)
    for path in encounter.paths:
        var estimate: Dictionary = encounter.estimates[path]
        Media.published(data,{"path":path,"cpu_bytes":estimate.cpu_bytes,"gpu_bytes":estimate.gpu_bytes,"energy":0.0,"emission_centroid":Vector2.ZERO})
    data.pending.clear(); data.queued.clear()
    Media.boot_ready(data)
    var packets: Array = []
    for clip in ["Idle","Attack1","Run","Rolling","TakeDamage"]:
        var paths = environment.required.duplicate()
        var gpu_only = {}; var cpu_required = {}
        for actor in state.actors.values():
            var result = Characters.sheet_paths(actor,[clip],cache)
            if not result.ok: print(result); quit(1); return
            paths.merge(result.value); gpu_only.merge(result.gpu_only); cpu_required.merge(result.cpu_required)
        var absolute = {}
        for path in paths: absolute[path] = Catalog.media_path(path)
        packets.append({"paths":absolute,"gpu_only":gpu_only,"cpu_required":cpu_required})
    var samples: Array = []
    for i in range(50):
        var packet: Dictionary = packets[i%packets.size()]
        var started = Time.get_ticks_usec()
        Media.demand(data,packet.paths,environment.required,environment.fixtures,packet.gpu_only,packet.cpu_required)
        Media.release_cold_images(data); Media.prune(data)
        Media.preload_progress(data); Media.diagnostics(data); Media.diagnostics(data,true)
        if i>=5: samples.append((Time.get_ticks_usec()-started)/1000.0)
    samples.sort()
    var report = {"sources":encounter.paths.size(),"selection_jobs":data.selection_jobs,"samples":samples.size(),
        "median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*.95)],"max_ms":samples.back(),
        "unexpected_decodes_queued":data.pending.size(),"scope":"CPU scheduling over real original Crypt paths/header accounting and a modeled fully-uploaded residency table. Includes demand, maintenance, and both diagnostic views; not native frame time or GPU allocation."}
    FileAccess.open("res://generated/encounter_demand_cpu.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report)); Media.close(data); quit(0 if data.selection_jobs==1 and data.pending.is_empty() else 1)
