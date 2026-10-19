extends RefCounted
## Observed native reactions, not a cancellation or spell-name classifier.
## Occurrence/lineage strings are seat-local protocol indices. Factory's
## *_uuid aliases do not turn them into global identities or wire UUIDs.

static func unavailable(reason:String)->Dictionary:
    return {"ready":false,"reason":reason,"observation":{},"evidence":{}}

static func observe(node:Dictionary,graph:Dictionary)->Dictionary:
    var fact:Dictionary=node.get("fact",{}) if node.get("fact")!=null else {}
    if node.get("canceled",false) or fact.get("kind")!="action" or fact.get("reaction")==null:
        return unavailable("reaction_completion_not_observed")
    var reaction:Dictionary=fact.reaction
    if reaction.get("triggered_lineage")==null:
        return unavailable("reaction_triggered_lineage_not_disclosed")
    var lineage:String=str(reaction.triggered_lineage)
    var triggered:Dictionary=graph.get("nodes",{}).get(lineage,{})
    if triggered.is_empty() or triggered.get("fact")==null:
        return unavailable("reaction_triggered_fact_not_disclosed")
    var parent:Variant=node.get("parent_event")
    if parent==null:return unavailable("reaction_triggering_occurrence_not_disclosed")
    # A terminal cast occurrence is not necessarily the version which fired
    # the reaction. Prove the actual native parent in the supplied version rows.
    var versions:Array=graph.get("version_index",{}).get("lineages",{}).get(lineage,[])
    if not versions.any(func(row):return str(row.occurrence)==str(parent)):
        return unavailable("reaction_triggering_occurrence_not_in_triggered_lineage")
    var source:Variant=fact.get("source_entity_uuid")
    if source==null:return unavailable("reaction_source_not_disclosed")
    var evidence={"reaction_occurrence":str(node.id),"reaction_lineage":str(node.lineage_id),
        "triggering_occurrence":str(parent),"triggered_lineage":lineage,
        "triggered_terminal_occurrence":str(triggered.id),"triggered_canceled":triggered.get("canceled",false),
        "source_entity_uuid":source,"target_entity_uuid":fact.get("target_entity_uuid"),
        "behavior_id":fact.get("behavior_id"),"automatic":reaction.automatic}
    # Attribution is corroboration, not a substitute for ActionFact.reaction.
    # Never borrow another seat's event number or infer a passive handler.
    var handlers:Array=[]
    for attribution in triggered.get("content_attributions",[]):
        if attribution.get("role")!="effective_handler" or attribution.get("behavior_id")!=fact.get("behavior_id"):
            continue
        if attribution.get("source_entity_uuid")!=source or str(attribution.get("triggering_occurrence"))!=str(parent) \
                or str(attribution.get("triggering_lineage"))!=lineage:
            continue
        if not attribution.get("emitted_lineages",[]).any(func(value):return str(value)==str(node.lineage_id)):
            continue
        handlers.append(attribution)
    if not handlers.is_empty():evidence.effective_handlers=handlers
    if node.get("turn_execution_id")!=null:evidence.turn_execution_id=node.turn_execution_id
    return {"ready":true,"reason":"","observation":{"reaction_uuid":str(node.id),
        "triggered_event_uuid":str(parent),"triggered_lineage_uuid":lineage,"succeeded":reaction.succeeded},
        "evidence":evidence,"triggered":triggered}

static func project(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Dictionary:
    var result:Dictionary=observe(node,graph)
    result.applies=true
    if not result.ready:return result
    if descriptor.has("succeeded") and result.observation.succeeded!=descriptor.succeeded:
        result.applies=false;return result
    var incoming:Dictionary=result.triggered.fact
    if not str(descriptor.get("trigger_kind","")).is_empty() and incoming.get("kind")!=descriptor.trigger_kind:
        result.ready=false;result.reason="reaction_trigger_kind_not_supported";return result
    # This study's authored target-hand endpoint belongs to the incoming
    # caster. Exact disclosed identity is required, never a nearest actor.
    if incoming.get("source_entity_uuid")==null or incoming.source_entity_uuid!=node.fact.get("target_entity_uuid"):
        result.ready=false;result.reason="reaction_incoming_caster_endpoint_not_bound";return result
    result.evidence.incoming_behavior_id=incoming.get("behavior_id")
    result.evidence.incoming_source_entity_uuid=incoming.source_entity_uuid
    result.evidence.incoming_target_entity_uuid=incoming.get("target_entity_uuid")
    return result

## Native values are ready before presentation geometry is ready. A successful
## cancellation currently has no scheduled incoming flight to sample. Keep
## that fact distinct from a missing backend reaction and do not construct the
## delivered study's saved Fireball path, midpoint or outcome fixture.
static func inputs(projected:Dictionary)->Dictionary:
    var gaps:Array=["reaction_incoming_presentation_path_unavailable"] if projected.ready else [projected.reason]
    return {"values":{},"gaps":gaps,"evidence":projected.evidence}
