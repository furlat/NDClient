extends RefCounted
# Absolute displayed time is independent of SDK consumption and wall-clock time.
const Characters=preload("res://presentation/characters.gd")
const Tracks = preload("res://presentation/tracks.gd")
const Compiler = preload("res://presentation/compiler.gd")
const EventTrace = preload("res://presentation/event_trace.gd")
const Conditions = preload("res://presentation/conditions.gd")
const ImpactPlacement = preload("res://presentation/impact_placement.gd")
const FrameProfile = preload("res://frame_profile.gd")
var profile:Dictionary={"phases":{}}
var state: Dictionary = {}
var queue: Array = []
var current: Dictionary = {}
var display_ms = 0.0
# A clip change binds its prepared, resident sources in sampling, and an
# effect-layer change builds its layers there. Hosts that still publish these
# through a private world preparation keep them as world boundaries.
var source_cut_boundaries := true
var _actor_samples_group: Dictionary = {}
var _actor_samples_at := NAN
var _actor_samples_resources:int=-1
var _actor_samples: Dictionary = {}
var media_target_ms = 0.0
var group_start_ms = 0.0
var commit_index = 0
var sequence = -1
var paused = false
var revision = 0
var resource_revision = 0
var world_revision = 0
var initialization_revision = 0
var world_changes: Dictionary = {"full":true,"tiles":{},"objects":{},"senses":false,"order":[],"revision":0}
var world_changes_consumed = -1

func take_world_changes(previous_revision: int) -> Dictionary:
    # There is one displayed-world consumer. Union keys survive every commit,
    # advance and media hold until that consumer can publish its complete view.
    var result = world_changes
    if previous_revision != world_changes_consumed or int(result.revision) != world_revision:
        result.full = true
    result.revision = world_revision
    world_changes = {"full":false,"tiles":{},"objects":{},"senses":false,"order":[],"revision":world_revision}
    world_changes_consumed = world_revision
    return result

func _record_world_changes(delta: Dictionary) -> void:
    for key in delta.get("tiles",{}): world_changes.tiles[key] = true
    for key in delta.get("objects",{}): world_changes.objects[key] = true
    for key in delta.get("objects_removed",[]): world_changes.objects[key] = true
    world_changes.senses = world_changes.senses or delta.get("set",{}).has("senses")
    world_changes.revision = world_revision

static func _append_membership_order(order: Array, delta: Dictionary, before: Dictionary) -> void:
    # Match Compiler.apply_delta's dictionary insertion/removal order. Dirty
    # keys alone cannot distinguish a replacement from a remove-and-reappend.
    var removed: Dictionary = {}
    for id in delta.get("objects_removed",[]):
        if before.objects.has(id) and not removed.has(id):
            order.append({"kind":"objects","id":id,"remove":true})
            removed[id] = true
    for id in delta.get("tiles",{}):
        if not before.tiles.has(id): order.append({"kind":"tiles","id":id,"remove":false})
    for id in delta.get("objects",{}):
        if removed.has(id) or not before.objects.has(id): order.append({"kind":"objects","id":id,"remove":false})
const DIAGNOSTIC_LIMIT = 2000
var completed_group_count = 0
var skipped_count = 0
var completed_groups: Array = []
var skipped: Array = []
var media_ready: Callable
var replay_media_ready: Callable
var replay_media_release: Callable
var world_ready: Callable
var world_published:Callable
var waiting_for_world = false
var pending_world: Dictionary = {}
var _world_plan: Dictionary = {}
var _replay_prepared_plan: Dictionary = {}
var _preview_world: Dictionary = {}
var _preview_signature: Array = []
var _static_preview_world:Dictionary={}
var _static_preview_signature:Array=[]
var _scheduled_group: Dictionary = {}
var _staged_world_times: Array = []
var _staged_group: Dictionary = {}
var _staged_times: Array = []
var _staged_indices: Array = []
var retire_group: Callable
var waiting_for_media = false
var retained_components: Array = []
var retained_directions: Dictionary = {}
var resolved_impacts: Dictionary = {}
var condition_owners: Dictionary = {}
var item_effect_owners:Dictionary={}
const NativeItems=preload("res://presentation/native_items.gd")
var appearance_cache:Dictionary={}
var spatial_effect_owners:Dictionary={}
const NativePersistent=preload("res://presentation/native_persistent.gd")
const Appearance=preload("res://presentation/condition_appearance.gd")
var crossed_audio: Array = []
var component_sample_ms = -1.0
var trace = EventTrace.create()
var trace_revision: int:
    get: return int(trace.revision)

func accept(message: Dictionary) -> void:
    if message.kind == "initialization":
        initialization_revision += 1
        media_target_ms = display_ms
        pending_world = {}; _world_plan = {}; waiting_for_world = false
        _replay_prepared_plan={}
        _preview_world = {}; _preview_signature = []
        _static_preview_world={};_static_preview_signature=[]
        _scheduled_group = {}; _staged_world_times = []; _staged_group = {}
        # A new admitted initialization replaces the pending presentation epoch.
        # Retire immutable old groups through the existing worker owner; none may
        # later apply an old operation to this new canonical snapshot.
        var previous = queue
        queue = []
        if not current.is_empty(): previous.push_front(current)
        current = {}; commit_index = 0; group_start_ms = display_ms
        retained_components=[]; retained_directions={}; resolved_impacts={}
        condition_owners={}; spatial_effect_owners={}; item_effect_owners={};crossed_audio=[];component_sample_ms=-1.0
        waiting_for_media = false
        if retire_group.is_valid():
            for group in previous: retire_group.call(group)
        state = message.state
        Conditions.observe(condition_owners,state.actors,display_ms,true)
        NativeItems.observe(item_effect_owners,state,display_ms,appearance_cache)
        NativePersistent.observe_spatial(spatial_effect_owners,state.senses.get("spatial_effects",{}),display_ms,true)
        sequence = int(message.sequence)
        revision += 1
        resource_revision += 1
        world_revision += 1
        world_changes = {"full":true,"tiles":{},"objects":{},"senses":true,"order":[],"revision":world_revision}
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
    # Readiness proves the proposed frame before any event/state publication.
    # Waiting never accrues extra time; retry from the unchanged display clock.
    media_target_ms = display_ms + maxf(0,delta_ms)
    if world_ready.is_valid():
        _advance_with_world_preparation(delta_ms)
    else:
        pending_world = {}; _world_plan = {}; waiting_for_world = false
        _scheduled_group = {}; _staged_world_times = []; _staged_group = {}
        _advance_immediate(delta_ms)

# Offline comparisons prepare each independent reducer before publishing either.
# These use the same group planner and delta consumer as ordinary playback.
func replay_plan(target_ms: float) -> Dictionary:
    # A comparison cut includes every due group, including consecutive zero-time
    # tails. Per-group media admission belongs to live playback; a replay host
    # proves the received recording's complete source closure before publication.
    var target=maxf(display_ms,target_ms)
    var retained_end:float=_appearance_end_between(display_ms,target)
    if not is_inf(retained_end):target=retained_end
    var plan={"segments":[],"groups":[],"display_ms":target,"boundary":not is_inf(retained_end),"media_wait":false,"replay":true}
    var cursor=display_ms
    var groups: Array=[]
    if not current.is_empty():groups.append(current)
    groups.append_array(queue)
    for group in groups:
        var active=is_same(group,current)
        var start=group_start_ms if active else maxf(cursor,float(group.get("preview_start_ms",cursor)))
        if target<start:break
        var first=commit_index if active else 0
        var step=_plan_group_world(group,start,first,cursor,target,not active,_group_stage_times(group),false)
        plan.segments.append_array(step.segments)
        plan.groups.append(group)
        plan.boundary=plan.boundary or step.boundary
        cursor=step.display_ms
        if not step.segments.back().complete:break
    plan.base = [initialization_revision,revision,world_revision,display_ms,completed_group_count,group_start_ms,commit_index,queue.size()]
    plan.base_current=current
    return plan

func replay_plan_current(plan: Dictionary) -> bool:
    if plan.get("base",[]) != [initialization_revision,revision,world_revision,display_ms,completed_group_count,group_start_ms,commit_index,queue.size()]:return false
    if not is_same(plan.get("base_current"),current):return false
    var next=0
    for segment in plan.get("segments",[]):
        if segment.activate:
            if next>=queue.size() or not is_same(segment.group,queue[next]):return false
            next+=1
        elif not is_same(segment.group,current):return false
    return true

func replay_prepare(plan: Dictionary) -> bool:
    if not replay_plan_current(plan): return false
    _replay_prepared_plan={}
    # Never ask the live callback to prepare a future group against current
    # pins. A rendering replay host must supply its explicit closure proof.
    waiting_for_media = not replay_media_ready.call(plan) if replay_media_ready.is_valid() else media_ready.is_valid()
    waiting_for_world = false
    if waiting_for_media: return false
    if plan.boundary:
        if not is_same(_world_plan,plan):
            _world_plan = plan
            pending_world = _world_candidate(plan)
            pending_world.replay=true
            pending_world.replay_groups=plan.groups
        if world_ready.is_valid() and not world_ready.call(pending_world):
            waiting_for_world = true
            return false
    else:
        pending_world={};_world_plan={}
    _replay_prepared_plan=plan
    return true

func replay_can_publish(plan: Dictionary) -> bool:
    return replay_plan_current(plan) and is_same(_replay_prepared_plan,plan)

func replay_publish(plan: Dictionary) -> bool:
    if not replay_can_publish(plan): return false
    _apply_world_plan(plan)
    replay_cancel_preparation()
    return true

func replay_cancel_preparation() -> void:
    pending_world = {}; _world_plan = {}
    _replay_prepared_plan={}
    waiting_for_world = false; waiting_for_media = false
    if replay_media_release.is_valid():replay_media_release.call()

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
            # Studio may space already compiled operations on this same display
            # clock. The interval contains only the prior real SDK state; no
            # group, event, actor sample or future commit is activated early.
            var start = maxf(display_ms,float(queue[0].get("preview_start_ms",display_ms)))
            if target < start:
                display_ms = target
                return
            display_ms = start
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
            _append_membership_order(world_changes.order,delta,state)
            var captures:Dictionary=pose_admissions(commits[commit_index],state.actors,condition_owners,current,group_start_ms,retained_directions,appearance_cache)
            Compiler.apply_delta(state,delta)
            _observe_resource_owners(delta,group_start_ms+commits[commit_index].at_ms,commits[commit_index].get("condition_rows",[]),str(commits[commit_index].get("event_uuid","")),captures)
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
        _retain_completed_presentation()
        if retire_group.is_valid(): retire_group.call(current)
        current = {}

func _world_delta(delta: Dictionary) -> bool:
    return not delta.get("tiles_removed",[]).is_empty() or not delta.get("tiles",{}).is_empty() or not delta.get("objects",{}).is_empty() or not delta.get("objects_removed",[]).is_empty() or delta.get("set",{}).has("senses") or delta.get("set",{}).has("connectors")

static func pose_admissions(commit:Dictionary,actors:Dictionary,owners:Dictionary,group:Dictionary,start_ms:float,directions:Dictionary,cache:Dictionary)->Dictionary:
    var rows:Array=commit.get("condition_rows",[])
    var wanted:Dictionary={}
    for row in rows:
        if row.before==null and row.after!=null and Conditions.ConditionPose.capture_requested(row.after,cache):wanted[row.actor_uuid]=true
    if wanted.is_empty():return {}
    var inputs:Dictionary={}
    var rigs:Dictionary=Characters.rigs(cache)
    for id in wanted:
        if not actors.has(id):continue
        var actor:Dictionary=actors[id]
        var rig:String=Characters.rig_id(actor,cache)
        if not rigs.has(rig):continue
        var rest:Dictionary=Characters.rest_sample(actor,rigs[rig],cache)
        if not rest.ok:continue
        inputs[id]=actor.duplicate();inputs[id].presentation_rig=rig;inputs[id].presentation_rest=rest.value
    return Conditions.ConditionPose.admissions(rows,inputs,owners,group,start_ms,float(commit.at_ms),directions,cache)

func _observe_resource_owners(delta:Dictionary,at_ms:float,rows:Array=[],event_uuid:String="",captures:Dictionary={})->void:
    # These existing owner updates report actual resource-input changes. HP,
    # logs and ordinary movement still commit without rebuilding presenters.
    var changed:bool=Conditions.observe(condition_owners,delta.get("actors",{}),at_ms,false,rows,captures)
    if NativeItems.interested(item_effect_owners,delta,appearance_cache):
        changed=NativeItems.observe(item_effect_owners,state,at_ms,appearance_cache,event_uuid) or changed
    if delta.get("set",{}).has("senses"):
        var spatial_changed:bool=NativePersistent.observe_spatial(spatial_effect_owners,state.senses.get("spatial_effects",{}),at_ms)
        changed=changed or spatial_changed
    if changed:resource_revision+=1

func _advance_with_world_preparation(delta_ms: float) -> void:
    if paused or state.is_empty(): return
    waiting_for_world = false; waiting_for_media = false
    var target: float = display_ms+maxf(0,delta_ms)
    while true:
        var first: Dictionary = current if not current.is_empty() else (queue[0] if not queue.is_empty() else {})
        var started:int=Time.get_ticks_usec()
        var ready:bool=not media_ready.is_valid() or media_ready.call(first)
        FrameProfile.end_phase(profile,"timeline_media_ready",started)
        if not ready:
            waiting_for_media = true
            return
        if pending_world.is_empty():
            started=Time.get_ticks_usec()
            var plan = _plan_world_advance(target,first,target)
            FrameProfile.end_phase(profile,"timeline_plan",started)
            waiting_for_media = plan.media_wait
            if not plan.boundary:
                _apply_world_plan(plan)
                if plan.media_wait or plan.segments.is_empty() or not plan.segments.back().complete:
                    return
                # Completion changes source ownership. Only now may the next
                # group prove readiness, using this call's original target.
                continue
            _world_plan = plan
            started=Time.get_ticks_usec()
            # The preview already built this boundary's candidate; the cue frame
            # reuses it instead of copying and re-reducing the state again.
            pending_world = _previewed_candidate(plan)
            if pending_world.is_empty():pending_world = _world_candidate(plan)
            FrameProfile.end_phase(profile,"timeline_candidate",started)
        # Reuse this exact passive candidate across waits. The elapsed wait is
        # never appended to display time, and this cut has not published yet.
        started=Time.get_ticks_usec()
        ready=world_ready.call(pending_world)
        FrameProfile.end_phase(profile,"timeline_world_ready",started)
        if not ready:
            waiting_for_world = true
            return
        _apply_world_plan(_world_plan)
        var published:Dictionary=pending_world
        pending_world = {}; _world_plan = {}
        # A prepared source-only cut can install its passive bindings now.
        # Real world/actor membership still yields for its atomic scene publish.
        if world_published.is_valid() and world_published.call(published):continue
        return

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

func _plan_world_advance(target: float, ready_group: Dictionary = {}, ready_target: float = -INF) -> Dictionary:
    # Plan only ordinary trace/actor progress preceding the next world boundary.
    # No state copy or source enumeration occurs on an ordinary animation frame.
    var group: Dictionary = current
    var start = group_start_ms
    var first_commit = commit_index
    var cursor = display_ms
    var activate = false
    if group.is_empty():
        if queue.is_empty(): return _plan_idle_advance(cursor,target)
        group = queue[0]
        start = maxf(cursor,float(group.get("preview_start_ms",cursor)))
        if target < start: return _plan_idle_advance(cursor,target)
        var idle:Dictionary=_plan_idle_advance(cursor,start)
        if idle.boundary:return idle
        cursor = start; first_commit = 0; activate = true
    # The live caller already checked this exact group and proposed clock.
    # This proof lasts only for this call; independent planners still check.
    var ready_proved: bool = is_same(group,ready_group) and target==ready_target
    if not ready_proved and media_ready.is_valid() and not media_ready.call(group):
        return {"segments":[],"display_ms":cursor,"boundary":false,"media_wait":true}
    return _plan_group_world(group,start,first_commit,cursor,target,activate,_group_stage_times(group))

func _appearance_end_between(cursor:float,target:float)->float:
    var next:float=INF
    for owner in condition_owners.values():
        if is_inf(owner.end_ms) or Appearance.declarations(owner.condition,appearance_cache).is_empty():continue
        var end:float=float(owner.end_ms)+Appearance.removal_ms(owner.condition)
        if end>cursor and end<=target:next=minf(next,end)
    return next

func _plan_idle_advance(cursor:float,target:float)->Dictionary:
    # Retained visual membership lives on the display clock, including idle
    # intervals after its authoritative operation. No synthetic group/commit.
    var end:float=_appearance_end_between(cursor,target)
    return {"segments":[],"display_ms":target if is_inf(end) else end,"boundary":not is_inf(end),"media_wait":false}

func _plan_group_world(group: Dictionary, start: float, first_commit: int, cursor: float,
        target: float, activate: bool, stage_times: Array, stop_at_boundary: bool=true,source_cuts:bool=true) -> Dictionary:
    var segments: Array = []
    var duration = float(group.duration_ms)
    var before = cursor-start
    # Compare on the absolute clock before subtracting: (start+duration)-start
    # can round below duration and leave an exactly clamped replay busy forever.
    var local = duration if target>=start+duration else minf(target-start,duration)
    var boundary_at = INF
    var commits: Array = group.commits
    for i in range(first_commit,commits.size()):
        var at = float(commits[i].at_ms)
        if at>local+0.000001: break
        if _world_delta(commits[i].delta): boundary_at = at; break
    for cuts in [group.get("actor_structure_times",[]),group.get("actor_effect_times",[]) if source_cut_boundaries else [],
            group.get("actor_source_times",[]) if source_cuts and source_cut_boundaries else []]:
        for at in cuts:
            # Source changes use the existing private preparation owner too;
            # no geometry rebuild or world revision is implied by a new clip.
            # Commits below use a one-microsecond admission window. A structure
            # edge must use that same window, or a fractional cue can publish
            # equipment before the exact already-prepared world is admitted.
            if start+float(at)>target+0.000001:break
            if start+float(at)>cursor or (activate and at<=0.0):
                boundary_at=minf(boundary_at,float(at));break
    # A presentation removal can outlive the operation that removed its
    # canonical condition. Later compiled operations cannot recover that old
    # owner from their before-state; the displayed owner supplies this edge.
    var appearance_edge:float=_appearance_end_between(cursor,minf(target,start+local))
    var appearance_local:float=appearance_edge-start
    if appearance_local>=0.0:boundary_at=minf(boundary_at,appearance_local)
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
    # A boundary commit admitted within the commit tolerance publishes at its
    # exact authored time, the time the preview planned and prepared it for:
    # a clock one rounding below it ((start+at)-start) must not miss that key.
    if boundary and stop_at_boundary: local = boundary_at if boundary_at>local and boundary_at<=local+0.000001 else minf(local,boundary_at)
    var end_commit = first_commit
    while end_commit<commits.size() and float(commits[end_commit].at_ms)<=local+0.000001: end_commit += 1
    var complete = local>=duration
    segments.append({"group":group,"start_ms":start,"first_commit":first_commit,"end_commit":end_commit,
        "local_ms":local,"activate":activate,"complete":complete})
    cursor = appearance_edge if boundary and stop_at_boundary and boundary_at==appearance_local else start+local
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

func preview_world(source_cuts:bool=true) -> Dictionary:
    # Read only already received groups. No media callback, trace activation,
    # clock advance or staging admission occurs here. One cached snapshot spans
    # ordinary actor/log commits and animation samples before its world boundary.
    if state.is_empty(): return {}
    if source_cuts and not pending_world.is_empty(): return pending_world
    var groups: Array = []
    if not current.is_empty(): groups.append(current)
    for i in range(mini(2-groups.size(),queue.size())): groups.append(queue[i])
    var signature: Array = [initialization_revision,world_revision,resource_revision,_support_signature()]
    for group in groups: signature.append([group.operation_sequence,group.id])
    if source_cuts:
        if signature==_preview_signature:return _preview_world
        _preview_signature=signature;_preview_world={}
    else:
        if signature==_static_preview_signature:return _static_preview_world
        _static_preview_signature=signature;_static_preview_world={}
    var segments: Array = []
    var cursor = display_ms
    for group in groups:
        var active = is_same(group,current)
        var start = group_start_ms if active else maxf(cursor,float(group.get("preview_start_ms",cursor)))
        var first = commit_index if active else 0
        if not active:
            var idle:Dictionary=_plan_idle_advance(cursor,start)
            if idle.boundary:
                idle.segments=segments
                var candidate:Dictionary=_world_candidate(idle)
                if source_cuts:_preview_world=candidate
                else:_static_preview_world=candidate
                return candidate
        var times = {}
        for key in group.get("staged_tiles",{}):
            times[float(group.get("staged_tile_at_ms",{}).get(key,0.0))] = true
        var ordered: Array = times.keys(); ordered.sort()
        var plan = _plan_group_world(group,start,first,cursor,INF,not active,ordered,true,source_cuts)
        segments.append_array(plan.segments)
        if plan.boundary:
            plan.segments = segments
            var candidate:Dictionary=_world_candidate(plan)
            if source_cuts:_preview_world=candidate
            else:_static_preview_world=candidate
            return candidate
        cursor = plan.display_ms
    var idle:Dictionary=_plan_idle_advance(cursor,INF)
    if idle.boundary:
        idle.segments=segments
        var candidate:Dictionary=_world_candidate(idle)
        if source_cuts:_preview_world=candidate
        else:_static_preview_world=candidate
        return candidate
    return {}

func _world_plan_tail(plan:Dictionary)->Dictionary:
    if not plan.segments.is_empty():return plan.segments.back()
    return {"group":current,"start_ms":group_start_ms,"end_commit":commit_index,
        "local_ms":plan.display_ms-group_start_ms,"complete":current.is_empty()}

func _previewed_candidate(plan: Dictionary) -> Dictionary:
    # The cached preview names the same boundary commit and clock, the same
    # revision after its commits and the same retained layers: _world_candidate
    # would rebuild these exact values (the deltas applied since the preview are
    # already in its snapshot).
    if _preview_world.is_empty(): return {}
    var last: Dictionary = _world_plan_tail(plan)
    var next_revision: int = revision
    for segment in plan.segments: next_revision += segment.end_commit-segment.first_commit
    if _preview_world.display_ms!=plan.display_ms or _preview_world.revision!=next_revision or _preview_world.get("resource_revision",-1)!=resource_revision: return {}
    var key: Array = [initialization_revision,world_revision,_support_signature(),last.group.get("operation_sequence",sequence),last.group.get("id",""),last.end_commit,last.local_ms,last.complete]
    return _preview_world if _preview_world.preparation_key==key else {}

func _world_candidate(plan: Dictionary) -> Dictionary:
    var snapshot = state.duplicate()
    # These are the collections Compiler.apply_delta mutates. Their immutable
    # after-values remain shared; collection ownership never aliases live state.
    for field in ["actors","items","tiles","objects","spatial_commit_cursors","combat_log_appends"]:
        if state.has(field): snapshot[field] = state[field].duplicate()
    var changes = {"full":false,"tiles":{},"objects":{},"senses":false,"order":[]}
    var next_revision = revision; var next_world_revision = world_revision; var next_sequence = sequence
    var appearance_owners:Dictionary=Appearance.copy_owners(condition_owners)
    var capture_directions:Dictionary=retained_directions.duplicate()
    for segment in plan.segments:
        for i in range(segment.first_commit,segment.end_commit):
            var delta: Dictionary = segment.group.commits[i].delta
            _append_membership_order(changes.order,delta,snapshot)
            var commit:Dictionary=segment.group.commits[i]
            var captures:Dictionary=pose_admissions(commit,snapshot.actors,appearance_owners,segment.group,segment.start_ms,capture_directions,appearance_cache)
            Compiler.apply_delta(snapshot,delta)
            Conditions.observe(appearance_owners,delta.get("actors",{}),segment.start_ms+commit.at_ms,false,commit.get("condition_rows",[]),captures)
            for key in delta.get("tiles",{}): changes.tiles[key] = true
            for id in delta.get("objects",{}): changes.objects[id] = true
            for id in delta.get("objects_removed",[]): changes.objects[id] = true
            changes.senses = changes.senses or delta.get("set",{}).has("senses")
            next_revision += 1
            if _world_delta(delta): next_world_revision += 1
        if segment.complete:
            _directions(segment.group.get("actor_tracks",[]),INF,capture_directions)
            if segment.group.get("operation_end",false):next_sequence=int(segment.group.operation_sequence)
    var last: Dictionary = _world_plan_tail(plan)
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
    # Construction needs only the same temporary outfit/hand layers. Sample
    # passive authored intervals; component_samples consumes audio/retention and
    # must never run against a future boundary.
    var layer_candidates:Array=retained_components.duplicate()
    for segment in plan.segments:
        for component in segment.group.get("components",[]):
            if component.kind=="sprite_layer":layer_candidates.append({"component":component,"group_start_ms":segment.start_ms})
    var actor_layers:Array=_actor_layers_at(layer_candidates,plan.display_ms)
    actor_layers.append_array(Appearance.components(appearance_owners,plan.display_ms,appearance_cache))
    return {"key":[initialization_revision,revision,last.group.get("operation_sequence",sequence),last.group.get("id",""),last.start_ms,last.end_commit,last.local_ms,last.complete],
        "preparation_key":[initialization_revision,world_revision,_support_signature(),last.group.get("operation_sequence",sequence),last.group.get("id",""),last.end_commit,last.local_ms,last.complete],
        "source_group_id":last.group.get("id",""),"source_local_ms":last.local_ms,"retained_boundary":plan.segments.is_empty(),
        "state":snapshot,"presentation_state":presented,"staged_tiles":supports,"staged_actors":_actors_for(group,last.local_ms),
        "actor_samples":_project_actor_samples(Tracks.samples(group.get("actor_tracks",[]),last.local_ms),snapshot.actors,appearance_owners),"actor_layers":actor_layers,
        "changes":changes,"display_ms":plan.display_ms,"revision":next_revision,"world_revision":next_world_revision,
        "sequence":next_sequence,"group_id":group.get("id",""),"operation_sequence":int(last.group.get("operation_sequence",sequence)),
        "resource_revision":resource_revision}

func _apply_world_plan(plan: Dictionary) -> void:
    var apply_started:int=Time.get_ticks_usec()
    for segment in plan.segments:
        if segment.activate:
            current = queue.pop_front()
            group_start_ms = segment.start_ms; commit_index = 0
            EventTrace.activate(trace,current.get("events",[]),group_start_ms)
            _resolve_preparation_issue(current)
        for i in range(segment.first_commit,segment.end_commit):
            var commit: Dictionary = current.commits[i]
            var delta: Dictionary = commit.delta
            var started:int=Time.get_ticks_usec()
            _append_membership_order(world_changes.order,delta,state)
            var captures:Dictionary=pose_admissions(commit,state.actors,condition_owners,current,group_start_ms,retained_directions,appearance_cache)
            Compiler.apply_delta(state,delta)
            FrameProfile.end_phase(profile,"timeline_apply_state",started)
            started=Time.get_ticks_usec()
            _observe_resource_owners(delta,group_start_ms+commit.at_ms,commit.get("condition_rows",[]),str(commit.get("event_uuid","")),captures)
            FrameProfile.end_phase(profile,"timeline_apply_owners",started)
            started=Time.get_ticks_usec()
            if commit.has("event_uuid"): EventTrace.commit(trace,int(current.operation_sequence),commit.event_uuid)
            EventTrace.append_logs(trace,commit.get("trace_logs",[]))
            if _world_delta(delta):
                world_revision += 1; _record_world_changes(delta)
            commit_index += 1; revision += 1
            FrameProfile.end_phase(profile,"timeline_apply_trace_changes",started)
        EventTrace.tick(trace,current.get("events",[]),segment.local_ms)
        display_ms = segment.start_ms+segment.local_ms
        if segment.complete:
            if current.get("operation_end",false): sequence = int(current.operation_sequence)
            completed_group_count += 1
            completed_groups.append({"id":current.id,"at_ms":display_ms,"sequence":sequence})
            if completed_groups.size()>DIAGNOSTIC_LIMIT: completed_groups.pop_front()
            _scheduled_group = {}; _staged_world_times = []; _staged_group = {}
            _retain_completed_presentation()
            if retire_group.is_valid(): retire_group.call(current)
            current = {}
    display_ms = plan.display_ms
    # Structural actor cuts can keep the same group/world revision. Their
    # consumed preview must still yield to the next authored constructor edge.
    if plan.get("boundary",false):
        _preview_world={};_preview_signature=[]
        _static_preview_world={};_static_preview_signature=[]
    FrameProfile.end_phase(profile,"timeline_apply",apply_started)

func staged_actors() -> Dictionary:
    var admitted = {}
    var local = display_ms-group_start_ms
    for id in current.get("staged_actors",{}):
        if local >= float(current.get("staged_at_ms",{}).get(id,0.0)):
            admitted[id] = current.staged_actors[id]
    return admitted

static func _directions(tracks: Array, local: float, target: Dictionary) -> void:
    var ordered=tracks.duplicate()
    ordered.sort_custom(func(a,b): return a.start_ms<b.start_ms)
    for track in ordered:
        if track.start_ms>local: continue
        var origin: Variant=track.get("from_position")
        var end: Variant=track.get("target_position",track.get("to_position"))
        if origin!=null and end!=null and origin!=end: target[track.actor_uuid]=[origin,end]

func actor_directions() -> Dictionary:
    var result=retained_directions.duplicate()
    _directions(current.get("actor_tracks",[]),display_ms-group_start_ms,result)
    return result

static func component_direction(group: Dictionary,component: Dictionary,previous: Dictionary) -> Array:
    var directions=previous.duplicate()
    _directions(group.get("actor_tracks",[]),component.get("impact_at_ms",component.start_ms),directions)
    return directions.get(component.get("impact_actor_uuid",component.get("actor_uuid")),[])

func _retain_completed_presentation() -> void:
    for component in current.get("components",[]):
        if component.kind=="audio": crossed_audio.append({"component":component,"group_start_ms":group_start_ms})
        if group_start_ms+component.start_ms+component.duration_ms>display_ms:
            var item={"component":component,"group_start_ms":group_start_ms}
            if component.has("impact"):item.impact_direction=component_direction(current,component,retained_directions)
            retained_components.append(item)
            resource_revision+=1
    _directions(current.get("actor_tracks",[]),INF,retained_directions)

func component_samples(cache: Dictionary={}) -> Array:
    var result: Array=[]
    var alive: Array=[]
    for item in retained_components:
        var component: Dictionary=item.component
        if item.group_start_ms+component.start_ms+component.duration_ms>display_ms:
            alive.append(item)
    if alive.size()!=retained_components.size():resource_revision+=1
    retained_components=alive
    var candidates=alive.duplicate()
    candidates.append_array(crossed_audio);crossed_audio=[]
    for component in current.get("components",[]): candidates.append({"component":component,"group_start_ms":group_start_ms})
    var seen={}
    var active_impacts={}
    for item in candidates:
        var component: Dictionary=item.component
        if seen.has(component.id): continue
        seen[component.id]=true
        var begin:float=item.group_start_ms+component.start_ms
        var age:float=display_ms-begin
        var crossed=component.kind=="audio" and item.group_start_ms+component.start_ms>=component_sample_ms
        if display_ms>=begin and (display_ms<begin+component.duration_ms or crossed):
            var sample=component.duplicate(); sample.age_ms=age; sample.absolute_start_ms=item.group_start_ms+component.start_ms
            if component.has("impact"):
                active_impacts[component.id]=true
                if not resolved_impacts.has(component.id):
                    var direction:Array=item.impact_direction if item.has("impact_direction") else component_direction(current,component,retained_directions)
                    resolved_impacts[component.id]=ImpactPlacement.with_direction(component.impact,direction,cache)
                sample.impact=resolved_impacts[component.id]
                if sample.impact.status=="missing":sample.status="missing";sample.reason=sample.impact.reason
            result.append(sample)
    for id in resolved_impacts.keys():
        if not active_impacts.has(id):resolved_impacts.erase(id)
    component_sample_ms=display_ms
    var activities={}
    var bodies=actor_samples()
    for id in bodies:activities[id]=bodies[id].get("activity","idle")
    var condition_count:int=condition_owners.size();var spatial_count:int=spatial_effect_owners.size()
    result.append_array(Conditions.samples(condition_owners,display_ms,cache,activities))
    result.append_array(NativePersistent.spatial_samples(spatial_effect_owners,display_ms,cache))
    result.append_array(NativeItems.samples(item_effect_owners,state,display_ms))
    if condition_count!=condition_owners.size() or spatial_count!=spatial_effect_owners.size():resource_revision+=1
    return result

func staged_tiles() -> Dictionary:
    # Only tiles whose admission time has passed are visited, in the group's
    # own order: a room staged for later costs one search per call, not a walk.
    var admitted = {}
    var staged: Dictionary = current.get("staged_tiles",{})
    if staged.is_empty(): return admitted
    if not is_same(_staged_group,current): _index_staged(current)
    var local = display_ms-group_start_ms
    var count: int = _staged_times.bsearch(local,false)
    if count==0: return admitted
    if count==staged.size():
        for key in staged:
            if not state.tiles.has(key): admitted[key] = staged[key]
        return admitted
    var keys: Array = staged.keys()
    var indices: Array = _staged_indices.slice(0,count); indices.sort()
    for i in indices:
        if not state.tiles.has(keys[i]): admitted[keys[i]] = staged[keys[i]]
    return admitted

func _index_staged(group: Dictionary) -> void:
    # Admission times ascending, ties in the group's order, with each tile's
    # position in group.staged_tiles; received groups are immutable.
    _staged_group = group
    var times: Dictionary = group.get("staged_tile_at_ms",{})
    var order: Array = []
    var i: int = 0
    for key in group.staged_tiles:
        order.append([float(times.get(key,0.0)),i]); i += 1
    order.sort()
    _staged_times = order.map(func(pair):return pair[0])
    _staged_indices = order.map(func(pair):return pair[1])

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

func _project_actor_samples(samples:Dictionary,actors:Dictionary,owners:Dictionary)->Dictionary:
    var rigs:Dictionary={}
    for owner in owners.values():
        if owner.has("logical_pose") and actors.has(owner.actor_uuid) and not rigs.has(owner.actor_uuid):rigs[owner.actor_uuid]=Characters.rig_id(actors[owner.actor_uuid],appearance_cache)
    return Conditions.ConditionPose.project(samples,actors,owners,appearance_cache,rigs)

func actor_samples() -> Dictionary:
    # Play and component sampling both read the same instant each frame.
    if not is_same(_actor_samples_group,current) or _actor_samples_at!=display_ms-group_start_ms or _actor_samples_resources!=resource_revision:
        _actor_samples_group=current;_actor_samples_at=display_ms-group_start_ms;_actor_samples_resources=resource_revision
        _actor_samples=_project_actor_samples(Tracks.samples(current.get("actor_tracks",[]),_actor_samples_at),state.actors,condition_owners)
    return _actor_samples

static func _actor_layers_at(candidates:Array,at_ms:float)->Array:
    var result:Array=[]
    var seen:Dictionary={}
    for item in candidates:
        var component:Dictionary=item.component
        if component.kind!="sprite_layer" or seen.has(component.id):continue
        var begin:float=item.group_start_ms+component.start_ms
        # Constructor membership and displayed sampling share the exact
        # absolute half-open interval. Subtraction can round an endpoint age
        # below duration even when this cut has completed the component.
        if at_ms>=begin and at_ms<begin+component.duration_ms:
            result.append(component);seen[component.id]=true
    return result

func actor_layer_samples()->Array:
    # Initial replay construction needs the current outfit without consuming
    # audio crossings or mutating the retained presentation during preparation.
    var candidates:Array=retained_components.duplicate()
    for component in current.get("components",[]):
        if component.kind=="sprite_layer":candidates.append({"component":component,"group_start_ms":group_start_ms})
    var result:Array=_actor_layers_at(candidates,display_ms)
    result.append_array(appearance_layer_samples())
    return result

func appearance_layer_samples(cache:Dictionary={})->Array:
    return Appearance.components(condition_owners,display_ms,appearance_cache if cache.is_empty() else cache)

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
