extends RefCounted
# Exact current/near-future character sheets, prepared off the scene thread.
# Workers own unpublished images/textures. Only scene publication makes them ready.
const Characters = preload("res://presentation/characters.gd")
const Conditions = preload("res://presentation/conditions.gd")
const WorldRows = preload("res://presentation/world.gd")
const EnvironmentMedia = preload("res://presentation/environment_media.gd")
const EncounterMedia = preload("res://presentation/encounter_media.gd")
const NativeSupport = preload("res://presentation/native_scene_support.gd")
const BUDGET_BYTES = 16 * 1024 * 1024 * 1024
const EVICTIONS_PER_FRAME = 2
const CPU_RELEASES_PER_FRAME = 2
const DECODE_WORKERS = 4
const PUBLICATION_BUDGET_USEC = 2000
const PUBLICATIONS_PER_FRAME = 8

static func create() -> Dictionary:
    return {"pending":[],"queued":{},"wanted":{},"environment":{},"fixtures":{},"failed":{},"resident":{},
        "decode_jobs":[],"decoded":0,"evicted":0,"worker_upload":false,"maximum_texture_size":0,
        "plan_task":-1,"plan_pending":{},"optional_pending":{},"plan_result":{},"plan_cache":{},
        "required_plan":false,"metadata_phases":{},"publication":{},
        "gpu_only":{},"cpu_required":{},"metadata_ms":0.0,"decode_ms":0.0,"metadata_jobs":0,
        "budget_bytes":maxi(0,int(ProjectSettings.get_setting("source_data/encounter_cache_mib",16384)))*1024*1024,
        "encounter":{},"encounter_override":{},"encounter_epoch":-1,"preload_selected":{},"preload_skipped":0,"preload_estimated_bytes":0,
        "required_estimated_bytes":0,"unknown_required":0,"boot_paths":{},"boot_started":false,"boot_complete":false,
        "prune_frame":-1,"pruned_this_frame":0,"stats":{},"cpu_release":{},
        "cpu_release_frame":-1,"cpu_released_this_frame":0,"cpu_released_bytes_this_frame":0,
        "selection_revision":-1,"selection_budget":-1,"selection_required":{},"selection_extra":{},"selection_jobs":0,
        "ready_paths":{},"boot_waiting":{},"selected_ready":{},"selected_failed":{},
        "selection_roles":{},"demand_roles":{},"selection_summary":{},"selection_refreshed":0,
        "source_sizes":{},"demand_snapshot":{},"demand_runs":0,"demand_noops":0,"demand_phases":{},"demand_counts":{}}

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

static func prepare_handoff(state: Dictionary, groups: Array, cache: Dictionary) -> Dictionary:
    # Called by the existing session preparer, before publishing these groups.
    # This cache belongs exclusively to that worker; no scene residency changes.
    if groups.is_empty(): return {}
    var selected: Array = groups.slice(0,mini(2,groups.size()))
    var result = {}
    _plan_sources({"key":[],"state":_snapshot(state),"groups":selected},result,cache)
    result.generation = state.generation
    result.observer_uuid = state.observer_uuid
    result.groups = selected
    return result

static func receive_handoff(data: Dictionary, completed: Dictionary, key: Array) -> Dictionary:
    # The scene has checked accepted group ownership and supplies its local epoch.
    # Raw source files are immutable; only the optional worker merges its cache.
    var result: Dictionary = completed.duplicate()
    result.key = key
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

static func _start_plan(data: Dictionary) -> void:
    if data.plan_task >= 0: return
    var request: Dictionary
    var optional = false
    if not data.plan_pending.is_empty():
        request = data.plan_pending
        data.plan_pending = {}
    elif not data.optional_pending.is_empty() and data.encounter_override.is_empty():
        request = data.optional_pending
        data.optional_pending = {}; optional = true
    else: return
    data.plan_result = {}
    var work = _plan_optional.bind(request,data.plan_result,data.plan_cache) if optional else _plan_sources.bind(request,data.plan_result,data.plan_cache)
    data.plan_task = WorkerThreadPool.add_task(work,false,"Optional authored families" if optional else "Required authored media")

static func _plan_sources(request: Dictionary, result: Dictionary, cache: Dictionary) -> void:
    var started = Time.get_ticks_usec()
    result.key = request.key
    result.stage = "required"
    result.value = plan(request.state,request.groups,cache)
    var characters_done = Time.get_ticks_usec()
    var environment = EnvironmentMedia.plan(request.state,request.groups,cache)
    var environment_done = Time.get_ticks_usec()
    result.value.environment_required = environment.required
    result.value.environment_upcoming = environment.upcoming
    result.value.fixtures = environment.fixtures
    var exact_paths: Dictionary = result.value.required.duplicate()
    for paths in [result.value.upcoming,environment.required,environment.upcoming,result.value.get("optical_candidates",{})]: exact_paths.merge(paths)
    result.value.source_sizes = EncounterMedia.source_sizes(exact_paths,cache)
    var sizes_done = Time.get_ticks_usec()
    # The single metadata owner schedules optional families only after this
    # exact required packet has crossed the completed-task publication boundary.
    result.optional_request = {"key":request.key,"state":request.state,"groups":request.groups,"required":result.value}
    result.source_files = Characters.Catalog.source_snapshot(cache)
    result.phases = {"characters":(characters_done-started)/1000.0,
        "environment":(environment_done-characters_done)/1000.0,"source_sizes":(sizes_done-environment_done)/1000.0,"source_files":(Time.get_ticks_usec()-sizes_done)/1000.0}
    for phase in environment.get("diagnostics",{}).get("phases",{}):
        result.phases["environment_"+phase] = environment.diagnostics.phases[phase]
    result.elapsed_ms = (Time.get_ticks_usec()-started)/1000.0


static func _plan_optional(request: Dictionary, result: Dictionary, cache: Dictionary) -> void:
    var started = Time.get_ticks_usec()
    cache.merge(request.get("source_files",{}),false)
    result.key = request.key
    result.stage = "optional"
    var required: Dictionary = request.required
    var environment: Dictionary = required.environment_required.duplicate()
    environment.merge(required.environment_upcoming)
    var encounter = EncounterMedia.plan(request.state,environment,required.fixtures,cache,request.groups).duplicate()
    var families_done = Time.get_ticks_usec()
    var estimates: Dictionary = encounter.paths.duplicate()
    var cpu_required: Dictionary = encounter.cpu_required.duplicate()
    var gpu_only: Dictionary = encounter.gpu_only.duplicate()
    for paths in [required.required,required.upcoming,required.environment_required,required.environment_upcoming]: estimates.merge(paths)
    cpu_required.merge(required.cpu_required); cpu_required.merge(environment)
    gpu_only.merge(required.gpu_only)
    encounter.estimates = EncounterMedia.estimates(estimates,cpu_required,gpu_only,cache)
    encounter.estimate_bytes = EncounterMedia.estimate_bytes(encounter.estimates)
    encounter.estimate_summary = EncounterMedia.estimate_summary(encounter)
    for path in encounter.paths:
        if encounter.estimates[path].has("error"):
            encounter.errors = encounter.errors.duplicate()
            encounter.errors.append(encounter.estimates[path].error)
    var estimates_done = Time.get_ticks_usec()
    result.value = {"encounter":encounter}
    result.source_files = Characters.Catalog.source_snapshot(cache)
    result.phases = {"families":(families_done-started)/1000.0,"estimates":(estimates_done-families_done)/1000.0,
        "source_files":(Time.get_ticks_usec()-estimates_done)/1000.0}
    result.elapsed_ms = (Time.get_ticks_usec()-started)/1000.0
    result.complete = true

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
    if data.queued.has(path) or data.failed.has(path): return
    if data.resident.has(path) and int(data.resident[path].gpu_bytes)>0 and (not _needs_cpu(data,path) or int(data.resident[path].cpu_bytes) > 0) \
        and (not _fixture(data,path) or data.resident[path].get("fixture_ready",false)): return
    data.demand_snapshot = {}
    data.queued[path] = true
    data.pending.append({"path":path,"absolute":absolute,"fixture":_fixture(data,path)})
    _pending_delta(data,path,1)

static func _adopt_epoch(data: Dictionary, epoch: int) -> void:
    if data.encounter_epoch == epoch: return
    data.encounter_epoch = epoch
    data.encounter = data.encounter_override; data.required_plan = false
    data.boot_paths = {}; data.boot_waiting = {}; data.boot_started = false; data.boot_complete = false
    data.selection_revision = -2
    data.source_sizes = {}

static func adopt_required(data: Dictionary, epoch: int) -> void:
    # Exact readiness and its startup pins do not depend on optional estimates.
    _adopt_epoch(data,epoch)
    data.required_plan = true

static func adopt_source_sizes(data: Dictionary, sizes: Dictionary, epoch: int) -> void:
    _adopt_epoch(data,epoch)
    for path in sizes:
        if data.source_sizes.get(path,-1)!=sizes[path]:
            data.source_sizes[path] = sizes[path]
            data.demand_snapshot = {}

static func adopt_encounter(data: Dictionary, encounter: Dictionary, epoch: int) -> void:
    # Called only for an accepted scene epoch, never on worker completion alone.
    _adopt_epoch(data,epoch)
    # Studio knows the exact admitted recording, so its finite source set can
    # replace generic optional rig families without altering required demand.
    data.encounter = encounter if data.encounter_override.is_empty() else data.encounter_override

static func _environment(data: Dictionary, path: String) -> bool:
    return data.environment.has(path) or data.encounter.get("environment",{}).has(path)

static func _fixture(data: Dictionary, path: String) -> bool:
    return data.fixtures.has(path) or data.encounter.get("fixtures",{}).has(path)

static func _estimate(data: Dictionary, path: String) -> int:
    var estimate: Dictionary = data.encounter.get("estimates",{}).get(path,{})
    if estimate.has("bytes"): return int(estimate.bytes)
    if data.source_sizes.has(path):
        return int(data.source_sizes[path])*(2 if _needs_cpu(data,path) else 1)
    if data.resident.has(path): return int(data.resident[path].bytes)
    return -1

static func _pinned(data: Dictionary, path: String) -> bool:
    return data.wanted.has(path) or data.preload_selected.has(path)

static func _invalidate(data: Dictionary) -> void:
    data.stats = {}

static func _pending_delta(data: Dictionary, path: String, amount: int) -> void:
    if not data.stats.is_empty(): data.stats[_environment(data,path)].pending += amount

static func _resident_delta(data: Dictionary, path: String, resident: Dictionary, amount: int) -> void:
    if data.stats.is_empty(): return
    var row: Dictionary = data.stats[resident.get("environment",false)]
    row.resident_sheets += amount
    row.estimated_bytes += amount*int(resident.bytes)
    row.cpu_bytes += amount*int(resident.cpu_bytes)
    row.gpu_estimated_bytes += amount*int(resident.gpu_bytes)
    if _pinned(data,path): row.pinned_bytes += amount*int(resident.bytes)

static func _refresh_path(data: Dictionary, path: String) -> void:
    var available = false
    if not data.failed.has(path) and data.resident.has(path):
        var resident: Dictionary = data.resident[path]
        available = int(resident.gpu_bytes)>0 and (not _needs_cpu(data,path) or int(resident.cpu_bytes)>0) \
            and (not _fixture(data,path) or resident.get("fixture_ready",false))
    if available: data.ready_paths[path] = true
    else: data.ready_paths.erase(path)
    if not data.boot_complete and data.boot_paths.has(path):
        if available or data.failed.has(path): data.boot_waiting.erase(path)
        else: data.boot_waiting[path] = true
    if data.preload_selected.has(path):
        if available: data.selected_ready[path] = true
        else: data.selected_ready.erase(path)
        if data.failed.has(path): data.selected_failed[path] = data.failed[path]
        else: data.selected_failed.erase(path)

static func _family_roles(encounter: Dictionary) -> Dictionary:
    return {"environment":encounter.get("environment",{}),"fixtures":encounter.get("fixtures",{}),
        "cpu_required":encounter.get("cpu_required",{}),"gpu_only":encounter.get("gpu_only",{})}

static func _changed_roles(previous: Dictionary, current: Dictionary, family: Dictionary = {}) -> Dictionary:
    var changed = {}
    for role in current:
        var old: Dictionary = previous.get(role,{})
        var new: Dictionary = current[role]
        # Accepted family role owners are immutable and reused by the worker.
        if is_same(old,new) or old==new: continue
        # Exact roles add to the accepted family roles. Removing/readding an
        # already family-owned requirement cannot change source readiness.
        var covered: Dictionary = family.get(role,{})
        var cpu: Dictionary = family.get("cpu_required",{}) if role=="gpu_only" else {}
        var environment: Dictionary = family.get("environment",{}) if role in ["cpu_required","gpu_only"] else {}
        var fixtures: Dictionary = family.get("fixtures",{}) if role in ["cpu_required","gpu_only"] else {}
        for path in old:
            if not new.has(path) and not covered.has(path) and not cpu.has(path) and not environment.has(path) and not fixtures.has(path): changed[path] = true
        for path in new:
            if not old.has(path) and not covered.has(path) and not cpu.has(path) and not environment.has(path) and not fixtures.has(path): changed[path] = true
    return changed

static func _selection_delta(data: Dictionary, previous: Dictionary, role_changes: Dictionary, new_boot: bool, membership_changes: Dictionary) -> Dictionary:
    var refresh: Dictionary = role_changes.duplicate()
    if new_boot:
        for path in data.boot_paths: refresh[path] = true
    for path in previous:
        if data.preload_selected.has(path): continue
        data.selected_ready.erase(path); data.selected_failed.erase(path)
        membership_changes[path] = true
    for path in data.preload_selected:
        if not previous.has(path):
            membership_changes[path] = true
            refresh[path] = true
        elif new_boot: refresh[path] = true
    # The resident-role pass below updates this same set after category and CPU
    # requirements are settled. Refreshing readiness here would do it twice.
    data.selection_refreshed += refresh.size()
    return refresh

static func _refresh_resident_role(data: Dictionary, path: String, selected_refresh:bool=false) -> void:
    if not data.resident.has(path):
        # Selection changes also update missing/failed source readiness. Keep
        # the original domain for unrelated nonresident role-only updates.
        if selected_refresh:_refresh_path(data,path)
        return
    var resident: Dictionary = data.resident[path]
    if resident.environment!=_environment(data,path):
        _resident_delta(data,path,resident,-1)
        resident.environment = _environment(data,path)
        _resident_delta(data,path,resident,1)
    if int(resident.cpu_bytes)>0 and not _needs_cpu(data,path): data.cpu_release[path] = true
    _refresh_path(data,path)

static func _same_demand(data: Dictionary, paths: Dictionary, roles: Array) -> bool:
    var prior: Dictionary = data.demand_snapshot
    if prior.is_empty(): return false
    # Most changed groups differ here. Reject their small exact demand before
    # comparing the much larger accepted family estimate map.
    if prior.paths!=paths or prior.order!=paths.keys() or prior.roles!=roles: return false
    var family: Dictionary = data.encounter
    var accepted: Dictionary = prior.encounter
    if prior.epoch!=data.encounter_epoch or prior.budget!=data.budget_bytes \
        or prior.boot!=[data.boot_started,data.boot_complete] \
        or accepted.get("revision",-1)!=family.get("revision",-1) \
        or accepted.get("estimate_summary",{})!=family.get("estimate_summary",{}) \
        or accepted.get("estimates",{})!=family.get("estimates",{}): return false
    for role in ["environment","fixtures","gpu_only","cpu_required"]:
        if accepted.get(role,{})!=family.get(role,{}): return false
    return accepted.get("paths",{})==family.get("paths",{})

static func demand(data: Dictionary, paths: Dictionary, environment: Dictionary = {}, fixtures: Dictionary = {}, gpu_only: Dictionary = {}, cpu_required: Dictionary = {}) -> void:
    var started = Time.get_ticks_usec()
    # Last-call CPU evidence only. Children are exclusive; total is inclusive.
    var phases = {"guard":0.0,"estimate":0.0,"selection":0.0,"role_diff":0.0,"selection_refresh":0.0,
        "resident_refresh":0.0,"queue":0.0,"snapshot":0.0,"total":0.0}
    data.demand_phases = phases
    data.demand_counts = {"required":paths.size(),"known":data.encounter.get("paths",{}).size(),
        "pending_before":data.pending.size(),"affected":0,"resident_refreshed":0,"role_changes":0,"selection_changed":false,"noop":false}
    var exact_roles = [environment,fixtures,gpu_only,cpu_required]
    var unchanged = _same_demand(data,paths,exact_roles)
    phases.guard = (Time.get_ticks_usec()-started)/1000.0
    if unchanged:
        data.wanted = paths; data.environment = environment; data.fixtures = fixtures
        data.gpu_only = gpu_only; data.cpu_required = cpu_required
        data.demand_noops += 1
        data.demand_counts.noop = true
        phases.total = (Time.get_ticks_usec()-started)/1000.0
        return
    var phase_started = Time.get_ticks_usec()
    data.demand_runs += 1
    data.demand_snapshot = {}
    var previous_paths: Dictionary = data.wanted
    var previous_selected: Dictionary = data.preload_selected
    # Exact roles can temporarily classify a retained source differently from
    # its family default. Queue counts were recorded under the previous role.
    var family_environment: Dictionary = data.encounter.get("environment",{})
    for path in data.environment:
        if not environment.has(path) and not family_environment.has(path): _invalidate(data); break
    for path in environment:
        if not data.environment.has(path) and not family_environment.has(path): _invalidate(data); break
    data.wanted = paths
    # Accepted worker-owned family roles stay immutable. Only the small exact
    # group demand changes here; never copy all companion roles per action.
    data.environment = environment
    data.fixtures = fixtures
    data.gpu_only = gpu_only
    data.cpu_required = cpu_required
    var used = 0
    var unknown = 0
    var extra = {}
    var known: Dictionary = data.encounter.get("paths",{})
    var exact_estimates = true
    var bytes_by_path: Dictionary = data.encounter.get("estimate_bytes",{})
    var estimates: Dictionary = data.encounter.get("estimates",{})
    for path in paths:
        if not bytes_by_path.has(path) and not estimates.get(path,{}).has("bytes") and not data.source_sizes.has(path): exact_estimates = false
        var size: int = bytes_by_path[path] if bytes_by_path.has(path) else _estimate(data,path)
        if size < 0: unknown += 1
        else: used += size
        if not known.has(path): extra[path] = size
    data.required_estimated_bytes = used
    data.unknown_required = unknown
    phases.estimate = (Time.get_ticks_usec()-phase_started)/1000.0
    phase_started = Time.get_ticks_usec()
    var revision: int = data.encounter.get("revision",-1)
    var summary: Dictionary = data.encounter.get("estimate_summary",{})
    var selection_changed: bool = data.selection_revision!=revision or data.selection_budget!=data.budget_bytes \
        or data.selection_extra!=extra or data.selection_summary!=summary or (data.preload_skipped>0 and data.selection_required!=paths)
    data.demand_counts.selection_changed = selection_changed
    var refresh = {}
    var membership_changes = {}
    if selection_changed:
        data.selection_jobs += 1
        data.selection_revision = revision; data.selection_budget = data.budget_bytes
        data.selection_extra = extra; data.selection_required = paths; data.selection_summary = summary
        var selected = {}
        var skipped = 0
        var preload_bytes = 0
        var extra_bytes = 0
        for size in extra.values(): extra_bytes += maxi(0,int(size))
        var boot_extra = {}
        if data.boot_started and not data.boot_complete:
            for path in data.boot_paths:
                if not known.has(path):
                    boot_extra[path] = data.boot_paths[path]
                    if not paths.has(path): extra_bytes += maxi(0,int(bytes_by_path[path]) if bytes_by_path.has(path) else _estimate(data,path))
        # A worker-computed total avoids re-estimating the whole resident family
        # on ordinary growth. Exact priority/frozen boot selection still uses
        # the original bounded algorithm when the entire family cannot fit.
        if not summary.is_empty() and summary.unknown==0 and unknown==0 and int(summary.bytes)+extra_bytes<=int(data.budget_bytes):
            selected = known
            preload_bytes = int(summary.bytes)
            if not boot_extra.is_empty():
                selected = known.duplicate()
                selected.merge(boot_extra)
                for path in boot_extra: preload_bytes += maxi(0,int(bytes_by_path[path]) if bytes_by_path.has(path) else _estimate(data,path))
        else:
            if data.boot_started and not data.boot_complete:
                for path in data.boot_paths:
                    selected[path] = data.boot_paths[path]
                    var size: int = bytes_by_path[path] if bytes_by_path.has(path) else _estimate(data,path)
                    preload_bytes += maxi(0,size)
                    if not paths.has(path): used += maxi(0,size)
            for path in known:
                if selected.has(path): continue
                var size: int = bytes_by_path[path] if bytes_by_path.has(path) else _estimate(data,path)
                if paths.has(path):
                    selected[path] = known[path]
                    preload_bytes += maxi(0,size)
                    continue
                if unknown>0 or size<0 or used+size>int(data.budget_bytes): skipped += 1; continue
                selected[path] = known[path]
                used += size
                preload_bytes += size
        data.preload_selected = selected
        data.preload_skipped = skipped
        data.preload_estimated_bytes = preload_bytes
        var new_boot: bool = (data.required_plan or not data.encounter.is_empty()) and not data.boot_started
        if new_boot:
            data.boot_started = true
            # Startup waits only for exact displayed/already-received demand.
            # Optional animations and normal treatments warm within the budget
            # after this boundary and never delay initial interaction.
            data.boot_paths = paths.duplicate()
        var role_started = Time.get_ticks_usec()
        var roles = _family_roles(data.encounter)
        var changed = _changed_roles(data.selection_roles,roles)
        phases.role_diff = (Time.get_ticks_usec()-role_started)/1000.0
        data.demand_counts.role_changes = changed.size()
        # Queue classifications were counted before accepted family roles moved.
        # Only a real role change of existing work invalidates those aggregates.
        for path in changed:
            if data.queued.has(path): _invalidate(data); break
        data.selection_roles = roles
        var refresh_started = Time.get_ticks_usec()
        refresh = _selection_delta(data,previous_selected,changed,new_boot,membership_changes)
        phases.selection_refresh = (Time.get_ticks_usec()-refresh_started)/1000.0
    phases.selection = (Time.get_ticks_usec()-phase_started)/1000.0-phases.role_diff-phases.selection_refresh
    phase_started = Time.get_ticks_usec()
    # Reuse selection membership differences; mandatory-only transfers can
    # alter pins without changing any source's residency role or readiness.
    var affected: Dictionary = membership_changes
    var paths_changed: bool = previous_paths!=paths
    if paths_changed:
        for path in previous_paths:
            if not paths.has(path): affected[path] = true
        for path in paths:
            if not previous_paths.has(path): affected[path] = true
    # Membership changes affect pin accounting, not every resident texture.
    if not data.stats.is_empty():
        for path in affected:
            if not data.resident.has(path): continue
            var prior_pin: bool = previous_paths.has(path) or previous_selected.has(path)
            var current_pin: bool = _pinned(data,path)
            if prior_pin!=current_pin:
                var resident: Dictionary = data.resident[path]
                data.stats[resident.environment].pinned_bytes += (int(current_pin)-int(prior_pin))*int(resident.bytes)
    var roles_now = {"environment":environment,"fixtures":fixtures,"gpu_only":gpu_only,"cpu_required":cpu_required}
    var exact_changed = _changed_roles(data.demand_roles,roles_now,data.encounter if data.encounter.has("estimate_bytes") else {})
    var resident_refresh: Dictionary = refresh.duplicate()
    for path in exact_changed:
        # Match the original affected domain even for manual role maps that
        # mention an unchanged optional source outside both exact demands.
        if previous_paths.has(path) or paths.has(path) or membership_changes.has(path): resident_refresh[path] = true
    if paths_changed:
        for path in paths:
            if not previous_paths.has(path): resident_refresh[path] = true
    if not data.encounter.has("estimate_bytes"):
        # Legacy/manual metadata has no prepared-byte owner. Keep its original
        # exhaustive refresh domain and residency fallback behavior.
        resident_refresh.merge(previous_paths)
        resident_refresh.merge(paths)
        resident_refresh.merge(membership_changes)
    data.demand_counts.affected = affected.size()
    data.demand_counts.resident_refreshed = resident_refresh.size()
    for path in resident_refresh: _refresh_resident_role(data,path,refresh.has(path))
    phases.resident_refresh = (Time.get_ticks_usec()-phase_started)/1000.0
    phase_started = Time.get_ticks_usec()
    # Promote mandatory sources ahead of unfinished background warmup. Once
    # warm, an action checks only its own small packet, not every retained sheet.
    var pending: Array = data.pending
    for request in pending:
        _pending_delta(data,request.path,-1)
        data.queued.erase(request.path)
    data.pending = []
    # Mandatory role changes and publications already refreshed ready_paths.
    # Do not repeat those CPU/fixture residency checks for every warm sheet.
    # Optional/manual roles retain enqueue's full check below.
    for path in paths:
        if not data.ready_paths.has(path): enqueue(data,path,paths[path])
    # Role refresh order and an older optional backlog must not move an admitted
    # outfit's authored rest/movement sources behind exhaustive pose families.
    for path in data.encounter.get("priority",{}):
        if data.preload_selected.has(path) and not paths.has(path): enqueue(data,path,data.preload_selected[path])
    for request in pending:
        if data.preload_selected.has(request.path) and not paths.has(request.path): enqueue(data,request.path,request.absolute)
    for path in refresh:
        if data.preload_selected.has(path) and not paths.has(path): enqueue(data,path,data.preload_selected[path])
    phases.queue = (Time.get_ticks_usec()-phase_started)/1000.0
    phase_started = Time.get_ticks_usec()
    # Without header estimates, residency progress can change the budget input.
    # Keep that uncommon path exhaustive instead of tracking another generation.
    var copied_roles: Array = []
    data.demand_roles = {}
    for role in roles_now:
        var copied: Dictionary = roles_now[role].duplicate()
        data.demand_roles[role] = copied
        copied_roles.append(copied)
    if exact_estimates and not summary.is_empty() and summary.unknown==0:
        data.demand_snapshot = {"paths":paths.duplicate(),"order":paths.keys(),"roles":copied_roles,
            "encounter":data.encounter,"epoch":data.encounter_epoch,"budget":data.budget_bytes,
            "boot":[data.boot_started,data.boot_complete]}
    phases.snapshot = (Time.get_ticks_usec()-phase_started)/1000.0
    phases.total = (Time.get_ticks_usec()-started)/1000.0

static func _decode(request: Dictionary, result: Dictionary) -> void:
    var started = Time.get_ticks_usec()
    result.path = request.path
    if not FileAccess.file_exists(request.absolute):
        result.error = "Missing authored image: " + request.path
        return
    var decoded = Image.new()
    var error = decoded.load(request.absolute)
    if error != OK or decoded.is_empty():
        result.error = "Cannot decode authored image: " + request.path + " (" + error_string(error) + ")"
        return
    result.image = decoded
    result.cpu_bytes = decoded.get_data().size()
    # Explicit estimate, not measured VRAM: an RGB PNG can have RGBA storage.
    result.gpu_bytes = decoded.get_width() * decoded.get_height() * 4
    if request.get("fixture",false):
        # Exact previous native reduction, now on the source worker. The
        # original decoded pixels remain unchanged for upload and picking.
        var reduced: Image = decoded.duplicate()
        reduced.srgb_to_linear()
        reduced.premultiply_alpha()
        reduced.convert(Image.FORMAT_RGBAF)
        reduced.resize(1,1,Image.INTERPOLATE_TRILINEAR)
        result.energy = reduced.get_pixel(0,0).get_luminance()
        # One original-frame moment on the decoding worker, never a scene-frame
        # pixel scan. Alpha-weighted linear emission excludes invisible RGB.
        var weight = 0.0
        var moment = Vector2.ZERO
        for y in range(decoded.get_height()):
            for x in range(decoded.get_width()):
                var colour = decoded.get_pixel(x,y)
                var amount = colour.srgb_to_linear().get_luminance()*colour.a
                weight += amount
                moment += Vector2(x+.5,y+.5)*amount
        result.emission_centroid = moment/weight if weight>0 else Vector2(decoded.get_width(),decoded.get_height())*.5

    result.elapsed_ms = (Time.get_ticks_usec()-started)/1000.0
    var maximum:int=request.get("maximum_texture_size",0)
    if maximum>0 and (decoded.get_width()>maximum or decoded.get_height()>maximum):
        result.error="Authored image exceeds GPU texture limit (%d×%d > %d): %s"%[decoded.get_width(),decoded.get_height(),maximum,request.path]
        return
    if request.get("worker_upload",false):
        # RenderingDevice permits asynchronous creation of a new texture. This
        # resource is private until the completed task is joined; never mutate
        # a published texture or touch the SceneTree from this worker.
        var upload_started:int=Time.get_ticks_usec()
        result.texture=ImageTexture.create_from_image(decoded)
        result.worker_upload_ms=(Time.get_ticks_usec()-upload_started)/1000.0
        if result.texture==null:result.error="Cannot create authored texture: "+request.path
    result.complete = true

static func poll(data: Dictionary, required_only: bool = false, publish:bool=true) -> Dictionary:
    var completed: Dictionary = {}
    # Completion order is independent of event playback: the exact required
    # set remains the readiness gate. Reclaim a completed optional job when no
    # required result is ready, so it cannot occupy a decode slot indefinitely.
    var next = -1
    var optional = -1
    for i in data.decode_jobs.size():
        var job: Dictionary = data.decode_jobs[i]
        if not WorkerThreadPool.is_task_completed(job.task): continue
        if data.wanted.has(job.path): next = i; break
        if optional<0: optional = i
    # A newly required request must not wait for optional GPU publication to
    # free every worker slot. Reclaim one completed optional decode only when
    # it actually blocks required work, under the caller's upload allowance.
    var blocked_required:bool=required_only and data.decode_jobs.size()>=DECODE_WORKERS and data.pending.any(func(request):return data.wanted.has(request.path))
    if next<0 and (not required_only or blocked_required): next = optional
    if next>=0 and publish:
        var job: Dictionary = data.decode_jobs[next]
        data.decode_jobs.remove_at(next)
        WorkerThreadPool.wait_for_task_completion(job.task)
        completed = job.result
        _pending_delta(data,job.path,-1)
        data.queued.erase(job.path)
        data.decoded += 1
        data.decode_ms += completed.get("elapsed_ms",0.0)
        if not completed.has("image") and not completed.has("error"):
            completed.error = "Authored image preparation did not complete: " + completed.path
        if not _pinned(data,completed.path): completed = {}
        elif completed.has("error"):
            data.failed[completed.path] = completed.error
            _refresh_path(data,completed.path)
    while not data.pending.is_empty() and data.decode_jobs.size()<DECODE_WORKERS:
        var request: Dictionary = data.pending.pop_front()
        request.maximum_texture_size=data.maximum_texture_size
        # A role upgrade may need emission metadata for an already resident
        # image; it must not allocate a second copy of its unchanged texture.
        request.worker_upload=data.worker_upload and not data.resident.has(request.path)
        var result: Dictionary = {}
        var task = WorkerThreadPool.add_task(_decode.bind(request,result),false,"Authored PNG preparation")
        data.decode_jobs.append({"task":task,"path":request.path,"result":result})
    return completed

static func validate_upload_dimensions(data:Dictionary,loaded:Dictionary,maximum:int)->void:
    if maximum<=0 or loaded.has("error"):return
    var size:Vector2i=loaded.image.get_size()
    if size.x<=maximum and size.y<=maximum:return
    loaded.error="Authored image exceeds GPU texture limit (%d×%d > %d): %s"%[size.x,size.y,maximum,loaded.path]
    data.failed[loaded.path]=loaded.error
    _refresh_path(data,loaded.path)

static func published(data: Dictionary, loaded: Dictionary) -> void:
    if data.resident.has(loaded.path): _resident_delta(data,loaded.path,data.resident[loaded.path],-1)
    data.resident[loaded.path] = {"bytes":int(loaded.cpu_bytes)+int(loaded.gpu_bytes),
        "cpu_bytes":int(loaded.cpu_bytes),"gpu_bytes":int(loaded.gpu_bytes),
        "cpu_required":_needs_cpu(data,loaded.path),"environment":_environment(data,loaded.path),
        "fixture_ready":loaded.has("energy") and loaded.has("emission_centroid"),"used":Time.get_ticks_msec()}
    if not _needs_cpu(data,loaded.path): data.cpu_release[loaded.path] = true
    _resident_delta(data,loaded.path,data.resident[loaded.path],1)
    _refresh_path(data,loaded.path)
    # A caller can satisfy queued work from an already-decoded original. The
    # next full demand must remove that redundant pending request as before.
    if data.queued.has(loaded.path) or (_pinned(data,loaded.path) and not data.ready_paths.has(loaded.path)):
        data.demand_snapshot = {}
    # A decode request captures its fixture role before entering the worker.
    # If a newer accepted demand upgrades that role while decoding, its colour
    # may publish first but cannot satisfy readiness without emission metrics.
    # Queue the missing preprocessing immediately; the stable scene plan need
    # not be requested again to recover from this one in-flight role change.
    if _pinned(data,loaded.path) and _fixture(data,loaded.path) and not data.resident[loaded.path].fixture_ready \
        and not data.queued.has(loaded.path) and not data.failed.has(loaded.path):
        var absolute: String = data.wanted.get(loaded.path,data.preload_selected.get(loaded.path,""))
        enqueue(data,loaded.path,absolute)
        if data.wanted.has(loaded.path): data.pending.push_front(data.pending.pop_back())

static func _needs_cpu(data: Dictionary, path: String) -> bool:
    # Original colour is needed for picking; environment/fixture preparation
    # retains its existing CPU contract. Only exact registered companions opt out.
    if _environment(data,path) or _fixture(data,path) or data.cpu_required.has(path) or data.encounter.get("cpu_required",{}).has(path): return true
    if data.gpu_only.has(path) or data.encounter.get("gpu_only",{}).has(path): return false
    return data.resident.get(path,{}).get("cpu_required",true)

static func ready(data: Dictionary, paths: Dictionary) -> bool:
    for path in paths:
        if data.failed.has(path) or not data.ready_paths.has(path): return false
    return true

static func release_cold_images(data: Dictionary, limit: int = CPU_RELEASES_PER_FRAME) -> Array:
    # Original alpha/picking pixels stay with their resident texture. Restoring
    # these on every action revisit would defeat encounter preloading. Exact
    # registered GPU-only companions still release their CPU copy immediately.
    # Play erases the returned Image handles immediately. Bound the entire
    # native frame, including maintenance called again during publication.
    # Explicit negative limits are for offline bulk-accounting fixtures only.
    var frame:int=Engine.get_process_frames()
    if data.cpu_release_frame!=frame:
        data.cpu_release_frame=frame;data.cpu_released_this_frame=0;data.cpu_released_bytes_this_frame=0
    var remaining:int=limit-data.cpu_released_this_frame if limit>=0 else data.cpu_release.size()
    if remaining<=0:return []
    var released: Array = []
    var examined: Array = []
    for path in data.cpu_release:
        if released.size()>=remaining:break
        examined.append(path)
        if not data.resident.has(path): continue
        if int(data.resident[path].cpu_bytes) == 0: continue
        if _needs_cpu(data,path): continue
        var bytes:int=data.resident[path].cpu_bytes
        _resident_delta(data,path,data.resident[path],-1)
        data.resident[path].bytes -= bytes
        data.resident[path].cpu_bytes = 0
        _resident_delta(data,path,data.resident[path],1)
        _refresh_path(data,path)
        data.cpu_released_bytes_this_frame+=bytes
        released.append(path)
    for path in examined:data.cpu_release.erase(path)
    data.cpu_released_this_frame+=released.size()
    return released

static func touch(data: Dictionary, path: String) -> void:
    if data.resident.has(path): data.resident[path].used = Time.get_ticks_msec()

static func prune(data: Dictionary, budget: int = -1) -> Array:
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
    for path in data.resident:
        if _pinned(data,path):continue
        var used:int=data.resident[path].used
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
    if not data.stats.is_empty(): return data.stats
    var stats = {}
    for category in [false,true]:
        stats[category] = {"pending":0,"resident_sheets":0,"estimated_bytes":0,"pinned_bytes":0,"cpu_bytes":0,"gpu_estimated_bytes":0}
    for job in data.decode_jobs: stats[_environment(data,job.path)].pending += 1
    for request in data.pending:
        stats[_environment(data,request.path)].pending += 1
    for path in data.resident:
        var resident: Dictionary = data.resident[path]
        var row: Dictionary = stats[resident.get("environment",false)]
        row.resident_sheets += 1
        row.estimated_bytes += int(resident.bytes)
        row.cpu_bytes += int(resident.cpu_bytes)
        row.gpu_estimated_bytes += int(resident.gpu_bytes)
        if _pinned(data,path): row.pinned_bytes += int(resident.bytes)
    data.stats = stats
    return stats

static func diagnostics(data: Dictionary, environment: bool = false) -> Dictionary:
    var stats = _residency_stats(data)
    var result: Dictionary = stats[environment].duplicate()
    var total: int = stats[false].estimated_bytes+stats[true].estimated_bytes
    var pinned: int = stats[false].pinned_bytes+stats[true].pinned_bytes
    result.merge({"combined_estimated_bytes":total,"pinned_over_budget_bytes":maxi(0,pinned-int(data.budget_bytes)),
        "eviction_pending_bytes":maxi(0,total-maxi(pinned,int(data.budget_bytes))),
        "metadata_ms":data.metadata_ms,"metadata_jobs":data.metadata_jobs,"metadata_phases":data.metadata_phases.duplicate(),"publication":data.publication.duplicate(),"decode_ms":data.decode_ms,
        "decode_jobs":data.decode_jobs.size(),"decode_worker_limit":DECODE_WORKERS,
        "cpu_release_pending":data.cpu_release.size(),"cpu_released_this_frame":data.cpu_released_this_frame,"cpu_released_bytes_this_frame":data.cpu_released_bytes_this_frame,
        "budget_bytes":data.budget_bytes,"demand_runs":data.demand_runs,"demand_noops":data.demand_noops,"demand_phases":data.demand_phases.duplicate(),"demand_counts":data.demand_counts.duplicate(),"selection_jobs":data.selection_jobs,"selection_refreshed":data.selection_refreshed,"decoded":data.decoded,"evicted":data.evicted,"failed":data.failed.duplicate(),
        "accounting":"Decoded CPU bytes plus conservative RGBA8 GPU estimate; not measured VRAM/RSS; combined environment and character budget."})
    return result

static func boot_ready(data: Dictionary) -> bool:
    if data.boot_complete: return true
    if not data.boot_started or not data.boot_waiting.is_empty(): return false
    data.boot_complete = true
    return true

static func preload_progress(data: Dictionary) -> Dictionary:
    return {"selected":data.preload_selected.size(),"ready":data.selected_ready.size(),"failed":data.selected_failed.duplicate(),
        "startup_required":data.boot_paths.size(),"startup_ready":data.boot_paths.size()-data.boot_waiting.size(),
        "skipped":data.preload_skipped,"selected_estimated_bytes":data.preload_estimated_bytes,
        "required_estimated_bytes":data.required_estimated_bytes,"required_unknown_estimates":data.unknown_required,
        "budget_bytes":data.budget_bytes,"errors":data.encounter.get("errors",[]),
        "scope":"Authored families from displayed state and the bounded already-received operation window; no future-state publication."}

static func _drawable(actor: Dictionary) -> bool:
    return actor.get("present",true) and actor.get("last_visual_position") != null \
        and actor.get("spatial_disposition","present") == "present" and actor.get("remains_disposition","intact") != "disintegrated"

static func _add_actor(paths: Dictionary, actor: Dictionary, clips: Array, cache: Dictionary, errors: Array, gpu_only: Dictionary, cpu_required: Dictionary, native_optics:bool=false, optical_candidates:Dictionary={}) -> void:
    if not _drawable(actor): return
    var wanted = clips.duplicate()
    var index: Dictionary = Characters._read("catalog-index.json",cache)
    var rigs: Dictionary = Characters._read(index.rigs,cache)
    var rig = Characters.rig_id(actor,cache)
    if not rigs.has(rig):
        errors.append("No authored rig for actor " + str(actor.get("uuid")))
        return
    var rest = Characters.rest_sample(actor,rigs[rig],cache)
    if not rest.ok: errors.append(rest.error.message); return
    if rest.value.clip not in wanted: wanted.append(rest.value.clip)
    # An admitted condition may select both resting and locomotion sources.
    # Prepare that finite closure together, before its first movement; actor
    # tracks still name the exact clip for attack/jump/hit/death independently.
    for activity in ["idle","move"]:
        var pose=Conditions.ConditionPose.select(actor,rig,activity,cache)
        if not pose.is_empty() and pose.clip not in wanted: wanted.append(pose.clip)
    var resolved = Characters.sheet_paths(actor,wanted,cache)
    if not resolved.ok: errors.append(resolved.error.message); return
    paths.merge(resolved.value)
    gpu_only.merge(resolved.gpu_only)
    cpu_required.merge(resolved.cpu_required)
    for path in resolved.geometry_slots:
        if not native_optics and optical_candidates.has(path):continue
        var optical:Dictionary=NativeSupport.required_paths(path,resolved.geometry_slots[path],cache)
        for optical_path in optical.values():
            # A native tail may overlap the next ordinary movement. Prepare
            # metadata for that clip's support masks, without demanding/uploading
            # them unless the real native renderer actually needs them.
            optical_candidates[optical_path]=true
            if native_optics:
                paths[optical_path]=true;cpu_required[optical_path]=true
    var effects=Conditions.paths(actor,cache)
    paths.merge(effects);cpu_required.merge(effects)

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

static func _visible_ids(visible: Dictionary, senses: Variant, audience: Dictionary) -> void:
    for id in audience.controlled: visible[id] = true
    var entities: Dictionary = senses.entities if senses != null else {}
    for id in entities:
        if entities[id].get("visual",false): visible[id] = true

static func roles_for(plan: Dictionary, paths: Dictionary) -> Dictionary:
    var roles = {"gpu_only":{},"cpu_required":{}}
    for path in paths:
        if plan.cpu_required.has(path): roles.cpu_required[path] = true
        elif plan.gpu_only.has(path): roles.gpu_only[path] = true
    return roles

static func plan(state: Dictionary, groups: Array, cache: Dictionary) -> Dictionary:
    var required = {}
    var upcoming = {}
    var errors: Array = []
    var upcoming_errors: Array = []
    var gpu_only = {}
    var cpu_required = {}
    errors.append_array(Characters.Catalog.validate_native(cache))
    if state.is_empty(): return {"required":required,"upcoming":upcoming,"errors":errors,"upcoming_errors":upcoming_errors,"gpu_only":gpu_only,"cpu_required":cpu_required}
    var actors: Dictionary = state.actors.duplicate()
    var senses: Variant = state.senses
    var audience: Dictionary = state.audience
    var optical_candidates={}
    var native_optics=groups.any(func(group):return group.get("components",[]).any(func(row):return row.get("native_spell",false)))
    for actor in actors.values():
        if WorldRows.visible_actor(actor,state): _add_actor(required,actor,[],cache,errors,gpu_only,cpu_required,native_optics,optical_candidates)
    for group_index in range(groups.size()):
        var group: Dictionary = groups[group_index]
        var paths: Dictionary = required if group_index == 0 else upcoming
        var group_errors: Array = errors if group_index == 0 else upcoming_errors
        var witnesses = {}
        var visible = {}
        for id in actors: _witness(witnesses,id,actors[id])
        for id in group.get("staged_actors",{}):
            _witness(witnesses,id,group.staged_actors[id])
            visible[id] = true
        _visible_ids(visible,senses,audience)
        for commit in group.get("commits",[]):
            var delta: Dictionary = commit.delta
            for id in delta.get("actors",{}):
                _witness(witnesses,id,delta.actors[id])
                actors[id] = delta.actors[id]
            senses = delta.get("set",{}).get("senses",senses)
            audience = delta.get("set",{}).get("audience",audience)
            _visible_ids(visible,senses,audience)
        # Union exact observed/committed outfits within this one group. This
        # conservative preparation changes no state and exposes no actor early.
        for id in witnesses:
            if not visible.has(id): continue
            for actor in witnesses[id]: _add_actor(paths,actor,[],cache,group_errors,gpu_only,cpu_required,native_optics,optical_candidates)
        var requested = {}
        for track in group.get("actor_tracks",[]):
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
                _add_actor(paths,shown,[track.clip],cache,group_errors,gpu_only,cpu_required,native_optics,optical_candidates)
    for path in cpu_required: gpu_only.erase(path)
    return {"required":required,"upcoming":upcoming,"errors":errors,"upcoming_errors":upcoming_errors,"gpu_only":gpu_only,"cpu_required":cpu_required,"optical_candidates":optical_candidates}

static func close(data: Dictionary) -> void:
    data.demand_snapshot = {}
    data.plan_pending = {}; data.optional_pending = {}
    if data.plan_task >= 0:
        WorkerThreadPool.wait_for_task_completion(data.plan_task)
        data.plan_task = -1
    for job in data.decode_jobs: WorkerThreadPool.wait_for_task_completion(job.task)
    data.decode_jobs.clear()
    data.pending.clear()
    data.queued.clear()
