extends RefCounted
## Immutable event-time captures emitted by the SDK fold; no authoring or scene resources.
static func empty_delta()->Dictionary:
    return {"set":{},"actors":{},"items":{},"tiles":{},"tiles_removed":[],"objects":{},"objects_removed":[],"spatial_commit_cursors":{}}
static func snapshot_senses(senses:Variant)->Variant:return senses
static func snapshot_actor(actor:Dictionary)->Dictionary:return actor

static func actor_inputs(target:Dictionary,node:Dictionary,_snapshots:Dictionary={},_retained:bool=false)->Dictionary:
    var result={};var fact:Variant=node.get("fact")
    if fact==null:return result
    for field in ["entity_uuid","source_entity_uuid","target_entity_uuid","observer_uuid"]:
        var identity:Variant=fact.get(field)
        if identity!=null and target.actors.has(identity):result[identity]=target.actors[identity]
    if fact.kind=="actor_change":
        for change in fact.get("actors",[]):
            if target.actors.has(change.actor_uuid):result[change.actor_uuid]=target.actors[change.actor_uuid]
    return result

static func item_inputs(target:Dictionary,actors:Dictionary)->Dictionary:
    var result:Dictionary={}
    for actor in actors.values():
        for layer in actor.get("visual_loadout",{}).get("layers",[]):
            if target.items.has(layer.item_uuid):result[layer.item_uuid]=target.items[layer.item_uuid]
    return result

static func capture_delta(target:Dictionary,node:Dictionary,bodies:Array,update:Variant,_snapshots:Dictionary={},_retained:bool=false,disclosed:Dictionary={},changed_actors:Dictionary={},changed_items:Dictionary={})->Dictionary:
    var delta=empty_delta();var identities=changed_actors.duplicate();var fact:Variant=node.get("fact")
    for record in bodies:identities[record.actor_uuid]=true
    if fact!=null and not node.get("canceled",false):
        for field in ["entity_uuid","source_entity_uuid","target_entity_uuid","observer_uuid"]:
            if fact.get(field)!=null:identities[fact[field]]=true
        if fact.kind=="actor_change":
            for change in fact.get("actors",[]):identities[change.actor_uuid]=true
        if fact.kind in ["sensory","spatial"]:
            delta.set.senses=target.senses
            for field in ["entity_members","object_contact_members","effect_members","light_sources","remembered_effects","spatial_content"]:delta.set[field]=target[field].duplicate()
        if fact.kind=="turn":delta.set.current_actor_uuid=target.current_actor_uuid;delta.set.round_number=target.round_number
        if fact.kind=="spatial" and fact.get("entity_uuid")!=null and target.spatial_commit_cursors.has(fact.entity_uuid):delta.spatial_commit_cursors[fact.entity_uuid]=target.spatial_commit_cursors[fact.entity_uuid]
    for identity in identities:
        if target.actors.has(identity):delta.actors[identity]=target.actors[identity]
    for identity in changed_items:delta.items[identity]=target.items[identity]
    if not bodies.is_empty():delta.set.static=target.static.duplicate()
    if update!=null:
        delta.tiles=disclosed.get("tiles",{});delta.tiles_removed=disclosed.get("tiles_removed",[]);delta.objects=disclosed.get("objects",{});delta.objects_removed=disclosed.get("objects_removed",[])
        delta.set.connectors=target.connectors.duplicate();delta.set.object_members=target.object_members.duplicate()
        delta.set.static=target.static.duplicate()
    return delta
