extends RefCounted
## Group-local observed results, keyed by native cast lineage and application.
## No target search, rule evaluation, defaults for hidden results or state edits.
static func key(node:Dictionary)->Array:
    var resolution:Dictionary=node.get("resolution_record",{})
    return [] if resolution.get("application_id")==null else [str(resolution.lineage),str(resolution.application_id)]

## A target cast can have a real resolution lineage without an application ID.
## Preserve that null scope; constructor project() still requires key() above.
static func scope_key(node:Dictionary)->Array:
    var resolution:Dictionary=node.get("resolution_record",{})
    if resolution.get("lineage")==null:return []
    return [str(resolution.lineage),null if resolution.get("application_id")==null else str(resolution.application_id)]

static func _save_owner(node:Dictionary,nodes:Dictionary)->Dictionary:
    var parent:Variant=node.get("parent_lineage")
    while parent!=null:
        var owner:Dictionary=nodes.get(str(parent),{})
        if owner.is_empty() or owner.get("canceled",false):return {}
        var fact:Variant=owner.get("fact")
        if fact!=null and fact.kind in ["spell","action","attack"]:return owner
        parent=owner.get("parent_lineage")
    return {}

static func index(events:Array,nodes:Dictionary={})->Dictionary:
    if nodes.is_empty():
        nodes={}
        for node in events:nodes[str(node.lineage_id)]=node
    var result:Dictionary={}
    for node in events:
        var identity:Array=scope_key(node)
        if identity.is_empty() or node.get("canceled",false) or node.get("fact")==null:continue
        var fact:Dictionary=node.fact
        if fact.kind!="saving_throw" and not (fact.kind=="damage" and fact.get("stage")=="applied"):continue
        if not result.has(identity):result[identity]={"saves":[],"damage":[]}
        var row:Dictionary={"occurrence":str(node.id),"lineage":str(node.lineage_id),"fact":fact}
        if fact.kind=="saving_throw":
            var owner:Dictionary=_save_owner(node,nodes)
            row.owner_occurrence=owner.get("id","");row.owner_lineage=owner.get("lineage_id","")
        result[identity]["saves" if fact.kind=="saving_throw" else "damage"].append(row)
    return result

## Variant operands belong to one actual application and recipient. A false
## result is disclosed data; absence, a null effect, or duplicate saves is not.
static func save_context(node:Dictionary,results:Dictionary)->Dictionary:
    if node.get("canceled",false):return {"ready":false,"reason":"application_save_canceled","by_effect":{}}
    var identity:Array=scope_key(node)
    if identity.is_empty():return {"ready":false,"reason":"application_result_identity_unavailable","by_effect":{}}
    var fact:Variant=node.get("fact")
    var target:Variant=null if fact==null else fact.get("target_entity_uuid")
    if identity[1]==null and (fact==null or fact.get("kind")!="spell" or node.get("phase")!="completion" or target==null):
        return {"ready":false,"reason":"application_result_identity_unavailable","by_effect":{}}
    if target==null:return {"ready":false,"reason":"application_result_target_unavailable","by_effect":{}}
    var grouped:Dictionary={}
    for row in results.get(identity,{}).get("saves",[]):
        if row.get("owner_occurrence")!=str(node.id) or row.fact.get("target_entity_uuid")!=target:continue
        var effect:Variant=row.fact.get("effect_id")
        if effect==null or effect=="":continue
        if not grouped.has(effect):grouped[effect]=[]
        grouped[effect].append(row)
    var by_effect:Dictionary={};var ready:bool=false
    for effect in grouped:
        var rows:Array=grouped[effect]
        var evidence:Dictionary={"cast_lineage":identity[0],"application_id":identity[1],
            "application_occurrence":str(node.id),"application_lineage":str(node.lineage_id),
            "target_uuid":target,"effect_id":effect}
        if identity[1]==null:evidence.scope="target_cast"
        if rows.size()!=1:
            evidence.save_occurrences=rows.map(func(row):return row.occurrence)
            evidence.save_lineages=rows.map(func(row):return row.lineage)
            by_effect[effect]={"ready":false,"reason":"save_result_ambiguous","evidence":evidence}
            continue
        var save:Dictionary=rows[0]
        evidence.save_occurrence=save.occurrence;evidence.save_lineage=save.lineage
        if save.fact.get("succeeded")==null:
            by_effect[effect]={"ready":false,"reason":"save_outcome_unavailable","evidence":evidence}
            continue
        by_effect[effect]={"ready":true,"reason":"","save_succeeded":save.fact.succeeded,"evidence":evidence}
        ready=true
    return {"ready":ready,"reason":"" if ready else "save_effect_unavailable" if by_effect.is_empty() else "save_result_unavailable","by_effect":by_effect}

static func project(node:Dictionary,descriptor:Dictionary,results:Dictionary)->Dictionary:
    var identity:Array=key(node)
    if identity.is_empty():return {"ready":false,"reason":"application_result_identity_unavailable"}
    var actual:Dictionary=results.get(identity,{})
    var target:Variant=node.fact.get("target_entity_uuid")
    if target==null:return {"ready":false,"reason":"application_result_target_unavailable"}
    var saves:Array=actual.get("saves",[]).filter(func(row):return row.fact.get("target_entity_uuid")==target and row.fact.get("effect_id")==descriptor.save_effect_id)
    var damage:Array=actual.get("damage",[]).filter(func(row):return row.fact.get("target_entity_uuid")==target and row.fact.get("damage_type")==descriptor.damage_type)
    if saves.size()!=1:return {"ready":false,"reason":"application_result_save_unavailable"}
    if damage.is_empty():return {"ready":false,"reason":"application_result_damage_unavailable"}
    var amount:int=0
    for row in damage:amount+=int(row.fact.applied_damage)
    return {"ready":true,"values":{"application_id":identity[1],"target_actor":str(target),"target_entity_uuid":str(target),
        "damage_applied":amount>0,"save_succeeded":saves[0].fact.succeeded,"damage_type":str(descriptor.damage_type).to_lower()},
        "evidence":{"cast_lineage":identity[0],"application_id":identity[1],"target_uuid":target,
            "application_occurrence":str(node.id),"application_lineage":str(node.lineage_id),
            "save_occurrence":saves[0].occurrence,"save_lineage":saves[0].lineage,
            "damage_occurrences":damage.map(func(row):return row.occurrence),"damage_lineages":damage.map(func(row):return row.lineage),"applied_damage":amount}}

## A first-cast spell strike consumes its own native descendant result. The
## Factory's *_uuid aliases below are opaque seat-local occurrence keys,
## never private damage-roll UUIDs or a fabricated held-condition owner.
static func spell_strike(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Dictionary:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false):return {"ready":false,"reason":"spell_strike_canceled"}
    if fact==null or fact.get("kind")!="spell" or fact.get("behavior_id")!=descriptor.get("behavior_id"):
        return {"ready":false,"reason":"spell_strike_first_cast_not_observed"}
    if fact.get("attack_outcome") not in ["Hit","Crit"]:
        return {"ready":false,"reason":"spell_strike_hit_not_observed"}
    var source:Variant=fact.get("source_entity_uuid")
    var target:Variant=fact.get("target_entity_uuid")
    if source==null or target==null:return {"ready":false,"reason":"spell_strike_recipient_not_disclosed"}
    var rows:Array=graph.get("observed_results",{}).get(str(node.id),[]).filter(func(row):
        return row.kind=="damage" and row.target_uuid==str(target) and row.node.fact.get("source_entity_uuid")==source \
            and row.node.fact.damage_type==descriptor.damage_type)
    if rows.size()!=1:return {"ready":false,"reason":"spell_strike_exact_damage_not_observed"}
    var damage:Dictionary=rows[0].node
    var strike:Dictionary={"source_actor_uuid":str(source),"recipient_uuid":str(target),"attack_uuid":str(node.id),
        "behavior_id":str(fact.behavior_id),"attack_kind":"spell","source_kind":"spell",
        "outcome":"critical" if fact.attack_outcome=="Crit" else "hit","payload_applied":true,
        "damage_type":str(damage.fact.damage_type).to_lower(),"damage_fact_uuid":str(damage.id)}
    var evidence:Dictionary={"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),
        "result_occurrence":str(damage.id),"result_lineage":str(damage.lineage_id),"source_uuid":source,"target_uuid":target,
        "applied_damage":damage.fact.applied_damage,"damage_type":damage.fact.damage_type,
        "damage_fact_identity":"native_applied_result_occurrence","resolution":node.get("resolution_record",{})}
    for field in ["source_condition_uuid","effect_id"]:
        if damage.fact.get(field)!=null:strike[field]=damage.fact[field];evidence[field]=damage.fact[field]
    # This finite source branch never reads owner, condition, tick or healing.
    # Clear their review packets and unused review identities in the private
    # source input; its sealed phase/material/art settings are retained.
    var values:Dictionary={"source_actor_uuid":str(source),"recipient_uuid":str(target),"attack_uuid":str(node.id),
        "behavior_id":str(fact.behavior_id),"strike":strike,"owner":{},"condition":{},"tick":{},"healing":{},
        "item_uuid":"","equipment_slot":"","render_slot":"","activation_event_uuid":"",
        "condition_uuid":"","condition_id":"","owner_uuid":"","owner_id":""}
    return {"ready":true,"reason":"","values":values,"inputs":{"strike_input":strike},"evidence":evidence}

## Index committed outcomes once per received group. An ancestor consumes only
## its native descendants; neither recipient proximity nor art chooses results.
static func observed_index(events:Array,graph:Dictionary)->Dictionary:
    var result:Dictionary={}
    for node in events:
        if node.get("canceled",false) or node.get("fact")==null:continue
        var fact:Dictionary=node.fact
        var rows:Array=[]
        if fact.kind=="heal" and int(fact.actual_healing)>0 and not fact.was_blocked:
            rows.append({"kind":"heal","target_uuid":str(fact.target_entity_uuid),"node":node,
                "event":{"actual_healing":fact.actual_healing,"blocked":fact.was_blocked,
                    "heal_fact":fact}})
        if fact.kind=="damage" and fact.get("stage")=="applied" and int(fact.applied_damage)>0:
            # The finite Factory outcome uses an opaque damage-component key.
            # One disclosed applied-result occurrence is that exact component;
            # this is not a wire UUID, roll identity or inferred passive rider.
            rows.append({"kind":"damage","target_uuid":str(fact.target_entity_uuid),"node":node,
                "event":{"actual_damage":fact.applied_damage,"damage_type":fact.damage_type,
                    "damage_component_uuid":str(node.id),"source_condition_uuid":fact.get("source_condition_uuid"),
                    "effect_id":fact.get("effect_id")}})
        if fact.kind=="life" and fact.previous_state=="dead" and fact.new_state=="alive":
            rows.append({"kind":"revival","target_uuid":str(fact.entity_uuid),"node":node,
                "event":{"revival_observed":true,"life_before":fact.previous_state,"life_after":fact.new_state,
                    "revived_entity_uuid":fact.entity_uuid,"life_change_event_uuid":str(node.id)}})
        var removed:Dictionary={}
        for cue in graph.get("condition_cues",{}).get(node.id,[]):
            if cue.phase!="removal":continue
            if not removed.has(cue.actor_uuid):removed[cue.actor_uuid]=[]
            removed[cue.actor_uuid].append(cue.condition.condition_uuid)
        for actor in removed:rows.append({"kind":"removal","target_uuid":str(actor),"node":node,
            "event":{"removed_condition_uuids":removed[actor]}})
        if rows.is_empty():continue
        var parent:Variant=node.get("parent_lineage")
        while parent!=null:
            var owner:Dictionary=graph.nodes.get(str(parent),{})
            if owner.is_empty():break
            if not result.has(str(owner.id)):result[str(owner.id)]=[]
            result[str(owner.id)].append_array(rows)
            parent=owner.get("parent_lineage")
    return result

static func observed(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var projection:String=str(descriptor.get("projection","event"))
    if projection!="event" and (node.get("phase")!="completion" or node.fact.get("source_entity_uuid")==null):return []
    var source:String=str(node.fact.source_entity_uuid)
    var kind:String=str(descriptor.outcome)
    # A finite source may draw at the caster or speak toward the actual
    # recipient. A target role never turns an undisclosed recipient into self.
    var recipient:Variant=node.fact.get("target_entity_uuid") if descriptor.get("recipient_role","caster")=="target" else source
    if node.get("canceled",false) or (kind=="cast" and recipient==null):return []
    var rows:Array=[{"node":node,"target_uuid":str(recipient),"event":{}}] if kind=="cast" else graph.get("observed_results",{}).get(str(node.id),[]).filter(func(row):return row.kind==kind)
    var revived:Array=[]
    if descriptor.get("living_only",false):
        for row in graph.get("observed_results",{}).get(str(node.id),[]):
            if row.kind=="revival":revived.append(row.target_uuid)
    var result:Array=[]
    for row in rows:
        if projection!="event" and row.node.get("phase")!="completion":continue
        if projection=="applied_contact" and row.node.fact.get("target_entity_uuid")==null:continue
        if row.target_uuid in revived:continue
        # A damage/heal explicitly names its source. A LifeFact/removal is linked by
        # the native parent lineage instead; it has no invented source fact.
        if kind in ["heal","damage"] and row.node.fact.get("source_entity_uuid")!=source:continue
        if kind=="damage" and descriptor.has("damage_type") and row.node.fact.damage_type!=descriptor.damage_type:continue
        if projection=="healing_return":
            # The actual self-heal returns optically from the drained enemy.
            # Preserve the different factual recipient in the packet/evidence.
            if kind!="heal" or node.fact.get("kind") not in ["spell","action"] \
                or node.fact.get("target_entity_uuid")==null or row.target_uuid!=source \
                or row.node.get("parent_event")==null:continue
            var donor:String=str(node.fact.target_entity_uuid)
            var healing:Dictionary={"observed":true,"actual_healing":row.node.fact.actual_healing,
                "was_blocked":row.node.fact.was_blocked,"healing_fact_uuid":str(row.node.id),
                "source_actor_uuid":source,"recipient_uuid":row.target_uuid,
                "parent_event_uuid":str(row.node.parent_event)}
            var returned:Dictionary={"source_actor_uuid":source,"recipient_uuid":donor,
                "activation_event_uuid":str(row.node.parent_event),"behavior_id":str(node.fact.behavior_id),
                "healing":healing,"owner":{},"strike":{},"condition":{},"tick":{},
                "item_uuid":"","equipment_slot":"","render_slot":"","attack_uuid":"",
                "condition_uuid":"","condition_id":"","owner_uuid":"","owner_id":""}
            result.append({"node":row.node,"target_uuid":donor,"values":returned,
                "inputs":{"healing_input":healing},"event":row.event,
                "evidence":{"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),
                    "result_occurrence":str(row.node.id),"result_lineage":str(row.node.lineage_id),
                    "activation_parent_occurrence":str(row.node.parent_event),"source_uuid":source,
                    "target_uuid":donor,"healed_target_uuid":row.target_uuid,"actual_healing":row.node.fact.actual_healing,
                    "outcome":"heal"}})
            continue
        var target:String=str(row.target_uuid)
        var event:Dictionary=row.event.merged({"uuid":str(row.node.id),"source_entity_uuid":source,
            "target_entity_uuid":target,"canceled":false,"effect_admitted":true},true)
        var roles={"caster":source,"target":target}
        var values={"source_entity_uuid":source,"recipient_entity_uuid":target,"owner_uuid":str(node.id),"event_uuid":str(row.node.id),
            "actor_roles":roles,"geometry_actor":roles[str(descriptor.geometry_actor)],"lease":{},"event":{},"plan_only":false,
            "native_behavior_id":str(node.fact.behavior_id),"voice_recipient_actor":target}
        if kind=="cast":values.parent_owner_uuid=""
        var evidence:Dictionary={"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),
            "result_occurrence":str(row.node.id),"result_lineage":str(row.node.lineage_id),"target_uuid":target,"outcome":kind}
        if kind=="damage":
            evidence.merge({"damage_component_identity":"native_applied_result_occurrence","applied_damage":row.node.fact.applied_damage,
                "damage_type":row.node.fact.damage_type,"source_condition_uuid":row.node.fact.get("source_condition_uuid"),
                "effect_id":row.node.fact.get("effect_id")})
        var inputs:Dictionary={"lease_input":{},"event_input":event}
        if projection=="applied_contact":
            # One applied-result occurrence owns this finite contact. Its cast
            # identity is distinct from any subsequently held condition UUID.
            var contact:Dictionary={"source_owner_uuid":str(node.id),"recipient_uuid":target,
                "original_caster_uuid":source,"event_uuid":str(row.node.id),"damage_applied":true}
            values.merge({"source_owner_uuid":str(node.id),"recipient_uuid":target,"original_caster_uuid":source,
                "condition_uuid":"","condition_id":"","state":contact},true)
            inputs={"native_state":contact}
        elif projection=="cast_completion":
            var identities:Dictionary={"event_uuid":str(node.id),"cast_uuid":str(node.id),
                "source_entity_uuid":source,"target_entity_uuid":target}
            var completion:Dictionary=identities.merged({"admitted":true,"canceled":false,"phase":"completion"})
            values.owner=identities.merged({"owner_uuid":str(node.id),"condition_uuid":"","condition_id":""})
            values.observation=completion
            inputs={"observation":completion}
        result.append({"node":row.node,"target_uuid":target,"values":values,"event":event,"inputs":inputs,"evidence":evidence})
    return result
