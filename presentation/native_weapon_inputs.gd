extends RefCounted
## Actual equipped-item operands. Physical optical sources may share; item,
## holder, contribution and condition identities never come from a source rig.

static func slots(component:Dictionary)->Array:
    var cue:Dictionary=component.get("native_cue",{})
    var authored:Dictionary=cue.get("recipient_geometry",cue.get("entity_geometry",{}))
    var result:Array=[]
    for slot in authored.get("slots",[]):
        if slot in ["weapon","offhand"] and slot not in result:result.append(slot)
    if result.is_empty() and cue.get("attachment")=="recipient_weapon" and cue.get("anchor") in ["weapon","offhand"]:
        result.append(cue.anchor)
    return result

static func actor(component:Dictionary)->String:
    var cue:Dictionary=component.get("native_cue",{})
    var authored:Dictionary=cue.get("recipient_geometry",cue.get("entity_geometry",{}))
    var selector:String=str(authored.get("actor",""))
    if selector=="caster":return str(component.get("actor_uuid",""))
    if selector in ["target","recipient"]:
        var target:Variant=component.get("target_uuid");return "" if target==null else str(target)
    if not selector.is_empty():return str(component.get("native_actor_uuids",{}).get(selector,""))
    var target:Variant=component.get("target_uuid")
    if not str(cue.get("attachment","")).begins_with("caster") and target!=null:return str(target)
    return str(component.get("actor_uuid",""))

static func resolve(world:Node,component:Dictionary)->Dictionary:
    var raw:Variant=component.get("condition",{}).get("state")
    var condition:Dictionary=raw if raw is Dictionary else {}
    var explicit:Dictionary=component.get("native_inputs",{}).get("weapon_binding",{})
    var item:Variant=condition.get("affected_item_uuid")
    if item==null:item=explicit.get("item_uuid")
    var target:Variant=component.get("target_uuid")
    if item==null and target!=null and world.timeline.state.get("items",{}).has(str(target)):item=target
    var owner:String=actor(component)
    if item==null and world.timeline.state.get("items",{}).has(owner):item=owner
    var requested:Array=slots(component)
    var result:Dictionary={"ready":false,"reason":"weapon_render_slot_not_authored","actor":owner,"slots":requested,
        "item_uuid":"" if item==null else str(item),"equipment_slot":"","render_slot":"","binding":{},"public_gaps":[]}
    if requested.is_empty():return result
    var actors:Dictionary=world.timeline.state.get("actors",{})
    var candidates:Array=[]
    # An actor-owned coating stays on that actor; an item-owned coating may
    # follow only the exact item's actually disclosed current holder.
    var holders:Array=[owner] if actors.has(owner) else actors.keys() if item!=null else []
    for holder in holders:
        var visual:Dictionary=world.visual_actors.get(holder,{})
        if visual.is_empty() or not visual.get("valid",false):continue
        for entry in visual.get("entries",[]):
            var layer:Dictionary=entry.actor_layer
            if entry.role=="shadow" or not entry.node.is_visible_in_tree() or not layer.get("effect",{}).is_empty():continue
            if layer.slot not in requested or not layer.has("item_uuid"):continue
            if item!=null and layer.item_uuid!=str(item):continue
            var matching:Array=actors[holder].get("visual_loadout",{}).get("layers",[]).filter(func(value):return value.item_uuid==layer.item_uuid)
            # Rendered item identity alone cannot invent an equipment slot.
            if matching.size()!=1:continue
            var equipped:String=str(matching[0].slot)
            if equipped not in ["MELEE_MAIN","MELEE_OFF","RANGED_MAIN","RANGED_OFF"]:continue
            var key:Array=[holder,layer.item_uuid,equipped,layer.slot]
            if not candidates.any(func(candidate):return candidate.key==key):
                candidates.append({"key":key,"actor":holder,"item_uuid":layer.item_uuid,"item_id":str(matching[0].get("item_id","")),"equipment_slot":equipped,"render_slot":layer.slot})
    if candidates.is_empty():result.reason="exact_weapon_not_currently_displayed";return result
    if candidates.size()!=1:result.reason="weapon_binding_ambiguous";return result
    var selected:Dictionary=candidates[0]
    result.merge(selected,true);result.erase("key");result.slots=[result.render_slot]
    var record:Dictionary=world.timeline.state.get("items",{}).get(result.item_uuid,{})
    if record.is_empty():result.reason="weapon_item_not_disclosed";return result
    var effect:Variant=component.get("condition_uuid",component.get("condition",{}).get("condition_uuid"))
    if effect==null or str(effect).is_empty():result.reason="weapon_effect_identity_not_disclosed";return result
    # Schema16 retires active Antimagic suppression; its absent legacy field
    # is not an unknown verdict. An actual supplied override still retires
    # the coating without changing the exact owner/item binding.
    var suppressed:bool=bool(explicit.get("suppressed",false))
    var owner_kind:String="caster" if actors.has(owner) else "item"
    result.binding={"owner_kind":owner_kind,"owner_uuid":owner,"effect_uuid":str(effect),"item_uuid":result.item_uuid,
        "item_id":result.item_id,"holder_uuid":result.actor,"equipment_slot":result.equipment_slot,"render_slot":result.render_slot,
        "present":true,"observed":true,"equipped":true,"suppressed":suppressed,
        "binding_origin":"observed_condition_and_current_visual_item"}
    # Legacy ownership sources have additional admission semantics. These are
    # not universal wire fields and prepared Measured does not require them.
    # Keep them explicit until their authored owner projection is supplied.
    for field in ["contribution_active","decoration_admitted"]:
        if explicit.has(field):result.binding[field]=explicit[field]
        else:result.public_gaps.append(field)
    result.ready=true;result.reason=""
    return result

static func surface(value:Dictionary,resolved:Dictionary)->Dictionary:
    var result:Dictionary=value.duplicate(false)
    result.item_uuid=resolved.item_uuid;result.equipment_slot=resolved.equipment_slot
    result.geometry_slots=resolved.slots
    result.gpu_geometry_key=[value.get("gpu_geometry_key",[]),resolved.item_uuid,resolved.equipment_slot,resolved.render_slot]
    return result

static func packet(resolved:Dictionary,hand:Dictionary)->Dictionary:
    if not resolved.ready:return {"ready":false,"reason":resolved.reason,"binding":{},"public_gaps":resolved.public_gaps}
    if not hand.get("ready",false):return {"ready":false,"reason":hand.get("reason","weapon_hand_not_prepared"),"binding":{},"public_gaps":resolved.public_gaps}
    var binding:Dictionary=resolved.binding.duplicate(false);binding.hand=hand.point
    return {"ready":true,"reason":"","binding":binding,"public_gaps":resolved.public_gaps}
