extends RefCounted
# Exact current/near-future character sheets, prepared off the scene thread.
# Workers own unpublished images/textures. Only scene publication makes them ready.
const EMPTY:Dictionary={}
const Characters = preload("res://presentation/characters.gd")
const Conditions = preload("res://presentation/conditions.gd")
const WorldRows = preload("res://presentation/world.gd")
const EnvironmentMedia = preload("res://presentation/environment_media.gd")
const EncounterMedia = preload("res://presentation/encounter_media.gd")
const NativeSupport = preload("res://presentation/native_scene_support.gd")
const CharacterGeometry = preload("res://presentation/character_geometry.gd")
const BUDGET_BYTES = 16 * 1024 * 1024 * 1024
const EVICTIONS_PER_FRAME = 2
const CPU_RELEASES_PER_FRAME = 2
const DECODE_WORKERS = 8
const OPTIONAL_DECODE_WORKERS = 4
const DECODE_BATCH_IMAGES = 2
const PUBLICATION_BUDGET_USEC = 2000
const PUBLICATIONS_PER_FRAME = DECODE_WORKERS * DECODE_BATCH_IMAGES
const OPTIONAL_UPDATES_PER_FRAME = 32

# A consumer owns metadata plans and its displayed/boot readiness. The physical
# record owns source handles, decode jobs, accounting and aggregate pin roles.
static func create() -> Dictionary:
    var budget=maxi(0,int(ProjectSettings.get_setting("source_data/encounter_cache_mib",16384)))*1024*1024
    var owner={"pending":[],"queued":{},"wanted":{},"failed":{},"resident":{},
        "decode_jobs":[],"decoded":0,"evicted":0,"worker_upload":false,"maximum_texture_size":0,
        "decode_ms":0.0,"publication":{},"budget_bytes":budget,
        "encounter":{"paths":{},"estimates":{}},"preload_selected":{},"preload_skipped":0,"preload_estimated_bytes":0,
        "required_estimated_bytes":0,"unknown_required":0,"optional_estimated_bytes":0,"unknown_optional":0,
        "prune_frame":-1,"pruned_this_frame":0,"stats":{},"cpu_release":{},
        "cpu_release_frame":-1,"cpu_released_this_frame":0,"cpu_released_bytes_this_frame":0,
        "ready_paths":{},"boot_complete":true,"selected_ready":{},"selected_failed":{},"source_sizes":{},
        "consumers":{},"next_consumer":0,"interests":{},"families":[],"source_revision":0,
        "due_paths":{},"pending_order_dirty":false,
        "textures":{},"source_images":{},"texture_last_use":{},"fixture_frame_energy":{},"fixture_frame_centroids":{},
        "family_revision":0,"selected_family_revision":-1,"all_optional_selected":true,"changed_paths":{},"pending_paths":{},
        "optional_frame":-1,"optional_updates":0,"selection_publication":{},
        "selection_revision":0,"selection_task":-1,"selection_result":{},"selection_applied_revision":-1,"selection_jobs":0}
    var data={"plan_task":-1,"plan_pending":{},"optional_pending":{},"plan_result":{},"plan_cache":{},
        "required_plan":false,"metadata_phases":{},"metadata_ms":0.0,"metadata_jobs":0,
        "wanted":{},"environment":{},"fixtures":{},"gpu_only":{},"cpu_required":{},"budget_bytes":budget,
        "encounter":{},"encounter_override":{},"encounter_epoch":-1,"source_sizes":{},
        "demand_runs":0,"demand_noops":0,"demand_phases":{},"demand_counts":{},
        # The character light profile in use; the optional library loads only
        # its normals. optional_last is re-planned when the profile changes.
        "light_profile":"","optional_last":{}}
    _attach(data,owner)
    return data

static func physical(data:Dictionary)->Dictionary:
    return data.get("physical",data)

static func bind_host(data:Dictionary,host:Node)->Dictionary:
    data.host=weakref(host)
    var owner=physical(data)
    owner.consumers[data.consumer_id].host=data.host
    return owner

static func hosts(data:Dictionary)->Array:
    var result=[]
    for consumer in physical(data).consumers.values():
        var reference:WeakRef=consumer.get("host")
        if reference!=null and reference.get_ref()!=null:result.append(reference.get_ref())
    return result

static func _attach(data:Dictionary,owner:Dictionary)->void:
    owner.next_consumer+=1
    data.physical=owner;data.consumer_id=owner.next_consumer;data.closed=false
    data.preload_selected=owner.preload_selected
    data.ready_paths={};data.boot_paths={};data.boot_waiting={};data.boot_started=false;data.boot_complete=false
    owner.consumers[data.consumer_id]=_consumer_record(data)
    # These are aliases, not copied residency directories. Readiness stays local.
    for field in ["resident","failed","pending","queued","decode_jobs","cpu_release","selected_ready","selected_failed"]:
        data[field]=owner[field]
    for path in owner.resident:_refresh_consumer(owner,owner.consumers[data.consumer_id],path)

static func _consumer_record(data:Dictionary)->Dictionary:
    # Aliases to the consumer's existing readiness, without retaining data and
    # creating a cycle back to the physical owner.
    return {"paths":{},"environment":{},"fixtures":{},"gpu_only":{},"cpu_required":{},"records":[],"record_ids":{},"record_unkeyed":[],"record_roles":{},"family":{},"hint":{},"later_families":[],"due_paths":{},"host":data.get("host"),
        "ready_paths":data.ready_paths,"boot_paths":data.boot_paths,"boot_waiting":data.boot_waiting}

static func share(data:Dictionary,reference:Dictionary)->void:
    if is_same(physical(data),physical(reference)):return
    close(data)
    _attach(data,physical(reference))

static func _role_values(paths:Dictionary,environment:Dictionary,fixtures:Dictionary,gpu_only:Dictionary,cpu_required:Dictionary,path:String,required:bool)->Array:
    if not paths.has(path):return [0,0,0,0,0]
    var env=environment.has(path)
    var fixture=fixtures.has(path)
    return [int(required),int(not required),int(env or fixture or cpu_required.has(path) or not gpu_only.has(path)),int(fixture),int(env)]

static func _account_interest(owner:Dictionary,counts:Array,amount:int)->void:
    if counts[0]>0:
        owner.required_estimated_bytes+=amount*maxi(0,counts[5])
        owner.unknown_required+=amount*int(counts[5]<0)
    elif counts[1]>0:
        owner.optional_estimated_bytes+=amount*maxi(0,counts[5])
        owner.unknown_optional+=amount*int(counts[5]<0)

static func _change_interest(owner:Dictionary,path:String,absolute:String,before:Array,after:Array,defer_readiness:bool=false,family_accounting:bool=false)->void:
    if before==after:return
    var counts:Array=owner.interests.get(path,[0,0,0,0,0,-1])
    var required_before:bool=counts[0]>0
    var optional_before:bool=counts[1]>0
    var cpu_before:bool=_needs_cpu(owner,path)
    var fixture_before:bool=counts[3]>0
    var environment_before:bool=counts[4]>0
    var pinned_before:int=_pinned_bytes(owner,path,owner.resident[path]) if owner.resident.has(path) else 0
    var estimate_before:int=counts[5]
    for index in 5:counts[index]+=int(after[index])-int(before[index])
    var required_now:bool=counts[0]>0
    var optional_now:bool=counts[1]>0
    var environment_now:bool=counts[4]>0
    var fixture_now:bool=counts[3]>0
    if counts[0]+counts[1]==0:owner.interests.erase(path)
    else:owner.interests[path]=counts
    var cpu_now:bool=_needs_cpu(owner,path)
    if required_before!=required_now:
        if required_now:owner.wanted[path]=absolute
        else:owner.wanted.erase(path)
    if optional_before!=optional_now:
        if optional_now:owner.encounter.paths[path]=absolute
        else:owner.encounter.paths.erase(path)
    if cpu_before!=cpu_now or estimate_before<0:counts[5]=_shared_estimate(owner,path)
    # Physical counts are the only aggregate optical-role directory. Another
    # consumer retaining the same role changes its count, not its readiness,
    # resident classification or byte account.
    if required_before==required_now and optional_before==optional_now and cpu_before==cpu_now \
            and fixture_before==fixture_now and environment_before==environment_now and estimate_before==counts[5]:return
    var old_account:Array=[int(required_before),int(optional_before),0,0,0,estimate_before]
    _account_interest(owner,old_account,-1)
    _account_interest(owner,counts,1)
    owner.changed_paths[path]=true;owner.pending_paths[path]=true
    # Immutable family activation already owns its whole optional selection.
    # Moving that family's accounting cursor is not another selector input.
    # Actual required pins/bytes still change the worker's captured budget.
    if required_before!=required_now or (required_now and counts[5]!=estimate_before) \
            or (not family_accounting and (optional_before!=optional_now or counts[5]!=estimate_before)):
        owner.selection_revision+=1
    if not owner.stats.is_empty() and owner.queued.has(path) and environment_before!=environment_now:
        owner.stats[environment_before].pending-=1;owner.stats[environment_now].pending+=1
    if owner.resident.has(path):
        var resident:Dictionary=owner.resident[path]
        if not owner.stats.is_empty():
            owner.stats[resident.environment].pinned_bytes+=_pinned_bytes(owner,path,resident)-pinned_before
        if environment_before!=environment_now or cpu_before!=cpu_now or required_before!=required_now:
            _refresh_resident_role(owner,path,true,not defer_readiness)
        elif not defer_readiness:_refresh_path(owner,path)
    elif not defer_readiness:_refresh_path(owner,path)

static func _family_interest(owner:Dictionary,family:Dictionary,amount:int,hint:bool=false)->void:
    if family.is_empty():return
    for row in owner.families:
        if not is_same(row.family,family):continue
        var active:bool=row.users>0
        row.users+=amount
        if active!=(row.users>0):owner.selection_revision+=1
        return
    if amount<0:return
    # Registration is a reference handoff. Source-by-source accounting belongs
    # to the bounded optional lane, never the action's exact demand update.
    owner.families.append({"family":family,"users":1,"hint":hint,"cursor":0,
        "paths":family.ordered_paths if family.has("ordered_paths") else family.get("paths",{}).keys()})
    owner.family_revision+=1;owner.selection_revision+=1

static func _step_families(owner:Dictionary,limit:int,hints_only:bool=false)->int:
    var used=0;var completed=[]
    var ordered:Array=owner.families.filter(func(row):return row.hint and row.users>0)
    if not hints_only:
        ordered.append_array(owner.families.filter(func(row):return not row.hint or row.users<=0))
    for row in ordered:
        var adding:bool=row.users>0
        if not ((adding and row.cursor<row.paths.size()) or (not adding and row.cursor>0)):
            if not adding:completed.append(row)
            continue
        var family:Dictionary=row.family
        var paths:Dictionary=family.paths
        var source_sizes:Dictionary=family.get("source_sizes",EMPTY)
        var estimates:Dictionary=family.get("estimates",EMPTY)
        var estimate_bytes:Dictionary=family.get("estimate_bytes",EMPTY)
        var environment:Dictionary=family.get("environment",EMPTY)
        var fixtures:Dictionary=family.get("fixtures",EMPTY)
        var gpu_only:Dictionary=family.get("gpu_only",EMPTY)
        var cpu_required:Dictionary=family.get("cpu_required",EMPTY)
        while used<limit and ((adding and row.cursor<row.paths.size()) or (not adding and row.cursor>0)):
            if not adding:row.cursor-=1
            var path:String=row.paths[row.cursor]
            if adding:
                if source_sizes.has(path):_source_size(owner,path,source_sizes[path])
                if estimates.has(path):owner.encounter.estimates[path]=estimates[path]
                elif estimate_bytes.has(path):owner.encounter.estimates[path]={"bytes":estimate_bytes[path]}
            var roles=_role_values(paths,environment,fixtures,gpu_only,cpu_required,path,false)
            _change_interest(owner,path,paths[path],[0,0,0,0,0] if adding else roles,roles if adding else [0,0,0,0,0],false,true)
            if adding:row.cursor+=1
            used+=1
        if not adding and row.cursor==0:completed.append(row)
        if used>=limit:break
    for row in completed:owner.families.erase(row)
    return used

static func _families_pending(owner:Dictionary)->bool:
    return owner.families.any(func(row):return row.cursor!=(row.paths.size() if row.users>0 else 0))

static func _shared_estimate(owner:Dictionary,path:String)->int:
    if owner.source_sizes.has(path):return int(owner.source_sizes[path])*(2 if _needs_cpu(owner,path) else 1)
    var estimate:Dictionary=owner.encounter.estimates.get(path,{})
    if estimate.has("gpu_bytes"):return int(estimate.gpu_bytes)*(2 if _needs_cpu(owner,path) else 1)
    if estimate.has("bytes"):return int(estimate.bytes)
    if owner.resident.has(path):
        var resident:Dictionary=owner.resident[path]
        return int(resident.gpu_bytes)*(2 if _needs_cpu(owner,path) else 1)
    return -1

static func _source_size(owner:Dictionary,path:String,size:int)->void:
    if owner.source_sizes.get(path,-1)==size:return
    if owner.interests.has(path):_account_interest(owner,owner.interests[path],-1)
    owner.source_sizes[path]=size
    if owner.interests.has(path):
        owner.interests[path][5]=_shared_estimate(owner,path)
        _account_interest(owner,owner.interests[path],1)
        owner.changed_paths[path]=true
        if owner.wanted.has(path):owner.selection_revision+=1

static func _select_path(owner:Dictionary,path:String,selected:bool)->void:
    if owner.preload_selected.has(path)==selected:return
    if owner.resident.has(path):_resident_delta(owner,path,owner.resident[path],-1)
    if selected:owner.preload_selected[path]=owner.encounter.paths[path]
    else:owner.preload_selected.erase(path)
    if owner.resident.has(path):_resident_delta(owner,path,owner.resident[path],1)
    _refresh_path(owner,path)
    if not selected:owner.selected_ready.erase(path);owner.selected_failed.erase(path)
    owner.pending_paths[path]=true

static func _selection_changes(before:Dictionary,after:Dictionary)->Dictionary:
    var changed={}
    for path in before:
        if not after.has(path):changed[path]=true
    for path in after:
        if not before.has(path):changed[path]=true
    return changed

static func _select_optional(families:Array,required:Dictionary,budget:int,previous:Dictionary,revision:int,result:Dictionary)->void:
    # Immutable family records are borrowed by this one worker. Required demand
    # is the small captured input; no residency maps or consumer nodes are read.
    var known={};var sizes={}
    for family in families:
        # Read each shared family map once. Per-path lookups with fresh default
        # dictionaries allocated and contended with the scene thread per hover.
        var paths:Dictionary=family.get("paths",EMPTY)
        var estimates:Dictionary=family.get("estimates",EMPTY)
        var estimate_bytes:Dictionary=family.get("estimate_bytes",EMPTY)
        var source_sizes:Dictionary=family.get("source_sizes",EMPTY)
        var cpu_required:Dictionary=family.get("cpu_required",EMPTY)
        var environment:Dictionary=family.get("environment",EMPTY)
        var fixtures:Dictionary=family.get("fixtures",EMPTY)
        var gpu_only:Dictionary=family.get("gpu_only",EMPTY)
        for path in paths:
            known[path]=paths[path]
            var estimate:Dictionary=estimates.get(path,EMPTY)
            var size:int=estimate.get("bytes",estimate_bytes.get(path,-1))
            if source_sizes.has(path):
                var cpu:bool=cpu_required.has(path) or environment.has(path) or fixtures.has(path) or not gpu_only.has(path)
                size=int(source_sizes[path])*(2 if cpu else 1)
            sizes[path]=maxi(int(sizes.get(path,-1)),size)
    var used=0;var unknown=0
    for path in required:
        if required[path].bytes<0:unknown+=1
        else:used+=required[path].bytes
        if known.has(path):sizes[path]=required[path].bytes
    var selected={};var selected_bytes=0
    for path in known:
        var size:int=sizes[path]
        if required.has(path):selected[path]=known[path];selected_bytes+=maxi(0,size)
        elif unknown==0 and size>=0 and used+size<=budget:
            selected[path]=known[path];used+=size;selected_bytes+=size
    result.merge({"revision":revision,"selected":selected,"bytes":selected_bytes,"changes":_selection_changes(previous,selected)})

static func _select_shared(owner:Dictionary,limit:int)->int:
    if owner.selection_task>=0 and WorkerThreadPool.is_task_completed(owner.selection_task):
        WorkerThreadPool.wait_for_task_completion(owner.selection_task);owner.selection_task=-1
        var result:Dictionary=owner.selection_result;owner.selection_result={}
        if result.get("revision",-2)==owner.selection_revision:
            # Withdraw superseded optional selections first. Then admit the
            # current cut before other accepted future sources, within the same
            # bounded publication allowance and the worker's budget decision.
            var removed:Array=[];var due:Array=[];var later:Array=[]
            for path in result.changes:
                if not result.selected.has(path):removed.append(path)
                elif owner.due_paths.has(path):due.append(path)
                else:later.append(path)
            result.paths=removed+due+later;result.removals=removed.size();result.cursor=0
            owner.selection_publication=result
    var used=0
    var fits:bool=owner.unknown_required==0 and owner.unknown_optional==0 \
        and owner.required_estimated_bytes+owner.optional_estimated_bytes<=owner.budget_bytes
    var publication:Dictionary=owner.selection_publication
    if not publication.is_empty() and publication.revision!=owner.selection_revision:
        owner.selection_publication={};publication={}
    # A ready budget decision gets the existing publication allowance before
    # continuing unrelated family bookkeeping can consume that allowance.
    while not publication.is_empty() and publication.cursor<publication.paths.size() and used<limit:
        var path:String=publication.paths[publication.cursor]
        _select_path(owner,path,publication.selected.has(path) and owner.encounter.paths.has(path))
        publication.cursor+=1;used+=1
    var processed=[]
    var ordered:Array=[]
    for path in owner.due_paths:
        if owner.changed_paths.has(path):ordered.append(path)
    for path in owner.changed_paths:
        if not owner.due_paths.has(path):ordered.append(path)
    for path in ordered:
        if used>=limit:break
        if fits and owner.all_optional_selected:_select_path(owner,path,owner.encounter.paths.has(path))
        elif not owner.encounter.paths.has(path):_select_path(owner,path,false)
        else:
            var decision:Dictionary=owner.selection_publication
            if decision.get("revision",-2)==owner.selection_revision and decision.cursor>=decision.removals:
                _select_path(owner,path,decision.selected.has(path))
        processed.append(path);used+=1
    for path in processed:owner.changed_paths.erase(path)
    if fits and owner.all_optional_selected:
        owner.preload_estimated_bytes=owner.optional_estimated_bytes
        for path in owner.wanted:
            if owner.preload_selected.has(path):owner.preload_estimated_bytes+=maxi(0,int(owner.interests[path][5]))
        if owner.changed_paths.is_empty():owner.selection_applied_revision=owner.selection_revision
    else:
        owner.all_optional_selected=false
        if not publication.is_empty() and publication.cursor==publication.paths.size():
            owner.preload_estimated_bytes=publication.bytes
            # Retain this decision for accepted paths whose family accounting
            # has not reached them yet. Cursor progress is not a new input.
            owner.selection_applied_revision=publication.revision
            owner.all_optional_selected=fits and not _families_pending(owner)
        if owner.selection_task<0 and owner.selection_publication.is_empty() \
                and owner.selection_applied_revision!=owner.selection_revision:
            var required={}
            for path in owner.wanted:required[path]={"bytes":owner.interests[path][5]}
            owner.selection_result={}
            var families:Array=owner.families.filter(func(row):return row.users>0 and row.hint).map(func(row):return row.family)
            families.append_array(owner.families.filter(func(row):return row.users>0 and not row.hint).map(func(row):return row.family))
            # A plain bounded-account snapshot is borrowed only by this worker;
            # it is not compared or reconstructed on the required demand path.
            var work=_select_optional.bind(families,required,owner.budget_bytes,owner.preload_selected.duplicate(),
                owner.selection_revision,owner.selection_result)
            owner.selection_task=WorkerThreadPool.add_task(work,false,"Shared optional source budget")
            owner.selection_jobs+=1
    owner.preload_skipped=owner.encounter.paths.size()-owner.preload_selected.size()
    return used

static func _decode_priority(owner:Dictionary,path:String)->int:
    if owner.due_paths.has(path) and _pinned(owner,path):return 0
    return 1 if owner.wanted.has(path) else 2

static func _order_pending(owner:Dictionary)->void:
    if not owner.pending_order_dirty:return
    # Stable partition of existing requests: current display cut, received
    # later work, optional reuse. Equal-priority authored order is preserved.
    var tiers:Array=[[],[],[]]
    for request in owner.pending:tiers[_decode_priority(owner,request.path)].append(request)
    owner.pending.clear()
    for tier in tiers:owner.pending.append_array(tier)
    owner.pending_order_dirty=false

static func prioritize(data:Dictionary,paths:Dictionary)->void:
    # Scheduling intent only. The whole received operation remains pinned by
    # demand; this consumer's exact due cut neither grants bytes nor new roles.
    var owner=physical(data)
    if not owner.consumers.has(data.consumer_id):return
    var consumer:Dictionary=owner.consumers[data.consumer_id]
    var before:Dictionary=consumer.due_paths
    if before==paths:return
    var changed:=false
    for path in before:
        if paths.has(path):continue
        owner.due_paths[path]-=1
        if owner.due_paths[path]==0:owner.due_paths.erase(path);changed=true
    for path in paths:
        if before.has(path):continue
        if not owner.due_paths.has(path):changed=true
        owner.due_paths[path]=int(owner.due_paths.get(path,0))+1
    consumer.due_paths=paths.duplicate()
    if changed:owner.pending_order_dirty=true;_order_pending(owner)

static func _update_pending(owner:Dictionary)->void:
    # Queue entries are the existing queued directory values. Role changes
    # preserve FIFO order within each priority, including new required sources.
    for path in owner.pending_paths:
        var pinned=_pinned(owner,path)
        if not owner.queued.has(path):
            if pinned:enqueue(owner,path,owner.wanted.get(path,owner.preload_selected.get(path,"")))
            continue
        var request:Dictionary=owner.queued[path]
        if not request.pending:continue
        if not pinned:
            owner.pending.erase(request);owner.queued.erase(path);_pending_delta(owner,path,-1)
        else:
            var required:bool=owner.wanted.has(path)
            if request.required!=required:
                request.required=required;owner.pending_order_dirty=true
            request.fixture=_fixture(owner,path)
    owner.pending_paths.clear()
    _order_pending(owner)

static func prepare_optional(data:Dictionary,hints_only:bool=false)->void:
    if data.get("closed",false):return
    var owner=physical(data)
    var frame=Engine.get_process_frames()
    if owner.optional_frame!=frame:owner.optional_frame=frame;owner.optional_updates=0
    var remaining:int=OPTIONAL_UPDATES_PER_FRAME-owner.optional_updates
    if remaining<=0:return
    # Settled: every interest change marks changed/pending paths and every
    # selector input bumps selection_revision, so a pass here would only
    # recompute the values already stored.
    var publication:Dictionary=owner.selection_publication
    if owner.changed_paths.is_empty() and owner.pending_paths.is_empty() and owner.selection_task<0 \
            and (publication.is_empty() or publication.cursor>=publication.paths.size()) \
            and owner.selection_applied_revision==owner.selection_revision and not _families_pending(owner):return
    var started=Time.get_ticks_usec()
    var used=_step_families(owner,maxi(1,remaining/2),hints_only)
    var family_done=Time.get_ticks_usec()
    # Select/account a bounded matching portion even while a large family is
    # arriving; exact demand never waits for these optional references.
    used+=_select_shared(owner,remaining-used)
    owner.optional_updates+=used
    var selection_done=Time.get_ticks_usec()
    _update_pending(owner)
    owner.optional_phases={"family":(family_done-started)/1000.0,"selection":(selection_done-family_done)/1000.0,"pending":(Time.get_ticks_usec()-selection_done)/1000.0,"updates":used}

static func _withdraw(data:Dictionary)->void:
    var owner=physical(data)
    if not owner.consumers.has(data.consumer_id):return
    prioritize(data,{})
    var before:Dictionary=owner.consumers[data.consumer_id]
    for path in before.paths:
        _change_interest(owner,path,before.paths[path],_role_values(before.paths,before.environment,before.fixtures,before.gpu_only,before.cpu_required,path,true),[0,0,0,0,0])
    _family_interest(owner,before.family,-1)
    _family_interest(owner,before.hint,-1)
    for family in before.later_families:_family_interest(owner,family,-1)
    owner.consumers.erase(data.consumer_id)
    _update_pending(owner)

static func _snapshot(state: Dictionary) -> Dictionary:
    # Dictionary membership can change on the scene thread. The after-value
    # records themselves are immutable, so copy only these small map indexes.
    var snapshot = {}
    if not state.is_empty():
        for field in ["actors","tiles","objects"]: snapshot[field] = state[field].duplicate()
        snapshot.senses = state.senses
        snapshot.audience = state.audience
    return snapshot

static func request_plan(data: Dictionary, key: Array, state: Dictionary, groups: Array) -> void:
    data.plan_pending = {"key":key.duplicate(true),"state":_snapshot(state),"groups":groups.duplicate()}
    # A new required request supersedes older optional intent at admission, not
    # later dispatch: a handoff arriving in between is newer and must survive.
    data.optional_pending = {}
    _start_plan(data)

static func prepare_handoff(state: Dictionary, groups: Array, cache: Dictionary, final_state: Dictionary = {}) -> Dictionary:
    # Called by the existing session preparer, before publishing these groups.
    # This cache belongs exclusively to that worker; no scene residency changes.
    if groups.is_empty(): return {}
    var selected: Array = groups.slice(0,mini(2,groups.size()))
    var result = {}
    _plan_sources({"key":[],"state":_snapshot(state),"groups":selected,
        "origin_state":state,"final_state":final_state,"tail_groups":groups.slice(selected.size())},result,cache)
    result.generation = state.generation
    result.observer_uuid = state.observer_uuid
    result.groups = selected
    return result

static func prepare_opening_handoff(state:Dictionary,group:Dictionary,cache:Dictionary)->Dictionary:
    # Resolve only the first authored source cut. Late hit/death, changed world
    # rows and the following group are a separate completion of this same owner.
    # The declared horizon prevents that partial metadata from admitting a later
    # cue before its complete requirements have been delivered.
    var opening:Dictionary=group.duplicate()
    var until_ms:float=INF
    for field in ["actor_tracks","components","commits","native_requirements"]:
        var selected:Array=[]
        for row in group.get(field,[]):
            var at:float=float(row.get("preparation_at_ms",0.0) if field=="native_requirements" else row.get("at_ms",0.0) if field=="commits" else row.get("start_ms",0.0))
            if at<=0.000001:selected.append(row)
            else:until_ms=minf(until_ms,at)
        opening[field]=selected
    for pair in [["staged_actors","staged_at_ms"],["staged_tiles","staged_tile_at_ms"]]:
        var selected:Dictionary={}
        for id in group.get(pair[0],{}):
            var at:float=float(group.get(pair[1],{}).get(id,0.0))
            if at<=0.000001:selected[id]=group[pair[0]][id]
            else:until_ms=minf(until_ms,at)
        opening[pair[0]]=selected
    if not is_finite(until_ms):return {}
    var previous:Dictionary=cache.get("__required_actor_closures",{})
    var result:Dictionary={}
    _plan_sources({"key":[],"state":_snapshot(state),"groups":[opening],"origin_state":state,"partial":true},result,cache)
    # A partial source cut borrows the previous complete selection. It cannot
    # evict already resolved impact/death sources immediately before the full
    # continuation needs them. Completion below replaces this bounded borrow.
    var current:Dictionary=cache.get("__required_actor_closures",{})
    if not previous.is_empty() and not current.is_empty() and is_same(previous.get("admission"),current.get("admission")):
        var retained:Array=current.entries.duplicate()
        for packet in previous.entries:
            if not retained.any(func(entry):return is_same(entry,packet)):retained.append(packet)
        current.entries=retained
    result.generation=state.generation;result.observer_uuid=state.observer_uuid
    result.groups=[group];result.coverage_until_ms=until_ms
    result.erase("optional_request")
    return result

static func receive_handoff(data: Dictionary, completed: Dictionary, key: Array) -> Dictionary:
    # The scene has checked accepted group ownership and supplies its local epoch.
    # Raw source files are immutable; only the optional worker merges its cache.
    var result: Dictionary = completed.duplicate()
    result.key = key
    if completed.has("optional_request"):
        var optional: Dictionary = completed.optional_request.duplicate()
        optional.key = key
        optional.source_files = completed.source_files
        data.optional_pending = optional
    data.metadata_ms += completed.elapsed_ms
    data.metadata_jobs += 1
    data.metadata_phases.required = completed.phases
    result.erase("optional_request")
    _start_plan(data)
    return result

static func _start_plan(data: Dictionary, allow_optional:bool=false) -> void:
    if data.plan_task >= 0: return
    var request: Dictionary
    var optional = false
    if not data.plan_pending.is_empty():
        request = data.plan_pending
        data.plan_pending = {}
    elif allow_optional and not data.optional_pending.is_empty() and data.encounter_override.is_empty():
        request = data.optional_pending
        data.optional_pending = {}; optional = true
        request = request.duplicate()
        request.profile = data.light_profile
        data.optional_last = request
    else: return
    data.plan_result = {}
    var work = _plan_optional.bind(request,data.plan_result,data.plan_cache) if optional else _plan_sources.bind(request,data.plan_result,data.plan_cache)
    data.plan_task = WorkerThreadPool.add_task(work,false,"Optional authored families" if optional else "Required authored media")

static func source_records(character:Dictionary,environment:Dictionary,groups:Array,cache:Dictionary,partial:bool=false)->Dictionary:
    var result:Dictionary={}
    var previous:Dictionary=cache.get("__source_record_sets",{})
    var reuse:Dictionary={"previous":previous.get("opening",[])+previous.get("complete",[]),"current":[]}
    for index in maxi(1,groups.size()):
        var group:Dictionary=groups[index] if not groups.is_empty() else {}
        var environment_records:Array=environment.required_records if index==0 else environment.upcoming_records
        var profiles:Dictionary={}
        for profile in CharacterGeometry.PROFILES:
            var sets:Array=[environment_records]
            var families:Array=[environment.get("required_family",{}) if index==0 else environment.get("upcoming_family",{})]
            for packet in character.get("actor_records",{}).get(group.get("id",""),[]):
                sets.append(packet.source_records[profile])
                families.append(packet.source_families[profile])
            profiles[profile]=_source_record_union(sets,reuse,families)
        profiles.make_read_only();result[group.get("id","")]=profiles
    cache.__source_record_sets={"opening":reuse.current if partial else previous.get("opening",[]),
        "complete":previous.get("complete",[]) if partial else reuse.current,"sizes":previous.get("sizes",{})}
    return result

static func _source_record_union(sets:Array,reuse:Dictionary,families:Array=[])->Array:
    for rows in [reuse.current,reuse.previous]:
        for row in rows:
            if row.sets.size()!=sets.size():continue
            var same:bool=true
            for index in sets.size():
                if not is_same(row.sets[index],sets[index]):same=false;break
            if same:
                if not reuse.current.any(func(current):return is_same(current,row)):reuse.current.append(row)
                return row.records
    var records:Array=[];var seen:Dictionary={}
    for selected in sets:append_source_records(records,seen,selected)
    records.make_read_only();sets.make_read_only();families.make_read_only()
    reuse.current.append({"sets":sets,"records":records,"families":families})
    return records

static func _source_size_union(character:Dictionary,environment:Dictionary,cache:Dictionary,partial:bool)->Dictionary:
    # Header facts belong to the selected immutable source packets. Repeated
    # actors/groups borrow those contributions; operation clocks do not create
    # another copy of every shared sheet's size.
    var parts:Array=[environment.source_sizes]
    var header_parts:Array=[environment.get("source_headers",{})]
    for packets in character.get("actor_records",{}).values():
        for packet in packets:
            var sizes:Dictionary=packet.source_sizes
            if not parts.any(func(part):return is_same(part,sizes)):
                parts.append(sizes);header_parts.append(packet.get("source_headers",{}))
    var owner:Dictionary=cache.get("__source_record_sets",{})
    var previous:Dictionary=owner.get("sizes",{})
    for kind in ["opening","complete"]:
        var row:Dictionary=previous.get(kind,{})
        if row.is_empty() or row.parts.size()!=parts.size():continue
        var same:bool=true
        for index in parts.size():
            if not is_same(row.parts[index],parts[index]):same=false;break
        if same:return row.value
    var value:Dictionary={}
    for part in parts:value.merge(part)
    var headers:Dictionary={}
    for part in header_parts:headers.merge(part)
    headers.make_read_only()
    value.make_read_only();parts.make_read_only()
    var retained:Dictionary=previous.duplicate()
    retained["opening" if partial else "complete"]={"parts":parts,"value":value,"headers":headers}
    owner.sizes=retained
    return value

static func _source_size_headers(sizes:Dictionary,cache:Dictionary)->Dictionary:
    for row in cache.get("__source_record_sets",{}).get("sizes",{}).values():
        if is_same(row.value,sizes):return row.headers
    return {}

static func append_source_records(records:Array,seen:Dictionary,incoming:Array)->void:
    # Imported sources own a stable identity. Their ordered union visits each
    # source once; custom tooling records without an identity retain ref equality.
    for record in incoming:
        if record.has("source_id"):
            if seen.has(record.source_id):continue
            seen[record.source_id]=true;records.append(record)
        else:
            # A passive source without an ID cannot be identical to a keyed
            # source. Compare only the few unkeyed partitions already seen,
            # rather than walking the entire keyed room for each partition.
            if not seen.has(null):seen[null]=[]
            var unkeyed:Array=seen[null]
            if unkeyed.any(func(current):return is_same(current,record)):continue
            unkeyed.append(record);records.append(record)

static func _source_first_use(schedule:Dictionary)->Dictionary:
    var times:Dictionary={}
    for path in schedule.get("initial",{}):times[path]=0.0
    for change in schedule.get("changes",[]):
        for path in change.paths:
            if not times.has(path):times[path]=float(change.at_ms)
    return times

static func _source_partition(record:Dictionary,roles:Dictionary,reuse:Dictionary)->Dictionary:
    for entries in [reuse.current,reuse.previous]:
        for prior in entries:
            if is_same(prior.source,record) and prior.roles==roles:
                if not reuse.current.has(prior):reuse.current.append(prior)
                return prior.value
    roles.make_read_only()
    var selected:Dictionary={"roles":roles};selected.make_read_only()
    reuse.current.append({"source":record,"roles":roles,"value":selected})
    return selected

static func _source_cut_schedule(records:Array,character_times:Dictionary,environment_times:Dictionary,reuse:Dictionary)->Dictionary:
    var by_time:Dictionary={}
    for record in records:
        var partitions:Dictionary={}
        for path in record.roles:
            var role:Array=record.roles[path]
            var times:Dictionary=environment_times if role[3]>0 else character_times
            var at:float=float(times.get(path,0.0))
            if not partitions.has(at):partitions[at]={}
            partitions[at][path]=role
        for at in partitions:
            if not by_time.has(at):by_time[at]=[]
            if partitions.size()==1:
                by_time[at].append(record)
            else:
                # A source operand can be needed before another role in the
                # same imported descriptor. Split only that actual cut; keep
                # its immutable role rows, without inventing a physical ID.
                by_time[at].append(_source_partition(record,partitions[at],reuse))
    var initial:Array=by_time.get(0.0,[]);initial.make_read_only()
    var changes:Array=[]
    var keys:Array=by_time.keys();keys.sort()
    var cumulative:Array=initial
    for at in keys:
        if at<=0:continue
        cumulative=cumulative.duplicate();cumulative.append_array(by_time[at]);cumulative.make_read_only()
        var change:Dictionary={"at_ms":at,"records":cumulative};change.make_read_only();changes.append(change)
    changes.make_read_only()
    var schedule:Dictionary={"initial":initial,"changes":changes};schedule.make_read_only()
    return schedule

static func _source_family(records:Array,sizes:Dictionary)->Dictionary:
    var paths:Dictionary={};var environment:Dictionary={};var fixtures:Dictionary={};var cpu:Dictionary={};var gpu:Dictionary={}
    for record in records:
        for path in record.roles:
            var role:Array=record.roles[path]
            paths[path]=role[0]
            if role[1]>0:cpu[path]=true
            if role[2]>0:fixtures[path]=true
            if role[3]>0:environment[path]=true
    for path in paths:
        if not cpu.has(path):gpu[path]=true
    var ordered:Array=paths.keys();ordered.make_read_only()
    for values in [paths,environment,fixtures,cpu,gpu]:values.make_read_only()
    var family:Dictionary={"paths":paths,"environment":environment,"fixtures":fixtures,"cpu_required":cpu,"gpu_only":gpu,
        "ordered_paths":ordered,"source_sizes":sizes};family.make_read_only()
    return family

static func _retained_source_family(records:Array,sizes:Dictionary,cache:Dictionary)->Dictionary:
    var owner:Dictionary=cache.get("__source_record_sets",{})
    for kind in ["opening","complete"]:
        for row in owner.get(kind,[]):
            if not is_same(row.records,records):continue
            if not row.has("family"):
                row.family=_combine_source_families(row.families) if not row.get("families",[]).is_empty() else _source_family(records,sizes)
            return row.family
    return _source_family(records,sizes)

static func _combine_source_families(parts:Array)->Dictionary:
    # Imported actor/environment packets already own role projections. Compose
    # their native maps only for a new selection, instead of re-walking every
    # descriptor and header once per profile on every operation.
    var paths:Dictionary={};var environment:Dictionary={};var fixtures:Dictionary={}
    var cpu:Dictionary={};var gpu:Dictionary={};var sizes:Dictionary={}
    for part in parts:
        if part.is_empty():continue
        paths.merge(part.paths,false);environment.merge(part.environment);fixtures.merge(part.fixtures)
        cpu.merge(part.cpu_required);gpu.merge(part.gpu_only);sizes.merge(part.source_sizes)
    for path in cpu:gpu.erase(path)
    var ordered:Array=paths.keys();ordered.make_read_only()
    for values in [paths,environment,fixtures,cpu,gpu,sizes]:values.make_read_only()
    var family:Dictionary={"paths":paths,"environment":environment,"fixtures":fixtures,"cpu_required":cpu,
        "gpu_only":gpu,"ordered_paths":ordered,"source_sizes":sizes};family.make_read_only()
    return family

static func _source_publications(plan:Dictionary,cache:Dictionary,initial_only:bool=false)->void:
    # The metadata producer computes cuts once. The scene thread selects an
    # already-owned array and hands later work to the existing bounded lane.
    var cuts:Dictionary={};var families:Dictionary={}
    var reuse:Dictionary={"previous":cache.get("__source_cut_partitions",[]),"current":[]}
    var sizes:Dictionary=plan.source_sizes;sizes.make_read_only()
    for id in plan.source_records:
        var character_times:Dictionary={} if initial_only else _source_first_use(plan.get("character_timeline",{}).get(id,{}))
        var environment_times:Dictionary={} if initial_only else _source_first_use(plan.get("environment_timeline",{}).get(id,{}))
        var profile_cuts:Dictionary={};var profile_families:Dictionary={}
        for profile in plan.source_records[id]:
            var records:Array=plan.source_records[id][profile]
            if initial_only:
                var changes:Array=[];changes.make_read_only()
                var opening:Dictionary={"initial":records,"changes":changes};opening.make_read_only()
                profile_cuts[profile]=opening
            else:profile_cuts[profile]=_source_cut_schedule(records,character_times,environment_times,reuse)
            profile_families[profile]=_retained_source_family(records,sizes,cache)
        profile_cuts.make_read_only();profile_families.make_read_only()
        cuts[id]=profile_cuts;families[id]=profile_families
    cuts.make_read_only();families.make_read_only()
    plan.source_cuts=cuts;plan.source_families=families
    # Opening has no late partition work. Its empty local list cannot retire
    # the previous complete source owner before this operation's continuation
    # has reused/replaced those real immutable partition refs.
    if not initial_only:cache.__source_cut_partitions=reuse.current

static func records_at(schedule:Dictionary,local_ms:float,fallback:Array=[])->Array:
    if not schedule.has("initial"):return fallback
    var records:Array=schedule.initial
    for change in schedule.changes:
        if float(change.at_ms)>local_ms+0.000001:break
        records=change.records
    return records

static func _plan_sources(request: Dictionary, result: Dictionary, cache: Dictionary) -> void:
    var started = Time.get_ticks_usec()
    result.key = request.key
    result.stage = "required"
    result.value = plan(request.state,request.groups,cache)
    var characters_done = Time.get_ticks_usec()
    var tail:Array=request.get("tail_groups",[])
    var environment = EnvironmentMedia.plan(request.state,request.groups,cache,request.get("origin_state",{}),
        request.get("final_state",{}) if tail.is_empty() else {},request.get("partial",false))
    var environment_done = Time.get_ticks_usec()
    result.value.environment_required = environment.required
    result.value.environment_upcoming = environment.upcoming
    result.value.environment_timeline = environment.environment_timeline
    result.value.fixtures = environment.fixtures
    result.value.source_records=source_records(result.value,environment,request.groups,cache,request.get("partial",false))
    var roles_done:int=Time.get_ticks_usec()
    result.value.source_sizes = _source_size_union(result.value,environment,cache,request.get("partial",false))
    result.source_headers = _source_size_headers(result.value.source_sizes,cache)
    var sizes_done = Time.get_ticks_usec()
    _source_publications(result.value,cache,request.get("partial",false))
    var publications_done:int=Time.get_ticks_usec()
    EnvironmentMedia.finish_handoff(tail,request.get("final_state",{}),cache)
    var tail_done:int=Time.get_ticks_usec()
    # The single metadata owner schedules optional families only after this
    # exact required packet has crossed the completed-task publication boundary.
    result.optional_request = {"key":request.key,"state":request.state,"groups":request.groups,"required":result.value}
    result.source_files = Characters.Catalog.source_snapshot(cache)
    result.phases = {"characters":(characters_done-started)/1000.0,
        "environment":(environment_done-characters_done)/1000.0,"roles":(roles_done-environment_done)/1000.0,
        "source_sizes":(sizes_done-roles_done)/1000.0,"source_publications":(publications_done-sizes_done)/1000.0,
        "environment_tail":(tail_done-publications_done)/1000.0,"source_files":(Time.get_ticks_usec()-tail_done)/1000.0}
    result.phases.source_headers_cached_count=cache.get("__required_headers",{}).size()
    result.phases.source_headers_selected_count=result.source_headers.size()
    for phase in environment.get("diagnostics",{}).get("phases",{}):
        result.phases["environment_"+phase] = environment.diagnostics.phases[phase]
    result.elapsed_ms = (Time.get_ticks_usec()-started)/1000.0
    result.complete = true

static func _plan_optional(request: Dictionary, result: Dictionary, cache: Dictionary) -> void:
    var started = Time.get_ticks_usec()
    Characters.Catalog.adopt_snapshot(cache,request.get("source_files",{}))
    result.key = request.key
    result.stage = "optional"
    var required: Dictionary = request.required
    var environment: Dictionary = required.environment_required.duplicate()
    environment.merge(required.environment_upcoming)
    var family=EncounterMedia.plan(request.state,environment,required.fixtures,cache,request.groups,request.get("profile",""))
    var families_done=Time.get_ticks_usec()
    var prior:Dictionary=cache.get("__published_optional_family",{})
    var encounter:Dictionary
    if not prior.is_empty() and is_same(prior.source,family):encounter=prior.value
    else:
        # This producer publishes one immutable family owner. Required source
        # headers/roles have their own consumer and cannot rebuild this family.
        encounter=family.duplicate()
        encounter.estimates=EncounterMedia.estimates(family.paths,family.cpu_required,family.gpu_only,cache)
        for field in ["paths","environment","fixtures","gpu_only","cpu_required"]:
            encounter[field]=encounter[field].duplicate()
            encounter[field].make_read_only()
        encounter.errors=family.errors.duplicate()
        for estimate in encounter.estimates.values():
            if estimate.has("error"):encounter.errors.append(estimate.error)
        encounter.ordered_paths=encounter.paths.keys();encounter.ordered_paths.make_read_only()
        encounter.estimates.make_read_only();encounter.errors.make_read_only();encounter.make_read_only()
        cache.__published_optional_family={"source":family,"value":encounter}
    var estimates_done=Time.get_ticks_usec()
    result.value={"encounter":encounter}
    result.source_headers=cache.get("__encounter_headers",{}).duplicate()
    result.source_files=Characters.Catalog.source_snapshot(cache)
    result.phases={"families":(families_done-started)/1000.0,"estimates":(estimates_done-families_done)/1000.0,
        "source_files":(Time.get_ticks_usec()-estimates_done)/1000.0}
    result.elapsed_ms=(Time.get_ticks_usec()-started)/1000.0
    result.complete=true

static func poll_plan(data: Dictionary) -> Dictionary:
    if data.plan_task < 0 or not WorkerThreadPool.is_task_completed(data.plan_task): return {}
    WorkerThreadPool.wait_for_task_completion(data.plan_task)
    var completed: Dictionary = data.plan_result
    if not completed.get("complete",false):
        completed.error = "Authored media metadata preparation did not complete; inspect the source error log."
    if completed.has("optional_request"):
        if data.encounter_override.is_empty() and data.plan_pending.is_empty() and data.optional_pending.is_empty():
            data.optional_pending = completed.optional_request
        completed.erase("optional_request")
    data.metadata_ms += completed.get("elapsed_ms",0.0)
    data.metadata_jobs += 1
    data.metadata_phases[completed.get("stage","required")] = completed.get("phases",{})
    data.plan_result = {}
    data.plan_task = -1
    _start_plan(data)
    return completed

static func enqueue(data: Dictionary, path: String, absolute: String) -> void:
    data=physical(data)
    if data.queued.has(path) or data.failed.has(path): return
    if data.resident.has(path) and int(data.resident[path].gpu_bytes)>0 and (not _needs_cpu(data,path) or int(data.resident[path].cpu_bytes) > 0) \
        and (not _fixture(data,path) or data.resident[path].get("fixture_ready",false)): return
    var request={"path":path,"absolute":absolute,"fixture":_fixture(data,path),"pending":true,"required":data.wanted.has(path),"queued_us":Time.get_ticks_usec()}
    data.queued[path]=request
    data.pending.append(request);data.pending_order_dirty=true
    _pending_delta(data,path,1)

static func _adopt_epoch(data: Dictionary, epoch: int) -> void:
    if data.encounter_epoch == epoch: return
    if data.has("consumer_id"):
        var owner=physical(data)
        _withdraw(data)
        data.ready_paths.clear();data.boot_paths.clear();data.boot_waiting.clear()
        owner.consumers[data.consumer_id]=_consumer_record(data)
        for path in owner.resident:_refresh_consumer(owner,owner.consumers[data.consumer_id],path)
    data.encounter_epoch = epoch
    data.encounter = data.encounter_override; data.required_plan = false
    data.boot_started = false; data.boot_complete = false
    data.source_sizes = {}

static func adopt_required(data: Dictionary, epoch: int) -> void:
    # Exact readiness and its startup pins do not depend on optional estimates.
    _adopt_epoch(data,epoch)
    data.required_plan = true

static func adopt_source_sizes(data: Dictionary, sizes: Dictionary, epoch: int) -> void:
    _adopt_epoch(data,epoch)
    for path in sizes:
        data.source_sizes[path]=sizes[path]
        _source_size(physical(data),path,int(sizes[path]))

static func adopt_encounter(data: Dictionary, encounter: Dictionary, epoch: int) -> void:
    # Only accepted immutable metadata becomes a consumer's optional family.
    _adopt_epoch(data,epoch)
    data.encounter = encounter if data.encounter_override.is_empty() else data.encounter_override

static func _hint_roles(data:Dictionary,path:String)->Dictionary:
    if not data.has("physical") or data.wanted.has(path):return {}
    var hint:Dictionary=data.physical.consumers.get(data.consumer_id,{}).get("hint",{})
    return hint if hint.get("paths",{}).has(path) else {}

static func _environment(data: Dictionary, path: String) -> bool:
    if not data.has("physical"):return data.interests.has(path) and data.interests[path][4]>0
    return data.environment.has(path) or _hint_roles(data,path).get("environment",{}).has(path)

static func _fixture(data: Dictionary, path: String) -> bool:
    if not data.has("physical"):return data.interests.has(path) and data.interests[path][3]>0
    return data.fixtures.has(path) or _hint_roles(data,path).get("fixtures",{}).has(path)

static func _estimate(data: Dictionary, path: String) -> int:
    var estimate: Dictionary = data.encounter.get("estimates",{}).get(path,{})
    if estimate.has("bytes"): return int(estimate.bytes)
    if data.source_sizes.has(path):
        return int(data.source_sizes[path])*(2 if _needs_cpu(data,path) else 1)
    if data.resident.has(path): return int(data.resident[path].bytes)
    return -1

static func _pinned(data: Dictionary, path: String) -> bool:
    return data.wanted.has(path) or data.preload_selected.has(path)

static func _cpu_pinned(data:Dictionary,path:String)->bool:
    return _pinned(data,path) and _needs_cpu(data,path)

static func _pinned_bytes(data:Dictionary,path:String,resident:Dictionary)->int:
    if not _pinned(data,path):return 0
    return int(resident.gpu_bytes)+(int(resident.cpu_bytes) if _needs_cpu(data,path) else 0)

static func _requested(data:Dictionary,path:String)->bool:
    if data.wanted.has(path):return true
    if not data.preload_selected.has(path):return false
    # Reference retirement is bounded, but withdrawn preview intent stops new
    # decode work immediately. Another consumer of that source still wins.
    for row in data.families:
        if row.users>0 and row.family.get("paths",{}).has(path):return true
    return false

static func _invalidate(data: Dictionary) -> void:
    physical(data).stats.clear()

static func _pending_delta(data: Dictionary, path: String, amount: int) -> void:
    if not data.stats.is_empty(): data.stats[_environment(data,path)].pending += amount

static func _resident_delta(data: Dictionary, path: String, resident: Dictionary, amount: int) -> void:
    if data.stats.is_empty(): return
    var row: Dictionary = data.stats[resident.get("environment",false)]
    row.resident_sheets += amount
    row.estimated_bytes += amount*int(resident.bytes)
    row.cpu_bytes += amount*int(resident.cpu_bytes)
    row.gpu_estimated_bytes += amount*int(resident.gpu_bytes)
    row.pinned_bytes += amount*_pinned_bytes(data,path,resident)

static func _refresh_path(data: Dictionary, path: String) -> void:
    if data.has("physical"):
        _refresh_consumer(data.physical,data.physical.consumers[data.consumer_id],path)
        return
    var available = false
    if not data.failed.has(path) and data.resident.has(path):
        var resident: Dictionary = data.resident[path]
        available = int(resident.gpu_bytes)>0 and (not _needs_cpu(data,path) or int(resident.cpu_bytes)>0) \
            and (not _fixture(data,path) or resident.get("fixture_ready",false))
    _refresh_readiness(data,path,available)
    for consumer in data.consumers.values():_refresh_consumer(data,consumer,path)

static func _consumer_requirements(consumer:Dictionary,path:String,resident:Dictionary)->int:
    return _consumer_requirements_with_hint(consumer,path,resident,consumer.hint)

static func _consumer_requirements_with_hint(consumer:Dictionary,path:String,resident:Dictionary,offered:Dictionary)->int:
    var hint:Dictionary=offered if not consumer.paths.has(path) and offered.get("paths",{}).has(path) else {}
    var roles:Dictionary=consumer if hint.is_empty() else hint
    var fixture:bool=roles.get("fixtures",{}).has(path)
    var cpu:bool=fixture or roles.get("environment",{}).has(path) or roles.get("cpu_required",{}).has(path)
    if not cpu:
        cpu=not roles.get("gpu_only",{}).has(path) and (not hint.is_empty() or resident.get("cpu_required",true))
    return int(cpu)|(int(fixture)<<1)

static func _refresh_consumer(owner:Dictionary,consumer:Dictionary,path:String)->void:
    var available:bool=_consumer_available(owner,consumer,path)
    if available:consumer.ready_paths[path]=true
    else:consumer.ready_paths.erase(path)
    if consumer.boot_paths.has(path):
        if available or owner.failed.has(path):consumer.boot_waiting.erase(path)
        else:consumer.boot_waiting[path]=true

static func _consumer_available(owner:Dictionary,consumer:Dictionary,path:String)->bool:
    var resident:Dictionary=owner.resident.get(path,{})
    if owner.failed.has(path) or resident.is_empty():return false
    var requirements:int=_consumer_requirements(consumer,path,resident)
    return int(resident.gpu_bytes)>0 and ((requirements&1)==0 or int(resident.cpu_bytes)>0) \
        and ((requirements&2)==0 or resident.get("fixture_ready",false))

static func _refresh_readiness(data:Dictionary,path:String,available:bool)->void:
    if available: data.ready_paths[path] = true
    else: data.ready_paths.erase(path)
    if not data.boot_complete and data.boot_paths.has(path):
        if available or data.failed.has(path): data.boot_waiting.erase(path)
        else: data.boot_waiting[path] = true
    if not data.has("physical") and data.preload_selected.has(path):
        if available: data.selected_ready[path] = true
        else: data.selected_ready.erase(path)
        if data.failed.has(path): data.selected_failed[path] = data.failed[path]
        else: data.selected_failed.erase(path)

static func _refresh_resident_role(data: Dictionary, path: String, selected_refresh:bool=false,refresh_readiness:bool=true) -> void:
    if not data.resident.has(path):
        # Selection changes also update missing/failed source readiness. Keep
        # the original domain for unrelated nonresident role-only updates.
        if selected_refresh and refresh_readiness:_refresh_path(data,path)
        return
    var resident: Dictionary = data.resident[path]
    if resident.environment!=_environment(data,path):
        _resident_delta(data,path,resident,-1)
        resident.environment = _environment(data,path)
        _resident_delta(data,path,resident,1)
    if _cpu_pinned(data,path):resident.cpu_required=true
    if int(resident.cpu_bytes)>0 and not _needs_cpu(data,path) and not resident.cpu_required:data.cpu_release[path]=true
    else:data.cpu_release.erase(path)
    if refresh_readiness:_refresh_path(data,path)

static func source_record(paths:Dictionary,environment:Dictionary={},fixtures:Dictionary={},gpu_only:Dictionary={},cpu_required:Dictionary={})->Dictionary:
    # The source selector owns this immutable contribution. A consumer retains
    # its reference until that selection changes, rather than comparing five
    # flattened maps again whenever another action arrives.
    var roles:Dictionary={}
    for path in paths:
        var cpu:bool=environment.has(path) or fixtures.has(path) or cpu_required.has(path) or not gpu_only.has(path)
        var row:Array=[paths[path] if paths[path] is String else Characters.Catalog.media_path(path),int(cpu),int(fixtures.has(path)),int(environment.has(path))]
        row.make_read_only();roles[path]=row
    roles.make_read_only()
    var result:Dictionary={"roles":roles};result.make_read_only()
    return result

static func _record_changes(changes:Dictionary,record:Dictionary,amount:int)->void:
    for path in record.roles:
        var role:Array=record.roles[path]
        if not changes.has(path):changes[path]=[role[0],0,0,0,0]
        var delta:Array=changes[path]
        delta[1]+=amount
        for index in range(1,4):delta[index+1]+=amount*int(role[index])

static func _consumer_role_mask(counts:Array)->int:
    return int(counts[0]>0)|(int(counts[1]>0)<<1)|(int(counts[2]>0)<<2)|(int(counts[3]>0)<<3)

static func demand_records(data:Dictionary,records:Array,hint:Dictionary={},later_families:Array=[])->void:
    var started=Time.get_ticks_usec()
    var owner=physical(data)
    assert(not data.closed,"Closed source consumer cannot publish demand")
    var before:Dictionary=owner.consumers[data.consumer_id]
    var changed:Dictionary={}
    var hint_changed:Dictionary={}
    var changes:Dictionary={}
    var added:int=0;var removed:int=0;var retained:int=0;var role_entries_visited:int=0
    if is_same(before.records,records):retained=records.size()
    else:
        var next_ids:Dictionary={};var next_unkeyed:Array=[]
        var previous_ids:Dictionary=before.record_ids
        var previous_unkeyed:Array=before.record_unkeyed
        var additions:Array=[]
        for record in records:
            var kept:bool
            if record.has("source_id"):
                next_ids[record.source_id]=record
                kept=is_same(previous_ids.get(record.source_id),record)
            else:
                next_unkeyed.append(record)
                kept=previous_unkeyed.any(func(previous):return is_same(previous,record))
            if kept:retained+=1
            else:additions.append(record)
        for record in before.records:
            var kept:bool=is_same(next_ids.get(record.source_id),record) if record.has("source_id") else next_unkeyed.any(func(current):return is_same(current,record))
            if not kept:_record_changes(changes,record,-1);removed+=1;role_entries_visited+=record.roles.size()
        for record in additions:
            _record_changes(changes,record,1);added+=1;role_entries_visited+=record.roles.size()
        before.record_ids=next_ids
        before.record_unkeyed=next_unkeyed
    var record_delta_done:int=Time.get_ticks_usec()
    for path in changes:
        var delta:Array=changes[path]
        if delta[1]==0 and delta[2]==0 and delta[3]==0 and delta[4]==0:continue
        var counts:Array=before.record_roles.get(path,[0,0,0,0])
        var previous:int=_consumer_role_mask(counts)
        counts[0]+=int(delta[1]);counts[1]+=int(delta[2]);counts[2]+=int(delta[3]);counts[3]+=int(delta[4])
        var current:int=_consumer_role_mask(counts)
        # Contribution counts still balance every owner. Retained Boolean
        # roles already publish exactly this physical/consumer contract.
        if previous==current:continue
        if counts[0]>0:
            before.record_roles[path]=counts;before.paths[path]=delta[0]
            if counts[1]>0:before.cpu_required[path]=true
            else:before.cpu_required.erase(path)
            if counts[2]>0:before.fixtures[path]=true
            else:before.fixtures.erase(path)
            if counts[3]>0:before.environment[path]=true
            else:before.environment.erase(path)
            if counts[1]==0:before.gpu_only[path]=true
            else:before.gpu_only.erase(path)
        else:
            before.record_roles.erase(path)
            for field in ["paths","environment","fixtures","gpu_only","cpu_required"]:before[field].erase(path)
        _change_interest(owner,path,delta[0],[previous&1,0,(previous>>1)&1,(previous>>2)&1,(previous>>3)&1],
            [current&1,0,(current>>1)&1,(current>>2)&1,(current>>3)&1],true)
        changed[path]=true
    before.records=records
    if not is_same(before.hint,hint) and (not before.hint.get("paths",{}).is_empty() or not hint.get("paths",{}).is_empty()):
        # Optional readiness belongs to its queried path, not the whole hint
        # catalog. Only explicit startup gates also retain eager readiness.
        for path in before.boot_paths:
            if before.paths.has(path) or changed.has(path) or not owner.resident.has(path):continue
            var resident:Dictionary=owner.resident[path]
            if _consumer_requirements_with_hint(before,path,resident,before.hint)!=_consumer_requirements_with_hint(before,path,resident,hint):hint_changed[path]=true
    var required_done=Time.get_ticks_usec()
    if not is_same(before.family,data.encounter):
        _family_interest(owner,before.family,-1);_family_interest(owner,data.encounter,1)
    if not is_same(before.hint,hint):
        _family_interest(owner,before.hint,-1);_family_interest(owner,hint,1,true)
    for family in before.later_families:
        if not later_families.any(func(current):return is_same(current,family)):_family_interest(owner,family,-1)
    for family in later_families:
        if not before.later_families.any(func(previous):return is_same(previous,family)):_family_interest(owner,family,1)
    before.family=data.encounter;before.hint=hint;before.host=data.get("host")
    before.later_families=later_families.duplicate()
    data.wanted=before.paths;data.environment=before.environment;data.fixtures=before.fixtures;data.gpu_only=before.gpu_only;data.cpu_required=before.cpu_required
    if owner.consumers.size()==1 and owner.budget_bytes!=data.budget_bytes:
        owner.budget_bytes=data.budget_bytes;owner.selection_revision+=1
    var families_done=Time.get_ticks_usec()
    _update_pending(owner)
    var pending_done=Time.get_ticks_usec()
    data.preload_selected=owner.preload_selected
    if (data.required_plan or not data.encounter.is_empty()) and not data.boot_started:
        data.boot_started=true;data.boot_paths.merge(before.paths)
        changed.merge(before.paths)
    for path in changed:_refresh_path(owner,path)
    # A hint changes only this consumer's readiness operands. Physical role
    # accounting follows its retained family in the existing optional lane.
    for path in hint_changed:
        if not changed.has(path):_refresh_consumer(owner,before,path)
    data.demand_runs+=1
    if changed.is_empty() and hint_changed.is_empty():data.demand_noops+=1
    data.demand_counts={"required":before.paths.size(),"affected":changed.size()+hint_changed.size(),"consumers":owner.consumers.size(),
        "records_added":added,"records_removed":removed,"records_retained":retained,"source_roles_visited":changes.size(),"source_role_entries_visited":role_entries_visited}
    data.demand_phases={"required":(required_done-started)/1000.0,"record_delta":(record_delta_done-started)/1000.0,"interest_updates":(required_done-record_delta_done)/1000.0,"family_handoff":(families_done-required_done)/1000.0,
        "pending":(pending_done-families_done)/1000.0,"readiness":(Time.get_ticks_usec()-pending_done)/1000.0,"total":(Time.get_ticks_usec()-started)/1000.0}
    if not data.optional_pending.is_empty():_start_plan(data,true)

static func demand(data: Dictionary, paths: Dictionary, environment: Dictionary = {}, fixtures: Dictionary = {}, gpu_only: Dictionary = {}, cpu_required: Dictionary = {}, hint: Dictionary = {}) -> void:
    # Compatibility for metadata fixtures and direct source-owner consumers.
    # Production Play publishes selector-owned contribution references.
    demand_records(data,[source_record(paths,environment,fixtures,gpu_only,cpu_required)] if not paths.is_empty() else [],hint)

static func fixture_facts(decoded:Image)->Dictionary:
    var reduced:Image=decoded.duplicate()
    reduced.srgb_to_linear()
    reduced.premultiply_alpha()
    reduced.convert(Image.FORMAT_RGBAF)
    reduced.resize(1,1,Image.INTERPOLATE_TRILINEAR)
    var weight:float=0.0
    var moment:Vector2=Vector2.ZERO
    for y in range(decoded.get_height()):
        for x in range(decoded.get_width()):
            var colour:Color=decoded.get_pixel(x,y)
            var amount:float=colour.srgb_to_linear().get_luminance()*colour.a
            weight+=amount;moment+=Vector2(x+.5,y+.5)*amount
    return {"energy":reduced.get_pixel(0,0).get_luminance(),
        "emission_centroid":moment/weight if weight>0 else Vector2(decoded.get_width(),decoded.get_height())*.5}

static func _decode(request: Dictionary, result: Dictionary) -> void:
    var started = Time.get_ticks_usec()
    result.worker_clock_us={"queued":request.get("queued_us",started),"dispatched":request.get("dispatched_us",started),"started":started}
    result.path = request.path
    if not FileAccess.file_exists(request.absolute):
        result.error = "Missing authored image: " + request.path
        return
    var decoded = Image.new()
    var error = decoded.load(request.absolute)
    if error != OK or decoded.is_empty():
        result.error = "Cannot decode authored image: " + request.path + " (" + error_string(error) + ")"
        return
    var loaded:int=Time.get_ticks_usec()
    result.worker_clock_us.loaded=loaded
    result.image = decoded
    result.cpu_bytes = decoded.get_data_size()
    # Explicit estimate, not measured VRAM: an RGB PNG can have RGBA storage.
    result.gpu_bytes = decoded.get_width() * decoded.get_height() * 4
    var accounted:int=Time.get_ticks_usec()
    if request.get("fixture",false):
        # Stable authored frames carry their exact offline measurements. New
        # fixture sources retain the same worker reduction until the next bake.
        var facts:Dictionary=request.get("fixture_facts",{})
        if facts.is_empty():facts=fixture_facts(decoded)
        result.energy=facts.energy;result.emission_centroid=facts.emission_centroid

    var reduced:int=Time.get_ticks_usec()
    result.elapsed_ms = (reduced-started)/1000.0
    result.phases_ms={"load":(loaded-started)/1000.0,"accounting":(accounted-loaded)/1000.0,"fixture":(reduced-accounted)/1000.0}
    var maximum:int=request.get("maximum_texture_size",0)
    if maximum>0 and (decoded.get_width()>maximum or decoded.get_height()>maximum):
        result.error="Authored image exceeds GPU texture limit (%d×%d > %d): %s"%[decoded.get_width(),decoded.get_height(),maximum,request.path]
        return
    if request.get("worker_upload",false):
        # RenderingDevice permits asynchronous creation of a new texture. This
        # resource is private until its completed image crosses the batch
        # mailbox; never mutate a published texture or touch the SceneTree.
        var upload_started:int=Time.get_ticks_usec()
        result.worker_clock_us.upload_started=upload_started
        result.texture=ImageTexture.create_from_image(decoded)
        result.worker_clock_us.upload_finished=Time.get_ticks_usec()
        result.worker_upload_ms=(result.worker_clock_us.upload_finished-upload_started)/1000.0
        if result.texture==null:result.error="Cannot create authored texture: "+request.path
    result.complete = true

static func _decode_batch(requests:Array, result:Dictionary)->void:
    # One finite task keeps its existing worker busy between scene frames.
    # Eight required workers each own at most two unpublished images: the
    # original sixteen-image bound. Optional work stays four single-image jobs
    # so idle reuse cannot occupy more CPU or queue a long speculative batch.
    for request in requests:
        var image:Dictionary={}
        _decode(request,image)
        # Each image is complete and immutable after this handoff. A fast
        # urgent source need not wait for the remaining PNGs in its batch.
        result.mutex.lock()
        result.images.append(image)
        result.mutex.unlock()

static func poll(data: Dictionary, required_only: bool = false, publish:bool=true) -> Dictionary:
    if data.get("closed",false):return {}
    if not required_only:prepare_optional(data)
    elif not physical(data).due_paths.is_empty() and physical(data).families.any(func(row):return row.hint and row.users>0 and row.cursor<row.paths.size()):prepare_optional(data,true)
    return poll_sources(data,required_only,publish)

static func poll_sources(data: Dictionary, required_only: bool = false, publish:bool=true) -> Dictionary:
    # Receipt of an already prepared source has no dependency on optional
    # library selection. Play services that existing maintenance owner in its
    # optional lane; the legacy poll entry point above keeps tool semantics.
    if data.get("closed",false):return {}
    data=physical(data)
    var completed: Dictionary = {}
    var next = -1
    var next_priority=3
    var next_image=-1
    # An unfinished finite batch still owns its worker slot, even when every
    # completed member has already been consumed. Only join completed tasks.
    for i in range(data.decode_jobs.size()-1,-1,-1):
        var job:Dictionary=data.decode_jobs[i]
        if not job.result.has("mutex"):continue
        if not job.get("joined",false) and WorkerThreadPool.is_task_completed(job.task):
            WorkerThreadPool.wait_for_task_completion(job.task);job.joined=true
        if job.get("joined",false) and job.result.images.is_empty():data.decode_jobs.remove_at(i)
    for i in data.decode_jobs.size():
        var job: Dictionary = data.decode_jobs[i]
        if job.result.has("mutex"):
            job.result.mutex.lock()
            for member in job.result.images.size():
                var priority:int=_decode_priority(data,job.result.images[member].path)
                if priority<next_priority:next=i;next_image=member;next_priority=priority
                if priority==0:break
            job.result.mutex.unlock()
            if next_priority==0:break
            continue
        if not job.get("joined",false) and not WorkerThreadPool.is_task_completed(job.task): continue
        var priority=2
        for path in job.get("paths",[job.path]):priority=mini(priority,_decode_priority(data,path))
        if priority<next_priority:next=i;next_image=-1;next_priority=priority
        if priority==0:break
    _order_pending(data)
    var cancelled:int=0
    var pending_priority:int=2
    while not data.pending.is_empty():
        var request:Dictionary=data.pending[0]
        pending_priority=_decode_priority(data,request.path)
        if pending_priority==2 or _requested(data,request.path):break
        # Withdrawn optional intent can retain a bounded accounting lease. It
        # cannot claim an urgent worker slot after its actual caller is gone.
        data.pending.pop_front();data.queued.erase(request.path);_pending_delta(data,request.path,-1)
        cancelled+=1
        if cancelled>=OPTIONAL_UPDATES_PER_FRAME:pending_priority=2;break
    var blocked_required:bool=required_only and data.decode_jobs.size()>=DECODE_WORKERS and not data.pending.is_empty() and pending_priority<2
    if next_priority==2 and required_only and not blocked_required:next=-1
    if next>=0 and publish:
        var job: Dictionary = data.decode_jobs[next]
        if job.result.has("mutex"):
            job.result.mutex.lock()
            completed=job.result.images.pop_at(next_image)
            job.result.mutex.unlock()
            job.paths.erase(completed.path)
            if not job.paths.is_empty():job.path=job.paths[0]
            if job.get("joined",false) and job.paths.is_empty():data.decode_jobs.remove_at(next)
        else:
            if not job.get("joined",false):
                WorkerThreadPool.wait_for_task_completion(job.task)
                job.joined=true
            if job.result.has("images"):
                # A newly due member wins even inside an already completed batch.
                var index:int=0
                var image_priority=3
                for i in job.result.images.size():
                    var priority:int=_decode_priority(data,job.result.images[i].path)
                    if priority<image_priority:index=i;image_priority=priority
                    if priority==0:break
                completed=job.result.images.pop_at(index)
                job.paths.erase(completed.path)
                if job.result.images.is_empty():data.decode_jobs.remove_at(next)
                else:job.path=job.paths[0]
            else:
                # Existing single-image jobs use the same publication contract.
                completed=job.result
                data.decode_jobs.remove_at(next)
        _pending_delta(data,completed.path,-1)
        data.queued.erase(completed.path)
        data.decoded += 1
        data.decode_ms += completed.get("elapsed_ms",0.0)
        if not completed.has("image") and not completed.has("error"):
            completed.error = "Authored image preparation did not complete: " + completed.path
        if not _requested(data,completed.path): completed = {}
        elif completed.has("error"):
            data.failed[completed.path] = completed.error
            _refresh_path(data,completed.path)
    while not data.pending.is_empty() and data.decode_jobs.size()<DECODE_WORKERS and cancelled<OPTIONAL_UPDATES_PER_FRAME:
        var batch_priority:int=_decode_priority(data,data.pending[0].path)
        var worker_limit:int=DECODE_WORKERS if batch_priority<2 else OPTIONAL_DECODE_WORKERS
        if data.decode_jobs.size()>=worker_limit:break
        var remaining_workers:int=worker_limit-data.decode_jobs.size()
        var batch_limit:int=mini(DECODE_BATCH_IMAGES,maxi(1,int(ceil(float(data.pending.size())/remaining_workers))))
        var requests:Array=[]
        while not data.pending.is_empty() and requests.size()<batch_limit:
            var request:Dictionary=data.pending[0]
            if not _requested(data,request.path):
                data.pending.pop_front();data.queued.erase(request.path);_pending_delta(data,request.path,-1)
                cancelled+=1
                if cancelled>=OPTIONAL_UPDATES_PER_FRAME:break
                continue
            if not requests.is_empty() and _decode_priority(data,request.path)!=batch_priority:break
            data.pending.pop_front();request.pending=false
            request.maximum_texture_size=data.maximum_texture_size
            request.dispatched_us=Time.get_ticks_usec()
            if request.fixture:request.fixture_facts=Characters.Catalog.fixture_optics().get(request.path,{})
            request.worker_upload=data.worker_upload and not data.resident.has(request.path)
            requests.append(request)
            if batch_priority==2:break
        if requests.is_empty():break
        var result: Dictionary = {"images":[],"mutex":Mutex.new()}
        var task = WorkerThreadPool.add_task(_decode_batch.bind(requests,result),false,"Authored PNG preparation")
        data.decode_jobs.append({"task":task,"path":requests[0].path,"paths":requests.map(func(request):return request.path),"result":result})
        if cancelled>=OPTIONAL_UPDATES_PER_FRAME:break
    return completed

static func validate_upload_dimensions(data:Dictionary,loaded:Dictionary,maximum:int)->void:
    data=physical(data)
    if maximum<=0 or loaded.has("error"):return
    var size:Vector2i=loaded.image.get_size()
    if size.x<=maximum and size.y<=maximum:return
    loaded.error="Authored image exceeds GPU texture limit (%d×%d > %d): %s"%[size.x,size.y,maximum,loaded.path]
    data.failed[loaded.path]=loaded.error
    _refresh_path(data,loaded.path)

static func published(data: Dictionary, loaded: Dictionary) -> void:
    data=physical(data)
    var used_cpu:bool=data.resident.get(loaded.path,{}).get("cpu_required",false) or _needs_cpu(data,loaded.path)
    if data.resident.has(loaded.path): _resident_delta(data,loaded.path,data.resident[loaded.path],-1)
    data.resident[loaded.path] = {"bytes":int(loaded.cpu_bytes)+int(loaded.gpu_bytes),
        "cpu_bytes":int(loaded.cpu_bytes),"gpu_bytes":int(loaded.gpu_bytes),
        "cpu_required":used_cpu,"environment":_environment(data,loaded.path),
        "fixture_ready":loaded.has("energy") and loaded.has("emission_centroid"),"used":Time.get_ticks_msec()}
    _source_size(data,loaded.path,int(loaded.gpu_bytes))
    if not used_cpu and not _needs_cpu(data,loaded.path): data.cpu_release[loaded.path] = true
    _resident_delta(data,loaded.path,data.resident[loaded.path],1)
    _refresh_path(data,loaded.path)
    # External publication can satisfy one queued original without changing
    # demand or optional priority. Remove only that pending request; an active
    # worker retains its queued ownership until its ordinary completion.
    if data.ready_paths.has(loaded.path) and data.queued.has(loaded.path):
        for i in range(data.pending.size()-1,-1,-1):
            if data.pending[i].path!=loaded.path:continue
            _pending_delta(data,loaded.path,-1)
            data.pending.remove_at(i)
            data.queued.erase(loaded.path)
    # A decode request captures its fixture role before entering the worker.
    # If a newer accepted demand upgrades that role while decoding, its colour
    # may publish first but cannot satisfy readiness without emission metrics.
    # Queue the missing preprocessing immediately; the stable scene plan need
    # not be requested again to recover from this one in-flight role change.
    if _pinned(data,loaded.path) and _fixture(data,loaded.path) and not data.resident[loaded.path].fixture_ready \
        and not data.queued.has(loaded.path) and not data.failed.has(loaded.path):
        var absolute: String = data.wanted.get(loaded.path,data.preload_selected.get(loaded.path,""))
        enqueue(data,loaded.path,absolute)
        _order_pending(data)

static func _needs_cpu(data: Dictionary, path: String) -> bool:
    # Original colour is needed for picking; environment/fixture preparation
    # retains its existing CPU contract. Only exact registered companions opt out.
    if data.has("physical"):
        return (_consumer_requirements(data.physical.consumers[data.consumer_id],path,data.resident.get(path,{}))&1)!=0
    if data.interests.has(path):return data.interests[path][2]>0
    return data.resident.get(path,{}).get("cpu_required",true)

static func ready(data: Dictionary, paths: Dictionary) -> bool:
    if data.get("closed",false):return false
    var owner:Dictionary=physical(data)
    var consumer:Dictionary=owner.consumers[data.consumer_id] if data.has("physical") else {}
    var keys:Array=paths.keys()
    # The consumer's published roles already maintain this exact ready set.
    # Use the native set operation for admitted demand, rather than revisiting
    # every CPU/fixture operand in GDScript on each frame. Unowned hint queries
    # still need their separate role projection below.
    if consumer.is_empty() or consumer.paths.has_all(keys):return data.ready_paths.has_all(keys)
    for path in paths:
        if not consumer.is_empty() and not consumer.paths.has(path):
            if not _consumer_available(owner,consumer,path):return false
        elif not data.ready_paths.has(path):return false
    return true

static func release_cold_images(data: Dictionary, limit: int = CPU_RELEASES_PER_FRAME) -> Array:
    data=physical(data)
    # Required CPU roles gate readiness. Previously used CPU pixels are cache:
    # retain them under budget, including while only the GPU role remains.
    # Never-used GPU companions can shed their decode image immediately.
    var frame:int=Engine.get_process_frames()
    if data.cpu_release_frame!=frame:
        data.cpu_release_frame=frame;data.cpu_released_this_frame=0;data.cpu_released_bytes_this_frame=0
    var remaining:int=limit-data.cpu_released_this_frame if limit>=0 else data.resident.size()
    if remaining<=0:return []
    var stats:Dictionary=_residency_stats(data)
    var bytes:int=stats[false].estimated_bytes+stats[true].estimated_bytes
    if bytes>data.budget_bytes:
        # Use the existing retirement allowance before whole-source GPU eviction.
        # Only a bounded oldest prefix is retained from this pressure-only scan.
        var cold:Array=[];var ages:Array=[]
        for path in data.resident:
            var resident:Dictionary=data.resident[path]
            if int(resident.cpu_bytes)==0 or _cpu_pinned(data,path):continue
            var at:int=cold.size()
            while at>0 and int(resident.used)<int(ages[at-1]):at-=1
            if at>=remaining:continue
            cold.insert(at,path);ages.insert(at,resident.used)
            if cold.size()>remaining:cold.pop_back();ages.pop_back()
        for path in cold:data.cpu_release[path]=true
    var released:Array=[];var examined:Array=[]
    for path in data.cpu_release:
        if released.size()>=remaining:break
        examined.append(path)
        if not data.resident.has(path):continue
        var resident:Dictionary=data.resident[path]
        if int(resident.cpu_bytes)==0 or _cpu_pinned(data,path):continue
        if resident.cpu_required and bytes<=data.budget_bytes:continue
        var size:int=resident.cpu_bytes
        _resident_delta(data,path,resident,-1)
        resident.bytes-=size;resident.cpu_bytes=0;bytes-=size
        _resident_delta(data,path,resident,1)
        _refresh_path(data,path)
        data.cpu_released_bytes_this_frame+=size
        released.append(path)
    for path in examined:data.cpu_release.erase(path)
    data.cpu_released_this_frame+=released.size()
    return released

static func touch(data: Dictionary, path: String) -> void:
    data=physical(data)
    if data.resident.has(path): data.resident[path].used = Time.get_ticks_msec()

static func prune(data: Dictionary, budget: int = -1) -> Array:
    data=physical(data)
    if budget<0: budget = data.budget_bytes
    var frame = Engine.get_process_frames()
    if data.prune_frame != frame: data.prune_frame = frame; data.pruned_this_frame = 0
    if data.pruned_this_frame>=EVICTIONS_PER_FRAME: return []
    var stats = _residency_stats(data)
    var bytes: int = stats[false].estimated_bytes + stats[true].estimated_bytes
    if bytes<=budget: return []
    var pinned:int=stats[false].pinned_bytes+stats[true].pinned_bytes
    if bytes<=pinned:return []
    # Only the oldest remaining release allowance can be used this frame.
    # Keep that bounded prefix while scanning, instead of sorting thousands
    # of cached sheets to discard every result after the first one or two.
    var limit:int=EVICTIONS_PER_FRAME-data.pruned_this_frame
    var cold:Array=[]
    var ages:Array=[]
    var residents:Dictionary=data.resident
    var wanted:Dictionary=data.wanted
    var selected:Dictionary=data.preload_selected
    for path:String in residents:
        if wanted.has(path) or selected.has(path):continue
        var entry:Dictionary=residents[path]
        var used:int=entry.used
        var at:int=cold.size()
        while at>0 and used<int(ages[at-1]):at-=1
        if at>=limit:continue
        cold.insert(at,path);ages.insert(at,used)
        if cold.size()>limit:cold.pop_back();ages.pop_back()
    var removed:Array=[]
    for path in cold:
        if bytes<=budget:break
        bytes-=int(data.resident[path].bytes)
        removed.append(path)
    for path in removed:
        _resident_delta(data,path,data.resident[path],-1)
        data.resident.erase(path)
        _refresh_path(data,path)
        data.evicted += 1
    data.pruned_this_frame += removed.size()
    return removed

static func _residency_stats(data: Dictionary) -> Dictionary:
    data=physical(data)
    if not data.stats.is_empty(): return data.stats
    var stats = {}
    for category in [false,true]:
        stats[category] = {"pending":0,"resident_sheets":0,"estimated_bytes":0,"pinned_bytes":0,"cpu_bytes":0,"gpu_estimated_bytes":0}
    for job in data.decode_jobs:
        for path in job.get("paths",[job.path]):stats[_environment(data,path)].pending += 1
    for request in data.pending:
        stats[_environment(data,request.path)].pending += 1
    for path in data.resident:
        var resident: Dictionary = data.resident[path]
        var row: Dictionary = stats[resident.get("environment",false)]
        row.resident_sheets += 1
        row.estimated_bytes += int(resident.bytes)
        row.cpu_bytes += int(resident.cpu_bytes)
        row.gpu_estimated_bytes += int(resident.gpu_bytes)
        row.pinned_bytes += _pinned_bytes(data,path,resident)
    data.stats.merge(stats)
    return data.stats

static func diagnostics(data: Dictionary, environment: bool = false) -> Dictionary:
    var owner=physical(data)
    var stats = _residency_stats(data)
    var result: Dictionary = stats[environment].duplicate()
    var total: int = stats[false].estimated_bytes+stats[true].estimated_bytes
    var pinned: int = stats[false].pinned_bytes+stats[true].pinned_bytes
    result.merge({"combined_estimated_bytes":total,"pinned_over_budget_bytes":maxi(0,pinned-int(owner.budget_bytes)),
        "eviction_pending_bytes":maxi(0,total-maxi(pinned,int(owner.budget_bytes))),
        "metadata_ms":data.metadata_ms,"metadata_jobs":data.metadata_jobs,"metadata_optional_pending":not data.optional_pending.is_empty(),"metadata_phases":data.metadata_phases.duplicate(),"publication":owner.publication.duplicate(),"decode_ms":owner.decode_ms,
        "decode_jobs":owner.decode_jobs.size(),"decode_worker_limit":DECODE_WORKERS,
        "cpu_release_pending":owner.cpu_release.size(),"cpu_released_this_frame":owner.cpu_released_this_frame,"cpu_released_bytes_this_frame":owner.cpu_released_bytes_this_frame,
        "budget_bytes":owner.budget_bytes,"demand_runs":data.demand_runs,"demand_noops":data.demand_noops,"demand_phases":data.demand_phases.duplicate(),"demand_counts":data.demand_counts.duplicate(),"selection_jobs":owner.selection_jobs,"decoded":owner.decoded,"evicted":owner.evicted,"failed":owner.failed.duplicate(),
        "consumers":owner.consumers.size(),"selection_pending":owner.selection_task>=0 or (not owner.selection_publication.is_empty() and owner.selection_publication.cursor<owner.selection_publication.paths.size()) or _families_pending(owner) or not owner.changed_paths.is_empty(),"source_revision":owner.source_revision,
        "accounting":"Decoded CPU bytes plus conservative RGBA8 GPU estimate; not measured VRAM/RSS; combined environment and character budget."})
    return result

static func boot_ready(data: Dictionary) -> bool:
    if data.boot_complete: return true
    if not data.boot_started or not data.boot_waiting.is_empty(): return false
    data.boot_complete = true
    return true

static func preload_progress(data: Dictionary) -> Dictionary:
    var owner=physical(data)
    return {"selected":owner.preload_selected.size(),"ready":owner.selected_ready.size(),"failed":owner.selected_failed.duplicate(),
        "startup_required":data.boot_paths.size(),"startup_ready":data.boot_paths.size()-data.boot_waiting.size(),
        "skipped":owner.preload_skipped,"selected_estimated_bytes":owner.preload_estimated_bytes,
        "required_estimated_bytes":owner.required_estimated_bytes,"required_unknown_estimates":owner.unknown_required,
        "budget_bytes":owner.budget_bytes,"errors":data.encounter.get("errors",[]),
        "scope":"Authored families from displayed state and the bounded already-received operation window; no future-state publication."}

static func _drawable(actor: Dictionary) -> bool:
    return actor.get("present",true) and actor.get("last_visual_position") != null \
        and actor.get("spatial_disposition","present") == "present" and actor.get("remains_disposition","intact") != "disintegrated"

static func _actor_base(actor: Dictionary, clips: Array, cache: Dictionary, errors: Array) -> Dictionary:
    if not _drawable(actor): return {}
    var wanted = clips.duplicate()
    var rigs: Dictionary = Characters.rigs(cache)
    var rig = Characters.rig_id(actor,cache)
    if not rigs.has(rig):
        errors.append("No authored rig for actor " + str(actor.get("uuid")))
        return {}
    var rest = Characters.rest_sample(actor,rigs[rig],cache)
    if not rest.ok: errors.append(rest.error.message); return {}
    if rest.value.clip not in wanted: wanted.append(rest.value.clip)
    # An admitted condition may select both resting and locomotion sources.
    # Prepare that finite closure together, before its first movement; actor
    # tracks still name the exact clip for attack/jump/hit/death independently.
    for activity in ["idle","move"]:
        var pose=Conditions.ConditionPose.select(actor,rig,activity,cache)
        if not pose.is_empty() and pose.clip not in wanted: wanted.append(pose.clip)
    var resolved = Characters.sheet_paths(actor,wanted,cache)
    if not resolved.ok: errors.append(resolved.error.message); return {}
    var effects:Dictionary=Conditions.paths(actor,cache)
    # This finite result selects artwork independently of native optical CPU
    # retention. The current/previous packet owns it under the same source proof.
    for field in ["value","gpu_only","cpu_required","geometry_slots","normal_sets"]:
        resolved[field].make_read_only()
    resolved.make_read_only();effects.make_read_only()
    var records:Dictionary={}
    var effect_record:Dictionary=source_record(effects) if not effects.is_empty() else {}
    for profile in CharacterGeometry.PROFILES:
        var selected:Array=resolved.source_records[profile].duplicate()
        if not effect_record.is_empty():selected.append(effect_record)
        selected.make_read_only();records[profile]=selected
    records.make_read_only()
    var base={"resolved":resolved,"effects":effects,"source_records":records};base.make_read_only()
    return base

static func _add_actor_base(paths: Dictionary, base: Dictionary, cache: Dictionary,
        gpu_only: Dictionary, cpu_required: Dictionary, native_optics: bool,
        optical_candidates: Dictionary, normal_sets: Dictionary) -> void:
    if base.is_empty():return
    var resolved:Dictionary=base.resolved
    paths.merge(resolved.value)
    normal_sets.merge(resolved.get("normal_sets",{}))
    gpu_only.merge(resolved.gpu_only)
    cpu_required.merge(resolved.cpu_required)
    for path in resolved.geometry_slots:
        if not native_optics and optical_candidates.has(path):continue
        var optical:Dictionary=NativeSupport.required_paths(path,resolved.geometry_slots[path],cache)
        var optical_cpu:Dictionary=NativeSupport.cpu_required_paths(path,resolved.geometry_slots[path],cache,true) if native_optics else {}
        for optical_path in optical.values():
            # A native tail may overlap the next ordinary movement. Prepare
            # metadata for that clip's support masks, without demanding/uploading
            # them unless the real native renderer actually needs them.
            optical_candidates[optical_path]=true
            if native_optics:
                paths[optical_path]=true
                if optical_cpu.has(optical_path):cpu_required[optical_path]=true
                elif not cpu_required.has(optical_path):gpu_only[optical_path]=true
    paths.merge(base.effects);cpu_required.merge(base.effects)

static func _add_actor(paths: Dictionary, actor: Dictionary, clips: Array, cache: Dictionary, errors: Array, gpu_only: Dictionary, cpu_required: Dictionary, native_optics:bool=false, optical_candidates:Dictionary={}, normal_sets:Dictionary={}) -> void:
    _add_actor_base(paths,_actor_base(actor,clips,cache,errors),cache,gpu_only,cpu_required,native_optics,optical_candidates,normal_sets)

static func _witness(witnesses: Dictionary, id: String, actor: Dictionary) -> void:
    if not witnesses.has(id): witnesses[id] = []
    # A long movement lineage can have one full actor after-value per cell.
    # Position/HP changes do not create new outfits; never cross-product all
    # those occurrences with every track just to request the same Run PNG.
    for prior in witnesses[id]:
        if prior.get("creature_content_ref") == actor.get("creature_content_ref") \
            and prior.appearance == actor.appearance and prior.visual_loadout == actor.visual_loadout \
            and prior.life_state == actor.life_state and prior.get("conditions",[])==actor.get("conditions",[]) and _drawable(prior) == _drawable(actor): return
    witnesses[id].append(actor)

static func _actor_selector(actor:Dictionary,cache:Dictionary={})->Array:
    # Physical source identity belongs to admitted layer Resources. UUID, tint,
    # portrait and transform never distinguish a sheet or its optical metadata.
    var id:String=Characters.rig_id(actor,cache)
    var rigs:Dictionary=Characters.rigs(cache)
    if not rigs.has(id):return [id,_drawable(actor)]
    var selected:Dictionary=Characters._select_layers(actor,rigs[id],id==Characters.BodySources.index(cache).root_rig,cache)
    var references:Array=[]
    if selected.ok:
        for layer in selected.value:
            var effect:Dictionary=layer.get("effect",{})
            references.append([layer.source_path,layer.slot,effect.get("sourceSheet"),effect.get("palette",{}).get("noiseSheet")])
    var poses:Array=[]
    for activity in ["idle","move"]:
        var pose:Dictionary=Conditions.ConditionPose.select(actor,id,activity,cache)
        poses.append(pose.get("clip",""))
    return [id,references,actor.life_state,_drawable(actor),poses,Conditions.paths(actor,cache).keys()]

static func _same_actor_selector(a: Array, b: Array) -> bool:
    # Canonical after-values may independently decode the same outfit. These
    # passive values select artwork; their allocation identity is not a source
    # change. The existing owner still validates authored documents separately.
    if a.size()!=b.size():return false
    for index in a.size():
        if not is_same(a[index],b[index]) and a[index]!=b[index]:return false
    return true

static func _same_actor_source_inputs(a:Dictionary,b:Dictionary)->bool:
    # Canonical HP/position after-values retain their immutable source operands.
    # Resolve actual layer paths only when one of those operands changes. This
    # deliberately excludes tint/scale, which cannot select another sheet.
    if a.is_empty() or a.life_state!=b.life_state or _drawable(a)!=_drawable(b) \
        or a.get("creature_content_ref")!=b.get("creature_content_ref"):return false
    var left:Dictionary=a.appearance;var right:Dictionary=b.appearance
    for field in ["presentation_kind","body_category","head_category","has_beard"]:
        if left.get(field)!=right.get(field):return false
    for field in ["visual_loadout","conditions","presentation_layers"]:
        if not a.has(field) and not b.has(field):continue
        if not is_same(a.get(field),b.get(field)):return false
    return true

static func _actor_reuse(cache:Dictionary)->Dictionary:
    var previous:Dictionary=cache.get("__required_actor_closures",{})
    var admitted=Characters.BodySources.index(cache)
    var entries:Array=previous.get("entries",[]) if is_same(previous.get("admission"),admitted) else []
    return {"previous":entries,"current":[],"hits":0,"misses":0,
        "selectors":previous.get("selectors",{}) if is_same(previous.get("admission"),admitted) else {},"selected_actors":{}}

static func _retain_actor_closures(cache:Dictionary,reuse:Dictionary)->void:
    # The immutable admitted revision owns all source selection metadata. No
    # per-action document/root proof or retained whole-catalog scan is needed.
    var entries:Array=reuse.current.duplicate()
    for prior in reuse.previous:
        var base:Dictionary=prior.get("base",{})
        if base.is_empty():continue
        var selected:bool=false
        for current in reuse.current:
            if is_same(current.base,base):selected=true;break
        if not selected:continue
        var retained:bool=false
        for current in entries:
            if is_same(current.base,base) and current.native_optics==prior.native_optics:retained=true;break
        # Native receiver demand changes the optical role, not the selected
        # physical sheets or their immutable metadata. Keep its two finite
        # views while that same base remains selected; no outfit/clip history.
        if not retained:entries.append(prior)
    cache.__required_actor_closures={"admission":Characters.BodySources.index(cache),"entries":entries,
        "selectors":reuse.selected_actors,"hits":reuse.hits,"misses":reuse.misses,"promotions":reuse.get("promotions",0)}

static func _add_actor_once(paths: Dictionary, actor: Dictionary, clips: Array, cache: Dictionary,
        errors: Array, gpu_only: Dictionary, cpu_required: Dictionary, native_optics: bool,
        optical_candidates: Dictionary, normal_sets: Dictionary, requested: Array, reuse: Dictionary = {}) -> void:
    var selector:Array=[]
    for prior in requested:
        if not is_same(prior.actor,actor):continue
        if is_same(prior.paths,paths) and prior.clips==clips:return
        selector=prior.get("selector",[])
    if selector.is_empty():
        var prior:Dictionary=reuse.get("selected_actors",{}).get(actor.uuid,reuse.get("selectors",{}).get(actor.uuid,{}))
        selector=prior.selector if _same_actor_source_inputs(prior.get("actor",{}),actor) else _actor_selector(actor,cache)
    if not reuse.is_empty():reuse.selected_actors[actor.uuid]={"actor":actor,"selector":selector}
    var packet = {}
    var base:Dictionary={}
    for entries in [reuse.get("current",[]),reuse.get("previous",[])]:
        for prior in entries:
            if prior.clips==clips and _same_actor_selector(prior.selector,selector):
                if prior.native_optics==native_optics:
                    packet=prior; break
                if base.is_empty():base=prior.get("base",{})
        if not packet.is_empty(): break
    if packet.is_empty():
        packet={"id":actor.uuid,"selector":selector,"clips":clips.duplicate(),"native_optics":native_optics,
            "paths":{},"gpu_only":{},"cpu_required":{},"optical_candidates":{},"normal_sets":{}}
        var previous_errors=errors.size()
        if base.is_empty():base=_actor_base(actor,clips,cache,errors)
        elif not reuse.is_empty():reuse.promotions=int(reuse.get("promotions",0))+1
        _add_actor_base(packet.paths,base,cache,packet.gpu_only,packet.cpu_required,native_optics,packet.optical_candidates,packet.normal_sets)
        var size_paths:Dictionary=packet.paths.duplicate();size_paths.merge(packet.optical_candidates)
        packet.source_sizes=EncounterMedia.source_sizes(size_paths,cache);packet.source_sizes.make_read_only()
        packet.source_headers=EncounterMedia.source_headers(size_paths,cache)
        packet.base=base
        var records:Dictionary={}
        for profile in CharacterGeometry.PROFILES:
            var contributions:Array=base.get("source_records",{}).get(profile,[]).duplicate()
            if native_optics:
                for reference in base.get("resolved",{}).get("native_records",[]):
                    contributions.append(reference)
            contributions.make_read_only();records[profile]=contributions
        records.make_read_only();packet.source_records=records
        var families:Dictionary={}
        for profile in records:families[profile]=_source_family(records[profile],packet.source_sizes)
        families.make_read_only();packet.source_families=families
        if not reuse.is_empty(): reuse.misses+=1
        if errors.size()!=previous_errors:
            paths.merge(packet.paths);gpu_only.merge(packet.gpu_only);cpu_required.merge(packet.cpu_required)
            optical_candidates.merge(packet.optical_candidates);normal_sets.merge(packet.normal_sets)
            return
    elif not reuse.is_empty(): reuse.hits+=1
    paths.merge(packet.paths);gpu_only.merge(packet.gpu_only);cpu_required.merge(packet.cpu_required)
    optical_candidates.merge(packet.optical_candidates);normal_sets.merge(packet.normal_sets)
    requested.append({"paths":paths,"actor":actor,"clips":clips.duplicate(),"packet":packet,"selector":selector})
    if not reuse.is_empty() and not reuse.current.any(func(entry):return is_same(entry,packet)): reuse.current.append(packet)

static func _visible_ids(visible: Dictionary, senses: Variant, audience: Dictionary) -> void:
    for id in audience.controlled: visible[id] = true
    var entities: Dictionary = senses.entities if senses != null else {}
    for id in entities:
        if entities[id].get("visual",false): visible[id] = true

static func roles_for(plan: Dictionary, paths: Dictionary) -> Dictionary:
    var roles = {"gpu_only":{},"cpu_required":{},"normal_sets":plan.get("normal_sets",{})}
    for path in paths:
        if plan.cpu_required.has(path): roles.cpu_required[path] = true
        elif plan.gpu_only.has(path): roles.gpu_only[path] = true
    return roles

static func required_at(schedule:Dictionary,local_ms:float,fallback:Dictionary={})->Dictionary:
    # Character and environment sources share the same passive first-use form.
    # The timeline remains the only owner of the proposed display clock.
    return EnvironmentMedia.required_at(schedule,local_ms,fallback)

static func errors_at(plan:Dictionary,local_ms:float)->Array:
    if not plan.has("error_timeline"):return plan.get("errors",[])
    var errors:Array=[]
    for row in plan.error_timeline:
        if float(row.at_ms)<=local_ms+0.000001:errors.append(row.message)
    return errors

static func _actor_first_use(times:Dictionary,actor:Dictionary,clips:Array,at_ms:float,
        cache:Dictionary,errors:Array,gpu_only:Dictionary,cpu_required:Dictionary,native_optics:bool,
        optical_candidates:Dictionary,normal_sets:Dictionary,requested:Array,reuse:Dictionary,error_times:Dictionary={})->void:
    # This exact source occurrence was already selected earlier in the same
    # plan. Its role projections are already composed; first-use needs only
    # its immutable path owner, not another set of scratch role/path maps.
    var borrowed:Dictionary={}
    for request in requested:
        if is_same(request.actor,actor) and request.clips==clips and request.packet.native_optics==native_optics:
            borrowed=request;break
    if not borrowed.is_empty():
        var occurrence:Dictionary=borrowed.duplicate();occurrence.paths={}
        requested.append(occurrence)
        EnvironmentMedia._first_use({},times,borrowed.packet.paths,at_ms)
        return
    var paths:Dictionary={}
    var before:int=errors.size()
    _add_actor_once(paths,actor,clips,cache,errors,gpu_only,cpu_required,native_optics,optical_candidates,normal_sets,requested,reuse)
    for index in range(before,errors.size()):error_times[errors[index]]=minf(float(error_times.get(errors[index],at_ms)),at_ms)
    EnvironmentMedia._first_use({},times,paths,at_ms)

static func _native_optics(group:Dictionary)->bool:
    # Constructor requirements also include audio and 2D outline helpers. Those
    # do not acquire 3D optical receiver inputs for the room's actors.
    return group.get("components",[]).any(func(row):return row.get("native_spell",false)) \
        or group.get("native_requirements",[]).any(func(row):return row.get("native_spell",false))

static func plan(state: Dictionary, groups: Array, cache: Dictionary) -> Dictionary:
    var required = {}
    var upcoming = {}
    var errors: Array = []
    var upcoming_errors: Array = []
    var gpu_only = {}
    var cpu_required = {}
    var normal_sets = {}
    var character_timeline:Dictionary={}
    var character_error_timeline:Dictionary={}
    var actor_records:Dictionary={}
    var requested_sources: Array = []
    var actor_reuse = _actor_reuse(cache)
    if state.is_empty(): return {"required":required,"upcoming":upcoming,"errors":errors,"upcoming_errors":upcoming_errors,"gpu_only":gpu_only,"cpu_required":cpu_required,"normal_sets":normal_sets,"character_timeline":character_timeline}
    var actors: Dictionary = state.actors.duplicate()
    var senses: Variant = state.senses
    var audience: Dictionary = state.audience
    var optical_candidates={}
    var native_optics=not groups.is_empty() and _native_optics(groups[0])
    for actor in actors.values():
        if WorldRows.visible_actor(actor,state): _add_actor_once(required,actor,[],cache,errors,gpu_only,cpu_required,native_optics,optical_candidates,normal_sets,requested_sources,actor_reuse)
    for group_index in range(groups.size()):
        var group: Dictionary = groups[group_index]
        var first_request:int=0 if group_index==0 else requested_sources.size()
        native_optics=_native_optics(group)
        var paths: Dictionary = required if group_index == 0 else upcoming
        var group_errors: Array = errors if group_index == 0 else upcoming_errors
        var error_times:Dictionary={}
        if group_index==0:
            for message in group_errors:error_times[message]=0.0
        var first_use:Dictionary={}
        var current_visible:Dictionary={}
        _visible_ids(current_visible,senses,audience)
        for id in current_visible:
            if actors.has(id):_actor_first_use(first_use,actors[id],[],0.0,cache,group_errors,gpu_only,cpu_required,native_optics,optical_candidates,normal_sets,requested_sources,actor_reuse,error_times)
        var witnesses = {}
        var visible = {}
        for id in actors: _witness(witnesses,id,actors[id])
        for id in group.get("staged_actors",{}):
            _witness(witnesses,id,group.staged_actors[id])
            visible[id] = true
            _actor_first_use(first_use,group.staged_actors[id],[],float(group.get("staged_at_ms",{}).get(id,0.0)),cache,group_errors,gpu_only,cpu_required,native_optics,optical_candidates,normal_sets,requested_sources,actor_reuse,error_times)
        _visible_ids(visible,senses,audience)
        for commit in group.get("commits",[]):
            var delta: Dictionary = commit.delta
            for id in delta.get("actors",{}):
                _witness(witnesses,id,delta.actors[id])
                actors[id] = delta.actors[id]
            senses = delta.get("set",{}).get("senses",senses)
            audience = delta.get("set",{}).get("audience",audience)
            _visible_ids(visible,senses,audience)
            var after_visible:Dictionary={}
            _visible_ids(after_visible,senses,audience)
            for id in after_visible:
                if actors.has(id) and (not current_visible.has(id) or delta.get("actors",{}).has(id)):
                    _actor_first_use(first_use,actors[id],[],float(commit.get("at_ms",0.0)),cache,group_errors,gpu_only,cpu_required,native_optics,optical_candidates,normal_sets,requested_sources,actor_reuse,error_times)
            current_visible=after_visible
        # Union exact observed/committed outfits within this one group. This
        # conservative preparation changes no state and exposes no actor early.
        for id in witnesses:
            if not visible.has(id): continue
            for actor in witnesses[id]: _add_actor_once(paths,actor,[],cache,group_errors,gpu_only,cpu_required,native_optics,optical_candidates,normal_sets,requested_sources,actor_reuse)
        var requested = {}
        for track in group.get("actor_tracks",[]):
            # This track's source outfit was captured by the compiler at its
            # occurrence. Later damage/death/outfit witnesses are demanded
            # ahead below, but cannot block this earlier authored source cue.
            var exact:Dictionary=track.get("presentation_actor",{})
            var track_actors:Array=[exact] if not exact.is_empty() else witnesses.get(track.actor_uuid,[])
            for actor in track_actors:
                if Characters.rig_id(actor,cache)!=track.rig:continue
                var shown:Dictionary=actor.duplicate()
                shown.presentation_layers=track.get("effect_layers",[])
                if track.has("visual_loadout"):shown.visual_loadout=track.visual_loadout
                _actor_first_use(first_use,shown,[track.clip],float(track.start_ms),cache,group_errors,gpu_only,cpu_required,native_optics,optical_candidates,normal_sets,requested_sources,actor_reuse,error_times)
            var key: String = track.actor_uuid + ":" + track.rig + ":" + track.clip
            if not requested.has(key): requested[key] = []
            var loadout: Variant = [track.get("visual_loadout"),track.get("effect_layers",[])]
            if loadout in requested[key]: continue
            requested[key].append(loadout)
            for actor in witnesses.get(track.actor_uuid,[]):
                if Characters.rig_id(actor,cache) != track.rig: continue
                var shown: Dictionary = actor.duplicate()
                shown.presentation_layers=track.get("effect_layers",[])
                if track.has("visual_loadout"):
                    shown.visual_loadout = track.visual_loadout
                _add_actor_once(paths,shown,[track.clip],cache,group_errors,gpu_only,cpu_required,native_optics,optical_candidates,normal_sets,requested_sources,actor_reuse)
        if group.has("id"):
            character_timeline[group.id]=EnvironmentMedia._timeline({},first_use)
            var error_rows:Array=[]
            var seen_errors:Dictionary={}
            for message in group_errors:
                if seen_errors.has(message):continue
                seen_errors[message]=true
                error_rows.append({"at_ms":float(error_times.get(message,0.0)),"message":message})
            character_error_timeline[group.id]=error_rows
            var records:Array=[]
            for request in requested_sources.slice(first_request):
                if not records.any(func(packet):return is_same(packet,request.packet)):records.append(request.packet)
            records.make_read_only();actor_records[group.id]=records
            # Exact occurrence snapshots can select a source absent from the
            # conservative endpoint witnesses. They still belong to demand.
            for path in first_use:paths[path]=true
    if groups.is_empty():
        var records:Array=[]
        for request in requested_sources:
            if not records.any(func(packet):return is_same(packet,request.packet)):records.append(request.packet)
        records.make_read_only();actor_records[""]=records
    for path in cpu_required: gpu_only.erase(path)
    _retain_actor_closures(cache,actor_reuse)
    return {"required":required,"upcoming":upcoming,"errors":errors,"upcoming_errors":upcoming_errors,"gpu_only":gpu_only,"cpu_required":cpu_required,"optical_candidates":optical_candidates,"normal_sets":normal_sets,"character_timeline":character_timeline,"character_error_timeline":character_error_timeline,"actor_records":actor_records}

static func close(data: Dictionary) -> void:
    if data.get("closed",false):return
    data.closed=true
    data.plan_pending={};data.optional_pending={}
    if data.plan_task>=0:
        WorkerThreadPool.wait_for_task_completion(data.plan_task);data.plan_task=-1
    var owner=physical(data)
    _withdraw(data)
    if not owner.consumers.is_empty():return
    if owner.selection_task>=0:
        WorkerThreadPool.wait_for_task_completion(owner.selection_task);owner.selection_task=-1
    owner.selection_result={}
    for job in owner.decode_jobs:
        if not job.get("joined",false):WorkerThreadPool.wait_for_task_completion(job.task)
    owner.decode_jobs.clear();owner.pending.clear();owner.queued.clear()
