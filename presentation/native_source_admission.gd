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

static func _drawn()->void:
    settling=false

static func _settle_resources()->void:
    # The headless dummy server has no draw submission to flush and does not
    # emit this fence. Resource/clock tests still join the real loading job;
    # native rendering keeps its ordinary post-draw compiler fence.
    settling=DisplayServer.get_name()!="headless"
    if settling:RenderingServer.frame_post_draw.connect(_drawn,CONNECT_ONE_SHOT)

static func _poll()->void:
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
    return loading_path.is_empty() and _material_job.is_empty() and not settling

static func begin_mutation()->bool:
    if not can_mutate():return false
    mutation_frame=Engine.get_process_frames()
    return true

static func prepare(paths:Array,cache:Dictionary,fresh:bool=false)->Dictionary:
    _poll()
    var pending:int=0;var errors:Array=[]
    for path in paths:
        if cache.has(path):continue
        if cache.get("native_load_errors",{}).has(path):
            errors.append(cache.native_load_errors[path]);continue
        if not fresh and loading_path.is_empty() and _material_job.is_empty() and not settling and ResourceLoader.has_cached(path):
            cache[path]=load(path)
            continue
        pending+=1
        if not loading_path.is_empty() or not _material_job.is_empty() or settling or mutation_frame==Engine.get_process_frames():continue
        var error:Error=ResourceLoader.load_threaded_request(path,"",false,ResourceLoader.CACHE_MODE_IGNORE_DEEP if fresh else ResourceLoader.CACHE_MODE_REUSE)
        if error!=OK:
            errors.append("Native resource preparation failed: "+str(path));continue
        loading_path=path;loading_owner=cache;loading_revision=int(cache.get("native_source_revision",0));loads_started+=1
    return {"ready":pending==0 and errors.is_empty(),"pending":pending,"errors":errors,
        "loading":loading_path,"settling":settling}

static func prepare_materials(packet:Resource,materials:Array[Material],cache:Dictionary)->bool:
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
