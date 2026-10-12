extends RefCounted
# Absolute displayed time is independent of SDK consumption and wall-clock time.
const Tracks = preload("res://presentation/tracks.gd")
const Compiler = preload("res://presentation/compiler.gd")
const EventTrace = preload("res://presentation/event_trace.gd")
var state: Dictionary = {}
var queue: Array = []
var current: Dictionary = {}
var display_ms = 0.0
var group_start_ms = 0.0
var commit_index = 0
var sequence = -1
var paused = false
var revision = 0
var world_revision = 0
var initialization_revision = 0
var world_changes: Dictionary = {"full":true,"tiles":{},"objects":{},"senses":false,"revision":0}
var world_changes_consumed = -1

func take_world_changes(previous_revision: int) -> Dictionary:
    # There is one displayed-world consumer. Union keys survive every commit,
    # advance and media hold until that consumer can publish its complete view.
    var result = world_changes
    if previous_revision != world_changes_consumed or int(result.revision) != world_revision:
        result.full = true
    result.revision = world_revision
    world_changes = {"full":false,"tiles":{},"objects":{},"senses":false,"revision":world_revision}
    world_changes_consumed = world_revision
    return result

func _record_world_changes(delta: Dictionary) -> void:
    for key in delta.get("tiles",{}): world_changes.tiles[key] = true
    for key in delta.get("objects",{}): world_changes.objects[key] = true
    for key in delta.get("objects_removed",[]): world_changes.objects[key] = true
    world_changes.senses = world_changes.senses or delta.get("set",{}).has("senses")
    world_changes.revision = world_revision
const DIAGNOSTIC_LIMIT = 2000
var completed_group_count = 0
var skipped_count = 0
var completed_groups: Array = []
var skipped: Array = []
var media_ready: Callable
var world_ready: Callable
var waiting_for_world = false
var pending_world: Dictionary = {}
var _world_plan: Dictionary = {}
var _preview_world: Dictionary = {}
var _preview_signature: Array = []
var _scheduled_group: Dictionary = {}
var _staged_world_times: Array = []
var retire_group: Callable
var waiting_for_media = false
var trace = EventTrace.create()
var trace_revision: int:
    get: return int(trace.revision)

func accept(message: Dictionary) -> void:
    if message.kind == "initialization":
        initialization_revision += 1
        pending_world = {}; _world_plan = {}; waiting_for_world = false
        _preview_world = {}; _preview_signature = []
        _scheduled_group = {}; _staged_world_times = []
        # A new admitted initialization replaces the pending presentation epoch.
        # Retire immutable old groups through the existing worker owner; none may
        # later apply an old operation to this new canonical snapshot.
        var previous = queue
        queue = []
        if not current.is_empty(): previous.push_front(current)
        current = {}; commit_index = 0; group_start_ms = display_ms
        waiting_for_media = false
        if retire_group.is_valid():
            for group in previous: retire_group.call(group)
        state = message.state
        sequence = int(message.sequence)
        revision += 1
        world_revision += 1
        world_changes = {"full":true,"tiles":{},"objects":{},"senses":true,"revision":world_revision}
        var initial_events: Array = message.get("events",[])
        EventTrace.activate(trace,initial_events,display_ms)
        for event in initial_events: EventTrace.commit(trace,int(message.sequence),event.event_uuid)
    else:
        queue.append_array(message.groups)
        if not message.groups.is_empty(): trace.revision += 1
        skipped_count += message.get("skipped",[]).size()
        skipped.append_array(message.get("skipped",[]))
        if skipped.size()>DIAGNOSTIC_LIMIT: skipped = skipped.slice(skipped.size()-DIAGNOSTIC_LIMIT)

func busy() -> bool:
    return not current.is_empty() or not queue.is_empty()

func advance(delta_ms: float) -> void:
    if world_ready.is_valid():
        _advance_with_world_preparation(delta_ms)
    else:
        pending_world = {}; _world_plan = {}; waiting_for_world = false
        _scheduled_group = {}; _staged_world_times = []
        _advance_immediate(delta_ms)

func _advance_immediate(delta_ms: float) -> void:
    if paused or state.is_empty(): return
    waiting_for_media = false
    var first: Dictionary = current if not current.is_empty() else (queue[0] if not queue.is_empty() else {})
    if media_ready.is_valid() and not media_ready.call(first):
        waiting_for_media = true
        return
    var target = display_ms + maxf(0,delta_ms)
    while true:
        if current.is_empty():
            if queue.is_empty(): display_ms = target; return
            # Preparation must precede even zero-duration groups and staging.
            # Waiting wall time is not added to the presentation clock later.
            if media_ready.is_valid() and not media_ready.call(queue[0]):
                waiting_for_media = true
                return
            current = queue.pop_front()
            group_start_ms = display_ms
            commit_index = 0
            EventTrace.activate(trace,current.get("events",[]),group_start_ms)
            _resolve_preparation_issue(current)
        var local = minf(target-group_start_ms,float(current.duration_ms))
        var commits: Array = current.commits
        while commit_index < commits.size() and float(commits[commit_index].at_ms) <= local + 0.000001:
            var delta: Dictionary = commits[commit_index].delta
            Compiler.apply_delta(state,delta)
            if commits[commit_index].has("event_uuid"):
                EventTrace.commit(trace,int(current.operation_sequence),commits[commit_index].event_uuid)
            EventTrace.append_logs(trace,commits[commit_index].get("trace_logs",[]))
            if not delta.get("tiles",{}).is_empty() or not delta.get("objects",{}).is_empty() or not delta.get("objects_removed",[]).is_empty() or delta.get("set",{}).has("senses") or delta.get("set",{}).has("connectors"):
                world_revision += 1
                _record_world_changes(delta)
            commit_index += 1
            revision += 1
        EventTrace.tick(trace,current.get("events",[]),local)
        if target < group_start_ms+float(current.duration_ms):
            display_ms = target
            return
        display_ms = group_start_ms+float(current.duration_ms)
        if current.get("operation_end",false): sequence = int(current.operation_sequence)
        completed_group_count += 1
        completed_groups.append({"id":current.id,"at_ms":display_ms,"sequence":sequence})
        if completed_groups.size()>DIAGNOSTIC_LIMIT: completed_groups.pop_front()
        if retire_group.is_valid(): retire_group.call(current)
        current = {}

func _world_delta(delta: Dictionary) -> bool:
    return not delta.get("tiles",{}).is_empty() or not delta.get("objects",{}).is_empty() or not delta.get("objects_removed",[]).is_empty() or delta.get("set",{}).has("senses") or delta.get("set",{}).has("connectors")

func _advance_with_world_preparation(delta_ms: float) -> void:
    if paused or state.is_empty(): return
    waiting_for_world = false; waiting_for_media = false
    var first: Dictionary = current if not current.is_empty() else (queue[0] if not queue.is_empty() else {})
    if media_ready.is_valid() and not media_ready.call(first):
        waiting_for_media = true
        return
    if pending_world.is_empty():
        var plan = _plan_world_advance(display_ms+maxf(0,delta_ms))
        waiting_for_media = plan.media_wait
        if not plan.boundary:
            _apply_world_plan(plan)
            return
        _world_plan = plan
        pending_world = _world_candidate(plan)
    # Reuse this exact passive candidate across waits. The elapsed wait is never
    # appended to display time, and no trace activation/commit has occurred yet.
    if not world_ready.call(pending_world):
        waiting_for_world = true
        return
    _apply_world_plan(_world_plan)
    pending_world = {}; _world_plan = {}
    # Even a zero-duration boundary yields to the scene for atomic publication.

func _group_stage_times(group: Dictionary) -> Array:
    if is_same(_scheduled_group,group): return _staged_world_times
    _scheduled_group = group
    var times = {}
    for key in group.get("staged_tiles",{}):
        times[float(group.get("staged_tile_at_ms",{}).get(key,0.0))] = true
    _staged_world_times = times.keys(); _staged_world_times.sort()
    return _staged_world_times

func _tiles_for(group: Dictionary, local: float, canonical: Dictionary) -> Dictionary:
    var result = {}
    for key in group.get("staged_tiles",{}):
        if not canonical.tiles.has(key) and local>=float(group.get("staged_tile_at_ms",{}).get(key,0.0)):
            result[key] = group.staged_tiles[key]
    return result

func _actors_for(group: Dictionary, local: float) -> Dictionary:
    var result = {}
    for id in group.get("staged_actors",{}):
        if local>=float(group.get("staged_at_ms",{}).get(id,0.0)): result[id] = group.staged_actors[id]
    return result

func _plan_world_advance(target: float) -> Dictionary:
    # Plan only ordinary trace/actor progress preceding the next world boundary.
    # No state copy or source enumeration occurs on an ordinary animation frame.
    var group: Dictionary = current
    var start = group_start_ms
    var first_commit = commit_index
    var cursor = display_ms
    var activate = false
    if group.is_empty():
        if queue.is_empty(): return {"segments":[],"display_ms":target,"boundary":false,"media_wait":false}
        group = queue[0]
        start = cursor; first_commit = 0; activate = true
    if media_ready.is_valid() and not media_ready.call(group):
        return {"segments":[],"display_ms":cursor,"boundary":false,"media_wait":true}
    return _plan_group_world(group,start,first_commit,cursor,target,activate,_group_stage_times(group))

func _plan_group_world(group: Dictionary, start: float, first_commit: int, cursor: float,
        target: float, activate: bool, stage_times: Array) -> Dictionary:
    var segments: Array = []
    var duration = float(group.duration_ms)
    var before = cursor-start
    var local = minf(target-start,duration)
    var boundary_at = INF
    var commits: Array = group.commits
    for i in range(first_commit,commits.size()):
        var at = float(commits[i].at_ms)
        if at>local+0.000001: break
        if _world_delta(commits[i].delta): boundary_at = at; break
    for at in stage_times:
        # Match staged_tiles()'s exact >= admission test. Commit tolerance must
        # not erase a nearby but still unadmitted support boundary.
        if at>local: break
        if not (at>before or (activate and at<=0.0)): continue
        # A support already canonically disclosed creates no staging edge.
        var newly_staged = false
        for key in group.get("staged_tiles",{}):
            if not state.tiles.has(key) and float(group.get("staged_tile_at_ms",{}).get(key,0.0))==at:
                newly_staged = true; break
        if newly_staged: boundary_at = minf(boundary_at,at); break
    if local>=duration and not _tiles_for(group,duration,state).is_empty():
        boundary_at = minf(boundary_at,duration)
    var boundary = boundary_at!=INF
    if boundary: local = minf(local,boundary_at)
    var end_commit = first_commit
    while end_commit<commits.size() and float(commits[end_commit].at_ms)<=local+0.000001: end_commit += 1
    var complete = local>=duration
    segments.append({"group":group,"start_ms":start,"first_commit":first_commit,"end_commit":end_commit,
        "local_ms":local,"activate":activate,"complete":complete})
    cursor = start+local
    if boundary: return {"segments":segments,"display_ms":cursor,"boundary":true,"media_wait":false}
    if not complete: return {"segments":segments,"display_ms":target,"boundary":false,"media_wait":false}
    # Media ownership still names this group until its completion is
    # published. Never preflight another group against its pins or state.
    return {"segments":segments,"display_ms":cursor,"boundary":false,"media_wait":false}

func _support_signature() -> Array:
    var supports = staged_tiles()
    if supports.is_empty(): return []
    # Immutable stage values belong to this occurrence, not merely to a cell.
    return [current.operation_sequence,current.id,supports.keys()]

func preview_world() -> Dictionary:
    # Read only already received groups. No media callback, trace activation,
    # clock advance or staging admission occurs here. One cached snapshot spans
    # ordinary actor/log commits and animation samples before its world boundary.
    if state.is_empty(): return {}
    if not pending_world.is_empty(): return pending_world
    var groups: Array = []
    if not current.is_empty(): groups.append(current)
    for i in range(mini(2-groups.size(),queue.size())): groups.append(queue[i])
    var signature: Array = [initialization_revision,world_revision,_support_signature()]
    for group in groups: signature.append([group.operation_sequence,group.id])
    if signature==_preview_signature: return _preview_world
    _preview_signature = signature
    _preview_world = {}
    var segments: Array = []
    var cursor = display_ms
    for group in groups:
        var active = is_same(group,current)
        var start = group_start_ms if active else cursor
        var first = commit_index if active else 0
        var times = {}
        for key in group.get("staged_tiles",{}):
            times[float(group.get("staged_tile_at_ms",{}).get(key,0.0))] = true
        var ordered: Array = times.keys(); ordered.sort()
        var plan = _plan_group_world(group,start,first,cursor,INF,not active,ordered)
        segments.append_array(plan.segments)
        if plan.boundary:
            plan.segments = segments
            _preview_world = _world_candidate(plan)
            return _preview_world
        cursor = plan.display_ms
    return {}

func _world_candidate(plan: Dictionary) -> Dictionary:
    var snapshot = state.duplicate()
    # These are the collections Compiler.apply_delta mutates. Their immutable
    # after-values remain shared; collection ownership never aliases live state.
    for field in ["actors","tiles","objects","spatial_commit_cursors","combat_log_appends"]:
        if state.has(field): snapshot[field] = state[field].duplicate()
    var changes = {"full":false,"tiles":{},"objects":{},"senses":false}
    var next_revision = revision; var next_world_revision = world_revision; var next_sequence = sequence
    for segment in plan.segments:
        for i in range(segment.first_commit,segment.end_commit):
            var delta: Dictionary = segment.group.commits[i].delta
            Compiler.apply_delta(snapshot,delta)
            for key in delta.get("tiles",{}): changes.tiles[key] = true
            for id in delta.get("objects",{}): changes.objects[id] = true
            for id in delta.get("objects_removed",[]): changes.objects[id] = true
            changes.senses = changes.senses or delta.get("set",{}).has("senses")
            next_revision += 1
            if _world_delta(delta): next_world_revision += 1
        if segment.complete and segment.group.get("operation_end",false): next_sequence = int(segment.group.operation_sequence)
    var last: Dictionary = plan.segments.back()
    var group: Dictionary = {} if last.complete else last.group
    var supports = _tiles_for(group,last.local_ms,snapshot)
    var previous = staged_tiles()
    for key in previous:
        if not supports.has(key) or previous[key]!=supports[key]: changes.tiles[key] = true
    for key in supports:
        if not previous.has(key) or previous[key]!=supports[key]: changes.tiles[key] = true
    var presented = snapshot
    if not supports.is_empty():
        presented = snapshot.duplicate(); presented.tiles = snapshot.tiles.duplicate(); presented.tiles.merge(supports)
    changes.revision = next_world_revision
    return {"key":[initialization_revision,revision,last.group.operation_sequence,last.group.id,last.start_ms,last.end_commit,last.local_ms,last.complete],
        "preparation_key":[initialization_revision,world_revision,_support_signature(),last.group.operation_sequence,last.group.id,last.end_commit,last.local_ms,last.complete],
        "source_group_id":last.group.id,
        "state":snapshot,"presentation_state":presented,"staged_tiles":supports,"staged_actors":_actors_for(group,last.local_ms),
        "changes":changes,"display_ms":plan.display_ms,"revision":next_revision,"world_revision":next_world_revision,
        "sequence":next_sequence,"group_id":group.get("id",""),"operation_sequence":int(last.group.operation_sequence)}

func _apply_world_plan(plan: Dictionary) -> void:
    for segment in plan.segments:
        if segment.activate:
            current = queue.pop_front()
            group_start_ms = segment.start_ms; commit_index = 0
            EventTrace.activate(trace,current.get("events",[]),group_start_ms)
            _resolve_preparation_issue(current)
        for i in range(segment.first_commit,segment.end_commit):
            var commit: Dictionary = current.commits[i]
            var delta: Dictionary = commit.delta
            Compiler.apply_delta(state,delta)
            if commit.has("event_uuid"): EventTrace.commit(trace,int(current.operation_sequence),commit.event_uuid)
            EventTrace.append_logs(trace,commit.get("trace_logs",[]))
            if _world_delta(delta):
                world_revision += 1; _record_world_changes(delta)
            commit_index += 1; revision += 1
        EventTrace.tick(trace,current.get("events",[]),segment.local_ms)
        display_ms = segment.start_ms+segment.local_ms
        if segment.complete:
            if current.get("operation_end",false): sequence = int(current.operation_sequence)
            completed_group_count += 1
            completed_groups.append({"id":current.id,"at_ms":display_ms,"sequence":sequence})
            if completed_groups.size()>DIAGNOSTIC_LIMIT: completed_groups.pop_front()
            _scheduled_group = {}; _staged_world_times = []
            if retire_group.is_valid(): retire_group.call(current)
            current = {}
    display_ms = plan.display_ms

func staged_actors() -> Dictionary:
    var admitted = {}
    var local = display_ms-group_start_ms
    for id in current.get("staged_actors",{}):
        if local >= float(current.get("staged_at_ms",{}).get(id,0.0)):
            admitted[id] = current.staged_actors[id]
    return admitted

func staged_tiles() -> Dictionary:
    var admitted = {}
    var local = display_ms-group_start_ms
    for key in current.get("staged_tiles",{}):
        if not state.tiles.has(key) and local >= float(current.get("staged_tile_at_ms",{}).get(key,0.0)):
            admitted[key] = current.staged_tiles[key]
    return admitted

func presentation_state() -> Dictionary:
    # First disclosed support can be needed to draw an admitted actor before
    # its canonical world commit. This overlay never changes reducer state or
    # replaces a tile which is already known to the displayed state.
    var tiles = staged_tiles()
    if tiles.is_empty(): return state
    var result = state.duplicate()
    result.tiles = state.tiles.duplicate()
    result.tiles.merge(tiles)
    return result

func actor_samples() -> Dictionary:
    return Tracks.samples(current.get("actor_tracks",[]),display_ms-group_start_ms)

func diagnostics() -> Dictionary:
    return {"display_ms":display_ms,"sequence":sequence,"queued_groups":queue.size(),"active_group":current.get("id",""),
        "paused":paused,"waiting_for_media":waiting_for_media,"waiting_for_world":waiting_for_world,"pending_world_key":pending_world.get("key",[]),"revision":revision,"completed_groups":completed_group_count,"completed_retained":completed_groups.size(),"skipped_count":skipped_count,"skipped":skipped}


func event_trace(limit: int = 200, selected_id: String = "", status_filter: String = "") -> Dictionary:
    var queued = 0
    for group in queue: queued += group.get("events",[]).size()
    return EventTrace.snapshot(trace,limit,selected_id,queued,status_filter)

func event_log(limit: int = 200) -> Dictionary:
    return EventTrace.logs(trace,limit)

func record_presented(evidence: Array) -> void:
    EventTrace.record(trace,evidence)

func record_render_issue(track_id: String, reason: String) -> void:
    record_presented([{"trace_track_id":track_id,"visible":false,"reason":reason}])

func record_preparation_issue(group_id: String, reason: String) -> void:
    var group: Dictionary = current if not current.is_empty() else (queue[0] if not queue.is_empty() else {})
    if group.is_empty() or group.get("id") != group_id: return
    var id = "preparation:%s:%s" % [group.operation_sequence,group.id]
    if trace.rows.has(id):
        if trace.rows[id].reasons != [reason]:
            trace.rows[id].reasons = [reason]
            trace.revision += 1
        return
    # Only the stalled boundary is identified: no future actor, fact or log.
    var row = {"id":id,"sequence":int(group.operation_sequence),"group_id":group.id,
        "event_uuid":"","lineage_uuid":"","source_index":-1,"parent_event":null,"parent_lineage":null,
        "kind":"preparation","phase":"","name":"Required media unavailable","behavior_id":null,
        "actor_uuid":null,"target_uuid":null,"status":"missing","reasons":[reason],"components":[],
        "committed":false,"completed":false,"committed_log":null,"versions":[],"_end_ms":0.0}
    EventTrace.activate(trace,[row],display_ms)

func _resolve_preparation_issue(group: Dictionary) -> void:
    var id = "preparation:%s:%s" % [group.operation_sequence,group.id]
    if not trace.rows.has(id): return
    var row: Dictionary = trace.rows[id]
    row.status = "state_only"
    row.reasons = ["preparation_recovered"]
    row.completed = true
    trace.revision += 1
