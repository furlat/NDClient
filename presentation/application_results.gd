extends RefCounted
## Group-local observed results, keyed by native cast lineage and application.
## No target search, rule evaluation, defaults for hidden results or state edits.
static func key(node:Dictionary)->Array:
    var resolution:Dictionary=node.get("resolution_record",{})
    return [] if resolution.get("application_id")==null else [str(resolution.lineage),str(resolution.application_id)]

static func index(events:Array)->Dictionary:
    var result:Dictionary={}
    for node in events:
        var identity:Array=key(node)
        if identity.is_empty() or node.get("canceled",false) or node.get("fact")==null:continue
        var fact:Dictionary=node.fact
        if fact.kind!="saving_throw" and not (fact.kind=="damage" and fact.get("stage")=="applied"):continue
        if not result.has(identity):result[identity]={"saves":[],"damage":[]}
        result[identity]["saves" if fact.kind=="saving_throw" else "damage"].append({"occurrence":str(node.id),"lineage":str(node.lineage_id),"fact":fact})
    return result

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
        "evidence":{"cast_lineage":identity[0],"application_id":identity[1],"target_uuid":target,"save_occurrence":saves[0].occurrence,
            "damage_occurrences":damage.map(func(row):return row.occurrence),"applied_damage":amount}}
