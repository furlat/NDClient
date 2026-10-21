extends RefCounted
## Godot 4.7's particle compiler is shared by loaded ShaderMaterials and
## generated ParticleProcessMaterials. Keep those two admission paths apart.
## Existing instances continue sampling; this owns no presentation clock.
static var loading_path:String=""
static var loading_owner:Dictionary={}
static var loading_revision:int=0
static var settling:bool=false
static var mutation_frame:int=-1
static var loads_started:int=0
static var _material_job:Dictionary={}
static var _prepared_material_owners:Dictionary={}
static var material_profile:Dictionary={}
static var _source_job:Dictionary={}

static func _drawn()->void:
    settling=false

static func _settle_resources()->void:
    # The headless dummy server has no draw submission to flush and does not
    # emit this fence. Resource/clock tests still join the real loading job;
    # native rendering keeps its ordinary post-draw compiler fence.
    settling=DisplayServer.get_name()!="headless"
    if settling:RenderingServer.frame_post_draw.connect(_drawn,CONNECT_ONE_SHOT)

static func _poll()->void:
    if _poll_source():return
    if not _material_job.is_empty():
        if not WorkerThreadPool.is_task_completed(_material_job.task):return
        WorkerThreadPool.wait_for_task_completion(_material_job.task)
        if _material_job.owner.get("native_source_revision",0)==_material_job.revision:
            _material_job.owner.native_material_programs[_material_job.packet]=true
        _prepared_material_owners[_material_job.packet.get_instance_id()]=weakref(_material_job.packet)
        material_profile={"materials":_material_job.materials.size(),"worker_ms":_material_job.elapsed_ms}
        _material_job={}
        _settle_resources()
    if loading_path.is_empty():return
    var status:int=ResourceLoader.load_threaded_get_status(loading_path)
    if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS:return
    if status==ResourceLoader.THREAD_LOAD_LOADED:
        var resource:Resource=ResourceLoader.load_threaded_get(loading_path)
        if loading_owner.get("native_source_revision",0)==loading_revision:loading_owner[loading_path]=resource
    elif loading_owner.get("native_source_revision",0)==loading_revision:
        if not loading_owner.has("native_load_errors"):loading_owner.native_load_errors={}
        loading_owner.native_load_errors[loading_path]="Native resource preparation failed: "+loading_path
    loading_path="";loading_owner={}
    # A loaded scene may leave generated particle materials on Godot's dirty
    # list. Let its normal draw flush complete before construction/adaptation.
    _settle_resources()

static func can_mutate()->bool:
    _poll()
    return loading_path.is_empty() and _material_job.is_empty() and _source_job.is_empty() and not settling

static func begin_mutation()->bool:
    _cancel_optional_source()
    if not can_mutate():return false
    mutation_frame=Engine.get_process_frames()
    return true

static func prepare(paths:Array,cache:Dictionary,fresh:bool=false,urgent:bool=true)->Dictionary:
    if urgent and not paths.is_empty():_prioritize_source(cache)
    _poll()
    var pending:int=0;var errors:Array=[]
    for path in paths:
        if cache.has(path):continue
        if cache.get("native_load_errors",{}).has(path):
            errors.append(cache.native_load_errors[path]);continue
        pending+=1
        if not loading_path.is_empty() or not _material_job.is_empty() or not _source_job.is_empty() or settling or mutation_frame==Engine.get_process_frames():continue
        var error:Error=ResourceLoader.load_threaded_request(path,"",false,ResourceLoader.CACHE_MODE_IGNORE_DEEP if fresh else ResourceLoader.CACHE_MODE_REUSE)
        if error!=OK:
            errors.append("Native resource preparation failed: "+str(path));continue
        loading_path=path;loading_owner=cache;loading_revision=int(cache.get("native_source_revision",0));loads_started+=1
        # A globally cached resource may still be loading for another owner.
        # Join only our requested token after its actual LOADED publication.
        _poll()
        if cache.has(path):pending-=1
        elif cache.get("native_load_errors",{}).has(path):
            pending-=1;errors.append(cache.native_load_errors[path])
    return {"ready":pending==0 and errors.is_empty(),"pending":pending,"errors":errors,
        "loading":loading_path,"settling":settling}

static func prepare_materials(packet:Resource,materials:Array[Material],cache:Dictionary,urgent:bool=true)->bool:
    if urgent:_prioritize_source(cache)
    _poll()
    if not cache.has("native_material_programs"):cache.native_material_programs={}
    if cache.native_material_programs.has(packet):return true
    var prior:WeakRef=_prepared_material_owners.get(packet.get_instance_id())
    if prior!=null and is_same(prior.get_ref(),packet):
        cache.native_material_programs[packet]=true
        return true
    if materials.is_empty():
        cache.native_material_programs[packet]=true
        return true
    if not can_mutate() or mutation_frame==Engine.get_process_frames():return false
    for identity in _prepared_material_owners.keys():
        if _prepared_material_owners[identity].get_ref()==null:_prepared_material_owners.erase(identity)
    # The one source admission owner excludes any concurrent native load,
    # constructor or program rewrite until this worker and its draw fence end.
    # Only retained prototype Material RIDs are initialized; no Node, instance
    # parameters, animation or source clock is touched on the worker.
    _material_job={"packet":packet,"materials":materials,"owner":cache,"revision":cache.get("native_source_revision",0),"elapsed_ms":0.0,"task":-1}
    _material_job.task=WorkerThreadPool.add_task(_prepare_material_programs.bind(_material_job),false,"Native prototype programs")
    return false

static func _prepare_material_programs(job:Dictionary)->void:
    var started:int=Time.get_ticks_usec()
    for material in job.materials:material.get_rid()
    job.elapsed_ms=(Time.get_ticks_usec()-started)/1000.0


## One actual source-readiness job belongs to this existing admission owner.
## Ordinary queries never advance its normal work; only its owner polls it.
static func step_owned_source(cache:Dictionary,urgent:bool=true)->Dictionary:
    _poll()
    if _source_job.is_empty() or not is_same(_source_job.owner,cache) or _source_job.draining:
        return {"stepped":false}
    return step_source(_source_job.preparation,_source_job.job,cache,urgent)


static func step_source(preparation: Script, job: Dictionary, cache: Dictionary, urgent: bool = true) -> Dictionary:
    _poll()
    if urgent and not _source_job.is_empty() and not is_same(_source_job.job, job):
        _cancel_optional_source()
    if not _source_job.is_empty():
        if not is_same(_source_job.job, job) or not is_same(_source_job.owner, cache) or _source_job.preparation != preparation:
            return {"state": "blocked", "stepped": false}
        if _source_job.draining:
            return {"state": "draining", "stepped": false}
        _source_job.urgent = _source_job.urgent or urgent
        if _source_job.has("legacy_path"):
            return _step_legacy_source(preparation, job, cache, _source_job.urgent)
    else:
        if job.complete or not job.error.is_empty():
            return {"state": "ready" if job.complete else "error", "stepped": false}
        if not preparation.has_method("drain"):
            # Preserve the default preparation implementation. Its existing RD
            # jobs enqueue finite render-thread callbacks, not a bank Thread.
            # Their unit/fence must finish before a new worker can claim admission.
            if not can_mutate() or mutation_frame == Engine.get_process_frames():
                return {"state": "blocked", "stepped": false}
            mutation_frame = Engine.get_process_frames()
            return _step_legacy_source(preparation, job, cache, urgent)
        if not can_mutate() or mutation_frame == Engine.get_process_frames():
            return {"state": "blocked", "stepped": false}
        _source_job = {"preparation": preparation, "job": job, "owner": cache,
            "revision": cache.get("native_source_revision", 0), "draining": false, "urgent": urgent}
    var progress: Dictionary = preparation.step(job)
    progress.stepped = true
    if not job.error.is_empty():
        _source_job.draining = true
        _poll_source()
    elif job.complete:
        _finish_source()
    return progress


static func _step_legacy_source(preparation: Script, job: Dictionary, cache: Dictionary, urgent: bool) -> Dictionary:
    var path := ""
    if job.has("pending") and int(job.at) < job.pending.size():
        path = str(job.pending[job.at].path)
    _source_job = {"preparation": preparation, "job": job, "owner": cache,
        "revision": cache.get("native_source_revision", 0), "draining": false, "legacy_path": path, "urgent": urgent}
    var progress: Dictionary = preparation.step(job)
    progress.stepped = true
    var requests: Variant = preparation.get("requests")
    if path.is_empty() or not requests is Dictionary or not requests.has(path):
        _finish_source()
    elif not job.error.is_empty():
        _source_job.draining = true
        _poll_source()
    return progress


static func cancel_source(job: Dictionary) -> void:
    if _source_job.is_empty() or not is_same(_source_job.job, job):
        return
    if job.error.is_empty():
        job.error = "Immutable preparation cancelled"
    # A later genuine request can restart discovery after this exact cancelled
    # unit drains. Real preparation errors remain ordinary reported job errors.
    var jobs: Dictionary = _source_job.owner.get("native_immutable_jobs", {})
    for identity in jobs.keys():
        if is_same(jobs[identity], job):jobs.erase(identity)
    _source_job.draining = true
    _poll_source()


## Required source preparation is already a demand even if all immutable
## paths/materials are cached: its caller still waits on construction admission.
## Keep the same owner's current unit; only displace a different optional owner.
static func _prioritize_source(cache: Dictionary) -> void:
    if _source_job.is_empty() or _source_job.draining or _source_job.urgent:return
    if is_same(_source_job.owner, cache):_source_job.urgent = true
    else:cancel_source(_source_job.job)


## A real construction/resource demand may displace optional discovery whose
## owner is skipped by the existing due-world priority. Queries never do so.
static func _cancel_optional_source() -> void:
    if not _source_job.is_empty() and not _source_job.urgent:
        cancel_source(_source_job.job)


static func cancel_source_cache(cache: Dictionary) -> void:
    if not _source_job.is_empty() and is_same(_source_job.owner, cache):
        cancel_source(_source_job.job)


static func _drain_source_after_draw() -> void:
    _poll_source()


static func _finish_source() -> void:
    _source_job = {}
    if RenderingServer.frame_post_draw.is_connected(_drain_source_after_draw):
        RenderingServer.frame_post_draw.disconnect(_drain_source_after_draw)
    _settle_resources()


static func _poll_source() -> bool:
    if _source_job.is_empty():
        return false
    var job: Dictionary = _source_job.job
    if _source_job.owner.get("native_source_revision", 0) != _source_job.revision:
        if job.error.is_empty():
            job.error = "Immutable preparation owner revision changed"
        _source_job.draining = true
    if not job.error.is_empty():
        _source_job.draining = true
    if _source_job.draining:
        # The consumer may have closed. Reuse this admission owner's existing
        # draw signal for drain-only polling; normal work is never advanced here.
        if DisplayServer.get_name() != "headless" and not RenderingServer.frame_post_draw.is_connected(_drain_source_after_draw):
            RenderingServer.frame_post_draw.connect(_drain_source_after_draw, CONNECT_DEFERRED)
        # A cancelled/error job is retained until its already-started load or
        # worker has been collected. This never starts a later resource unit.
        var progress: Dictionary
        if _source_job.has("legacy_path"):
            var path: String = _source_job.legacy_path
            var requests: Dictionary = _source_job.preparation.get("requests")
            if requests.has(path):
                var status := ResourceLoader.load_threaded_get_status(path)
                if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
                    progress = {"complete": false}
                elif status == ResourceLoader.THREAD_LOAD_LOADED:
                    var resources: Dictionary = _source_job.preparation.get("resources")
                    resources[path] = ResourceLoader.load_threaded_get(path)
                if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
                    requests.erase(path)
            if progress.is_empty():
                progress = {"complete": true}
        else:
            progress = _source_job.preparation.drain(job)
        _source_job.drain_error = str(progress.get("error", ""))
        if progress.get("complete", false):
            _finish_source()
    return true
