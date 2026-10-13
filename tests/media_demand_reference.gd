extends RefCounted
# Frozen demand + selection-delta bodies from tested checkpoint 927a55b.
# Only stable residency/publication helpers remain shared. The caller clears
# demand_snapshot so every comparison executes this pre-optimization algorithm.
const Media = preload("res://presentation/media_warmup.gd")

static func _changed_roles(previous: Dictionary, current: Dictionary) -> Dictionary:
    var changed = {}
    for role in current:
        var old: Dictionary = previous.get(role,{})
        var new: Dictionary = current[role]
        # Accepted family role owners are immutable and reused by the worker.
        if is_same(old,new): continue
        for path in old:
            if not new.has(path): changed[path] = true
        for path in new:
            if not old.has(path): changed[path] = true
    return changed


static func _selection_delta(data: Dictionary, previous: Dictionary, role_changes: Dictionary, new_boot: bool) -> Dictionary:
    var refresh: Dictionary = role_changes.duplicate()
    if new_boot:
        for path in data.boot_paths: refresh[path] = true
    for path in previous:
        if data.preload_selected.has(path): continue
        data.selected_ready.erase(path); data.selected_failed.erase(path)
    for path in data.preload_selected:
        if new_boot or not previous.has(path): refresh[path] = true
    for path in refresh:
        Media._refresh_path(data,path)
        data.selection_refreshed += 1
    return refresh


static func demand(data: Dictionary, paths: Dictionary, environment: Dictionary = {}, fixtures: Dictionary = {}, gpu_only: Dictionary = {}, cpu_required: Dictionary = {}) -> void:
    var started = Time.get_ticks_usec()
    # Last-call CPU evidence only. Children are exclusive; total is inclusive.
    var phases = {"guard":0.0,"estimate":0.0,"selection":0.0,"role_diff":0.0,"selection_refresh":0.0,
        "resident_refresh":0.0,"queue":0.0,"snapshot":0.0,"total":0.0}
    data.demand_phases = phases
    data.demand_counts = {"required":paths.size(),"known":data.encounter.get("paths",{}).size(),
        "pending_before":data.pending.size(),"affected":0,"role_changes":0,"selection_changed":false,"noop":false}
    var exact_roles = [environment,fixtures,gpu_only,cpu_required]
    var unchanged = Media._same_demand(data,paths,exact_roles)
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
        if not environment.has(path) and not family_environment.has(path): Media._invalidate(data); break
    for path in environment:
        if not data.environment.has(path) and not family_environment.has(path): Media._invalidate(data); break
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
    for path in paths:
        if not data.encounter.get("estimates",{}).get(path,{}).has("bytes"): exact_estimates = false
        var size = Media._estimate(data,path)
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
                    if not paths.has(path): extra_bytes += maxi(0,Media._estimate(data,path))
        # A worker-computed total avoids re-estimating the whole resident family
        # on ordinary growth. Exact priority/frozen boot selection still uses
        # the original bounded algorithm when the entire family cannot fit.
        if not summary.is_empty() and summary.unknown==0 and unknown==0 and int(summary.bytes)+extra_bytes<=int(data.budget_bytes):
            selected = known
            preload_bytes = int(summary.bytes)
            if not boot_extra.is_empty():
                selected = known.duplicate()
                selected.merge(boot_extra)
                for path in boot_extra: preload_bytes += maxi(0,Media._estimate(data,path))
        else:
            if data.boot_started and not data.boot_complete:
                for path in data.boot_paths:
                    selected[path] = data.boot_paths[path]
                    if not paths.has(path): used += maxi(0,Media._estimate(data,path))
            for path in known:
                if selected.has(path): continue
                var size = Media._estimate(data,path)
                if paths.has(path): selected[path] = known[path]; continue
                if unknown>0 or size<0 or used+size>int(data.budget_bytes): skipped += 1; continue
                selected[path] = known[path]
                used += size
            for path in selected: preload_bytes += maxi(0,Media._estimate(data,path))
        data.preload_selected = selected
        data.preload_skipped = skipped
        data.preload_estimated_bytes = preload_bytes
        var new_boot: bool = not data.encounter.is_empty() and not data.boot_started
        if new_boot:
            data.boot_started = true
            # Startup waits only for exact displayed/already-received demand.
            # Optional animations and normal treatments warm within the budget
            # after this boundary and never delay initial interaction.
            data.boot_paths = paths.duplicate()
        var role_started = Time.get_ticks_usec()
        var roles = Media._family_roles(data.encounter)
        var changed = _changed_roles(data.selection_roles,roles)
        phases.role_diff = (Time.get_ticks_usec()-role_started)/1000.0
        data.demand_counts.role_changes = changed.size()
        # Queue classifications were counted before accepted family roles moved.
        # Only a real role change of existing work invalidates those aggregates.
        for path in changed:
            if data.queued.has(path): Media._invalidate(data); break
        data.selection_roles = roles
        var refresh_started = Time.get_ticks_usec()
        refresh = _selection_delta(data,previous_selected,changed,new_boot)
        phases.selection_refresh = (Time.get_ticks_usec()-refresh_started)/1000.0
    phases.selection = (Time.get_ticks_usec()-phase_started)/1000.0-phases.role_diff-phases.selection_refresh
    phase_started = Time.get_ticks_usec()
    var affected: Dictionary = previous_paths.duplicate()
    affected.merge(paths)
    if selection_changed:
        for path in previous_selected:
            if not data.preload_selected.has(path): affected[path] = true
        for path in data.preload_selected:
            if not previous_selected.has(path): affected[path] = true
    # Membership changes affect pin accounting, not every resident texture.
    if not data.stats.is_empty():
        for path in affected:
            if not data.resident.has(path): continue
            var prior_pin: bool = previous_paths.has(path) or previous_selected.has(path)
            var current_pin: bool = Media._pinned(data,path)
            if prior_pin!=current_pin:
                var resident: Dictionary = data.resident[path]
                data.stats[resident.environment].pinned_bytes += (int(current_pin)-int(prior_pin))*int(resident.bytes)
    affected.merge(refresh)
    data.demand_counts.affected = affected.size()
    for path in affected: Media._refresh_resident_role(data,path)
    phases.resident_refresh = (Time.get_ticks_usec()-phase_started)/1000.0
    phase_started = Time.get_ticks_usec()
    # Promote mandatory sources ahead of unfinished background warmup. Once
    # warm, an action checks only its own small packet, not every retained sheet.
    var pending: Array = data.pending
    for request in pending:
        Media._pending_delta(data,request.path,-1)
        data.queued.erase(request.path)
    data.pending = []
    for path in paths: Media.enqueue(data,path,paths[path])
    for request in pending:
        if data.preload_selected.has(request.path) and not paths.has(request.path): Media.enqueue(data,request.path,request.absolute)
    for path in refresh:
        if data.preload_selected.has(path) and not paths.has(path): Media.enqueue(data,path,data.preload_selected[path])
    phases.queue = (Time.get_ticks_usec()-phase_started)/1000.0
    phase_started = Time.get_ticks_usec()
    # Without header estimates, residency progress can change the budget input.
    # Keep that uncommon path exhaustive instead of tracking another generation.
    if exact_estimates and not summary.is_empty() and summary.unknown==0:
        var copied_roles: Array = []
        for role in exact_roles: copied_roles.append(role.duplicate())
        data.demand_snapshot = {"paths":paths.duplicate(),"order":paths.keys(),"roles":copied_roles,
            "encounter":data.encounter,"epoch":data.encounter_epoch,"budget":data.budget_bytes,
            "boot":[data.boot_started,data.boot_complete]}
    phases.snapshot = (Time.get_ticks_usec()-phase_started)/1000.0
    phases.total = (Time.get_ticks_usec()-started)/1000.0

