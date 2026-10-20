extends RefCounted
## Decorations share the actual item's membership, never its body. Intrinsic
## uses follow gear; selected dynamic uses follow exact public effect UUIDs.
## Actor Conditions and finite spell/action cues retain their existing owners.
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
    if not entries.is_empty() and not delta.get("items",{}).is_empty():return true
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
    return owner.get("member_present",true) and owner.get("location",{}).get("kind")=="held"

static func _matches(cue:Dictionary,member:Dictionary)->bool:
    return not str(cue.get("item_effect_behavior_id","")).is_empty() \
        and member.get("behavior_id")==cue.item_effect_behavior_id \
        and (str(cue.get("item_effect_damage_type","")).is_empty() or member.get("damage_type")==cue.item_effect_damage_type)

static func _identity(item:String,cue:Dictionary,effect:String="")->String:
    return "item:"+item+":effect:"+str(cue.source)+(":"+effect if not effect.is_empty() else "")

static func _kind(state:Dictionary,item:String,location:Dictionary)->String:
    return str(location.get("item_id",state.get("items",{}).get(item,{}).get("look",{}).get("item_id","")))

static func _admit(owners:Dictionary,item:String,item_id:String,cue:Dictionary,member:Dictionary,at_ms:float,event_uuid:String)->bool:
    var id:String=_identity(item,cue,str(member.effect_uuid))
    var prior:Dictionary=owners.get(id,{})
    if not prior.is_empty() and prior.get("member_present",false) and prior.member==member:return false
    var after:Dictionary=prior.duplicate(false)
    if prior.is_empty() or not prior.get("member_present",false):
        after={"id":id,"item_uuid":item,"item_id":item_id,"definition":cue,"start_ms":at_ms,"end_ms":INF,
            "source_event_uuid":event_uuid,"location":{},"dynamic":true}
    after.member=member;after.member_present=true;owners[id]=after
    return true

static func _remove(owners:Dictionary,id:String,at_ms:float,event_uuid:String="")->bool:
    if not owners.has(id) or not owners[id].get("member_present",false):return false
    var after:Dictionary=owners[id].duplicate(false);after.member_present=false;after.end_ms=at_ms;after.end_event_uuid=event_uuid;owners[id]=after
    return true

## A transient is inspection evidence of actual ordered membership, not an
## eligible optical sample or permission to construct an absent item's effect.
static func transient_memberships(owners:Dictionary,at_ms:float)->Array:
    return owners.values().filter(func(owner):return owner.get("dynamic",false) and not owner.get("member_present",false) \
        and float(owner.get("end_ms",INF))==at_ms and float(owner.start_ms)==at_ms)

static func observe(owners:Dictionary,state:Dictionary,at_ms:float,cache:Dictionary,event_uuid:String="",item_rows:Array=[])->bool:
    var changed:bool=false
    var available:Dictionary=definitions(cache)
    if available.is_empty() and owners.is_empty():return false
    var current:Dictionary=locations(state)
    var admitted:Dictionary={}
    # The SDK supplies these immutable before/after arrays in original row
    # order. Removal/reapplication can share one final snapshot and one clock.
    for row in item_rows:
        var item:String=str(row.item_uuid)
        var item_id:String=_kind(state,item,current.get(item,{}))
        var after_members:Dictionary={}
        for member in row.after:after_members[str(member.effect_uuid)]=member
        for cue in available.get(item_id,[]):
            if str(cue.get("item_effect_behavior_id","")).is_empty():continue
            for member in row.before:
                if _matches(cue,member) and not _matches(cue,after_members.get(str(member.effect_uuid),{})):
                    changed=_remove(owners,_identity(item,cue,str(member.effect_uuid)),at_ms,event_uuid) or changed
            for member in row.after:
                if not _matches(cue,member):continue
                # This is a disclosed membership transition, not cached item
                # metadata. Its lifetime does not invent a holder or optical
                # eligibility; location remains independently authoritative.
                changed=_admit(owners,item,item_id,cue,member,at_ms,event_uuid) or changed
    for item in current:
        var location:Dictionary=current[item]
        var item_id:String=_kind(state,item,location)
        for cue in available.get(item_id,[]):
            if not str(cue.get("item_effect_behavior_id","")).is_empty():
                for member in state.get("items",{}).get(item,{}).get("effects",[]):
                    if not _matches(cue,member):continue
                    var id:String=_identity(item,cue,str(member.effect_uuid))
                    admitted[id]=true
                    changed=_admit(owners,item,item_id,cue,member,at_ms,event_uuid) or changed
                continue
            if location.get("kind")!="held":continue
            var id:String=_identity(item,cue)
            admitted[id]=true
            if not owners.has(id):
                owners[id]={"id":id,"item_uuid":item,"item_id":item_id,"definition":cue,
                    "start_ms":at_ms,"source_event_uuid":event_uuid,"location":location}
                changed=true
            elif owners[id].location!=location:
                var after:Dictionary=owners[id].duplicate(false);after.location=location;owners[id]=after;changed=true
    for id in owners:
        var owner:Dictionary=owners[id]
        var location:Dictionary=current.get(owner.item_uuid,{})
        if owner.get("dynamic",false) and current.has(owner.item_uuid) and not admitted.has(id):
            changed=_remove(owners,id,at_ms,event_uuid) or changed
        # A changed look with the same item UUID cannot retain a previous use.
        if not admitted.has(id) and location.get("kind")=="held":location={}
        if owners[id].location!=location:
            var after:Dictionary=owners[id].duplicate(false);after.location=location;owners[id]=after;changed=true
    return changed

static func samples(owners:Dictionary,_state:Dictionary,at_ms:float)->Array:
    var result:Array=[]
    for owner in owners.values():
        # Studio inspects exact same-clock transitions before sampling. Later
        # samples release ended dynamic metadata just like other owner tables.
        if owner.get("dynamic",false) and not owner.get("member_present",false) and at_ms>float(owner.end_ms):
            owners.erase(owner.id);continue
        if not active(owner,{}):continue
        var cue:Dictionary=owner.definition.duplicate(false)
        var equipment:String="weapon_"+("ranged_" if str(owner.location.equipment_slot).begins_with("RANGED") else "melee_")+("off" if owner.location.render_slot=="offhand" else "main")
        if not cue.get("equipment_slots",[]).is_empty() and equipment not in cue.equipment_slots:continue
        cue.merge({"begin":0.0,"end":INF,"launch":0.0,"contact":0.0},true)
        var clip:Dictionary=Effects.resolve(str(cue.clip),str(cue.get("selection","")),"attached").duplicate(false)
        var actor:String=owner.location.holder_uuid
        var dynamic:bool=owner.get("dynamic",false)
        var row={"id":owner.id,"kind":"native_effect","native_spell":true,"native_item":true,"intrinsic_item_effect":not dynamic,
            "item_owner_uuid":owner.item_uuid,"item_effect_owner":owner.id,"item_effect":owner,
            "actor_uuid":actor,"target_uuid":actor,"start_ms":owner.start_ms,"absolute_start_ms":owner.start_ms,
            "duration_ms":INF,"age_ms":maxf(0,at_ms-owner.start_ms),"persistent_owner":true,"lifecycle":{},"alpha":1.0,
            "status":"available","source":cue.source,"source_id":str(cue.clip),"native_clip":clip,"native_cue":cue,
            "cast_recipe":{"enabled":false},"recipe":{},"finish_profile":{},"optical":{"energy_multiplier":0.0},
            "from_position":[0,0],"to_position":[0,0],"from_elevation_feet":0.0,"to_elevation_feet":0.0,
            "trace_keys":[owner.id],"source_event_uuid":owner.source_event_uuid}
        if dynamic:
            row.dynamic_item_effect=true;row.item_effect_uuid=str(owner.member.effect_uuid);row.item_effect_member=owner.member
        var unbound:Array=cue.get("unbound_constructor_inputs",[])
        if not unbound.is_empty():
            row.status="missing";row.unbound_constructor_inputs=unbound
            row.reason="native_constructor_inputs_unbound:"+",".join(unbound)
        result.append(row)
    return result


## Selection is from the actual attack, never the weapon currently held later.
## Conditional contacts use that attack's disclosed item-effect membership.
## Neither membership nor a successful contact asserts positive rider damage.
static func impact_binding(fact:Dictionary,cache:Dictionary)->Dictionary:
    if fact.get("attack_source_kind")!="equipped" or fact.get("attack_outcome") not in ["Hit","Crit"]:return {}
    if fact.get("source_item_uuid")==null or fact.get("source_item_id")==null:return {}
    var index:Resource=Bodies.index(cache)
    var cues:Array=[] if index==null else index.item_impact_effects.get(fact.source_item_id,[])
    var selected:Array=[]
    for cue in cues:
        if str(cue.get("item_effect_behavior_id","")).is_empty():
            selected.append(cue);continue
        var members:Array=fact.get("item_effects",[]).filter(func(member):return _matches(cue,member))
        if members.is_empty():continue
        # One contact per authored use, even when several actual contributions
        # match. Keep all exact members as evidence, not another held owner.
        var actual:Dictionary=cue.duplicate(false)
        actual.item_effect_members=members
        actual.item_effect_source_item_uuid=fact.source_item_uuid
        selected.append(actual)
    if selected.is_empty():return {}
    return {"effect_cues":selected,"source":str(selected[0].source).get_base_dir()}
