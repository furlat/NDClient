extends SceneTree
# CPU-only publication/readiness workload over authentic authored source paths.
# No PNG pixels or GPU textures are allocated by this timing diagnostic.
const Media = preload("res://presentation/media_warmup.gd")
const Encounter = preload("res://presentation/encounter_media.gd")
const EnvironmentMedia = preload("res://presentation/environment_media.gd")
const Protocol = preload("res://sdk/protocol.gd")

func _initialize() -> void:
    var state: Dictionary = Protocol.parse_json(FileAccess.get_file_as_bytes("res://.runtime/player-runs/20261011T223103.996259Z/state.json")).value
    var cache = {}
    var environment = EnvironmentMedia.plan(state,[],cache)
    var encounter = Encounter.plan(state,environment.required,environment.fixtures,cache).duplicate()
    encounter.estimates = Encounter.estimates(encounter.paths,encounter.cpu_required,encounter.gpu_only,cache)
    var data = Media.create()
    Media.adopt_encounter(data,encounter,1)
    Media.demand(data,{})
    # Queue dispatch/decode timing is outside this diagnostic. Model only the
    # successful scene publication stream and repeated loading-screen queries.
    data.pending.clear(); data.queued.clear()
    var samples: Array = []
    var total = 0.0
    for path in encounter.paths:
        var estimate: Dictionary = encounter.estimates[path]
        var started = Time.get_ticks_usec()
        Media.published(data,{"path":path,"cpu_bytes":estimate.cpu_bytes,"gpu_bytes":estimate.gpu_bytes,"energy":0.0,"emission_centroid":Vector2.ZERO})
        Media.release_cold_images(data,-1) # Offline bulk-accounting probe, no live frame.
        for i in range(3): Media.boot_ready(data)
        Media.preload_progress(data)
        Media.diagnostics(data); Media.diagnostics(data,true)
        var elapsed = (Time.get_ticks_usec()-started)/1000.0
        total += elapsed
        samples.append(elapsed)
    samples.sort()
    var report = {"sources":encounter.paths.size(),"samples":samples.size(),"total_cpu_ms":total,
        "median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*.95)],"max_ms":samples.back(),
        "ready":Media.boot_ready(data),"progress":Media.preload_progress(data),
        "scope":"CPU publication bookkeeping plus3boot queries/progress/both diagnostics per authentic source. Modeled successful uploads; no texture allocation/decode/driver timing."}
    var label: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "current"
    FileAccess.open("res://generated/media_readiness_cpu_"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report)); Media.close(data); quit()
