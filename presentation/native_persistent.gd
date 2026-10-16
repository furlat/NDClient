extends RefCounted
## Presentation lifetimes follow disclosed after-values. No rule or expiration
## is inferred from a Factory clip's finite demonstration duration.
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Authoring=preload("res://presentation/authoring.gd")

static func fade_ms(selected:Dictionary)->float:
    return phase_fade_ms(Spells.condition_phases(selected))

static func phase_fade_ms(phases:Array)->float:
    var result=0.0
    for phase in phases:
        result=maxf(result,(float(phase.lifecycle.get("exit_end_seconds",0))-float(phase.lifecycle.get("exit_start_seconds",0)))*1000.0)
    return result

static func condition_samples(common:Dictionary,cache:Dictionary)->Array:
    var selected=Spells.condition(str(common.condition.behavior_id),cache)
    return phase_samples(common,Spells.condition_phases(selected))

static func phase_samples(common:Dictionary,phases:Array)->Array:
    # Phase descriptions are owner-independent. Each output receives its own
    # cue before adding occurrence age/removal state; never mutate the input.
    var result:Array=[]
    var index=0
    for phase in phases:
        var close_ms:float=(float(phase.lifecycle.get("exit_end_seconds",0))-float(phase.lifecycle.get("exit_start_seconds",0)))*1000.0
        if float(common.age_ms)>=float(common.duration_ms)+close_ms:index+=1;continue
        var row=common.duplicate()
        row.merge(phase,true)
        row.merge({"id":common.id+":native:"+str(index),"kind":"native_effect","native_spell":true,"persistent_owner":true,
            "status":phase.get("status","available"),"target_uuid":common.get("actor_uuid"),"cast_recipe":{"enabled":false},
            "start_ms":common.start_ms,"absolute_start_ms":common.absolute_start_ms,"duration_ms":common.duration_ms,
            "from_position":[0,0],"to_position":common.get("position",[0,0]),
            "from_elevation_feet":common.get("elevation_feet",0),"to_elevation_feet":common.get("elevation_feet",0),
            "ground_target":common.get("spatial_owner",false),"sample_hz":60.0},true)
        row.native_cue=row.native_cue.duplicate(true)
        row.native_cue.lifecycle=row.lifecycle
        row.native_cue.initial=common.initial
        row.native_cue.owner_end_seconds=float(common.duration_ms)/1000.0
        row.trace_keys=[row.id]
        result.append(row);index+=1
    return result

static func spatial_selection(effect:Dictionary,cache:Dictionary)->Dictionary:
    var ref:Dictionary=effect.get("content_ref",{})
    var identity:String=str(ref.get("content_id",""))
    var entries:Dictionary=Authoring.load_data("native_effects/index.json",cache).get("spells",{})
    for spell_id in entries:
        var lifecycle:Dictionary=entries[spell_id].get("lifecycle",{})
        if lifecycle.get("owner_kind")!="spatial_effect":continue
        if identity in lifecycle.get("owner_ids",[]) or "spatial_effect."+identity in lifecycle.get("owner_ids",[]):return Spells.selection(spell_id,cache)
    return {}

static func observe_spatial(owners:Dictionary,effects:Dictionary,at_ms:float,initial:bool=false)->bool:
    var changed:bool=false
    for id in effects:
        if not owners.has(id):
            owners[id]={"id":id,"start_ms":at_ms,"end_ms":INF,"initial":initial,"effect":effects[id]}
            changed=true
        else:
            changed=changed or not is_same(owners[id].effect,effects[id]) or not is_inf(owners[id].end_ms)
            owners[id].effect=effects[id];owners[id].end_ms=INF
    for id in owners:
        if not effects.has(id) and is_inf(owners[id].end_ms):owners[id].end_ms=at_ms;changed=true
    return changed

static func spatial_samples(owners:Dictionary,at_ms:float,cache:Dictionary)->Array:
    var result:Array=[]
    for id in owners.keys():
        var owner:Dictionary=owners[id]
        var selected=spatial_selection(owner.effect,cache)
        if selected.is_empty():continue
        if at_ms>=float(owner.end_ms)+fade_ms(selected):owners.erase(id);continue
        var effect:Dictionary=owner.effect
        var excluded:Dictionary={}
        for suppression in effect.get("suppressions",[]):
            for point in suppression.get("positions",[]):excluded["%d,%d"%point]=true
        var positions:Array=effect.get("positions",[]).filter(func(point):return not excluded.has("%d,%d"%point))
        if positions.is_empty():continue
        var anchor:Variant=effect.get("anchor_position")
        if anchor==null:anchor=positions[0]
        var common={"id":"spatial:"+str(id),"spatial_effect_uuid":id,"spatial_owner":true,"actor_uuid":null,
            "start_ms":owner.start_ms,"absolute_start_ms":owner.start_ms,"duration_ms":owner.end_ms-owner.start_ms,
            "age_ms":maxf(0,at_ms-owner.start_ms),"initial":owner.initial,"alpha":1.0,
            "removal_age_ms":null if is_inf(owner.end_ms) else maxf(0,at_ms-owner.end_ms),
            "position":anchor,"elevation_feet":float(effect.anchor_elevation_steps)*5.0 if effect.get("anchor_elevation_steps")!=null else 0.0,
            "resolved_area_positions":positions,"source_event_uuid":"","recipe":{}}
        result.append_array(phase_samples(common,Spells.condition_phases(selected)))
    return result
