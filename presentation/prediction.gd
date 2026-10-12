extends RefCounted
# One outstanding native command, one passive visual prefix. The reducer and
# Timeline are never written here. Other presentation channels can use the same
# command identity/lifecycle when their authored prefix samplers are introduced.
const Tracks = preload("res://presentation/tracks.gd")
const MAX_PREFIX_MS = 120.0
const RETURN_MS = 80.0

static func create() -> Dictionary:
    return {"active":{},"started":0,"matched":0,"corrected":0,"rejected":0,"last_reason":"idle"}

static func same_scope(a: Dictionary, b: Dictionary) -> bool:
    for field in ["game_id","game_epoch","audience_id"]:
        if not a.has(field) or a[field]!=b.get(field): return false
    return true

static func reset(record: Dictionary, reason: String) -> void:
    record.active = {}
    record.last_reason = reason

static func begin(record: Dictionary, cursor: Dictionary, command: Dictionary, plan: Dictionary) -> bool:
    if not record.active.is_empty() or not plan.has("actor_tracks") or plan.actor_tracks.is_empty(): return false
    if not same_scope(cursor,cursor) or plan.limit_ms<=0: return false
    var tracks: Array = plan.actor_tracks.duplicate(true)
    var occurrence = "prediction:%s:%s:%s:%s" % [cursor.game_id,cursor.game_epoch,cursor.audience_id,command.command_number]
    for track in tracks:
        track.occurrence = occurrence
        track.erase("trace_track_id")
    record.active = {"cursor":cursor.duplicate(true),"number":command.command_number,"actor_uuid":command.actor_uuid,
        "tracks":tracks,"limit_ms":minf(MAX_PREFIX_MS,plan.limit_ms),"elapsed_ms":0.0,"sequence":-1,
        "phase":"pending","return_ms":0.0,"receipt":"pending"}
    record.started += 1; record.last_reason = "pending"
    return true

static func observe(record: Dictionary, message: Dictionary) -> void:
    if message.kind=="initialization": reset(record,"initialization"); return
    if record.active.is_empty(): return
    var active: Dictionary = record.active
    if message.get("command_number")==active.number and same_scope(active.cursor,message.get("cursor",{})):
        active.sequence = int(message.sequence)

static func receipt(record: Dictionary, value: Dictionary) -> void:
    if record.active.is_empty() or value.command_number!=record.active.number: return
    var active: Dictionary = record.active
    if not same_scope(active.cursor,value): return
    if value.kind=="committed":
        if not same_scope(active.cursor,value.cursor): return
        active.sequence = int(value.cursor.sequence)
        active.receipt = value.kind
    elif value.kind=="rejected" and active.sequence<0:
        active.phase = "returning"; active.return_ms = 0.0
        record.rejected += 1; record.last_reason = value.kind
    # Unknown, expired, indeterminate, pending and failed HTTP are not rejection.

static func compatible(predicted: Dictionary, confirmed: Dictionary) -> bool:
    # Exact source program, registration and timing: never hide a reaction or
    # credit a similar-looking animation with a different contact/clip/rate.
    for field in ["actor_uuid","rig","clip","duration_ms","source_start_seconds","source_end_seconds",
        "source_time_keys","from_position","to_position","from_elevation_feet","to_elevation_feet",
        "trajectory","arc_height_px","motion_fraction_from","motion_fraction_to","hidden_slots",
        "target_uuid","target_position","visual_loadout"]:
        if predicted.get(field)!=confirmed.get(field): return false
    return float(confirmed.start_ms)==0.0

static func overlay(record: Dictionary, canonical: Dictionary, group: Dictionary, local_ms: float,
        sequence: int, delta_ms: float, paused: bool = false) -> Dictionary:
    if record.active.is_empty(): return canonical
    var active: Dictionary = record.active
    if active.sequence>=0 and sequence>=active.sequence:
        reset(record,"operation_complete"); return canonical
    var id: String = active.actor_uuid
    var matching = not group.is_empty() and group.get("command_number")==active.number and same_scope(active.cursor,group.get("cursor",{}))
    if matching and canonical.has(id):
        var original: Dictionary = active.tracks[0]
        if not compatible(original,canonical[id]):
            record.corrected += 1; reset(record,"authoritative_difference"); return canonical
        if local_ms>=active.elapsed_ms:
            record.matched += 1; reset(record,"handoff"); return canonical
        active.phase = "catching_up"
    elif not group.is_empty() and float(group.duration_ms)>0.0:
        # Includes an earlier reaction, unrelated operation, disappearance, and
        # source-less group: authoritative time takes precedence immediately.
        record.corrected += 1; reset(record,"authoritative_interruption"); return canonical
    if active.phase=="pending" and not paused:
        active.elapsed_ms = minf(active.limit_ms,active.elapsed_ms+maxf(0,delta_ms))
    var at = active.elapsed_ms
    if active.phase=="returning":
        if not paused: active.return_ms += maxf(0,delta_ms)
        if active.return_ms>=RETURN_MS:
            reset(record,"returned"); return canonical
        at *= 1.0-active.return_ms/RETURN_MS
    var result = canonical.duplicate()
    var predicted = Tracks.samples(active.tracks,at)
    for actor_id in predicted:
        var sample: Dictionary = predicted[actor_id]
        sample.predicted = true
        # No authoritative track identity until the actual canonical pose is
        # sampled. Holding the speculative prefix is not a rendered-event witness.
        sample.erase("trace_track_id")
        result[actor_id] = sample
    return result

static func diagnostics(record: Dictionary) -> Dictionary:
    var active: Dictionary = record.active
    return {"phase":active.get("phase","idle"),"command_number":active.get("number"),
        "elapsed_ms":active.get("elapsed_ms",0.0),"started":record.started,"matched":record.matched,
        "corrected":record.corrected,"rejected":record.rejected,"last_reason":record.last_reason}
