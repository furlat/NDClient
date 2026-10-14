extends RefCounted
## Resolve only an already selected cue and source marker. The shared compiler
## supplies occurrence identity/timing; this module knows no actions or rules.
const Authoring=preload("res://presentation/authoring.gd")

static func source_seconds(row:Dictionary,age_ms:float)->float:
    var seconds=maxf(0,age_ms/1000.0)
    if row.get("loop",false):
        var begin:float=row.get("loop_start_s",0.0)
        var end:float=row.get("loop_end_s",row.clip_duration_s)
        if seconds>=end:seconds=begin+fposmod(seconds-begin,maxf(.000001,end-begin))
    return seconds

static func contact_marker_error(marker:Dictionary,clip:Dictionary,loop:bool)->String:
    if not is_finite(float(clip.fps)) or float(clip.fps)<=0 or not is_finite(float(clip.frames)) or int(clip.frames)<=0:return "invalid_contact_clip_clock"
    if str(marker.get("id","")).strip_edges().is_empty():return "contact_id_not_authored"
    if marker.get("boundary","frame_start") not in ["frame_start","clip_end"]:return "invalid_contact_boundary"
    var frame=float(marker.get("frame",-1))
    if not is_finite(frame) or frame<0 or frame>clip.frames or not is_equal_approx(frame,roundf(frame)):return "invalid_contact_frame"
    if marker.get("direction","") not in ["forward","reverse"]:return "contact_direction_not_authored"
    if (frame==clip.frames and (loop or marker.get("boundary","")!="clip_end")) or (marker.get("boundary","")=="clip_end" and frame!=clip.frames):return "invalid_contact_end_boundary"
    if marker.get("binding","") not in ["path","takeoff","landing"]:return "contact_binding_not_authored"
    return ""

static func source_frame_times(track:Dictionary,frame:float,fps:float,frames:int,direction:String="forward")->Array:
    # Invert the same piecewise source clock sampled by Tracks. Endpoint
    # crossings belong to the preceding segment; holds do not emit repeatedly.
    var keys:Array=track.get("source_time_keys",[[0.0,track.source_start_seconds],[1.0,track.source_end_seconds]])
    var result:Array=[]
    if fps<=0 or frames<=0 or frame<0 or frame>frames or (frame==frames and track.get("loop",false)):return result
    var minimum=float(keys[0][1])*fps;var maximum=minimum
    for key in keys:
        minimum=minf(minimum,float(key[1])*fps);maximum=maxf(maximum,float(key[1])*fps)
    var cycles=range(int(floor(minimum/frames)),int(floor(maximum/frames))+1) if track.get("loop",false) else [0]
    for cycle in cycles:
        var target=frame+cycle*frames
        for i in range(1,keys.size()):
            var a=float(keys[i-1][1])*fps;var b=float(keys[i][1])*fps
            var forward=b>a
            if is_equal_approx(a,b) or (direction=="forward" and not forward) or (direction=="reverse" and forward):continue
            var crossed=(a<target and target<=b) if forward else (b<=target and target<a)
            # The first native source frame starts a new clip/occurrence. Later
            # chunks and loop starts are already owned by the previous crossing.
            if i==1 and is_zero_approx(a) and is_zero_approx(target):crossed=true
            if not crossed:continue
            var fraction=lerpf(float(keys[i-1][0]),float(keys[i][0]),inverse_lerp(a,b,target))
            var at_ms=float(track.start_ms)+fraction*float(track.duration_ms)
            if not result.any(func(time):return is_equal_approx(time,at_ms)):result.append(at_ms)
    result.sort()
    return result

static func resolve(cue_id: String, occurrence_id: String, ordinal: int, start_ms: float, interval_ms: float=-1.0, parameters: Dictionary={}, cache: Dictionary={}) -> Dictionary:
    var catalog: Dictionary=Authoring.load_data("audio/cues.json",cache)
    var cue: Dictionary=catalog.get("cues",{}).get(cue_id,{})
    var row={"id":occurrence_id+":audio:"+cue_id+":"+str(ordinal),"kind":"audio","cue_id":cue_id,
        "start_ms":start_ms,"duration_ms":0.0,"source":"audio/cues.json:/cues/"+cue_id,
        "status":"missing","reason":catalog.get("missing_cues",{}).get(cue_id,"cue_not_selected")}
    row.merge(parameters,true)
    if cue.is_empty() or cue.clips.is_empty(): return row
    if cue.loop and interval_ms<0:
        row.reason="loop_interval_not_resolved"; return row
    var variation=posmod(ordinal,cue.clips.size())
    for field in ["gain_db","bus","attachment","loop","fade_out_ms","source_marker","loop_start_s","loop_end_s"]:
        if cue.has(field): row[field]=cue[field]
    row.clip=cue.clips[variation]
    row.clip_duration_s=cue.clip_durations_s[variation]
    if cue.loop and row.clip.get_extension().to_lower()=="ogg" and not is_equal_approx(row.get("loop_end_s",row.clip_duration_s),row.clip_duration_s):
        row.reason="ogg_loop_end_must_match_source_duration";return row
    row.variation=variation
    var sync_points:Array=cue.get("source_sync_s",[])
    if sync_points.size()!=cue.clips.size():
        row.reason="source_sync_points_not_authored";return row
    row.source_sync_s=float(sync_points[variation])
    if cue.loop and not is_zero_approx(row.source_sync_s):
        row.reason="loop_source_sync_not_supported";return row
    row.contact_ms=start_ms
    row.start_ms=start_ms-row.source_sync_s*1000.0
    if not is_finite(row.source_sync_s) or row.source_sync_s<0 or row.source_sync_s>=row.clip_duration_s:
        row.reason="invalid_source_sync_point";return row
    if row.start_ms<0:
        row.reason="source_sync_requires_unavailable_preroll";return row
    row.duration_ms=interval_ms if cue.loop else row.clip_duration_s*1000.0
    row.voice_limit=int(catalog.mix.max_voices_per_cue)
    row.total_voice_limit=int(catalog.mix.max_simultaneous_voices)
    row.status="available";row.reason="";row.temporary=true
    return row
