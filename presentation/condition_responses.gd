extends RefCounted
## Finite projections from disclosed native results and their exact retained
## condition member. No timers, range checks, outcome simulation or state edits.
static func supported(descriptor:Dictionary)->bool:
    return descriptor.get("kind") in ["attributed_damage","attributed_component","miss_damage","attributed_healing","temporary_hp_refresh","consumed_member"] \
        and descriptor.get("participant") in ["owner","recipient"]

static func project(node:Dictionary,actor:Dictionary,member:Dictionary,descriptor:Dictionary,graph:Dictionary)->Dictionary:
    if not supported(descriptor) or node.get("canceled",false) or node.get("fact")==null:return {}
    if descriptor.kind in ["attributed_component","miss_damage"]:return _attack_result(node,actor,member,descriptor,graph)
    var fact:Dictionary=node.fact
    var owner:String=str(actor.uuid)
    var identity:String=str(member.condition_uuid)
    var state:Variant=member.get("state")
    if state!=null and not state.get("suppression_provider_uuids",[]).is_empty():return {}
    for field in descriptor.get("when_state",{}):
        if state==null or state.get(field)!=descriptor.when_state[field]:return {}
    var recipient:String=""
    var evidence:Dictionary={"condition_uuid":identity,"condition_id":str(member.behavior_id),"owner_actor_uuid":owner,
        "result_occurrence":str(node.id),"result_lineage":str(node.lineage_id)}
    match descriptor.kind:
        "consumed_member":
            if fact.get("kind")!="actor_change":return {}
            var removals:Array=graph.get("condition_cues",{}).get(str(node.id),[]).filter(func(cue):
                return cue.get("phase")=="removal" and cue.get("actor_uuid")==owner \
                    and cue.get("condition",{}).get("condition_uuid")==identity and cue.get("row",{}).get("consumed",false))
            if removals.size()!=1:return {}
            recipient=owner;evidence.consumed=true
        "attributed_damage":
            if fact.get("kind")!="damage" or fact.get("stage")!="applied" or int(fact.get("applied_damage",0))<=0:return {}
            if fact.get("source_condition_uuid")!=identity or fact.get("damage_type")!=descriptor.get("damage_type"):return {}
            if descriptor.has("effect_id") and fact.get("effect_id")!=descriptor.effect_id:return {}
            if descriptor.get("source_actor")=="owner" and fact.get("source_entity_uuid")!=owner:return {}
            if fact.get("target_entity_uuid")==null:return {}
            recipient=str(fact.target_entity_uuid)
            evidence.merge({"effect_id":fact.get("effect_id"),"damage_type":fact.damage_type,"applied_damage":fact.applied_damage})
        "attributed_healing":
            if fact.get("kind")!="heal" or int(fact.get("actual_healing",0))<=0 or fact.get("was_blocked",false):return {}
            if fact.get("source_condition_uuid")!=identity or fact.get("target_entity_uuid")==null:return {}
            recipient=str(fact.target_entity_uuid)
            evidence.actual_healing=fact.actual_healing
        "temporary_hp_refresh":
            if fact.get("kind")!="temporary_hit_points" or fact.get("entity_uuid")!=owner:return {}
            var grant:Variant=fact.get("grant")
            if grant==null or grant.get("instance_uuid")==null or str(descriptor.get("grant_source_prefix","")).is_empty() \
                or grant.get("source_id")!=str(descriptor.grant_source_prefix)+identity:return {}
            # Initial application also grants temporary HP. Only the exact
            # recipient's real turn-start ancestry admits the refresh source.
            var boundary:Dictionary={}
            var parent:Variant=node.get("parent_lineage")
            while parent!=null:
                var ancestor:Dictionary=graph.get("nodes",{}).get(str(parent),{})
                if ancestor.is_empty() or ancestor.get("canceled",false):return {}
                var cause:Variant=ancestor.get("fact")
                if cause!=null:
                    if cause.get("kind")=="turn" and cause.get("event_type")=="turn_start" and cause.get("entity_uuid")==owner:
                        boundary=ancestor;break
                    if cause.get("kind") in ["spell","action","attack"]:return {}
                parent=ancestor.get("parent_lineage")
            if boundary.is_empty():return {}
            recipient=owner
            evidence.merge({"grant_instance_uuid":grant.instance_uuid,"grant_source_id":grant.source_id,
                "resulting_temporary_hp":fact.resulting_temporary_hp,"turn_occurrence":str(boundary.id),"turn_lineage":str(boundary.lineage_id)})
    evidence.recipient_uuid=recipient
    return {"owner":owner,"recipient":recipient,"actor":owner if descriptor.participant=="owner" else recipient,"evidence":evidence}


## Spatial responses retain the actual public zone, not an invented actor
## condition. The compiler captures its disclosed before-result snapshot; a
## current heal never borrows a retired zone or an inferred nearby owner.
static func project_spatial(node:Dictionary,captured:Dictionary,descriptor:Dictionary,graph:Dictionary)->Dictionary:
    if node.get("canceled",false) or node.get("phase")!="completion" or node.get("fact")==null or descriptor.get("participant")!="recipient":return {}
    var fact:Dictionary=node.fact
    var identity:String=str(captured.get("identity",""))
    var effect:Dictionary=captured.get("effect",{})
    var content:String=str(effect.get("content_ref",{}).get("content_id",""))
    if identity.is_empty() or content.is_empty() or fact.get("source_condition_uuid")!=identity \
        or fact.get("target_entity_uuid")==null or captured.get("origin_cut")!="canonical_before_result":return {}
    var recipient:String=str(fact.target_entity_uuid)
    var evidence:Dictionary={"owner_kind":"spatial_effect","spatial_effect_uuid":identity,"spatial_content_id":content,
        "source_condition_uuid":identity,"source_actor_uuid":fact.get("source_entity_uuid"),
        "result_occurrence":str(node.id),"result_lineage":str(node.lineage_id),
        "recipient_uuid":recipient,"source_cut":captured.origin_cut}
    var projected:Dictionary={"owner":identity,"recipient":recipient,"actor":recipient,"evidence":evidence}
    if descriptor.get("kind")=="attributed_healing":
        if fact.get("kind")!="heal" or int(fact.get("actual_healing",0))<=0 or fact.get("was_blocked",false):return {}
        evidence.actual_healing=fact.actual_healing
        return projected
    if descriptor.get("kind")!="attributed_damage" or fact.get("kind")!="damage" or fact.get("stage")!="applied" \
        or int(fact.get("applied_damage",0))<=0 or fact.get("damage_type")!=descriptor.get("damage_type"):return {}
    if descriptor.has("effect_id") and fact.get("effect_id")!=descriptor.effect_id:return {}
    evidence.merge({"applied_damage":fact.applied_damage,"damage_type":fact.damage_type,"effect_id":fact.get("effect_id")})
    # A recipient-geometry-only contact can be admitted by this exact positive
    # zone-attributed packet. Turn/save-dependent source variants keep their
    # stronger explicit predicates below; no save is guessed from its amount.
    if str(descriptor.get("turn_event_type","")).is_empty():return projected
    var boundary:Dictionary=_turn_owner(node,recipient,str(descriptor.get("turn_event_type","")),graph)
    if boundary.is_empty():return {}
    var saves:Array=[]
    for scope in graph.get("application_results",{}).values():
        for save in scope.saves:
            if save.fact.get("target_entity_uuid")!=recipient or save.fact.get("effect_id")!=descriptor.get("save_effect_id"):continue
            var saved_node:Dictionary=graph.get("nodes",{}).get(str(save.lineage),{})
            if not saved_node.is_empty() and _turn_owner(saved_node,recipient,str(descriptor.turn_event_type),graph).get("id")==boundary.id:saves.append(save)
    var unique_save:bool=saves.size()==1 and saves[0].fact.get("succeeded")!=null
    var policy:String=str(descriptor.get("save_policy","exact_unique"))
    if policy=="exact_unique" and not unique_save or policy=="unavailable_or_ambiguous" and unique_save:return {}
    if policy not in ["exact_unique","unavailable_or_ambiguous"]:return {}
    evidence.merge({"turn_occurrence":str(boundary.id),"turn_lineage":str(boundary.lineage_id),
        "applied_damage":fact.applied_damage,"damage_type":fact.damage_type,"matching_save_count":saves.size(),
        "original_caster_uuid":fact.get("source_entity_uuid"),"anchor_entity_uuid":effect.get("anchor_entity_uuid")})
    if not unique_save:
        # Exact zone attribution is enough for an authored finite Fire
        # receiver. A source that differentiates save outcomes remains
        # unselected when sibling handlers make that save join ambiguous.
        evidence.save_binding="not_uniquely_disclosed"
        return projected
    var anchor:Variant=effect.get("anchor_entity_uuid")
    # This delivered source only equality-matches source_uuid; when the
    # anchor is undisclosed, explicit empty metadata is sufficient. Neither
    # the caster nor a nearby construct substitutes for the actual anchor.
    var source:String="" if anchor==null else str(anchor)
    var event:Dictionary={"owner_uuid":identity,"source_uuid":source,"damage_component_uuid":str(node.id),
        "recipient_uuid":recipient,"applied":true,"trigger":str(descriptor.trigger),
        "outcome":"saved_half" if saves[0].fact.succeeded else "failed_save"}
    projected.source_values={"owner_uuid":identity,"source_uuid":source,"event":{}}
    projected.native_inputs={"contact_event":event}
    evidence.merge({"anchor_entity_uuid":anchor,"original_caster_uuid":fact.get("source_entity_uuid"),
        "turn_occurrence":str(boundary.id),"turn_lineage":str(boundary.lineage_id),
        "save_occurrence":saves[0].occurrence,"save_lineage":saves[0].lineage,"saved":saves[0].fact.succeeded,
        "save_effect_id":saves[0].fact.effect_id,"applied_damage":fact.applied_damage,"damage_type":fact.damage_type,
        "damage_component_identity":"native_applied_result_occurrence"})
    return projected

static func _turn_owner(node:Dictionary,recipient:String,event_type:String,graph:Dictionary)->Dictionary:
    if event_type.is_empty():return {}
    var parent:Variant=node.get("parent_lineage")
    while parent!=null:
        var ancestor:Dictionary=graph.get("nodes",{}).get(str(parent),{})
        if ancestor.is_empty() or ancestor.get("canceled",false):return {}
        var fact:Variant=ancestor.get("fact")
        if fact!=null:
            if fact.get("kind") in ["action","attack","spell"]:return {}
            if fact.get("kind")=="turn":
                return ancestor if fact.get("event_type")==event_type and fact.get("entity_uuid")==recipient else {}
        parent=ancestor.get("parent_lineage")
    return {}

## Component attribution and the enclosing packet are distinct. Positive
## after-affinity attribution never claims how much of the final HP loss it
## paid. The nearest real attack, member and source must all agree.
static func _attack_result(node:Dictionary,actor:Dictionary,member:Dictionary,descriptor:Dictionary,graph:Dictionary)->Dictionary:
    var fact:Dictionary=node.fact
    if fact.get("kind")!="damage" or fact.get("stage")!="applied" or int(fact.get("applied_damage",0))<=0 \
        or fact.get("source_entity_uuid")!=actor.get("uuid") or fact.get("target_entity_uuid")==null:return {}
    var state:Dictionary=member.state if member.get("state") is Dictionary else {}
    if not state.get("suppression_provider_uuids",[]).is_empty():return {}
    for field in descriptor.get("when_state",{}):
        if state.get(field)!=descriptor.when_state[field]:return {}
    var attack:Dictionary={};var parent:Variant=node.get("parent_lineage")
    while parent!=null:
        var ancestor:Dictionary=graph.get("nodes",{}).get(str(parent),{})
        if ancestor.is_empty() or ancestor.get("canceled",false):return {}
        var cause:Variant=ancestor.get("fact")
        if cause!=null:
            if cause.get("kind")=="attack":attack=ancestor;break
            if cause.get("kind") in ["spell","action"]:return {}
        parent=ancestor.get("parent_lineage")
    if attack.is_empty():return {}
    var strike:Dictionary=attack.fact
    if strike.get("source_entity_uuid")!=actor.uuid or strike.get("target_entity_uuid")!=fact.target_entity_uuid:return {}
    if descriptor.has("attack_behavior_id") and strike.get("behavior_id")!=descriptor.attack_behavior_id:return {}
    if descriptor.has("action_behavior_id"):
        var owner:Dictionary={};parent=attack.get("parent_lineage")
        while parent!=null:
            var ancestor:Dictionary=graph.get("nodes",{}).get(str(parent),{})
            if ancestor.is_empty() or ancestor.get("canceled",false):return {}
            var cause:Variant=ancestor.get("fact")
            if cause!=null and cause.get("kind") in ["action","attack","spell"]:owner=ancestor;break
            parent=ancestor.get("parent_lineage")
        if owner.get("fact",{}).get("behavior_id")!=descriptor.action_behavior_id \
            or owner.fact.get("source_entity_uuid")!=actor.uuid:return {}
    var evidence:Dictionary={"condition_uuid":str(member.condition_uuid),"condition_id":str(member.behavior_id),
        "owner_actor_uuid":str(actor.uuid),"recipient_uuid":str(fact.target_entity_uuid),
        "result_occurrence":str(node.id),"result_lineage":str(node.lineage_id),
        "attack_occurrence":str(attack.id),"attack_lineage":str(attack.lineage_id),
        "packet_applied_damage":fact.applied_damage,"damage_type":fact.damage_type}
    var projected:Dictionary={"owner":str(actor.uuid),"recipient":str(fact.target_entity_uuid),
        "actor":str(fact.target_entity_uuid),"attack":attack,"evidence":evidence}
    if descriptor.kind=="miss_damage":
        if fact.get("source_condition_uuid")!=member.condition_uuid or fact.get("damage_type")!=descriptor.get("damage_type") \
            or strike.get("attack_outcome") not in descriptor.get("attack_outcomes",[]):return {}
        projected.event_state={"observed":true,"active":true,"event_serial":str(node.id),
            "condition_uuid":str(member.condition_uuid),"source_actor_uuid":str(actor.uuid),
            "action_uuid":str(attack.id),"lineage_uuid":str(attack.lineage_id),"recipient_uuid":str(fact.target_entity_uuid),
            "attack_outcome":strike.attack_outcome,"range_type":str(descriptor.range_type),"canceled":false,
            "damage_event_uuid":str(node.id),"damage_type":fact.damage_type,"damage_amount":fact.applied_damage,
            "tenacity_damage_observed":true,"observation_revision":int(node.occurrence)}
        projected.event_binding={"condition_uuid":str(member.condition_uuid),"source_actor_uuid":str(actor.uuid)}
        evidence.merge({"source_condition_uuid":str(member.condition_uuid),"attack_outcome":strike.attack_outcome,
            "range_type":str(descriptor.range_type),"range_basis":"exact_attributed_native_handler",
            "identity_scope":"action/lineage/event keys are native occurrence indices, not wire UUIDs"})
        return projected
    if strike.get("attack_outcome") not in ["Hit","Crit"] \
        or strike.get("source_item_uuid")==null or strike.get("source_item_id")==null \
        or strike.get("weapon_slot") not in ["MELEE_MAIN","MELEE_OFF","RANGED_MAIN","RANGED_OFF"]:return {}
    # Components identify the condition behavior, not its instance. An
    # ambiguous duplicate member cannot borrow one another's event identity.
    var matching:Array=actor.get("conditions",[]).filter(func(value):return value.get("behavior_id")==member.behavior_id)
    if matching.size()!=1:return {}
    var parts:Array=fact.get("components",[]).filter(func(part):return part.get("source_id")==member.behavior_id \
        and part.get("source_entity_uuid")==actor.uuid and part.get("source_damage_uuid")!=null \
        and int(part.get("after_affinity_damage",0))>0 and (not descriptor.has("damage_type") or part.get("damage_type")==descriptor.damage_type))
    if parts.is_empty():return {}
    var identities:Array=[]
    for part in parts:
        if str(part.source_damage_uuid).is_empty() or str(part.source_damage_uuid) in identities:return {}
        identities.append(str(part.source_damage_uuid))
    projected.native_inputs={"weapon_impact":{"occurrence":str(attack.id),"lineage":str(attack.lineage_id),
        "source_item_uuid":str(strike.source_item_uuid),"source_item_id":str(strike.source_item_id),"weapon_slot":str(strike.weapon_slot),
        "source_entity_uuid":str(strike.source_entity_uuid),"target_entity_uuid":str(strike.target_entity_uuid),"attack_outcome":str(strike.attack_outcome)}}
    evidence.merge({"source_damage_uuids":identities,"source_id":str(member.behavior_id),
        "components":parts,"amount_scope":"component_before_packet_reductions","source_item_uuid":str(strike.source_item_uuid)})
    return projected


## The same finite observed-event source contract used by action outcomes can
## receive an exactly attributed condition result. Source art/roles stay in
## its resource; the member UUID never becomes the result's occurrence key.
static func source_result(node:Dictionary,identity:String,behavior:String,projected:Dictionary,descriptor:Dictionary)->Dictionary:
    if descriptor.get("kind")=="observed_event" and descriptor.get("projection")=="spatial_fire_contact":
        if not projected.has("source_values") or not projected.has("native_inputs"):return {}
        return {"values":projected.source_values,"inputs":projected.native_inputs,"evidence":projected.evidence}
    if descriptor.get("kind")!="observed_event" or descriptor.get("projection","event")!="event":return {}
    var fact:Dictionary=node.fact
    var source:Variant=fact.get("source_entity_uuid")
    if source==null or str(source).is_empty():return {}
    var recipient:String=str(projected.recipient)
    var event:Dictionary={"uuid":str(node.id),"source_entity_uuid":str(source),"target_entity_uuid":recipient,
        "canceled":false,"effect_admitted":true}
    match str(descriptor.get("outcome","")):
        "damage":
            if fact.get("kind")!="damage" or fact.get("stage")!="applied" or int(fact.get("applied_damage",0))<=0:return {}
            event.merge({"actual_damage":fact.applied_damage,"damage_type":fact.damage_type,
                "damage_component_uuid":str(node.id),"source_condition_uuid":fact.get("source_condition_uuid")})
        "heal":
            if fact.get("kind")!="heal" or int(fact.get("actual_healing",0))<=0 or fact.get("was_blocked",false):return {}
            event.merge({"actual_healing":fact.actual_healing,"blocked":fact.was_blocked})
        _:return {}
    var roles:Dictionary={"caster":str(source),"target":recipient}
    var geometry:String=str(descriptor.get("geometry_actor",""))
    if not roles.has(geometry):return {}
    return {"values":{"source_entity_uuid":str(source),"recipient_entity_uuid":recipient,"owner_uuid":identity,
        "condition_id":behavior,"event_uuid":str(node.id),"actor_roles":roles,"geometry_actor":roles[geometry],
        "lease":{},"event":{},"plan_only":false,"native_behavior_id":behavior},
        "inputs":{"lease_input":{},"event_input":event},
        "evidence":projected.evidence.merged({"source_uuid":str(source),"target_uuid":recipient,
            "damage_component_identity":"native_applied_result_occurrence" if fact.kind=="damage" else "not_applicable"})}
