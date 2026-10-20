extends RefCounted
## Accepted finite actions and the seat's own operation-level sheet witness.
## Sheet changes are not native event facts; keep that disclosure boundary
## explicit instead of inventing a descendant spellbook event or item result.
const Actions=preload("res://presentation/native_action_authoring.gd")

static func sheets(before:Dictionary,packet:Dictionary)->Dictionary:
    var result:Dictionary={}
    var hud:Variant=packet.get("hud")
    if hud==null:return result
    var prior:Variant=before.get("hud_snapshot")
    for patch in hud.get("sheets",[]):
        if not patch.changes.has("scribed_spell_ids"):continue
        var actor:String=str(patch.actor_uuid)
        var held:Array=[] if prior==null else prior.get("sheets",[]).filter(func(row):return str(row.actor_uuid)==actor)
        var actual:Array=patch.changes.scribed_spell_ids.duplicate()
        var known:bool=held.size()==1 and held[0].has("scribed_spell_ids")
        var old:Array=held[0].scribed_spell_ids.duplicate() if known else []
        var added:Array=actual.filter(func(id):return id not in old)
        var accepted:Dictionary={}
        for lineage in packet.get("lineages",[]):
            for node in lineage.events:
                var fact:Variant=node.get("fact")
                if node.get("canceled",false) or node.phase!="completion" or fact==null \
                    or fact.kind!="action" or str(fact.get("source_entity_uuid",""))!=actor:continue
                var resolution:Variant=node.get("resolution")
                if resolution!=null and lineage.resolutions[int(resolution)].get("application_id")!=null:continue
                var behavior:String=str(fact.get("behavior_id",""))
                if not accepted.has(behavior):accepted[behavior]=[]
                accepted[behavior].append(str(node.occurrence))
        for rows in accepted.values():rows.make_read_only()
        accepted.make_read_only();old.make_read_only();actual.make_read_only();added.make_read_only()
        var witness:Dictionary={"known_before":known,"before":old,"after":actual,"added":added,"accepted":accepted,
            "operation_sequence":packet.cursor.sequence}
        witness.make_read_only();result[actor]=witness
    result.make_read_only()
    return result

static func project(node:Dictionary,descriptor:Dictionary,graph:Dictionary)->Dictionary:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null or fact.kind!="action" \
        or node.get("resolution_record",{}).get("application_id")!=null:
        return {"ready":false,"reason":"operation_accepted_completion_not_observed"}
    var actor:Variant=fact.get("source_entity_uuid")
    if actor==null:return {"ready":false,"reason":"operation_actor_not_disclosed"}
    var identity:String=str(node.id)
    var state:Dictionary={"operation_uuid":identity,"actor_uuid":str(actor),"outcome":"accepted",
        "present":true,"suppressed":false,"visibility":1.0}
    # Clear the review state in the private constructor. Only this actual
    # completion packet admits the finite source, through its public setter.
    var values:Dictionary={"operation_uuid":identity,"actor_uuid":str(actor),"state":{},"review_states":[]}
    var evidence:Dictionary={"operation_occurrence":identity,"operation_lineage":str(node.lineage_id),
        "source_uuid":str(actor),"behavior_id":fact.behavior_id,"admission":"noncanceled_action_completion"}
    if descriptor.operation=="scribe":
        var item:Dictionary=_source_item(node,graph)
        if not item.ready:return item
        var witness:Dictionary=graph.get("operation_sheets",{}).get(str(actor),{})
        if not witness.get("known_before",false):return {"ready":false,"reason":"operation_prior_spellbook_not_disclosed"}
        var completions:Array=[]
        for rows in witness.accepted.values():completions.append_array(rows)
        if witness.added.size()!=1 or completions!=[identity]:
            return {"ready":false,"reason":"operation_learned_spell_not_unambiguous"}
        values.item_uuid=item.item_uuid;values.learned_spell_id=str(witness.added[0]);state.item_uuid=item.item_uuid
        evidence.merge(item.evidence);evidence.item_uuid=item.item_uuid;evidence.learned_spell_id=str(witness.added[0])
        evidence.sheet_witness={"scope":"operation_hud","operation_sequence":witness.operation_sequence,
            "before":witness.before,"after":witness.after}
    return {"ready":true,"reason":"","values":values,"inputs":{"operation_state":state},"evidence":evidence}

## Consuming the last scroll can retire it before the completed ActionFact,
## which then omits source_item_uuid. Its real descendant charge retains the
## exact item identity; a cached inventory entry never supplies that link.
static func _source_item(node:Dictionary,graph:Dictionary)->Dictionary:
    var disclosed:Variant=node.fact.get("source_item_uuid")
    if disclosed!=null:return {"ready":true,"item_uuid":str(disclosed),"evidence":{"item_identity":"action_source_item"}}
    var charged:Dictionary={}
    for candidate in graph.get("nodes",{}).values():
        var fact:Variant=candidate.get("fact")
        if candidate.get("canceled",false) or candidate.get("phase")!="completion" or fact==null \
            or fact.kind!="item_charge" or fact.get("source_entity_uuid")!=node.fact.source_entity_uuid \
            or fact.get("resource_change")!="consume" or not Actions.descendant(candidate,node,graph):continue
        var parent:Variant=candidate.get("parent_lineage")
        while parent!=node.lineage_id:
            var ancestor:Dictionary=graph.nodes.get(str(parent),{})
            var action:Variant=ancestor.get("fact")
            if ancestor.get("canceled",false) or action!=null and action.kind in ["action","spell","attack"]:break
            parent=ancestor.get("parent_lineage")
        if parent!=node.lineage_id:continue
        var item:String=str(fact.item_uuid)
        if not charged.has(item):charged[item]={"occurrences":[],"lineages":[]}
        charged[item].occurrences.append(str(candidate.id));charged[item].lineages.append(str(candidate.lineage_id))
    if charged.size()!=1:return {"ready":false,"reason":"operation_source_item_not_disclosed" if charged.is_empty() else "operation_source_item_ambiguous"}
    var item:String=charged.keys()[0]
    return {"ready":true,"item_uuid":item,"evidence":{"item_identity":"descendant_consumed_charge",
        "item_charge_occurrences":charged[item].occurrences,"item_charge_lineages":charged[item].lineages}}
