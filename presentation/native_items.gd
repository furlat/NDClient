extends RefCounted
## Intrinsic decorations share the actual item's membership, never its body.
## Conditions own temporary buffs; spell/action cues own finite cast effects.
const Bodies=preload("res://presentation/body_sources.gd")
const World=preload("res://presentation/world.gd")
const Effects=preload("res://presentation/effect_package.gd")
const WEAPON_SETS={"MELEE_MAIN":"melee","MELEE_OFF":"melee","RANGED_MAIN":"ranged","RANGED_OFF":"ranged"}

static func definitions(cache:Dictionary)->Dictionary:
    var index:Resource=Bodies.index(cache)
    return {} if index==null else index.item_effects

static func interested(owners:Dictionary,delta:Dictionary,cache:Dictionary)->bool:
    if not owners.is_empty():return true
    var entries:Dictionary=definitions(cache)
    if not entries.is_empty() and delta.get("set",{}).has("senses"):return true
    for actor in delta.get("actors",{}).values():
        for layer in actor.get("visual_loadout",{}).get("layers",[]):
            if entries.has(layer.item_id):return true
    return false

## One membership pass at a canonical change, shared by all effects on an item.
## Cached item metadata alone cannot establish current presence/disclosure.
static func locations(state:Dictionary)->Dictionary:
    var result:Dictionary={}
    for actor in state.get("actors",{}).values():
        var controlled:Variant=actor.get("controlled_items")
        if controlled!=null:
            for id in controlled:result[id]={"kind":"inventory","holder_uuid":str(actor.uuid)}
    for actor in state.get("actors",{}).values():
        if not World.visible_actor(actor,state):continue
        var loadout:Dictionary=actor.get("visual_loadout",{})
        for layer in loadout.get("layers",[]):
            if not WEAPON_SETS.has(str(layer.slot)) or WEAPON_SETS[str(layer.slot)]!=loadout.get("active_weapon_set"):continue
            var previous:Dictionary=result.get(layer.item_uuid,{})
            if previous.get("kind") in ["held","ambiguous"]:
                result[layer.item_uuid]={"kind":"ambiguous"};continue
            result[layer.item_uuid]={"kind":"held","holder_uuid":str(actor.uuid),"item_id":str(layer.item_id),
                "equipment_slot":str(layer.slot),"render_slot":"offhand" if str(layer.slot).ends_with("OFF") else "weapon"}
    return result

static func membership(item:String,state:Dictionary)->Dictionary:
    return locations(state).get(item,{})

static func active(owner:Dictionary,_state:Dictionary)->bool:
    return owner.get("location",{}).get("kind")=="held"

static func observe(owners:Dictionary,state:Dictionary,at_ms:float,cache:Dictionary,event_uuid:String="")->bool:
    var changed:bool=false
    var available:Dictionary=definitions(cache)
    if available.is_empty() and owners.is_empty():return false
    var current:Dictionary=locations(state)
    var admitted:Dictionary={}
    for item in current:
        var location:Dictionary=current[item]
        if location.get("kind")!="held":continue
        var item_id:String=location.item_id
        for cue in available.get(item_id,[]):
            var id:String="item:"+item+":effect:"+str(cue.source)
            admitted[id]=true
            if not owners.has(id):
                owners[id]={"id":id,"item_uuid":item,"item_id":item_id,"definition":cue,
                    "start_ms":at_ms,"source_event_uuid":event_uuid,"location":location}
                changed=true
            elif owners[id].location!=location:
                var after:Dictionary=owners[id].duplicate(false);after.location=location;owners[id]=after;changed=true
    for id in owners:
        if admitted.has(id):continue
        var location:Dictionary=current.get(owners[id].item_uuid,{})
        # A changed look with the same item UUID cannot retain a previous use.
        if location.get("kind")=="held":location={}
        if owners[id].location!=location:
            var after:Dictionary=owners[id].duplicate(false);after.location=location;owners[id]=after;changed=true
    return changed

static func samples(owners:Dictionary,_state:Dictionary,at_ms:float)->Array:
    var result:Array=[]
    for owner in owners.values():
        if not active(owner,{}):continue
        var cue:Dictionary=owner.definition.duplicate(false)
        var equipment:String="weapon_"+("ranged_" if str(owner.location.equipment_slot).begins_with("RANGED") else "melee_")+("off" if owner.location.render_slot=="offhand" else "main")
        if not cue.get("equipment_slots",[]).is_empty() and equipment not in cue.equipment_slots:continue
        cue.merge({"begin":0.0,"end":INF,"launch":0.0,"contact":0.0},true)
        var clip:Dictionary=Effects.resolve(str(cue.clip),str(cue.get("selection","")),"attached").duplicate(false)
        var actor:String=owner.location.holder_uuid
        var row={"id":owner.id,"kind":"native_effect","native_spell":true,"native_item":true,"intrinsic_item_effect":true,
            "item_owner_uuid":owner.item_uuid,"item_effect_owner":owner.id,"item_effect":owner,
            "actor_uuid":actor,"target_uuid":actor,"start_ms":owner.start_ms,"absolute_start_ms":owner.start_ms,
            "duration_ms":INF,"age_ms":maxf(0,at_ms-owner.start_ms),"persistent_owner":true,"lifecycle":{},"alpha":1.0,
            "status":"available","source":cue.source,"source_id":str(cue.clip),"native_clip":clip,"native_cue":cue,
            "cast_recipe":{"enabled":false},"recipe":{},"finish_profile":{},"optical":{"energy_multiplier":0.0},
            "from_position":[0,0],"to_position":[0,0],"from_elevation_feet":0.0,"to_elevation_feet":0.0,
            "trace_keys":[owner.id],"source_event_uuid":owner.source_event_uuid}
        result.append(row)
    return result


## Selection is from the actual attack, never the weapon currently held later.
## Default semantics are hit-contact, not an inferred positive damage rider.
static func impact_binding(fact:Dictionary,cache:Dictionary)->Dictionary:
    if fact.get("attack_source_kind")!="equipped" or fact.get("attack_outcome") not in ["Hit","Crit"]:return {}
    if fact.get("source_item_uuid")==null or fact.get("source_item_id")==null:return {}
    var index:Resource=Bodies.index(cache)
    var cues:Array=[] if index==null else index.item_impact_effects.get(fact.source_item_id,[])
    if cues.is_empty():return {}
    return {"effect_cues":cues,"source":str(cues[0].source).get_base_dir()}
