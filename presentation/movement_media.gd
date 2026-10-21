extends RefCounted
## Original movement_context selectors, shared by compilation and gap reporting.
const Authoring=preload("res://presentation/authoring.gd")
const Phases=preload("res://presentation/native_spell_authoring.gd")

static func selected(actor:Dictionary,trajectory:String,cache:Dictionary,phase:Dictionary={})->Array:
    if trajectory not in ["path","direct_arc"]:return []
    var conditions={}
    for condition in actor.get("conditions",[]):conditions[condition.behavior_id]=true
    var field="walkMedia" if trajectory=="path" else "jumpMedia"
    var rows:Array=Authoring.load_data("catalog/movement_context.json",cache).get(field,[])
    var selected_rows:Array=[]
    for i in rows.size():
        var row:Dictionary=rows[i]
        if not row.get("whenConditions",[]).all(func(id):return conditions.has(id)):continue
        if row.get("unlessConditions",[]).any(func(id):return conditions.has(id)):continue
        if row.role=="takeoff" and phase.has("from") and float(phase.from)>0.0:continue
        if row.role=="landing" and phase.has("to") and float(phase.to)<1.0:continue
        selected_rows.append({"media":row,"source":"catalog/movement_context.json:/"+field+"/"+str(i)})
    return selected_rows

static func native_source(asset_id:String,cache:Dictionary)->String:
    var sources:Dictionary=Authoring.load_data("native_effects/index.json",cache).sources
    for id in sources:
        if asset_id in sources[id].get("media_ids",[]):return id
    for cue in Authoring.load_data("catalog/movement_context.json",cache).get("nativeEffects",[]):
        if asset_id in cue.get("movement",{}).get("replaces_media",[]):return str(cue.clip)
    return ""


## Typed Factory uses selected against this exact scheduled native motion.
## The resource owns condition predicates, phase anchors, cadence and source.
static func native_uses(actor:Dictionary,trajectory:String,cache:Dictionary)->Array:
    var members:Dictionary={}
    for member in actor.get("conditions",[]):members[str(member.behavior_id)]=true
    return Authoring.load_data("catalog/movement_context.json",cache).get("nativeEffects",[]).filter(func(cue):
        var rule:Dictionary=cue.get("movement",{})
        return rule.get("trajectory")==trajectory \
            and rule.get("when_conditions",[]).all(func(id):return members.has(id)) \
            and not rule.get("unless_conditions",[]).any(func(id):return members.has(id)))

static func phases(track:Dictionary,tracks:Array,actor:Dictionary,cache:Dictionary)->Array:
    var result:Array=[]
    if float(track.duration_ms)<=0.0:return result
    for original in native_uses(actor,str(track.trajectory),cache):
        var cue:Dictionary=original.duplicate(true)
        var rule:Dictionary=cue.movement
        var start:float=float(track.start_ms)
        var finish:float=start+float(track.duration_ms)
        var times:Array=[]
        match str(cue.at):
            "movement.interval":
                var interval:float=float(rule.get("interval_seconds",0.0))*1000.0
                if interval<=0.0:continue
                var origin:float=start
                for sibling in tracks:
                    if sibling.get("motion",false) and sibling.get("actor_uuid")==track.actor_uuid \
                        and sibling.get("occurrence")==track.get("occurrence") and sibling.get("trajectory")==track.trajectory:
                        origin=minf(origin,float(sibling.start_ms))
                var emission_ms:float=origin+(floorf((start-origin)/interval)+1.0)*interval
                while emission_ms<=finish+0.000001:
                    times.append(minf(emission_ms,finish));emission_ms+=interval
            "movement.takeoff":
                if is_zero_approx(float(track.get("motion_fraction_from",0.0))):times.append(start)
            "movement.landing":
                if is_equal_approx(float(track.get("motion_fraction_to",1.0)),1.0):times.append(finish)
            "movement.track":times.append(start)
            _:continue
        for phase_ms in times:
            var staged:Dictionary=cue.duplicate(true)
            staged.at="release"
            var selected:Dictionary={"id":"movement","source":str(cue.source),"staging":{},"source_bounds":{},"palette":{}}
            var phase:Dictionary=Phases._phase(selected,staged,{"prepare":float(phase_ms)},float(phase_ms),0.0,0)
            phase.source=str(cue.source);phase.source_id="movement.native."+str(cue.source_index)
            phase.erase("spell_id")
            phase.timing_selector=str(cue.at);phase.timing_source=str(cue.source)+"/at"
            phase.native_cue.authored_at=str(cue.at)
            if rule.get("fit_to_motion",false):
                var from:float=float(track.get("motion_fraction_from",0.0))
                var to:float=float(track.get("motion_fraction_to",1.0))
                if to<=from:continue
                var whole_seconds:float=float(track.duration_ms)/1000.0/(to-from)
                var rate:float=float(cue.source_end)/whole_seconds
                phase.duration_ms=float(track.duration_ms)
                phase.native_cue.source_rate=rate
                phase.native_cue.begin=-from*whole_seconds
                phase.native_cue.end=float(track.duration_ms)/1000.0
            phase.merge({"native_spell":true,"actor_uuid":str(track.actor_uuid),"target_uuid":str(track.actor_uuid),
                "cast_recipe":{"enabled":false},"ground_target":true,"source_track":track,
                "body_track_id":str(track.get("trace_track_id","")),"authored_media":rule.get("replaces_media",[]).duplicate(),
                "native_movement":{"track":track,"sample_ms":float(phase_ms),"follow":bool(cue.get("follow",false))},
                "from_position":track.from_position,"to_position":track.to_position,
                "from_elevation_feet":float(track.get("from_elevation_feet",0.0)),"to_elevation_feet":float(track.get("to_elevation_feet",0.0))},true)
            result.append(phase)
    return result
