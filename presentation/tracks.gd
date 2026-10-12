extends RefCounted
# Shared passive authored tracks. No clock ownership or reducer writes.

static func samples(tracks: Array, local: float) -> Dictionary:
    var result: Dictionary = {}
    for track in tracks:
        var start = float(track.start_ms)
        var end = start+float(track.duration_ms)
        if local < start or (local >= end and not track.get("holding_pose",false)): continue
        var id: String = track.actor_uuid
        if result.has(id) and int(result[id].priority) > int(track.get("priority",0)): continue
        var fraction = clampf((local-start)/maxf(0.000001,float(track.duration_ms)),0,1)
        var sample: Dictionary = track.duplicate()
        sample.source_seconds = lerpf(track.get("source_start_seconds",0.0),track.get("source_end_seconds",0.0),fraction)
        if track.has("source_time_keys"):
            var keys: Array = track.source_time_keys
            for i in range(1,keys.size()):
                if fraction <= float(keys[i][0]):
                    var t = inverse_lerp(float(keys[i-1][0]),float(keys[i][0]),fraction)
                    sample.source_seconds = lerpf(float(keys[i-1][1]),float(keys[i][1]),t)
                    break
        if track.get("from_position") != null and track.get("to_position") != null:
            var a: Array = track.from_position
            var b: Array = track.to_position
            sample.position = [lerpf(a[0],b[0],fraction),lerpf(a[1],b[1],fraction)]
            sample.base_height_steps = lerpf(track.get("from_elevation_feet",0.0),track.get("to_elevation_feet",0.0),fraction)/5.0
            var motion = lerpf(track.get("motion_fraction_from",0.0),track.get("motion_fraction_to",1.0),fraction)
            sample.lift_pixels = sin(PI*motion)*float(track.get("arc_height_px",0)) if track.get("trajectory","") == "direct_arc" else 0.0
        result[id] = sample
    return result

static func _source_at(keys: Array, fraction: float) -> float:
    for index in range(1,keys.size()):
        if fraction <= float(keys[index][0]):
            return lerpf(keys[index-1][1],keys[index][1],inverse_lerp(keys[index-1][0],keys[index][0],fraction))
    return keys[-1][1]

static func body_keys(track: Dictionary, body: Dictionary, clip: Dictionary, first: float = 0.0, last: float = 1.0) -> void:
    track.hidden_slots = body.actor.get("hiddenSlots",[])
    if body.get("reversed",false):
        track.source_start_seconds = float(clip.frames)/clip.fps
        track.source_end_seconds = 0.0
    if not body.has("frameKeys"): return
    var keys: Array = []
    for key in body.frameKeys: keys.append([float(key[0]),float(key[1])/clip.fps])
    var selected = [[0.0,_source_at(keys,first)]]
    for key in keys:
        if key[0] > first and key[0] < last: selected.append([inverse_lerp(first,last,key[0]),key[1]])
    selected.append([1.0,_source_at(keys,last)])
    track.source_time_keys = selected
    track.source_start_seconds = selected[0][1]
    track.source_end_seconds = selected[-1][1]

static func body(actor_id: String, rig: String, clip_name: String, clip: Dictionary, speed: float, priority: int) -> Dictionary:
    if clip.is_empty() or speed<=0: return {}
    var seconds = float(clip.frames)/float(clip.fps)
    return {"actor_uuid":actor_id,"rig":rig,"clip":clip_name,"start_ms":0.0,
        "duration_ms":seconds*1000.0/speed,"source_start_seconds":0.0,"source_end_seconds":seconds,
        "priority":priority,"holding_pose":clip_name=="Die","trajectory":"stationary","motion":false,"loop":false}

static func jump_context(path: Array, motion: Dictionary, occurrence: String) -> Dictionary:
    var distance = Vector2(path[0][0],path[0][1]).distance_to(Vector2(path[-1][0],path[-1][1]))
    return {"occurrence":occurrence,"path":path,"count":maxi(1,path.size()-1),
        "duration":clampf(motion.jumpBaseDurationMs+motion.jumpPerCellDurationMs*distance,motion.jumpMinDurationMs,motion.jumpMaxDurationMs),
        "arc":minf(motion.jumpArcBasePx+motion.jumpArcPerCellPx*distance,motion.jumpArcMaxPx)}

static func movement(track: Dictionary, fact: Dictionary, motion: Dictionary, body_config: Dictionary,
        clip: Dictionary, context: Dictionary, rate: float, speed_scale: float, previous: Dictionary = {}) -> void:
    track.merge({"from_position":fact.from_position,"to_position":fact.to_position,
        "from_elevation_feet":fact.from_elevation_feet,"to_elevation_feet":fact.to_elevation_feet,
        "trajectory":fact.trajectory,"motion":true,"arc_height_px":0.0,"motion_fraction_from":0.0,"motion_fraction_to":1.0},true)
    if fact.trajectory=="direct_arc" and context.has("path"):
        var edge = context.path.find(fact.from_position)
        track.occurrence = context.occurrence
        track.duration_ms = context.duration/context.count/speed_scale
        track.motion_fraction_from = float(maxi(0,edge))/context.count
        track.motion_fraction_to = float(maxi(0,edge)+1)/context.count
        track.arc_height_px = context.arc
        track.source_start_seconds = motion.jumpBodyFrames/motion.jumpSourceFps*track.motion_fraction_from
        track.source_end_seconds = motion.jumpBodyFrames/motion.jumpSourceFps*track.motion_fraction_to
    else:
        var distance = Vector2(fact.from_position[0],fact.from_position[1]).distance_to(Vector2(fact.to_position[0],fact.to_position[1]))
        track.duration_ms = motion.walkStepDurationMs*distance/speed_scale
        if fact.trajectory=="path": track.occurrence = context.get("occurrence",track.occurrence)
        if previous.get("occurrence")==track.occurrence and previous.get("clip")==track.clip:
            track.source_start_seconds = previous.source_end_seconds
        track.source_end_seconds = track.source_start_seconds+track.duration_ms/1000.0*rate
        track.loop = true
    body_keys(track,body_config,clip,track.motion_fraction_from,track.motion_fraction_to)
