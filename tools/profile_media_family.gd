extends SceneTree
# CPU source-family growth using original Crypt paths/header estimates. This
# does not measure scene/GPU work or claim a full gameplay frame improvement.
const Media = preload("res://presentation/media_warmup.gd")
const Encounter = preload("res://presentation/encounter_media.gd")
const EnvironmentMedia = preload("res://presentation/environment_media.gd")
const Protocol = preload("res://sdk/protocol.gd")

func _initialize() -> void:
    var state: Dictionary = Protocol.parse_json(FileAccess.get_file_as_bytes("res://.runtime/player-runs/20261011T223103.996259Z/state.json")).value
    var cache = {}
    var environment = EnvironmentMedia.plan(state,[],cache)
    var full = Encounter.plan(state,environment.required,environment.fixtures,cache).duplicate()
    full.estimates = Encounter.estimates(full.paths,full.cpu_required,full.gpu_only,cache)
    var additions: Array = environment.required.keys().slice(-16)
    var base = full.duplicate()
    for field in ["paths","environment","cpu_required","gpu_only","fixtures","estimates"]:
        base[field] = full[field].duplicate()
        for path in additions: base[field].erase(path)
    base.estimate_summary = Encounter.estimate_summary(base)
    var data = Media.create()
    Media.adopt_encounter(data,base,1)
    Media.demand(data,{})
    for path in base.paths:
        var estimate: Dictionary = base.estimates[path]
        Media.published(data,{"path":path,"cpu_bytes":estimate.cpu_bytes,"gpu_bytes":estimate.gpu_bytes,"energy":0.0,"emission_centroid":Vector2.ZERO})
    data.pending.clear(); data.queued.clear(); data.stats.clear()
    Media.boot_ready(data); Media.diagnostics(data)
    var samples: Array = []
    var correct = true
    for path in additions:
        var plan = base.duplicate()
        for field in ["paths","environment","cpu_required","gpu_only","fixtures","estimates"]:
            plan[field] = base[field].duplicate()
            if full[field].has(path): plan[field][path] = full[field][path]
        plan.revision = int(base.revision)+1
        plan.estimate_summary = Encounter.estimate_summary(plan)
        var started = Time.get_ticks_usec()
        Media.adopt_encounter(data,plan,1)
        Media.demand(data,{})
        Media.preload_progress(data); Media.diagnostics(data); Media.diagnostics(data,true)
        samples.append((Time.get_ticks_usec()-started)/1000.0)
        correct = correct and data.preload_selected==plan.paths and data.pending.size()==1 and data.pending[0].path==path
        # Publication counters represent a successful upload; no real textures
        # are allocated here. Dispatch/worker timing is deliberately excluded.
        data.pending.clear(); data.queued.clear(); data.stats.clear()
        var estimate: Dictionary = plan.estimates[path]
        Media.published(data,{"path":path,"cpu_bytes":estimate.cpu_bytes,"gpu_bytes":estimate.gpu_bytes,"energy":0.0,"emission_centroid":Vector2.ZERO})
        base = plan
    samples.sort()
    var report = {"samples":samples.size(),"sources":full.paths.size(),"selection_refreshed":data.selection_refreshed,"median_ms":samples[samples.size()/2],
        "p95_ms":samples[int(samples.size()*.95)],"max_ms":samples.back(),"correct_membership_and_only_new_source_queued":correct,
        "scope":"CPU-only metadata growth over authentic Crypt original paths and modeled published residency; no native frame or GPU allocation claim."}
    var label: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "current"
    FileAccess.open("res://generated/media_family_cpu_"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report)); Media.close(data); quit(0 if correct else 1)
