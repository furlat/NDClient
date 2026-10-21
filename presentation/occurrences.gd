extends RefCounted
## Group-local presentation metadata. Native facts and journal values stay untouched.
## String ids are the seat's actual occurrence/lineage indices, never invented UUIDs.

static func group(source:Dictionary,initial:bool=false)->Dictionary:
    var result:Dictionary=source.duplicate()
    var versions:Dictionary=source.version_rows
    var owners:Dictionary={}
    for index in versions.get("occurrences",[]).size():owners[int(versions.occurrences[index])]=int(versions.lineages[index])
    var events:Array=[]
    var parents:Dictionary={}
    for actual in source.get("nodes" if initial else "events",[]):
        var node:Dictionary=actual.duplicate()
        node.id=str(node.occurrence);node.lineage_id=str(owners[int(node.occurrence)])
        node.canceled=node.get("canceled",false);node.fact=node.get("fact")
        node.children_lineages=node.get("children_lineages",[]).map(func(value):return str(value))
        node.parent_event=str(node.parent_event) if node.get("parent_event")!=null else null
        node.parent_lineage=str(node.parent_lineage) if node.get("parent_lineage")!=null else null
        node.resolution_record=source.get("resolutions",[])[int(node.resolution)] if node.get("resolution")!=null else {}
        for index in node.children_lineages.size():parents[node.children_lineages[index]]={"lineage":node.lineage_id,"order":index}
        events.append(node)
    for node in events:
        var parent:Dictionary=parents.get(node.lineage_id,{})
        node.parent_lineage=parent.get("lineage",node.parent_lineage);node.child_order=parent.get("order")
    result.events=events;result.id="initialization" if initial else str(source.lineage)
    result.root=events[int(source.root)] if not initial and source.get("root")!=null else null
    return result

static func spell(node:Dictionary,graph:Dictionary)->Dictionary:
    if graph.get("spell_facts",{}).has(node.id):return graph.spell_facts[node.id]
    var fact:Dictionary=node.fact
    var resolution:Dictionary=node.get("resolution_record",{})
    if resolution.get("application_id")==null:return fact
    var declaration:Dictionary=graph.get("nodes",{}).get(str(resolution.lineage),{}).get("fact",{})
    var result:Dictionary=fact.duplicate()
    for key in ["source_entity_uuid","behavior_id","name","source_position","declared_target_entity_uuids","cast_origin","source_item_uuid","area_propagation","effect_id","damage_types"]:
        if declaration.has(key):result[key]=declaration[key]
    graph.spell_facts[node.id]=result
    return result

static func application(node:Dictionary)->bool:
    return node.get("resolution_record",{}).get("application_id")!=null

## Exactly the child Attack the compiler schedules before a native Step.
## Scheduling identity excludes earlier versions and unrelated reaction names.
static func pre_motion_attack(node:Dictionary,graph:Dictionary)->bool:
    if node.get("canceled",false) or node.get("fact")==null or node.fact.get("kind")!="attack" \
        or not graph.get("starts",{}).has(str(node.id)):return false
    var parent:Dictionary=graph.get("nodes",{}).get(node.get("parent_lineage"),{})
    return parent.get("fact")!=null and parent.fact.get("kind")=="step" \
        and str(node.lineage_id) in parent.get("children_lineages",[])

static func application_index(node:Dictionary,graph:Dictionary)->int:
    var id:Variant=node.get("resolution_record",{}).get("application_id")
    return graph.get("application_indices",{}).get(str(id),0) if id!=null else 0
