extends RefCounted
const Creation=preload("res://presentation/creation_inputs.gd")
const Catalog=preload("res://source_catalog.gd")
const Characters=preload("res://presentation/characters.gd")
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

## A completed spell strike consumes its own native descendant result. The
## Factory's *_uuid aliases below are opaque seat-local occurrence keys,
## never private damage-roll UUIDs or a fabricated held-condition owner.
static func spell_strike(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Dictionary:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false):return {"ready":false,"reason":"spell_strike_canceled"}
    if fact==null or fact.get("kind")!="spell" or fact.get("behavior_id")!=descriptor.get("behavior_id") or node.get("phase")!="completion":
        return {"ready":false,"reason":"spell_strike_first_cast_not_observed"}
    if fact.get("attack_outcome") not in ["Hit","Crit"]:
        return {"ready":false,"reason":"spell_strike_hit_not_observed"}
    var source:Variant=fact.get("source_entity_uuid")
    var target:Variant=fact.get("target_entity_uuid")
    if source==null or target==null:return {"ready":false,"reason":"spell_strike_recipient_not_disclosed"}
    var rows:Array=graph.get("observed_results",{}).get(str(node.id),[]).filter(func(row):
        return row.kind=="damage" and row.target_uuid==str(target) and row.node.fact.get("source_entity_uuid")==source \
            and row.node.fact.damage_type==descriptor.damage_type and row.node.get("phase")=="completion" \
            and _cast_owns_result(node,row.node,graph))
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
    # Clear review packets before applying the exact finite source operands.
    # An initial impact never reads an owner. A completed granted repeat is
    # an event-local activity witness for its one disclosed pre-row member;
    # it does not infer contribution activity at any idle or later cut.
    var values:Dictionary={"source_actor_uuid":str(source),"recipient_uuid":str(target),"attack_uuid":str(node.id),
        "behavior_id":str(fact.behavior_id),"strike":strike,"owner":{},"condition":{},"tick":{},"healing":{},
        "item_uuid":"","equipment_slot":"","render_slot":"","activation_event_uuid":"",
        "condition_uuid":"","condition_id":"","owner_uuid":"","owner_id":""}
    var inputs:Dictionary={"strike_input":strike}
    var owner_id:String=str(descriptor.get("owner_condition_id",""))
    if not owner_id.is_empty():
        var actor:Dictionary=graph.get("actor_inputs",{}).get(str(node.id),{}).get(str(source),{})
        var members:Array=actor.get("conditions",[]).filter(func(member):return member.get("behavior_id")==owner_id)
        if actor.get("uuid")!=source or members.size()!=1:
            return {"ready":false,"reason":"spell_strike_exact_grant_owner_not_disclosed"}
        var member:Dictionary=members[0]
        var owner:Dictionary={"condition_uuid":str(member.condition_uuid),"condition_id":owner_id,
            "source_actor_uuid":str(source),"recipient_uuid":str(source),"present":true,"observed":true,
            "contribution_active":true,"suppressed":false}
        values.owner=owner;values.owner_uuid=owner.condition_uuid;values.owner_id=owner_id
        inputs.owner_input=owner
        evidence.merge({"condition_uuid":owner.condition_uuid,"condition_id":owner_id,
            "owner_activity_occurrence":str(node.id),"owner_activity_basis":"completed_granted_strike",
            "owner_cut":"source_actor_before_row"})
    return {"ready":true,"reason":"","node":damage,"values":values,"inputs":inputs,"evidence":evidence}

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
        if fact.kind=="life" and fact.new_state=="dead" and fact.previous_state!="dead":
            rows.append({"kind":"death","target_uuid":str(fact.entity_uuid),"node":node})
        if fact.kind=="portal_transfer" and fact.get("committed",false) and node.get("phase")=="completion" \
            and not (fact.get("start_position")!=null and fact.get("end_position")!=null and fact.start_position==fact.end_position):
            rows.append({"kind":"relocation","target_uuid":str(fact.target_entity_uuid),"node":node})
        var removed:Dictionary={}
        for cue in graph.get("condition_cues",{}).get(node.id,[]):
            if cue.phase=="application":
                rows.append({"kind":"condition_application","target_uuid":str(cue.actor_uuid),"node":node,"condition":cue.condition})
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

## A finite cast can name its actual committed descendant membership without
## publishing that condition early. Current item/optical admission is separate.
static func condition_application(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Dictionary:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null or fact.kind!="spell":
        return {"ready":false,"reason":"condition_application_cast_not_observed"}
    var actor:Variant=fact.get("source_entity_uuid")
    if actor==null:return {"ready":false,"reason":"condition_application_actor_not_disclosed"}
    var rows:Array=graph.get("observed_results",{}).get(str(node.id),[]).filter(func(row):
        return row.kind=="condition_application" and row.target_uuid==str(actor) \
            and row.condition.get("behavior_id")==descriptor.condition_id and _cast_owns_result(node,row.node,graph))
    if rows.size()!=1:return {"ready":false,"reason":"condition_application_exact_owner_not_observed"}
    var applied:Dictionary=rows[0]
    var member:Dictionary=applied.condition
    var evidence:Dictionary={"cast_occurrence":str(node.id),"cast_lineage":str(node.lineage_id),
        "application_occurrence":str(applied.node.id),"application_lineage":str(applied.node.lineage_id),
        "actor_uuid":str(actor),"condition_uuid":str(member.condition_uuid),"condition_id":str(member.behavior_id)}
    return {"ready":true,"condition":member,
        "values":{"ownership":{"owner_kind":"caster","owner_uuid":str(actor),"effect_uuid":str(member.condition_uuid),"binding":{}},"hit":{}},
        "evidence":evidence}

static func _cast_owns_result(cast:Dictionary,result:Dictionary,graph:Dictionary)->bool:
    var parent:Variant=result.get("parent_lineage")
    while parent!=null:
        var owner:Dictionary=graph.get("nodes",{}).get(str(parent),{})
        if owner.is_empty() or owner.get("canceled",false):return false
        if str(owner.lineage_id)==str(cast.lineage_id):return true
        var fact:Variant=owner.get("fact")
        if fact!=null and fact.kind in ["spell","action","attack"]:
            # A native per-recipient application remains this same cast;
            # another action or independently resolving spell is a new owner.
            if fact.kind not in ["spell","action"] or fact.kind!=cast.fact.kind \
                or str(owner.get("resolution_record",{}).get("lineage",""))!=str(cast.lineage_id) \
                or fact.has("behavior_id") and fact.behavior_id!=cast.fact.behavior_id \
                or fact.has("source_entity_uuid") and fact.source_entity_uuid!=cast.fact.source_entity_uuid:return false
        parent=owner.get("parent_lineage")
    return false

static func observed(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var projection:String=str(descriptor.get("projection","event"))
    if projection=="condition_outcome":return _condition_outcome(node,descriptor,graph)
    if projection=="owner_activity":return _owner_activity(node,descriptor,graph)
    if projection=="prismatic_outcomes":return _prismatic(node,descriptor,graph)
    if projection in ["breath_grant","breath_exhale"]:return _breath(node,descriptor,graph)
    if projection=="weapon_component":return _weapon_component(node,descriptor,graph)
    if projection=="quarry_application":return _quarry_application(node,descriptor,graph)
    if projection=="attack_attempt":return _attack_attempt(node,descriptor,graph)
    if projection=="accepted_area_blast":return _accepted_area_blast(node,descriptor,graph)
    if projection=="portable_payload_blast":return _portable_blast(node,descriptor,graph)
    if projection=="owned_fire_contact":return _owned_fire_contact(node,descriptor,graph)
    if projection=="finite_contact":return _finite_contact(node,descriptor,graph)
    if projection=="condition_set_outcome":return _condition_set_outcome(node,descriptor,graph)
    if projection=="immediate_blast":return _immediate_blast(node,descriptor,graph)
    if projection=="retired_payload_blast":return _retired_payload_blast(node,descriptor,graph)
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
        if kind!="cast" and not _cast_owns_result(node,row.node,graph):continue
        if projection=="owned_outcome" and (not _cast_owns_result(node,row.node,graph) \
            or node.fact.get("target_entity_uuid")!=null and str(node.fact.target_entity_uuid)!=str(row.target_uuid)):continue
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

## These sources consume current recipient geometry only. Native outcomes own
## their admission and clock without pretending that the source takes a lease,
## a life-state setter, or a synthetic successful event packet.
static func geometry_results(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null \
        or fact.get("kind") not in ["spell","action"] or fact.get("source_entity_uuid")==null:return []
    var owned:Array=graph.get("observed_results",{}).get(str(node.id),[]).filter(func(row):
        return _cast_owns_result(node,row.node,graph) and (fact.get("target_entity_uuid")==null \
            or str(fact.target_entity_uuid)==row.target_uuid))
    var revived:Array=[]
    for row in owned:
        if row.kind=="revival":revived.append(row.target_uuid)
    var result:Array=[];var seen:Array=[]
    for row in owned:
        if row.kind not in descriptor.outcomes or row.kind=="heal" and row.target_uuid in revived:continue
        if row.node.get("phase")!="completion":continue
        if row.kind=="heal" and row.node.fact.get("source_entity_uuid")!=fact.source_entity_uuid:continue
        if row.target_uuid in seen:return []
        var transfers:Array=owned.filter(func(other):return other.kind=="relocation" and other.target_uuid==row.target_uuid)
        if transfers.size()>1:return []
        var relocated:bool=transfers.size()==1
        if relocated!=(descriptor.relocation=="committed"):continue
        var publication:Dictionary=row.node
        var contact:Dictionary=graph.get("result_contacts",{}).get(str(row.node.id),{})
        if contact.is_empty() or contact.get("target_uuid")!=row.target_uuid:continue
        if relocated:
            var transfer:Dictionary=transfers[0].node
            var destination:Dictionary=graph.get("result_contacts",{}).get(str(transfer.id),{})
            if destination.is_empty() or destination.get("target_uuid")!=row.target_uuid:continue
            if transfer.fact.get("end_position")!=null and destination.position!=transfer.fact.end_position:continue
            # Source indices are the existing ordered canonical cuts, not a
            # guessed age. Both facts must have committed before this source
            # starts; use whichever real supported cut was observed later.
            if int(destination.source_index)>int(contact.source_index):
                publication=transfer;contact=destination
        seen.append(row.target_uuid)
        result.append({"node":publication,"target_uuid":row.target_uuid,"position":contact.position,
            "elevation_feet":float(contact.elevation_steps)*5.0,
            "evidence":{"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),
                "source_uuid":str(fact.source_entity_uuid),"target_uuid":row.target_uuid,
                "result_occurrence":str(row.node.id),"result_lineage":str(row.node.lineage_id),"outcome":row.kind,
                "placement_cut":"canonical_after_result","position":contact.position,"relocated":relocated,
                "publication_occurrence":str(publication.id)}})
    return result

## Eyebite's save has one common effect ID. Its actual new recipient member
## identifies the form, including a granted strike which does not recast the
## spell. A successful save never supplies an undisclosed form by default.
static func _condition_outcome(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null \
        or fact.get("kind") not in ["spell","action"] \
        or fact.get("behavior_id")!=descriptor.get("behavior_id") \
        or fact.get("source_entity_uuid")==null or fact.get("target_entity_uuid")==null:return []
    var source:String=str(fact.source_entity_uuid)
    var target:String=str(fact.target_entity_uuid)
    var applied:Array=graph.get("observed_results",{}).get(str(node.id),[]).filter(func(row):
        return row.kind=="condition_application" and row.target_uuid==target \
            and row.condition.get("behavior_id")==descriptor.get("condition_id") \
            and _cast_owns_result(node,row.node,graph))
    if applied.size()!=1:return []
    var saves:Array=[]
    for scope in graph.get("application_results",{}).values():
        for save in scope.get("saves",[]):
            if save.fact.get("effect_id")!=descriptor.get("save_effect_id") or save.fact.get("target_entity_uuid")!=target \
                or save.fact.get("succeeded")!=descriptor.get("save_succeeded"):continue
            var saved:Dictionary=graph.get("nodes",{}).get(str(save.lineage),{})
            if not saved.is_empty() and _cast_owns_result(node,saved,graph):saves.append(save)
    if saves.size()!=1:return []
    var application:Dictionary=applied[0]
    return [{"node":application.node,"target_uuid":target,"condition":application.condition,
        "values":{},"inputs":{},"event":{},
        "evidence":{"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),
            "source_uuid":source,"target_uuid":target,"condition_uuid":str(application.condition.condition_uuid),
            "condition_id":str(application.condition.behavior_id),"result_occurrence":str(application.node.id),
            "result_lineage":str(application.node.lineage_id),"save_occurrence":str(saves[0].occurrence),
            "save_lineage":str(saves[0].lineage),"save_succeeded":saves[0].fact.succeeded,"form_basis":"actual_recipient_membership"}}]

## The retained hand's finite startup is admitted at a real new membership,
## or an accepted granted activation of its exact before-row member. It never
## borrows a future condition to render before the initial cast completes.
static func _owner_activity(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null \
        or fact.get("kind") not in ["spell","action"] or fact.get("behavior_id")!=descriptor.get("behavior_id") \
        or fact.get("source_entity_uuid")==null or fact.get("target_entity_uuid")==null:return []
    var source:String=str(fact.source_entity_uuid);var target:String=str(fact.target_entity_uuid)
    var rows:Array=[]
    if descriptor.get("new_membership",false):
        for row in graph.get("observed_results",{}).get(str(node.id),[]):
            if row.kind=="condition_application" and row.target_uuid==source \
                and row.condition.get("behavior_id")==descriptor.get("condition_id") and _cast_owns_result(node,row.node,graph):rows.append(row)
    else:
        var actor:Dictionary=graph.get("actor_inputs",{}).get(str(node.id),{}).get(source,{})
        for member in actor.get("conditions",[]):
            if member.get("behavior_id")==descriptor.get("condition_id"):rows.append({"node":node,"condition":member})
    if rows.size()!=1:return []
    var member:Dictionary=rows[0].condition
    var state:Variant=member.get("state")
    if state!=null and not state.get("suppression_provider_uuids",[]).is_empty():return []
    var owner:Dictionary={"condition_uuid":str(member.condition_uuid),"condition_id":str(member.behavior_id),
        "source_actor_uuid":source,"recipient_uuid":source,"present":true,"observed":true,
        "contribution_active":true,"suppressed":false}
    return [{"node":rows[0].node,"target_uuid":target,"condition":member,
        "values":{"source_actor_uuid":source,"recipient_uuid":target,"behavior_id":str(fact.behavior_id),
            "owner_uuid":str(member.condition_uuid),"owner_id":str(member.behavior_id),"owner":{},
            "condition_uuid":"","condition_id":"","item_uuid":"","equipment_slot":"","render_slot":"",
            "attack_uuid":"","activation_event_uuid":"","strike":{},"condition":{},"tick":{},"healing":{}},
        "inputs":{"owner_input":owner},"event":{},
        "evidence":{"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),
            "owner_activity_occurrence":str(rows[0].node.id),"owner_activity_lineage":str(rows[0].node.lineage_id),
            "condition_uuid":str(member.condition_uuid),"condition_id":str(member.behavior_id),
            "owner_activity_basis":"actual_membership_admission" if descriptor.get("new_membership",false) else "completed_granted_activation"}}]

## One actual cone owns all independently disclosed recipient colour choices.
## Save/result ancestry is retained without solving the seven colour rules.
static func _prismatic(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var fact:Dictionary=node.fact
    if node.get("canceled",false) or node.get("phase")!="completion" or fact.get("behavior_id")!=descriptor.get("behavior_id") \
            or not key(node).is_empty() or fact.get("source_entity_uuid")==null:return []
    var source:String=str(fact.source_entity_uuid)
    var outcomes:Array=[];var bindings:Dictionary={};var endpoints:Array=[];var evidence:Array=[]
    for application in graph.get("nodes",{}).values():
        var resolution:Dictionary=application.get("resolution_record",{})
        var applied:Variant=application.get("fact")
        if application.get("canceled",false) or application.get("phase")!="completion" or applied==null \
                or applied.kind!="spell" or resolution.get("application_id")==null \
                or str(resolution.get("lineage"))!=str(node.lineage_id) or applied.get("target_entity_uuid")==null:continue
        var colors:Array=applied.get("prismatic_colors",[])
        var roll:Variant=applied.get("prismatic_roll")
        if colors.is_empty() or colors.size()>2 or roll==null:continue
        if int(roll)==8 and colors.size()!=2 or int(roll)!=8 and colors!=[int(roll)]:continue
        if colors.any(func(color):return int(color)<1 or int(color)>7) or colors.size()==2 and colors[0]==colors[1]:continue
        var target:String=str(applied.target_entity_uuid)
        if bindings.has(target):continue
        var endpoint:int=int(descriptor.recipient_endpoint_start)+endpoints.size()
        bindings[target]=endpoint;endpoints.append({"actor":"recipient_"+str(endpoint),"socket":str(descriptor.recipient_socket),"actor_uuid":target})
        var saves:Array=[]
        for save in graph.get("nodes",{}).values():
            var save_fact:Variant=save.get("fact")
            if save.get("canceled",false) or save.get("phase")!="completion" or save_fact==null \
                    or save_fact.kind!="saving_throw" or save_fact.get("target_entity_uuid")!=target \
                    or not _cast_owns_result(application,save,graph):continue
            for color in colors:
                if save_fact.get("effect_id")==str(descriptor.save_effect_prefix)+str(color):
                    saves.append({"color":color,"occurrence":str(save.id),"lineage":str(save.lineage_id),"succeeded":save_fact.succeeded})
        outcomes.append({"recipient_uuid":target,"endpoint_index":endpoint,"colors":colors.duplicate(),
            "application_admitted":true,"at_seconds":float(descriptor.contact_seconds),"result":"actual_disclosed_application"})
        evidence.append({"application_occurrence":str(application.id),"application_lineage":str(application.lineage_id),
            "application_id":resolution.application_id,"recipient_uuid":target,"roll":roll,"colors":colors,"saves":saves})
    var values:Dictionary={"cast_uuid":str(node.id),"source_uuid":source,"recipient_capacity":outcomes.size(),
        "recipient_bindings":bindings,"cast_present":true,"supplied_outcomes":[],"observation_kind":"actual_public_application_colours"}
    return [{"node":node,"target_uuid":source,"values":values,"inputs":{},
        "input_values":{"cast_uuid":str(node.id),"source_uuid":source,"outcomes":outcomes,"present":true},
        "endpoint_bindings":endpoints,
        "evidence":{"cast_occurrence":str(node.id),"cast_lineage":str(node.lineage_id),"recipients":evidence}}]

## A grant is its actual recipient membership. A completed exhale names that
## retained member. Original caster is optional metadata for the selected
## exhale source: its geometry/admission consumes only the actual acting
## recipient/grant/element. No unknown original caster is substituted.
## An accepted action is an activity witness only at this finite occurrence.
static func _breath(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null or fact.get("kind")!="spell":return []
    var exhale:bool=descriptor.projection=="breath_exhale"
    if fact.get("behavior_id")!=descriptor.get("behavior_id"):return []
    var element:String=str(descriptor.element)
    var members:Array=[];var event:Dictionary=node;var recipient:String="";var caster:String=""
    if exhale:
        recipient=str(fact.source_entity_uuid)
        var actor:Dictionary=graph.get("actor_inputs",{}).get(str(node.id),{}).get(recipient,{})
        members=actor.get("conditions",[]).filter(func(member):return member.get("behavior_id")==descriptor.get("condition_id") and member.get("state")!=null and str(member.state.get("energy_type","")).to_lower()==element)
        var origins:Array=[]
        for row in graph.get("observed_results",{}).get(str(node.id),[]):
            if row.kind!="damage" or row.node.fact.get("source_entity_uuid")==null or str(row.node.fact.damage_type).to_lower()!=element or not _cast_owns_result(node,row.node,graph):continue
            var source:String=str(row.node.fact.source_entity_uuid)
            if source not in origins:origins.append(source)
        if origins.size()>1:return []
        # This source only compares the two original-caster metadata fields;
        # it neither asserts nor uses them in the exhale branch. Empty retains
        # actual non-disclosure when no positive result names the old caster.
        caster=str(origins[0]) if origins.size()==1 else ""
        if fact.get("area_geometry")==null or fact.area_geometry.get("shape")!="cone" or fact.area_geometry.get("origin")==null or fact.area_geometry.get("direction")==null:return []
    else:
        caster=str(fact.source_entity_uuid)
        var rows:Array=graph.get("observed_results",{}).get(str(node.id),[]).filter(func(row):return row.kind=="condition_application" and row.condition.get("behavior_id")==descriptor.get("condition_id") and row.condition.get("state")!=null and str(row.condition.state.get("energy_type","")).to_lower()==element and _cast_owns_result(node,row.node,graph))
        if rows.size()!=1:return []
        members=[rows[0].condition];recipient=rows[0].target_uuid;event=rows[0].node
    if members.size()!=1:return []
    var member:Dictionary=members[0]
    if str(member.get("condition_uuid","")).is_empty():return []
    var suppressed:bool=not member.state.get("suppression_provider_uuids",[]).is_empty()
    if suppressed:return []
    var packet:Dictionary={"grant_uuid":str(member.condition_uuid),"recipient_uuid":recipient,"original_caster_uuid":caster,
        "element":element,"present":true,"observed":true,"contributions_active":true,"suppressed":false}
    if exhale:packet.recipient_action_discovered=true
    var values:Dictionary={"grant_uuid":str(member.condition_uuid),"recipient_uuid":recipient,"original_caster_uuid":caster,
        "element":element,"state":{},"acting_recipient_uuid":recipient if exhale else ""}
    var row:Dictionary={"node":event,"target_uuid":recipient,"values":values,"inputs":{"grant_state":packet},
        "evidence":{"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),"grant_uuid":str(member.condition_uuid),
            "recipient_uuid":recipient,"original_caster_uuid":caster,"original_caster_disclosed":not caster.is_empty(),
            "original_caster_operand":"actual_result_source" if exhale and not caster.is_empty() else "actual_grant_cast" if not exhale else "not_consumed_by_selected_exhale_source",
            "element":element,"publication_occurrence":str(event.id),
            "admission":"completed_granted_exhale" if exhale else "actual_recipient_condition_application"}}
    if exhale:
        var origin:Array=fact.area_geometry.origin;var direction:Array=fact.area_geometry.direction
        row.origin_position=origin;row.destination_position=[origin[0]+direction[0],origin[1]+direction[1]]
        row.origin_elevation_feet=graph.get("contacts",{}).get(recipient,{}).get("from_elevation_feet",0.0)
    return [row]

## Component amounts are attribution before packet-wide reductions. They never
## allocate HP: require this exact enclosing positive applied packet as well.
static func _weapon_component(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null or fact.get("kind")!="attack" \
        or fact.get("attack_source_kind")!="equipped" or fact.get("attack_outcome") not in ["Hit","Crit"] \
        or fact.get("source_item_uuid")==null or fact.get("source_entity_uuid")==null or fact.get("target_entity_uuid")==null \
        or fact.get("weapon_slot") not in ["MELEE_MAIN","MELEE_OFF","RANGED_MAIN","RANGED_OFF"]:return []
    if str(descriptor.get("damage_type","")).is_empty() and descriptor.get("damage_type_policy")!="actual_component":return []
    var predicate:Dictionary=descriptor.get("recipient_condition",{})
    if not predicate.is_empty():
        var recipient:Dictionary=graph.get("actor_inputs",{}).get(str(node.id),{}).get(str(fact.target_entity_uuid),{})
        if not recipient.has("conditions"):return []
        var members:Array=recipient.conditions.filter(func(member):return Catalog.condition_key(member)==predicate.get("condition_key"))
        if (not members.is_empty())!=predicate.get("present"):return []
        if members.any(func(member):return member.get("state")!=null and not member.state.get("suppression_provider_uuids",[]).is_empty()):return []
    var result:Array=[];var identities:Array=[]
    for row in graph.get("observed_results",{}).get(str(node.id),[]):
        if row.kind!="damage" or int(row.node.fact.get("applied_damage",0))<=0 or row.target_uuid!=str(fact.target_entity_uuid) \
            or not _cast_owns_result(node,row.node,graph):continue
        for part in row.node.fact.get("components",[]):
            if part.get("source_id") not in descriptor.damage_source_ids or part.get("source_entity_uuid")!=fact.source_entity_uuid \
                or descriptor.has("damage_type") and part.get("damage_type")!=descriptor.damage_type or int(part.get("after_affinity_damage",0))<=0 \
                or part.get("source_damage_uuid")==null:continue
            var identity:String=str(part.source_damage_uuid)
            if identity.is_empty() or identity in identities:return []
            identities.append(identity)
            var strike:Dictionary={"source_actor_uuid":str(fact.source_entity_uuid),"recipient_uuid":str(fact.target_entity_uuid),
                "item_uuid":str(fact.source_item_uuid),"equipment_slot":str(fact.weapon_slot),"attack_uuid":str(node.id),
                "behavior_id":str(fact.behavior_id),"source_kind":"equipped","attack_kind":"weapon",
                "outcome":"critical" if fact.attack_outcome=="Crit" else "hit","payload_applied":true,
                "rider_component_applied":true,"damage_component_uuid":identity}
            var values:Dictionary={"source_actor_uuid":strike.source_actor_uuid,"recipient_uuid":strike.recipient_uuid,
                "item_uuid":strike.item_uuid,"equipment_slot":strike.equipment_slot,"attack_uuid":strike.attack_uuid,
                "behavior_id":strike.behavior_id,"strike":{},"condition":{},"tick":{},"owner":{},"healing":{}}
            if descriptor.has("handler_behavior_id"):
                var handlers:Array=[]
                for owner in graph.get("nodes",{}).values():
                    if not _cast_owns_result(node,owner,graph):continue
                    for attribution in owner.get("content_attributions",[]):
                        if attribution.get("role")=="effective_handler" and attribution.get("behavior_id")==descriptor.handler_behavior_id \
                            and attribution.get("source_entity_uuid")==fact.source_entity_uuid and attribution.get("dispatch_index")!=null:
                            handlers.append({"node":owner,"attribution":attribution})
                if handlers.size()!=1:continue
                var handler:Dictionary=handlers[0]
                # Opaque native occurrence/dispatch key, not a wire handler UUID.
                var handler_key:String=str(handler.node.id)+":"+str(handler.attribution.dispatch_index)
                values.effective_handler_uuid=handler_key;strike.effective_handler_uuid=handler_key
                values.behavior_id=handler.attribution.behavior_id;strike.behavior_id=handler.attribution.behavior_id
            var inputs:Dictionary={"strike_input":strike}
            var observed:Dictionary={"node":row.node,"target_uuid":strike.recipient_uuid,"values":values,"inputs":inputs,
                "weapon_result_item_uuid":str(fact.source_item_uuid),
                "evidence":{"attack_occurrence":str(node.id),"attack_lineage":str(node.lineage_id),"result_occurrence":str(row.node.id),
                    "result_lineage":str(row.node.lineage_id),"source_damage_uuid":identity,"source_id":part.source_id,
                    "damage_type":part.damage_type,"after_affinity_damage":part.after_affinity_damage,
                    "packet_applied_damage":row.node.fact.applied_damage,"amount_scope":"component_before_packet_reductions"}}
            if descriptor.get("packet")=="event":
                var source:String=str(fact.source_entity_uuid);var target:String=str(fact.target_entity_uuid)
                var event:Dictionary={"uuid":str(row.node.id),"source_entity_uuid":source,"target_entity_uuid":target,
                    "canceled":false,"effect_admitted":true,"actual_damage":row.node.fact.applied_damage,
                    "damage_component_uuid":identity,"damage_type":part.damage_type}
                observed.values={"source_entity_uuid":source,"recipient_entity_uuid":target,"owner_uuid":str(node.id),
                    "event_uuid":str(row.node.id),"actor_roles":{"caster":source,"target":target},"geometry_actor":target,
                    "lease":{},"event":{},"plan_only":false,"native_behavior_id":str(part.source_id)}
                observed.inputs={"lease_input":{},"event_input":event}
                observed.evidence.damage_component_identity="actual_source_damage_uuid"
                result.append(observed);continue
            var owner_id:String=str(descriptor.get("owner_condition_id",""))
            if descriptor.has("quarry_kind"):
                var actors:Dictionary=graph.get("actor_inputs",{}).get(str(node.id),{})
                var sustain_id:String=str(descriptor.owner_condition_id)
                var recipient_id:String=str(descriptor.recipient_condition_id)
                var owners:Array=actors.get(str(fact.source_entity_uuid),{}).get("conditions",[]).filter(func(member):return member.get("behavior_id")==sustain_id)
                var children:Array=actors.get(str(fact.target_entity_uuid),{}).get("conditions",[]).filter(func(member):return member.get("behavior_id")==recipient_id)
                if owners.size()!=1 or children.size()!=1:continue
                var pair:Dictionary={"ready":true,"quarry_kind":descriptor.quarry_kind,"owner_id":sustain_id,"recipient_id":recipient_id,
                    "identity":{"caster_uuid":str(fact.source_entity_uuid),"recipient_uuid":str(fact.target_entity_uuid),
                        "sustain_condition_uuid":str(owners[0].condition_uuid),"recipient_condition_uuid":str(children[0].condition_uuid)}}
                var packets:Dictionary=Creation.quarry_state(pair,{"actors":actors})
                if not packets.quarry.observed or not packets.owner.contribution_active or not packets.quarry.condition.contribution_active:continue
                values.merge({"owner_uuid":str(owners[0].condition_uuid),"owner_id":sustain_id,"condition_uuid":str(children[0].condition_uuid),
                    "condition_id":recipient_id,"quarry_state":{},"lifecycle_mode":"owned_state"},true)
                strike.sustain_uuid=str(owners[0].condition_uuid);strike.quarry_condition_uuid=str(children[0].condition_uuid)
                strike.rider_applied=true;strike.damage_fact_uuid=str(row.node.id);strike.attack_roll_observed=true
                inputs.owner_input=packets.owner;inputs.quarry_input=packets.quarry
                inputs.hit_input=strike;inputs.erase("strike_input")
                observed.evidence.sustain_uuid=str(owners[0].condition_uuid);observed.evidence.quarry_condition_uuid=str(children[0].condition_uuid)
            if not owner_id.is_empty() and not descriptor.has("quarry_kind"):
                var actor:Dictionary=graph.get("actor_inputs",{}).get(str(node.id),{}).get(str(fact.source_entity_uuid),{})
                var members:Array=actor.get("conditions",[]).filter(func(member):return member.get("behavior_id")==owner_id)
                if members.size()!=1:continue
                var member:Dictionary=members[0];var state:Dictionary=member.state if member.get("state")!=null else {}
                if not state.get("suppression_provider_uuids",[]).is_empty():continue
                observed.condition=member
                values.ownership={"owner_kind":"caster","owner_uuid":strike.source_actor_uuid,"effect_uuid":str(member.condition_uuid),"binding":{}}
                values.hit={};strike.owner_uuid=strike.source_actor_uuid;strike.effect_uuid=str(member.condition_uuid)
                inputs.erase("strike_input");inputs.hit_input=strike
                inputs.weapon_binding={"item_uuid":strike.item_uuid,"contribution_active":true,"decoration_admitted":true,"suppressed":false}
                observed.evidence.condition_uuid=str(member.condition_uuid)
            result.append(observed)
    return result

## An autonomous source executes this actual attack attempt. Its original
## source owns the stroke clock; only real outcomes admit contact artwork.
static func _attack_attempt(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null or fact.get("kind")!="attack" \
        or fact.get("behavior_id")!=descriptor.get("behavior_id") or fact.get("source_entity_uuid")==null \
        or fact.get("target_entity_uuid")==null or fact.get("attack_outcome") not in ["Hit","Crit","Miss","Crit Miss"] \
        or fact.get("weapon_slot") not in descriptor.get("weapon_slots",[]) \
        or fact.get("attack_source_kind") not in descriptor.get("source_kinds",[]):return []
    var source:String=str(fact.source_entity_uuid);var target:String=str(fact.target_entity_uuid)
    var actor:Dictionary=graph.get("actor_inputs",{}).get(str(node.id),{}).get(source,{})
    var creature:String=Characters.content_id(actor.get("creature_content_ref"))
    if actor.get("uuid")!=source or creature not in descriptor.get("source_creature_ids",[]):return []
    var contacts:Dictionary=graph.get("condition_response_inputs",{}).get(str(node.id),{})
    if not contacts.has(source) or not contacts.has(target):return []
    var origin:Dictionary=contacts[source];var destination:Dictionary=contacts[target]
    var state:Dictionary={"owner_uuid":source,"present":true,"observed":true,"suppressed":false}
    var contact:bool=fact.attack_outcome in ["Hit","Crit"]
    return [{"node":node,"target_uuid":target,"origin_position":origin.position,"destination_position":destination.position,
        "origin_elevation_feet":float(origin.elevation_steps)*5.0,"destination_elevation_feet":float(destination.elevation_steps)*5.0,
        "values":{"owner_uuid":source,"state":state,"review_owner_states":[],"contact_enabled":contact},
        "inputs":{"owner_state":state},"evidence":{"attack_occurrence":str(node.id),"attack_lineage":str(node.lineage_id),
            "source_actor_uuid":source,"recipient_uuid":target,"source_creature_id":creature,
            "weapon_slot":str(fact.weapon_slot),"attack_source_kind":str(fact.attack_source_kind),
            "attack_outcome":str(fact.attack_outcome),"contact_enabled":contact,"source_cut":"source_actor_before_row"}}]

static func _quarry_application(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var pair:Dictionary=Creation.quarry_binding(node,graph,descriptor)
    if not pair.get("ready",false) or pair.quarry_kind!=descriptor.get("quarry_kind"):return []
    var rows:Array=graph.get("observed_results",{}).get(str(node.id),[]).filter(func(row):return row.kind=="condition_application" and str(row.condition.condition_uuid) in [str(pair.identity.sustain_condition_uuid),str(pair.identity.recipient_condition_uuid)])
    var retained:bool=pair.has("retained_owner_member")
    if rows.size()!=(1 if retained else 2):return []
    var actors:Dictionary={}
    if retained:actors[str(pair.identity.caster_uuid)]={"conditions":[pair.retained_owner_member]}
    for row in rows:
        if not actors.has(row.target_uuid):actors[row.target_uuid]={"conditions":[]}
        actors[row.target_uuid].conditions.append(row.condition)
    var packet:Dictionary=Creation.quarry_state(pair,{"actors":actors})
    if not packet.owner.observed or not packet.quarry.observed:return []
    var event:Dictionary=rows[-1].node
    var id:Dictionary=pair.identity
    return [{"node":event,"target_uuid":str(id.recipient_uuid),"native_quarry":true,"creation_binding":pair,
        "publication_occurrences":[str(pair.owner_observation_occurrence)] if retained else [],
        "values":{"source_actor_uuid":str(id.caster_uuid),"recipient_uuid":str(id.recipient_uuid),
            "owner_uuid":str(id.sustain_condition_uuid),"owner_id":str(pair.owner_id),"condition_uuid":str(id.recipient_condition_uuid),
            "condition_id":str(pair.recipient_id),"owner":{},"condition":{},"quarry_state":{},"strike":{},"tick":{},"healing":{},
            "item_uuid":"","attack_uuid":"","lifecycle_mode":"owned_state"},
        "inputs":{"owner_input":packet.owner,"quarry_input":packet.quarry},"evidence":pair.evidence}]

## This selected source phase is Freezing Sphere's immediate native explosion.
## Its resolved cells plus the actual direct AoE declaration distinguish it
## from a held-item detonation; no radius or target search reconstructs them.
static func _immediate_blast(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null \
        or fact.kind!="spell" or fact.get("behavior_id")!=descriptor.get("behavior_id") \
        or fact.get("source_entity_uuid")==null \
        or fact.get("resolved_area_positions",[]).is_empty():return []
    var launch:Dictionary={}
    var parent:Variant=node.get("parent_lineage")
    while parent!=null:
        var ancestor:Dictionary=graph.nodes.get(str(parent),{})
        if ancestor.is_empty() or ancestor.get("canceled",false):return []
        var source:Variant=ancestor.get("fact")
        if source!=null and source.kind in ["spell","action","attack"]:
            if source.kind!="spell" or source.get("behavior_id")!=fact.behavior_id \
                or source.get("source_entity_uuid")!=fact.source_entity_uuid or source.get("aoe_position")==null \
                or ancestor.get("phase")!="completion":return []
            launch=ancestor;break
        parent=ancestor.get("parent_lineage")
    if launch.is_empty():return []
    var origin:Array=launch.fact.aoe_position
    if fact.get("source_position")!=null and fact.source_position!=origin:return []
    var support:Dictionary=graph.get("area_contacts",{}).get(str(launch.id),{})
    if support.get("position")!=origin or not support.has("elevation_steps"):return []
    var origin_occurrence:String=str(node.id) if fact.get("source_position")!=null else str(launch.id)
    var cells:Array=[]
    for cell in fact.resolved_area_positions:
        cells.append([int(cell[0])-int(origin[0]),int(cell[1])-int(origin[1])])
    var packet:Dictionary={"kind":str(descriptor.payload_kind),"source_owner_uuid":str(node.id),
        "original_caster_uuid":str(fact.source_entity_uuid),"event_uuid":str(node.id),
        "observed":true,"blast_committed":true,"immediate_launch":true,"admitted_cells":cells}
    return [{"node":node,"target_uuid":str(fact.source_entity_uuid),"origin_position":origin,
        "origin_elevation_feet":float(support.elevation_steps)*5.0,
        "values":{"kind":str(descriptor.payload_kind),"source_owner_uuid":str(node.id),"original_caster_uuid":str(fact.source_entity_uuid),
            "admitted_cells":cells,"immediate_launch":true,"event":{},"item_uuid":"","lifetime_uuid":""},
        "inputs":{"blast_event":packet},"event":packet,
        "evidence":{"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),
            "source_uuid":str(fact.source_entity_uuid),"source_position":origin,"origin_occurrence":origin_occurrence,
            "direct_launch_occurrence":str(launch.id),"direct_launch_lineage":str(launch.lineage_id),
            "resolved_area_positions":fact.resolved_area_positions,"source_relative_cells":cells,
            "admission":"completed_native_immediate_explosion"}}]

## Vitriolic's completed direct cast now discloses its actual resolved cells.
## The public ground aim owns the origin; the caster position never replaces it.
static func _accepted_area_blast(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null or fact.get("kind")!="spell" \
        or fact.get("behavior_id")!=descriptor.get("behavior_id") or fact.get("source_entity_uuid")==null \
        or fact.get("aoe_position")==null or fact.get("resolved_area_positions",[]).is_empty() \
        or node.get("resolution_record",{}).get("application_id")!=null:return []
    var geometry:Dictionary=fact.area_geometry if fact.get("area_geometry")!=null else {}
    if geometry.get("shape")!=descriptor.get("area_shape") or geometry.get("center")!=fact.aoe_position:return []
    var origin:Array=fact.aoe_position;var cells:Array=[]
    var support:Dictionary=graph.get("area_contacts",{}).get(str(node.id),{})
    if support.get("position")!=origin or not support.has("elevation_steps"):return []
    for cell in fact.resolved_area_positions:cells.append([int(cell[0])-int(origin[0]),int(cell[1])-int(origin[1])])
    var values:Dictionary={"kind":str(descriptor.payload_kind),"source_owner_uuid":str(node.id),"original_caster_uuid":str(fact.source_entity_uuid),
        "admitted_cells":cells,"event":{}}
    var packet:Dictionary=values.duplicate();packet.erase("event")
    packet.merge({"event_uuid":str(node.id),"observed":true,"blast_committed":true})
    return [{"node":node,"target_uuid":str(fact.source_entity_uuid),"origin_position":origin,
        "origin_elevation_feet":float(support.elevation_steps)*5.0,"values":values,"inputs":{"blast_event":packet},
        "evidence":{"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),"source_uuid":str(fact.source_entity_uuid),
            "source_position":origin,"resolved_area_positions":fact.resolved_area_positions,"source_relative_cells":cells,
            "admission":"completed_direct_cast_resolved_footprint"}}]

## Public finite explosions carry their own completed occurrence and linked
## native ancestry. A private item/lifetime never becomes a public operand.
## The selected source independently checks this same unchanged packet.
static func _portable_blast(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null or fact.get("kind")!="action" \
        or fact.get("behavior_id")!=descriptor.get("behavior_id") or fact.get("source_entity_uuid")==null \
        or fact.get("target_position")==null:return []
    var explosions:Array=[]
    for candidate in graph.get("nodes",{}).values():
        var actual:Variant=candidate.get("fact")
        if candidate.get("canceled",false) or candidate.get("phase")!="completion" or actual==null \
            or actual.get("kind")!="spell" or actual.get("behavior_id")!=descriptor.get("explosion_behavior_id") \
            or actual.get("source_entity_uuid")==null or actual.get("aoe_position")!=fact.target_position \
            or actual.get("source_position")!=null and actual.source_position!=actual.aoe_position \
            or actual.get("resolved_area_positions",[]).is_empty() \
            or actual.get("area_propagation")!=descriptor.get("area_propagation"):continue
        var geometry:Dictionary=actual.area_geometry if actual.get("area_geometry")!=null else {}
        if geometry.get("shape")!=descriptor.get("area_shape") or geometry.get("center")!=actual.aoe_position:continue
        var ancestors:Array=[];var child:Dictionary=candidate;var parent:Variant=candidate.get("parent_lineage")
        var seen:Dictionary={str(candidate.lineage_id):true};var accepted:bool=false
        while parent!=null:
            var ancestor:Dictionary=graph.get("nodes",{}).get(str(parent),{})
            if ancestor.is_empty() or ancestor.get("canceled",false) or ancestor.get("phase")!="completion" \
                or ancestor.get("fact")==null or seen.has(str(ancestor.lineage_id)) \
                or str(child.lineage_id) not in ancestor.get("children_lineages",[]):break
            seen[str(ancestor.lineage_id)]=true;ancestors.append(ancestor)
            if str(ancestor.lineage_id)==str(node.lineage_id):accepted=true;break
            if ancestor.fact.get("kind") in ["action","spell","attack"]:break
            child=ancestor;parent=ancestor.get("parent_lineage")
        if accepted:explosions.append({"node":candidate,"ancestors":ancestors})
    if explosions.size()!=1:return []
    var explosion:Dictionary=explosions[0].node
    var origin:Array=explosion.fact.aoe_position
    var support:Dictionary=graph.get("target_contacts",{}).get(str(node.id),{})
    if support.is_empty() or support.get("position")!=origin or not support.has("elevation_steps"):return []
    var caster:String=str(explosion.fact.source_entity_uuid)
    var values:Dictionary={"kind":str(descriptor.payload_kind),"source_owner_uuid":str(explosion.id),"original_caster_uuid":caster}
    return [{"node":explosion,"target_uuid":caster,"origin_position":origin,"origin_elevation_feet":float(support.elevation_steps)*5.0,
        "values":values,"inputs":{"observed_explosion":{"explosion":explosion,"ancestors":explosions[0].ancestors}},
        "evidence":{"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),
            "explosion_occurrence":str(explosion.id),"explosion_lineage":str(explosion.lineage_id),
            "throw_actor_uuid":str(fact.source_entity_uuid),"original_caster_uuid":caster,
            "source_position":origin,"resolved_area_positions":explosion.fact.resolved_area_positions,
            "ancestry_occurrences":explosions[0].ancestors.map(func(ancestor):return str(ancestor.id)),
            "admission":"actual_public_explosion_and_completed_throw_ancestry","requires_private_inventory_identity":false}}]

## The exact lifetime removal owns both native retirement and its explosion.
## A discarded object, unrelated removal or accepted action alone cannot admit
## a blast. The canonical object was disclosed before this lineage began.
static func _retired_payload_blast(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null \
        or fact.kind!="spell" or fact.get("behavior_id")!=descriptor.get("behavior_id") \
        or fact.get("source_entity_uuid")==null or fact.get("resolved_area_positions",[]).is_empty():return []
    var caster:String=str(fact.source_entity_uuid)
    var removed:Dictionary={};var lifetime:Dictionary={};var action:Dictionary={}
    var parent:Variant=node.get("parent_lineage")
    while parent!=null:
        var ancestor:Dictionary=graph.nodes.get(str(parent),{})
        if ancestor.is_empty() or ancestor.get("canceled",false):return []
        var owners:Array=graph.get("condition_cues",{}).get(str(ancestor.id),[]).filter(func(cue):
            return cue.phase=="removal" and str(cue.actor_uuid)==caster \
                and cue.condition.get("behavior_id")==descriptor.get("lifetime_condition_id"))
        if owners.size()>1:return []
        if owners.size()==1:
            if not removed.is_empty():return []
            removed=ancestor;lifetime=owners[0].condition
        var source:Variant=ancestor.get("fact")
        if source!=null and source.kind in ["spell","action","attack"]:
            if removed.is_empty() or source.kind!="action" or source.get("behavior_id")!=descriptor.get("behavior_id") \
                or source.get("source_entity_uuid")!=caster or ancestor.get("phase")!="completion":return []
            action=ancestor;break
        parent=ancestor.get("parent_lineage")
    if action.is_empty():return []
    var saves:Array=[]
    for scope in graph.get("application_results",{}).values():
        for save in scope.saves:
            if str(save.owner_occurrence)==str(node.id) and save.fact.get("effect_id")==descriptor.save_effect_id:saves.append(save)
    if saves.is_empty():return []
    var retirements:Array=[]
    for candidate in graph.nodes.values():
        var spatial:Variant=candidate.get("fact")
        if candidate.get("canceled",false) or candidate.get("phase")!="completion" or spatial==null \
            or spatial.kind!="spatial" or spatial.get("change_type")!="object_removed" \
            or spatial.get("object_uuid")==null or not _cast_owns_result(removed,candidate,graph):continue
        var object:Dictionary=graph.get("object_inputs",{}).get(str(candidate.id),{})
        if object.get("item",{}).get("item_id")!=descriptor.item_id \
            or object.get("placement",{}).get("position")!=spatial.get("position"):continue
        retirements.append({"node":candidate,"object":object})
    if retirements.size()!=1:return []
    var retired:Dictionary=retirements[0];var origin:Array=retired.object.placement.position
    if fact.get("source_position")!=null and fact.source_position!=origin:return []
    var cells:Array=[]
    for cell in fact.resolved_area_positions:cells.append([int(cell[0])-int(origin[0]),int(cell[1])-int(origin[1])])
    var identity:String=str(lifetime.condition_uuid)
    var item:String=str(retired.node.fact.object_uuid)
    var values:Dictionary={"kind":str(descriptor.payload_kind),"source_owner_uuid":identity,"original_caster_uuid":caster,
        "item_uuid":item,"lifetime_uuid":identity,"admitted_cells":cells,"immediate_launch":false,"event":{}}
    var packet:Dictionary=values.duplicate();packet.erase("event")
    packet.merge({"event_uuid":str(node.id),"observed":true,"blast_committed":true,
        "item_retirement_committed":true,"lifetime_removal_committed":true})
    var elevation:float=float(retired.object.placement.base_height_steps)*5.0
    return [{"node":node,"target_uuid":caster,"origin_position":origin,"origin_elevation_feet":elevation,
        "values":values,"inputs":{"blast_event":packet},"event":packet,
        "evidence":{"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),"source_uuid":caster,
            "source_position":origin,"origin_occurrence":str(retired.node.id),"origin_cut":"canonical_object_before_lineage",
            "item_uuid":item,"item_id":str(descriptor.item_id),"lifetime_uuid":identity,
            "lifetime_removal_occurrence":str(removed.id),"lifetime_removal_lineage":str(removed.lineage_id),
            "item_removal_occurrence":str(retired.node.id),"item_removal_lineage":str(retired.node.lineage_id),
            "accepted_action_occurrence":str(action.id),"accepted_action_lineage":str(action.lineage_id),
            "resolved_area_positions":fact.resolved_area_positions,"source_relative_cells":cells,
            "admission":"native_explosion_owned_by_exact_payload_retirement"}}]

## Retained-payload and granted-action receiver programs consume an actual
## finite result owner, not a guessed grant/lifetime. Their exact native save
## effect establishes which result family fired. The original caster remains
## the damage source even when another actor performs the granted action.
static func _finite_contact(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null \
        or fact.kind not in ["spell","action"] or fact.get("source_entity_uuid")==null:return []
    if descriptor.has("accepted_behavior_id") and fact.get("behavior_id")!=descriptor.accepted_behavior_id:return []
    var result:Array=[]
    for row in graph.get("observed_results",{}).get(str(node.id),[]):
        if row.kind!="damage" or row.node.get("phase")!="completion" or row.node.fact.damage_type!=descriptor.damage_type \
            or row.node.fact.get("source_entity_uuid")==null or not _cast_owns_result(node,row.node,graph):continue
        var saves:Array=[]
        for scope in graph.get("application_results",{}).values():
            for save in scope.saves:
                if save.fact.get("target_entity_uuid")!=row.target_uuid or save.fact.get("effect_id")!=descriptor.save_effect_id \
                    or descriptor.has("save_ability") and save.fact.get("ability_name")!=descriptor.save_ability:continue
                var owner:Dictionary=graph.nodes.get(str(save.owner_lineage),{})
                if str(save.owner_occurrence)==str(node.id) or not owner.is_empty() and _cast_owns_result(node,owner,graph):saves.append(save)
        if saves.size()!=1 or saves[0].fact.get("succeeded")==null:continue
        var caster:String=str(row.node.fact.source_entity_uuid)
        if not descriptor.get("retained_caster",false) and caster!=str(fact.source_entity_uuid):continue
        var packet:Dictionary={"source_owner_uuid":str(node.id),"recipient_uuid":str(row.target_uuid),
            "event_uuid":str(row.node.id),"damage_applied":true,"saved":saves[0].fact.succeeded}
        var values:Dictionary={"source_owner_uuid":str(node.id),"recipient_uuid":str(row.target_uuid),"event":{}}
        if descriptor.has("payload_kind"):
            packet.kind=str(descriptor.payload_kind);packet.original_caster_uuid=caster
            values.kind=packet.kind;values.original_caster_uuid=caster
        else:
            packet.element=str(descriptor.damage_type).to_lower();values.element=packet.element
        var inputs:Dictionary={"damage_event":packet}
        if descriptor.get("packet")=="electric_network":
            # Source contacts receive only this exact saved/applied recipient.
            # No extra storm endpoints or repeated gameplay results are made.
            values={"edges":[],"endpoint_count":1,"contact_schedule":[{"endpoint":0,"at":0.0}],
                "charge_coil":false,"contact_from_edges":false}
            inputs={"link_edges":[]}
        result.append({"node":row.node,"target_uuid":str(row.target_uuid),"values":values,
            "event":packet,"inputs":inputs,
            "evidence":{"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),
                "result_occurrence":str(row.node.id),"result_lineage":str(row.node.lineage_id),
                "source_uuid":str(fact.source_entity_uuid),"damage_source_uuid":caster,"target_uuid":str(row.target_uuid),
                "damage_type":row.node.fact.damage_type,"applied_damage":row.node.fact.applied_damage,
                "save_occurrence":saves[0].occurrence,"save_lineage":saves[0].lineage,
                "save_effect_id":saves[0].fact.effect_id,"saved":saves[0].fact.succeeded,
                "source_owner_identity":"native_finite_result_owner_occurrence"}})
    return result

## The resource maps actual owned child memberships/death to the source's
## finite outcome. Held conditions retain their own ordinary UUID lifecycles.
static func _condition_set_outcome(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null \
        or fact.kind!="spell" or fact.get("behavior_id")!=descriptor.get("behavior_id") \
        or fact.get("source_entity_uuid")==null or fact.get("target_entity_uuid")==null:return []
    var target:String=str(fact.target_entity_uuid)
    var conditions:Dictionary={};var observed:Dictionary={};var death:bool=false
    var condition_results:Array=[]
    for row in graph.get("observed_results",{}).get(str(node.id),[]):
        if row.target_uuid!=target or not _cast_owns_result(node,row.node,graph):continue
        if row.kind=="death":death=true;observed=row
        elif row.kind=="condition_application":
            conditions[str(row.condition.behavior_id)]=str(row.condition.condition_uuid)
            condition_results.append(row)
    var outcome:String=""
    for branch in descriptor.get("outcome_branches",[]):
        var required:Array=branch.get("condition_ids",[])
        if branch.get("result_kind")=="death" and death \
            or not death and not required.is_empty() and conditions.has_all(required):
            outcome=str(branch.outcome)
            if not death:
                for row in condition_results:
                    if row.condition.behavior_id in required:observed=row
            break
    if outcome.is_empty():return []
    var identity:Dictionary={"event_uuid":str(observed.node.id),"cast_uuid":str(node.id),
        "source_entity_uuid":str(fact.source_entity_uuid),"target_entity_uuid":target}
    var observation:Dictionary=identity.merged({"phase":"effect","admitted":true,"canceled":false,"affected":true,"outcome":outcome})
    return [{"node":observed.node,"target_uuid":target,"values":{"owner":identity.merged({"owner_uuid":str(node.id),"condition_uuid":"","condition_id":""}),
        "observation":{},"review_observations":[]},"inputs":{"observation":observation},"event":observation,
        "evidence":{"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),
            "result_occurrence":str(observed.node.id),"result_lineage":str(observed.node.lineage_id),
            "target_uuid":target,"outcome":outcome,"condition_uuids":conditions,"death_observed":death}}]

## A delayed condition packet requires its disclosed source-condition UUID
## and the actual recipient END ancestry. Another residue on the same actor,
## a nearby removal, or a counted turn can never supply that causal identity.
static func condition_contact(node:Dictionary,member:Dictionary,descriptor:Dictionary,graph:Dictionary)->Dictionary:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null \
        or fact.kind!="damage" or fact.get("stage")!="applied" or int(fact.get("applied_damage",0))<=0 \
        or fact.get("source_condition_uuid")!=member.get("condition_uuid") \
        or fact.get("damage_type")!=descriptor.damage_type or member.get("behavior_id")!=descriptor.condition_id \
        or fact.get("source_entity_uuid")==null:return {}
    var end:Dictionary={};var parent:Variant=node.get("parent_lineage")
    while parent!=null:
        var ancestor:Dictionary=graph.nodes.get(str(parent),{})
        if ancestor.is_empty() or ancestor.get("canceled",false):return {}
        var actual:Variant=ancestor.get("fact")
        if actual!=null:
            if actual.kind in ["spell","action","attack"]:return {}
            if actual.kind=="turn" and actual.get("event_type")==descriptor.get("turn_event_type","turn_end") and actual.get("entity_uuid")==fact.target_entity_uuid:
                end=ancestor;break
        parent=ancestor.get("parent_lineage")
    if end.is_empty():return {}
    if descriptor.get("packet_kind")=="condition_tick":
        var state:Variant=member.get("state")
        if state!=null and not state.get("suppression_provider_uuids",[]).is_empty():return {}
        # This is an event-local activity witness: the actual applied packet
        # names the exact member observed before its native turn boundary.
        # No idle contribution, timer, future tick or old strike is invented.
        var condition:Dictionary={"condition_uuid":str(member.condition_uuid),"condition_id":str(member.behavior_id),
            "source_actor_uuid":str(fact.source_entity_uuid),"recipient_uuid":str(fact.target_entity_uuid),
            "present":true,"observed":true,"contribution_active":true,"suppressed":false}
        var tick:Dictionary={"condition_uuid":str(member.condition_uuid),"recipient_uuid":str(fact.target_entity_uuid),
            "damage_applied":true,"damage_type":str(fact.damage_type).to_lower(),"damage_fact_uuid":str(node.id)}
        var values:Dictionary={"source_actor_uuid":str(fact.source_entity_uuid),"recipient_uuid":str(fact.target_entity_uuid),
            "condition_uuid":str(member.condition_uuid),"condition_id":str(member.behavior_id),
            "condition":{},"tick":{},"strike":{},"owner":{},"healing":{},"item_uuid":"","attack_uuid":"",
            "activation_event_uuid":"","owner_uuid":"","owner_id":"","effective_handler_uuid":"","equipment_slot":"","render_slot":""}
        return {"values":values,"inputs":{"condition_input":condition,"tick_input":tick},
            "evidence":{"source_condition_uuid":str(member.condition_uuid),"condition_id":str(member.behavior_id),
                "result_occurrence":str(node.id),"result_lineage":str(node.lineage_id),"turn_occurrence":str(end.id),
                "turn_lineage":str(end.lineage_id),"original_caster_uuid":str(fact.source_entity_uuid),
                "target_uuid":str(fact.target_entity_uuid),"applied_damage":fact.applied_damage,"damage_type":fact.damage_type}}
    var packet:Dictionary={"source_owner_uuid":str(member.condition_uuid),"condition_uuid":str(member.condition_uuid),
        "condition_id":str(member.behavior_id),"recipient_uuid":str(fact.target_entity_uuid),
        "original_caster_uuid":str(fact.source_entity_uuid),"event_uuid":str(node.id),"damage_applied":true,
        "reason":"recipient_end_residue_packet"}
    return {"values":packet.merged({"state":{}}),"inputs":{"native_state":packet},
        "evidence":{"source_condition_uuid":str(member.condition_uuid),"condition_id":str(member.behavior_id),
            "result_occurrence":str(node.id),"result_lineage":str(node.lineage_id),"recipient_end_occurrence":str(end.id),
            "recipient_end_lineage":str(end.lineage_id),"original_caster_uuid":str(fact.source_entity_uuid),
            "target_uuid":str(fact.target_entity_uuid),"applied_damage":fact.applied_damage,"damage_type":fact.damage_type}}

## A real spatial member can own a finite recipient contact independently of
## its zone's visual hold. Its UUID, public element and applied damage must
## agree; no nearby field, alignment or caster class supplies those operands.
static func spatial_contact(node:Dictionary,identity:String,effect:Dictionary,descriptor:Dictionary,graph:Dictionary={})->Dictionary:
    var fact:Dictionary=node.fact
    var elemental:bool=descriptor.get("packet")=="element_contact"
    if node.get("canceled",false) or node.get("phase")!="completion" or fact.get("kind")!="damage" \
        or fact.get("stage")!="applied" or int(fact.get("applied_damage",0))<=0 \
        or fact.get("source_condition_uuid")==null or str(fact.source_condition_uuid)!=identity \
        or effect.get("content_ref",{}).get("content_id")!=descriptor.get("content_id") \
        or not elemental and effect.get("energy_type")!=descriptor.get("damage_type") \
        or fact.get("damage_type")!=descriptor.get("damage_type") \
        or fact.get("source_entity_uuid")==null or fact.get("target_entity_uuid")==null:return {}
    var evidence:Dictionary={"spatial_effect_uuid":identity,"content_id":str(descriptor.content_id),
        "result_occurrence":str(node.id),"result_lineage":str(node.lineage_id),
        "original_caster_uuid":str(fact.source_entity_uuid),"target_uuid":str(fact.target_entity_uuid),
        "applied_damage":fact.applied_damage,"damage_type":fact.damage_type}
    if not elemental:
        evidence.energy_type=effect.energy_type
        return {"values":{},"inputs":{},"evidence":evidence}
    var boundary:String=_spatial_result_boundary(node,graph)
    if boundary.is_empty():return {}
    var saves:Array=[]
    for scope in graph.get("application_results",{}).values():
        for save in scope.saves:
            if save.fact.get("target_entity_uuid")!=fact.target_entity_uuid or save.fact.get("effect_id")!=descriptor.get("save_effect_id"):continue
            var owner:Dictionary=graph.get("nodes",{}).get(str(save.lineage),{})
            if not owner.is_empty() and _spatial_result_boundary(owner,graph)==boundary:saves.append(save)
    if saves.size()!=1 or saves[0].fact.get("succeeded")==null:return {}
    var packet:Dictionary={"source_owner_uuid":identity,"recipient_uuid":str(fact.target_entity_uuid),
        "event_uuid":str(node.id),"element":str(fact.damage_type).to_lower(),"damage_applied":true,"saved":saves[0].fact.succeeded}
    evidence.merge({"save_occurrence":saves[0].occurrence,"save_lineage":saves[0].lineage,
        "save_effect_id":saves[0].fact.effect_id,"saved":saves[0].fact.succeeded,"native_emission_boundary":boundary,
        "selection_scope":"actual_typed_recipient_contact_not_glyph_payload"})
    return {"values":{"source_owner_uuid":identity,"recipient_uuid":str(fact.target_entity_uuid),
        "element":packet.element,"event":{}},"inputs":{"damage_event":packet},"evidence":evidence}

## The actual entry/cast owns both this save and damage. Another field's
## independent save under another native owner cannot tint this contact.
static func _spatial_result_boundary(node:Dictionary,graph:Dictionary)->String:
    var parent:Variant=node.get("parent_lineage")
    while parent!=null:
        var owner:Dictionary=graph.get("nodes",{}).get(str(parent),{})
        if owner.is_empty() or owner.get("canceled",false):return ""
        var fact:Variant=owner.get("fact")
        if fact!=null and (fact.get("kind") in ["spell","action","attack"] \
            or fact.get("kind")=="spatial" and fact.get("change_type")=="entity_entered"):return str(owner.lineage_id)
        parent=owner.get("parent_lineage")
    return ""

## An accepted action by an actual condition-owned source can retain its
## original caster on damage facts. Exact native ancestry owns the result;
## changing the damage source to the optical source would invent attribution.
static func _owned_fire_contact(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Array:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null \
        or fact.get("kind") not in ["spell","action"] or fact.get("source_entity_uuid")==null \
        or fact.get("target_entity_uuid")==null:return []
    var source:String=str(fact.source_entity_uuid)
    var target:String=str(fact.target_entity_uuid)
    var actor:Dictionary=graph.get("actor_inputs",{}).get(str(node.id),{}).get(source,{})
    var owners:Array=actor.get("conditions",[]).filter(func(member):return member.get("behavior_id")==descriptor.owner_condition_id)
    if owners.size()!=1:return []
    var saves:Dictionary=save_context(node,graph.get("application_results",{})).get("by_effect",{}).get(str(descriptor.save_effect_id),{})
    if not saves.get("ready",false):return []
    var rows:Array=graph.get("observed_results",{}).get(str(node.id),[]).filter(func(row):
        return row.kind=="damage" and row.target_uuid==target and row.node.get("phase")=="completion" \
            and row.node.fact.get("damage_type")==descriptor.damage_type and row.node.fact.get("source_entity_uuid")!=null \
            and _cast_owns_result(node,row.node,graph))
    if rows.size()!=1:return []
    var damage:Dictionary=rows[0].node
    var event:Dictionary={"owner_uuid":str(owners[0].condition_uuid),"source_uuid":source,
        "damage_component_uuid":str(damage.id),"trigger":str(descriptor.trigger),
        "outcome":"saved_half" if saves.save_succeeded else "failed_save","applied":true,"recipient_uuid":target}
    return [{"node":damage,"target_uuid":target,
        "values":{"owner_uuid":event.owner_uuid,"source_uuid":source,"event":event},
        "event":event,"inputs":{"contact_event":event},
        "evidence":{"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),
            "result_occurrence":str(damage.id),"result_lineage":str(damage.lineage_id),
            "source_uuid":source,"target_uuid":target,"owner_uuid":event.owner_uuid,
            "owner_condition_id":str(descriptor.owner_condition_id),"outcome":"damage",
            "damage_source_uuid":str(damage.fact.source_entity_uuid),"damage_type":damage.fact.damage_type,
            "applied_damage":damage.fact.applied_damage,"damage_component_identity":"native_applied_result_occurrence",
            "save":saves.evidence}}]
